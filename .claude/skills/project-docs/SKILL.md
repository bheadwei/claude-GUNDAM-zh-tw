---
name: project-docs
description: Use when writing or updating a project document — 「寫 PRD」「補架構文件」「寫 ADR」「要不要寫威脅模型／runbook」「API 規格放哪」「文件要寫哪幾份」，running /docs-init or /task-init 2.7b, or before creating any new file under docs/. 決定這份內容屬於 6 份文件的哪一份、該照哪份範本、哪些東西不該寫進去；demo／mvp／full 只決定先產哪幾份。
---

# 專案文件

**一個專案只有 6 份文件**，每份回答一個問題、有固定路徑。5 種範本放在本 skill 的 `templates/`，隨 `.claude/` 一起更新。
決策依據：ADR-2026-11-05-004（6 份文件）、005（PRD 情境）、006（plan）、007（架構文件自動段）、ADR-2026-11-06-001（資料流）。

## 6 份文件

| 文件 | 路徑 | 回答什麼 | 誰寫、何時更新 | 格式來源 |
|---|---|---|---|---|
| brief | `docs/00_brief.md` | 為什麼做、範圍上限、不做什麼、怎樣算成功 | `/task-init` 2.7b 產、使用者逐段確認；方向改變時改 | 02 範本上半 |
| PRD | `docs/prd.md` | 系統該有什麼行為（編號情境）、用語 | `/docs-init` 產初稿；之後只由 `/verify` 依 plan 的「PRD 情境變更」套回 | 02 範本下半 |
| 架構文件 | `docs/architecture.md` | 跟誰連、用什麼、怎麼部署；模組與依賴；跨服務的資料流 | 第 1–3、5 節由 `architect` 撰寫；第 4 節由專案地圖從程式碼自動產生 | 05 範本 |
| WBS | `.claude/taskmaster-data/wbs.md` | 做到哪、誰負責、下一個 | `/task-init`、`/task-add`、`/verify` | `.claude/templates/wbs.template.md` |
| plan | `.claude/taskmaster-data/plans/*.md` | 這次為什麼做、怎麼做、改善了什麼 | `planner`、`/tdd`、`/verify`；完成即歸檔 | `plan-format` skill |
| ADR | `docs/decisions/ADR-*.md` | 為什麼這樣設計 | `architect`、`/adr`；接受後只改 status | 04 範本 |

**按條件才有**（不算常駐）：

| 文件 | 路徑 | 何時要 | 格式來源 |
|---|---|---|---|
| 威脅模型 | `docs/threat-model.md` | critical 任務碰到認證、金流、個資時**必產** | 20 範本 |
| runbook | `docs/runbook.md` | 會上線並持續維運時（選配），由 `deployment-expert` 維護 | 14 範本 |

**不算文件體系**：

- 專案地圖與一頁現況（`/task-status`）是產生物，不進 git
- `README.md`、`CLAUDE.md` 是入口。6 份文件的位置寫在 CLAUDE.md 的「文件在哪」，**不另寫手寫索引**（`docs/README.md` 這種索引最先腐爛）
- 交付物、對外手冊、評測紀錄、匯出檔是使用者自己的，模板不管、不檢查
- `docs/12_*`、`docs/17_*` 由 `/ui-site` 產生（12、17 範本），路徑不動

## 每份不寫什麼

同一件事寫在兩處就會漂開。寫之前先查這張表：

| 內容 | 唯一來源 | 其他文件怎麼寫 |
|---|---|---|
| 產品方向、不做什麼 | brief | PRD、plan 不重述 |
| 系統行為 | PRD 情境（已完成的）／plan 的「PRD 情境變更」（進行中的） | 驗收句寫情境編號 |
| 設計理由 | ADR | plan 的「發現與決策」只記本變更內的小決策 |
| 做法、階段 | plan | WBS 不寫 |
| 任務狀態、負責 | WBS | plan 只有 `wbs_task` |
| 模組、依賴、路由數 | 程式碼（架構文件第 4 節自動段、專案地圖） | 不手寫 |
| 跨服務的資料流 | 架構文件第 5 節 | plan 只寫「資料流變更」一句，不貼整張圖 |
| 用語 | PRD 用語表 | 其他文件與程式命名照用 |
| API 欄位與端點 | 程式碼與框架產生的 OpenAPI | 不另寫 API 規格文件（設計準則見 `api-design` skill） |

各範本自己也有一張「不寫什麼」表，寫那份文件時照它。

## demo／mvp／full 只決定先產哪幾份

| 模式 | `/docs-init` 先產 |
|---|---|
| demo | brief、WBS（PRD 等第一條情境出現才建；不產架構文件） |
| mvp | brief、PRD、架構文件、WBS |
| full | 同 mvp；碰到認證、金流、個資時加威脅模型；詢問要不要 runbook |

不再產 `tech-spec.md` 與編號文件序列。舊專案的 `docs/tech-spec.md`、`docs/01_prd.md` 仍會被讀（專案地圖找架構文件、`spec-convergence` 找 PRD 都有退路），但不再新增。

## 怎麼寫

1. **先讀範本**：`.claude/skills/project-docs/templates/<編號>_*.md`。範本的節、寫法、「不寫什麼」是唯一來源，不要憑記憶重打
2. **能從程式碼或既有文件推斷的先讀再確認**；問使用者時照 `rules/interactive-qa.md`（一次一題）
3. **只寫程式碼看不出來的事**。會過期的東西（模組清單、依賴圖、計數、進度）不手寫
4. **不替使用者填答案**：不確定的寫進該文件的「待確認」或 brief 的「仍未釐清」，不要編
5. **引用而不複製**：跨文件寫路徑、情境編號（`ORD-02`）、ADR 編號；不把別份的內容抄過來
6. **架構文件第 4 節不要手改**：標記 `<!-- overview:generated:start -->`／`<!-- overview:generated:end -->` 之間由 `overview.sh --sync-arch` 改寫；改模組名稱或分組改 `.claude/taskmaster-data/module-notes.md`

## 範本

| # | 範本 | 用在 |
|---|---|---|
| 02 | `project_brief_and_prd.md` | brief（上半）、PRD（下半） |
| 04 | `architecture_decision_record_template.md` | ADR（簡易版給 `/adr`、完整版給 `architect`） |
| 05 | `architecture_and_design_document.md` | 架構文件 |
| 14 | `deployment_and_operations_guide.md` | runbook |
| 20 | `threat_model_template.md` | 威脅模型 |

另有 UI 鏈的 12、17，由 `/ui-site` 使用。清單與產出路徑見 `templates/INDEX.md`。

## 淘汰的範本

01、03、06、07、08、09、11、13、15、16、18、19、21 已移除。`update-template` 不會刪掉既有專案裡的舊檔，它們只是不再被引用。
想找它們原本的內容時的去處：

| 原本 | 現在 |
|---|---|
| 01 流程手冊 | `.claude/guides/WORKFLOW.md` |
| 03 BDD、07 模組規格與測試 | PRD 的情境（假設／當／那麼）＋`testing-standards` skill |
| 06 API 規格 | `api-design` skill（準則）＋框架產生的 OpenAPI |
| 08 專案結構、09 設計與依賴 | 架構文件第 4 節自動段＋專案地圖 |
| 11 Code Review | `code-quality-specialist` agent |
| 13 安全檢查 | `rules/security.md`＋`security-infrastructure-auditor` agent |
| 15 文件維護 | 本 skill |
| 16 WBS 開發計畫 | brief（範圍上限）＋`.claude/templates/wbs.template.md` |
| 18 資料模型與 migration | `database-migrations` skill |
| 19 可觀測性與 SLO | runbook 的「SLO 與告警」節 |
| 21 AI／LLM 整合 | PRD 的領域情境＋`cost-aware-llm-pipeline` skill |
