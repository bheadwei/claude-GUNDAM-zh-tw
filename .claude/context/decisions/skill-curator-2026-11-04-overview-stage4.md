# 專案圖解 — 階段 4（任務圖）決策紀錄

- 日期：2026-11-04
- 作者：skill-curator。它在 worktree 裡工作，紀錄由主模型落檔。
- 分支與 commit：`worktree-agent-a3815b739b72befaf`，從 e40a70d 開出。commit 為 4b42237（任務圖、`--actual`、overlay、測試）和 16bf2b6（接線，測試數 869 → 901）。
- 驗證：
  - check-counts `--tests 901`：714 項全部一致。之後 index.html 又改了一行，改完沒有重跑。
  - overview 那一節測試：通過 89、失敗 0（新增 32 個）。
  - 整套測試沒跑：使用者要求等全部改完再一起跑。
  - Edge 實測任務圖分頁：沒有 JS 錯誤。index.html 為 33,303 bytes。

## 改了哪些檔

- `scripts/overview.sh`：新增任務圖、`--actual`、worktree overlay。部件表的欄名常數是 `OVERVIEW_COLS_PART`。jq 輸出兩行：data.js 疊上 worktree 的資料，overview.md 只看主 checkout。
- `templates/overview/index.html`：新增「專案地圖｜任務圖」分頁（`#tasks`）、AI 摘要、標出改動來自哪個 worktree，以及同時有多個「本次」。
- `plan-format` skill：新增「一眼看懂」與「計畫 vs 實際」兩節（這兩節以此為唯一來源）。planner 和 `/plan` 用指標指過去。
- `subagent-execution`、`implementer-prompt.md`：帳本加 `摘要=`、`測試=`；新增「部件 pN 完成」行。
- `commands/verify.md`：新增「寫回 plan 的『計畫 vs 實際』」一節。
- `worktree-orchestration`：邊界表補上 overlay。
- `check-counts.sh`：部件表的欄名常數要和 plan-format 的表頭一致。

## 跟提案不同的地方

1. 部件表第一欄叫 `id`，不叫 `部件 id`。欄名常數用空白分隔，欄名不能含空白，而且這樣和 05 範本的模組表一致。
2. diff 範圍包含還沒 commit 的改動和新檔。主模型常常最後才 commit，只看已 commit 的會漏掉。
3. 沒有 `.current-task` 時，「本次」取狀態為 ⏳ 或 🔄、而且最近修改過的 plan。這時標 `guessed:true`，畫面顯示「（推測）」。
4. 「本次」改成 `currents[]` 陣列。原本的 `current` 保留，值是陣列第一個。
5. overview.md 有任務圖，但只反映主 checkout，而且不放「本次」標記。
6. 找不到預設分支時，plan 的比較基準是 null：changes 為空，並出一則 notice。
7. `counts.archivedDone` 只算已經從 WBS 移走的任務。階段 5 把 wbs-archive 算進來時，要依任務編號去重。
8. `--actual` 的規則：
   - FAIL 沒附原因時 exit 2，不寫入。
   - 拿不到鎖時最多等 60 秒。
   - 第一次接在檔尾，之後原地取代。
   - 判斷檔案在主 checkout 還是 worktree，是比對 git-dir 和 common dir，不比對路徑字串。原因是 8.3 短檔名（例如 `KUANWE~1`）會讓同一個路徑比對成不相等。
9. worktree 的取捨：
   - 同名 plan 依序比「完成階段數 → 有沒有驗證結果 → 修改時間」，勝出的用 worktree 的版本；內容和主 checkout 完全相同時，算主 checkout 的。
   - 既沒有 plan、也沒有 `.current-task` 的 worktree 不列出。

## 已知限制

- 計畫外的部件最多列 30 個，其餘只記 `extraMore` 數量。
- `files:` glob 對到模組的方式是把萬用字元換成實際字元再比對，可能多算，不會漏算。
- `--actual` 用 Bash 寫入 plan，所以不會觸發 post-write，改由腳本自己重產圖解。

## 未驗證

- 整套 `run-tests.sh`。
- 手動驗收 [M]：真的跑一輪 `/plan → /tdd → /verify`，看部件從虛線依序變實線。
- planner 和主模型會不會照新格式寫「一眼看懂」和帳本的 `摘要=`。沒照寫時，任務圖只會列出改了哪些檔，畫不出部件，也不會報錯。
- 任務圖分頁在 Firefox 和 VS Code 裡的表現。
- 由 `/verify` 呼叫 `--actual` 的完整流程（目前只直接跑腳本測過）。

STATUS: DONE_WITH_CONCERNS
