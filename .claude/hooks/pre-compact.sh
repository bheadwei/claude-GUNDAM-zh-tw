#!/bin/bash

# PreCompact Hook — context 壓縮前自動快照工作狀態
# 在 Claude Code 壓縮對話（manual 或 auto）前觸發，把當前任務 / git / agent 狀態
# 存成 snapshot，避免壓縮後關鍵脈絡流失。
#
# 限制：shell hook 無法請 Claude 摘要「對話內容」；完整敘事式存檔請用 /save-session。
# 本 hook 只負責「機器可抓的狀態」這層安全網。
#
# 掛載：settings.json → hooks.PreCompact（無 matcher）

# 消費 stdin（PreCompact payload：含 trigger=manual|auto、custom_instructions、cwd）
input=$(cat 2>/dev/null)

# worktree 感知：任務狀態與 git 狀態都要看**當前** checkout，
# 否則在 worktree 裡壓縮會存下主 checkout 的狀態，快照就失真了
source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$input"
    ROOT="$WORK_ROOT"
else
    ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
    IN_WORKTREE=0
fi

TS=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown)
SNAP_DIR="$ROOT/.claude/sessions"
SNAP="$SNAP_DIR/auto-precompact-$TS.md"

mkdir -p "$SNAP_DIR" 2>/dev/null
trigger=$(printf '%s' "$input" | grep -oE '"trigger"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

TASK=$(cat "$ROOT/.claude/taskmaster-data/.current-task" 2>/dev/null)
MODE=$(cat "$ROOT/.claude/taskmaster-data/.current-task-mode" 2>/dev/null)

{
    echo "# Auto Snapshot (PreCompact) — $TS"
    echo
    echo "> 由 pre-compact.sh 在 context 壓縮前自動產生。完整敘事請改用 /save-session。"
    echo
    echo "- trigger: ${trigger:-n/a}"
    [ "${IN_WORKTREE:-0}" = "1" ] && echo "- worktree: $ROOT"
    echo "- current task: ${TASK:-（無）}"
    echo "- task mode: ${MODE:-（無）}"
    echo
    echo "## Git 狀態"
    echo '```'
    echo "branch: $(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    git -C "$ROOT" status --short 2>/dev/null | head -40
    echo '```'
    echo
    echo "## 最近 commit"
    echo '```'
    git -C "$ROOT" log --oneline -8 2>/dev/null
    echo '```'
    echo
    echo "## 最近 agent 活動"
    echo '```'
    tail -15 "$ROOT/.claude/logs/agent-activity.log" 2>/dev/null
    echo '```'

    # 待處理的坑候選 —— 這是唯一必須寫進快照的「非 git 狀態」：
    # PreCompact 不支援 additionalContext，所以壓縮後這份清單只剩檔案系統這條路。
    CAND="$ROOT/.claude/taskmaster-data/.learned-candidates"
    if [ -s "$CAND" ]; then
        echo
        echo "## 待處理的坑候選（尚未寫進 context/learned/）"
        echo '```'
        cat "$CAND" 2>/dev/null
        echo '```'
        echo
        echo "> 壓縮後請處理這份清單：值得留的用 \`/learn\` 寫進 \`.claude/context/learned/\`，"
        echo "> 只是打錯字的從 \`.learned-candidates\` 刪掉。"
    fi
} > "$SNAP" 2>/dev/null

echo "🛟 PreCompact：已快照工作狀態 → .claude/sessions/auto-precompact-$TS.md（完整存檔可用 /save-session）"
exit 0
