# .claude 配置目錄

> 版本與變更記錄見根目錄 `README.md`。

## 目錄結構

```
.claude/
├── settings.json              # 專案設定（權限、StatusLine、Model）
├── settings.local.json        # 個人設定（MCP 啟用）-- 不入 Git
├── statusline.sh              # StatusLine bash 腳本
│
├── guides/                    # 參考文件（不自動載入）
│   ├── WORKFLOW.md            # 開發流程指南
│   ├── MECHANISMS.md          # 五套擴充機制權威對照
│   ├── MODELS.md              # 模型選擇策略
│   ├── MCP_CONFIGS.md         # MCP Server 推薦清單
│   ├── PAUSE_RESUME_GUIDE.md  # 暫停/恢復 SOP
│   └── STATUSLINE_GUIDE.md    # StatusLine 客製化手冊
├── agents/       (15 個)      # 專業 Agent 定義
├── commands/     (29 個)      # Slash Command
├── rules/        ( 6 個)      # 自動載入規則
├── skills/       (28 個)      # 專案特定領域知識
├── hooks/                     # Hook 腳本＋lib/（閘門）＋tests/（回歸測試）
├── scripts/                   # context-gc.sh、check-counts.sh、overview.sh（產生專案圖解）
├── templates/                 # CLAUDE.md／WBS 版面範本、overview/index.html（專案圖解畫面原檔）
├── ui/                        # 設計系統 DESIGN.md + CATALOG.md（/ui-style 選用）
├── tests/skill-compliance/    # 壓力測試：模型會不會照 skill 做
├── output-styles/             # 回覆風格（預設 plain-language；另有 terse／decision／teaching／report，用 /output-style 切換）
├── context/                   # 跨 Agent 上下文共享
├── coordination/              # Agent 協調配置
└── taskmaster-data/           # WBS、時間日誌、plans/（計畫持久化）
    ├── wbs.md                 # WBS 任務清單（What；版面見 templates/wbs.template.md）
    ├── overview/              # 專案圖解：overview.md＋index.html＋data.js（scripts/overview.sh 產生、不進版控；畫面原檔在 templates/overview/）
    ├── plans/                 # 計畫檔（How，/plan 寫入）
    │   ├── INDEX.md
    │   └── archive/           # /verify 完成後歸檔
    └── .current-task          # 當前進行中任務 ID
```

## Agents（15 個）

| Agent | Model | 用途 |
| :--- | :--- | :--- |
| planner | opus | 功能規劃 |
| architect | opus | 架構設計 |
| security-infrastructure-auditor | opus | 安全稽核 |
| debug-investigator | opus | 執行期 bug 根因調查 |
| build-error-resolver | opus | 建置/型別錯誤修復 |
| deployment-expert | opus | 部署運維 |
| test-automation-engineer | opus | 實作後補測試缺口（有具體缺口才派） |
| ui-builder | opus | 前端 UI 產出（嚴格遵循 DESIGN.md） |
| conflict-resolver | opus | 合併衝突處理 |
| skill-curator | opus | `.claude/` 擴充維護 |
| code-quality-specialist | sonnet | 程式碼審查 |
| e2e-validation-specialist | sonnet | E2E 測試 |
| refactor-cleaner | sonnet | 死碼清理 |
| documentation-specialist | sonnet | 文檔生成 |
| workflow-template-manager | sonnet | 模板管理 |

實作（含 TDD）沒有專屬 agent：`/tdd` 由主模型照 `tdd-workflow` skill 做，
多階段計畫逐階段派 `general-purpose` implementer（`subagent-execution` skill）。

模型分派原則見 `guides/MODELS.md`（含派工時覆寫的時機）。

## Skills（28 個，按需載入）

僅保留模型不知道的專案特定知識。完整清單、觸發時機與接到哪些 agent 見
`skills/INDEX.md`（唯一來源）。唯一常駐的是 `using-taskmaster`——每個 session 由
`session-start.sh` 全文注入。


## Rules（6 個，自動載入）

每次對話自動注入 context，無需手動觸發。**只保留「任何任務都適用、而且與模型預設
行為不同」的規則**——領域專屬知識改由 skill 按需載入，可強制的約束交給 hook。

| 規則 | 內容 |
| :--- | :--- |
| coding-style | 克制原則、註解預設不寫、不可變性、依職責拆檔、錯誤處理、CWD、Context 管理 |
| task-mode | quick/standard/critical 三檔分級（由 `pre-tool-use.sh` 強制判級） |
| git-workflow | 先開分支、多 session ref 驗證、destructive 前打 backup tag（由 `lib/git-backup-gate.sh` 強制） |
| agent-orchestration | 鏈怎麼推進、handoff 接力、安全平行（路由表在 `using-taskmaster` skill） |
| security | commit 前安全檢查 |
| interactive-qa | AskUserQuestion 一次一題 |

### 從 rules 移出的去向

| 原 rule | 現在在哪 |
| :--- | :--- |
| bash-cwd | `pre-tool-use.sh` 硬擋裸 `cd` + coding-style 一句話 |
| testing | `testing-standards` skill |
| plan-persistence | `plan-format` skill |
| ui-design + pencil-design-location | `ui-style-compliance` skill |
| package-manager | `node-package-manager` skill |
| development-workflow | `python-uv` skill + `node-package-manager` skill + task-mode |
| patterns | 併入 coding-style |
| performance | `guides/MODELS.md` + 併入 coding-style |

## Hooks

每支 hook 接在哪個事件、做什麼，見 `hooks/README.md`（唯一來源，含檔案結構樹與功能表）；
實際接線以 `settings.json` 為準。最常碰到的幾件：

- `pre-tool-use.sh`：任務模式閘門（未判級不得寫程式碼）、裸 `cd` 攔截，以及 `lib/` 底下的 git／合併／平行測試閘門
- `post-write.sh`：寫 wbs／plan／架構文件後在背景重產專案圖解（`scripts/overview.sh`）、記錄文件債
- `session-start.sh`：全文注入 `using-taskmaster`、補產專案圖解

改了 hook 之後：`bash hooks/tests/run-tests.sh --changed <起點>` 只跑改到的節；
整套與何時跑見 `hooks/tests/README.md` 與 `commands/verify.md` 步驟 4。

## Context 系統（跨 Agent 共享）

11 個 agent 完成時寫報告到 `.claude/context/<area>/`（對應表在 `hooks/post-agent-report.sh` 的 `AREA`），
需要後續處理的透過 handoffs 交接工作（誰會建 handoff 見 `rules/agent-orchestration.md`）。

```bash
# 查看最新報告
ls -t .claude/context/quality/*.md | head -5

# 查看待處理交接
grep -l "status: pending" .claude/coordination/handoffs/*.md

# 清理舊報告（每個 agent 留最新 5 份；decisions/、learned/ 不動）
bash .claude/scripts/context-gc.sh --dry-run
```

詳見 `guides/MECHANISMS.md`。

## 自訂指南

### 新增 Agent
在 `agents/` 新增 `.md`，含 frontmatter（name、description、tools、model）。

### 新增 Command
在 `commands/` 新增 `.md`，含 frontmatter（description）。

### 新增 Rule
在 `rules/` 新增 `.md`（自動載入，無需 frontmatter）。

### 新增 Skill

委派 `skill-curator`（`subagent_type: "skill-curator"`）——它依
`writing-extensions` 的五層決策表先確認該不該是 skill，然後寫觸發式
`description`、接線到相關 agent、同步 `INDEX.md`、跑 `check-counts.sh`。
