# 改動 B 範圍：是否搭配 Floorplan

時間：2026-11-04

## Q1：Floorplan 和改動 B 有一半重疊，B 的範圍要怎麼定？

選項：
- 縮小 B，搭配 Floorplan (Recommended)
- 照原計畫做完整 B（自建 overview-viewer.html）
- 先裝 Floorplan 試用再決定

答案：縮小 B，搭配 Floorplan

## 結論

程式碼地圖交給 Floorplan（模板文件推薦安裝，不強制）。B 只做 plan 的「一眼看懂」mermaid＋對照表（進版控）與 `/verify` 計畫 vs 實際；取消自建互動 viewer。借用「虛線＝計畫」「改動附對應需求」兩個做法。

## 更新（同日，使用者重新釐清需求後）

需求改為兩層：①專案架構圖帶模組燈號 ②任務 plan 圖帶燈號＋這次 AI 改了什麼；要互動。前一個「縮小 B」結論作廢。

### Q2：方向（A 自己做完整／B 疊在 Floorplan 上／C 兩層分開）
答案：先看圖再說 → 預覽 https://claude.ai/artifact/LLt7shnsmF4uwDqtzU7DjM

### 使用者回覆（非選擇題）
- 要能自動更新
- 先把架構文件整理出來，再處理專案地圖
- 關心 token 成本 → 說明：腳本產生、0 token

### Q3：形式
選項：md 正本＋一個互動 html (Recommended)／只要 md／還有問題要討論
答案：md 正本＋一個互動 html

## 結論（目前）
md 正本進 git；整個專案一個互動 html，資料檔分離、自動更新；先定 docs/architecture.md 格式。B 仍未開工。

### Q4：模組與 WBS 任務的對應
使用者先指出架構格式已在 project-docs 05 範本、由 architect／documentation-specialist 處理。
選項：用路徑自動推 (Recommended)／WBS 加一欄「模組」／兩個都用
答案：兩個都用（WBS 標模組＋路徑比對，不一致時標出）

### 使用者回覆
- html 不進 git 沒關係，問放哪 → 建議 `.claude/taskmaster-data/overview/`（自帶 `*` 的 .gitignore、MAIN_CLAUDE）
- 舊專案無架構文件：照建議（documentation-specialist 反推草稿、確認後才產地圖）

### Q5：下一步
選項：先寫設計提案給我看 (Recommended)／直接開工／位置想換
答案：先寫設計提案給我看

### 設計提案待確認 8 項（提案：context/decisions/skill-curator-2026-11-04-visual-overview-proposal.md，Artifact https://claude.ai/artifact/2MB2ZgS9DH7Hgt3ZfHRYwo）
- 使用者先釐清：index.html 是固定畫面、讀 data.js 在瀏覽器畫圖；overview.md 由腳本產生
- #1 先進 git，用一週再決定
- #2、#3 OK
- #4 architect 加 Edit
- #5、#6 OK
- #7 OK；#8 疑慮效能 → 說明 data.js 只在事件時重產、瀏覽器只讀本機小檔 → 選「3 秒＋分頁不在前景時暫停」
