---
description: 從 WBS 取得下一個任務建議，分析優先級和依賴關係。
---

# 下個任務建議

## 功能

分析 WBS 任務清單，考慮依賴關係和優先級，建議最適合的下一個任務。

## 資料來源

**必須** 從 `.claude/taskmaster-data/wbs.md` 讀取 WBS 資料。

如果檔案不存在，提示使用者先執行 `/task-init` 初始化專案。

## 分析內容

1. **依賴檢查** -- 前置任務是否完成
2. **優先級排序** -- 關鍵路徑、阻塞因素
3. **複雜度評估** -- 預估時間和難度
4. **Agent 建議** -- 建議搭配的專業 Agent

## 輸出格式

先顯示任務資訊：

```
下個任務建議:

  任務: [任務名稱]
  描述: [簡述]
  優先級: [高/中/低]
  預估: [時間]
  依賴: [前置任務（已完成）]
  建議 Agent: [agent-name]
```

然後**必須使用 `AskUserQuestion`** 詢問使用者動作（遵守 `.claude/rules/interactive-qa.md`）：

- 「開始此任務」
- 「跳過，看下一個」
- 「查看詳細資訊」
- 「查看完整任務清單」

## 問答記錄

遵守 `.claude/rules/interactive-qa.md`：

- 流程結束後**一次性** `Write` 到 `.claude/qa-history/YYYY-MM-DD-HHMMSS-task-next.md`
- 記錄：建議任務、使用者選擇、時間戳
- 不要每題都寫（省 token）

## 使用方式

```
/task-next              # 取得建議
/task-next --detailed   # 含詳細分析
```

## 狀態同步

當使用者選擇開始任務時：
1. 讀取 `.claude/taskmaster-data/wbs.md`
2. 將選中的任務狀態更新為 `🔄 進行中`
3. 更新「最後更新」日期
4. 寫回檔案
5. **時間追蹤**：將任務編號寫入 `.claude/taskmaster-data/.current-task`（例如 `2.1`）

當任務完成（透過 `/verify` 或使用者確認）時：
1. 將任務狀態更新為 `✅ 完成`
2. 寫回檔案
3. **時間追蹤**：清除 `.claude/taskmaster-data/.current-task`
4. **自動推薦下一個任務**：用 `AskUserQuestion` 詢問使用者：
   - 「繼續下一個任務」(Recommended) — 自動執行 `/task-next` 流程
   - 「查看目前進度」 — 顯示 WBS 狀態摘要
   - 「結束，稍後再繼續」 — 停止，不再推薦

## 搭配使用

```
/task-next    → 取得任務（自動更新 wbs.md）
/plan         → 規劃實作步驟
/tdd          → 開始開發
/verify       → 完成驗證
/task-next    → 取得下一個（自動更新 wbs.md）
```
