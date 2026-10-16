# 繁中字型（`ui-style-compliance` 附屬檔）

**什麼時候讀：專案語言含繁體中文時**（`SKILL.md` 1.3 節）。判斷依據任一：頁面 `lang` 是 `zh-Hant`／`zh-TW`／`zh-HK`、
專案文件或 IA 是繁中、使用者用繁中描述要放上網頁的內容。

本檔是下列內容的**唯一來源**：繁中字型清單、中英搭配、載入方式、系統字型堆疊、排版參數，
以及 **jp 風格的日文字型換成什麼繁中字型**（那張對照表只寫在這裡，jp 的 DESIGN.md 一份都不改）。

字型選擇本身也要過 `anti-ai.md`：表 2 點名的「有品味的預設」字型，下面用 ⚠ 標出來。

---

## 1. Google Fonts 上的繁中字型

每一列都在 Google Fonts 的字型目錄（`https://fonts.google.com/metadata/fonts`）查過名稱、子集和字重。
**字重少的字型撐不起「字重對比要拉開」那條規則**，選標題字時要先看這一欄。

| 字型（CSS 名稱） | 分類 | 字重 | 子集 | 氣質 | 適合 | 查證日期 |
|---|---|---|---|---|---|---|
| Noto Sans TC（思源黑體） | 黑體 | 100～900 | chinese-traditional | 中性、清楚、什麼都撐得住 | 內文的預設；介面、資訊密集的頁面 | 2026-10-16 |
| Noto Serif TC（思源宋體） | 宋體 | 200～900 | chinese-traditional | 端正、出版品、書卷 | 標題、長文、文化與出版 | 2026-10-16 |
| LXGW WenKai TC（霞鶩文楷） | 手寫（楷書） | 300、400、700 | chinese-traditional | 溫和、像手寫筆記 | 茶、手作、教育、個人品牌的標題 | 2026-10-16 |
| LXGW WenKai Mono TC | 等寬（楷書） | 300、400、700 | chinese-traditional | 同上，等寬 | 需要中文對齊的表格、程式碼註解 | 2026-10-16 |
| Iansui（芫荽） | 手寫 | **只有 400** | chinese-traditional | 手寫感、比文楷更隨性 | 短標題、標語。字重只有一個，靠字級做對比 | 2026-10-16 |
| Huninn（粉圓） | 圓體 | **只有 400** | chinese-traditional | 圓潤、親切、可愛 | 親子、甜點、寵物。字重只有一個 | 2026-10-16 |
| Chiron GoRound TC | 圓體 | 200～900 | chinese-traditional | 圓潤但字重齊全 | 要圓體又要字重對比時，代替 Huninn | 2026-10-16 |
| Chiron Hei HK（昭源黑體） | 黑體 | 200～900（含斜體） | chinese-traditional | 比思源黑體多一點書寫味 | 有個性的標題黑體 | 2026-10-16 |
| Chiron Sung HK（昭源宋體） | 宋體 | 200～900（含斜體） | **chinese-hongkong** | 比思源宋體更有印刷味 | 標題宋體。**子集是香港字形**，部分字的寫法和台灣教育部標準不同；教育、公部門網站改用 Noto Serif TC | 2026-10-16 |
| Cactus Classical Serif | 宋體（仿古典活字） | **只有 400** | chinese-traditional | 老派鉛字、古書 | 老店、歷史、文學。字重只有一個 | 2026-10-16 |

另外有 `Bpmf Iansui`、`Bpmf Huninn` 兩個**帶注音**的版本（2026-01-30 加入 Google Fonts），適合兒童、華語教學。

**Google Fonts 上的字型都是開源授權**，可用於商業網站；個別條款以各字型頁的 License 為準。

---

## 2. 中英搭配

中文字型本身也有英數字，但通常不好看。做法是**把西文字型放在 `font-family` 的前面**，
瀏覽器會用西文字型顯示英數、用後面的中文字型顯示中文：

```css
:root {
  --font-heading: "Source Serif 4", "Noto Serif TC", serif;
  --font-body: "Work Sans", "Noto Sans TC", "PingFang TC", "Microsoft JhengHei", sans-serif;
}
```

下表的西文字型都在 Google Fonts 查過（2026-10-16）。⚠＝`anti-ai.md` 點名的預設，用了要能講出理由。

| # | 標題 | 內文 | 西文 | 氣質 | 注意 |
|---|---|---|---|---|---|
| 1 | Noto Serif TC 700／900 | Noto Sans TC 400 | Source Serif 4、Newsreader | 端正的出版品，像書店的選書誌 | 最穩的一組，也因此容易平淡：記憶點要靠字級 |
| 2 | Cactus Classical Serif | Noto Sans TC 400 | EB Garamond、Cormorant Garamond | 老派鉛字、老店、歷史感 | 標題只有一個字重，對比靠字級。⚠ 配暖米白底＋陶土色就是 `anti-ai.md` 第 1 種樣式 |
| 3 | LXGW WenKai TC 700 | Noto Sans TC 400 | Lora、Literata | 溫和的手寫，像茶舖的手寫菜單 | 楷書很容易被拿來做「溫暖手作」的通用配方，要有題材上的理由（店裡真的用手寫招牌） |
| 4 | Huninn 或 Chiron GoRound TC | Noto Sans TC 400 | DM Sans、Outfit | 圓潤親切 | Huninn 只有 400；要字重對比用 Chiron GoRound TC |
| 5 | Noto Sans TC 900 | Noto Sans TC 300 | Manrope、IBM Plex Sans | 現代、乾淨，靠極端字重對比撐場 | 只用一個家族也可以有個性，前提是字重拉開（300 對 900） |
| 6 | Chiron Hei HK 800 | Noto Sans TC 400 | ⚠ Space Grotesk | 新創、科技 | Space Grotesk 是被點名最多次的預設字，換掉它通常更好 |
| 7 | Noto Serif TC 700 | Noto Sans TC 400 | ⚠ Instrument Serif、⚠ Fraunces、Playfair Display、DM Serif Display | 時髦的編輯感 | 這幾個是高對比西文展示襯線，就是第 1 種樣式的「襯線」元素。底色、強調色一定要避開米白和陶土 |
| 8 | 任一 | Noto Sans TC 400 | ⚠ Inter、⚠ Geist | 中性 | 全站只有 Inter 或沒改過的 Geist 是第一層預設。只拿來當內文、標題換別的，才算有選過 |

---

## 3. 載入

### Google Fonts CSS API

- **一律加 `display=swap`**：字型還沒下載完時先用系統字型顯示，不會整段空白。
  `font-display` 的可選值是 `auto`／`block`／`swap`／`fallback`／`optional`
  （Google Fonts CSS API 文件 https://developers.google.com/fonts/docs/css2 ，2026-10-16）
- **內文不需要自己做子集。** Google Fonts 會把中文字型自動切成很多小檔，每個檔標好 `unicode-range`，
  瀏覽器只下載頁面用到的那幾片。實測 `Noto Sans TC` 400 一個字重就切成 108 片（2026-10-16）
- **標題、Logo 這種固定的少數字，用 `text=` 只取那幾個字**，檔案小很多（文件寫最多可省 90%）。
  實測帶 `text=` 時只回一個檔（2026-10-16）。限制：文字改了 URL 要跟著改；內容會變動的地方不能用

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+TC:wght@400;700&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=Cactus+Classical+Serif&text=%E4%B8%80%E4%BF%9D%E5%A0%82&display=swap" rel="stylesheet">
```

- **字重只載會用到的**：中文字型每多一個字重，就多一整組切片
- 標題用 `text=` 的字型，如果內文也要用同一個字型，就要另外載一份完整的；不要讓同一個字型的兩個版本同時出現在 `font-family`

### 系統字型堆疊（不載網路字型，或當退路）

| 用途 | 堆疊 | 依據 |
|---|---|---|
| 黑體 | `"PingFang TC", "Microsoft JhengHei", "Noto Sans TC", sans-serif` | macOS／iOS 內建蘋方、Windows 內建微軟正黑體；omd 的誠品、全家實測紀錄都是這個順序（`.claude/context/decisions/skill-curator-2026-10-16-1034-brand-candidates.md`） |
| 宋體 | `"Songti TC", "PMingLiU", "Noto Serif TC", serif` | macOS 宋體、Windows 新細明體；omd 讀墨的分類標籤用 Songti TC |

西文字型照樣放在最前面。

---

## 4. 排版參數

| 項目 | 建議 | 說明 |
|---|---|---|
| 內文行距 | 1.7～1.9 | 經驗值。中文字是方塊，比西文需要更多行距；西文常用的 1.5 對中文太擠 |
| 標題行距 | 1.2～1.4 | 經驗值 |
| 內文字距 | 0～0.05em | 經驗值。中文內文不要拉大字距，會變得鬆散難讀 |
| 標題字距 | 可以拉到 0.1em 以上 | jp 風格常見的大字距，套在繁中標題上效果類似 |
| 一行字數 | 內文 25～40 個中文字 | 經驗值，約等於西文建議的不超過 80 個字母 |
| 斷行禁則 | `line-break: strict` | 不讓句號、逗號、右括號出現在行首。Chrome 58、Firefox 69、Safari 11 起支援（https://developer.mozilla.org/docs/Web/CSS/Reference/Properties/line-break ，2026-10-16） |
| 中英之間的空白 | `text-autospace: normal` | 自動在中文和英數之間留一點空。Chrome 140、Firefox 145、Safari 18.4 起支援，**但三家的初始值都是 `no-autospace`，要自己寫才會生效**（https://developer.mozilla.org/docs/Web/CSS/Reference/Properties/text-autospace ，2026-10-16）。用了這個就不要再手動打空白，否則會變兩倍 |
| 全形標點擠壓 | `text-spacing-trim` | 只有 Chrome 123 起支援，Firefox、Safari 不支援（https://developer.mozilla.org/docs/Web/CSS/Reference/Properties/text-spacing-trim ，2026-10-16）。當漸進增強用，不要依賴 |
| 內文對齊 | 靠左（`text-align: start`） | 中文左右對齊（`justify`）在窄螢幕會出現大空隙，手機上不要用 |

---

## 5. jp 風格的日文字型換成繁中字型

jp 風格（`jp-*`）的 DESIGN.md 是日文原檔，字型寫的是日文字型。**檔案不改**，套用時照這張表換。
判斷順序：先看**骨架**（明朝、黑體、圓體、手寫），再看**粗細**（細明朝就挑 200／300），最後才看個性。

| jp DESIGN.md 寫的字型 | 骨架 | 換成（Google Fonts） | 系統字型退路 | 說明 |
|---|---|---|---|---|
| 游明朝、本明朝、ヒラギノ明朝、Noto Serif JP、Shippori Mincho、Zen Old Mincho | 明朝 | Noto Serif TC（細明朝用 200／300，一般用 400／500） | Songti TC、PMingLiU | 最接近的對應 |
| 秀英明朝、筑紫明朝 | 個性強的明朝 | Chiron Sung HK，或要更老派時 Cactus Classical Serif | 同上 | 這兩個的味道就是它們的個性，用思源宋體會太平。Chiron Sung HK 是香港字形（見第 1 節） |
| 游ゴシック、ヒラギノ角ゴ、源ノ角ゴシック、Noto Sans JP、Zen Kaku Gothic、秀英ゴシック | 黑體 | Noto Sans TC（同字重） | PingFang TC、Microsoft JhengHei | 源ノ角ゴシック就是 Source Han Sans，和 Noto Sans TC 是同一個設計家族，最接近 |
| 筑紫ゴシック | 帶書寫味的黑體 | Chiron Hei HK | 同上 | |
| 丸ゴシック類（Zen Maru Gothic、M PLUS Rounded 等） | 圓體 | Chiron GoRound TC（要字重）或 Huninn（只要 400） | — | |
| 教科書體、Klee One 等手寫字 | 手寫／楷 | LXGW WenKai TC、Iansui | — | |
| 西文字型（Futura PT、Lato、DM Sans、Cardo、Neuton…） | — | **不換**，照原樣放在 `font-family` 最前面 | DESIGN.md 寫的替代字 | 不在 Google Fonts 的商用字型，用 DESIGN.md 裡寫的替代字或同類型的開源字 |

jp DESIGN.md 裡和字型綁在一起的設定，換成繁中時這樣處理：

| jp 的設定 | 換成繁中時 |
|---|---|
| `font-feature-settings: "palt"`（讓假名和標點比例化） | **內文不要沿用**：繁中沒有假名，套了只會讓標點擠在一起。標題要用的話先實際看效果 |
| 禁則處理 | 用 `line-break: strict`（第 4 節） |
| 行距、字距 | 標題的大字距可以直接沿用；內文字距改回 0～0.05em，行距沿用即可（jp 的內文行距通常也在 1.7～2.0） |
| 直排（`writing-mode: vertical-rl`） | 繁中也能直排，但標點要改成直排標點，夾在裡面的數字和英文要另外處理（`text-combine-upright`） |

**換完之後照 `anti-ai.md`「例外」那一節的判準再看一次**：白底＋明朝不算 AI 痕跡，但換成繁中後
如果又搭了暖米白底和陶土色，就變成第 1 種樣式了。

---

## 查不到或沒查的

- 各字型的中文名：思源、霞鶩文楷、芫荽、粉圓、昭源是通用叫法；`Chiron GoRound TC`、`Cactus Classical Serif` 的正式中文名**待查證**，表中只寫 CSS 名稱
- 第 4 節標「經驗值」的數字沒有可查證的出處，是常見的排版建議，依 DESIGN.md 調整
- `palt` 在各繁中字型上的實際效果：**待查證**（沒有逐一實測）
