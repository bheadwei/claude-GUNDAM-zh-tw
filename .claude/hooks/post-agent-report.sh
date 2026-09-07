#!/bin/bash
# post-agent-report.sh — PostToolUse(Agent) hook
#
# 兩個職責：
#   (1) 報告稽核：非同步啟動的 agent（tool_response 帶 "status":"async_launched"）
#       在此刻還沒動工，立即 find 必定假警報 → 只記下「期望」，交由
#       lib/check-report-expectations.sh 在後續對話邊界重新檢查並**注入**要求補寫。
#       同步完成的 agent 仍在當下稽核。
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

PAYLOAD=$(cat 2>/dev/null || echo '{}')

source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$PAYLOAD"
else
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    MAIN_CLAUDE="$MAIN_ROOT/.claude"; WORK_ROOT="$MAIN_ROOT"; WORK_CLAUDE="$MAIN_CLAUDE"; IN_WORKTREE=0
fi

PROJECT_ROOT="$MAIN_ROOT"
CLAUDE_DIR="$MAIN_CLAUDE"                      # 報告與交接跨 worktree 共享
LOG_FILE="$CLAUDE_DIR/logs/context-reports.log"
HANDOFF_DIR="$CLAUDE_DIR/coordination/handoffs"
WORK_DATA="$WORK_CLAUDE/taskmaster-data"       # 報告期望：每個 worktree 各自
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
AGENT_NAME=$(echo "$PAYLOAD" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || echo "")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ============================================================================
# (1) 報告稽核 — 只對需寫報告的 agent
# ============================================================================
# 這張表必須與各 agent 檔「結束後（必須）」的「寫入報告到」路徑一致。
# 改 agent 的報告落點時要同步這裡，否則稽核會永遠找不到報告（見 CLAUDE.md 連帶檢查）。
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
    debug-investigator)               AREA="quality" ;;
esac

# quick 模式下 tdd-guide 刻意不寫報告（小任務不值得這開銷）→ 不稽核，避免假警報
if [ "$AGENT_NAME" = "tdd-guide" ]; then
    TM_FILE="$WORK_DATA/.current-task-mode"
    if [ -f "$TM_FILE" ] && [ "$(tr -d '[:space:]' < "$TM_FILE" 2>/dev/null)" = "quick" ]; then
        AREA=""
    fi
fi

if [ -n "$AREA" ]; then
    CONTEXT_DIR="$CLAUDE_DIR/context/$AREA"
    mkdir -p "$CONTEXT_DIR" 2>/dev/null || true

    # 非同步啟動判定：tool_response 可能是物件也可能是 JSON 字串，一律轉字串再比對
    RESP=$(echo "$PAYLOAD" | jq -r '(.tool_response.response // .tool_response // "") | tostring' 2>/dev/null || echo "")
    IS_ASYNC=0
    case "$RESP" in
        *async_launched*|*'"isAsync": true'*|*'"isAsync":true'*) IS_ASYNC=1 ;;
    esac

    if [ "$IS_ASYNC" = "1" ]; then
        # 此刻 agent 還沒動工，立即 find 必定假警報 → 記下期望，延後稽核
        EXPECT_FILE="$WORK_DATA/.report-expectations.jsonl"
        mkdir -p "$(dirname "$EXPECT_FILE")" 2>/dev/null || true
        jq -nc --arg a "$AGENT_NAME" --arg ar "$AREA" --arg ts "$TIMESTAMP" \
               --argjson ep "$(date +%s)" \
            '{ts:$ts, epoch:$ep, agent:$a, area:$ar, notified:0}' \
            >> "$EXPECT_FILE" 2>/dev/null || true
        echo "[$TIMESTAMP] DEFER: $AGENT_NAME 非同步啟動，報告稽核延後" >> "$LOG_FILE" 2>/dev/null || true
    else
        RECENT_REPORT=$(find "$CONTEXT_DIR" -maxdepth 1 -name "${AGENT_NAME}-*.md" -mmin -5 2>/dev/null | head -1)
        if [ -z "$RECENT_REPORT" ]; then
            echo "[$TIMESTAMP] WARN: $AGENT_NAME completed but no report written to context/$AREA/" >> "$LOG_FILE" 2>/dev/null || true
        else
            echo "[$TIMESTAMP] OK: $AGENT_NAME wrote $(basename "$RECENT_REPORT")" >> "$LOG_FILE" 2>/dev/null || true
        fi
    fi
fi

# 延後稽核：檢查先前記下的期望，缺報告則產生要求補寫的文字（可能為空）
REPORT_AUDIT_MSG=$(bash "$(dirname "${BASH_SOURCE[0]}")/lib/check-report-expectations.sh" "$WORK_CLAUDE" "$MAIN_CLAUDE" 2>/dev/null || echo "")

# ============================================================================
# (2) Pending handoff 掃描 + 注入
# ============================================================================

# 讀 suggest-mode（預設 medium）
SUGGEST_MODE="medium"
SM_FILE="$MAIN_CLAUDE/taskmaster-data/.suggest-mode"
if [ -f "$SM_FILE" ]; then
    SUGGEST_MODE=$(tr -d '[:space:]' < "$SM_FILE" 2>/dev/null || echo "medium")
    [ -z "$SUGGEST_MODE" ] && SUGGEST_MODE="medium"
fi

# off → 完全不注入（連報告稽核也一併靜音，這是文件化的逃生門）
[ "$SUGGEST_MODE" = "off" ] && exit 0

NL=$'\n'
LINES=""
COUNT=0

# handoff 目錄不存在時仍要讓報告稽核有機會注入 → 用 if 包住掃描而非 exit
[ -d "$HANDOFF_DIR" ] && for f in "$HANDOFF_DIR"/*.md; do
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

MSG=""

if [ "$COUNT" -gt 0 ]; then
    MSG="🔗 偵測到 ${COUNT} 個待處理 agent 交接（status: pending）。若符合當前目標，建議啟動對應的「to」agent 接手——各 agent 啟動時會自行讀取其 handoff 工作清單：${LINES}${NL}${NL}完成後請將對應 handoff 的 status 改為 completed（保留檔案作審計軌跡）。"
fi

if [ -n "$REPORT_AUDIT_MSG" ]; then
    [ -n "$MSG" ] && MSG="${MSG}${NL}${NL}"
    MSG="${MSG}${REPORT_AUDIT_MSG}"
fi

[ -z "$MSG" ] && exit 0

jq -n --arg ctx "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'

exit 0
