---
date: 2026-11-05
title: jq 1.6 不接受保留字當變數名，開發機與 CI 的新版 jq 抓不到
files:
  - ".claude/hooks/*.sh"
  - ".claude/hooks/lib/*.sh"
  - ".claude/scripts/*.sh"
symptom: '既有專案（Linux 伺服器、jq 1.6）跑完 update-template 後專案圖解從沒產生過，.last-error 是 jq 編譯錯誤；同一支 overview.sh 在開發機（jq 1.8.1）與 CI 全部測試通過'
root-cause: overview.sh 的 jq 程式寫了 `... as $as`。jq 1.7 起才允許保留字（as、if、end、and、or、not、reduce、def…）當變數名，jq 1.6 直接編譯失敗。Ubuntu 22.04 以前、許多伺服器仍是 jq 1.6；開發機與 CI（ubuntu-latest）都是 1.7+，所以實際執行的測試永遠過。
guard: jq 變數名不要用保留字。`run-tests.sh`「全體 hooks — 語法與健壯性」有一條靜態掃描（`as $<保留字>`），涵蓋 hooks、lib、`.claude/scripts/`。jq 1.7 之後才有的內建函式（trim、ltrim、rtrim、abs、toarray、pick、have_decnum…）同理：要用就自己 def 一份（overview.sh 的 trim 就是自己定義的）。
severity: high
---

2026-11-05 使用者在遠端專案（for-query，jq 1.6）實際同步模板後發現：專案圖解畫不出來，追到 `overview.sh:570`。
993 個 hook 測試全部通過也沒抓到——測試跑在哪個 jq 版本，就只證明那個版本。
