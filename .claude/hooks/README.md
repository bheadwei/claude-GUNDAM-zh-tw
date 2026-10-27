# 🪝 Hooks 系統

`.claude/hooks/` 下的 shell 腳本由 Claude Code 在特定事件自動觸發，負責**副作用與上下文注入**（記錄、時間追蹤、agent 觀測、handoff 自動化、意圖路由）。掛載設定在 `.claude/settings.json` 的 `hooks` 區。

## 📁 檔案結構

```
.claude/hooks/
├── README.md                # 本文件
├── session-start.sh         # SessionStart：模板偵測、時間歸檔、log 輪替、進行中任務接續
├── user-prompt-submit.sh    # UserPromptSubmit：/task-init 偵測 + 意圖路由注入 + pending handoff 注入
├── pre-tool-use.sh          # PreToolUse(Write|Edit|MultiEdit|Bash|PowerShell)：任務模式閘門（含從 plan 還原）+ 坑閘門 + TTL + 裸 cd 攔截 + 四道 git lib 閘門 + rm 權限判斷
├── pre-agent-gate.sh        # PreToolUse(Agent)：擋同時派多個無隔離 subagent（deny-once；唯讀名單與定義自帶隔離放行）
├── lib/                     # 共用函式庫（被多支 hook source，不自己掛事件）
│   ├── agent-inflight.sh    # 算「還有幾個 subagent 在跑」＋唯讀名單（pre-agent-gate + branch-switch-gate 共用）
│   ├── branch-switch-gate.sh # 站在 topic 分支上不得直接開新分支（pre-tool-use 用）
│   ├── check-report-expectations.sh  # 延後式報告稽核（post-agent-report + user-prompt-submit 共用）
│   ├── cmd-segments.sh      # 指令切段／樣式比對（四道 git 閘門 + post-bash 共用，見下方註）
│   ├── doc-impact.sh        # 「改了這個檔，文件會不會過期」的判斷規則（post-write + post-bash 共用）
│   ├── git-backup-gate.sh   # destructive git 操作前必須有 backup tag（pre-tool-use 用）
│   ├── handoff-archive.sh   # 已完成交接的歸檔
│   ├── handoff-scan.sh      # pending 交接掃描與注入文字（post-agent-report + user-prompt-submit 共用）
│   ├── merge-gate.sh        # 合併未驗證前不得再合併（pre-tool-use 用）
│   ├── merge-noff-gate.sh   # 合併本地 topic 分支必須帶 --no-ff（pre-tool-use 用）
│   ├── resolve-roots.sh     # MAIN_ROOT / WORK_ROOT 解析（worktree 狀態隔離）
│   ├── rm-state-gate.sh     # rm 只刪 hook 狀態檔或 scratchpad 暫存區 → allow，其他 rm → ask（pre-tool-use 用；取代 settings 的 ask 規則）
│   └── ui-lint.sh           # 前端寫入檢查：寫死色碼、動畫等級不符、AI 痕跡 P0（post-write 用）
├── post-write.sh            # PostToolUse(Write|Edit)：WBS 歷史＋格子長度提醒、hook 語法檢查、擴充維護提醒、文件影響偵測、前端寫入檢查
├── post-bash.sh             # PostToolUse + PostToolUseFailure（Bash|PowerShell）：合併待驗證紀錄（含衝突、reflog 確認、補文件債）+ 連續失敗後成功 → 踩坑候選累積
├── agent-monitor.sh         # Pre/PostToolUse(Agent) + SubagentStop：subagent 活動記錄
├── post-agent-report.sh     # PostToolUse(Agent)：報告稽核 + pending handoff 注入
├── pre-compact.sh           # PreCompact：壓縮前快照工作狀態到 sessions/
└── watch-agents.sh          # 手動工具（非 hook）：即時追蹤 agent 活動
```

> 已移除 `hook-utils.sh`（舊 TaskMaster `taskmaster.js` 時代的共用庫，無任何 hook 引用）。
>
> **判斷「這條指令做了什麼」一律走 `lib/cmd-segments.sh`，不要用 `case "$CMD" in *"<指令名>"*)`。**
> 子字串比對會把唯讀查詢（`git merge-base`）與文件內文（heredoc、echo、grep 樣式）
> 當成真的執行過——2026-09-11 實測一天誤擋四次，其中一次擋下了「修好它自己」的那次編輯。
> 以前 `lib/merge-gate.sh` 是刻意保留的例外（「只在 `.merge-pending` 非空時才比對」），
> 2026-10-20 已改用同一套：待驗證期間正是最常查歷史的時候，`git merge-base`、
> `git log | grep "git merge"` 都被它擋過。**現在沒有例外。**
>
> **效能是 `pre-tool-use.sh` 的正確性問題**：hook 超時時 Claude Code **放行**那個工具呼叫。
> Windows 上每開一個行程約 170ms，四道 git 閘門各自切段時 `git checkout -b` 曾跑到 12～15 秒
> （timeout 10 秒）。現在指令不含 `git` 就跳過四道閘門、切段只做一次（`CMD_SEGS`）、
> 常用的比對與路徑轉換改用 bash 內建；timeout 調到 30 秒當安全邊際，**不要**改成超時即擋。

## 🎯 各 Hook 功能

| 腳本 | 事件 / Matcher | 功能 |
|---|---|---|
| `session-start.sh` | `SessionStart` | 偵測 `CLAUDE_TEMPLATE.md` 顯示提示；歸檔上次 session 時間；**啟動時一次性輪替 log**；jq 缺失健檢；擴充維護提醒：①踩坑候選未處理 ②設計走向超過 90 天沒更新 ③`.claude/ui/_sources.json` 有上游的來源 `last_synced` 是 null 或超過 90 天 → 提醒跑 `scripts/sync-ui-sources.sh` 預覽。**②③只在模板 repo 出現**，判斷依據是 `scripts/sync-ui-sources.sh` 在不在（四份 copy／update 腳本都排除它；測試用 `copy-template.sh` 真的建一個新專案驗證不會出現）。逃生門：`CURATION_REMINDERS=off`。①的措辭是「收尾時處理」，不要求開場就打斷使用者。**跨 session 接續**：當前 checkout 有 `taskmaster-data/.current-task` 時注入一行「進行中任務 X（mode Y），用 `/tdd` 接續」，mode 先讀模式檔、沒有再讀 plan 的 `mode:`，並附最新一份 `.claude/sessions/*.md` 的路徑 |
| `user-prompt-submit.sh` | `UserPromptSubmit` | 偵測 `/task-init` 建資料夾；依關鍵字注入「建議任務模式 + 建議 agent 鏈」（受 `.suggest-mode` 控制）。前端路由的 `ui`／`css` 前後不能是英文字母（否則 quick、build、guide 都會命中），另認「網站／官網／landing／形象頁／一頁式／首頁／版型／配色／字型」。`pip`／`uv`／`test`／`bug` 也有單字邊界（pipeline、latest、debug 不命中）；金流比對前先拿掉 `git checkout`；`permission` 是弱訊號、裸 `token` 不算認證邏輯字（「settings 的 permission」「session 的 token 用量」不再判 critical）。**pending handoff 注入**（`lib/handoff-scan.sh`，與 `post-agent-report.sh` 同格式、同上限 5 筆）：Agent 是非同步的，只接 `PostToolUse(Agent)` 時 agent 建的交接要等下一次派工才看得到，而那個提示本來就是要觸發下一次派工。只在有 pending 時輸出，斜線指令與 agent 交回訊息也照樣輸出。**刻意不接 `SubagentStop`**（未驗證它能注入主對話） |
| `pre-tool-use.sh` | `PreToolUse` `Write\|Edit\|MultiEdit\|Bash\|PowerShell`（timeout 30） | **模板唯一的硬閘門**：①寫程式碼檔前未判級 → 先依契約從進行中任務的 plan 還原（`.current-task` → `plans/<值>.md` 或 `plans/<值>-*.md` 的 `mode:`，不含 `archive/`），還原成功就寫回模式檔並經 `additionalContext` 告知；還原不了才 `deny` 並要求先判級，訊息裡的寫入指令是**展開後的實際路徑**（worktree 裡就是 worktree 那份） ②模式檔逾 `TASKMODE_TTL_HOURS`（預設 8h）自動清除，解掉「verify 沒清 → 判級永久不觸發」的互鎖 ③**坑閘門**：要寫的檔案在 `context/learned/*.md` 的 `files:` glob 命中時 `deny` 一次並貼出 symptom/root-cause/guard，讀完重試即通過（同檔案一 session 只擋一次） ④裸 `cd` 攔截 ⑤Bash 的四道 lib 閘門，依序 `merge-gate`（上一個合併未 `/verify` 前不得再合併）→ `branch-switch-gate`（站在非預設分支上 `git checkout -b`／`git switch -c` → `deny`；有 in-flight subagent 時**持續擋**（會抽掉它腳下的分支），沒有時**擋一次**（新分支的基底會混進前一個任務）；帶 start-point、站在預設分支上、detached HEAD 均放行）→ `merge-noff-gate`（合併本地 topic 分支沒帶 `--no-ff` → `deny`，fast-forward 會讓任務邊界永久消失；遠端／同步 ref、`--squash`、`--ff-only` 放行；**無 deny-once**，補旗標重打即通過）→ `git-backup-gate`（destructive 操作前被弄丟的那個 commit 必須有 `backup/*` tag：一般是 HEAD；`branch -D <b>` 看 `<b>` 的 tip；`reset --hard` 沒帶目標時工作區乾淨就放行、有未 commit 改動就換訊息說明 tag 救不到）。四道 git 閘門 **Bash 與 PowerShell 都管**（裸 `cd` 只管 Bash），指令不含 `git` 時整段跳過、切段只做一次。逃生門：`.suggest-mode=off`、`TASKMODE_GATE=off`、`PITFALL_GATE=off`（只關坑閘門）、`MERGE_GATE=off`、`MERGE_NOFF_GATE=off`、`GIT_BACKUP_GATE=off`、`BRANCH_SWITCH_GATE=off` ⑥**rm 權限**（`lib/rm-state-gate.sh`，只管 Bash）：每段 `rm` 的目標都是 `<root>/.claude/taskmaster-data/.<名稱>`（不得帶 `-r`）或 Claude Code 的 scratchpad 暫存區（`…/claude[-<uid>]/<專案>/<session>/scratchpad[/…]`，可帶 `-rf`），且整條指令除了 `cd` 與單獨成段的 `S=/字面路徑` 沒別的 → `allow`（`$S`／`"$S"`／`${S}`／`$S/子路徑` 會換成同一條指令裡設過的字面值；設兩次、`export`、`S=$(…)` 不認）；任何一段刪的不是狀態檔或判斷不了（`$`、萬用字元、`~`、`\`、`..`、`-r` 等旗標、不知道 cwd 的相對路徑、heredoc 內文裡以 `rm` 開頭的行）→ `ask`；只刪狀態檔但混了其他指令 → 不表態。取代 `settings.json` 原本的 `ask: Bash(rm:*)`——hook 回 `allow` 蓋不過 settings 的 ask 規則（官方文件），那條規則在 auto mode 下連刪 `.merge-pending` 都要人按。逃生門：`RM_STATE_GATE=off` |
| `post-write.sh` | `PostToolUse` `Write\|Edit` | ①WBS 更新寫歷史 ①-b **WBS 格子長度提醒**：寫入 `taskmaster-data/wbs.md` 時掃 Markdown 表格列，格子的可見文字（以 codepoint 計，中文一字算一；連結的 `](目標)` 不計）超過 `WBS_CELL_MAX`（預設 40）字 → 經 `additionalContext` 列出任務編號與欄位，附長內容去處對照；沒有「現況」區時順帶指向 `/task-status` 的舊格式轉換。每次寫入最多一則，**只提醒不擋**。版面唯一來源 `.claude/templates/wbs.template.md`。逃生門：`WBS_CELL_CHECK=off`、`.suggest-mode=off` ②**文件影響偵測**：改到「文件描述的對象」（`*/api/*`、`*/routes/*`、`*openapi*`、`*/migrations/*`、`*/models/*`、`*/index.ts`、`*/cli/*`…）時記進 `taskmaster-data/.doc-impact`，本任務第一次命中經 `additionalContext` 提醒一次；`/verify` 標 WBS ✅ 前必須處理該清單。排除 `.claude/**`、`docs/**`、測試檔、依賴與建置產物。逃生門：`DOC_SYNC_GATE=off` ③**前端寫入檢查**（`lib/ui-lint.sh`）：寫入 `tsx／jsx／vue／svelte／html／css／scss`（不含 `.claude/**`（worktree 除外）、`docs/**`、測試檔（`test/`、`tests/`、`__tests__/`、`*fixtures*`、`*.test.*`、`*.spec.*`、`*.stories.*`）、依賴（`node_modules/`、`vendor/`）與建置產物（`dist/`、`build/`、`.next/`、`out/`、`coverage/`、`*.min.css`））時讀**磁碟上的檔案**；副檔名與 `.claude/` 由 `post-write.sh` 先篩過才啟動 `ui-lint.sh`：寫死 hex（tokens／theme 檔、`--x: #…` 宣告、`var()` 備援值、頁內錨點除外）；`ui-style.json` 的 `motion` 是 L1 卻 import／CDN 載入動畫函式庫、L2 卻載入 three／Vanta／Spline（沒有 `ui-style.json` 不檢查，沒有 `motion` 當 L1；頁面檔對應得到 `docs/17_frontend_information_architecture.md` 裡該頁 snippet 的「動畫等級」時以單頁為準，對應不到時取專案與各頁中最寬鬆的那級，寧可漏提醒不誤報）；AI 痕跡 P0 三條（C6 漸層字、C1 紫靛漸層的 Tailwind 寫法、K1 沒改過的 shadcn `--primary`，改寫自 avoid-ai-design 的 `detect.mjs`，MIT 原文在 `.claude/ui/_licenses/avoid-ai-design.txt`，可用 `avoid-ai-design-ignore: <ID>` 豁免）。與文件影響提醒同時命中時合併成一則。**只提醒不擋**，只接 `PostToolUse`（寫檔失敗時磁碟內容沒變，沒有東西可檢查）。逃生門：`UI_LINT=off`、`.suggest-mode=off` |
| `post-bash.sh` | `PostToolUse` `Bash\|PowerShell` + **`PostToolUseFailure` `Bash\|PowerShell`** | **兩個事件都要接**：官方定義 `PostToolUse` 只在成功時觸發，指令非零結束走 `PostToolUseFailure`（payload 沒有 `tool_response`，錯誤在頂層 `error`，首行 `Exit code N`）。只接前者時下面兩個功能都在失敗那一刻收不到事件（2026-10-15 修，見 `context/learned/2026-10-15-posttooluse-skips-failures.md`）。①**合併待驗證**：執行了 `git merge`／`cherry-pick`／`rebase`（切段比對，見 `lib/cmd-segments.sh`）→ 記進 `taskmaster-data/.merge-pending` 供 `lib/merge-gate.sh` 擋下一次合併；成功、衝突、非零但原因不明**一律記**。衝突判定看 `git ls-files -u`，後備看輸出的衝突字樣 → 導向 `conflict-resolver`。`--abort` 成功清單、**失敗不清**。沒有衝突時看 `git reflog -1`：最新一筆不是 30 分鐘內（`MERGE_REFLOG_WINDOW`）的 merge／cherry-pick／rebase → 合併沒發生（分支名打錯、被拒），**不記**；讀不到 reflog 照舊記（逃生門 `MERGE_REFLOG_CHECK=off` 恢復一律記）。合併成功時用 `git diff --name-only ORIG_HEAD HEAD`（cherry-pick 用 `HEAD@{1}`）套 `lib/doc-impact.sh` 的規則補進這個 checkout 的 `.doc-impact`——worktree 那份是短命旗標，不會跟著合併回來（逃生門 `DOC_SYNC_GATE=off`）。逃生門：`MERGE_GATE=off` ②**踩坑偵測**：**同一件事**（指令前 40 字相同；換指令就歸零）連續失敗 ≥N 次（預設 3，`LEARN_CAPTURE_THRESHOLD`）然後成功 → 記進 `taskmaster-data/.learned-candidates` 並經 `additionalContext` 提醒一次。一次就過的不算坑。`.learned-notified`（「本任務只提醒一次」的旗標）由 `/verify` 完成任務時清除——那是文件線（`commands/verify.md`）的職責，本 hook 不清。`session-start.sh` 在下次開場提醒清單未清空，`pre-compact.sh` 把清單寫進快照（PreCompact 不支援 additionalContext）。逃生門：`LEARN_CAPTURE=off` |
| `pre-agent-gate.sh` | `PreToolUse` `Agent` | 擋下「同時派多個**沒帶 `isolation`** 的 subagent」——它們全在同一個工作目錄動手，改到同一檔案時後寫的直接覆蓋前面的，無衝突提示也無錯誤。從 `agent-activity.jsonl` 算 in-flight（**對應鍵 `agent_id`**），deny-once：擋第一次並貼出三個選項，重試即通過；in-flight 歸零時清除標記讓下一批重新受檢。**攔截訊息先給一個推薦**（工作區不乾淨或沒有帶 `files:` 的 plan → 序列化；乾淨且有 plan → worktree），算不出來就安靜退回中立三選項；推薦所需的 `git status` **只在攔截路徑跑**。**掃描／驗證類 agent**（`security-infrastructure-auditor`、`code-quality-specialist`、`test-automation-engineer`、`e2e-validation-specialist`、`refactor-cleaner`）在本次派工或 in-flight 名單裡時改走另一條路：推薦序列化並講**讀寫衝突**（它們讀／跑整個 repo，寫入集卻是空的，所以「檔案範圍不重疊」永遠成立）、**收掉選項 3**、**不套用 deny-once**（擋到 in-flight 歸零或帶 `isolation` 為止）。**不必擋的兩類**（依據與邊界在本檔頭）：①定義檔 frontmatter 寫 `isolation: worktree` 的（refactor-cleaner）視同帶隔離 ②唯讀名單 `Explore Plan claude-code-guide planner architect workflow-template-manager`（`lib/agent-inflight.sh`，兩道閘門共用）——要派的是名單內的直接放行，在跑的不算 in-flight；`general-purpose` 絕不進名單。in-flight 計數**逐行容錯**（壞行跳過，以前一行截斷就讓計數歸零、閘門靜默失效）。逃生門：`PARALLEL_AGENT_GATE=off`、`.suggest-mode=off` |
| `agent-monitor.sh` | `Pre/PostToolUse` `Agent` + `SubagentStop` `.*` | 記錄 subagent 啟動/完成（人類可讀 `agent-activity.log` + 結構化 `agent-activity.jsonl`）。**JSONL 的帳：`agent_start` 由 `PostToolUse` 寫（`agentId` 只在 tool response 裡）、`agent_complete` 由 `SubagentStop` 寫**。不能拿 `PostToolUse` 當完成——Agent 工具是非同步的，它記的是「派工返回」（實測 2 秒）而非 agent 做完（實測 44 分鐘）；靠它判斷完成會讓 `pre-agent-gate.sh` 的 in-flight 永遠是 0。`agent_start` 帶派工參數的 `isolation`（帶 worktree／remote 的不算 in-flight） |
| `post-agent-report.sh` | `PostToolUse` `Agent` | ①**報告稽核**：非同步啟動（`tool_response` 帶 `async_launched`）的 agent 此刻還沒動工，立即 find 必假警報 → 只記期望到 `.report-expectations.jsonl`，由 `lib/check-report-expectations.sh` 在後續對話邊界重查並**注入**要求補寫；同步完成的仍當下稽核。期望帶 `agent_id`：`agent-activity.jsonl` 還沒有它的 `agent_complete` 就**先不催**（還在跑的 agent 不該被要求補寫），最多等 4h（`REPORT_INFLIGHT_MAX_SECONDS`）；結束後的期限從最後一次看到它在跑起算。`refactor-cleaner` 跑在自己的 worktree、報告與 handoff 全文在回應裡，缺檔時的訊息是「請主模型落檔」而不是缺漏 ②掃描 `coordination/handoffs/` 的 pending 交接並注入主對話（`lib/handoff-scan.sh`，`user-prompt-submit.sh` 也接；受 `.suggest-mode` 控制）。逃生門：`REPORT_AUDIT=off` |
| `pre-compact.sh` | `PreCompact` | context 壓縮（manual/auto）前，將當前任務 / git 狀態 / 最近 agent 活動快照到 `sessions/auto-precompact-<ts>.md`（敘事式存檔仍用 `/save-session`） |
| `watch-agents.sh` | （手動）| `--summary` / `--last N` / `--json` / `--clear`；被 `/agent-log` 包裝 |

## ⚙️ 相關設定檔

- `.claude/taskmaster-data/.suggest-mode` — `high`/`medium`/`low`/`off`，控制意圖路由與 handoff 注入密度（預設 medium）。由 `/suggest-mode` 寫入。
- `.claude/taskmaster-data/.session-snapshot` / `.session-start` — 時間追蹤用。
- log 一律寫在 `.claude/logs/`（`hooks.log`、`agent-activity.log`、`agent-activity.jsonl`、`context-reports.log`）。

## 🧹 Log 輪替

`session-start.sh` 在**每次 session 啟動時**將各 log 截尾保留最後 N 行（`agent-activity.log` 8000、`.jsonl` 5000、`hooks.log` 2000、`context-reports.log` 1000）。集中在啟動做，避免在高頻 hook 中加 per-call 成本。

## 🔍 除錯與測試

```bash
# 查看 hook log
tail -n 50 .claude/logs/hooks.log

# 即時追蹤 agent 活動（另開終端）
bash .claude/hooks/watch-agents.sh
bash .claude/hooks/watch-agents.sh --summary

# 手動測試（hook 從 stdin 讀 JSON）
echo '{"hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"subagent_type":"planner","description":"x","prompt":"y"}}' \
  | bash .claude/hooks/agent-monitor.sh

# 除錯模式（部分腳本支援）
export TASKMASTER_DEBUG=true
```

## 🛠️ 撰寫新 Hook 的慣例

1. **不要用 `set -e`** — hook 不應因小錯中斷 Claude Code；以 `exit 0` 收尾，關鍵指令用 `|| true` 兜底。
2. **路徑用 `$CLAUDE_PROJECT_DIR`**（Claude Code 注入），fallback 才從 `BASH_SOURCE` 推算。
3. **jq 可能缺失** — `command -v jq || exit 0` 軟降級，不阻擋。
4. **效能** — hook 在主迴圈內同步執行；減少 process spawn（例如一次 jq 解析多欄位，而非逐欄呼叫）。
5. **避免在高頻事件做重活** — `Read`、`Edit` 觸發極頻繁；一次性工作（如 log 輪替）放 `SessionStart`。
6. **CWD 不污染** — 需要切目錄時用 subshell `(cd ... && ...)`（見 `.claude/hooks/pre-tool-use.sh`）。
7. **`PostToolUse` 不等於「那件事做完了」** — 只代表工具呼叫返回了。非同步工具
   （`Agent` 是其一，tool response 帶 `"isAsync": true` / `"status": "async_launched"`）
   呼叫後立刻返回，實際工作還在跑。**要判斷真正結束，用對應的專屬事件**
   （subagent → `SubagentStop`）。這條踩過一次且完全無聲：`pre-agent-gate.sh`
   曾靠 `PostToolUse` 當完成訊號，in-flight 永遠是 0，閘門從裝上去那天就沒攔過任何一次。
   細節見 `.claude/context/learned/2026-09-11-async-dispatch-breaks-posttooluse-gates.md`。
8. **`PostToolUse` 只在成功時觸發** — 失敗走 `PostToolUseFailure`（官方定義）。
   「事後記錄型」的 hook 先問：**失敗的那一次要不要記？** 要的話兩個事件都接，
   並用 `hook_event_name` 分辨（兩者 payload 形狀不同，回應的 `hookEventName` 也要對上）。
   `post-bash.sh` 只接了 `PostToolUse`，有衝突的合併從沒被記過、失敗計數從沒累加過，
   而測試直接餵 payload 繞過了「Claude Code 何時呼叫 hook」這一層，所以抓不到。
   細節見 `.claude/context/learned/2026-10-15-posttooluse-skips-failures.md`。

---

**設計原則**：所有 hook 皆為非侵入式——即使 hook 失敗，Claude Code 正常功能不受影響。
