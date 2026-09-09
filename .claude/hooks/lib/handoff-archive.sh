#!/bin/bash
# handoff-archive.sh — 把已結案的 handoff 移出掃描路徑（供 post-agent-report.sh source）
#
# 為什麼需要：`_HANDOFF_TEMPLATE.md` 原本寫「完成後不刪除，作為審計軌跡」，
# 於是 completed 的檔案永遠留在平坦的 handoffs/ 裡。三個後果：
#
#   1. post-agent-report.sh 的 pending 掃描每次 subagent 結束都 for-loop 整個目錄、
#      對每個檔案 grep 一次。做過 50 次交接後，每次 hook 都掃 50 檔才找到 0 個 pending
#   2. agent 要讀「屬於自己的 pending handoff」時得在一堆 completed 裡撈
#   3. 歸檔若靠指令或自律，就要有人記得打、記得做
#
# 所以歸檔做成 hook：completed／cancelled 自動搬到 archive/YYYY-MM/。
# **審計軌跡不消失，只是換位置**——不刪檔、不覆蓋。
#
# 呼叫端必須傳主 checkout 的 handoffs 路徑：coordination/ 屬**共享產物**，
# 一律走 MAIN_CLAUDE（見 worktree-orchestration skill 的狀態隔離邊界表）。
# 用 WORK_CLAUDE 的話，worktree session 會放著主 checkout 的交接不動，
# 反而去搬 worktree 裡那份 git 追蹤的複本——合併時變成無謂的檔案移動衝突。
#
# 任何一步失敗都靜默跳過該檔：hook 不能因為歸檔失敗就中斷主流程。
#
# 用法（post-agent-report.sh 內，確認 suggest-mode 非 off 之後）：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/handoff-archive.sh"
#   archive_handoffs "$HANDOFF_DIR"

archive_handoffs() {
    local dir="${1:-}"
    [ -n "$dir" ] || return 0
    [ -d "$dir" ] || return 0

    local f base status ym target stem n
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        # `_` 開頭是範本（_HANDOFF_TEMPLATE.md），不是交接
        case "$base" in _*) continue ;; esac

        status=$(grep -m1 '^status:' "$f" 2>/dev/null | tr -d '\r')
        case "$status" in
            *completed*|*cancelled*) ;;
            *) continue ;;
        esac

        # YYYY-MM 取 frontmatter 的 date:（交接發生的月份）。mtime 是「最後一次
        # 改 status 的時間」，可能已跨月，所以只當 fallback
        ym=$(grep -m1 '^date:' "$f" 2>/dev/null \
             | sed 's/^date:[[:space:]]*//' | tr -d '\r' \
             | grep -oE '[0-9]{4}-[0-9]{2}' | head -1)
        [ -n "$ym" ] || ym=$(date -r "$f" '+%Y-%m' 2>/dev/null)
        [ -n "$ym" ] || ym=$(date '+%Y-%m')

        mkdir -p "$dir/archive/$ym" 2>/dev/null || continue

        stem="${base%.md}"
        target="$dir/archive/$ym/$base"
        if [ -e "$target" ]; then
            n=2
            while [ "$n" -lt 100 ] && [ -e "$dir/archive/$ym/$stem-$n.md" ]; do
                n=$((n + 1))
            done
            target="$dir/archive/$ym/$stem-$n.md"
            # 連 -99 都被佔滿 → 留在原地。寧可不歸檔，也不覆蓋審計軌跡
            [ -e "$target" ] && continue
        fi

        mv "$f" "$target" 2>/dev/null || true
    done
    return 0
}
