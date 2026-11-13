# debug-investigator — 分支切換閘門測試 14 個失敗（2026-11-12）

> 由主模型依 agent 回報補寫（agent 在 worktree 執行，未落報告檔）。

## 結論
閘門 `.claude/hooks/lib/branch-switch-gate.sh` 沒壞。失敗只在**單獨跑**「分支切換閘門 — 站在 topic 分支上不得直接開新分支」那一節時出現。

## 根因
沙箱的 `git init` 寫在「git backup 閘門」那一節的頂層（`.claude/hooks/tests/run-tests.sh:2186`）。「分支切換閘門」一節（`run-tests.sh:2402` 起）沿用前一節的沙箱。選節模式對沒選中的節只取函式與變數、不執行頂層指令，所以 `$SANDBOX` 不是 git repo，閘門依設計走「不在 git repo 裡放行」，14 個期望 deny 的案例拿到 allow。

## 驗證
- 修前單跑：38 過 14 敗；與 git backup 閘門一起跑：88 過 0 敗
- 修後單跑：52 過 0 敗；`run-tests.sh --changed main`：82 過 0 敗；check-counts 720 項一致
- 排除：git 版本（2.43.5）、預設分支名、resolve-roots 的 worktree 誤判

## 修正
- `run-tests.sh`：該節開頭補自建沙箱 repo＋一個空 commit（整套跑時 `.git` 已存在，不做事）
- 新增 `context/learned/2026-11-12-single-section-run-skips-sandbox-git-init.md`
- 分支 `fix/branch-switch-gate-tests`，commit `de02b2b`

## 未處理
「merge --no-ff 閘門」一節（`run-tests.sh:2303`）同類問題，單跑 51 過 1 敗，未修。

STATUS: DONE
