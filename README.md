# Claude Code 全面開發配置

> **版本:** v4.4 | **更新:** 2026-04-08 | **平台:** Windows / Linux (Ubuntu, RHEL)

人類主導的文檔導向智能協作開發平台。

**核心文件**：
- 📖 [`.claude/MECHANISMS.md`](.claude/MECHANISMS.md) — Agent / Skill / Command / Hook / Context 五套擴充機制的權威對照
- 📘 [`.claude/CONTEXT_USAGE.md`](.claude/CONTEXT_USAGE.md) — Context 跨 session 共享系統使用指南
- 📙 [`.claude/PAUSE_RESUME_GUIDE.md`](.claude/PAUSE_RESUME_GUIDE.md) — 開發暫停 / 恢復 SOP
- 📗 [`.claude/WORKFLOW.md`](.claude/WORKFLOW.md) — 完整開發流程

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
│   ├── MECHANISMS.md                 # 五機制權威對照（必讀）
│   ├── CONTEXT_USAGE.md              # Context 系統使用指南
│   ├── PAUSE_RESUME_GUIDE.md         # 開發暫停 / 恢復 SOP
│   ├── WORKFLOW.md                   # 開發流程指南
│   ├── agents/          (13 個)      # 專業 Agent
│   ├── commands/        (17 個)      # Slash Commands
│   ├── rules/           (7 個)       # 自動載入規則
│   ├── skills/          (8 個)       # 領域知識 Skill
│   ├── output-styles/   (15 個)      # Output Styles
│   ├── mcp-configs/                  # MCP 推薦清單
│   ├── hooks/                        # Hook 腳本（含 post-agent-report.sh）
│   ├── context/                      # Agent 跨 session 結構化報告
│   │   ├── _REPORT_TEMPLATE.md       # 報告統一格式
│   │   ├── quality/                  # code-quality-specialist 報告
│   │   ├── security/                 # security agent 報告
│   │   ├── testing/                  # test-automation-engineer 報告
│   │   ├── e2e/                      # e2e agent 報告
│   │   ├── decisions/                # 架構決策 ADR
│   │   ├── deployment/               # 部署紀錄
│   │   └── docs/                     # 文檔狀態
│   ├── coordination/                 # Agent 間任務交接
│   │   ├── handoffs/                 # 交接檔
│   │   └── conflicts/                # 衝突解決紀錄
│   ├── sessions/                     # /save-session 儲存
│   ├── scripts/                      # 工具腳本
│   │   └── context-gc.sh             # Context GC（保留最新 5 份）
│   ├── templates/                    # 初始化模板（僅 init 時讀）
│   │   ├── CLAUDE-md.template.md
│   │   └── project-structures.md
│   ├── custom-rule&skill/            # 取材備份池（不參與執行）
│   │   ├── README.md
│   │   ├── rules/                    # 8 種語言完整 rules
│   │   └── skills/                   # 94 個 skills + INDEX.md
│   ├── statusline.sh                 # StatusLine（bash，Windows）
│   ├── statusline-linux.sh           # StatusLine（bash，Linux）
│   └── statusline-go.exe             # StatusLine（Go 備用）
├── VibeCoding_Workflow_Templates/    # 工作流模板庫（17 個）
├── .mcp.json                         # MCP Server 設定（不入 Git）
├── .mcp.json.windows.example         # MCP 範本（Windows）
├── .mcp.json.linux.example           # MCP 範本（Linux）
├── CLAUDE_TEMPLATE.md                # 專案初始化哨兵（init 後刪除）
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
| code-quality-specialist | opus | 程式碼審查（寫入 context/quality/） |
| security-infrastructure-auditor | opus | OWASP Top 10（寫入 context/security/） |
| test-automation-engineer | opus | **實作後**測試補強（讀 quality handoff，寫入 context/testing/） |
| tdd-guide | opus | **實作前**測試驅動開發引導（前置門禁） |
| e2e-validation-specialist | opus | Playwright E2E 測試（寫入 context/e2e/） |
| build-error-resolver | opus | 最小差異修復建置錯誤 |
| refactor-cleaner | opus | 死碼偵測與安全清理 |
| documentation-specialist | opus | **Codemap 與 API 文檔**（程式碼層） |
| deployment-expert | opus | 零停機部署、監控告警 |
| workflow-template-manager | opus | **VibeCoding 流程模板**（PRD/ADR/設計文檔） |

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

語言特定規則可從 `.claude/custom-rule&skill/rules/` 複製（typescript、python、golang、kotlin、swift、php、perl 等 8 種語言）。

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

更多 skill（94 個）可從 `.claude/custom-rule&skill/skills/` 按需複製，
索引見 [`.claude/custom-rule&skill/skills/INDEX.md`](.claude/custom-rule&skill/skills/INDEX.md)。

---

## Context 系統（第 5 機制）

4 個專業 agent 在執行前後自動讀寫結構化技術發現報告，實現跨 session 與跨 agent 的上下文共享：

| Agent | 寫入位置 |
| :--- | :--- |
| code-quality-specialist | `.claude/context/quality/` |
| security-infrastructure-auditor | `.claude/context/security/` |
| test-automation-engineer | `.claude/context/testing/` |
| e2e-validation-specialist | `.claude/context/e2e/` |

**設計原則**：
- 不污染主對話 context（按需讀取，不在 session-start 自動注入）
- 100% 留在專案內，跟著 git 走
- 與 `save-session`、`/learn`、Auto-memory 不重疊（衝突矩陣見 MECHANISMS.md）

**常用操作**：
```bash
# 看最新報告
ls -t .claude/context/quality/

# 看待處理交接
grep -l "status: pending" .claude/coordination/handoffs/*.md

# 清理舊報告（保留最新 5 份）
bash .claude/scripts/context-gc.sh
```

完整使用見 [`.claude/CONTEXT_USAGE.md`](.claude/CONTEXT_USAGE.md)。

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

1. 複製整個 `claude_v2026` 目錄到新位置
2. 複製 MCP 範本：
   - Windows: `cp .mcp.json.windows.example .mcp.json`
   - Linux: `cp .mcp.json.linux.example .mcp.json`
3. 編輯 `.mcp.json` 填入 API keys
4. （可選）依語言需求從 `.claude/custom-rule&skill/rules/<lang>/` 複製到 `.claude/rules/`
5. （可選）依專案需求從 `.claude/custom-rule&skill/skills/` 複製額外 skill 到 `.claude/skills/`
6. 啟動 Claude Code → 自動偵測 `CLAUDE_TEMPLATE.md` → 確認後執行 `/task-init`
7. `/task-init` 完成後會自動刪除 `CLAUDE_TEMPLATE.md`

---

## 版本記錄

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v4.4 | 2026-04-08 | Context 系統啟用（第 5 機制）、MECHANISMS.md 機制對照、CLAUDE_TEMPLATE 精簡 82%、Hook 健壯性修正、test-automation-engineer 重定位為「實作後補強」 |
| v4.3 | 2026-03-24 | 開發時間追蹤（每日/每任務）、`/time-log` 命令、StatusLine 時間持久化、17 Commands |
| v4.2 | 2026-03-16 | 跨平台支援（Windows/Linux）、MCP example 分平台、Agent 全 opus、移除 count_tokens.js |
| v4.1 | 2026-03-16 | 新增 rules(7)、skills(8)、MCP(+2)、開發流程文件 |
| v4.0 | 2026-03-16 | 全面升級：13 Agent、16 Commands、StatusLine 適配、模板精簡 68% |
| v3.0 | 2025-09-25 | TaskMaster Hub-and-Spoke 架構 |
