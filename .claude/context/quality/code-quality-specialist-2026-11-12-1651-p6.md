---
agent: code-quality-specialist
date: 2026-11-12-1651
area: quality
target: git diff 30485ee..ff73c2e（overview.sh --live、run-tests.sh 新節、worktree-orchestration 一句）
severity: high
status: findings
---

# 階段 6 即時聚合 --live 審查：有 1 個 HIGH（.live-dirty 沒有「尾端補跑」，最後一筆事件會被吞）

## TL;DR
JQ_LIVE／JQ_GLOB 實際用本機 jq 1.6（/usr/bin/jq）與 1.8.1 跑同一組 fixture，輸出逐字相同；need 開關、排序、lanes、clashes、doneToday、不重寫都照檔頭做。
HIGH：--live 跑完之後才寫進來的 .live-dirty 沒有人處理，2 秒視窗內的最後一筆事件（例如另一條線的 PermissionRequest）要等到下一筆事件才會出現在畫面上。
MEDIUM：只觸發 PermissionRequest 而 PostToolUse 沒接線的工具（WebFetch、MCP 等），need 會一直掛到下一筆有記的事件；session lane 的 doing 會沿用 Stop 之前的動作；效能案例沒有限平台。

## 範圍
- **檢查目標**: .claude/scripts/overview.sh（檔頭即時聚合段、JQ_GLOB、JQ_LIVE、take_live_lock／live_once／live_rounds、run_once 接線、plans[].files）、.claude/hooks/tests/run-tests.sh「overview.sh --live」節、worktree-orchestration SKILL.md 一句
- **觸發原因**: plan adhoc-2026-11-12-overview-live 階段 6 的階段審查
- **參考資料**: plan 階段 6、ADR-2026-11-12-002、learned/2026-11-04-jq-windows-non-ascii-path.md、hooks/agent-events.sh 觸發段（未變更，用來對照 dirty 的契約）

## 發現

### 🔴 Critical / High
- `.claude/scripts/overview.sh:471-484`（搭配未變更的 `.claude/hooks/agent-events.sh:132-135`）— agent-events 在 2 秒視窗內只寫 `.live-dirty`、不啟動 --live，靠「持鎖者跑完前看到 dirty 再跑一輪」消化。但 --live 跑一次不到 1 秒，第一筆觸發的 --live 跑完放鎖後才寫進的 dirty 沒有人處理；之後如果沒有新事件，live.js 就停在少一筆的狀態。重現步驟：agent X 在第 S 秒寫檔（觸發 --live，0.5 秒跑完）→ agent Y 在第 S+1 秒 PermissionRequest（在視窗內，只留 dirty）→ 兩條線都在等使用者，沒有下一筆事件 → 「需要你」看不到 Y。run_once 裡呼叫 live_rounds 時拿不到鎖也走同一條路（curGroups 的變更會晚一拍才反映）。 → 建議在 live_rounds 補上視窗結束後的尾端檢查：持鎖等到 `.live-at` 加視窗秒數，再看一次 `.live-dirty`，有就再跑一輪（背景行程多活約 2 秒）；或是改 agent-events：在視窗內但沒有 `.live.lock` 時照樣啟動 --live。要補一個案例：先跑完 --live，再只留 `.live-dirty`，確認畫面最後會反映。

### 🟡 Medium
- `.claude/scripts/overview.sh:376-389`（關閉規則；接線在 `.claude/settings.json` 的 PreToolUse／PostToolUse matcher）— 這不是本 diff 引入的，是 ADR 第 5 節前提跟接線之間的落差：關閉規則 1 假設「使用者回應後，那條線的下一個動作會留下事件」，但 PreToolUse 只接 `AskUserQuestion|Bash|PowerShell`、PostToolUse 只接 `Write|Edit|MultiEdit|Bash|PowerShell|AskUserQuestion`。PermissionRequest 是 WebFetch、MCP、NotebookEdit 這類工具觸發的，批准後沒有 PostToolUse；接下來如果只做 Read、Grep、WebFetch，也都不會留下事件。結果 need 會一直掛著：subagent 要等到 SubagentStop，主 session 要等到下一個 Bash、寫檔或 Stop。這要主模型決定：PostToolUse 加接全部工具（只記 ev／tool），或是接受並寫進 KNOWN-GAPS。
- `.claude/scripts/overview.sh:355,370` — session lane 的 since 取「最後一個 Stop 之後」，但 `doing($evs)` 和 `lfiles` 吃的是這個 sid 全部的事件。實測：PostToolUse「跑 測試」→ Stop → 60 秒後 Notification idle_prompt，lane 會重新出現，而且 doing 是「跑 測試」（Stop 之前的動作），但這個 session 其實閒著在等輸入。 → doing 改成只看 Stop 之後的事件；另外要不要讓 idle_prompt 讓 lane 重新出現，交給階段 7 一起決定。
- `.claude/hooks/tests/run-tests.sh:5656` — 「3000 行 < 1 秒」沒有限定平台。plan 寫的是「在 Linux 上」；Git Bash 起一個行程約 170ms，live_once 至少要起約 10 個（git、tail、grep、sed、date×3、jq、mv…），Windows 上整套測試這個案例幾乎一定失敗。 → 用 `uname -s` 判斷，MINGW／MSYS／CYGWIN 只印耗時、不斷言（`:5765` 已經有同樣的寫法）。
- `.claude/scripts/overview.sh:389` — 自加的「同 aid 的 SubagentStop 換了 sid 也算關閉」（$stopP 那條）沒有案例：`:5536-5538` 的 SubagentStop 跟 need 同 sid，走的是 reduce 那條路。`live_rounds` 的「看到 dirty 再跑一輪」、`.live-error` 的寫入與清除也都沒有案例。不是 plan 驗收列的項目，所以不建 handoff。

### 🟢 Low / Info
- `.claude/scripts/overview.sh:441,445` — 主 checkout 的事件檔最後一行如果寫到一半（沒有換行），jq -R 會把它跟下一個檔（第一個 worktree 檔）的第一行接成同一行，兩筆一起被 fromjson? 丟掉。1.6／1.8.1 都實測過。→ 每個 tail 之後補一個 `printf '\n'`（空行會被 fromjson? 略過，已實測）。
- `.claude/scripts/overview.sh:376-383` — 開著的 need 被新的開啟者取代、或因 $stopP 關掉時，feed 不會出現 need_done，只會看到連續兩筆 need_open。
- 自述的差異都可以接受：readonly 照 lib 名單（ADR 寫「從 lib 讀、不抄一份」，plan 驗收寫錯了，progress 已有 Ruling）；clashes「只靠對方 glob、兩線同組就不算」合理，真的兩邊都寫還是抓得到；`agents` 欄位、need id、feed 形狀、沒做 aid 為空的退路（檔頭有寫原因）都 OK。

### 逐項確認（brief 1–11）
1. need：開啟者／關閉者、10 秒合併（XOR 判斷，連鎖合併也對）、只留最新、4 小時、主 session 由 UPS 關閉、PreToolUse 同一秒但 ms 較小又反序寫入，都正確，有實測。macOS／bash 4 的 ms=0 只能靠行序，這是階段 3 已接受的限制。
2. 排序：`sort_by([.t,.ms,.i])`，i 是串接後的輸入序號，所以排序穩定；檔案順序是 ev0（主 checkout）在前、worktree 照 glob 展開順序，跟檔頭描述一致。
3. readonly：在 live_once 裡 `source` lib，lib 頂層只有一個賦值和三個函式定義，沒有副作用，函式名也沒有和 overview.sh 撞名；local 變數會接住 lib 的賦值。
4. clashes：只有實際寫入才逐檔比對；兩邊都只有 glob 重疊不算；同一 checkout 兩個還在跑的 agent 都寫同一檔算。glob2re 是原樣搬移，`**`、`**/`、`*`、`?`、`.`、`()` 跳脫、結尾 `/`、沒有萬用字元時當前綴，在兩個 jq 版本都實測過（`[ab]` 照字面處理，跟搬移前一致）。
5. doneToday：day0 用本機時區的時分秒倒推（DST 切換那天可能差 1 小時，可忽略）；同 aid 只算 1；tasks 用 [月,日] 比對 doneOn。
6. 鎖：沒有永久鎖（有 at 檔且超過 30 秒就接手），沒有無限迴圈（最多 3 輪）；尾端的問題見 HIGH。
7. 不重寫：輸出裡沒有用「現在」算出來的衍生值（since／lastAt／feed.t 都是事件的絕對時間），只有跨過 15 分／4 小時／12 小時門檻時內容才會變；`${old%,"at":*}` 不會被字串內容誤切（字串裡的引號都被跳脫）。
8. jq 1.6：本機 `/usr/bin/jq` 就是 1.6（implementer 用的是 `~/.local/bin/jq` 1.8.1）。用整份 JQ_GLOB＋JQ_LIVE 在 1.6 實跑了三組 fixture：一般情況、壞行／v2／t 非數字／非物件、空輸入，輸出跟 1.8.1 逐字相同。逐一確認過：`--rawfile`、`-n -R inputs`、`input_filename`、`fromjson?`、`tonumber?`、管線中途的 `def`、`reduce`、`group_by`／`unique_by`／`sort_by` 陣列鍵、`any(g; c)`、`first`／`last`、字串切片 `.[:120]`、`+=`、gsub 具名擷取；沒有用到 trim／abs／toarray／pick／limit／splits／ltrimstr／$__loc__，變數名也沒有保留字。
9. 中文路徑：jq 讀的檔全部在 `cd "$d"` 之後用相對 ASCII 檔名，跟 run_once 的做法一致。
10. plans[].files：只有幾個 glob 字串；level 4 縮減時不是本次的 plan 會被丟掉 files，但 curGroups 對應的都是本次的 plan，所以不影響；檔案內容是靜態的，不影響「沒變不重寫」。
11. 測試：都斷言具體的值，OVERVIEW_NOW 和 TZ 都固定，路徑含中文和空格；平台相依見 MEDIUM。

## 建議的後續 Agent
- 無 handoff（沒有「有風險的路徑完全沒測」，也沒有安全問題）。HIGH 交回主模型進修復迴圈；ADR 前提落差那條要主模型或使用者決定。

## 度量
- 檢查檔案數: 3（另外對照 agent-events.sh、settings.json、agent-inflight.sh）
- 通過: 9 項 | 警告: 1 HIGH、4 MEDIUM | 失敗: 0 CRITICAL
