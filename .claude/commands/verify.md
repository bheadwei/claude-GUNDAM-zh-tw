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
- 執行所有測試
- 報告通過/失敗數量
- 報告覆蓋率百分比

### 5. Console.log 稽核
- 搜尋原始碼中的 console.log
- 報告位置

### 6. Git 狀態
- 顯示未提交的變更
- 顯示自上次 commit 以來修改的檔案

## 輸出

產出簡潔的驗證報告：

```
VERIFICATION: [PASS/FAIL]

Build:    [OK/FAIL]
Types:    [OK/X errors]
Lint:     [OK/X issues]
Tests:    [X/Y passed, Z% coverage]
Secrets:  [OK/X found]
Logs:     [OK/X console.logs]

Ready for PR: [YES/NO]
```

如有任何關鍵問題，列出並附修復建議。

## Plan 驗收標準比對

若當前 `.current-task` 對應的 plan 存在（`.claude/taskmaster-data/plans/<id>-*.md`），在步驟 1-6 驗證後：

1. 讀取 plan 檔的「驗收標準（整體）」checklist
2. 逐項比對前面驗證結果：
   - 「測試覆蓋率達門檻」→ 由步驟 4 結果填入，門檻依任務模式（見 `testing-standards` skill）
   - 「所有階段狀態為 ✅」→ 讀 plan frontmatter `status`
   - 「`/code-review` 無 CRITICAL/HIGH 問題」→ 若未執行，提示使用者執行
   - 其他自訂條件 → 呈現給使用者確認
3. **Plan 檔內的 checklist 同步勾選**（已通過的標 `[x]`）
4. 若全部 checklist 通過 → 視為整體驗收 PASS

**相關規範：** `plan-format` skill

## 任務完成銜接

若 `.claude/taskmaster-data/.current-task` 存在（表示有進行中的任務），且驗證結果為 PASS：

### 0a. 合併驗證關卡（**若有待驗證的合併，先做這個**）

讀 `.claude/taskmaster-data/.merge-pending`。這份清單由 `post-bash.sh` 在偵測到
`git merge`／`cherry-pick`／`rebase` **成功**時累積。清單非空表示：**有合併結果還沒被驗過**。

清單非空時，除了上面的步驟 1-6，**額外做這三件事**：

1. **比對每一個已合併任務的 plan 驗收標準** —— 不只當前 `.current-task`。
   平行開發合了 N 個分支就有 N 份 plan，每一份的「驗收標準（整體）」都要過。
   對應的 plan 從 WBS 找：狀態不是 ✅ 但分支已合進來的那些。

2. **載入 `spec-convergence` skill 跑一次收斂檢查** —— 這是「合併後仍符合原本目標」
   的唯一實際檢查。它比對 `docs/00_brief.md`／PRD 與 `wbs.md`，查三件事：
   漏做、範圍蔓延、描述失真。**平行開發最容易踩的是第二項**：三個 agent 各自
   多做了一點「順手的改善」，單獨看都合理，合起來就偏離了當初講好的範圍。

3. **全部通過才刪除 `.merge-pending`**。刪掉之後 `pre-tool-use.sh` 的合併閘門才會
   放行下一次合併。

**任一項未過 → 不得刪除清單、不得標 WBS ✅。** 在主 checkout 修好再重驗；
修不動就 `git merge --abort` 退回那個合併。

> **為什麼要獨立一道關卡**：每個 worktree 自己 `/verify` 過了，但它們**看不到彼此** ——
> 合併才第一次讓兩邊的程式碼真的碰面，那些互動是全新的、沒有任何人驗過的程式碼。
> 而「一次一個 merge、每次都驗」原本只寫在 `worktree-orchestration` skill 裡，
> 是自律；`.merge-pending` 讓它變成機器保證。
>
> 逃生門：`MERGE_GATE=off`（連偵測與閘門一起關）。

### 0b. 文件同步關卡（**未處理不得標 ✅**）

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
      寫進 plan 的「未同步文件」欄，下次碰到同一批檔案還會再問
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

### 標記與歸檔

1. 將 WBS 該任務狀態更新為 `✅ 完成`
2. 清除 `.current-task`
3. **Plan 歸檔**（若存在對應 plan 檔）：
   - 將 plan frontmatter 標 `status: "✅ 完成"`、`archived: "YYYY-MM-DD"`
   - 移動至 `.claude/taskmaster-data/plans/archive/`（目錄不存在則建立）
   - **同名的執行帳本 `<plan 同名>.progress.md` 一起搬到 `archive/`**（若存在）——
     留在 `plans/` 會讓下次同 ID 的任務誤認為「有續跑中的帳本」
   - 更新 `plans/INDEX.md`：該行的狀態改為 `✅ 完成（已歸檔）`，路徑改為 `archive/<filename>`
   - **更新 WBS 該任務的 `Plan` 欄**改指 `plans/archive/<filename>`
     （漏掉這步，歸檔後從 WBS 點過去會是死連結）
4. 用 `AskUserQuestion` 詢問下一步（遵守 `.claude/rules/interactive-qa.md`）：
   - 「繼續下一個任務」(Recommended) — 自動執行 `/task-next` 流程
   - 「查看目前進度」 — 顯示 WBS 狀態摘要
   - 「結束，稍後再繼續」 — 停止

## 里程碑完成時：規格收斂 ＋ 提議歸檔

### 先跑規格收斂（**里程碑是唯一該做完整收斂的時機**）

標記任務為 ✅ 且**該任務所屬里程碑全部完成**時，先載入 `spec-convergence` skill
跑完整檢查（A 漏做 ／ B 範圍蔓延 ／ C 描述失真），再提議歸檔。

順序不能反：歸檔會把已完成任務移到 `wbs-archive.md`，收斂檢查需要同時讀兩個檔，
先歸檔不會壞掉但報告會少掉「這個里程碑做了什麼」的脈絡。

> **為什麼是里程碑而不是每個任務**：單一任務很少讓整份規格跑掉，每次都跑只會
> 變成被忽略的噪音。里程碑是「一批工作完成」的自然邊界，也是客戶會來驗收的時點。

## 里程碑完成時：提議歸檔

標記任務為 ✅ 後，檢查**該任務所屬的里程碑是否全部完成**
（所有任務皆為 ✅ 完成 或 ⏭️ 跳過）。若是，用 `AskUserQuestion` 問：

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

- **補登為已完成**（Recommended）— 追加一行到 `wbs.md`，狀態直接標 `✅ 完成`，
  備註填 `[計畫](plans/archive/<filename>)`
- **不用，這是一次性的** — 不動 WBS
- **補登並順便加後續任務** — 補登後接 `/task-add` 流程

> 不補登會讓 WBS 逐漸偏離實際做過的事，`/task-status` 與 `/time-log` 的統計也會失真。

這樣使用者不用手動再跑 `/task-next`，形成 **自動任務接力**，且計畫自動歸檔不佔主目錄。

## 參數

$ARGUMENTS 可以是：
- `quick` - 僅建置 + 型別
- `full` - 所有檢查（預設）
- `pre-commit` - 與 commit 相關的檢查
- `pre-pr` - 完整檢查加安全掃描，**再跑規格收斂的 A+B**（載入 `spec-convergence` skill；跳過檢查 C，太慢）

## 自動 Profile 選擇（依任務模式）

若使用者**未指定** `$ARGUMENTS`，讀取 `.claude/taskmaster-data/.current-task-mode`：

| 任務模式 | 自動 profile |
|---|---|
| `quick` | `quick` |
| `standard`（或檔案不存在） | `full` |
| `critical` | `pre-pr` |

使用者明確帶入 `$ARGUMENTS` 時優先採用使用者選擇。

**相關規範：** `.claude/rules/task-mode.md`

## 任務完成後清除狀態檔

第「任務完成銜接」階段標記 WBS 為 ✅ 後，**同步清除**這些檔案，避免下個任務沿用舊狀態：

| 檔案 | 不清的後果 |
|---|---|
| `.current-task` | 下個任務被誤認為同一個 |
| `.current-task-mode` | 沿用舊的任務模式（TTL 8h 是機器保底，但不該靠它） |
| `.doc-impact` ・ `.doc-impact-notified` | 下個任務一開始就被上個任務的文件債擋住 |
| `.pitfall-seen` | 不需清 —— 它由 `session-start.sh` 每個 session 重置 |
| `.report-expectations.jsonl` | 不需清 —— 由稽核器自己按 deadline 汰除 |
