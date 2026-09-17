# Git 工作流

**收錄判準：只留「每次 git 操作都成立、而且與模型預設行為不同」的約束。**

## 為什麼這次只有三條（先讀這段再往下加東西）

**這個檔名曾經存在，並在 commit `7596b1d`「消除跨層重複」時被刻意刪除。**
舊檔只有兩節，兩節都是重複：commit message 格式（已併進 `coding-style.md`）、
Pull Request 流程（已被 `commands/pr.md` 取代，而且 pr.md 寫得更好——
它連「`git diff base...HEAD` 務必用三個點」的理由都解釋了）。

所以本檔的唯一來源邊界是：

| 內容 | 唯一來源 | 本檔的做法 |
|---|---|---|
| commit message 格式 | `.claude/rules/coding-style.md` | 不重述 |
| PR 流程・PR 內容骨架・開 PR 前的問答 | `.claude/commands/pr.md` | 不重述、**也不與它相左** |

「commit → push → PR 一氣呵成、禁止中間問要不要 push」這條**刻意不收**：
`commands/pr.md` 步驟 2、3 本來就設計成用 `AskUserQuestion` 確認兩次，
而 `interactive-qa.md` 規定所有決策點都必須這樣問。收它進來會讓 rules/ 出現
一條禁止另外兩份文件所要求的行為。

要往本檔加內容前先問兩題：**模型本來就會做了嗎？**（會 → 只是稀釋注意力）
**別處已經有唯一來源了嗎？**（有 → 寫指標，不要抄一份）

## 1. 先開分支，再寫程式

收到開發任務的**第一步**——在讀檔、在動任何一行 code 之前：

```bash
git branch --show-current && git status --short
```

四種情況**停下來問使用者**，不要自己決定：在 `main`／`master` 上、
工作區不乾淨、使用者沒指定分支、**已經站在別人正在用的 topic 分支上**（**由
`.claude/hooks/lib/branch-switch-gate.sh` 強制**）。分支命名 `<type>/<short-description>`，
type 用 commit 那組（`feat` `fix` `refactor` …）。

**為什麼檢查點在這裡**：`/pr` 也會擋「在 main 上開 PR」，但那是**程式碼已經寫完
之後**，那時要補開分支就得先處理散在工作區的改動。
**不要用 `git stash` 當替代品**——stash 沒有名字、沒有歷史、下一次 stash 就疊上去。
它是臨時挪開，不是工作流。

## 2. 動 ref 之前先確認沒被別人推進

同一台機器常有多個 session／worktree 同時在跑。任何 git 寫操作前掃一眼，
出現下列任一項就**停下來問**，不要自己 commit 掉或還原：

- 工作樹有你不認得的變更（你沒碰過那些檔案）
- 同一個 subject 出現不同 SHA（別人已經 commit 過同一件事）
- 分支 tip 與你上次所見不同
- 出現你沒打的 `backup/*` tag、或你沒開的 sibling branch
- `HEAD` 指向你不認得的 commit

**為什麼**：模型預設假設「工作區還是我留下的樣子」。多 session 下這個假設是錯的，
而且錯的時候**沒有任何錯誤訊息**。2026-09-09 真的發生過一次，靠「我記得開始時
工作區是乾淨的」才察覺，純屬運氣。

## 3. Destructive 操作前先打 backup tag（**由閘門強制**）

`git reset --hard`／`git push --force`（含 `--force-with-lease`）／`git branch -D`／
`git rebase` 之前，先讓當前 HEAD 有一個 ref 指著它：

```bash
git tag backup/<branch>-<YYYY-MM-DD-HHMM>
```

**這條不靠自律。** `.claude/hooks/lib/git-backup-gate.sh` 會擋下「沒有安全快照」的
destructive 指令，並把算好的 tag 指令貼給你；打完 tag 重試同一條指令即通過。
`--force-with-lease` **不例外**——它防的是覆蓋別人的 push，不是防你弄丟自己的工作。
（逃生門：`GIT_BACKUP_GATE=off`）

## 相關

- `.claude/commands/pr.md` — PR 流程唯一來源（前置檢查、PR 內容骨架、署名）
- `.claude/rules/coding-style.md` — commit message 格式
- `.claude/hooks/lib/branch-switch-gate.sh` — 第 1 條第四種情況的閘門實作
- `.claude/hooks/lib/git-backup-gate.sh` — 第 3 條的閘門實作
- `worktree-orchestration` skill — 平行開發的狀態隔離邊界與合併順序
