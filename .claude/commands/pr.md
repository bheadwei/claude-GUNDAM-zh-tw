---
description: 建立 Pull Request。分析完整 commit 歷史與 diff、可選先跑把關鏈、產出含測試計畫的 PR 內容，確認後 push 並開 PR。
---

# 建立 Pull Request

**PR 流程以本檔為唯一來源。** commit message 格式見 `.claude/rules/coding-style.md`
（那條常駐，因為 commit 是高頻動作，不能靠 skill 喚起）。

## 前置檢查（自動，失敗就停）

| 檢查 | 不通過時 |
|---|---|
| 不在預設分支（main/master） | 提示先開分支：`git checkout -b <type>/<slug>`，停止 |
| 有 commit 領先 base | 沒有變更 → 提示無事可做，停止 |
| 工作目錄乾淨 | 有未提交變更 → 問「先 commit / 暫存 / 取消」 |
| `gh` 可用（`gh auth status`） | 不可用 → 改為只 push 並給出手動開 PR 的網址 |
| 有 remote | 無 remote → 提示先設定，停止 |

## 步驟 1：分析完整變更（**不是只看最新 commit**）

```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@.*/@@' || echo main)
git log --oneline "$BASE"..HEAD          # 完整 commit 歷史
git diff "$BASE"...HEAD --stat           # 三個點：只看本分支引入的變更
git diff "$BASE"...HEAD                  # 實際內容
```

> **務必用三個點 `...`**。兩個點會把 base 分支的新 commit 也算進來，導致摘要包含別人的變更。

從中歸納：真正的意圖是什麼（不是逐 commit 複述）、影響範圍、有沒有破壞性變更。

## 步驟 2：把關

### 2a. 先比對上次 `/verify`（跑這段，不要憑記憶判斷）

```bash
LV="$(git rev-parse --show-toplevel)/.claude/taskmaster-data/.last-verify"
# 同 commands/verify.md「記下這次驗證」的 SCOPE（唯一來源，逐字沿用）
SCOPE=(':(top)' ':(top,exclude).claude/taskmaster-data' ':(top,exclude).claude/context' ':(top,exclude).claude/coordination' ':(top,exclude).claude/qa-history')
SHA=$(sed -n 's/^sha=\([0-9a-f]*\) .*/\1/p' "$LV" 2>/dev/null)
if [ -z "$SHA" ] || ! grep -q ' result=PASS clean=yes suite=full ' "$LV"; then
  echo "REUSE: no（沒有可沿用的整套驗證）"
elif [ -n "$(git status --porcelain -- "${SCOPE[@]}")" ]; then
  echo "REUSE: no（工作區有未 commit 變更）"
elif ! git merge-base --is-ancestor "$SHA" HEAD || [ -n "$(git diff --name-only "$SHA" HEAD -- "${SCOPE[@]}")" ]; then
  echo "REUSE: no（驗證之後程式碼有變）"
else
  echo "REUSE: yes"; grep -o 'secrets=[a-z]* spec=[a-z]*' "$LV"
fi
```

「沒變」＝HEAD 就是驗過的那個 commit，或之後的 commit 只動了 `SCOPE` 排除的執行時產物目錄
（`/verify` 完標 WBS ✅、plan 歸檔、agent 報告那類 commit）。檔案格式與寫入時機見 `commands/verify.md`
的「記下這次驗證」（唯一來源）。

- `REUSE: yes` → **不重跑建置／型別／lint／測試**。`/verify pre-pr` 只補上次沒做的：
  `secrets=no` → 補步驟 7 秘密掃描；`spec=no` → 補 `spec-convergence` A+B
- `REUSE: no` → 照常

### 2b. 問要不要跑檢查（用 `AskUserQuestion` 問一題）

> **題目：** 開 PR 前要先跑檢查嗎？

- **跑 `/verify pre-pr`**（Recommended）— 建置/型別/lint/測試/安全掃描。
  2a 是 `REUSE: yes` 時選項說明改成「沿用 `<sha 前 7 碼>` 的整套結果，只補 …」
- **跑完整把關鏈** — code-quality-specialist → security-infrastructure-auditor →
  e2e-validation-specialist（見 `using-taskmaster` skill 路由表的「開 PR 前把關」列）。
  code-quality-specialist 的審查範圍見下方 2c
- **跳過，直接開** — 適合文件變更或已經驗過

**critical 時把關鏈不可跳過**——直接執行，不問。判定 critical 的條件（任一成立）：

- 本分支涵蓋的任一 plan frontmatter 為 `mode: critical`——**含 `plans/archive/`**
  （`/verify` 完成時會把 plan 歸檔、清掉模式檔，所以到 `/pr` 時通常只剩歸檔的那份）。
  「涵蓋」＝ plan 檔本身在 `git diff "$BASE"...HEAD --name-only` 裡，或它的 `wbs_task`
  出現在本分支的 commit 訊息中
- `.claude/taskmaster-data/.current-task-mode` 為 `critical`

檢查失敗 → 停下回報，不要帶著紅燈開 PR。

### 2c. 把關鏈的 code-quality-specialist 只審「階段審查沒看過」的 diff

每個階段的 diff 已經由 `code-quality-specialist` 審過（`rules/task-mode.md`「審查節奏」）。
這裡再審整條分支等於同一批程式碼審兩次，所以只交給它三類：

| 類別 | 怎麼找 |
|---|---|
| 沒走階段審查的 commit（沒有 plan、quick 任務、合併後在主 checkout 補的修正） | 本分支非 merge 的 commit，扣掉帳本記錄的已審範圍 |
| 解衝突的修改 | 每個 merge commit 的 `git show --remerge-diff`——乾淨合併沒有輸出，有輸出的就是解衝突時寫的東西 |
| 已審範圍之後又改過的 | 同第一類：審查通過之後的 commit 不在範圍內，自然會被列出來 |

已審範圍＝帳本（`plans/` 與 `plans/archive/` 的 `*.progress.md`）裡含「審查通過」那幾行的 `範圍=<A>..<B>`
（格式見 `subagent-execution` skill 的「帳本要記什麼」，唯一來源）。

```bash
P=.claude/taskmaster-data/plans
RANGES=$(cat "$P"/*.progress.md "$P"/archive/*.progress.md 2>/dev/null | grep '審查通過' |
         grep -o '範圍=[0-9a-f]*\.\.[0-9a-f]*' | sed 's/^範圍=//')
REVIEWED=$(for r in $RANGES; do git rev-list "$r" 2>/dev/null || echo "BAD-RANGE $r"; done | sort -u)
echo "$REVIEWED" | grep BAD-RANGE                                           # 有輸出 → 範圍不可信
git show --remerge-diff --format= HEAD >/dev/null 2>&1 || echo NO-REMERGE-DIFF   # git < 2.36 沒有這個選項
git rev-list --no-merges "$BASE"..HEAD | grep -vxF -f <(printf '%s\n' "$REVIEWED")   # 沒審過的 commit
for m in $(git rev-list --merges "$BASE"..HEAD); do
  [ -n "$(git show --remerge-diff --format= "$m")" ] && echo "conflict-resolved: $m"
done
```

交給它的內容：沒審過的 commit 各自的 `git show <sha>`，加上解衝突那幾個 merge 的
`git show --remerge-diff <merge>`。三類都是空的 → 這一棒跳過，在回報寫明「全部 diff 已由階段審查覆蓋」。

**退回審整個 `git diff "$BASE"...HEAD`（保守）**：一行 `審查通過｜範圍=` 都找不到、
出現 `BAD-RANGE`（範圍的 commit 已不存在，例如被 rebase 或 squash 掉）、
出現 `NO-REMERGE-DIFF`（舊版 git 會讓 `--remerge-diff` 報錯、迴圈把每個合併都當成乾淨的）、或沒審過的 commit
佔了大半（拆開審不划算）。

**只有 code-quality-specialist 縮範圍。** critical 的 `security-infrastructure-auditor`
與 `e2e-validation-specialist` 照舊看整條分支。

## 步驟 3：草擬 PR 內容

用 `AskUserQuestion` 呈現草稿並確認（可選「就這樣」/「我要改標題」/「補充說明」/「取消」）。

**標題**：conventional commits 格式，一行講完做了什麼
`feat(auth): 支援 OAuth 登入`

**內容骨架**：

```markdown
## 摘要

<2-4 句：為什麼要做、做了什麼。針對整個分支，不是逐 commit 流水帳>

## 變更內容

- <依主題分組，不是依檔案列>
- <破壞性變更用 ⚠️ 標出，並寫明遷移方式>

## 測試計畫

- [ ] <具體怎麼驗證，含指令>
- [ ] `/verify pre-pr` 通過
- [ ] <手動驗證步驟，如果有 UI 變更>

## 相關

- WBS 任務：<id>（若有）
- 計畫：`plans/<id>-<slug>.md`（若有）
- 關聯 issue：Closes #<n>（若有）
```

**內容來源**：優先從 WBS 任務描述與 plan 檔的「目標／驗收標準」取材，
那些本來就寫好了，不要重新編一套說法。

## 步驟 4：推送並建立

```bash
git push -u origin "$(git branch --show-current)"     # 新分支必須 -u
gh pr create --base "$BASE" --title "<標題>" --body "<內容>"
```

草稿 PR 加 `--draft`。指定審查者加 `--reviewer <user>`。

## 步驟 5：回報

給出 PR 網址，並提示：

- 有 CI 的話用 `gh pr checks --watch` 追蹤
- `/deploy` 走部署（合併後）

## 使用方式

```
/pr              # 互動式建立
```

不接受參數——標題與內容由分析結果產生並讓你確認，比背參數快。

## 注意

- **PR 內容的署名**：預設附上 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`。
  不想要就在確認那一步說一聲，之後都不加。
- **不要 `--force` push** 到已有審查意見的 PR，除非你明確要求
- 已存在 PR 的分支再跑本指令 → 改為顯示現有 PR 並問要不要更新內容

## 相關

- `.claude/rules/coding-style.md` — commit message 格式
- `using-taskmaster` skill 路由表「開 PR 前把關」列 — 把關鏈的組成（唯一來源）
- `/verify pre-pr` — 完整檢查含安全掃描
