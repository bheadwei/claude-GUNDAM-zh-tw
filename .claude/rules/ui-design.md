# UI/UX 設計風格（調度器 + 強制檢查）

本規則是 UI 風格的**調度器**與**檢查器**。實際風格規範由選定的設計系統提供（`.claude/ui/<codename>/DESIGN.md`），本規則強制執行前中後三階段檢查，確保產出符合風格。

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

再對每個非 null 的 `overrides` 欄位，載入對應風格並**只取對應段落**：

| overrides 欄位 | 讀取 `.claude/ui/<override>/DESIGN.md` 的段落 |
|--------------|---------------------------------------------|
| `color` | Color Palette & Roles |
| `typography` | Typography Rules |
| `components` | Buttons / Cards / Inputs / Components |
| `layout` | Spacing / Grid / Section Rhythm |
| `animation` | Motion / Transitions |

覆蓋段落優先於主風格，其他段落維持不變。

### 1.3 寫碼前必答（無法略過）

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

例外：若專案完全未建立 tokens，第一次建立時可直接從 DESIGN.md 抄 hex 值到 `tailwind.config.ts` 或 `styles/tokens.css`，**但後續元件必須引用 token，不再抄 hex**。

### 2.2 字體禁令

❌ 禁止隨意 `font-size: 17px` 這種散亂值
✅ 必須對應 DESIGN.md 的 Typography Hierarchy（例如 `text-body` / `text-heading-md`）

### 2.3 間距禁令

❌ 禁止 `padding: 13px`、`margin: 22px`
✅ 必須 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64px 倍數（或 DESIGN.md 定義的 spacing scale）

### 2.4 元件一致性

同類元件（按鈕、卡片、輸入框）**不得同時存在 2 種風格**。已建立 `Button` 就不要再寫 inline `<button>`；已有 `Card` 不要再寫自訂卡片。

---

## 階段 3：寫 UI 後的**自我驗證**

完成 UI 後，**必須**在回覆最後附上「風格合規自檢」：

```
🔍 風格合規自檢：
- [x] 色票：全用 tokens / CSS 變數，零硬編碼 hex
- [x] 字體：遵循 Typography Hierarchy（使用 text-heading-md / text-body 等）
- [x] 間距：4/8px 倍數
- [x] 圓角：符合 DESIGN.md 規範（小元素 Xpx、卡片 Xpx）
- [x] 陰影：符合規範
- [x] 深色模式：CSS 變數已雙版本定義
- [x] 元件一致性：同類元件無並存多風格
- [ ] 未達成項目說明：[如有]
```

**不附自檢 = 違規**。

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
- **動畫：** 150-300ms ease
- **深色模式：** 必須支援，CSS 變數語意化命名

### 元件風格
- **按鈕：** 主要實心、次要輪廓、三級文字
- **輸入框：** 簡潔邊框、focus 時品牌色高亮
- **卡片：** 白底微陰影，內容優先
- **導航：** 頂部或側邊，圖標 + 文字，當前頁明確標示
- **表格/列表：** 行間距充足，斑馬紋或細分隔線二選一

**建議：** 若專案有前端需求，執行 `/ui-style` 選擇正式風格。

---

## 相關指令

- `/ui-style` — 選擇或切換 UI 風格
- `/ui-site` — 產生網站雛形（多頁骨架 + IA 文檔 + 設計 tokens）
- `/ui-page <path>` — 深化單一頁面
- 目錄瀏覽：`.claude/ui/CATALOG.md`
- 完整規範：`.claude/ui/<codename>/DESIGN.md`
