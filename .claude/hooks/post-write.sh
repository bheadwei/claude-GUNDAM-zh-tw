#!/bin/bash
# Post Write Hook — PostToolUse(Write|Edit)
#
# 兩個職責：
#   (1) WBS 寫入歷史（沿用）
#   (2) 文件影響偵測：寫到「文件會描述的檔案」（API 路由、schema、對外介面…）時，
#       記進 .doc-impact 並在本任務第一次命中時注入提醒。
#       /verify 在標記 WBS ✅ 前必須處理這份清單。
#
# 為什麼需要 (2)：新需求／客戶 CR 的程式都會寫出來，但文件常常沒跟上。
# 原因是 documentation-specialist 在「任務完成路徑」上完全沒有位置——
# /verify 只驗建置/型別/lint/測試，從不問文件。靠自律記得同步文件是行不通的，
# 所以改成：機器在改動當下就標記，並在任務收尾時擋一次。
#
# 逃生門：DOC_SYNC_GATE=off、或 .suggest-mode 為 off

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
DATA_DIR="$CLAUDE_DIR/taskmaster-data"
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true

INPUT=$(cat)
FILE_PATH=""
command -v jq >/dev/null 2>&1 && FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# WBS 更新時記錄歷史
if [[ "$FILE_PATH" == *"taskmaster-data/wbs.md"* ]]; then
    mkdir -p "$DATA_DIR" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WBS updated" >> "$DATA_DIR/wbs-history.log" 2>/dev/null
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] post-write: $FILE_PATH" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true

# ============================================================================
# (2) 文件影響偵測
# ============================================================================
[ -z "$FILE_PATH" ] && exit 0
[ "${DOC_SYNC_GATE:-on}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

if [ -f "$DATA_DIR/.suggest-mode" ]; then
    sm=$(tr -d '[:space:]' < "$DATA_DIR/.suggest-mode" 2>/dev/null)
    [ "$sm" = "off" ] && exit 0
fi

NORM=$(printf '%s' "$FILE_PATH" | tr '\\' '/')
ROOT_NORM=$(printf '%s' "$PROJECT_ROOT" | tr '\\' '/')
REL="${NORM#"$ROOT_NORM"/}"

# 先排除：模板自身、依賴、建置產物、文件本身、測試
case "$REL" in
    .claude/*|*/.claude/*) exit 0 ;;
    docs/*|*/docs/*) exit 0 ;;
    node_modules/*|*/node_modules/*|.venv/*|*/.venv/*|venv/*|*/venv/*) exit 0 ;;
    dist/*|*/dist/*|build/*|*/build/*|.next/*|*/.next/*|target/*|*/target/*) exit 0 ;;
    .git/*|*/.git/*) exit 0 ;;
    *test*|*spec*|*__tests__*|*fixtures*) exit 0 ;;
esac

# 文件會描述的檔案 —— 改到這些，文件就有機會過期
DOC_BEARING=0
case "$REL" in
    */api/*|api/*|*/routes/*|routes/*|*/router/*|*/controllers/*|*/handlers/*|*/endpoints/*)
        DOC_BEARING=1 ;;
    *openapi*|*swagger*|*.proto|*.graphql|*schema.*|*/schema/*|*/schemas/*)
        DOC_BEARING=1 ;;
    */migrations/*|*/models/*|*/entities/*|*/dto/*)
        DOC_BEARING=1 ;;
    */index.ts|*/index.js|*/index.tsx|*.d.ts|*/public-api.ts)
        DOC_BEARING=1 ;;
    */cli/*|*/commands/*|.env.example)
        DOC_BEARING=1 ;;
esac
[ "$DOC_BEARING" -eq 0 ] && exit 0

mkdir -p "$DATA_DIR" 2>/dev/null || true
IMPACT_FILE="$DATA_DIR/.doc-impact"
NOTIFIED="$DATA_DIR/.doc-impact-notified"

# 去重後累積（/verify 會讀這份清單）
grep -qxF "$REL" "$IMPACT_FILE" 2>/dev/null || echo "$REL" >> "$IMPACT_FILE" 2>/dev/null || true

# 本任務只提醒一次，避免每次寫檔都吵
[ -f "$NOTIFIED" ] && exit 0
: > "$NOTIFIED" 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] doc-impact: $REL" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true

jq -n --arg f "$REL" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("📘 文件影響提醒：你剛改了 `" + $f + "`——這類檔案（API／路由／schema／對外介面／CLI）是文件描述的對象，改了文件就可能過期。\n\n本任務的影響清單累積在 `.claude/taskmaster-data/.doc-impact`，**`/verify` 在標記 WBS ✅ 前會擋下來要求處理**（同步文件或明確豁免）。現在不用停下來，繼續實作即可；收尾時委派 `documentation-specialist` 一次處理完。\n（本任務只提醒這一次。關閉：DOC_SYNC_GATE=off）")
  }
}' 2>/dev/null || true

exit 0
