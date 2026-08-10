# .claude 配置目錄

> **版本:** v5.2 | **更新:** 2026-04-23

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
├── agents/       (14 個)      # 專業 Agent 定義
├── commands/     (28 個)      # Slash Command
├── rules/        ( 6 個)      # 自動載入規則
├── skills/       (12 個)      # 專案特定領域知識
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

## Agents（14 個）

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
| deployment-expert | sonnet | 部署運維 |
| debug-investigator | sonnet | 執行期 bug 根因調查 |
| build-error-resolver | haiku | 建置/型別錯誤修復 |
| documentation-specialist | haiku | 文檔生成 |
| workflow-template-manager | haiku | 模板管理 |
| ui-builder | sonnet | 前端 UI 產出（嚴格遵循 DESIGN.md） |

## Skills（12 個，按需載入）

僅保留模型不知道的專案特定知識。

| Skill | 用途 |
| :--- | :--- |
| project-docs | 依 VibeCoding 範本產專案文件，支援 demo/mvp/full 三檔深度（由 `/docs-init` 呼叫） |
| deep-research | 多源深度研究（MCP 串接） |
| e2e-testing | Playwright E2E 測試模式 |
| cost-aware-llm-pipeline | LLM API 成本優化 |
| mcp-builder | MCP Server 開發指南 |
| database-migrations | DB Migration 安全模式 |
| postgres-patterns | PostgreSQL 速查表 |

按需從 `custom-rule&skill/skills/` 複製語言特定 skill。

## Rules（6 個，自動載入）

每次對話自動注入 context，無需手動觸發。**只保留「任何任務都適用」的規則**——
領域專屬知識改由 skill 按需載入，可強制的約束交給 hook。

| 規則 | 內容 |
| :--- | :--- |
| coding-style | 克制原則、不可變性、檔案大小、錯誤處理、CWD、Context 管理 |
| task-mode | quick/standard/critical 三檔分級（由 `pre-tool-use.sh` 強制判級） |
| agent-orchestration | 各任務類型的 agent 鏈、handoff 接力、安全平行 |
| security | commit 前安全檢查 |
| git-workflow | Conventional Commits |
| interactive-qa | AskUserQuestion 一次一題 |

### 從 rules 移出的去向

| 原 rule | 現在在哪 |
| :--- | :--- |
| bash-cwd | `pre-tool-use.sh` 硬擋裸 `cd` + coding-style 一句話 |
| testing | `testing-standards` skill |
| plan-persistence | `plan-format` skill |
| ui-design + pencil-design-location | `ui-style-compliance` skill |
| package-manager | `node-package-manager` skill |
| development-workflow | `python-uv` skill + `node-package-manager` skill + task-mode |
| patterns | 併入 coding-style |
| performance | `guides/MODELS.md` + 併入 coding-style |

## Hooks

| 事件 | 腳本 | 用途 |
| :--- | :--- | :--- |
| SessionStart | session-start.sh | 時間歸檔、偵測模板、提示初始化 |
| UserPromptSubmit | user-prompt-submit.sh | 意圖路由：依關鍵字建議任務模式、agent、該載入的 skill |
| PreToolUse (Agent) | agent-monitor.sh | 記錄 subagent 啟動 |
| **PreToolUse (Write/Edit/Bash)** | **pre-tool-use.sh** | **任務模式閘門：未判級不得寫程式碼；模式檔 TTL 過期自動清除；裸 `cd` 攔截** |
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
