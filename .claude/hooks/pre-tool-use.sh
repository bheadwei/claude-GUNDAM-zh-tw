#!/bin/bash
# Pre Tool Use Hook — 輕量 log，不注入 context
# Matcher: Write|Edit|Read

# 優先用 Claude Code 注入的環境變數；不存在時從腳本自身位置算
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true

INPUT=$(cat)
TOOL_NAME="unknown"
command -v jq >/dev/null 2>&1 && TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')

echo "[$(date '+%Y-%m-%d %H:%M:%S')] pre-tool: $TOOL_NAME" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
exit 0
