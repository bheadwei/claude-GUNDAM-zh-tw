---
description: 網站雛形產生器：Q&A 引導收集需求 → 產資訊架構文檔 + 多頁骨架 + 設計 tokens。
---

# 網站雛形產生器

為前端網站從零建立**多頁雛形**，產出包含：IA 資訊架構文檔、前端架構文檔、多頁 stub、共用 layout、設計 tokens、路由設定。

**相關規範：**
- `.claude/rules/ui-design.md`（強制三階段檢查）
- `.claude/rules/interactive-qa.md`（一次一題 Q&A）

## 使用方式

```
/ui-site              # 互動式 Q&A
/ui-site --from-idea  # 從一段自然語言描述起步（第 1 題跳過）
```

## 執行前置檢查

### 1. 風格載入

```
Read .claude/taskmaster-data/ui-style.json
```

- 不存在 → 提示：「尚未選擇風格，建議先跑 `/ui-style`。仍要用 fallback 繼續嗎？」
  - 選 y：用 fallback
  - 選 n：引導去跑 `/ui-style`

### 2. 技術框架偵測

讀取 `CLAUDE.md` 與 `package.json`（若存在），自動判定主要語言/框架：

| 偵測線索 | 對應框架預設 |
|---|---|
| `next` in package.json | Next.js App Router |
| `nuxt` in package.json | Nuxt 3 |
| `@sveltejs/kit` | SvelteKit |
| `astro` | Astro |
| `vite` + `react` | Vite + React |
| Python 專案（FastAPI/Django） | Jinja2 + Tailwind + Alpine.js |
| 純前端 / 未偵測 | 純 HTML + Tailwind |

**自動選定後告知使用者**：「偵測到使用 [框架]，若要改請告知，否則按此繼續」。

## Q&A 流程（必須用 AskUserQuestion 一次一題）

### Q1. 網站類型

| 選項 | 說明 |
|---|---|
| SaaS 產品官網 | 吸引註冊、展示功能、定價 |
| 個人作品集 | 作品展示、個人品牌 |
| 企業官網 | 公司介紹、產品、聯絡 |
| 電商 | 商品展示、購物車、結帳 |
| 部落格/內容站 | 文章列表、作者、分類 |
| 文件站 | API doc、教學、搜尋 |
| 管理後台 | 登入、儀表板、列表、設定 |

### Q2. 核心目的

依 Q1 動態調整。例如 SaaS：

| 選項 | 說明 |
|---|---|
| 吸引註冊 | 以 CTA 為主軸 |
| 教育市場 | 以內容為主軸 |
| 展示產品 | 以功能截圖為主軸 |

### Q3. 必要頁面（multiSelect，依 Q1 預設推薦）

SaaS 預設推薦：`首頁 / 定價 / 功能 / 關於 / 部落格 / 聯絡 / 登入 / 註冊 / 儀表板 / 設定 / Privacy / Terms`

管理後台預設推薦：`登入 / 儀表板 / 使用者列表 / 個人資料 / 設定`

**使用者可增刪，Other 選項允許自填頁面名稱與路徑**。

### Q4. 認證需求

| 選項 | 說明 |
|---|---|
| 無 | 純公開頁面 |
| email + password | 基礎認證 |
| OAuth (Google/GitHub) | 第三方登入 |
| SSO / 企業 | 多租戶、SAML/SSO |

### Q5. 資料層

| 選項 | 說明 |
|---|---|
| 靜態 | 純文件，無資料 |
| REST API | 有後端，REST 介面 |
| GraphQL | 有後端，GraphQL |
| Supabase / Firebase | BaaS |
| 待定 | 先做前端，之後串 |

### Q6. i18n 多語言

| 選項 | 說明 |
|---|---|
| 不需要 | 單一語系 |
| zh-TW + en | 雙語 |
| 多語系 | 3+ 語系 |

### Q7. 部署目標

| 選項 | 說明 |
|---|---|
| Vercel | Next.js 首選 |
| Netlify | JAMstack |
| Cloudflare Pages | 邊緣計算 |
| 自架 (Docker) | 企業內部 |
| 不確定 | 先做再決定 |

### Q8. 確認設定

展示摘要：

```
網站類型：SaaS 產品官網
核心目的：吸引註冊
頁面（9）：/, /pricing, /features, /about, /blog, /contact, /login, /signup, /dashboard
框架：Next.js App Router
認證：OAuth (Google)
資料層：Supabase
i18n：zh-TW + en
部署：Vercel

確認產生？(y/N)
```

### Q&A 記錄

遵守 `.claude/rules/interactive-qa.md`：
- 所有問答**在記憶中收集**
- 全部結束後**一次性** Write 到 `.claude/qa-history/YYYY-MM-DD-HHMMSS-ui-site.md`

## 產出階段

### 1. 建立 IA 文檔

根據 VibeCoding 範本 17（`VibeCoding_Workflow_Templates/17_frontend_information_architecture_template.md`），填入 Q&A 答案，產出：

```
docs/17_frontend_information_architecture.md
```

內容包含：
- 核心價值主張（取自 Q2）
- 資訊架構原則
- 頁面清單 + 使用者旅程（取自 Q3）
- URL 規範
- 導航設計（依類型決定 Header/Sidebar/Bottom Nav）
- 每頁 IA 細節（目的、CTA、區塊、資料、狀態）

### 2. 建立前端架構文檔

根據 VibeCoding 範本 12（`VibeCoding_Workflow_Templates/12_frontend_architecture_specification.md`），填入技術決策：

```
docs/12_frontend_architecture.md
```

內容包含：
- 技術選型（框架、狀態管理、UI 庫、樣式方案）
- 目錄結構規範
- 路由策略
- 認證流程
- 資料流
- 部署策略

### 3. 委派 ui-builder agent 產骨架

呼叫 `ui-builder` agent 產出：

**a. 專案基礎檔**
- `package.json` / `requirements.txt`（若 Python）
- `tsconfig.json` / `vite.config.ts` / `next.config.js`
- `tailwind.config.ts`（載入 DESIGN.md 的色票為 tokens）
- `.env.example`
- `.gitignore`
- `README.md`（專案說明）

**b. 設計 tokens**（關鍵！）

從 `.claude/ui/<codename>/DESIGN.md` 抽取：
- 色票 → `src/styles/tokens.css` 或 `tailwind.config.ts` 的 `theme.extend.colors`
- 字體 → `theme.extend.fontFamily` + `fontSize`
- 間距 → `theme.extend.spacing`
- 圓角 → `theme.extend.borderRadius`
- 陰影 → `theme.extend.boxShadow`
- 深色模式 → `@media (prefers-color-scheme: dark)` 或 Tailwind `dark:` 變數

**c. 共用 Layout**
- `src/components/layout/Header.tsx`（含導航，依 Q3 頁面清單）
- `src/components/layout/Footer.tsx`
- `src/components/layout/Nav.tsx`（若 Q1 為管理後台，則 Sidebar）

**d. 原子元件**
- `src/components/ui/Button.tsx`
- `src/components/ui/Input.tsx`
- `src/components/ui/Card.tsx`

**e. 每頁 Stub**

依 Q3 清單，每頁建立**可跑但內容為 placeholder** 的檔案：

```tsx
// src/app/pricing/page.tsx
import { Header, Footer } from '@/components/layout'

export default function PricingPage() {
  return (
    <>
      <Header />
      <main className="container mx-auto py-16">
        <h1 className="text-heading-xl">定價</h1>
        <p className="text-body mt-4">
          {/* 待 /ui-page /pricing 深化：方案比較表、FAQ */}
        </p>
      </main>
      <Footer />
    </>
  )
}
```

每頁都能跑起來看見基本佈局，但內容待 `/ui-page` 深化。

**f. 路由設定**（若非檔案路由框架）

### 4. 展示結構樹

```
my-site/
├── docs/
│   ├── 17_frontend_information_architecture.md   ✅ 已產
│   └── 12_frontend_architecture.md                ✅ 已產
├── src/
│   ├── app/                                       ✅ 9 頁 stub
│   ├── components/
│   │   ├── layout/                                ✅ Header/Footer
│   │   └── ui/                                    ✅ Button/Input/Card
│   └── styles/
│       └── tokens.css                             ✅ 由 DESIGN.md 產
├── tailwind.config.ts                             ✅ tokens 注入
├── package.json                                   ✅
└── README.md                                      ✅
```

### 5. 最終提示

```
網站雛形已建立！

下一步：
  cd <專案目錄>
  npm install           # 或 pnpm / yarn
  npm run dev           # 啟動後可見基本 layout

深化個別頁面：
  /ui-page /pricing     # 深化定價頁
  /ui-page /dashboard   # 深化儀表板
  /ui-page /            # 深化首頁

每頁都有 IA 文檔作為契約，/ui-page 會讀 IA 生成符合風格的頁面。
```

## 邊界情況

| 情境 | 處理 |
|---|---|
| 既有專案執行 `/ui-site` | 偵測 `docs/17_*.md` 已存在 → 警告「會覆寫既有 IA，確認？」 |
| 既有 `src/app/` 有檔案 | 警告 + 詢問是否備份現有 → `src/app.bak/` |
| Q3 頁面選了 0 個 | 至少要 `/`，強制加入 |
| ui-style.json 不存在 | 用 fallback，但每頁 stub 加註解「建議 /ui-style 後重新產出」 |

## 搭配其他指令

```
/ui-style          選擇風格（寫入 ui-style.json）
/ui-site           網站雛形（本指令）→ 產 IA + 骨架
/ui-page <path>    深化單頁（讀 IA，填充該頁）
/tdd               為頁面寫測試（若有 E2E 需求）
```
