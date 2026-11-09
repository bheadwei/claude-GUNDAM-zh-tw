---
description: Use when 要產專案文件初稿（「寫 PRD」「補架構文件」「先把需求寫下來」），或舊專案要補文件、`docs/` 已有一堆舊文件不知道怎麼收（先問要不要盤點）。依 demo / mvp / full 決定先產哪幾份：demo 只有 brief；mvp 加 PRD 與架構文件；full 再依專案特性加威脅模型、runbook
---

# 文件初始化

## 功能

依開發情境產出專案文件的初稿，作為 WBS 拆解與後續開發的基準。

一個專案只有 6 份文件（brief、PRD、架構文件、WBS、plan、ADR），各份回答什麼、不寫什麼，
唯一來源是 `.claude/skills/project-docs/SKILL.md`。本指令只決定**先產哪幾份、照什麼順序產**。

**核心原則**：文件先行，WBS 從文件反推——避免「越做越發散」。

## 三種模式對照

| 模式 | 先產 | 適用情境 |
|---|---|---|
| **demo** | `docs/00_brief.md`（PRD 等第一條情境出現才建；不產架構文件） | 快速驗證想法、個人實驗、< 1 天 |
| **mvp** | `docs/00_brief.md`、`docs/prd.md`、`docs/architecture.md` | 內部工具、小型產品、< 1 週 |
| **full** | 同 mvp；碰到認證、金流、個資時加 `docs/threat-model.md`；詢問要不要 `docs/runbook.md` | 正式產品、跨團隊、> 1 週 |

WBS 三種模式都有，由 `/task-init` 寫進 `.claude/taskmaster-data/wbs.md`；plan 與 ADR 在開發中產生，不在這裡產。

---

## 何時觸發

- `/task-init` 依使用者選擇的情境自動呼叫（傳入 `--demo` / `--mvp` / `--full`）
- 使用者主動執行 `/docs-init` 互動選模式
- demo 做大了要升級：`/docs-init --mvp` 或 `/docs-init --full`
- 既有專案補文件：任何時候都能跑；舊文件多時第一題問要不要先盤點（步驟 1a）

---

## 執行流程

### 互動原則（CRITICAL）

**必須遵守 `.claude/rules/interactive-qa.md`**：

- 使用 `AskUserQuestion` 逐題詢問
- 記憶中收集問答，結束後一次性 Write 到 `.claude/qa-history/YYYY-MM-DD-HHMMSS-docs-init.md`

### 步驟 1：偵測既有文件，再確認模式

#### 1a. 既有文件多 → 先問要不要盤點

不管有沒有帶參數都先算一次「不是 6 份之一」的 md：

```bash
git -c core.quotepath=false ls-files 'docs/*.md' \
  | grep -Ev '^docs/(00_brief|prd|architecture|threat-model|runbook)\.md$|^docs/(decisions|archive)/|^docs/1[27]_'
```

（`docs/archive/` 是盤點後封存的去處，`docs/12_*`、`docs/17_*` 由 `/ui-site` 產生，都不算。
`core.quotepath=false` 不能省：預設會把中文檔名輸出成 `"docs/\344…"`，`^docs/` 就對不上。）

不是 git repo 或清單為空 → 不問，直接進 1c。

這份清單有 **5 份以上**，或沒有 `docs/00_brief.md` 而清單至少 1 份 → 視為既有專案，用 `AskUserQuestion` 問第一題：

**題目：** `docs/` 已經有 N 份不在 6 份文件體系裡的文件，要先盤點嗎？

| 選項 | 說明 |
|------|------|
| **先盤點 (Recommended)** | 派 `documentation-specialist` 讀每份開頭、分類，產報告到 `.claude/context/docs/`。**盤點只產報告、不改 `docs/`**；搬不搬檔看完報告再逐批決定 |
| **直接產文件** | 跳過盤點，照下方「確認模式」產新文件；舊文件原樣留著 |

清單不到門檻 → 不問，直接進「確認模式」。

#### 1b. 盤點分支（選了「先盤點」才走）

1. 派 `documentation-specialist`（`subagent_type: "documentation-specialist"`），prompt 寫「盤點既有文件」。
   它回 `DONE` 與報告路徑 `.claude/context/docs/docs-inventory-<日期>.md`；此時 `git status` 不該有任何 `docs/` 的變更
2. 把報告的 TL;DR 與各類檔數回述給使用者
3. **逐批搬檔**：報告的「搬移批次」一批一題。先列出這批的檔案，再用 `AskUserQuestion` 問「第 N 批（<類>，k 檔）搬到 `docs/archive/`？」：
   搬（Recommended）／跳過這批／停在這裡。選「搬」：
   - `git mv` 每個檔到 `docs/archive/<原本在 docs/ 底下的相對路徑>`；目標已存在 → 跳過該檔並告知使用者，不覆蓋
   - `rg` 找 repo 內指向舊路徑的連結，改成新路徑。**不含「現行，模板外」那類的檔**：交付物裡的舊連結列給使用者，不改
   - 一批一個 commit：`docs: 封存舊文件第 N 批（<類>）`，commit 裡只有 rename 與連結修正
4. 不搬「現行，模板外」那類（交付物一個字都不改），**任何情況都不刪除檔案**
5. **內容轉換是另一題**：搬完（或停下）後問「要從報告的『併入』類起草新格式的文件嗎？」：
   起草（Recommended）／先不用。選「起草」→ 往下走「確認模式」，步驟 2 起把併入類的檔當草稿來源，每份照原步驟逐段讓使用者確認才寫；
   單檔多條 ADR 拆成一條一檔用 `/adr`。選「先不用」→ 跳到步驟 8，提示之後再跑 `/docs-init`

#### 1c. 確認模式

若指令帶參數（`--demo` / `--mvp` / `--full`）→ 直接採用，跳到步驟 2。

若無參數 → 用 `AskUserQuestion` 問：

**題目：** 要先產哪幾份文件？

| 選項 | 說明 |
|------|------|
| **demo** | 只產 brief。適合快速驗證；PRD 等第一條情境出現才建 |
| **mvp (Recommended)** | brief＋PRD＋架構文件。適合內部工具與小產品 |
| **full** | 同 mvp，再依專案特性加威脅模型、runbook。適合正式產品 |

### 步驟 2：讀取既有上下文

從以下來源讀取已收集的專案資訊，避免重問：

0. **`docs/00_brief.md`（優先，若存在）** —— `/task-init` 步驟 2.7 產出且**已由使用者逐段確認**的需求 brief。
   **有 brief 就不要再問它已經涵蓋的問題。**
   - 特別注意 brief 的「**仍未釐清**」段：那些是使用者當時說「還不確定」的事。
     產文件時**不要自己填答案**——寫進該文件的「待確認」
1. `.claude/qa-history/YYYY-MM-DD-HHMMSS-task-init.md`（若由 `/task-init` 觸發，或 brief 不存在時的退路）
2. `.claude/taskmaster-data/project.json`
3. 既有 `docs/` 下的檔案（若為升級模式）；走過 1b 的「起草」時，讀最新一份 `docs-inventory-*.md` 的「併入」類（已封存的到 `docs/archive/` 找）

### 步驟 3：brief（三種模式都有）

`docs/00_brief.md` 已存在 → 直接用，進步驟 4。

不存在 → 照 `.claude/skills/project-docs/templates/02_project_brief_and_prd.md` 的**上半**產（唯一來源，勿在此重述骨架）。
骨架裡缺的段用 `AskUserQuestion` 一題一題補問（由 `/task-init` 觸發時直接用它的問答），寫完逐段回述給使用者確認。

**demo 到這裡結束**，跳到步驟 7。demo 沒有架構文件，WBS 的模組欄一律 `—`。
使用者要求在 demo 就先建一份架構文件時，照步驟 5 建，但第 5 節只放 `## 5. 資料流` 標題與「尚無」一行，不畫圖。

### 步驟 4：PRD 初稿（mvp／full）

照 02 範本的**下半**產 `docs/prd.md`（格式的唯一來源）：

1. 從 brief 的「核心功能」切出**領域**（一組相關的功能）。節標題括號寫模組分組名；還沒有程式碼時分組名先由這裡定，之後架構文件與專案地圖照用同一個名字
2. 先寫**用語表**：brief 與問答裡出現的業務名詞，各寫一句意思與「不要說成」
3. 每個領域先寫 **1–3 條情境**（`#### <代碼>-<序號> 標題`＋假設／當／那麼），只寫使用者看得到的行為，不寫實作、路徑、API 端點
4. 不確定的寫進「待確認」一節，不要替使用者填答案
5. **逐領域回述**，用 `AskUserQuestion` 問「這個領域的情境對嗎？」：對（Recommended）／要改（直接輸入要改的地方）

PRD 寫好之後只由 `/verify` 依 plan 的「PRD 情境變更」套回，不手寫進度。

### 步驟 5：架構文件（mvp／full）

照 `.claude/skills/project-docs/templates/05_architecture_and_design_document.md` 產 `docs/architecture.md`
（節的寫法、標記字串、「不寫什麼」都以範本為唯一來源，不在這裡重述或內嵌表格）。
第 1–3、5 節由 architect 撰寫；第 4 節由專案地圖從程式碼自動產生。

- **第 1–3 節（系統情境、技術選型、部署）由 architect 撰寫**：委派 `architect`（`subagent_type: "architect"`），或主模型照範本寫。
  資訊來自 brief 的技術約束與問答；技術選型每列要連到 ADR，還沒有 ADR 的標 `[待確認]`，並提示之後用 `/adr` 補
- **第 4 節（模組與依賴）自動產生**：照範本放兩行標記與標記內那一行說明，其餘留空，第一次 `/task-status` 時由專案地圖從程式碼填上。**不要手寫模組表**
- **第 5 節（資料流）由 architect 撰寫**：依 PRD 的領域，為跨服務的主要功能各畫一張 `sequenceDiagram`，小標題括號寫對應的 PRD 情境編號。
  系統只有一個服務、也不連外部系統 → 寫「無跨服務或跨系統的流程」，節保留

寫好後把 architect 撰寫的各節重點回述給使用者，用 `AskUserQuestion` 確認：對（Recommended）／要改（直接輸入要改的地方）。

### 步驟 6：條件式文件（full）

- **威脅模型**：brief 或 PRD 碰到認證、金流、個資 → **必產** `docs/threat-model.md`（`20_threat_model_template.md`），不另外問
- **runbook**：用 `AskUserQuestion` 問「這個專案會上線並持續維運嗎？」
  - 上線前再補（Recommended）— 現在還沒有部署可寫
  - 現在就產 — 照 `14_deployment_and_operations_guide.md` 產 `docs/runbook.md`，沒有的節直接刪

### 步驟 7：更新 project.json

Write `.claude/taskmaster-data/project.json`：

```json
{
  "name": "...",
  "mode": "mvp",
  "docs": {
    "location": "docs/",
    "set": ["00_brief.md", "prd.md", "architecture.md"]
  }
}
```

- `mode` 只准 `demo`、`mvp`、`full` 三個值
- `docs.set` 列實際產出的檔（相對 `docs/`），沒產的不列；升級模式時把新產的加進去
- 既有專案的 `docs.files`、`docs.mode_produced` 不用刪，也不再更新

### 步驟 8：完成提示

```
✅ 文件已產出（模式：{mode}）
   檔案：{列出 docs.set}

下一步：
  /task-init 會接著產生 WBS（若由 task-init 呼叫）

  獨立執行時：
    閱讀 docs/ 下的文件 → 確認內容 → 執行 /task-next 開始開發
    或執行 /docs-init --{上一層模式} 補齊文件
```

---

## 使用方式

```
/docs-init                 # 互動選模式
/docs-init --demo          # 只產 brief
/docs-init --mvp           # brief＋PRD＋架構文件
/docs-init --full          # 同 mvp，再加條件式文件
```

## 注意事項

- **不覆蓋既有文件**：要產的檔已存在時，先問使用者是覆蓋、合併、還是取消
- **模式升級**保留既有文件，只補缺的（例：demo → mvp 保留 brief，補 PRD 與架構文件）
- **模式降級**不支援（降級無意義；要從頭重來請手動刪除 docs/ 後重跑）
- 文件格式一律照 `project-docs` skill 的範本，不自創格式、不在本檔內嵌骨架
