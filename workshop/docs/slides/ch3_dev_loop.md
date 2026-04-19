# Chapter 3 — 開發循環

> 投影片文字稿 | 預估時長：25 min（核心章節）

---

## Slide 1: 章節目標

```
Chapter 3: 開發循環
━━━━━━━━━━━━━━━━━━

 我們會跑 3 輪完整循環：

 第 1 輪（詳細）後端 API     → 10 min
 第 2 輪（加速）前端 UI      → 10 min
 第 3 輪（快速）修 Bug       →  5 min

 每輪都是：
 /task-next → /plan → /tdd → /review-code → commit
```

---

## Slide 2: 開發循環全貌

```
         ┌──────────────────────────────────────┐
         │                                      │
         ▼                                      │
   /task-next     取得下一個任務                 │
         │                                      │
         ▼                                      │
   /plan          planner agent 建立計畫         │
         │        （人類審核 → 確認）             │
         ▼                                      │
   /tdd           tdd-guide agent               │
         │        RED → GREEN → IMPROVE          │
         ▼                                      │
   /review-code   code-quality agent 審查        │
         │        （修復 CRITICAL / HIGH）        │
         ▼                                      │
   git commit     conventional commits           │
         │                                      │
         └──────── 還有任務？──── Yes ───────────┘
                        │
                       No
                        ▼
                   /verify 全面驗證
```

**講師口述：** 這個循環就是今天的核心。每個步驟都有對應的 Agent 在背後工作。注意 `/plan` 之後有一個人類審核的環節——AI 不會自己決定怎麼做，你要看過計畫才繼續。

---

## Slide 3: 第 1 輪開始 — /task-next

```
⚡ 操作：輸入 /task-next

AI 會從 WBS 中選出最優先的任務
通常第一個是後端基礎架構

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
```

**講師口述：** `/task-next` 不是隨便挑任務，它會看依賴關係和優先級。

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

## Slide 11: 第 3 輪 — 刻意犯錯 + /build-fix

```
⚡ 操作：刻意引入一個 bug

  例：把 models.py 的 category 型別改壞

  → 建置失敗 ❌
  → 測試失敗 ❌

⚡ 操作：輸入 /build-fix

  build-error-resolver agent (Haiku) 會：

  1. 讀取錯誤訊息
  2. 定位問題檔案
  3. 用最小差異修復
  4. 驗證修復成功

  ┌──────────────────────────┐
  │  修復完成                 │
  │  變更: 1 file, 1 line    │
  │  測試: ✅ all passed      │
  └──────────────────────────┘

  → 用最輕量的 Haiku 模型，快速修復，省成本
```

**講師口述：** 開發一定會出錯，重點是出錯後怎麼處理。`/build-fix` 用最便宜的模型做最小修復。不是重寫，是精準修補。

---

## Slide 12: Chapter 3 小結

```
✅ 你剛完成了 3 輪開發循環

  第 1 輪: 後端 API（FastAPI + pytest）
  第 2 輪: 前端 UI（React + Vitest）
  第 3 輪: Bug 修復（/build-fix）

核心流程：
  /task-next → /plan → /tdd → /review-code → commit

你體驗到的 Agent 協作：
  planner (Opus)       → 規劃
  tdd-guide (Sonnet)   → 測試驅動
  code-quality (Sonnet) → 審查
  build-resolver (Haiku) → 修錯

接下來：品質驗證 →
```
