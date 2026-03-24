# Claude Code 全面開發配置

> **版本:** v4.3 | **更新:** 2026-03-24 | **平台:** Windows / Linux (Ubuntu, RHEL)

人類主導的文檔導向智能協作開發平台。

---

## 快速開始

```bash
# 1. 複製本模板到新專案
# 2. 複製對應平台的 MCP 範本並填入 API keys
#    Windows: cp .mcp.json.windows.example .mcp.json
#    Linux:   cp .mcp.json.linux.example .mcp.json
# 3. 啟動 Claude Code
claude

# 4. 初始化專案
/task-init

# 5. 開始開發循環
/task-next → /plan → /tdd → /verify
```

完整開發流程見 [.claude/WORKFLOW.md](.claude/WORKFLOW.md)。

---

## 系統架構

```
claude_v2026/
├── .claude/
│   ├── settings.json                 # 主設定（權限、StatusLine、Hooks）
│   ├── agents/          (13 個)      # 專業 Agent
│   ├── commands/        (17 個)      # Slash Commands
│   ├── rules/           (7 個)       # 自動載入規則
│   ├── skills/          (8 個)       # 領域知識 Skill
│   ├── output-styles/   (15 個)      # Output Styles
│   ├── mcp-configs/                  # MCP 推薦清單
│   ├── hooks/                        # Hook 腳本
│   ├── context/                      # 專案上下文
│   ├── coordination/                 # Agent 協調
│   ├── statusline.sh                 # StatusLine（bash，Windows）
│   ├── statusline-linux.sh           # StatusLine（bash，Linux）
│   ├── statusline-go.exe             # StatusLine（Go 備用）
│   └── WORKFLOW.md                   # 開發流程指南
├── VibeCoding_Workflow_Templates/    # 工作流模板庫（17 個）
├── .mcp.json                         # MCP Server 設定（不入 Git）
├── .mcp.json.windows.example         # MCP 範本（Windows）
├── .mcp.json.linux.example           # MCP 範本（Linux）
├── CLAUDE_TEMPLATE.md                # 專案初始化範本
└── PROJECT_STRUCTURE.md              # 專案結構說明
```

---

## 開發流程

```
/task-init  →  /task-next  →  /plan  →  /tdd  →  /build-fix
                                                      ↓
/save-session  ←  /time-log  ←  /task-status  ←  /verify  ←  /e2e  ←  /review-code
```

| 階段 | 指令 | 用途 |
| :--- | :--- | :--- |
| 專案級 | `/task-init` | 建立 WBS、分析複雜度 |
| 專案級 | `/task-next` | 從 WBS 取下一個任務（自動追蹤時間） |
| 專案級 | `/task-status` | 查看整體進度（含預估 vs 實際時間） |
| 專案級 | `/time-log` | 每日/每任務開發時間報表 |
| 功能級 | `/plan` | 規劃實作步驟（等待確認） |
| 功能級 | `/tdd` | Red-Green-Refactor |
| 功能級 | `/build-fix` | 修復建置錯誤 |
| 品質級 | `/review-code` | 程式碼審查 |
| 品質級 | `/e2e` | Playwright E2E 測試 |
| 品質級 | `/verify` | 全面驗證（quick/full/pre-pr） |
| 收尾 | `/save-session` | 儲存 session 狀態 |

快速模式（小功能）：`/plan → /tdd → /verify quick`

---

## Agent 系統（13 個）

| Agent | Model | 用途 |
| :--- | :--- | :--- |
| general-purpose | opus | 通用問題解決、跨領域研究 |
| planner | opus | 功能規劃、實作步驟拆解 |
| architect | opus | 系統架構設計、技術決策 |
| code-quality-specialist | opus | 程式碼審查、品質把關 |
| security-infrastructure-auditor | opus | OWASP Top 10、安全稽核 |
| test-automation-engineer | opus | 單元/整合測試、TDD |
| tdd-guide | opus | 測試驅動開發引導 |
| e2e-validation-specialist | opus | Playwright E2E 測試 |
| build-error-resolver | opus | 最小差異修復建置錯誤 |
| refactor-cleaner | opus | 死碼偵測與安全清理 |
| documentation-specialist | opus | Codemap 生成、技術文檔 |
| deployment-expert | opus | 零停機部署、監控告警 |
| workflow-template-manager | opus | VibeCoding 模板整合 |

---

## Rules（7 個，自動載入）

放在 `.claude/rules/`，每次對話自動生效：

| 規則 | 強制內容 |
| :--- | :--- |
| coding-style | 不可變性、檔案 < 800 行、函式 < 50 行 |
| development-workflow | 研究先行 → Plan → TDD → Review |
| git-workflow | Conventional Commits、PR 流程 |
| security | commit 前安全檢查清單 |
| testing | 80%+ 覆蓋率、TDD 強制 |
| performance | 模型選擇策略、Context 管理 |
| patterns | Repository Pattern、API 格式 |

語言特定規則可從 `everything-claude/rules/` 複製（typescript、python、golang 等 8 種語言）。

---

## Skills（8 個精選）

放在 `.claude/skills/`，提供領域深度知識：

| Skill | 搭配 |
| :--- | :--- |
| tdd-workflow | `/tdd` 指令 |
| api-design | API 模板 |
| security-review | 安全 Agent |
| e2e-testing | `/e2e` 指令 |
| coding-standards | 所有開發 |
| deep-research | 複雜問題 |
| deployment-patterns | 部署規劃 |
| docker-patterns | 容器化 |

更多 skill（95 個）可從 `everything-claude/skills/` 按需複製。

---

## MCP Server（6 個啟用）

| Server | 用途 |
| :--- | :--- |
| brave-search | 網路搜尋 |
| context7 | 即時套件文檔查詢 |
| github | GitHub PR/Issue 操作 |
| playwright | 瀏覽器自動化與 E2E |
| sequential-thinking | 鏈式推理（複雜問題） |
| memory | 跨 session 記憶 |

更多可用 server 見 [.claude/mcp-configs/README.md](.claude/mcp-configs/README.md)。

---

## VibeCoding 工作流模板（17 個）

| 階段 | 模板 |
| :--- | :--- |
| 流程總覽 | `01` workflow_manual |
| 規劃 | `02` PRD、`03` BDD |
| 架構設計 | `04` ADR、`05` 架構、`06` API |
| 詳細設計 | `07` 模組、`08` 結構、`09` 依賴、`10` 類別 |
| 開發品質 | `11` Review、`12` 前端架構、`17` 前端 IA |
| 安全部署 | `13` 安全、`14` 部署 |
| 維護管理 | `15` 文檔、`16` WBS |

索引：[VibeCoding_Workflow_Templates/INDEX.md](VibeCoding_Workflow_Templates/INDEX.md)

---

## Output Styles（15 個）

使用 `/output-style <name>` 切換 Claude 的產出格式：

01-prd / 02-bdd / 03-architecture / 04-ddd / 05-api / 06-tdd / 07-code-review / 08-security / 09-database / 10-backend-python / 11-frontend-bdd / 12-integration / 13-data-contract / 14-ci-gates / 15-vision

---

## StatusLine

```
Opus 4.6 (1M context) │ 26% (266k/1.0m) │ project-name (main*) │ 15m │ $12.50
current ●●●○○○○○○○  28% ⟳ 19:00
weekly  ●●●●●●●●○○  79% ⟳ 03/23 10:00
```

StatusLine 同時負責**時間追蹤持久化**：每次更新時將當前 session 的 duration 和任務寫入暫存檔，供跨 session 歸檔。

**平台設定：** Linux 環境須使用 `statusline-linux.sh`（LF 換行），避免 CRLF 導致執行錯誤。

在 `.claude/settings.json` 中設定：
```jsonc
// Windows
"statusLine": "bash .claude/statusline.sh"

// Linux
"statusLine": "bash .claude/statusline-linux.sh"
```

---

## 新專案設定

1. 複製整個 `claude-GUNDAM-zh-tw` 目錄到新位置
2. 複製 MCP 範本：Windows `cp .mcp.json.windows.example .mcp.json` / Linux `cp .mcp.json.linux.example .mcp.json`
3. 編輯 `.mcp.json` 填入 API keys
4. 根據語言需求，從 `.claude\custom-rule&skill/` 複製規則到 `.claude/rules/`
5. 根據專案需求，從 `.claude\custom-rule&skill/` 複製額外 skill 到 `.claude/skills/`
6. 啟動 Claude Code → `/task-init`

---

## 版本記錄

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v4.3 | 2026-03-24 | 開發時間追蹤（每日/每任務）、`/time-log` 命令、StatusLine 時間持久化、17 Commands |
| v4.2 | 2026-03-16 | 跨平台支援（Windows/Linux）、MCP example 分平台、Agent 全 opus、移除 count_tokens.js |
| v4.1 | 2026-03-16 | 新增 rules(7)、skills(8)、MCP(+2)、開發流程文件 |
| v4.0 | 2026-03-16 | 全面升級：13 Agent、16 Commands、StatusLine 適配、模板精簡 68% |
| v3.0 | 2025-09-25 | TaskMaster Hub-and-Spoke 架構 |
