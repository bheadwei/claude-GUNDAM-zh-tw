# Agent 編排劇本（Orchestration Playbook）

定義主模型（main agent）何時、如何串接專業 subagent。目標：**該委派時主動委派、該交棒時靠 handoff 接力**，而不是凡事自己硬幹或忘記下一棒。

與 `task-mode.md`（任務強度）、`coordination/README.md`（交接機制）、`suggest-mode.md`（建議密度）協同運作。

## 核心原則

1. **有專業 agent 就優先委派** — 對應領域有專家（見下表）時，優先委派而非自己做；`general-purpose` 只在無人適配時當後備。
2. **委派要看任務模式** — `quick` 任務原則上**不**拉 planner/tdd-guide（避免小題大作，見問題 #2）；`standard`/`critical` 才走完整鏈。
3. **交棒靠 handoff，不靠記憶** — agent 之間的後續工作以 `coordination/handoffs/` 交接檔傳遞；`post-agent-report.sh` 會在 agent 完成後把 pending 交接注入對話，**看到提示就接手對應的「to」agent**。
4. **委派前先宣告** — 啟動 agent 前用一句話說明「為什麼是這個 agent、預期產出」，讓使用者可當場否決。

## 標準鏈（依任務類型）

> 箭頭代表典型順序；實際接力由各 agent 寫出的 handoff 驅動。`quick` 模式只做粗體步驟。

| 任務類型 | 建議鏈 |
|---|---|
| **新功能（feature）** | planner → **tdd-guide** → code-quality-specialist → test-automation-engineer →（critical 才）security-infrastructure-auditor |
| **修 bug** | **tdd-guide（先寫重現測試）** → code-quality-specialist |
| **重構 / 清理** | refactor-cleaner → code-quality-specialist → test-automation-engineer |
| **建置 / 型別錯誤** | **build-error-resolver**（單點，修完即止） |
| **前端 UI** | （/ui-style →）ui-builder →（關鍵流程才）e2e-validation-specialist |
| **PR 前把關** | code-quality-specialist → security-infrastructure-auditor → e2e-validation-specialist |
| **部署 / 上線** | security-infrastructure-auditor → deployment-expert |
| **架構決策** | architect（唯讀產出 ADR/設計）→ planner（落地為計畫） |
| **文檔同步** | documentation-specialist（codemap/API）／ workflow-template-manager（PRD/ADR 模板） |

## 鏈如何實際推進

1. 主模型依任務類型啟動**第一棒** agent。
2. 該 agent 完成時：寫報告到 `context/<area>/`，並對需要後續處理者建立 handoff 到 `coordination/handoffs/`。
3. `post-agent-report.sh`（PostToolUse hook）掃到 pending handoff → 注入提示給主模型。
4. 主模型看到提示 → 啟動 handoff 的「to」agent；該 agent 啟動時自行讀取屬於自己的 pending handoff 作為工作清單，完成後把 status 改 `completed`。
5. 重複直到無 pending handoff。

> Hook 無法直接啟動 agent，只能注入提示。**主模型是執行者**——看到 pending handoff 且符合當前目標時，要主動接手。

## 任務模式對照（節錄自 task-mode.md）

| 模式 | 鏈的深度 |
|---|---|
| `quick` | 不拉 planner/tdd-guide；直接做 + happy-path；必要時才 code-quality |
| `standard` | 完整 feature 鏈，覆蓋率 80% |
| `critical` | 完整鏈 + security 必跑 + 覆蓋率 100% + PR 前把關鏈 |

## 反模式（避免）

- ❌ `quick` 小修改卻啟動 planner + tdd-guide 全套（過度流程）
- ❌ 有專業 agent 卻全用 general-purpose
- ❌ agent 留下 pending handoff 卻無人接手（看到注入提示要行動）
- ❌ 同時平行啟動會互改同一批檔案的 agent（會衝突；序列化或用 worktree 隔離）
- ❌ 一次委派一長串 agent 卻不在每棒後檢視產出

## 安全平行（worktree 編排）

平行不是反模式，**「會互改同一批檔案」才是**。當多個任務的檔案範圍不重疊時，可安全並行：

- **判斷依據**：每個任務 `plan` 檔的 `files:` frontmatter（見 `plan-persistence.md`）。`files:` 無交集 → 可平行；沒 plan/沒 `files:` → 保守視為不可平行。
- **入口**：`/task-next` 偵測到「依賴已滿足且互不衝突」的任務 ≥ 2 個時，會（**選擇性、不強制**）提供「🔀 平行開發」選項。
- **隔離**：每個任務在獨立 git worktree（`.claude/worktrees/<task-id>`）+ 獨立分支開發，完成 `/verify` 後**依序** `merge --no-ff` 回主分支，再 `git worktree remove` 清理。
- **委派**：以 `Agent` 工具 + `isolation: "worktree"` 並行委派時，務必確保各 agent 檔案範圍不重疊（即上面的 `files:` 無交集）。
- **合併衝突**＝`files:` 估算有漏 → 停下人工解，並補正該 plan 的 `files:`。

> 一句話：**循序是預設、平行是選項**；平行的安全來自「檔案範圍不重疊 + worktree 隔離」。

## 相關

- `.claude/rules/task-mode.md` — 任務強度分級
- `.claude/rules/plan-persistence.md` — plan 的 `files:` 欄（平行判斷依據）
- `.claude/commands/task-next.md` — 平行任務偵測與 worktree 編排入口
- `.claude/coordination/README.md` — 交接檔格式與場景
- `.claude/commands/suggest-mode.md` — 調整建議/注入密度
- `.claude/commands/hub-delegate.md` — 手動委派單一 agent
