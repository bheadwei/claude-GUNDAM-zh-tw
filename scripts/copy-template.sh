#!/usr/bin/env bash
# copy-template.sh — 將 claude_v2026 模板複製到新專案資料夾
# 自動排除個人設定、執行時資料、歷史紀錄等專案專屬內容
#
# 用法:
#   bash scripts/copy-template.sh /path/to/new-project
#   bash scripts/copy-template.sh ~/projects/my-app
#
# 支援: Linux、macOS、Windows Git Bash、WSL

set -euo pipefail

# ============================================================================
# 參數處理
# ============================================================================

if [ $# -lt 1 ]; then
    echo "用法: bash $0 <目標資料夾>"
    echo "範例: bash $0 /d/projects/my-new-app"
    exit 1
fi

DEST="$1"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 禁止複製到自己
if [ "$(cd "$DEST" 2>/dev/null && pwd)" = "$SRC" ]; then
    echo "❌ 錯誤：目標資料夾不能是模板本身"
    exit 1
fi

# ============================================================================
# 目標驗證
# ============================================================================

if [ -e "$DEST" ] && [ "$(ls -A "$DEST" 2>/dev/null)" ]; then
    echo "⚠️  目標資料夾已存在且非空: $DEST"
    read -r -p "是否繼續覆蓋？[y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi
fi

mkdir -p "$DEST"

# ============================================================================
# 排除清單
# ============================================================================

# 專案專屬資料（每個新專案都應該重建）
EXCLUDES=(
    # 使用者個人設定（含 template 開發過程累積的 permission）
    ".claude/settings.local.json"

    # 執行時產生的資料
    ".claude/taskmaster-data/"
    ".claude/qa-history/"
    ".claude/sessions/"
    ".claude/logs/"
    ".claude/worktrees/"
    ".claude/context/"
    ".claude/coordination/"

    # Git 與依賴
    ".git/"
    "node_modules/"
    ".venv/"
    "venv/"
    "__pycache__/"
    "*.pyc"

    # 環境與秘密
    ".env"
    ".env.local"
    ".mcp.json"

    # 編輯器與 OS
    ".vscode/"
    ".idea/"
    ".DS_Store"
    "Thumbs.db"

    # 暫存
    "tmp/"
    "*.tmp"
    "*.bak"

    # 模板開發工作目錄（不該帶到新專案）
    "workshop/"
)

# ============================================================================
# 執行複製
# ============================================================================

echo "📦 複製模板..."
echo "   來源: $SRC"
echo "   目標: $DEST"
echo ""

if command -v rsync >/dev/null 2>&1; then
    # 優先使用 rsync
    RSYNC_ARGS=(-a --info=progress2)
    for pattern in "${EXCLUDES[@]}"; do
        RSYNC_ARGS+=(--exclude="$pattern")
    done
    rsync "${RSYNC_ARGS[@]}" "$SRC/" "$DEST/"
else
    # Fallback: 用 cp + find 移除
    echo "⚠️  rsync 未安裝，使用 cp 備援方案（較慢）"
    cp -r "$SRC/." "$DEST/"

    for pattern in "${EXCLUDES[@]}"; do
        find "$DEST" -path "$DEST/$pattern" -exec rm -rf {} + 2>/dev/null || true
    done
fi

# ============================================================================
# 後置處理
# ============================================================================

# 建立空的必要目錄（避免後續 hook 報錯）
mkdir -p "$DEST/.claude/logs"
mkdir -p "$DEST/.claude/taskmaster-data"

# 建立最小化的 settings.local.json
cat > "$DEST/.claude/settings.local.json" <<'EOF'
{
  "permissions": {
    "allow": []
  },
  "enableAllProjectMcpServers": true
}
EOF

# ============================================================================
# 完成訊息
# ============================================================================

echo ""
echo "✅ 模板複製完成"
echo ""
echo "下一步:"
echo "  cd \"$DEST\""
echo ""
echo "  # 1. 複製 MCP 設定範本"
echo "  cp .mcp.json.windows.example .mcp.json  # Windows"
echo "  # 或"
echo "  cp .mcp.json.linux.example .mcp.json    # Linux / macOS"
echo ""
echo "  # 2. 填入 API keys 後啟動"
echo "  claude"
echo ""
echo "  # 3. 初始化專案"
echo "  /task-init"
echo ""
