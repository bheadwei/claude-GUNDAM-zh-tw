#!/bin/bash
# resolve-roots.sh — worktree 感知的路徑解析（供各 hook source）
#
# 為什麼需要這支：官方文件明確寫著
#
#   「Hook paths don't follow the worktree. ${CLAUDE_PROJECT_DIR} stays put —
#     it still points at the project root where the session started.
#     The cwd field in the hook's input JSON is the worktree root.」
#
# 所以在 worktree session 裡：主模型寫檔寫到 worktree，hook 卻讀主 checkout。
# 沒有這支解析器，三個平行 worktree 會共用同一份 .current-task-mode ——
# A 判 quick、B 判 critical，互相覆寫，閘門就判錯了。
#
# 用法（hook 讀完 stdin 之後）：
#
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh"
#   resolve_roots "$INPUT"
#
# 解析後可用：
#   MAIN_ROOT      主 checkout（session 啟動處）
#   MAIN_CLAUDE    $MAIN_ROOT/.claude
#   WORK_ROOT      當前 checkout root（在 worktree 裡就是 worktree，否則同 MAIN_ROOT）
#   WORK_CLAUDE    $WORK_ROOT/.claude
#   IN_WORKTREE    1 = 在 worktree 裡
#
# 狀態該放哪一邊 —— 判準是「短命旗標 vs 共享產物」：
#
#   WORK_CLAUDE（跟著 worktree）  MAIN_CLAUDE（跨 worktree 共享）
#   ────────────────────────────  ──────────────────────────────
#   taskmaster-data/.current-task*   context/learned/    踩過的坑是共享知識
#   taskmaster-data/.doc-impact*     context/decisions/  ADR
#   taskmaster-data/.pitfall-seen    coordination/       agent 交接
#                                    logs/               log 集中一處才查得到
#
#   注意 wbs.md 與 plans/ **不在上表** —— 它們是 git 追蹤的檔案，
#   worktree 會自然帶一份、改動由 git 合併，不需要 hook 介入選 root。

# shellcheck disable=SC2034

resolve_roots() {
    local input="${1:-}"

    # 主 checkout：CLAUDE_PROJECT_DIR 優先（官方保證它留在 session 啟動處）
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-}"
    if [ -z "$MAIN_ROOT" ]; then
        MAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || MAIN_ROOT="."
    fi
    MAIN_CLAUDE="$MAIN_ROOT/.claude"

    WORK_ROOT="$MAIN_ROOT"
    IN_WORKTREE=0

    # 取 hook input 的 cwd。官方：「cwd follows Claude, and it moves again
    # when Claude runs cd」——所以 cwd 可能是 worktree 的**子目錄**，
    # 必須往上走到 checkout root，不能直接當根用。
    local cwd=""
    if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
        cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null) || cwd=""
    fi
    [ -n "$cwd" ] || { WORK_CLAUDE="$WORK_ROOT/.claude"; return 0; }

    local norm main_norm
    norm=$(printf '%s' "$cwd" | tr '\\' '/')
    main_norm=$(printf '%s' "$MAIN_ROOT" | tr '\\' '/')

    # 往上找 .git（linked worktree 的 .git 是**檔案**，主 checkout 是目錄）
    local d="$norm" found=""
    while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
        if [ -e "$d/.git" ]; then found="$d"; break; fi
        case "$d" in */*) d="${d%/*}" ;; *) break ;; esac
    done
    [ -n "$found" ] || { WORK_CLAUDE="$WORK_ROOT/.claude"; return 0; }

    # 與主 checkout 同一個根 → 不在 worktree
    if [ "$found" = "$main_norm" ]; then
        WORK_CLAUDE="$WORK_ROOT/.claude"
        return 0
    fi

    # 不同根 + .git 是檔案 → 這是 linked worktree
    if [ -f "$found/.git" ]; then
        WORK_ROOT="$found"
        IN_WORKTREE=1
    fi

    WORK_CLAUDE="$WORK_ROOT/.claude"
    return 0
}
