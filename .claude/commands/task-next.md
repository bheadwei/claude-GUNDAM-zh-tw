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

先顯示任務資訊（含 plan 狀態檢查）：

```
下個任務建議:

  任務: [任務名稱]
  描述: [簡述]
  優先級: [高/中/低]
  預估: [時間]
  依賴: [前置任務（已完成）]
  建議 Agent: [agent-name]
  計畫狀態: [依下方規則填入]
```

### 計畫狀態檢查規則

**必須**檢查 `.claude/taskmaster-data/plans/<id>-*.md` 是否存在：

- **找到計畫檔** → 讀取其 frontmatter，顯示：
  ```
  計畫狀態: 🔄 進行中（階段 2/4） — plans/2.1-auth-middleware.md
  建議下一步: /tdd  （自動接續階段 2）
  ```
- **無計畫檔** 且任務預估 ≥ 1h 或 跨 ≥ 2 檔案 → 顯示：
  ```
  計畫狀態: ⚪ 尚無計畫
  建議下一步: /plan [任務ID]  （建立實作藍圖）
  ```
- **無計畫檔** 但任務簡單（< 1h 且單檔案） → 顯示：
  ```
  計畫狀態: ⚪ 尚無計畫（任務簡單，可直接進入）
  建議下一步: /tdd  （ad-hoc TDD）
  ```

然後**必須使用 `AskUserQuestion`** 詢問使用者動作（遵守 `.claude/rules/interactive-qa.md`）：

- 「開始此任務」— 會依 plan 狀態導向對應下一步
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
/task-next        取得任務（自動更新 wbs.md + .current-task + 檢查 plan 狀態）
/plan <id>        規劃實作步驟（寫入 plans/<id>-<slug>.md，WBS 加連結）
/tdd              自動載入 plan 並按階段 TDD 推進，完成階段同步 plan 狀態
/verify           驗證覆蓋率與驗收 → 自動標 WBS 任務為 ✅
/task-next        取得下一個
```

**相關規範：** `.claude/rules/plan-persistence.md`
