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
> 完成後不刪除，作為審計軌跡。
