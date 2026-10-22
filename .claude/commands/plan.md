---
description: 重述需求、評估風險、建立逐步實作計畫。等待使用者確認後持久化至 plans/。
---

# 規劃指令

此指令呼叫 **planner** agent 建立全面的實作計畫，並在確認後寫入 `.claude/taskmaster-data/plans/`。

**相關規範：** 計畫檔格式、命名、狀態同步請依 `plan-format` skill。

## 使用方式

```
/plan              # 規劃當前 WBS 進行中任務（自動偵測 .current-task）
/plan 2.1          # 規劃指定 WBS 任務
/plan --adhoc      # 無 WBS 對應的臨時計畫
```

## 執行流程

### 1. 來源偵測

- **`/plan <id>`**：讀取 `.claude/taskmaster-data/wbs.md`，找出任務 `<id>` 作為規劃目標
- **`/plan`（無參數）**：讀 `.claude/taskmaster-data/.current-task` 取得當前進行中任務，若為空則提示使用者執行 `/task-next` 或指定 `--adhoc`
- **`/plan --adhoc`**：不綁 WBS，直接進入需求問答

### 2. 需求對焦

planner agent：

1. **重述需求** — 以清晰用語重述（含 WBS 任務原始描述 + 依賴項已完成狀態）
2. **識別風險** — 浮現潛在問題和阻礙
3. **拆解階段** — 4 個階段：介面/核心/整合/打磨
4. **評估複雜度** — 高/中/低，給出預估時數
5. **呈現草案** — 等使用者明確確認

### 2.5 確認流程（planner 派兩次）

planner 沒有 `AskUserQuestion`，所以確認由主模型做，**planner 會被派兩次**：

1. **第一次派**：prompt 寫明「只回草案，不寫檔」。planner 回 `NEEDS_CONTEXT`，
   附草案全文與待確認事項（含你建議的預設答案）
2. **主模型用 `AskUserQuestion` 確認**（一次一題，遵守 `interactive-qa.md`）
3. **第二次派**：prompt 開頭明寫以下其一，並附上使用者的修改意見
   - 「已確認，寫入」——照草案（含修改）建立新 plan 檔
   - 「以現有 plan 為基線修改」——用 `Edit` 改既有 plan 檔，不整份覆寫

沒有第二次派工的那句話，planner 不會寫檔——這是「確認前不污染 plans/」的機制本身。

### 3. 持久化（使用者確認後）

確認後 planner 自動：

1. **寫入 plan 檔**：`.claude/taskmaster-data/plans/<id>-<slug>.md` 或 `adhoc-YYYY-MM-DD-<slug>.md`
   - **必填 `files:` frontmatter**：依階段拆解列出本任務會新增/修改的檔案（或 glob）。這是 `/task-next` 判斷任務可否平行開發的依據（範圍重疊＝不可平行）；不確定就多列、偏保守。格式見 `plan-format` skill。
2. **更新 INDEX.md**：在 `plans/INDEX.md` 新增一行
3. **更新 WBS**：若綁 WBS 任務，在該任務「連結」欄加入 `[計畫](plans/<id>-<slug>.md)`
   （規則見 `plan-format` skill 的「與 WBS 的雙向同步」）
4. **顯示摘要**：列出計畫路徑與下一步建議

**`/plan` 只寫計畫，不開工**：不改 WBS 的任務狀態、不寫 `.current-task`。
「先規劃、之後再做」的任務會維持 `⏳ 待處理`。標進行中是 `/tdd` 真正開始實作時的事
（見 `commands/tdd.md`「偵測當前任務與計畫」）。

### 4. 下一步提示

```
計畫已儲存：.claude/taskmaster-data/plans/2.1-auth-middleware.md

下一步：
  /tdd          以 TDD 方式執行計畫（會自動載入此 plan）
  /plan 2.1     若需修改計畫，重新規劃
```

## 修改既有計畫

如需重新規劃：

- 直接再執行 `/plan <id>`，planner 會讀取現有 plan 作為基線
- 使用者回覆：
  - 「修改階段 2：...」
  - 「新增階段：...」
  - 「重寫」— 整份覆蓋（會警告原 plan 將被覆蓋）

## 與其他指令的搭配

```
/task-next        取得 WBS 下一個任務（自動更新 .current-task）
/plan             規劃當前任務（寫入 plans/）
/tdd              以 TDD 執行計畫（讀 plans/ 更新階段狀態）
/verify           所有階段完成後驗證（標 WBS 任務為 ✅）
```

## 何時不該用 /plan

門檻見 `plan-format` skill 的「何時不該用 /plan」（唯一來源，勿在此重述）。

## 重要提醒

**關鍵**：planner agent **不會**在使用者明確確認前寫入檔案（不會污染 plans/）——
機制見上方「2.5 確認流程」。
