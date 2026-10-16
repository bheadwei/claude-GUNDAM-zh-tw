# UI 設計風格目錄

本目錄收錄 104 種設計系統規範，供 `/ui-style` 指令及前端開發時查詢使用。

**這些是「參考風格」，不是品牌授權。** 每份 DESIGN.md 描述的是某個品牌網站公開呈現的視覺語言，用來給你的專案定調；商標、標誌、品牌名稱屬原公司所有。做出來的介面不要放對方的 logo、不要用對方的品牌名或招牌文案，也不要讓人誤以為是對方的官方網站。

每個風格的完整規範位於 `.claude/ui/<codename>/DESIGN.md`（上游原文，含色票、字體、間距、元件）。大多是英文；`jp-*` 是日文原檔，借給繁中專案時字型怎麼換見 `ui-style-compliance` 的 `fonts-cjk.md`。來源與授權記在每份的 `SOURCE.json` 和 `_sources.json`，授權原文在 `_licenses/`。

說明後面標「AI 痕跡」的，是照 `ui-style-compliance/anti-ai.md` 的判準看起來接近 AI 常見樣式的風格。它們本身是真實品牌、照做不算違規，但「看預覽選」提方向時要照 anti-ai.md 的規則避開或標註。

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
- **openai** — 純黑白研究機構感、全 pill 幾何、OpenAI Sans 唯一字體
- **shadcn** — zinc 中性灰階、CSS 語意 token 系統、元件庫預設美學
- **perplexity** — 米白紙感、深青單一強調、知識書卷氣

### 資料密集 (Data-dense)
> 表格為王、高資訊密度、密集元件、功能優先

- **clickhouse** — 分析工具、密集圖表、技術感橙黃
- **posthog** — 產品分析、活潑粉紅、資料視覺化
- **sentry** — 錯誤追蹤、紫色警示、時間序列
- **supabase** — 綠色電光、資料庫介面、深色預設
- **airtable** — 表格優先、橘色強調、試算表 UX
- **attio** — 新世代 CRM、無彩度精準灰階、12px 高密度表格美學
- **huggingface** — AI 社群、灰階列表 + 品牌黃點綴、tag pills 密集內容
- **semrush** — 行銷儀表板、橘藍對比、密集 KPI（依官方設計系統抽取）
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
- **zed** — 高效編輯器、暖灰紙感 + 工程藍、襯線標題 + 實體按鍵陰影
- **neon** — 純黑 + 電光綠 pill、大字階、終端指令即 CTA
- **railway** — 深紫黑夜景、亮紫層次、襯線編輯感標題

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
- **granola** — 紙感筆記、橄欖綠 + 超大襯線標題、有機手作溫度
- **lovable** — AI 建站、粉紫漸層、可愛感
- **intercom** — 對話客服、溫暖橘、圓潤元件
- **pinterest** — 視覺靈感、紅色、瀑布流
- **oura** — 健康穿戴：米色紙張感底、高對比襯線標題、芥末黃與橄欖綠，只有按鈕是藍（AI 痕跡：高——米白底、襯線標題、陶土強調三個都中，當對照組）

### 奢華精品 (Luxurious)
> 大圖戲劇性、攝影感、精緻留白、品牌至上

- **ferrari** — 賽車紅、義式奢華、速度感
- **lamborghini** — 銳利幾何、戰鬥美學、黑黃
- **bmw** — 德式精準、藍黑白、工藝感
- **tesla** — 科技精品、極簡未來車
- **renault** — 法式優雅、現代黃色品牌
- **omd-farfetch** — Farfetch 精品電商：純白底純黑字、沒有品牌色、沒有圓角，商品當主角

### 企業專業 (Corporate)
> 保守穩重、藍灰系、結構化資訊、信任感

- **ibm** — 藍巨人、經典企業、Carbon Design
- **clerk** — auth SaaS、紫強調、精工多層按鈕陰影
- **hashicorp** — DevOps 專業、多產品線、藍紫
- **coinbase** — 加密金融、藍色穩重、合規感
- **kraken** — 交易所、深紫專業、金融強度
- **revolut** — 數位銀行、黑色極簡專業
- **mastercard** — 溫暖灰米色底配訊號橘、大圓角、膠囊與正圓造型（AI 痕跡：中——米白底＋接近陶土的橘，字是無襯線）
- **omd-cathay** — 國泰世華：近白底、深墨綠主按鈕配亮綠，穩重但不沉重的銀行

### 消費者友善 (Consumer-friendly)
> 親和力、色彩豐富、生活化、易用優先

- **airbnb** — 珊瑚紅、生活場景、溫暖旅宿
- **uber** — 黑底、效率感、城市出行
- **spotify** — 綠色活力、音樂沉浸、深色預設
- **webflow** — 設計工具、藍色活潑、創作者
- **zapier** — 橘色流程、工具整合、友善
- **miro** — 黃色白板、協作彩色

### 和風靜謐 (Japanese Quiet)
> 白底或深色底、全站明朝、字距行距拉開、只有一個傳統色點綴（非科技業）

- **jp-ippodo** — 一保堂茶舖：白底明朝、字距行距拉得很開、茶褐色點綴，像茶室一樣安靜（日文原檔，字型對照見 fonts-cjk.md）
- **jp-toraya** — 虎屋和菓子：純白底配深藏青，明朝標題，櫻粉、抹茶綠等季節淡色（日文原檔，字型對照見 fonts-cjk.md）
- **jp-funabashiya** — 船橋屋葛餅：全站明朝黑白、滿版照片加白色細框、臙脂紅日期標籤（日文原檔，字型對照見 fonts-cjk.md）
- **jp-kayanoya** — 茅乃舎高湯：黃昏古民家滿版照片疊白色明朝字，商品頁換成白底（日文原檔，字型對照見 fonts-cjk.md）
- **jp-kaikado** — 開化堂銅茶筒：白底、極細明朝，唯一的顏色是古銅（日文原檔，字型對照見 fonts-cjk.md）
- **jp-sousou** — SOU・SOU 和風布料：淺灰白底、全站明朝、芥末金點綴，像現代和風雜誌（日文原檔，字型對照見 fonts-cjk.md）
- **jp-nakagawa** — 中川政七商店：白底灰階，黑體配明朝撐出端正感，幾乎沒有彩色（日文原檔，字型對照見 fonts-cjk.md）
- **jp-onibuscoffee** — ONIBUS 咖啡：烘豆紙袋的象牙色底、黑色細線、字距開大，幾乎沒有裝飾（日文原檔，字型對照見 fonts-cjk.md）
- **jp-kai-ryokan** — 星野 界 溫泉旅館：直排明朝標題、文字帶藏青到淡藍的漸層、青色訂房鈕（日文原檔，字型對照見 fonts-cjk.md）
- **jp-mitsui-kyoto** — 三井京都飯店：深焦茶色底、全站明朝，只有照片有彩度，橄欖綠與金點綴（日文原檔，字型對照見 fonts-cjk.md）
- **jp-grand-seiko** — Grand Seiko 手錶：白底配接近黑的深藏青、全站明朝、方形按鈕（日文原檔，字型對照見 fonts-cjk.md）
- **omd-muji** — 無印良品：近白底灰黑字、全站只有一個酒紅，空無一物的器皿感

### 編輯刊物感 (Editorial / Print)
> 像印刷品搬上網：標題字型有個性、分欄與細線、照片和文章是主角（非科技業）

- **wired** — WIRED 雜誌：白底黑字、窄長的襯線大標題、內文也用襯線（AI 痕跡：中——表 1 第 3 種報紙排版，但它本來就是刊物）
- **theverge** — The Verge：近黑底配螢光薄荷綠和紫，新聞卡像彩色派對傳單（AI 痕跡：中——表 1 第 2 種黑底加螢光，但另有多色色塊）
- **aljazeera** — 半島電視台：白紙底、密集 Roboto 標題、一個橘色當欄目標示，快訊用紅
- **omd-ft** — 金融時報：整頁 FT 招牌的淡鮭魚粉紙色、暖棕字、襯線大標題、深青按鈕（AI 痕跡：中——紙色底＋襯線標題，是 FT 真的報紙色）
- **jp-brutus** — BRUTUS 雜誌：白底黑字、粗黑日文黑體配幾何西文字、專題各有自己的顏色（日文原檔，字型對照見 fonts-cjk.md）
- **jp-popeye** — POPEYE 雜誌：強烈鈷藍配白、一點螢光青和橘，版面滿而活潑（日文原檔，字型對照見 fonts-cjk.md）
- **jp-kurashi-no-techo** — 暮しの手帖：白紙明朝黑字，鵝黃、淡藍像印刷特別色的色塊，完全沒有漸層（日文原檔，字型對照見 fonts-cjk.md）
- **jp-dancyu** — dancyu 美食雜誌：料理照片滿版，只用朱紅、黑、生成色三色，沒有圓角（日文原檔，字型對照見 fonts-cjk.md）
- **omd-readmoo** — 讀墨電子書：灰白紙張感底、天藍主色、分類標籤用宋體，像安靜的書店
- **omd-pixnet** — 痞客邦：白底棕炭色字、整個介面都用 Noto Serif TC 宋體，只有登入鈕是橘

### 在地零售與生活 (Retail & Everyday)
> 商品、價格、照片排得滿，品牌色鮮明，以成交與日常使用為主（非科技業）

- **starbucks** — 星巴克：淡米色底配四種深淺的星巴克綠、按鈕全是膠囊形，像店裡的招牌
- **nike** — Nike：純黑白、超大的大寫標題直接壓在運動照片上，商品卡排得很密
- **omd-icook** — 愛料理：白底與暖白卡片、珊瑚紅主色，料理照片是主角
- **omd-pinkoi** — Pinkoi 設計市集：淺灰白底、藍綠主按鈕、珊瑚橘購買鈕，排得密
- **omd-familymart-tw** — 全家便利商店：白底資訊密集、一條細細的品牌綠、微軟正黑
- **omd-poya** — 寶雅：白底、亮粉紅膠囊按鈕、暖棕黑字，中文黑體配西文襯線
- **omd-momoshop** — momo 購物：灰底桃紅，商品圖、價格徽章、倒數計時排得又滿又急
- **omd-greenvines** — 綠藤生機：白底配深森林綠、大照片放在灰綠區塊、一個燒橘重點
- **omd-bloomandwild** — Bloom & Wild 花店：白底、亞麻米色區塊、檸檬黃與松綠點綴（元件段落偏薄）

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
claude, openai, perplexity, huggingface, cohere, mistral.ai, x.ai, ollama, runwayml, replicate, elevenlabs, minimax, together.ai, voltagent

### 開發工具 / IDE
cursor, zed, warp, raycast, figma, framer, vercel, webflow, lovable, opencode.ai, expo, composio, shadcn

### 資料 / 後端 / DevOps
supabase, neon, railway, clerk, mongodb, clickhouse, sentry, posthog, sanity, hashicorp

### 金融 / 支付 / 加密
stripe, wise, revolut, coinbase, kraken, mastercard, omd-cathay

### 生產力 SaaS
linear.app, notion, airtable, attio, granola, cal, miro, zapier, superhuman, intercom, mintlify, resend, clay

### 消費者 App
airbnb, uber, spotify, pinterest

### 汽車 / 精品 / 硬體
apple, tesla, bmw, ferrari, lamborghini, renault, nvidia, spacex, ibm, oura

### 行銷 / 分析
semrush, posthog

### 非科技業

以下六類都是非科技業的實站品牌。`jp-*` 是日文原檔，`omd-*` 裡 TW 的有繁中字型實例。

#### 餐飲與茶
starbucks, jp-ippodo, jp-toraya, jp-funabashiya, jp-onibuscoffee, jp-kayanoya, omd-icook

#### 工藝與生活選物
jp-nakagawa, jp-kaikado, jp-sousou, omd-muji, omd-greenvines, omd-bloomandwild, omd-pinkoi

#### 雜誌與編輯
wired, jp-brutus, jp-popeye, jp-kurashi-no-techo, jp-dancyu, omd-readmoo, omd-pixnet

#### 新聞媒體
theverge, aljazeera, omd-ft

#### 旅館與精品
jp-kai-ryokan, jp-mitsui-kyoto, jp-grand-seiko, omd-farfetch

#### 在地品牌與電商
omd-familymart-tw, omd-poya, omd-momoshop, nike

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

每個風格可從 `DESIGN.md` 分段覆蓋（新舊兩種格式的標題都認，忽略標題前的編號）：

| 覆蓋欄位 | 對應 DESIGN.md 段落（任一） |
|---------|---------------------|
| `color` | `Color Palette & Roles`、`Colors` |
| `typography` | `Typography Rules`、`Typography` |
| `components` | `Component Stylings`、`Components` |
| `layout` | `Layout Principles`、`Layout` |

抽取規則（含新格式要一併讀檔頭 YAML、找不到段落時怎麼說）見
`ui-style-compliance` skill 的 1.2 節（唯一來源）。動畫不從品牌檔抽，改由 `ui-style.json` 的 `motion` 決定。

---

**使用方式：** 執行 `/ui-style` 進入互動選擇流程。
