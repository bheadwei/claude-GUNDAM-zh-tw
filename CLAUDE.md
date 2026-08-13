# CLAUDE.md — 模板本身的開發須知

> **這個 repo 是模板本身，不是用模板開發的專案。**
> 在這裡「開發」＝改 `.claude/` 底下的規則、指令、agent 定義、hook——幾乎都是 `.md` 和 `.sh`。
>
> 本檔已列入 `scripts/copy-template.*` 的排除清單，**不會被複製到新專案**。
> 新專案的 CLAUDE.md 由 `/task-init` 依 `.claude/templates/CLAUDE-md.template.md` 產生。

## 目錄地雷

| 路徑 | 注意 |
|---|---|
| `.claude/custom-rule&skill/` | **備份池，不參與執行。** 94 個 skill + 多份 rule 放在這裡供取材，執行路徑只有 `.claude/skills/`（12 個）與 `.claude/rules/`（6 個）。改錯地方等於沒改 |
| `workshop/VibeCoding_Workshop.pptx` | **由使用者手動編輯。** 不要跑 `generate_pptx.py` 重生，會洗掉手改內容 |
| `.claude/context/`、`.claude/coordination/` | 執行時產物，已排除複製。修改 agent 的報告/交接格式時記得對應更新 `_REPORT_TEMPLATE.md` 與 `_HANDOFF_TEMPLATE.md` |

## 改動時的連帶檢查

- **改 `.claude/` 的目錄結構** → 同步 `scripts/copy-template.sh` 的 `EXCLUDES` **和** `scripts/copy-template.ps1` 的 `$excludeDirs` / `$excludeFiles`（兩份要一致，容易漏改 ps1）
- **新增 skill** → 更新 `.claude/skills/INDEX.md`，否則沒人知道它存在
- **改 hook** → `.claude/hooks/tests/run-tests.sh` 有測試
- **改 agent 的報告或 handoff 行為** → `post-agent-report.sh` 的 `AREA` 對應表要同步

## 已知落差

- **agent 報告機制命中率低**：`post-agent-report.sh` 的稽核在 PostToolUse 當下檢查，但 Agent tool 常是非同步啟動（log 裡的 `"status":"async_launched"`），檢查時 agent 還沒動工 → 真有寫報告也被記成 WARN。且稽核只寫 log 不注入，等於沒有牙齒。對照組：同檔案的 handoff 那半用 `additionalContext` 注入，完成率 100%
- **新專案缺 `_REPORT_TEMPLATE.md`**：`.claude/context/` 整個被排除複製，但多個 agent 的「結束後」都寫「格式遵循 `.claude/context/_REPORT_TEMPLATE.md`」——新專案裡那個檔不存在
