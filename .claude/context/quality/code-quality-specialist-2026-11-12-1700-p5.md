---
agent: code-quality-specialist
date: 2026-11-12-1700
area: quality
target: git diff bb0636f..f86b56b（專案地圖階段 5）
severity: low
status: findings
---

# 階段 5 審查：無 CRITICAL／HIGH，3 項 MEDIUM／LOW

## TL;DR
curGroups／humans／doneOn／標籤皆符合 plan 驗收；jq 1.6 相容、`esc()` 完整、390px 不溢出。
僅有 humans 分支來源與測試覆蓋的小落差，記為技術債。

## 發現

### Medium
- `overview.sh` for-each-ref 一行（gather）— 本地與遠端同名分支只用 committerdate 排序：遠端較新時取到 `origin/...` 前綴；且不論有無負責人都跑，大 repo 分支多時每次完整重產都付成本 → 沒有任何任務有負責人時可略過；或遠端同名時去前綴取本地。
- `run-tests.sh` 新節 — 沒測「兩條都符合取最近一條」「`1.50`／`21.5`／`1x5` 不誤判」「遠端 `origin/` 前綴」；regex 以檢視確認正確（`.` 以 `[.-]` 處理、前後有邊界），但沒有測試鎖住。

### Low
- humans 比對「我」用整欄相等：負責欄 `alice, bob` 且我是 alice 時仍列出（plan 寫「相同」，行為符合規格，但多人欄位沒定義）。
- chrome 找不到時新節整段靜默略過、不印提示；既有 3553 行的作法是印 `ok "（沒有 chrome，略過…）"`。
