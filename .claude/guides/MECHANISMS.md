# 擴充機制對照表 — Agent / Skill / Command / Hook / Context

> 本模板有**五**套擴充機制。發生衝突時以本檔為準。

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
└─ Agent 之間或跨 session 共享技術發現 → Context
```

## 3. Context 系統

4 個專業 agent 在執行前後自動讀寫 context：

| Agent | Area |
|---|---|
| code-quality-specialist | `context/quality/` |
| security-infrastructure-auditor | `context/security/` |
| test-automation-engineer | `context/testing/` |
| e2e-validation-specialist | `context/e2e/` |

**運作**：Agent 啟動時讀最新報告 + handoffs → 結束時寫新報告 → 需後續處理則建立 handoff。
**清理**：`bash .claude/scripts/context-gc.sh`

## 4. 持久化系統邊界

| 系統 | 位置 | 內容 | 觸發 |
|---|---|---|---|
| **Context** | `.claude/context/` | Agent 結構化技術發現 | Agent wiring |
| **save-session** | `.claude/sessions/` | Session 進度快照 | `/save-session` 手動 |
| **/learn** | `.claude/skills/<name>/SKILL.md`（真 skill）<br>或 `.claude/context/learned/`（筆記） | 可重用 pattern | `/learn` 手動，二選一 |
| **TaskMaster** | `.claude/taskmaster-data/` | WBS、時間紀錄 | hook 自動 |
| **logs** | `.claude/logs/` | 活動 log | hook 自動 |

## 5. 職責邊界

### TDD 領域

| 元件 | 角色 | 介入時機 |
|---|---|---|
| `/tdd` command | 入口 | 開始寫新功能 |
| `tdd-guide` agent | 前置門禁：強制 test-first | 寫新程式碼之前 |
| `test-automation-engineer` agent | 後置補強：讀 quality/e2e 報告補覆蓋率 | 程式碼完成後 |

### 程式碼審查

| 元件 | 角色 |
|---|---|
| `/code-review`（**Claude Code 內建**） | 程式碼審查入口，支援 `ultra` 多 agent 雲端審查、`--fix`、`--comment`、指定 PR/分支 |
| `/template-check` command | VibeCoding 模板合規（21 個範本） |
| `/check-quality` command | 品質評估 + agent 推薦 |
| `code-quality-specialist` agent | 審查程式碼可維護性 |
| `security-infrastructure-auditor` agent | 審查安全漏洞 |

> 本模板**不自建** code review 指令——內建的 `/code-review` 功能更完整。
> 舊有的 `/review-code` 已刪除（它名為審查、內容其實是模板合規清單，職責歸 `/template-check`）。

### 規劃領域

| 元件 | 回答的問題 |
|---|---|
| `architect` agent | 「做什麼樣的系統」— 架構、技術選型 |
| `planner` agent | 「怎麼一步步做」— 拆解、依賴、風險 |

### 文件領域

| 元件 | 區別 |
|---|---|
| `documentation-specialist` agent | 程式碼層：codemap、API doc |
| `workflow-template-manager` agent | 流程層：PRD、ADR 模板 |

## 6. 命名約定

| 類型 | 命名 | 範例 |
|---|---|---|
| Command | 動詞或動賓 | `/plan`、`/check-quality`（避開內建指令名） |
| Skill | 名詞 + workflow/patterns | `deep-research`、`e2e-testing` |
| Agent | 角色名 + specialist/expert/guide | `code-quality-specialist`、`tdd-guide` |
| Hook | 事件 + 動作 | `post-write.sh`、`session-start.sh` |
