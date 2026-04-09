---
description: 對整個專案做品質評估與 agent 路由推薦（不直接執行審查，先分流再決定要叫哪個 agent）。範圍：整個專案。
---

# 品質評估

## 分析內容

針對當前專案或指定路徑執行品質檢查：

1. **程式碼品質** -- 可讀性、複雜度、重複、命名
2. **架構合規** -- 分層結構、依賴方向、模組化
3. **測試覆蓋** -- 單元/整合/E2E 覆蓋率
4. **安全檢查** -- 硬編碼秘密、輸入驗證、注入風險
5. **模板合規** -- 對照 VibeCoding 模板檢查點

## 輸出格式

先顯示評估結果：

```
品質評估結果:
  程式碼品質:  [A/B/C/D]
  架構合規:    [通過/需改善]
  測試覆蓋:    [X]%
  安全檢查:    [通過/有風險]
  模板合規:    [X]%
```

然後**必須使用 `AskUserQuestion`** 詢問後續動作（遵守 `.claude/rules/interactive-qa.md`）：

- 「code-quality-specialist — 深度程式碼審查」
- 「security-infrastructure-auditor — 安全稽核」
- 「test-automation-engineer — 測試補強」
- 「deployment-expert — 部署就緒檢查」

（依評估結果決定推薦順序，問題可設 `multiSelect: true` 允許同時選多個 Agent）

## 問答記錄

遵守 `.claude/rules/interactive-qa.md`：

- 流程結束後**一次性** `Write` 到 `.claude/qa-history/YYYY-MM-DD-HHMMSS-check-quality.md`
- 記錄：評估結果、使用者選擇、後續執行的 Agent
- 不要每題都寫（省 token）

## 使用方式

```
/check-quality              # 檢查整個專案
/check-quality src/api/     # 檢查特定目錄
```
