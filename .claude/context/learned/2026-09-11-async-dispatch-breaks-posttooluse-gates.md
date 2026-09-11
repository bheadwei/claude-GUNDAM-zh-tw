---
date: 2026-09-11
title: 非同步工具讓「靠 PostToolUse 判斷完成」的閘門全面失效——而且完全無聲
files:
  - ".claude/hooks/*.sh"
  - ".claude/hooks/lib/*.sh"
  - ".claude/settings.json"
symptom: pre-agent-gate.sh 從裝上去那天起就沒攔截過任何一次。另一個專案同一則訊息派 3 個 debug-investigator、後續兩個 tdd-guide 並行寫同一個工作樹，全程零提示，hooks.log 裡連一筆閘門紀錄都沒有
root-cause: 閘門數的是 agent-activity.jsonl 裡「agent_start 過但沒有 agent_complete」的筆數，而 agent_complete 由 PostToolUse(Agent) 寫。Agent 工具是**非同步**的——呼叫立刻返回 {"isAsync":true,"status":"async_launched"}，所以 PostToolUse 記的是「派工動作返回了」，不是「agent 做完了」。實測 start→complete 間隔 2 秒，那個 agent 實際跑了 44 分鐘。每一筆 start 都在 2 秒內被自己的 complete 沖銷 → in-flight 恆等於 0
guard: PostToolUse 只保證「工具呼叫返回了」。凡是要判斷「那件事真的做完了」，先確認該工具是不是非同步（tool_response 帶 isAsync / async_launched 就是），是的話改用專屬的結束事件（subagent → SubagentStop）。寫這類閘門時**先用一筆真實資料對時間差**：start 與 complete 只差幾秒而工作明顯更久，就是這個坑
severity: high
---

> ⚠️ 與 `2026-09-09-hook-sees-own-dispatch.md` 同一支閘門，但是**不同的坑**。
> 那次是「把自己算進 in-flight」（誤報）；這次是「完成訊號記錯時機」（漏報，
> 而且漏光）。兩者可以同時存在，因為誤報有 deny-once 掩護、漏報沒有任何症狀。

## 怎麼發現的

不是靠測試，也不是靠這個 repo。是在**另一個專案實際踩到**：同一則訊息派了
3 個 `debug-investigator`，接著兩個 `tdd-guide` 並行寫同一個工作樹的程式碼，
全程沒有任何提示。回頭查 `hooks.log` 連一筆閘門紀錄都沒有——**因為閘門只在
攔截時才寫 log**，沒攔截就什麼都不留，所以「壞掉」和「沒事」長得一模一樣。

確認根因靠的是對 `agent-activity.jsonl` 的時間差：

```
10:02:44  agent_start     toolu_013b9neGLpKY8haj17tydCbK
10:02:46  agent_complete  toolu_013b9neGLpKY8haj17tydCbK   ← 2 秒
```

那個 agent 實際跑了 44 分鐘。`agent_complete` 的 response 內容是
`{"isAsync": true, "status": "async_launched", "agentId": "..."}`——
它自己就寫著「這只是啟動了」。

**245 個 hook 單元測試一個都沒抓到。** 原因不是測得不夠細，是測的東西不對：
測試直接造假 JSONL（`ag_start a1`）再問閘門會不會擋，於是只驗到「閘門怎麼讀帳」，
**沒有任何一個案例驗「帳記得對不對」**。bug 在後者。

## 修法

`agent_complete` 改由 **`SubagentStop`** 寫。實測事實（本 repo 裝臨時探針量到的）：

- `SubagentStop` **對非同步／背景 subagent 也會觸發**，時機是 agent 真正結束時
- payload 有 `agent_id`，**與派工時 Agent 工具回傳的 `agentId` 是同一個值**；
  payload 裡**沒有** `agentId` 駝峰欄位（值為 null），也**沒有** `tool_use_id`
- `matcher` 比對 `agent_type`（實測值 `Explore`），用 `".*"` 收全部
- `settings.json` 的 hook 設定是**熱載入**，改完不用重啟 session

連帶要動的兩件事：

1. **`agent_start` 必須移到 `PostToolUse(Agent)` 寫**——`agentId` 只存在於
   PostToolUse 的 tool response 裡，PreToolUse 拿不到。對應鍵從 `tool_use_id`
   換成 `agent_id`
2. 因為 (1)，`pre-agent-gate.sh` 原本「排除自己那一筆 `tool_use_id`」的邏輯
   **整段可以刪掉**：閘門跑在 PreToolUse，必然早於自己那次 PostToolUse，
   帳上根本還沒有自己。2026-09-09 那個誤報也一併消失（它的成因就是
   monitor 在 PreToolUse 先寫了 start）

### 必須容忍的兩個邊界（實測撈到的，不是假想）

- 會收到 `agent_type` 是**空字串**的 `SubagentStop` → 照樣寫 `agent_complete`。
  漏一筆就讓那個 agent 的 in-flight 永遠不歸零，閘門會從此**誤擋每一次委派**
- 會收到這個 session **從沒派過的 `agent_id`** → 照寫即可。閘門算的是
  「有 start 卻沒 complete」，多餘的 complete 不影響計數，也不可能讓它變成負數

## 為什麼這條會重犯

`PostToolUse` 這個名字讀起來就像「那件事做完之後」，而對絕對多數工具來說它就是。
`Agent` 是例外，而例外不會報錯——它會給你一個**看起來完整、時間戳也合理**的帳本。

目前模板裡「記錄 + 依記錄判斷」的組合還有：

- `post-bash.sh` 寫 `.merge-pending` → `pre-tool-use.sh` 的 merge-gate 讀它
  （Bash 是同步的，沒有這個問題）
- `post-agent-report.sh` 寫 `.report-expectations.jsonl`
  （**已經是對的**：它偵測 `async_launched` 就只記期望、不當場稽核，
  由 `lib/check-report-expectations.sh` 在後續對話邊界重查。本次沒有動它）

新增這類 hook 時先問兩題：**我讀的這份狀態，會不會已經包含我正在處理的這一次？**
（2026-09-09 那個坑）以及**我拿來當「完成」的那個事件，真的代表完成嗎？**（本坑）

## 相關

- `.claude/hooks/agent-monitor.sh` 檔頭 — 三種事件各自寫什麼、為什麼
- `.claude/hooks/pre-agent-gate.sh` — 讀帳的一方
- `.claude/context/learned/2026-09-09-hook-sees-own-dispatch.md` — 同一支閘門的另一個坑
- `.claude/hooks/tests/run-tests.sh` 的
  「agent-monitor.sh × pre-agent-gate.sh — 非同步派工的完成時機」節 —
  這組不造假 JSONL，一律走真的 monitor，payload 用實測的欄位形狀
