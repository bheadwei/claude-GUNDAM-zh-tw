---
date: 2026-10-15
title: PostToolUse 只在工具成功時觸發——「事後記錄型」hook 收不到失敗的那一次，而且完全無聲
files:
  - ".claude/hooks/post-bash.sh"
  - ".claude/settings.json"
symptom: 有衝突的 git merge 解完之後，下一次合併直接放行、沒被合併閘門擋下；`git merge … && 某個會失敗的指令` 那次合併沒進 .merge-pending，hooks.log 裡連一筆 post-bash 紀錄都沒有。踩坑偵測（連續失敗後成功）從 2026-09-08 裝上後一次都沒觸發過
root-cause: settings.json 只把 post-bash.sh 接在 PostToolUse。官方定義 PostToolUse 是「After a tool call succeeds」，指令非零結束屬於失敗，走的是 PostToolUseFailure。所以失敗的那一次 hook 根本不會被呼叫——post-bash.sh 裡判斷 tool_response.is_error／exit_code 的程式碼永遠執行不到，失敗計數永遠是 0
guard: 寫「事後記錄型」hook 時先問「失敗的那一次要不要記？」要的話 PostToolUse 與 PostToolUseFailure 兩個都接，用 hook_event_name 分辨。兩者 payload 形狀不同：失敗事件**沒有** tool_response，錯誤在頂層 `error`（首行 `Exit code N`）與 `is_interrupt`；回應的 hookEventName 也要等於觸發的事件。測試要用 Claude Code 真的會送出的 payload 形狀，不要自己發明欄位
severity: high
---

> ⚠️ 與 `2026-09-11-async-dispatch-breaks-posttooluse-gates.md` **同一類坑**：
> 都是把 `PostToolUse` 讀成「那件事發生之後」。那次是「工具返回了 ≠ 事情做完了」
> （非同步），這次是「事情發生了 ≠ PostToolUse 會來」（失敗）。
> 兩次都完全無聲，兩次都是單元測試全綠。

## 怎麼發現的

2026-10-15 17:14，主模型跑了一條

```
git switch -q main && git merge --no-ff -m "..." feat/x >/dev/null && echo ... && cat 不存在的檔
```

合併本身成功了，但結尾的 `cat` 讓整條結束碼是 1。`.merge-pending` 沒有紀錄，
`hooks.log` 也完全沒有 post-bash 的任何一行。前一次同樣寫法、結尾是成功指令的那次就有記到。

對照官方文件（https://code.claude.com/docs/en/hooks）：

| Event | When it fires |
|---|---|
| PostToolUse | After a tool call succeeds |
| PostToolUseFailure | After a tool call fails |

順著查下去才發現 `post-bash.sh` 的**兩個功能都**建立在「失敗也會呼叫我」這個假設上：

1. **合併待驗證**：註解寫著「成功與衝突都要記」，用 `tool_response.is_error`／`exit_code`
   判斷衝突——但衝突的 merge 退出碼非零，那段程式永遠執行不到。衝突解完後清單是空的，
   下一次合併跳過驗證。**衝突的結果正是最需要驗證的那一種。**
2. **踩坑偵測**（本檔最早的功能）：數「連續失敗幾次後成功」。失敗事件從沒來過 →
   計數永遠 0 → `hooks.log` 從 2026-09-08 到修好之前沒有任何一筆 `learn-candidate`。

**單元測試一個都沒抓到。** 測試直接把 `{"tool_response":{"is_error":true}}` 餵給腳本，
那是 Claude Code **從來不會送出**的形狀（Bash 的 PostToolUse 的 tool_response 是
`{stdout, stderr, interrupted, isImage}`）。測試驗到的是「腳本收到這種 payload 會怎麼做」，
繞過了「Claude Code 什麼時候會呼叫 hook、送什麼」這一層——bug 在後者。

## 官方文件：PostToolUseFailure 的 input（原文）

> PostToolUseFailure hooks receive the same `tool_name` and `tool_input` fields as
> PostToolUse, along with error information as top-level fields.

```json
{
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_input": { "command": "npm test", "description": "Run test suite" },
  "tool_use_id": "toolu_01ABC123...",
  "error": "Exit code 1\nError: Cannot find module 'express'",
  "is_interrupt": false,
  "duration_ms": 4187
}
```

> Key your hook on `tool_name`, `is_interrupt`, and the `Exit code N` first line;
> treat the rest of the string as display text, not a stable format.
> For Bash and PowerShell, a command that ran and exited produces a first line
> `Exit code N`, then any output the command produced as one block with stdout
> and stderr interleaved

也不會在這些情況觸發：工具名不存在、輸入驗證失敗、權限被拒（被 PreToolUse deny 的不算）。

## 修法

- `settings.json` 加 `PostToolUseFailure`（matcher `Bash`）→ 同一支 `post-bash.sh`
- `post-bash.sh` 讀 `hook_event_name` 決定 `FAILED`，回應的 `hookEventName` 跟著事件走
- 合併：成功、衝突、非零但原因不明**一律記**。「非零」不等於「衝突」——
  衝突判定改看證據：`git ls-files -u` 有未合併路徑（不受 `>/dev/null` 影響，
  成功事件也查，涵蓋 `git merge x; true`），後備才看輸出裡的衝突字樣
- `--abort` **失敗時不清單**：它失敗最常見的原因是「沒有進行中的合併」，
  也就是清單裡那筆是一個早已完成、真的待驗證的合併
- 踩坑偵測不用改邏輯——它本來就寫對了，只是事件沒接上。**修好之後它會開始觸發**

## 為什麼這條會重犯

`PostToolUse` 這個名字讀起來是「工具用完之後」，沒有「成功」兩個字。
而失敗路徑的 bug 不會報錯——它給你一份**沒有失敗紀錄的帳**，看起來就像一切順利。

寫「記錄 + 依記錄判斷」或「計數」型 hook 時先問三題：

1. 我拿來當觸發的事件，**真的代表那件事發生了嗎？**（async-dispatch 那個坑）
2. **失敗的那一次會不會呼叫我？我需不需要它？**（本坑）
3. 測試的 payload 是 Claude Code **真的會送的形狀**嗎？還是我自己發明的欄位？

## 相關

- `.claude/context/learned/2026-09-11-async-dispatch-breaks-posttooluse-gates.md` — 同類坑（非同步）
- `.claude/context/learned/2026-09-11-gate-blocks-its-own-fix.md` — 同一支 hook 的另一個坑（子字串誤判）
- `.claude/hooks/README.md` 的「撰寫新 Hook 的慣例」第 7、8 條
- `.claude/hooks/tests/run-tests.sh` 的「post-bash.sh — 失敗事件（PostToolUseFailure）」節 ——
  payload 照官方形狀，並用一個真的處於衝突狀態的 git repo 驗 `ls-files -u` 判定
