---
name: project-docs
description: 依據 VibeCoding 工作流範本撰寫專案文件。涵蓋 PRD、架構設計、ADR、API 規範、WBS 等 16 種文件範本，支援完整流程與 MVP 兩種模式。適用於需要產出專案文件、規劃文檔或技術規格時。
---

# 專案文件撰寫

依據 `VibeCoding_Workflow_Templates/` 中的 16 種範本，產出結構化的專案文件。

## 啟動時機

- 使用者要求撰寫專案文件（PRD、架構文件、API 規格等）
- 使用者說「寫文件」、「產出文檔」、「建立 PRD」、「架構設計」、「API 規範」
- `/task-init` 完成後進入文件撰寫階段
- 使用者提到 VibeCoding 範本或文件編號（如「幫我寫 05」）

## 範本清單與選擇

### 階段對照表

| 階段 | 編號 | 範本 | 用途 | 適用模式 |
|:---|:---|:---|:---|:---|
| **規劃** | 02 | `project_brief_and_prd.md` | PRD（含 OKRs、Personas、競爭分析） | 完整+MVP |
| | 03 | `behavior_driven_development_guide.md` | BDD 指南與 Gherkin | 完整 |
| **架構** | 04 | `architecture_decision_record_template.md` | ADR 決策紀錄 | 完整+MVP |
| | 05 | `architecture_and_design_document.md` | 架構設計（C4/DDD） | 完整 |
| | 06 | `api_design_specification.md` | API 設計規範 | 完整+MVP |
| **詳設** | 07 | `module_specification_and_tests.md` | 模組規格與測試（含效能邊界、實際範例） | 完整 |
| | 08 | `project_structure_guide.md` | 專案結構指南 | 完整+MVP |
| | 09 | `design_and_dependencies.md` | 設計與依賴（類別圖、分層、SOLID） | 完整 |
| **開發** | 11 | `code_review_and_refactoring_guide.md` | 程式碼審查（嚴重等級、PR 範本） | 完整 |
| | 12 | `frontend_architecture_specification.md` | 前端架構規範 | 完整 |
| | 17 | `frontend_information_architecture_template.md` | 前端資訊架構 | 完整 |
| **安全部署** | 13 | `security_and_readiness_checklists.md` | 安全與上線檢查 | 完整+MVP(簡化) |
| | 14 | `deployment_and_operations_guide.md` | 部署與運維指南 | 完整 |
| **管理** | 15 | `documentation_and_maintenance_guide.md` | 文檔維護指南 | 完整 |
| | 16 | `wbs_development_plan_template.md` | WBS 開發計畫 | 完整+MVP |

### 模式選擇邏輯

**完整流程**（依序產出）：涉及金流/法遵/隱私、高可用規模化、跨 3+ 團隊
```
02 PRD → 03 BDD → 04 ADR + 05 架構 → 06 API + 07 模組 → 08 結構 + 09 設計與依賴 → 11 審查 + 12/17 前端 → 13 安全 → 14 部署 → 15 文檔 + 16 WBS
```

**MVP 快速迭代**（合併為 Tech Spec）：快速驗證、時間有限
- 一份文件合併 02+05+06+08 的最小集合
- 必要時單獨補 04 ADR 和 13 安全檢查

## 工作流程

### 步驟 1：確認需求

用 `AskUserQuestion` 確認：
1. **要寫哪份文件？** — 提供編號或描述，推薦依階段順序
2. **完整模式還是 MVP？** — 若尚未決定，依專案特性建議

### 步驟 2：讀取範本

```
Read VibeCoding_Workflow_Templates/[編號]_[名稱].md
```

取得該範本的完整結構，作為產出骨架。

### 步驟 3：收集專案資訊

依範本欄位，逐項向使用者收集：
- 用 `AskUserQuestion` 一次問 1-2 個關鍵欄位
- 能從程式碼或既有文件推斷的，先讀取再確認
- 標記 `[待填]` 的欄位讓使用者後續補充

### 步驟 4：撰寫文件

- 嚴格遵循範本結構（標題、表格、欄位順序）
- 填入收集到的專案資訊
- 保留範本中的 Mermaid 圖框架，填入實際內容
- 輸出到 `docs/` 目錄，檔名沿用範本編號

### 步驟 5：交叉參照

撰寫時自動檢查：
- PRD (02) 的 User Story ID 與 OKR → 是否在架構 (05) 中被引用
- ADR (04) 編號 → 是否在技術選型表中對應
- API (06) 端點 → 是否在模組規格 (07) 中有對應
- 設計與依賴 (09) 的介面契約 → 是否在模組 (07) 中有測試覆蓋
- 發現不一致時提醒使用者

## 品質規則

1. **範本結構不可任意刪減** — 可以標 `N/A` 但不能跳過章節
2. **每個決策都要理由** — ADR 的「選擇理由」不能空白
3. **量化優於描述** — OKR 用數字、NFR 用目標值、工時用小時
4. **連結相關文件** — 用相對路徑連結其他文件（如 `→ 詳見 06_api_design_specification.md`）
5. **版本與狀態必填** — 每份文件頂部的版本、日期、狀態三欄位
6. **遵循互動問答規則** — 收集資訊時使用 `AskUserQuestion`，記錄到 `.claude/qa-history/`

## 角色對應

根據使用者角色推薦重點範本：

| 角色 | 優先範本 |
|:---|:---|
| PM / PO | 02 PRD、03 BDD、16 WBS |
| Tech Lead | 04 ADR、05 架構、06 API、11 審查 |
| 架構師 | 05 架構、09 設計與依賴 |
| 後端工程師 | 06 API、07 模組、08 結構 |
| 前端工程師 | 12 前端架構、17 資訊架構 |
| 安全工程師 | 13 安全檢查 |
| SRE / DevOps | 14 部署運維 |
