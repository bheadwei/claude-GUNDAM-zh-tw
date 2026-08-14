# Claude Code 全面開發配置

> **版本:** v5.3 | **更新:** 2026-08-14 | **平台:** Windows（需 Git Bash）/ Linux / macOS

人類主導的文檔導向智能協作開發平台。

---

## 快速開始

### 前置需求

| 平台 | 必要軟體 |
|---|---|
| Windows | **Git Bash**（Git for Windows 附帶）+ `jq`（`winget install jqlang.jq`） |
| Linux / macOS | `bash`（系統內建）+ `jq`（`apt/brew install jq`） |

> `.claude/hooks/*.sh` 與 `statusline.sh` 皆為 bash 腳本。Windows 原生 PowerShell 無法執行，**必須裝 Git Bash**。

### 開新專案

```bash
# Git Bash / Linux / macOS / WSL
bash scripts/copy-template.sh /path/to/new-project

# Windows PowerShell（只用於複製，hooks 仍需 Git Bash 執行）
powershell -ExecutionPolicy Bypass -File scripts\copy-template.ps1 D:\projects\my-app
```

複製腳本會自動排除 `settings.local.json`、`taskmaster-data/`、`logs/`、`sessions/`、
`context/`、`coordination/`、`workshop/` 與本 repo 的 `CLAUDE.md`——手動 `cp -r` 會把這些
專案專屬資料一起帶走，造成新專案被舊資料污染。

```bash
cd /path/to/new-project

# 1. 複製對應平台的 MCP 範本並填入 API keys
cp .mcp.json.windows.example .mcp.json  # Windows
cp .mcp.json.linux.example .mcp.json    # Linux / macOS

# 2. 啟動 Claude Code
claude

# 3. 初始化（先選開發情境 demo / mvp / full → 產文件 → 生 WBS）
/task-init

# 4. 開發循環
/task-next → /plan → /tdd → /verify
```

### 更新既有專案

模板改版後，用 `update-template` 把最新資產同步過去——**只更新模板擁有的檔案，
完全不碰該專案的 WBS、plan、時間紀錄、session 與問答歷史**。

```bash
bash scripts/update-template.sh /path/to/project --dry-run   # 先預覽
bash scripts/update-template.sh /path/to/project             # 實跑（自動備份到 .claude-backups/）
```

| 分類 | 涵蓋 | 行為 |
|---|---|---|
| SYNC | `agents/ commands/ rules/ skills/ hooks/ guides/ templates/ ui/ scripts/` | 覆寫（加 `--prune` 才刪除多出來的舊檔） |
| MERGE | `context/ coordination/` | 只補骨架，**永不刪除**既有報告與交接 |
| PRESERVE | `taskmaster-data/ sessions/ logs/ qa-history/ settings.local.json` + 專案自己的 `CLAUDE.md` | 完全不碰 |

可選參數：`--prune`（清掉目標多出來的模板舊檔）、`--claude-only`（只更新 `.claude/`）、
`--no-backup`。PowerShell 版本為 `scripts\update-template.ps1 -Destination <path> -DryRun`。

> **更新後記得跑一次 `/task-status`**——若該專案的 `wbs.md` 還沒有 `Plan` 欄，
> 它會提議把既有 plan 回填成連結（一次性遷移）。

---

## 目錄結構

```
claude_v2026/
├── CLAUDE.md                         # 模板本身的開發須知（不複製到新專案）
├── CLAUDE_TEMPLATE.md                # 專案初始化哨兵（init 後自動刪除）
├── .mcp.json.windows.example         # MCP 範本（Windows）
├── .mcp.json.linux.example           # MCP 範本（Linux / macOS）
├── scripts/                          # copy-template / update-template（.sh + .ps1）
└── .claude/
    ├── README.md                     # 配置目錄詳細說明
    ├── settings.json                 # 主設定（權限、StatusLine、Hooks）
    ├── statusline.sh                 # StatusLine 腳本
    │
    ├── rules/        ( 6 個)         # 自動載入規則（每次對話注入）
    ├── agents/       (14 個)         # 專業 Agent 定義
    ├── commands/     (28 個)         # Slash Commands
    ├── skills/       (12 個)         # 按需載入（不佔常駐 context）
    ├── hooks/                        # Hook 腳本 + 63 案例回歸測試
    ├── scripts/                      # context-gc.sh（報告輪替）
    ├── ui/           (69 種風格)     # 設計系統 DESIGN.md（/ui-style 選用）
    │
    ├── guides/                       # 參考文件（不自動載入）
    │   ├── WORKFLOW.md               # 開發流程指南
    │   ├── MECHANISMS.md             # 各套機制權威對照
    │   ├── MODELS.md                 # 模型選擇策略
    │   ├── MCP_CONFIGS.md            # MCP Server 推薦清單
    │   ├── PAUSE_RESUME_GUIDE.md     # 暫停/恢復 SOP
    │   └── STATUSLINE_GUIDE.md       # StatusLine 客製化手冊
    │
    ├── context/                      # Agent 跨 session 報告
    │   ├── decisions/                # ADR（architect 自動產出 + /adr）
    │   └── learned/                  # 踩過的坑、可重用 pattern（長期累積）
    ├── coordination/                 # Agent 間工作交接（handoff）
    ├── taskmaster-data/              # WBS、plans/、時間日誌
    ├── sessions/                     # /save-session 儲存
    ├── qa-history/                   # 問答紀錄
    ├── logs/                         # Hook 執行 log
    ├── templates/                    # 初始化範本（僅 /task-init 讀）
    └── custom-rule&skill/            # 備份池（94 skills、8 種語言 rules；不參與執行）
```

---

## 開發流程

```
/task-init                                          ← 第一題：demo / mvp / full
    │
    ├─ demo  → /docs-init --demo  → docs/prd.md
    ├─ mvp   → /docs-init --mvp   → docs/tech-spec.md
    └─ full  → /docs-init --full  → docs/01_prd.md, 02_bdd.md ...
         ↓
   WBS（從文件反推，避免發散）
         ↓
/task-next  ──→  判定任務模式  ──→  （觸及架構決策才）architect → ADR
     │            quick / standard / critical
     ↓
  quick     → 直接寫 → /verify quick
  standard  → /plan → /tdd → /verify
  critical  → /plan → /tdd → /code-review → /verify pre-pr
     ↓
/verify  →  標 WBS ✅ + plan 歸檔  →  /pr  →  /deploy
```

**任務分級（quick / standard / critical）由 hook 強制**，不靠自律：`pre-tool-use.sh`
在你要寫程式碼檔時檢查 `.current-task-mode`，未判級直接擋下。逃生門為
`/suggest-mode off` 或環境變數 `TASKMODE_GATE=off`。規範見 `.claude/rules/task-mode.md`。

**Plan 持久化**：`/plan` 寫入 `taskmaster-data/plans/`、`/tdd` 按階段接續、
`/verify` PASS 後標 WBS ✅ 並歸檔至 `plans/archive/`。WBS（What）與 Plan（How）
職責分工與雙向連結見 `plan-format` skill。

**Agent 交接鏈**：11 個 agent 完成後會寫報告到 `context/<area>/` 並對需要後續處理者
建立 handoff，`post-agent-report.sh` 掃到 pending 交接即注入提示。編排劇本見
`.claude/rules/agent-orchestration.md`。

### 指令速查（28 個）

| 階段 | 指令 | 用途 |
| :--- | :--- | :--- |
| 專案級 | `/task-init` | 初始化（選情境 → 產文件 → 生 WBS） |
| | `/docs-init` | 規格文件產出（`--demo` / `--mvp` / `--full`） |
| | `/task-next` | 取下一個任務（判定模式、可選平行 worktree） |
| | `/task-add` | 追加新功能到既有 WBS（自動拆解、接編號、算依賴） |
| | `/task-status` | 查看進度（含 plan 連結與里程碑歸檔） |
| | `/time-log` | 開發時間報表 |
| 功能級 | `/plan` | 規劃實作步驟並持久化 |
| | `/tdd` | Red-Green-Refactor（自動載入當前 plan） |
| | `/build-fix` | 修復建置/型別錯誤 |
| 品質級 | `/verify` | 全面驗證（quick / full / pre-pr） |
| | `/e2e` | Playwright E2E 測試 |
| | `/check-quality` | 品質評估 + Agent 路由推薦 |
| | `/refactor-clean` | 死碼清理（分批移除、每批測試） |
| 交付級 | `/pr` | 建立 PR（分析完整 commit 歷史 + 測試計畫） |
| | `/deploy` | 部署（先安全把關再委派 deployment-expert） |
| | `/deps` | 依賴維護（依風險分批升級） |
| UI 前端 | `/ui-style` | 選擇/切換 UI 風格（69 種設計系統） |
| | `/ui-site` | 網站雛形產生器（Q&A → IA 文檔 + 多頁骨架 + tokens） |
| | `/ui-page <path>` | 單頁深化（讀 IA、Q&A 補細節、委派 ui-builder） |
| 環境設定 | `/pm-choose` | 選擇 Node.js 套件管理器（bun / pnpm / npm） |
| | `/pm-switch` | 切換已設定的 PM（附遷移指引） |
| 知識沉澱 | `/adr` | 記錄技術決策（為什麼選 A 不選 B） |
| | `/learn` | 擷取可重用 pattern（存成 skill 或 learned 筆記） |
| | `/save-session` | 儲存 session 狀態供下次恢復 |
| 輔助 | `/hub-delegate` | 手動委派單一 Agent |
| | `/agent-log` | 查看 subagent 活動軌跡與交接決策 |
| | `/suggest-mode` | 調整建議/注入密度（off / low / medium / high） |
| | `/template-check` | VibeCoding 模板合規檢查 |

> 程式碼審查用 **Claude Code 內建的 `/code-review`**（支援 `ultra` 多 agent 雲端審查、
> `--fix`、`--comment`、指定 PR/分支）。本模板不自建，舊有的 `/review-code` 已刪除。

---

## Agent（14 個）

| Agent | Model | 用途 |
| :--- | :--- | :--- |
| planner | opus | 功能規劃、階段拆解、持久化 plan |
| architect | opus | 架構設計、技術選型 → **自動產 ADR** |
| security-infrastructure-auditor | opus | OWASP Top 10、秘密偵測、依賴與基礎設施安全 |
| code-quality-specialist | sonnet | 程式碼品質與安全審查 |
| test-automation-engineer | sonnet | 實作後測試補強 |
| tdd-guide | sonnet | 實作前 TDD 門禁（RED→GREEN→REFACTOR） |
| debug-investigator | sonnet | 執行期 bug 根因調查（先重現再定因） |
| e2e-validation-specialist | sonnet | Playwright 端到端驗證 |
| refactor-cleaner | sonnet | 死碼清理與合併 |
| deployment-expert | sonnet | 部署、CI/CD、IaC、上線監控 |
| ui-builder | sonnet | 前端 UI 產出（嚴格遵循 DESIGN.md） |
| build-error-resolver | haiku | 建置/型別錯誤最小差異修復 |
| documentation-specialist | haiku | codemap、API 文檔 |
| workflow-template-manager | haiku | PRD/ADR 等流程模板管理 |

通用任務退回 Claude Code **內建的 `general-purpose`**——本模板不自訂它，同名會 shadow
掉內建版，換來的是更小的工具集。

---

## Rules（6 個，自動載入）

每次對話自動注入。從 15 條瘦身至 6 條——常駐規則的成本是**注意力稀釋**，
「只在特定情境才該生效」的規則被淹沒後反而失效，因此改搬成按需載入的 skill。

| 規則 | 強制內容 |
| :--- | :--- |
| **task-mode** | 任務分級 quick / standard / critical，由 `pre-tool-use.sh` 硬性強制 |
| **agent-orchestration** | 何時委派哪個 agent、標準鏈、handoff 接力、安全平行 |
| **coding-style** | 克制原則、**註解預設不寫**、不可變性、檔案 < 800 行、函式 < 50 行 |
| **interactive-qa** | `AskUserQuestion` 一次一題、問答歷史落檔 |
| **security** | commit 前安全檢查清單、秘密管理、事件回應 |
| **git-workflow** | Conventional Commits、PR 流程 |

### 從 rules 移出的去向

| 原 rule | 現在在哪 |
| :--- | :--- |
| testing | `testing-standards` skill |
| plan-persistence | `plan-format` skill |
| ui-design + pencil-design-location | `ui-style-compliance` skill |
| package-manager | `node-package-manager` skill |
| development-workflow | `python-uv` + `node-package-manager` skill + task-mode |
| bash-cwd | `pre-tool-use.sh` 硬擋裸 `cd` + coding-style 一句話 |
| patterns / performance | 併入 coding-style ／ `guides/MODELS.md` |

> 從舊版更新的專案，若 `rules/` 還留著上表左欄的檔案，**請刪除**——它們會自動載入並跟新規則衝突。

語言特定規則可從 `custom-rule&skill/rules/` 複製（typescript、python、golang 等 8 種）。

---

## Skills（12 個，按需載入）

不佔常駐 context，由 `description` 的觸發條件決定何時載入。

### 專案約定（原為常駐 rule）

| Skill | 用途 | 啟動時機 |
| :--- | :--- | :--- |
| **testing-standards** | 覆蓋率門檻（依任務模式分級）、TDD 流程、測試反模式 | 寫/修測試、`/tdd`、決定覆蓋率目標 |
| **plan-format** | plan 格式、命名、`files:` 欄、與 WBS 的職責分工與雙向連結 | `/plan` `/tdd` `/verify` `/task-next`，或動 `plans/` |
| **ui-style-compliance** | UI 三階段強制檢查 + Pencil `.pen` 落地 `design/` | 寫前端頁面/元件、`/ui-site` `/ui-page`、呼叫 pencil MCP 前 |
| **node-package-manager** | bun/pnpm/npm 由使用者決定，含指令對照與 lock 衝突處理 | 跑任何 npm/pnpm/bun 指令、動 package.json 前 |
| **python-uv** | Python 一律 uv，禁 pip/poetry | 跑 Python 套件/環境指令、建 Python 骨架前 |

### 領域知識包

| Skill | 用途 |
| :--- | :--- |
| **project-docs** | 依 VibeCoding 範本產專案文件（**21 份範本自帶於 skill 內**），支援 demo/mvp/full 三檔深度 |
| **deep-research** | 多源深度研究（MCP 串接） |
| **e2e-testing** | Playwright E2E 測試模式 |
| **cost-aware-llm-pipeline** | LLM API 成本優化（模型路由 + 預算追蹤） |
| **mcp-builder** | MCP Server 開發指南（FastMCP / MCP SDK） |
| **database-migrations** | DB Migration 安全模式（zero-downtime DDL） |
| **postgres-patterns** | PostgreSQL 速查表（Index、型態、RLS） |

更多 skill（94 個）可從 `custom-rule&skill/skills/` 按需複製；新增後記得更新
`.claude/skills/INDEX.md`。

---

## MCP Server（8 個）

| Server | 用途 | 備註 |
| :--- | :--- | :--- |
| brave-search | 網路搜尋 | |
| context7 | 即時套件文檔查詢 | |
| firecrawl | 網頁爬取與深度研究 | |
| github | GitHub PR/Issue 操作 | |
| playwright | 瀏覽器自動化與 E2E | |
| sequential-thinking | 鏈式推理 | |
| memory | 跨 session 記憶 | |
| pencil | 設計檔（.pen）編輯/產生 | **需本機先安裝 Pencil 擴充元件**（Cursor / VS Code）。Windows 範本用 `${USERPROFILE}` 自動解析；Linux/macOS 需自行填 binary 路徑 |

更多可用 server 見 `.claude/guides/MCP_CONFIGS.md`。

---

## VibeCoding 工作流模板（20 份）

自帶於 `project-docs` skill 的 `templates/`，由 `/docs-init` 依情境選用（編號無 `10`）。

| 階段 | 模板 |
| :--- | :--- |
| 流程總覽 | `01` workflow_manual |
| 規劃 | `02` PRD、`03` BDD |
| 架構設計 | `04` ADR、`05` 架構、`06` API |
| 詳細設計 | `07` 模組與測試、`08` 專案結構、`09` 設計與依賴、`18` 資料模型與 migration |
| 開發品質 | `11` Code Review、`12` 前端架構、`17` 前端 IA |
| 安全部署 | `13` 安全與就緒清單、`20` 威脅模型、`14` 部署維運、`19` 可觀測性與 SLO |
| 維護管理 | `15` 文檔維護、`16` WBS、`21` AI/LLM 整合 |

---

## 版本記錄

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v5.3 | 2026-08-14 | **任務分級改由 hook 強制**（`pre-tool-use.sh` 擋下未判級的寫入）、**rules 15→6**（其餘搬成按需 skill，解注意力稀釋）、**agent 交接鏈接回**（11 個 agent 自動寫報告 + 建 handoff）、新增 `debug-investigator`、拆除名實不符的 `/review-code`（改用內建 `/code-review`）、新增 `/task-add` `/pr` `/deps` `/adr` `/deploy` `/agent-log`、`update-template` 無痛更新既有專案、project-docs 範本搬入 skill 自包含（20 份）、UI 擴充至 69 種設計系統、模型參照更新至 Claude 5 家族、hooks 精簡 + 63 案例回歸測試、WBS 里程碑歸檔、可選平行開發（worktree 編排）、註解規則強化（預設不寫）、WBS↔Plan 雙向連結 |
| v5.2 | 2026-04-23 | 文件先行流程（`/task-init` 選 demo/mvp/full → `/docs-init` 產文件 → WBS 從文件反推）、Package Manager 選擇系統、Pencil MCP 接入與 `.pen` 檔強制落地 `design/` |
| v5.1 | 2026-04-20 | Plan 持久化系統（`/plan` 寫入 `plans/`、`/tdd` 接續階段、`/verify` 驗收歸檔）、模型別名收租、settings.json 權限改 uv |
| v5.0 | 2026-04-13 | Skills 精簡、Rules 精簡、Hooks 精簡、文檔整合到 guides/、新增 project-docs skill |
| v4.4 | 2026-04-08 | Context 系統啟用、MECHANISMS.md、Hook 健壯性修正 |
| v4.3 | 2026-03-24 | 開發時間追蹤、`/time-log`、StatusLine 持久化 |
| v4.2 | 2026-03-16 | 跨平台支援（Windows/Linux） |
| v4.0 | 2026-03-16 | 全面升級：13 Agent、16 Commands、StatusLine |
