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

遵循 `.claude/WORKFLOW.md` 的標準流程：
/task-next → /plan → /tdd → /verify

## 機制概覽

- Agent / Skill / Command / Hook / Context 五套擴充機制
- 詳見 `.claude/MECHANISMS.md`
- Context 系統使用見 `.claude/CONTEXT_USAGE.md`

## 專案結構

[依選擇的類型填入，可參考 .claude/templates/project-structures.md]

## 技術棧

[依收集的資訊填入]
```

---

## 注意事項

- **不要重複** `.claude/rules/` 已包含的規則（不可變性、80% 覆蓋率、commit 規則等）
  rules 會自動載入，CLAUDE.md 不需要再列一次
- CLAUDE.md 應該專注於**該專案獨有**的資訊：技術棧、資料模型、外部 API、領域術語
- 通用最佳實踐應留在 rules，不要放 CLAUDE.md
