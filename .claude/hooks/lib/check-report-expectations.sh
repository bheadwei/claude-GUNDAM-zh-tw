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
KEPT=""

while IFS= read -r line; do
    [ -n "$line" ] || continue

    agent=$(echo "$line" | jq -r '.agent // ""'    2>/dev/null) || agent=""
    area=$(echo  "$line" | jq -r '.area // ""'     2>/dev/null) || area=""
    epoch=$(echo "$line" | jq -r '.epoch // 0'     2>/dev/null) || epoch=0
    notified=$(echo "$line" | jq -r '.notified // 0' 2>/dev/null) || notified=0

    # 壞行直接丟掉，不讓它卡住整個檔案
    if [ -z "$agent" ] || [ -z "$area" ] || ! [ "$epoch" -gt 0 ] 2>/dev/null; then
        continue
    fi

    age=$(( NOW - epoch ))

    # 還在寬限期 → 原封不動留著，不檢查也不吵
    if [ "$age" -lt "$GRACE" ]; then
        KEPT="${KEPT}${line}${NL}"
        continue
    fi

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

    if [ "$age" -ge "$DEADLINE" ]; then
        log "WARN: $agent 逾 ${age}s 仍無報告於 context/$area/ — 放棄追蹤"
        continue
    fi

    if [ "$notified" = "0" ]; then
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

[ -n "$MISSING" ] || exit 0

cat <<EOF
📋 有 agent 完成後沒寫報告（延後稽核；非同步啟動的 agent 在 PostToolUse 當下還沒動工，所以改在這裡查）：${MISSING}

報告是跨 session 的唯一記憶——下一棒 agent 和未來的你都靠它。若該 agent 已結束，**現在補寫**（格式見 \`.claude/context/_REPORT_TEMPLATE.md\`）；若它仍在背景執行，忽略本訊息即可。
（關閉稽核：環境變數 REPORT_AUDIT=off）
EOF

exit 0
