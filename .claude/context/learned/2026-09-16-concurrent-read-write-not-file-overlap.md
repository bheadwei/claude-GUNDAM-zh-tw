---
date: 2026-09-16
title: 平行 agent 的風險是「併行讀寫」，不是「寫入範圍重疊」——閘門用錯判準，還親手教模型繞過自己
files:
  - ".claude/hooks/pre-agent-gate.sh"
  - ".claude/rules/agent-orchestration.md"
  - ".claude/agents/*.md"
symptom: 平行派工時 ①`security-infrastructure-auditor` 跑測試回報 2 個 failed，實際上那兩個測試沒問題——它讀到 `code-quality-specialist` 改到一半的產品碼 ②一個審查類 agent 把 `debug-investigator` 刻意留紅的測試檔刪掉了。兩次 `pre-agent-gate.sh` 都有攔下來，但都在看完訊息後被放行
root-cause: 判準錯了。「檔案範圍不重疊」只涵蓋**寫入集**，而掃描／驗證類 agent 的寫入集是空的或很小——所以那個條件對它**永遠成立**。真正的衝突發生在它**讀**的那一邊：它讀或執行整個 repo，必然撞上任何併行寫入者留在工作區的半成品。更糟的是閘門訊息的選項 3 明寫「確認檔案範圍不重疊後重試即可通過」，等於閘門親手把模型引導到那個永遠成立的結論，再加上 deny-once 就放行了
guard: 判斷兩個 agent 能不能平行時，先問「有沒有一方是讀／跑整個 repo 的」（`security-infrastructure-auditor`、`code-quality-specialist`、`test-automation-engineer`、`e2e-validation-specialist`、`refactor-cleaner`）。有 → 只能序列化或帶 `isolation: "worktree"`，不要拿 plan 的 `files:` 無交集當理由。寫閘門訊息時也要檢查：你給的「重試即可通過」條件，會不會對某一類輸入恆為真
severity: high
---

> **注意：坑閘門不會貼出這一篇。** `pre-tool-use.sh` 對 `.claude/*` 直接放行
> （worktree 路徑誤命中的修法帶來的取捨），所以 `files:` 在這裡只是**索引用**。
> 這個坑真正的強制者是 `pre-agent-gate.sh` 本身——它現在會在偵測到掃描／驗證類
> agent 時改推薦序列化、收掉選項 3、並且不套用 deny-once。

## 怎麼發現的

兩次事故，相隔不久，一開始被當成兩個不相干的問題：

**事故一 — 假 failed。** `code-quality-specialist` 正在重構產品碼，同時派了
`security-infrastructure-auditor`。後者跑測試時讀到的是**改到一半**的檔案，
於是回報 2 個 failed。那兩個測試本身沒有問題，重構結束後再跑就是綠的。
第一反應是去查那兩個測試，繞了一圈才想到時間點。

**事故二 — RED 測試被刪。** `debug-investigator` 照流程先寫了一個會失敗的
重現測試（那正是它該做的事），還沒開始修。併行的審查類 agent 掃到那個檔案，
在它的視角裡那就是「一個壞掉的測試」，於是刪掉了。**沒有任何錯誤訊息**——
它甚至在報告裡把這件事寫成一項清理成果。

排除掉的假設：不是 agent 本身有 bug（兩個 agent 各自單獨跑都正確）、
不是 prompt 沒寫清楚（第二次的 prompt 有寫「不要動測試」）。
共同點只有一個：**兩次都有一個「讀整個 repo」的 agent 跟一個寫入者同時在跑。**

## 關鍵情節：閘門存在，而且真的擋了，卻沒有防住

這不是「忘記裝閘門」的故事。`pre-agent-gate.sh` 兩次都攔了下來，
訊息也正確地說了「後寫的會直接覆蓋前面的」。問題出在它給的**出路**：

```
3. 確認範圍無交集後重試 —— 若你已確認這幾個 agent 的檔案範圍不重疊
   （例如各寫不同的報告檔），用一句話說出各自要寫哪些檔案，然後重試
```

掃描／驗證類 agent 的寫入集**是空的**。所以「範圍不重疊」是一句永遠為真的話，
模型每次都能誠實地說出來、然後重試、然後通過（deny-once 連第二次都不會再擋）。

**閘門沒有漏判，它是把模型引導到了一個恆為真的條件上。**
這比沒有閘門更難發現：現場看起來是「有把關、有理由、有人確認過」。

## 修法

`pre-agent-gate.sh`（2026-09-16）：

1. 定義 `SCAN_AGENTS`（讀或執行整個 repo 的五個），並從 `agent-activity.jsonl`
   的 `agent_type` 判斷 in-flight 那一批是誰
2. 本次要派的或任何 in-flight 落在名單裡 → 推薦序列化，理由明講**讀寫衝突**，
   附上這兩起事故當證據
3. **收掉選項 3** —— 那不是一個有效的理由
4. **不套用 deny-once** —— 持續擋到 in-flight 歸零、或這次帶 `isolation`。
   兩個出口閘門自己都驗得出來，所以不會鎖死。一般情境的 deny-once 不變

文字版判準同步到 `rules/agent-orchestration.md`「安全平行」與
`worktree-orchestration` skill 的判準表（各一句，指回閘門，不重述訊息內容）。

## 可以帶走的通則

**寫閘門訊息時，把每個「這樣做就放行」的條件拿去問一次：有沒有哪一類輸入
讓它恆為真？** 有的話那個條件就是漏洞，而且它會以「使用者確認過了」的形式
出現在紀錄裡，事後查起來完全合理。

## 相關

- `.claude/hooks/pre-agent-gate.sh` — 強制者（訊息是判準的唯一來源）
- `.claude/rules/agent-orchestration.md` — 「安全平行」節
- `.claude/skills/worktree-orchestration/SKILL.md` — 何時值得開 worktree
- `2026-09-11-async-dispatch-breaks-posttooluse-gates.md` — 同一支閘門的另一次
  靜默失效（那次是帳算錯，這次是判準錯）
