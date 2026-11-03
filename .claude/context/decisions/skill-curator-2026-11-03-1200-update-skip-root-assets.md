---
agent: skill-curator
date: 2026-11-03-1200
area: decisions
target: scripts/{copy,update}-template.{sh,ps1}、.claude/scripts/check-counts.sh
severity: info
status: resolved
---

# update-template 不再同步根目錄 scripts/ 與 .mcp.json.*.example；check-counts 搬進 .claude/scripts/

## TL;DR
- `check-counts.sh` 用 `git mv` 搬到 `.claude/scripts/`（ROOT 改往上兩層），隨 `.claude/scripts` 同步。
- update-template（sh/ps1）不再同步根目錄 `scripts/` 和 mcp 範例，也不刪目標端已有的；結尾提示可以手動刪。
- copy-template（sh/ps1）排除根目錄 `scripts/`（錨定根目錄，`.claude/scripts/` 不受影響），**mcp 範例保留**。

## 決定與理由
- **copy-template 保留 mcp 範例**：新專案的 `.mcp.json` 被排除了，所以範例是唯一的起點。
  `copy-template.{sh,ps1}` 的完成訊息和 `README.md`「開新專案」步驟 1 都要使用者 `cp .mcp.json.*.example .mcp.json`。
  `/task-init` 沒有引用它們。
- **排除規則必須錨定根目錄**：rsync 的 `scripts/` 和 robocopy 的 `/XD scripts` 都會比對任何層級，
  會把 `.claude/scripts/` 一起排掉。sh 改用 `"/scripts/"`，cp 退路新增「開頭是 `/` 就只刪 `$DEST$p`」的分支；
  ps1 改成 `/XD <來源完整路徑>\scripts`。
- **刪掉 `SYNC_ROOT_DIRS`、`$syncRootDirs` 和 `ROOT_SCRIPTS_EXCLUDE` 全套邏輯**，而不是只把它們改成空陣列。
  理由是 `set -u` 搭配空陣列展開在 bash 3.2（macOS）會報錯，而且留著也只是死碼。
- **行為改變**：以前 update 會刪掉目標端 `scripts/sync-ui-sources*`，現在不刪了（依照「不刪目標端 scripts/」的要求）。
  只有很舊、而且在加入排除規則之後一次都沒跑過 update 的專案會受影響。

## 已知未處理
- `.skill-impact` 裡面累積的是之前任務的 hook 變更，本次沒有審，所以**沒有清除**。
- `README.md:326`（v5.5 changelog）裡的 `scripts/check-counts.sh` 是歷史紀錄，沒有改。
- `CLAUDE_TEMPLATE.md` 每次 update 都會被同步回去（使用者要求維持現狀）。它是「init 後自動刪除」的哨兵檔，
  所以已經 init 過的專案每次 update 後都會再出現一次。這是既有行為，沒有改，等使用者確認。
