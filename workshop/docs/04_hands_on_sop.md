# GeminiChat 示範專案 — 實作 SOP

> 按順序執行，每步都標明要輸入的指令
> 示範專案：串流式 AI 聊天機器人（FastAPI + Gemini + 單頁前端）
> 任務分級三種 lane 對應不同強度；核心循環壓到 ~20 分鐘

---

## Step 0: 環境準備

```bash
# 確認工具版本
claude --version
uv --version        # Python 套件管理一律用 uv
python --version    # 需要 3.11+
node --version      # E2E 用 Playwright 才需要

# 進入專案根目錄（確保 hook 不會報錯）
cd D:/模板/claude_v2026
```

**Gemini API Key 準備：**
```bash
# 在示範專案目錄建立 .env（稍後 /task-init 會建立目錄）
# GEMINI_API_KEY=your_key_here
# GEMINI_MODEL=gemini-2.0-flash
```
- Key 取得：Google AI Studio（aistudio.google.com）
- **務必把 `.env` 加入 `.gitignore`** — 這是 Ch3 安全示範的伏筆

**Python 套件管理規則：**
- 一律用 `uv` 管理，不用 pip / poetry
- 必須使用虛擬環境（`.venv`）
- 初始化：`uv init` → `uv venv`
- 安裝套件：`uv add fastapi uvicorn google-genai python-dotenv sse-starlette`
- 執行程式：`uv run uvicorn app.main:app --reload`

**Node 套件管理：** 本專案前端是原生單頁，無需 Node；只有跑 `/e2e`（Playwright）時才需要。

---

## Step 1: 啟動 Claude Code

```bash
claude
```

---

## Step 2: 專案初始化

```
/task-init GeminiChat
```

**Q&A 回答參考：**

| 問題 | 回答 |
|:---|:---|
| 專案描述 | 串流式 AI 聊天機器人，用於 Workshop 示範 |
| 技術棧 | Python FastAPI + Gemini API + 原生 HTML/JS 單頁前端 |
| 開發模式 | mvp（求快可選 demo） |
| 功能範圍 | 串流對話（SSE）+ 多輪歷史 + 系統提示角色設定 |
| 專案目錄 | workshop/src/geminichat |

**產出檢查：**
- [ ] CLAUDE.md 已產出
- [ ] wbs.md 已產出
- [ ] CLAUDE_TEMPLATE.md 已刪除

```
/task-status
```

---

## 任務分級概念

`/task-next` 會在選定任務後問「任務模式」：

- **quick** — 直接寫，跳過 plan/tdd（< 30min 小修改，如改 system prompt）
- **standard** — 走完整 plan → tdd → verify（一般功能）
- **critical** — standard + 100% 覆蓋 + review-code（API Key 保護等）

> 若沒先跑 `/task-next` 就直接請 AI 實作，主模型會**入口自動分級**並宣告判定（你可一句話否決）。

下面 Step 3-6 對應不同 lane 的示範。

---

## Step 3: 第 1 輪 — 後端串流 API（Standard Lane）

### 3a. 取任務 + 選模式
```
/task-next
```
→ 選 **standard** 模式（後端串流端點，約 1.5h 量級）

### 3b. 規劃
```
/plan
```
→ planner agent 會規劃：FastAPI app 結構、`google-genai` client、`POST /api/chat` 串流端點、對話歷史模型、mock 測試策略。讀完確認合理後讓 AI 繼續。

### 3c. TDD 開發
```
/tdd
```
→ 觀察 RED → GREEN → REFACTOR
- 測試用 **mock Gemini**（不打真 API，避免計費 + 加速）
- 驗證：串流端點回傳 SSE 格式、多輪 context 正確傳遞
- 80% 覆蓋率自動檢查

### 3d. 驗證串流（兩個 wow）
```bash
# 啟動 server
uv run uvicorn app.main:app --reload

# 1) 互動文檔
#    瀏覽器開 http://localhost:8000/docs

# 2) 看串流逐塊吐出（-N 關閉 curl 緩衝）
curl -N -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"用一句話介紹你自己"}]}'
```
→ 觀眾會看到 token 一塊一塊回來，不是一次吐完。

### 3e. 程式碼審查
```
/review-code
```
→ 重點看它是否抓到「API Key 不可硬編碼」「使用者輸入需驗證」等問題，修復 CRITICAL / HIGH。

### 3f. 驗證 + 提交
```
/verify
```
→ 自動跑 full profile（build + types + lint + tests + coverage）

```
git add workshop/src/geminichat
git commit -m "feat: 實作 Gemini 串流對話 API (FastAPI + SSE)"
```

---

## Step 4: 第 2 輪 — 前端聊天 UI（Standard Lane）

### 4a. UI 風格設定（首次）
```
/ui-style
```
→ 選一個風格（或用 Apple 風格 fallback）。本專案前端是原生單頁，**不需要** `/pm-choose`。

### 4b. 取任務 → 完整流程
```
/task-next          # 選 standard
/plan
/tdd
/review-code
/verify
git commit -m "feat: 實作單頁聊天 UI + SSE 逐字串流顯示"
```

### 4c. 全場高潮 — 瀏覽器即時對話
```bash
# 後端 server 仍在跑；用瀏覽器開前端單頁
# 例：直接開 workshop/src/geminichat/static/index.html
#     或由 FastAPI 掛 StaticFiles 後開 http://localhost:8000/
```
→ 輸入訊息，看 AI **一個字一個字** 串流回覆（像 ChatGPT 打字）。再追問一句驗證多輪 context 生效。

---

## Step 5: 第 3 輪 — Quick Lane（加角色 + 修 Bug）

### 5a. 取任務 + 選 quick 模式
```
/task-next
```
→ 任務是「加系統提示讓 bot 換人設」，選 **quick** 模式

### 5b. 直接寫（跳過 plan / tdd）
請 AI 直接在 chat 請求加上 `system` 指令，例如讓 bot 用「海盜語氣」或「專業客服」回答。重啟 server 後對話一輪驗證人設生效。

### 5c. 刻意 Bug（教學用）
手動改壞一個檔案（例：import 打錯、型別註記錯誤），然後：
```
/build-fix
```
→ 觀察 build-error-resolver (Haiku) 最小差異修復

### 5d. 快速驗證
```
/verify
```
→ 自動跑 **quick** profile（僅 build + types，數秒完成）

### 5e. 提交
```
git commit -m "feat: 加入系統提示角色設定 + 修正啟動錯誤"
```

---

## Step 6: 第 4 輪 — API Key 安全強化（Critical Lane 示範，選做）

> 觸及 secret / 安全 → critical lane

### 6a. 取任務
```
/task-next
```
→ 選 **critical** 模式（任務含「API Key / 安全」→ 預設標 Recommended）

### 6b. 完整嚴格流程
```
/plan               # 必須先有計畫
/tdd                # 100% 覆蓋強制
/review-code        # 階段完成必跑
/verify             # 自動跑 pre-pr profile（含安全掃描）
```
→ 重點：確認 `.env` 在 `.gitignore`、啟動時驗證 Key 存在、加簡易 rate limit、錯誤訊息不洩漏 Key。

### 6c. 提交
```
git commit -m "feat: API Key 環境變數保護 + rate limiting"
```

---

## Step 7: 全專案品質驗證與可觀測性

```
/check-quality      # 全專案品質掃描 + Agent 路由建議
/e2e                # Playwright 端到端測試（自動發訊息、驗證 AI 回覆）
/agent-log          # 回顧 subagent 軌跡、報告與 handoff 交接
/time-log           # 開發時間報表
```

→ 用 `/time-log` 收尾：「我們花了約 20 分鐘做出一個能真聊天的 AI 產品」

---

## Step 8: 收尾

```
/save-session       # 保存 session 快照
/task-status        # 確認所有任務 ✅
```

---

## 快速指令對照

```
/task-init    初始化（一次）
/task-next    取任務 + 選模式（quick / standard / critical）
/task-status  看進度

/plan         standard / critical 規劃
/tdd          測試驅動（依模式自動切換強度）
/ui-style     前端風格設定
/build-fix    修建置錯誤
/review-code  程式碼審查
/verify       全面驗證（依模式自動選 profile）

/e2e          端到端測試（自動對話）
/check-quality 全專案品質
/agent-log    subagent 軌跡與交接
/time-log     時間報表
/suggest-mode 調整建議密度
/save-session 保存進度
```

---

## 模式速判表（給講師現場參考）

| 任務描述 | 推薦模式 |
|---|---|
| 改 system prompt、調 UI 文案/樣式、換顏色 | quick |
| 修小 bug、改 config、加環境變數 | quick |
| 新增串流端點、新前端元件、重構函式 | standard |
| 多輪對話歷史、輸入驗證、整合第三方 API | standard |
| API Key 保護、rate limiting、認證 | critical |
| 改安全 schema、秘密管理 | critical |

---

## 講師備援（Demo 失敗時）

| 狀況 | 對策 |
|---|---|
| Gemini Key 失效 / 額度不足 | 測試全用 mock，不依賴真 API；改放預錄串流影片 |
| 串流被 proxy 緩衝、瀏覽器不逐字顯示 | 後端回應加 `X-Accel-Buffering: no`；改用 `curl -N` 展示 |
| `/task-init` 產出不如預期 | 直接替換預備好的標準答案 CLAUDE.md |
| server 啟動失敗 | 先 `/build-fix`，仍不行則切預錄畫面 |
