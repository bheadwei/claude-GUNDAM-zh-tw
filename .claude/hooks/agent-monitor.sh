#!/bin/bash

# Agent Activity Monitor Hook
# 記錄所有 subagent 的啟動、prompt、結果和耗時
# 支援 PreToolUse 和 PostToolUse 事件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.claude/logs"
LOG_FILE="$LOG_DIR/agent-activity.log"
LOG_JSONL="$LOG_DIR/agent-activity.jsonl"

# 確保 log 目錄存在
mkdir -p "$LOG_DIR"

# 從 stdin 讀取 hook 輸入 JSON
INPUT=$(cat)

# 檢查 jq 是否可用
if ! command -v jq >/dev/null 2>&1; then
    echo "[WARN] jq not found, agent monitoring disabled" >&2
    exit 0
fi

# 解析共用欄位
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 只處理 Agent 工具
if [ "$TOOL_NAME" != "Agent" ]; then
    exit 0
fi

# 解析 Agent 特有欄位
AGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // "general-purpose"')
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // "N/A"')
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // "N/A"')
MODEL=$(echo "$INPUT" | jq -r '.tool_input.model // "inherited"')
BACKGROUND=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // false')
TOOL_USE_ID=$(echo "$INPUT" | jq -r '.tool_use_id // "unknown"')

# 截斷過長的 prompt（保留前 500 字元）
PROMPT_PREVIEW=$(echo "$PROMPT" | head -c 500)
if [ ${#PROMPT} -gt 500 ]; then
    PROMPT_PREVIEW="${PROMPT_PREVIEW}... [truncated, total ${#PROMPT} chars]"
fi

case "$EVENT" in
    "PreToolUse")
        # === 人類可讀 log ===
        {
            echo ""
            echo "================================================================"
            echo "[$TIMESTAMP] AGENT START"
            echo "----------------------------------------------------------------"
            echo "  Type:        $AGENT_TYPE"
            echo "  Description: $DESCRIPTION"
            echo "  Model:       $MODEL"
            echo "  Background:  $BACKGROUND"
            echo "  Session:     ${SESSION_ID:0:12}..."
            echo "  Tool Use ID: ${TOOL_USE_ID:0:16}..."
            echo "----------------------------------------------------------------"
            echo "  Prompt:"
            echo "$PROMPT_PREVIEW" | sed 's/^/    /'
            echo "================================================================"
        } >> "$LOG_FILE"

        # === 結構化 JSONL log ===
        jq -n \
            --arg ts "$TIMESTAMP" \
            --arg event "agent_start" \
            --arg agent_type "$AGENT_TYPE" \
            --arg description "$DESCRIPTION" \
            --arg model "$MODEL" \
            --arg background "$BACKGROUND" \
            --arg session "$SESSION_ID" \
            --arg tool_use_id "$TOOL_USE_ID" \
            --arg prompt "$PROMPT" \
            '{
                timestamp: $ts,
                event: $event,
                agent_type: $agent_type,
                description: $description,
                model: $model,
                background: ($background == "true"),
                session_id: $session,
                tool_use_id: $tool_use_id,
                prompt: $prompt
            }' >> "$LOG_JSONL"

        # stderr 輸出（verbose 模式可見）
        echo "[$TIMESTAMP] Agent START: $AGENT_TYPE - $DESCRIPTION" >&2
        ;;

    "PostToolUse")
        # 解析回應
        RESPONSE=$(echo "$INPUT" | jq -r '.tool_response.response // .tool_response // "no response"')
        RESPONSE_PREVIEW=$(echo "$RESPONSE" | head -c 800)
        if [ ${#RESPONSE} -gt 800 ]; then
            RESPONSE_PREVIEW="${RESPONSE_PREVIEW}... [truncated, total ${#RESPONSE} chars]"
        fi

        # === 人類可讀 log ===
        {
            echo ""
            echo "================================================================"
            echo "[$TIMESTAMP] AGENT COMPLETE"
            echo "----------------------------------------------------------------"
            echo "  Type:        $AGENT_TYPE"
            echo "  Description: $DESCRIPTION"
            echo "  Tool Use ID: ${TOOL_USE_ID:0:16}..."
            echo "----------------------------------------------------------------"
            echo "  Result:"
            echo "$RESPONSE_PREVIEW" | sed 's/^/    /'
            echo "================================================================"
        } >> "$LOG_FILE"

        # === 結構化 JSONL log ===
        jq -n \
            --arg ts "$TIMESTAMP" \
            --arg event "agent_complete" \
            --arg agent_type "$AGENT_TYPE" \
            --arg description "$DESCRIPTION" \
            --arg session "$SESSION_ID" \
            --arg tool_use_id "$TOOL_USE_ID" \
            --arg response "$RESPONSE" \
            '{
                timestamp: $ts,
                event: $event,
                agent_type: $agent_type,
                description: $description,
                session_id: $session,
                tool_use_id: $tool_use_id,
                response_length: ($response | length),
                response: $response
            }' >> "$LOG_JSONL"

        echo "[$TIMESTAMP] Agent COMPLETE: $AGENT_TYPE - $DESCRIPTION" >&2
        ;;
esac

exit 0
