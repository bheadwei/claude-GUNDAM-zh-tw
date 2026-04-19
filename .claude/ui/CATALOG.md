# UI 設計風格目錄

本目錄收錄 57 種設計系統規範，供 `/ui-style` 指令及前端開發時查詢使用。

每個風格的完整規範位於 `.claude/ui/<codename>/DESIGN.md`（英文原文，含色票、字體、間距、元件）。

---

## 索引格式

- **codename** — 繁中一句話特色

---

## 按設計哲學分類（推薦：依視覺感受選擇）

### 極簡主義 (Minimalism)
> 少即是多、大量留白、單一強調色、內容為王

- **apple** — 黑/淺灰二元對比、電影感排版、單一 Apple Blue 強調
- **linear.app** — 精準網格、無裝飾、速度感、深灰中性基調
- **stripe** — 明亮漸層點綴、專業留白、柔和陰影
- **vercel** — 純黑底、幾何精準、開發者氛圍
- **cal** — 柔和圓角、平靜配色、時間優先
- **notion** — 白底、文字優先、塊狀排版
- **resend** — 極簡電子郵件感、黑白高對比
- **mintlify** — 文檔淨空感、側欄清晰、重閱讀節奏
- **superhuman** — 毛玻璃層次、鍵盤優先、精練資訊密度
- **wise** — 溫和綠色、金融專業、去複雜化

### 資料密集 (Data-dense)
> 表格為王、高資訊密度、密集元件、功能優先

- **clickhouse** — 分析工具、密集圖表、技術感橙黃
- **posthog** — 產品分析、活潑粉紅、資料視覺化
- **sentry** — 錯誤追蹤、紫色警示、時間序列
- **supabase** — 綠色電光、資料庫介面、深色預設
- **airtable** — 表格優先、橘色強調、試算表 UX
- **semrush** — 行銷儀表板、橘藍對比、密集 KPI
- **mongodb** — 綠色技術、資料模型視覺化
- **sanity** — CMS 專業、藍色系、結構化內容

### 終端機美學 (Terminal / Dev-native)
> 等寬字、深色底、開發者原生感、指令優先

- **warp** — 現代終端機、玫粉強調、AI 命令列
- **cursor** — AI IDE、深色專業、程式碼高亮
- **claude** — 橘褐色、書卷氣、對話優先
- **opencode.ai** — 開源開發、簡潔命令
- **raycast** — 啟動器美學、鍵盤驅動、紅色品牌
- **ollama** — 本地 LLM、黑白極簡、技術極客

### 科技未來感 (Futuristic / Cyber)
> 霓虹漸層、動態效果、賽博感、AI 氛圍

- **x.ai** — 純黑未來感、極簡科技
- **runwayml** — 創意 AI、前衛視覺、電影感
- **replicate** — AI 模型市集、漸層霓虹
- **nvidia** — GPU 綠、科技硬體、動態效果
- **spacex** — 太空感、深黑藍、工程美學
- **elevenlabs** — 語音 AI、紫色漸層、聲波視覺
- **minimax** — AI 平台、科技藍紫
- **mistral.ai** — 法式 AI、橘紅漸層、風感流動
- **together.ai** — 協作 AI、青藍光感
- **voltagent** — Agent 平台、電光感
- **cohere** — 企業 LLM、暖橙漸層、柔和科技感

### 溫暖擬物 (Warm / Skeuomorphic)
> 圓角柔和、立體陰影、童趣、人情味

- **clay** — 黏土質感、擬物立體、遊戲感
- **lovable** — AI 建站、粉紫漸層、可愛感
- **intercom** — 對話客服、溫暖橘、圓潤元件
- **pinterest** — 視覺靈感、紅色、瀑布流

### 奢華精品 (Luxurious)
> 大圖戲劇性、攝影感、精緻留白、品牌至上

- **ferrari** — 賽車紅、義式奢華、速度感
- **lamborghini** — 銳利幾何、戰鬥美學、黑黃
- **bmw** — 德式精準、藍黑白、工藝感
- **tesla** — 科技精品、極簡未來車
- **renault** — 法式優雅、現代黃色品牌

### 企業專業 (Corporate)
> 保守穩重、藍灰系、結構化資訊、信任感

- **ibm** — 藍巨人、經典企業、Carbon Design
- **hashicorp** — DevOps 專業、多產品線、藍紫
- **coinbase** — 加密金融、藍色穩重、合規感
- **kraken** — 交易所、深紫專業、金融強度
- **revolut** — 數位銀行、黑色極簡專業

### 消費者友善 (Consumer-friendly)
> 親和力、色彩豐富、生活化、易用優先

- **airbnb** — 珊瑚紅、生活場景、溫暖旅宿
- **uber** — 黑底、效率感、城市出行
- **spotify** — 綠色活力、音樂沉浸、深色預設
- **webflow** — 設計工具、藍色活潑、創作者
- **zapier** — 橘色流程、工具整合、友善
- **miro** — 黃色白板、協作彩色

### 毛玻璃流體 (Glassmorphism)
> backdrop-blur、半透明、漸變流動

- **framer** — 互動原型、藍紫漸層、流體
- **figma** — 設計工具、多色彩、協作

### 開發平台 (Developer Platform)
> 極簡 + 資料密集混合、面向開發者

- **expo** — React Native、深色技術
- **composio** — 工具編排、開發者 UX
- **figma** — 協作設計（見毛玻璃）

---

## 按品牌類型分類（依產業對標）

### AI / LLM
claude, cohere, mistral.ai, x.ai, ollama, runwayml, replicate, elevenlabs, minimax, together.ai, voltagent

### 開發工具 / IDE
cursor, warp, raycast, figma, framer, vercel, webflow, lovable, opencode.ai, expo, composio

### 資料 / 後端 / DevOps
supabase, mongodb, clickhouse, sentry, posthog, sanity, hashicorp

### 金融 / 支付 / 加密
stripe, wise, revolut, coinbase, kraken

### 生產力 SaaS
linear.app, notion, airtable, cal, miro, zapier, superhuman, intercom, mintlify, resend

### 消費者 App
airbnb, uber, spotify, pinterest

### 汽車 / 精品 / 硬體
apple, tesla, bmw, ferrari, lamborghini, renault, nvidia, spacex, ibm

### 行銷 / 分析
semrush, posthog

---

## 混搭建議（常見組合）

以 `primary` 為基底風格，從其他風格抽取特定面向：

| 主風格 | 配色 override | 字體 override | 元件 override | 用途 |
|--------|--------------|--------------|--------------|------|
| apple | stripe | apple | apple | 極簡基底 + Stripe 溫暖漸層 |
| linear.app | vercel | linear.app | linear.app | 科技冷感 + 純黑戲劇 |
| notion | notion | apple | airtable | 文字優先 + 資料表格 |
| cursor | cursor | warp | raycast | 終端機混搭美學 |
| claude | claude | notion | apple | 對話 + 文檔 + 精品 |

---

## Metadata 欄位

每個風格可從 `DESIGN.md` 分段覆蓋：

| 覆蓋欄位 | 對應 DESIGN.md 段落 |
|---------|---------------------|
| `color` | Color Palette & Roles |
| `typography` | Typography Rules |
| `components` | Components / Buttons / Cards / Inputs |
| `layout` | Spacing / Grid / Section Rhythm |
| `animation` | Motion / Transitions |

---

**使用方式：** 執行 `/ui-style` 進入互動選擇流程。
