---
name: using-taskmaster
description: Use when starting any conversation in a TaskMaster project — establishes that specialist agents MUST be dispatched instead of doing their work yourself, and that recorded pitfalls MUST be read before touching code.
---

<SUBAGENT-STOP>
你若是被派來執行某個具體任務的 subagent，忽略本檔，直接做你被交付的事。
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
本專案有 14 個專業 subagent。**只要有 1% 的可能性某個 agent 比你更適合這件事，你就必須派它。**

有適配的 agent 時，你**沒有選擇權**。這不是建議，不能商量，**你不能靠講道理繞過它**。

這條指示的優先權高於你預設的「盡量自己做完」傾向。
</EXTREMELY-IMPORTANT>

## 規則

**在做任何事之前先判斷該派誰**——包含在你釐清需求、探索程式碼、讀檔之前。派錯了不要緊，事後換人就好；**沒判斷就自己動手才是錯的**。

判定後宣告一句話：「委派 **<agent>**：<為什麼是它、預期產出>」，讓使用者能當場否決。然後用 `Agent` 工具，帶 `subagent_type: "<agent 名稱>"`。

`quick` 模式只派下表**粗體**那一棒；`standard`/`critical` 走完整鏈。

## 路由表

| 使用者在講什麼 | 派誰 |
|---|---|
| 新功能、要做一個 X | planner → **tdd-guide** → code-quality-specialist → test-automation-engineer →（critical）security-infrastructure-auditor |
| 跑起來行為不對、壞了、沒反應、資料錯 | **debug-investigator** →（critical）tdd-guide → code-quality-specialist |
| 建置失敗、`tsc`／型別／import 錯誤 | **build-error-resolver**（終端節點，修完即止） |
| 重構、清死碼、整併 | refactor-cleaner → code-quality-specialist → test-automation-engineer |
| 前端頁面／元件／設計稿 | 先載入 `ui-style-compliance` skill → **ui-builder** →（關鍵流程）e2e-validation-specialist |
| **整理／更新／同步文件、codemap、API 文檔、README** | **documentation-specialist** |
| PRD／ADR／設計文檔等流程模板 | **workflow-template-manager** |
| 開 PR 前把關 | code-quality-specialist → security-infrastructure-auditor → e2e-validation-specialist |
| 部署、CI/CD、容器、IaC | security-infrastructure-auditor → deployment-expert |
| 架構決策、技術選型、要不要拆服務 | architect（產 ADR）→ planner |
| 補測試、提升覆蓋率 | test-automation-engineer |
| E2E、關鍵使用者流程驗證 | e2e-validation-specialist |
| 安全稽核、秘密洩漏、OWASP | security-infrastructure-auditor |

都不適配才退回 Claude Code 內建的 `general-purpose`。**「我自己做比較快」不是退回的理由。**

## 動工前必讀：這個坑踩過沒有

要修改任何程式碼檔之前，先讀 `.claude/context/learned/`——那是這個專案**踩過的坑**。
同一個坑不該踩第二次。`pre-tool-use.sh` 會在你寫到有紀錄的檔案時擋你一次並把坑貼給你看。

解完一個非平凡的問題後，**寫一筆進 `learned/`**（格式見該目錄 README）。不要只在對話裡講完就算。

## Red Flags —— 想到這些就是在合理化

| 你正在想 | 事實 |
|---|---|
| 「這只是個簡單問題」 | 問題就是任務。先判斷該派誰。 |
| 「我先了解一下狀況再說」 | 判斷該派誰**先於**釐清需求。agent 自己會釐清。 |
| 「我先看一下程式碼」 | agent 的職責就包含怎麼看。先判斷。 |
| 「這個我自己做比較快」 | 快不是目標。**agent 帶的是不會被跳過的流程**（先重現、先寫測試、先掃安全）。 |
| 「才改一行，不值得開 agent」 | 那就判 `quick` 並宣告，不是跳過判斷。 |
| 「我記得這個 agent 大概在幹嘛」 | agent 定義會改。要用就讀當前版本。 |
| 「文件更新算雜事，不用派」 | documentation-specialist 就是為此存在。**這是最常被漏掉的一棒。** |
| 「使用者只是問問題」 | 若答案要跨檔調查，那是任務。 |
| 「我等一下再一起派」 | 現在判斷。「等一下」不會到。 |
| 「反正我做完會自己檢查」 | 自檢不等於 code-quality-specialist 的檢查。 |
| 「hook 沒提示我，應該不用派」 | hook 的關鍵字表不完整。**沒提示不代表不用派。** |

## 執行多階段計畫時：agent 不只是顧問

`standard`/`critical` 且 plan 有 ≥2 階段時，**載入 `subagent-execution` skill**——
它把每個階段交給一個全新的 implementer subagent 實作，帶階段審查、有界修復迴圈、
以及能撐過 context 壓縮的帳本。

不要自己一路把 4 個階段寫完：長任務裡你會慢慢偏離 plan，而且沒有任何紀錄能讓人
（包括下一個 session 的你）看出是從哪一步開始偏的。

`quick` 模式不適用——開 subagent 的開銷大於收益。

## agent 回來之後：照狀態碼分流

每個 agent 結束時會輸出 `STATUS: <碼>`。照這張表處理，**不要自己揣測**：

| 狀態碼 | 你要做的事 |
|---|---|
| `DONE` | 收下產出 → 依它建立的 handoff 啟動下一棒 |
| `DONE_WITH_CONCERNS` | **先讀疑慮**。屬於正確性或範圍的 → 處理掉再往下；只是觀察（「這檔案有點大」）→ 記下來繼續 |
| `NEEDS_CONTEXT` | 補齊它說缺的東西後**重新派同一個 agent**。缺的是使用者意圖就去問使用者 |
| `BLOCKED` | 評估阻礙。**絕不用同一個模型原樣重試**——它說卡住了，就得有東西改變：換方法、換更強的模型、或修正計畫本身 |
| 沒有狀態碼 | 當作沒交代完。要它補一份狀態，或自己驗證產出後再往下 |

## 交接（handoff）

agent 完成後會寫報告並對需要後續處理者建立 handoff。`post-agent-report.sh` 會把
pending handoff 注入對話——**看到注入提示就啟動那個「to」agent**，不要停在原地問
使用者要不要繼續。

hook 只能注入提示，**啟動 agent 的執行者是你**。

## 使用者指示優先

使用者的明確指示（CLAUDE.md、當下的話）優先於本檔。使用者說「不要開 agent，你直接做」就直接做。
只有在使用者明確這樣說過時才略過本檔。

## 相關

- `.claude/rules/agent-orchestration.md` — 完整編排劇本、反模式、安全平行
- `.claude/rules/task-mode.md` — quick / standard / critical 判級
- `.claude/context/learned/` — 踩過的坑
- `.claude/coordination/README.md` — handoff 格式
