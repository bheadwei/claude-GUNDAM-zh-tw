# 執行帳本 — plan: .claude/taskmaster-data/plans/adhoc-2026-11-09-overview-readability.md

- 執行方式：逐階段派 implementer（使用者 2026-11-09 選定）
- 使用者已決定：完成的 plan 只顯示階段不算改動；本次是猜的時工作區改動不分給任何 plan；`--actual` 例外照收

## 階段 1: 產生器——完成的 plan 不算改動、改動只歸本次、計畫外收成一行
- 2026-11-09 17:30 派工 implementer（opus）｜BASE=a07b828
- 2026-11-09 17:50 回報 DONE_WITH_CONCERNS｜commit=d8ec41d、fd10089｜測試 411/414（3 敗為既有：無 jq ×2、--notes-todo 排序）｜index.html 62603→63167
- 2026-11-09 17:52 Ruling: 卡片下方檔案表格仍逐列列出計畫外檔，違背「收成一行」的目的；修復輪一併拿掉表格裡的計畫外列（已在 details 內） — 使用者抱怨的就是整頁讀不下去 — 若錯，計畫外檔的 +/- 行數只能從 overview.md 看
- 2026-11-09 17:52 派審查 code-quality-specialist｜範圍=a07b828..fd10089
- 2026-11-09 18:05 使用者決定 index.html 上限 64KB→80KB；主模型改 check-counts.sh 並寫 ADR-2026-11-09-001，plan files: 加 check-counts.sh｜commit 見 git log
- 2026-11-09 18:06 審查 R1：PASS（0 CRITICAL／0 HIGH／2 MEDIUM／1 LOW）
- 2026-11-09 18:06 Ruling: MEDIUM「worktree 的 .current-task 指到、overlay 卻選了主 checkout 版 → 本次卡拿不到改動」一併修，改成檔名相同、任一來源指到就算 — 使用者的 smartwork 大量用 worktree 平行 — 若錯，同名 plan 在兩邊都動時會把 worktree 改動顯示在主 checkout 版卡上
- 2026-11-09 18:06 Ruling: LOW「本次 plan 全 ✅ 後不列改動」照計畫保留 — 使用者選了完成就只顯示階段 — 若錯，/verify 前看不到本次改動，可從地圖「本次改動」看
- 2026-11-09 18:07 修復 R1 派工（同一 implementer）：表格拿掉計畫外列、worktree 本次比對、stub 欄位斷言
- 2026-11-09 18:20 修復 R1 回報 DONE_WITH_CONCERNS｜commit=45dec49｜測試 413/416（3 敗同前，既有）｜index.html 63256
- 2026-11-09 18:22 主模型驗修復（截圖 tasks-r1-open.png：表格只剩計畫內 1 列；diff 27+/9-）；只剩 MEDIUM 已修、不加審查輪
- 2026-11-09 18:22 審查通過（規格 ✅ 品質 ✅）｜範圍=a07b828..45dec49
- 2026-11-09 18:22 階段完成 → plan 標 ✅，current_phase=2｜摘要=完成的 plan 不算改動、改動只歸本次、計畫外收成一行｜測試=413/416

## 階段 2: 任務圖目錄
- 2026-11-09 18:25 派工 implementer（sonnet）｜BASE=1ef199b
- 2026-11-09 18:45 回報 DONE｜commit=7a4d20d｜7 條驗收量測全過（第 10 列捲動 -0.5px、390px scrollWidth=innerWidth、重繪 scrollTop 777→777）｜index.html 63256→64637
- 2026-11-09 18:46 主模型看截圖 wide-dark／narrow 確認；派審查 code-quality-specialist｜範圍=1ef199b..7a4d20d
- 2026-11-09 18:55 審查通過（規格 ✅ 品質 ✅，0 CRITICAL／0 HIGH／2 MEDIUM／3 LOW）｜範圍=1ef199b..7a4d20d
- 2026-11-09 18:55 Ruling: MEDIUM（輪詢重繪丟目錄焦點與內層捲動、修飾鍵點擊被攔）記技術債不加輪 — 只在 data.js 重產時重繪、驗收要求的 #tv.scrollTop 已保留 — 若錯，手機上每次重產後目錄橫向捲動歸零
- 2026-11-09 18:55 階段完成 → plan 標 ✅，current_phase=3｜摘要=任務圖左側目錄，點了跳到該計畫卡｜測試=7/7

## 階段 3: 地圖可選計畫
- 2026-11-09 18:57 派工 implementer（opus）｜BASE=9b84fc2
- 2026-11-10 09:10 回報 DONE_WITH_CONCERNS｜commit=1902706, feb86d5｜run-tests --changed 9b84fc2 通過 416／失敗 3（皆既有失敗）｜index.html 67021 bytes
- 2026-11-10 09:10 Ruling: 疑慮 2（預設選取含已 ✅ 的 current plan、抽屜卻不列它）接受不改 — 為了讓預設畫面跟改版前完全一致，且 /verify 會清掉 .current-task — 若使用者覺得「選計畫（N）」數字對不上抽屜，再改成只算未完成的
- 2026-11-10 09:10 Ruling: 疑慮 1（390px 選計畫鈕在圖例列最右、要滑才看得到）沿用既有手機版行為 — 不擴範圍 — 實機截圖若使用者覺得找不到再調
- 2026-11-10 09:20 審查 PASS（MEDIUM 1、LOW 2）｜報告 context/quality/code-quality-specialist-2026-11-10-0915.md
- 2026-11-10 09:25 Ruling: MEDIUM（「只選本次」設成固定 file、current 已 ✅ 或換 .current-task 時跟預設不同）主模型直接修，改走 PSEL=null 預設路徑 — 一行、且是 09:10 裁決帶出的後果 — 無｜commit=27f2b9d｜playwright 驗：預設 svc-a、清除空、只選本次回 svc-a、全選 4
- 2026-11-10 09:25 Ruling: 兩個 LOW（psel 消失時 aria-expanded 殘留、stub 測試只驗型別）不修 — 既有 header 按鈕同樣寫法、內容由 shop 案例涵蓋 — 技術債
- 2026-11-10 09:25 審查通過（規格 ✅ 品質 ✅）｜範圍=9b84fc2..27f2b9d
- 2026-11-10 09:25 階段完成 → plan 標 ✅，status=✅ 完成｜摘要=地圖可選計畫，虛線框與預計但沒動讀選取聯集｜測試=416/419（3 既有失敗）
