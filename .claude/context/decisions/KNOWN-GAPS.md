# 已知落差（尚未修）

從 `CLAUDE.md` 搬出來的現況說明。修好的搬到同目錄的 `FIXED-LOG.md`。

**為什麼不放 CLAUDE.md**：這些只在動到相關機制時才需要，常駐會讓每個 session 多付約 3 KB。
CLAUDE.md 只留指標和一條當下就要照做的（衝突檔含 hook 時自己看 `git status`）。

**什麼時候讀**：改 hook、改發佈流程（`copy-template`／`update-template`）、跑壓力測試、
或懷疑某個行為是已知問題時。用 grep 找關鍵字比通讀快。

---

- **發佈仍是 pull 式**：`copy-template` / `update-template` 要手動跑。真正的自動更新要走 Claude Code plugin marketplace（改版號即更新），但 plugin **帶不了 `rules/`**，且指令會變 `/taskmaster:task-next`。`using-taskmaster` 已示範「rules 改寫成 SessionStart 注入的 skill」這條遷移路徑
- **沒有 constitution**：`rules/` 是模板通用規範，缺「這個專案不可違反的原則」那一層
- **workshop 第 5 章教的機制已不存在**：`workshop/docs/slides/ch5_advanced.md`（4 處）與 `01_workshop_prd.md`（2 處）還在教「從 `custom-rule&skill/` 複製 94 個技能包」，但備份池已於 v5.6 移除。新說法是「委派 `skill-curator`」（它查官方文檔、寫觸發式 description、接線、驗證）。**開課前務必修**。未動的原因：`.md` 與手改的 `.pptx` 關係未確認
- **壓力測試已實跑一輪，但測不到正向題**（2026-09-09，結果與判讀在 `.claude/tests/skill-compliance/results/20260909-130333/_判讀.md`，該目錄不進版控）。三件事：
  - 8 份有 5 份的目標物（`src/`、API、schema）**在模板 repo 不存在**，受測 session 只能正確地回「給我專案路徑」→ 正向題永遠半殘。**這批必須在有應用程式碼的專案裡跑**
  - **受測者讀得到考卷**：prompt 04／05 都主動指出題目一字不差存在 `prompts/*.txt`。這次它選擇不看評分標準，但下次照答案演我們分不出來
  - `-p` 非互動模式拿不到權限提示 → 受測 session 寫不了 `.claude/**`、跑不了 Bash 腳本
  - 已驗出的結論：反向題 2/2 PASS（注入沒硬到壓過使用者指示）、任務分級與升級有效；**文件路由（01／02）兩次都沒走**，證實了 Red Flags 表「最常被漏掉的一棒」那句判斷
- **衝突檔本身是 live hook 時，「委派 `conflict-resolver`」的注入靜默失效**（2026-09-11 實測）。衝突標記讓 hook 語法壞掉 → PostToolUse 只噴語法錯誤，該出現的提示沒出現。這推翻了「hook 一定會提醒你委派」這個隱含假設，而本模板最常做的事就是改 hook。沒有簡單解；務實做法是**衝突檔含 `.claude/hooks/**` 時不要等提示，自己看 `git status`**（CLAUDE.md 有留這一條）
- **hook 已知但暫不修的四個問題**（2026-11-05 確認仍在程式裡，使用者決定先不處理）：
  - `lib/resolve-roots.sh` 在 `claude -w` 開的 session 裡把 worktree 當成主 checkout：`CLAUDE_PROJECT_DIR` 本身就指向 worktree，只比對它就判成 `IN_WORKTREE=0`，短命旗標與共享產物會落在同一邊
  - hook 在 Windows 慢：每個 `bash`／`jq` 子行程約 170ms，整套測試約 50 分鐘
  - `lib/full-suite-gate.sh` 把 `bash -n …/run-tests.sh`（只檢查語法）當成跑整套，在 worktree 裡會擋一次
  - `post-bash.sh` 不檢查合併是不是發生在本 repo：在 repo 外（`git -C` 別處、`cd` 到別的 repo）跑 `git merge` 也會記進 `.merge-pending`，擋下下一次合併
