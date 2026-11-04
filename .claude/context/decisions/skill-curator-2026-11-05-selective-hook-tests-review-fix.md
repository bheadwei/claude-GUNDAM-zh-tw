# hook 測試依改動挑節：審查修正

- 日期：2026-11-05 ・ 作者：skill-curator（worktree，由主模型落檔）
- commit：**668a46e**，接在 6d1e852 之後，分支 `worktree-agent-aa114decd3484e9f2`
- 依據：`../quality/code-quality-specialist-2026-11-05-0100.md`，以及使用者兩項決定（`qa-history/2026-11-05-010000-selective-tests-scope.md`）

## 決策

- **只有模板 repo 自己的 hook 測試會依改動挑節。** 判斷是不是模板 repo，看根目錄有沒有 `scripts/sync-ui-sources.sh`，跟 session-start 用同一個判準。新專案的 `/verify` 維持原樣：最後一個合併跑整套（verify.md 已還原成 e40a70d，只加一小節例外說明）。
- **改到 `run-tests.sh` 時，用 `git diff -U0 --no-renames` 的行號判斷改到哪幾節，只跑那幾節。**
  - 被改的節如果有定義函式，呼叫這些函式的節也一起跑。寧可多跑，不判斷這次改的是不是函式本體。
  - 改到框架或結尾統計時，跑整套。
  - 在 worktree 裡判成要跑整套時，exit 3 拒絕執行，要明確加 `--full` 才跑。
- **起點改由 merge-gate 在第一個合併執行前，寫進 `.merge-round-start`，不再事後讀 `ORIG_HEAD`。**
  - `.gitignore` 加了一行忽略這個檔。
  - 已知副作用：如果合併被其他閘門擋下，起點還是會寫入，結果起點會偏早。偏早只會多測，不會少測。
- **pr.md**：在 worktree 裡，建議先合回主 checkout 再開 PR；如果硬要在 worktree 裡開，要在 PR 說明寫清楚「沒跑整套」。
- **「什麼時候跑整套」只寫在 verify.md。** 其他檔已還原，或只留一句指標。
- **LOW**：
  - 已處理：
    - 加上 `--no-renames`。
    - 部分執行的結尾改寫成「通過數」，避免被抓 `通過 N` 的 regex 誤認成整套結果。
    - 閘門現在認得 `bash -x`、`nohup`、引號包住的路徑。
  - 已知漏抓：用相對路徑執行，或包在 `bash -c` 裡的寫法。

## 驗證

- check-counts `--tests 921`：全部一致。
- 實跑 4 節，171 個案例，全部通過。
- 已驗證：用真實 git repo 測行號對應；在 worktree 裡會 exit 3；加 `--full` 會跑整套。
- 未驗證：
  - 整套。
  - verify.md 新流程實際走一輪。
  - 其他 30 節單獨跑的結果。
  - skill-compliance。
