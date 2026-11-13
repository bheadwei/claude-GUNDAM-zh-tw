# 專案地圖改版計畫的決策（2026-11-12）

計畫：`.claude/taskmaster-data/plans/adhoc-2026-11-12-overview-live.md`

## Q1 頁面大小（改版後估 84–86KB，超過 80KB 上限）
- 選項：拆出 now.js (Recommended)／提高上限寫新 ADR／砍功能壓回 80KB
- 使用者先問「沒有技術上限問題為什麼要限」；說明 80KB 是防膨脹護欄後再問一次
- 選項：不拆檔，上限提高到 128KB (Recommended)／不拆檔，拿掉上限／拆出 now.js
- 答案：不拆檔，上限提高到 128KB

## Q2 即時資料放哪
- 選項：獨立的 live.js (Recommended)／放進 data.js
- 答案：獨立的 live.js

## Q3 本機伺服器生命週期
- 選項：閒置 30 分鐘自動結束 (Recommended)／常駐手動關／跟著 session 結束
- 答案：閒置 30 分鐘自動結束

## Q4 非 VS Code 終端機時是否自動開瀏覽器
- 選項：新起伺服器時自動開 (Recommended)／只印網址
- 答案：新起伺服器時自動開

## Q5「人在做」怎麼認出使用者自己
- 選項：比對 git 使用者名稱 (Recommended)／在 project.json 指定
- 答案：比對 git 使用者名稱

## Q6「今天完成」算什麼
- 選項：今天結束的 agent 數 (Recommended)／今天標 ✅ 的 WBS 任務數
- 答案：兩個都要

## 結論
不拆檔、上限 128KB（新 ADR 取代 ADR-2026-11-09-001）；即時資料獨立成 live.js；伺服器閒置 30 分鐘自行結束、新起時自動開瀏覽器；「我」由 git user.name／email 比對；「今天完成」同時顯示 agent 數與 WBS 任務數。
