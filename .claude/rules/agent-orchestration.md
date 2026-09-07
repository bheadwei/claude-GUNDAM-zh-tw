# Agent 編排劇本（Orchestration Playbook）

定義主模型何時、如何串接專業 subagent。目標：**該委派時主動委派、該交棒時靠 handoff 接力**。

## 核心原則

1. **有專業 agent 就優先委派** — 強制性與 Red Flags 反合理化表見 `using-taskmaster` skill。
   都不適配時才退回 Claude Code 內建的 `general-purpose`
   （本模板不自訂它：同名會 shadow 掉內建版，換來的是更小的工具集）
2. **委派要看任務模式** — `quick` 原則上不拉 planner/tdd-guide；`standard`/`critical` 才走完整鏈
3. **交棒靠 handoff，不靠記憶** — 後續工作以 `coordination/handoffs/` 傳遞；`post-agent-report.sh` 會把 pending 交接注入對話，**看到提示就接手對應的「to」agent**
4. **委派前先宣告** — 一句話說明「為什麼是這個 agent、預期產出」，讓使用者可當場否決

## 該派誰

**路由表的唯一來源是 `using-taskmaster` skill**（`session-start.sh` 每個 session 全文注入，
所以它一定在你的 context 裡）。本檔不重述那張表——重複的表會漂開，而它有牙齒、這裡沒有。

本檔負責的是**表以外**的編排知識：鏈怎麼推進、哪些 agent 會建交接、反模式、安全平行。

## 鏈如何推進

1. 主模型依任務類型啟動**第一棒**（依 `using-taskmaster` 的路由表）
2. 該 agent 完成時：寫報告到 `context/<area>/`，並對需要後續處理者建立 handoff
3. `post-agent-report.sh`（PostToolUse hook）掃到 pending handoff → 注入提示
4. 主模型看到提示 → 啟動 handoff 的「to」agent；該 agent 讀取屬於自己的 pending handoff
   作為工作清單，完成後把 status 改 `completed`
5. 重複直到無 pending handoff

> Hook 只能注入提示，無法直接啟動 agent。**主模型是執行者**。

### 哪些 agent 實作了接力

**會寫報告 + 建 handoff（11）**：planner、architect、tdd-guide、code-quality-specialist、
test-automation-engineer、security-infrastructure-auditor、e2e-validation-specialist、
deployment-expert、refactor-cleaner、ui-builder、debug-investigator

**終端節點，不建 handoff（3）**：build-error-resolver（單點修完即止）、
documentation-specialist、workflow-template-manager

`quick` 模式例外——tdd-guide 在 quick 下不寫報告也不建 handoff。

## 反模式（避免）

- ❌ `quick` 小修改卻啟動 planner + tdd-guide 全套
- ❌ 有專業 agent 卻全用 general-purpose
- ❌ agent 留下 pending handoff 卻無人接手
- ❌ 同時平行啟動會互改同一批檔案的 agent（序列化或用 worktree 隔離）
- ❌ 一次委派一長串 agent 卻不在每棒後檢視產出

## 安全平行

平行不是反模式，**「會互改同一批檔案」才是**。

- **判斷依據**：各任務 plan 檔的 `files:` frontmatter（見 `plan-format` skill）。
  無交集 → 可平行；沒 plan／沒 `files:` → 保守視為不可平行
- **完整程序**：見 `worktree-orchestration` skill（**唯一來源**）——狀態隔離邊界、
  原生 `claude -w`、依相依順序合併、清理判準
- **入口**：`/task-next` 的平行選項（WBS 驅動）、`/worktree`（臨時隔離）
- **委派**：`Agent` 工具帶 `isolation: "worktree"`，或 agent frontmatter 寫
  `isolation: worktree`（`refactor-cleaner` 已如此設定）
- **並行數 2-4 個**。再多你自己看不過來，磁碟與 context 成本也會超過收益

> 一句話：**循序是預設、平行是選項**。
>
> 但要知道 Claude Code 會**強制**隔離：worktree session（含它派出的 subagent）
> 對主 checkout 的寫入、cwd 逃逸、`git -C` 重導都會被擋。這比本檔寫「不要互改
> 同一批檔案」強得多——那是自律，這是機器。

## 相關

- `.claude/rules/task-mode.md` — 任務強度分級
- `plan-format` skill — plan 的 `files:` 欄
- `worktree-orchestration` skill — worktree 的完整程序與狀態隔離邊界
- `.claude/commands/worktree.md` — 臨時隔離工作區的入口
- `.claude/coordination/README.md` — 交接檔格式
- `.claude/commands/suggest-mode.md` — 調整建議/注入密度
- `.claude/commands/hub-delegate.md` — 手動委派單一 agent
