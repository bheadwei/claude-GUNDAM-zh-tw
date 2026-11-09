# Hooks 回歸測試

```bash
bash .claude/hooks/tests/run-tests.sh                    # 整套
bash .claude/hooks/tests/run-tests.sh --changed <起點>   # 依改動挑節；判成整套時 worktree 裡要加 --full
bash .claude/hooks/tests/run-tests.sh overview post-write   # 只跑標題含關鍵字的節
bash .claude/hooks/tests/run-tests.sh --list             # 列出所有節；任何形式加 --dry-run 只印會跑哪些節
```

1268 個案例，全數通過才算綠燈（失敗時 exit 1，可直接掛 CI）。只跑部分節時結尾寫
「部分執行（N 節／共 M 節，不是整套）… 通過數 X」——刻意不用「通過 X」，CI 與 `check-counts.sh --tests`
的 regex 抓不到。改動檔對應到哪些節的規則只寫在 `run-tests.sh` 的 `_changed_rule`（唯一來源）；
什麼時候跑整套見 `commands/verify.md` 步驟 4。在 worktree 裡不帶參數跑整套會被 `full-suite-gate` 擋一次。

**整套在 Windows Git Bash 上約需 50 分鐘**（2026-11-04 實測 869 案例 51 分鐘；2026-09-17 的
356 案例是 12 分鐘，案例增加時這個數字會繼續往上）——大量 `bash` + `jq` 子行程，
process spawn 是主要成本。**看起來像掛住其實只是慢**：用背景執行並把輸出重導到檔案，
不要 `| tail`（管線會把輸出憋到最後，中途看不到進度，也就看不出它到底跑到哪）。

## 為什麼這套測試存在

`pre-tool-use.sh` 是模板裡唯一的硬閘門。它壞掉有兩種方式，**兩種都很難用肉眼發現**：

| 失效模式 | 症狀 | 後果 |
|---|---|---|
| 誤擋 | 所有程式碼寫入被 deny | 很吵，會馬上發現 |
| **靜默失效** | 該擋沒擋，一切看起來正常 | **不會發現** |

第二種正是這個模板的歷史教訓：`.current-task-mode` 該清沒清，導致入口自動分級
永久不觸發，壞了很久都沒人察覺。測試就是為了讓靜默失效變成紅燈。

## 涵蓋範圍

| 區塊 | 案例數 | 重點 |
|---|---|---|
| 任務模式閘門（無模式檔） | 11 | 程式碼檔擋、文件/設定/`.claude`/`docs`/依賴放行、deny 訊息含判級指引 |
| 有模式檔 | 7 | 有效放行、空檔視同無、TTL 未過期不清除、**過期必須清除（解互鎖）**、TTL 可調 |
| 逃生門 | 3 | `.suggest-mode=off`、`TASKMODE_GATE=off`、`low` 仍會攔 |
| 裸 `cd` 偵測 | 6 | 裸 cd 擋；`&&`、`;`、subshell、非 cd 指令放行 |
| handoff 注入 | 9 | pending 注入含 from/to/優先級/起因；completed 不注入；suggest-mode 分級過濾；範本檔不誤判 |
| 意圖路由 | 8 | auth→critical、UI/npm/測試→提示載入對應 skill、斜線指令不路由 |
| git backup 閘門 | 27 | 四種 destructive 指令都擋、`--force-with-lease` 不例外、tag 指向 HEAD 才放行、`--continue/--abort/--skip` 放行、**只是提到指令不擋**、兩個逃生門、非 repo/空 repo 放行、註解含單引號／`$((1<<x))` 之後的指令仍擋 |
| **cmd-segments 切段邊界** | 25 | 直接驗 `cmd_segments` 輸出（四支閘門共用）：引號外的 `#` 註解先拿掉（`$#`、`${#a}`、URL 錨點不算）、`$((1<<x))`／`((…))` 不是 heredoc、`<<<` 不受影響、`--git-dir`／`--work-tree`／`--namespace` 等帶值全域選項、裸 `--exec-path` 沒有子指令、`<<WORD` 結束行一字不差（只有 `<<-` 允許行首 tab）；post-bash 合併紀錄的對應回歸 |
| **分支切換閘門** | 34 | 站在預設分支放行（即使有 agent 在跑）、站在 topic 分支擋一次、有 in-flight agent 時**持續擋**、標記記分支名（換分支重新受檢）、回預設分支清標記、帶 start-point 放行但有 agent 時仍擋、`git checkout <既有分支>`／`git switch <既有分支>`／`git checkout -- <file>` 不誤擋、detached HEAD 與非 repo 放行、兩個逃生門、**與 `pre-agent-gate` 共用同一份 in-flight 計數** |
| 平行 agent 閘門 | 14 | 有 in-flight 就擋、deny-once、`isolation: worktree\|remote` 放行、in-flight 歸零後下一批重新受檢、舊格式紀錄（無 `agent_id`）忽略、兩個逃生門、**攔截訊息的推薦**（不乾淨／沒有帶 `files:` 的 plan → 序列化；乾淨 → worktree） |
| **非同步派工的完成時機** | 13 | 走真的 `agent-monitor.sh`（不造假 JSONL）：`PreToolUse` 不記帳、派工返回只記 `agent_start`、**只有 `SubagentStop` 才沖銷 in-flight**、`agent_type` 空字串仍沖銷、沒見過的 `agent_id` 不轉負、同步完成的 agent 淨變化 0 |
| **post-bash 失敗事件** | 21 | **`settings.json` 把 `post-bash.sh` 接在 `PostToolUse` 與 `PostToolUseFailure` 兩處**（真正的 bug 在接線）；payload 一律照官方 `PostToolUseFailure` 形狀（無 `tool_response`、頂層 `error`）：衝突的 merge／cherry-pick 記錄並導向 `conflict-resolver`、合併成功但後段指令失敗仍記錄、失敗的 grep／merge-base 不誤記、`--abort` 失敗不清單、用**真的衝突中 repo** 驗 `ls-files -u` 判定、失敗事件累加踩坑計數 |
| 全體 hooks | 12 | 語法可解析、空 payload 不爆炸 |

> 上面兩區分工刻意不同：「平行 agent 閘門」測**閘門怎麼讀帳**，
> 「非同步派工的完成時機」測**帳記得對不對**。2026-09-11 那個 bug 在後者——
> 閘門邏輯一直是對的，是 `agent_complete` 記在 `PostToolUse` 而 Agent 工具是非同步的，
> 導致 in-flight 恆為 0。造假 JSONL 的測試永遠抓不到這種錯。
>
> 「post-bash 失敗事件」是同一類教訓的第二次：舊測試餵 `tool_response.is_error`
> 給腳本——那是 Claude Code 從不送出的形狀，而且失敗時它根本不呼叫只接在
> `PostToolUse` 的 hook。**payload 測試證明不了接線**，所以那一區開頭兩條直接驗 `settings.json`。

> 這張表**不是全部**（缺合併閘門、resolve-roots 等區塊），
> 各列的數字也只對得上自己那一區。要看完整清單請直接讀 `run-tests.sh` 的 `section` 標題。

## 隔離保證

所有測試在 `mktemp -d` 沙箱內執行，`CLAUDE_PROJECT_DIR` 指向沙箱。
**絕不觸碰真實的 `.claude/taskmaster-data/` 或 `coordination/handoffs/`**，
跑測試不會清掉你當前的任務模式或交接檔。結束時 `trap` 自動清理沙箱。

## 改了 hook 之後

1. 跑一次 `run-tests.sh`，確認全綠
2. **加測試**——新分支要有對應案例，否則下一個人改它時沒有保護

## 驗證測試本身有效（突變測試）

一套在壞掉的程式上也會過的測試沒有價值。改動測試框架後，用突變確認它還抓得到：

```bash
cp .claude/hooks/pre-tool-use.sh /tmp/bak

# 突變 1：拿掉 TTL 清除 → 應有 2 個案例失敗
sed -i 's|rm -f "$MODE_FILE" 2>/dev/null|:|' .claude/hooks/pre-tool-use.sh
bash .claude/hooks/tests/run-tests.sh   # 期望 exit 1

# 突變 2：閘門永遠放行 → 應有多個案例失敗
cp /tmp/bak .claude/hooks/pre-tool-use.sh
sed -i '/模式已存在 → 放行/{n;s|.*|exit 0|}' .claude/hooks/pre-tool-use.sh
bash .claude/hooks/tests/run-tests.sh   # 期望 exit 1

git checkout -- .claude/hooks/pre-tool-use.sh   # 還原（比 cp 可靠）
```

> 還原務必用 `git checkout --`，不要只依賴 `cp` 備份——
> 若中途逾時或中斷，備份還原那一步可能根本沒執行到。

## 專案圖解的測試資料與畫面檢查

`fixtures/overview/` 只放產生器與檢查腳本，不放實體的 `.py`／`.ts`（會被新專案的 pytest、tsc、依賴掃描撿到）。
用法與各組資料的內容寫在各檔開頭（唯一來源），這裡只列入口：

```bash
F=.claude/hooks/tests/fixtures/overview
bash $F/make-fixture.sh shop-clean      <目錄>   # 範例電商：5.1／5.5 有效、WBS 每個任務都標模組
bash $F/make-fixture.sh messy-fullstack <目錄>   # 髒資料：Python 後端＋TS 前端、沒有 5.5、WBS 沒有模組欄
bash $F/make-fixture.sh maven-multi     <目錄>   # Maven／Gradle 多模組
bash $F/gen-large.sh 5000 <目錄>                 # 效能實測用：N 個帶 import 的檔
```

產生器只寫檔，不 `git init`、不 commit。「本次改動」「說明層」「> 60 檔的模組」要先 commit 基礎檔，
再帶 `MAKE_FIXTURE_CHANGES=1`／`MAKE_FIXTURE_NOTES=1`／`MAKE_FIXTURE_LARGE=1` 補（見 `make-fixture.sh` 開頭）。
產好後跑 `bash .claude/scripts/overview.sh <目錄>`，畫面在 `<目錄>/.claude/taskmaster-data/overview/index.html`。

**`qa-check.js`** 量畫面有沒有疊卡、溢出、殘留 `<br>`、橫向捲動等七項，回傳的物件全部為 0／false 才算過。
它整份就是一個函式，原樣當 Playwright MCP `browser_evaluate` 的 `function` 參數：

1. `browser_navigate` 到 `file:///<目錄>/.claude/taskmaster-data/overview/index.html`
2. `browser_resize` 成 390 或 1440 寬；`browser_emulate_media` 切 `colorScheme` 淺／深
3. 按「全圖」（或展開模組後按「整個模組」），**等縮放動畫跑完（約 1 秒）**再 `browser_evaluate` 貼上 `qa-check.js` 全文——
   放大後本來就會有東西在畫面外，`offStage` 只在全貌時有意義；動畫中途量會多出幾個 `offStage`（實測過 3）
4. 全圖量模組卡片；點模組 →「展開內部」後量的是內部圖，同一支腳本不用帶參數

兩組 fixture（shop-clean、messy-fullstack）× 390／1440 × 淺／深，全圖與一個模組的內部圖都要量。

## 加新案例

`run-tests.sh` 內建的斷言：

```bash
expect_decision "案例名稱" deny  "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"
expect_contains "案例名稱" "子字串" "$(run user-prompt-submit.sh "$(p '使用者輸入')")"
expect_empty    "案例名稱" "$(run post-agent-report.sh '{}')"
```

payload 產生器：`w <路徑>`（Write）、`e <路徑>`（Edit）、`b <指令>`（Bash）、`p <文字>`（prompt）。
每個區塊開頭記得 `reset` 清乾淨沙箱狀態。
