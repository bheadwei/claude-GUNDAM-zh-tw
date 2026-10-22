#!/bin/bash
# handoff-scan.sh — 掃 coordination/handoffs/ 的 pending 交接，產生注入文字（供 hook source）
#
# 為什麼獨立成 lib、而且接在兩個事件（2026-10-20 補）：
# 原本只接在 PostToolUse(Agent)。而 Agent 是**非同步**的——派工返回時 agent 才剛開始跑，
# 它建的 handoff 要等到**下一次**派 agent 的 PostToolUse 才會被看到。但這個提示的用途
# 正是「觸發下一次派工」：沒有下一次派工，提示就永遠不出現，接力鏈斷在第一棒之後。
# 所以同一份掃描也接到 UserPromptSubmit——非同步 agent 交回時 harness 會送一則訊息進來，
# 那正是接力該發生的時點。
# **不接 SubagentStop**：沒驗證過它的輸出能不能注入主對話（README「撰寫新 Hook 的慣例」第 7 條）。
#
# 用法：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/handoff-scan.sh" 2>/dev/null || true
#   MSG=$(handoff_pending_message "$HANDOFF_DIR" "$SUGGEST_MODE")   # 沒有 pending 時印空字串
#
# 格式與上限（最多 5 筆、low 模式只列 high priority）與原本 post-agent-report.sh 那段一字不差，
# 兩個事件的注入長得一樣，模型不必學兩種。
# 一次 awk 讀完所有檔案：原本每個檔案開 4 個 grep＋sed＋tr，這台機器一個行程 ~170ms，
# 5 個 pending 就要 10 秒——UserPromptSubmit 的 timeout 是 15 秒。

handoff_pending_message() {
    local dir="$1" mode="${2:-medium}" lines count
    [ -d "$dir" ] || return 0
    local files=()
    local f
    for f in "$dir"/*.md; do
        [ -e "$f" ] || continue
        [ "${f##*/}" = "_HANDOFF_TEMPLATE.md" ] && continue
        files+=("$f")
    done
    [ "${#files[@]}" -gt 0 ] || return 0

    lines=$(awk -v mode="$mode" -v max=5 '
        function flush(   name) {
            if (fn == "" || done) return
            if (status !~ /pending/) return
            if (prio == "") prio = "medium"
            if (mode == "low" && prio != "high" && prio != "HIGH") return
            if (reason == "") reason = "(見交接檔)"
            name = fn; sub(/.*\//, "", name)
            printf "  • [%s] %s → %s（%s）：%s\n", prio, from, to, name, reason
            n++
            if (n >= max) done = 1
        }
        FNR == 1 { flush(); fn = FILENAME; status = ""; to = ""; from = ""; prio = ""; reason = ""; want = 0; gotr = 0; st = 0; tt = 0; ft = 0; pt = 0 }
        { sub(/\r$/, "") }
        !st && /^status:/   { v = $0; sub(/^status:[[:space:]]*/, "", v);   status = v; st = 1 }
        !tt && /^to:/       { v = $0; sub(/^to:[[:space:]]*/, "", v);       to = v;     tt = 1 }
        !ft && /^from:/     { v = $0; sub(/^from:[[:space:]]*/, "", v);     from = v;   ft = 1 }
        !pt && /^priority:/ { v = $0; sub(/^priority:[[:space:]]*/, "", v); prio = v;   pt = 1 }
        want && !gotr { if ($0 !~ /^[[:space:]]*$/) { reason = $0; gotr = 1; want = 0 }; next }
        !gotr && /^## 起因/ { want = 1 }
        END { flush() }
    ' "${files[@]}" 2>/dev/null)
    [ -n "$lines" ] || return 0
    count=$(printf '%s\n' "$lines" | grep -c '•')

    local NL=$'\n'
    printf '%s' "🔗 偵測到 ${count} 個待處理 agent 交接（status: pending）。若符合當前目標，建議啟動對應的「to」agent 接手——各 agent 啟動時會自行讀取其 handoff 工作清單：${NL}${lines}${NL}${NL}完成後請將對應 handoff 的 status 改為 completed —— 不用刪檔也不用搬檔，hook 會自動歸檔到 archive/YYYY-MM/，審計軌跡不會消失。"
}
