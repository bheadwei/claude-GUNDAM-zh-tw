# skill-curator 報告：前端風格庫計畫 階段 1（G1、G2、G4）

計畫：`.claude/taskmaster-data/plans/adhoc-2026-10-16-frontend-style-library.md` 階段 1

## G1 — `/verify` 合併驗證關卡獨立

- `commands/verify.md`：「合併驗證關卡」搬出「任務完成銜接」，成為獨立一節
  「合併驗證關卡（不論有沒有進行中任務）」。第 1 步改成「有 plan 才做」，對不到 plan 時
  寫明「無對應 plan，只做收斂檢查」。
- 「任務完成銜接」裡留 `### 0a. 合併驗證關卡` 當指標 —— `commands/worktree.md:118` 與
  `skills/worktree-orchestration/SKILL.md:237` 用「0a. 合併驗證關卡」這個名字引用它，標題保留才不會斷。

## G2 — 指令切段的 heredoc／引號誤判

重現（修前，`post-bash.sh` 實跑）：

| 指令形狀 | 修前 | 修後 |
|---|---|---|
| heredoc commit 後同一條指令真的 merge（10-16 實際形狀） | `[merge] 結束碼非` | `[merge] feat/real` |
| heredoc 內文某行以 `git merge` 開頭 | `[merge] 是這樣用的` | 不記 |
| `git commit -m "說明 git merge foo"` | 記整條指令 | 不記 |
| 跨行單引號字串內某行以 `git merge` 開頭 | 記 | 不記 |
| `git -C /some/path merge feature/x` | `[merge] feature/x` | 同左 |

修法（`hooks/lib/cmd-segments.sh`，唯一來源）：切段前拿掉 heredoc 內文、清空引號內容；
每段去掉 git 全域選項；新增 `cmd_git_subcmd`（git 後第一個非選項字）。
`post-bash.sh` 改用 `cmd_git_subcmd` 判斷子指令，抽 ref 前也先拿掉 heredoc、並要求 op 緊接在 `git`（及其全域選項）之後。

**順帶修到其他三支閘門**（同一份 `cmd_segments`）：`git-backup-gate.sh`、`merge-noff-gate.sh`、
`branch-switch-gate.sh` 現在也不會被 heredoc／引號內文誤觸發。這三支的檔案本身沒改。

**沒做到的**：`git-backup-gate.sh` 仍用 `cmd_match` 看整段任何位置判斷 `reset`／`push`／`branch`。
引號清空後實務上已很難誤觸（剩 `git log --grep reset --hard` 這類不合理的指令），
但若要完全照計畫「子指令只看第一個非選項字」，要改 `git-backup-gate.sh`，它不在階段 1 的 `files:`。

## G4 — quick 模式的 debug-investigator 報告假警報

`hooks/post-agent-report.sh`：啟動當下讀 `$WORK_CLAUDE/taskmaster-data/.current-task-mode`，
`quick` → `AREA=""`，`context-reports.log` 寫 `SKIP: debug-investigator quick 模式不寫報告`。

## 測試

`hooks/tests/run-tests.sh` 新增 16 條（post-bash 8、失敗事件 1、backup gate 3、post-agent-report 4）。（394 → 410，全過）

## 行為驗證

hook 改動由 run-tests 釘住。`verify.md` 的改動是給模型讀的文字 —— **未驗證行為改變**
（計畫列為人工驗收：無 `.current-task`、`.merge-pending` 一筆、跑 `/verify`）。
