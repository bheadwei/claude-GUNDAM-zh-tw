#!/bin/bash
# post-agent-report.sh
# 在 Agent 工具完成後，驗證 agent 是否依照規範寫入了 context 報告
# 不阻擋執行，僅記錄警告供下次參考

set -uo pipefail

# 軟降級：jq 不存在則直接退出
command -v jq >/dev/null 2>&1 || exit 0

# 取得專案根目錄（優先用 Claude Code 提供的環境變數）
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LOG_FILE="$PROJECT_ROOT/.claude/logs/context-reports.log"
mkdir -p "$(dirname "$LOG_FILE")"

# 從 stdin 讀 hook payload
PAYLOAD=$(cat 2>/dev/null || echo '{}')

# 嘗試解析被呼叫的 agent 名稱
AGENT_NAME=$(echo "$PAYLOAD" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)

# 沒有 agent 名稱就退出（不是我們關心的 agent 呼叫）
[ -z "$AGENT_NAME" ] && exit 0

# 只關注需要寫報告的 agent
case "$AGENT_NAME" in
    code-quality-specialist|security-infrastructure-auditor|test-automation-engineer|e2e-validation-specialist)
        ;;
    *)
        exit 0
        ;;
esac

# 對應的 context area
case "$AGENT_NAME" in
    code-quality-specialist) AREA="quality" ;;
    security-infrastructure-auditor) AREA="security" ;;
    test-automation-engineer) AREA="testing" ;;
    e2e-validation-specialist) AREA="e2e" ;;
esac

CONTEXT_DIR="$PROJECT_ROOT/.claude/context/$AREA"
mkdir -p "$CONTEXT_DIR"

# 檢查最近 5 分鐘內是否有此 agent 的新報告
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
RECENT_REPORT=$(find "$CONTEXT_DIR" -maxdepth 1 -name "${AGENT_NAME}-*.md" -mmin -5 2>/dev/null | head -1)

if [ -z "$RECENT_REPORT" ]; then
    echo "[$TIMESTAMP] WARN: $AGENT_NAME completed but no report written to context/$AREA/" >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] OK: $AGENT_NAME wrote $(basename "$RECENT_REPORT")" >> "$LOG_FILE"
fi

exit 0
