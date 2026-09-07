# CLAUDE.md — 模板本身的開發須知

> **這個 repo 是模板本身，不是用模板開發的專案。**
> 在這裡「開發」＝改 `.claude/` 底下的規則、指令、agent 定義、hook——幾乎都是 `.md` 和 `.sh`。
>
> 本檔已列入 `scripts/copy-template.*` 的排除清單，**不會被複製到新專案**。
> 新專案的 CLAUDE.md 由 `/task-init` 依 `.claude/templates/CLAUDE-md.template.md` 產生。

## 目錄地雷

| 路徑 | 注意 |
|---|---|
| `.claude/custom-rule&skill/` | **備份池，不參與執行。** 94 個 skill + 多份 rule 放在這裡供取材，執行路徑只有 `.claude/skills/`（14 個）與 `.claude/rules/`（6 個）。改錯地方等於沒改 |
| `workshop/VibeCoding_Workshop.pptx` | **由使用者手動編輯。** 不要跑 `generate_pptx.py` 重生，會洗掉手改內容 |
| `.claude/context/`、`.claude/coordination/` | 執行時產物，已排除複製。修改 agent 的報告/交接格式時記得對應更新 `_REPORT_TEMPLATE.md` 與 `_HANDOFF_TEMPLATE.md` |

## 改動時的連帶檢查

- **新增 agent／skill／command／rule** → 跑 `bash scripts/check-counts.sh`，它會列出所有該同步卻沒同步的計數（CI 也會跑）
- **改 `.claude/` 的目錄結構** → 同步 `scripts/copy-template.sh` 的 `EXCLUDES` **和** `scripts/copy-template.ps1` 的 `$excludeDirs` / `$excludeFiles`（兩份要一致，容易漏改 ps1）
- **新增 skill** → 更新 `.claude/skills/INDEX.md`，否則沒人知道它存在
- **改 hook** → `.claude/hooks/tests/run-tests.sh` 有測試
- **改 agent 的報告落點或 handoff 行為** → `post-agent-report.sh` 的 `AREA` 對應表要同步，**否則稽核永遠找不到報告**
- **新增 `context/` 的 area 子目錄** → 同步 `copy-template.sh` 的 `for d in ...` **和** `copy-template.ps1` 的 `$contextAreas`（四份腳本的骨架規則要一致：`copy-template.{sh,ps1}` 建目錄、`update-template.{sh,ps1}` 只補 `README.md`／`_*.md`／`.gitkeep`）
- **改 hook 讀寫的狀態檔** → 先想清楚它屬「短命旗標」還是「共享產物」，照 `worktree-orchestration` skill 的邊界表選 `WORK_CLAUDE` 或 `MAIN_CLAUDE`。用錯的話平行開發會靜默壞掉
- **改閘門的路徑排除規則** → 一律先相對化到 `WORK_ROOT` 再比對，樣式錨定開頭。用絕對路徑子字串比對會被 `.claude/worktrees/` 誤命中
- **改 `using-taskmaster` skill** → 它由 `session-start.sh` 全文注入，**每個 session 都會載入**；加東西前先想清楚值不值得佔常駐 context

## 已知落差

- **發佈仍是 pull 式**：`copy-template` / `update-template` 要手動跑。真正的自動更新要走 Claude Code plugin marketplace（改版號即更新），但 plugin **帶不了 `rules/`**，且指令會變 `/taskmaster:task-next`。`using-taskmaster` 已示範「rules 改寫成 SessionStart 注入的 skill」這條遷移路徑
- **沒有 constitution**：`rules/` 是模板通用規範，缺「這個專案不可違反的原則」那一層

### 已修（2026-09-07）

- ~~沒有 converge 收斂檢查~~ → `spec-convergence` skill：以 `docs/00_brief.md`＋PRD 為基準，三查（A 漏做／B 範圍蔓延／C 描述失真），輸出報告與提議的 WBS 行。**刻意不自動改 PRD**——「這個 CR 該進 PRD」還是「當初就不該做」是人的判斷。做成 skill 而非塞進 `/verify`，是為了能用自然語言喚起（「現在還符合原本規格嗎」）。三個觸發點：里程碑完成（完整）、`/verify pre-pr`（A+B）、`/task-add` 的 CR 累積提醒
- ~~需求釐清沒有回述確認~~ → `/task-init` 新增步驟 2.7：補問 non-goals 與最大風險（原本兩題都沒問）、產出 `docs/00_brief.md`、**逐段回述給使用者確認**。原因是文件從步驟 2 的答案產出、WBS 又從文件反推，**誤解會被放大兩次**。`/docs-init` 改為優先讀 brief，並對 brief 的「仍未釐清」段標 `TBD` 而非自己填答案

- ~~沒有 CI~~ → `.github/workflows/template-ci.yml`，六個 job：hook 回歸測試（**Ubuntu + Windows/Git Bash 都跑**，因為踩過平台專屬的雷）、shell 與 PowerShell 語法、**文件計數一致性**、copy/update-template 沙箱實跑。案例數由測試 job 的實跑輸出傳給計數 job，避免兩邊各寫一個數字
- ~~文件計數靠人工同步~~ → `scripts/check-counts.sh`：比對檔案系統實況 vs README／`.claude/README`／WORKFLOW／INDEX 四處寫的數字，另檢查「每個 skill 有 SKILL.md 且列入 INDEX」「每個 agent 的 model 是合法別名」。**寫完立刻抓到 3 處既有 drift**（`.claude/README.md` 的 skills 12、commands 28、Skills 14）

- ~~worktree 平行開發的狀態分裂~~ → **這是 bug 不是缺功能**。官方文件明講「hook 路徑不跟著 worktree 走：`${CLAUDE_PROJECT_DIR}` 留在 session 啟動處，`cwd` 才是 worktree 根」，而 7 支 hook 全部只用 `CLAUDE_PROJECT_DIR` → 三個平行 worktree 共用同一份 `.current-task-mode`，A 判 quick、B 判 critical 互相覆寫。新增 `hooks/lib/resolve-roots.sh` 統一解析（往上找 `.git`，因為 `cwd` 會隨 `cd` 移動成子目錄），短命旗標跟 worktree、共享產物留主 checkout
- ~~閘門在 worktree 裡全部失效~~ → worktree 住在 `.claude/worktrees/`，所以裡面每個檔案的絕對路徑都含 `/.claude/`，而閘門用 `*/.claude/*` 放行以免自鎖 → 整個 worktree 被放行。修法：排除判斷先相對化到當前 checkout root、樣式錨定開頭。**由新增的 worktree 測試案例抓出**
- ~~沒接 Claude Code 原生 worktree 支援~~ → 新增 `.worktreeinclude`（worktree 是乾淨 checkout，沒它就缺 `.env` 跑不動）、`settings.json` 的 `worktree` 設定、`refactor-cleaner` 加 `isolation: worktree`；`task-next.md` 的平行段改用 `claude -w` 並**刪掉那句錯的「每個任務各自寫 .current-task（互不干擾）」**
- ~~update-template 會覆寫專案的根目錄檔案~~ → 新增 **SEED** 分類：只在目標不存在時建立、永不覆寫。`.worktreeinclude` 走這條（專案會自己加規則，而 update-template 的備份只包 `.claude/`，根目錄檔案覆寫等於無備份的破壞）

- ~~新需求／CR 的程式寫出來但文件沒同步~~ → **根因是結構性的**：`documentation-specialist` 在任務完成路徑上原本沒有位置，`/verify` 只驗建置/型別/lint/測試，從不問文件。修法：`post-write.sh` 偵測「文件描述的對象」（`*/api/*`、`*openapi*`、`*/migrations/*`、`*/index.ts`…）→ 記進 `taskmaster-data/.doc-impact` 並提醒一次；`/verify` 在標 WBS ✅ 前**必須**處理該清單（委派 documentation-specialist／已自行更新／明確豁免）。逃生門 `DOC_SYNC_GATE=off`
- ~~`planner` 與 `architect` 沒有關鍵字入口~~ → 「新功能／CR」那條補上 `subagent_type: "planner"`，「技術選型」那條補上 `subagent_type: "architect"`。原本只提示 `/task-add` 與 `/adr`

### 已修（2026-09-04）

- ~~新專案缺 `_REPORT_TEMPLATE.md`~~ → `copy-template.{sh,ps1}` 後置處理改為複製 `context/` 與 `coordination/` 的骨架（`README.md` + `_*.md` + 各 area 目錄），實際報告仍不帶。兩份腳本產出已比對一致
- ~~自然語言輸入不會派 agent~~ → `session-start.sh` 改用 `hookSpecificOutput.additionalContext` 全文注入 `skills/using-taskmaster/SKILL.md`（含 Red Flags 反合理化表）。**根因**：slash command 在 Claude Code 裡算 skill，滿足內建的 *"unless a skill asks for it"* 所以 `/tdd` 能派 agent；自然語言沒有這張授權
- ~~`documentation-specialist` / `workflow-template-manager` 零入口~~ → `user-prompt-submit.sh` 補文件類關鍵字，且全表語氣從「建議委派」改為帶 `subagent_type` 的命令式
- ~~踩過的坑只靠自律~~ → `pre-tool-use.sh` 新增**坑閘門**：比對 `context/learned/*.md` 的 `files:` glob，命中則 deny-once 並貼出教訓（PreToolUse 不支援 `additionalContext`，只能用 deny）。`debug-investigator` 的「結束後（必須）」已改為強制寫 learned
- ~~agent 報告稽核無牙齒~~ → 非同步啟動改為只記期望到 `taskmaster-data/.report-expectations.jsonl`，由 `hooks/lib/check-report-expectations.sh` 在後續對話邊界重查並**經 `additionalContext` 注入**要求補寫。用 `-newermt` 比對啟動時間（`-mmin` 會把 agent 上一輪的舊報告誤認成這次產出）。同步完成的 agent 仍走當下稽核
- ~~agent 仍是「顧問」不是「工人」~~ → 新增 `subagent-execution` skill：逐階段派 implementer subagent + 帳本（`plans/<plan 同名>.progress.md`，第一行身分行）+ 階段審查（規格合規與程式品質分開審）+ 修復迴圈上限 5 輪（R≥4 換新 implementer 並升級模型）+ 「裁決而非停等」。由 `/tdd` 的「3.5 選執行方式」用 `AskUserQuestion` 帶入，**是選項不是強制**
- ~~`context/planning/` 目錄不存在~~ → `planner` 與 `tdd-guide` 都往那寫、`context/README.md:28` 也記載了它，但骨架從未建立。已加入兩份 copy-template 的 area 清單
- ~~`debug-investigator` 不在報告稽核映射裡~~ → 已補進 `post-agent-report.sh` 的 `AREA` 表（它寫 `context/quality/`）
