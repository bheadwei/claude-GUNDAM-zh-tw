---
agent: code-quality-specialist
date: 2026-11-09-1830
area: quality
target: .claude/templates/overview/index.html（git diff 1ef199b..7a4d20d，階段 2 任務圖目錄）
severity: medium
status: findings
---

# 階段 2 任務圖目錄：無 CRITICAL／HIGH，2 項 MEDIUM、2 項 LOW

## TL;DR
- XSS、id 撞名、listener 重複綁定、鍵盤可達性（目錄項是 `<a href>`）四項特別關注都過。
- MEDIUM：輪詢重繪會讓目錄項失去焦點、目錄自身的捲動位置歸零（`tv.scrollTop` 有保留，目錄內層沒有）。
- 結論：PASS（MEDIUM／LOW 記技術債）。

## 範圍
- **檢查目標**: `.claude/templates/overview/index.html` 的 `tocItem`、`planCard(pl, i)`、`renderTasks`、`#tv` click 委派、`.tw/.toc` CSS
- **觸發原因**: 階段 2 審查
- **參考資料**: plan `adhoc-2026-11-09-overview-readability.md` 階段 2；不跑測試

## 發現

### 🔴 Critical / High
無。

特別關注項逐項：
- XSS：目錄文字（`pl.task`、`pl.title`）一律經 `esc()`；`href`、`data-p`、卡片 id 只由陣列索引整數組成，不含資料內容。燈號 class 由固定字串選出。通過。
- id 撞名：靜態與動態產生的 id 中沒有 `p0`、`p1` 形式；既有 id 是 `ntc`、`cv`、`ah`、`world`、`probe`、`mini`、`panel`、`tv`、`zout` 等。通過。
- listener：委派綁在不會被 `innerHTML` 重建的 `#tv` 上、只綁一次（頂層執行一次），重繪不會重複綁定。`reduce` 定義於 641 行，晚於 click 處理才被讀，無初始化順序問題。通過。
- 鍵盤：目錄項是 `<a href="#pN">`，可聚焦、Enter 會觸發 click 委派；沒有被重設的 outline，瀏覽器預設焦點框可見。通過。

### 🟡 Medium
- `index.html:926-931`（renderTasks）— 輪詢重繪用 `tv.innerHTML` 整段重建，使用者用 Tab 聚焦在目錄項時焦點會被丟掉（回到 body），鍵盤使用者每次輪詢都得重新 Tab；`.toc` 自己的捲動（桌機 `max-height` 內捲、手機橫向捲）也歸零，目錄列數多時所選項會跳出可視範圍。計畫驗收只要求 `#tv.scrollTop` 保留，所以不算驗收缺口 → 建議重繪前記 `.toc` 的 `scrollTop/scrollLeft` 與 `document.activeElement` 的 `data-p`，重繪後還原；或資料沒變時（比較 plans 序列化結果）跳過重繪。
- `index.html:149-150, 922-925` — 目錄連結 `href="#pN"` 在 click 委派裡不分修飾鍵一律 `preventDefault`，Ctrl／Cmd／中鍵開新分頁會失效；另外新分頁開 `#p3` 時 `view()` 啟動只認 `#tasks`，會落在地圖。影響小，這是內部工具頁 → 可在處理器開頭 `if (e.metaKey || e.ctrlKey || e.shiftKey || e.button) return;`，或接受現況。

### 🟢 Low / Info
- `index.html:917` `tocItem` 的燈號判斷 `a && b || c ? x : y` 一行巢狀三元，優先序正確但難讀；可抽成與 `partCard`／既有狀態對照共用的小函式。
- `index.html:149` `calc(100vh - 140px)` 的 140 是頂欄＋分頁列高度的估值，頂欄換行（窄螢幕、長標題）時會偏；魔法數字無來源說明。
- 目錄跳轉後焦點不會移到目標卡片（`section` 非可聚焦），螢幕閱讀器使用者無回饋；內部工具頁可不處理。

## 建議的後續 Agent
無。沒有「有風險行為路徑完全沒有測試」的項目（純前端呈現，計畫以截圖／Playwright 驗收）；也無安全敏感問題。

## 度量
- 檢查檔案數: 1
- 通過: 4（特別關注項）| 警告: 2 | 失敗: 0
