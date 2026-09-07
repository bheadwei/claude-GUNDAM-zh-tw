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
      依相依順序、一次一個；合併前確認該 worktree 已 /verify 過
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

1. `git worktree list` 列出候選，用 `AskUserQuestion` 讓使用者選要合哪一個
   （**一次一個**，不提供「全部合併」選項）
2. **合併前確認**：該 worktree 內 `/verify` 通過了嗎？沒有就先提醒
3. 若有多個要合，**問出相依順序**並說明理由：先合獨立的、再合依賴它們的，
   這樣基礎型別已經在 main 了
4. 執行：

   ```bash
   git checkout main && git pull --rebase
   git merge --no-ff worktree-<name>
   ```

5. **有衝突就停下** —— 衝突只在主 checkout 解。若這個 worktree 來自
   `/task-next` 的平行開發，順便提醒：衝突代表該 plan 的 `files:` 估算有漏，
   要回頭補正，否則下次同樣組合還是會被判成可平行
6. 合併後問要不要移除該 worktree

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
