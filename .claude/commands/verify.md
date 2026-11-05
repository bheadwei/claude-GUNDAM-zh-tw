---
description: 對當前程式碼庫狀態執行全面驗證檢查。
---

# 驗證指令

## 說明

依以下確切順序執行驗證：

### 1. 建置檢查
- 執行專案的建置指令
- 如失敗則報告錯誤並停止

### 2. 型別檢查
- 執行 TypeScript/型別檢查器
- 報告所有錯誤含檔案:行號

### 3. Lint 檢查
- 執行 linter
- 報告警告和錯誤

### 4. 測試套件

**整套只在主 checkout 跑**（worktree 裡取不到分支起點的退路除外，見下方 `START: unknown`），
而且合併時只在最後一個合併跑。依情境選範圍：

| 情境 | 跑什麼 | `Tests:` 欄註明 |
|---|---|---|
| `quick` profile | 只跑這次改到的測試檔（見「參數」） | — |
| **在 worktree 裡**（判斷方式見「標記與歸檔」） | 只跑**這條線改到的**測試（找法見下）。`pre-pr` 也一樣 | `本線相關，整套留給合併後` |
| 主 checkout、`.merge-pending` 非空、判為**中間合併** | 只跑這次合併帶進來的檔案對應的測試（見「合併驗證關卡」） | `本次合併相關，整套留給最後一個合併` |
| 其他（主 checkout） | 整套 | — |

worktree 裡「這條線改到的檔」＝從分支起點到現在（含未 commit 與未追蹤）：

```bash
BASE_BR=$(git worktree list --porcelain | awk 'NR==1,/^$/ { if ($1 == "branch") { sub("refs/heads/", "", $2); print $2 } }')
START=$(git merge-base HEAD "${BASE_BR:-main}" 2>/dev/null)   # 主 checkout 當前分支＝這條線開出來的基底
if [ -z "$START" ]; then echo "START: unknown"
else { git diff --name-only "$START"; git ls-files --others --exclude-standard; } | sort -u; fi
```

清單裡的測試檔，加上被改模組對應的測試檔（對應方式與 `quick` 相同）。一個都找不到 → `Tests: none`
並提醒補上。

印出 `START: unknown`（取不到分支起點，例如主 checkout 是 detached HEAD）→ **跑整套**
（指令尾端加 `# full-suite`，否則 `full-suite-gate` 會擋一次），`Tests:` 欄註明「取不到分支起點，改跑整套」。
寧可多跑，不要因為起點不明而少跑。這些指令都帶了路徑，`full-suite-gate` 不攔，不需要 `# full-suite`。

#### 唯一的例外：模板 repo 自己的 hook 測試依改動挑節

**只在模板 repo 本身適用**，判斷：根目錄有 `scripts/sync-ui-sources.sh`（與 `session-start.sh` 判斷
「這是模板 repo」用同一個檔；`copy-template` 不帶根目錄的 `scripts/`，新專案永遠不成立）。
**新專案一律照上表**——一般專案的整套幾十秒，依改動挑反而會漏測。
這裡例外是因為模板 repo 的測試是 hook 測試（`.claude/hooks/tests/run-tests.sh`）＋`check-counts.sh`，
整套在 Windows/Git Bash 上約 50 分鐘。

| 情境 | 跑什麼 |
|---|---|
| 主 checkout 的 `pre-pr` | `bash .claude/hooks/tests/run-tests.sh` 整套 |
| 其他所有情境（worktree、中間合併、最後一個合併） | `bash .claude/hooks/tests/run-tests.sh --changed <起點>`：worktree 用上方的分支起點；中間合併用 `ORIG_HEAD`（cherry-pick 用 `'HEAD@{1}'`）；主 checkout 其他情境用下方的起點 |

`check-counts.sh` 每次都跑。改動檔→節的對應表只寫在 `run-tests.sh` 的 `_changed_rule`。

主 checkout 的起點＝有合併時是**本輪第一個合併執行前的 HEAD**（`merge-gate.sh` 在合併前記下），
否則是**分支起點**：

```bash
TD="$(git rev-parse --show-toplevel)/.claude/taskmaster-data"
if [ -e "$TD/.merge-round-start" ]; then S=$(head -1 "$TD/.merge-round-start")
else
  DEF=$(git symbolic-ref -q --short refs/remotes/origin/HEAD | sed 's@^origin/@@')
  S=$(git merge-base HEAD "${DEF:-main}" 2>/dev/null)
  # 站在預設分支上（分支起點就是 HEAD）→ 從上一次涵蓋過的驗證點算
  [ "$S" = "$(git rev-parse HEAD)" ] && S=$(sed -nE 's/^sha=([0-9a-f]+) result=PASS clean=yes suite=(full|changed) .*/\1/p' "$TD/.last-verify" 2>/dev/null)
fi
[ -n "$S" ] && git merge-base --is-ancestor "$S" HEAD 2>/dev/null && echo "START: $S" || echo "START: unknown"
```

`START: unknown` → 跑整套。`--changed` 印「→ 整套」（或跑整套的任何情境）→ **放背景執行**：
Bash 工具單次最長 10 分鐘，整套約 50 分鐘。在 worktree 裡它會拒絕（exit 3），確定要跑才加 `--full`。
印「不跑」就只跑 `check-counts.sh`。主 checkout 依改動挑、起點不是 `unknown` 時，「記下這次驗證」的 `suite` 填 `changed`。

- 報告通過/失敗數量，失敗只附摘要——不要把整份輸出讀進來（格式見 `testing-standards` skill 的「執行測試」）
- 報告覆蓋率：只對照**這次改到的檔**（門檻見 `testing-standards` skill）

### 5. Console.log 稽核
- 搜尋原始碼中的 console.log
- 報告位置

### 6. Git 狀態
- 顯示未提交的變更
- 顯示自上次 commit 以來修改的檔案

### 7. 秘密掃描（僅 `pre-pr`／`pre-commit`）
- 掃這次變更（`git diff` 與未追蹤檔）裡的硬編碼秘密：API key、token、密碼、私鑰、連線字串
- 檢查清單見 `.claude/rules/security.md` 的「秘密管理」；有找到就列出檔案:行號，結果為 FAIL
- 其他 profile 不跑，輸出寫 `Secrets: skipped`

## 輸出

產出簡潔的驗證報告：

```
VERIFICATION: [PASS/FAIL]

Build:    [OK/FAIL]
Types:    [OK/X errors]
Lint:     [OK/X issues]
Tests:    [X/Y passed, Z% coverage]
Secrets:  [OK/X found/skipped]
Logs:     [OK/X console.logs]

Ready for PR: [YES/NO]
```

如有任何關鍵問題，列出並附修復建議。

## 記下這次驗證（給 `/pr` 沿用）

每次 `/verify` 做完步驟 1-7 與兩道關卡（合併、文件同步）、**進「任務完成銜接」之前**（PASS 或 FAIL）
都覆寫 `.claude/taskmaster-data/.last-verify`，一行，**欄位順序固定**
（`/pr` 與「標記與歸檔」第 0 步用固定順序比對）：

```bash
TD="$(git rev-parse --show-toplevel)/.claude/taskmaster-data"
LV="$TD/.last-verify"
# 執行時產物排除清單（唯一來源；pr.md 2a 與「標記與歸檔」第 0 步逐字沿用這一行）
SCOPE=(':(top)' ':(top,exclude).claude/taskmaster-data' ':(top,exclude).claude/context' ':(top,exclude).claude/coordination' ':(top,exclude).claude/qa-history')
CLEAN=yes
[ -n "$(git status --porcelain -- "${SCOPE[@]}")" ] && CLEAN=no
RESULT=<PASS|FAIL> SUITE=<full|changed|partial>
printf 'sha=%s result=%s clean=%s suite=%s secrets=%s spec=%s profile=%s at=%s\n' \
  "$(git rev-parse HEAD)" "$RESULT" "$CLEAN" "$SUITE" <yes|no> <yes|no> <profile> \
  "$(date '+%Y-%m-%dT%H:%M')" > "$LV"
case "$RESULT $CLEAN $SUITE" in "PASS yes full"|"PASS yes changed") echo "CLOSE-ROUND: yes" ;; esac
```

印出 `CLOSE-ROUND: yes` → 接著**單獨**跑 `rm -f .claude/taskmaster-data/.merge-round-open`，
再**單獨**跑 `rm -f .claude/taskmaster-data/.merge-round-start`
（從 repo 根目錄、字面路徑——含 `$` 或混了其他指令的 `rm`，`rm-state-gate` 會改成問使用者）。

| 欄 | 填什麼 |
|---|---|
| `suite` | 步驟 4 跑了整套才填 `full`；模板 repo 主 checkout 依改動挑、起點不是 `unknown` 填 `changed`（見步驟 4 的例外）；`quick`、worktree 內、中間合併一律 `partial`。`/pr` 只沿用 `full` |
| `secrets` | 步驟 7 跑了而且沒找到秘密才填 `yes` |
| `spec` | 本次跑了 `spec-convergence`（最後一個合併、`pre-pr`）才填 `yes` |

`clean=no` 表示驗的是含未 commit 變更的工作區，sha 代表不了驗過的程式碼，`/pr` 不會沿用。
**合併關卡通過、而合併還沒 commit**（`git rev-parse -q --verify MERGE_HEAD` 有輸出，解過衝突的那種）時：

- **由 `/worktree` 合併迴圈（或 `/task-next` 的平行合併）呼叫** → 先 commit 那個合併再寫——
  這就是迴圈「PASS → 這裡才 commit」那一步
- **其他情況**（使用者自己 `git merge --no-commit` 後跑 `/verify`）→ **不替使用者 commit**，照實寫
  `clean=no`。代價是之後 `/pr` 與第 0 步要再跑一次整套，但 commit 與否是使用者的決定

`SCOPE` 排除的四個目錄都是執行時產物，不影響建置與測試：`taskmaster-data/`（追蹤檔與狀態檔，
`.last-verify` 本身也在那裡）、`context/`（agent 報告）、`coordination/`（交接）、`qa-history/`（問答紀錄）。
後三個**進版控**，少排除任何一個，agent 一寫報告就讓 `clean=no`，第 0 步永遠過不了、重跑也沒用。

清掉 `.merge-round-open` 的理由：整套在乾淨工作區通過，本輪合併的結果就被整套涵蓋了（旗標見「中間合併：快檢」）。

## 寫回 plan 的「計畫 vs 實際」

緊接在「記下這次驗證」之後、**歸檔 plan 之前**（PASS 或 FAIL 都做；worktree 裡也做，寫的是 worktree 那份 plan）。
對應的 plan 照下方「Plan 驗收標準比對」的找法（`.current-task` → `plans/<值>.md` 或 `<值>-*.md`）；
找不到 plan 就跳過這一步，在輸出寫一句「無對應 plan，未寫回計畫 vs 實際」。

```bash
bash .claude/scripts/overview.sh --actual .claude/taskmaster-data/plans/<plan 檔名> --result <PASS|FAIL> --reason "<一句>"
```

- `--reason` 只有 FAIL 要帶，寫**一句**使用者看得懂的失敗原因（例：`2 個測試失敗：token 過期判斷用了本地時區`）；
  FAIL 沒帶 reason 腳本會 exit 2、不寫
- 腳本只改 plan 裡 `<!-- overview:actual:start -->` 到 `end` 之間的文字（再跑是取代），並重產專案圖解。
  區塊格式見 `plan-format` skill 的「計畫 vs 實際」節（唯一來源）
- 印出 `已寫入「計畫 vs 實際」…` 就完成，**不要 Read 剛寫的區塊來檢查**；之後要 Edit 這份 plan（勾 checklist、
  歸檔改 frontmatter）前照常先重讀，因為檔案剛被腳本改過
- exit 非 0 → 把它印的原因放進驗證報告，**不因此把驗證結果改成 FAIL**（這是圖解，不是驗證本身）

## Plan 驗收標準比對

若當前 `.current-task` 對應的 plan 存在（`.claude/taskmaster-data/plans/<值>.md` 或 `<值>-*.md`，
值可能是 WBS id 或 `adhoc-…` 檔名主幹），在步驟 1-7 驗證後：

1. 讀取 plan 檔的「驗收標準（整體）」checklist
2. 逐項比對前面驗證結果：
   - 「測試覆蓋率達門檻」→ 由步驟 4 結果填入，門檻依任務模式（見 `testing-standards` skill）
   - 「所有階段狀態為 ✅」→ 讀 plan frontmatter `status`
   - 「階段審查無未解的 CRITICAL/HIGH」→ 讀帳本（`<plan 同名>.progress.md`）或 `context/quality/`、
     `context/security/` 本任務的報告；審查節奏見 `rules/task-mode.md`。**`/verify` 不另派審查**
   - 其他自訂條件 → 呈現給使用者確認
3. **Plan 檔內的 checklist 同步勾選**（已通過的標 `[x]`）
4. 若全部 checklist 通過 → 視為整體驗收 PASS

**在 worktree 裡**：`.current-task` 是 worktree 自己那份（不跟主 checkout 共用），
由派工的第一步寫入（見 `worktree-orchestration` skill 的「派工」）。沒寫就對不到 plan——
這時在輸出寫明「無 `.current-task`，未比對 plan 驗收」，不要靜默跳過。

**相關規範：** `plan-format` skill

## 合併驗證關卡（不論有沒有進行中任務）

> 這一節**不依賴** `.current-task`。曾經放在「任務完成銜接」底下，結果沒有進行中任務時
> （主 checkout 合完分支直接 `/verify`，最常見的情境）清單永遠清不掉，只能手動刪——
> 手動刪就等於跳過了這道關卡。

讀 `.claude/taskmaster-data/.merge-pending`。這份清單由 `post-bash.sh` 在偵測到
`git merge`／`cherry-pick`／`rebase` 執行時累積（成功、衝突、非零結束都記）。清單非空表示：**有合併結果還沒被驗過**。

清單是空的（或不存在）→ 跳過本節。清單非空時，先判斷這是**中間合併**還是**最後一個合併**——
兩者驗的東西不同。

### 判準：是不是最後一個合併（唯一來源）

```bash
# 印出「還有 commit 沒合進來」的其他 worktree 分支。什麼都沒印 → 最後一個合併
CUR=$(git branch --show-current)
MH=$(git rev-parse -q --verify MERGE_HEAD)    # 合併還沒 commit 時，正在合的那條算已合
git worktree list --porcelain | awk '$1 == "branch" { sub("refs/heads/", "", $2); print $2 }' |
while read -r br; do
  [ "$br" = "$CUR" ] && continue
  [ "$(git rev-list --count "$br" --not HEAD $MH)" -gt 0 ] && echo "$br"
done
```

- **沒印任何分支 → 最後一個**。不是 worktree 開發的合併（一般分支、cherry-pick、rebase）
  自然印不出東西，所以照最後一個做——等於舊行為
- **有印 → 中間**。把印出的分支寫進輸出（`仍待合併：worktree-b, worktree-c`）
- **只能升級、不能降級**：印出的分支裡有不屬於本輪的 worktree（實驗、review PR 開的）時，
  判準會一直說「中間」。這時由合併迴圈或使用者明說「這是本輪最後一個」，照最後一個做。
  反方向——判準說最後一個，卻想當中間省掉整套——不允許

### 中間合併：快檢

只做這三項，其他（lint、整套、收斂檢查）留給最後一個合併：

1. 建置（步驟 1）、型別（步驟 2）
2. 測試：只跑**這次合併帶進來的檔案**對應的測試檔（對應方式同 `quick` profile）。
   帶進來的檔案：

   ```bash
   REF=ORIG_HEAD                        # merge／rebase：合併前的 HEAD；還沒 commit 的合併也涵蓋
   # REF='HEAD@{1}'                     # cherry-pick（它不設 ORIG_HEAD）
   F=$(git diff --name-only "$REF" 2>/dev/null)
   [ -n "$F" ] || F=$(git diff --name-only HEAD^1 HEAD 2>/dev/null)
   [ -n "$F" ] && printf '%s\n' "$F" || echo "MERGED-FILES: unknown"
   ```

   印出 `MERGED-FILES: unknown`（兩種找法都空或出錯）→ **改跑整套**，不要當成 `Tests: none` 通過。

3. 這條分支的 plan 驗收比對（有 plan 才做；怎麼找 plan 見下方「最後一個合併」第 1 點）

**三項都過就算通過** → 刪除 `.merge-pending`，**同一步**立起 `.merge-round-open`（本輪有合併還沒被整套涵蓋），
`pre-tool-use.sh` 的合併閘門放行下一個合併：

```bash
touch "$(git rev-parse --show-toplevel)/.claude/taskmaster-data/.merge-round-open"   # 合併只在主 checkout 做，toplevel 就是主 checkout
```

然後**單獨**跑 `rm -f .claude/taskmaster-data/.merge-pending`（從 repo 根目錄、字面路徑，`rm-state-gate`
才會自動放行）。先 touch 後 rm：中途斷掉的話留下的是「旗標在、清單也在」，往多驗的方向錯。

`.merge-round-open` 由「記下這次驗證」在整套（模板 repo 的 `changed` 也算）乾淨通過時清掉；它存在就讓「標記與歸檔」第 0 步生效。

> **為什麼中間可以只快檢**：每條線在 worktree 裡已經跑過自己的相關測試、每階段過了兩道審查；
> 合併新增的只有「兩邊碰面」的互動。快檢抓得到碰在同一批檔案上的互動；碰在別處的，
> 最後一個合併的整套會抓到，再用下方的二分找出是哪一個合併。代價是元凶要二分才找得到，
> 換來的是 N 個合併只跑一次整套。

### 最後一個合併：整套＋收斂

步驟 1-7 全做（步驟 4 跑整套；模板 repo 照步驟 4 的例外，從本輪起點依改動挑），另外：

1. **比對本輪每一個已合併任務的 plan 驗收標準**（**有 plan 才做**）—— 不只當前 `.current-task`。
   平行開發合了 N 個分支就有 N 份 plan，每一份的「驗收標準（整體）」都要過。
   對應的 plan 從 WBS 找：狀態不是 ✅ 但分支已合進來的那些；ad-hoc 的從
   `plans/INDEX.md` 找。**一份 plan 都對不到**（例如模板維護、臨時分支）→ 跳過這一步，
   在輸出寫明「無對應 plan，只做收斂檢查」，不要因此卡住。

2. **載入 `spec-convergence` skill 跑一次收斂檢查** —— 這是「合併後仍符合原本目標」
   的唯一實際檢查。它比對 `docs/00_brief.md`／PRD 與 `wbs.md`，查三件事：
   漏做、範圍蔓延、描述失真。**平行開發最容易踩的是第二項**：三個 agent 各自
   多做了一點「順手的改善」，單獨看都合理，合起來就偏離了當初講好的範圍。
   **只在最後一個合併跑**——中間合併時範圍還沒到齊，查「漏做」必然誤報。

3. **全部通過才刪除 `.merge-pending`**，同一步立起 `.merge-round-open`（指令同上方快檢）。
   整套是在這次跑的，「記下這次驗證」寫 `suite=full clean=yes` 時會立刻清掉它；
   清不掉（`clean=no`，例如合併還沒 commit）就留給第 0 步擋。

**任一項未過 → 不得刪除清單、不得標 WBS ✅。** 在主 checkout 修好再重驗；
修不動就退回那個合併（見下節）。

### 最後一個的整套紅了：二分找出是哪個合併

本輪只有一個合併 → 元凶就是它，不用二分：修好，或退回（還沒 commit 用 `git merge --abort`，
已 commit 用下方的 revert）。

本輪有多個合併 → 在本輪的 merge commit 之間二分。**每一步只跑整套裡紅掉的那幾個測試檔**，
不是再跑整套——整套已經告訴你哪些壞了，二分只需要知道「從哪個合併開始壞」。

```bash
# 0. 最後一個合併還沒 commit（解過衝突、/verify 前不 commit 的那種）→ 先 commit，
#    bisect 需要乾淨工作區。這個先 commit 的合併若就是元凶 → commit 之後用下方的 revert 退回
#    （已經 commit 了，不能再 git merge --abort）
git log --first-parent --merges --oneline -n <本輪合併數>     # 本輪的 merge commit，最新在上
ROUND_BASE=$(git rev-parse <最早那個 merge>^1)                # 本輪開始前

git bisect start --first-parent HEAD "$ROUND_BASE"            # HEAD 已知是壞的
#    git 會停在某個 merge commit → 只跑紅掉的測試檔 → git bisect good ／ git bisect bad
#    紅掉的測試檔在這個 commit 還不存在 → 標 good（它還沒進來，不可能壞在這裡）
#    直到 git 印出 "<sha> is the first bad commit"
git bisect reset
```

`--first-parent` 讓每一步都落在 merge commit 上（一次一個合併），不會掉進某條分支內部的
commit。本輪 ≤4 個合併最多 2 步。**先在 `ROUND_BASE` 跑一次那幾個測試檔**：它也紅 → 是本輪之前
就壞的，不是合併造成的，不要二分。

找到元凶 `M` 後二選一：

- **修好**：在主 checkout 修、commit，重跑 `/verify`（仍是最後一個合併 → 整套）
- **退回**：`git revert -m 1 <M>`，再重跑 `/verify`。那條分支回它的 worktree 修。
  ⚠️ **之後要再合同一條分支，先 `git revert <剛才那個 revert commit>` 再合**——
  否則 git 認為那些 commit 已經合過，修正以外的內容不會回來

> **為什麼要獨立一道關卡**：每個 worktree 自己 `/verify` 過了，但它們**看不到彼此** ——
> 合併才第一次讓兩邊的程式碼真的碰面，那些互動是全新的、沒有任何人驗過的程式碼。
> 而「一次一個 merge、每次都驗」原本只寫在 `worktree-orchestration` skill 裡，
> 是自律；`.merge-pending` 讓它變成機器保證——中間合併的快檢通過也算驗過。
>
> 逃生門：`MERGE_GATE=off`（連偵測與閘門一起關）。

## 文件同步關卡（不論有沒有進行中任務）

> 這一節**不依賴** `.current-task`，理由同上方合併關卡：沒有進行中任務時（合完分支直接
> `/verify`、ad-hoc 修改）清單一樣會累積，放在「任務完成銜接」底下就永遠不會被問到。

讀 `.claude/taskmaster-data/.doc-impact`。這份清單由 `post-write.sh` 自動累積——
本任務改到過的「文件會描述的檔案」（API／路由／schema／對外介面／migration／CLI）。

**清單非空時，必須用 `AskUserQuestion` 問一題再往下**：

```
本任務改到 3 個文件會描述的檔案：
  src/api/reconcile/route.ts
  src/models/ledger.ts
  src/api/index.ts

文件要怎麼處理？
  [Recommended] 委派 documentation-specialist 同步
      從程式碼反推 codemap／API 文檔／技術 README，一次處理完清單上全部檔案
  我已經自己更新過了
      標記完成，不再詢問
  這次不需要（記錄原因）
      寫進 plan 的「未同步文件」欄（沒有 plan 就寫在本次輸出），下次碰到同一批檔案還會再問
```

- 選第一個 → 用 `Agent` 工具，`subagent_type: "documentation-specialist"`，
  **把 `.doc-impact` 的完整清單放進 prompt**（它需要知道要看哪些檔案）
- 三個選項任一完成後 → 刪除 `.doc-impact` 與 `.doc-impact-notified`
- 清單為空 → 不問，直接往下

> **為什麼要擋**：新需求／客戶 CR 的程式一定會被寫出來，但文件常常沒跟上。
> 原因是 `documentation-specialist` 在任務完成路徑上原本沒有位置——`/verify` 只驗
> 建置/型別/lint/測試，從不問文件。這道關卡是唯一會強迫做這個決定的地方。
>
> 逃生門：環境變數 `DOC_SYNC_GATE=off`（連偵測一起關）。

## 任務完成銜接

若 `.claude/taskmaster-data/.current-task` 存在（表示有進行中的任務），且驗證結果為 PASS：

### 0a. 合併驗證關卡

見上方「合併驗證關卡（不論有沒有進行中任務）」（唯一來源，勿在此重述）。
清單非空且未通過 → **不得往下做 0b、不得標 WBS ✅**。

### 0b. 文件同步關卡

見上方「文件同步關卡（不論有沒有進行中任務）」（唯一來源，勿在此重述）。
清單非空且未處理 → **不得標 WBS ✅**。

### 標記與歸檔

> **在 worktree 裡跑的話：跳過這一整節。**
>
> 判斷方式：`git rev-parse --git-dir` 的結果含 `worktrees/`，或當前路徑在
> `.claude/worktrees/` 底下。
>
> 理由是實測出來的：`wbs.md`、`plans/INDEX.md` 這些追蹤檔如果被 N 個 worktree
> 各改一次，合併時**必定**衝突——而且相鄰任務各自標 ✅ 的情況下，
> `merge=union` 會靜默產出重複且狀態矛盾的列（試過，比報衝突更糟）。
>
> 所以 worktree 內的 `/verify` 只驗**程式碼**（步驟 1-7 ＋ plan 驗收標準比對——
> 後者需要 worktree 內已寫 `.current-task`，見上方「Plan 驗收標準比對」），
> 驗完就停，回報「本 worktree 驗證通過，可以合併」。
> **WBS 與 plan 的歸檔統一在主 checkout、全部合併完成後做一次**——
> 那是 `commands/worktree.md` 合併迴圈的最後一步。

在**主 checkout** 執行時：

0. **前置：合併過的任務，整套必須已經涵蓋到現在的程式碼。** 要不要做由下面的 shell 判斷
   （`.merge-round-open` 存在或 `.merge-pending` 非空才檢查），不靠記憶判斷「這次有沒有合併過」：

   ```bash
   TD="$(git rev-parse --show-toplevel)/.claude/taskmaster-data"
   LV="$TD/.last-verify"
   # 同「記下這次驗證」的 SCOPE（唯一來源，逐字沿用）
   SCOPE=(':(top)' ':(top,exclude).claude/taskmaster-data' ':(top,exclude).claude/context' ':(top,exclude).claude/coordination' ':(top,exclude).claude/qa-history')
   SHA=$(sed -n 's/^sha=\([0-9a-f]*\) .*/\1/p' "$LV" 2>/dev/null)
   if [ ! -e "$TD/.merge-round-open" ] && [ ! -s "$TD/.merge-pending" ]; then
     echo "FULL-COVERED: n/a（本輪沒有未涵蓋的合併）"
   elif [ -n "$SHA" ] && grep -qE ' result=PASS clean=yes suite=(full|changed) ' "$LV" 2>/dev/null \
      && git merge-base --is-ancestor "$SHA" HEAD 2>/dev/null \
      && D=$(git diff --name-only "$SHA" HEAD -- "${SCOPE[@]}" 2>/dev/null) && [ -z "$D" ]; then
     echo "FULL-COVERED: yes"
   else
     echo "FULL-COVERED: no"
   fi
   ```

   印出 `yes` 或 `n/a` 才往下標 ✅。印出 `no`、沒有輸出、或指令出錯 → **先照「最後一個合併：整套＋收斂」
   再跑一次 `/verify`**，通過後再回到這裡。工作區有還沒 commit 的合併（`MERGE_HEAD` 存在）時重跑也只會得到
   `clean=no`——先請使用者 commit 再重跑，不要替他 commit。
   這一步擋的是判準被清單外的 worktree 誤判成「中間」、整套從沒跑過卻標了 ✅。
   （所以「記下這次驗證」必須在本節之前寫好，見該節。）

1. 將 WBS 該任務狀態更新為 `✅ MM-DD`（完成日；驗證數據**不寫進格子**——
   它屬於 plan 的驗收或評估報告，WBS 連結欄放 `[報告](…)` 即可）。
   **`.current-task` 以 `adhoc-` 開頭 → 跳過這步與下方所有改 WBS 的子步驟**（它不在 WBS 裡；
   補登與否由「Ad-hoc plan 完成後：補登 WBS」那節問）
2. 清除 `.current-task`
3. **Plan 歸檔**（若存在對應 plan 檔）：
   - 將 plan frontmatter 標 `status: "✅ 完成"`、`archived: "YYYY-MM-DD"`
   - 移動至 `.claude/taskmaster-data/plans/archive/`（目錄不存在則建立）
   - **同名的執行帳本 `<plan 同名>.progress.md` 一起搬到 `archive/`**（若存在）——
     留在 `plans/` 會讓下次同 ID 的任務誤認為「有續跑中的帳本」
   - 更新 `plans/INDEX.md`：該行的狀態改為 `✅ 完成（已歸檔）`，路徑改為 `archive/<filename>`
   - **更新 WBS 該任務的 `連結` 欄**：計畫（與帳本）改指 `plans/archive/<filename>`
     （漏掉這步，歸檔後從 WBS 點過去會是死連結）
   - **重算 WBS「現況」區**與總進度（規則見 `.claude/templates/wbs.template.md` 第 3 節，唯一來源）
4. 用 `AskUserQuestion` 詢問下一步（遵守 `.claude/rules/interactive-qa.md`）：
   - 「繼續下一個任務」(Recommended) — 自動執行 `/task-next` 流程
   - 「開 PR（`/pr`）」 — 這個分支的工作告一段落時
   - 「查看目前進度」 — 顯示 WBS 狀態摘要
   - 「結束，稍後再繼續」 — 停止

   這樣使用者不用手動再跑 `/task-next`，形成 **自動任務接力**，且計畫自動歸檔不佔主目錄。

## 里程碑完成時：規格收斂 → 提議歸檔

標記任務為 ✅ 後，檢查**該任務所屬的里程碑是否全部完成**
（所有任務皆為 ✅ 完成 或 ⏭️ 跳過）。若是，依序做兩件事：

### 1. 先跑規格收斂（**里程碑是唯一該做完整收斂的時機**）

載入 `spec-convergence` skill 跑完整檢查（A 漏做 ／ B 範圍蔓延 ／ C 描述失真）。

順序不能反：歸檔會把已完成任務移到 `wbs-archive.md`，收斂檢查需要同時讀兩個檔，
先歸檔不會壞掉但報告會少掉「這個里程碑做了什麼」的脈絡。

> **為什麼是里程碑而不是每個任務**：單一任務很少讓整份規格跑掉，每次都跑只會
> 變成被忽略的噪音。里程碑是「一批工作完成」的自然邊界，也是客戶會來驗收的時點。

### 2. 再提議歸檔

用 `AskUserQuestion` 問：

```
🎉 里程碑「M1: MVP」全部完成（12 個任務 / 預估 24.5h / 實際 27h）

要歸檔嗎？歸檔後 wbs.md 只留活躍任務，歷史移到 wbs-archive.md。
```

- **歸檔**（Recommended）— 執行 `/task-status` 定義的歸檔程序
- **先不要，我想再看看** — 不動

**完整歸檔程序見 `.claude/commands/task-status.md` 的「WBS 歸檔」節**（唯一來源，勿在此重述）。

## Ad-hoc plan 完成後：補登 WBS

若本次驗收的是 **ad-hoc plan**（`plans/adhoc-*.md`，`wbs_task: "none"`）且結果為 PASS，
在歸檔後**必須**用 `AskUserQuestion` 問一題：

```
剛完成的是臨時任務（未登記在 WBS）：<plan 標題>

要補登到 WBS 嗎？補登後進度統計與時間報表才會涵蓋它。
```

- **補登為已完成**（Recommended）— 追加一行到 `wbs.md` 的當前里程碑節，狀態直接標 `✅ MM-DD`，
  模組欄與負責欄填 `—`、連結欄填 `[計畫](plans/archive/<filename>)`，並重算「現況」區（版面見 `.claude/templates/wbs.template.md`）。
  寫入前先讀該節表頭，依該表頭的欄位寫；表頭沒有「模組」欄就不寫那一格（範本第 2 節「依表頭寫入」）
- **不用，這是一次性的** — 不動 WBS
- **補登並順便加後續任務** — 補登後接 `/task-add` 流程

> 不補登會讓 WBS 逐漸偏離實際做過的事，`/task-status` 與 `/time-log` 的統計也會失真。

## 參數

$ARGUMENTS 可以是：
- `quick` - 建置 + 型別 + **只跑這次改到的測試檔**（`git diff --name-only` 裡的測試檔，以及和被改檔案對應的測試檔）。quick 要求寫的那 1 個 happy-path 測試就是在這裡被執行；一個都找不到就在報告寫 `Tests: none` 並提醒補上（純文案／樣式改動除外）
- `full` - 所有檢查（預設）
- `pre-commit` - 與 commit 相關的檢查
- `pre-pr` - 完整檢查加安全掃描，**再跑規格收斂的 A+B**（載入 `spec-convergence` skill；跳過檢查 C，太慢）。
  **在 worktree 裡跑時不跑整套**（照步驟 4 的 worktree 那列），輸出的 `Tests:` 要寫明「worktree 內，這次沒跑整套」

## 自動 Profile 選擇（依任務模式）

若使用者**未指定** `$ARGUMENTS`，讀取 `.claude/taskmaster-data/.current-task-mode`：

| 任務模式 | 自動 profile |
|---|---|
| `quick` | `quick` |
| `standard` | `full` |
| `critical` | `pre-pr` |
| 檔案不存在 | `full`——只是取保守的檢查組合，**不等於**把任務判成 standard（判級見 `task-mode.md`） |

使用者明確帶入 `$ARGUMENTS` 時優先採用使用者選擇。

**相關規範：** `.claude/rules/task-mode.md`

## 任務完成後清除狀態檔

第「任務完成銜接」階段標記 WBS 為 ✅ 後，**同步清除**這些檔案，避免下個任務沿用舊狀態：

| 檔案 | 不清的後果 |
|---|---|
| `.current-task` | 下個任務被誤認為同一個 |
| `.current-task-mode` | 沿用舊的任務模式（TTL 8h 是機器保底，但不該靠它） |
| `.doc-impact` ・ `.doc-impact-notified` | 下個任務一開始就被上個任務的文件債擋住 |
| `.learned-notified` | 下個任務踩坑時不再提醒 `/learn`（`post-bash.sh` 每個任務只提醒一次） |
| `.pitfall-seen` | 不需清 —— 它由 `session-start.sh` 每個 session 重置 |
| `.report-expectations.jsonl` | 不需清 —— 由稽核器自己按 deadline 汰除 |
| `.last-verify` | 不需清 —— 它綁 HEAD sha，程式碼一動就自動失效。清掉反而讓最常見的「`/verify` → 標 ✅ → `/pr`」必須重跑整套 |
| `.merge-round-open` | **不要手動清** —— 只由「記下這次驗證」在整套（模板 repo 的 `changed` 也算）乾淨通過時清。手動刪等於跳過第 0 步 |
| `.merge-round-start` | **不要手動清** —— 跟 `.merge-round-open` 同時清（`CLOSE-ROUND: yes`）。它是 `merge-gate.sh` 在本輪第一個合併前記下的起點 |
