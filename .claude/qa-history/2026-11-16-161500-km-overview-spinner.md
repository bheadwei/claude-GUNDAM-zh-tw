# 問答紀錄：KM 專案地圖轉圈（2026-11-16）

## Q1 16:10 同步到下游專案的方式
- 選項：只複製這次改到的檔 (Recommended)／跑 update-template.sh／先不要同步
- 回答：已自行跑 update-template，但地圖打不開、一直轉圈

## Q2 16:12 點終端機裡的地圖網址結果
- 選項：點了可以打開 (Recommended)／還是一直轉圈／我是用 Live Server 開的
- 回答：成功；問下次怎麼知道網址；VS Code 連接埠面板把 8765 轉到 8766，手動改回 8765 才正常

## Q3 16:15 是否改成每個專案用自己固定的 port
- 選項：每個專案一個固定 port (Recommended)／不改只在提示裡說明／先不處理
- 回答：先不處理

## 結論
伺服器端正常（debug-investigator 報告 `context/quality/debug-investigator-2026-11-16-1610.md`）。轉圈原因推測為兩個專案的地圖都從 8765 開始，前一個專案視窗的轉發仍佔著本機 8765，下一個專案的轉發被 VS Code 改到 8766，瀏覽器卻開 8765。使用者決定先不改 port 配置；網址已固定，可存書籤，`/task-status` 或 `overview-serve.sh` 會再印出。
