#!/bin/bash
# post-agent-report.sh — PostToolUse(Agent) hook
#
# 兩個職責：
#   (1) 報告稽核：驗證需寫報告的 agent 是否依規範寫入 context 報告（沿用，僅記 log）
#   (2) Handoff 主動化：掃描 coordination/handoffs/ 的 pending 交接，
#       透過 hookSpecificOutput.additionalContext 注入主對話，
#       讓主模型「看見」待處理交接並據以啟動下一棒 agent。
#
# 注入格式依 Claude Code hook 規格：exit 0 + JSON。
# 受 .suggest-mode 控制：off→不注入、low→僅 high priority、medium/high→全部。
#
# 不使用 set -e：hook 不應因小錯而失敗。

set -uo pipefail

# jq 不存在 → 軟降級直接退出（不阻擋）
command -v jq >/dev/null 2>&1 || exit 0

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
LOG_FILE="$CLAUDE_DIR/logs/context-reports.log"
HANDOFF_DIR="$CLAUDE_DIR/coordination/handoffs"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

PAYLOAD=$(cat 2>/dev/null || echo '{}')
AGENT_NAME=$(echo "$PAYLOAD" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || echo "")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ============================================================================
# (1) 報告稽核 — 只對需寫報告的 agent
# ============================================================================
AREA=""
case "$AGENT_NAME" in
    code-quality-specialist)          AREA="quality" ;;
    security-infrastructure-auditor)  AREA="security" ;;
    test-automation-engineer)         AREA="testing" ;;
    e2e-validation-specialist)        AREA="e2e" ;;
    planner)                          AREA="planning" ;;
    architect)                        AREA="decisions" ;;
    tdd-guide)                        AREA="testing" ;;
    refactor-cleaner)                 AREA="quality" ;;
    ui-builder)                       AREA="quality" ;;
    deployment-expert)                AREA="deployment" ;;
esac

# quick 模式下 tdd-guide 刻意不寫報告（小任務不值得這開銷）→ 不稽核，避免假警報
if [ "$AGENT_NAME" = "tdd-guide" ]; then
    TM_FILE="$CLAUDE_DIR/taskmaster-data/.current-task-mode"
    if [ -f "$TM_FILE" ] && [ "$(tr -d '[:space:]' < "$TM_FILE" 2>/dev/null)" = "quick" ]; then
        AREA=""
    fi
fi

if [ -n "$AREA" ]; then
    CONTEXT_DIR="$CLAUDE_DIR/context/$AREA"
    mkdir -p "$CONTEXT_DIR" 2>/dev/null || true
    RECENT_REPORT=$(find "$CONTEXT_DIR" -maxdepth 1 -name "${AGENT_NAME}-*.md" -mmin -5 2>/dev/null | head -1)
    if [ -z "$RECENT_REPORT" ]; then
        echo "[$TIMESTAMP] WARN: $AGENT_NAME completed but no report written to context/$AREA/" >> "$LOG_FILE" 2>/dev/null || true
    else
        echo "[$TIMESTAMP] OK: $AGENT_NAME wrote $(basename "$RECENT_REPORT")" >> "$LOG_FILE" 2>/dev/null || true
    fi
fi

# ============================================================================
# (2) Pending handoff 掃描 + 注入
# ============================================================================

# 讀 suggest-mode（預設 medium）
SUGGEST_MODE="medium"
SM_FILE="$CLAUDE_DIR/taskmaster-data/.suggest-mode"
if [ -f "$SM_FILE" ]; then
    SUGGEST_MODE=$(tr -d '[:space:]' < "$SM_FILE" 2>/dev/null || echo "medium")
    [ -z "$SUGGEST_MODE" ] && SUGGEST_MODE="medium"
fi

# off → 完全不注入
[ "$SUGGEST_MODE" = "off" ] && exit 0
[ -d "$HANDOFF_DIR" ] || exit 0

NL=$'\n'
LINES=""
COUNT=0

for f in "$HANDOFF_DIR"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = "_HANDOFF_TEMPLATE.md" ] && continue

    status=$(grep -m1 '^status:' "$f" 2>/dev/null | sed 's/^status:[[:space:]]*//' | tr -d '\r')
    case "$status" in *pending*) ;; *) continue ;; esac

    to=$(grep -m1 '^to:'       "$f" 2>/dev/null | sed 's/^to:[[:space:]]*//'       | tr -d '\r')
    from=$(grep -m1 '^from:'   "$f" 2>/dev/null | sed 's/^from:[[:space:]]*//'     | tr -d '\r')
    prio=$(grep -m1 '^priority:' "$f" 2>/dev/null | sed 's/^priority:[[:space:]]*//' | tr -d '\r')
    [ -z "$prio" ] && prio="medium"

    # low 模式只顯示 high priority
    if [ "$SUGGEST_MODE" = "low" ]; then
        case "$prio" in high|HIGH) ;; *) continue ;; esac
    fi

    # 起因：抓「## 起因」後第一行非空白
    reason=$(awk '/^## 起因/{getline; while($0 ~ /^[[:space:]]*$/ && (getline)>0){}; print; exit}' "$f" 2>/dev/null | tr -d '\r')
    [ -z "$reason" ] && reason="(見交接檔)"

    LINES="${LINES}${NL}  • [${prio}] ${from} → ${to}（$(basename "$f")）：${reason}"
    COUNT=$((COUNT + 1))
    [ "$COUNT" -ge 5 ] && break
done

[ "$COUNT" -eq 0 ] && exit 0

MSG="🔗 偵測到 ${COUNT} 個待處理 agent 交接（status: pending）。若符合當前目標，建議啟動對應的「to」agent 接手——各 agent 啟動時會自行讀取其 handoff 工作清單：${LINES}${NL}${NL}完成後請將對應 handoff 的 status 改為 completed（保留檔案作審計軌跡）。"

jq -n --arg ctx "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'

exit 0
