# 模型選擇參考

> 這份是**參考資料**，不是常駐規則。Agent frontmatter 一律用別名
> （`haiku` / `sonnet` / `opus` / `fable`），會自動解析到當下最新版本，
> 模型改版時無需逐檔更新——只需更新本表的說明。

## 對照表

| 別名 | 當前對應 | 適用場景 |
| :--- | :--- | :--- |
| `haiku` | Haiku 4.5 | 輕量 agent、高頻呼叫、機械性任務（建置修復、文檔生成、模板管理） |
| `sonnet` | Sonnet 5 | 主要開發、多 agent 編排、複雜編碼 |
| `opus` | Opus 5 | 架構決策、深度推理、安全稽核、規劃 |
| `fable` | Fable 5 | 最高難度推理與長程自主任務 |

## 本模板的 agent 分佈

| 模型 | Agents |
|---|---|
| `sonnet`（5） | code-quality-specialist、documentation-specialist、e2e-validation-specialist、refactor-cleaner、workflow-template-manager |
| `opus`（11） | planner、architect、security-infrastructure-auditor、debug-investigator、tdd-guide、skill-curator、build-error-resolver、deployment-expert、test-automation-engineer、ui-builder、conflict-resolver |

`opus` 的判準是**錯了要人回頭抓、而且抓不到就會一路錯下去**：
規劃階段拆錯（planner）、架構決策寫錯（architect）、漏報安全問題
（security-infrastructure-auditor）、根因判斷錯（debug-investigator）、
測試設計不到位（tdd-guide）、擴充接線寫錯（skill-curator）。

**2026-09-08 起，凡是會動到專案程式碼的 agent 一律 `opus`**（使用者決定）——
`build-error-resolver`、`deployment-expert`、`test-automation-engineer`、`ui-builder`
從 `sonnet` 升上來。理由是同一條：型別錯誤被 `any` 蓋掉、CI 設定寫得能跑但不對、
測試斷言太鬆、前端硬編色票——這些都是「看起來對但其實錯」，要人回頭抓。

留在 `sonnet` 的五個，共同點是**產出有外部約束在把關**：
`code-quality-specialist` 與 `e2e-validation-specialist` 的結論會被下一棒驗證、
`refactor-cleaner` 每批移除都跑測試（且跑在自己的 worktree 裡）、
`documentation-specialist` 與 `workflow-template-manager` 產文件不動程式碼。

**沒有任何 agent 預設用 `haiku`**（2026-09-07 起）。原本的三個（build-error-resolver、
documentation-specialist、workflow-template-manager）先改為 `sonnet`，其中
`build-error-resolver` 又於 2026-09-08 升到 `opus`。理由一直是同一條：它們的失敗模式
不是「慢」而是「看起來對但其實錯」——型別錯誤被用 `any` 蓋掉、API 文檔寫出不存在的參數。
這類錯誤要人回頭抓，比省下的推理成本貴。

`haiku` 仍在 dispatch 層使用：`subagent-execution` skill 派 implementer subagent 時，
規格明確的機械任務指定 `model: "haiku"`。那是「有 plan 當規格」的情境，與 agent 預設不同。

`fable` 目前沒有任何 agent 或流程使用，保留在對照表供需要時 dispatch 層覆寫。

## 派工時覆寫模型

`Agent` 工具的 `model` 參數會覆寫 agent frontmatter 的預設值。用它做「同一個 agent、
不同強度」的分流——frontmatter 是靜態的，讀不到當前任務模式。

| 情境 | 建議覆寫 |
|---|---|
| `critical` 模式派 `code-quality-specialist` | `model: "opus"` |
| `standard` 模式派 `tdd-guide` 且階段極機械（純樣板、單檔） | `model: "sonnet"` 降級省成本 |
| 修復迴圈第 4-5 輪 | 至少比前一輪高一級（見 `subagent-execution` skill） |

> `tdd-guide` 的預設已是 `opus`（2026-09-07）。它是標準迴圈裡頻率最高的寫手——
> 每個任務的每個階段都會叫它一次——所以這是本模板成本結構最重的一個選擇。
> 若某個 `standard` 任務的階段確實只是機械填空，派工時降級成 `sonnet` 是合理的。

主 session 模型由 `.claude/settings.json` 的 `model` 欄位決定（目前 `opus`），
或由使用者以 `/model` 切換。

## 建置疑難排解

建置失敗時委派 `build-error-resolver` agent（見 `rules/agent-orchestration.md` 的標準鏈），
分析錯誤 → 增量修復 → 每次修復後驗證。
