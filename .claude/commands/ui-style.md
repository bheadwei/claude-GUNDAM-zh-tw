---
description: 選擇或切換專案的 UI 設計風格——看三個方向的預覽挑一個、從風格庫挑或混搭、用 Claude Design 定調、貼網址抽風格、從現有程式碼反推；同時決定網站類型與動畫等級，寫入 .claude/taskmaster-data/ui-style.json
---

# UI 風格選擇

## 功能

以互動問答選定前端 UI 設計風格，寫入設定檔供所有前端任務引用。一輪問答決定三件事：

1. **風格**：從哪裡來（下面七條路徑擇一）
2. **網站類型**（`site_type`）：決定推薦哪些方向、動畫推薦幾級
3. **動畫等級**（`motion`）：L1 安靜／L2 有節奏／L3 沉浸

| 路徑 | 適合 | `source` |
|---|---|---|
| **F 看預覽選** | 不知道要什麼風格，想先看幾個方向（預設推薦） | `preview` |
| A 單一風格 | 已經知道想要像哪個品牌 | `catalog` |
| B 混搭 | 配色、字型、元件、版面想各取不同品牌 | `catalog` |
| C 瀏覽目錄 | 先看看風格庫有什麼 | （回到入口） |
| D 直接指定 | 熟手，直接打 codename | `catalog` |
| G 用 Claude Design 定調 | 想在畫面上邊看邊調 | `claude-design` |
| H 貼網址抽風格 | 有喜歡的網站 | `url` |
| E 從現有程式碼反推 | 既有專案已經有自己的樣子 | `code-scan` |

路徑代號沿用舊版（A～E 不改名，其他檔案的「路徑 E」照樣找得到）。

---

## 執行流程

### 互動原則（CRITICAL）

**必須遵守 `.claude/rules/interactive-qa.md`**：

- 使用 `AskUserQuestion` 工具，一次一題逐題詢問
- **在記憶中收集所有問答**，全部結束後**一次性**用 `Write` 寫入 `.claude/qa-history/YYYY-MM-DD-HHMMSS-ui-style.md`
- 依使用者答案動態調整後續問題
- **題目和選項一律白話**：使用者不一定懂前端。不寫 token、easing、函式庫名這類詞；
  真的要提就附一句「意思是…」

### 步驟 0：已經有設定檔時

`.claude/taskmaster-data/ui-style.json` 存在 → 先用一段文字顯示目前設定，再問：

| 選項 | 說明 |
|---|---|
| **重新選風格 (Recommended)** | 從入口題重來 |
| **只補網站類型和動畫等級** | 風格不動，只問步驟 2、4，再寫回去（舊版設定檔升級用） |
| **取消** | 不改 |

舊版設定檔的讀法見文末「舊版設定檔」（唯一來源）。

### 步驟 1：入口題（兩層）

`AskUserQuestion` 一題最多 4 個選項，所以拆兩層。

**第一層** —— 題目：「要怎麼決定網站的樣子？」

| 選項 | 說明 |
|---|---|
| **讓我推薦（看預覽選）(Recommended)** | 我依你的專案提 3 個方向，每個都有配色和版面示意，挑一個就好 |
| **我自己挑** | 從風格庫選一個品牌風格，或把幾個混在一起 |
| **我有參考來源** | 有喜歡的網站、想用 Claude Design 邊看邊調，或專案已經有自己的樣子 |

> 使用者直接打品牌 codename（如 `apple`、`linear.app`）→ 走路徑 D，不必再選。
>
> **專案已經有前端樣式時**（找得到 `tailwind.config.*`、CSS 的 `:root` 自訂屬性、
> `components.json`，或 `src/` 底下有 `.css`／元件檔）：在第三個選項的說明加一句
> 「偵測到專案已經有樣式，建議選這個再選『從現有程式碼反推』」。
> 挑一個品牌風格套到已經有自己風格的專案上，結果是新元件遵循一套 app 其他地方不用的規範，越寫越不一致。

**第二層（我自己挑）**

| 選項 | 說明 | 路徑 |
|---|---|---|
| **單一風格 (Recommended)** | 選一個品牌設計系統全面套用 | A |
| **混搭** | 配色、字型、元件、版面分別從不同風格取 | B |
| **先看目錄** | 先看每個風格的介紹，再回來選 | C |

**第二層（我有參考來源）**

| 選項 | 說明 | 路徑 |
|---|---|---|
| **貼網址抽風格** | 貼 1～3 個喜歡的網站，抽它們的配色、字型、圓角 | H |
| **用 Claude Design 定調** | 在 Claude 的設計工具裡邊看畫面邊調，調好再交回來（需要較新版的 Claude Code） | G |
| **從現有程式碼反推** | 照專案現在的樣子整理成一份風格規範 | E |

偵測到專案已經有樣式時，把「從現有程式碼反推」移到第一個並標 (Recommended)。

### 步驟 2：網站類型

先推斷，**推斷不出來才問**。依序讀：

1. 既有 `ui-style.json` 的 `site_type`
2. `docs/17_*.md`（IA 文件）
3. `docs/00_brief.md`、`README.md`、`CLAUDE.md` 的專案描述

推斷出來 → 一句話告知「判斷這是 <類型>，要改請說」，繼續。推斷不出來 → 問。

**選項、寫進設定檔的值、兩層分組，照 `.claude/commands/ui-site.md` 的 Q1（唯一來源，勿在此重述）。**
兩個指令問的是同一題，`/ui-site` 遇到已經有 `site_type` 時會直接帶入。

> 路徑 C（瀏覽目錄）會回到入口題，不在這裡問。

### 步驟 3：依路徑分流

#### 路徑 F：看預覽選

**F-1：先讀這三樣**

1. `.claude/skills/ui-style-compliance/anti-ai.md` 的「產出前」整節，以及「例外」節裡的「看預覽選提方向時」（**提方向的規則以那裡為唯一來源**）
2. `.claude/ui/CATALOG.md`（候選 codename 從這裡找）
3. 專案描述：`docs/00_brief.md`、`docs/17_*.md`、`README.md`、`CLAUDE.md`。
   全都沒有 → 先問一題：「這個網站在介紹什麼、給誰看？一句話就好」（直接輸入）

**F-2：想 3 個方向**

每個方向對應一個 codename（單一），或「主風格＋1～2 個覆蓋」（混搭）。

- **對應的 codename 必須存在**：每個都 `ls .claude/ui/<codename>/DESIGN.md` 確認過
- **色票從那份 DESIGN.md 讀出來**，不要自己配。混搭時色票取自 `color` 覆蓋的那一份
- 方向要從**這個專案的題材**長出來（產業、地方、客群、店裡實際用的東西），不是從「溫暖」「質感」這種形容詞
- 三個方向要**真的不一樣**：不是同一種感覺的三種深淺

**F-3：送出前自查**（任一項不過就換掉那個方向）

- [ ] 3 個 codename 都存在
- [ ] 符合 `anti-ai.md`「看預覽選提方向時」的四條
- [ ] 「暖紙感」這一路（米白底、襯線、陶土或大地色）**最多一個**，而且方向名寫明它接近哪一種樣式
- [ ] 每個方向講得出一個題材上的理由

**F-4：用 `AskUserQuestion` 的 `preview` 欄位呈現**（單選題）

- 題目：「這三個方向，哪一個最接近你想要的？」
- `label`：方向名（白話，例如「安靜的資料桌面」，不是 codename）
- `description`：一句話概念
- `preview`：照下面的格式，**至少 4 個 `#RRGGBB` 色票、至少 3 行 ASCII 版面**

```
方向：安靜的資料桌面
概念：整頁像一張排好的表格，資料本身就是畫面
對應風格：attio（單一）

配色
  #FFFFFF  底色
  #2E3238  主要文字
  #202124  按鈕、強調
  #6F7988  次要文字
  #CAD0D9  分隔線

版面
  ┌──────────────────────────────────┐
  │ 品牌名            功能  價格  登入 │
  ├────────────────────┬─────────────┤
  │ 大標題（靠左）      │ 產品畫面     │
  │ 一句說明＋一個按鈕  │ （真的表格） │
  ├────────────────────┴─────────────┤
  │ 寬窄不一的兩欄說明                 │
  └──────────────────────────────────┘
```

混搭方向的「對應風格」寫成 `linear.app（主）＋ 配色 stripe`。

使用者用自填回「都不喜歡」或說了想要的感覺 → 依回饋再提一輪 3 個。**兩輪都不中**就建議改走「我自己挑」或「貼網址」，不要一直提。

**F-5：寫入**：單一 codename → `mode: "single"`；有覆蓋 → `mode: "mixed"`。`source: "preview"`，
`notes` 記方向名和一句話概念（之後 `ui-builder` 讀得到這個方向的初衷）。

#### 路徑 A：單一風格

**2A-1：分類角度**

| 選項 | 說明 |
|------|------|
| **按設計哲學 (Recommended)** | 依視覺感受分類（極簡/資料密集/終端機/科技感…） |
| **按品牌類型** | 依產業分類（AI/開發工具/金融/消費者…） |

**2A-2a（哲學路徑）：選哲學**

從 11 種哲學選 1（後三種是非科技業的實站品牌）：
- 極簡主義 (Minimalism) — apple, linear.app, stripe, vercel, cal, notion, superhuman...
- 資料密集 (Data-dense) — clickhouse, posthog, sentry, supabase, airtable...
- 終端機美學 (Terminal) — warp, cursor, claude, raycast, ollama...
- 科技未來感 (Futuristic) — x.ai, runwayml, nvidia, spacex, elevenlabs...
- 溫暖擬物 (Warm) — clay, lovable, intercom, pinterest
- 奢華精品 (Luxurious) — ferrari, lamborghini, bmw, tesla, apple
- 企業專業 (Corporate) — ibm, hashicorp, coinbase, kraken, revolut
- 毛玻璃流體 (Glassmorphism) — framer, figma
- 和風靜謐 (Japanese Quiet) — jp-ippodo, jp-toraya, jp-kaikado, jp-mitsui-kyoto, omd-muji...
- 編輯刊物感 (Editorial) — wired, jp-brutus, jp-kurashi-no-techo, jp-dancyu, omd-readmoo...
- 在地零售與生活 (Retail) — starbucks, nike, omd-icook, omd-pinkoi, omd-momoshop...

**2A-3a：選該哲學下的具體品牌**（3-5 個選項，最推薦放第一個）

**2A-2b（品牌類型路徑）：選產業**

從 14 種產業選 1（後六種是非科技業，見 CATALOG「非科技業」）：
- AI / LLM
- 開發工具 / IDE
- 資料 / 後端 / DevOps
- 金融 / 支付 / 加密
- 生產力 SaaS
- 消費者 App
- 汽車 / 精品 / 硬體
- 行銷 / 分析
- 餐飲與茶
- 工藝與生活選物
- 雜誌與編輯
- 新聞媒體
- 旅館與精品
- 在地品牌與電商

**2A-3b：選該產業下的具體品牌**（3-5 個選項）

選項超過 4 個時照步驟 1 的作法拆兩層。`source: "catalog"`。

#### 路徑 B：混搭

**2B-1：先選主風格（base）**

走路徑 A 流程（2A-1 → 2A-3）選定一個 `primary`。

**2B-2：逐項詢問是否覆蓋（共 4 題）**

對每個面向用 `AskUserQuestion` 問：

| 面向 | 問題 |
|------|------|
| 配色 (color) | 配色要沿用主風格，還是從另一個風格抽取？ |
| 字體 (typography) | 字體排版要沿用主風格，還是從另一個風格抽取？ |
| 元件 (components) | 按鈕/卡片/輸入框風格要沿用主風格，還是從另一個風格抽取？ |
| 間距版面 (layout) | 間距與版面節奏要沿用主風格，還是從另一個風格抽取？ |

每題選項：
- **沿用主風格 (Recommended)** — null（不覆蓋）
- **從另一風格抽取** — 若選此，下一題問「從哪個風格？」（列熱門幾個 + 直接輸入）

動畫不在這裡問——它是步驟 4 的獨立題。`source: "catalog"`。

#### 路徑 C：瀏覽目錄

1. Read `.claude/ui/CATALOG.md`
2. 以條列方式展示分類摘要給使用者
3. 回到步驟 1 重新問入口題

#### 路徑 D：直接指定

1. `AskUserQuestion` 問：「輸入品牌 codename」（直接輸入框，提示範例）
2. 驗證 `.claude/ui/<codename>/DESIGN.md` 存在
3. 不存在 → 提示可用清單 → 回步驟 1

`source: "catalog"`。

#### 路徑 G：用 Claude Design 定調

Claude Design 是 Anthropic Labs 的 research preview（入口 `claude.ai/design`），
入口、指令、交接格式都可能改。以下是 2026-10-16 的查證狀態：

- Claude Code 端的 `/design`、`/design-sync` 需要 **v2.1.265 以上**
- 官方說明：**沒有先建設計系統時，產出是「可用但通用」**
- **交接包格式查不到官方說明** → 轉寫時以實際收到的內容為準

**G-1：版本檢查**

```bash
v=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -z "$v" ]; then echo "UNKNOWN"
elif [ "$(printf '%s\n' 2.1.265 "$v" | sort -V | head -1)" = "2.1.265" ]; then echo "OK $v"
else echo "OLD $v"; fi
```

- `OLD` → 告訴使用者：「你的 Claude Code 是 <版本>，Claude Design 的交接需要 2.1.265 以上。
  可以先跑 `claude update` 升級，升級後重開再跑 `/ui-style`。」→ **回到步驟 1**
- `UNKNOWN`（找不到 `claude` 指令）→ 請使用者自己確認版本，不夠新同樣回到步驟 1

**G-2：一步一步帶**（每一步說完用 `AskUserQuestion` 問「好了／卡住了（直接輸入狀況）」，好了才講下一步）

1. 開 `claude.ai/design`
2. **先建設計系統**：從專案程式碼、品牌素材（logo、色票、字型檔），或既有網站建一套。
   提醒使用者：「官方說沒有設計系統時，做出來的東西可用但很通用——這一步別跳。」
3. 讓它產一個代表性的畫面（例如首頁），**看著畫面微調**到滿意
4. **Export → Hand off to Claude Code**，把收到的東西交回來（貼上指令、給檔案路徑，或照它的提示在這裡操作）

**G-3：轉寫**：照下方「轉寫成 `_project/DESIGN.md`」一節。收到的內容對應不上段落的欄位留 `【待確認】`，
不要猜。`source: "claude-design"`，`notes` 記 `source: claude-design` 和收到的交接內容是什麼形式（檔案、指令、貼上的文字）。

> 卡在某一步超過兩次 → 問使用者要不要改走「貼網址」或「看預覽選」，不要硬推。

#### 路徑 H：貼網址抽風格

**只取風格**：色票、字型、字級、圓角、陰影、間距。**不搬 logo、圖片、文案**——
那是別人的品牌資產，而且 `_project/DESIGN.md` 描述的是「這個專案要長怎樣」，不是那個網站。

**H-1：收網址**

`AskUserQuestion`，題目：「貼 1～3 個你喜歡的網站網址（直接輸入，多個用空白隔開）」。
選項給「我還沒想到，改用看預覽選」「回上一步」，網址讓使用者直接打。
只收 `http(s)://`，超過 3 個只取前 3 個並告知。

**H-2：逐一抽取**（依序試，前一個成功就不往下）

| 順序 | 方法 | 抽什麼 | 信心 |
|---|---|---|---|
| 1 | firecrawl MCP 的 `firecrawl_scrape`，`formats` 帶 `branding` 和 `screenshot`（參數名以當下工具的 schema 為準） | `branding` 的 `colors`、`typography`、`spacing`、`components`。**忽略** `logo`、`images`；`personality` 是工具推測的，不當事實 | 色票、字型、圓角：高；色彩**角色**（誰是 primary）：中，要標「推斷」 |
| 2 | 沒有 firecrawl 工具、呼叫失敗、或回傳沒有 `branding` → Playwright MCP：`browser_navigate` 開網址，`browser_evaluate` 對 `body`、`h1`、`h2`、`a`、`button`、`input` 讀 `getComputedStyle` 的 `color`、`background-color`、`font-family`、`font-size`、`font-weight`、`border-radius`、`box-shadow`、`padding`，再截一張圖 | 同上，但只取樣這幾種元素 | 高，但標「只取樣 6 種元素」 |
| 3 | 兩個都不行 → 請使用者上傳那個網站的截圖（直接拖進對話），用 Read 看圖 | 色票、大致的圓角和間距感 | **全部標「目測，低信心」**；字型寫「目測無法確認」 |

firecrawl 的截圖網址 **24 小時後失效**（docs.firecrawl.dev/features/scrape，2026-10-16 查）。

**H-3：截圖確認**（每個網址一題，**確認後才往下**）

把截圖給使用者看（給截圖網址，或請他對照自己上傳的那張），自己也用 Read 看過。
`AskUserQuestion`，題目：「<網域> 是你要的那種感覺嗎？」，`preview` 放抽到的色票和字型：

| 選項 | 之後 |
|---|---|
| **是，就是這個感覺** | 收下 |
| **不是，換一個網址** | 使用者直接輸入新網址 → 回 H-2 |
| **這個不要** | 丟掉這個網址 |

全部都不要 → 回到步驟 1。

**H-4：多個網址時逐項選**（只剩一個就跳過）

對配色、字型、元件（按鈕／卡片／輸入框的圓角與陰影）、版面（間距）各問一題「這一項要照哪個網站？」，
選項是各網址的網域名。四項都同一個網址就是單一來源。

**H-5：轉寫**：照下方「轉寫成 `_project/DESIGN.md`」一節，檔頭記每個網址、抽取日期、用了哪個方法。
`source: "url"`。寫完跑一次自查，**有結果就逐行看，搬進來的 logo、圖片網址一律拿掉**：

```bash
grep -nE 'https?://[^ )]+\.(png|jpe?g|svg|webp|gif|ico)|logo' .claude/ui/_project/DESIGN.md
```

（檔頭的來源網址本身不是圖片，不會被抓到。）

#### 路徑 E：從現有程式碼反推

**委派 `skill-curator`**（`subagent_type: "skill-curator"`）—— 它的職責就是維護 `.claude/` 底下的素材。

產出：`.claude/ui/_project/DESIGN.md`。`_` 前綴表示「非品牌、由本專案反推」。

**掃描來源**（依優先序，找到哪個用哪個）：

| 來源 | 抽什麼 |
|---|---|
| `tailwind.config.{js,ts,mjs}` | theme.extend 的 colors／fontFamily／spacing／borderRadius／boxShadow |
| CSS 檔的 `:root` / `@theme` 自訂屬性 | 已定義的 token 與其命名慣例 |
| `components.json`（shadcn） | baseColor、cssVariables、radius |
| styled-components／emotion 的 theme 檔 | 同上 |
| MUI `createTheme()` | palette／typography／shape |
| 元件檔（`Button`／`Card`／`Input`） | 實際存在的變體清單 |

**沒有集中設定檔時**（純手寫 CSS／Tailwind 行內類名），改用統計：

```bash
# 出現頻率最高的色值 —— 高頻且用在背景/文字的是主色
rg -o '#[0-9a-fA-F]{3,8}|rgb\([^)]+\)' --no-filename | sort | uniq -c | sort -rn | head -20
# 實際用到的間距 → 反推尺度（是不是 4/8px 倍數）
rg -o 'p[xytblr]?-\[?[0-9.]+(rem|px)?\]?|gap-[0-9]+|m[xytblr]?-[0-9]+' --no-filename | sort | uniq -c | sort -rn | head -20
# 圓角與陰影的實際值域
rg -o 'rounded-[a-z0-9]+|border-radius:[^;]+|shadow-[a-z0-9]+|box-shadow:[^;]+' --no-filename | sort | uniq -c | sort -rn | head -20
# 字體
rg -o 'font-family:[^;]+|font-[a-z]+' --no-filename | sort | uniq -c | sort -rn | head -15
```

**信心分級**照下方共用節。設計**意圖**推不出來，不要編。skill-curator 沒有提問工具，所以流程是：

1. skill-curator 掃描、照共用節寫好 DESIGN.md，意圖段落留 `【待確認】`，回 `NEEDS_CONTEXT`，
   附下面三題和**每題建議的預設答案**（依它掃到的東西推）
2. 主模型用 `AskUserQuestion` **逐題**問使用者，建議答案放第一個並標 (Recommended)
3. 主模型**再派一次** skill-curator，把三個答案補進意圖段落、拿掉對應的 `【待確認】`

三題（唯一來源；`skill-curator.md` 指向這裡）：

1. 這個產品給誰用、在什麼情境下用？
2. 要資訊密集（工具型儀表板）還是留白克制（內容型）？
3. 有沒有想像中的參考品牌？（可從 CATALOG 挑，或直接打字）

**順手產出的價值**：反推過程會抓到既有程式碼的**不一致** —— 三種不同圓角、
五個相近但不同的灰、兩套按鈕實作。寫進 DESIGN.md 末尾的「待收斂項目」，它本身就是可行動的技術債清單。

`source: "code-scan"`，`notes` 記「由現有程式碼反推」與掃描日期。

#### 共用：轉寫成 `_project/DESIGN.md`

路徑 E、G、H 都照這一節寫（**唯一來源**）。

**已經有 `.claude/ui/_project/DESIGN.md`** → 先問「覆蓋／取消」。取消就回到步驟 1。

**段落標題用新格式**（`ui-style-compliance` 1.2 節的對照表認得的那一組），混搭時才抽得到：

```markdown
# Design System：<專案名>（_project）

> 來源：<code-scan | claude-design | url>
> 來源細節：<掃描的設定檔／交接內容的形式／每個網址與它用了哪個抽取方法>
> 產生日期：YYYY-MM-DD
> 信心：高＝直接讀到的值；中＝推斷（行尾標「推斷」）；低＝推不出來，留【待確認】

## Overview
<設計意圖與個性。只寫使用者親口說的，沒有就寫【待確認】>

## Colors
<每個色：名稱、hex、角色。角色是推斷的就標「推斷」>

## Typography
<字型家族、字級階層、字重、行高>

## Components
<按鈕、輸入框、卡片的圓角、陰影、邊框、內距>

## Layout
<間距尺度（是不是 4／8 的倍數）、版面寬度、區塊節奏>

## 待確認
<所有【待確認】的項目，一行一個>
```

- **不加 YAML 檔頭**：數值直接寫在段落裡。檔頭有 `version: alpha` 時，`ui-style-compliance` 會去 YAML 找數值
- 路徑 E 另外加 `## 待收斂項目`
- 抽不到的段落**留標題、內文寫「抽不到，沿用 fallback」**，不要整段刪掉
- 不寫動畫等級：那是 `ui-style.json` 的 `motion`

寫入設定檔：`primary: "_project"`、`mode: "single"`。

> `_project` 不需要列進 `CATALOG.md`（那是品牌目錄）。`check-counts.sh` 對 `_` 前綴的目錄整個豁免。

### 步驟 4：動畫要多少（每條路徑都問，在確認題之前）

**選項文字照 `.claude/skills/ui-style-compliance/motion.md` 第 1 節（唯一來源）。** 先 Read 那一節再組題，
不要憑記憶寫，也不要在這裡另抄一份。

- 題目：「網站的動畫要多少？」
- `label`：表格的「等級」欄（如 `L1 安靜`）
- `description`：依序接「感覺」「像什麼」「適合誰」「代價」四欄
- **推薦與限制**：照同一節的「依網站類型推薦」表。推薦的放第一個並標 (Recommended)；
  表上寫「不提供 L3」的網站類型，就只給 L1、L2 兩個選項
- 送出前確認選項和描述**沒有任何函式庫名或技術名詞**。那一節本來就沒有；
  如果你看到有，是那一節壞了——照常出題（把那個詞拿掉），並在完成訊息提醒使用者回報

步驟 0 選「只補網站類型和動畫等級」的，問完這題直接跳步驟 5。

### 步驟 5：確認

用 `AskUserQuestion` 顯示最終設定摘要：

```
來源：看預覽選 / 風格庫 / Claude Design / 網址 / 現有程式碼
模式：單一風格 / 混搭
主風格：{primary}（{中文摘要}）
[若混搭]
  配色：{color or 沿用}
  字體：{typography or 沿用}
  元件：{components or 沿用}
  間距：{layout or 沿用}
網站類型：{site_type 的中文}
動畫：{L1 安靜 / L2 有節奏 / L3 沉浸}

確認？
```

選項：**確認** / **重新選擇**（回步驟 1）

### 步驟 6：寫入設定檔

建立 `.claude/taskmaster-data/ui-style.json`（若不存在目錄先建立）：

```json
{
  "version": "1.1",
  "mode": "single",
  "primary": "apple",
  "overrides": {
    "color": null,
    "typography": null,
    "components": null,
    "layout": null
  },
  "motion": "L1",
  "site_type": "saas",
  "source": "catalog",
  "chosen_at": "2026-10-16",
  "notes": ""
}
```

混搭模式範例：

```json
{
  "version": "1.1",
  "mode": "mixed",
  "primary": "linear.app",
  "overrides": {
    "color": "stripe",
    "typography": null,
    "components": "apple",
    "layout": null
  },
  "motion": "L2",
  "site_type": "brand",
  "source": "preview",
  "chosen_at": "2026-10-16",
  "notes": "方向「工程感的品牌頁」：Linear 節奏 + Stripe 配色 + Apple 元件"
}
```

| 欄位 | 值 |
|---|---|
| `motion` | `L1`／`L2`／`L3` |
| `site_type` | `/ui-site` Q1 表的「寫進設定檔」欄 |
| `source` | `preview`／`catalog`／`claude-design`／`url`／`code-scan` |
| `overrides` | 只有 `color`、`typography`、`components`、`layout` 四個鍵。**沒有 `animation`**（動畫改由頂層 `motion` 決定） |

### 步驟 7：寫入 QA 歷史

將所有問答收集後，一次性 `Write` 到：
`.claude/qa-history/YYYY-MM-DD-HHMMSS-ui-style.md`

格式：
```markdown
# UI 風格選擇 QA 歷史

**時間：** YYYY-MM-DD HH:MM:SS
**最終結果：** {source} / {mode} / {primary} / {overrides} / {site_type} / {motion}

---

## Q1: 入口
- 選項：讓我推薦 / 我自己挑 / 我有參考來源
- 答案：{user_choice}

## Q2: ...
...

---

## 最終結論
寫入 `.claude/taskmaster-data/ui-style.json`
```

路徑 F 要把三個方向的名稱和對應 codename 都記下來（沒選中的也記），之後重跑時可以參考。
路徑 H 的網址照記；使用者貼的網址若含帳號、token 這類參數，記之前先拿掉（`interactive-qa.md` 的敏感資料檢查）。

### 步驟 8：完成訊息

```
UI 風格已設定

來源：{source}
模式：{mode}
主風格：{primary}
覆蓋：{overrides or 無}
網站類型：{site_type}
動畫：{motion}

設定檔：.claude/taskmaster-data/ui-style.json
完整規範：.claude/ui/{primary}/DESIGN.md

前端任務將自動套用此風格。如需調整：
  /ui-style       重新選擇
```

---

## 舊版設定檔（唯一來源）

`version` 是 `"1.0"` 或沒有 `version` 的設定檔照常能用，讀法：

| 狀況 | 怎麼處理 | 提示 |
|---|---|---|
| 沒有 `motion` | 當作 `L1` | 「設定檔是舊版，動畫先照 L1（安靜）。要調整可以跑 `/ui-style` 選『只補網站類型和動畫等級』」 |
| 有 `overrides.animation` | **忽略**（動畫改由 `motion` 決定） | 「舊設定裡的動畫覆蓋已經不用了，改由動畫等級決定」 |
| 沒有 `site_type` | 動畫推薦當作「其他」 | 不提示 |
| 沒有 `source` | 不影響任何行為 | 不提示 |

**提示只講一次**：同一個指令的流程裡講過就不再講。`/ui-page`、`/ui-site`、`ui-builder` 讀設定檔時都照這張表。

---

## 使用方式

```
/ui-style                 互動式選擇（推薦）
/ui-style apple           直接指定單一風格
/ui-style apple+stripe    混搭（主：apple、覆蓋：自動提示）
```

帶參數時跳過步驟 1 和步驟 3，步驟 2、4 照問。

## 特殊情境

- **已存在設定檔** — 見步驟 0
- **未指定前端需求** — 仍可執行，供未來前端任務參考
- **codename 大小寫** — 一律轉小寫（對應資料夾名稱）
- **混搭但全部沿用主風格** — 自動降級為 `mode: single`
