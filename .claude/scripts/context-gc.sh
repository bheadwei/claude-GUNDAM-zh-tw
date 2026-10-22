#!/bin/bash
# context-gc.sh
# 清理 .claude/context/ 下的舊 agent 報告。舊報告歸檔到 <area>/_archive/，不刪除。
#
# 規則：
#   - decisions/、learned/ 整個跳過：ADR、FIXED-LOG、踩坑紀錄是長期知識，不是「最新幾份」的報告
#   - 其餘 area 依 agent 前綴分組（檔名 <agent>-YYYY-MM-DD-....md），每組保留最新 N 份
#     一個 area 可能有多個 agent 寫入（例 quality/ 有 code-quality-specialist 與 refactor-cleaner），
#     不分組的話寫得勤的 agent 會把別人的報告擠進 archive
#   - 新舊依 mtime 排序（同 mtime 再依檔名）。檔名尾碼不保證可排序（有的帶 -<主題>）
#   - 檔名對不出 <agent>-YYYY- 前綴的不動
#
# 使用：bash .claude/scripts/context-gc.sh [--keep N] [--dry-run]

set -uo pipefail

KEEP=5
DRY_RUN=0
SKIP_AREAS="decisions learned _archive"

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
UNGROUPED=0

for area_dir in "$CONTEXT_DIR"/*/; do
    area=$(basename "$area_dir")
    case " $SKIP_AREAS " in *" $area "*) echo "skip area: $area"; continue ;; esac

    archive_dir="${area_dir%/}/_archive"

    # "<mtime> <basename>"，新到舊
    mapfile -t entries < <(find "$area_dir" -maxdepth 1 -type f -name "*.md" \
        ! -name "README.md" ! -name "_*.md" -printf '%T@ %f\n' 2>/dev/null \
        | sort -k1,1nr -k2,2r)

    declare -A seen=()
    for entry in "${entries[@]}"; do
        name="${entry#* }"
        if [[ "$name" =~ ^(.+)-[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
            agent="${BASH_REMATCH[1]}"
        else
            UNGROUPED=$((UNGROUPED + 1))
            continue
        fi

        n=$(( ${seen[$agent]:-0} + 1 ))
        seen[$agent]=$n
        if [ "$n" -le "$KEEP" ]; then
            KEPT=$((KEPT + 1))
            continue
        fi

        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[dry-run] would archive: $area/$name  (agent=$agent, #$n)"
        else
            mkdir -p "$archive_dir"
            mv "${area_dir%/}/$name" "$archive_dir/"
            echo "archived: $area/$name"
        fi
        ARCHIVED=$((ARCHIVED + 1))
    done
    unset seen
done

echo ""
echo "Summary: kept=$KEPT, archived=$ARCHIVED, ungrouped_untouched=$UNGROUPED, keep_per_agent=$KEEP"
echo "Skipped areas: $SKIP_AREAS"
[ "$DRY_RUN" -eq 1 ] && echo "(dry-run mode, no changes made)"
exit 0
