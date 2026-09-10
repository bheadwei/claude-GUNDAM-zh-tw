---
wbs_task: "none"
slug: "git-workflow-rules"
created: "2026-09-09"
updated: "2026-09-11"
archived: "2026-09-11"
status: "✅ 完成"
current_phase: 5
files:
  - ".claude/rules/git-workflow.md"
  - ".claude/hooks/lib/git-backup-gate.sh"
  - ".claude/hooks/pre-tool-use.sh"
  - ".claude/hooks/tests/run-tests.sh"
  - ".claude/skills/writing-extensions/SKILL.md"
  - "scripts/check-counts.sh"
---

# 實作計畫：git 工作流的三條鐵律 + backup tag 閘門

> **⚠️ 執行中修正（2026-09-09）：四條改三條，`commands/pr.md` 移出 `files:`。**
>
> 使用者指出這個檔名以前存在過、因重複打架被刪。查證屬實：`commit 7596b1d`
> 「refactor: 消除跨層重複」刪掉它，理由是 PR 那半已被 `commands/pr.md` 取代且更好。
>
> **第 4 條「commit → push → PR 為單一連貫操作」撤回** —— 它正是被刪掉的那個類別，
> 且與 `commands/pr.md` 的兩次 `AskUserQuestion` 和 `rules/interactive-qa.md:5`
> 「所有決策點必須用 AskUserQuestion」**直接矛盾**。
>
> 完整分析見 ADR 的「⚠️ 修正（同日）」那節。下方階段 1 的第 4 條**不要實作**。

## 目標

模板目前**沒有任何 git 工作流的常駐規範**。補上四條鐵律，其中「destructive 操作前打
backup tag」做成機器強制的閘門而不是文字規則。完成後：在 main 上要改 code 會被提醒、
多 session 併行時 ref 被別人推進會被察覺、`reset --hard` 之類的操作在沒有安全快照時
會被擋下來。

## 背景

決策與完整評估見 **`.claude/context/decisions/2026-09-09-adopt-git-workflow-from-godzilla-z.md`**
（先讀它，本檔不重述取捨理由與「明確不採納」的清單）。

來源是使用者 pull 的另一套模板 `D:\模板\claude-Godzilla-z`。使用者已核准採用範圍：
四條鐵律 + backup tag 做成 hook + `writing-extensions` 補收錄判準。

促成的兩個現場證據：

1. **多 session 衝突今天真的發生了** —— 壓力測試的受測 session 撞見同機另一個 session
   的未提交改動，靠「我記得開始時工作區是乾淨的」才發現，純屬運氣
2. **本 session 自己違反「先開分支」十幾次** —— 全部直推 main。`commands/pr.md:14`
   確實會在 main 上時攔，但那是**程式碼已經寫完之後**

## 技術依賴 / 既有資產

- `.claude/hooks/lib/merge-gate.sh` —— **拆 lib 的先例，照它的形狀寫**：
  一個函式、命中時自行輸出 deny JSON 並 exit、逃生門用環境變數
- `.claude/hooks/pre-tool-use.sh` —— 已有 4 道閘門，是最複雜的一支。
  CLAUDE.md 明文要求「再加要拆 lib」，所以新閘門**必須**是 lib
- `.claude/commands/pr.md` —— PR 流程唯一來源。第 14、16 行已有分支與乾淨度檢查，
  新 rule 要指向它，不要重述
- `.claude/rules/coding-style.md` —— commit message 格式的唯一來源，同樣不重述

## 階段拆解

### 階段 1: `rules/git-workflow.md`（只放四條鐵律）✅

- [x] 開頭寫明收錄判準：**只留每次 git 操作都成立、而且與模型預設行為不同的約束**；
      細則指向 `commands/pr.md`（PR）與 `coding-style.md`（commit 格式）
- [x] 四條鐵律，每條都要寫「為什麼」而不只是「要這樣做」：
      1. **先開分支** —— 收到開發任務的第一步跑 `git branch --show-current` + `git status`；
         在 main 上、工作區 dirty、或使用者沒指定分支就要改 code → 停止並詢問。
         不用 `git stash` 當工作流替代品。分支命名 `<type>/<short-description>`
      2. **多 session ref 驗證** —— 任何 git 寫操作前確認 ref 沒被別處推進。
         列出警訊清單（工作樹有不認得的變更、同 subject 不同 SHA、分支 tip 與上次所見不同、
         出現未追蹤的 backup tag 或 sibling branch、HEAD 指向不認得的 commit）
      3. **destructive 先打 backup tag** —— 並註明**這條由 hook 強制**，指向階段 2
      4. **commit → push → PR 為單一連貫操作** —— 使用者說「做完了」就一氣呵成，
         禁止中間插入「要不要 push？」。例外：使用者明說只要 commit／只要 push、
         merge 到共享分支、destructive 操作
- [x] **不要**寫 commit message 細則、PR body 結構、tangled history 恢復策略 ——
      那些屬按需內容，前兩者已有唯一來源，第三個這輪不做
- **預估**：50min
- **驗收**：全檔 ≤ 80 行（常駐 rule 的成本是注意力，不只 token）；
      `rg 'commit message|PR body'` 在本檔應該只出現「見 XXX」的指向，不出現細則本身

### 階段 2: `lib/git-backup-gate.sh` ✅

- [x] 偵測 `git reset --hard`／`git push --force`（含 `-f`／`--force-with-lease`）／
      `git branch -D`／`git rebase`
- [x] 命中時檢查**是否已有可用的安全快照**：當前分支有 `backup/<branch>-*` tag
      且指向當前 HEAD → 放行；否則 deny 並在訊息裡給出**可直接複製的指令**
      （含算好的 tag 名與當前 oid）
- [x] `--force-with-lease` 要不要放行：**不要特例放行**。它防的是覆蓋別人的 push，
      不是防自己弄丟本地工作，兩者不同
- [x] `git rebase --continue`／`--abort`／`--skip` 放行（收拾當前狀態，不是新的 destructive 操作）
      —— 照 `merge-gate.sh` 既有的做法
- [x] 逃生門：`GIT_BACKUP_GATE=off`；並尊重 `.suggest-mode` = off
- [x] **`.suggest-mode` 一律讀 `MAIN_CLAUDE`**（專案級設定，見 `worktree-orchestration`
      的隔離邊界表）。`pre-agent-gate.sh` 讀成 `WORK_CLAUDE` 是既有的不一致，
      **不要跟著抄錯**
- **預估**：1h
- **驗收**：手動驗四種 destructive 指令都被擋、打了 tag 之後放行、三個 `--continue` 類放行

### 階段 3: 接進 `pre-tool-use.sh` ✅

- [x] 照 `merge-gate.sh` 的接法 source + 呼叫（確定是 Bash 工具且取得 COMMAND 之後）
- [x] 放在 merge-gate **之後**（merge 衝突的處置優先於 destructive 檢查）
- **預估**：20min
- **驗收**：`bash .claude/hooks/tests/run-tests.sh` 既有 209 案例全綠

### 階段 4: 測試 ✅

- [x] 新增案例：四種 destructive 指令各擋一次、有 tag 時放行、tag 指向舊 commit 時仍擋、
      `--continue`／`--abort`／`--skip` 放行、兩個逃生門、`.suggest-mode=off`
- [x] **每個新案例都要做負向測試**（把修法還原確認會紅）—— 本 repo 的硬要求
- **預估**：1h
- **驗收**：全綠且負向測試做過；`check-counts.sh --tests <新數字>` 一致
      （**測試數會變，記得同步文件裡的計數**，CLAUDE.md 的連帶檢查列了哪些檔案）

### 階段 5: `writing-extensions` 補收錄判準 + rule 計數同步 ✅

- [x] 「常駐 vs 按需」那節補上判準：常駐 rule 除了「適用範圍廣」，還要問
      **「模型本來就會做了嗎」**——寫模型預設就會做的事是純粹的注意力稀釋。
      註明這條判準取自 Godzilla-z 的 `git-workflow.md`
- [x] `rules/` 從 5 條變 6 條 → `check-counts.sh` 會抓到計數漂移，把文件裡的數字同步
- **預估**：30min
- **驗收**：`check-counts.sh` 全綠

## 風險與緩解

| 風險 | 影響 | 緩解 |
|---|---|---|
| 「先開分支」寫成硬閘門 → 每次小改都被擋，使用者關掉整個 suggest-mode | HIGH | **這條只寫成 rule，不做閘門**。只有 backup tag 那條做閘門 |
| backup tag 閘門誤擋 `rebase --continue` 之類 | MEDIUM | 照 merge-gate 的既有樣式排除，並寫測試 |
| `pre-tool-use.sh` 再變複雜 | MEDIUM | 新邏輯全部在 lib，本體只加 source + 呼叫兩行 |
| rule 太長稀釋注意力 | MEDIUM | 階段 1 的驗收硬性限制 ≤ 80 行 |

## 驗收標準（整體）

- [x] 五階段全 ✅
- [x] `run-tests.sh` 全綠且新案例做過負向測試
- [x] `check-counts.sh` 全綠（含 rules 5→6 的計數同步）
- [x] `rules/git-workflow.md` ≤ 80 行，且不重述 PR 或 commit 細則
- [x] 不動 `files:` 以外的任何檔案

## 歸檔紀錄（2026-09-11 補登）

實作在 2026-09-09 完成並 commit（`e7fd4c2`），歸檔被下班中斷，隔日恢復 session 時補做。
驗收證據：`run-tests.sh` 232/232 全綠（新增 22 案例，含 heredoc 誤擋回歸與兩個逃生門）、
`check-counts.sh` 313 項一致、`git-workflow.md` 78 行、`commands/pr.md` 未被誤動。

**兩處與 plan 的偏差，都是刻意的：**

1. **四條鐵律變三條。** 第 4 條「commit→push→PR 一氣呵成、禁止中間問」在 agent 寫檔
   中途叫停 —— 它與 `commands/pr.md` 步驟 2/3（刻意問兩次）和 `interactive-qa.md:5`
   （所有決策點都要問）**三方直接矛盾**。新檔裡改為明文寫下「刻意不收」與理由，
   而非靜默省略。決策記錄見 `context/decisions/2026-09-09-adopt-git-workflow-from-godzilla-z.md`
   的「⚠️ 修正（同日）」節

2. **`files:` 少報了 5 個檔。** 驗收標準寫「不動 `files:` 以外的任何檔案」，實際還動了
   `.claude/README.md`、`README.md`、`.claude/guides/WORKFLOW.md`、
   `.claude/hooks/tests/README.md`、`.claude/skills/writing-extensions/SKILL.md`。
   這五個是階段 5 自己要求的計數同步，**所以不是超出範圍，是 `files:` 一開始就漏報**。
   值得記住的是後果：`files:` 是平行開發判「能不能同時跑」的唯一依據，漏報它
   等於把衝突風險藏起來。**寫 plan 時，凡是 CLAUDE.md「連帶檢查」會拉進來的檔案，
   都必須列進 `files:`。**

## 邊界（本任務不做）

- **不做** PR 大小門檻（< 400 行／< 10 檔）與 commit 歷史稽核表 ——
  使用者這輪選的範圍不含它們，見 ADR 的「這輪不做，但值得記著」
- **不做** tangled history 恢復策略
- **不新開 skill** —— 細則推給既有的唯一來源
- 不碰 `pre-agent-gate.sh` 的 `.suggest-mode` 讀錯 root（另一個既有落差，
  已記在 CLAUDE.md，要修另開任務）
