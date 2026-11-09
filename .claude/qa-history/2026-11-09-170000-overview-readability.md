# 專案圖解可讀性問答（2026-11-09）

背景：以 smartwork_for_KM 為案例，任務圖「計畫外」灌滿（.gitignore、11.38 的 170 個檔），任務多時難找，地圖「plan 預計會動」只標一份 plan。

## Q1 已完成（✅）的 plan 任務圖上怎麼顯示改動？
- 選項：只顯示階段，不算改動 (Recommended)／算到完成那一刻／收合到最下面
- 答案：只顯示階段，不算改動

## Q2 開分支與範圍
- 選項：fix/overview-readability 三項都做 (Recommended)／先只修 A／先不動工
- 答案：fix/overview-readability 三項都做

## 結論
開 `fix/overview-readability`，standard 模式，三階段：A 修計畫外歸屬（完成 plan 不算改動、無帳本 plan 不分未 commit 改動、計畫外收成一行）→ B 任務圖目錄 → C 地圖可選計畫。
