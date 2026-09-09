---
from: <source-agent>
to: <target-agent>
date: <YYYY-MM-DD-HHMM>
priority: <high|medium|low>
status: <pending|accepted|completed|cancelled>
related_report: <context/<area>/<report>.md>
---

# Handoff: <from> → <to>

## 起因
<為什麼需要這次交接，1-2 句>

## 必須處理的項目
- [ ] `<file>:<line>` — <要做什麼>
- [ ] `<file>:<line>` — <要做什麼>

## 已知限制 / 注意事項
<目標 agent 應該知道的背景，避免重複踩雷>

## 期望結果
<完成標準>

## 完成回報（目標 agent 填寫）
- 完成日期: <YYYY-MM-DD-HHMM>
- 處理結果: <完成 / 部分 / 遞延 / 取消>
- 後續報告: `context/<area>/<new-report>.md`

---

> 命名規則：`<from>-to-<to>-<YYYY-MM-DD-HHMM>.md`
>
> 完成後**只改 `status:` 為 `completed`**（或 `cancelled`）——不要刪檔，也不要自己搬。
> `post-agent-report.sh` 會在下一次 subagent 結束時自動把它移到
> `handoffs/archive/YYYY-MM/`（月份取自上面的 `date:`）。
>
> **審計軌跡沒有消失，只是換了位置**：舊檔一字不差地留在 `archive/` 裡，同名也只加
> `-2` 後綴、絕不覆蓋。這樣 `handoffs/` 平坦層永遠只剩還沒結案的那幾份，
> hook 的 pending 掃描與「找屬於自己的交接」都不必在一堆已完成的檔案裡撈。
