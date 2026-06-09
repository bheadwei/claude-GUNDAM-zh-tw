# WBS 開發計劃 — VibeCoding Workshop 教材製作

> **版本:** v2.0 | **更新:** 2026-06-08 | **狀態:** 草稿
> **v2.0 重點:** 示範專案改為 GeminiChat 串流聊天機器人

---

## 1. 專案總覽

| 項目 | 內容 |
| :--- | :--- |
| **專案名稱** | VibeCoding Workshop 教材 |
| **負責人** | bheadwei |
| **總工期** | 依節奏推進 |
| **目前進度** | 教材重寫中（demo 換成 GeminiChat） |

---

## 2. WBS 結構

```
1.0 教學規劃 ✅
├── 1.1 教學目標與受眾分析          ✅
├── 1.2 課程大綱設計                ✅
└── 1.3 示範專案選型（改 GeminiChat） ✅

2.0 示範專案開發（GeminiChat）
├── 2.1 專案初始化
│   ├── 2.1.1 建立專案目錄結構（workshop/src/geminichat）
│   ├── 2.1.2 用模板跑 /task-init
│   └── 2.1.3 產出 CLAUDE.md + WBS
├── 2.2 後端串流 API (Python)
│   ├── 2.2.1 FastAPI + google-genai + dotenv 基礎架構
│   ├── 2.2.2 POST /api/chat SSE 串流端點 (TDD, mock Gemini)
│   ├── 2.2.3 多輪對話歷史 (messages context)
│   └── 2.2.4 系統提示 / 角色人設設定
├── 2.3 前端聊天 UI（單頁）
│   ├── 2.3.1 index.html 骨架 + Apple 風格 CSS tokens
│   ├── 2.3.2 對話氣泡 + 訊息列表 (TDD)
│   ├── 2.3.3 串接 SSE → 逐字串流顯示
│   └── 2.3.4 互動細節（Enter 送出、loading、清除對話）
├── 2.4 整合與驗證
│   ├── 2.4.1 前後端整合測試
│   ├── 2.4.2 E2E 測試 (Playwright 自動對話)
│   └── 2.4.3 品質驗證 (/verify)
├── 2.5 quick lane 場景
│   ├── 2.5.1 加系統提示讓 bot 換人設（quick 示範）
│   └── 2.5.2 準備可重現的建置錯誤 + 錄製 /build-fix
└── 2.6 critical lane 場景（選做）
    ├── 2.6.1 API Key 環境變數保護 + .gitignore
    └── 2.6.2 簡易 rate limiting

3.0 教學素材製作
├── 3.1 投影片
│   ├── 3.1.1 Chapter 1 開場：模板介紹 + 架構圖 + 編排劇本
│   ├── 3.1.2 5 大機制對比圖
│   └── 3.1.3 Agent 協作 / handoff 流程圖
├── 3.2 指令速查卡
│   └── 3.2.1 25 個 slash command + 14 agent 單頁整理
├── 3.3 學員手冊
│   ├── 3.3.1 環境安裝指南（含 uv + Gemini API Key）
│   ├── 3.3.2 Step-by-step 跟做指引（SOP）
│   └── 3.3.3 常見問題 FAQ（串流被緩衝、Key 失效等）
└── 3.4 課後作業
    ├── 3.4.1 初級：翻譯小幫手 chatbot 需求書
    ├── 3.4.2 中級：對話持久化 + 多角色
    └── 3.4.3 進階：RAG 或 MCP tool 化

4.0 內訓準備
├── 4.1 講師準備
│   ├── 4.1.1 講稿 / 腳本撰寫（每章節關鍵台詞）
│   ├── 4.1.2 彩排 & 計時（確認 60 min 內完成）
│   └── 4.1.3 備用方案準備（離線截圖、mock 回覆、預建中間產物）
├── 4.2 學員環境
│   ├── 4.2.1 內部 Git repo 準備（模板 + 示範專案）
│   ├── 4.2.2 學員機器環境預檢腳本（uv / python / node）
│   └── 4.2.3 Gemini API Key / MCP 設定統一發放
└── 4.3 場地與設備
    ├── 4.3.1 投影 + 終端機字體大小調整
    └── 4.3.2 網路環境確認（Gemini API 連線、串流不被 proxy 緩衝）
```

---

## 3. 任務優先級

### Phase 1：核心內容（建議先做）

| 編號 | 任務 | 工時估 | 依賴 | 說明 |
| :--- | :--- | :--- | :--- | :--- |
| 2.1.1 | 建立 GeminiChat 專案目錄 | 0.5h | - | 在 workshop/src/ 下建立 |
| 2.1.2 | 用模板跑 /task-init | 0.5h | 2.1.1 | 錄製整個 Q&A 過程 |
| 2.2.1 | FastAPI + google-genai + dotenv 基礎架構 | 1h | 2.1.2 | /plan → /tdd, 含 pyproject.toml + .env |
| 2.2.2 | POST /api/chat SSE 串流端點 | 1.5h | 2.2.1 | 教學第 1 輪核心，展示 /docs + curl -N 串流 |
| 2.2.3 | 多輪對話歷史 | 0.5h | 2.2.2 | messages context 累積 |
| 2.3.1 | index.html + Apple 風格 CSS | 0.5h | 2.2.2 | 前端起手式（零建置） |
| 2.3.3 | 串接 SSE → 逐字串流顯示 | 1h | 2.3.1 | 教學第 2 輪核心 = 全場高潮 |

### Phase 2：品質與展示

| 編號 | 任務 | 工時估 | 依賴 |
| :--- | :--- | :--- | :--- |
| 2.2.4 | 系統提示 / 角色人設 | 0.5h | 2.2.3 |
| 2.4.1 | 前後端整合測試 | 1h | 2.3.3 |
| 2.4.2 | E2E 測試（Playwright 自動對話） | 1h | 2.4.1 |
| 2.5.2 | 準備刻意 Bug + /build-fix 錄製 | 0.5h | 2.4.2 |
| 3.2.1 | 指令速查卡 | 0.5h | - |
| 3.3.2 | Step-by-step 指引（SOP） | 1.5h | 2.4.2 |

### Phase 3：教學素材與內訓準備

| 編號 | 任務 | 工時估 | 依賴 |
| :--- | :--- | :--- | :--- |
| 3.1.1 | 開場投影片（Ch1 模板介紹 + 架構圖 + 編排劇本） | 1h | - |
| 3.1.2 | 5 大機制對比圖 | 0.5h | - |
| 3.1.3 | Agent 協作 / handoff 流程圖 | 0.5h | - |
| 3.3.1 | 環境安裝指南（uv + Gemini Key） | 1h | - |
| 3.4.* | 課後作業 | 1h | 2.4.2 |
| 4.1.* | 講稿撰寫 + 彩排 | 1.5h | 3.* |
| 4.2.* | 學員環境 + Gemini Key 準備 | 1h | - |

---

## 4. 里程碑

| 里程碑 | 交付物 | 依賴 |
| :--- | :--- | :--- |
| M1: 規劃完成 | 教學 PRD + WBS | ✅ 已完成 |
| M2: 教學素材就緒 | 投影片 + 速查卡 + 學員手冊 | Phase 3 |
| M3: 示範專案可運行 | GeminiChat 完成品 + 測試通過 + 真的能聊天 | Phase 1 |
| M4: 內訓就緒 | 彩排完成 + 學員環境預檢通過 | Phase 3 |

---

## 5. 教學指令流程速查

Workshop 中會用到的指令，按教學順序排列：

```
Chapter 2: 初始化
  /task-init          → 互動式 Q&A，產出 CLAUDE.md + WBS
  /task-status        → 查看任務總覽

Chapter 3: 開發循環（重複 2-3 次，依任務模式分流）
  /task-next          → 取得下一個任務 + 選 quick / standard / critical
  /plan               → planner agent 建立實作計畫（standard/critical）
  /ui-style           → 前端任務首次設定設計風格
  /tdd                → tdd-guide agent 測試驅動開發（依模式調強度）
  /build-fix          → build-error-resolver 修復建置錯誤
  /review-code        → code-quality-specialist 審查程式碼

Chapter 4: 品質驗證
  /verify             → 全面驗證（依模式自動選 profile）
  /e2e                → Playwright 端到端測試（自動對話）
  /agent-log          → 查看 subagent 軌跡與 handoff
  /check-quality      → 品質評估報告
  /time-log           → 開發時間報表

Chapter 5: 進階
  /suggest-mode       → 調整 AI 建議密度
  /save-session       → 保存會話狀態
  /hub-delegate       → 手動委派 Agent
  /learn              → 萃取可複用模式
```

---

## 6. 關鍵教學時刻（Aha Moments）

這些是最能打動觀眾的瞬間，務必確保展示效果：

| 時刻 | 章節 | 效果 |
| :--- | :--- | :--- |
| `/task-init` 自動問問題並產出文件 | Ch2 | 「AI 真的在理解我的專案」 |
| `/plan` 輸出串流架構的結構化計畫 | Ch3 | 「AI 不是直接寫 code，而是先想清楚」 |
| `/tdd` 測試從紅轉綠（mock Gemini） | Ch3 | 「先寫測試原來這麼自然」 |
| `curl -N` 看後端 token 逐塊吐出 | Ch3 | 「串流真的在動」 |
| **瀏覽器逐字串流顯示 AI 回覆** | Ch3 | **全場高潮 — 像 ChatGPT 在打字** |
| 改一行 system prompt 讓 bot 換人設 | Ch3 | 「原來這麼好玩」（互動笑點） |
| `/build-fix` 秒修錯誤 | Ch3 | 「出錯不可怕，有自動修復」 |
| `/e2e` Playwright 自動發訊息聊天 | Ch4 | 視覺衝擊強 |
| `/agent-log` 看剛剛哪些 agent 跑過 | Ch4 | 「模板會自己觀測自己」 |
| `/time-log` 展示自動追蹤的時間 | Ch4 | 「我們 20 分鐘做出一個 AI 產品」 |
