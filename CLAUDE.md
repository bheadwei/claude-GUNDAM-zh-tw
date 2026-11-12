
# CLAUDE.md — 模板本身的開發須知

> **這個 repo 是模板本身，不是用模板開發的專案。**
> 在這裡「開發」＝改 `.claude/` 底下的規則、指令、agent 定義、hook——幾乎都是 `.md` 和 `.sh`。
>
> 本檔已列入 `scripts/copy-template.*` 的排除清單，**不會被複製到新專案**。
> 新專案的 CLAUDE.md 由 `/task-init` 依 `.claude/templates/CLAUDE-md.template.md` 產生。

## 目錄地雷

| 路徑 | 注意 |
|---|---|
| `workshop/VibeCoding_Workshop.pptx` | **由使用者手動編輯。** 不要跑 `generate_pptx.py` 重生，會洗掉手改內容 |
| `.claude/context/`、`.claude/coordination/` | 執行時產物，已排除複製。改 agent 的報告/交接格式時同步 `_REPORT_TEMPLATE.md` 與 `_HANDOFF_TEMPLATE.md` |
| `.claude/taskmaster-data/overview/` | 專案圖解的產物，不進 git、hook 會在背景重產。**要改畫面就改 `.claude/templates/overview/index.html`** |
| 本 repo 的 ADR | 模板 repo 沒有 `docs/`，自己的 ADR **仍放 `.claude/context/decisions/`**（ADR-2026-11-05-004 的例外）。在這個 repo 用 `/adr`、`architect` 時改寫到這裡 |

## 改動時的連帶檢查

- **加或改 `.claude/` 底下任何東西** → 先讀 `writing-extensions` skill（五層決策表）。踩過四次「該用 hook 卻寫成文字規則」
- **改了注入內容**（`using-taskmaster`、關鍵字路由、rules）→ 跑 `.claude/tests/skill-compliance/run-compliance.sh`。hook 測試證明不了模型會不會照做
- **改 `using-taskmaster`** → 它每個 session 全文注入，加東西前先想值不值得佔常駐 context
- **新增 agent／skill／command／rule** → `bash .claude/scripts/check-counts.sh`（CI 也跑）；新增 skill 另更新 `.claude/skills/INDEX.md`
- **改 `.claude/` 目錄結構** → 同步 `copy-template.sh` 的 `EXCLUDES` **和** `copy-template.ps1` 的 `$excludeDirs`／`$excludeFiles`（容易漏 ps1）
- **新增 `context/` 的 area 子目錄** → 同步 `copy-template.sh` 的 `for d in ...` **和** `copy-template.ps1` 的 `$contextAreas`；`update-template.{sh,ps1}` 只補 `README.md`／`_*.md`／`.gitkeep`
- **新增 `.claude/ui/` 風格** → 用 `scripts/sync-ui-sources.sh --import <來源>:<id>`，再補 `CATALOG.md` 兩處（分類索引＋清單）；自己抽的照 `_sources.json` 的 `self-extracted` 欄位手寫 `SOURCE.json`；新上游同步 `_sources.json` 與 `_licenses/`。AI 痕跡判準見 `ui-style-compliance/anti-ai.md`
- **改 hook** → `bash .claude/hooks/tests/run-tests.sh --changed <起點>`（放背景），新分支要補案例；整套何時跑見 `commands/verify.md` 步驟 4。動 hook 前先看 `.claude/context/decisions/KNOWN-GAPS.md` 的四個暫不修問題
- **新增 hook 事件接線** → 同步 `.claude/settings.json` **和** `.claude/hooks/README.md`（`check-counts.sh` 不會提醒）
- **寫「那件事做完了沒」的閘門** → `PostToolUse` 只代表工具返回；`Agent` 是非同步的，結束事件是 `SubagentStop`（見 `context/learned/2026-09-11-async-dispatch-breaks-posttooluse-gates.md`）
- **改 agent 的報告落點或 handoff 行為** → 同步 `post-agent-report.sh` 的 `AREA` 對應表，否則稽核找不到報告
- **改 hook 讀寫的狀態檔** → 照 `worktree-orchestration` skill 的邊界表選 `WORK_CLAUDE`（短命旗標）或 `MAIN_CLAUDE`（共享產物），用錯平行開發會靜默壞掉
- **改閘門的路徑排除規則** → 先相對化到 `WORK_ROOT` 再比對、樣式錨定開頭，否則會被 `.claude/worktrees/` 誤命中
- **合併衝突檔含 `.claude/hooks/**`** → 不要等「委派 conflict-resolver」的提示（hook 語法壞了提示不會出現），自己看 `git status`

## 已知落差

未修的在 `.claude/context/decisions/KNOWN-GAPS.md`，已修的在同目錄 `FIXED-LOG.md`。
懷疑某個行為是已知問題、或要動相關機制（hook、發佈流程、壓力測試）之前去 grep。
