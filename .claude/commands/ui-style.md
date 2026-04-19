---
description: 選擇或切換專案的 UI 設計風格，支援單一風格與混搭模式，寫入 .claude/taskmaster-data/ui-style.json
---

# UI 風格選擇

## 功能

以互動問答方式選定前端 UI 設計風格，寫入設定檔供所有前端任務引用。

支援：
- **單一風格** — 整體套用一個品牌設計系統
- **混搭模式** — 配色、字體、元件、間距分別從不同風格抽取
- **直接指定** — 輸入品牌 codename（熟手）
- **瀏覽目錄** — 先看 `.claude/ui/CATALOG.md` 再回來選

---

## 執行流程

### 互動原則（CRITICAL）

**必須遵守 `.claude/rules/interactive-qa.md`**：

- 使用 `AskUserQuestion` 工具，一次一題逐題詢問
- **在記憶中收集所有問答**，全部結束後**一次性**用 `Write` 寫入 `.claude/qa-history/YYYY-MM-DD-HHMMSS-ui-style.md`
- 依使用者答案動態調整後續問題

### 步驟 1：入口模式

用 `AskUserQuestion` 問：

**題目：** 要怎麼挑選 UI 風格？

| 選項 | 說明 |
|------|------|
| **單一風格 (Recommended)** | 選一個品牌設計系統全面套用 |
| **混搭** | 配色、字體、元件分別從不同風格抽取 |
| **瀏覽目錄** | 先看 CATALOG.md 介紹，再回來選 |
| **直接指定** | 輸入品牌 codename（如 apple、linear.app） |

### 步驟 2：依模式分流

#### 路徑 A：單一風格

**2A-1：分類角度**

| 選項 | 說明 |
|------|------|
| **按設計哲學 (Recommended)** | 依視覺感受分類（極簡/資料密集/終端機/科技感…） |
| **按品牌類型** | 依產業分類（AI/開發工具/金融/消費者…） |

**2A-2a（哲學路徑）：選哲學**

從 8 種哲學選 1：
- 極簡主義 (Minimalism) — apple, linear.app, stripe, vercel, cal, notion, superhuman...
- 資料密集 (Data-dense) — clickhouse, posthog, sentry, supabase, airtable...
- 終端機美學 (Terminal) — warp, cursor, claude, raycast, ollama...
- 科技未來感 (Futuristic) — x.ai, runwayml, nvidia, spacex, elevenlabs...
- 溫暖擬物 (Warm) — clay, lovable, intercom, pinterest
- 奢華精品 (Luxurious) — ferrari, lamborghini, bmw, tesla, apple
- 企業專業 (Corporate) — ibm, hashicorp, coinbase, kraken, revolut
- 毛玻璃流體 (Glassmorphism) — framer, figma

**2A-3a：選該哲學下的具體品牌**（3-5 個選項，最推薦放第一個）

**2A-2b（品牌類型路徑）：選產業**

從 8 種產業選 1：
- AI / LLM
- 開發工具 / IDE
- 資料 / 後端 / DevOps
- 金融 / 支付 / 加密
- 生產力 SaaS
- 消費者 App
- 汽車 / 精品 / 硬體
- 行銷 / 分析

**2A-3b：選該產業下的具體品牌**（3-5 個選項）

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
- **從另一風格抽取** — 若選此，下一題問「從哪個風格？」（列熱門 5 個 + 直接輸入）

#### 路徑 C：瀏覽目錄

1. Read `.claude/ui/CATALOG.md`
2. 以條列方式展示分類摘要給使用者
3. 回到步驟 1 重新問入口模式

#### 路徑 D：直接指定

1. `AskUserQuestion` 問：「輸入品牌 codename」（直接輸入框，提示範例）
2. 驗證 `.claude/ui/<codename>/DESIGN.md` 存在
3. 不存在 → 提示可用清單 → 回步驟 1

### 步驟 3：確認

用 `AskUserQuestion` 顯示最終設定摘要：

```
模式：單一風格 / 混搭
主風格：{primary}（{中文摘要}）
[若混搭]
  配色：{color or 沿用}
  字體：{typography or 沿用}
  元件：{components or 沿用}
  間距：{layout or 沿用}

確認？
```

選項：**確認** / **重新選擇**（回步驟 1）

### 步驟 4：寫入設定檔

建立 `.claude/taskmaster-data/ui-style.json`（若不存在目錄先建立）：

```json
{
  "version": "1.0",
  "mode": "single",
  "primary": "apple",
  "overrides": {
    "color": null,
    "typography": null,
    "components": null,
    "layout": null
  },
  "chosen_at": "2026-04-17",
  "notes": ""
}
```

混搭模式範例：

```json
{
  "version": "1.0",
  "mode": "mixed",
  "primary": "linear.app",
  "overrides": {
    "color": "stripe",
    "typography": null,
    "components": "apple",
    "layout": null
  },
  "chosen_at": "2026-04-17",
  "notes": "Linear 節奏 + Stripe 漸層配色 + Apple 元件"
}
```

### 步驟 5：寫入 QA 歷史

將所有問答收集後，一次性 `Write` 到：
`.claude/qa-history/YYYY-MM-DD-HHMMSS-ui-style.md`

格式：
```markdown
# UI 風格選擇 QA 歷史

**時間：** YYYY-MM-DD HH:MM:SS
**最終結果：** {mode} / {primary} / {overrides}

---

## Q1: 入口模式
- 選項：單一風格 / 混搭 / 瀏覽 / 直接指定
- 答案：{user_choice}

## Q2: ...
...

---

## 最終結論
寫入 `.claude/taskmaster-data/ui-style.json`
```

### 步驟 6：完成訊息

```
UI 風格已設定

模式：{mode}
主風格：{primary}
覆蓋：{overrides or 無}

設定檔：.claude/taskmaster-data/ui-style.json
完整規範：.claude/ui/{primary}/DESIGN.md

前端任務將自動套用此風格。如需調整：
  /ui-style       重新選擇
```

---

## 使用方式

```
/ui-style                 互動式選擇（推薦）
/ui-style apple           直接指定單一風格
/ui-style apple+stripe    混搭（主：apple、覆蓋：自動提示）
```

## 特殊情境

- **已存在設定檔** — 先顯示目前設定，問「覆蓋 / 取消」
- **未指定前端需求** — 仍可執行，供未來前端任務參考
- **codename 大小寫** — 一律轉小寫（對應資料夾名稱）
- **混搭但全部沿用主風格** — 自動降級為 `mode: single`
