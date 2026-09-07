# 開發工作流指南

## 系統由五層組成

| 層 | 數量 | 何時生效 | 可否略過 |
|---|---|---|---|
| **Hooks** | 7 | 事件觸發，機器執行 | 只有明確逃生門 |
| **Rules** | 6 | 每個 session 全量載入 | 否（但靠模型遵守） |
| **Skills** | 14 | 情境觸發，按需載入 | 是（需被想起來） |
| **Commands** | 28 | 使用者主動叫 | — |
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

### 多階段 plan：兩種執行方式

`standard`/`critical` 且 plan 有 ≥2 階段時，`/tdd` 會問一題：

```
[Recommended] 逐階段派 implementer subagent
    每階段一個全新 subagent + 階段審查 + 有界修復迴圈，過程記進帳本
我直接照 plan 實作
    委派 tdd-guide 走標準 RED-GREEN-REFACTOR
```

選第一個走 `subagent-execution` skill：

```
準備：建立/接續帳本 plans/<plan 同名>.progress.md → 讀相關的坑
   ▼
每階段：記 BASE commit → 派 implementer（明確指定 model）→ 讀狀態碼
        → 規格合規審查 + code-quality-specialist → 有問題進修復迴圈
   ▼
修復迴圈上限 5 輪：R1-R3 交回同一個 implementer；R4-R5 換新的 + 升級模型
   ▼
全部階段完成 → 全域審查 → /verify（帳本隨 plan 一起歸檔）
```

三個關鍵設計：

- **帳本是復原地圖**：第一行寫 `# 執行帳本 — plan: <路徑>` 當身分。context 被壓縮後
  **相信帳本與 `git log`，不要相信記憶**——帳本點名的 commit 在 git 裡真的存在
- **裁決而非停等**：跑起來之後不問人。衝突自己決定並記成
  `Ruling: <決定> — <理由> — <錯了的代價>`。只有四件事會停：不可逆操作、安全敏感、
  副作用超出 plan 的 `files:` 範圍、全部完成
- **每次派工都指定 `model`**：機械任務 `haiku`、整合判斷 `sonnet`、架構 `opus`。
  但**回合數比單價貴**——便宜模型來回五次比貴模型一次做對更貴，規格模糊時直接上一級

### 做到一半想加功能

```
/task-add
   │  問要加什麼 → 自動拆解成 1~N 行、接上編號、算依賴與預估
   ▼
預覽 → 確認 → 寫回 wbs.md → 問要不要現在開始
```

不用記這個指令也行，三個地方會主動提起：
`/task-next` 在待辦清空時 · `/verify` 在 ad-hoc plan 完成時 · 你說「想加功能…」時關鍵字提示。

> **為什麼要先過 WBS**：直接跳 `/plan` 會讓那一行永遠不存在，
> plan 就被迫兼差當 backlog（這正是「plan 感覺很像 WBS」的成因）。
> WBS = 還有什麼要做（一行）；Plan = 這件事怎麼做（一份檔）。

### 東西壞了

直接說「這個壞了 / 沒反應 / 為什麼會這樣」，會委派 **debug-investigator**。
它的價值是**不讓人跳步**：

```
穩定重現（最常被跳過）→ 二分縮小是哪一層 → 寫下可證偽的假設
   → 寫重現測試（RED）→ 修根因不修症狀 → 驗證 + 記錄排除過的假設
```

無法重現時它會停下來回報，不會瞎猜——「無法重現」本身是情報，不是失敗。
建置/型別錯誤走另一條（`build-error-resolver`，不需調查，直接最小差異修）。

### WBS 太大包時

一個里程碑的任務全部完成 → `/verify` 會問要不要歸檔：

```
wbs.md          只留活躍任務 + 里程碑摘要（長度跟「還沒做完的事」掛鉤）
wbs-archive.md  已完成里程碑的完整任務列（含實際耗時，可回顧估準不準）
```

編號**永不重用**，`/task-add` 會同時掃兩個檔決定新編號。
`/task-status` 顯示「活躍 8 ・已歸檔 34」，`/time-log` 找不到任務時會回查歸檔。

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

## Phase 2：收尾與交付

```bash
/verify pre-pr      # 完整檢查 + 安全掃描
/code-review        # 需要時單獨跑審查（Claude Code 內建）
/pr                 # 開 PR：分析完整 commit 歷史 + 測試計畫，可選先跑把關鏈
/deploy             # 部署（強制先過 security 閘門）
/time-log           # 開發時間報表
/save-session       # 儲存 session 狀態
```

## 定期維護（不綁任務循環）

```bash
/deps               # 依賴維護：分批升級，每批測試後才 commit
/adr                # 記錄技術決策（為什麼選 A 不選 B）
/refactor-clean     # 死碼清理
/template-check     # 模板合規
```

`/deps` 建議每月或每個里程碑結束時跑，**不要在功能開發到一半跑**——
會混淆「是我改壞的還是升級弄壞的」。

---

## 什麼時候誰會自己跳出來

### Hooks（機器執行）

| 時機 | Hook | 做什麼 |
|---|---|---|
| Session 開始 | `session-start.sh` | **注入 `using-taskmaster`（強制委派指令）**、時間歸檔、模板偵測、log 輪替、jq 健檢 |
| 你送出訊息 | `user-prompt-submit.sh` | 依關鍵字路由：任務模式、**該委派哪個 agent（含 `subagent_type`）**、該載入哪個 skill |
| 我要寫檔/跑 Bash | `pre-tool-use.sh` | **任務模式閘門**、**坑閘門**、模式檔 TTL 過期清除、裸 `cd` 攔截 |
| Agent 完成 | `post-agent-report.sh` | 把 pending handoff 注入對話，提示接下一棒；**非同步啟動的 agent 記下報告期望，交由延後稽核** |
| 寫檔後 | `post-write.sh` | 記錄 WBS 變更歷史；**文件影響偵測**（改到 API／schema／對外介面時記進 `.doc-impact` 並提醒一次） |
| Context 將壓縮 | `pre-compact.sh` | 自動快照 |

### 閘門的逃生門

| 方式 | 效果 |
|---|---|
| `/suggest-mode off` | 關閉閘門與所有建議注入 |
| `TASKMODE_GATE=off` | 環境變數，單次或整段 session 關閉 |
| `TASKMODE_TTL_HOURS=N` | 調整模式檔過期時間（預設 8h） |
| `PITFALL_GATE=off` | 只關坑閘門，保留任務模式閘門 |
| `DOC_SYNC_GATE=off` | 只關文件影響偵測與 `/verify` 的文件關卡 |
| `REPORT_AUDIT=off` | 只關 agent 報告稽核 |

### 坑閘門：同一個坑不踩第二次

`.claude/context/learned/` 的每份紀錄都有 `files:` glob。要寫入命中的檔案時，
`pre-tool-use.sh` **擋一次**並把 `symptom` / `root-cause` / `guard` 貼進對話，
讀完重試同一次編輯即通過（同一檔案一個 session 只擋一次）。

```
debug-investigator 找到根因
   ▼
必須寫一筆 learned/<slug>.md（frontmatter 四欄不能空）
   ▼
下次任何人（或 agent）要改 files: 命中的檔案
   ▼
PreToolUse 擋下 → 貼出教訓 → 重試通過
```

`files:` 寫錯或留空 = 這份紀錄永遠不會被觸發，等於沒寫。
坑修掉了就改掉／刪掉那份檔案，不要用 `PITFALL_GATE=off` 繞過——
留著過期紀錄比沒紀錄更糟，大家會學會忽略它。

> 為什麼是「擋一次」而不是「溫和提示」：PreToolUse 事件**不支援**
> `additionalContext`（只認 `permissionDecision` / `permissionDecisionReason`），
> 非阻斷式提醒在這個 hook 點無法送達。這是 Claude Code 的機制邊界。

> TTL 存在的理由：`/verify` 完成任務時應清除模式檔，但那是靠自律的。
> TTL 是機器保證——就算沒清，逾時也會自動失效並重新要求判級。

### 報告稽核：非同步 agent 的延後檢查

`post-agent-report.sh` 原本在 PostToolUse 當下就 `find` 報告檔，但 Agent tool 常是
**非同步啟動**（`tool_response` 帶 `"status":"async_launched"`），那一刻 agent 根本還沒動工
→ 真有寫報告也被記成 WARN。而且只寫 log 不注入，等於沒有牙齒。

現在改成：

```
非同步啟動 → 只記下「報告期望」到 taskmaster-data/.report-expectations.jsonl
   ▼
後續對話邊界（UserPromptSubmit 或下一個 agent 完成）
   ▼
lib/check-report-expectations.sh 重新檢查
   ├─ 寬限期內（<120s）→ 安靜，不吵
   ├─ 報告已寫（-newermt 比對啟動時間，舊報告不算）→ 清除期望，log 記 OK
   ├─ 缺報告 → **經 additionalContext 注入**要求補寫（同一筆只吵一次）
   └─ 逾 30 分鐘 → 放棄追蹤，log 記 WARN
```

同步完成的 agent 仍走當下稽核（原行為）。

| 參數 | 預設 | 作用 |
|---|---|---|
| `REPORT_GRACE_SECONDS` | 120 | 幾秒內不檢查，避免 agent 還在跑就催 |
| `REPORT_DEADLINE_SECONDS` | 1800 | 超過就放棄追蹤 |
| `REPORT_AUDIT=off` | — | 完全關閉稽核 |

> `AREA` 對應表（agent → `context/<area>/`）必須與各 agent 檔的「寫入報告到」路徑一致。
> 改 agent 報告落點時要同步 `post-agent-report.sh`，否則稽核永遠找不到報告。

### 文件同步關卡：程式寫了、文件沒跟上

這是新需求與客戶 CR 最常見的失敗，而原因是結構性的——`documentation-specialist`
在任務完成路徑上**原本沒有位置**。`/verify` 只驗建置/型別/lint/測試，從不問文件。

```
你改到 src/api/reconcile/route.ts
   ▼
post-write.sh 認出這是「文件描述的對象」
   ├─ 記進 taskmaster-data/.doc-impact（去重累積）
   └─ 本任務第一次命中 → additionalContext 提醒一次（之後安靜）
   ▼
繼續實作（不要停下來處理文件）
   ▼
/verify 通過，準備標 WBS ✅
   ▼
讀 .doc-impact → 非空則**必須**問一題：
   ├─ 委派 documentation-specialist 同步（把整份清單放進 prompt）
   ├─ 我已經自己更新過了
   └─ 這次不需要（記錄原因）
   ▼
處理完才清除 .doc-impact 並標 ✅
```

**哪些檔案算「文件描述的對象」**：`*/api/*`、`*/routes/*`、`*/controllers/*`、
`*/handlers/*`、`*openapi*`、`*.proto`、`*.graphql`、`*schema*`、`*/migrations/*`、
`*/models/*`、`*/entities/*`、`*/dto/*`、`*/index.ts`、`*.d.ts`、`*/cli/*`、`.env.example`。

**排除**：`.claude/**`、`docs/**`（改文件本身不算文件債）、測試檔（`*test*`／`*spec*`／
`__tests__`／`fixtures`）、依賴與建置產物。

> 為什麼提醒只發一次：每改一個 API 檔就吵一次會被無視。真正的關卡在 `/verify`，
> 那裡才是「不處理就不能標完成」的地方。

### Skills（按需載入）

| 情境 | Skill |
|---|---|
| （每個 session 自動注入，不需想起來） | `using-taskmaster` — 強制委派 + 動工前先讀坑 |
| 寫前端頁面/元件、開 Pencil 設計稿 | `ui-style-compliance` |
| 跑 npm/pnpm/bun、動 package.json | `node-package-manager` |
| Python 套件/環境操作 | `python-uv` |
| 寫測試、決定覆蓋率門檻 | `testing-standards` |
| 建立或更新 plan 檔 | `plan-format` |
| 執行多階段 plan（standard/critical） | `subagent-execution` — 逐階段派 implementer + 帳本 |
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
| 修 bug（跑起來行為不對） | **debug-investigator（先重現再定根因）** →（critical）tdd-guide → code-quality-specialist |
| 修 bug（建置/型別錯誤） | **build-error-resolver**（直接最小差異修，不需調查） |
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
| `/task-next` | 取下一個任務（含任務模式選擇、平行任務偵測；待辦清空時提議 `/task-add`） |
| `/task-add` | 把新功能追加進 WBS（自動拆解、接編號、算依賴） |
| `/task-status` | 專案進度總覽（含 plan 階段進度） |
| `/plan [wbs-id]` | 規劃 → 寫入 `plans/<id>-<slug>.md` |
| `/tdd [mode]` | TDD 推進，自動載入 plan 按階段執行 |
| `/build-fix` | 修復建置/型別錯誤 |
| `/code-review` | 程式碼審查 |
| `/e2e` | E2E 測試 |
| `/verify [profile]` | 驗證（`quick`/`full`/`pre-commit`/`pre-pr`） |
| `/pr` | 建立 Pull Request（含把關與測試計畫） |
| `/deploy` | 部署（先過安全閘門） |
| `/deps` | 依賴維護（分批升級 + 每批測試） |
| `/adr` | 記錄技術決策與被否決的方案 |

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

## 剩下的已知限制

1. **啟動 agent 的執行者永遠是主模型** —— hook 只能注入 context，無法直接呼叫 Agent 工具。
   這是 Claude Code 的機制邊界。目前用三層把「注入」做到夠強：
   SessionStart 全文注入 `using-taskmaster`（含 Red Flags 反合理化表）、
   `user-prompt-submit.sh` 的關鍵字路由（帶 `subagent_type`）、
   agent 完成後的 pending handoff 注入。
2. **skill 召回不是硬保證** —— 除了常駐注入的 `using-taskmaster`，其餘 13 個 skill
   仍是「要被想起來才載入」。兩層保險：`description` 寫成觸發條件導向、
   `user-prompt-submit.sh` 的關鍵字提示。要再硬一點的話，可以比照任務模式閘門，
   在 `pre-tool-use.sh` 加「寫 `.tsx/.vue/.css` 但未載入 `ui-style-compliance` → deny」，
   機制現成（坑閘門就是照這個模式做的）。
3. **執行型委派是選項不是預設** —— `subagent-execution` 需要 plan 有 ≥2 階段，
   而且由使用者在 `/tdd` 的「選執行方式」決定。沒有 plan 的 ad-hoc 路徑不適用。

### 尚未做的（已規劃）

- **plugin 化發佈** —— 把 `skills/ commands/ agents/ hooks/` 拆成 Claude Code plugin 走
  marketplace，改版號即自動更新（取代手動 `update-template.sh`）。
  代價：指令會變 `/taskmaster:task-next`；且 plugin 帶不了 `rules/`，需先把 rules 改寫成
  SessionStart 注入的 skill（`using-taskmaster` 已示範這個路徑）。
- **`converge` 類收斂檢查** —— `/verify` 目前只驗建置/型別/lint/測試/console.log 與 plan
  驗收標準，沒有「codebase 還符合當初的 PRD 嗎」這層（對標 spec-kit 的 `/speckit.converge`）。
- **constitution（專案不變量）** —— `rules/` 是模板通用規範，缺「這個專案不可違反的原則」。
- **CI** —— `.github/` 不存在。`run-tests.sh` 失敗時 exit 1，可直接掛。

## 改動 hook 之後

```bash
bash .claude/hooks/tests/run-tests.sh
```

127 個案例，全綠才算沒破壞閘門。詳見 `.claude/hooks/tests/README.md`。
