---
agent: code-quality-specialist
date: 2026-11-12-1830
area: quality
target: git diff 47f210f..9f6b55b（plan adhoc-2026-11-12-overview-live 階段 7 現況分頁）
severity: medium
status: findings
---

# 階段 7 現況分頁審查：沒有 CRITICAL／HIGH，3 個 MEDIUM（1 個行為、2 個測試缺口）

## TL;DR
跳脫、計時器、`.serve-id` 分流、和地圖／任務圖分頁的隔離都沒找到會出錯的地方；頁面硬限制全部符合。
MEDIUM：伺服器結束後每秒時鐘仍拿過期的 `lastAt` 算「卡住」，「需要你」會在凍結的畫面上一直往上加；
reduced-motion 測試在沒有 lane 的畫面上跑，等於沒驗；斷線後恢復那條驗收沒有自動測試。結論：通過。

## 範圍
- **檢查目標**: `.claude/templates/overview/index.html`、`.claude/hooks/tests/run-tests.sh`（新節＋`#map`）、`.claude/hooks/tests/fixtures/overview/now-check.js`、`README.md`、`.claude/guides/WORKFLOW.md`
- **觸發原因**: 階段 7 每階段審查
- **參考資料**: plan 階段 7 驗收、`overview.sh` 檔頭「即時聚合」（第 49–94 行）、curGroups／humans 的 jq（第 1476–1500 行）

## 逐項確認（沒有問題）
- **硬限制**：91702 bytes；沒有 module script、沒有外部網址（只有 SVG namespace）；新增 CSS 沒有 hex 色碼；動畫（ring／slide／bump／enter／leave、transition）都在 `prefers-reduced-motion: no-preference` 內；`sync()` 用 data-id 對應，留下的節點不換新
- **欄位對照**：lanes（id, who, desc, where, readonly, group, since, lastAt, doing, files）、needs（id, kind, who, where, text, since）、clashes（file, lines）、doneToday、feed（t, kind, id, who, where, text）、at，curGroups 的 sources／activePhases／phases／guessed，humans 的 who／task／title／status／branch，都和 overview.sh 一致
- **XSS**：外部字串走 `textContent`（`txt()`、`livetx`），或先 `esc()` 再進 innerHTML（feed、clashes、humans、groupHead、stepsBar）。沒跳脫就進 innerHTML 的只有數字（`dt.agents`／`dt.tasks` 是 jq `length`，`ph.n` 是 `tonumber`）和寫死的常數
- **計時器**：`start()` 有 `if (!timer)` 防重入，`stop()` 兩個都清；hidden → stop；GONE 時 visible 只跑 `serverCheck`，200 才 `setGone(false)` 重開；GONE 時 hidden 的 fetch 回來不會重開（有檢查 `visibilityState`）。沒有疊加
- **`.serve-id` 分流**：reject 才算結束，200／404 都算活著（404 已裁決要改，不重報）；`file:` 不檢查
- **互相干擾**：新加的 class／id（kpi、lane、feed、needs、gone、still、live、nv…）在既有 CSS／DOM 都沒出現過；同一個 IIFE 裡沒有重名函式；`stored()` 改成帶參數，兩個呼叫端都改了；沒有 hash 開 `#now`、`#map`／`#tasks` 照舊；在現況分頁時 `render()` 走 `pending`，切回地圖會補畫
- **跑過**：`run-tests.sh 現況分頁` 44／0。`eval: line 413/431 syntax error` 兩行在 47f210f 一樣有（選節 hoist 的既有問題，不是這次引入的）

## 發現

### 🔴 Critical / High
（無）

### 🟡 Medium

- **[MEDIUM] 伺服器結束後，「卡住」與「需要你」還是用過期資料每秒重算**
  `.claude/templates/overview/index.html:1300`（`tick`）、`:1218`（`stuckFor`）、`:1325`（`setInterval(tick, 1000)`）
  問題：`setGone(true)` 只停了 data.js 和 live.js 的輪詢，`tick` 還是每秒拿 `secs() - l.lastAt` 判斷卡住。
  伺服器結束 10 分鐘後，畫面上每條線都會變成「卡住」，「需要你」的數字一直加還會跳動畫，
  「N 分鐘沒有動靜」也繼續長。但這些線真正的狀態其實不知道。頂端的提示說「伺服器已結束」，下面的數字卻像還在即時更新，兩邊互相矛盾。
  修法：`GONE` 時讓 `tick` 不再更新卡住判斷和 needs（例如 `stuckFor` 的「現在」在 GONE 時固定成進入 GONE 的時間），
  或最簡單：`tick` 開頭 `if (GONE) return;`，讓時鐘一起停住。這也符合 plan 說的「保留畫面」。

- **[MEDIUM] reduced-motion 驗收的測試沒有 lane 卡，等於沒驗**
  `.claude/hooks/tests/fixtures/overview/now-check.js:48-54`、`.claude/hooks/tests/run-tests.sh:6029`
  問題：`ON` 分支在 800ms 時直接 `return done()`，這時 `LV` 還是 null，畫面上沒有任何 lane、沒有 `.pbar.ind i`、沒有 `.lane .pdot::after`。
  所以「所有元素（含 ::after）的 animation-name 為 none」只檢查了 `#live .pdot::after` 一個規則。
  如果之後有人把 `.pbar.ind i{animation:slide…}` 或 lane 的 ring 移到 media query 外，這條測試照樣是綠的。
  修法：reduce 那輪也先把 `LV` 設成有 lane 的資料（至少一條 `files: null`、一條非 stuck），等 live.js 載入後再掃 `qa('*')`。

- **[MEDIUM] 「斷線後恢復」那條驗收沒有自動測試**
  `.claude/templates/overview/index.html:1429-1434`（`setGone(false)` → `check(); checkLive(); start()`）
  問題：plan 驗收「再跑伺服器後切走再切回 → 提示消失、live.js 恢復更新」沒有對應的 expect。
  `.progress`／plan 寫的是用替身伺服器手動驗過。換 token 那半已裁決會在修復輪改成「網址已失效」，
  但「網路錯誤 → 提示 → visible 時 `.serve-id` 回 200 → 收掉提示、重開兩個計時器」這條路徑還在，
  而且 SSH `-L` 隧道斷掉再接回就會走到。這條路錯了，就是畫面永遠停在「伺服器已結束」、不會再更新。
  因為修復輪本來就要動 `serverCheck`，不另外建 handoff。建議修復輪一起補一個案例：
  用同一個 port 的替身伺服器（`python3 -m http.server` 放一個 `.serve-id`），或攔 `fetch` 先 reject 再 resolve，
  派 `visibilitychange` 之後，斷言 `#gone` 隱藏而且 live.js 又被載入。

### 🟢 Low / Info
- `html()`（`index.html` 約 1185 行）拿 `innerHTML` 跟 `esc()` 的輸出比對。文字含 `"` 或 `'` 時，序列化後永遠不相等，那些 feed 行／組標題每次 `renderNow` 都會重寫。只影響效能，不是卡片，不影響驗收
- 選節執行時 `eval: line 413/431 syntax error` 是既有問題（47f210f 一樣），跟本階段無關，可以另外查 `_hoist_defs` 哪一節解析失敗

## 建議的後續 Agent
- 無 handoff：沒有「有風險的路徑完全沒測試」到需要另派的程度；恢復路徑的測試併進已裁決的修復輪

## 度量
- 檢查檔案數: 5
- 通過: 5 | 警告: 0 | 失敗: 0（MEDIUM 3、LOW 2）
- 局部測試：`run-tests.sh 現況分頁` 44 通過／0 失敗
