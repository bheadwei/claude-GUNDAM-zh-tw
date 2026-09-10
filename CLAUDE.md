# CLAUDE.md — 模板本身的開發須知

> **這個 repo 是模板本身，不是用模板開發的專案。**
> 在這裡「開發」＝改 `.claude/` 底下的規則、指令、agent 定義、hook——幾乎都是 `.md` 和 `.sh`。
>
> 本檔已列入 `scripts/copy-template.*` 的排除清單，**不會被複製到新專案**。
> 新專案的 CLAUDE.md 由 `/task-init` 依 `.claude/templates/CLAUDE-md.template.md` 產生。

## 目錄地雷

| 路徑 | 注意 |
|---|---|
| `workshop/VibeCoding_Workshop.pptx` | **由使用者手動編輯。** 不要跑 `generate_pptx.py` 重生，會洗掉手改內容 |
| `.claude/context/`、`.claude/coordination/` | 執行時產物，已排除複製。修改 agent 的報告/交接格式時記得對應更新 `_REPORT_TEMPLATE.md` 與 `_HANDOFF_TEMPLATE.md` |

## 改動時的連帶檢查

- **要加或改 `.claude/` 底下任何東西** → **先讀 `writing-extensions` skill**（五層決策表）。這個模板踩過四次「選錯層」，都是把該用 hook 的事寫成文字規則
- **改了注入內容**（`using-taskmaster`、關鍵字路由、rules）→ 跑一輪 `.claude/tests/skill-compliance/run-compliance.sh`。209 個 hook 測試證明不了「模型會不會照做」
- **新增 agent／skill／command／rule** → 跑 `bash scripts/check-counts.sh`，它會列出所有該同步卻沒同步的計數（CI 也會跑）
- **改 `.claude/` 的目錄結構** → 同步 `scripts/copy-template.sh` 的 `EXCLUDES` **和** `scripts/copy-template.ps1` 的 `$excludeDirs` / `$excludeFiles`（兩份要一致，容易漏改 ps1）
- **新增 skill** → 更新 `.claude/skills/INDEX.md`，否則沒人知道它存在
- **改 hook** → `.claude/hooks/tests/run-tests.sh` 有測試
- **改 agent 的報告落點或 handoff 行為** → `post-agent-report.sh` 的 `AREA` 對應表要同步，**否則稽核永遠找不到報告**
- **新增 `context/` 的 area 子目錄** → 同步 `copy-template.sh` 的 `for d in ...` **和** `copy-template.ps1` 的 `$contextAreas`（四份腳本的骨架規則要一致：`copy-template.{sh,ps1}` 建目錄、`update-template.{sh,ps1}` 只補 `README.md`／`_*.md`／`.gitkeep`）
- **改 hook 讀寫的狀態檔** → 先想清楚它屬「短命旗標」還是「共享產物」，照 `worktree-orchestration` skill 的邊界表選 `WORK_CLAUDE` 或 `MAIN_CLAUDE`。用錯的話平行開發會靜默壞掉
- **改閘門的路徑排除規則** → 一律先相對化到 `WORK_ROOT` 再比對，樣式錨定開頭。用絕對路徑子字串比對會被 `.claude/worktrees/` 誤命中
- **改 `using-taskmaster` skill** → 它由 `session-start.sh` 全文注入，**每個 session 都會載入**；加東西前先想清楚值不值得佔常駐 context

## 已知落差

- **發佈仍是 pull 式**：`copy-template` / `update-template` 要手動跑。真正的自動更新要走 Claude Code plugin marketplace（改版號即更新），但 plugin **帶不了 `rules/`**，且指令會變 `/taskmaster:task-next`。`using-taskmaster` 已示範「rules 改寫成 SessionStart 注入的 skill」這條遷移路徑
- **沒有 constitution**：`rules/` 是模板通用規範，缺「這個專案不可違反的原則」那一層
- **workshop 第 5 章教的機制已不存在**：`workshop/docs/slides/ch5_advanced.md`（4 處）與 `01_workshop_prd.md`（2 處）還在教「從 `custom-rule&skill/` 複製 94 個技能包」，但備份池已於 v5.6 移除。新說法是「委派 `skill-curator`」（它查官方文檔、寫觸發式 description、接線、驗證）。**開課前務必修**。未動的原因：`.md` 與手改的 `.pptx` 關係未確認
- **壓力測試已實跑一輪，但測不到正向題**（2026-09-09，結果與判讀在 `.claude/tests/skill-compliance/results/20260909-130333/_判讀.md`，該目錄不進版控）。三件事：
  - 8 份有 5 份的目標物（`src/`、API、schema）**在模板 repo 不存在**，受測 session 只能正確地回「給我專案路徑」→ 正向題永遠半殘。**這批必須在有應用程式碼的專案裡跑**
  - **受測者讀得到考卷**：prompt 04／05 都主動指出題目一字不差存在 `prompts/*.txt`。這次它選擇不看評分標準，但下次照答案演我們分不出來
  - `-p` 非互動模式拿不到權限提示 → 受測 session 寫不了 `.claude/**`、跑不了 Bash 腳本
  - 已驗出的結論：反向題 2/2 PASS（注入沒硬到壓過使用者指示）、任務分級與升級有效；**文件路由（01／02）兩次都沒走**，證實了 Red Flags 表「最常被漏掉的一棒」那句判斷
- **`pre-agent-gate.sh` 的 `.suggest-mode` 讀錯 root**：它讀 `WORK_CLAUDE`，但 `post-agent-report.sh` 與 `worktree-orchestration` 的隔離表都把它列為 `MAIN_CLAUDE` 的專案級設定。後果是主 checkout 設 `/suggest-mode off` 關不掉 worktree 裡的平行 agent 閘門。無測試覆蓋
- **閘門用子字串比對指令名，寫到那個指令的文件會被當成真的執行過**（2026-09-11 實測，一天被誤擋四次，**包括擋下修好它自己的那次編輯**）。`post-bash.sh` 的 `case "$CMD" in *"<指令名>"*)` 只要內文命中就記一筆待驗證。`git-backup-gate.sh` **已經修過同一類問題**（測試案例「只是提到指令（heredoc 內文）不擋」），但合併偵測沒跟著補。`.claude/` 底下所有用同樣寫法判斷的地方都該一起檢查。細節見 `context/learned/2026-09-11-gate-blocks-its-own-fix.md`
- **衝突檔本身是 live hook 時，「委派 `conflict-resolver`」的注入靜默失效**（2026-09-11 實測）。衝突標記讓 hook 語法壞掉 → PostToolUse 只噴語法錯誤，該出現的提示沒出現。這推翻了「hook 一定會提醒你委派」這個隱含假設，而本模板最常做的事就是改 hook。沒有簡單解；務實做法是**衝突檔含 `.claude/hooks/**` 時不要等提示，自己看 `git status`**

### 已修的落差

搬到 `.claude/context/decisions/FIXED-LOG.md`（歷史紀錄不需常駐，且會無限成長）。
懷疑某個落差是否還存在、或要動相關機制之前去 grep 它。
