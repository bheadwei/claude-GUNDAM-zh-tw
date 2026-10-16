---
name: ui-style-compliance
description: UI/前端產出前後的強制風格檢查（調度器）—— 載入專案選定的 DESIGN.md、禁止硬編碼色票/散亂間距、反 AI slop、產出後附合規自檢；另含 Pencil MCP 設計稿必須落在 design/ 的規則。MUST BE USED before writing any frontend page or component code (React/Vue/Svelte/HTML/Tailwind/CSS), before running /ui-site or /ui-page, and before calling any pencil MCP tool.
---

# UI/UX 設計風格（調度器 + 強制檢查）

本 skill 是 UI 風格的**調度器**與**檢查器**。實際風格規範由選定的設計系統提供
（`.claude/ui/<codename>/DESIGN.md`），本 skill 強制執行前中後三階段檢查。

---

## 🚨 CRITICAL：執行任何前端 / UI 任務前必跑

違反以下任一檢查 → **停止寫程式碼**，先處理完檢查再繼續。

---

## 階段 1：寫 UI 前的**強制載入**

### 1.1 讀取風格設定

Read `.claude/taskmaster-data/ui-style.json`：

- **檔案不存在** → 採用文末「Fallback 預設風格」，並告知使用者「建議執行 `/ui-style` 建立正式風格」
- **檔案存在** → 依 `mode` 載入對應資源（見 1.2）

### 1.2 依模式載入 DESIGN.md

#### mode: `single`

```
Read .claude/ui/{primary}/DESIGN.md
```

整份 DESIGN.md 為唯一依據。

#### mode: `mixed`

先載入主風格：
```
Read .claude/ui/{primary}/DESIGN.md
```

再對每個非 null 的 `overrides` 欄位，載入對應風格並**只取對應段落**。
風格檔有新舊兩種格式，兩種標題都要認（比對時忽略標題前的編號，例如 `## 2. `）：

| overrides 欄位 | 認這些 `##` 標題（任一） |
|--------------|---------------------------------------------|
| `color` | `Color Palette & Roles`、`Colors` |
| `typography` | `Typography Rules`、`Typography` |
| `components` | `Component Stylings`、`Components` |
| `layout` | `Layout Principles`、`Layout` |

- **舊格式**（9 節，`## 2. Color Palette & Roles` 這種）：數值寫在段落內文
- **新格式**（Google DESIGN.md 規格，檔頭 YAML 有 `version: alpha`）：段落內文用
  `{colors.primary}` 這類引用，實際數值在檔頭 YAML 的同名區塊（`colors:`、`typography:`、
  `spacing:`、`rounded:`、`components:`）——**段落和 YAML 區塊都要讀**，只讀段落拿不到數值
- **對應段落找不到時要明說**：「`<codename>` 沒有 `<段落>`，沿用主風格」，不能默默略過

覆蓋段落優先於主風格，其他段落維持不變。動畫不在這張表裡——絕大多數風格檔沒有動畫段落，
動畫強度改由 `ui-style.json` 的頂層 `motion` 欄位（L1／L2／L3）決定，不從品牌檔抽。

### 1.3 載入附屬檔

和本檔同一個目錄（`.claude/skills/ui-style-compliance/`）：

| 檔案 | 什麼時候讀 |
|---|---|
| `anti-ai.md` | **一律讀**。反 AI 感的產出前／產出後清單、文案與「不准編事實」 |
| `motion.md` | `ui-style.json` 的 `motion` 是 `L2` 或 `L3` 時才讀（沒有 `motion` 欄位＝L1，不讀）。L1 只看本檔 2.6③ |
| `fonts-cjk.md` | 專案語言含繁體中文時讀（頁面 `lang` 是 `zh-Hant`／`zh-TW`／`zh-HK`，或內容是繁中）。jp 風格的日文字型換成繁中的對照表也在這裡 |

### 1.4 寫碼前必答（無法略過）

在寫任何 UI 程式碼前，**必須在回覆中明確陳述**：

```
✅ 風格載入確認：
  - Mode: [single / mixed / fallback]
  - Primary: [codename 或 "fallback"]
  - DESIGN.md 關鍵規範：
    - 主色：#XXXXXX（使用變數名 --color-primary）
    - 字體：[font-family]
    - 間距基準：4px / 8px
    - 圓角規範：小元素 Xpx、卡片 Xpx
    - 陰影：[spec]
  - 動畫等級：[L1 / L2 / L3]（沒有 motion 欄位＝L1）
  - 已讀附屬檔：anti-ai.md［+ motion.md］［+ fonts-cjk.md］
  - 風格本身接近的 AI 樣式：[無 / 有：見 anti-ai.md「例外」，照選定風格做]
```

**未陳述此確認就寫 UI 程式碼 = 違規**。

---

## 階段 2：寫 UI 中的**硬禁止**

### 2.1 色彩禁令

❌ **禁止硬編碼色票**：
```jsx
// BAD
<div style={{ color: '#1D1D1F' }}>

// BAD
<button className="bg-[#007AFF]">
```

✅ **必須使用設計 tokens**：
```jsx
// GOOD — CSS 變數
<div style={{ color: 'var(--color-text-primary)' }}>

// GOOD — Tailwind token
<button className="bg-primary text-on-primary">
```

例外：若專案完全未建立 tokens，第一次建立時可直接從 DESIGN.md 抄 hex 值到
`tailwind.config.ts` 或 `styles/tokens.css`，**但後續元件必須引用 token，不再抄 hex**。

> Token 分層與交換格式對齊 W3C DTCG（global → semantic/alias → component），
> 詳見範本 `12_frontend_architecture_specification.md`。
>
> 動畫的時長、easing、位移距離也是 token，不要散在元件裡（L2／L3 的寫法見 `motion.md` 第 4 節）。

### 2.2 字體禁令

❌ 禁止隨意 `font-size: 17px` 這種散亂值
✅ 必須對應 DESIGN.md 的 Typography Hierarchy（例如 `text-body` / `text-heading-md`）

### 2.3 間距禁令

❌ 禁止 `padding: 13px`、`margin: 22px`
✅ 必須 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64px 倍數（或 DESIGN.md 定義的 spacing scale）

### 2.4 元件一致性

同類元件（按鈕、卡片、輸入框）**不得同時存在 2 種風格**。已建立 `Button` 就不要再寫
inline `<button>`；已有 `Card` 不要再寫自訂卡片。

### 2.5 反 AI 感 → `anti-ai.md`（唯一來源）

紫色漸層、全站 Inter、罐頭版型這類「第一層預設」，和米白底＋襯線＋陶土色這類「有品味的預設」，
規則與例外都在 `anti-ai.md`（1.3 節規定一律讀）：

- **產出前**（挑方向、配色、字型時）：五種常見樣式、被用爛的字型、動手前先寫計畫再對照題目
- **產出後**（自檢時）：逐項對照的清單
- **例外**：選定的 DESIGN.md 本身就是那種樣式（`claude`、`granola` 等）時怎麼處理

### 2.6 跨風格通用規則（入口）

跨風格通用的規則一律放在本節指向的地方，**不因選了哪個品牌而變**，也不寫進任何一份 DESIGN.md。
色彩、字體、版型的個性從選定的 DESIGN.md 取；沒有 DESIGN.md 時用文末 Fallback。
編號沿用舊版，既有的指標（例如「2.6 ②」）照樣找得到。

| 編號 | 規則 | 在哪裡 |
|---|---|---|
| ① | 字體當主角 | `anti-ai.md`「該主動做的事」 |
| ② | 文案的具體性、**不准編事實**（查不到的留 `【待提供：<項目>】`） | `anti-ai.md`「文案與事實」 |
| ③ | 動畫底線（所有等級） | **本節下方**（L1 只看這裡） |
| ④ | 原生 CSS 優先、瀏覽器支援度 | `motion.md` 第 2、5 節 |
| ⑤ | 一次只做一個區塊 | `anti-ai.md`「該主動做的事」 |
| ⑥ | 影片 hero | `anti-ai.md`「該主動做的事」 |

**③ 動畫底線（L1／L2／L3 都要守）**

> 動畫的職責是**解釋層級**或**回應互動**，不是讓所有元素同時飄。

- **UI 微互動**（hover、focus、展開收合）150～300ms、ease-out，不彈跳、不過衝。
  這個時長限制**不適用於捲動連動的動畫**（進度跟著捲動走，沒有固定時長；L2／L3 見 `motion.md`）
- 進場動畫一次只帶一個層級，不要整頁元素一起淡入，也不要每一段都同一個淡入上移
- 裝飾性動畫**超過 5 秒必須可暫停**（WCAG 2.2）
- **必須**處理 `prefers-reduced-motion: reduce`：自動播放改成靜態 poster，位移動畫改成直接顯示
- **L1 只用 CSS `transition`／`animation`，不 import 任何動畫函式庫**
- 等級是 L2／L3 → 讀 `motion.md`（允許的技術、效能預算、降級方式、函式庫速查與常見坑）

---

## 階段 3：寫 UI 後的**自我驗證**

完成 UI 後，**必須**在回覆最後附上「風格合規自檢」。

**這是自檢清單的唯一來源。** `ui-builder` agent 與 `/ui-page`、`/ui-site` 都指向這裡，
不各自抄一份——之前三份各自漂開，真正在寫程式碼的那份反而最短。
要加檢查項目就加在這裡。

```
🔍 風格合規自檢：
- [x] 色票：全用 tokens / CSS 變數，零硬編碼 hex
      （檢查：grep -rE '#[0-9a-fA-F]{3,8}\b' src/ 只應出現在 tokens 檔）
- [x] 字體：遵循 Typography Hierarchy（使用 text-heading-md / text-body 等）
- [x] 間距：4/8px 倍數（或 DESIGN.md 的 spacing scale）
- [x] 圓角：符合 DESIGN.md 規範（小元素 Xpx、卡片 Xpx）
- [x] 陰影：符合規範
- [x] 深色模式：token 用語意命名（--color-surface 而非 --white）；
      只有 DESIGN.md 有定義或使用者要求時才做第二套值
- [x] 元件一致性：同類元件無並存多風格
- [x] 語意化 HTML：header / nav / main / section / footer 使用恰當，不是整頁 div
- [x] 反 AI 感：已逐項對照 `anti-ai.md` 的「產出後」清單；命中但由 DESIGN.md 要求的，寫明是哪一份要求的
- [x] 文案具體性：遮掉公司名後仍看得出在講什麼產品（見 `anti-ai.md`「文案與事實」）
- [x] 事實沒有編造：價格、營業時間、電話、得獎、年份、評論、客戶名都有來源；
      缺的都標了 `【待提供：<項目>】`，並列進回報的「開放問題」（見 2.6 ②）
- [x] 動畫有目的：解釋層級或回應互動，非全頁一起飄；已處理 `prefers-reduced-motion`（見 2.6 ③）
- [x] 動畫等級：用到的技術沒有超出 `ui-style.json` 的 `motion` 等級（L1 沒有 import 動畫函式庫；L2／L3 照 `motion.md` 第 2 節）
- [x] 動畫實作：能用原生 CSS（scroll-driven / View Transitions）就沒加動畫庫，而且有不支援時的退路
- [x] a11y：文字對比 ≥ 4.5:1、focus 狀態可見、觸控目標 ≥ 44px、圖片有 alt
- [x] 斷點：390、1440 已截圖看過；768、1024 沒有水平捲軸
- [ ] 未達成項目說明：[如有]
```

**斷點規則（唯一來源）**：

- **必截圖**：390px（手機）與 1440px（桌機）
- **只檢查沒有水平捲軸**：768px、1024px
- **CSS 斷點本身**：照 DESIGN.md 的 Responsive 段落；沒寫就用框架預設
  （例如 Tailwind 的 `sm`／`md`／`lg`），不要自己發明一組數字
- 沒有截圖工具時，斷點那一項**不准勾**，在「未達成項目說明」寫「未截圖，原因：…」

**不附自檢 = 違規**。沒做到的項目不准勾成 `[x]`——勾了沒做比不勾更糟。

---

## Fallback 預設風格（使用者未設定時）

採用 Apple / Google 簡約哲學：

### 設計方向
- **少即是多** — 每個元素都有明確目的，去除裝飾
- **大量留白** — 內容之間保持呼吸空間
- **清晰層級** — 字體大小/粗細/深淺區分主次
- **一致間距** — 4px / 8px 倍數
- **克制色彩** — 中性色為主，單一強調色用於 CTA

### 具體規範
- **字體：** 系統字體優先（`-apple-system`, `Inter`, `Noto Sans TC`）
- **圓角：** 小元素 4-8px、卡片 12-16px
- **陰影：** `0 1px 3px rgba(0,0,0,0.1)`
- **毛玻璃：** `backdrop-filter: blur(20px) saturate(180%)`，背景 `rgba(255,255,255,0.72)` / 深色 `rgba(28,28,30,0.72)`
- **動畫：** UI 微互動 150-300ms ease（捲動連動的動畫不受此限，見 2.6 ③）
- **深色模式：** 預設不做。token 一律用語意命名（`--color-surface`、`--color-text-primary`），
  之後要加深色模式只需補一套值，不必改元件。使用者要求時才做

### 元件風格
- **按鈕：** 主要實心、次要輪廓、三級文字
- **輸入框：** 簡潔邊框、focus 時品牌色高亮
- **卡片：** 白底微陰影，內容優先
- **導航：** 頂部或側邊，圖標 + 文字，當前頁明確標示
- **表格/列表：** 行間距充足，斑馬紋或細分隔線二選一

**建議：** 若專案有前端需求，執行 `/ui-style` 選擇正式風格。

---

# Pencil 設計稿落地規則（強制）

Pencil MCP 產出的 `.pen` 檔必須落地在專案根目錄的 `design/` 資料夾。
本規則在呼叫 Pencil MCP 工具前強制執行。

## 🚨 呼叫 Pencil MCP 前必檢

### 規則 1：新增 `.pen` 檔一律指定 `design/` 路徑

❌ **禁止**使用 `"new"` 參數（會存到 IDE 預設位置，離開專案目錄）：

```
mcp__pencil__open_document("new")   // BAD
```

✅ **必須**傳入 `design/<name>.pen` 路徑：

```
mcp__pencil__open_document("design/login-page.pen")
mcp__pencil__open_document("design/components/button-kit.pen")
```

### 規則 2：確認 `design/` 目錄存在

呼叫 `open_document` 前，若目錄尚未建立，**先用 Bash/Write 建立**（`mkdir -p design`）。

### 規則 3：命名規範

- 英數小寫 + 連字號（kebab-case）
- 描述性名稱：`login-page.pen`、`checkout-flow.pen`、`button-kit.pen`
- **禁止** `untitled.pen`、`new.pen`、`test.pen`
- 需要時透過 `AskUserQuestion` 徵詢命名

### 規則 4：子資料夾建議分類

```
design/
├── pages/          # 完整頁面
├── components/     # 元件庫
├── mobile/         # 行動版
└── web/            # 網頁版
```

## 標準流程

1. `AskUserQuestion` 問名稱與子類（若不清楚）
2. 確認目標目錄存在（不存在則 `mkdir -p`）
3. `mcp__pencil__open_document("design/<name>.pen")`
4. `mcp__pencil__get_guidelines` 載入設計指南
5. `mcp__pencil__batch_design` 操作

## 例外

- 使用者**明確指定**絕對路徑 → 尊重使用者意圖
- 使用者**明確要求**放其他資料夾 → 尊重，但提醒預設是 `design/`
- 純讀取既有 `.pen` 檔做分析 → 不受限制

---

## 相關指令

- `/ui-style` — 選擇或切換 UI 風格
- `/ui-site` — 產生網站雛形（多頁骨架 + IA 文檔 + 設計 tokens）
- `/ui-page <path>` — 深化單一頁面
- 目錄瀏覽：`.claude/ui/CATALOG.md`
- 完整規範：`.claude/ui/<codename>/DESIGN.md`
