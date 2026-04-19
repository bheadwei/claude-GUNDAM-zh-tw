#!/bin/bash
# User Prompt Submit Hook — 偵測 /task-* 命令，確保資料目錄存在

# 優先用 Claude Code 注入的環境變數；不存在時從腳本自身位置算
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true

INPUT=$(cat)
USER_INPUT=""
command -v jq >/dev/null 2>&1 && USER_INPUT=$(echo "$INPUT" | jq -r '.content // .message // ""')

if [[ "$USER_INPUT" == *"/task-init"* ]]; then
    mkdir -p "$CLAUDE_DIR/taskmaster-data" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] user-prompt: /task-init detected" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
fi

exit 0
