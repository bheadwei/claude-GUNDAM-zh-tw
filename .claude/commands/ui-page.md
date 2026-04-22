---
description: 單頁深化：讀 IA 契約 + Q&A 補細節 → 生成符合風格的完整頁面。缺 IA 時引導三種模式。
---

# 單頁深化產生器

為既有頁面（`/ui-site` 建立的 stub，或既有專案的頁面）**填充內容**，產出符合風格的完整程式碼。

**相關規範：**
- `.claude/rules/ui-design.md`（強制三階段檢查）
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

#### 1.1 風格載入（參 `rules/ui-design.md` 階段 1）

```
Read .claude/taskmaster-data/ui-style.json
Read .claude/ui/<codename>/DESIGN.md
```

#### 1.2 技術框架偵測

讀 `package.json` / `CLAUDE.md` 判定 React / Vue / Svelte / Vanilla。

#### 1.3 IA 檢查（三種模式分流）

檢查 `docs/17_frontend_information_architecture.md` 是否存在：

**模式 A：IA 已存在**
- 讀取該頁區段（例如「## 定價頁（/pricing）」）
- 取得：頁面目的、CTA、區塊、資料、狀態
- **跳過模式選擇 Q&A**，直接進入第 2 步

**模式 B：IA 不存在** — 用 AskUserQuestion 問：

| 選項 | 說明 |
|---|---|
| **[Recommended] 先跑 /ui-site** | 建立完整網站 IA（30 min Q&A，後續加頁面容易） |
| **最小 IA 模式** | 只為這一頁建立 IA snippet（5 min，可漸進累積） |
| **Adhoc 模式** | 跳過 IA，純頁面 Q&A，不留檔（快速原型） |

依選擇進入對應流程（見第 2 步）。

**模式 C：`--adhoc` flag** → 強制進入 Adhoc，跳過 IA 檢查。

### 2. Q&A 分流

#### 2.1 模式 A（IA 已有） — 補充實作細節

從 IA 取得該頁基本資訊後，只問實作細節：

1. **狀態管理**（若頁面有互動）— useState / Zustand / Redux / 不需要
2. **表單驗證**（若有表單）— React Hook Form + Zod / Formik / 原生
3. **動畫程度** — 無 / 微（過渡）/ 中（進場）/ 強（互動）
4. **特殊效果** — 無 / 毛玻璃 / 視差 / 3D（若 DESIGN.md 支援）

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

### 4. 委派 ui-builder agent

確認後呼叫 `ui-builder` agent，傳入：
- 頁面路徑
- IA 資訊（或 Q&A 結果）
- 風格確認（DESIGN.md 關鍵規範）
- 響應式需求

agent 會嚴格遵循 `.claude/rules/ui-design.md` 的三階段檢查。

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
- 動畫程度：[答案]
```

#### 5.2 Plan 持久化（若複雜）

若此頁預估 ≥ 1h 且跨 ≥ 2 檔案，詢問使用者是否要用 `/plan --adhoc` 建立實作計畫（寫入 `plans/adhoc-YYYY-MM-DD-ui-<page>.md`），以便後續 `/tdd` 接續。

### 6. Q&A 記錄

遵守 `.claude/rules/interactive-qa.md`，流程結束後**一次性** Write 到：
```
.claude/qa-history/YYYY-MM-DD-HHMMSS-ui-page-<path>.md
```

## 邊界情況

| 情境 | 處理 |
|---|---|
| 該頁 stub 不存在（既有專案無此檔） | 詢問「建立新檔案嗎？」→ 建立 |
| 該頁已有完整內容（不是 stub） | 警告「已有內容，行為為 ⦅覆寫 / 補充 / 取消⦆」 |
| 模式 B.2 Adhoc 後使用者想補 IA | 提示「執行 `/ui-page <path>` 無 --adhoc 會走模式 B.1」 |
| IA 存在但該頁區段缺 | 回退到模式 B.1，新增該頁 snippet 到既有 IA |
| DESIGN.md 缺對應區塊規範（例如沒定義 FAQ accordion） | 用 fallback 規範 + 告知使用者「DESIGN.md 未規範 FAQ，用預設模式」|

## 風格合規硬檢查（由 ui-builder 執行）

每次產出後回覆最後必附：

```
🔍 風格合規自檢：
- [x] 色票：全用 tokens
- [x] 字體：遵循 Typography Hierarchy
- [x] 間距：4/8px 倍數
- [x] 圓角：符合 DESIGN.md
- [x] 深色模式：已處理
- [x] 響應式：mobile/tablet/desktop
- [x] 語意化 HTML
```

缺項需說明。

## 搭配其他指令

```
/ui-style          選擇風格
/ui-site           產網站雛形（建議先跑）
/ui-page <path>    深化單頁（本指令）
/tdd               為頁面補 E2E 測試
/verify            完成後驗收
```
