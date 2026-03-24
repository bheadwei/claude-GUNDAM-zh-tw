# .claude 配置目錄

> **版本:** v4.3 | **更新:** 2026-03-24

---

## 目錄結構

```
.claude/
├── settings.json              # 專案設定（權限、StatusLine、Model）
├── settings.local.json        # 個人設定（MCP 啟用）-- 不入 Git
├── WORKFLOW.md                # 開發流程指南
├── statusline.sh              # StatusLine bash 腳本（Windows）
├── statusline-linux.sh        # StatusLine bash 腳本（Linux）
├── statusline-go.exe          # StatusLine Go 備用
├── SOP.md                     # 設定 SOP
│
├── agents/       (13 個)      # 專業 Agent 定義
├── commands/     (17 個)      # Slash Command
├── rules/        (7 個)       # 自動載入規則
├── skills/       (8 個)       # 領域知識 Skill
├── output-styles/ (15 個)     # 輸出樣式模板
├── mcp-configs/               # MCP 推薦清單
├── hooks/                     # Hook 腳本庫
├── taskmaster-data/           # 持久化資料（WBS、時間日誌）
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

### Commands（17 個）

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
| /task-next | 下個任務（自動追蹤時間） |
| /task-status | 專案狀態（含時間追蹤） |
| /time-log | 開發時間報表（每日/每任務） |
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

### Hooks（已註冊於 settings.json）

```
hooks/
├── hook-utils.sh          # 共用工具函數庫（非 hook）
├── session-start.sh       # 會話啟動：偵測模板、提示初始化
├── user-prompt-submit.sh  # 用戶輸入：攔截 /task-* 命令
├── pre-tool-use.sh        # 工具前置：TaskMaster 狀態提示
├── post-write.sh          # 寫入後置：文檔審查通知
├── agent-monitor.sh       # Agent 監控：記錄 subagent 活動
└── watch-agents.sh        # 監控工具：即時追蹤 agent log
```

#### Hook 註冊對照表

| 事件 | 腳本 | Matcher | 用途 |
| :--- | :--- | :--- | :--- |
| SessionStart | session-start.sh | 全部 | 偵測 `CLAUDE_TEMPLATE.md`，提示 `/task-init` |
| UserPromptSubmit | user-prompt-submit.sh | 全部 | 攔截 `/task-*` 命令，準備 TaskMaster 環境 |
| PreToolUse | agent-monitor.sh | `Agent` | 記錄 subagent 啟動（類型、prompt、model） |
| PreToolUse | pre-tool-use.sh | `Write\|Edit\|Read` | 提供 TaskMaster 狀態上下文 |
| PostToolUse | agent-monitor.sh | `Agent` | 記錄 subagent 完成結果 |
| PostToolUse | post-write.sh | `Write` | 文檔寫入後觸發駕駛員審查通知 |

#### Agent 活動監控

所有 subagent 的啟動和完成會自動記錄到 `.claude/logs/`：

- `agent-activity.log` — 人類可讀格式（prompt、結果、時間戳）
- `agent-activity.jsonl` — 結構化 JSON（適合程式分析）

即時監控（開另一個終端機）：

```bash
bash .claude/hooks/watch-agents.sh           # 即時追蹤
bash .claude/hooks/watch-agents.sh --json    # JSON 格式
bash .claude/hooks/watch-agents.sh --last 30 # 最近 30 行
bash .claude/hooks/watch-agents.sh --summary # 統計摘要
bash .claude/hooks/watch-agents.sh --clear   # 清除 log
```

#### 複製到其他專案

```bash
# 1. 複製 hooks 腳本
mkdir -p .claude/hooks .claude/logs
cp <模板路徑>/.claude/hooks/*.sh .claude/hooks/
cp <模板路徑>/.claude/logs/.gitignore .claude/logs/

# 2. 在目標專案 .claude/settings.json 加入 hooks 區段（見本專案 settings.json）
```

#### 自訂 Hook

所有 hook 透過 **stdin** 接收 JSON 資料，使用 `jq` 解析：

```bash
#!/bin/bash
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
# 處理邏輯...
exit 0  # 0=放行, 2=阻擋
```

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
