# .claude 配置目錄

> **版本:** v4.1 | **更新:** 2026-03-16

---

## 目錄結構

```
.claude/
├── settings.json              # 專案設定（權限、StatusLine、Model）
├── settings.local.json        # 個人設定（MCP 啟用）-- 不入 Git
├── WORKFLOW.md                # 開發流程指南
├── statusline.sh              # StatusLine bash 腳本
├── statusline-go.exe          # StatusLine Go 備用
├── SOP.md                     # 設定 SOP
│
├── agents/       (13 個)      # 專業 Agent 定義
├── commands/     (16 個)      # Slash Command
├── rules/        (7 個)       # 自動載入規則
├── skills/       (8 個)       # 領域知識 Skill
├── output-styles/ (15 個)     # 輸出樣式模板
├── mcp-configs/               # MCP 推薦清單
├── hooks/                     # Hook 腳本庫
├── context/                   # 跨 Agent 上下文共享
├── coordination/              # Agent 協調配置
└── plugins/                   # Plugin 配置
```

---

## 各元件說明

### Agents（13 個）

自動註冊，可透過 Agent tool 或 `/hub-delegate` 呼叫。

| Agent | Model | 用途 |
| :--- | :--- | :--- |
| general-purpose | sonnet | 通用問題解決 |
| planner | opus | 功能規劃 |
| architect | opus | 架構設計 |
| code-quality-specialist | sonnet | 程式碼審查 |
| security-infrastructure-auditor | sonnet | 安全稽核 |
| test-automation-engineer | sonnet | 測試自動化 |
| tdd-guide | sonnet | TDD 引導 |
| e2e-validation-specialist | sonnet | E2E 測試 |
| build-error-resolver | sonnet | 建置修復 |
| refactor-cleaner | sonnet | 死碼清理 |
| documentation-specialist | sonnet | 文檔生成 |
| deployment-expert | sonnet | 部署運維 |
| workflow-template-manager | sonnet | 模板管理 |

### Commands（16 個）

在 Claude Code 中輸入 `/` 即可使用。

| 指令 | 用途 |
| :--- | :--- |
| /plan | 規劃實作步驟 |
| /tdd | 測試驅動開發 |
| /build-fix | 修復建置錯誤 |
| /e2e | E2E 測試 |
| /verify | 全面驗證 |
| /refactor-clean | 死碼清理 |
| /review-code | 程式碼審查 |
| /check-quality | 品質評估 |
| /learn | 擷取模式 |
| /save-session | 儲存 session |
| /task-init | 專案初始化 |
| /task-next | 下個任務 |
| /task-status | 專案狀態 |
| /hub-delegate | Agent 委派 |
| /suggest-mode | 建議密度 |
| /template-check | 模板合規 |

### Rules（7 個，自動載入）

放在 `rules/` 下，**每次對話自動注入 context**，無需手動觸發。

| 規則 | 內容 |
| :--- | :--- |
| coding-style | 不可變性、檔案大小、錯誤處理 |
| development-workflow | 研究先行 → Plan → TDD → Review |
| git-workflow | Conventional Commits |
| security | commit 前安全檢查 |
| testing | 80%+ 覆蓋率、TDD |
| performance | 模型選擇、Context 管理 |
| patterns | Repository Pattern、API 格式 |

### Skills（8 個精選）

放在 `skills/` 下，按需載入。更多可從 `everything-claude/skills/` 複製。

| Skill | 搭配 |
| :--- | :--- |
| tdd-workflow | /tdd |
| api-design | API 模板 |
| security-review | 安全 Agent |
| e2e-testing | /e2e |
| coding-standards | 所有開發 |
| deep-research | 複雜問題 |
| deployment-patterns | 部署規劃 |
| docker-patterns | 容器化 |

### Output Styles（15 個）

使用 `/output-style <name>` 切換，詳見 `output-styles/README.md`。

### Hooks

`hooks/` 下有腳本庫，目前 `settings.json` 未啟用任何 hook。
如需啟用，在 `settings.json` 的 `hooks` 區段配置。

---

## 自訂指南

### 新增 Agent

在 `agents/` 新增 `.md` 檔案：

```yaml
---
name: my-agent
description: 繁體中文描述
tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
model: sonnet
---

Agent 的指示內容...
```

### 新增 Command

在 `commands/` 新增 `.md` 檔案：

```yaml
---
description: 繁體中文描述
---

# 指令標題

指令的執行邏輯...
```

### 新增 Rule

在 `rules/` 新增 `.md` 檔案（自動載入，無需 frontmatter）。

### 新增語言特定規則

```bash
cp everything-claude/everything-claude-code/rules/typescript/*.md .claude/rules/
```

### 新增 Skill

```bash
cp -r everything-claude/everything-claude-code/skills/python-patterns .claude/skills/
```
