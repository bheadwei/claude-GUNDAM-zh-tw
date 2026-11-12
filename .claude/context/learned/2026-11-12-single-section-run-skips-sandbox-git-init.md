---
date: 2026-11-12
title: run-tests.sh 單跑一節時，前面節在頂層做的 git init 不會執行，沿用沙箱 repo 的節全部變「不在 git repo 裡放行」
files:
  - ".claude/hooks/tests/run-tests.sh"
symptom: "`run-tests.sh 分支切換閘門` 單跑 14 個失敗，全是期望 deny 實得 allow（含訊息類案例實得空輸出）；跟「git backup 閘門」一起跑或跑整套則全過"
root-cause: "選節模式對沒選中的節只取函式定義與純變數指派。沙箱的 git init 寫在「git backup 閘門」節的頂層（run-tests.sh:2186），單跑「分支切換閘門」時不執行 → $SANDBOX 不是 repo → branch-switch-gate.sh 走「不在 git repo 裡放行」。閘門本身沒壞"
guard: "節的開頭若沿用前面節建好的檔案狀態（git repo、commit、remote），要自己補 setup（`[ -d \"$SANDBOX/.git\" ] || …`，git init 照樣帶 -c init.defaultBranch=main），並用單跑該節驗一次。看到「單跑紅、整套綠」先懷疑跨節的檔案狀態，不要先懷疑被測的 hook"
severity: medium
---

## 怎麼發現的

單跑該節 38 過 14 敗；加跑「git backup 閘門」節後 88 過 0 敗 → 差別只在那一節頂層的 `git init`。
閘門的「不在 git repo 裡放行」案例本身通過，對上了「沙箱不是 repo」。

排除：git 版本（2.43.5）、初始分支名（本檔 git init 都已釘 main，見 2026-11-09 那筆）、resolve-roots 的 worktree 誤判（沙箱不是 worktree）。

## 修法

「分支切換閘門」節開頭補：沙箱沒有 `.git` 時自己 init 並做一個空 commit（閘門要讀當前分支，unborn HEAD 讀不到）。

## 同類風險

「merge --no-ff 閘門」節也寫著「沿用上一區塊 git init 過的 $SANDBOX」，單跑目前 51 過 1 敗，同一類，未修。
