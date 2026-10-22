---
date: 2026-10-21
title: 閘門的失敗方向是「放行」——壞一行 log、慢幾秒、換個 shell，閘門就無聲消失
files:
  - ".claude/hooks/pre-tool-use.sh"
  - ".claude/hooks/pre-agent-gate.sh"
  - ".claude/hooks/agent-monitor.sh"
  - ".claude/hooks/post-bash.sh"
  - ".claude/hooks/lib/*.sh"
  - ".claude/settings.json"
symptom: 三種「閘門看起來裝著、其實沒在擋」同時存在。(1) agent-activity.jsonl 第 992 行被併發寫壞成 `ord"}`，之後 pre-agent-gate 與 branch-switch-gate 的 in-flight 恆為 0，5 天沒擋過任何一次；(2) Windows 上 `git checkout -b` 的 PreToolUse 跑 12～15 秒，超過 10 秒 timeout，畫面只出現 `hook error`，指令照常執行；(3) 模型改用 PowerShell 工具跑 git，matcher 只寫 `Bash`，四道 git 閘門完全不觸發。
root-cause: 每一層的錯誤處理都選了 fail-open（`jq -s ... || return 0`、官方規定 PreToolUse 超時不擋、matcher 不符就不呼叫），而且都不出聲。單看每一處都合理（hook 壞掉不該卡死使用者），疊起來就是「閘門失效時沒有任何訊號」。`jq -s` 讀整檔是一行壞全部壞；`>>` 在 MSYS 下不是原子附加，併發 SubagentStop 會互相覆寫。
guard: 動閘門時逐一問三題——(a) 它讀的狀態檔壞一行會怎樣？用 `jq -Rn '[inputs|fromjson?|objects]'` 逐行容錯，不要 `jq -s`；(b) 在 Windows 上實測延遲（沙盒餵假 JSON 跑 3 次），能跳過的昂貴檢查先跳過，timeout 留餘裕但不要設成超時即擋；(c) matcher 涵蓋所有能做同一件事的工具（`Bash|PowerShell`），hook 內的 `tool_name` 判斷同步。修好「計數恆為 0」之後，原本被遮住的誤擋會一起浮現，要同時處理。
severity: high
---

## 怎麼發現的

使用者回報「常常看到 `PreToolUse:Agent hook error`」。追下去，紅字其實有兩個來源：
閘門正常 deny（Claude Code 也顯示成 hook error），以及 hook 超時。複查時拿真實
log 跑 `agent_inflight_types` 才發現它從 10-16 起一直回空——同一輪派三個 agent
都沒被擋，本身就是證據。

## 修法位置

見 `context/decisions/FIXED-LOG.md`「已修（2026-10-20，流程鏈複查・hook 線）」。
