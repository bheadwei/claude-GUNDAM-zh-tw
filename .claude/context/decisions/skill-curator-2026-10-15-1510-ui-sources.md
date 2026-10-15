# UI 風格庫來源調查：除了 VoltAgent 還能從哪裡收

- 日期：2026-10-15
- 執行者：skill-curator（只做調查，沒有改任何檔案）
- 範圍：`.claude/ui/` 的上游來源、授權、可以補哪些缺口
- 查證方式：GitHub API（`gh api`，2026-10-15 當天的數字）＋ 讀上游的 README、LICENSE 和樣本檔

---

## 0. 先修正一個前提

**69 份並不全是 VoltAgent 來的。** 用 git log 對照上游清單的結果：

| 來源 | 份數 | 證據 |
|---|---|---|
| VoltAgent，上游還在 | 58 | 和上游 `design-md/` 目錄同名 |
| VoltAgent，**上游已經刪掉** | 1（`semrush`） | 上游最後一筆 commit 是 2026-05-01，現在的清單裡沒有 |
| **自己抽的**（用 firecrawl 實測） | 10（attio、clerk、granola、huggingface、neon、openai、perplexity、railway、shadcn、zed） | commit `d4e6f78`（2026-07-24），訊息寫明「依實站品牌抽取」 |

這代表來源 metadata 不能只有一個「來源」欄位。**「自己抽的」本身就要算一種來源。**

---

## 1. VoltAgent/awesome-design-md 本身

| 項目 | 結果 |
|---|---|
| 網址 | https://github.com/VoltAgent/awesome-design-md （網站 getdesign.md） |
| 熱度 | 121,439 stars，最後 push 是 2026-10-14，仍在維護 |
| 授權 | **MIT**（Copyright (c) 2026 VoltAgent）。README 另外聲明：內容 "as is"、數值取自公開 CSS、**不主張擁有任何品牌的視覺識別** |
| 份數 | **84 份**。我們有 59 份是從它來的，其中 58 份還在上游 |
| 上游有、我們沒有的（26） | 1win、aljazeera、binance、bmw-m、bugatti、dell-1996、dji、hp、jobright、mastercard、mercury、meta、mydealz、nerdwallet、nike、nintendo-2001、oracle、oura、playstation、sap、shopify、slack、**starbucks**、**theverge**、vodafone、**wired** |
| 收稿政策 | CONTRIBUTING 寫明「cannot accept DESIGN.md pull requests」，等於只有維護者自己在加 |

### 會影響我們的兩件事

1. **上游格式已經換了。** 多數檔案改用 Google Stitch DESIGN.md 規格（YAML frontmatter 寫 `version: alpha`，章節是 `## Overview` / `## Colors` / `## Typography` / `## Layout` / `## Components`）。抽查 stripe、linear.app、nike、wired 都是新格式，starbucks 還是舊的 9 節格式。我們手上的是**舊格式快照**（例如 airbnb 本地是 `## 2. Color Palette & Roles`）。
   → `ui-style-compliance` 1.2 節的 mixed 模式是**照舊標題抽段落**的（`Color Palette & Roles`、`Typography Rules`…）。**直接拿上游新版覆蓋，mixed 模式會抽不到東西，而且不會報錯。** 同步之前一定要先處理這點（見第 5 節）。
2. **MIT 要求保留著作權聲明，但模板目前沒有附。** 59 份衍生內容已經散布到其他專案，卻沒有附 VoltAgent 的 LICENSE。這是現存的授權缺口，不管要不要加新來源都該補。

---

## 2. 候選來源一覽

stars 和最後 push 日期都是 2026-10-15 用 `gh api repos/<repo>` 查的。

### A. DESIGN.md 集合（可以直接當風格匯入）

| 名稱 | 熱度 | 內容與格式 | 授權 | 補得到哪個缺口 | 建議 |
|---|---|---|---|---|---|
| [kzhrknt/awesome-design-md-jp](https://github.com/kzhrknt/awesome-design-md-jp) | 991★，2026-10-15 | **574 份**日本品牌。用的是 **VoltAgent 舊版 9 節格式**（`## 2. Color Palette & Roles`、`## 3. Typography Rules`…），**跟我們的標題直接相容**。Typography 多了 CJK 子節：和文字型、font-family 指定、禁則、OpenType、縱書。內文是日文，每份附 preview.html。數值用 Puppeteer computed style 實測 | **MIT**，另有免責聲明（非官方、商標屬原公司） | **非科技業：大量**。茶舖（ippodo 一保堂、toraya）、咖啡（bluebottlecoffee、onibuscoffee、sarutahiko）、在地工藝（hasami-porcelain、nakagawa、kaikado、sousou）、編輯雜誌（brutus、casa-brutus、kurashi-no-techo、popeye、dancyu）、精品（aman-tokyo、mikimoto、tasaki、grand-seiko）、美術館、旅館。**CJK 字型處理：有**，但是日文字型 | **納入，優先度 2**。挑非科技類 10～15 份，用 `jp-` 前綴當 codename |
| [kwakseongjae/oh-my-design](https://github.com/kwakseongjae/oh-my-design) | 535★，2026-10-14 | 521 份 reference，放在 `web/references/<id>/`，每份有 DESIGN.md、reference.json（含國家、驗證日期）和 `.verification.md`。格式是它自己的 design-md v3：章節接近 Google 規格（Overview / Colors / Typography / Components / Do's and Don'ts），證據標得很細，查不到的值寧可留空 | **MIT**。README：「References belong to their respective companies; reproduced for educational reference」 | **繁中：目前唯一有大量台灣品牌的來源**，像誠品 eslite、pinkoi、icook、kkday、gogoro、familymart-tw、thsr、kkbox、dcard、readmoo、cathay、evaair、poya、momoshop。誠品那份記錄了實際的字型堆疊：Noto Sans TC → PingFang TC → 微軟正黑體。**非科技**也有：muji、ikea、lego、starbucks、bloomandwild、cookpad、theguardian、ft | **納入，優先度 3**。只收台灣與非科技類。要注意：它的嚴格度讓部分檔案的色票只有電商區塊（誠品就是這樣），挑檔時要先看 Colors 節夠不夠用。標題要經過別名對應才能給 mixed 模式用 |
| [VoltAgent/official-design-md](https://github.com/VoltAgent/official-design-md) | 522★，2026-09-21 | 只是**連結清單**，列出公司自己發布的 DESIGN.md（Ant Design、Atlassian、Clerk、Nuxt、Vercel、Oxide…） | 清單本身 MIT；**每個檔案的授權屬於各公司，不一定能再散布** | 全是科技／SaaS | **只當參考**。要收某一份，得逐檔確認該公司的授權 |
| [scroobius-pip/fudge-design-md](https://github.com/scroobius-pip/fudge-design-md) | 115★，2026-08-11 | 約 1000 份，由 Fudge 從實站擷取後產生。README 說「thin generated drafts are not listed」 | MIT | 有一些非科技的：nytimes、oatly、etsy、christies、pentagram、mcsweeneys、generalbread、hoopladonuts、ramen.haus | **只當參考**。量大但品質沒有逐份驗證；格式也跟我們不同。真的缺某個品牌時再單份評估 |
| [educlopez/design-bites](https://github.com/educlopez/design-bites) | 86★，2026-10-14 | 295 份，多數是個人作品集、設計工作室、AI 新創 | MIT | 幾乎不補缺口 | **不採用** |
| [rohitg00/awesome-claude-design](https://github.com/rohitg00/awesome-claude-design) | 1,144★，**2026-04-23 後就沒更新** | 依「美學家族」分類（editorial、warm、brutalist、indie…），但 repo 裡實際只有約 7 份 DESIGN.md，其他都是外部連結 | MIT | 「Cult / Indie」那節列了 Criterion、A24、ProPublica 這類非科技品牌，**但只有連結，沒有檔案** | **只當參考**。分類法可以拿來改善 CATALOG |
| [VoltAgent/awesome-claude-design](https://github.com/VoltAgent/awesome-claude-design) | 4,086★，2026-06-20 | 68 個條目全部連到 getdesign.md，**跟 awesome-design-md 是同一批內容** | MIT | 無 | **不採用**（重複） |
| [bergside/awesome-design-skills](https://github.com/bergside/awesome-design-skills) | 3,181★，2026-06-28 | 67 個「風格家族」skill，每個是 SKILL.md 加 DESIGN.md（cafe、editorial、paper、retro、riso、vintage、terracotta…） | MIT | 名稱上看起來能補非科技風格，**但內容很薄**：cafe 那份只有 55 行，字型是 Poppins 加 JetBrains Mono，semantic 色用的是 Tailwind 預設值，本身就是 AI 感的典型 | **不採用**。會把 AI 感帶進來，跟使用者的要求相反 |
| 簡中鏡像（[fchangjun](https://github.com/fchangjun/awesome-design-md-cn)、[bayshier](https://github.com/bayshier/awesome-design-md-cn)、[HU-UH](https://github.com/HU-UH/awesome-design-md) 等） | 145★ 以下 | 多半是 VoltAgent 的翻譯或鏡像 | fchangjun **沒有 LICENSE**；其他是 MIT | 沒有原創內容 | **不採用** |
| [ricocc/brands-design-md](https://github.com/ricocc/brands-design-md) | 155★ | 品牌 DESIGN.md | **沒有 LICENSE** | 不明 | **不採用**（授權不明） |
| [CaesiumY/ko-design-md](https://github.com/CaesiumY/ko-design-md) | 62★，2026-10-13 | 韓國品牌，有標出處 | MIT | 對繁中幫助有限 | **不採用**（oh-my-design 已經涵蓋韓國品牌） |

### B. 格式規格

| 名稱 | 熱度 | 說明 | 授權 | 建議 |
|---|---|---|---|---|
| [google-labs-code/design.md](https://github.com/google-labs-code/design.md) | 28,385★，2026-10-08，release 0.4.0（2026-07-27） | DESIGN.md 的官方規格。內容是 YAML token 加上 8 個固定順序的章節（Overview / Colors / Typography / Layout / Elevation & Depth / Shapes / Components / Do's and Don'ts），附 `npx @google/design.md lint`、`diff`、`export` | Apache-2.0 | **當格式基準**。VoltAgent 新版和 oh-my-design 都在往它靠。同步腳本可以用 `lint` 做匯入前的檢查 |

### C. 反 AI 感（不是風格，是規則或偵測器）

| 名稱 | 熱度 | 內容 | 授權 | 建議 |
|---|---|---|---|---|
| [anthropics/skills — frontend-design](https://github.com/anthropics/skills/tree/main/skills/frontend-design) | repo 181,227★；這個 skill 最後更新 2026-09-03（"avoid generic design defaults"） | 列出 AI 產出常見的 **5 種集群**。重點是第 1 種：**米白底（約 #F4F1EA）加高對比襯線標題加陶土色強調（約 #D97757）**，它明說這是 Claude 自己的介面色，出現在使用者專案裡會被認出來。另外 4 種是黑底配單一螢光綠、報紙排版、SaaS 卡片組、模板裝飾（全大寫 eyebrow、`→`、中點分隔）。也有官方 plugin 版本（[claude-plugins-official/plugins/frontend-design](https://github.com/anthropics/claude-plugins-official)） | 這個 skill 是 **Apache-2.0**（附 LICENSE.txt）。repo 沒有統一授權，各 skill 不同 | **當參考**，把重點轉寫進 `ui-style-compliance` 2.5／2.6（唯一來源），附出處連結。**不要整份複製**：Apache-2.0 要附 NOTICE，而且 subagent 拿不到 Skill 工具，裝成 plugin 也到不了 ui-builder |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | 81,322★，2026-10-15 | 1 個 skill、24 個指令，加 **59 條確定性偵測規則**（CLI 跑，不需要 LLM）。README 說它是從 frontend-design 延伸出來的 | Apache-2.0 | **只當參考**。24 個指令跟我們的 `/ui-*` 重疊，整套搬進來是兩套系統並存。偵測規則可以當 hook 的候選素材 |
| [funboy322/avoid-ai-design](https://github.com/funboy322/avoid-ai-design) | 108★，2026-09-24 | 67 條 AI 痕跡目錄，用 P0／P1／P2 分級（由誰會注意到來分），附零依賴的掃描器 `scripts/detect.mjs`。**特別點名「有品味的預設」**：cream 加 terracotta、Space Grotesk、Geist、Instrument Serif、Fraunces | MIT | **當參考，優先度高於 impeccable**。小、單一用途、MIT。它的目錄可以拿來補 2.5／2.6；掃描器可以評估做成 PostToolUse 提醒（判斷得出時機的事該用 hook，見 writing-extensions） |
| [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | 96,717★，2026-10-14 | 14 個 skill（taste、minimalist、brutalist、soft、redesign、imagegen…），走美術指導加參考圖加瀏覽器檢查的路線 | MIT | **只當參考**。偏流程，不是風格資料 |
| [emilkowalski/skills](https://github.com/emilkowalski/skills) | 46,321★，2026-10-11 | 以動效為主（easing、時長、效能），另有 apple-design | MIT | **只當參考**。動效的通用規則若要收，進 2.6 |
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 135,955★，2026-10-15 | CSV 資料庫：79 種風格、192 種產品類型對應的配色、74 組字型配對。`products.csv` 有 Restaurant/Food Service、Bakery/Cafe、Florist/Plant Shop、Brewery/Winery、Luxury/Premium Brand、Hotel/Hospitality、Magazine/Blog | MIT | **只當參考**。「產業對應風格」那張表可以拿來幫 CATALOG 加「依產業」索引。資料本身是通用配色，不是實站擷取，直接匯入會變成另一種罐頭感 |

### D. Token 與主題集合

| 名稱 | 熱度 | 內容 | 授權 | 建議 |
|---|---|---|---|---|
| [jnsahaj/tweakcn](https://github.com/jnsahaj/tweakcn) | 10,451★，2026-09-03 | shadcn 主題編輯器。`utils/theme-presets.ts` 有 vintage-paper、mocha-mousse、elegant-luxury、sage-garden、kodama-grove 等預設 | Apache-2.0 | **不採用**。只有色票和圓角，沒有排版、元件、版面規則，轉成 DESIGN.md 要自己補大半；而且 shadcn 色票本身就在 AI 痕跡清單上 |
| [saadeghi/daisyui](https://github.com/saadeghi/daisyui) | 42,597★，2026-10-13 | 35 個主題（coffee、retro、garden、luxury、lofi、caramellatte、silk…） | MIT | **不採用**。理由同上，只有色彩 token |
| [radix-ui/themes](https://github.com/radix-ui/themes) | 8,765★，最後 push **2026-04-11** | 元件庫的主題系統 | MIT | **不採用**。它是元件庫，不是風格集合，而且半年沒更新 |
| [argyleink/open-props](https://github.com/argyleink/open-props) | 5,546★，2026-10-11 | CSS 變數基礎值（easing、陰影、漸層…） | MIT | **不採用**。它提供的是素材，不是風格 |

---

## 3. 缺口對照：使用者在意的兩點

| 缺口 | 誰補得到 | 備註 |
|---|---|---|
| 非科技業：餐飲、在地小店 | **jp**（茶舖、咖啡、和菓子、麵包、居酒屋類）、**oh-my-design**（icook、cookpad、starbucks、familymart-tw）、VoltAgent 新增的 starbucks | 主力是 jp |
| 編輯或雜誌感 | **jp**（brutus、casa-brutus、kurashi-no-techo、popeye）、VoltAgent 新增的 wired、theverge、aljazeera、oh-my-design 的 theguardian、ft | |
| 溫暖手作 | **jp**（hasami-porcelain、nakagawa、kaikado、sousou、mina-perhonen）、oh-my-design 的 pinkoi | **風險見下方** |
| 精品 | **jp**（aman-tokyo、mikimoto、tasaki、grand-seiko）、VoltAgent 新增的 bugatti | |
| 繁中 | **oh-my-design**（台灣品牌和實際的 TC 字型堆疊）。jp 的 CJK 排版規則（禁則、行距、字距）可以借用 | 沒有找到純繁中的 DESIGN.md 集合 |
| 反 AI 感 | frontend-design、avoid-ai-design、impeccable 的規則 | 進 `ui-style-compliance`，不進 DESIGN.md |

**「溫暖手作」有一個要先講清楚的風險。** Anthropic 的 frontend-design 和 avoid-ai-design 都明確把「米白、襯線、陶土色」列為**現在最典型的 AI 痕跡**。如果照字面去找一份通用的「溫暖手作」風格（例如 bergside 的 cafe、terracotta），等於把 AI 感直接寫進風格庫。要補這一塊，應該用**實站擷取的具體品牌**（例如一保堂、中川政七商店），它們的溫暖來自特定字型、特定色票和真實的版面決定，不是一個通用配方。

---

## 4. 推薦納入順序

| 順序 | 來源 | 做法 | 理由 |
|---|---|---|---|
| 1 | **VoltAgent/awesome-design-md**（重新同步） | 先補 MIT 聲明；挑新增的 starbucks、wired、theverge、aljazeera、mastercard、oura、nike、shopify；semrush 標成「上游已刪除、本地保留」 | 已經在用、授權清楚。新增的幾份剛好補到雜誌和非科技。**前提：先處理格式改版**（第 5 節） |
| 2 | **kzhrknt/awesome-design-md-jp** | 挑非科技類 10～15 份，codename 加 `jp-` 前綴；日文字型怎麼換成繁中字型寫進 `ui-style-compliance`（一處），**不要改 15 份檔案** | 非科技最大宗、標題格式直接相容、MIT、每天都在更新 |
| 3 | **kwakseongjae/oh-my-design** | 只收台灣品牌與少數非科技國際品牌，加 `omd-` 前綴；先確認每份 Colors 節的資料夠不夠用 | 唯一有繁中實際字型堆疊的來源 |
| 4 | **anthropics frontend-design 加 funboy322/avoid-ai-design** | 轉寫進 `ui-style-compliance` 2.5／2.6，附出處；另外評估 `detect.mjs` 能不能做成 hook | 反 AI 感要放在跨風格層，不是放在風格檔裡 |
| 參考 | google design.md 規格、ui-ux-pro-max 的產業表、rohitg00 的分類法 | 拿來改 CATALOG 的分類，以及同步腳本的 lint | |

**prefix 為什麼必要：** jp、oh-my-design、VoltAgent 三邊都有 muji、uniqlo、notion、starbucks 之類的同名品牌，不加前綴 codename 會撞名。

---

## 5. 多來源怎麼記錄

### 5.1 metadata 放哪裡

**建議放在每個風格目錄的 sidecar 檔 `SOURCE.json`，不要寫進 DESIGN.md。** 理由：

- DESIGN.md 保持跟上游**一模一樣**，同步時直接比 hash 就知道有沒有改
- ui-builder 讀風格時不會多吃 metadata 的 context
- Google 規格的 YAML frontmatter 是 token schema，塞自訂欄位要看規格允不允許（規格只說遇到不認得的**章節**要保留，沒說不認得的 frontmatter key 怎麼處理，**這點我沒查到**）

### 5.2 建議欄位

```json
{
  "source": "voltagent | jp | omd | self-extracted | reverse-engineered",
  "upstream_repo": "VoltAgent/awesome-design-md",
  "upstream_path": "design-md/airbnb/DESIGN.md",
  "upstream_commit": "3b60532",
  "upstream_format": "voltagent-9section | google-alpha | omd-v3",
  "upstream_status": "present | removed",
  "imported_at": "2026-04-19",
  "license": "MIT",
  "license_file": ".claude/ui/_licenses/voltagent-awesome-design-md.txt",
  "locally_modified": false,
  "local_changes": "",
  "language": "en | ja | zh-TW",
  "extraction_method": "upstream | firecrawl | puppeteer | code-scan"
}
```

自己抽的那 10 份：`source: self-extracted`、`upstream_repo: null`、`extraction_method: firecrawl`，`imported_at` 用 `d4e6f78` 的日期。

### 5.3 授權檔

建一個 `.claude/ui/_licenses/` 目錄，每個上游放一份 LICENSE 原文。`_` 前綴已經在 CATALOG 檢查的豁免範圍內。MIT 要求「保留著作權和授權聲明」，這是**現在就該補**的。

---

## 6. 同步腳本怎麼支援多個來源

建議新增 `scripts/sync-ui-sources.sh`。它只給模板維護者用，所以要加進 `copy-template.{sh,ps1}` 的排除清單。

1. **來源登記表** `.claude/ui/_sources.json`：每個來源記錄 `id`、`repo`、`ref`、`path_pattern`、`license`、`format`、`prefix`
2. **預設只做 dry-run**，輸出四種清單：
   - 上游有更新：比 `upstream_commit` 或 hash
   - 上游新增：只列出來，**不自動加入**，因為 CATALOG 的繁中一句話要人寫
   - 上游刪除：標 `upstream_status: removed`，不刪本地檔
   - `locally_modified: true`：只顯示 diff，不覆蓋
3. **格式不會自動轉換。** 兩種處理方式：
   - (a) 改 `ui-style-compliance` 1.2 節的 mixed 對照表，讓每個欄位同時認新舊標題，例如 `color` 認 `Color Palette & Roles` **或** `Colors`。改一處就好
   - (b) 匯入時把標題正規化成舊格式，這等於每份都有本地修改
   **建議 (a)。** 上游正在往 Google 規格收斂，(b) 每次同步都要重做一次
4. **匯入前檢查**：跑 `npx @google/design.md lint`（只對 google-alpha 格式的檔案），再跑 `check-counts.sh` 確認 CATALOG 兩處都同步了
5. **抓取方式**：`gh api` 或 `git sparse-checkout` 固定在某個 commit。下載內容放 scratch 目錄，不要在專案目錄裡解開

---

## 7. 查不到或沒查的

- getdesign.md 網站本身有沒有比 repo 更多的檔案或不同的授權：沒查。repo 內的 `design-md/<x>/README.md` 只寫「moved to getdesign.md」，但 DESIGN.md 本體還在 repo 裡，受 MIT 管
- Google 規格對**不認得的 frontmatter key** 怎麼處理：README 裡沒找到明文
- oh-my-design 521 份裡，有多少份的 Colors 節足夠完整：只抽了誠品一份
- jp 的 574 份品質：只抽了一保堂一份（399 行，有實測日期和方法）
- 各集合檔案中**品牌商標或字型的使用權**：每個 repo 都聲明不擁有品牌識別。風格庫是「參考風格」，不是「冒用品牌」，這個前提要寫進 CATALOG 的說明裡

---

## 8. 後續（每項都要使用者先同意）

| 事項 | 層 | 誰做 |
|---|---|---|
| 補 VoltAgent 的 MIT 聲明（`_licenses/`） | `.claude/ui/` | skill-curator |
| mixed 對照表加入新格式的別名 | `ui-style-compliance` 1.2 節 | skill-curator |
| 2.5／2.6 加入 frontend-design 的 5 種集群和 avoid-ai-design 的「有品味的預設」 | `ui-style-compliance` | skill-curator（改完要跑 compliance） |
| 評估 AI 痕跡掃描器做成 PostToolUse hook | hook | skill-curator（先照 writing-extensions 判層） |
| 建 `sync-ui-sources.sh` 和 `_sources.json` | `scripts/`、`.claude/ui/` | skill-curator |
| 實際匯入 jp、oh-my-design 的子集 | `.claude/ui/`、CATALOG | skill-curator（要使用者挑清單） |

---

## 來源

- VoltAgent/awesome-design-md：https://github.com/VoltAgent/awesome-design-md （LICENSE、README License 節、CONTRIBUTING）
- star-history（佐證熱度）：https://www.star-history.com/voltagent/awesome-design-md/
- Google DESIGN.md 規格：https://github.com/google-labs-code/design.md ；Google 部落格：https://blog.google/innovation-and-ai/models-and-research/google-labs/stitch-design-md/
- awesome-design-md-jp：https://github.com/kzhrknt/awesome-design-md-jp （README 的 Credits、Disclaimer、License；樣本 design-md/ippodo/DESIGN.md）
- oh-my-design：https://github.com/kwakseongjae/oh-my-design （README License 節；樣本 web/references/eslite/）
- official-design-md：https://github.com/VoltAgent/official-design-md
- fudge-design-md：https://github.com/scroobius-pip/fudge-design-md
- design-bites：https://github.com/educlopez/design-bites
- rohitg00/awesome-claude-design：https://github.com/rohitg00/awesome-claude-design
- VoltAgent/awesome-claude-design：https://github.com/VoltAgent/awesome-claude-design
- bergside/awesome-design-skills：https://github.com/bergside/awesome-design-skills
- anthropics/skills frontend-design：https://github.com/anthropics/skills/tree/main/skills/frontend-design
- claude-plugins-official：https://github.com/anthropics/claude-plugins-official
- impeccable：https://github.com/pbakaus/impeccable
- avoid-ai-design：https://github.com/funboy322/avoid-ai-design
- taste-skill：https://github.com/Leonxlnx/taste-skill
- emilkowalski/skills：https://github.com/emilkowalski/skills
- ui-ux-pro-max-skill：https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- tweakcn：https://github.com/jnsahaj/tweakcn
- daisyUI：https://github.com/saadeghi/daisyui
- Radix Themes：https://github.com/radix-ui/themes
- Open Props：https://github.com/argyleink/open-props
- GitHub topic design-md：https://github.com/topics/design-md
