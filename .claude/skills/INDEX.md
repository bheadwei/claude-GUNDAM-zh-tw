# Skills 索引

12 個 skill，**按需載入**（不佔常駐 context）。分兩類：從 rules 移出的專案約定、以及原有的領域知識包。

## 專案約定（原本是常駐 rule，改為按需）

這些內容以前每個 session 都載入、互相稀釋；現在只在相關情境載入。

| Skill | 用途 | 啟動時機 |
| :--- | :--- | :--- |
| **testing-standards** | 覆蓋率門檻（依任務模式分級）、TDD 流程、測試反模式 | 寫/修測試、跑 `/tdd`、決定覆蓋率目標 |
| **plan-format** | plan 檔格式、命名、`files:` 欄、與 WBS 的職責分工 | `/plan`、`/tdd`、`/verify`、`/task-next`，或動 `plans/` 下的檔案 |
| **ui-style-compliance** | UI 三階段強制檢查（載入 DESIGN.md → 禁硬編碼 → 產出自檢）+ Pencil `.pen` 落地 `design/` | 寫任何前端頁面/元件、`/ui-site`、`/ui-page`、呼叫 pencil MCP 前 |
| **node-package-manager** | bun/pnpm/npm 由使用者決定，含指令對照與 lock 衝突處理 | 跑任何 npm/pnpm/bun 指令、動 package.json 或 lockfile 前 |
| **python-uv** | Python 一律 uv，禁 pip/poetry | 跑 Python 套件/環境指令、建 Python 專案骨架前 |

## 領域知識包

| Skill | 用途 | 啟動時機 |
| :--- | :--- | :--- |
| **project-docs** | 依 VibeCoding 範本產專案文件（21 種範本自帶於 skill 的 `templates/`），支援 demo/mvp/full 三檔深度 | `/docs-init` 觸發，或手動要求寫 PRD/架構/API 規格 |
| **deep-research** | 多源深度研究（MCP 串接） | 複雜問題調查 |
| **e2e-testing** | Playwright E2E 測試模式 | 測試關鍵使用者流程 |
| **cost-aware-llm-pipeline** | LLM API 成本優化（模型路由 + 預算追蹤） | 開發 AI 應用 |
| **mcp-builder** | MCP Server 開發指南（FastMCP / MCP SDK） | 串接外部 API 或服務 |
| **database-migrations** | DB Migration 安全模式（zero-downtime DDL） | Schema 變更、資料遷移 |
| **postgres-patterns** | PostgreSQL 速查表（Index、型態、RLS） | 寫 SQL、設計 Schema |

## 為什麼 rule 要搬成 skill

常駐 rule 的成本是**注意力稀釋**，不只是 token：15 條規則全量載入時，
「只在特定情境才該生效」的規則會被淹沒（`task-mode.md` 的入口自動分級就是這樣失效的）。

搬成 skill 的代價是「要被想起來才會載入」，所以每個 skill 的 `description`
都寫成**觸發條件導向**（"MUST BE USED before …"），而不是內容摘要。
UI 與 Node 兩類另有 `user-prompt-submit.sh` 的關鍵字提示當第二層保險。

## 不需要 Skill 的場景

以下知識模型已內建：

- Python 語法、PEP 8、pytest → 模型內建知識
- React/Vue/Angular 前端模式 → 用 **context7 MCP** 查最新文檔
- REST API / GraphQL 後端模式 → 專案約定見 `rules/coding-style.md`
- Docker / 通用安全 → 見 `rules/security.md`
- Claude API / SDK → 已是 **Claude Code 內建 skill**

## 擴充方式

語言/框架特定的 skill 可從備份池按需複製：

```bash
cp -r ".claude/custom-rule&skill/skills/[skill-name]" .claude/skills/
```
