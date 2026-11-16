# 階段 4 審查（fcb6ade..b37eded）
結論：WARNING（1 HIGH）。sh 路徑與接線沒問題；ps1 靜態審查有一個會讓核心情境失效的 bug。
- HIGH scripts/lib/vscode-live-server.ps1:29 `$text.Contains('/*')` 會被 glob 誤中（`**/*.ts`、`**/*.scss`、`**/*.pyc` 含 `/*`），改成「有就印手動那行」→ 驗收「既有 ["**/*.ts"] → 附加」在 ps1 必失敗；run-tests.sh:5185/5189 的 ps1 案例在有 pwsh 的機器會紅。修法：只比對區塊註解開頭，如 `-match '(?m)(^|[\s,{\[\]:])/\*(?!\*?/)'` 的更嚴版，或用 `(?m)^\s*/\*|[,{\[]\s*/\*`，並補一個含 `**/*.ts` 的 ps1 案例（已有 p2）。
- MEDIUM ps1:12 `Join-Path $Root '.vscode\settings.json'`：Linux／macOS pwsh 會產生含反斜線的檔名，run-tests.sh 的 ps1 案例（在 Linux 跑）會找不到檔。修法：`Join-Path (Join-Path $Root '.vscode') 'settings.json'`。
- MEDIUM ps1:50 ConvertTo-Json 不保留原縮排（5.1 為怪異 4 空白、7 為 2 空白）、5.1 會把 < > ' & 轉成 \uXXXX、PS7 會把 ISO 日期字串轉成 DateTime 再序列化（值格式改變）。規格只要求 sh 保留縮排，故不算偏離；建議在 plan 發現與決策記一筆。
- LOW copy-template.ps1:202 傳 `$Destination`（可能是相對路徑）給用 .NET `WriteAllText` 的 helper，.NET cwd 與 PS location 可能不同；改傳 `$destPath`（該檔 94 行已有）。
- LOW vscode-live-server.sh:59 CRLF 轉換後的新檔失去原檔權限（cp -p 只作用在 $tmp，`$tmp.crlf` 是新檔）；sed 失敗時 `$tmp` 殘留。可改成 `sed ... "$tmp" > "$tmp.crlf" && cat "$tmp.crlf" > "$tmp"; rm -f "$tmp.crlf"`。
- LOW vscode-live-server.sh:54 `mktemp ... || return 0` 靜默吞錯（唯讀目錄時什麼都不印）；至少印手動那行。
- LOW 測試：`--dry-run` 且檔案已存在但缺 glob 的分支（`[dry] 會在`）、copy-template 目標已存在且有自己 settings.json 的合併，沒有案例。不是金額／權限類風險，不建 handoff。
已驗：sh 測試 51 通過 0 失敗；挑的幾條（CRLF 每行 CR、tab 縮排、連跑兩次、無 jq）拿掉對應實作會失敗，測得到行為。接線：dot-source 路徑、-DryRun/-ClaudeOnly/--claude-only/--dry-run 參數名與各腳本既有名稱一致；/scripts/ 與 $sourcePath\scripts 排除讓 lib 不進新專案。jq 1.6 語法（any/2、--indent、--tab、keys_unsorted）相容。
