# 問答紀錄：專案地圖改以程式碼為準（ADR-2026-11-05-001～003 待決問題）

時間：2026-11-05 15:30 前後
來源：architect 報告 `architect-2026-11-05-1500.md` 文末 7 題

## Q1 寫模組說明時程式碼片段會經 Claude Code 送到 Anthropic；按需、每次由 /task-status 問、可設 overview.notes: off 關閉，可以嗎？
- 選項：可以（Recommended）／預設關閉／不要說明層
- 答案：**可以**

## Q2 module-notes.md 要進 git 嗎？
- 選項：進 git（Recommended）／不進 git
- 答案：**進 git**

## Q3 實測專案的語言與結構（只要結構特徵）
- 選項：Python 後端＋JS/TS 前端／C# .NET 為主／Java 為主
- 答案：**Python 後端＋JS/TS 前端**（backend/ 與 frontend/ 分開）

## Q4 SSH 遠端伺服器上畫面怎麼開？
- 選項：維持 VS Code 轉送（Recommended）／加「匯出單一 html」
- 答案：**維持 VS Code 轉送**（不加新功能，只在文件寫明怎麼開）

## Q5–Q7 寫程式碼檔時背景重掃（30 秒節流）／codegraph 先不做／主題跟隨系統＋手動切換
- 選項：三項都照建議（Recommended）／有項目要改
- 答案：**三項都照建議**

## 結論
三份 ADR 的待決問題全部定案，依建議方案採用。交給 planner 拆階段計畫。
