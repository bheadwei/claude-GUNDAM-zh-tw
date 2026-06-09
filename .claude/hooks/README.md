# 🪝 Hooks 系統

`.claude/hooks/` 下的 shell 腳本由 Claude Code 在特定事件自動觸發，負責**副作用與上下文注入**（記錄、時間追蹤、agent 觀測、handoff 自動化、意圖路由）。掛載設定在 `.claude/settings.json` 的 `hooks` 區。

## 📁 檔案結構

```
.claude/hooks/
├── README.md                # 本文件
├── session-start.sh         # SessionStart：模板偵測、時間歸檔、log 輪替
├── user-prompt-submit.sh    # UserPromptSubmit：/task-init 偵測 + 意圖路由注入
├── pre-tool-use.sh          # PreToolUse(Write|Edit)：輕量 log
├── post-write.sh            # PostToolUse(Write)：WBS/檔案寫入記錄
├── agent-monitor.sh         # Pre/PostToolUse(Agent)：subagent 活動記錄
├── post-agent-report.sh     # PostToolUse(Agent)：報告稽核 + pending handoff 注入
├── pre-compact.sh           # PreCompact：壓縮前快照工作狀態到 sessions/
└── watch-agents.sh          # 手動工具（非 hook）：即時追蹤 agent 活動
```

> 已移除 `hook-utils.sh`（舊 TaskMaster `taskmaster.js` 時代的共用庫，無任何 hook 引用）。

## 🎯 各 Hook 功能

| 腳本 | 事件 / Matcher | 功能 |
|---|---|---|
| `session-start.sh` | `SessionStart` | 偵測 `CLAUDE_TEMPLATE.md` 顯示提示；歸檔上次 session 時間；**啟動時一次性輪替 log**；jq 缺失健檢 |
| `user-prompt-submit.sh` | `UserPromptSubmit` | 偵測 `/task-init` 建資料夾；依關鍵字注入「建議任務模式 + 建議 agent 鏈」（受 `.suggest-mode` 控制） |
| `pre-tool-use.sh` | `PreToolUse` `Write\|Edit` | 輕量記錄 tool 名到 `logs/hooks.log`（**已移除 Read**：高頻低價值） |
| `post-write.sh` | `PostToolUse` `Write\|Edit` | WBS 更新寫歷史；記錄寫入/編輯事件（hook 內按路徑過濾） |
| `agent-monitor.sh` | `Pre/PostToolUse` `Agent` | 記錄 subagent 啟動/完成（人類可讀 `agent-activity.log` + 結構化 `agent-activity.jsonl`） |
| `post-agent-report.sh` | `PostToolUse` `Agent` | 稽核需寫報告的 agent；掃描 `coordination/handoffs/` 的 pending 交接並注入主對話（受 `.suggest-mode` 控制） |
| `pre-compact.sh` | `PreCompact` | context 壓縮（manual/auto）前，將當前任務 / git 狀態 / 最近 agent 活動快照到 `sessions/auto-precompact-<ts>.md`（敘事式存檔仍用 `/save-session`） |
| `watch-agents.sh` | （手動）| `--summary` / `--last N` / `--json` / `--clear`；被 `/agent-log` 包裝 |

## ⚙️ 相關設定檔

- `.claude/taskmaster-data/.suggest-mode` — `high`/`medium`/`low`/`off`，控制意圖路由與 handoff 注入密度（預設 medium）。由 `/suggest-mode` 寫入。
- `.claude/taskmaster-data/.session-snapshot` / `.session-start` — 時間追蹤用。
- log 一律寫在 `.claude/logs/`（`hooks.log`、`agent-activity.log`、`agent-activity.jsonl`、`context-reports.log`）。

## 🧹 Log 輪替

`session-start.sh` 在**每次 session 啟動時**將各 log 截尾保留最後 N 行（`agent-activity.log` 8000、`.jsonl` 5000、`hooks.log` 2000、`context-reports.log` 1000）。集中在啟動做，避免在高頻 hook 中加 per-call 成本。

## 🔍 除錯與測試

```bash
# 查看 hook log
tail -n 50 .claude/logs/hooks.log

# 即時追蹤 agent 活動（另開終端）
bash .claude/hooks/watch-agents.sh
bash .claude/hooks/watch-agents.sh --summary

# 手動測試（hook 從 stdin 讀 JSON）
echo '{"hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"subagent_type":"planner","description":"x","prompt":"y"}}' \
  | bash .claude/hooks/agent-monitor.sh

# 除錯模式（部分腳本支援）
export TASKMASTER_DEBUG=true
```

## 🛠️ 撰寫新 Hook 的慣例

1. **不要用 `set -e`** — hook 不應因小錯中斷 Claude Code；以 `exit 0` 收尾，關鍵指令用 `|| true` 兜底。
2. **路徑用 `$CLAUDE_PROJECT_DIR`**（Claude Code 注入），fallback 才從 `BASH_SOURCE` 推算。
3. **jq 可能缺失** — `command -v jq || exit 0` 軟降級，不阻擋。
4. **效能** — hook 在主迴圈內同步執行；減少 process spawn（例如一次 jq 解析多欄位，而非逐欄呼叫）。
5. **避免在高頻事件做重活** — `Read`、`Edit` 觸發極頻繁；一次性工作（如 log 輪替）放 `SessionStart`。
6. **CWD 不污染** — 需要切目錄時用 subshell `(cd ... && ...)`（見 `.claude/rules/bash-cwd.md`）。

---

**設計原則**：所有 hook 皆為非侵入式——即使 hook 失敗，Claude Code 正常功能不受影響。
