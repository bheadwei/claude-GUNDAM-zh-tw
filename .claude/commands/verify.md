---
description: 對當前程式碼庫狀態執行全面驗證檢查。
---

# 驗證指令

## 說明

依以下確切順序執行驗證：

### 1. 建置檢查
- 執行專案的建置指令
- 如失敗則報告錯誤並停止

### 2. 型別檢查
- 執行 TypeScript/型別檢查器
- 報告所有錯誤含檔案:行號

### 3. Lint 檢查
- 執行 linter
- 報告警告和錯誤

### 4. 測試套件
- 執行所有測試
- 報告通過/失敗數量
- 報告覆蓋率百分比

### 5. Console.log 稽核
- 搜尋原始碼中的 console.log
- 報告位置

### 6. Git 狀態
- 顯示未提交的變更
- 顯示自上次 commit 以來修改的檔案

## 輸出

產出簡潔的驗證報告：

```
VERIFICATION: [PASS/FAIL]

Build:    [OK/FAIL]
Types:    [OK/X errors]
Lint:     [OK/X issues]
Tests:    [X/Y passed, Z% coverage]
Secrets:  [OK/X found]
Logs:     [OK/X console.logs]

Ready for PR: [YES/NO]
```

如有任何關鍵問題，列出並附修復建議。

## Plan 驗收標準比對

若當前 `.current-task` 對應的 plan 存在（`.claude/taskmaster-data/plans/<id>-*.md`），在步驟 1-6 驗證後：

1. 讀取 plan 檔的「驗收標準（整體）」checklist
2. 逐項比對前面驗證結果：
   - 「測試覆蓋率 ≥ 80%」→ 由步驟 4 結果填入
   - 「所有階段狀態為 ✅」→ 讀 plan frontmatter `status`
   - 「`/review-code` 無 CRITICAL/HIGH 問題」→ 若未執行，提示使用者執行
   - 其他自訂條件 → 呈現給使用者確認
3. **Plan 檔內的 checklist 同步勾選**（已通過的標 `[x]`）
4. 若全部 checklist 通過 → 視為整體驗收 PASS

**相關規範：** `.claude/rules/plan-persistence.md`

## 任務完成銜接

若 `.claude/taskmaster-data/.current-task` 存在（表示有進行中的任務），且驗證結果為 PASS：

1. 將 WBS 該任務狀態更新為 `✅ 完成`
2. 清除 `.current-task`
3. **Plan 歸檔**（若存在對應 plan 檔）：
   - 將 plan frontmatter 標 `status: "✅ 完成"`、`archived: "YYYY-MM-DD"`
   - 移動至 `.claude/taskmaster-data/plans/archive/`（目錄不存在則建立）
   - 更新 `plans/INDEX.md`：該行的狀態改為 `✅ 完成（已歸檔）`，路徑改為 `archive/<filename>`
4. 用 `AskUserQuestion` 詢問下一步（遵守 `.claude/rules/interactive-qa.md`）：
   - 「繼續下一個任務」(Recommended) — 自動執行 `/task-next` 流程
   - 「查看目前進度」 — 顯示 WBS 狀態摘要
   - 「結束，稍後再繼續」 — 停止

這樣使用者不用手動再跑 `/task-next`，形成 **自動任務接力**，且計畫自動歸檔不佔主目錄。

## 參數

$ARGUMENTS 可以是：
- `quick` - 僅建置 + 型別
- `full` - 所有檢查（預設）
- `pre-commit` - 與 commit 相關的檢查
- `pre-pr` - 完整檢查加安全掃描

## 自動 Profile 選擇（依任務模式）

若使用者**未指定** `$ARGUMENTS`，讀取 `.claude/taskmaster-data/.current-task-mode`：

| 任務模式 | 自動 profile |
|---|---|
| `quick` | `quick` |
| `standard`（或檔案不存在） | `full` |
| `critical` | `pre-pr` |

使用者明確帶入 `$ARGUMENTS` 時優先採用使用者選擇。

**相關規範：** `.claude/rules/task-mode.md`

## 任務完成後清除模式

第「任務完成銜接」階段標記 WBS 為 ✅ 後，**同步清除** `.current-task-mode`（連同 `.current-task`），避免下個任務沿用舊模式。
