---
date: <YYYY-MM-DD-HHMM>
parties: <agent-A> vs <agent-B>（或 人類 vs agent）
severity: <high|medium|low>
status: <open|resolved|deferred>
related_reports: <context/<area>/<report>.md, ...>
---

# Conflict: <一句話描述衝突主題>

## 衝突點
<雙方在什麼決策/做法上不一致，1-2 句>

## 各方立場
- **<agent-A>**: <主張與理由>
- **<agent-B>**: <主張與理由>

## 取捨分析
<比較利弊：正確性、風險、成本、可維護性等>

## 決議（人類拍板）
<最終採用哪個方案，為什麼>

## 後續行動
- [ ] `<file>:<line>` — <要做什麼>
- [ ] 通知 <agent> 依此決議繼續

---

> 命名規則：`conflict-<YYYY-MM-DD-HHMM>-<簡述>.md`
> 決議後不刪除，作為決策審計軌跡。
