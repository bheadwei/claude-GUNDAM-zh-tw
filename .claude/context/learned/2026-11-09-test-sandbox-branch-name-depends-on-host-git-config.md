---
date: 2026-11-09
title: 測試沙箱的分支名跟著跑測試那台機器的 git 設定走，平台條件案例讓案例數兩平台不同
files:
  - ".claude/hooks/tests/run-tests.sh"
  - ".claude/hooks/lib/branch-switch-gate.sh"
  - ".github/workflows/template-ci.yml"
symptom: "CI Windows job 的分支切換閘門 4 案例紅（期望 allow 實得 deny、訊息說預設分支是 master），本機與 Ubuntu 全綠；counts job 每次『文件寫 N，實際 N+1』。main 從 2026-10-22 起連續 7 次 CI failure"
root-cause: "測試沙箱第一次 git init（run-tests.sh:1415、:1931）沒帶 -c init.defaultBranch=main，初始分支名隨機器設定變；cd714e8 在 :2241 加的 checkout main 跑在 :2404 固定分支名之前，失敗被 gitq 吞掉，留下 master，Windows runner 的 init.defaultBranch=master 讓 branch-switch-gate 判預設分支為 master。另外 :3207（只在有 cygpath 時跑）與 :3294（只在建得出 symlink 時跑）讓案例數隨平台不同；文件照本機 Windows 寫，CI 的 counts job 拿 Ubuntu 的數字比"
guard: "沙箱裡每個 git init 都帶 -c init.defaultBranch=main；新增寫死分支名的 git 指令前確認分支名已固定；平台條件案例的 else 分支補同樣數量的 ok「（…略過）」讓兩平台案例數一致（前例 run-tests.sh:4643）。本機 Git for Windows 的系統設定是 main，所以本機永遠重現不了，要用 GIT_CONFIG_GLOBAL 指向 defaultBranch=master 的檔驗"
severity: high
---

## 證據

調查報告：`.claude/context/quality/debug-investigator-2026-11-09-1025.md`（CI run 41998714259 的失敗原文、10-20 到 11-05 每次 run 的對照表、排除的假設）。

## 可升級成機器保證

在「全體 hooks — 語法與健壯性」節加一條 grep：`run-tests.sh` 裡不准出現沒帶 `init.defaultBranch` 的 `git init`。
