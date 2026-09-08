#!/bin/bash
# context-gc.sh
# 清理 .claude/context/ 下的舊報告，每個 area 只保留最新 5 份
# 舊報告歸檔到 <area>/_archive/，不刪除
#
# 使用：bash .claude/scripts/context-gc.sh [--keep N] [--dry-run]

set -uo pipefail

KEEP=5
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --keep) KEEP="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTEXT_DIR="$PROJECT_ROOT/.claude/context"

[ ! -d "$CONTEXT_DIR" ] && { echo "context dir not found: $CONTEXT_DIR"; exit 1; }

ARCHIVED=0
KEPT=0

for area_dir in "$CONTEXT_DIR"/*/; do
    area=$(basename "$area_dir")
    [ "$area" = "_archive" ] && continue

    archive_dir="$area_dir/_archive"
    mkdir -p "$archive_dir"

    # 找出所有報告檔（排除 README、template、_archive）
    mapfile -t reports < <(find "$area_dir" -maxdepth 1 -type f -name "*.md" \
        ! -name "README.md" \
        ! -name "_*.md" \
        2>/dev/null | sort -r)

    count=${#reports[@]}
    [ "$count" -le "$KEEP" ] && { KEPT=$((KEPT + count)); continue; }

    # 保留最新 KEEP 份，其餘歸檔
    for ((i=KEEP; i<count; i++)); do
        report="${reports[i]}"
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[dry-run] would archive: $area/$(basename "$report")"
        else
            mv "$report" "$archive_dir/"
            echo "archived: $area/$(basename "$report")"
        fi
        ARCHIVED=$((ARCHIVED + 1))
    done
    KEPT=$((KEPT + KEEP))
done

echo ""
echo "Summary: kept=$KEPT, archived=$ARCHIVED, keep_per_area=$KEEP"
[ "$DRY_RUN" -eq 1 ] && echo "(dry-run mode, no changes made)"
