# UI/UX 設計風格（調度器）

本規則是 UI 風格的**調度器**，不直接定義風格。實際風格規範由選定的設計系統提供，位於 `.claude/ui/<codename>/DESIGN.md`。

---

## 工作流程（執行任何前端 / UI 任務前必跑）

### 1. 讀取使用者選擇

Read `.claude/taskmaster-data/ui-style.json`：

- **檔案不存在** → 採用本文件底部「Fallback 預設風格」，並建議使用者執行 `/ui-style` 設定
- **檔案存在** → 依 `mode` 載入對應資源

### 2. 依模式載入規範

#### mode: `single`

```
Read .claude/ui/{primary}/DESIGN.md
```

整份 DESIGN.md 為唯一依據，涵蓋色票、字體、間距、元件、動畫。

#### mode: `mixed`

先載入主風格作為基底：
```
Read .claude/ui/{primary}/DESIGN.md
```

再對每個非 null 的 `overrides` 欄位，載入對應風格並**只取對應段落**覆蓋：

| overrides 欄位 | 讀取 `.claude/ui/<override>/DESIGN.md` 的段落 |
|--------------|---------------------------------------------|
| `color` | Color Palette & Roles（色票與角色） |
| `typography` | Typography Rules（字體規則） |
| `components` | Buttons / Cards / Inputs / Components（元件） |
| `layout` | Spacing / Grid / Section Rhythm（間距版面） |
| `animation` | Motion / Transitions（動畫） |

**覆蓋規則：** 覆蓋段落的規範優先於主風格；主風格其他段落維持不變。

### 3. 寫程式碼前檢查

- [ ] 已讀取 `ui-style.json` 或確認採用 fallback
- [ ] 已載入主風格 DESIGN.md
- [ ] 若 mixed，已載入所有覆蓋風格的對應段落
- [ ] 色票使用 hex / HSL 變數化，不硬編碼
- [ ] 字體層級遵循該風格 Typography Hierarchy
- [ ] 元件樣式（按鈕/卡片/輸入框）一致
- [ ] 深色模式變數已定義

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
- **圓角：** 小元素 4-8px、卡片 12-16px，不過度圓潤
- **陰影：** `0 1px 3px rgba(0,0,0,0.1)`，避免重陰影
- **毛玻璃：** `backdrop-filter: blur(20px) saturate(180%)`，背景 `rgba(255,255,255,0.72)` / 深色 `rgba(28,28,30,0.72)`
- **動畫：** 150-300ms ease，微妙自然
- **深色模式：** 必須支援，使用語意化 CSS 變數

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
- 目錄瀏覽：`.claude/ui/CATALOG.md`
- 完整規範：`.claude/ui/<codename>/DESIGN.md`
