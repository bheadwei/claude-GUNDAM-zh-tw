#!/bin/bash

# Agent Activity Real-time Monitor
# 用法: bash .claude/hooks/watch-agents.sh [options]
#
# Options:
#   --json     顯示結構化 JSONL 格式
#   --last N   顯示最近 N 行記錄
#   --clear    清除所有 log

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.claude/logs"
LOG_FILE="$LOG_DIR/agent-activity.log"
LOG_JSONL="$LOG_DIR/agent-activity.jsonl"

case "${1:-}" in
    --json)
        echo "Watching JSONL log (Ctrl+C to stop)..."
        echo ""
        tail -f "$LOG_JSONL" 2>/dev/null | while IFS= read -r line; do
            echo "$line" | jq '.' 2>/dev/null || echo "$line"
        done
        ;;
    --last)
        N="${2:-20}"
        echo "=== Last $N agent activities ==="
        echo ""
        tail -n "$N" "$LOG_FILE" 2>/dev/null || echo "No log file yet."
        ;;
    --clear)
        rm -f "$LOG_FILE" "$LOG_JSONL"
        echo "Agent activity logs cleared."
        ;;
    --summary)
        echo "=== Agent Activity Summary ==="
        echo ""
        if [ -f "$LOG_JSONL" ]; then
            echo "Total events: $(wc -l < "$LOG_JSONL")"
            echo ""
            echo "By agent type:"
            jq -r '.agent_type' "$LOG_JSONL" 2>/dev/null | sort | uniq -c | sort -rn
            echo ""
            echo "By event:"
            jq -r '.event' "$LOG_JSONL" 2>/dev/null | sort | uniq -c | sort -rn
        else
            echo "No activity recorded yet."
        fi
        ;;
    *)
        echo "Watching agent activity log (Ctrl+C to stop)..."
        echo "Tip: Open a separate terminal and run this command"
        echo ""
        # 顯示既有內容 + 即時追蹤
        tail -f "$LOG_FILE" 2>/dev/null || {
            echo "No log file yet. Waiting for first agent activity..."
            # 等待檔案建立
            while [ ! -f "$LOG_FILE" ]; do sleep 1; done
            tail -f "$LOG_FILE"
        }
        ;;
esac
