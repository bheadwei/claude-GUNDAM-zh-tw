---
agent: code-quality-specialist
date: 2026-11-16-1500
area: quality
target: feat/overview-stable-url 階段 2（6fa86b1..a25b578）
severity: medium
status: findings
---

# 專案圖解頁斷線自動接回：無 CRITICAL／HIGH，2 項 MEDIUM

## TL;DR
- 狀態機沒找到計時器洩漏或重複 setInterval；`bash run-tests.sh 現況分頁` 61 通過 0 失敗；`check-counts.sh` 725 項一致；index.html 94,618 位元組（<112KB）。
- 新測試在舊行為下都會失敗（見下）。
- MEDIUM：真伺服器案例的餘裕只有慢速伺服器的 3 秒。

## 發現

### MEDIUM
- `run-tests.sh` 真伺服器案例（`nw_slow` 一段）— 請求懸著期間虛擬時間凍結，「重起伺服器」必須在 3 秒（慢伺服器 sleep）內真實時間完成，否則釋放後虛擬時間快轉，10 秒重試在伺服器還沒起來時就打光，`.back.gone` 非 null → 紅。本機 23 秒整節綠；Ubuntu CI 若 python 冷啟動慢（共用 runner）有機率偶發。失敗型態是偶發紅、不會誤綠（`.dead.gone` 另有斷言，沒關成會先紅）。建議：sleep 拉到 5–6 秒（只換真實時間、不影響虛擬時間），成本幾乎為零。另 `R.held` 沒被斷言，慢伺服器有沒有真的接到請求只靠「失敗會紅」間接保證，可接受。
- 同段：慢伺服器與背景重起子行程沒有 trap；`nw_run` 或中途 `set -e` 類中止時會留下 python 行程。LOW 等級，現況每個路徑都走到 `kill`。

### 確認無誤（逐項）
1. 狀態機：`setGone` 先 `stop()`（同時清 rtimer）再視情況 `retry()`／`start()`，`start()` 有 `!timer` 守衛，`htimer` 在 visibilitychange 有守衛並在可見時清掉；心跳（隱藏）與輪詢（可見）互斥；隱藏中拿到 200 只把 GONE 設 null，回可見時走 `check/checkLive/start`。`visible` 且 GONE 時 `serverCheck(); retry()` 的 rtimer 會在 200 後被 `setGone(null)` 的 `stop()` 清掉。file:// 下 `serverCheck` 與心跳都被 `/^http/` 擋。從沒連上過就 404：`SEEN` 為 false → 走 `setGone(null)`，保留。
2. 舊行為下會失敗：`?mock` 不再 `seeVis()`，舊碼斷線後只在 visibilitychange 重試 → m3 會紅；404 後改回 200，舊碼 `DEAD` 永久 → m5 會紅；`?hide` 舊碼隱藏時全停 → sid 0≠3；文字斷言也都換了。驗收 8 條都有對應案例（隱藏 15 分鐘 3/0/0、回可見 1/1 且心跳停、file:// 0、連不上提示 10 秒內消失且 live.js 恢復、404 提示與恢復、從沒連上過、真伺服器、check-counts）。
3. 頁面限制：新增程式碼沒有 hex 色碼、沒有外部網址、仍是 classic script。
4. 案例數：新增案例都在既有 chrome＋Python 守衛之內，沒有新增 `case uname` 之類平台條件，不會造成 Windows／Ubuntu 差異；守衛略過時的 info 行本來就「不計入通過數」，與前例一致。

### LOW（不阻擋）
- 頁面若是在背景分頁開啟（沒有收到 visibilitychange），不會啟動心跳，維持舊行為的輪詢；plan 沒要求，僅供知悉。
