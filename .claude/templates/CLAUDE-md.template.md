# CLAUDE.md 生成模板

> 此檔案是 `/task-init` 執行時用來生成專案 CLAUDE.md 的範本。
> **不會被自動載入到 session context**，僅在初始化時被讀取。

---

## 生成的 CLAUDE.md 應包含

```markdown
# CLAUDE.md - [PROJECT_NAME]

> **專案:** [PROJECT_NAME]
> **描述:** [PROJECT_DESCRIPTION]
> **語言:** [LANGUAGE]
> **建立:** [DATE]

## 開發流程

遵循 `.claude/guides/WORKFLOW.md` 的標準流程：
/task-next → /plan → /tdd → /verify

## 機制概覽

- Agent / Skill / Command / Hook / Context 五套擴充機制
- 詳見 `.claude/guides/MECHANISMS.md`
- Context 系統見 `.claude/guides/MECHANISMS.md`

## 程式碼看不出來的事

[外部約束、環境前提、踩過的雷、刻意不做的事。看程式碼就知道的（目錄結構、用了哪些套件）不要寫；沒有就刪掉這節]

## 文件在哪

- brief：`docs/00_brief.md`
- PRD：`docs/prd.md`
- 架構文件：`docs/architecture.md`
- WBS：`.claude/taskmaster-data/wbs.md`
- plan：`.claude/taskmaster-data/plans/`
- ADR：`docs/decisions/`
- 專案地圖：`/task-status`
```

---

## 注意事項

- **不要重複** `.claude/rules/` 已包含的規則（不可變性、任務分級、commit 規則等）
  或 `.claude/skills/` 的按需知識（測試門檻、UI 風格、套件管理、plan 格式）
  rules 會自動載入，CLAUDE.md 不需要再列一次
- CLAUDE.md 只放**程式碼看不出來**的事。專案結構、模組清單會過期，看專案地圖；
  技術選型在架構文件第 2 節、用語在 PRD 用語表，不要再抄一份
- 「文件在哪」只寫路徑，**不寫份數、模組數這類數字**——數字會過期，路徑不會
- 只列實際存在的文件：demo 沒有 PRD 與架構文件就刪掉那兩行；有威脅模型或 runbook 時補上路徑
- 通用最佳實踐應留在 rules，不要放 CLAUDE.md
