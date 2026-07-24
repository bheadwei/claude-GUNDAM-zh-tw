# Q&A 紀錄 — VibeCoding 範本搬遷與 v5.0 升級

**日期：** 2026-07-24
**情境：** 使用者要求更新 VibeCoding_Workflow_Templates、直接做成 skill、整合進 workflow，內容升級至現行業界標準。

## Q1: 根目錄的 VibeCoding_Workflow_Templates/ 搬進 skill 後要怎麼處理？

- 選項：刪除只留 README 指標（推薦）／保留為同步副本／完全刪除不留指標
- **答案：** 刪除，只留 README 指標

## 最終結論

1. 16 份範本 `git mv` 至 `.claude/skills/project-docs/templates/`（skill 自包含，`update-template -ClaudeOnly` 可同步）
2. 根目錄留 README 搬遷指標
3. 全數範本升級 v5.0（2026 業界標準），新增條件式範本 18 資料模型、19 SLO、20 威脅模型、21 AI/LLM
4. 整合點更新：SKILL.md、/docs-init（條件式範本 QA 勾選）、/template-check、01 手冊、INDEX、output-styles 路徑
