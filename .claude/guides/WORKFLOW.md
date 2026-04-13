# 開發工作流指南

## 完整流程

```
/task-init → 任務循環 → 結束保存
```

### Phase 0: 初始化
```bash
/task-init          # 建立 WBS、分析複雜度
```

### Phase 1: 任務循環

```
/task-next  →  /plan  →  /tdd  →  /build-fix（如需）  →  /review-code  →  /verify  →  /task-status
```

### Phase 2: 收尾
```bash
/time-log           # 查看開發時間
/verify pre-pr      # PR 前完整檢查
/save-session       # 儲存 session 狀態
```

## 快速模式（小功能/Bug）

```
/plan [描述]  →  /tdd  →  /verify quick
```

## 指令速查

### 核心工作流

| 指令 | 用途 |
| :--- | :--- |
| `/task-init` | 專案初始化 |
| `/task-next` | 取下一個任務（自動追蹤時間） |
| `/task-status` | 查看專案進度 |
| `/time-log` | 開發時間報表 |
| `/plan` | 規劃實作步驟 |
| `/tdd` | 測試驅動開發 |
| `/build-fix` | 修復建置錯誤 |
| `/review-code` | 程式碼審查 |
| `/e2e` | E2E 測試 |
| `/verify` | 全面驗證（`quick`/`full`/`pre-pr`） |

### 輔助指令

| 指令 | 用途 |
| :--- | :--- |
| `/hub-delegate` | 委派 agent |
| `/check-quality` | 品質評估 |
| `/refactor-clean` | 死碼清理 |
| `/suggest-mode` | 調整建議密度 |
| `/learn` | 擷取可重用模式 |
| `/save-session` | 儲存 session |
