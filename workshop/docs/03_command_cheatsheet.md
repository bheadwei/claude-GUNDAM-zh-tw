# VibeCoding 模板 — 指令速查卡

> 隨堂參考用，23 個 slash command + 14 個 Agent 一覽

---

## 🆕 任務分級系統（v5.3）

`/task-next` 選任務後會問「任務模式」，後續指令依模式自動分流：

| 模式 | 適用 | 流程 | 覆蓋率 |
| :--- | :--- | :--- | :--- |
| **quick** | < 30min 單檔（文案/樣式/小 bug） | 直接寫 → `/verify` | 不檢查 |
| **standard** | 1-4h 新功能/重構 | `/plan` → `/tdd` → `/verify` | 80% |
| **critical** | 金流/認證/安全/核心邏輯 | `/plan` → `/tdd` → `/review-code` → `/verify` | 100% |

`/verify` 會依模式自動選 profile（quick / full / pre-pr），不必手動帶參數。

---

## Slash Commands

### 專案管理

| 指令 | 說明 | 何時用 |
| :--- | :--- | :--- |
| `/task-init` | 專案初始化，選情境（demo/mvp/full）→ 產文件 → CLAUDE.md + WBS | 新專案第一步 |
| `/docs-init` | 規格文件產出（`--demo` / `--mvp` / `--full`，可升級） | `/task-init` 自動呼叫，或補文件 |
| `/task-next` | 從 WBS 取下個任務 + **選任務模式**（自動追蹤時間） | 每個任務開始前 |
| `/task-status` | 查看 WBS 任務狀態總覽 | 想了解整體進度 |
| `/time-log` | 開發時間報表（按日期/任務） | 回顧開發時間 |

### 環境設定

| 指令 | 說明 | 何時用 |
| :--- | :--- | :--- |
| `/ui-style` | 選擇 / 切換 UI 設計風格 | 前端專案開始前或想換風格 |
| `/ui-site` | 網站雛形產生器（IA 文檔 + 多頁骨架 + tokens） | 從零開新網站 |
| `/ui-page` | 單頁深化（讀 IA + Q&A → 完整頁面） | 已有網站要做新頁 |
| `/pm-choose` | 選 Node.js 套件管理器（bun/pnpm/npm） | 新前端專案或首次跑 Node 指令 |
| `/pm-switch` | 切換已設定的 PM，附遷移指引 | 想改用不同 PM |

### 開發流程

| 指令 | 說明 | 何時用 |
| :--- | :--- | :--- |
| `/plan` | 建立實作計畫（觸發 planner agent） | standard / critical 任務開始前 |
| `/tdd` | 測試驅動開發；依模式自動切換 Fast / Standard / Strict Lane | 寫程式碼時 |
| `/build-fix` | 自動修復建置/型別錯誤 | 編譯失敗時 |

### 品質把關

| 指令 | 說明 | 何時用 |
| :--- | :--- | :--- |
| `/review-code` | 程式碼審查（觸發 code-quality-specialist） | 寫完一段程式碼後 / critical 任務必跑 |
| `/e2e` | Playwright 端到端測試 | 前端功能完成後 |
| `/verify` | 全面驗證（依任務模式自動選 profile） | 任務結束前 |
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

## 14 個 Agent

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
| **tdd-guide** | 強制 TDD 流程、依任務模式調整覆蓋率門檻 |
| **e2e-validation-specialist** | Playwright E2E 測試、跨瀏覽器驗證 |
| **refactor-cleaner** | 死碼識別與安全移除 |
| **deployment-expert** | 部署策略、CI/CD、監控 |
| **ui-builder** | 前端 UI 產出（嚴格遵循 DESIGN.md） |
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

## 典型開發循環（依任務模式）

### Quick Lane（快車道）

```
/task-next              ← 選 quick 模式
    ↓
直接寫程式碼
    ↓
/verify                 ← 自動跑 quick profile（build + types）
    ↓
✅ 完成 → /task-next 接力下一個
```

### Standard Lane（一般）

```
/task-next              ← 選 standard 模式（預設）
    ↓
/plan                   ← 規劃（planner agent）
    ↓
/tdd                    ← RED → GREEN → REFACTOR（80% 覆蓋）
    ↓
/build-fix              ← 如果建置失敗
    ↓
/review-code            ← 審查
    ↓
/verify                 ← 自動跑 full profile
    ↓
git commit              ← 提交（conventional commits）
    ↓
✅ 完成 → /task-next 接力
```

### Strict Lane（金流/認證/安全）

```
/task-next              ← 選 critical 模式
    ↓
/plan
    ↓
/tdd                    ← 100% 覆蓋強制
    ↓
/review-code            ← 階段完成必跑
    ↓
/verify                 ← 自動跑 pre-pr profile（含安全掃描）
    ↓
git commit
```

---

## 全部任務完成後

```
/check-quality          ← 全專案品質掃描
/e2e                    ← 端到端測試
/time-log               ← 時間報表
/save-session           ← 保存進度
```
