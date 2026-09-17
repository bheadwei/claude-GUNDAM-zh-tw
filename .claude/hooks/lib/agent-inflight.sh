#!/bin/bash
# agent-inflight.sh — 算「現在有幾個 subagent 還在跑」（供 hook source）
#
# 為什麼獨立成 lib：兩道閘門需要同一個答案——
#   - pre-agent-gate.sh   ：要不要擋下「再派一個沒隔離的 agent」
#   - lib/branch-switch-gate.sh：要不要擋下「把別人腳下的分支抽掉」
# 理由跟 cmd-segments.sh 檔頭寫的一樣：同一個坑修過兩次，就是因為兩邊各寫各的。
# 這個計數的歷史特別能說明問題——它曾經**永遠是 0**，等於閘門從裝上那天起
# 沒攔過任何一次（2026-09-11 查出，成因見 agent-monitor.sh 檔頭：agent_complete
# 原本由非同步的 PostToolUse(Agent) 寫）。再讓第二支 hook 抄一份，就是把那個
# 坑複製一份出去等它被修第二次。
#
# 判斷方式：從 agent-activity.jsonl 取「已 agent_start 但沒有對應 agent_complete」
# 的紀錄，對應鍵是 **agent_id**（不是 tool_use_id）。
#
# 三個刻意的細節（改之前先讀，每一條都有對應的 bug）：
#   - 只看最近 N 分鐘（預設 60）——見過跑 37 分鐘的 agent，窗太小會漏算；
#     太大會被當機殘留的 phantom start 污染
#   - 沒有 agent_id 的紀錄一律忽略：那是升級前的舊格式，全歸在同一個 null 鍵下
#     會互相沖銷，算出來的數字沒有意義
#   - 沒有 agent_type 的印成 `-` 而不是空行：空行會讓呼叫端無法與「零個
#     in-flight」區分，那個 agent 就從計數裡消失了
#
# 用法：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-inflight.sh" 2>/dev/null || true
#   declare -F agent_inflight_types >/dev/null 2>&1 || ...   # 缺檔時呼叫端自行決定
#   TYPES=$(agent_inflight_types "$LOG_JSONL")      # 一行一個 agent_type
#   N=$(agent_inflight_count "$TYPES")              # 筆數（吃上一行的輸出，不重跑 jq）

# agent_inflight_types <agent-activity.jsonl> [視窗分鐘數]
# 輸出：每個 in-flight agent 的 agent_type，一行一個。算不出來就印空的。
agent_inflight_types() {
    local log="$1" mins="${2:-60}" cutoff
    [ -n "$log" ] && [ -f "$log" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0

    cutoff=$(date -d "$mins minutes ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
             || date -v-"${mins}"M '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")

    jq -rs --arg cutoff "$cutoff" '
        [ .[] | select(($cutoff == "") or (.timestamp >= $cutoff)) ] as $rows
        | ($rows | map(select(.event == "agent_complete"))
            | map(.agent_id // "")) as $dones
        | [ $rows[] | select(.event == "agent_start")
            | select((.agent_id // "") != "") ]
        | group_by(.agent_id) | map(.[0])
        | map(select((.agent_id) as $s | ($dones | index($s)) == null))
        | map(if (.agent_type // "") == "" then "-" else .agent_type end)
        | .[]
    ' "$log" 2>/dev/null || return 0
}

# agent_inflight_count <agent_inflight_types 的輸出>
# 數非空白行。數不出來一律回 0（方向偏放行，與本模板所有閘門一致）。
agent_inflight_count() {
    local types="${1:-}" n
    [ -n "$types" ] || { echo 0; return 0; }
    n=$(printf '%s\n' "$types" | grep -c '[^[:space:]]' 2>/dev/null)
    case "${n:-}" in ''|*[!0-9]*) n=0 ;; esac
    echo "$n"
}
