---
date: 2026-09-09
title: 同一事件的多支 hook 有執行順序，後跑的會看到前一支寫下的狀態——包含「它自己這一次」
files:
  - ".claude/hooks/*.sh"
  - ".claude/hooks/lib/*.sh"
  - ".claude/settings.json"
symptom: 閒置超過 60 分鐘後的第一次委派**必被** pre-agent-gate 擋一次，理由寫「已經有 1 個沒有隔離的 agent 在跑」——但當下根本沒有其他 agent
root-cause: settings.json 的 PreToolUse 把 agent-monitor.sh 排在 pre-agent-gate.sh 前面。monitor 先把這一次的 agent_start 寫進 agent-activity.jsonl，閘門接著從同一份 log 算 in-flight，於是把「它自己正在把關的這一次」也算進去
guard: 任何從共享狀態檔（log／jsonl／旗標）反推「現在有幾個 X 在進行中」的 hook，都必須確認自己這一次沒被算進去。不要靠調整 settings.json 的 hook 順序——順序是隱性契約，下一個重排的人不會知道
severity: medium
---

> 📌 **2026-09-11 更新：教訓仍然成立，但當時的修法已被取代。**
> 那次的 `SELF_ID` 排除邏輯**已整段移除**——`agent_start` 改在 `PostToolUse` 寫之後，
> 閘門（`PreToolUse`）必然早於自己那次 `PostToolUse`，帳上根本不會有自己，
> 誤報的成因消失了。**不要照下面「修法的選擇」那節把 `tool_use_id` 比對加回去**，
> 對應鍵已經換成 `agent_id`。原因見
> `2026-09-11-async-dispatch-breaks-posttooluse-gates.md`。

> ⚠️ **這份紀錄的 `files:` 正確，但坑閘門不會貼出來。** `pre-tool-use.sh:146` 對
> `.claude/*` 直接放行（避免自鎖），所以關於模板自身擴充的教訓一律不會被攔下來提示。
> 這是已知落差（`learned/` 不覆蓋 `.claude/`）。**要有守門只能加 `check-counts.sh` 的檢查。**

## 怎麼發現的

不是靠測試，是靠**實跑**。2026-09-09 第一輪 skill-compliance 壓力測試中，
prompt 01 的受測 session 自己派 agent 時撞到，在回報裡指名根因。

**190 個 hook 單元測試一個都沒抓到**，原因是它們直接餵 JSON 給單一 hook，
**不經過 `settings.json` 的 hook 串接**。單支測起來完全正確，串起來才錯。

`deny-once` 機制讓症狀看起來只是「擋一下、重試就過」，所以放了很久沒人覺得不對。

### 排除過的假設

- **不是** in-flight 計算的 60 分鐘視窗太寬（那會讓誤報跟閒置時間相關，
  但誤報是「第一次委派」必中，與閒置多久無關）
- **不是** 當機殘留的 phantom `agent_start`（清空 log 後第一次委派照樣被擋）

### 修法的選擇（有量測，不是猜）

先驗證 PreToolUse 的 INPUT 真的帶 `tool_use_id`：實測 `agent-activity.jsonl` 裡
**41 筆 PreToolUse 產生的 `agent_start` 全部帶真實 `tool_use_id`，零筆 `"unknown"`**。
確認可行才改成「算 in-flight 時排除自己」。

**沒有選調 hook 順序**，因為那只治症狀，還會留給下一個重排 `settings.json` 的人一顆地雷。
**也沒有選「in-flight ≥ 2 才擋」**——那會讓真正的兩個並行漏掉第一次，
把誤報換成漏報。

## 完整說明

官方對同一事件的多支 hook 不保證你以為的順序語意：它們**依序執行**，
所以先跑的那支對共享狀態的寫入，後跑的那支看得到。
本模板的 PreToolUse 掛了 monitor（記錄）與 gate（把關）兩類 hook，
記錄型的先跑就會污染把關型的判斷依據。

同一類風險存在於任何「記錄 + 依記錄判斷」的 hook 組合。目前模板裡符合這個形狀的還有：

- `post-bash.sh` 寫 `.merge-pending` → `pre-tool-use.sh` 的 merge-gate 讀它
  （這組沒問題：寫在 PostToolUse、讀在 PreToolUse，跨事件不會撞到自己）
- `agent-monitor.sh` 寫 `agent-activity.jsonl` → `pre-agent-gate.sh` 讀它
  （**就是本坑**，同一事件同一批 hook）

新增這類 hook 時先問：**我讀的這份狀態，會不會已經包含我正在處理的這一次？**

## 相關

- 修正的 commit：`0b9da63`（只動 `pre-agent-gate.sh`，順序無關）
- 壓力測試判讀：`.claude/tests/skill-compliance/results/20260909-130333/_判讀.md`
  （該目錄不進版控，見 `.gitignore` 第 45 行）
- 相關落差：`pre-agent-gate.sh` 的 `.suggest-mode` 讀 `WORK_CLAUDE` 而非 `MAIN_CLAUDE`，
  與 `worktree-orchestration` 的隔離邊界表不一致（已記入 CLAUDE.md 已知落差，未修）
