---
name: worktree-orchestration
description: Use when running work in parallel across git worktrees — creating isolated checkouts, dispatching agents into them, merging back in dependency order, and cleaning up. Also the reference for which state files follow a worktree and which stay in the main checkout. Load before /task-next 的平行開發、/worktree、or dispatching an agent with isolation worktree.
---

# Worktree 編排

**這是 worktree 相關程序的唯一來源。** `/task-next` 的平行段、`/worktree` 指令、
`rules/agent-orchestration.md` 的「安全平行」都指向本檔，不各自重述。

## 何時值得開 worktree

| 情境 | 開嗎 |
|---|---|
| ≥2 個任務，檔案範圍**無交集**（依 plan 的 `files:` 判斷） | ✅ |
| 想同時試兩種做法，之後丟掉一個 | ✅ |
| 邊開發邊 review 別人的 PR | ✅（`claude --worktree "#1234"`） |
| 大範圍機械重構，怕污染主 checkout | ✅ |
| **同一個功能拆成很多小步驟** | ❌ 步驟間有依賴，隔離只會讓你一直在合併 |
| 任務會頻繁改到同一批共用檔 | ❌ 衝突成本大於平行收益 |
| 沒有 plan／plan 沒寫 `files:` | ❌ 範圍未知 → 保守視為不可平行 |
| 其中一方是**讀／跑整個 repo** 的掃描／驗證類 agent | ✅ **隔離是唯一選項**——它的寫入集是空的，`files:` 無交集對它永遠成立卻擋不住「讀撞到寫」。名單與理由見 `rules/agent-orchestration.md`「安全平行」 |
| **baseline 還沒 commit**（測試基礎設施、前置修復還在工作區） | ❌ worktree 是乾淨 checkout，agent 會在一個**缺那些東西**的環境裡開工，等於要它從零重建——而且**沒有任何錯誤訊息**。先 commit 再開，見「派工前務必做的一件事」 |

**並行數 2-4 個。** 再多你自己看不過來，磁碟與 context 成本也會超過收益。

---

## 狀態隔離邊界（**最重要的一節**）

官方文件明確寫著：

> Hook paths don't follow the worktree. `${CLAUDE_PROJECT_DIR}` stays put — it still
> points at the project root where the session started. The `cwd` field in the hook's
> input JSON is the worktree root.

所以 hook 必須自己決定每份狀態該讀哪個 root。`.claude/hooks/lib/resolve-roots.sh`
負責解析，判準是**短命旗標 vs 共享產物**：

| 跟著 worktree（`WORK_CLAUDE`） | 留在主 checkout（`MAIN_CLAUDE`） |
|---|---|
| `taskmaster-data/.current-task` | `context/learned/` — 踩過的坑是跨任務共享知識 |
| `taskmaster-data/.current-task-mode` | `context/decisions/` — ADR |
| `taskmaster-data/.doc-impact`＋`.doc-impact-notified` | `context/<area>/` — agent 報告 |
| `taskmaster-data/.pitfall-seen` | `coordination/handoffs/` — agent 交接 |
| `taskmaster-data/.report-expectations.jsonl` | `taskmaster-data/.suggest-mode` — 專案級設定 |
| | `logs/`＋`timelog.jsonl` — 集中一處才查得到 |

**`wbs.md` 與 `plans/` 不在上表**——它們是 git 追蹤的檔案，worktree 會自然帶一份、
改動由 git 合併，不需要 hook 介入選 root。這也是為什麼 `.gitignore` 必須讓它們進版控：
沒進版控的話 worktree 裡連 plan 都沒有，agent 不知道要實作什麼。

> 有個陷阱值得記住：worktree 住在 `.claude/worktrees/<name>/`，所以 worktree 裡
> **每個**檔案的絕對路徑都含 `/.claude/`。閘門的排除規則若用絕對路徑做子字串比對，
> 會把整個 worktree 當成「模板自身設定」放行。排除判斷一律先相對化到當前 checkout root。

---

## 建立

**優先用原生支援，不要手動 `git worktree add`：**

```bash
claude --worktree feature-auth      # 或 claude -w feature-auth
```

它會建在 `.claude/worktrees/feature-auth/`、分支 `worktree-feature-auth`，
並套用 `.worktreeinclude`。從哪裡開分支由 `settings.json` 的 `worktree.baseRef` 決定。

> **「優先用原生」的前提是你站在預設分支上。** 本模板設 `"head"`，所以在 topic
> 分支上跑 `claude -w`，開出來的 worktree **以那條 topic 分支為基底**——前一個
> 任務的 commit 會整批混進新任務（實際踩過）。這時改用下表「從預設分支開」那一列。
> （`git checkout -b` 也有同一個坑，已由 `lib/branch-switch-gate.sh` 擋。）

### `baseRef`：本模板設 `"head"`，不是官方預設

只有兩個合法值：

| 值 | 從哪開 | 帶得到未 push 的 commit |
|---|---|---|
| `"fresh"`（官方預設） | **遠端**的預設分支（通常 `origin/main`）。24 小時內沒 fetch 過會去 fetch（上限 5 秒，失敗則用本地快取的 ref） | ❌ |
| `"head"`（**本模板的設定**） | 當前本地 HEAD（在 worktree 內解析成該 worktree 自己的 HEAD） | ✅ |

**為什麼本模板不用官方預設**：這裡的平行流程是 `/plan` 寫出 plan →
`/task-next` 判定可平行 → 開 worktree 派 agent。那份 plan 剛寫好，**絕對還沒 push**。
`"fresh"` 之下 worktree 從遠端開，plan 不在裡面 —— 隔離的 agent 讀不到自己要實作什麼，
只會自己發明範圍。共用型別／schema 同理。設定寫在 `.claude/settings.json`
的 `worktree.baseRef`（標準 JSON 不能寫註解，理由記在這裡）。

**`"head"` 的代價（知道再選，不要當它不存在）**：基底是「你現在站在哪」，
所以站在 topic 分支上開 worktree，前一個任務的 commit 會混進新任務。
繞法在下面那張表。**沒有第三個值可以兩全**——`baseRef` 不吃分支名字串
（2026-09-17 查證：合法值就是 `fresh` / `head` 兩個，「指定基底分支」還是
[開著的 feature request](https://github.com/anthropics/claude-code/issues/35730)），
所以這是二選一，本模板選「plan 進得去」而不是「基底永遠乾淨」。

帶 `isolation: "worktree"` 的 subagent worktree **同樣遵守** `worktree.baseRef`
與 `.worktreeinclude`，不是另一套規則。

| 需求 | 做法 |
|---|---|
| 從遠端乾淨狀態開（放棄本地未 push 的工作） | `settings.json` 改回 `worktree.baseRef: "fresh"`（**會讓 plan 進不了 worktree**，改前先讀上面那段） |
| 從某個 PR 開 | `claude --worktree "#1234"`（引號必要，`#` 會被 shell 當註解） |
| 從預設分支開（人在 topic 分支上時） | 原生會用當前 HEAD → `git worktree add -b <新分支> .claude/worktrees/<名字> main` |
| 從既有分支開 | 原生不支援 → `git worktree add ../x existing-branch` |
| session 中途進去 | 叫我「在 worktree 裡做」，我用 `EnterWorktree` |
| 讓某個 agent 永遠隔離 | 該 agent frontmatter 加 `isolation: worktree` |
| 單次派工隔離 | `Agent` 工具帶 `isolation: "worktree"` |

**環境準備**：worktree 是乾淨 checkout，只有 tracked 檔案。`.worktreeinclude`
負責帶 `.env`／`.mcp.json` 這類 gitignored 設定；**依賴要自己裝**。

### `symlinkDirectories`：本模板預設**空的**，開之前先讀判準

`settings.json` 的 `worktree.symlinkDirectories` 會把列出的目錄做成**指回主 checkout**
的 symlink，原意是省磁碟（一份 `node_modules` 動輒 300–500MB）。**本模板預設 `[]`**，
原本的 `["node_modules", ".venv", ".next", "dist", "build"]` 已全部移除。

**為什麼**：worktree 的隔離是**檔案層**的。symlink 一個會影響「執行到哪份程式碼」的
目錄，等於在執行層把隔離拆掉——而且**完全沒有錯誤訊息**。2026-09-17 實測：
`.venv` 走 symlink 時，worktree 裡的 `router.__file__` 指向**主 checkout**，
worktree 的 agent 跑測試測到的是另一條線的程式碼（對方正在做突變測試）。

**判準（要開哪些自己照這條判）：**

| 可以 symlink | 不能 symlink |
|---|---|
| **純快取／純下載產物**——內容只由 lockfile 決定，跟你在哪個 checkout 無關 | **任何會記錄來源路徑的東西**：editable install 的 `.pth`／`__editable__*.pth`、workspace 的 package 連結（`node_modules/<pkg>` 指回 repo source）、從 schema 產生的 client（`node_modules/.prisma`） |
| | **建置產物**（`.next`／`dist`／`build`）——它是**這份 source 的輸出**，共用等於 B 服務／測試 A 的產出 |

`node_modules` 也不是無條件安全：**扁平、非 workspace 的專案可以開**；
npm／pnpm workspaces 或 monorepo 就落在右欄（`node_modules/<pkg>` 是指回 source 的 symlink）。
`.venv` 在本模板一律不建議——`python-uv` 的 workspace 成員預設就是 editable install。

**已經中招了怎麼修**（順序不能換）：

```bash
test -L backend/.venv && unlink backend/.venv     # 確認是 symlink 才動
uv sync --all-packages                            # 重建，不要只 uv sync
```

- **`unlink` 不是 `rm -rf`**：`rm -rf backend/.venv/` 帶斜線會沿著 symlink 進去
  **刪掉主 checkout 的那一份**。`test -L` 先確認、`unlink` 只斷連結。
- **`--all-packages` 不能省**：只跑 `uv sync` 會把 workspace 成員修剪掉。
- 驗收條件是**不帶 `PYTHONPATH`** 也載得到 worktree 自己的檔案
  （`python -c "import <pkg>; print(<pkg>.__file__)"` 要指向 worktree）。
  成本：一份新 venv 約 484MB（實測）。

---

## 派工

每個 worktree 內走既有鏈（`/tdd` → `/verify`）。兩種派法：

1. **一個 worktree 一個 session** —— `claude -w <name>` 開多個終端，各自獨立。
   最直觀，也最容易看清誰在做什麼
2. **一個 session 派多個隔離 subagent** —— `Agent` 工具帶 `isolation: "worktree"`。
   context 集中在你這邊，但你要自己協調

### 派工前務必做的一件事

**先 commit，再開 worktree。** 對象不只共用定義——凡是 agent 進去就得用到的東西
（測試基礎設施、fixture、前置修復）留在工作區，worktree 裡就沒有。

若這幾個任務用到共同的型別／介面／schema，**共用定義必須在 worktree 開出去之前就存在**。
各 worktree 看不到彼此，少了共用定義每個 agent 各自發明一份，合併時必衝突。

兩者漏掉的後果不同，所以要分開檢查：**共用定義漏了，會在合併時變成看得見的衝突；
baseline 漏了，agent 只會安靜地重建一份**（它甚至會做得很像，你要到對帳時才發現）。

**「存在」的門檻取決於 `baseRef`**：

| `baseRef` | 前置動作 |
|---|---|
| `"head"`（**本模板的設定**） | `git commit` 就夠 —— worktree 從本地 HEAD 開，看得到未 push 的 commit |
| `"fresh"` | **commit 不夠，必須 push**。worktree 從遠端開，只 commit 在本地的東西它拿不到 |

改過 `baseRef` 的人特別注意這條：在 `"fresh"` 之下做了 commit 就以為安全，
agent 會在一個沒有共用型別的 worktree 裡開工，而且不會有任何錯誤訊息。

**plan 檔必須進版控，worktree 才拿得到。** worktree 是乾淨 checkout，
只有 tracked 檔案；`taskmaster-data/plans/` 沒進版控的話，worktree 裡連 plan 都沒有。
`.worktreeinclude` **不是替代方案** —— 它只複製「符合樣式**且本來就被 gitignore**」的檔案，
而官方沒有說明 `.git/info/exclude` 裡的項目是否算等價的排除來源，不能依賴它。
這也是為什麼 `.gitignore` 的「以下刻意進版控」清單裡有 `plans/`。

跨 worktree 的依賴**先 mock**，等合併後再接真的。

---

## Claude Code 會幫你強制隔離

worktree session（含它派出的所有 subagent）被四道檢查擋住：

1. **檔案編輯** —— 目標在主 checkout 的 `Edit`／`Write`／`NotebookEdit` 被擋
2. **指令工作目錄** —— cwd 解析到主 checkout 的 Bash／PowerShell／Monitor 被擋
3. **git 重導** —— `git -C`、`--git-dir`、`GIT_DIR`、先 `cd` 再 git，全被擋
4. **指令形狀** —— 無法從指令文字確認 git 會留在 worktree 內時被擋（**這條關不掉**）

比 rules 裡寫「不要互改同一批檔案」強得多——那是自律，這是機器。

帶 `isolation: "worktree"` 的 subagent 走的是同一套：同樣遵守 `worktree.baseRef`
與 `.worktreeinclude`，同樣被上面四道檢查擋。結束後的處置與互動 session 不同 ——
**沒有變更時自動移除，有變更則留在磁碟上**等 `cleanupPeriodDays` 的定期掃描。
分支命名規則官方未公開，要找它就用 `git worktree list`，不要照猜的名字去 `git branch`。

---

## 合併回 main

**依相依順序、一次一個。** 不要一次 merge 全部。

```bash
# 1. 每個 worktree 先自己驗過
#    （在該 worktree 內）/verify 通過才算完成

# 2. 回主 checkout
git checkout main && git pull --rebase

# 3. 一次一個
git merge --no-ff worktree-<name>

# 4. 立刻 /verify  ←── 這一步是機器強制的，不是建議
#    合併成功時 post-bash.sh 記一筆進 .merge-pending，
#    在 /verify 通過清掉它之前，pre-tool-use.sh 會**擋下下一次 merge**

# 5. 衝突只在主 checkout 解
```

**第 4 步為什麼不能跳**：每個 worktree 自己驗過，但它們**看不到彼此** ——
合併才第一次讓兩邊的程式碼真的碰面，那些互動是全新的、沒人驗過的程式碼。
而且一次疊三個之後測試紅了，你得回頭二分找元凶。

**最後一個合併之後**，`/verify` 會多做一件事：載入 `spec-convergence` 跑收斂檢查。
理由是平行開發最容易踩的不是「漏做」而是**範圍蔓延** —— 三個 agent 各自多做了一點
「順手的改善」，單獨看都合理，合起來就偏離當初講好的範圍。
完整關卡定義見 `.claude/commands/verify.md` 的「0a. 合併驗證關卡」。

**順序**：先合**獨立**的功能，再合**依賴它們**的。例如 search 與 cart 先合、
用到 `CartItem` 的 order-email 後合——這樣基礎型別已經在 main 了。

**出現衝突代表 `files:` 估算有漏。** 停下、人工解、並回頭補正那份 plan 的 `files:`，
否則下次同樣的組合還是會被判成可平行。

**`wbs.md` 不該衝突，因為 worktree 內不准標它。**

原本這裡寫著「git 多能自動處理，真衝突時保留兩邊的狀態即可」——**實測是錯的**。
兩個相鄰任務各自標 ✅ 時，`merge=union` 產出的是四列、兩份重複、狀態互相矛盾，
**而且沒有衝突標記**（union 保留的是兩個版本的整個 diff hunk，不是各留自己那一行）。
細節記在 `.gitattributes` 的註解裡。

正解是從源頭避免：**worktree 內的 `/verify` 跳過「標記與歸檔」那一節**，
只驗程式碼，驗完回報「可以合併」。`wbs.md`、`plans/INDEX.md` 與 plan 歸檔
統一在主 checkout、全部合併完成後做一次（合併迴圈的最後一步）。

同一個原則適用於任何「被多個 worktree 各改一次」的追蹤檔：
不要想在合併時補救，要讓它只有一個寫入者。

---

## 清理

**先看官方會自動做什麼，別重複勞動：**

| 情況 | 官方行為 |
|---|---|
| 互動 session 結束、worktree 乾淨、未命名 | 自動移除 worktree 與分支 |
| 互動 session 結束、worktree 乾淨、已命名 | 先問你 |
| worktree 內有未提交／未追蹤／未 push 的東西 | 先問你，保留或刪除 |
| subagent worktree、**結束時沒有變更** | 自動移除 |
| subagent worktree、**結束時有變更** | 留在磁碟上，等超過 `cleanupPeriodDays` 由定期掃描移除 |
| 背景 session 的 worktree | 超過 `cleanupPeriodDays` 由定期掃描移除 |
| `-p` 非互動 session | **不清理**，且 lock 留著直到後續掃描釋放 |
| **你自己 `git worktree add` 建的** | **永不自動刪** |

手動清理：

```bash
git worktree list                                  # 看還有哪些
git worktree remove .claude/worktrees/<name>       # 有未提交變更要加 --force
git worktree unlock .claude/worktrees/<name>       # 被 lock 時先解鎖
git worktree prune                                 # 清掉目錄已消失的紀錄
```

> **Windows 注意**：worktree 內若有 NTFS junction 或目錄 symlink，移除 worktree
> 只刪連結、不刪它指向的資料夾。

---

## 反模式

- ❌ 手動 `git worktree add` 而不用 `claude -w`（少掉 `.worktreeinclude`、自動清理、隔離強制）
- ❌ 把 `.venv` 或建置產物列進 `symlinkDirectories`（隔離在**執行層**失效，而且無聲）
- ❌ 沒把共用型別先落地（`"head"` → commit；`"fresh"` → push）就開三個 agent
- ❌ 一次 merge 全部 worktree
- ❌ 在 worktree 裡跑 `git -C <主checkout>`（會被擋，而且意圖本身就錯）
- ❌ 把 `.claude/worktrees/` 從 `.gitignore` 移出來（`.worktreeinclude` 帶進去的秘密會進版控）
- ❌ 忘記 worktree 要自己裝依賴，然後以為是程式壞了
- ❌ 沒有 plan／`files:` 就硬開平行

## 相關

- `.claude/hooks/lib/resolve-roots.sh` — 狀態隔離的實作
- `.worktreeinclude` — 要帶進 worktree 的 gitignored 檔案
- `plan-format` skill — `files:` 欄（平行判斷的依據）
- `.claude/commands/task-next.md` — WBS 驅動的平行入口
- `.claude/commands/worktree.md` — 臨時隔離的入口
- `subagent-execution` skill — 隔離 subagent 的派工與審查
