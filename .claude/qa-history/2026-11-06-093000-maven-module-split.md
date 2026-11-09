# 問答紀錄：Maven 式深層目錄的模組切分

- 指令／情境：恢復 session（地圖計畫階段 1 修復迴圈 R1 進行中）時，處理上個 session 擱置的待決事項
- 日期：2026-11-06

## Q1. 專案地圖遇到 Maven 式深層目錄（`src/main/java/com/acme/...`）時，要不要在後續階段讓它自動處理？

背景：階段 1 實作時發現整棵樹會被併成單一模組，目前要手動在設定寫 `overview.scan.roots`／`depth` 才分得開。

選項：
1. 自動偵測 (Recommended)：偵測 `src/main/java`、`src/main/kotlin` 這類慣例路徑，自動跳過套件前綴再切模組；加在地圖階段 2，多約 2–3 小時，要新增 fixture 測試
2. 維持手動覆寫：不改程式，只在文件寫清楚要設 roots／depth
3. 先不決定：等使用者在專案 A／B 實測後再看

答案：**自動偵測**

## 結論

地圖計畫階段 2 新增 2-D（plan X16）：`overview-scan.sh` 偵測 `src/main/<lang>/` 慣例路徑、剝套件前綴鏈後切模組；有手動 `overview.scan.roots`／`depth` 時不偵測；新增 `maven-multi` fixture。階段 2 12.5h → 15h，合計 48.5h → 51h。
