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
# 幾個刻意的細節（改之前先讀，每一條都有對應的 bug）：
#   - **逐行解析，壞行跳過**（`-R` + `fromjson?`）。以前用 `jq -s` 整檔吞，
#     log 裡只要有一行被截斷（2026-10-16 實際出現在第 992 行：兩個 hook 併發寫入，
#     一行只剩 `ord"}`），整個 jq 就 parse error、`|| return 0` 把計數變成 0——
#     **閘門又一次靜默失效**，跟 2026-09-11 那次同一個結果。
#     副作用：升級前的多行 JSON 舊格式會被整批丟掉，那些本來就沒有 agent_id，無損
#   - 只看最近 N 分鐘（預設 60）——見過跑 37 分鐘的 agent，窗太小會漏算；
#     太大會被當機殘留的 phantom start 污染
#   - 沒有 agent_id 的紀錄一律忽略：那是升級前的舊格式，全歸在同一個 null 鍵下
#     會互相沖銷，算出來的數字沒有意義
#   - 沒有 agent_type 的印成 `-` 而不是空行：空行會讓呼叫端無法與「零個
#     in-flight」區分，那個 agent 就從計數裡消失了
#   - **不算進 in-flight 的三種**（它們不會在共用 checkout 裡跟別人撞）：
#       ① 派工時帶 `isolation: worktree|remote`（agent-monitor.sh 記進 agent_start）
#       ② agent 定義的 frontmatter 寫 `isolation: worktree`（例：refactor-cleaner）——
#          派工參數沒帶，但 Claude Code 照樣替它開 worktree
#       ③ 唯讀名單 AGENT_INFLIGHT_READONLY（下方）。名單的依據與邊界寫在
#          pre-agent-gate.sh 檔頭（唯一來源），改名單前先讀那段
#
# 用法：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-inflight.sh" 2>/dev/null || true
#   declare -F agent_inflight_types >/dev/null 2>&1 || ...   # 缺檔時呼叫端自行決定
#   TYPES=$(agent_inflight_types "$LOG_JSONL")      # 一行一個 agent_type
#   N=$(agent_inflight_count "$TYPES")              # 筆數（吃上一行的輸出，不重跑 jq）
#   agent_def_isolated "$MAIN_CLAUDE/agents" refactor-cleaner && echo 自帶隔離

# 唯讀名單（依據與邊界：pre-agent-gate.sh 檔頭）。**general-purpose 絕不能進來。**
AGENT_INFLIGHT_READONLY="Explore Plan claude-code-guide planner architect workflow-template-manager"

# agent_def_isolated <agents 目錄> <agent_type>
# 該 agent 的定義檔第一個 frontmatter 區塊寫了 `isolation: worktree` → 0。
# 純 bash 讀檔（不開 awk）：這在每次派工都可能跑，這台機器開一個行程要 ~170ms。
agent_def_isolated() {
    local dir="$1" type="$2" f line n=0 v
    case "$type" in ''|-|*/*|*..*) return 1 ;; esac
    f="$dir/$type.md"
    [ -f "$f" ] || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        if [ "$line" = "---" ]; then
            n=$((n + 1)); [ "$n" -ge 2 ] && return 1
            continue
        fi
        [ "$n" -eq 1 ] || return 1          # 第一行不是 `---` → 沒有 frontmatter
        case "$line" in
            isolation:*)
                v="${line#isolation:}"; v="${v//[[:space:]\"\']/}"
                [ "$v" = "worktree" ] && return 0
                return 1 ;;
        esac
    done < "$f"
    return 1
}

# agent_inflight_types <agent-activity.jsonl> [視窗分鐘數] [agents 目錄]
# 輸出：每個 in-flight agent 的 agent_type，一行一個。算不出來就印空的。
# agents 目錄預設為 jsonl 往上兩層的 `agents/`（`.claude/logs/x.jsonl` → `.claude/agents`）。
agent_inflight_types() {
    local log="$1" mins="${2:-60}" agents_dir="${3:-}" cutoff raw t
    [ -n "$log" ] && [ -f "$log" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    if [ -z "$agents_dir" ]; then
        agents_dir="${log%/*}"; agents_dir="${agents_dir%/*}/agents"
    fi

    cutoff=$(date -d "$mins minutes ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
             || date -v-"${mins}"M '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")

    raw=$(jq -Rrn --arg cutoff "$cutoff" --arg ro "$AGENT_INFLIGHT_READONLY" '
        ($ro | split(" ") | map(select(. != ""))) as $ro
        | [ inputs | fromjson? | objects
            | select(($cutoff == "") or ((.timestamp // "") >= $cutoff)) ] as $rows
        | ($rows | map(select(.event == "agent_complete"))
            | map(.agent_id // "")) as $dones
        | [ $rows[] | select(.event == "agent_start")
            | select((.agent_id // "") != "") ]
        | group_by(.agent_id) | map(.[0])
        | map(select((.agent_id) as $s | ($dones | index($s)) == null))
        | map(select((.isolation // "") as $i | ($i != "worktree" and $i != "remote")))
        | map(select((.agent_type // "") as $t | ($ro | index($t)) == null))
        | map(if (.agent_type // "") == "" then "-" else .agent_type end)
        | .[]
    ' "$log" 2>/dev/null) || return 0
    [ -n "$raw" ] || return 0

    # ② 定義檔自帶隔離的，逐一剔除（只在真的有 in-flight 時才讀檔）
    while IFS= read -r t; do
        t="${t%$'\r'}"
        [ -n "$t" ] || continue
        agent_def_isolated "$agents_dir" "$t" && continue
        printf '%s\n' "$t"
    done <<< "$raw"
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
