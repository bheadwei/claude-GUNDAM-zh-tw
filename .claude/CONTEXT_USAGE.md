# Context 系統使用指南

> 此文件說明如何使用 `.claude/context/` + `.claude/coordination/` 的 agent 跨 session 共享系統。
> 機制設計與其他系統的邊界請看 `.claude/MECHANISMS.md`。

## 核心概念（30 秒版）

4 個專業 agent 在執行前後會自動讀寫 `.claude/context/<area>/`：

```
quality   ← code-quality-specialist
security  ← security-infrastructure-auditor
testing   ← test-automation-engineer
e2e       ← e2e-validation-specialist
```

它們能彼此讀對方的報告，並透過 `.claude/coordination/handoffs/` 互相交接工作。
所有資料**100% 留在專案內**，跟著 git 走。

---

## 你需要做什麼？答：基本上什麼都不用做

Context 系統設計成「**對使用者透明**」—— 你照常用 `/review-code`、`/tdd`、`/check-quality` 等指令，agent 會自動讀寫 context 報告。

唯一需要你介入的時機：
1. **想看 agent 上次發現了什麼** → `ls .claude/context/<area>/`
2. **想清理舊報告** → `bash .claude/scripts/context-gc.sh`
3. **想停用 Auto-memory（讓所有記憶留在專案內）** → 見下方第 4 節

---

## 1. 典型工作流範例

### 範例 A：審查 → 補強測試

```
你：/review-code

  ↓ Claude 委派 code-quality-specialist agent
  ↓ agent 讀取 .claude/context/quality/ 上次的報告（避免重複工作）
  ↓ 完成審查，寫入 .claude/context/quality/code-quality-specialist-2026-04-08-1430.md
  ↓ 發現 3 個檔案缺測試 → 自動建立 handoff 到 test-automation-engineer
  ↓ handoff 檔：.claude/coordination/handoffs/code-quality-specialist-to-test-automation-engineer-2026-04-08-1430.md

你：（稍後）幫我補測試

  ↓ Claude 委派 test-automation-engineer agent
  ↓ agent 讀取 handoffs/ 找到 pending 的交接 → 直接知道要補哪 3 個檔
  ↓ 補完後寫報告到 .claude/context/testing/
  ↓ 把 handoff 的 status 更新為 completed
```

關鍵點：**第二次對話不需要重講背景**，agent 從 handoff 直接接手。

### 範例 B：跨日的安全稽核

```
週一：/check-quality

  ↓ security agent 寫入 .claude/context/security/security-infrastructure-auditor-2026-04-06-1530.md
  ↓ 發現 7 個問題

週三：你想知道上次稽核結果

你：上週的安全掃描有哪些未修的？
Claude：（讀 .claude/context/security/ 最新報告）
       「2026-04-06 的報告顯示 7 個問題，其中未修的是：
        - X.py:42 SQL 注入
        - Y.ts:88 硬編碼 token」
```

關鍵點：**跨日記憶不依賴 Claude 的對話 context**，從 git 追蹤的報告檔讀。

---

## 2. 手動操作指令

### 查看某個領域的最新報告
```bash
ls -t .claude/context/quality/*.md | head -5
cat .claude/context/quality/$(ls -t .claude/context/quality/*.md | head -1)
```

### 查看待處理交接
```bash
grep -l "status: pending" .claude/coordination/handoffs/*.md 2>/dev/null
```

### 清理舊報告（保留最新 5 份）
```bash
bash .claude/scripts/context-gc.sh
```

### 預演 GC（不實際移動）
```bash
bash .claude/scripts/context-gc.sh --dry-run
```

### 自訂保留份數
```bash
bash .claude/scripts/context-gc.sh --keep 10
```

### 檢查 hook 是否正常運作
```bash
cat .claude/logs/context-reports.log | tail -20
```
日誌會顯示 `OK` 或 `WARN`。如果某次 agent 執行後出現 `WARN: ... no report written`，代表那次 agent 沒遵守規範。

---

## 3. 報告格式

所有報告使用 `.claude/context/_REPORT_TEMPLATE.md` 的格式。手動寫報告時可從 template 複製。

關鍵欄位：
- **frontmatter**：agent / date / area / target / severity / status
- **TL;DR**：3 行內，給其他 agent 快速判斷
- **發現**：按嚴重程度分組
- **建議的後續 Agent**：誰該接手

---

## 4. 記憶系統選擇（重要：保持資料在專案內）

模板有**多套**「跨 session 紀錄」機制，本節幫你決定哪些開、哪些關。

### 推薦配置：所有資料留在專案內

| 系統 | 預設狀態 | 是否保留專案內 | 建議 |
|---|---|---|---|
| Context（本系統） | ✅ 已啟用 | ✅ `.claude/context/` | **保留** |
| save-session | ✅ 已啟用 | ✅ `.claude/sessions/`（已修正） | **保留** |
| /learn | ✅ 已啟用 | ✅ `.claude/skills/learned/`（已修正） | **保留** |
| TaskMaster | ✅ 已啟用 | ✅ `.claude/taskmaster-data/` | **保留** |
| Auto-memory ⚠️ | Claude Code 自動 | ❌ `~/.claude/projects/.../memory/` | **建議停用** |

### 如何停用 Auto-memory（讓所有記憶 100% 留在專案內）

Auto-memory 是 Claude Code 內建機制，**無法從專案配置改路徑**。要停用有兩種方法：

**方法 A：刪除既有記憶 + 告訴 Claude 不要再寫**

```bash
# 1. 刪除既有的 auto-memory 檔案
rm -rf ~/.claude/projects/D-----claude-v2026/memory/

# 2. 在每次 session 開始時，告訴 Claude：
#    「不要使用 auto-memory，所有記憶請寫入 .claude/context/ 或 .claude/sessions/」
```

**方法 B：在 CLAUDE_TEMPLATE.md 加入永久指示（推薦）**

在 `CLAUDE_TEMPLATE.md` 開頭加：
```markdown
## 記憶系統規則
- 不要使用 auto-memory（~/.claude/projects/.../memory/）
- 跨 session 技術發現 → .claude/context/<area>/
- 跨 session 工作交接 → .claude/sessions/
- 可重用 pattern → .claude/skills/learned/
```

這樣每次 session 開始 Claude 讀到 CLAUDE_TEMPLATE.md 就會遵守。

---

## 5. 故障排除

### 問題：agent 跑完但沒寫報告
**原因**：agent 沒遵守 .md 中的指示
**檢查**：`tail .claude/logs/context-reports.log`
**解法**：
1. 確認 agent 的 .md 包含「上下文整合」段落
2. 在主對話提醒 Claude：「請依照 agent .md 的規範寫報告到 context/」

### 問題：handoff 檔越來越多
**原因**：handoff 完成後沒更新 status
**解法**：手動或讓 test-automation-engineer 在處理時更新 status，或定期清理：
```bash
# 找出超過 30 天的 handoff
find .claude/coordination/handoffs/ -name "*.md" -mtime +30
```

### 問題：context 報告佔太多 token
**原因**：保留太多舊報告
**解法**：
```bash
bash .claude/scripts/context-gc.sh --keep 3
```

### 問題：hook 在 Windows Git Bash 失敗
**原因**：`jq` 未安裝
**解法**：hook 已做軟降級（沒 jq 直接退出），不會阻擋。但會失去報告驗證功能。
建議安裝 jq：`winget install jqlang.jq`

---

## 6. 設計原則（為什麼這樣設計）

1. **不污染主對話 context**：不在 session-start 自動注入報告，避免吃 token
2. **按需讀取**：只有相關 agent 在啟動時才讀對應領域的報告
3. **互補不重複**：與 save-session、/learn、Auto-memory 邊界明確
4. **資料留在專案內**：所有檔案在 `.claude/` 下，git 可追蹤
5. **軟強制**：hook 只警告不阻擋，agent 不遵守規範也不會弄壞工作流
6. **可清理**：context-gc.sh 防止報告無限累積

---

## 7. 進階：擴充到其他 agent

如果未來想讓 `architect`、`deployment-expert`、`documentation-specialist` 也加入 context 系統：

1. 在該 agent 的 .md 加上「上下文整合」段落（仿照 `code-quality-specialist.md`）
2. 在 `post-agent-report.sh` 的 case 區塊加上對應 agent
3. 在 `MECHANISMS.md` 的「啟用範圍」更新清單

預設只啟用 4 個是為了避免過度工程 — 等實際需要再擴。
