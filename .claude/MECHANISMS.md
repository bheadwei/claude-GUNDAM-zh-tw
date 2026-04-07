# 擴充機制對照表 — Agent / Skill / Command / Hook

> 本模板有四套擴充機制。容易混淆，這份文件是**唯一權威來源**：發生衝突時以本檔為準。

## 1. 四者本質

| 機制 | 觸發者 | 何時跑 | 帶來什麼 | 在哪 |
|---|---|---|---|---|
| **Hook** | Claude Code 主程式 | 系統事件自動 | shell 副作用 / context 注入 | `.claude/hooks/` + `settings.json` |
| **Command** | 使用者打 `/xxx` | 手動 | 一段預設 prompt | `.claude/commands/*.md` |
| **Skill** | Claude 自主判斷 | 偵測語意自動載入 | 領域知識 / 方法論 | `.claude/skills/<name>/SKILL.md` |
| **Agent** | Claude 主對話委派 | 子任務 | 獨立 context 的子 Claude | `.claude/agents/*.md` |

## 2. 決策樹

```
要做的事？
├─ 系統事件後一定要發生 ────────────→ Hook
├─ 使用者按一個快捷鍵啟動流程 ──────→ Command
├─ 領域知識，希望 Claude 自動套用 ──→ Skill
└─ 要平行 / 隔離 context / 限工具 ──→ Agent
```

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

| 元件 | 角色 | 何時用 |
|---|---|---|
| `/tdd` command | **入口**：使用者觸發 TDD 流程 | 開始寫新功能 |
| `tdd-workflow` skill | **方法論**：Red-Green-Refactor 規則 | Claude 自動載入 |
| `tdd-guide` agent | **執行者**：實際寫測試的子 Claude | command 委派 |
| ~~`test-automation-engineer` agent~~ | **建議移除**：與 tdd-guide 重疊 | — |

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

### 部署 / 文件 / 架構

| 元件 | 角色 |
|---|---|
| `deployment-expert` agent | 部署、CI/CD、監控 |
| `documentation-specialist` agent | API doc、codemap、知識庫 |
| `architect` agent | 系統設計、技術決策（唯讀） |
| `workflow-template-manager` agent | VibeCoding 模板協調 |

## 5. 已知重疊與建議

| 狀況 | 問題 | 建議 |
|---|---|---|
| `tdd-guide` ＋ `test-automation-engineer` | 兩個 agent 都做 TDD，職責 95% 重疊 | **保留 `tdd-guide`**，移除 `test-automation-engineer` |
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
