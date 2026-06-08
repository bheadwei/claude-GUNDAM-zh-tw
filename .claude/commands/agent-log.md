---
description: 查看 subagent 的活動軌跡、產出報告與交接決策（包裝 watch-agents.sh 與 context/handoffs 查詢）。
---

# /agent-log — Subagent 觀測

快速查看 subagent 的**進度、內容、決策**。依 `$ARGUMENTS` 分流；無參數時給總覽。

## 分流

讀 `$ARGUMENTS` 第一個 token：

| 參數 | 行為 |
|---|---|
| （空） | 總覽：先跑 `summary`，再列 `last 10` |
| `summary` | 統計：各 agent 跑幾次、事件數 |
| `last [N]` | 最近 N 筆活動（預設 20，含 prompt + 結果摘要） |
| `watch` | 提示使用者**另開終端**執行即時追蹤指令（slash 指令不適合長駐 tail -f） |
| `reports` | 列出 `.claude/context/<領域>/` 所有報告，並顯示**最新一份**內容 |
| `handoffs` | 列出 `.claude/coordination/handoffs/` 的交接，標出 `status: pending` |
| `<agent-name>` | 用 jq 過濾該 agent 的所有活動（例：`/agent-log security-infrastructure-auditor`） |
| `clear` | 詢問確認後清空活動 log |

## 執行對應指令

> 路徑一律以專案根的 `.claude/` 為基準（用絕對或 `$CLAUDE_PROJECT_DIR`）。Windows 走 Git Bash。

### 總覽 / summary
```bash
bash "$CLAUDE_PROJECT_DIR/.claude/hooks/watch-agents.sh" --summary
```

### last [N]
```bash
bash "$CLAUDE_PROJECT_DIR/.claude/hooks/watch-agents.sh" --last "${N:-20}"
```

### watch（告知使用者自行執行）
```
請另開一個終端執行（即時追蹤，Ctrl+C 結束）：
  bash .claude/hooks/watch-agents.sh
```

### reports
```bash
# 列出所有報告
find "$CLAUDE_PROJECT_DIR/.claude/context" -name "*.md" \
  -not -name "_*" -not -path "*_archive*" -not -name "README*" 2>/dev/null | sort
# 顯示最新一份
latest=$(find "$CLAUDE_PROJECT_DIR/.claude/context" -name "*.md" \
  -not -name "_*" -not -path "*_archive*" -not -name "README*" 2>/dev/null \
  -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
[ -n "$latest" ] && cat "$latest"
```

### handoffs
```bash
for f in "$CLAUDE_PROJECT_DIR/.claude/coordination/handoffs/"*.md; do
  [ -e "$f" ] || continue
  [ "$(basename "$f")" = "_HANDOFF_TEMPLATE.md" ] && continue
  status=$(grep -m1 '^status:' "$f" | sed 's/^status:[[:space:]]*//')
  echo "[$status] $(basename "$f")"
done
```

### <agent-name>
```bash
# 原生 streaming jq（jsonl 為多物件串流，不可逐行 fromjson）
jq -r --arg a "$ARGUMENTS" \
  'select(.agent_type==$a) | "\(.timestamp) \(.event) — \(.description)"' \
  "$CLAUDE_PROJECT_DIR/.claude/logs/agent-activity.jsonl"
```

### clear
先用 `AskUserQuestion` 確認，再：
```bash
bash "$CLAUDE_PROJECT_DIR/.claude/hooks/watch-agents.sh" --clear
```

## 輸出原則

- 用表格或清單呈現，**摘要重點**（不要把整份 jsonl 貼出來）
- 結果為空時，明確說「目前尚無紀錄」並提示對應原因（例：context 報告需鏈上 agent 跑過才會有）
- 若 `jq` 不存在，提示安裝（見 `session-start.sh` 的健檢訊息）

## 相關

- `.claude/hooks/agent-monitor.sh` — 自動記錄來源
- `.claude/hooks/watch-agents.sh` — 底層查詢腳本
- `.claude/context/` / `.claude/coordination/handoffs/` — 報告與交接
- `.claude/rules/agent-orchestration.md` — 編排劇本
