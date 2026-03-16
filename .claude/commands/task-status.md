---
description: 查看專案 WBS 任務狀態總覽，追蹤進度和阻塞項。
---

# 專案狀態

## 功能

顯示 WBS 任務清單的完整狀態，包含進度、阻塞項和下一步建議。

## 輸出格式

```
專案狀態:
  總任務: [N] 個
  待處理: [X] 個
  進行中: [X] 個
  已完成: [X] 個
  阻塞:   [X] 個
  進度:   [=====-----] X%

VibeCoding 模板合規:
  05_architecture_and_design_document.md    [通過]
  07_module_specification_and_tests.md      [待檢查]
  08_project_structure_guide.md             [通過]
  13_security_and_readiness_checklists.md   [待檢查]

任務清單:
  [完成] 1.1 專案初始化
  [完成] 1.2 需求分析
  [進行] 2.1 架構設計           ← 當前
  [待處理] 2.2 API 設計
  [待處理] 3.1 核心功能開發
  ...

下一步建議: /task-next
```

## 使用方式

```
/task-status              # 簡要狀態
/task-status --detailed   # 含每個任務詳情
/task-status --metrics    # 含效能指標
```
