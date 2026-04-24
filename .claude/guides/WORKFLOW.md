# 開發工作流指南

## 完整流程

```
/task-init → 文件產出 → WBS → 任務循環 → 結束保存
```

### Phase 0: 初始化 + 文件先行

```bash
/task-init          # 選情境（demo/mvp/full） → 自動觸發 /docs-init → 建立 WBS
```

**三種情境**：

| 情境 | 適用 | 產出文件 | 題數 |
|---|---|---|---|
| **demo** | 快速驗證、< 1 天 | `docs/prd.md`（精簡 PRD） | 少 |
| **mvp** | 內部工具、< 1 週 | `docs/tech-spec.md`（合併 Tech Spec） | 中 |
| **full** | 正式產品、跨團隊 | `docs/01_prd.md`、`02_bdd.md`…（VibeCoding 完整集） | 多 |

**核心原則**：文件先行，WBS 從文件反推，避免「越做越發散」。

**獨立使用**：
```bash
/docs-init              # 互動選模式
/docs-init --demo       # 直接 demo
/docs-init --mvp        # MVP 模式（可從 demo 升級）
/docs-init --full       # 完整模式（可從 mvp 升級）
/docs-init --full --resume   # 接續中斷的完整流程
```

### Phase 1: 任務循環

```
/task-next  →  /plan  →  /tdd  →  /build-fix（如需）  →  /review-code  →  /verify  →  /task-status
```

### Phase 2: 收尾
```bash
/time-log           # 查看開發時間
/verify pre-pr      # PR 前完整檢查
/save-session       # 儲存 session 狀態
```

## 快速模式（小功能/Bug）

```
/plan [描述]  →  /tdd  →  /verify quick
```

## 指令速查

### 核心工作流

| 指令 | 用途 |
| :--- | :--- |
| `/task-init` | 專案初始化（選情境 → 產文件 → 生 WBS） |
| `/docs-init` | 文件產出（`--demo` / `--mvp` / `--full`） |
| `/task-next` | 取下一個任務（自動追蹤時間） |
| `/task-status` | 查看專案進度 |
| `/time-log` | 開發時間報表 |
| `/plan [wbs-id]` | 規劃實作步驟 → 寫入 `plans/<id>-<slug>.md`（持久化）|
| `/tdd` | 測試驅動開發，自動載入當前任務 plan 並按階段推進 |
| `/build-fix` | 修復建置錯誤 |
| `/review-code` | 程式碼審查 |
| `/e2e` | E2E 測試 |
| `/verify` | 全面驗證（`quick`/`full`/`pre-pr`） |

### 環境設定

| 指令 | 用途 |
| :--- | :--- |
| `/ui-style` | 選擇/切換 UI 設計風格 |
| `/pm-choose` | 選 Node.js 套件管理器（bun/pnpm/npm） |
| `/pm-switch` | 切換已設定的 PM（附遷移指引） |

### 輔助指令

| 指令 | 用途 |
| :--- | :--- |
| `/hub-delegate` | 委派 agent |
| `/check-quality` | 品質評估 |
| `/refactor-clean` | 死碼清理 |
| `/suggest-mode` | 調整建議密度 |
| `/learn` | 擷取可重用模式 |
| `/save-session` | 儲存 session |
