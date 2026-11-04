# skill-curator — 平行開發驗證精簡（2026-11-03）

分支：`refactor/streamline-verification`（未 commit，交主模型審查後 commit）

## 目標

3 條 worktree 線 × 3 階段時，整套測試從 7 次（worktree 內 /verify ×3、每次合併後 /verify ×3、
/pr 的 /verify pre-pr ×1）降到 1 次（最後一個合併後）。每階段的相關測試與兩道階段審查不動。

## 五項改動

| # | 改動 | 唯一來源 | 指標 |
|---|---|---|---|
| 1 | worktree 內 `/verify` 只跑本線相關測試（分支起點＝`git merge-base HEAD <主 checkout 當前分支>`） | `commands/verify.md` 步驟 4 | `testing-standards`「執行測試」第三列與閘門說明、`full-suite-gate.sh` 訊息、`worktree-orchestration` 合併第 1 步註解、`hooks/README.md` |
| 2 | 中間合併快檢、最後一個才整套＋spec-convergence；「最後一個」判準＝`git worktree list` 裡沒有領先 HEAD 的其他分支（只能升級不能降級）；整套紅了用 `git bisect --first-parent` 在本輪 merge commit 之間二分（每步只跑紅掉的測試檔） | `commands/verify.md`「合併驗證關卡」 | `worktree-orchestration`「合併回 main」、`commands/worktree.md` 迴圈、`post-bash.sh` 與 `merge-gate.sh` 訊息 |
| 3 | 刪掉 subagent-execution 的「全域最終審查」 | `rules/task-mode.md` 審查節奏（原本就是） | `subagent-execution` 第 11、49 行、`guides/WORKFLOW.md` 第 78 行 |
| 4 | `/verify` 每次寫 `.last-verify`（sha/result/clean/suite/secrets/spec），`/pr` 步驟 2a 用 shell 比對決定沿用 | 格式：`commands/verify.md`「記下這次驗證」；比對：`commands/pr.md` 2a | `worktree-orchestration` 狀態邊界表（WORK_CLAUDE 欄） |
| 5 | /pr 把關鏈的 code-quality-specialist 只審沒被階段審查看過的 commit＋`--remerge-diff` 有輸出的 merge；帳本「審查通過」行加 `範圍=A..B` | 找法：`commands/pr.md` 2c；帳本格式：`subagent-execution`「帳本要記什麼」 | `commands/tdd.md` 步驟 4 |

## 選層理由（第 4 項）

依 writing-extensions 決策表：

- **不是 PreToolUse 閘門**：「要不要重跑」不是對錯判斷，沒有要 deny 的東西
- **不是 hook 注入**：`/verify` 通過沒有對應的工具事件（它是 slash command 流程，PASS 是模型的判讀），
  寫入點只能在指令裡；比對點在 `/pr` 步驟 2，這一步本來就一定會執行，用 UserPromptSubmit 偵測 `/pr`
  再注入只是把同一段比對搬到 hook，多一支要測的程式而沒有多保證什麼
- **所以放在 command 內的明確 shell 步驟**：比對由 shell 做（sha、祖先關係、diff 排除 taskmaster-data、
  工作區乾淨），模型只讀 `REUSE: yes/no`。**失效方向是安全的**：模型忘了寫或忘了比對 → 照常重跑，
  不會少驗

狀態檔歸屬：WORK_CLAUDE（跟著 checkout）——它描述的是「這個 checkout 的 HEAD 驗過了」。
沒有 hook 讀寫它，所以不經 `resolve-roots.sh`；指令裡用 `git rev-parse --show-toplevel` 定位，
在 worktree 裡自然是 worktree 那份。不列進「任務完成後清除」：它綁 sha，程式碼一動就失效，
清掉反而讓「/verify → 標 ✅ → /pr」必須重跑。

## 與使用者核准範圍的出入

1. **「HEAD 相同」放寬為「HEAD 相同，或之後的 commit 只動了 `.claude/taskmaster-data/`」**。
   理由：`/verify` 在主 checkout 通過後會標 WBS ✅、歸檔 plan，那些改動 commit 之後 HEAD 必然不同，
   照字面判斷會讓最常見的路徑永遠沿用不到。排除的只有追蹤檔與狀態檔，不影響建置與測試。
2. **pre-pr 沿用 full 時補兩項而非一項**：秘密掃描＋`spec-convergence` A+B（pre-pr 定義本來就含 A+B）。
   最後一個合併跑過收斂時 `spec=yes`，就只補秘密掃描。
3. **conflict-resolver 的測試步驟改成只跑解過衝突的檔案對應的測試**（原為整套 `# full-suite`）。
   不在五項字面範圍內，但不改的話每個有衝突的中間合併仍各跑一次整套，目標「1 次」達不到；
   它原文也寫著「/verify 會跑 spec-convergence」，在第 2 項之後是錯的。可退回。
4. **二分每一步只跑紅掉的測試檔，不是整套**（使用者寫「最多 2 次整套」）。整套已經指出哪些壞了，
   二分只需要知道從哪個合併開始壞，跑整套是浪費。
5. 中間快檢**不跑 lint**（照使用者定義的快檢範圍），lint 留給最後一個。

## 風險

- **判準會被清單外的 worktree 卡在「中間」**（實驗、review PR 開的）。處理：只能升級不能降級，
  合併迴圈合最後一個時明說。漏說的後果是那次只快檢、整套延到 `/pr`（`.last-verify` 的 suite=partial
  不會被沿用，所以 `/pr` 會跑整套）——但 WBS ✅ 已在整套之前標掉。
- **快檢抓不到「碰在不同檔案上」的互動**，要到最後一個才發現，再靠二分定位。這是用二分成本換整套次數。
- **`.gitignore` 需要加 `.claude/taskmaster-data/.last-verify`**——根目錄檔案不在我的寫入範圍。
  順帶發現 `.full-suite-warned`（既有閘門的標記檔）也沒列。沒加的話未追蹤檔會讓 `git status` 不乾淨；
  2a 與寫入端的乾淨檢查都排除了 `taskmaster-data/`，所以比對本身不受影響。既有專案的 `.gitignore`
  不會被 `update-template` 更新，要手動加。
- **帳本 `範圍=` 是新格式**，舊帳本沒有 → /pr 退回審整條分支（保守方向）。
- 測試時發現：在**專案外的另一個 repo** 裡跑 `git merge`，`post-bash.sh` 會把它記進本專案的
  `.merge-pending`（`resolve_roots` 找到的 `.git` 不屬於本專案時退回 MAIN）。已手動清掉，未改。

## 驗證

- 判準、分支起點、`--first-parent` 二分、`--remerge-diff`、帳本範圍解析、`.last-verify` 寫入與四種比對情境
  （無紀錄／HEAD 相同／只多了 taskmaster-data commit／工作區髒／程式碼有新 commit）都在 scratchpad 的拋棄式 repo 實跑過
- hook 測試：`通過 812 ・ 失敗 0`（新增 5 條：merge-gate deny 訊息含「只快檢」「快檢通過也算」、
  post-bash 合併成功訊息含「最後一個才跑整套」、full-suite-gate 訊息不再把 `/verify` 列為整套出口且含「整套留給合併回主 checkout 之後」）
- check-counts：不帶 `--tests` 695 項全部一致；`--tests 812` 698 項中 1 項不一致——根目錄 `README.md:95`
  仍寫 807（不在寫入範圍，已建 handoff 給 documentation-specialist）
- hook 改動只有訊息文字（`merge-gate.sh`、`post-bash.sh`、`full-suite-gate.sh`），閘門邏輯與事件接線沒動，
  所以 `settings.json`／`hooks/README.md` 檔案樹不用同步（README 只改了 full-suite-gate 那句出口說明）
- **未驗證行為改變**：沒有跑 skill-compliance。模型會不會照 verify.md 判「中間／最後」、會不會跑 2a 的比對，
  只能在有應用程式碼的專案實跑平行開發才看得到

## 審查修復 R1（code-quality-specialist）

原則：空輸出或指令失敗一律往多跑測試的方向走。

| 項 | 修法 | 位置 |
|---|---|---|
| HIGH-1 判準誤判成「中間」→ 整套從沒跑過就標 ✅ | 「標記與歸檔」加第 0 步：本次 `/verify` 開始時 `.merge-pending` 非空、或合併迴圈的最後一步 → 用 shell 檢查 `.last-verify`（`result=PASS clean=yes suite=full`、sha 是 HEAD 的祖先、之後的 diff 扣掉 taskmaster-data 為空），只有印出 `FULL-COVERED: yes` 才標 ✅，否則先跑一次整套 `/verify`。為了讓第 0 步讀得到，`.last-verify` 的寫入時機改成「兩道關卡之後、任務完成銜接之前」；合併還沒 commit 時先 commit 再寫（否則 clean=no 會讓解過衝突的最後一個合併被迫再跑一次整套） | `commands/verify.md:322-341`、`:87-89`、`:105-107`；`commands/worktree.md:111` 只放指標 |
| M1 快檢的 diff 空了或出錯會被當成 Tests: none 通過 | `ORIG_HEAD`／`HEAD@{1}` 找不到 → 退回 `HEAD^1 HEAD`；還是空 → 印 `MERGED-FILES: unknown` → 改跑整套 | `commands/verify.md:172-181` |
| M2 舊版 git 沒有 `--remerge-diff`，報錯會被當成乾淨合併 | 先探測一次，有問題就印 `NO-REMERGE-DIFF`，跟 BAD-RANGE 一樣是退回審整個 diff 的條件 | `commands/pr.md:101`、退回條件段 |
| M3 worktree 取不到分支起點 → 跑的測試變少 | `START: unknown` → 跑整套（加 `# full-suite`），並在輸出註明；testing-standards 的合法出口補上這條退路 | `commands/verify.md:38-48`、`skills/testing-standards/SKILL.md:40-41` |
| L1 worktree.md 重述了判準 | 改成只放指向 verify.md 的指標 | `commands/worktree.md:105-106` |
| L2 二分步驟 0 | 補一句：先 commit 的那個合併若就是元凶，commit 之後用 revert 退回 | `commands/verify.md:222-224` |

R1 的 shell 都在拋棄式 repo 實跑過：FULL-COVERED 測了五種情況（過期、partial、HEAD 上的 full、壞 sha、沒有檔案），結果都對；MERGED-FILES 的退回、START unknown、NO-REMERGE-DIFF 的探測也都測過。
沒有動 hook，所以依指示沒有重跑 run-tests.sh。check-counts 不帶 --tests 時 695 項全部一致。

## 審查修復 R2（code-quality-specialist 複審 `context/quality/code-quality-specialist-2026-11-04-0900.md`）

| 項 | 修法 | 位置 |
|---|---|---|
| HIGH clean 死結（只排除 taskmaster-data，agent 報告一寫 clean=no、第 0 步永遠 no） | 排除清單改成 bash 陣列 `SCOPE`，四個執行時產物目錄（`taskmaster-data`／`context`／`coordination`／`qa-history`）。唯一定義在 verify.md「記下這次驗證」，另兩處逐字沿用並註明來源 | `commands/verify.md`「記下這次驗證」、第 0 步；`commands/pr.md` 2a |
| MEDIUM `/verify` 隱含替使用者 commit | 只有 `/worktree` 合併迴圈（或 `/task-next` 平行合併）呼叫時先 commit；使用者手動 `--no-commit` 後跑 `/verify` → 不 commit，照實寫 `clean=no`；第 0 步遇到這種情況提示先請使用者 commit | `commands/verify.md`「記下這次驗證」、第 0 步結尾 |
| 第 0 步適用條件機械化 | 新旗標 `.merge-round-open`（MAIN；合併只在主 checkout 做，用 `--show-toplevel` 定位即主 checkout）。中間快檢**與最後一個合併**通過、刪 `.merge-pending` 的同一步 touch；「記下這次驗證」`PASS yes full` 時印 `CLOSE-ROUND: yes` 再單獨 rm；第 0 步 shell 先判 `[ -e flag ] || [ -s .merge-pending ]`，都不成立印 `FULL-COVERED: n/a` | `commands/verify.md` 快檢、最後一個合併第 3 點、記下這次驗證、第 0 步、清理表；`.gitignore`；`worktree-orchestration` 狀態邊界表 MAIN 欄 |
| LOW 步驟 4 字面不一致 | 「整套只在主 checkout 跑」補「worktree 裡取不到分支起點的退路除外」 | `commands/verify.md` 步驟 4 |

### 與審查建議的出入

1. **最後一個合併也 touch 旗標**（審查只寫中間快檢）。理由：旗標若只在中間快檢立，單一個合併、
   或最後一個合併以 `clean=no` 收尾（`--no-commit` 未 commit）時，第 0 步執行當下 `.merge-pending`
   已被刪、旗標也不存在 → 跳過檢查，比 R1 的「開始時 `.merge-pending` 非空」還鬆。
   最後一個立了旗標，整套乾淨通過時「記下這次驗證」立刻清掉，正常路徑沒有額外成本。
2. **rm 不放在 shell 片段裡**。`rm-state-gate.sh` 只對「單獨一條、字面路徑」的狀態檔 `rm` 自動放行；
   `rm -f "$TD/..."` 或混在其他指令裡會改成 `ask`（實測：前者 `allow`、後者 `ask`）——
   照審查建議的寫法會讓每個合併都跳權限詢問，正是 2026-10-27 使用者回報過的問題。
   所以寫入端印 `CLOSE-ROUND: yes`、快檢端先 `touch` 再單獨 `rm -f .claude/taskmaster-data/.merge-pending`。
   先 touch 後 rm：中途斷掉時錯在多驗的方向。
3. **`SCOPE` 三處各有一份字面相同的行**，不是物理上的單一定義：shell 狀態不跨 Bash 呼叫，指令片段必須自足。
   漂移風險靠註解指回 verify.md；若要機器保證，可在 `check-counts.sh` 加一項「三處 `SCOPE=` 行一致」（本輪未做，範圍外）。

### 驗證

- pathspec 在拋棄式 repo 實測（git status 與 git diff 皆正確）：四目錄的修改與未追蹤檔（含整個目錄未追蹤時的 `?? dir/` 收合）都被排除；
  從子目錄執行結果相同（`:(top)` 生效）；`.claude/contextual/` 不會被 `.claude/context` 誤排除；程式碼檔照常出現
- 旗標流程六種情境：無旗標 → `n/a`；有旗標無紀錄 → `no`；有未追蹤 agent 報告下整套 PASS → clean=yes、印 CLOSE-ROUND；
  旗標＋有效紀錄 → `yes`；程式碼髒 → clean=no、旗標留著、`no`；partial PASS → 旗標留著、`no`
- `rm_state_gate` 直接呼叫：`rm -f .claude/taskmaster-data/.merge-round-open` → allow；`rm -f "$TD/.merge-round-open"` → ask
- 沒有動 hook，未跑 run-tests.sh。check-counts `--tests 812`：698 項全部一致
- **未驗證行為改變**：模型會不會照做 touch／CLOSE-ROUND／第 0 步，只能在有應用程式碼的專案實跑平行開發才看得到
