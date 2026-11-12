# Git 工作流

**收錄判準：只留「每次 git 操作都成立、而且與模型預設行為不同」的約束。**
本檔的歷史（第一版因重述而整檔刪除，commit `7596b1d`）與三道判準見 `writing-extensions` skill。
PR 流程見 `commands/pr.md`、commit 格式見 `coding-style.md`——**不在此重述，也不與它們相左**
（例：「commit → push → PR 不要中途問」不收，`pr.md` 本來就設計成問兩次）。

## 1. 先開分支，再寫程式

收到開發任務的**第一步**——在讀檔、在動任何一行 code 之前：

```bash
git branch --show-current && git status --short
```

四種情況**停下來問使用者**，不要自己決定：在 `main`／`master` 上、
工作區不乾淨、使用者沒指定分支、**已經站在別人正在用的 topic 分支上**（由
`.claude/hooks/lib/branch-switch-gate.sh` 強制）。分支命名 `<type>/<short-description>`，
type 用 commit 那組。

檢查點在這裡而不是 `/pr`：到開 PR 時程式碼已經散在工作區。
**不要用 `git stash` 當替代品**——它沒有名字、沒有歷史，是臨時挪開，不是工作流。

## 2. 動 ref 之前先確認沒被別人推進

同一台機器常有多個 session／worktree 同時在跑。任何 git 寫操作前掃一眼，
出現下列任一項就**停下來問**，不要自己 commit 掉或還原：

- 工作樹有你不認得的變更（你沒碰過那些檔案）
- 同一個 subject 出現不同 SHA（別人已經 commit 過同一件事）
- 分支 tip 與你上次所見不同
- 出現你沒打的 `backup/*` tag、或你沒開的 sibling branch
- `HEAD` 指向你不認得的 commit

模型預設假設「工作區還是我留下的樣子」；多 session 下這個假設是錯的，而且**沒有任何錯誤訊息**。

## 3. Destructive 操作前先打 backup tag（**由閘門強制**）

`git reset --hard`／`git push --force`（含 `--force-with-lease`）／`git branch -D`／`git rebase` 之前
先 `git tag backup/<branch>-<YYYY-MM-DD-HHMM>`。`lib/git-backup-gate.sh` 會擋下沒有快照的指令並貼出
算好的 tag 指令（逃生門 `GIT_BACKUP_GATE=off`）。

## 相關

`commands/pr.md`（PR 唯一來源）・`worktree-orchestration` skill（平行開發的隔離與合併順序）
