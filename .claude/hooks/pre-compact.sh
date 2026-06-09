#!/bin/bash

# PreCompact Hook — context 壓縮前自動快照工作狀態
# 在 Claude Code 壓縮對話（manual 或 auto）前觸發，把當前任務 / git / agent 狀態
# 存成 snapshot，避免壓縮後關鍵脈絡流失。
#
# 限制：shell hook 無法請 Claude 摘要「對話內容」；完整敘事式存檔請用 /save-session。
# 本 hook 只負責「機器可抓的狀態」這層安全網。
#
# 掛載：settings.json → hooks.PreCompact（無 matcher）

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TS=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown)
SNAP_DIR="$ROOT/.claude/sessions"
SNAP="$SNAP_DIR/auto-precompact-$TS.md"

mkdir -p "$SNAP_DIR" 2>/dev/null

# 消費 stdin（PreCompact payload：含 trigger=manual|auto、custom_instructions）
input=$(cat 2>/dev/null)
trigger=$(printf '%s' "$input" | grep -oE '"trigger"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

TASK=$(cat "$ROOT/.claude/taskmaster-data/.current-task" 2>/dev/null)
MODE=$(cat "$ROOT/.claude/taskmaster-data/.current-task-mode" 2>/dev/null)

{
    echo "# Auto Snapshot (PreCompact) — $TS"
    echo
    echo "> 由 pre-compact.sh 在 context 壓縮前自動產生。完整敘事請改用 /save-session。"
    echo
    echo "- trigger: ${trigger:-n/a}"
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
} > "$SNAP" 2>/dev/null

echo "🛟 PreCompact：已快照工作狀態 → .claude/sessions/auto-precompact-$TS.md（完整存檔可用 /save-session）"
exit 0
