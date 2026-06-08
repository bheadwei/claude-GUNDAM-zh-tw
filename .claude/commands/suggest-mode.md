---
description: 調整 Agent 建議的頻率和密度，控制人機協作模式。
---

# 建議模式控制

## 模式說明

| 模式 | 說明 | 適用場景 |
| :--- | :--- | :--- |
| `high` | 每個任務節點都建議 Agent | 新手、學習中 |
| `medium` | 僅在關鍵決策點建議（預設） | 日常開發 |
| `low` | 僅在必要時建議 | 熟練開發者 |
| `off` | 關閉自動建議 | 心流模式、快速原型 |

## 使用方式

```
/suggest-mode high      # 每步都建議
/suggest-mode medium    # 關鍵點建議（預設）
/suggest-mode low       # 最少建議
/suggest-mode off       # 關閉建議
```

## 模式行為

### high
- 每完成一個函式 → 建議 code-quality-specialist
- 每次 git commit 前 → 建議 security-infrastructure-auditor
- 每個新功能 → 建議 tdd-guide

### medium（預設）
- 完成整個功能後 → 建議 code-quality-specialist
- 準備 PR 時 → 建議安全檢查

### low
- 僅在偵測到風險時建議（安全漏洞、測試缺失）

### off
- 完全不主動建議，只在你呼叫 `/hub-delegate` 時才啟動

## 持久化（machine-readable）

選定模式後，**必須**將值寫入設定檔，供 hook 與其他指令讀取：

```
路徑：.claude/taskmaster-data/.suggest-mode
內容：純文字，僅一個值 high / medium / low / off
```

- 檔案不存在時，所有讀取方一律**預設 medium**
- `post-agent-report.sh`（handoff 注入 hook）會讀此檔：
  - `off` → 完全不注入待處理交接
  - `low` → 只注入 `priority: high` 的交接
  - `medium` / `high` → 注入全部 pending 交接（上限 5 筆）
- `user-prompt-submit.sh`（意圖路由 hook）同樣依此檔調整注入密度

> 寫入範例：`echo medium > .claude/taskmaster-data/.suggest-mode`
