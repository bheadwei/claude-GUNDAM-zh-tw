# VibeCoding 模板 — 指令速查卡

> 隨堂參考用，17 個 slash command + 13 個 Agent 一覽

---

## Slash Commands

### 專案管理

| 指令 | 說明 | 何時用 |
| :--- | :--- | :--- |
| `/task-init` | 專案初始化，互動式 Q&A → 產出 CLAUDE.md + WBS | 新專案第一步 |
| `/task-next` | 從 WBS 取得下一個任務（自動追蹤時間） | 每個任務開始前 |
| `/task-status` | 查看 WBS 任務狀態總覽 | 想了解整體進度 |
| `/time-log` | 開發時間報表（按日期/任務） | 回顧開發時間 |

### 開發流程

| 指令 | 說明 | 何時用 |
| :--- | :--- | :--- |
| `/plan` | 建立實作計畫（觸發 planner agent） | 開始一個功能前 |
| `/tdd` | 測試驅動開發：RED → GREEN → IMPROVE | 寫程式碼時 |
| `/build-fix` | 自動修復建置/型別錯誤 | 編譯失敗時 |

### 品質把關

| 指令 | 說明 | 何時用 |
| :--- | :--- | :--- |
| `/review-code` | 程式碼審查（觸發 code-quality-specialist） | 寫完一段程式碼後 |
| `/e2e` | Playwright 端到端測試 | 前端功能完成後 |
| `/verify` | 全面驗證（型別 + 測試 + lint） | 準備提交前 |
| `/check-quality` | 品質評估 + Agent 路由推薦 | 想全面檢視品質 |

### 輔助工具

| 指令 | 說明 | 何時用 |
| :--- | :--- | :--- |
| `/hub-delegate` | 手動指定 Agent 執行任務 | 需要特定 Agent |
| `/refactor-clean` | 安全移除死碼 | 重構時 |
| `/suggest-mode` | 調整 AI 建議頻率 | 想要更多/少建議 |
| `/learn` | 萃取可複用模式 | 發現好模式時 |
| `/save-session` | 保存會話狀態快照 | 結束工作前 |
| `/template-check` | 驗證是否符合模板規範 | 品質稽核時 |

---

## 13 個 Agent

### Opus（重量級推理）

| Agent | 職責 |
| :--- | :--- |
| **planner** | 功能規劃、依賴分析、實作步驟拆解 |
| **architect** | 系統架構設計、技術選型決策 |
| **security-infrastructure-auditor** | OWASP 漏洞掃描、合規檢查 |

### Sonnet（一般開發）

| Agent | 職責 |
| :--- | :--- |
| **code-quality-specialist** | 程式碼審查、可維護性評估、技術債管理 |
| **test-automation-engineer** | 測試覆蓋率補強、測試基礎設施維護 |
| **tdd-guide** | 強制 TDD 流程、確保 80%+ 覆蓋率 |
| **e2e-validation-specialist** | Playwright E2E 測試、跨瀏覽器驗證 |
| **refactor-cleaner** | 死碼識別與安全移除 |
| **deployment-expert** | 部署策略、CI/CD、監控 |
| **general-purpose** | 通用任務處理 |

### Haiku（輕量快速）

| Agent | 職責 |
| :--- | :--- |
| **build-error-resolver** | 建置錯誤快速修復（最小差異） |
| **documentation-specialist** | API 文檔、Codemap 生成 |
| **workflow-template-manager** | VibeCoding 模板管理 |

---

## 5 大擴展機制

| 機制 | 觸發方式 | 用途 | 位置 |
| :--- | :--- | :--- | :--- |
| **Hook** | 系統事件自動觸發 | Shell 副作用 + 上下文注入 | `.claude/hooks/` |
| **Command** | 使用者輸入 `/xxx` | 預設 prompt 模板 | `.claude/commands/` |
| **Skill** | AI 語意偵測自動觸發 | 領域知識 + 方法論 | `.claude/skills/` |
| **Agent** | 主 Agent 委派子任務 | 隔離執行 + 專用工具 | `.claude/agents/` |
| **Context** | Agent 執行前後 | 跨 Agent 知識共享 | `.claude/context/` |

---

## 典型開發循環

```
/task-next          ← 取任務
    ↓
/plan               ← 規劃（planner agent）
    ↓
/tdd                ← 寫測試 → 寫實作（tdd-guide agent）
    ↓
/build-fix          ← 如果建置失敗（build-error-resolver agent）
    ↓
/review-code        ← 審查（code-quality-specialist agent）
    ↓
git commit          ← 提交（conventional commits）
    ↓
重複 ↑ 直到所有任務完成
    ↓
/verify             ← 全面驗證
/e2e                ← 端到端測試
/time-log           ← 時間報表
```
