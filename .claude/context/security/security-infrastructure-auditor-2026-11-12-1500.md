---
agent: security-infrastructure-auditor
date: 2026-11-12-1500
area: security
target: .claude/scripts/overview-serve.py, overview-serve.sh, commands/task-status.md（3342b90..c4404e5）
severity: low
status: findings
---

# 專案圖解本機伺服器：無 CRITICAL/HIGH，4 項 LOW、2 項 INFO

## TL;DR
- 8 項檢查全數通過核心要求：只綁 127.0.0.1、token 128 bit、路徑穿越被擋、.serve 為 600、shell 無注入路徑。
- 都是縱深防禦與穩健性的小項，無需阻擋合併。
- 未跑掃描工具：本次無第三方依賴（Python 標準庫），依賴掃描不適用；結論皆來自讀程式碼。

## 範圍
- 只做靜態閱讀，未啟動伺服器、未跑測試。
- 參考 ADR-2026-11-12-003。另讀 templates/overview/index.html（確認有無外連）。

## 發現

### Critical / High
無。

### Medium
無。

### Low
1. overview-serve.py:50 — 閒置計時在 token 驗證前就重設。任何本機程式或惡意網頁（對 8765–8784 發 `<img>`）都能讓伺服器不自動結束。只延長壽命，不洩資料。
   修法：把 `Handler.activity[0] = time.monotonic()` 移到比對通過之後（line 55 之後）。
2. overview-serve.py:53 — `hmac.compare_digest(str, str)` 遇非 ASCII 字元拋 TypeError（請求行以 latin-1 解碼，攻擊者可送 `%` 以外的高位元組）。結果是該連線 handler 例外，不洩資料，但 traceback 會累積進已 unlink 的 .serve.err。
   修法：`hmac.compare_digest(parts[1].encode("latin-1"), self.token.encode())`。
3. overview-serve.py:78/83（list_directory）— 資料夾無 index.html 時，SimpleHTTPRequestHandler 會列出目錄，檔名會包含 `.serve`、`.serve.lock`。內容讀不到（dot 檔被 line 70 擋），只洩漏檔名。
   修法：在 Handler 覆寫 `def list_directory(self, path): self.send_error(404); return None`。
4. overview-serve.sh:126-137 — 網址（含 token）放在 xdg-open／BROWSER／cmd 的 argv，開啟瞬間同機其他使用者可用 `ps` 看到；若啟動新的瀏覽器行程則整個瀏覽器存活期間都看得到。這是「開瀏覽器」功能固有的代價。
   修法：多使用者主機可設 `hidepid=2` 掛載 /proc，或在 task-status.md 註明「共用主機請自己貼網址、設 BROWSER=true」。不建議改程式。

### Info
- 沿用舊 .serve 的 token（py:131）：安全。overview-serve.sh:109 在每次啟動前都 `rm -f "$SERVE"`，所以實務上每次新 token；只有直接跑 .py 才會沿用，而 .serve 為 600、改得動它的人已等同本人。過期 .serve 的 port 若被別人佔用，sh 會把舊 token 送給對方，但該 token 已作廢，無害。
- Windows：`ThreadingHTTPServer` 預設 `allow_reuse_address=True`，Windows 上此選項允許他人重複綁同一 port 並攔截連線（含 URL 中的 token）。僅單人桌機實務風險低；若要收斂，在 Handler 所屬的 server 子類設 `allow_reuse_address = False`。請依實測決定，我未驗證。

## 逐項結論（對應任務 1–8）
1. 綁定：唯一的 bind 在 py:108，寫死 `"127.0.0.1"`，無參數可改成 0.0.0.0 或 ::。通過。
2. token：`secrets.token_urlsafe(16)` = 128 bit。比對用 `compare_digest`（常數時間）。本情境（loopback、128 bit）時序攻擊不可行，用了無害（但見 Low 2）。log_message 已清空（py:45），send_error 走 log_error→log_message 也被吞。Python 命令列只含資料夾，不含 token（py 啟動行 sh:110）。token 只存在 600 的 .serve，與 stdout 網址。
3. 路徑：先以 `split("/",2)` 取 token 後的 rest，再對 `unquote(rest)` 逐段檢查是否以 `.` 開頭（py:70）。與 `translate_path` 同為解一次碼，所以 `..`、`%2e%2e`、`.%2e` 都被擋；`%252e%252e` 解一次得 `%2e%2e`，translate_path 再解碼後視為普通檔名而非 `..`。`//`、絕對 URI（`GET http://…`）、空 token 段都落入 404。反斜線：Linux 無特殊意義；Windows 由 translate_path 的 `os.path.dirname(word)` 檢查丟棄。目錄列出見 Low 3。overview 內無 symlink（已 `find -type l` 確認現有資料夾）。
4. DNS rebinding：未檢查 Host。但 rebinding 攻擊者不知道 128 bit token，每個請求都落入 404，token 已足夠。要補縱深可驗 Host 的主機名（只比對 `127.0.0.1`／`localhost`／`[::1]`，不要比對 port，否則 `ssh -L 9000:127.0.0.1:8765` 會壞）；Codespaces 等轉發網域也會壞。我不建議強制。
5. POST /.shutdown：要 token 才執行（py:85-92），跨站頁面不知 token 就送不出有效請求，也沒有任何回應可讀。足夠；最壞後果只是伺服器被關。
6. 權限：`os.umask(0o077)`（py:129）＋`os.open(..., 0o600)`（py:117）；.serve.err 在 sh:110 的 subshell 內 `umask 077` 後才建立，也是 600。.serve.lock 是空目錄、無秘密。注意 overview 資料夾本身與 index.html／data.js 用的是使用者預設 umask（通常 755/644），同機其他使用者若能穿過上層目錄，可直接讀檔而不需 token；token 只防「經 TCP 連線」這條路。RHEL 預設家目錄 700，通常沒問題；共用主機請確認 repo 上層目錄權限。
7. 指令注入：未發現。URL 由 PORT 與 TOKEN 組成，兩者都先經 `serve_field` 的 sed 只留 `[A-Za-z0-9_-]`（sh:39），不可能含 `&`、空白、引號，`cmd //c start "" "$URL"` 安全。`"$BROWSER" "$URL"` 有加引號，且是使用者自己的環境變數。`$PY`／`$1`（sh:97、110）刻意不加引號以支援 `py -3`，會做 word splitting 與 glob，但無 eval，變數由使用者控制，信任層級與 shell 相同；副作用是 OVERVIEW_SERVE_PYTHON 路徑含空白會失效，屬功能面。
8. 回應標頭：頁面無任何外部連結（templates/overview/index.html 僅 SVG 命名空間字串與相對 href），所以 Referer 洩漏 token 目前沒有實際途徑；`X-Content-Type-Options` 也無實際風險（檔案皆為自家產物）。**不強制建議**；若想零成本防未來加外連，在 py:41 end_headers 加 `self.send_header("Referrer-Policy", "no-referrer")` 一行即可。

## 附帶（非安全）
- 目錄不帶結尾斜線時，SimpleHTTPRequestHandler 的 301 會用被改寫過的 self.path（py:72），Location 少了 token 前綴而落入 404。目前 overview 無子目錄，不觸發。
