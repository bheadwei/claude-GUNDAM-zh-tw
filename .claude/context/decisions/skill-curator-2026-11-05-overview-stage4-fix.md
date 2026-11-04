# 專案圖解 — 階段 4 審查修正

- 日期：2026-11-05
- 作者：skill-curator（worktree），由主模型落檔
- 分支：`worktree-agent-a9b301618fae8815c`，merge commit 871141a（把階段 4 接進來）之後是 **af41300**
- 依據：`../quality/code-quality-specialist-2026-11-04-2300.md`

## 修正內容

1. **[HIGH] 標記不成對**
   - 新增 `actual_markers_bad`：區塊標記只接受兩種情況——完全沒有，或 start、end 各一行且 start 在前。
   - 這個檢查在啟動時（不合格 exit 2）和寫入前（不合格 exit 1）各做一次，不合格就不寫。錯誤訊息會指出位置和修法。
   - `parse_plan` 也改成同一套判斷。plan-format 補上這條規則。
2. **[HIGH] worktree 帶著舊 plan 副本**
   - worktree 裡的 plan，只收有改動（含 staged）或不在版控裡的檔。
   - 例外：`--actual` 指定的那一份一定收。
   - 這條取代 stage4 決策紀錄第 9 項的第二點。
3. **[MEDIUM]** `LOCK_STALE_SEC` 從 60 改成 120；`--actual` 的等待時間維持 60 秒。
4. **[MEDIUM]** planner.md 和 implementer-prompt.md 原本抄了規則，改成指向唯一來源。
5. 測試數 901 → 907。新增 6 個，其中 5 個是修改前先跑失敗、修改後才通過；overview 節 95/95。check-counts `--tests 907` 跑 714 項，全部一致。

## 待處理

- 第 2 點的規則是「相對 worktree 的 HEAD 有改動」才收。worktree 一旦把 plan commit 到自己的分支，這份 plan 就會從任務圖消失。平行開發時，implementer 每完成一個階段都會 commit，所以這等於 overlay 會失效。
- 主模型已請同一個 agent 改成「相對 merge-base 有改動」。

STATUS: DONE_WITH_CONCERNS

## 補修（066855a，已完成）

- worktree 裡的 plan 只在以下三種情況才收：
  - 在 merge-base（worktree 的 HEAD 與主 checkout 的 HEAD 的共同祖先）之後動過，包括 commit、staged、工作區的改動。
  - 沒進版控。
  - 是 `--actual` 指定的那一份（這份一定收）。
- 算不出 merge-base 時，改用 HEAD 比較。
- 新增測試「worktree 改了 plan 並 commit 到自己的分支 → 仍在 plans[]」：修改前失敗，修改後通過。原本的「沒動過的舊副本不收」測試也仍然通過。overview 那一節 96/96。
- 測試數 908，check-counts 714 項全部一致。
- 這次的說法取代 stage4 決策紀錄第 9 項的第二點。
