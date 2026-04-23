# Claude Code 全面開發配置

> **版本:** v5.1 | **更新:** 2026-04-20 | **平台:** Windows（需 Git Bash）/ Linux / macOS

人類主導的文檔導向智能協作開發平台。

---

## 快速開始

### 前置需求

| 平台 | 必要軟體 |
|---|---|
| Windows | **Git Bash**（Git for Windows 附帶）+ `jq`（`winget install jqlang.jq`） |
| Linux / macOS | `bash`（系統內建）+ `jq`（`apt/brew install jq`） |

> `.claude/hooks/*.sh` 與 `statusline.sh` 皆為 bash 腳本。Windows 原生 PowerShell 無法執行，**必須裝 Git Bash**。

### 步驟 1：複製模板到新專案（使用複製腳本，自動排除專案專屬資料）

```bash
# Git Bash / Linux / macOS / WSL
bash scripts/copy-template.sh /path/to/new-project

# Windows PowerShell（只用於複製，hooks 仍需 Git Bash 執行）
powershell -ExecutionPolicy Bypass -File scripts\copy-template.ps1 D:\projects\my-app
```

> **為什麼用腳本？** 手動 `cp -r` 會把 `settings.local.json`、`taskmaster-data/`、`logs/`、`sessions/` 等專案專屬資料一起帶走，造成新專案被舊資料污染。複製腳本會自動排除這些目錄。

### 步驟 2-5：MCP 設定 → 啟動 → 初始化 → 開發

```bash
cd /path/to/new-project

# 2. 複製對應平台的 MCP 範本並填入 API keys
cp .mcp.json.windows.example .mcp.json  # Windows
cp .mcp.json.linux.example .mcp.json    # Linux / macOS

# 3. 啟動 Claude Code
claude

# 4. 初始化專案
/task-init

# 5. 開始開發循環
/task-next → /plan → /tdd → /verify
```

### 手動複製時需排除的目錄（若不用腳本）

| 路徑 | 原因 |
|------|------|
| `.claude/settings.local.json` | 含模板開發過程累積的 permission，對新專案無意義 |
| `.claude/taskmaster-data/` | 前一專案的 WBS 與計時記錄 |
| `.claude/qa-history/` | 前一專案的問答歷史 |
| `.claude/sessions/` | 前一專案的 session 存檔 |
| `.claude/logs/` | 執行時 log |
| `.claude/worktrees/` | Agent worktree |
| `.claude/context/`、`coordination/` | Agent 跨 session 報告 |
| `workshop/` | 模板開發工作區 |
| `.git/`、`node_modules/`、`.venv/` | 依賴與版控 |

---

## 目錄結構

```
claude_v2026/
├── CLAUDE_TEMPLATE.md                # 專案初始化哨兵（init 後自動刪除）
├── .mcp.json                         # MCP Server 設定（不入 Git）
├── .mcp.json.windows.example         # MCP 範本（Windows）
├── .mcp.json.linux.example           # MCP 範本（Linux）
├── VibeCoding_Workflow_Templates/    # 工作流文件範本（16 個，編號 01-09,11-17）
│
└── .claude/                          # 核心配置
    ├── README.md                     # 配置目錄詳細說明
    ├── settings.json                 # 主設定（權限、StatusLine、Hooks）
    ├── settings.local.json           # 個人設定（MCP 啟用）
    ├── statusline.sh                 # StatusLine 腳本
    │
    ├── rules/        (11 個)         # 自動載入規則（每次對話注入）
    ├── agents/       (13 個)         # 專業 Agent 定義
    ├── commands/     (17 個)         # Slash Commands
    ├── skills/       (7 個)          # 專案特定領域知識
    ├── output-styles/ (15 個)        # 輸出樣式模板
    ├── hooks/                        # Hook 腳本庫
    ├── plugins/                      # Plugin 套件
    │   └── dev-project-kit/          # 開發工具包（可攜帶到其他專案）
    │
    ├── guides/                       # 參考文件（不自動載入）
    │   ├── WORKFLOW.md               # 開發流程指南
    │   ├── MECHANISMS.md             # 五套機制權威對照
    │   ├── MCP_CONFIGS.md            # MCP Server 推薦清單
    │   ├── PAUSE_RESUME_GUIDE.md     # 暫停/恢復 SOP
    │   └── STATUSLINE_GUIDE.md       # StatusLine 客製化手冊
    │
    ├── context/                      # Agent 跨 session 報告
    ├── coordination/                 # Agent 間工作交接
    ├── sessions/                     # /save-session 儲存
    ├── taskmaster-data/              # WBS、時間日誌
    ├── qa-history/                   # 問答紀錄
    ├── logs/                         # Hook 執行 log
    ├── templates/                    # 初始化範本（僅 /task-init 時讀）
    └── custom-rule&skill/            # 備份池（94+ skills、8 種語言 rules）
```

---

## 開發流程

```
/task-init  →  /task-next  →  /plan  →  /tdd  →  /build-fix
                   ↑           ↓          ↓
                   |      寫入 plan   讀 plan
                   |      更新 WBS    更新階段
                   ↓
/save-session  ←  /time-log  ←  /task-status  ←  /verify  ←  /e2e  ←  /review-code
                                      ↑                        讀 plan 驗收
                                顯示 plan 進度                 歸檔 plan
```

**Plan 持久化（v5.1 新增）**：
- `/plan <wbs-id>` 寫入 `.claude/taskmaster-data/plans/<id>-<slug>.md`
- `/tdd` 自動載入當前任務的 plan，按階段 RED→GREEN→REFACTOR 並更新階段狀態
- `/verify` PASS → 自動標 WBS ✅ + plan 歸檔至 `plans/archive/`
- WBS（What）與 Plan（How）職責分工詳見 `.claude/rules/plan-persistence.md`

快速模式（小功能）：`/plan --adhoc → /tdd → /verify quick`

### 指令速查

| 階段 | 指令 | 用途 |
| :--- | :--- | :--- |
| 專案級 | `/task-init` | 建立 WBS、分析複雜度 |
| | `/task-next` | 取下一個任務（自動追蹤時間） |
| | `/task-status` | 查看進度 |
| | `/time-log` | 開發時間報表 |
| 功能級 | `/plan` | 規劃實作步驟 |
| | `/tdd` | Red-Green-Refactor |
| | `/build-fix` | 修復建置錯誤 |
| 品質級 | `/review-code` | 程式碼審查 |
| | `/e2e` | Playwright E2E 測試 |
| | `/verify` | 全面驗證（quick/full/pre-pr） |
| UI 前端 | `/ui-style` | 選擇/切換 UI 風格 |
| | `/ui-site` | 網站雛形產生器（Q&A → IA 文檔 + 多頁骨架 + 設計 tokens）|
| | `/ui-page <path>` | 單頁深化（讀 IA，Q&A 補細節，委派 ui-builder）|
| 輔助 | `/hub-delegate` | 手動委派 Agent |
| | `/check-quality` | 品質評估 + Agent 推薦 |
| | `/refactor-clean` | 死碼清理 |
| | `/suggest-mode` | 調整建議密度 |
| | `/learn` | 擷取可重用模式 |
| | `/save-session` | 儲存 session 狀態 |
| | `/template-check` | 模板合規檢查 |

---

## Agent（14 個）

| Agent | Model | 用途 |
| :--- | :--- | :--- |
| planner | opus | 功能規劃、步驟拆解 |
| architect | opus | 架構設計、技術選型 |
| security-infrastructure-auditor | opus | OWASP、安全漏洞 |
| code-quality-specialist | sonnet | 程式碼審查 |
| test-automation-engineer | sonnet | 實作後測試補強 |
| tdd-guide | sonnet | 實作前 TDD 門禁 |
| e2e-validation-specialist | sonnet | Playwright E2E |
| refactor-cleaner | sonnet | 死碼清理 |
| deployment-expert | sonnet | 部署、CI/CD、監控 |
| general-purpose | sonnet | 通用任務 |
| build-error-resolver | haiku | 建置修復 |
| documentation-specialist | haiku | codemap、API 文檔 |
| workflow-template-manager | haiku | VibeCoding 模板管理 |
| ui-builder | sonnet | 前端 UI 產出專家（嚴格遵循 DESIGN.md） |

---

## Rules（11 個，自動載入）

每次對話自動注入。

| 規則 | 強制內容 |
| :--- | :--- |
| bash-cwd | Bash CWD 汙染防護、subshell 隔離 |
| coding-style | 不可變性、檔案 < 800 行、函式 < 50 行 |
| development-workflow | 研究先行 → Plan → TDD → Review，Python 強制 uv |
| git-workflow | Conventional Commits |
| interactive-qa | AskUserQuestion 一次一題 |
| security | commit 前安全檢查清單 |
| testing | 80%+ 覆蓋率、TDD 強制 |
| performance | 模型選擇策略、Context 管理 |
| patterns | Repository Pattern、API 格式 |
| plan-persistence | `/plan` 檔案持久化、WBS/Plan 職責分工、狀態同步 |
| ui-design | Apple 風格簡約設計、毛玻璃效果 |

語言特定規則可從 `custom-rule&skill/rules/` 複製（typescript、python、golang 等 8 種語言）。

---

## Skills（7 個精選）

僅保留模型不知道的專案特定知識。

| Skill | 用途 | 觸發時機 |
| :--- | :--- | :--- |
| **project-docs** | 依據 VibeCoding 範本撰寫專案文件 | 撰寫 PRD、架構、API 規格 |
| **deep-research** | 多源深度研究（MCP 串接） | 複雜問題調查 |
| **e2e-testing** | Playwright E2E 測試模式 | 測試關鍵使用者流程 |
| **cost-aware-llm-pipeline** | LLM API 成本優化 | 開發 AI 應用 |
| **mcp-builder** | MCP Server 開發指南 | 串接外部 API |
| **database-migrations** | DB Migration 安全模式 | Schema 變更 |
| **postgres-patterns** | PostgreSQL 速查表 | 寫 SQL、設計 Schema |

更多 skill（94 個）可從 `custom-rule&skill/skills/` 按需複製。

---

## MCP Server（8 個，含可選）

| Server | 用途 | 備註 |
| :--- | :--- | :--- |
| brave-search | 網路搜尋 | |
| context7 | 即時套件文檔查詢 | |
| firecrawl | 網頁爬取與深度研究 | |
| github | GitHub PR/Issue 操作 | |
| playwright | 瀏覽器自動化與 E2E | |
| sequential-thinking | 鏈式推理 | |
| memory | 跨 session 記憶 | |
| pencil | 設計檔（.pen）編輯/產生 | **需本機先安裝 Pencil 擴充元件**（Cursor / VS Code）。Windows 範本使用 `${USERPROFILE}` 變數自動解析路徑；Linux/macOS 需自行填入 binary 路徑（見 `.mcp.json.linux.example`）。 |

更多可用 server 見 `.claude/guides/MCP_CONFIGS.md`。

---

## VibeCoding 工作流模板（16 個）

| 階段 | 模板 |
| :--- | :--- |
| 流程總覽 | `01` workflow_manual |
| 規劃 | `02` PRD、`03` BDD |
| 架構設計 | `04` ADR、`05` 架構、`06` API |
| 詳細設計 | `07` 模組、`08` 結構、`09` 設計與依賴 |
| 開發品質 | `11` Review、`12` 前端架構、`17` 前端 IA |
| 安全部署 | `13` 安全、`14` 部署 |
| 維護管理 | `15` 文檔、`16` WBS |

---

## 新專案設定

1. 複製必要檔案到新專案：
   ```bash
   cp -r .claude/ <新專案>/
   cp .gitattributes <新專案>/          # 確保 .sh 換行符正確（Windows 必備）
   cp CLAUDE_TEMPLATE.md <新專案>/      # 初始化哨兵（可選）
   ```
2. 複製 MCP 範本：
   - Windows: `cp .mcp.json.windows.example <新專案>/.mcp.json`
   - Linux: `cp .mcp.json.linux.example <新專案>/.mcp.json`
3. 編輯 `.mcp.json` 填入 API keys
4. （可選）複製語言規則：`cp .claude/custom-rule&skill/rules/<lang>/*.md .claude/rules/`
5. （可選）複製額外 skill：`cp -r .claude/custom-rule&skill/skills/<name> .claude/skills/`
6. 啟動 Claude Code → 偵測 `CLAUDE_TEMPLATE.md` → 執行 `/task-init`

---

## 版本記錄

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v5.1 | 2026-04-20 | Plan 持久化系統（`/plan` 寫入 `plans/`、`/tdd` 自動接續階段、`/verify` 驗收歸檔）、新增 `rules/plan-persistence.md`、模型別名收租（agent frontmatter 全用 `opus/sonnet/haiku` 自動追最新）、settings.json 權限改 uv |
| v5.0 | 2026-04-13 | Skills 精簡至 7 個（-46%）、Rules 精簡（-28%）、Hooks 精簡（-81%）、文檔整合到 guides/、新增 project-docs skill、新增 dev-project-kit plugin、刪除通用知識 skill |
| v4.4 | 2026-04-08 | Context 系統啟用、MECHANISMS.md、Hook 健壯性修正 |
| v4.3 | 2026-03-24 | 開發時間追蹤、`/time-log`、StatusLine 持久化 |
| v4.2 | 2026-03-16 | 跨平台支援（Windows/Linux） |
| v4.0 | 2026-03-16 | 全面升級：13 Agent、16 Commands、StatusLine |
