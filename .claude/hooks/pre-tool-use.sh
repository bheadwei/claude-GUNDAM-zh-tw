#!/bin/bash
# Pre Tool Use Hook — 輕量 log，不注入 context
# Matcher: Write|Edit|Read

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || SCRIPT_DIR="."
CLAUDE_DIR="${SCRIPT_DIR}/.."
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true

INPUT=$(cat)
TOOL_NAME="unknown"
command -v jq >/dev/null 2>&1 && TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')

echo "[$(date '+%Y-%m-%d %H:%M:%S')] pre-tool: $TOOL_NAME" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
exit 0
