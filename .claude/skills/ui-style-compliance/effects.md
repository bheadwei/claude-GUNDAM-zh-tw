# 前端效果庫（`ui-style-compliance` 附屬檔）

**什麼時候讀**（`SKILL.md` 1.3 節）：

| 情境 | 讀哪幾節 |
|---|---|
| 要產出一整頁或一個區塊（不是修單一元件） | 第 1、2 節，再讀挑中的配方 |
| 動畫等級是 L1 | 同上，但**只能用第 2 節標 L1 的配方**（純 CSS） |
| 使用者說「做好看一點」「要有動態」「像某某網站那樣」 | 第 1、2 節＋第 4 節（去哪找元素） |
| 使用者貼了參考網站 | 第 5 節（萃取風格 DNA） |

本檔是**效果配方、挑元素的來源、參考網站流程**的唯一來源。其他規則不在這裡重寫：

- 各等級允許什麼技術、效能預算、`prefers-reduced-motion` 怎麼降、函式庫的用途與選擇 → `motion.md`（第 2、3、6 節）
- 反 AI 感、「題材優先」、記憶點 → `anti-ai.md`
- API 與版本 → 一律用 context7 查當前版本，本檔片段只示範結構

---

## 1. 怎麼挑（每次都先讀）

效果的工作是**解釋層級**或**回應互動**（`SKILL.md` 2.6③）。好看不是因為效果多，是因為少數幾個效果講的是同一件事。

1. **一頁挑 1～3 個主角效果**，其他段落只有 L1 的微互動加一種共用的進場。主角通常放在首屏和一個中段的「被安排好的時刻」（`motion.md` 第 2 節的節制規則）
2. **每個效果要答得出一句話**：「它讓使用者注意到哪一層？」或「它回應了哪個動作？」答不出來就不放
3. **機制和材質分開看**。第 3 節的配方來自一份水墨題材的提案，**水墨是那個題材的材質，不是預設值**。
   要搬到別的題材時，保留機制、換材質：

   | 機制 | 水墨題材的材質 | 換題材的例子 |
   |---|---|---|
   | 不規則邊緣的揭露（3.2） | 墨暈擴散 | 紙張撕邊、顏料筆刷、光斑擴散 |
   | 程序生成的層疊剪影（3.5） | 遠山 | 海浪、城市天際線、沙丘、等高線 |
   | 游標拖尾（3.6） | 墨滴 | 水波、粉塵、光點 |
   | 字與字之間的分隔（3.7） | 直排豎線 | 西文的細橫線、編號、字重對比 |

   材質從題材本身取（`anti-ai.md` 原則 1）。**SaaS、後台、文件站不要用水墨、紙紋這類手工材質。**
4. **等級是上限**：配方標的等級高於專案的 `motion`（或這一頁 IA snippet 的「動畫等級」）就不能用
5. **寫進 1.4 的風格載入確認**：「已讀附屬檔」那一行寫 `effects.md（主角：3.2、3.7）`，讓審查的人知道你挑了什麼

### 所有配方共用的骨架

每個配方都假設頁面已有這三樣，配方裡不再重複：

```js
const CONFIG = { /* 所有時長、距離、間隔都在這裡，見 motion.md 第 4 節 */ }
const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches
const fine = matchMedia('(hover: hover) and (pointer: fine)').matches
```

- 用 GSAP 時一律寫 `gsap.from(...)`（初始狀態由 JS 設），**不要**在 CSS 先寫 `opacity: 0`——JS 沒載到內容就永遠看不見（`motion.md` 第 7 節）
- 用 Lenis 時和 ScrollTrigger 的同步寫法見 `motion.md` 第 7 節
- 每個配方都要在 `reduce` 為真時有一條**直接顯示完整內容**的路

---

## 2. 配方索引

「依賴」欄的純 CSS／純 JS 表示不需要任何函式庫。

| # | 配方 | 等級 | 依賴 | 角色 | 適合 | 不適合 |
|---|---|---|---|---|---|---|
| 3.1 | 載入頁（真實載入進度） | L2 | GSAP（可改純 JS） | 開場 | 首屏素材重的品牌頁、活動頁 | 工具、後台、回訪頻繁的頁面、首屏只有文字 |
| 3.2 | 有機邊緣遮罩揭露 | L2（靜態版 L1） | SVG filter＋GSAP | 主角 | 照片是主角的在地店家、工藝、作品集 | 產品截圖、資訊圖表（邊緣會被吃掉） |
| 3.3 | 焦點輪播（中央放大、兩側淡出） | L1（CSS 版）／L2 | 純 CSS 或 GSAP | 主角 | 3～8 件代表作、招牌商品 | 需要比較規格的商品列表 |
| 3.4 | 交疊輪播＋進度條 | L2 | GSAP（可改 CSS） | 配角 | 環境照、空間照 | 每張都要被仔細看的內容 |
| 3.5 | 程序生成層疊剪影＋視差 | L2（靜態版 L1） | 純 JS＋SVG（視差用 GSAP） | 分隔或首屏背景 | 有地景、地方感的題材 | 資訊密集頁、管理後台 |
| 3.6 | 首屏游標拖尾 | L2 | 純 JS（canvas） | 首屏小驚喜 | 品牌頁首屏 | 手機（不做）、表單與工具頁 |
| 3.7 | 標題分隔＋逐字浮現 | L1（靜態）／L2（動畫） | 純 CSS／GSAP | 全站節奏 | 中日文標題、短標題 | 長標題、會被翻譯的動態文字 |
| 3.8 | 字距按鈕＋填色掃過 | L1 | 純 CSS | 互動回饋 | 有襯線或書法感的品牌 | 密集的工具列、表格內按鈕 |
| 3.9 | 紙紋雜訊疊層 | L1 | 純 CSS | 底材 | 印刷、手作、復古題材 | 科技、醫療、需要乾淨感的介面 |
| 3.10 | 釘選橫向相簿 | L3 | GSAP＋ScrollTrigger | 主角 | 作品集、菜色、系列商品（5～10 張） | 少於 4 張、手機（改原生橫捲） |
| 3.11 | 跑馬燈＋捲動加速 | L2 | GSAP | 配角 | 標語、品項名稱的帶狀裝飾 | 承載必讀資訊（使用者讀不完） |
| 3.12 | 遮罩上推與 clip-path 揭露 | L2 | GSAP | 進場 | 大標、首屏主圖、相簿 | 每一段都用（會變成同一個淡入上移） |
| 3.13 | 磁吸按鈕、傾斜卡片、自訂游標 | L2 | GSAP | 互動回饋 | 作品集、創意品牌 | 觸控裝置（不做）、需要精準點擊的介面 |
| 3.14 | 數字滾動 | L2 | GSAP（可改純 JS） | 配角 | **有來源的**真實數字 | 編出來的信任條（`anti-ai.md` 不准編事實） |

---

## 3. 配方

### 3.1 載入頁（真實載入進度）

**機制**：進度數字跟著首屏素材（圖片、網頁字型）實際載完的比例走，不是假的計時器；載完後載入頁淡出、首屏的進場動畫接著跑。

```html
<head>
<script>
try {
  if (!matchMedia('(prefers-reduced-motion: reduce)').matches
      && sessionStorage.getItem('intro-seen') !== '1')
    document.documentElement.classList.add('intro')
} catch (e) {}
</script>
<style>
.loader { display: none }
html.intro .loader { display: grid; position: fixed; inset: 0; z-index: 200 }
html.intro body { overflow: hidden }
</style>
```

```js
const srcs = CONFIG.loader.preload            // 只放首屏會看到的圖
const jobs = srcs.map(s => new Promise(r => { const i = new Image(); i.onload = i.onerror = r; i.src = s }))
jobs.push(document.fonts ? document.fonts.ready : Promise.resolve())
let done = 0
jobs.forEach(p => p.then(() => setProgress(++done / jobs.length)))
Promise.race([Promise.all(jobs), new Promise(r => setTimeout(r, CONFIG.loader.timeoutMs))])
  .then(() => wait(CONFIG.loader.minMs - elapsed()))
  .then(finish)                                // 移除 html.intro → 啟動捲動動畫 → 首屏進場
```

| 參數 | 參考值 | 作用 |
|---|---|---|
| `loader.minMs` | 1800 | 素材很快時也至少停這麼久，避免一閃而過 |
| `loader.timeoutMs` | 6000 | 網路慢時最多等這麼久就放行 |
| 一個 session 只播一次 | `sessionStorage` | 回訪或站內返回不再播 |

- **reduced-motion**：`<head>` 那段就不加 `intro`，載入頁完全不出現
- **手機**：照常，但 `preload` 只放手機首屏用得到的尺寸
- **坑**：判斷寫在 `<head>` 的同步 script 裡，否則會先閃一下內容再蓋上載入頁；`sessionStorage` 在隱私模式可能丟例外，要 `try`；`finish()` 之後要讓 ScrollTrigger 重新計算位置（`motion.md` 第 7 節「素材晚到」）

### 3.2 有機邊緣遮罩揭露

**機制**：圖片包在 SVG 裡，遮罩是一個被雜訊扭曲過的圓，動畫只改圓的半徑——邊緣就會不規則地擴散開。

```html
<svg width="0" height="0" aria-hidden="true" style="position:absolute">
  <filter id="roughEdge" x="-30%" y="-30%" width="160%" height="160%">
    <feTurbulence type="fractalNoise" baseFrequency=".018" numOctaves="4" seed="7" result="n"/>
    <feDisplacementMap in="SourceGraphic" in2="n" scale="90" xChannelSelector="R" yChannelSelector="G" result="d"/>
    <feGaussianBlur in="d" stdDeviation="6"/>
  </filter>
</svg>
```

```js
let maskSeq = 0
function maskedImage(src, alt, w = 1000, h = 750) {
  const id = 'mask' + (++maskSeq)
  return `<svg viewBox="0 0 ${w} ${h}" role="img" aria-label="${alt}">
    <defs><mask id="${id}"><rect width="${w}" height="${h}" fill="black"/>
      <g filter="url(#roughEdge)"><circle class="bleed" cx="${w * .45}" cy="${h * .55}" r="0" fill="white"/></g>
    </mask></defs>
    <image href="${src}" width="${w}" height="${h}" preserveAspectRatio="xMidYMid slice" mask="url(#${id})"/></svg>`
}
function reveal(svg, duration = 1.8, k = .75) {
  const c = svg.querySelector('.bleed'), vb = svg.viewBox.baseVal
  const R = Math.hypot(vb.width, vb.height) * k
  if (reduce || !window.gsap) return c.setAttribute('r', R)
  return gsap.fromTo(c, { attr: { r: 0 } }, { attr: { r: R }, duration, ease: 'power2.inOut' })
}
```

| 參數 | 怎麼調 |
|---|---|
| `baseFrequency` | 越小邊緣起伏越大、越像暈染；越大越碎，像紙張撕邊 |
| `scale`（displacement） | 邊緣扭曲的幅度 |
| `stdDeviation` | 邊緣柔和度；設 0 就是硬的撕邊 |
| `k` | 最終半徑比例。`< 1` 會留下不規則外框（首屏主圖常用 .42 左右，讓照片停在一團暈染裡） |

- **reduced-motion**：直接把半徑設到最終值，保留形狀、不做擴散
- **手機**：可用，但同一個畫面只讓一張在動
- **坑**：filter 的 `x/y/width/height` 要放大（上面的 -30%／160%），否則扭曲後的邊緣會被切成直線；每張圖的 mask `id` 要唯一；大面積 SVG filter 很吃 CPU，不要同時跑好幾張；`aria-label` 放在 `<svg role="img">` 上，`<image>` 沒有 alt

### 3.3 焦點輪播（中央放大、兩側淡出）

**機制**：所有卡片疊在同一個中心點，依「離目前這張幾格」算出位移、縮放、透明度、濾鏡。中央是彩色清楚的，兩側縮小並轉灰、模糊。

```js
function layout(cur) {
  const step = slides[0].offsetWidth * (isMobile() ? CONFIG.carousel.spacingMobile : CONFIG.carousel.spacingDesktop)
  slides.forEach((s, i) => {
    let o = i - cur; if (o > n / 2) o -= n; if (o < -n / 2) o += n
    const a = Math.abs(o)
    const to = {
      x: o * step,
      scale: a === 0 ? 1 : CONFIG.carousel.sideScale - (a - 1) * .12,
      opacity: a > 2 ? 0 : a === 0 ? 1 : .85 - (a - 1) * .35,
      filter: a === 0 ? 'grayscale(0) blur(0px)' : `grayscale(1) blur(${a}px)`,
      zIndex: 10 - a,
    }
    s.setAttribute('aria-hidden', a !== 0)
    reduce ? gsap.set(s, to) : gsap.to(s, { ...to, duration: .9, ease: 'power3.inOut' })
  })
}
```

L1 版：同一套計算寫進 `style.transform`／`opacity`／`filter`，用 CSS `transition` 補間，不需要 GSAP。

| 參數 | 參考值 |
|---|---|
| `carousel.spacingDesktop`／`spacingMobile` | .95／.78（卡片寬的倍數） |
| `carousel.sideScale` | .66 |
| `carousel.autoplayMs` | 4200；不想自動播就設 0 |

- **reduced-motion**：不自動播，切換時直接跳位
- **手機**：`pointerdown`／`pointerup` 判斷橫向位移超過 40px 就切換；容器加 `touch-action: pan-y` 讓直向捲動不被吃掉
- **坑**：自動播放是「持續超過 5 秒的動態」，要有**看得見的暫停鈕**（`SKILL.md` 2.6③），只有滑鼠移入暫停不夠；離開視窗時用 `IntersectionObserver` 停掉計時器；鍵盤要能用左右鍵；文字說明放在輪播外、加 `aria-live="polite"`

### 3.4 交疊輪播＋進度條

**機制**：多張圖疊在同一格，新的一張在最上層用 3.2 的遮罩擴散出現，同時從 1.08 慢慢縮回 1（緩慢推近），下方每張一條進度條，目前這條用 `scaleX` 從 0 走到 1，時長等於換圖間隔。

```js
function show(i) {
  layers[cur].style.zIndex = 1; cur = i; layers[cur].style.zIndex = 2
  reveal(layers[cur], 1.6)
  if (reduce) return
  gsap.fromTo(layers[cur].querySelector('image'), { scale: 1.08, transformOrigin: '50% 50%' },
    { scale: 1, duration: CONFIG.fader.intervalMs / 1000 + 1.5, ease: 'none' })
  bars.forEach((b, j) => gsap.set(b, { scaleX: j < cur ? 1 : 0 }))
  gsap.fromTo(bars[cur], { scaleX: 0 }, { scaleX: 1, duration: CONFIG.fader.intervalMs / 1000, ease: 'none' })
  clearTimeout(timer); timer = setTimeout(() => show((cur + 1) % layers.length), CONFIG.fader.intervalMs)
}
```

- 不用遮罩時，換成 `opacity` 交叉淡入也成立；L1 可以只保留「點進度條切換」，不自動播
- **reduced-motion**：全部直接顯示第一張，進度條變成可點的分頁
- **坑**：第一次播放等區塊進入視窗才開始（ScrollTrigger `once: true` 或 `IntersectionObserver`），否則使用者捲到時已經播到第三張；同 3.3 要有暫停

### 3.5 程序生成層疊剪影＋視差

**機制**：用有種子的亂數產生一條平滑的稜線路徑，疊三層（遠的淡、近的深），每層加一點粗糙濾鏡；捲動時三層用不同速度位移。有種子所以每次重新整理形狀都一樣。

```js
function rng(seed) { return () => (seed = seed * 16807 % 2147483647, (seed - 1) / 2147483646) }
function ridge(w, h, base, amp, seed, steps = 90) {
  const r = rng(seed); let y = base, v = 0, pts = []
  for (let i = 0; i <= steps; i++) {
    v = (v + (r() - .5) * amp * .6) * .82
    y = Math.min(h - 10, Math.max(h * .05, y + v))
    pts.push([i / steps * w, y])
  }
  let d = `M0 ${h} L0 ${pts[0][1]}`
  for (let i = 1; i < pts.length; i++) {
    const [x0, y0] = pts[i - 1], [x1, y1] = pts[i]
    d += ` Q${x0} ${y0} ${(x0 + x1) / 2} ${(y0 + y1) / 2}`
  }
  return d + ` L${w} ${h} Z`
}
```

每層一個 `<path d="${ridge(...)}">`，填一條由上往下變透明的 `linearGradient`，外層 `<g data-depth="0|1|2">`。視差：

```js
layers.forEach(g => gsap.to(g, {
  yPercent: CONFIG.parallax.layers[+g.dataset.depth], ease: 'none',
  scrollTrigger: { trigger: g.closest('section'), start: 'top top', end: 'bottom top', scrub: true },
}))
```

| 參數 | 參考值 |
|---|---|
| 每層 `base`（高度比例）／`amp`（起伏）／`seed` | 遠 .28／42、中 .48／36、近 .7／30；`seed` 隨便給，換到喜歡的形狀為止 |
| 每層頂端不透明度 | .16／.32／.55 |
| `parallax.layers` | `[6, 14, 26]`（近的動得多） |

- 換材質：`steps` 調大、`amp` 調小就是海浪；把 `Q` 曲線換成直線段、`y` 取整到格子就是城市天際線
- **reduced-motion／L1**：只畫靜態剪影，不加視差
- **手機**：SVG 用 `preserveAspectRatio="xMidYMax slice"` 讓底部貼齊，寬度設 110% 往左偏 5%，視差位移時兩側不會露白
- **坑**：粗糙濾鏡（`feTurbulence`＋`feDisplacementMap`，`scale` 約 22）同樣要放大 filter 區域；漸層的 `id` 每個 SVG 要唯一

### 3.6 首屏游標拖尾

**機制**：首屏放一張滿版 `canvas`（`pointer-events: none`），滑鼠移動超過一段距離就丟一顆「墨滴」，每顆慢慢變大變淡，淡到看不見就移除。

```js
if (!reduce && fine && CONFIG.trail.enabled) {
  hero.addEventListener('pointermove', e => {
    const x = e.clientX - rect.left, y = e.clientY - rect.top
    if (last && Math.hypot(x - last[0], y - last[1]) < CONFIG.trail.minDist) return
    last = [x, y]
    drops.push({ x, y, r: 2 + Math.random() * 4, max: 14 + Math.random() * 26, a: .16 })
    if (drops.length > CONFIG.trail.max) drops.shift()
  })
  function tick() {
    ctx.clearRect(0, 0, W, H)
    for (const d of drops) { d.r += (d.max - d.r) * .04; d.a *= .985; paintRadial(d) }
    drops = drops.filter(d => d.a > .01)
    if (visible) requestAnimationFrame(tick)
  }
}
```

| 參數 | 參考值 |
|---|---|
| `trail.minDist` | 14px（越小越密） |
| `trail.max` | 70 顆 |
| 裝置像素比上限 | 2（`Math.min(devicePixelRatio, 2)`，高解析螢幕不爆記憶體） |

- **reduced-motion、觸控裝置**：整段不跑（`fine` 為假）
- **坑**：首屏捲出視窗後要停掉 `requestAnimationFrame`（用 `IntersectionObserver` 設 `visible`），否則整頁捲到底它還在空轉；`resize` 時要重設 canvas 尺寸

### 3.7 標題分隔＋逐字浮現

**機制**：中日文標題每個字包一層，字與字之間用一條細豎線隔開；進場時豎線先出現、字從模糊中浮現、下方的西文副標字距從寬收回。

```html
<h2 class="stitle" aria-label="店的故事"><span><i>店</i></span><span><i>的</i></span><span><i>故</i></span><span><i>事</i></span></h2>
```

```css
.stitle { display: inline-flex }
.stitle span { padding: 0 .5em; border-left: 1px solid var(--color-line) }
.stitle span:first-child { border-left: 0 }
.stitle i { display: inline-block; font-style: normal }
```

```js
gsap.timeline({ scrollTrigger: { trigger: t, start: 'top 82%' } })
  .from(t.querySelectorAll('span'), { borderLeftColor: 'transparent', duration: .6, stagger: .08 })
  .from(t.querySelectorAll('i'), { opacity: 0, y: 18, filter: 'blur(10px)', duration: 1, stagger: .12, ease: 'power2.out' }, 0)
```

**變體：遮罩上推**——每個字（或每一行）外層 `overflow: hidden`，裡層從 `yPercent: 110` 推上來。比模糊浮現俐落，適合無襯線或現代題材。西文要以「詞」或「行」為單位切，不要逐字母；切字用 GSAP 的 SplitText（用法查 context7）。

- **L1**：只用 CSS 的分隔線，不做進場
- **reduced-motion**：不做進場，分隔線照常顯示
- **坑**：`<h2>` 一定要有 `aria-label` 放完整標題，否則螢幕閱讀器會一個字一個字唸；超過 6 個字的標題不要拆（豎線會變成柵欄）；會被翻譯或由 CMS 輸出的動態標題不適合

### 3.8 字距按鈕＋填色掃過

**機制**：寬字距的細框按鈕，滑過時底色從右側收起、從左側長出（`transform-origin` 在 hover 前後對調），文字顏色同步反白。

```css
.btn {
  display: inline-flex; align-items: center; justify-content: center; min-height: 48px; padding: 0 30px;
  border: 1px solid var(--color-accent); color: var(--color-accent);
  letter-spacing: .45em; text-indent: .45em;
  position: relative; overflow: hidden; isolation: isolate;
  transition: color var(--motion-duration-base) var(--motion-ease-out);
}
.btn::before {
  content: ""; position: absolute; inset: 0; z-index: -1; background: var(--color-accent);
  transform: scaleX(0); transform-origin: right;
  transition: transform var(--motion-duration-slow) var(--motion-ease-out);
}
.btn:hover, .btn:focus-visible { color: var(--color-on-accent) }
.btn:hover::before, .btn:focus-visible::before { transform: scaleX(1); transform-origin: left }
```

- **坑**：`text-indent` 要等於 `letter-spacing`，否則最後一個字後面的字距會讓文字看起來偏左；`:focus-visible` 要給同樣的效果；手機上字距縮到 .3em 左右，避免按鈕被撐寬換行
- **reduced-motion**：底色直接切換，不掃過（`SKILL.md` 2.6③ 的微互動規則）

### 3.9 紙紋雜訊疊層

**機制**：一張用 `feTurbulence` 產生的雜訊圖當 `data:` URI，固定蓋在整頁最上層、不吃滑鼠事件，用 `multiply` 混合讓底色有紙張的顆粒。

```css
body::before {
  content: ""; position: fixed; inset: 0; pointer-events: none; z-index: 90;
  opacity: .5; mix-blend-mode: multiply;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='260' height='260'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.7' numOctaves='3'/%3E%3CfeColorMatrix values='0 0 0 0 .4 0 0 0 0 .37 0 0 0 0 .3 0 0 0 .22 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
}
```

- `feColorMatrix` 前三列的最後一欄是顆粒的 RGB（0～1），最後一列的 `.22` 是顆粒濃度；換成題材的底色色相
- **坑**：全螢幕固定圖層加混合模式，在低階手機捲動可能變卡——卡的話改成只蓋首屏的 `position: absolute`，或手機不加；顆粒太濃會降低文字對比，疊上去後重新檢查 4.5:1

### 3.10 釘選橫向相簿

**機制**：桌機上，整段被釘住，往下捲變成往左移；手機上不釘，改成原生的橫向捲動加 `scroll-snap`。

```js
const mm = gsap.matchMedia()
mm.add('(min-width: 768px)', () => {
  const dist = () => track.scrollWidth - innerWidth
  const tween = gsap.to(track, {
    x: () => -dist(), ease: 'none',
    scrollTrigger: { trigger: pinBox, start: 'top top', end: () => '+=' + dist(),
      pin: true, scrub: 1, invalidateOnRefresh: true, anticipatePin: 1,
      onUpdate: s => progress.style.transform = `scaleX(${s.progress})` },
  })
  cards.forEach(c => gsap.fromTo(c.querySelector('img'), { scale: 1.25 }, { scale: 1.06, ease: 'none',
    scrollTrigger: { trigger: c, containerAnimation: tween, start: 'left right', end: 'center center', scrub: true } }))
})
```

```css
@media (max-width: 767px) {
  .track-wrap { overflow-x: auto; scroll-snap-type: x mandatory; scrollbar-width: none }
  .card { width: 78vw; scroll-snap-align: center }
}
```

- **等級**：釘選與橫向捲動在 `motion.md` 第 2 節屬 **L3**
- **reduced-motion**：不釘選，桌機也改用上面的原生橫捲（或直接直向排列）
- **坑**：距離要寫成函式並開 `invalidateOnRefresh`，視窗縮放後才會重算；卡片裡的圖要用 `containerAnimation` 掛在橫向 tween 上，掛在一般捲動上觸發點會錯；最後一張後面留一張「看全部」的結尾卡，不然釘選結束得很突然

### 3.11 跑馬燈＋捲動加速

**機制**：內容複製一份接在後面，整條無限往左移 50%；捲動時依捲動速度暫時加快，停下後回到原速。

```js
const loop = gsap.to(track, { xPercent: -50, ease: 'none', duration: CONFIG.marquee.seconds, repeat: -1 })
ScrollTrigger.create({ trigger: document.body, start: 'top top', end: 'bottom bottom', onUpdate: s => {
  const boost = Math.min(Math.abs(s.getVelocity()) / 300, 6)
  gsap.to(loop, { timeScale: 1 + boost, duration: .2, overwrite: true })
  gsap.to(loop, { timeScale: 1, duration: 1, delay: .2 })
} })
```

- 跑馬燈是裝飾，加 `aria-hidden="true"`；**不要**放使用者必須讀到的資訊
- **reduced-motion**：不動，顯示成一行靜態文字
- **坑**：無限循環就是「超過 5 秒的裝飾動畫」，要能暫停（`SKILL.md` 2.6③）——最簡單是滑過或聚焦時暫停，再加一個全站的「暫停動態」開關

### 3.12 遮罩上推與 clip-path 揭露

**機制**：圖片或區塊的 `clip-path` 從 `inset(100% 0 0 0)` 收到 `inset(0)`，裡面的圖同時從 1.25 縮回 1；拱形主圖可在 `inset()` 加 `round` 做出圓頂。

```js
gsap.from(heroMedia, { clipPath: 'inset(100% 0 0 0 round 260px 260px 10px 10px)', duration: 1.3, ease: 'power4.inOut' })
gsap.from(heroMedia.querySelector('img'), { scale: 1.3, duration: 1.6, ease: 'power3.out' })
```

- 原生替代：只要「捲到時揭露」、不需要所有瀏覽器都有效果，用 `animation-timeline: view()` 包在 `@supports` 裡（`motion.md` 第 5 節）
- **坑**：這是最容易「每一段都用」的效果。一頁只給首屏主圖和一個相簿用，其他段落不要

### 3.13 磁吸按鈕、傾斜卡片、自訂游標

**機制**：只在精準指標裝置上——按鈕往游標方向被吸一點，卡片依游標位置做 3D 傾斜，自訂游標由一個小點和一個慢半拍的圓環組成，滑到有 `data-cursor` 的元素時圓環放大並顯示文字。

```js
if (fine && !reduce) {
  const rx = gsap.quickTo(ring, 'x', { duration: .45, ease: 'power3' })
  const ry = gsap.quickTo(ring, 'y', { duration: .45, ease: 'power3' })
  addEventListener('pointermove', e => { rx(e.clientX); ry(e.clientY) })
  magnets.forEach(el => {
    el.addEventListener('pointermove', e => {
      const r = el.getBoundingClientRect()
      gsap.to(el, { x: (e.clientX - r.left - r.width / 2) * CONFIG.magnet, y: (e.clientY - r.top - r.height / 2) * CONFIG.magnet, duration: .4, ease: 'power2.out' })
    })
    el.addEventListener('pointerleave', () => gsap.to(el, { x: 0, y: 0, duration: .6, ease: 'power3.out' }))
  })
}
```

| 參數 | 參考值 |
|---|---|
| `magnet` | .35（游標偏移的倍數） |
| 傾斜最大角度 | 8° |

- **坑**：回彈**不要用 `elastic`／`back` 這類會過衝的 easing**——`anti-ai.md` 產出後清單把彈跳、過衝列為 AI 痕跡，用 `power3.out` 這類平順的收尾；自訂游標不要藏掉系統游標（`cursor: none`），只疊在上面；觸控裝置完全不跑

### 3.14 數字滾動

**機制**：數字從 0 補間到目標值，進入視窗時觸發一次。

```js
el => { const o = { v: 0 }; gsap.to(o, { v: +el.dataset.to, duration: 1.6, ease: 'power2.out',
  scrollTrigger: { trigger: el, start: 'top 90%' }, onUpdate: () => el.textContent = o.v.toFixed(+el.dataset.dec || 0) }) }
```

- **只用在有來源的真實數字**（評分、年份、店家提供的數據）。沒有來源就沒有這個區塊（`anti-ai.md`「文案與事實」）
- **坑**：HTML 裡先寫好最終數字，JS 才改成 0 再滾——JS 沒跑時看到的是正確值；`reduce` 時不滾

---

## 4. 去哪裡挑元素

先決定等級和主角（第 1 節），**再**去找機制；不要先逛範例再回頭找地方塞。
函式庫本身的用途與選擇（Lenis、GSAP、Motion、three.js…）見 `motion.md` 第 6 節，這裡只列**可以挑元素的地方**。

| 來源 | 技術棧 | 適合挑什麼 | 授權（查證日 2026-11-13） |
|---|---|---|---|
| **GSAP 官方範例**（https://demos.gsap.com）與外掛文件（ScrollTrigger、SplitText、Flip、MorphSVG、Observer） | 任何技術棧（純 JS 可用） | 捲動敘事、逐字進場、版面轉場 | GSAP 自己的 no-charge license，README 寫明**全部外掛免費、可商用**。做「視覺化動畫編輯器」這類工具時先讀 https://gsap.com/standard-license 全文 |
| **React Bits**（https://reactbits.dev） | **只有 React**；每個元件有 JS／TS × CSS／Tailwind 四種版本，可用 shadcn CLI 或 jsrepo 加入 | 文字動畫、游標效果、背景、輪播 | **MIT＋Commons Clause**：可用在任何網站或產品（含商業）；**不可**把元件本身拿去賣、再授權或重新散布（例如包成模板或元件包）。Pro 版另外付費 |
| **Motion 官方範例**（https://motion.dev/examples） | React、純 JS、Vue | 版面動畫、手勢、捲動連動 | 函式庫 MIT。**部分範例原始碼和進階 API 屬付費的 Motion+**，挑之前看該頁有沒有標 Motion+ |
| **Magic UI**（https://magicui.design） | React＋Tailwind | 首屏背景、邊框光效、數字、標記牆 | MIT。它的不少元件屬 `anti-ai.md` 點名的發光／漸層樣式，挑之前先對照產出後清單 |
| **Codrops**（https://tympanus.net/codrops/demos） | 多為純 HTML／CSS／JS，很多是 WebGL | 實驗性的轉場、圖片扭曲、捲動敘事；附教學文 | 可下載的 demo 未另外註明時是 MIT；**每個 demo 以它自己的授權說明為準**。教學文章本身不可整篇轉載 |
| **CodePen** | 任何 | 單一小效果的寫法 | 公開的 Pen 預設 MIT，作者另外註明授權的以作者為準 |

**挑的時候逐項檢查**：

1. **技術棧對得上嗎？** React Bits、Magic UI 只能用在 React 專案；純 HTML 專案只能挑 GSAP、Codrops、CodePen 的寫法
2. **等級對得上嗎？** WebGL、3D、影片背景都是 L3（`motion.md` 第 2 節）
3. **它處理了 `prefers-reduced-motion` 和觸控嗎？** 範例常常沒有——沒有就自己補，補不了就不用
4. **改寫，不整包貼。** 數字改讀 `CONFIG`／motion tokens、顏色改用 tokens，刪掉範例裡用不到的分支
5. **授權要保留聲明的（MIT 等）**，在用到的檔案頂端留一行出處網址與授權——這屬於 `coding-style.md` 允許的「外部約束」註解

---

## 5. 參考別人的網站：萃取風格 DNA

使用者貼了一個網站說「想要像這樣」時照這節做。**只學結構與節奏，不搬東西。**

### 5.1 截圖

存到 `<repo 根>/.claude/tmp/ui-references/<網域>-<YYYY-MM-DD>/`，建目錄時同時寫一份內容只有 `*` 的 `.gitignore`
（別人的畫面不准進使用者的版控）。截圖操作（絕對路徑、每次給 `filename`）照 `ui-builder.md` 的「截圖驗收」①②。

| 截什麼 | 用來看 |
|---|---|
| 390×844、1440×900 各一張 `fullPage` | 版面節奏、區塊順序、手機怎麼重排 |
| 1440 寬在捲動 0%、25%、50%、75% 各一張（非 fullPage） | 每個捲動位置畫面上同時有幾樣東西、哪裡留白 |
| 有明顯動效的段落：剛進視窗、置中、快離開各一張 | 動效的起點和終點 |

再用 `browser_evaluate` 讀實際數值（不要從截圖猜字級）：

```js
() => {
  const pick = s => { const e = document.querySelector(s); if (!e) return null
    const c = getComputedStyle(e); return { font: c.fontFamily, size: c.fontSize, weight: c.fontWeight, lh: c.lineHeight, ls: c.letterSpacing, color: c.color } }
  const sections = [...document.querySelectorAll('main > section, body > section')].slice(0, 12)
    .map(s => ({ h: Math.round(s.getBoundingClientRect().height), pad: getComputedStyle(s).paddingTop, bg: getComputedStyle(s).backgroundColor }))
  return { h1: pick('h1'), h2: pick('h2'), body: pick('p'), bodyBg: getComputedStyle(document.body).backgroundColor, sections,
    libs: { gsap: !!window.gsap, scrollTrigger: !!window.ScrollTrigger, lenis: !!window.Lenis || document.documentElement.classList.contains('lenis'), three: !!window.THREE } }
}
```

`libs` 只用來判斷「這個效果大概是什麼機制、屬於哪一級」，不是要照抄它的程式。

沒有 Playwright 時（主模型沒接瀏覽器工具）：請使用者自己截 390 和 1440 兩張，字級與色彩改成「截圖估計」，在 DNA 裡標明。

### 5.2 寫成風格 DNA

```markdown
## 風格 DNA：<網域>（<YYYY-MM-DD> 擷取）

- **版面節奏**：<區塊順序；滿版和窄欄怎麼交替；區塊上下留白約 Npx（1440）／Npx（390）；對齊方式>
- **字級階層**：h1 <px>／h2 <px>／內文 <px>（1440）；h1 與內文的比例約 <N> 倍；字重對比 <300 對 800 這類>
- **字型的角色**：標題 <襯線／無襯線／手寫>、內文 <…>（只記角色，字型照我們的題材另選）
- **色彩的角色**：<底色深淺、強調色只用在哪裡、一頁幾個顏色>（只記比例與角色，色值用我們的 tokens）
- **動效**：主角是 <什麼>，機制接近本檔 <3.x>，等級 <L?>；其他段落 <安靜／統一進場>
- **記憶點**：<這個站讓人記住的那一件事>
- **不學的部分**：<和我們題材不合、或 anti-ai.md 點名的樣式>
```

### 5.3 界線

- **不抄**：程式碼、logo、插畫、照片、影片、文案、付費字型檔、獨特的品牌圖形。也不要 hotlink 對方的素材
- **色彩不整套搬**：借「深底配一個強調色」這種比例，色值從我們的題材和 DESIGN.md 來（`anti-ai.md` 原則 1）
- **DESIGN.md 優先**：DNA 和選定的 DESIGN.md 衝突時照 DESIGN.md（`anti-ai.md` 原則 2）；DNA 主要補 DESIGN.md 通常沒寫的節奏和動效
- **等級照專案**：參考站是 L3，專案設定是 L2，就用 L2 做得到的方式重現那個節奏

### 5.4 寫到哪裡

| 從哪裡進來 | DNA 放哪 |
|---|---|
| `gmap-landing-page` | `brief.md` 的「風格 DNA」 |
| `/ui-page` | 派給 `ui-builder` 時附在派工內容；有 IA 文件時同時寫進該頁 IA snippet |
| `/ui-site` | IA 文檔 |
| 其他 | 派工內容；使用者要留存時存成 `.claude/tmp/ui-references/` 同目錄的 `DNA.md`（不進版控） |

---

## 出處

- 第 3 節配方：從使用者提供的一頁式提案三版（純 HTML＋GSAP＋ScrollTrigger＋Lenis，2026-11-13 分析）抽出機制後改寫。
  原檔不隨模板發佈，片段已去掉店名、文案、照片與地點資訊；參數值是原檔的實際值，換題材時當起點，不是規範
- 3.3、3.11 的暫停鈕、3.6 的離開視窗停止 rAF、3.13 改掉 `elastic` 回彈：原檔沒有做，是對照 `SKILL.md` 2.6③ 與 `anti-ai.md` 補上的
- 第 4 節（2026-11-13 查）：
  - GSAP：`greensock/GSAP` README（"GSAP is FREE!"、License 節）；license 全文 https://gsap.com/standard-license
  - React Bits：`DavidHDev/react-bits` 的 `LICENSE.md`（MIT + Commons Clause）與 README（四種版本、shadcn／jsrepo 安裝）
  - Motion：`motiondivision/motion` README（React／JavaScript／Vue、Examples、Motion+ 節），GitHub API 授權欄位 MIT
  - Magic UI：`magicuidesign/magicui` README 的 License 節（MIT）
  - Codrops：授權頁 https://tympanus.net/codrops/?p=7319 （demo 預設 MIT、各 demo 以自身說明為準、文章不可整篇轉載）。直接抓頁面回 403，內容經 WebSearch 摘要取得，未逐字讀原頁
  - CodePen：https://blog.codepen.io/docs/licensing/ （公開 Pen 為 MIT），經 WebSearch 摘要，未逐字讀原頁
