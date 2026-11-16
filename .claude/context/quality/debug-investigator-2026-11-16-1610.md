# debug-investigator — smartwork_for_KM 專案地圖轉圈（2026-11-16 16:10）

STATUS: NEEDS_CONTEXT

## 結論
伺服器端重現不出。KM 的 overview-serve（port 8765）與模板四個檔 sha256 相同；curl 帶 token 取 index.html／data.js／live.js／.serve-id 皆 200、<10ms；Playwright 開頁 345ms 渲染完整，無 pageerror；節流 400ms／100KB/s 仍正常。觀察期間沒有任何請求到達 8765，懷疑是使用者本機瀏覽器 → VS Code Remote-SSH 轉發這一段。

## 已排除
舊 server／舊 token、.serve-keep 權限、data.js 產生失敗、頁面 JS 例外、update-template 漏檔、輪詢 inflight、外部資源、.vscode 覆寫、單執行緒卡住。

## 待使用者提供
實際網址與開法、VS Code 連接埠面板 8765 的轉發狀態、F12 Network 裡 index.html 的狀態。
