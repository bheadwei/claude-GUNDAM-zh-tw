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
| `haiku`（3） | build-error-resolver、documentation-specialist、workflow-template-manager |
| `sonnet`（7） | code-quality-specialist、tdd-guide、test-automation-engineer、e2e-validation-specialist、refactor-cleaner、deployment-expert、ui-builder |
| `opus`（3） | planner、architect、security-infrastructure-auditor |

主 session 模型由 `.claude/settings.json` 的 `model` 欄位決定（目前 `opus`），
或由使用者以 `/model` 切換。

## 建置疑難排解

建置失敗時委派 `build-error-resolver` agent（見 `rules/agent-orchestration.md` 的標準鏈），
分析錯誤 → 增量修復 → 每次修復後驗證。
