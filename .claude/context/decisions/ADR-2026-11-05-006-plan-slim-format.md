---
status: 已採納
date: 2026-11-05
decision-makers: [使用者]
---

# ADR-2026-11-05-006: plan 只有四段——為什麼做、怎麼做、改善了什麼、發現與決策；每個階段寫「依賴」讓可平行的階段被主動提出；程式在讀的部分一律不動

## 背景

實測專案 A 有 321 份 plan（平均 197 行、最長 1,053 行），B 有 65 份（平均 200 行）。
`status:` 是自由文字：A 有 60 多種寫法、B 有 20 多種；A 有 2 份標「✅ 完成」卻還在進行中目錄，
B 有 4 份「階段狀態未逐項回填」；很多 plan 完成後被當成實作日誌續寫。
現行骨架 8 段：目標、一眼看懂、WBS 連結、技術依賴、階段拆解、風險與緩解、驗收標準（整體）、計畫 vs 實際；
「WBS 連結」和 frontmatter 的 `wbs_task` 重複，「驗收標準（整體）」大多是每個任務都一樣的共同門檻。
使用者要 plan 回答四件事：為什麼做、怎麼做、改善了什麼、做的過程發現了什麼。

另一個問題：使用者要特別說「平行開發」，階段才會被考慮平行。原因有兩層——
任務層級 `commands/task-next.md` 第 83–95 行只在 ready 任務**都已有 plan 且寫了 `files:`** 時才出現平行選項，
但 plan 通常在選完任務後才寫，選項幾乎不會出現；階段層級 `commands/tdd.md` 第 84–100 行只問「逐階段派 implementer／主模型直接做」，
兩者都循序，而 plan 的階段沒有「依賴哪些階段」，部件表雖有「檔案」欄也算不出哪些階段能同時跑。

plan 要怎麼瘦身、怎麼讓可平行的階段被主動提出，才不會讓讀它的程式與幾百份舊 plan 壞掉？

## 決策

**骨架（standard）**：

```markdown
---
wbs_task: "2.1"            # ad-hoc 填 "none"
slug: "partial-shipment"
created: "2026-11-05"
updated: "2026-11-05"
status: "🔄 進行中"         # 只准四個值，見下
current_phase: 1
mode: standard
files:
  - "src/services/orders/**"
---

# 訂單可以部分出貨

## 為什麼做
（≤ 3 句：誰遇到什麼問題）

### PRD 情境變更
- ADDED ORD-03 部分出貨 —（全文）
（沒有動到使用者看得到的行為就寫「無」；格式見 ADR-005）

## 怎麼做

**可平行**：階段 2、3（依賴都是階段 1，檔案不重疊）

### 一眼看懂
（mermaid＋部件表，欄名不變——overview.sh 讀）

### 階段 1: 資料結構 ⏳
- **依賴**：無
- [ ] 步驟 — 驗證：`pytest tests/orders/test_partial.py`
- **驗收**：ORD-03 的「那麼」成立；另外 <只有這階段才有的行為>

### 階段 2: 出貨服務拆單 ⏳
- **依賴**：階段 1
- …

### 階段 3: 訂單頁顯示子單 ⏳
- **依賴**：階段 1
- …

## 改善了什麼
| | 之前 | 之後 |
|---|---|---|
| 缺一件貨的訂單 | 整筆卡住不能出貨 | 有貨的先出，缺的那件另開待出貨 |

## 發現與決策
- 2026-11-06 物流 API 不支援拆單編號，改成在我們這邊產子單號
```

- **為什麼做**：取代「目標」；底下的「PRD 情境變更」是 ADR-005 的介面
- **怎麼做**：「一眼看懂」與「階段 N」都搬到這段底下，**標題文字與格式不變**；每個步驟附「驗證：」指令；
  階段的「驗收」引用 PRD 情境編號（例如「ORD-03 的『那麼』成立」），只補那一階段特有的行為
- **改善了什麼**：寫 plan 時就填「之前／之後」（只寫**行為**，不要求數字或截圖）；`/verify` 完成時照實際結果修正。這段取代原本的「結果」
- **發現與決策**：邊做邊寫，一筆一行帶日期；只記改變了計畫或影響之後的事。跨任務的設計決策寫 ADR，這裡放連結
- critical 多兩段：`## 回滾`、`## 威脅`（連到 `docs/threat-model.md`）。quick 照舊不寫 plan
- **刪掉**：「WBS 連結」（用 `wbs_task`）、「技術依賴」（寫進步驟）、「風險與緩解」（真的會踩的坑寫進該階段一行「注意」；跨任務風險寫 WBS 風險表）、
  「驗收標準（整體）」（共同門檻已在 `task-mode.md` 與 `testing-standards`）

**階段可平行**（只改 md：`plan-format`、`planner.md`、`tdd.md`、`task-next.md`；不加 hook、不加腳本）：

- **依賴**：每個階段標題的**下一行**寫 `- **依賴**：階段 X, Y`（沒有寫「無」）。**會讀到另一階段產出的型別、介面、schema、fixture 也算依賴**——
  部件表的「檔案」只看得到寫入，看不到讀取（同 `agent-orchestration.md` 的「讀撞寫」）
- **可平行的判準**：兩個階段的依賴都已完成，**而且**部件表中屬於這兩個階段的「檔案」glob 無交集；任一階段在部件表沒有列檔案 → 不可平行
- **planner**：在「怎麼做」開頭寫一行 `**可平行**：…`（沒有就寫「無」）。這行是給人看的摘要；`/tdd` 依上一條重算，不一致時以重算為準並在輸出指出
- **`/tdd`**：選執行方式時，重算出「依賴已完成、可同時開工」的階段 ≥ 2 個，就多一個選項「階段 N、M 用 worktree 同時跑」。
  程序沿用 `worktree-orchestration`（開 worktree、合併順序、共用執行資源）與 `subagent-execution`（每階段一個 implementer＋階段審查），不在 tdd.md 重寫。
  implementer 帶 `isolation: "worktree"`，由既有的 `pre-agent-gate.sh` 依 `agent-orchestration.md` 的規則放行；會讀整個 repo 的審查 agent 在**該階段的 worktree 裡**審該階段的 diff；
  plan 與帳本只由主模型在主 checkout 改（開 worktree 前 plan 要已 commit，合併一條驗一條，合併後才標 ✅）；同時進行的階段都標 🔄，`current_phase` 寫最小的未完成階段
- **`/task-next`**：候選任務沒有 plan 時，若 WBS 有「模組」欄、兩個 ready 任務的模組不同（都不是空或 `—`），在選項說明提示「2.2、2.3 可能可平行，先 `/plan` 兩個再確認」，**不直接提供平行選項**；有 plan 且有 `files:` 的照現行規則
- 舊 plan 沒有「依賴」行 → 視為依賴前一階段，`/tdd` 不提供階段平行選項（等同現狀）

**程式在讀的部分，一律不動**：frontmatter 的 `wbs_task`／`status`／`current_phase`／`mode`／`files:`、
`### 階段 N: 名稱 <狀態>` 標題、「一眼看懂」部件表欄名（`OVERVIEW_COLS_PART`）、`overview:actual` 區塊。
專案地圖的「plan 預計會動」一層（ADR-007）就是讀 `files:`、`current_phase` 與階段標題數。
「依賴」寫在標題**下一行**而不是標題裡：`overview.sh` 只解析 `^###\s*階段\s*\d` 標題行（名稱經 `strip_state` 去掉狀態），
寫進標題會被當成階段名稱的一部分；部件表也不加欄。statusline 的 `grep -c '^### 階段'` 不受影響。
唯一受影響的是地圖疊層的「plan 第 N／M 階段」：兩個階段同時 🔄 時只顯示 `current_phase` 會誤導，
所以地圖計畫的 A3 改成取標題狀態為 🔄 的全部階段（`overview.sh` 已有 `pstate`），顯示「第 2、3／4 階段」（見 ADR-007 與 handoff）。

**status 只准四個既有值**：`⏳ 未開始`、`🔄 進行中`、`🚫 阻塞`、`✅ 完成`，**後面不加任何附註**（附註寫進「發現與決策」）。
歸檔另加 `archived:` 日期，照現行。選這四個是因為 `overview.sh`、`/tdd`、`/verify` 本來就認得它們，不用改任何讀取程式；
60 多種寫法的來源是附註，不是 emoji。

**收尾**：`/verify` 修正「改善了什麼」、套回 PRD 情境（ADR-005）、標 `✅ 完成`、歸檔。歸檔後的 plan 不再續寫，新的發現開新 plan 或寫 `context/learned/`——這條寫在 `plan-format`，不加 hook。

**相容**：**舊 plan 一份都不改寫。** 舊 plan 有「驗收標準（整體）」節時，`/verify` 照舊比對它；新 plan 比對各階段驗收與 PRD 情境。
`/tdd` 接續舊格式的 plan 時照舊做，不強迫轉換。

## 替代方案

| 方案 | 優點 | 否決理由 |
|---|---|---|
| 維持現行 8 段骨架 | 不用改 | 平均 200 行、status 60 多種，已證實不收斂 |
| ExecPlan 式四段（Progress、Surprises、Decision Log、Outcomes） | 有官方範本 | Progress 會和階段標題、執行帳本重複；使用者要的是「為什麼／怎麼做／改善／發現」，不是過程紀錄 |
| status 改成英文列舉（planned／active／done…） | 不容易被加附註 | 要改 `overview.sh`、`/tdd`、`/verify` 的讀取，還要一張新舊對照表；禁止附註就能解決同一個問題 |
| 「改善了什麼」要求數字或截圖 | 證據力強 | 很多變更沒有可量的數字；硬要數字會變成編造。行為的之前／之後人就看得懂 |
| 一次性腳本把舊 plan 全轉成新格式 | 只剩一種格式 | 改寫歷史紀錄、diff 巨大；歸檔的 plan 沒人會再依格式讀它 |
| 階段平行：只看部件表「檔案」無交集，不寫依賴 | planner 少寫一行 | 只看得到寫撞寫、看不到讀撞寫：階段 3 讀階段 2 新增的型別時檔案不重疊，卻不能同時跑 |
| 階段平行：依賴寫進部件表多一欄 | 一張表看完 | 依賴是階段的屬性、不是部件的；同一階段多個部件要重複寫，而且動到 `OVERVIEW_COLS_PART` 所在的表 |
| 階段平行：依賴寫進 `### 階段 N` 標題 | 一行看完 | `overview.sh` 會把它當成階段名稱的一部分 |
| 階段平行：只靠 planner 寫的「可平行」行，`/tdd` 不重算 | 最簡單 | 階段做到一半時依賴的完成狀態會變，摘要行會過期；重算只是讀標題狀態與部件表 |
| `/task-next` 沒 plan 時直接用 WBS 模組欄提供平行選項 | 平行選項更常出現 | 模組不同不代表檔案不重疊（共用型別、設定檔）；只能提示「先 `/plan` 兩個再確認」 |
| 用 hook 檢查 plan 的 status 與長度 | 機器強制 | 使用者明確不要再加 hook（實測 Windows 上每次 Bash 工具呼叫已多 3.5～4 秒）；`/verify` 歸檔時本來就會寫 status |

## 後果

**得到：**
- plan 讀起來回答四個問題，「改善了什麼」讓人不讀程式也知道這次的成果
- 驗收直接引用 PRD 情境，PRD 與 plan 對得起來
- 讀 plan 的程式（`overview.sh`、statusline、閘門、`/tdd`、`/verify`）不用改；只有文字要改：`plan-format`、`planner.md`、`tdd.md`、`task-next.md`、`verify.md`、`task-status.md`
- 可平行的階段不用使用者開口就會被提出，平行與否仍由使用者在 `/tdd` 選；不選就是現在的循序流程

**犧牲：**
- status 不加附註只靠 `plan-format` 的規則與 `/verify` 照做，沒有機器檢查
- 舊格式（有「驗收標準（整體）」）與新格式在 `/verify` 有兩條比對路徑並存
- planner 每個階段多寫一行「依賴」；漏列讀取型依賴時，兩個階段會被判成可平行。緩解：缺的型別會讓該 worktree 的建置或測試失敗，不會靜默合併；合併一條驗一條
- 平行階段多了 worktree 的開銷（磁碟、合併、各自審查），也會搶本機 DB、固定 port；後者照 `worktree-orchestration`「共用的執行資源」處理
- 地圖計畫的 A3 要多算一個 `activePhases`

**何時該重新考慮：**
- 新格式的 plan 半年後平均仍超過 200 行 → 看是哪一段在長
- 「發現與決策」又被寫成實作日誌（單份超過 30 筆）→ 改成只准寫在執行帳本
- 使用者選了階段平行、卻有兩成以上的合併因為漏列依賴而失敗 → 判準加上「兩階段的模組不同」，或改成預設不提供、使用者問了才算
- 平行選項出現了但使用者幾乎都不選 → 選項說明太長或成本太高，改成只在可平行階段估時合計 ≥ 2h 才出現
- 抽查發現 status 仍常被加附註 → 再考慮由 `overview.sh` 在一頁現況裡列出（它本來就解析 status，不需要新 hook）

## 確認方式

- [T] 既有 `run-tests.sh` 的 plan fixture 原樣通過；另加一份四段格式的 fixture：`overview.sh` 讀得到部件表、`currentPhase`，statusline 算得出 `(plan n/m)`
- [C] `check-counts.sh`：`plan-format` 範例的 status 值是四個之一、部件表欄名檢查照舊
- [T] 每個階段標題下有「依賴」行的 fixture：`overview.sh` 解析出的階段名稱不含「依賴」字樣、階段數與部件表照舊；兩個階段同時 🔄 → data.js 的 `currents[].activePhases` 為兩個編號（地圖計畫 A3）
- [C] `check-counts.sh`：`plan-format` 範例的每個 `### 階段 N` 下一行是 `- **依賴**：`
- [M] 用新格式寫一份 plan 跑完 `/tdd` → `/verify`：「改善了什麼」被修正、PRD 已套回、status 為 `✅ 完成`、已歸檔
- [M] plan 有「階段 2、3 依賴都是 1、檔案不重疊」：階段 1 完成後 `/tdd` 出現「階段 2、3 用 worktree 同時跑」；把階段 3 的依賴改成「階段 2」→ 選項消失
- [M] plan 的階段 2、3 部件表檔案有交集 → 不出現平行選項，即使「可平行」行寫了；輸出指出摘要行與重算不一致
- [M] `/task-next`：兩個 ready 任務沒有 plan、WBS 模組欄分別是 `orders`、`members` → 選項說明出現「可能可平行，先 `/plan`」，但沒有平行開發選項；模組欄都是 `orders` → 不提示

## 相關

- 設計提案：`.claude/context/decisions/architect-2026-11-05-1730.md` 第 6 節
- 修改：`plan-format` skill（唯一來源）、`agents/planner.md`（改成指向 plan-format，不再內嵌骨架）、`commands/{tdd,task-next,verify,task-status}.md`
- 沿用（不修改）：`worktree-orchestration`、`subagent-execution` skill、`rules/agent-orchestration.md`、`hooks/pre-agent-gate.sh`
- 相關：ADR-2026-11-05-005（情境變更小節）、007（地圖讀 `files:` 與階段）
