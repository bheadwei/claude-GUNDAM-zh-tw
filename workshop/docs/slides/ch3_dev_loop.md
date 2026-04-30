# Chapter 3 — 開發循環

> 投影片文字稿 | 預估時長：25 min（核心章節）

---

## Slide 1: 章節目標

```
Chapter 3: 開發循環
━━━━━━━━━━━━━━━━━━

 v5.3 新增「任務分級」— 三種 lane 對應不同強度：

 ┌──────────┬────────────────────────────────┐
 │ quick    │ 直接寫 → /verify               │
 │ standard │ /plan → /tdd → /verify         │
 │ critical │ /plan → /tdd(100%) → /review   │
 │          │   → /verify(pre-pr)            │
 └──────────┴────────────────────────────────┘

 我們會跑 3 輪：

 第 1 輪 後端 API   (standard) → 10 min
 第 2 輪 前端 UI    (standard) → 10 min
 第 3 輪 修 Bug     (quick)    →  5 min
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

**講師口述：** v5.3 起 `/task-next` 會多問一題「任務模式」。小修改走 quick lane，跳過 plan/tdd 直接寫；一般功能走 standard；金流/認證等核心走 critical。`/verify` 會依模式自動選對應 profile，不必手動帶參數。

---

## Slide 3: 第 1 輪開始 — /task-next

```
⚡ 操作：輸入 /task-next

AI 會從 WBS 選出最優先的任務，並詢問執行模式

┌──────────────────────────────────────┐
│  📋 下一個任務                        │
│                                      │
│  編號: 2.1                           │
│  名稱: FastAPI + SQLite 基礎架構      │
│  優先級: 高                           │
│  依賴: 無                            │
│  預估: 1h                            │
│                                      │
│  → 開始工作？                        │
└──────────────────────────────────────┘

接著會問：選擇任務模式

  ▸ standard  (Recommended)  ← 預估 1h，預設此值
    quick
    critical
```

**講師口述：** `/task-next` 不只看依賴和優先級，還會依任務量級推薦預設模式。今天這個 1h 的後端任務適合 standard，按預設往下走就好。

---

## Slide 4: /plan — AI 先想清楚再動手

```
⚡ 操作：輸入 /plan

planner agent (Opus) 會輸出：

┌──────────────────────────────────────────┐
│  📋 實作計畫                              │
│                                          │
│  步驟 1: 建立專案結構                     │
│    - pyproject.toml (dependencies)        │
│    - app/main.py (FastAPI entry)          │
│    - app/models.py (SQLModel schemas)     │
│    - app/database.py (SQLite connection)  │
│                                          │
│  步驟 2: 定義 Todo 資料模型               │
│    - id, title, category, done, created   │
│                                          │
│  步驟 3: 實作 CRUD endpoints              │
│    - GET    /api/todos                    │
│    - POST   /api/todos                    │
│    - PUT    /api/todos/{id}               │
│    - DELETE /api/todos/{id}               │
│                                          │
│  風險: 無（標準 CRUD，低複雜度）            │
│                                          │
│  → 確認計畫？                            │
└──────────────────────────────────────────┘
```

**講師口述：**（暫停讓學員讀計畫）

注意這裡。AI 不是直接開始寫程式碼，而是先用最聰明的 Opus 模型做規劃。你看完覺得合理，才讓它繼續。這就是「人類主導、AI 輔助」的核心精神。

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

  1. 先產出 test_todos.py（pytest + httpx）
  2. 執行測試 → 全部 FAIL（紅色）  ← 這是對的！
  3. 寫最小實作讓測試通過
  4. 執行測試 → 全部 PASS（綠色）
  5. 重構，保持測試綠色
```

**講師口述：** 看到紅色不要緊張，這是 TDD 的第一步。我們**先定義期望**（測試），再讓 AI 寫出滿足期望的程式碼。這比「先寫 code 再補測試」可靠得多。

---

## Slide 6: TDD 實際畫面（講師現場操作）

```
重點觀察：

1. 測試檔案先出現
   → tests/test_todos.py
   → 測試 CRUD 四個操作 + 邊界情況

2. 執行 pytest → 紅色 ❌
   → 預期中的失敗

3. 實作檔案逐步出現
   → app/models.py
   → app/database.py
   → app/routes/todos.py

4. 再執行 pytest → 綠色 ✅
   → 所有測試通過

5. AI 自動重構
   → 改善命名、抽取共用邏輯
```

**講師口述：**（現場操作，邊做邊解說）

---

## Slide 7: FastAPI /docs — 免費的互動文檔

```
⚡ 操作：啟動 FastAPI server

  uvicorn app.main:app --reload

打開瀏覽器：http://localhost:8000/docs

┌─────────────────────────────────────────┐
│  Swagger UI                    FastAPI  │
│                                         │
│  GET    /api/todos     List all todos   │
│  POST   /api/todos     Create a todo    │
│  PUT    /api/todos/{id} Update a todo   │
│  DELETE /api/todos/{id} Delete a todo   │
│                                         │
│  [Try it out] ← 直接在瀏覽器測試 API    │
└─────────────────────────────────────────┘

寫完 API 就自動有互動文檔 — 不需要額外工具
```

**講師口述：** 這是選 FastAPI 的一個好處——API 寫完，文檔就自動有了。在瀏覽器裡直接點「Try it out」就能測試，不需要 Postman。

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
│  ✅ PASS  無硬編碼值                    │
│  ⚠️  WARN  缺少輸入驗證 (title 長度)    │
│  ✅ PASS  錯誤處理                      │
│  ✅ PASS  不可變模式                    │
│                                         │
│  整體: 8.5/10                           │
│  建議: 加上 title 的 max_length 驗證     │
└─────────────────────────────────────────┘
```

**講師口述：** AI 寫的程式碼，再讓另一個 AI 來審查。它會依照模板的 9 條規則打分。注意它抓到了一個 WARN——我們來修掉它。

---

## Slide 9: git commit — 規範化提交

```
⚡ 操作：提交程式碼

  git add .
  git commit -m "feat: 實作 Todo CRUD API

  - FastAPI + SQLModel + SQLite 基礎架構
  - GET/POST/PUT/DELETE endpoints
  - pytest + httpx 測試覆蓋
  - 輸入驗證 (title max_length)"

提交格式：conventional commits
  feat:     新功能
  fix:      修 bug
  refactor: 重構
  test:     測試
  docs:     文件
```

**講師口述：** 第 1 輪完成！我們用了 /task-next → /plan → /tdd → /review-code → commit，一個完整循環。

---

## Slide 10: 第 2 輪 — 前端 UI（加速）

```
同樣的流程，節奏加快：

  /task-next     → 自動跳到前端任務
  /plan          → 快速帶過
  /tdd           → React + Vitest 測試
  瀏覽器查看      → dev server 啟動
  /review-code   → 確認 UI 規範

重點觀察：
┌─────────────────────────────────────────┐
│  UI 設計規則自動套用                      │
│                                         │
│  • 系統字體 (-apple-system, Inter)       │
│  • 圓角 12-16px                         │
│  • 輕微陰影                             │
│  • 大量留白                             │
│  • Tailwind CSS                         │
│                                         │
│  → 來自 .claude/rules/ui-design.md      │
│  → 不需要手動指定，AI 自動遵守           │
└─────────────────────────────────────────┘
```

**講師口述：** 注意 AI 產出的前端自動套用了 Apple 風格的設計規範。這不是我臨時告訴它的，而是模板的 rules 自動生效。

---

## Slide 11: 第 3 輪 — Quick Lane + /build-fix

```
⚡ 操作：/task-next → 選 quick 模式

  小 bug / 文案 / 樣式調整 → 走 quick lane
  跳過 /plan 和 /tdd 強制流程，直接動手

⚡ 操作：刻意引入一個 bug

  例：把 models.py 的 category 型別改壞
  → 建置失敗 ❌

⚡ 操作：輸入 /build-fix

  build-error-resolver agent (Haiku) 會：
  1. 讀取錯誤訊息
  2. 定位問題檔案
  3. 用最小差異修復
  4. 驗證修復成功

⚡ 操作：/verify

  ┌──────────────────────────┐
  │  自動跑 quick profile     │
  │  Build:  ✅              │
  │  Types:  ✅              │
  │  → 數秒完成               │
  └──────────────────────────┘
```

**講師口述：** quick 模式是 v5.3 加的快車道。小修改不該被 80% 覆蓋率和完整 plan 拖累。`/verify` 也會自動降階成 quick profile，只跑 build + types，幾秒就好。

---

## Slide 12: Chapter 3 小結

```
✅ 你剛完成了 3 輪開發循環，體驗了三種 lane

  第 1 輪: 後端 API   (standard) → 完整 plan/tdd/review
  第 2 輪: 前端 UI    (standard) → 同上 + UI 規範
  第 3 輪: Bug 修復   (quick)    → 直接寫 + quick verify

核心流程（依模式分流）：
  quick     → 直接寫 → /verify
  standard  → /plan → /tdd → /review-code → /verify
  critical  → 同 standard 但 100% 覆蓋 + 強制 review

你體驗到的 Agent 協作：
  planner (Opus)         → 規劃
  tdd-guide (Sonnet)     → 測試驅動
  code-quality (Sonnet)  → 審查
  build-resolver (Haiku) → 修錯

接下來：品質驗證 →
```
