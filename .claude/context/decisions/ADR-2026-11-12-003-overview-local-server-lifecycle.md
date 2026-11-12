---
status: 已接受
date: 2026-11-12
decision-makers: [使用者]
consulted: [architect]
informed: [planner]
---

# ADR-2026-11-12-003: 專案圖解改用自寫的本機 Python 靜態伺服器，只綁 127.0.0.1、閒置 30 分鐘自行結束

## 背景

使用者用 VS Code Live Server 開專案圖解，資料每幾秒更新，Live Server 看到檔案變動就整頁重載，畫面每幾秒閃一次。
直接用 file:// 開不會閃，但 SSH 遠端開發時本機瀏覽器開不到遠端的檔，只能裝 Live Preview 擴充或整個資料夾下載回來。
現況分頁（ADR-2026-11-12-002）每 2 秒輪詢 `live.js`，更需要一個「不會自己重載、能經 port 轉發」的開法。
要用什麼伺服器、怎麼起、怎麼認出已經在跑的那一個、什麼時候關、不能用時怎麼退？

## 決策驅動因素

* **不閃**：伺服器只回檔案，不注入重載腳本
* **SSH／VS Code Remote 能用**：要是 http 網址，才能走 port 轉發
* **不常駐**：使用者選閒置自動結束（Q3），不想多一個要手動關的行程
* **不暴露**：圖解含檔案路徑、任務名、agent 正在做什麼，不能被同機其他使用者或網頁讀到
* **零新依賴**：模板不能要求 Node；Python 3 在大多數開發機上有，沒有時要能退
* **Windows Git Bash** 背景行程的存活行為沒實測過

## 決策

選擇 **`overview-serve.py`（標準庫 `http.server`）＋ `overview-serve.sh`（找 Python、認身分、起停、開瀏覽器）**，
因為它只靠 Python 3 標準庫、回應可以帶 `no-store`、能自己計時閒置結束，而 `python -m http.server` 這三件事都做不到。

### 1. 伺服器本身（`overview-serve.py`）

- `ThreadingHTTPServer` ＋ `SimpleHTTPRequestHandler(directory=<overview 資料夾>)`；兩者都是 Python 3.7 起才有，**最低需求 3.7**
- **只綁 `127.0.0.1`**，不綁 `0.0.0.0`、不綁 IPv6 萬用位址
- **網址帶 token 前綴**：只服務 `/<token>/` 底下的路徑，其他一律 404。對外網址是 `http://127.0.0.1:<port>/<token>/index.html`
  - 理由一：多人共用的 Linux 主機（SSH 情境最常見）上，127.0.0.1 對同機所有使用者都開放；沒有 token，誰都能讀別人的圖解
  - 理由二：擋 DNS rebinding——惡意網頁把自己的網域解析到 127.0.0.1 後可以讀本機伺服器，猜不到 token 就只拿到 404
  - 不改用 Host 標頭白名單：VS Code 轉發後的 port 可能不同、Codespaces 等轉發網址的主機名也不同，Host 檢查會擋掉正常使用；token 對兩種威脅都有效
  - token 用 Python `secrets.token_urlsafe(16)` 產生；每次新起都換新 token，舊網址隨之失效（重起後要用 `/task-status` 印的新網址）
- 所有回應帶 `Cache-Control: no-store`；不印存取 log（`log_message` 改成不輸出）
- **閒置結束**：記錄最後一次請求的時間，超過 `OVERVIEW_SERVE_IDLE_MIN`（預設 30）分鐘沒有任何請求就自行結束並刪掉 `.serve`。頁面可見時每 2 秒輪詢 live.js，所以**分頁開著、看得到就不會被關**；切走分頁或關掉瀏覽器 30 分鐘後才結束
- **身分確認端點**：`GET /<token>/.serve-id` 回 200。token 不對就是 404，所以這個端點本身不洩露 token
- **停止端點**：`POST /<token>/.shutdown` → 回 200 後結束。`--stop` 走這條，不靠 `kill <pid>`（Windows 上 Git Bash 看到的 pid 與原生 `python.exe` 的 pid 不同，kill 不可靠）
- **選 port 由 Python 自己做**：從 8765 起依序嘗試 bind，最多 20 個；bind 成功才把 `{port, token, pid, started}` 原子寫進 `overview/.serve`（暫存檔＋rename）。由 bash 先探測空 port 再交給 Python 會有「探完到 bind 之間被別人拿走」的空窗

### 2. 起停與身分判斷（`overview-serve.sh`）

```
overview-serve.sh [--stop] [<工作目錄>]
```

1. 主 checkout 用 git common dir 算（同 `overview.sh`）；沒有 `project.json` → 什麼都不印、exit 0
2. 讀 `overview/.serve`。有 → 用 bash `/dev/tcp` 打 `GET /<token>/.serve-id`（不開 curl 行程）：
   - 回 200 → **已在跑**：只印網址，不開瀏覽器
   - 連不上、或不是 200（port 被別的程式拿走、伺服器已閒置結束）→ 視為失效，往下起新的
3. `mkdir overview/.serve.lock` 拿鎖（兩個 `/task-status` 同時跑時不會起兩個）；拿到鎖後**再讀一次** `.serve` 再確認一次，避免等鎖期間別人已經起好
4. 找 Python：`python3` → `python` → `py -3`，每個都跑 `-c 'import sys;print(sys.version_info>=(3,7))'` 確認輸出 `True`。用這招擋掉 Windows 的 Microsoft Store 假 `python3`（它不會印出 `True`）
5. 在背景起伺服器，最多等 3 秒讓 `.serve` 出現，再用 `.serve-id` 確認一次；印網址
6. `--stop`：有 `.serve` 且身分確認通過 → `POST .shutdown`；沒在跑 → exit 0

`.serve` 建立時權限 600（`umask 077`），token 只有本人讀得到。`.serve`、`.serve.lock` 都在 `taskmaster-data/overview/`（不進 git、`MAIN_CLAUDE` 側，同 data.js）。

### 3. 開瀏覽器：只在「新起」時

| 條件（依序，先符合者為準） | 做法 |
|---|---|
| 已在跑 | 只印網址 |
| 有 `$BROWSER`（VS Code 終端機會設，Remote-SSH 下它會在**本機**開瀏覽器並自動轉發 port） | `"$BROWSER" <網址>` |
| Linux，有 `DISPLAY` 或 `WAYLAND_DISPLAY`，且有 `xdg-open` | `xdg-open <網址>` |
| macOS | `open <網址>` |
| Windows（Git Bash） | `cmd //c start "" <網址>` |
| 其他（純 SSH、沒有桌面） | 只印網址；有 `SSH_CONNECTION` 時多印一行 `ssh -L <port>:127.0.0.1:<port> <你的主機>` |

開瀏覽器的指令失敗不影響結果，網址照印。不論哪種情況，stdout 最後一行都是網址。

### 4. 沒有 Python、或 20 個 port 都不能用

印 `file:///…/index.html` 與一行原因（「找不到 Python 3.7 以上，改用檔案開啟；SSH 遠端請改用 Live Preview」），exit 0。
**file:// 下頁面照常運作**：data.js 與 live.js 都用插 `<script>` 載入（不是 `fetch`），現況分頁也能輪詢，只是 SSH 遠端看不到。

### 5. Windows Git Bash 的背景行程（待階段 4 實測）

從 Git Bash 用 `nohup … &` 起原生 `python.exe`，Bash tool 的 shell 結束後會不會被一起收掉，**沒有實測過**。
階段 4 驗收手動驗「`/task-status` 跑完 60 秒後網址仍打得開」：

- 通過 → 照 `nohup … &`
- 不通過 → 依序改試 `cmd //c start "" /b <python> …`、`powershell -NoProfile -Command Start-Process -WindowStyle Hidden …`，採用第一個通過的，寫進計畫「發現與決策」與 `overview-serve.sh` 檔頭
- 都不通過 → Windows 上退回第 4 節的 file://，並記進 KNOWN-GAPS

## 替代方案

| 方案 | 優點 | 缺點 | 否決理由 |
|---|---|---|---|
| 維持 VS Code Live Server | 使用者已裝 | 檔案一變就整頁重載 | 閃爍正是要解決的問題 |
| `python -m http.server` | 一行、零程式 | 預設綁所有介面（要記得加 `--bind`）；不能帶 `no-store`；不會自己結束；每個請求印 log；沒有身分端點，認不出是不是自己起的 | 常駐、暴露、認不出身分 |
| `npx http-server`／`serve` 等 Node 工具 | 功能多 | 需要 Node；首次要下載套件 | 模板不能要求 Node |
| 常駐，手動關（Q3 選項） | 永遠打得開 | 多一個長命行程，使用者會忘記它還在 | 使用者選閒置結束 |
| 跟著 session 結束（`SessionEnd` hook 關） | 生命週期清楚 | 多個 session 共用同一個伺服器，關掉一個 session 會讓其他 session 的頁面斷線；session 當掉時不會觸發 | 共用資源不能綁在單一 session |
| 只用 file://、不起伺服器 | 零行程 | SSH 遠端看不到；Live Server 的使用者仍會用 Live Server 開 | 解決不了遠端情境 |
| 只綁 127.0.0.1、不加 token | 網址較短 | 同機其他使用者、DNS rebinding 都讀得到 | 多人共用主機是 SSH 情境的常態；token 成本只有網址長一段 |
| 用 Host 標頭白名單代替 token | 網址短 | 轉發後 port／主機名會變，誤擋正常使用；擋不到同機其他使用者 | token 兩種威脅都擋得住 |
| 每次 `/task-status` 都開瀏覽器 | 一定看得到 | 每跑一次多一個分頁 | 使用者選「新起時才開」（Q4） |

## 後果

**得到：**
* 頁面不再因 Live Server 重載而閃；SSH／VS Code Remote 經 port 轉發就能看
* 分頁開著就一直活著，不看了 30 分鐘後自己消失，不用管
* 同機其他使用者與惡意網頁讀不到圖解
* ADR-2026-11-12-001 記的拆檔顧慮「SSH 要整個資料夾下載」從此不成立

**犧牲：**
* 網址多一段 token（`/<token>/index.html`），手打不方便；靠 `/task-status` 印出來或 `$BROWSER` 開
* 多兩支腳本（`.sh`＋`.py`），模板第一次出現 Python 檔；沒 Python 的環境只能退回 file://
* 分頁在背景超過 30 分鐘後伺服器會結束，回到分頁時頁面要能顯示「伺服器已結束，重跑 `/task-status`」（頁面那側要做，見下）
* Windows 背景行程的做法要等實測才定

**中性影響：**
* `commands/task-status.md` 步驟 7、README「專案圖解」段、WORKFLOW 的 SSH 說明要改成網址與 port 轉發
* `run-tests.sh` 的 `_changed_rule` 要加 `overview-serve.*` 一列

**何時該重新考慮：**
* 實測發現 Windows 背景行程三種起法都活不過 shell 結束 → 評估改由 SessionStart hook 起（仍閒置結束）
* 使用者常抱怨「回到分頁打不開」→ 把預設閒置時間調長，或頁面偵測斷線時顯示一鍵複製的重起指令
* 模板開始要求 Node → 可改用 Node 單檔伺服器，取消 Python 依賴

## 確認方式

- [T] 沒在跑 → 起一個，stdout 最後一行符合 `^http://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_-]+/index\.html$`，GET 回 200；GET `/index.html`（不帶 token）回 404
- [T] 已在跑時再呼叫 → 不起第二個（行程數不變），印同一個網址，假 `$BROWSER` 沒被呼叫
- [T] 8765 被測試先佔住 → 用 8766
- [T] `.serve` 記的 port 上是別人的伺服器（`/<token>/.serve-id` 不是 200）→ 另起一個，`.serve` 更新
- [T] 行程命令列與 `.serve` 不含 `0.0.0.0`；用 `ss`／`netstat` 確認只聽 127.0.0.1
- [T] 回應標頭含 `Cache-Control: no-store`
- [T] `OVERVIEW_SERVE_IDLE_MIN` 設極短且沒有請求 → 自己結束、`.serve` 被刪
- [T] `--stop` → 伺服器結束、`.serve` 刪除；沒在跑時 `--stop` → exit 0
- [T] PATH 裡只有一個印不出 `True` 的假 `python3` → 印 `file://` 網址與原因，exit 0
- [T] 兩個 `overview-serve.sh` 同時跑 → 只有一個伺服器
- [T] `.serve` 權限為 600（Linux）
- [M] Windows Git Bash：`/task-status` 跑完 60 秒後網址仍打得開（第 5 節）
- [M] VS Code Remote-SSH 終端機跑 `/task-status` → 本機瀏覽器自動打開、畫面不閃

## 相關

- 計畫：`.claude/taskmaster-data/plans/adhoc-2026-11-12-overview-live.md` 階段 4
- 使用者決定：`.claude/qa-history/2026-11-12-130000-overview-live-plan.md` Q3、Q4
- 相關 ADR：ADR-2026-11-12-001（不拆檔；本 ADR 讓「SSH 要整資料夾下載」不再成立）、ADR-2026-11-12-002（live.js 的輪詢讓分頁開著時不會閒置）
- 參考：Python 標準庫 `http.server`（`ThreadingHTTPServer`、`SimpleHTTPRequestHandler` 的 `directory` 參數，3.7 起）
