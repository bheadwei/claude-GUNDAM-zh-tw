---
description: 依開發情境產出規格文件（demo / mvp / full）。demo 產精簡 PRD；mvp 產單檔 Tech Spec；full 走 VibeCoding 完整流程
---

# 文件初始化

## 功能

依據開發情境產出對應深度的規格文件，作為 WBS 拆解與後續開發的基準。

**核心原則**：文件先行，WBS 從文件反推——避免「越做越發散」。

## 三種模式對照

| 模式 | 產出文件 | 存放位置 | 適用情境 |
|---|---|---|---|
| **demo** | 精簡 PRD（1 份） | `docs/prd.md` | 快速驗證想法、個人實驗、< 1 天 |
| **mvp** | Tech Spec（1 份合併 02+05+06+08） | `docs/tech-spec.md` | 內部工具、小型產品、< 1 週 |
| **full** | VibeCoding 完整文件集（多份編號檔） | `docs/01_prd.md`、`docs/02_bdd.md`… | 正式產品、跨團隊、> 1 週 |

**共通**：三種模式都會產出 PRD 與 WBS，差別在深度與文件數量。

---

## 何時觸發

- `/task-init` 依使用者選擇的情境自動呼叫（傳入 `--demo` / `--mvp` / `--full`）
- 使用者主動執行 `/docs-init` 互動選模式
- demo 做大了要升級：`/docs-init --mvp` 或 `/docs-init --full`
- 既有專案補文件：任何時候都能跑

---

## 執行流程

### 互動原則（CRITICAL）

**必須遵守 `.claude/rules/interactive-qa.md`**：

- 使用 `AskUserQuestion` 逐題詢問
- 記憶中收集問答，結束後一次性 Write 到 `.claude/qa-history/YYYY-MM-DD-HHMMSS-docs-init.md`

### 步驟 1：確認模式

若指令帶參數（`--demo` / `--mvp` / `--full`）→ 直接採用，跳到步驟 2。

若無參數 → 用 `AskUserQuestion` 問：

**題目：** 要產出哪種深度的文件？

| 選項 | 說明 |
|------|------|
| **demo** | 只產精簡 PRD（名稱/問題/使用者/核心功能/成功標準）。適合快速驗證 |
| **mvp (Recommended)** | 單檔 Tech Spec：PRD + 架構 + API + 結構。適合內部工具與小產品 |
| **full** | VibeCoding 完整 16 份文件集。適合正式產品 |

### 步驟 2：讀取既有上下文

從以下來源讀取已收集的專案資訊，避免重問：

1. `.claude/qa-history/YYYY-MM-DD-HHMMSS-task-init.md`（若由 `/task-init` 觸發）
2. `.claude/taskmaster-data/project.json`
3. 既有 `docs/` 下的檔案（若為升級模式）

若資訊不足，在步驟 3 依模式補問。

### 步驟 3：依模式產出文件

#### 路徑 A：demo 模式

**不額外問問題**——直接用 `/task-init` 步驟 2 收集到的答案產出精簡 PRD。

若獨立執行（非由 task-init 觸發），用 `AskUserQuestion` 補問：
1. 一句話描述這個 demo 要做什麼
2. 目標使用者是誰
3. 最重要的 3 個功能
4. 成功標準（用什麼判斷做出來了）

**產出**：`docs/prd.md`

```markdown
# PRD — {專案名稱}

**版本：** 0.1
**日期：** {YYYY-MM-DD}
**狀態：** draft
**模式：** demo

## 一句話描述

{摘要}

## 目標使用者

{誰會用、為什麼用}

## 核心功能

1. {功能 1}
2. {功能 2}
3. {功能 3}

## 成功標準

{如何判斷做出來了，量化優先}

## 技術約束

{若無，填「無特殊限制」}

## 備註

此為 demo 模式精簡 PRD。要擴展為完整文件請執行：
- `/docs-init --mvp`（升級為 Tech Spec）
- `/docs-init --full`（升級為完整 VibeCoding 文件集）
```

#### 路徑 B：mvp 模式

讀取 `VibeCoding_Workflow_Templates/02_project_brief_and_prd.md`、`05_architecture_and_design_document.md`、`06_api_design_specification.md`、`08_project_structure_guide.md` 的骨架，**取最小集合**合併為一份。

用 `AskUserQuestion` 補問（已從 task-init 取得的不重問）：
1. 關鍵 OKR 或成功指標（1-2 個量化數字）
2. 主要架構決策（單體/微服務、前後端分離等）
3. 核心 API 端點（3-5 個）
4. 資料模型雛形（實體與關係）

**產出**：`docs/tech-spec.md`

骨架：
```markdown
# Tech Spec — {專案名稱}

**版本：** 0.1 | **日期：** {YYYY-MM-DD} | **狀態：** draft | **模式：** mvp

## 1. 產品需求（來自 PRD 02）
- 問題陳述
- 目標使用者 & Personas（簡化）
- 核心功能
- 成功指標（OKR）

## 2. 架構總覽（來自 05）
- 系統 Context（C4 Level 1）
- 主要元件與職責
- 關鍵技術選型

## 3. API 設計（來自 06）
- 端點清單
- 資料格式約定

## 4. 專案結構（來自 08）
- 目錄配置
- 命名規範

## 5. 後續擴展

要升級為完整文件集請執行 `/docs-init --full`
```

#### 路徑 C：full 模式

依 VibeCoding 順序**依序產出**完整文件集。每份文件由 `project-docs` skill 處理：

```
02 PRD → 03 BDD → 04 ADR → 05 架構 → 06 API → 07 模組
  → 08 結構 → 09 設計與依賴 → 11 審查 → (12/17 前端) → 13 安全 → 14 部署 → 15 文檔
```

WBS（16）由本指令後續產出，不在 docs-init 階段產。

**產出檔名**：`docs/01_prd.md`、`docs/02_bdd.md`、`docs/03_adr.md`…（依階段編號，與 VibeCoding 範本編號對齊）

**執行方式**：
1. 讀 `VibeCoding_Workflow_Templates/INDEX.md` 確認階段順序
2. 依序呼叫 `project-docs` skill 處理每份
3. 每份完成後 `AskUserQuestion` 詢問「繼續產下一份？還是暫停？」
4. 使用者可隨時中斷，下次執行 `/docs-init --full --resume` 從上次進度接續

### 步驟 4：更新 project.json

Write `.claude/taskmaster-data/project.json`：

```json
{
  "name": "...",
  "mode": "demo" | "mvp" | "full",
  "docs": {
    "location": "docs/",
    "mode_produced": "demo" | "mvp" | "full",
    "files": ["prd.md"]  // 或 ["tech-spec.md"] 或 ["01_prd.md", "02_bdd.md", ...]
  },
  ...
}
```

### 步驟 5：完成提示

```
✅ 文件已產出（模式：{mode}）
   位置：docs/
   檔案：{列出產出的檔案}

下一步：
  /task-init 會接著產生 WBS（若由 task-init 呼叫）
  
  獨立執行時：
    閱讀 docs/ 下的文件 → 確認內容 → 執行 /task-next 開始開發
    或執行 /docs-init --{上一層模式} 升級文件深度
```

---

## 使用方式

```
/docs-init                 # 互動選模式
/docs-init --demo          # 精簡 PRD
/docs-init --mvp           # Tech Spec
/docs-init --full          # 完整文件集
/docs-init --full --resume # 接續中斷的完整模式
```

## 注意事項

- **不覆蓋既有文件**：若 `docs/prd.md` 已存在，先提示使用者是覆蓋、合併、還是取消
- **模式升級** 會**保留**既有文件，在其上補充（例：demo → mvp 會保留 `prd.md`，另產 `tech-spec.md`）
- **模式降級** 不支援（降級無意義；要從頭重來請手動刪除 docs/ 後重跑）
- 所有文件都遵循 VibeCoding 範本結構，不自創格式
