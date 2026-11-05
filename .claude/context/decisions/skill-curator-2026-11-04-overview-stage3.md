# 專案圖解 — 階段 3（專案地圖）決策紀錄

- 日期：2026-11-04
- 作者：skill-curator。它在 worktree 裡工作，這份由主模型落檔。
- 依據：
  - `skill-curator-2026-11-04-visual-overview-proposal.md`（第 3–6、12 節）
  - `skill-curator-2026-11-04-overview-spike.md` 第 2 節
  - `../quality/code-quality-specialist-2026-11-04-1130.md`
- Commit：fdc5ff0、062372d、773948e（分支 `worktree-agent-a6213f33362eedc86`）

## 照提案做的

- **用到的層**：
  - Script：`overview.sh`
  - Hook：`post-write` 第 ④ 段，不輸出任何內容
  - Command：`task-status` 第 7 步
  - 沒有新增 hook 檔、skill、command、rule，`settings.json` 沒動。
- **照階段 1 實測報告選定的寫法**：
  - 背景啟動寫成 `( nohup bash … </dev/null >/dev/null 2>&1 & )`，工作目錄用參數傳。
  - 主 checkout 用 git common dir 自己算。
  - `data.js` 是單一一句賦值，先寫暫存檔再 `mv`。
  - 輪詢帶 `?t=`；載入前先設成 `null`，用來判斷檔案寫到一半；只在 `generatedAt` 改變時重畫；分頁不在前景時暫停。
- **處理審查交代的事**：
  - 讀到 `<!-- overview: draft -->` 時不出地圖，notices 和畫面都標示「架構草稿」。
  - 產生的 mermaid 箭頭兩端留空格，有測試。
  - 欄名常數的一致性加進 check-counts。
- **不用改的地方**：
  - copy-template／update-template 四支腳本：`.claude/scripts` 和 `.claude/templates` 本來就在同步範圍，`taskmaster-data/` 已經排除或保留。
  - 根目錄 `.gitignore`：`overview/.gitignore` 的內容是 `*`。

## 跟提案字面不同、或提案沒寫到的地方

1. **「本次改動」的資料**
   - `data.js` 頂層多了 `changes[]` 和 `changesBase`；模組多了 `changed`、`pos`、`declared`、`shape`。
   - 理由：使用者確認的畫布有「本次改動清單」，但提案的 schema 只把 changes 放在 `plans[]` 底下，那屬於階段 4。
   - 階段 3 的「本次改動」包含三種：分支從預設分支分出後的改動、還沒 commit 的改動、還沒追蹤的新檔。`.claude/` 底下的不算。
   - 「改了什麼」目前只顯示 +/− 行數。AI 寫的摘要要等階段 4 改完帳本格式才有。
2. **版面由腳本決定**
   - 依 5.1 的 subgraph 順序排欄，群組內再依連線深度分子欄，每欄最多 4 列，結果寫成 `pos:{col,row}`。
   - 畫面只負責換算成像素，節點不能拖。
3. **overview.md 不放「本次」標記，也不放改動清單**
   - 原因：`.current-task` 和工作區的改動都不進 git，放進去的話 md 就不再是確定性輸出（見提案 3.2）。
   - 「本次」只出現在 `data.js` 和畫面上。
4. **畫面不載 Google Fonts**：正式版不准用 CDN，所以改用系統字型。
5. **拿不到鎖時**
   - 留下 `.dirty`，由持鎖的那支做完後再跑一輪，最多 3 輪。
   - 如果 `.dirty` 在持鎖者最後一次檢查之後才寫入，要等下一次觸發才會補上。這個情況有測試覆蓋。
6. **hook 多一道前置條件**
   - 主 checkout 或 worktree 有 `project.json` 才啟動，所以模板 repo 本身不會開任何行程。
   - 觸發範圍多加了 `taskmaster-data/project.json`，因為 mode 改了要重算。
7. **check-counts 的大小上限用 50KB**
   - 使用者說 50KB，提案寫的是 80KB 護欄，這裡照使用者的說法。
   - 另外加了兩條：不准 module script、不准外部 `src`/`href`。
8. **jq 失敗時**：保留上一份 `data.js`，錯誤寫進 `overview/.last-error`。

## 已知限制（交給後續階段）

- **從 worktree 觸發時**：讀的仍是主 checkout 的資料，worktree 的進度不會出現在地圖上。這是階段 4 的 worktree overlay 要處理的。
- **屬於階段 5 的**：`archivedDone`、大小上限與 `truncated` 的完整策略。目前只先把 `changes` 截在 200 筆。
- **hooks.log**：post-write 那一行還沒記 `agent_type`，因為每次寫檔都要多開一個 jq 行程。
- **resolve-roots.sh**：在 `claude -w` 裡會把 worktree 當成主 checkout，這個既有缺陷這次沒修。`overview.sh` 自己算主 checkout，不受影響。

## 驗證

- `run-tests.sh`：通過 859、失敗 0。新增 47 個，涵蓋提案的 21 項驗收，另加 6 項。
- `check-counts`：713 項中 712 項一致，差在根目錄 `README.md` 還寫 812，由主模型修正。
- 瀏覽器：Chrome 156、Edge 156 實測過，項目有開啟、縮放分層、滾輪縮放錨點、雙擊聚焦、`Esc`、篩選、輪詢、寫到一半、分頁不在前景、草稿。
- 未驗證：
  - Firefox、VS Code、真實切換分頁。
  - 在真的 Claude Code session 裡走一遍端到端。
  - 模型會不會主動去 Read `data.js`（沒跑 skill-compliance）。
- 速度：產生器在這台機器要 4.5–6 秒，所以從寫入到重畫最多要「產生器時間＋3 秒」，比提案寫的 8 秒長。

STATUS: DONE_WITH_CONCERNS
