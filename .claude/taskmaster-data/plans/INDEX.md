# Plans Index

| ID | 標題 | WBS 任務 | 狀態 | 最後更新 |
|---|---|---|---|---|
| adhoc-2026-06-08 | Agent 協作精準化 + 任務分級自動化 | - | ✅ 完成（5/5 階段） | 2026-06-08 |
| adhoc-2026-09-09-a | handoff 自動歸檔 + 兩個 agent hook 的真 bug | - | ✅ 完成（已歸檔）→ `archive/adhoc-2026-09-09-handoff-auto-archive.md` | 2026-09-09 |
| adhoc-2026-09-09-b | 壓力測試 harness 的三個缺口 | - | ✅ 完成（已歸檔）→ `archive/adhoc-2026-09-09-grader-agent-drift.md` | 2026-09-09 |
| adhoc-2026-09-09-c | git 工作流三條鐵律 + backup tag 閘門 | - | ✅ 完成（已歸檔）→ `archive/adhoc-2026-09-09-git-workflow-rules.md` | 2026-09-11 |
| adhoc-2026-09-11-a | 待驗證清單記目標 ref | - | ✅ 完成（已歸檔）→ `archive/adhoc-2026-09-11-mp-branch-name.md` | 2026-09-11 |
| adhoc-2026-09-11-b | 待驗證清單標記操作類型 | - | ✅ 完成（已歸檔）→ `archive/adhoc-2026-09-11-mp-op-type.md` | 2026-09-11 |

> 09-09 的兩份是**平行開發實測**用的，各自在隔離的 worktree 由 `skill-curator` 實作，
> 依序合併回 main（零衝突，`files:` 判定準確）。
>
> 這個 repo 的 `plans/` 在 `.git/info/exclude` 裡，所以它們是 `git add -f` 強制加入的 ——
> `baseRef: head` 之下 worktree 從本地 HEAD 開分支，未進版控的 plan 帶不進去。

> 09-11 的兩份是 **`conflict-resolver` 的驗證實驗**用的：`files:` 刻意完全重疊、
> 改同一段程式碼但意圖不同，正解是保留雙方。它解對了，並抓到兩件實作者沒發現的事
> （`iconv` 不存在導致 fallback 靜默失效、以及「這兩個任務當初就不該判成可平行」）。
