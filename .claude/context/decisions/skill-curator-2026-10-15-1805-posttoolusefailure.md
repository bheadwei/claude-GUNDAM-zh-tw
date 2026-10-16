# skill-curator — post-bash.sh 接上 PostToolUseFailure（2026-10-15 18:05）

分支 `fix/merge-gate-on-tool-failure`，未 commit。

## 決策

| 項目 | 裁決 | 理由 |
|---|---|---|
| `settings.json` 加 `PostToolUseFailure(Bash)` → `post-bash.sh` | 已做 | 官方：PostToolUse 只在成功時觸發。衝突的 merge 非零結束 → 從沒被記過 → 下一次合併跳過驗證 |
| 失敗事件裡的合併 | 一律記 | 「非零」不等於「衝突」。衝突判定看 `git ls-files -u`（不受 `>/dev/null` 影響，成功事件也查），後備看 `error` 裡的衝突字樣。非零但沒衝突的也記，另給一則提示（多記一筆的代價是多跑一次 /verify，漏記的代價是跳過驗證） |
| `--abort` 失敗 | 不清單 | 它失敗最常見的原因是「沒有進行中的合併」，也就是清單裡那筆是早已完成、真的待驗證的合併 |
| 踩坑偵測（`.bash-fail-streak`） | 失敗事件照常累加 | 這段本來就寫對了，只是從沒收到失敗事件。hooks.log 自 2026-09-08 起 0 筆 `learn-candidate`。**修好後它會開始觸發**，這是行為變更 |
| 回應的 `hookEventName` | 跟著事件走 | 失敗事件回 `PostToolUse` 的話注入可能被丟掉 |

## 驗證

- `run-tests.sh`：394／0（375 − 2 個舊形狀案例 + 21 個新案例；其中 2 條直接驗 settings.json 接線）
- `check-counts.sh --tests 394`：316 項中 1 項不一致，是根目錄 `README.md` 的 375，由主模型改
- 現場實測：在本 session 跑一個失敗的 `ls`，真實的 `.bash-fail-streak` 變成 1。證實 PostToolUseFailure 會觸發、設定是熱載入、subagent 的工具呼叫也吃得到
- 未實測：真實的衝突 merge 走完整條路徑（只用沙箱中的真 git repo 跑過 ls-files 判定）

## 掃過的其他 PostToolUse hook（未改）

- `post-write.sh`（Write|Edit）：失敗的寫入沒有改檔，略過是對的；Edit 的「找不到 old_string」屬驗證失敗，兩個事件都不會觸發
- `agent-monitor.sh`（Agent）：Agent 呼叫失敗時不寫 `agent_start`，in-flight 不會多算，方向安全；只是人類可讀 log 只有 START、沒有失敗紀錄（只影響外觀）
- `post-agent-report.sh`（Agent）：Agent 呼叫失敗時不記報告期望、這一輪也不注入 pending handoff。若 agent 建了 handoff 之後呼叫才失敗，要等下一次 Agent 成功才會注入。風險低，未改

## 順帶發現（未處理）

- `commands/verify.md` 的合併驗證關卡在「`.current-task` 存在」那一節底下，沒有進行中任務時 `/verify` 不會清 `.merge-pending`（今天 15:47 那次就是手動清的）
- `hooks/README.md` 的 `post-write.sh` 那一列有一段重複、斷掉的文字（「②**文件影響偵測**\|Edit` | ①WBS…」），應是之前合併留下的
- `writing-extensions` SKILL.md 寫「356 個 hook 測試」、CLAUDE.md 寫「375 個」，這兩處是敘述用的數字，check-counts 不檢查
