# TaskFlow 示範專案 — 實作 SOP

> 按順序執行，每步都標明要輸入的指令
> v5.3 起加入「任務分級」概念，三種 lane 對應不同強度

---

## Step 0: 環境準備

```bash
# 確認工具版本
claude --version
uv --version        # Python 套件管理一律用 uv
python --version    # 需要 3.11+
node --version      # 需要 18+

# 進入專案根目錄（確保 hook 不會報錯）
cd D:/模板/claude_v2026
```

**Python 套件管理規則：**
- 一律用 `uv` 管理，不用 pip / poetry
- 必須使用虛擬環境（`.venv`）
- 初始化：`uv init` → `uv venv`
- 安裝套件：`uv add fastapi sqlmodel aiosqlite`
- 執行程式：`uv run uvicorn app.main:app --reload`

**Node 套件管理：** `/pm-choose` 由使用者決定 bun / pnpm / npm

---

## Step 1: 啟動 Claude Code

```bash
claude
```

---

## Step 2: 專案初始化

```
/task-init TaskFlow
```

**Q&A 回答參考：**

| 問題 | 回答 |
|:---|:---|
| 專案描述 | 極簡待辦清單應用，用於 Workshop 示範 |
| 技術棧 | Python FastAPI + React + SQLite |
| 開發模式 | MVP |
| 功能範圍 | Todo CRUD（新增/完成/刪除）+ 分類篩選（工作/個人/學習） |
| 專案目錄 | workshop/src/taskflow |

**產出檢查：**
- [ ] CLAUDE.md 已產出
- [ ] wbs.md 已產出
- [ ] CLAUDE_TEMPLATE.md 已刪除

```
/task-status
```

---

## 任務分級概念（v5.3）

`/task-next` 會在選定任務後問「任務模式」：

- **quick** — 直接寫，跳過 plan/tdd（< 30min 小修改）
- **standard** — 走完整 plan → tdd → verify（一般功能）
- **critical** — standard + 100% 覆蓋 + review-code（金流/認證）

下面 Step 3-5 對應三種 lane 的示範。

---

## Step 3: 第 1 輪 — 後端 API（Standard Lane）

### 3a. 取任務 + 選模式
```
/task-next
```
→ 選 **standard** 模式

### 3b. 規劃
```
/plan
```
→ 讀完計畫，確認合理後讓 AI 繼續

### 3c. TDD 開發
```
/tdd
```
→ 觀察 RED → GREEN → REFACTOR（80% 覆蓋率自動檢查）

### 3d. 驗證 FastAPI /docs
```
啟動 server 確認 http://localhost:8000/docs 可用
```

### 3e. 程式碼審查
```
/review-code
```
→ 修復 CRITICAL / HIGH 問題

### 3f. 驗證 + 提交
```
/verify
```
→ 自動跑 full profile（build + types + lint + tests + coverage）

```
git add workshop/src/
git commit -m "feat: 實作 Todo CRUD API (FastAPI + SQLModel)"
```

---

## Step 4: 第 2 輪 — 前端 UI（Standard Lane）

### 4a. UI 風格設定（首次）
```
/ui-style
/pm-choose          # 選 bun / pnpm / npm
```

### 4b. 取任務 → 完整流程
```
/task-next          # 選 standard
/plan
/tdd
/review-code
/verify
git commit -m "feat: 實作 Todo 前端 UI (React + Tailwind)"
```

→ 啟動 dev server，在瀏覽器確認功能正常

---

## Step 5: 第 3 輪 — Bug 修復（Quick Lane 示範）

### 5a. 取任務 + 選 quick 模式
```
/task-next
```
→ 任務是「修小 bug」，選 **quick** 模式

### 5b. 直接寫（跳過 plan / tdd）
手動改檔案修 bug，或請 AI 直接改。

### 5c. 刻意 Bug（教學用）
手動改壞一個檔案，然後：
```
/build-fix
```
→ 觀察最小差異修復

### 5d. 快速驗證
```
/verify
```
→ 自動跑 **quick** profile（僅 build + types，數秒完成）

### 5e. 提交
```
git commit -m "fix: 修正分類篩選 bug"
```

---

## Step 6: 第 4 輪 — 認證強化（Critical Lane 示範，選做）

> 若 WBS 有 auth/payment 相關任務才示範

### 6a. 取任務
```
/task-next
```
→ 選 **critical** 模式（任務名含 auth → 預設標 Recommended）

### 6b. 完整嚴格流程
```
/plan               # 必須先有計畫
/tdd                # 100% 覆蓋強制
/review-code        # 階段完成必跑
/verify             # 自動跑 pre-pr profile（含安全掃描）
```

### 6c. 提交
```
git commit -m "feat: 加入 JWT 驗證中介層"
```

---

## Step 7: 全專案品質驗證

```
/check-quality      # 全專案品質掃描 + Agent 路由建議
/e2e                # Playwright 端到端測試
/time-log           # 開發時間報表
```

→ 確認三道品質門全部通過

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
/build-fix    修建置錯誤
/review-code  程式碼審查
/verify       全面驗證（依模式自動選 profile）

/e2e          端到端測試
/check-quality 全專案品質
/time-log     時間報表
/save-session 保存進度
```

---

## 模式速判表（給講師現場參考）

| 任務描述 | 推薦模式 |
|---|---|
| 修改文案、調 padding、換顏色 | quick |
| 修小 bug、改 config、加環境變數 | quick |
| 新增 CRUD endpoint、新元件、重構函式 | standard |
| 整合第三方 API、表單驗證、檔案上傳 | standard |
| JWT/OAuth、金流串接、權限控管 | critical |
| DB migration、改認證 schema | critical |
