# 開發工作流指南

## 系統由五層組成

| 層 | 數量 | 何時生效 | 可否略過 |
|---|---|---|---|
| **Hooks** | 6 | 事件觸發，機器執行 | 只有明確逃生門 |
| **Rules** | 6 | 每個 session 全量載入 | 否（但靠模型遵守） |
| **Skills** | 12 | 情境觸發，按需載入 | 是（需被想起來） |
| **Commands** | 25 | 使用者主動叫 | — |
| **Agents** | 14 | 委派時啟動 | — |

**設計原則**：能交給機器的交給 hook；任何任務都適用的才常駐 rule；
領域專屬知識放 skill 按需載入。

---

## Phase 0：一次性初始化

```bash
/task-init          # 選情境 → 自動觸發 /docs-init → 從文件反推 WBS
```

| 情境 | 適用 | 產出文件 |
|---|---|---|
| **demo** | 快速驗證、< 1 天 | `docs/prd.md`（精簡 PRD） |
| **mvp** | 內部工具、< 1 週 | `docs/tech-spec.md`（合併 Tech Spec） |
| **full** | 正式產品、跨團隊 | `docs/01_prd.md`、`02_bdd.md`…（VibeCoding 完整集） |

**核心原則**：文件先行，WBS 從文件反推，避免「越做越發散」。

初始化過程會條件式分流：偵測到前端 → `/ui-style`；偵測到 Node → `/pm-choose`。

獨立使用：`/docs-init [--demo|--mvp|--full] [--resume]`

---

## Phase 1：任務循環

### 有 WBS 的正規路徑

```
/task-next
   │  取任務、問任務模式 → 寫入 .current-task + .current-task-mode
   ▼
┌──────────── 依模式分流 ────────────┐
│ quick     直接寫 → /verify quick    │  跳過 plan 與 TDD
│ standard  /plan → /tdd → /verify    │  覆蓋率 80%
│ critical  /plan（必要）→ /tdd        │  覆蓋率 100%
│           → /code-review            │
│           → /verify pre-pr          │
└─────────────────────────────────────┘
   ▼
/verify 通過 → WBS 標 ✅ → plan 歸檔 → 問要不要接下一個任務
```

### Ad-hoc 路徑（沒跑 /task-next，直接叫我改東西）

這條路以前是斷的——沒人判級、也不會產計畫。現在由 hook 保證：

```
你：「幫我改掉 X」
   ▼
我開始寫程式碼檔
   ▼
PreToolUse 閘門攔截（.current-task-mode 不存在）
   ▼
我判級 + 用一句話宣告理由 + 寫入模式檔
   ▼
你可以當場一句話否決（「這要 standard」）
   ▼
依該模式繼續
```

**閘門只攔程式碼檔**（`.ts/.py/.go/.sh/.sql/…`）。
`.md`、`.json`、`docs/`、`.claude/**`、依賴與建置產物一律放行。
純問答、檢視、研究不觸發。

---

## Phase 2：收尾

```bash
/verify pre-pr      # 完整檢查 + 安全掃描
/code-review        # 需要時單獨跑審查
/deploy             # 部署（強制先過 security 閘門）
/time-log           # 開發時間報表
/save-session       # 儲存 session 狀態
```

---

## 什麼時候誰會自己跳出來

### Hooks（機器執行）

| 時機 | Hook | 做什麼 |
|---|---|---|
| Session 開始 | `session-start.sh` | 時間歸檔、模板偵測、log 輪替、jq 健檢 |
| 你送出訊息 | `user-prompt-submit.sh` | 依關鍵字提示：建議任務模式、建議 agent、**該載入哪個 skill** |
| 我要寫檔/跑 Bash | `pre-tool-use.sh` | **任務模式閘門**、模式檔 TTL 過期清除、裸 `cd` 攔截 |
| Agent 完成 | `post-agent-report.sh` | 把 pending handoff 注入對話，提示接下一棒 |
| 寫入 WBS | `post-write.sh` | 記錄 WBS 變更歷史 |
| Context 將壓縮 | `pre-compact.sh` | 自動快照 |

### 閘門的逃生門

| 方式 | 效果 |
|---|---|
| `/suggest-mode off` | 關閉閘門與所有建議注入 |
| `TASKMODE_GATE=off` | 環境變數，單次或整段 session 關閉 |
| `TASKMODE_TTL_HOURS=N` | 調整模式檔過期時間（預設 8h） |

> TTL 存在的理由：`/verify` 完成任務時應清除模式檔，但那是靠自律的。
> TTL 是機器保證——就算沒清，逾時也會自動失效並重新要求判級。

### Skills（按需載入）

| 情境 | Skill |
|---|---|
| 寫前端頁面/元件、開 Pencil 設計稿 | `ui-style-compliance` |
| 跑 npm/pnpm/bun、動 package.json | `node-package-manager` |
| Python 套件/環境操作 | `python-uv` |
| 寫測試、決定覆蓋率門檻 | `testing-standards` |
| 建立或更新 plan 檔 | `plan-format` |
| 產專案文件 | `project-docs` |
| E2E 測試 | `e2e-testing` |
| DB schema 變更 | `database-migrations` / `postgres-patterns` |
| 開發 AI 應用 | `cost-aware-llm-pipeline` |
| 串接外部服務 | `mcp-builder` |
| 深度調查 | `deep-research` |

### Agent 鏈（依任務類型）

| 任務類型 | 鏈 |
|---|---|
| 新功能 | planner → **tdd-guide** → code-quality-specialist → test-automation-engineer →（critical）security-infrastructure-auditor |
| 修 bug | **tdd-guide（先寫重現測試）** → code-quality-specialist |
| 重構/清理 | refactor-cleaner → code-quality-specialist → test-automation-engineer |
| 建置/型別錯誤 | **build-error-resolver**（單點） |
| 前端 UI | （/ui-style →）ui-builder →（關鍵流程）e2e-validation-specialist |
| PR 前把關 | code-quality-specialist → security-infrastructure-auditor → e2e-validation-specialist |
| 部署 | security-infrastructure-auditor → deployment-expert |
| 架構決策 | architect → planner |

`quick` 模式只做粗體那一棒。

---

## 指令速查

### 核心循環

| 指令 | 用途 |
| :--- | :--- |
| `/task-init` | 專案初始化（選情境 → 產文件 → 生 WBS） |
| `/docs-init` | 文件產出（`--demo` / `--mvp` / `--full`） |
| `/task-next` | 取下一個任務（含任務模式選擇、平行任務偵測） |
| `/task-status` | 專案進度總覽（含 plan 階段進度） |
| `/plan [wbs-id]` | 規劃 → 寫入 `plans/<id>-<slug>.md` |
| `/tdd [mode]` | TDD 推進，自動載入 plan 按階段執行 |
| `/build-fix` | 修復建置/型別錯誤 |
| `/code-review` | 程式碼審查 |
| `/e2e` | E2E 測試 |
| `/verify [profile]` | 驗證（`quick`/`full`/`pre-commit`/`pre-pr`） |
| `/deploy` | 部署（先過安全閘門） |

### 環境設定

| 指令 | 用途 |
| :--- | :--- |
| `/ui-style` | 選擇/切換 UI 設計風格（單一或混搭） |
| `/ui-site` | 網站雛形（IA 文檔 + 多頁骨架 + tokens） |
| `/ui-page <path>` | 深化單一頁面 |
| `/pm-choose` · `/pm-switch` | Node 套件管理器選擇/切換 |
| `/suggest-mode` | 調整建議密度（也控制閘門開關） |

### 觀測與輔助

| 指令 | 用途 |
| :--- | :--- |
| `/agent-log` | 查看 subagent 軌跡、報告、handoff |
| `/check-quality` | 專案品質評估 + agent 路由 |
| `/template-check` | VibeCoding 模板合規檢查 |
| `/refactor-clean` | 死碼清理 |
| `/time-log` | 開發時間報表 |
| `/learn` | 擷取可重用模式 |
| `/save-session` | 儲存 session 狀態 |

---

## 已知未接上的環節

誠實標註，避免以為它會自己動：

1. ~~agent handoff 鏈只有 5/14 實作~~ —— **已修**。現為 10/14，
   `agent-orchestration.md` 表列的每條鏈都會自動交接；其餘 4 個是終端節點，本就不需要。
   仍需注意：hook 只能**注入提示**，實際啟動下一棒的是主模型，不是全自動。
2. **模板合規仍散在三處** —— `/template-check`（正主）、`/check-quality`（第 5 項）、
   `/task-status`（輸出區塊）。原本名實不符的 `/review-code` 已刪除，程式碼審查
   統一走內建 `/code-review`，但另外兩處的重述尚未收斂。
3. **`/learn` 的產出不是合法 skill 格式** —— 寫進 `skills/learned/` 但缺 frontmatter，
   不會被索引，實質只是筆記。
4. **skill 召回不是硬保證** —— rules 搬成 skill 後改為「要被想起來才載入」，
   `user-prompt-submit.sh` 的關鍵字提示是第二層保險，但非強制。
