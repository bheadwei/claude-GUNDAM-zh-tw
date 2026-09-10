# 決策：從 claude-Godzilla-z 採納 git 工作流的四條鐵律

**日期**：2026-09-09
**狀態**：已決定，**尚未實作**（等平行開發的兩個 worktree 合併完才動手）
**來源**：`D:\模板\claude-Godzilla-z`（github.com/Zenobia000/claude-Godzilla-z，HEAD `0b5267b`）

## 背景

使用者 pull 了另一套模板，指名要看它的 `rules/git-workflow.md`、
`skills/sunnydata-branch-lifecycle`（含 `references/git-conventions.md`、
`references/worktree-setup.md`）與 `skills/sunnydata-parallel-agents`。

我們這邊的現況：**沒有任何 git 工作流的常駐規範**。
`rules/` 只有 5 條（agent-orchestration、coding-style、interactive-qa、security、task-mode），
commit 格式在 `coding-style.md`、PR 流程在 `commands/pr.md`（唯一來源）。
`ch1_introduction.md` 曾引用的 `rules/git-workflow.md` 早已不存在。

## ⚠️ 修正（同日）：四條變三條 —— 這個檔名曾經被刻意刪除

**使用者指出「我記得之前有 git-workflow 這個 rule，後來因為重複打架被刪掉」。查證後他是對的，
而本 ADR 的初版漏了這件事。**

`.claude/rules/git-workflow.md` 從 init 就存在，在 **commit `7596b1d`**
（2026-09-07，「refactor: 消除跨層重複，常駐 context 524 → 496 行」）被刪除。舊檔只有兩節：

| 舊內容 | 處置 |
|---|---|
| `## Commit Message 格式` | 併進 `rules/coding-style.md`（8 行，並在檔內寫下「為什麼刻意留在常駐」） |
| `## Pull Request 流程`（5 步） | **刪除** —— `commands/pr.md` 取代且更好 |

刪除理由原文：

> **PR 那半已被 `/pr.md` 取代，而且 `/pr.md` 更好**。rule 只寫「使用 `git diff [base]...HEAD`」，
> pr.md 連「務必用三個點，兩個點會把 base 分支的新 commit 也算進來」都解釋了。
> 而 pr.md 第 7 行還寫著「git-workflow.md 早就定義了 PR 流程，本指令是它的執行入口」
> —— **方向是反的**

### 對本決策的影響

三條是真的新的（舊檔完全沒有）：**先開分支**、**多 session ref 驗證**、**backup tag**。

**第 4 條「commit → push → PR 為單一連貫操作」撤回** —— 它正是當初被刪掉的那個類別，
而且不只是重複，是**三方直接矛盾**：

| 來源 | 說什麼 |
|---|---|
| `commands/pr.md` 步驟 2、3 | 刻意用 `AskUserQuestion` 問**兩次**（要不要先跑把關、草稿確認） |
| `rules/interactive-qa.md:5` | 所有決策點**必須**用 `AskUserQuestion`，一次一題 |
| Godzilla-z 第 4 條 | **禁止**在中間插入「要不要 push？」 |

Godzilla-z 能有那條，是因為**它沒有 `interactive-qa.md` 這一層**。它的哲學是
「使用者說做完了就一氣呵成」，我們的是「一次一題問清楚」。單獨把那條搬過來，
會讓 `rules/` 出現一條禁止其他兩份文件所要求的行為。

### 教訓（比這個決策本身更值得記）

**採納外部模板的單一條文之前，要先查這個檔名／這個主題在本 repo 的歷史。**
`git log --all --diff-filter=D -- <path>` 一行就能查到。本 ADR 初版評估了
Godzilla-z 的內容、也比對了我們**當前**的檔案，但沒查**刪除紀錄**——
而「曾經有、後來刻意移除」正是最需要知道的那種資訊。

新的 `rules/git-workflow.md` 檔頭要寫下這段歷史，讓下一個想補 PR 內容進來的人先看到警告。

---

## 原始決定（四條鐵律，新開 `.claude/rules/git-workflow.md`）

> 第 4 條已依上方修正撤回，保留原文供對照。

1. **先開分支** —— 收到開發任務的第一步跑 `git branch --show-current` + `git status`；
   在 main 上、工作區 dirty、或使用者沒指定分支就要改 code → 停止並詢問
2. **多 session ref 驗證** —— 任何 git 寫操作前確認 ref 沒被別的 session 推進
3. **destructive 前置** —— `reset --hard`／`push --force`／`branch -D`／`rebase` 之前先打
   `backup/<branch>-<YYYY-MM-DD>` tag
4. **commit → push → PR 為單一連貫操作** —— 使用者說「做完了」就一氣呵成，
   禁止中間插入「要不要 push？」

**細則不另開 skill**，全部推給既有的 `commands/pr.md`（PR 唯一來源）與
`coding-style.md`（commit 格式）。Godzilla-z 用 skill + references 兩層放細則，
我們不照抄——我們的 PR 細則已經有唯一來源，再開一層會漂開。

### 第 3 條要做成 hook，不是文字規則

打 backup tag 是**純機械動作、零判斷**，而 `pre-tool-use.sh` 已經在攔 Bash 指令。
照本專案既有決策「自動化一律做成 hook，指令要人記得打」，這條該由閘門自動打 tag
或擋下來。Godzilla-z 寫成 rule 是因為**他們沒有 hook 層**。

> `pre-tool-use.sh` 已有 4 道閘門，是最複雜的一支。CLAUDE.md 要求再加就拆 lib ——
> 照 `merge-gate.sh` 的先例做成 `lib/git-backup-gate.sh`。

## 連帶採納：`writing-extensions` 的收錄判準要補一句

Godzilla-z 的 `git-workflow.md` 開頭寫：

> 本檔只留**每次 git 操作都成立、而且與模型預設行為不同**的約束。

「**與模型預設行為不同**」這半句比我們 `writing-extensions:26` 的判準
（「任何任務都適用，且不長」）鋒利。我們現在只問「適用範圍多廣」，
沒問「模型本來就會做了嗎」——常駐 rule 寫模型本來就會做的事，是純粹的注意力稀釋。

## 明確不採納（連帶記下理由，避免下次重新爭論）

### `references/worktree-setup.md` 整份不用

它教手動 `git worktree add .worktrees/<name>`、手動驗 gitignore、手動裝依賴。
這是我們 `worktree-orchestration` 反模式清單的**第一條**
（❌ 手動 `git worktree add` 而不用 `claude -w`）。

原生路徑給我們的是 `.worktreeinclude`、自動清理，以及**機器強制的隔離**——
worktree session 對主 checkout 的寫入、cwd 逃逸、`git -C` 重導全被擋。
他們沒有這層，只能靠紀律。

而且它的依賴安裝寫 `pip install -r requirements.txt` / `poetry install`，
跟本專案「Python 一律用 uv」直接衝突。

### `sunnydata-parallel-agents` 沒有可拿的東西

它是「多個獨立測試失敗就分頭派 agent」的通用建議，缺我們整套機制：
沒有 plan 的 `files:` frontmatter 當衝突判準、沒有合併閘門、沒有 `conflict-resolver`、
沒有狀態隔離邊界表。它的衝突處理是**事後**問「Did agents edit same code?」，
我們是**派工前**用 `files:` 判。它的 dispatch 範例還寫 `Task(...)`，是舊工具名。

### PR 門檻與 commit 稽核表：這輪不做，但值得記著

`diff < 400 行且 < 10 檔` 的拆分建議、commit 歷史稽核表
（subject > 72 字元／空泛詞／單一 commit 動 10+ 不相關檔案／多個 commit 做同一件事），
以及**「advisory 不是 gate」**這個中間檔位。

使用者這輪選的範圍不含它們。但「一律呈報、使用者可照原樣走」的檔位我們幾乎沒用過——
本模板傾向什麼都做成閘門，這個檔位值得將來補。

## 促成這個決策的現場證據

**多 session 衝突今天就發生了。** 第一輪壓力測試的 prompt 01 受測 session 自己回報：

> 工作區不是我弄的那部分：`.claude/settings.json`、`worktree-orchestration/SKILL.md`、
> `.gitignore` 有未提交改動……這些來自**同機另一個 session**，還在跑。我沒碰它們

它是靠「我記得 session 開始時工作區是乾淨的」發現的，純屬運氣。第 2 條就是要制度化這件事。

**先開分支那條，本 session 自己違反了三次**——baseRef 修正、文件計數同步、
plan 強制加入，全部直推 main。本 repo 歷史一路都是直推 main，所以照做了；
`commands/pr.md:14` 確實會在 main 上時攔下來，但那是**程式碼已經寫完之後**。
Godzilla-z 把檢查點移到「收到任務的第一步」，這個位置才對。

## 相關

- `.claude/commands/pr.md` — PR 流程唯一來源，細則推給它
- `.claude/rules/coding-style.md` — commit message 格式
- `.claude/skills/writing-extensions/SKILL.md` — 要補「與模型預設不同」的判準
- `.claude/skills/worktree-orchestration/SKILL.md` — 反模式清單（為什麼不抄 worktree-setup）
- `.claude/hooks/lib/merge-gate.sh` — backup tag 閘門要照它的拆 lib 先例
