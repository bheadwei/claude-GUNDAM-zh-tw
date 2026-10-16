---
description: 單頁深化：讀 IA 契約 + Q&A 補細節 → 一段一段生成符合風格的頁面，每段看截圖驗收、不滿意就退件重做。缺 IA 時引導三種模式。
---
# 單頁深化產生器

為既有頁面（`/ui-site` 建立的 stub，或既有專案的頁面）**填充內容**，產出符合風格的完整程式碼。

**相關規範：**

- `ui-style-compliance` skill（強制三階段檢查）
- `.claude/rules/interactive-qa.md`（一次一題 Q&A）

## 使用方式

```
/ui-page /pricing              # 深化定價頁
/ui-page /dashboard            # 深化儀表板
/ui-page /blog/[slug]          # 動態路由頁
/ui-page /                     # 首頁（或省略為 /ui-page）
/ui-page /pricing --adhoc      # 強制 Adhoc 模式（跳過 IA 檢查）
```

## 執行流程

### 1. 前置檢查

#### 1.1 風格載入（參 `ui-style-compliance` skill 階段 1）

```
Read .claude/taskmaster-data/ui-style.json
Read .claude/ui/<codename>/DESIGN.md
```

記下專案的動畫等級（`motion`）和網站類型（`site_type`），2.1 第 3 題要用。

**舊版設定檔**（沒有 `motion`，或有 `overrides.animation`）→ 照 `.claude/commands/ui-style.md`
的「舊版設定檔」一節處理（唯一來源）：沒有 `motion` 當作 L1、`overrides.animation` 忽略，
**各提示一次**（這次 `/ui-page` 流程裡講過就不再講）。

#### 1.2 技術框架偵測

讀 `package.json` / `CLAUDE.md` 判定 React / Vue / Svelte / Vanilla。

#### 1.3 IA 檢查（三種模式分流）

檢查 `docs/17_frontend_information_architecture.md` 是否存在：

**模式 A：IA 已存在**

- 讀取該頁區段（例如「## 定價頁（/pricing）」）
- 取得：頁面目的、CTA、區塊、資料、狀態
- **跳過模式選擇 Q&A**，直接進入第 2 步

**模式 B：IA 不存在** — 用 AskUserQuestion 問：

| 選項                                  | 說明                                           |
| ------------------------------------- | ---------------------------------------------- |
| **[Recommended] 先跑 /ui-site** | 建立完整網站 IA（30 min Q&A，後續加頁面容易）  |
| **最小 IA 模式**                | 只為這一頁建立 IA snippet（5 min，可漸進累積） |
| **Adhoc 模式**                  | 跳過 IA，純頁面 Q&A，不留檔（快速原型）        |

依選擇進入對應流程（見第 2 步）。

**模式 C：`--adhoc` flag** → 強制進入 Adhoc，跳過 IA 檢查。

### 2. Q&A 分流

#### 2.1 模式 A（IA 已有） — 補充實作細節

從 IA 取得該頁基本資訊後，只問實作細節：

1. **狀態管理**（若頁面有互動）— useState / Zustand / Redux / 不需要
2. **表單驗證**（若有表單）— React Hook Form + Zod / Formik / 原生
3. **動畫等級** — 題目：「這一頁的動畫要照專案設定嗎？」
   - **沿用專案設定（L?）(Recommended)** — `?` 填 1.1 讀到的等級，描述寫那一級的「感覺」
   - **這一頁另外調** — 再問一題 L1／L2／L3。選項文字、推薦與限制照
     `.claude/skills/ui-style-compliance/motion.md` 第 1 節（唯一來源；網站類型寫「不提供 L3」的，這裡一樣不給 L3）。
     給使用者看的文字不寫任何函式庫名
4. **特殊效果** — 無 / 毛玻璃 / 視差 / 3D（若 DESIGN.md 支援）。
   選項依第 3 題的等級過濾：視差要 L2 以上、3D 只有 L3 才列（等級允許什麼見 `motion.md` 第 2 節）

#### 2.2 模式 B.1（最小 IA） — 短 IA + 實作

短 IA 問題（6 題）：

1. **頁面目的** — 一句話描述
2. **目標受眾** — 訪客 / 會員 / 管理員
3. **主要 CTA** — 這頁希望使用者做什麼動作
4. **必要區塊**（multiSelect，依路徑推薦）：
   - `/pricing` 推薦：Header / Pricing Cards / FAQ / CTA / Footer
   - `/dashboard` 推薦：Sidebar / Stats / Chart / Recent Activity / Quick Actions
   - `/` 推薦：Header / Hero / Features / Social Proof / Pricing / CTA / Footer
5. **資料來源** — 靜態 / API (GET) / 使用者輸入表單
6. **響應式需求** — 同等（預設）/ 手機優先 / 桌面優先

然後接 2.1 的實作細節問題（4 題）。

#### 2.3 模式 B.2（Adhoc） — 只問實作，不留檔

類似模式 B.1 但不寫入任何 IA doc。6+4=10 題精簡走完。

### 3. 骨架確認

展示即將產出的 component tree：

```
/pricing
└── PricingPage
    ├── Header (shared)
    ├── <main>
    │   ├── Hero
    │   ├── PricingCards (3 方案)
    │   ├── FeatureComparison
    │   ├── FAQ (accordion)
    │   └── CTASection
    └── Footer (shared)

新增檔案：
  src/app/pricing/page.tsx         (主頁面)
  src/components/sections/
    ├── PricingCards.tsx
    ├── FeatureComparison.tsx
    ├── FAQ.tsx
    └── CTASection.tsx

確認生成？(y/N)
```

### 4. 委派 ui-builder agent（一段一段做）

確認後**一次只派一段**，先做 hero（首屏）。一次生成整頁，每一段都只分到平均值的注意力
（`ui-style-compliance/anti-ai.md`「該主動做的事」⑤）。每次呼叫 `ui-builder` 都傳入：

- 頁面路徑、**這一次要做的是哪一段**（以及已經做好、不要動的段落）
- IA 資訊（或 Q&A 結果）
- 風格確認（DESIGN.md 關鍵規範）
- **這一頁的動畫等級**（2.1 第 3 題的結果）
- 響應式需求

agent 會嚴格遵循 `ui-style-compliance` skill 的三階段檢查。

### 4.5 分段驗收迴圈

每一段回來後：

1. **給使用者看 390（手機）和 1440（桌機）兩張截圖**——路徑在 `ui-builder` 的報告裡。
   報告寫「截圖未驗證」時要照實講，並請使用者自己開頁面看（給他啟動指令和網址），不要假裝看過
2. `AskUserQuestion`，題目：「這一段可以嗎？」
   - **可以，做下一段 (Recommended)**
   - **要修改**——在問題描述寫明「直接輸入哪裡不對就好，例如『手機版標題太擠』『感覺很 AI』」

hero 通過後再多問一次：「剩下的段落要一段一段看，還是一次做完再一起看？」
（**一段一段看 (Recommended)**／一次做完再看）。使用者選一次做完，就把剩下的段落一次派出去，回來後整頁走同一個驗收題。

**使用者要修改時：先改寫成退件格式，再交給 `ui-builder`。** 不要把「太擠」原封不動轉過去——
它不知道是哪一段、哪個寬度、擠在哪裡。

```
退件：<段落名>
- 哪個狀態：<寬度（390／1440）、哪一段、什麼互動下（滑過、展開、捲到哪裡）>
- 看到什麼：<具體現象，例如「標題和按鈕之間大約只有 8px，三張卡片貼著螢幕邊緣」>
- 像什麼：<使用者的原話＋你理解的感覺，例如「使用者說『太擠』，像塞滿的傳單」>
- 建議改法：<查下表；只改 token 或這一段，不動已通過的段落>
```

看截圖還是判斷不出「哪個狀態」時，先回問使用者一題，不要猜。

**白話回饋對照表**

| 使用者說 | 先檢查 | 建議改法 |
|---|---|---|
| 太擠 | 區塊之間、元素和螢幕邊緣的距離 | 區塊間距加一級 spacing token；手機版左右留白至少一級 |
| 太空、太散 | 同一組內容是不是被拆得太開 | 組內間距減一級，組與組之間維持，讓層次出來 |
| 太素、沒記憶點 | 標題和內文的字級、字重差多少 | 加大標題字重和字級對比（`anti-ai.md`「該主動做的事」①） |
| 很 AI、很罐頭 | `anti-ai.md`「產出後」清單 | 逐項對照，把命中的改掉，回報改了哪幾項 |
| 太花、太吵 | 動畫、顏色、裝飾同時出現幾種 | 動畫降一級（只改 motion tokens，見 `motion.md` 第 4 節）；強調色只留一個任務 |
| 看不清楚 | 文字和背景的對比度 | 檢查對比度是否 ≥ 4.5:1，不夠就換成 DESIGN.md 裡更深／更淺的那一階 |
| 不像我們、不像品牌 | DESIGN.md 和 `ui-style.json` 的 `notes` | 回頭對照選定方向的初衷；差太多就建議重跑 `/ui-style` |
| 手機版怪怪的 | 只看 390 截圖逐段比 | 請使用者指出是哪一段，再用退件格式 |

**同一段退件 3 次還不行** → 停下來問使用者：「要繼續改這一段，還是回頭用 `/ui-style` 換方向？」
連續被退通常是方向不對，不是細節沒調好。

### 5. 後處理

#### 5.1 回寫 IA（模式 A 補充 / 模式 B.1 建立 snippet）

- **模式 A**：若此次 Q&A 補充了 IA 未涵蓋的資訊（例如確定了使用哪套表單庫），append 到 IA doc 該頁區段
- **模式 B.1**：建立或更新 `docs/17_frontend_information_architecture.md`，append 這一頁的 IA snippet
- **模式 B.2**（Adhoc）：不寫任何 doc

IA snippet 格式（最小模式）：

```markdown
## [頁面名]（[路徑]）

**狀態：** ✅ 已建立  |  **最後更新：** YYYY-MM-DD

### 頁面資訊
- **目的：** [Q1 答案]
- **目標受眾：** [Q2 答案]
- **主要 CTA：** [Q3 答案]

### 區塊組成
[Q4 multiSelect 結果]

### 資料來源
[Q5 答案]

### 實作筆記
- 狀態管理：[實作問題答案]
- 表單：[若有]
- 動畫等級：[沿用專案 L? ／ 本頁另外調為 L?]
```

「動畫等級」這一行是之後再改這一頁時的依據（`motion.md` 開頭：頁面另外調過的以這一行為準）。
這一次的產出不靠它——第 4 步交給 `ui-builder` 的 prompt 本來就帶著等級。

#### 5.2 Plan 持久化（若複雜）

若此頁預估 ≥ 1h 且跨 ≥ 2 檔案，詢問使用者是否要用 `/plan --adhoc` 建立實作計畫（寫入 `plans/adhoc-YYYY-MM-DD-ui-<page>.md`），以便後續 `/tdd` 接續。

### 6. Q&A 記錄

遵守 `.claude/rules/interactive-qa.md`，流程結束後**一次性** Write 到：

```
.claude/qa-history/YYYY-MM-DD-HHMMSS-ui-page-<path>.md
```

## 邊界情況

| 情境                                                 | 處理                                                              |
| ---------------------------------------------------- | ----------------------------------------------------------------- |
| 該頁 stub 不存在（既有專案無此檔）                   | 詢問「建立新檔案嗎？」→ 建立                                     |
| 該頁已有完整內容（不是 stub）                        | 警告「已有內容，行為為 ⦅覆寫 / 補充 / 取消⦆」                   |
| 模式 B.2 Adhoc 後使用者想補 IA                       | 提示「執行 `/ui-page <path>` 無 --adhoc 會走模式 B.1」          |
| IA 存在但該頁區段缺                                  | 回退到模式 B.1，新增該頁 snippet 到既有 IA                        |
| DESIGN.md 缺對應區塊規範（例如沒定義 FAQ accordion） | 用 fallback 規範 + 告知使用者「DESIGN.md 未規範 FAQ，用預設模式」 |

## 風格合規硬檢查（由 ui-builder 執行）

每次產出後回覆最後必附風格合規自檢。

自檢清單見 `.claude/skills/ui-style-compliance/SKILL.md` 階段 3（唯一來源，勿在此重述）。
缺項需說明。

## 搭配其他指令

```
/ui-style          選擇風格
/ui-site           產網站雛形（建議先跑）
/ui-page <path>    深化單頁（本指令）
/tdd               為頁面補 E2E 測試
/verify            完成後驗收
```
