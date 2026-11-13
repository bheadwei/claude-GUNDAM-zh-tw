---
agent: code-quality-specialist
date: 2026-11-13-1130
area: quality
target: git diff efe5396..fc2fb02（plan adhoc-2026-11-12-overview-live 階段 8）
severity: medium
status: findings
---

# 階段 8 審查：部件卡「誰在做／等你」與標籤連動。沒有 CRITICAL 或 HIGH，結論「通過」

## TL;DR
沒有 CRITICAL 或 HIGH，7 條硬限制都符合，plan 的 4 條驗收都有對應測試而且是綠的。另外記了 2 個 MEDIUM（效能測試沒涵蓋 parts、頁面上 aid 為空時改用 sid 對應的路徑沒有測試）和 2 個 LOW。
用 jq 1.6 時有 3 條測試失敗，原因不在測試：jq 1.6 編譯不了完整重產的 overview.jq（`{module, file}` 的簡寫在 1.6 裡是保留字錯誤），所以完整重產時 data.js 和 live.js 都不會寫。這個問題 2026-11-04 起就有，不是階段 8 引入的，而且 jq 1.6 本來就低於支援版本（README 和 session-start 寫最低 1.7.1）。

## 範圍
- **檢查目標**：6b85544（`.claude/scripts/overview.sh` 的 lanes 加 `parts`，以及 --live 測試）、fc2fb02（`.claude/templates/overview/index.html` 部件卡的 patch 與標籤 button、`parts-check.js`、`now-check.js`、`run-tests.sh`）
- **觸發原因**：plan 階段 8 的階段審查
- **參考資料**：plan 的「階段 8」與「發現與決策」；`code-quality-specialist-2026-11-12-1830-p7.md`、`-1651-p6.md`；README 的 jq 最低版本；`session-start.sh:153-165`

## 硬限制逐條
| 限制 | 結果 |
|---|---|
| file:// 可用（沒有 module script、不連外部網址） | 符合：diff 沒有新增 `type="module"`，也沒有 http 網址 |
| hex 色碼只在 `:root` | 符合：新增的 CSS 全部用 `var(--wip)`、`var(--accent)` |
| 頁面 ≤128KB | 符合：94144 bytes |
| 外部字串進 DOM 前跳脫 | 符合：`data-part` 和 `data-st` 經過 `esc`；`.who` 和 `.st` 用 `textContent` 或 `txt()`（內含 `clean`）；`data-g` 經過 `esc` |
| live.js 更新只 patch 部件卡 | 符合：`partsTick` 只改 `.pc[data-part]` 的 class 和文字；測試驗了 `.tcards`、卡片是同一個 DOM 物件，`scrollTop` 不變 |
| GONE 或 DEAD 後停止更新 | 符合：`partsTick` 掛在 `tick()` 的 `GONE \|\| DEAD` 早退之後；mock 測試驗了過了整分仍是「0 分」 |
| 檔頭「即時聚合」與 jq 一致 | 符合：檔頭寫「planned 不為 false、不限階段、session 只看最後一個 Stop 之後、沒有組 → []」，`lparts` 逐項對得上（plan 找不到時用 `$pl.parts // []` 也回 []） |

## 重點項目的判斷
- **glob 比對**：直接沿用 `glob2re`（有 `^…$` 錨定；沒有萬用字元時當成目錄前綴 `(/.*)?$`）。`src/pay/**` 不會命中 `src/payment.ts`，`src/pay` 也不會命中 `src/payment`。沒找到誤命中。
- **session lane 的範圍**：`lparts($g; $cur)` 用的 `$cur` 和 `files`、`doing` 相同（最後一個 Stop 之後）。agent lane 用該 aid 的全部事件。範圍正確。
- **group 為 null**：回 `[]`，有測試。
- **need 對應 lane**：overview.sh:416 的 need id 是 `"\(.sid)|\(.aid)|\(.since)"`。頁面用 `a[1] || a[0]` 取值：aid 有值時取 aid，對 agent lane 的 id；aid 為空時取 sid，對 session lane 的 id（`$z.sid`）。兩邊對得上。
- **從「等你」還原**：`st` 改回 `n.dataset.st`，`.st` 的 className 和文字一起還原，`waiting` class 也拿掉。測試驗了「進行中 · p9a」。data.js 重產時 `render → renderTasks → renderNow → tick → partsTick` 是同步執行，重建後不會閃掉標記。
- **標籤 button**：原生 `<button>`，Enter 和 Space 會觸發 click；全域 keydown 只處理 Escape、`+`、`-`，不會攔到它。在下拉裡點時先 `m.open = false`，toggle 事件會把關閉狀態寫回 `OPEN`。頁面沒有 hashchange 監聽，`view('now')` 只用 `replaceState`，和現況分頁不會互相干擾。只有焦點有小問題，見下方 LOW。

## 發現

### 🔴 Critical / High
（無）

### 🟡 Medium
- `.claude/scripts/overview.sh:359-364` 加上 `.claude/hooks/tests/run-tests.sh:5704`：parts 的成本是「lane 數 × 部件數 × 每個部件的檔數 × 寫過的檔數」，每次都跑 `test()`。3000 行的效能測試用的 lane-data 沒有帶 plan 部件，所以這段成本完全沒有被量到。我單獨量了 parts 這一段（jq 1.8.1，最壞情況是沒有命中、`any` 無法提早結束）：10 條 lane × 60 個部件（每個 2 檔）× 30 個寫過的檔 → 0.25 秒；40 條 lane（效能測試本身模擬的規模）→ 1.21 秒，光這段就超過「<1 秒」的預算。
  → 修法：每個組只算一次 `[部件 | {id, r: ([.files[]? | glob2re] | join("|"))}]`，每條 lane 對每個寫過的檔只跑一次 `test`（同樣 40 條 lane 實測降到 0.67 秒），並在效能測試的 lane-data 帶一份有部件的 plan。
- `.claude/hooks/tests/fixtures/overview/parts-check.js:21`：頁面上「aid 為空時改用 sid 對 session lane」這條路徑（`index.html:1314` 的 `a[0]`）沒有測試。fixture 的 need 只有 `s1|a1|…` 這一種（aid 有值）。這條是 UI 標記，錯了不會壞資料或放錯權限，所以只記 MEDIUM、不建 handoff。
  → 修法：在 B 階段多放一條 session lane（`id: 's9'`，parts 為 `['p9b']`）和一筆 `s9||<since>` 的 need，斷言 p9b 變成「等你」。

### 🟢 Low / Info
- `.claude/templates/overview/index.html:1323`：分鐘數沒有夾到 0 以上。用 SSH 轉發 port 從本機瀏覽器看遠端時（本 plan 的主要情境之一），兩台機器的時鐘只要差幾十秒，卡片就可能顯示「implementer · -1 分」。同頁的 `.lclock` 用 `clock()` 做了 `Math.max(0, …)`。→ 改成 `Math.max(0, Math.floor((t - l.since) / 60))`。
- `.claude/templates/overview/index.html:1040`：在下拉裡用鍵盤按標籤時，`m.open = false` 會把正在聚焦的 button 藏起來，焦點掉到 `body`，鍵盤使用者得從頁首重新 Tab。→ 關掉前先 `m.querySelector('summary').focus()`，或捲動後把焦點移到目標組框（組框要加 `tabindex="-1"`）。
- **jq 1.6 的 3 條失敗**（「完整重產結束 → 也寫 live.js…」、「data.js 的 plans 帶 files:」、「curGroups 變了…」）：
  - **原因不在測試。** 我用 `/usr/bin/jq` 1.6 在沙箱跑完整重產，`.last-error` 是 `syntax error, unexpected ',', expecting ':'`，出錯位置在 overview.sh:1380 的 `{module, file}` 和 :1392 的 `{…, module}`。jq 1.6 把 `module` 當保留字，物件裡不能用簡寫（`/usr/bin/jq -n '{module:1}|{module}'` 可以重現）。
  - **使用者實際會遇到。** 整支 overview.jq 編譯失敗，`run_once` 在 `generate` 就回 1，data.js 和 live.js 都不會寫；第一次跑的專案連 data.js 都沒有。這是背景重產，只會留下 `.last-error`。用 jq 1.6 跑「專案地圖」那節，110 條裡失敗 110 條。
  - **不是這次引入的。** 這兩行從 fdc5ff0 和 4b42237（2026-11-04）就在，main 上也有。`--live` 的 jq 在 1.6 上正常，新的 parts 測試在 1.6 下全過。
  - **嚴重度：本階段不計。** jq 1.6 低於官方支援版本：README:15-21 寫最低 1.7.1，`session-start.sh:164-165` 會警告「hook 與專案地圖可能出錯或靜默失效」。所以這是「不支援的環境下靜默失效」，和既有文件說的一致。
  - **另外要注意兩點。** 第一，ADR-2026-11-05-001:60 仍寫著「[T] jq 1.6 相容」，和 README 的 1.7.1 矛盾。第二，plan「發現與決策」階段 6 那行寫「jq 1.6 實跑輸出與 1.8.1 逐字相同」，只適用於 `--live`，容易讓人誤以為完整重產也相容。建議擇一處理：把 `module` 簡寫改成 `module: .module`（2 處），或在 KNOWN-GAPS 記一筆並更正 ADR 那行。這個決定交給主模型或使用者。
- plan 驗收裡的 3 張截圖（p9a 顯示誰在做、等你黃框、點標籤後組框在頂端）我沒有驗證。自動測試已經涵蓋同樣的斷言。

## 建議的後續 Agent
- 無。測試缺口只有 MEDIUM，不符合 handoff 門檻。沒有安全敏感問題。

## 度量
- 檢查檔案數：5（另讀 agent-events.sh、README、session-start.sh、ADR 作為上下文）
- 測試：「即時聚合」節 95/0（jq 1.8.1）、92/3（jq 1.6，失敗原因如上）；「現況分頁」節 54/0（含階段 8 的 6 條）
- 通過：7 條硬限制、4 條驗收 | 警告：MEDIUM 2、LOW 2 | 失敗：0
