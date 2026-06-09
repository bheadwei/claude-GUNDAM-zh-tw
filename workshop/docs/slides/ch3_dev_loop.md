# Chapter 3 — 開發循環

> 投影片文字稿 | 預估時長：20 min（核心章節）

---

## Slide 1: 章節目標

```
Chapter 3: 開發循環
━━━━━━━━━━━━━━━━━━

 「任務分級」— 三種 lane 對應不同強度：

 ┌──────────┬────────────────────────────────┐
 │ quick    │ 直接寫 → /verify               │
 │ standard │ /plan → /tdd → /verify         │
 │ critical │ /plan → /tdd(100%) → /review   │
 │          │   → /verify(pre-pr)            │
 └──────────┴────────────────────────────────┘

 我們會跑 3 輪：

 第 1 輪 後端串流 API (standard) → 8 min
 第 2 輪 前端聊天 UI (standard) → 8 min
 第 3 輪 加角色 + 修 Bug (quick) → 4 min
```

---

## Slide 2: 開發循環全貌（依任務模式分流）

```
   /task-next     取任務 + 選模式（quick/standard/critical）
         │
         ▼
   ┌─────┴──────────────┬──────────────────┐
   │ quick              │ standard         │ critical
   │                    │                  │
   ▼                    ▼                  ▼
 直接寫            /plan              /plan
   │           planner agent      planner agent
   │                │                  │
   │                ▼                  ▼
   │            /tdd                /tdd（100% 覆蓋）
   │       RED→GREEN→REFAC       RED→GREEN→REFAC
   │       （80% 覆蓋）              │
   │                │                  ▼
   │                │             /review-code
   │                │                  │
   ▼                ▼                  ▼
 /verify         /verify            /verify
 (auto:quick)    (auto:full)        (auto:pre-pr)
   │                │                  │
   └────────────────┴──────────────────┘
                    ▼
              git commit
                    │
                    └──→ /task-next 接力下一個
```

**講師口述：** `/task-next` 會多問一題「任務模式」。小修改走 quick lane，跳過 plan/tdd 直接寫；一般功能走 standard；API Key 保護這種安全相關走 critical。`/verify` 會依模式自動選對應 profile，不必手動帶參數。

---

## Slide 3: 第 1 輪開始 — /task-next

```
⚡ 操作：輸入 /task-next

AI 會從 WBS 選出最優先的任務，並詢問執行模式

┌──────────────────────────────────────┐
│  📋 下一個任務                        │
│                                      │
│  編號: 2.2                           │
│  名稱: /api/chat SSE 串流端點         │
│  優先級: 高                           │
│  依賴: 2.1 基礎架構                   │
│  預估: 1.5h                          │
│                                      │
│  → 開始工作？                        │
└──────────────────────────────────────┘

接著會問：選擇任務模式

  ▸ standard  (Recommended)  ← 預估 1.5h，預設此值
    quick
    critical
```

**講師口述：** `/task-next` 不只看依賴和優先級，還會依任務量級推薦預設模式。今天這個串流端點適合 standard，按預設往下走就好。

---

## Slide 4: /plan — AI 先想清楚再動手

```
⚡ 操作：輸入 /plan

planner agent (Opus) 會輸出：

┌──────────────────────────────────────────┐
│  📋 實作計畫                              │
│                                          │
│  步驟 1: Gemini client 初始化             │
│    - 讀 GEMINI_API_KEY（dotenv）          │
│    - 啟動時驗證 Key 存在                   │
│                                          │
│  步驟 2: 定義請求/回應模型                 │
│    - messages: [{role, content}]          │
│    - 多輪 context 累積                     │
│                                          │
│  步驟 3: POST /api/chat 串流端點          │
│    - generate_content_stream()            │
│    - StreamingResponse (SSE)              │
│    - X-Accel-Buffering: no                │
│                                          │
│  風險: API 計費 → 測試用 mock，不打真 API  │
│                                          │
│  → 確認計畫？                            │
└──────────────────────────────────────────┘
```

**講師口述：**（暫停讓學員讀計畫）

注意這裡。AI 不是直接開始寫程式碼，而是先用最聰明的 Opus 模型做規劃，連「測試別打真 API 以免計費」這種細節都想到了。你看完覺得合理，才讓它繼續。這就是「人類主導、AI 輔助」的核心精神。

---

## Slide 5: /tdd — 先寫測試，再寫實作

```
⚡ 操作：輸入 /tdd

tdd-guide agent (Sonnet) 會強制執行：

  ┌─────────┐     ┌─────────┐     ┌─────────┐
  │   RED   │ ──→ │  GREEN  │ ──→ │ IMPROVE │
  │ 寫測試  │     │ 寫實作  │     │  重構   │
  │ 要失敗  │     │ 要通過  │     │ 要乾淨  │
  └─────────┘     └─────────┘     └─────────┘

  1. 先產出 test_chat.py（pytest + httpx）
     → mock Gemini client，不打真 API
  2. 執行測試 → 全部 FAIL（紅色）  ← 這是對的！
  3. 寫最小實作讓測試通過
  4. 執行測試 → 全部 PASS（綠色）
  5. 重構，保持測試綠色
```

**講師口述：** 看到紅色不要緊張，這是 TDD 的第一步。我們**先定義期望**（測試），再讓 AI 寫出滿足期望的程式碼。注意測試是 mock 掉 Gemini 的——又快又不花錢。

---

## Slide 6: TDD 實際畫面（講師現場操作）

```
重點觀察：

1. 測試檔案先出現
   → tests/test_chat.py
   → 測 SSE 格式、多輪 context、錯誤處理

2. 執行 pytest → 紅色 ❌
   → 預期中的失敗

3. 實作檔案逐步出現
   → app/config.py   (讀 .env)
   → app/gemini.py   (串流封裝)
   → app/main.py     (/api/chat 端點)

4. 再執行 pytest → 綠色 ✅
   → 所有測試通過

5. AI 自動重構
   → 改善命名、抽取共用邏輯
```

**講師口述：**（現場操作，邊做邊解說）

---

## Slide 7: 看見串流 — /docs + curl -N

```
⚡ 操作：啟動 server

  uv run uvicorn app.main:app --reload

(1) 互動文檔：http://localhost:8000/docs
    → 寫完 API 就自動有 Swagger UI

(2) 看 token 逐塊吐出：

  curl -N -X POST localhost:8000/api/chat \
    -H "Content-Type: application/json" \
    -d '{"messages":[{"role":"user",
         "content":"用一句話介紹你自己"}]}'

  data: 我
  data: 是一個
  data: 由 Gemini
  data: 驅動的...
        ↑ 一塊一塊回來，不是一次吐完
```

**講師口述：** 用 `-N` 關掉 curl 的緩衝，你就能看到後端真的在串流——文字一塊一塊回來。這是後端的第一個 wow，等下到前端會更震撼。

---

## Slide 8: /review-code — AI 審查程式碼

```
⚡ 操作：輸入 /review-code

code-quality-specialist agent (Sonnet) 會檢查：

┌─────────────────────────────────────────┐
│  📋 程式碼審查報告                       │
│                                         │
│  ✅ PASS  命名規範                      │
│  ✅ PASS  函式長度 < 50 行              │
│  🔴 CRIT  API Key 不可硬編碼（用 .env） │
│  ⚠️  WARN  缺少輸入長度驗證             │
│  ✅ PASS  錯誤處理                      │
│  ✅ PASS  串流資源正確關閉              │
│                                         │
│  整體: 8/10                             │
│  必修: 把 Key 移到環境變數              │
└─────────────────────────────────────────┘
```

**講師口述：** AI 寫的程式碼，再讓另一個 AI 來審查。它依模板的安全規則抓到了一個 CRITICAL——API Key 外洩風險。我們先把它修掉再提交。這也呼應等下 critical lane 的安全強化。

---

## Slide 9: git commit — 規範化提交

```
⚡ 操作：提交程式碼

  git add workshop/src/geminichat
  git commit -m "feat: 實作 Gemini 串流對話 API

  - FastAPI StreamingResponse (SSE)
  - google-genai generate_content_stream
  - 多輪 context 累積
  - pytest mock Gemini 測試覆蓋
  - API Key 移到 .env"

提交格式：conventional commits
  feat:     新功能
  fix:      修 bug
  refactor: 重構
  test:     測試
  docs:     文件
```

**講師口述：** 第 1 輪完成！我們用了 /task-next → /plan → /tdd → /review-code → commit，一個完整循環，後端串流 API 上線。

---

## Slide 10: 第 2 輪 — 前端聊天 UI（加速）

```
同樣的流程，節奏加快：

  /ui-style      → 首次選設計風格
  /task-next     → 自動跳到前端任務
  /plan          → 快速帶過
  /tdd           → 單頁 UI + 串流顯示邏輯
  /review-code   → 確認 UI 規範

重點觀察：
┌─────────────────────────────────────────┐
│  UI 設計規則自動套用                      │
│                                         │
│  • 系統字體 (-apple-system, Inter)       │
│  • 圓角 12-16px、對話氣泡               │
│  • 輕微陰影、大量留白                    │
│  • 零硬編碼色票，全用 CSS 變數           │
│                                         │
│  → 來自 .claude/rules/ui-design.md      │
│  → 原生單頁，零建置，啟動超快            │
└─────────────────────────────────────────┘
```

**講師口述：** 前端是原生單頁，沒有 React 建置鏈，啟動超快。注意 AI 產出的介面自動套用了 Apple 風格的設計規範——這不是我臨時告訴它的，而是模板的 rules 自動生效。

---

## Slide 11: 全場高潮 — 瀏覽器即時對話

```
⚡ 操作：瀏覽器開聊天頁，輸入訊息

┌─────────────────────────────────────────┐
│  🤖 GeminiChat                          │
│  ─────────────────────────────────────  │
│  你：幫我用一句話解釋什麼是 SSE          │
│                                         │
│  AI：SSE 是一種▌                        │
│      ↑ 文字一個字一個字冒出來            │
│        （像 ChatGPT 在打字）            │
│                                         │
│  ─────────────────────────────────────  │
│  [ 輸入訊息...            ] [ 送出 ]    │
└─────────────────────────────────────────┘

再追問一句 → 驗證多輪 context 生效
```

**講師口述：**（等串流跑起來）看到了嗎？AI 一個字一個字回，跟 ChatGPT 一模一樣。這就是整堂課最有成就感的一刻——我們從零到這裡，只用了十幾分鐘。再追問一句，它記得上一輪的對話，多輪 context 也通了。

---

## Slide 12: 第 3 輪 — Quick Lane（換人設 + /build-fix）

```
⚡ 操作：/task-next → 選 quick 模式

  小修改（改 system prompt / 樣式）→ 走 quick lane
  跳過 /plan 和 /tdd 強制流程，直接動手

⚡ 操作：加一句系統提示讓 bot 變身

  system: "你是一個講話很跩的海盜船長"
  → 重啟後對話，bot 整個換人設（笑點）

⚡ 操作：刻意引入一個 bug

  例：把 import 打錯 → 啟動失敗 ❌

⚡ 操作：輸入 /build-fix

  build-error-resolver agent (Haiku) 會：
  1. 讀取錯誤訊息  2. 定位問題檔案
  3. 用最小差異修復  4. 驗證修復成功

⚡ 操作：/verify → 自動跑 quick profile（數秒）
```

**講師口述：** quick 模式是快車道。改個 system prompt 就讓機器人換人設，互動性超強。小修改不該被 80% 覆蓋率和完整 plan 拖累，`/verify` 也會自動降階成 quick profile，只跑 build + types，幾秒就好。

---

## Slide 13: Chapter 3 小結

```
✅ 你剛完成了 3 輪開發循環，體驗了三種 lane

  第 1 輪: 後端串流 API (standard) → 完整 plan/tdd/review
  第 2 輪: 前端聊天 UI (standard) → 同上 + UI 規範
  第 3 輪: 換人設+修Bug (quick)    → 直接寫 + quick verify

核心流程（依模式分流）：
  quick     → 直接寫 → /verify
  standard  → /plan → /tdd → /review-code → /verify
  critical  → 同 standard 但 100% 覆蓋 + 強制 review

你體驗到的 Agent 協作：
  planner (Opus)         → 規劃
  tdd-guide (Sonnet)     → 測試驅動
  code-quality (Sonnet)  → 審查
  build-resolver (Haiku) → 修錯

成果：一個會串流回覆、能多輪對話的 AI 聊天機器人

接下來：品質驗證 →
```
