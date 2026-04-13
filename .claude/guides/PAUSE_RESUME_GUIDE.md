# 開發暫停 / 恢復 SOP

> 開發到一半要中斷時，照這份 SOP 操作，下次開啟可無痛接續。
> 「結束 session」與「開發到一半暫停」不一樣 — 後者更需要紀錄程式碼狀態與思考脈絡。

---

## 暫停時要解決的 4 個問題

1. **未完成的程式碼怎麼辦？** — 有沒有 commit？
2. **我剛才在想什麼？** — 思路、待解問題、下一步
3. **WBS 任務進度** — 哪個任務做到哪？
4. **哪些路試過不通？** — 避免下次重蹈覆轍

---

## 暫停 SOP（5 步驟，約 2 分鐘）

### Step 1：先跑測試（確認基線）
```
/verify quick
```
或手動跑 `npm test` / `pytest`。
**目的**：知道暫停的這一刻程式碼是綠是紅。下次開啟才知道「上次就壞了」還是「我搞壞了」。

### Step 2：處理未 commit 的變更

**情境 A — 可以 commit（完成了一個小單元）**
```bash
git add .
git commit -m "wip: 實作 X 函式（測試未完成）"
```
用 `wip:` 前綴標明這是未完成的暫存點。

**情境 B — 不能 commit（半成品、測試壞）**
```bash
git stash push -u -m "WIP: 註冊功能 - validation 寫到一半"
```
`-u` 包含未追蹤檔案，`-m` 加說明。

**情境 C — 想先看完整 diff**
```bash
git diff > .claude/sessions/diff-$(date +%Y-%m-%d).patch
```
存成 patch 檔，下次想看就 `cat` 它。

### Step 3：更新 WBS 狀態
```
/task-status
```
看 Claude 顯示的當前任務。如果做到一半就告訴 Claude：

```
把任務 2.3「使用者註冊」狀態改為「進行中 50%」，
備註「validation 寫完，token 生成未開始」
```

Claude 會更新 `.claude/taskmaster-data/wbs.md`。

### Step 4：擷取重要學習（如果有）
今天有發現坑、解法、設計決策：
```
/learn
```
把它存成 skill，下次自動載入。**沒有就跳過**。

### Step 5：寫斷點筆記（最重要）
```
/save-session
```

執行時 Claude 會詢問你補充。**特別要寫的是**：

- ✅ **「確切的下一步」** — 下次第一件事做什麼
- ✅ **「進行中的檔案」** — 哪些檔開著沒寫完
- ✅ **「卡住的問題」** — 卡在哪個錯誤/決策

範例：
```markdown
## 確切的下一步
src/auth/register.ts:88 — 補完 generateToken() 的 JWT 簽章邏輯
卡點：不確定要用 RS256 還是 HS256，等決定再寫

## 檔案當前狀態
| 檔案 | 狀態 | 備註 |
|---|---|---|
| src/auth/register.ts | 進行中 50% | validation 完成，token 未開始 |
| src/auth/validators.ts | 完成 | 已 commit (wip:) |
| tests/auth/register.test.ts | 壞掉 | 缺 token 的測試 |
```

---

## 恢復 SOP（3 步驟，約 1 分鐘）

### Step 1：開啟 Claude Code
- TaskMaster 歡迎畫面會自動跑出來
- 如果 WBS 有 in-progress 任務會被顯示

### Step 2：告訴 Claude 讀斷點筆記
```
讀 .claude/sessions/ 最新檔案，從「確切的下一步」繼續
```

或更明確：
```
讀 .claude/sessions/2026-04-08-template-audit-session.md，
我要從「下一步」段落繼續開發
```

Claude 會：
1. 讀 session 檔
2. 讀「進行中的檔案」清單，自動 Read 它們
3. 確認測試狀態（git status / git stash list）
4. 告訴你：「上次卡在 X，下一步是 Y，要開始嗎？」

### Step 3：恢復未 commit 的變更（如果用了 stash）
```bash
git stash list                     # 看看有什麼
git stash pop                      # 恢復最近一個
# 或
git stash apply stash@{1}          # 套用特定的（不刪除）
```

如果你用的是 wip commit 而非 stash：
```bash
git log --oneline -5               # 找到 wip commit
git reset HEAD~1                   # 取消 commit 但保留變更
# 或繼續寫然後 amend
git commit --amend
```

---

## 完整流程範例

### 假設情境
你在實作「使用者註冊 API」，validation 寫完了，token 生成寫到一半，測試還是紅的。下班了。

### 暫停時
```bash
# 1. 確認基線
/verify quick
# 結果：3 個測試失敗（預期內，token 還沒寫完）

# 2. 先把寫完的部分 commit
git add src/auth/validators.ts tests/auth/validators.test.ts
git commit -m "feat(auth): 實作註冊 validation 邏輯"

# 3. 把半成品 stash
git stash push -u -m "WIP: register.ts token 生成未完成"

# 4. 更新 WBS（在 Claude 對話中）
/task-status
# 然後告訴 Claude：「2.3 改為進行中，備註 token 未完成」

# 5. 寫斷點筆記
/save-session
# Claude 詢問細節時補充「下一步」「卡點」「進行中檔案」
```

### 隔天恢復
```bash
# 1. 開啟 Claude Code
claude

# 2. 第一句話
讀 .claude/sessions/ 最新檔案，恢復昨天的工作

# Claude 會說類似：
# 「找到 2026-04-09-...-session.md
#  上次卡在 src/auth/register.ts:88 的 JWT 簽章選擇
#  你之前 stash 了半成品變更
#  要恢復 stash 並從 token 生成繼續嗎？」

# 3. 恢復 stash
git stash pop

# 4. 繼續開發
```

---

## 三個常被忽略的小技巧

### 技巧 1：用 wip commit 代替 stash（更安全）
**stash 容易遺忘**，且不會被 push 到遠端，換機器就沒了。

建議改用 wip commit：
```bash
git commit -am "wip: 註冊 - token 生成中"
```
- 之後可 `git reset HEAD~1`（取消 commit 但保留變更）
- 或繼續寫然後 `git commit --amend`
- 或最終整理時 `git rebase -i` 壓掉 wip 提交

### 技巧 2：在 session 檔加「執行指令清單」
寫 `/save-session` 時，把下次要跑的指令寫進去：
```markdown
## 確切的下一步
1. `git stash pop`
2. `npm test -- register.test.ts` 確認測試還是紅的
3. 開 src/auth/register.ts:88 補 generateToken
4. 測試應該轉綠
```
這樣下次完全不用思考，照抄即可。

### 技巧 3：Context 系統會自動幫你記 agent 部分
如果你跑過 `/review-code`、agent 已經把報告寫進 `.claude/context/quality/`。
下次叫 `code-quality-specialist` 會自動讀 — **這部分不需要手動引導**，是 Context 系統的好處。

詳見 [`CONTEXT_USAGE.md`](CONTEXT_USAGE.md)。

---

## 一張表記住

| 暫停時 | 恢復時 |
|---|---|
| 1. `/verify quick` 確認基線 | 1. 開 Claude Code |
| 2. `git commit wip` 或 `git stash` | 2. 「讀最新 session 繼續」 |
| 3. 更新 WBS 進度 | 3. `git stash pop`（如有） |
| 4. `/learn`（如果有收穫） | 4. 照 session 檔的「下一步」做 |
| 5. `/save-session` 寫斷點 | |

---

## FAQ

**Q：為什麼不直接用 Auto-memory？**
A：本模板已停用 Auto-memory（記憶會跑到專案外的 `~/.claude/projects/.../memory/`）。
所有狀態應保存在 `.claude/sessions/` 內，跟著 git 走。
詳見 [`MECHANISMS.md`](MECHANISMS.md)。

**Q：Claude 自動載入 session 檔嗎？**
A：**不會**。`save-session` 紀錄需要你在新 session 第一句話明確要求 Claude 讀取。
這是刻意設計 — 自動載入會吃 context，且舊 session 可能已過時。

**Q：我有 5 個未完成的功能同時在做，怎麼辦？**
A：每個功能各自開分支 + 各自 wip commit。`save-session` 寫一份檔案統整所有分支的當前狀態。
恢復時：「我要繼續 feature/auth，讀最新 session 並 checkout 該分支」。

**Q：如果我忘記做暫停 SOP 就關了 Claude Code？**
A：
1. `git status` 看有什麼未 commit 變更
2. `git log --oneline -5` 看最近 commit
3. `ls -t .claude/context/*/` 看 agent 上次跑過什麼
4. 如果都沒線索 → 從 README 對應的功能段落重建 context

預防勝於治療：養成 SOP 習慣比補救容易。

---

## 相關文件

- [`MECHANISMS.md`](MECHANISMS.md) — 五套擴充機制權威對照
- [`WORKFLOW.md`](WORKFLOW.md) — 完整開發流程
- [`../commands/save-session.md`](../commands/save-session.md) — `/save-session` 指令詳細
- [`commands/learn.md`](commands/learn.md) — `/learn` 指令詳細
