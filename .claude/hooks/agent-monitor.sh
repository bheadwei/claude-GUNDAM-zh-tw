#!/bin/bash

# Agent Activity Monitor Hook
# 記錄所有 subagent 的啟動、prompt、結果和耗時
# 支援 PreToolUse、PostToolUse(Agent) 與 SubagentStop 事件
#
# 「誰在跑」這份帳由 agent_start / agent_complete 兩種 JSONL 事件構成，
# pre-agent-gate.sh 靠它算 in-flight。**對應鍵是 agent_id，不是 tool_use_id。**
#
# 為什麼不能用 PostToolUse 當「完成」（2026-09-11 實測，踩過）：
#   Agent 工具是**非同步**的——呼叫立刻返回 {"isAsync":true,"status":"async_launched"}。
#   所以 PostToolUse 的時機是「派工動作返回了」，不是「agent 做完了」。
#   實測 start→PostToolUse 間隔 2 秒，而那個 agent 實際跑了 44 分鐘。
#   結果是 in-flight 永遠算 0，閘門從裝上去那天就沒攔過任何一次。
#   真正的完成時機只有 SubagentStop 拿得到（它對非同步／背景 subagent 也會觸發）。
#
# 為什麼 agent_start 改在 PostToolUse 寫：`agentId` 只存在於 PostToolUse 的
# tool_response 裡，PreToolUse 拿不到。要和 SubagentStop 對得上就只能在這裡寫。
#
# 不使用 set -e：hook 不應因小錯而失敗
#
# 效能：每個事件 3 次 jq 呼叫
#   (1) 一次 @tsv 解析所有純量 metadata
#   (2) 一次抽出 prompt/response（可能很長/多行，需單獨處理）
#   (3) 一次直接從原始 INPUT 產生 JSONL（不經 shell 變數 round-trip）
# 唯一的例外是同步完成的 agent（PostToolUse 拿不到 agentId），
# 那一條路徑要多寫一筆 agent_complete，共 4 次。

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
#
# AGENT_ID 的來源依事件而異，一條 jq 表達式同時覆蓋兩邊：
#   PostToolUse  → .tool_response.agentId（`objects` 是必要的防護：同步完成時
#                  tool_response 也是物件但沒有 agentId，而若哪天變成字串，
#                  直接 .tool_response.agentId 會讓整個 jq 報錯並吃掉這筆紀錄）
#   SubagentStop → .agent_id（payload 裡**沒有** agentId 駝峰欄位，值為 null）
# 兩者實測是同一個值，所以能對得上。
IFS=$'\t' read -r EVENT TOOL_NAME SESSION_ID AGENT_TYPE DESCRIPTION MODEL BACKGROUND TOOL_USE_ID AGENT_ID < <(
    echo "$INPUT" | jq -r '[
        .hook_event_name              // "unknown",
        .tool_name                    // "unknown",
        .session_id                   // "unknown",
        (if (.tool_input.subagent_type // "") != "" then .tool_input.subagent_type
         elif (.agent_type // "")            != "" then .agent_type
         elif .hook_event_name == "SubagentStop"   then "unknown"
         else "general-purpose" end),
        .tool_input.description        // "N/A",
        .tool_input.model              // "inherited",
        (.tool_input.run_in_background // false | tostring),
        .tool_use_id                  // "unknown",
        (((.tool_response | objects | .agentId) // .agent_id // ""))
    ] | @tsv' 2>/dev/null | tr -d '\r'
)
# tr -d '\r'：Git Bash 下 jq 輸出 CRLF，最後一個欄位會夾帶 \r。
# 以前最後一欄是 TOOL_USE_ID、只用於截斷顯示，看不出問題；現在 AGENT_ID
# 要拿來比對與判空（`[ -z "$AGENT_ID" ]`），帶 \r 會讓同步分支永遠走錯邊。

# 只處理 Agent 工具。SubagentStop 沒有 tool_name，不能被這道過濾器擋掉。
if [ "$EVENT" != "SubagentStop" ]; then
    [ "$TOOL_NAME" != "Agent" ] && exit 0
fi

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

        # 這裡**刻意不寫 JSONL 的 agent_start**。
        # agent_id 只在 PostToolUse 的 tool_response 裡拿得到，而 agent_start／
        # agent_complete 必須用同一個鍵才對得上（見檔頭）。人類可讀 log 仍寫在
        # 派工當下——prompt 是這個時點最有價值的資訊。
        echo "[$TIMESTAMP] Agent START: $AGENT_TYPE - $DESCRIPTION" >&2
        ;;

    "PostToolUse")
        # 派工動作返回了。**這不代表 agent 做完了**（見檔頭）。
        # 這裡的職責是：把 agent_id 記進帳，讓 SubagentStop 有東西可以沖銷。
        RESPONSE=$(echo "$INPUT" | jq -r '(.tool_response | objects | .response) // .tool_response // "no response"' 2>/dev/null)
        RESPONSE_PREVIEW=$(printf '%s' "$RESPONSE" | head -c 800)
        [ ${#RESPONSE} -gt 800 ] && RESPONSE_PREVIEW="${RESPONSE_PREVIEW}... [truncated, total ${#RESPONSE} chars]"

        # 沒有 agentId → 這次是**同步完成**的 agent（tool_response 只帶結果，
        # 實測形如 {"status":"completed",...}）。它在 PostToolUse 觸發時就已經結束，
        # 不會再有 SubagentStop 來沖銷，所以 start 與 complete 一起寫、in-flight 淨變化 0。
        # 鍵退回 tool_use_id：反正這一對是自己配對，不需要跨事件對應。
        AG_SYNC=0
        if [ -z "$AGENT_ID" ]; then
            AG_SYNC=1
            AGENT_ID="$TOOL_USE_ID"
        fi

        {
            echo ""
            echo "================================================================"
            [ "$AG_SYNC" = 1 ] \
                && echo "[$TIMESTAMP] AGENT COMPLETE (sync)" \
                || echo "[$TIMESTAMP] AGENT DISPATCHED (async, 尚未完成)"
            echo "----------------------------------------------------------------"
            echo "  Type:        $AGENT_TYPE"
            echo "  Description: $DESCRIPTION"
            echo "  Agent ID:    $AGENT_ID"
            echo "----------------------------------------------------------------"
            echo "  Result:"
            echo "$RESPONSE_PREVIEW" | sed 's/^/    /'
            echo "================================================================"
        } >> "$LOG_FILE" 2>/dev/null || true

        # === (3) 直接從原始 INPUT 產生 JSONL（單次 jq）===
        echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" --arg aid "$AGENT_ID" '{
            timestamp: $ts,
            event: "agent_start",
            agent_type: (.tool_input.subagent_type // "general-purpose"),
            description: (.tool_input.description // "N/A"),
            model: (.tool_input.model // "inherited"),
            background: (.tool_input.run_in_background // false),
            session_id: (.session_id // "unknown"),
            tool_use_id: (.tool_use_id // "unknown"),
            agent_id: $aid,
            prompt: (.tool_input.prompt // "N/A")
        }' >> "$LOG_JSONL" 2>/dev/null || true

        if [ "$AG_SYNC" = 1 ]; then
            echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" --arg aid "$AGENT_ID" '
                ((.tool_response | objects | .response) // .tool_response // "no response") as $resp | {
                timestamp: $ts,
                event: "agent_complete",
                agent_type: (.tool_input.subagent_type // "general-purpose"),
                description: (.tool_input.description // "N/A"),
                session_id: (.session_id // "unknown"),
                tool_use_id: (.tool_use_id // "unknown"),
                agent_id: $aid,
                response_length: ($resp | tostring | length),
                response: $resp
            }' >> "$LOG_JSONL" 2>/dev/null || true
        fi

        echo "[$TIMESTAMP] Agent DISPATCHED: $AGENT_TYPE - $DESCRIPTION" >&2
        ;;

    "SubagentStop")
        # agent **真正**結束了。這是唯一可靠的完成時機。
        #
        # 兩個實測會遇到、必須安靜容忍的情況：
        #   1. agent_type 是空字串 —— 不能因此跳過寫入，否則那個 agent 的
        #      in-flight 永遠不會歸零，閘門會從此誤擋每一次委派
        #   2. agent_id 是本 session 從沒派過的 —— 照寫即可。閘門算的是
        #      「有 start 卻沒有 complete」，多出來的 complete 不影響任何計數，
        #      也不可能讓計數變成負數
        [ -z "$AGENT_ID" ] && exit 0

        RESPONSE=$(echo "$INPUT" | jq -r '.last_assistant_message // "no response"' 2>/dev/null)
        RESPONSE_PREVIEW=$(printf '%s' "$RESPONSE" | head -c 800)
        [ ${#RESPONSE} -gt 800 ] && RESPONSE_PREVIEW="${RESPONSE_PREVIEW}... [truncated, total ${#RESPONSE} chars]"

        {
            echo ""
            echo "================================================================"
            echo "[$TIMESTAMP] AGENT COMPLETE"
            echo "----------------------------------------------------------------"
            echo "  Type:        $AGENT_TYPE"
            echo "  Agent ID:    $AGENT_ID"
            echo "----------------------------------------------------------------"
            echo "  Result:"
            echo "$RESPONSE_PREVIEW" | sed 's/^/    /'
            echo "================================================================"
        } >> "$LOG_FILE" 2>/dev/null || true

        echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" --arg aid "$AGENT_ID" --arg at "$AGENT_TYPE" '
            (.last_assistant_message // "no response") as $resp | {
            timestamp: $ts,
            event: "agent_complete",
            agent_type: $at,
            description: "N/A",
            session_id: (.session_id // "unknown"),
            agent_id: $aid,
            response_length: ($resp | tostring | length),
            response: $resp
        }' >> "$LOG_JSONL" 2>/dev/null || true

        echo "[$TIMESTAMP] Agent COMPLETE: $AGENT_TYPE ($AGENT_ID)" >&2
        ;;
esac

exit 0
