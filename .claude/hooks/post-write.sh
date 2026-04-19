#!/bin/bash
# Post Write Hook — 記錄文檔和 WBS 寫入事件

# 優先用 Claude Code 注入的環境變數；不存在時從腳本自身位置算
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true

INPUT=$(cat)
FILE_PATH=""
command -v jq >/dev/null 2>&1 && FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# WBS 更新時記錄歷史
if [[ "$FILE_PATH" == *"taskmaster-data/wbs.md"* ]]; then
    mkdir -p "$CLAUDE_DIR/taskmaster-data" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WBS updated" >> "$CLAUDE_DIR/taskmaster-data/wbs-history.log" 2>/dev/null
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] post-write: $FILE_PATH" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
exit 0
