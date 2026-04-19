# TaskFlow 示範專案 — 實作 SOP

> 按順序執行，每步都標明要輸入的指令

---

## Step 0: 環境準備

```bash
# 確認工具版本
claude --version
uv --version        # 套件管理一律用 uv
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

## Step 3: 第 1 輪 — 後端 API

### 3a. 取任務
```
/task-next
```

### 3b. 規劃
```
/plan
```
→ 讀完計畫，確認合理後讓 AI 繼續

### 3c. TDD 開發
```
/tdd
```
→ 觀察 RED → GREEN → IMPROVE 流程

### 3d. 驗證 FastAPI /docs
```
啟動 server 確認 http://localhost:8000/docs 可用
```

### 3e. 程式碼審查
```
/review-code
```
→ 修復 CRITICAL / HIGH 問題

### 3f. 提交
```
git add workshop/src/
git commit -m "feat: 實作 Todo CRUD API (FastAPI + SQLModel)"
```

---

## Step 4: 第 2 輪 — 前端 UI

### 4a-4e: 重複 Step 3 流程
```
/task-next
/plan
/tdd
/review-code
git commit -m "feat: 實作 Todo 前端 UI (React + Tailwind)"
```

→ 啟動 dev server，在瀏覽器確認功能正常

---

## Step 5: 第 3 輪 — 整合 + Bug 修復

### 5a. 取任務 & 開發
```
/task-next
/plan
/tdd
```

### 5b. 刻意 Bug（教學用）
手動改壞一個檔案，然後：
```
/build-fix
```
→ 觀察最小差異修復

### 5c. 提交
```
git commit -m "feat: 前後端整合 + 分類篩選"
```

---

## Step 6: 品質驗證

```
/verify
/e2e
/check-quality
/time-log
```

→ 確認三道品質門全部通過

---

## Step 7: 收尾

```
/save-session
/task-status
```

→ 確認所有任務完成

---

## 快速指令對照

```
/task-init    初始化
/task-next    取任務
/task-status  看進度
/plan         規劃
/tdd          測試驅動開發
/build-fix    修建置錯誤
/review-code  程式碼審查
/verify       全面驗證
/e2e          端到端測試
/time-log     時間報表
/save-session 保存進度
```
