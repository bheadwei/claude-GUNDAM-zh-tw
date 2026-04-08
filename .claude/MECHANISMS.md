# 擴充機制對照表 — Agent / Skill / Command / Hook / Context

> 本模板有**五**套擴充機制。容易混淆，這份文件是**唯一權威來源**：發生衝突時以本檔為準。

## 1. 五者本質

| 機制 | 觸發者 | 何時跑 | 帶來什麼 | 在哪 |
|---|---|---|---|---|
| **Hook** | Claude Code 主程式 | 系統事件自動 | shell 副作用 / context 注入 | `.claude/hooks/` + `settings.json` |
| **Command** | 使用者打 `/xxx` | 手動 | 一段預設 prompt | `.claude/commands/*.md` |
| **Skill** | Claude 自主判斷 | 偵測語意自動載入 | 領域知識 / 方法論 | `.claude/skills/<name>/SKILL.md` |
| **Agent** | Claude 主對話委派 | 子任務 | 獨立 context 的子 Claude | `.claude/agents/*.md` |
| **Context** | Agent 執行前後 | Agent wiring | 跨 session 結構化技術發現 | `.claude/context/` + `.claude/coordination/` |

## 2. 決策樹

```
要做的事？
├─ 系統事件後一定要發生 ────────────→ Hook
├─ 使用者按一個快捷鍵啟動流程 ──────→ Command
├─ 領域知識，希望 Claude 自動套用 ──→ Skill
├─ 要平行 / 隔離 context / 限工具 ──→ Agent
└─ Agent 之間或跨 session 共享技術發現 → Context（透過 Agent wiring）
```

## 2.5 Context 系統（第 5 個機制）

**目的**：讓 4 個專業 agent（quality / security / testing / e2e）能跨 session 與彼此共享結構化的技術發現。

**運作方式**：
1. Agent 啟動時讀取 `.claude/context/<area>/` 最新報告 + `.claude/coordination/handoffs/` 中的待處理交接
2. Agent 結束時寫入新報告，遵循 `.claude/context/_REPORT_TEMPLATE.md`
3. 若需要其他 agent 後續處理，建立 handoff 檔到 `.claude/coordination/handoffs/`
4. `post-agent-report.sh` hook 在 agent 結束時驗證報告是否寫入
5. `bash .claude/scripts/context-gc.sh` 定期清理舊報告（保留最新 5 份）

**啟用範圍**：
- ✅ `code-quality-specialist` → `context/quality/`
- ✅ `security-infrastructure-auditor` → `context/security/`
- ✅ `test-automation-engineer` → `context/testing/`
- ✅ `e2e-validation-specialist` → `context/e2e/`
- ❌ 其他 agent 暫未 wire（避免過度工程）

## 2.6 與其他「記憶」系統的衝突矩陣

模板中有多個「跨 session 紀錄」機制，邊界如下：

| 系統 | 位置 | 內容 | 觸發 | 適用 |
|---|---|---|---|---|
| **Context（本機制）** | `.claude/context/` | Agent 結構化技術發現 | Agent wiring | 跨 agent 共享、合規審計 |
| **save-session** | `.claude/sessions/` | 整個 session 的人類可讀進度 | `/save-session` 手動 | 跨 session 工作交接 |
| **/learn** | `.claude/skills/learned/` | 抽象 reusable pattern | `/learn` 手動 | 累積專案知識庫 |
| **TaskMaster** | `.claude/taskmaster-data/` | WBS、時間紀錄 | hook 自動 | 專案管理 |
| **logs** | `.claude/logs/` | 機器可讀活動 log | hook 自動 | 除錯、稽核 |
| **Auto-memory** ⚠️ | `~/.claude/projects/.../memory/` | Claude 對使用者偏好的自然語言記憶 | Claude 自主 | 個人化偏好（**位於專案外**）|

**互補關係**：
- Context 與 save-session：**粒度不同**（單 agent vs 整個 session）
- Context 與 /learn：**目標不同**（具體 finding vs 抽象 pattern）
- Context 與 Auto-memory：**內容不同**（結構化技術發現 vs 自然語言偏好）

⚠️ **Auto-memory 位置警告**：Claude Code 內建的 Auto-memory 寫入 `~/.claude/projects/.../memory/`，**位於專案根目錄之外**且**無法從專案配置改變路徑**。
- 若你希望所有記憶留在專案內：在主對話告訴 Claude「不要使用 auto-memory，改用 context 系統」
- 或刪除 `~/.claude/projects/D-----claude-v2026/memory/` 下既有檔案
- 詳見 `.claude/CONTEXT_USAGE.md` 的「記憶系統選擇」章節

## 3. 標準協作鏈

四者並非取代關係，而是**分工**。典型流程：

```
使用者 ──/command──▶ Claude
                      │
                      ├─ 自動載入 Skill（方法論）
                      ├─ 委派 Agent（執行子任務，獨立 context）
                      └─ Hook 在事件點自動跑（記錄 / 驗證 / 注入）
```

**範例：使用者打 `/tdd 加註冊功能`**
1. `/tdd` command 注入 TDD 流程提示
2. Claude 自動載入 `tdd-workflow` skill 取得方法論
3. Claude 委派 `tdd-guide` agent 寫測試（獨立 context）
4. `PostToolUse` hook 在每次寫檔後記錄

## 4. 職責邊界（權威表）

### TDD 領域

| 元件 | 角色 | 介入時機 |
|---|---|---|
| `/tdd` command | **入口**：使用者觸發 TDD 流程 | 開始寫新功能 |
| `tdd-workflow` skill | **方法論**：Red-Green-Refactor 規則 | Claude 自動載入 |
| `tdd-guide` agent | **前置門禁**：實作**前**強制 test-first，引導 Red-Green | 寫新程式碼之前 |
| `test-automation-engineer` agent | **後置補強**：實作**後**讀 quality/e2e 報告補強測試覆蓋率 | 程式碼完成、quality 審查之後 |

> 兩個 agent **互補不重疊**：tdd-guide 是「寫之前」的門禁，test-automation-engineer 是「寫完後」的補強。
> 區分機制：test-automation-engineer 透過 Context 系統讀取 quality/e2e handoff，目標明確。

### 程式碼審查 / 品質

| 元件 | 角色 | 何時用 |
|---|---|---|
| `/review-code` command | **入口**：完整 code review | 寫完功能後 |
| `/check-quality` command | **入口**：品質評估＋agent 推薦 | 不確定要做什麼時 |
| `security-review` skill | **方法論**：安全檢查清單 | Claude 自動載入 |
| `code-quality-specialist` agent | **執行者**：審查程式碼品質 | `/review-code` 委派 |
| `security-infrastructure-auditor` agent | **執行者**：OWASP / 基礎設施安全 | 安全敏感變更後 |

**邊界**：`code-quality-specialist` 專注**程式碼可維護性**；`security-infrastructure-auditor` 專注**安全漏洞**。兩者不重疊。

### E2E 測試

| 元件 | 角色 |
|---|---|
| `/e2e` command | 入口：產生並執行 E2E 測試 |
| `e2e-testing` skill | 方法論：Playwright POM、artifacts、flaky 處理 |
| `e2e-validation-specialist` agent | 執行者：跑 Playwright |

### 建置修復

| 元件 | 角色 |
|---|---|
| `/build-fix` command | 入口：使用者觸發 |
| `build-error-resolver` agent | 執行者：以最小變更修錯 |

### 規劃

| 元件 | 角色 |
|---|---|
| `/plan` command | 入口：手動觸發規劃 |
| `planner` agent | 執行者：產出詳細實作計畫（自動使用） |

### 重構

| 元件 | 角色 |
|---|---|
| `/refactor-clean` command | 入口 |
| `refactor-cleaner` agent | 執行者：死碼清理 |

### 規劃領域（時序互補）

| 元件 | 介入時機 | 回答的問題 |
|---|---|---|
| `architect` agent | **最早**：新功能或重構之前 | 「**做什麼樣的系統**」— 架構設計、技術選型、可擴展性 |
| `planner` agent | architect 之後 | 「**怎麼一步步做出來**」— 需求拆解、依賴順序、風險點 |
| `/plan` command | 使用者觸發 | 入口；通常委派 planner 執行 |

> **典型流程**：複雜功能 → 先 architect（高層架構） → 再 planner（步驟拆解） → 進入實作階段
> 簡單功能可跳過 architect，直接 planner。

### 部署 / 文件

| 元件 | 角色 | 區別 |
|---|---|---|
| `deployment-expert` agent | 部署、CI/CD、監控 | — |
| `documentation-specialist` agent | **技術文檔**：codemap、API doc、技術 README | 對應「程式碼產生的文件」 |
| `workflow-template-manager` agent | **流程文檔**：PRD、ADR、設計文檔（VibeCoding 模板） | 對應「過程性文件」 |

> 兩個「文件 agent」互補：documentation-specialist 處理**程式碼層**的文檔，workflow-template-manager 處理**流程層**的模板套用。

## 5. 已知重疊與建議

| 狀況 | 問題 | 處理 |
|---|---|---|
| `tdd-guide` ＋ `test-automation-engineer` | ~~原本~~ 兩 agent 內容寫得幾乎一樣，職責不清 | ✅ **已修正**：test-automation-engineer 重寫為「實作後補強」角色，透過 Context 系統取得明確工作清單 |
| `/review-code` ＋ `/check-quality` | 兩個 command 都做品質評估 | 保留 `/check-quality` 做分類，`/review-code` 專注實際審查 |
| skill `security-review` ＋ agent `security-infrastructure-auditor` | skill 是清單、agent 是執行者 | **OK，分工明確**，無需動 |

## 6. 命名約定（未來新增請遵循）

| 類型 | 命名 | 範例 |
|---|---|---|
| Command | 動詞或動賓 | `/plan`、`/review-code` |
| Skill | 名詞 + workflow/patterns | `tdd-workflow`、`api-design` |
| Agent | 角色名 + specialist/expert/guide | `code-quality-specialist`、`tdd-guide` |
| Hook | 事件 + 動作 | `post-write.sh`、`session-start.sh` |

## 7. 最常見的疑問

**Q: 我寫了一個 skill，為什麼 Claude 沒自動用？**
A: 檢查 `SKILL.md` frontmatter 的 `description` 是否清楚描述觸發時機。Claude 是用語意比對 description 來決定要不要載入。

**Q: command 和 skill 內容看起來很像，差別到底是什麼？**
A: command 是「使用者按按鈕」，skill 是「Claude 隨身的書」。前者必須使用者主動呼叫，後者 Claude 自己決定要不要翻書。

**Q: 為什麼不全部用 agent 就好？**
A: agent 開新 context 有成本（重新載入規則、無法看主對話歷史）。簡單任務在主對話直接做更快。

**Q: hook 失敗會怎樣？**
A: 看 hook 類型。`PreToolUse` 失敗會阻擋工具呼叫；`PostToolUse` / `SessionStart` 失敗只是輸出錯誤，不影響流程。
