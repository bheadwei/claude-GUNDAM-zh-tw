# 動畫分級 L1／L2／L3（`ui-style-compliance` 附屬檔）

**什麼時候讀：只有動畫等級是 L2 或 L3 時才讀**（`SKILL.md` 1.3 節）。

- 等級來自 `.claude/taskmaster-data/ui-style.json` 的頂層 `motion`；`/ui-page` 某一頁另外調過的，以那一頁的 IA snippet「動畫等級」為準
- **沒有 `motion` 欄位就當作 L1**（舊格式的 `ui-style.json`）
- **L1 不必讀本檔。** 所有等級都要守的底線（微互動時長、`prefers-reduced-motion`、可暫停）在 `SKILL.md` 2.6③，那裡是唯一來源

本檔是 L2／L3 規則、動畫函式庫速查與常見坑的**唯一來源**。API 細節和版本一律**用 context7 查當前版本**，本檔不寫。

---

## 1. 給使用者看的選項

`/ui-style` 和 `/ui-page` 問「動畫要多少」時，選項文字照這張表。**這一節是給非專業使用者看的，不寫任何函式庫名或技術名詞。**

| 等級 | 感覺 | 像什麼 | 適合誰 | 代價 |
|---|---|---|---|---|
| **L1 安靜** | 畫面穩定，只有按下去、滑過去時有輕微回應 | 像翻一本排版好的書 | 管理後台、文件站、長輩客群、資訊為主的網站 | 最輕、最快、最少出錯；但第一眼的記憶點要靠字體和版面撐 |
| **L2 有節奏** | 往下捲時內容依序出現，標題和圖片有一點前後層次 | 像好的品牌官網或雜誌的線上專題 | 品牌形象頁、在地店家、作品集、活動頁 | 載入稍重、要多花時間調；調不好會變成「每段都在飄」 |
| **L3 沉浸** | 捲動像在操作一段影片或一個場景，背景會動、有段落會停住讓你橫向看 | 像產品發表會網站或得獎的互動專題 | 新品發表、作品集的主打作品、一次性的活動 | 手機上耗電、慢的網路會等；製作和維護成本最高，素材（影片、3D）要另外準備 |

**依網站類型推薦**（`ui-style.json` 的 `site_type`）：

| 網站類型 | 推薦 | 限制 |
|---|---|---|
| 管理後台、文件站 | L1 | **不提供 L3** |
| 品牌形象頁、在地店家、作品集 | L2 | — |
| 其他 | L1 | — |

---

## 2. 每一級允許什麼

這一節開始是技術內容，可以寫函式庫名。

| | L1 安靜 | L2 有節奏 | L3 沉浸 |
|---|---|---|---|
| **允許的技術** | 只有 CSS `transition`／`animation`。規則在 `SKILL.md` 2.6③ | L1 全部＋原生捲動驅動動畫、View Transitions；原生做不到時才加平滑捲動（Lenis）和捲動動畫（GSAP＋ScrollTrigger、SplitText），React 專案可用 Motion | L2 全部＋釘選段落、橫向捲動相簿、動態背景（WebGL 漸層、Vanta.js）、3D（three.js、Spline）、影片拆幀捲動 |
| **不允許** | 任何動畫函式庫的 import | WebGL、3D、影片拆幀；「每一段都同一個淡入上移」 | 一頁超過一個重型場景（WebGL、3D、影片拆幀擇一當主角） |
| **效能預算** | 不增加任何動畫用的 JS | 只動 `transform` 和 `opacity`；捲動時主執行緒不出現超過 50ms 的長任務；首屏文字不等 JS 就看得到 | L2 的全部＋重型素材在首屏之後才載入；手機有降級版（見第 3 節）；首屏不因為素材還沒載完而空白 |
| **節制規則** | — | 一頁一個「被安排好的時刻」（一段開場、一次揭露）勝過到處都在動 | 同 L2，而且沉浸段落以外的地方回到 L2 的節奏 |

**先問「原生 CSS 做不做得到」**，做得到就不要加依賴。原生的捲動驅動動畫跑在合成執行緒上，
和捲動本身一樣順；但支援度還不完整（見第 5 節），所以一定要做成**漸進增強**：不支援的瀏覽器看到的是靜態的完整內容。

**KB 預算沒有寫死數字**：專案差異太大，沒有可以查證的通用門檻。需要時在專案的 IA 文件或 DESIGN.md 定。

---

## 3. `prefers-reduced-motion: reduce` 時怎麼降級

使用者在系統設定「減少動態效果」時，每一級都要降：

| 等級 | 降級成 |
|---|---|
| L1 | 照 `SKILL.md` 2.6③：自動播放改靜態，微互動可以保留但不位移 |
| L2 | 關掉平滑捲動和視差；進場動畫改成直接顯示（或只保留不位移的淡入）；逐字進場改成整句直接出現 |
| L3 | L2 的全部＋動態背景換成靜態圖或 CSS 漸層；影片拆幀改成顯示一張代表畫面；釘選和橫向捲動改成一般的直向排列 |

實作上的三個重點：

- **用 CSS 的 `@media (prefers-reduced-motion: no-preference)` 包住動畫**，而不是預設開、偵測到才關——
  JS 還沒跑完的那一瞬間就不會先動一下
- **平滑捲動函式庫自己處理了不代表動畫也停了。** Lenis 的 README（2026-10-16 查）寫它預設會尊重這個設定、關掉平滑效果，
  但 GSAP 的動畫不會跟著停，要另外依同一個 media query 關掉（用法查 context7）
- 降級版也要**完整可讀**：不能因為關了動畫，某段內容就停在 `opacity: 0` 看不見

---

## 4. 動畫參數集中成 motion tokens

和色彩、間距一樣，動畫的數字也是 token（`SKILL.md` 2.1 的 token 概念延伸到動畫）。**不要把時長、距離、easing 散在各個元件裡。**

CSS 端：

```css
:root {
  --motion-duration-fast: 150ms;
  --motion-duration-base: 240ms;
  --motion-duration-slow: 480ms;
  --motion-ease-out: cubic-bezier(0.2, 0, 0, 1);
  --motion-distance-sm: 8px;
  --motion-distance-md: 24px;
  --motion-stagger: 60ms;
}
```

JS 端（用了 GSAP、Lenis 這類函式庫時）：集中在**一個** `CONFIG` 物件，每個區塊從它讀，不在區塊裡寫數字。

```js
const MOTION = {
  reveal: { distance: 24, duration: 0.6, stagger: 0.06 },
  parallax: { hero: 0.3 },
  smoothScroll: { enabled: true },
}
```

數值是示意，實際值照 DESIGN.md 的 Motion 段落；沒有就先用上面這組，**整個專案只有一組**。
改「太花」「太慢」這類回饋時，只改 token，不逐一改元件。

---

## 5. 瀏覽器支援度

**查證日期 2026-10-16**，資料取自 MDN 頁面背後的 browser-compat-data（`mdn/browser-compat-data`，同日抓取）。
Edge 跟隨 Chrome。這張表會過期——每次 skill-curator 更新設計走向時要重查。

| 功能 | Chrome／Edge | Safari | Firefox | 來源 |
|---|---|---|---|---|
| 捲動驅動動畫 `animation-timeline: scroll()`／`view()` | 115 起 | 26 起 | **穩定版尚未支援**：資料標 159 起，查證當天 159 還是 beta（排定 2026-10-27 發布），穩定版是 158 | https://developer.mozilla.org/docs/Web/CSS/Reference/Properties/animation-timeline （2026-10-16） |
| `view-timeline` | 115 起 | 26 起 | 同上，159 起 | https://developer.mozilla.org/docs/Web/CSS/Reference/Properties/view-timeline （2026-10-16） |
| 同頁 View Transitions（`document.startViewTransition()`） | 111 起 | 18 起 | 144 起 | https://developer.mozilla.org/docs/Web/API/Document/startViewTransition （2026-10-16） |
| 跨頁 View Transitions（`@view-transition`） | 126 起 | 18.2 起 | **不支援** | https://developer.mozilla.org/docs/Web/CSS/Reference/At-rules/@view-transition （2026-10-16） |
| `prefers-reduced-motion` | 74 起 | 10.1 起 | 63 起 | https://developer.mozilla.org/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-motion （2026-10-16） |

怎麼用這張表：

- 捲動驅動動畫：用 `@supports (animation-timeline: view())` 包起來，不支援時內容直接顯示。
  需要所有瀏覽器都有效果時（例如 L3 的主場景），才改用 ScrollTrigger
- 跨頁 View Transitions：Firefox 不支援時就是一般換頁，不會壞，可以直接用
- 舊版 `SKILL.md` 曾寫「Firefox 132+、Safari 18+ 支援捲動驅動動畫」，**兩個數字都是錯的**，已依上表更正

---

## 6. 函式庫速查

用途和選擇理由在這裡；**安裝方式、API、版本一律用 context7 查**。

| 用途 | 首選 | 備註（2026-10-16 查各 repo） |
|---|---|---|
| 平滑捲動 | Lenis | 搭 ScrollTrigger 時要同步捲動事件（見第 7 節） |
| 捲動動畫 | GSAP＋ScrollTrigger、SplitText | 視差、釘選、逐字進場。GSAP 的 README 寫明**全部外掛都免費、可商用**（授權是 GSAP 自己的 no-charge license，不是 MIT） |
| React 動畫 | Motion（原名 Framer Motion）、React Bits | Motion 的 README 寫明 Framer Motion 已改名為 Motion，也支援純 JS，不只 React |
| 動態背景 | WebGL 漸層、Vanta.js、ShaderGradient | **只用在 L3**，注意手機效能。Vanta.js 需要 three.js，repo 最後一次更新是 2024-03。ShaderGradient 有 React 和 Vue 3 的官方套件，**純 HTML 專案用不了**，改用 CSS 漸層或自己寫 WebGL |
| 3D | three.js、Spline | 有 3D 模型（GLB）才用 |
| 影片拆幀捲動 | ffmpeg 轉 WebP 序列，用 canvas 依捲動位置換幀 | 素材量見第 7 節 |

---

## 7. 常見坑

| 坑 | 症狀 | 怎麼做 | 查證 |
|---|---|---|---|
| **Lenis 搭 ScrollTrigger 沒同步** | 觸發位置對不上、視差慢半拍 | 要 `lenis.on('scroll', ScrollTrigger.update)`，並讓 Lenis 跟著 GSAP 的 ticker 更新（完整寫法查 context7） | Lenis README 的 GSAP ScrollTrigger 範例，2026-10-16 |
| **以為平滑捲動關了，動畫就都關了** | 開了「減少動態效果」，平滑捲動停了但進場動畫照跑 | 見第 3 節 | Lenis README 的 Reduced motion 節，2026-10-16 |
| **ShaderGradient 用在純 HTML** | 沒有可用的套件 | 只在 React 或 Vue 3 專案用；純 HTML 改用 CSS 漸層或 WebGL | ShaderGradient README 的 Installation 節，2026-10-16 |
| **影片拆幀素材太大** | 首屏卡住、手機流量爆掉 | 10 秒 × 30fps＝300 張圖。gmap 的經驗值是總量 10～30MB（依解析度和壓縮而異，本模板沒有實測）。首屏之後才載入、手機用較低解析度或較少幀、一定要有一張代表畫面當 fallback | 張數是算術；MB 範圍是 gmap 原文的經驗值，**未查證** |
| **進場動畫的初始狀態寫死在 CSS** | JS 載入失敗或很慢時，內容永遠停在 `opacity: 0` 看不見 | 「藏起來等動畫」的狀態只在 JS 確定會跑時才套（例如 JS 啟動後在 `<html>` 加一個 class） | 一般作法 |
| **素材晚到，觸發位置跑掉** | 延遲載入的圖片或網頁字型到了之後，版面高度變了，動畫在錯的位置觸發 | 素材載入完要重新計算觸發位置（ScrollTrigger 的作法查 context7）；圖片先寫好寬高比，讓版面不跳 | 一般作法 |
| **動到會觸發重排的屬性** | 捲動卡頓 | 只動 `transform`、`opacity`；不要動 `top`、`left`、`width`、`height`、`margin` | 一般作法 |
| **每一段都同一個淡入上移** | 「很 AI」 | 一頁只安排一兩個重點時刻。這也是 `anti-ai.md` 產出後清單的一項 | `anti-ai.md` |

---

## 出處

- 分級、函式庫速查、常見坑的原始素材：gmap-landing-page skill（本機 `D:\wei\sunny_課程\landingpage_design_demo\.claude\skills\gmap-landing-page\SKILL.md`，2026-10-15 分析，見 `.claude/context/decisions/skill-curator-2026-10-15-1530-frontend-gmap-analysis.md`）。本檔已改寫並逐項查證，修正了兩處：ShaderGradient 不只 React、Motion 不只 React
- 瀏覽器支援度：MDN（網址見第 5 節）、`mdn/browser-compat-data`
- 函式庫事實：各 repo 的 README（darkroomengineering/lenis、greensock/GSAP、motiondivision/motion、ruucm/shadergradient、tengbao/vanta），2026-10-16 以 `gh api` 讀取
