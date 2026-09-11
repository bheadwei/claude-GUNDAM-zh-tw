# 已修落差紀錄

從 `CLAUDE.md` 搬出來的歷史紀錄。

**為什麼不放 CLAUDE.md**：那份是常駐的（每個 session 全量載入），而這是**歷史**——
價值在「別重複調查已經修好的東西」，不在「每次對話都提醒」。而且它只會無限成長：
本檔搬出時 CLAUDE.md 已從 27 行漲到 64 行，其中 29 行是這份清單。

**什麼時候讀**：懷疑某個落差是否還存在時、或要動到相關機制之前。
用 grep 找關鍵字比通讀快。

---

### 已修（2026-09-11）

- ~~把 hook 改壞的當下沒有任何人告訴你~~ → `post-write.sh` 在寫入／編輯
  `.claude/hooks/**/*.sh` 之後跑 `bash -n`，不過就把錯誤訊息印出來。
  實測確認過三件事：壞檔 `bash -n` 抓得到、餵 `post-write.sh` 對應 payload
  **一個字都沒輸出**、整個 `hooks/` 底下 `bash -n` 零命中。
  **刻意只出聲不擋**（PostToolUse；壞掉的 hook 本來就得再被編輯才能修好，
  擋住等於重演「閘門擋下修好它自己的那次編輯」），不自動修／還原／備份，
  不擴大到 `.sh` 以外或 `hooks/` 以外，只有一個逃生門 `HOOK_SYNTAX_CHECK=off`。
  位置在 `.suggest-mode` 與擴充提醒**之前**：檔案是真的壞的、不是建議密度問題，
  而且擴充提醒命中 `.claude/hooks/*` 後會 `exit`，放後面永遠輪不到。
  **`post-write.sh` 自己被改壞時這段不會跑——無解，刻意不做自舉保護。**
  新增 2 條回歸（壞的要報、好的不出聲），241 → 243 全綠
- ~~閘門用子字串比對指令名，寫到那個指令的文件會被當成真的執行過~~ →
  `post-bash.sh` 的合併偵測改用新的 `hooks/lib/cmd-segments.sh` 切段：沿 `&& || ; |`
  切開、剝掉前導 `( {`、只留 `^git[[:space:]]` 的段，再用前後空白錨定的 ERE 確認子指令
  **本身**是 `merge`／`cherry-pick`／`rebase`。`git merge-base --is-ancestor`（純唯讀
  祖先查詢，2026-09-11 實際復現的那一條）與 heredoc／echo／grep 內文都不再命中。
  累計誤擋五次，其中一次擋下了「修好它自己」的那次編輯。
  **切段邏輯是從 `git-backup-gate.sh` 的 `_gbg_segments`／`_gbg_m` 抽出來共用的**，
  不是複製第二份——這個坑要修第二次，起因正是當初兩支 hook 各寫各的。
  `lib/merge-gate.sh` **刻意不跟進**：它只在 `.merge-pending` 非空這個罕見狀態下才進入
  比對，誤判成本低，改它是沒必要的風險（理由已寫在 `hooks/README.md`）。
  新增 8 條回歸測試（含 4 條誤判、3 條正向、1 條 `--abort` 清除），232 → 241 全綠
- ~~`conflict-resolver` 從未被驗證~~ → 刻意製造衝突實跑了一次。兩個任務改 `post-bash.sh`
  同一段、意圖不同（一邊記目標 ref、一邊記操作類型），正解是保留雙方。**它解對了**：
  組合成 `BR="[$MP_OP] $MP_REF"`，兩邊註解都留住，報告逐項寫出決定與依據哪份 plan 的哪一條。
  三件沒被要求卻自己做到的事：(a) 先去讀 `merge-gate.sh` 與 `verify.md` 確認沒有下游解析器
  在吃這個格式，才判定可機械合併而非設計決策；(b) 抓到 `iconv` 不在這台機器上、
  `|| printf` 的 fallback 會靜默退回 byte 腰斬，等於那條驗收標準從沒達成；
  (c) 糾正了「衝突＝`files:` 漏列」的預設——兩份 plan 的 `files:` 完全正確也完全重疊，
  **是當初就不該判成可平行**。一項越界：它主動往 `.merge-pending` 補寫了一筆
  （理由正當，且有明講並請人裁決，但超出「只碰衝突檔」的宣稱）
- ~~`.merge-pending` 記的是整條指令而非分支名~~ → 改成抽 `merge`／`cherry-pick`／`rebase`
  後第一個非旗標參數，並在列首標上操作類型：`[merge] feat/x`。截斷改用 bash 的
  `${var:0:100}`（算**字元**不算 byte）——原本用 `cut -c` 會把中文腰斬，
  改 `iconv -c` 也不行，**這台機器根本沒裝 iconv**，`|| printf` 會讓它靜默退回腰斬

### 已修（2026-09-07）

- ~~沒有東西寫下「該做成哪一層」~~ → `writing-extensions` skill：五層決策表（依序問「能不能在工具呼叫當下用程式判斷」→ hook；「任何任務都適用」→ rule…）、`description` 寫觸發條件的規則、以及**壓力測試法**。附 `.claude/tests/skill-compliance/` 可執行雛形（8 份真實開場 prompt + 跑批腳本 + `--baseline` 對照組），把「怎麼驗證模型真的照做」從方法論變成能跑的東西
- ~~路由表在兩層重複~~ → `rules/agent-orchestration.md` 的「標準鏈」與 `using-taskmaster` 的「路由表」曾是同一張表的兩份，**而兩者都常駐 context**（rules 自動載入、skill 強制注入）。已把鏈表從 rule 移除只留指標，rule 的 agent 名稱提及 44→20 次。判準寫進 `writing-extensions`：**同一份知識存在 2 個地方就要指定唯一來源**

- ~~沒有 converge 收斂檢查~~ → `spec-convergence` skill：以 `docs/00_brief.md`＋PRD 為基準，三查（A 漏做／B 範圍蔓延／C 描述失真），輸出報告與提議的 WBS 行。**刻意不自動改 PRD**——「這個 CR 該進 PRD」還是「當初就不該做」是人的判斷。做成 skill 而非塞進 `/verify`，是為了能用自然語言喚起（「現在還符合原本規格嗎」）。三個觸發點：里程碑完成（完整）、`/verify pre-pr`（A+B）、`/task-add` 的 CR 累積提醒
- ~~需求釐清沒有回述確認~~ → `/task-init` 新增步驟 2.7：補問 non-goals 與最大風險（原本兩題都沒問）、產出 `docs/00_brief.md`、**逐段回述給使用者確認**。原因是文件從步驟 2 的答案產出、WBS 又從文件反推，**誤解會被放大兩次**。`/docs-init` 改為優先讀 brief，並對 brief 的「仍未釐清」段標 `TBD` 而非自己填答案

- ~~沒有 CI~~ → `.github/workflows/template-ci.yml`，六個 job：hook 回歸測試（**Ubuntu + Windows/Git Bash 都跑**，因為踩過平台專屬的雷）、shell 與 PowerShell 語法、**文件計數一致性**、copy/update-template 沙箱實跑。案例數由測試 job 的實跑輸出傳給計數 job，避免兩邊各寫一個數字
- ~~文件計數靠人工同步~~ → `scripts/check-counts.sh`：比對檔案系統實況 vs README／`.claude/README`／WORKFLOW／INDEX 四處寫的數字，另檢查「每個 skill 有 SKILL.md 且列入 INDEX」「每個 agent 的 model 是合法別名」。**寫完立刻抓到 3 處既有 drift**（`.claude/README.md` 的 skills 12、commands 28、Skills 14）

- ~~worktree 平行開發的狀態分裂~~ → **這是 bug 不是缺功能**。官方文件明講「hook 路徑不跟著 worktree 走：`${CLAUDE_PROJECT_DIR}` 留在 session 啟動處，`cwd` 才是 worktree 根」，而 7 支 hook 全部只用 `CLAUDE_PROJECT_DIR` → 三個平行 worktree 共用同一份 `.current-task-mode`，A 判 quick、B 判 critical 互相覆寫。新增 `hooks/lib/resolve-roots.sh` 統一解析（往上找 `.git`，因為 `cwd` 會隨 `cd` 移動成子目錄），短命旗標跟 worktree、共享產物留主 checkout
- ~~閘門在 worktree 裡全部失效~~ → worktree 住在 `.claude/worktrees/`，所以裡面每個檔案的絕對路徑都含 `/.claude/`，而閘門用 `*/.claude/*` 放行以免自鎖 → 整個 worktree 被放行。修法：排除判斷先相對化到當前 checkout root、樣式錨定開頭。**由新增的 worktree 測試案例抓出**
- ~~沒接 Claude Code 原生 worktree 支援~~ → 新增 `.worktreeinclude`（worktree 是乾淨 checkout，沒它就缺 `.env` 跑不動）、`settings.json` 的 `worktree` 設定、`refactor-cleaner` 加 `isolation: worktree`；`task-next.md` 的平行段改用 `claude -w` 並**刪掉那句錯的「每個任務各自寫 .current-task（互不干擾）」**
- ~~update-template 會覆寫專案的根目錄檔案~~ → 新增 **SEED** 分類：只在目標不存在時建立、永不覆寫。`.worktreeinclude` 走這條（專案會自己加規則，而 update-template 的備份只包 `.claude/`，根目錄檔案覆寫等於無備份的破壞）

- ~~新需求／CR 的程式寫出來但文件沒同步~~ → **根因是結構性的**：`documentation-specialist` 在任務完成路徑上原本沒有位置，`/verify` 只驗建置/型別/lint/測試，從不問文件。修法：`post-write.sh` 偵測「文件描述的對象」（`*/api/*`、`*openapi*`、`*/migrations/*`、`*/index.ts`…）→ 記進 `taskmaster-data/.doc-impact` 並提醒一次；`/verify` 在標 WBS ✅ 前**必須**處理該清單（委派 documentation-specialist／已自行更新／明確豁免）。逃生門 `DOC_SYNC_GATE=off`
- ~~`planner` 與 `architect` 沒有關鍵字入口~~ → 「新功能／CR」那條補上 `subagent_type: "planner"`，「技術選型」那條補上 `subagent_type: "architect"`。原本只提示 `/task-add` 與 `/adr`

### 已修（2026-09-04）

- ~~新專案缺 `_REPORT_TEMPLATE.md`~~ → `copy-template.{sh,ps1}` 後置處理改為複製 `context/` 與 `coordination/` 的骨架（`README.md` + `_*.md` + 各 area 目錄），實際報告仍不帶。兩份腳本產出已比對一致
- ~~自然語言輸入不會派 agent~~ → `session-start.sh` 改用 `hookSpecificOutput.additionalContext` 全文注入 `skills/using-taskmaster/SKILL.md`（含 Red Flags 反合理化表）。**根因**：slash command 在 Claude Code 裡算 skill，滿足內建的 *"unless a skill asks for it"* 所以 `/tdd` 能派 agent；自然語言沒有這張授權
- ~~`documentation-specialist` / `workflow-template-manager` 零入口~~ → `user-prompt-submit.sh` 補文件類關鍵字，且全表語氣從「建議委派」改為帶 `subagent_type` 的命令式
- ~~踩過的坑只靠自律~~ → `pre-tool-use.sh` 新增**坑閘門**：比對 `context/learned/*.md` 的 `files:` glob，命中則 deny-once 並貼出教訓（PreToolUse 不支援 `additionalContext`，只能用 deny）。`debug-investigator` 的「結束後（必須）」已改為強制寫 learned
- ~~agent 報告稽核無牙齒~~ → 非同步啟動改為只記期望到 `taskmaster-data/.report-expectations.jsonl`，由 `hooks/lib/check-report-expectations.sh` 在後續對話邊界重查並**經 `additionalContext` 注入**要求補寫。用 `-newermt` 比對啟動時間（`-mmin` 會把 agent 上一輪的舊報告誤認成這次產出）。同步完成的 agent 仍走當下稽核
- ~~agent 仍是「顧問」不是「工人」~~ → 新增 `subagent-execution` skill：逐階段派 implementer subagent + 帳本（`plans/<plan 同名>.progress.md`，第一行身分行）+ 階段審查（規格合規與程式品質分開審）+ 修復迴圈上限 5 輪（R≥4 換新 implementer 並升級模型）+ 「裁決而非停等」。由 `/tdd` 的「3.5 選執行方式」用 `AskUserQuestion` 帶入，**是選項不是強制**
- ~~`context/planning/` 目錄不存在~~ → `planner` 與 `tdd-guide` 都往那寫、`context/README.md:28` 也記載了它，但骨架從未建立。已加入兩份 copy-template 的 area 清單
- ~~`debug-investigator` 不在報告稽核映射裡~~ → 已補進 `post-agent-report.sh` 的 `AREA` 表（它寫 `context/quality/`）
