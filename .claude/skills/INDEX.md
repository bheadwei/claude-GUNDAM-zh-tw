# Skills 索引

已安裝 7 個精選 skill（僅保留模型不知道的專案特定知識）。

## 已安裝

| Skill | 用途 | 啟動時機 |
| :--- | :--- | :--- |
| **project-docs** | 依據 VibeCoding 範本撰寫專案文件 | 撰寫 PRD、架構、API 規格等文件 |
| **deep-research** | 多源深度研究（MCP 串接） | 複雜問題調查 |
| **e2e-testing** | Playwright E2E 測試模式 | 測試關鍵使用者流程 |
| **cost-aware-llm-pipeline** | LLM API 成本優化（模型路由 + 預算追蹤） | 開發 AI 應用 |
| **mcp-builder** | MCP Server 開發指南（FastMCP / MCP SDK） | 串接外部 API 或服務 |
| **database-migrations** | DB Migration 安全模式（zero-downtime DDL） | Schema 變更、資料遷移 |
| **postgres-patterns** | PostgreSQL 速查表（Index、型態、RLS） | 寫 SQL、設計 Schema |

## 不需要 Skill 的場景

以下知識模型已內建，不需額外 skill：
- Python 語法、PEP 8、pytest → 模型內建知識
- React/Vue/Angular 前端模式 → 用 **context7 MCP** 查最新文檔
- REST API / GraphQL 後端模式 → 用 `rules/patterns.md` 的專案約定
- TDD / Security / Docker → 用 `rules/` 的精簡規則
- Claude API / SDK → 已是 **Claude Code 內建 skill**

## 擴充方式

語言/框架特定的 skill 可從備份池按需複製：

```bash
cp -r .claude/custom-rule&skill/skills/[skill-name] .claude/skills/
```
