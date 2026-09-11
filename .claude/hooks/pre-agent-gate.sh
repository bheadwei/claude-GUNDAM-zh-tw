#!/bin/bash
# Pre Agent Gate — PreToolUse(Agent)
#
# 職責：擋下「同時派多個沒有隔離的 subagent」。
#
# 為什麼需要：沒帶 isolation 的 subagent 全部在**同一個工作目錄**裡動手。
# 兩個 agent 改到同一個檔案時，**後寫的直接覆蓋前面的，沒有衝突提示、沒有錯誤**——
# 你會拿到一個「看起來完成了」但其中一份工作被靜默吃掉的結果。
#
# 原本對這件事的保護只有 rules/agent-orchestration.md 的一行文字：
#   ❌ 同時平行啟動會互改同一批檔案的 agent（序列化或用 worktree 隔離）
# 那是自律。這支是機器。
#
# 判斷方式：從 agent-activity.jsonl 算「已 start 但還沒 complete」的 agent 數，
# 對應鍵是 **agent_id**（不是 tool_use_id）。
# 帶了 isolation 的直接放行——它有自己的 checkout 與分支，改不到別人。
#
# 這個計數曾經永遠是 0，等於閘門從裝上去那天就沒攔過任何一次（2026-09-11 查出）：
# 當時 agent_complete 由 PostToolUse(Agent) 寫，而 Agent 工具是**非同步**的，
# PostToolUse 記的是「派工動作返回了」而非「agent 做完了」。修法見
# agent-monitor.sh 檔頭——完成改由 SubagentStop 寫。本檔只需知道：
# **agent_complete 現在代表 agent 真的結束了。**
#
# deny-once：擋第一次、把理由貼出來，重試就通過（跟任務模式閘門同一個模式）。
# 每一「批」平行只擋一次：in-flight 歸零時自動清除標記，下一批會再擋一次。
#
# 同一則訊息連派多個時擋在第幾個：實測（另一個專案的 3 個 agent 批次）
# 第 1 個的 PostToolUse 早於第 2 個的 PreToolUse 5 秒，所以**第 2 個會被擋**；
# 但第 3 個的 PreToolUse 早於第 2 個的 PostToolUse，可見這條鏈不是嚴格交錯的。
# 不影響本閘門的設計——deny-once 本來就是一批只擋一次。
#
# 逃生門：PARALLEL_AGENT_GATE=off、或 .suggest-mode 為 off

INPUT=$(cat)

source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$INPUT"
else
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    MAIN_CLAUDE="$MAIN_ROOT/.claude"; WORK_CLAUDE="$MAIN_CLAUDE"
fi

CLAUDE_DIR="$MAIN_CLAUDE"                  # log 集中在主 checkout
DATA_DIR="$WORK_CLAUDE/taskmaster-data"
LOG_JSONL="$CLAUDE_DIR/logs/agent-activity.jsonl"
WARNED="$DATA_DIR/.parallel-agent-warned"

[ "${PARALLEL_AGENT_GATE:-on}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

if [ -f "$DATA_DIR/.suggest-mode" ]; then
    sm=$(tr -d '[:space:]' < "$DATA_DIR/.suggest-mode" 2>/dev/null)
    [ "$sm" = "off" ] && exit 0
fi

# 這次要派的 agent 有沒有帶隔離
ISOLATION=$(printf '%s' "$INPUT" | jq -r '.tool_input.isolation // ""' 2>/dev/null)
SUBAGENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // "general-purpose"' 2>/dev/null)

# 這裡以前有一段「排除本次呼叫自己的 tool_use_id」的邏輯，**已不再需要**：
# agent_start 現在由 PostToolUse(Agent) 寫，而本檔跑在 PreToolUse，
# 也就是**必然早於自己那次 PostToolUse**。帳上根本還沒有自己這一筆，
# 無從誤算。原本那個誤擋（閒置超過 60 分鐘後的第一次委派必被擋一次）
# 一併消失，因為它的成因就是「monitor 在 PreToolUse 先寫了 start」。

# 帶了 isolation → 有自己的 checkout，改不到別人，直接放行
case "$ISOLATION" in
    worktree|remote) exit 0 ;;
esac

# 算 in-flight：start 過但沒有對應 complete 的 agent_id。
# 只看最近 60 分鐘——這個 session 見過跑 37 分鐘的 agent，窗開太小會漏算；
# 開太大則會被當機殘留的 phantom start 污染，60 分鐘是折衷。
#
# 沒有 agent_id 的紀錄一律忽略（`select(. != "")`）：那是本 hook 升級前寫的舊格式，
# 全部歸在同一個 null 鍵下會互相沖銷，算出來的數字沒有意義。
# starts 取 unique，避免同一個 agent_id 重複寫入時被算成多個。
INFLIGHT=0
if [ -f "$LOG_JSONL" ]; then
    CUTOFF=$(date -d '60 minutes ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
             || date -v-60M '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    INFLIGHT=$(jq -rs --arg cutoff "$CUTOFF" '
        [ .[] | select(($cutoff == "") or (.timestamp >= $cutoff)) ]
        | (map(select(.event == "agent_start"))
            | map(.agent_id // "") | map(select(. != "")) | unique) as $starts
        | (map(select(.event == "agent_complete"))
            | map(.agent_id // "")) as $dones
        | [ $starts[] | select(. as $s | ($dones | index($s)) == null) ]
        | length
    ' "$LOG_JSONL" 2>/dev/null || echo 0)
fi
[ -n "$INFLIGHT" ] || INFLIGHT=0

mkdir -p "$DATA_DIR" 2>/dev/null || true

# in-flight 歸零 → 上一批平行已結束，清掉標記讓下一批重新受檢
if [ "$INFLIGHT" -eq 0 ]; then
    rm -f "$WARNED" 2>/dev/null || true
    exit 0
fi

# 這一批已經擋過一次 → 放行（deny-once）
[ -f "$WARNED" ] && exit 0

: > "$WARNED" 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] parallel-agent-gate: deny (inflight=$INFLIGHT, next=$SUBAGENT)" \
    >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true

jq -n --arg n "$INFLIGHT" --arg next "$SUBAGENT" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("⚠️ 已經有 " + $n + " 個沒有隔離的 agent 在跑，你正要再派一個 `" + $next + "`。\n\n沒帶 `isolation` 的 subagent 全部在**同一個工作目錄**動手。兩個 agent 改到同一個檔案時，後寫的會**直接覆蓋前面的**——沒有衝突提示、沒有錯誤訊息。你會拿到「看起來完成了」但其中一份工作被靜默吃掉的結果，而且通常要到很後面才發現。\n\n**三個選擇，挑一個：**\n\n1. **序列化** —— 等前一個回來再派下一個。任務有依賴、或會動到同一批檔案時就選這個\n2. **帶隔離** —— `Agent` 工具加 `isolation: \"worktree\"`。各自一份 checkout 與分支，衝突變成看得見的 git 衝突。適合檔案範圍無交集且每個任務 ≥30 分鐘（開 worktree 有固定成本，短任務是淨虧損）\n3. **確認範圍無交集後重試** —— 若你已確認這幾個 agent 的檔案範圍不重疊（例如各寫不同的報告檔），**用一句話說出各自要寫哪些檔案**，然後重試同一次呼叫即可通過\n\n（本批只擋這一次；前一批跑完會自動重新受檢。關閉：PARALLEL_AGENT_GATE=off）")
  }
}' 2>/dev/null || true

exit 0
