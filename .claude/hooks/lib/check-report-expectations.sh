#!/bin/bash
# check-report-expectations.sh — 延後式 agent 報告稽核
#
# 為什麼需要這支：原本 post-agent-report.sh 在 PostToolUse 當下就 find 報告檔，
# 但 Agent tool 常是非同步啟動（tool_response 帶 "status":"async_launched"），
# 檢查時 agent 根本還沒動工 → 真有寫報告也被記成 WARN。而且只寫 log 不注入，
# 等於沒有牙齒。對照組是同檔案的 handoff 那半：用 additionalContext 注入，
# 完成率 100%。
#
# 改法：非同步啟動時只「記下期望」，由本腳本在後續的對話邊界（UserPromptSubmit
# 或下一個 agent 完成時）重新檢查，缺報告則注入要求補寫。
#
# 用法：bash check-report-expectations.sh <WORK_CLAUDE> [MAIN_CLAUDE]
#   WORK_CLAUDE  當前 worktree 的 .claude —— 期望檔放這裡（每個 worktree 各自）
#   MAIN_CLAUDE  主 checkout 的 .claude —— 報告與 log 找這裡（跨 worktree 共享）
#                省略時等同 WORK_CLAUDE（非 worktree 情境）
#   stdout：有事要講時輸出純文字（呼叫端負責包成 additionalContext）；沒事則無輸出
#   exit ：一律 0（稽核不該擋任何事）
#
# 可調參數（環境變數）：
#   REPORT_GRACE_SECONDS     幾秒內不檢查，避免 agent 還在跑就催（預設 120）
#   REPORT_DEADLINE_SECONDS  超過就放棄追蹤並記 WARN（預設 1800）
#   REPORT_AUDIT=off         完全關閉

set -uo pipefail

WORK_CLAUDE="${1:-}"
MAIN_CLAUDE="${2:-$WORK_CLAUDE}"
[ -n "$WORK_CLAUDE" ] && [ -d "$WORK_CLAUDE" ] || exit 0
[ -d "$MAIN_CLAUDE" ] || MAIN_CLAUDE="$WORK_CLAUDE"
[ "${REPORT_AUDIT:-on}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

EXPECT_FILE="$WORK_CLAUDE/taskmaster-data/.report-expectations.jsonl"
LOG_FILE="$MAIN_CLAUDE/logs/context-reports.log"
[ -s "$EXPECT_FILE" ] || exit 0

GRACE="${REPORT_GRACE_SECONDS:-120}"
DEADLINE="${REPORT_DEADLINE_SECONDS:-1800}"
NOW=$(date +%s)
TS=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "[$TS] $*" >> "$LOG_FILE" 2>/dev/null || true; }

NL=$'\n'
MISSING=""
FROM_RESPONSE=""
KEPT=""

# ---- 「這個 agent 真的結束了嗎」（2026-10-20 補）----
#
# 以前只看「啟動後過了多久」：過了寬限期（120 秒）就去找報告，找不到就催補寫。
# 而 agent 常跑幾十分鐘（見過 44 分鐘），於是**還在工作的 agent** 被催「補寫報告」，
# 主模型照做的話會自己寫一份假報告、或去打擾一個沒做完的 agent。
# 現在期望裡帶 agent_id（post-agent-report.sh 記），agent-activity.jsonl 裡還沒有它的
# agent_complete（SubagentStop 寫）就**先不催**、原樣留著。
# 沒有 agent_id 的期望（同步完成、或升級前的舊紀錄）、或 jsonl 讀不到時 → 照舊只看時間。
#
# 還在跑的期望不能永遠留著：當機的 agent 不會有 SubagentStop。超過
# REPORT_INFLIGHT_MAX_SECONDS（預設 14400 = 4h）就放棄追蹤。
# 結束之後的 DEADLINE 從「最後一次看到它還在跑」起算（running_seen），
# 否則跑了 40 分鐘的 agent 一結束就直接超過 30 分鐘的期限，連催都沒催就被放棄。
INFLIGHT_MAX="${REPORT_INFLIGHT_MAX_SECONDS:-14400}"
JSONL="$MAIN_CLAUDE/logs/agent-activity.jsonl"
DONE_IDS=""; DONE_LOADED=0
load_done_ids() {
    [ "$DONE_LOADED" -eq 1 ] && return 0
    DONE_LOADED=1
    [ -f "$JSONL" ] || { DONE_IDS="__unreadable__"; return 0; }
    # 逐行容錯（-R + fromjson?），理由同 lib/agent-inflight.sh：一行壞掉不能讓整份讀不到
    DONE_IDS=" $(jq -Rrn '[inputs | fromjson? | objects | select(.event == "agent_complete") | .agent_id // empty] | unique | join(" ")' "$JSONL" 2>/dev/null | tr -d '\r') "
}

while IFS= read -r line; do
    [ -n "$line" ] || continue

    agent=""; area=""; epoch=0; notified=0; aid=""; rseen=0
    _f=$(printf '%s' "$line" | jq -r '@sh "agent=\(.agent // "") area=\(.area // "") epoch=\(.epoch // 0) notified=\(.notified // 0) aid=\(.agent_id // "") rseen=\(.running_seen // 0)"' 2>/dev/null) || _f=""
    _f="${_f//$'\r'/}"
    [ -n "$_f" ] && eval "$_f"

    # 壞行直接丟掉，不讓它卡住整個檔案
    if [ -z "$agent" ] || [ -z "$area" ] || ! [ "$epoch" -gt 0 ] 2>/dev/null; then
        continue
    fi
    case "$rseen" in ''|*[!0-9]*) rseen=0 ;; esac

    age=$(( NOW - epoch ))

    # 還在寬限期 → 原封不動留著，不檢查也不吵
    if [ "$age" -lt "$GRACE" ]; then
        KEPT="${KEPT}${line}${NL}"
        continue
    fi

    # 還在跑 → 先不催（見上）
    if [ -n "$aid" ]; then
        load_done_ids
        if [ "$DONE_IDS" != "__unreadable__" ]; then
            case "$DONE_IDS" in
                *" $aid "*) ;;
                *)
                    if [ "$age" -ge "$INFLIGHT_MAX" ]; then
                        log "WARN: $agent（$aid）逾 ${age}s 仍未收到結束事件 — 放棄追蹤報告"
                    else
                        KEPT="${KEPT}$(printf '%s' "$line" | jq -c --argjson n "$NOW" '.running_seen = $n' 2>/dev/null || echo "$line")${NL}"
                    fi
                    continue ;;
            esac
        fi
    fi
    # DEADLINE 從最後一次看到它還在跑起算
    dage=$age
    [ "$rseen" -gt 0 ] && dage=$(( NOW - rseen ))

    # 找「這次啟動之後才出現」的報告：-newermt 比 -mmin 精確，
    # 而且避免把 agent 上一輪的舊報告誤認為這次的產出
    found=""
    ctx="$MAIN_CLAUDE/context/$area"
    if [ -d "$ctx" ]; then
        found=$(find "$ctx" -maxdepth 1 -name "${agent}-*.md" \
                     -newermt "@$epoch" 2>/dev/null | head -1)
    fi

    if [ -n "$found" ]; then
        log "OK: $agent wrote $(basename "$found")（延後 ${age}s 確認）"
        continue
    fi

    if [ "$dage" -ge "$DEADLINE" ]; then
        log "WARN: $agent 逾 ${dage}s 仍無報告於 context/$area/ — 放棄追蹤"
        continue
    fi

    if [ "$notified" = "0" ] && [ "$agent" = "refactor-cleaner" ]; then
        # 它跑在自己的 worktree、寫不回主 checkout，所以報告與 handoff 全文放在**回應**裡，
        # 由主模型落檔（agents/refactor-cleaner.md）。沒有檔案不是它漏寫，是還沒人落檔。
        FROM_RESPONSE="${FROM_RESPONSE}${NL}  • **${agent}** → 把它最終回應裡的報告落檔到 \`.claude/context/${area}/${agent}-{YYYY-MM-DD-HHMM}.md\`；回應裡若有 handoff，一併寫進 \`.claude/coordination/handoffs/\`"
        KEPT="${KEPT}$(echo "$line" | jq -c '.notified = 1' 2>/dev/null || echo "$line")${NL}"
    elif [ "$notified" = "0" ]; then
        MISSING="${MISSING}${NL}  • **${agent}** → 應寫入 \`.claude/context/${area}/${agent}-{YYYY-MM-DD-HHMM}.md\`（已啟動 ${age}s）"
        KEPT="${KEPT}$(echo "$line" | jq -c '.notified = 1' 2>/dev/null || echo "$line")${NL}"
    else
        KEPT="${KEPT}${line}${NL}"
    fi
done < "$EXPECT_FILE"

# 原子替換：先寫暫存再 mv，避免併發 hook 讀到半截檔案
tmp="${EXPECT_FILE}.tmp.$$"
if printf '%s' "$KEPT" > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$EXPECT_FILE" 2>/dev/null || rm -f "$tmp" 2>/dev/null
fi

[ -n "$MISSING" ] || [ -n "$FROM_RESPONSE" ] || exit 0

if [ -n "$MISSING" ]; then
cat <<EOF
📋 有 agent 完成後沒寫報告（延後稽核；非同步啟動的 agent 在 PostToolUse 當下還沒動工，所以改在這裡查）：${MISSING}

報告是跨 session 的唯一記憶——下一棒 agent 和未來的你都靠它。若該 agent 已結束，**現在補寫**（格式見 \`.claude/context/_REPORT_TEMPLATE.md\`）；若它仍在背景執行，忽略本訊息即可。
（關閉稽核：環境變數 REPORT_AUDIT=off）
EOF
fi

if [ -n "$FROM_RESPONSE" ]; then
    [ -n "$MISSING" ] && echo
cat <<EOF
📥 這些 agent 跑在自己的 worktree，報告寫不回主 checkout，**全文在它們的最終回應裡**——由你落檔：${FROM_RESPONSE}

照回應原文寫，不要重新摘要；落檔後 handoff 才會被接力機制看到。
（關閉稽核：環境變數 REPORT_AUDIT=off）
EOF
fi

exit 0
