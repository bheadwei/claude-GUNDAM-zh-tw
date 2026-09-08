---
description: 臨時隔離工作區：開 worktree、看狀態、依序合併、清理。WBS 驅動的平行開發請用 /task-next。
---

# Worktree

打了就進問答，**不用記子指令**。完整程序見 `worktree-orchestration` skill（唯一來源）。

## 與 `/task-next` 的分工

| | `/task-next` 的平行選項 | 本指令 |
|---|---|---|
| 前提 | WBS 有 ≥2 個 ready 任務，**都有 plan 且寫了 `files:`** | 什麼都不用 |
| 場景 | 已規劃的平行推進 | 臨時隔離：試兩種做法、邊改邊 review PR、開實驗分支 |

`/task-next` 的排除規則是「沒有 plan／沒寫 `files:` → 不可平行」（保守，避免衝突）。
本指令服務的正是那一類被擋在門外的工作。

---

## 流程

**先載入 `worktree-orchestration` skill**，然後用 `AskUserQuestion` 問一題：

```
要做什麼？
  [Recommended] 開一個隔離工作區
      建 worktree + 帶 .worktreeinclude 的設定過去 + 提示裝依賴
  看目前有哪些
      列出所有 worktree、各自分支、有沒有未提交／未 push 的東西
  合併回 main
      依相依順序自動合併迴圈：每個合完就 /verify，衝突或驗證失敗才停
  清理
      只處理官方自動掃描不會動的那些
```

依照答案執行下列對應節。**不要一次問多題。**

---

## 開一個隔離工作區

1. 問一題：**要做什麼？**（直接輸入即可，或選常見情境）
   - 說明裡註明「直接打字描述就好，我會轉成分支名」
   - 常見情境選項：試另一種做法 ／ review 一個 PR ／ 隔離的實驗
2. 由描述產生 kebab-case 名稱（中文要轉英文，20 字元內）。
   若使用者說的是 PR，改用 `claude --worktree "#<number>"`（引號必要）
3. **前置檢查**：
   - `.worktreeinclude` 存在嗎？不存在就提醒「worktree 會缺 `.env`，要先建嗎」
   - 主 checkout 乾淨嗎？有未提交變更就提醒（不強制擋——開 worktree 本身不會弄壞它）
4. 給使用者指令，**不要自己在背景開一個他看不到的 session**：

   ```bash
   claude --worktree <name>
   ```

   說明它會做什麼：建在 `.claude/worktrees/<name>/`、分支 `worktree-<name>`、
   從 repo 預設分支開出去、套用 `.worktreeinclude`。

   若使用者要的是「我這個 session 直接進去做」→ 用 `EnterWorktree` 工具。
5. **提醒裝依賴**（worktree 只有 tracked 檔案）：依專案的 package manager
   給出實際指令（讀 `taskmaster-data/package-manager.json`，見 `node-package-manager` skill）

---

## 看目前有哪些

```bash
git worktree list
```

逐個檢查並用表格呈現：分支、路徑、**有未提交變更嗎**、**有未 push 的 commit 嗎**、
建立多久了。有工作在裡面的要標出來——那些是官方自動掃描**不會**動的。

順手指出可疑狀況：目錄已消失但 git 還記著（建議 `git worktree prune`）、
被 lock 住的（`git worktree unlock`）。

---

## 合併回 main

`git worktree list` 列出候選，用 `AskUserQuestion` 問怎麼合：

| 選項 | 行為 |
|---|---|
| **依序全部合併（Recommended，≥2 個時）** | 自動跑合併迴圈到底，遇到衝突或驗證失敗就停 |
| 只合這一個 | 選一個，合完就停 |

### 路徑 A：依序全部合併（自動迴圈）

**先問出相依順序並說明理由**：先合獨立的、再合依賴它們的，這樣基礎型別已經在 main 了。
順序確認後**不再逐個確認**，一路跑到底或停在問題上。

```
git checkout main && git pull --rebase

對每個 worktree（依相依順序）:
    git merge --no-ff worktree-<name>
    ├─ 衝突 → 委派 conflict-resolver（subagent_type: "conflict-resolver"）
    │          ├─ DONE     → 檔案已 stage → 往下跑 /verify
    │          ├─ BLOCKED  → 它已 git merge --abort（設計決策）→ ⛔ 停下回報
    │          └─ CONCERNS → ⛔ 停下回報（測試紅，或它對某個解法沒把握）
    └─ 成功 → 往下跑 /verify

    /verify
    ├─ FAIL → ⛔ 停下回報，不自動修
    └─ PASS → 解過衝突的話這裡才 commit → 繼續下一個

全部合完 → 更新 WBS（各任務標 ✅）→ plan 歸檔 → 問要不要移除這些 worktree
```

**這個迴圈可以自動跑，是因為閘門在把關**：`post-bash.sh` 在每次合併成功時記一筆
`.merge-pending`，而 `pre-tool-use.sh` 會擋下「未驗證就合下一個」。所以迴圈**不可能**
悄悄跳過 `/verify` —— 這也是為什麼舊版本明文寫著「不提供全部合併選項」，
那條限制在閘門存在之後不再需要。

`/verify` 在有 `.merge-pending` 時會多做兩件事（定義見 `commands/verify.md` 的
「0a. 合併驗證關卡」）：比對**每一個已合併任務**的 plan 驗收標準、以及載入
`spec-convergence` 查漏做／範圍蔓延／描述失真。

**停下來的時候要回報什麼**：已經合成功幾個、卡在哪一個、卡的是衝突還是驗證、
以及還沒合的有哪些。使用者要能決定「修完繼續」或「`git merge --abort` 退回」。

### 路徑 B：只合這一個

1. **合併前確認**：該 worktree 內 `/verify` 通過了嗎？沒有就先提醒
2. 執行：

   ```bash
   git checkout main && git pull --rebase
   git merge --no-ff worktree-<name>
   ```

3. 合併成功 → **跑 `/verify`**（閘門會擋下下一次合併直到它通過）
4. 問要不要移除該 worktree

### 衝突為什麼可以自動解（以及哪些不行）

一般的合併衝突難解，是因為寫那兩段程式碼的人不在場，只能從程式碼猜意圖。
**平行開發不一樣：兩邊的作者都是 agent，而它們的意圖已經寫在磁碟上了** ——
各自的 plan、驗收標準、完成報告。那是人工解衝突時拿不到的資訊。

所以 `conflict-resolver` 在回答的是「哪個做法符合當初講好的事」，
而不是「哪段程式碼比較漂亮」。它的依據順序寫在
`.claude/agents/conflict-resolver.md`（唯一來源）。

**它一定會停下來的情況**：設計決策（API 語意、資料結構取捨、migration 順序、
env var 意義）、一邊刪掉另一邊在改的東西、兩份 plan 的驗收標準互相矛盾。
那時它會 `git merge --abort` 並回報，不自己決定。

**它不會 commit。** 完整的 `/verify`（含 plan 驗收比對與 `spec-convergence`）
是主模型的事——解過衝突的合併比乾淨合併**更**需要驗證。

**衝突另有一個訊號要處理**：它代表該 plan 的 `files:` 估算有漏。
`conflict-resolver` 會順手補正那份 plan 的 `files:` frontmatter ——
不補的話下次同樣兩個任務又會被判成可平行、又衝突一次。

---

## 清理

**先講清楚官方已經自動做了什麼**，避免重複勞動——那張表在
`worktree-orchestration` skill 裡，直接引用，不在此重述。

只針對「官方不會動的」提議清理：你自己 `git worktree add` 建的、
有未提交／未追蹤／未 push 內容的、`-p` 非互動 session 留下的。

移除前**列出裡面有什麼會消失**（未提交的檔案清單、未 push 的 commit），
讓使用者確認。有價值的東西先提議 commit 或 cherry-pick 出來。

```bash
git worktree remove .claude/worktrees/<name>    # 有未提交變更才加 --force
git worktree prune                              # 清掉目錄已消失的紀錄
```

---

## 注意

- **不要手動 `git worktree add`** 當作預設做法。原生 `claude -w` 會處理
  `.worktreeinclude`、自動清理、以及四道隔離強制檢查
- `.claude/worktrees/` 必須留在 `.gitignore` 裡 ——
  `.worktreeinclude` 帶進去的 `.env`／`.mcp.json` 含秘密
- 並行 2-4 個。再多就是給自己找麻煩
