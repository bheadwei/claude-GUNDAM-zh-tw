# Q&A 問答歷史紀錄

此目錄保存所有互動式問答流程的完整紀錄。

## 目的

- **可追溯**：回顧過去的決策脈絡與選擇理由
- **跨 session 持久化**：問答紀錄不會因 session 結束而遺失
- **模板複製**：可從過去問答檔案複製到新專案作為起點

## 檔案命名規則

```
YYYY-MM-DD-HHMMSS-<command-name>.md
```

範例：
- `2026-04-09-143055-task-init.md`
- `2026-04-09-150812-hub-delegate.md`
- `2026-04-10-091234-check-quality.md`

## 誰寫入這裡？

所有遵守 `.claude/rules/interactive-qa.md` 的指令都會自動在此記錄問答。
目前涵蓋：

- `/task-init`
- `/task-next`
- `/hub-delegate`
- `/check-quality`

## 檔案格式

參見 `.claude/rules/interactive-qa.md` 的「記錄檔格式」章節。

## 注意事項

- **批次寫入**：流程結束後一次性用 `Write` 寫完整檔案，不要每題都 Edit（省 token）
- 不要在此目錄放非 Q&A 檔案
- 此目錄不應被 `.gitignore` 忽略（決策歷史應納入版控）
