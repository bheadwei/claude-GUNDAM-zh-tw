---
status: 已採納
date: 2026-11-05
decision-makers: [使用者]
---

# ADR-2026-11-05-004: 專案文件收成 6 份（brief、PRD、架構文件、WBS、plan、ADR），範本跟著收斂，`workflow-template-manager` 退場

## 背景

模板的 `project-docs` 有 20 份範本，分 demo／mvp／full 三種深度，full 會產出十幾份編號文件。
盤點兩個用這套模板的實際專案（匿名為 A、B）：

| | A | B |
|---|---|---|
| `docs/` 的 md | 85 份／27,554 行 | 75 份／26,808 行 |
| 失效路徑 | 6%，集中在入口索引 | 13%，主架構文件就有 9 處 |
| 同一主題的成品 | 評測報告 32 檔、分兩處 | API 文件 8 份、端點數有 5 種寫法 |
| ADR | 分兩處、兩套編號 | 分兩處、兩套編號 |

使用者的判斷：文件太多太冗、沒反映專案真實狀態、沒有一眼看懂的總覽；專案地圖在兩個專案畫不出來，
原因是架構文件不是真實狀態。開發流程（task-init → task-next → plan → tdd → verify → pr）不變。
那麼一個專案該有哪幾份文件、範本要留哪些？

## 決策

**文件只有 6 份**，路徑固定（程式與指令找得到）：

| 文件 | 路徑 | 回答什麼 | 誰寫、何時更新 |
|---|---|---|---|
| brief | `docs/00_brief.md` | 為什麼做、範圍上限、不做什麼、怎樣算成功 | `/task-init` 2.7b 產、使用者逐段確認；方向改變時改 |
| PRD | `docs/prd.md` | 系統該有什麼行為（編號情境）、用語 | `/docs-init` 產初稿；之後**只由 `/verify` 依 plan 的情境變更套回**（ADR-005） |
| 架構文件 | `docs/architecture.md` | 系統跟誰連、用什麼技術、怎麼部署；模組與依賴 | 人寫三節＋地圖資料自動產生一段（ADR-007） |
| WBS | `.claude/taskmaster-data/wbs.md` | 做到哪、誰負責、下一個 | 既有指令，版面不變 |
| plan | `.claude/taskmaster-data/plans/` | 這次為什麼做、怎麼做、改善了什麼 | planner／`/tdd`／`/verify`，四段格式（ADR-006） |
| ADR | `docs/decisions/ADR-*.md` | 為什麼這樣設計 | `architect`、`/adr`；**唯一的家**，簡易版與完整版都放這裡 |

另外兩份**按條件才有**，不算常駐：`docs/threat-model.md`（critical 任務碰到認證、金流、個資時必產）、
`docs/runbook.md`（會上線並持續維運時，選配）。

**6 份以外的檔案模板不管**：交付物、評測紀錄、匯出檔留在使用者自己的位置，不受任何檢查；
既有專案的舊文件怎麼收斂見 ADR-008。`README.md`、`CLAUDE.md` 是入口，不算文件體系的一份。

**demo／mvp／full 只決定 `/docs-init` 先產哪幾份**：demo 只有 brief＋WBS（PRD 等第一條情境出現才建）；
mvp、full 產 brief、PRD、架構文件、WBS；full 碰到認證、金流、個資時加威脅模型。不再產 `tech-spec.md` 與編號文件序列。

**範本**（`project-docs/templates/`）：

| 範本 | 處置 |
|---|---|
| 02 `project_brief_and_prd.md` | **改寫**：上半 brief 骨架（`/task-init` 2.7b 改成指向它，唯一來源）、下半 PRD 骨架（ADR-005 的格式）。檔名不變 |
| 04 ADR | 保留；落點改成兩版都寫 `docs/decisions/` |
| 05 架構 | **改寫**：人寫三節（系統情境、技術選型、部署）＋自動產生段的固定標記（ADR-007）。檔名不變 |
| 20 威脅模型 | 保留（critical 用） |
| 14 部署與運維 | **精簡**成 runbook（選配），吸收 19 的 SLO 要點 |
| 12、17 前端 | 不動：屬 `/ui-site` 的產物，`ui-lint.sh` 讀 `docs/17_*`，不算文件體系 |
| 01、03、06、07、08、09、11、13、15、16、18、19、21 | **淘汰** |

plan 沒有範本檔，格式的唯一來源是 `plan-format` skill；WBS 的版面是 `.claude/templates/wbs.template.md`。

**`workflow-template-manager` 退場**。理由：
1. 它的知識庫是「21 份範本／8 個階段」，收斂後只剩 5 份範本、沒有階段序列，定義裡的內容幾乎全部失效
2. 「套用哪份範本」由 `/docs-init` 依 demo／mvp／full 決定，「怎麼寫」在 `project-docs` skill，「什麼時候更新」寫在各指令裡——它沒有剩下的職責
3. 它沒有 Bash、Glob，做不了舊文件盤點（ADR-008 由 `documentation-specialist` 做）
4. 留著會讓路由表多一個沒事做的選項

## 替代方案

| 方案 | 優點 | 否決理由 |
|---|---|---|
| 維持現狀（20 份範本、三種深度） | 不用改；full 涵蓋面最完整 | A、B 證實會長出 75–85 份、6–13% 死連結、同一數字多種版本 |
| brief 取代 PRD、行為寫在按領域拆的 `docs/specs/` | 每份規格短 | 人要翻好幾個檔才看得懂系統做什麼；使用者要的是「人看得懂的一份 PRD」 |
| 架構文件淘汰、由專案地圖取代 | 少一份要維護的文件 | 客戶需要一份可交付的架構文件；地圖不進 git、不能交付 |
| 按需文件再加對外手冊、CHANGELOG 與生命週期資料夾（deliverables／records／archive） | 交付物有固定的家 | 又長回十幾種位置與規則；交付物是使用者自己的事，模板管好 6 份就好 |
| 保留 `workflow-template-manager`、改寫成管 5 份範本 | 不動路由表 | 5 份範本由一個 skill 和一個指令就管得了，多一個 agent 只多一次委派 |

## 後果

**得到：**
- 新專案最多 6 份文件（加條件式 2 份），新人知道該讀哪幾份、各回答什麼
- ADR 只有一個家、一套編號
- 範本從 20 份剩 5 份（另有 UI 鏈 2 份不在體系內）

**犧牲：**
- PRD 的 OKR、Personas、競品分析，API 規格、模組規格、資料模型文件不再是預設產物；需要的團隊自己寫在 6 份以外，模板不管
- 13 份範本淘汰、1 個 agent 退場，引用它們的指令、agent、`check-counts.sh`、`agent-orchestration.md` 的 8＋1＋1＋4 計數、`using-taskmaster` 路由表都要一起改；三個既有 hook（`user-prompt-submit.sh` 的關鍵字路由、`lib/agent-inflight.sh` 的唯讀名單、`pre-agent-gate.sh` 的註解）要刪改它的名字——只改字串，不新增 hook
- 模板 repo 自己沒有 `docs/`，它的 ADR 仍放 `.claude/context/decisions/`（由模板 repo 的 CLAUDE.md 註明這個例外）

**何時該重新考慮：**
- 多數專案在 6 份以外又自己長出同一種文件（例如 API 規格）→ 那一種該收進體系
- 多數專案的 `docs/architecture.md` 人寫部分一直是空的 → 架構文件可以降為選配

## 確認方式

- [C] `check-counts.sh`：`project-docs/templates/` 的範本數與各處寫的數字一致；淘汰範本的檔名在 `.claude/` 沒有殘留引用（`docs/12_*`、`docs/17_*` 除外）；agent 數少 1
- [M] 用 `/task-init` 開一個 mvp 新專案，`docs/` 底下只有 `00_brief.md`、`prd.md`、`architecture.md`
- [M] 改了 `using-taskmaster` 之後跑一輪 `skill-compliance`（CLAUDE.md 規定）

## 相關

- 設計提案：`.claude/context/decisions/architect-2026-11-05-1730.md` 第 2、3、5 節
- 相關：ADR-2026-11-05-005（PRD）、006（plan）、007（架構文件自動段）、008（舊文件盤點）
- 部分取代：`04_architecture_decision_record_template.md` 的「簡易版落點 `.claude/context/decisions/`」——改為兩版都寫進 `docs/decisions/`
