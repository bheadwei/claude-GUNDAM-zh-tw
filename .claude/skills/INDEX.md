# Skills 索引

17 個 skill，**按需載入**（不佔常駐 context）。分兩類：從 rules 移出的專案約定、以及原有的領域知識包。

## 常駐注入（唯一的例外）

| Skill | 用途 | 啟動時機 |
| :--- | :--- | :--- |
| **using-taskmaster** | 強制委派專業 agent 的命令 + Red Flags 反合理化表 + 路由表 + 動工前先讀坑 | **每個 session 由 `session-start.sh` 全文注入**，不需被想起來 |

這個 skill 反其道而行——它是**唯一**常駐的，因為它要解決的問題正好是「軟規則會被
忽略」：`rules/agent-orchestration.md` 寫「有專業 agent 就優先委派」，對撞 Claude Code
內建的「非必要不開 Agent」預設會輸。SessionStart 的 `additionalContext` 注入不會。

> 實證：`/tdd` 這類 slash command 能成功派 agent（command 本身算 skill，等於取得授權），
> 但自然語言輸入（「整理更新文件」）不會。這個 skill 就是補上那張授權。

## 擴充這個模板時

| Skill | 用途 | 啟動時機 |
| :--- | :--- | :--- |
| **writing-extensions** | 該做成 hook／rule／skill／command／agent 的決策表、`description` 怎麼寫才會被喚起、怎麼壓力測試驗證真的生效 | 要加或改 `.claude/` 底下任何東西之前；`/learn` 產 skill 前；某條 rule／skill 一直被忽略時 |

這個模板實際踩過**四次「選錯層」**（把該用 hook 的事寫成文字規則），
佔了歷次修補的大半。決策表就是為此存在。

## 專案約定（原本是常駐 rule，改為按需）

這些內容以前每個 session 都載入、互相稀釋；現在只在相關情境載入。

| Skill | 用途 | 啟動時機 |
| :--- | :--- | :--- |
| **testing-standards** | 覆蓋率門檻（依任務模式分級）、TDD 流程、測試反模式 | 寫/修測試、跑 `/tdd`、決定覆蓋率目標 |
| **plan-format** | plan 檔格式、命名、`files:` 欄、與 WBS 的職責分工 | `/plan`、`/tdd`、`/verify`、`/task-next`，或動 `plans/` 下的檔案 |
| **spec-convergence** | codebase／WBS 還符合當初規格嗎：漏做、範圍蔓延、描述失真三查，報告不自動改 PRD | 里程碑完成、`/verify pre-pr`、CR 累積、使用者問「還符合需求嗎」 |
| **worktree-orchestration** | worktree 的狀態隔離邊界、原生 `claude -w`、依序合併、清理判準 | `/task-next` 的平行開發、`/worktree`、派 `isolation: worktree` 的 agent 前 |
| **subagent-execution** | 逐階段派 implementer subagent 執行 plan：帳本、階段審查、有界修復迴圈、裁決而非停等 | `standard`/`critical` 且 plan 有 ≥2 階段時，由 `/tdd` 的「選執行方式」帶入 |
| **ui-style-compliance** | UI 三階段強制檢查（載入 DESIGN.md → 禁硬編碼 → 產出自檢）+ Pencil `.pen` 落地 `design/` | 寫任何前端頁面/元件、`/ui-site`、`/ui-page`、呼叫 pencil MCP 前 |
| **node-package-manager** | bun/pnpm/npm 由使用者決定，含指令對照與 lock 衝突處理 | 跑任何 npm/pnpm/bun 指令、動 package.json 或 lockfile 前 |
| **python-uv** | Python 一律 uv，禁 pip/poetry | 跑 Python 套件/環境指令、建 Python 專案骨架前 |

## 領域知識包

| Skill | 用途 | 啟動時機 |
| :--- | :--- | :--- |
| **project-docs** | 依 VibeCoding 範本產專案文件（20 種範本自帶於 skill 的 `templates/`），支援 demo/mvp/full 三檔深度 | `/docs-init` 觸發，或手動要求寫 PRD/架構/API 規格 |
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

## 什麼該做成 Skill、什麼不該

**判準不是「這個主題重要嗎」，是「模型缺的是知識還是可執行的模式」。**

### 不做 Skill（模型已經會，或有更好的來源）

| 主題 | 為什麼不用 |
|---|---|
| Python 語法、PEP 8、pytest 用法 | 模型內建知識 |
| React/Vue/Angular 的框架模式 | 用 **context7 MCP** 查當前版本的官方文檔，比寫死在 skill 裡不會過期 |
| REST／GraphQL 的通則 | 專案約定在 `rules/coding-style.md` |
| Docker、通用安全概念 | 見 `rules/security.md` |
| Claude API／SDK | 已是 **Claude Code 內建 skill** |

### 做 Skill（有具體到值得記下來的操作模式）

留著的七個領域包不是「主題重要」，是它們各自帶了**模型不會憑空產出的具體東西**：

| Skill | 帶的是什麼具體東西 |
|---|---|
| `project-docs` | 20 份 VibeCoding 範本的實際骨架與章節順序 |
| `database-migrations` | zero-downtime DDL 的實際步驟順序（先加欄位再回填再切換） |
| `postgres-patterns` | RLS 政策與索引選擇的實際語法，不是「該加索引」這種通則 |
| `e2e-testing` | Page Object Model 的實際結構與 flaky 處理策略 |
| `cost-aware-llm-pipeline` | 模型路由與預算追蹤的實作骨架 |
| `mcp-builder` | FastMCP／MCP SDK 的 server 骨架 |
| `deep-research` | 多源交叉驗證的流程（不是「去查資料」，是查完怎麼比對與引用） |

**它們的常駐成本接近零** —— skill 只有 `description` 進 context（七個合計 729 字元），
本體要被喚起才載入。所以「留著」的代價很小，而「移走後哪天需要要記得回備份池撈」
的代價比較大。

> 舊版本檔這一節只寫了「不需要 Skill 的場景」，論點是「模型內建知識夠了」，
> 卻同時留著六個領域包——讀起來像自相矛盾。實際上兩邊的判準不同，
> 上面兩張表把它講清楚了。

## 擴充方式

語言/框架特定的 skill 可從備份池按需複製：

```bash
cp -r ".claude/custom-rule&skill/skills/[skill-name]" .claude/skills/
```
