#!/bin/bash

# Agent Activity Monitor Hook
# 記錄所有 subagent 的啟動、prompt、結果和耗時
# 支援 PreToolUse 和 PostToolUse 事件
#
# 不使用 set -e：hook 不應因小錯而失敗
#
# 效能：每個事件僅 3 次 jq 呼叫
#   (1) 一次 @tsv 解析所有純量 metadata
#   (2) 一次抽出 prompt/response（可能很長/多行，需單獨處理）
#   (3) 一次直接從原始 INPUT 產生 JSONL（不經 shell 變數 round-trip）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd 2>/dev/null)}" || PROJECT_ROOT="."
LOG_DIR="$PROJECT_ROOT/.claude/logs"
LOG_FILE="$LOG_DIR/agent-activity.log"
LOG_JSONL="$LOG_DIR/agent-activity.jsonl"

mkdir -p "$LOG_DIR" 2>/dev/null || true

INPUT=$(cat)

# jq 不可用 → 軟降級（不阻擋）
if ! command -v jq >/dev/null 2>&1; then
    echo "[WARN] jq not found, agent monitoring disabled" >&2
    exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# === (1) 單次 @tsv 解析所有純量 metadata ===
# @tsv 會把資料中的 tab/newline 轉義為 \t / \n，欄位不會錯位
IFS=$'\t' read -r EVENT TOOL_NAME SESSION_ID AGENT_TYPE DESCRIPTION MODEL BACKGROUND TOOL_USE_ID < <(
    echo "$INPUT" | jq -r '[
        .hook_event_name              // "unknown",
        .tool_name                    // "unknown",
        .session_id                   // "unknown",
        .tool_input.subagent_type     // "general-purpose",
        .tool_input.description        // "N/A",
        .tool_input.model              // "inherited",
        (.tool_input.run_in_background // false | tostring),
        .tool_use_id                  // "unknown"
    ] | @tsv' 2>/dev/null
)

# 只處理 Agent 工具
[ "$TOOL_NAME" != "Agent" ] && exit 0

case "$EVENT" in
    "PreToolUse")
        # === (2) 抽出 prompt（可能很長/多行）並截斷供人類可讀 log ===
        PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // "N/A"' 2>/dev/null)
        PROMPT_PREVIEW=$(printf '%s' "$PROMPT" | head -c 500)
        [ ${#PROMPT} -gt 500 ] && PROMPT_PREVIEW="${PROMPT_PREVIEW}... [truncated, total ${#PROMPT} chars]"

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
        } >> "$LOG_FILE" 2>/dev/null || true

        # === (3) 直接從原始 INPUT 產生 JSONL（單次 jq，不經 shell 變數）===
        echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" '{
            timestamp: $ts,
            event: "agent_start",
            agent_type: (.tool_input.subagent_type // "general-purpose"),
            description: (.tool_input.description // "N/A"),
            model: (.tool_input.model // "inherited"),
            background: (.tool_input.run_in_background // false),
            session_id: (.session_id // "unknown"),
            tool_use_id: (.tool_use_id // "unknown"),
            prompt: (.tool_input.prompt // "N/A")
        }' >> "$LOG_JSONL" 2>/dev/null || true

        echo "[$TIMESTAMP] Agent START: $AGENT_TYPE - $DESCRIPTION" >&2
        ;;

    "PostToolUse")
        # === (2) 抽出 response 並截斷供人類可讀 log ===
        RESPONSE=$(echo "$INPUT" | jq -r '.tool_response.response // .tool_response // "no response"' 2>/dev/null)
        RESPONSE_PREVIEW=$(printf '%s' "$RESPONSE" | head -c 800)
        [ ${#RESPONSE} -gt 800 ] && RESPONSE_PREVIEW="${RESPONSE_PREVIEW}... [truncated, total ${#RESPONSE} chars]"

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
        } >> "$LOG_FILE" 2>/dev/null || true

        # === (3) 直接從原始 INPUT 產生 JSONL（單次 jq）===
        echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" '
            (.tool_response.response // .tool_response // "no response") as $resp | {
            timestamp: $ts,
            event: "agent_complete",
            agent_type: (.tool_input.subagent_type // "general-purpose"),
            description: (.tool_input.description // "N/A"),
            session_id: (.session_id // "unknown"),
            tool_use_id: (.tool_use_id // "unknown"),
            response_length: ($resp | tostring | length),
            response: $resp
        }' >> "$LOG_JSONL" 2>/dev/null || true

        echo "[$TIMESTAMP] Agent COMPLETE: $AGENT_TYPE - $DESCRIPTION" >&2
        ;;
esac

exit 0
