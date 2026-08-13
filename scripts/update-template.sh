#!/usr/bin/env bash
# update-template.sh — 將 claude_v2026 模板的「最新資產」更新到既有專案
#
# 與 copy-template.sh 的差異：
#   copy-template   = 開新專案（複製到空資料夾）
#   update-template = 更新既有專案（只更新模板資產，保留該專案的 log/plan/qa-history/sessions）
#
# 用法:
#   ./scripts/update-template.sh /path/to/my-app
#   ./scripts/update-template.sh /path/to/my-app --dry-run    # 只預覽不寫入
#   ./scripts/update-template.sh /path/to/my-app --prune       # 連目標多出來的模板檔一起清掉
#   ./scripts/update-template.sh /path/to/my-app --no-backup   # 不先備份（不建議）
#   ./scripts/update-template.sh /path/to/my-app --claude-only # 只更新 .claude/，完全不碰根目錄資產

set -euo pipefail

DEST=""
DRY_RUN=0
PRUNE=0
NO_BACKUP=0
CLAUDE_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=1 ;;
    --prune)       PRUNE=1 ;;
    --no-backup)   NO_BACKUP=1 ;;
    --claude-only) CLAUDE_ONLY=1 ;;
    -*)            echo "未知選項: $arg" >&2; exit 1 ;;
    *)             DEST="$arg" ;;
  esac
done

if [ -z "$DEST" ]; then
  echo "用法: $0 <目標專案路徑> [--dry-run] [--prune] [--no-backup] [--claude-only]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- 分類設定 ----
SYNC_CLAUDE_DIRS=(agents commands rules skills hooks guides output-styles plugins templates ui scripts "custom-rule&skill")
SYNC_CLAUDE_FILES=(statusline.sh statusline-debug.sh settings.json README.md)
SYNC_ROOT_DIRS=(scripts)
SYNC_ROOT_FILES=(.mcp.json.linux.example .mcp.json.windows.example CLAUDE_TEMPLATE.md .gitattributes)
MERGE_CLAUDE_DIRS=(context coordination)
PRESERVE_NOTE=("settings.local.json" "taskmaster-data/" "sessions/" "logs/" "qa-history/" "worktrees/" "(root) .mcp.json / .env")

# ---- 驗證 ----
if [ ! -d "$DEST" ]; then
  echo "❌ 目標資料夾不存在: $DEST" >&2
  echo "   若要開新專案，請改用 copy-template.sh" >&2
  exit 1
fi
DEST="$(cd "$DEST" && pwd)"
if [ "$DEST" = "$SOURCE" ]; then
  echo "❌ 目標不能是模板本身" >&2
  exit 1
fi
if [ ! -d "$DEST/.claude" ]; then
  echo "⚠️  目標沒有 .claude 目錄，看起來不是既有專案。若要從零建立請用 copy-template.sh" >&2
  read -r -p "仍要繼續？[y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }
fi

# ---- 備份 ----
if [ "$DRY_RUN" -eq 0 ] && [ "$NO_BACKUP" -eq 0 ] && [ -d "$DEST/.claude" ]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$DEST/.claude-backups"
  mkdir -p "$BACKUP_DIR"
  BACKUP="$BACKUP_DIR/claude-backup-$TS.tar.gz"
  echo "🛟 備份目標 .claude → $BACKUP"
  tar -czf "$BACKUP" -C "$DEST" .claude
fi

# ---- rsync 包裝（無 rsync 時 fallback 到 cp）----
have_rsync=0; command -v rsync >/dev/null 2>&1 && have_rsync=1

sync_dir() {  # $1=src $2=dst $3=mode(mirror|additive)
  local src="$1" dst="$2" m="$3"
  [ -d "$src" ] || return 0
  mkdir -p "$dst"
  if [ "$have_rsync" -eq 1 ]; then
    local flags=(-a)
    [ "$DRY_RUN" -eq 1 ] && flags+=(-n -v)
    [ "$m" = "mirror" ] && [ "$PRUNE" -eq 1 ] && flags+=(--delete)
    rsync "${flags[@]}" "$src/" "$dst/"
  else
    [ "$DRY_RUN" -eq 1 ] && { echo "   [dry] $dst/"; return 0; }
    cp -a "$src/." "$dst/"
  fi
}

copy_file() {  # $1=src $2=dst
  local src="$1" dst="$2"
  [ -f "$src" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then echo "   [dry] $dst"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
}

# ---- 執行 ----
MODE="SYNC（不刪除）"
[ "$PRUNE" -eq 1 ] && MODE="SYNC + PRUNE"
[ "$DRY_RUN" -eq 1 ] && MODE="DRY-RUN（不寫入）"
[ "$CLAUDE_ONLY" -eq 1 ] && MODE="$MODE · CLAUDE-ONLY"

echo ""
echo "🔄 更新模板資產 [$MODE]"
echo "   來源: $SOURCE"
echo "   目標: $DEST"
[ "$CLAUDE_ONLY" -eq 1 ] && echo "   範圍: 僅 .claude/（跳過根目錄資產）"
echo ""

echo "▶ SYNC 模板目錄..."
for d in "${SYNC_CLAUDE_DIRS[@]}"; do sync_dir "$SOURCE/.claude/$d" "$DEST/.claude/$d" mirror; done
if [ "$CLAUDE_ONLY" -eq 0 ]; then
  for d in "${SYNC_ROOT_DIRS[@]}"; do sync_dir "$SOURCE/$d" "$DEST/$d" mirror; done
else
  echo "   ⏭  跳過根目錄目錄: ${SYNC_ROOT_DIRS[*]}"
fi

echo "▶ SYNC 模板檔案..."
for f in "${SYNC_CLAUDE_FILES[@]}"; do copy_file "$SOURCE/.claude/$f" "$DEST/.claude/$f"; done
if [ "$CLAUDE_ONLY" -eq 0 ]; then
  for f in "${SYNC_ROOT_FILES[@]}"; do copy_file "$SOURCE/$f" "$DEST/$f"; done
else
  echo "   ⏭  跳過根目錄檔案: ${SYNC_ROOT_FILES[*]}"
fi

echo "▶ MERGE 骨架目錄（保留執行資料）..."
for d in "${MERGE_CLAUDE_DIRS[@]}"; do sync_dir "$SOURCE/.claude/$d" "$DEST/.claude/$d" additive; done

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "✅ DRY-RUN 完成（未寫入任何檔案）"
else
  echo "✅ 模板更新完成"
fi
echo ""
echo "🔒 以下專案紀錄完全未被更動："
for p in "${PRESERVE_NOTE[@]}"; do echo "     - $p"; done
[ "$CLAUDE_ONLY" -eq 1 ] && echo "     - (root) scripts/ 及所有根層檔案（CLAUDE.md / .gitignore / .gitattributes / .mcp.json.* 等）"
echo ""
if [ "$DRY_RUN" -eq 0 ] && [ "$NO_BACKUP" -eq 0 ]; then
  echo "🛟 如需還原：解壓 .claude-backups/ 內最新的 tar.gz 覆蓋回 .claude/"
fi
if [ "$DRY_RUN" -eq 0 ]; then
  echo ""
  echo "👉 下一步：到目標專案開 Claude Code 跑一次 /task-status"
  echo "   若 wbs.md 還沒有 Plan 欄，它會提議把既有 plan 回填成連結（一次性遷移）"
fi
echo ""
