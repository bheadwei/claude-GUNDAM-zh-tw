---
name: gmap-landing-page
description: Use when 使用者貼了 Google 地圖商家連結（maps.app.goo.gl、google.com/maps），或說「幫這間店做官網」「做一頁式網站／形象頁」「做個網站給店家看」「提案給店家」——用地圖上的商家資訊、評論與評論照片，為沒有官網的店家（餐廳、咖啡廳、小店）逐題問答確認方向後產出一頁式形象網站。已有網站要改版的不適用（改用 /ui-page 或 unslop）。
---

# Google 地圖商家 → 形象 Landing Page

使用者丟一個 Google 地圖連結（`maps.app.goo.gl/...`、`google.com/maps/place/...` 皆可），就直接開工。
流程濃縮自 TaonyDesign「AI x UIUX 工作流」的四個角色（PM → 設計師 → 素材 → 前端），但砍掉 Figma 迭代，改成**問答式決策**，每一輪只讓使用者做選擇題。

## 核心原則（整個流程都適用）

1. **先別動工**：拿到連結後先蒐集、再問、再寫 brief，brief 確認前不寫任何 HTML。
2. **問答一律用 AskUserQuestion，一次一題**（最多 2 題且高度相關，見 `.claude/rules/interactive-qa.md`）：每題 2–4 個具體選項、推薦項放第一個並標 `(Recommended)`、題目內寫進做決定所需的背景（使用者只看題目就能選）。下面各輪列的是**這一輪要問的題目**，照順序逐題問，收到答案再問下一題；使用者可選 Other 貼網址或說要自己上傳素材。若工具不可用，改用純文字選項題，一樣一次一題。
3. **不准腦補事實**：菜單、價格、營業時間、電話、得獎、創立年份，只用地圖或使用者提供的資料；找不到就留 `【待提供：<項目>】` 佔位（格式同 `.claude/skills/ui-style-compliance/anti-ai.md`「文案與事實」），並列進「開放問題」。評論引用必須是原文節錄，附評論者名稱。
4. **退件要具體**：自我檢查或使用者回饋時，用「哪個狀態 → 看到什麼 → 像什麼」描述問題再修。
5. **分段驗收**：每完成一個區塊就截圖給使用者看，不要全部做完才一起驗。
6. 全程使用台灣慣用繁體中文。

## 工作目錄

- 若 session 有連接資料夾，在該資料夾下建 `<店名-slug>/`；否則用 `/mnt/user-data/outputs/<店名-slug>/`。
- 結構：

```
<slug>/
  00-intake/  store.json  reviews.md  photos/raw/
  brief.md                ← 設計 brief + 精簡 PRD
  asset-prompts.md        ← 給外部 AI 工具的素材 prompt（有需要才產）
  site/  index.html  assets/img/*.webp  assets/fonts/(可選)
  screenshots/
  CREDITS.md              ← 照片來源與授權狀態
```

---

## Step 0｜資料蒐集（不問問題，直接做）

依序嘗試，拿到就停：

1. **瀏覽器**（首選，built-in browser 或 Claude in Chrome）：開啟連結 → `get_page_text` 抓店名、類別、評分、評論數、地址、電話、營業時間、價位、網站欄位、服務標籤（內用／外帶／訂位）。
   - 切到「評論」分頁，依「最相關」抓 20–40 則評論文字（含評論者、星等、日期）。
   - 切到「相片」分頁（含「依據評論」「菜單」「氛圍」等篩選），用 `javascript_tool` 收集 `googleusercontent.com` 的圖片網址（`img[src]` 與 `background-image`），把網址尾端的尺寸參數改成 `=w1600-h1200-k-no` 取高解析版，去重後存清單。同時記錄每張照片的上傳者（店家 / 顧客名）。
2. **places_search 工具**：只拿基本資訊（名稱、座標、地址、評分）作備援。
3. **Google Places API**：使用者若提供 API key，用 Place Details (New) 拿 `websiteUri`、`regularOpeningHours`、`reviews`（最多 5 則）、`photos`（最多 10 張，需顯示 `authorAttributions`）。
4. 都失敗 → 請使用者貼上店名＋地址，或截圖給你。

WebFetch 對 Google 地圖頁通常拿不到內容（JS 渲染），不要硬試。

**官網檢查**：地圖上的「網站」欄位 + WebSearch `"<店名>" 官網 OR 官方網站`。
- 若已有正式官網 → 用 AskUserQuestion 問：「已有官網 <網址>，要 (a) 仍做一版形象提案 (b) 停止」。
- 只有 FB / IG / 訂位平台頁 → 視為沒有官網，記下連結當 CTA 候選。

**照片下載**：在 cloud bash 用 curl 下載到 `00-intake/photos/raw/`，用 Pillow 產生縮圖聯絡表（contact sheet，每張標編號），Read 它來**親自看圖**，給每張標記：類型（招牌菜／飲品／空間／外觀／菜單）、構圖品質（可當 Hero / 可用 / 不建議）、主色調。

**評論萃取**（寫入 reviews.md）：
- 高頻提到的菜色 Top 5（含提及次數）
- 氛圍關鍵字（例：老宅、文青、熱鬧、適合約會、寵物友善）
- 3–6 則可上評論牆的短句（原文節錄 ≤ 60 字，附名字與星等）
- 負評常見點（只作內部參考，不放上網頁）

完成後用一則 SendUserMessage 給使用者「店家速覽」：店名、評分、主要賣點 3 點、可用照片數量與聯絡表。

---

## Step 1｜第一輪問答：定位與內容（逐題問，共 4 題）

1. **用途**：(a) 提案 demo 給店家看 (Recommended)（頁面加「概念提案」標記）(b) 店家已同意，要正式上線
2. **主要 CTA**：依蒐集到的資料給選項，例：電話訂位 / Google 地圖導航 / LINE 官方帳號 / 訂位平台（inline、EZTABLE）/ 外送平台
3. **區塊範圍**（multiSelect）：Hero、品牌故事、招牌菜、菜單、評論牆、環境照片、營業資訊＋地圖、FAQ、IG 動態牆
4. **語言**：繁中 / 繁中＋英文 / 繁中＋日文（觀光區店家把雙語標 (Recommended)）

## Step 2｜第二輪問答：視覺方向與動態強度（逐題問，共 3 題）

**第 1 題：設計方向。** 先根據照片主色、店家類型、評論氛圍，**自己發想 3 個設計方向**——每個都照 `.claude/skills/ui-style-compliance/anti-ai.md`「動手前：寫方向、自我對照、等使用者確認」寫五行（產品、個性、世界、亮點、記號）並過自我對照，提三個方向時另守同檔「看預覽選提方向時」四條。每個方向寫成一個 AskUserQuestion 選項，並在 `preview` 欄位放：方向名稱、一句話概念（含個性與記號）、色票（4–5 個 hex）、版面示意（ASCII）、參考風格（例：日式雜誌、80s 台式懷舊、北歐極簡、夜市霓虹）、1～3 個主角效果（從 `.claude/skills/ui-style-compliance/effects.md` 第 2 節挑，preview 裡寫效果給人的感覺，材質照這家店的題材換，見同檔第 1 節）。

使用者在這一題選定方向，就是 `anti-ai.md` 說的「方向已確認」，Step 5、Step 6 不再另外問方向。

方向選定後，再逐題問：

- **第 2 題：動態強度**（選項文字照 `.claude/skills/ui-style-compliance/motion.md` 第 1 節，不寫函式庫名；各等級能用哪些技術見同檔第 2 節）：
  - L1 安靜：畫面穩定，只有按下去、滑過去時有輕微回應（適合長輩客群、資訊為主）
  - L2 有節奏 (Recommended)：往下捲時內容依序出現，標題和照片有前後層次，像品牌官網
  - L3 沉浸：捲動像在看一段影片，背景會動、相簿會停住讓你橫向看；手機較耗電、要另外準備素材
- **第 3 題：參考素材**：「有沒有喜歡的網站或圖片？可直接貼網址或上傳」→ 選項：沒有，照方向走 (Recommended) / 我要貼參考網址 / 我要上傳圖片
  - 使用者貼網址 → 照 `.claude/skills/ui-style-compliance/effects.md` 第 5 節截圖、萃取，寫進 brief 的「風格 DNA」（只學結構與節奏，不搬對方的程式碼、素材、文案）。

## Step 3｜第三輪問答：字型（1 題）

依選定方向，推薦 3 組 Google Fonts 中英搭配（標題＋內文），每組在 `preview` 寫出字型名、字重、氣質、Google Fonts 連結。
字型清單與中英搭配從 `.claude/skills/ui-style-compliance/fonts-cjk.md` 第 1、2 節挑（唯一來源；標 ⚠ 的要講得出這家店為什麼是它）。
字型規則照 `anti-ai.md`：只有一種字型（Inter／系統字）不行，兩個字型時角色要明顯不同；字重 400／500、最多 600，標題不用粗體（不是 900 粗宋）。

選項加一個「我有指定字型（貼名稱或上傳字型檔）」。中文字型務必用 Google Fonts 的 `text=` 子集或 `display=swap`，避免首屏卡住。

## Step 4｜第四輪問答：素材確認

把聯絡表再次給使用者，逐題問（共 3 題）：

1. **Hero 用哪張**：列出你評為「可當 Hero」的前 3 張（選項寫編號＋內容），加「我自己提供」。
2. **素材不足時**：(a) 用現有照片＋色塊/字體排版撐場 (Recommended)(b) 我提供店家原始照片（貼雲端連結或上傳）(c) 幫我寫 AI 生圖 prompt，我自己去 Nano Banana / Midjourney 生成後再給你
3. **Logo**：用字體做文字標 (Recommended) / 沒有 / 我上傳

選 (c) 時，在 asset-prompts.md 寫 prompt，沿用影片的句型骨架：
「以附圖為準」宣告 → 主體逐項描述（數量、形狀、位置、顏色）→ 攝影規格 → 背景 hex 色＋逐項否定（no gradient, no vignette, no text, no logo, no watermark）→ 失敗判準（If … the result is wrong）。要做影片拆幀時，提醒使用首尾幀模式（Frames to Video）並保留 Physics 段落。

## Step 5｜寫 brief.md，給使用者確認

一份文件包含：

- **專案定位**：用途、受眾、成功判準（例：手機 3 秒內看懂賣什麼、一指點到 CTA）
- **風格 DNA**：方向（Step 2 選定的五行）、色票（CSS 變數）、字型、動態強度、參考網址
- **頁面結構**：逐區塊列 內容來源 / 用哪張照片 / 動效
- **功能清單（MoSCoW）＋ 逐項驗收條件**（具體可測，例：「375px 寬時 CTA 按鈕固定在底部且高度 ≥ 48px」，不寫「體驗良好」）
- **非目標**：明寫不做什麼（線上點餐、會員、後台 CMS…）
- **開放問題**：所有 `【待提供：…】` 項目

用 SendUserMessage 給摘要，AskUserQuestion 問「brief 可以開工嗎？」(可以 / 要修改)。確認後才進 Step 6。

## Step 6｜實作

**技術棧（預設）**：單一 `index.html` + 內嵌 CSS/JS，函式庫走 CDN（jsDelivr / unpkg）：

- 用哪些函式庫、各等級允許什麼：`.claude/skills/ui-style-compliance/motion.md` 第 2、6 節（唯一來源）
- 主角效果的寫法、參數、手機與 reduced-motion 怎麼處理：`.claude/skills/ui-style-compliance/effects.md` 第 3 節；要另外找元素時看同檔第 4 節（含授權）
- 使用者要求 React 時改用 Vite + React + TS + Tailwind。

**實作規則**：

- Mobile-first RWD（餐廳流量多半來自手機），斷點 390 / 768 / 1440。
- 動畫參數集中、`prefers-reduced-motion` 降級：照 `motion.md` 第 3、4 節。
- 照片：用 Pillow 轉 WebP（寬 1600 / 800 兩種尺寸，品質 80），`<img srcset loading="lazy">`，Hero 不 lazy。
- 營業資訊區：嵌入 `https://www.google.com/maps?q=<地址或店名>&output=embed`（不需 API key），電話用 `tel:`，導航用 Google 地圖連結。
- SEO：`<title>`、meta description、Open Graph、`LocalBusiness`/`Restaurant` JSON-LD（只填已確認的欄位）。
- 評論牆：原文節錄 + 評論者名稱 + 「來自 Google 地圖評論」連結。
- 用途是提案 demo 時：頁尾與首屏角落加「概念提案・非官方網站」標記。

**分段建構與驗收**：Hero → 招牌菜 → 評論/環境 → 資訊＋CTA，每段完成就：

1. 用 Playwright（cloud 已預裝 Chromium）在 390 與 1440 寬截圖，Read 截圖自查；動畫段落額外截 3 個捲動位置看連續狀態。
2. 檢查 console 無錯誤、圖片皆載入、無水平捲軸。
3. 截圖給使用者，問「這段 OK 嗎？」，有回饋就照「狀態 → 看到什麼 → 像什麼」修。

（若檔案在使用者電腦的連接資料夾，只把 `site/` 暫存到 cloud 截圖，原始檔仍在原處修改。）

## Step 7｜交付

- `site/` 可直接雙擊 index.html 預覽；告訴使用者資料夾與檔名。
- 寫 **CREDITS.md**：每張照片的來源（店家上傳／顧客 <名字> 上傳／使用者提供／AI 生成）。
- 提醒（一段話，不要長篇）：
  - Google 地圖上的顧客照片版權屬於上傳者，提案 demo 可用，**正式上線前要換成店家自有照片或取得授權**。
  - 部署選項：Netlify Drop（拖拉即上線）、Vercel、Cloudflare Pages、GitHub Pages。
- 用 AskUserQuestion 問下一步：微調某區塊 / 產出提案用截圖組 / 結束。

不要把這個網頁用 Artifact 發布成公開頁面——它帶著真實店家的名稱，未經店家同意不應有對外網址；交付本地檔案即可。

---

## 素材庫速查

不在這裡列——函式庫用途見 `.claude/skills/ui-style-compliance/motion.md` 第 6 節，效果配方與去哪挑元素見同目錄 `effects.md` 第 2～4 節（兩份都是唯一來源）。
