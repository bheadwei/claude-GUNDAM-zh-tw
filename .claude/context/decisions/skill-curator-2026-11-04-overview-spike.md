# 專案圖解 — 階段 1 可行性實測報告

- 日期：2026-11-04
- 作者：skill-curator
- 依據：`skill-curator-2026-11-04-visual-overview-proposal.md` 第 4 節階段 1、3.4 節、12 節 #8
- 範圍：只產這份報告。原型與沙箱都在 scratchpad，**repo 其他檔案一律沒改、沒 commit**

## 0. 結論

1. **不需要走任何退路。** 輪詢加動態插入 `<script>`、tmp 檔加 `mv`、背景啟動、git common dir 推主 checkout，四件事在 Chrome、Edge 與 Claude Code 2.1.318（Windows）都實測通過
2. **找到一個提案裡沒寫到的坑**：背景啟動段**不能**寫成 `( cd "$X" && nohup bash … >/dev/null 2>&1 & )`。這種寫法下，被放到背景的是整串 `cd && nohup …`，它佔著 hook 的 stdout，等於讓 hook 等完整支腳本。改向必須寫在被放到背景的那個指令上。提案原文 `( nohup bash … </dev/null >/dev/null 2>&1 & )` 是對的，照抄即可
3. **驗收 7 證實 3.4 節的懷疑**：`claude -w` session 裡，`CLAUDE_PROJECT_DIR` 與 payload 的 `cwd` **都指向 worktree**，而 `resolve-roots.sh` 會把那個 worktree 當成主 checkout（`IN_WORKTREE=0`）。`overview.sh` 用 3.4 節的寫法可以算出正確的主 checkout；`resolve-roots.sh` 本身的缺陷需要另開 handoff（見第 5 節）
4. 剩下要人工測的：Firefox、VS Code 內建瀏覽器，以及在真實瀏覽器裡切分頁（Playwright 會強制頁面維持 visible，所以自動化只能用模擬事件驗證邏輯）

## 1. 驗收結果

| # | 項目 | 結果 | 量到的數字 |
|---|---|---|---|
| 1 | `file://` 初次以 `<script src="data.js">` 載入，畫面顯示 `generatedAt` | **通過**（Chrome 156.0.8078.80、Edge 156.0.4314.58，有視窗與無視窗模式都測）；Firefox **需手動** | 初次就顯示 `資料時間 2026-11-04 00:00:00` |
| 2 | 改寫 data.js 後 8 秒內更新，不整頁重載 | **通過**（Chrome、Edge） | 每次 1.8–3.1 秒（每個瀏覽器、每種寫法各連續 4 次，全部 ≤ 3.07 秒）。判斷沒有重載的依據：頁面上的 `window.__marker` 還在、展開中的 `m2`／`m5` 仍然展開、`scrollY` 保持 400、`<script>` 數量維持 2（舊的會移除） |
| 3 | 重載帶 `?t=` 與不帶 `?t=` 的差別 | **Chrome、Edge 兩種寫法都拿得到新內容**，沒有差別；Firefox **需手動** | 帶 `?t=`：2604–2991 ms；不帶：2906–3066 ms |
| 4 | VS Code 內建瀏覽器 | **需手動**（步驟見第 4 節） | — |
| 5 | data.js 寫到一半時畫面不壞 | **通過**（Chrome、Edge） | 故意**不經過** tmp＋mv，直接把 data.js 寫成一半，2.9 秒內狀態列顯示 `更新中…（資料時間 <上一份>）`，6 個模組照常顯示，展開狀態與捲動位置不變；補寫完整後 3.0 秒內恢復。正式寫法是 tmp 檔加 `mv`，連這個中間狀態都不會出現 |
| 5b | 分頁不在前景時暫停（12 節 #8） | **邏輯通過，真實切分頁需手動** | 用模擬 `visibilitychange` 事件：隱藏 10 秒內發出的檢查 **0 次**；切回前景後 **118–134 ms** 就顯示新資料（不必等下一個 3 秒週期）。Playwright 會強制頁面維持 visible：分頁切換、視窗最小化、CDP 外接都量到 `visible`，所以無法用自動化驗證真實切分頁 |
| 6 | Windows Git Bash 背景啟動，hook 不被等住 | **通過**，但「1 秒內返回」這句要重新解讀（見下方） | 見下方 6 的細節 |
| 7 | `claude -w` session 的 `CLAUDE_PROJECT_DIR` 與 payload `cwd` | **已實測**（用 `claude -p -w spikewt`，非互動模式）：**兩者都指向 worktree** | 見下方 7 的細節 |
| 8 | subagent 用 Write 寫檔時 PostToolUse 會觸發 | **通過**，有兩份證據 | 見下方 8 的細節 |

### 6 的細節（背景啟動）

先在 Node 寫一個測試程式，模擬 Claude Code 呼叫 hook 的方式：用 pipe 接 stdin、stdout、stderr，分別記下「行程結束」與「pipe 關閉」兩個時間點。這台機器（有 Check Point 端點防護，hook 測試要跑 2 分鐘以上）的數字如下：

| 寫法 | 行程結束 | pipe 關閉 |
|---|---|---|
| 最小 hook（只有 `true`） | 70 ms | 70 ms |
| 最小 hook，加上 `( nohup bash slow.sh </dev/null >/dev/null 2>&1 & )` | 158 ms | 158 ms |
| 完整 post-write，加上觸發段（提案寫法），6 次 | 1773–2841 ms | **與結束時間相同** |
| 完整 post-write，`OVERVIEW_AUTO=off`，6 次 | 1656–3903 ms | 與結束時間相同 |
| 完整 post-write，**錯誤寫法** `( cd … && nohup … >/dev/null 2>&1 & )` | 2722–3611 ms | **8220–9471 ms**（多等了整支 5 秒的腳本） |
| 完整 post-write，**完全不改向** `( bash overview.sh & )` | 1673–1923 ms | **6936–7229 ms** |

- 觸發段本身只多花約 **90 ms**（158 − 70）。post-write 原本就要 1.7–3.9 秒，那是既有成本，加不加觸發段的差距落在雜訊範圍內。所以「hook 1 秒內返回」在這台機器上做不到，但做不到的是 post-write 本身，跟這個功能無關；**觸發段不會讓 hook 多等 `sleep 5`**，這才是這一項要驗的事
- 也試過另外三種脫離方式：`cmd //c start /b` 211 ms、PowerShell 的 `Start-Process` 3125 ms、`node` 的 detached spawn 794 ms。都可行但都比較慢，**不採用**。Git Bash 沒有 `setsid`
- **在真的 Claude Code 2.1.318 裡實測**：在沙箱用 `claude -p --model haiku` 寫 `docs/architecture.md`，假腳本設成睡 20 秒。用 `--include-hook-events` 看事件順序：
  - 提案寫法：PostToolUse 回應之後，下一個工具（Bash）的 PreToolUse 在背景腳本**還沒做完時**就開始了。腳本 14:28:43 啟動、14:29:05 結束，下一個工具 14:28:46 就開始了
  - 不改向的寫法也一樣沒被等住：腳本 14:30:22 啟動、14:30:43 結束，下一個工具 14:30:24 開始。也就是說，**目前的 Claude Code 只等 hook 行程結束，不等 pipe 關閉**
  - 但改向**仍然必要**：`run-tests.sh` 這類用 `$(…)` 擷取 hook 輸出的測試會等 pipe 關閉，不改向的話每個案例會被拖 5 秒以上；Claude Code 日後的行為也可能改變

### 7 的細節（`claude -w`）

在沙箱跑 `claude -p -w spikewt`，用一支 PreToolUse／PostToolUse 的探針 hook 記錄環境：

```
cwd=…\sandbox\.claude\worktrees\spikewt
CLAUDE_PROJECT_DIR=…/sandbox/.claude/worktrees/spikewt
```

- 這個 session 讀的是 **worktree 裡那份** `.claude/settings.json` 與 hooks（也就是 checkout 出來的版本），不是主 checkout 的那份
- `overview.sh` 用 3.4 節的 `git rev-parse --path-format=absolute --git-common-dir` 算出 `main=…/sandbox`，data.js 寫進主 checkout，**這個寫法正確**
- 在同一個 worktree 裡呼叫 repo 現有的 `resolve_roots`，得到 `MAIN_ROOT=…/worktrees/spikewt`、`IN_WORKTREE=0`。也就是說，在 `claude -w` session 裡所有 hook 都會把 worktree 當成主 checkout，本來該共享的產物（log、learned、overview）會各寫各的。**這是既有缺陷，不屬於這個功能**
- 測的是 `-p` 非互動模式。互動模式的 `claude -w` 理論上走同一條路，但沒有實測，複驗步驟見第 4 節

### 8 的細節（subagent 寫檔）

- **沙箱實測**：叫主 session 派一個 `general-purpose` subagent，由它 Write `docs/sub-architecture.md`。探針記到 `ev=PostToolUse tool=Write agent=general-purpose`，觸發段也跑了（`run.log` 在 14:31:17 記到 start，當時 subagent 還在執行）
- **repo 的 `hooks.log` 佐證**：提案檔是 skill-curator subagent 寫的（`agent-activity.jsonl` 記錄的時間窗是 11:18:06 到 11:29:33，`agent_id a19b1cf275c855633`），`hooks.log` 第 2031 行記到 `[11:29:03] post-write: …visual-overview-proposal.md`。我這次以 subagent 身分寫的 scratchpad 檔案也都有記錄（第 1964、2067 行）
- 不足的地方：`hooks.log` 的 `post-write:` 那一行**沒有記 `agent_type`**，所以只能靠時間窗對照。payload 裡其實有 `agent_type` 欄位（探針讀得到），階段 3 可以順手把它加進 log 行

## 2. 選定的寫法（給階段 3）

### 畫面（`index.html`）

- **輪詢 3 秒，每次插入一個新的 classic `<script>`，路徑是 `data.js?t=<Date.now()>`**。Chrome 和 Edge 帶不帶 `?t=` 都可以，但 Firefox 和 VS Code 還沒測，帶上 `?t=` 比較保險，而且沒有任何代價。載入完就移除這個 `<script>` 元素
- **判斷「寫到一半」的方法**：插入前把 `window.OVERVIEW` 設成 `null`；載入後如果還是 `null`（代表檔案有語法錯誤或不存在），就還原成上一份並顯示「更新中」。這個方法成立的**前提**是 data.js 必須是**單一一句賦值** `window.OVERVIEW = {…};`。如果拆成多句，讀到一半的檔案可能前幾句已經執行，畫面就會半新半舊。這條要寫進階段 3 的腳本註解和 schema
- **只有 `generatedAt` 變了才重畫**。重畫時先記下哪些 `details[open]` 是展開的再還原，而且不碰頁面高度以外的捲動，捲動位置就不會跑掉
- **visibility**：`hidden` 時 `clearInterval`；回到 `visible` 時立刻 `check()` 一次再重新開始計時
- **不能用 `type="module"`**（提案已查證：`file://` 會被 CORS 擋）
- 原型最終版在 `C:\Users\KUANWE~1\AppData\Local\Temp\claude\D-----claude-v2026\54332dd6-b815-4f46-96f7-1761b4f0f91e\scratchpad\overview-spike\index.html`（3.8 KB）。裡面的 `?reload=plain` 參數和 `window.__ovStats` 只是測試用，正式版要拿掉

### 背景啟動（post-write 的觸發段）

```bash
case "$(printf '%s' "$FILE_PATH" | tr '\\' '/')" in
    */taskmaster-data/wbs.md|*/taskmaster-data/plans/*.md|*/docs/*architecture*.md)
        if [ "${OVERVIEW_AUTO:-on}" != "off" ] && [ -f "$MAIN_CLAUDE/scripts/overview.sh" ]; then
            ( nohup bash "$MAIN_CLAUDE/scripts/overview.sh" "$WORK_ROOT" </dev/null >/dev/null 2>&1 & )
        fi ;;
esac
```

- **不要在小括號裡用 `cd … &&` 串接。** 工作目錄用參數傳給腳本；一定要 `cd` 的話，改向就要寫在整個小括號外面
- 位置要放在 `[ -z "$FILE_PATH" ] && exit 0` 之前、`hooks.log` 寫入之後（沙箱放在原檔第 42 行之後）
- `$MAIN_CLAUDE` 在 `claude -w` session 裡其實是 worktree 的 `.claude`（見驗收 7）。這不影響結果，因為 `overview.sh` 自己會用 git common dir 算出主 checkout。但這代表腳本的**位置**來自 worktree 那份 checkout，而 worktree 一定有這個檔（它是進版控的）

### 主 checkout 推算

照 3.4 節原文：`MAIN_ROOT=$(cd "$(git -C "$WORK_ROOT" rev-parse --path-format=absolute --git-common-dir)/.." && pwd)`。這次在主 checkout 與 `claude -w` worktree 兩種情況都實測正確。

### 退路

**一條都不用走。** 退路表裡「動態插 script」「背景被等住」「`CLAUDE_PROJECT_DIR` 指向 worktree」三列，前兩列已排除，第三列本來就是 3.4 節的設計，不需要額外處理。

## 3. 原型與沙箱位置（scratchpad，不進 repo）

根目錄：`C:\Users\KUANWE~1\AppData\Local\Temp\claude\D-----claude-v2026\54332dd6-b815-4f46-96f7-1761b4f0f91e\scratchpad\overview-spike\`

| 檔案 | 用途 |
|---|---|
| `index.html` | 原型最終版 |
| `data.js`、`gen-data.sh` | 手寫資料與產生器（單句賦值，約 2.2 KB） |
| `overview.sh` | 假產生器：`sleep 5`，寫 tmp 檔後 `mv` |
| `browser-test.js` | Playwright 測試，驗收 1、2、3、5、5b |
| `hook-timing.js`、`detach-timing.js`、`detach/` | 驗收 6 的計時程式與各種脫離方式 |
| `sandbox/` | `git init` 過的沙箱專案。`.claude/hooks/post-write.sh` 已加觸發段，另有 `-cdbug`、`-noredir` 兩個對照版、`probe.sh` 探針、`settings.json`，以及 `.claude/worktrees/spikewt`（`claude -w` 建的 worktree） |
| `e2e-noredir.jsonl`、`probe.log` | 真實 Claude Code 跑出來的 hook 事件與探針紀錄 |
| `result-*.json` | 各瀏覽器的測試結果 |

## 4. 給使用者的手動測試步驟

準備：用檔案總管打開上表的根目錄。測試會用到兩個檔：`index.html`，以及在 Git Bash 執行的 `bash gen-data.sh "<時間>" > data.js`（直接覆寫）。

### A. Firefox（驗收 1、2、3、5b）

1. 把 `index.html` 拖進 Firefox。**觀察**：上方顯示 `資料時間 …`，下面有 6 個模組
2. 展開「模組 2」，往下捲一點
3. 在 Git Bash 進到該目錄，執行 `bash gen-data.sh "2026-12-01 10:00:00" > data.js`。**觀察**：8 秒內時間變成 `2026-12-01 10:00:00`，模組 2 仍然展開，捲動位置沒變，畫面沒有閃白
4. 網址列最後加上 `?reload=plain` 後重新整理，重做步驟 2、3，時間改用 `10:05:00`。**觀察**：會不會更新。**沒更新就回報**，這代表 Firefox 必須帶 `?t=`，也就是已選定的寫法
5. 切到別的分頁，執行 `bash gen-data.sh "2026-12-01 11:00:00" > data.js`，等 10 秒再切回來。**觀察**：一切回來時間就馬上變成 `11:00:00`（不到 1 秒）

### B. Edge／Chrome 真實切分頁（只補驗 5b）

照 A 的步驟 1 和 5 做一次。自動化已經驗過步驟 2–4。

### C. VS Code 內建瀏覽器（驗收 4）

1. 在 VS Code 按 `Ctrl+Shift+P`，選 `Simple Browser: Show`，輸入 `index.html` 的 `file:///C:/…/index.html` 網址。**觀察**：能不能開、有沒有顯示 `資料時間`。有些版本的 Simple Browser 不接受 `file://`，打不開也要回報
2. 能開的話，照 A 的步驟 3 做。**觀察**：8 秒內是否更新
3. 如果裝了 Live Preview 擴充：在 `index.html` 上按右鍵，選 `Show Preview`，再做一次步驟 2（Live Preview 走 http，`?t=` 的行為可能不同）

### D. 互動式 `claude -w`（複驗驗收 7，非必要）

1. 在**任何有 commit 的 git 專案**執行 `claude -w spike-check`
2. 在 session 裡輸入 `!echo "$CLAUDE_PROJECT_DIR"; pwd`
3. **觀察**：如果兩個路徑都以 `.claude/worktrees/spike-check` 結尾，代表和 `-p` 模式的結論一致。結束後執行 `git worktree remove .claude/worktrees/spike-check`

## 5. 另外發現（不屬於這個功能，沒有改）

1. **`resolve-roots.sh` 在 `claude -w` session 會把 worktree 當成主 checkout**（驗收 7 實測）。影響：`hooks.log`、`learned/` 這類本來要集中在主 checkout 的產物，會寫進 worktree；跨 worktree 的閘門（例如 `.current-task-mode` 的歸屬判斷）也會判錯。修法和 3.4 節一樣，改用 `git rev-parse --git-common-dir` 推算主 checkout。**建議主模型開 handoff**（`to: skill-curator` 或直接交給主模型；hook 屬於 `.claude/**`），並附上 `run-tests.sh` 的案例：「`CLAUDE_PROJECT_DIR` 指向 worktree 時，`MAIN_ROOT` 仍是主 checkout」。這次沒有建 handoff 檔，因為任務規定 repo 裡只能改這份報告
2. **`pre-tool-use.sh` 第 62 行的 `${IN_WORKTREE:+[wt]}` 永遠成立**。`IN_WORKTREE=0` 也是非空值，所以 `hooks.log` 裡每一筆 pre-tool 都標了 `[wt]`（目前 1560 筆全部是 `[wt]`，沒有任何一筆是 `pre-tool:`）。這個標記完全不能用來判斷。修法：改成依 `[ "$IN_WORKTREE" = 1 ]` 判斷
3. **`.skill-impact` 這輪沒處理也沒清除**（任務限定只能寫這份報告），留給下一輪例行盤點

## 驗證狀態

- 接線檢查：`check-counts.sh` 共 695 項，全部一致（這次沒有動到被檢查的檔案）
- 行為驗證：
  - 瀏覽器：Chrome 156、Edge 156 用 Playwright 1.64.1 實測，有視窗與無視窗模式都測
  - hook：在 Claude Code 2.1.318 的真實 session 實測（`claude -p`，在沙箱裡跑）
  - 未驗證：Firefox、VS Code、真實切分頁，以及互動式 `claude -w`
- 第一次有視窗的 Chrome 測試出現過一次「展開狀態和捲動位置沒保住」，之後連跑 3 次（含單獨重測）都沒有重現。**推測**是測試時跳出的瀏覽器視窗被人點到了，但沒有證據可以確認。手動步驟 A-3 會再看一次這一項
