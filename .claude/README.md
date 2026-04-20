# .claude 配置目錄

> **版本:** v5.1 | **更新:** 2026-04-20

## 目錄結構

```
.claude/
├── settings.json              # 專案設定（權限、StatusLine、Model）
├── settings.local.json        # 個人設定（MCP 啟用）-- 不入 Git
├── statusline.sh              # StatusLine bash 腳本
│
├── guides/                    # 參考文件（不自動載入）
│   ├── WORKFLOW.md            # 開發流程指南
│   ├── MECHANISMS.md          # 五套擴充機制權威對照
│   ├── MCP_CONFIGS.md         # MCP Server 推薦清單
│   ├── PAUSE_RESUME_GUIDE.md  # 暫停/恢復 SOP
│   └── STATUSLINE_GUIDE.md    # StatusLine 客製化手冊
├── agents/       (13 個)      # 專業 Agent 定義
├── commands/     (17 個)      # Slash Command
├── rules/        (11 個)      # 自動載入規則
├── skills/       (7 個)       # 專案特定領域知識
├── output-styles/ (15 個)     # 輸出樣式模板
├── hooks/                     # Hook 腳本庫
├── context/                   # 跨 Agent 上下文共享
├── coordination/              # Agent 協調配置
└── taskmaster-data/           # WBS、時間日誌、plans/（計畫持久化）
    ├── wbs.md                 # WBS 任務清單（What）
    ├── plans/                 # 計畫檔（How，/plan 寫入）
    │   ├── INDEX.md
    │   └── archive/           # /verify 完成後歸檔
    └── .current-task          # 當前進行中任務 ID
```

## Agents（13 個）

| Agent | Model | 用途 |
| :--- | :--- | :--- |
| planner | opus | 功能規劃 |
| architect | opus | 架構設計 |
| security-infrastructure-auditor | opus | 安全稽核 |
| code-quality-specialist | sonnet | 程式碼審查 |
| test-automation-engineer | sonnet | 測試自動化 |
| tdd-guide | sonnet | TDD 引導 |
| e2e-validation-specialist | sonnet | E2E 測試 |
| refactor-cleaner | sonnet | 死碼清理 |
| general-purpose | sonnet | 通用問題解決 |
| deployment-expert | sonnet | 部署運維 |
| build-error-resolver | haiku | 建置修復 |
| documentation-specialist | haiku | 文檔生成 |
| workflow-template-manager | haiku | 模板管理 |

## Skills（7 個精選）

僅保留模型不知道的專案特定知識。

| Skill | 用途 |
| :--- | :--- |
| project-docs | 依據 VibeCoding 範本撰寫專案文件 |
| deep-research | 多源深度研究（MCP 串接） |
| e2e-testing | Playwright E2E 測試模式 |
| cost-aware-llm-pipeline | LLM API 成本優化 |
| mcp-builder | MCP Server 開發指南 |
| database-migrations | DB Migration 安全模式 |
| postgres-patterns | PostgreSQL 速查表 |

按需從 `custom-rule&skill/skills/` 複製語言特定 skill。

## Rules（11 個，自動載入）

每次對話自動注入 context，無需手動觸發。

| 規則 | 內容 |
| :--- | :--- |
| bash-cwd | Bash CWD 汙染防護 |
| coding-style | 不可變性、檔案大小、錯誤處理 |
| development-workflow | 研究先行 → Plan → TDD → Review，Python 強制 uv |
| git-workflow | Conventional Commits |
| interactive-qa | AskUserQuestion 一次一題 |
| security | commit 前安全檢查 |
| testing | 80%+ 覆蓋率、TDD |
| performance | 模型選擇、Context 管理 |
| patterns | Repository Pattern、API 格式 |
| plan-persistence | `/plan` 持久化、WBS/Plan 職責分工 |
| ui-design | Apple 風格簡約設計、毛玻璃效果 |

## Hooks

| 事件 | 腳本 | 用途 |
| :--- | :--- | :--- |
| SessionStart | session-start.sh | 時間歸檔、偵測模板、提示初始化 |
| UserPromptSubmit | user-prompt-submit.sh | 偵測 /task-* 命令 |
| PreToolUse (Agent) | agent-monitor.sh | 記錄 subagent 啟動 |
| PreToolUse (Write/Edit/Read) | pre-tool-use.sh | 輕量 log |
| PostToolUse (Agent) | agent-monitor.sh + post-agent-report.sh | 記錄完成 + 驗證報告 |
| PostToolUse (Write) | post-write.sh | WBS 更新 log |

## Context 系統（跨 Agent 共享）

4 個 agent 自動讀寫 `.claude/context/<area>/`，透過 handoffs 交接工作。

```bash
# 查看最新報告
ls -t .claude/context/quality/*.md | head -5

# 查看待處理交接
grep -l "status: pending" .claude/coordination/handoffs/*.md

# 清理舊報告
bash .claude/scripts/context-gc.sh
```

詳見 `guides/MECHANISMS.md`。

## 自訂指南

### 新增 Agent
在 `agents/` 新增 `.md`，含 frontmatter（name、description、tools、model）。

### 新增 Command
在 `commands/` 新增 `.md`，含 frontmatter（description）。

### 新增 Rule
在 `rules/` 新增 `.md`（自動載入，無需 frontmatter）。

### 新增 Skill
```bash
cp -r .claude/custom-rule&skill/skills/[skill-name] .claude/skills/
```
