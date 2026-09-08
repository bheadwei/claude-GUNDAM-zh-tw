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

INPUT=$(cat)

source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$INPUT"
else
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    MAIN_CLAUDE="$MAIN_ROOT/.claude"; WORK_ROOT="$MAIN_ROOT"; WORK_CLAUDE="$MAIN_CLAUDE"; IN_WORKTREE=0
fi

PROJECT_ROOT="$WORK_ROOT"                  # 判斷寫入檔案是否為「文件描述的對象」
CLAUDE_DIR="$MAIN_CLAUDE"                  # log 集中
DATA_DIR="$WORK_CLAUDE/taskmaster-data"    # .doc-impact：每個 worktree 各自累積
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true
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
command -v jq >/dev/null 2>&1 || exit 0

if [ -f "$DATA_DIR/.suggest-mode" ]; then
    sm=$(tr -d '[:space:]' < "$DATA_DIR/.suggest-mode" 2>/dev/null)
    [ "$sm" = "off" ] && exit 0
fi

NORM=$(printf '%s' "$FILE_PATH" | tr '\\' '/')
ROOT_NORM=$(printf '%s' "$PROJECT_ROOT" | tr '\\' '/')
REL="${NORM#"$ROOT_NORM"/}"

# ---------------------------------------------------------------- 擴充維護提醒
#
# 為什麼是 hook 而不是指令：`/learn`、`/skill-audit` 這類入口都要使用者自己想起來
# 並手動輸入，而「改了 skill 卻沒接線／沒更新 INDEX」的當下使用者不會知道要跑。
# 判斷得出時機的事就該由機器提出——照 writing-extensions 的五層決策表。
#
# 這裡刻意**不跑** check-counts.sh：hook 在這台機器上單次已要 7-9 秒，
# 再加一次全掃會讓每次寫檔都變慢。累積清單就好，skill-curator 自己會跑。
if [ "${SKILL_CURATOR_GATE:-on}" != "off" ]; then
    # 這裡刻意比對絕對路徑 $NORM 而非相對化的 $REL：`.claude/` 本身就是要找的錨點，
    # 而 payload 沒帶 `cwd` 時 PROJECT_ROOT 會解析深一層、讓 REL 掉掉 `.claude/` 前綴。
    # worktree 內的 `.claude/skills/` 也該命中——那是真的在改擴充。
    EXT_BEARING=0
    case "/$NORM" in
        */.claude/skills/*|*/.claude/agents/*|*/.claude/commands/*|*/.claude/rules/*|*/.claude/hooks/*)
            EXT_BEARING=1 ;;
    esac
    # 排除測試與執行時產物，避免跑測試或寫報告時自己觸發自己
    case "/$NORM" in
        */.claude/hooks/tests/*|*/.claude/tests/*|*/.claude/context/*|*/.claude/coordination/*|*/.claude/taskmaster-data/*)
            EXT_BEARING=0 ;;
    esac

    if [ "$EXT_BEARING" -eq 1 ]; then
        mkdir -p "$DATA_DIR" 2>/dev/null || true
        SK_IMPACT="$DATA_DIR/.skill-impact"
        SK_NOTIFIED="$DATA_DIR/.skill-impact-notified"

        grep -qxF "$REL" "$SK_IMPACT" 2>/dev/null || echo "$REL" >> "$SK_IMPACT" 2>/dev/null || true

        if [ ! -f "$SK_NOTIFIED" ]; then
            : > "$SK_NOTIFIED" 2>/dev/null || true
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] skill-impact: $REL" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
            jq -n --arg f "$REL" '{
              hookSpecificOutput: {
                hookEventName: "PostToolUse",
                additionalContext: ("🧩 擴充維護提醒：你剛改了 `" + $f + "`。\n\n改動 `.claude/` 底下的擴充有三件事會**安靜失效**（不會報錯）：接線沒接上（agent 拿不到 `Skill` 工具，只認完整路徑）、`INDEX.md` 沒同步、description 是內容摘要所以永遠不會被喚起。\n\n變更清單累積在 `.claude/taskmaster-data/.skill-impact`。現在不用停下來，繼續做即可；**收尾時委派 `skill-curator`**（`subagent_type: \"skill-curator\"`）一次處理完並跑 `scripts/check-counts.sh`。\n（本任務只提醒這一次。關閉：SKILL_CURATOR_GATE=off）")
              }
            }' 2>/dev/null || true
            exit 0
        fi
    fi
fi

[ "${DOC_SYNC_GATE:-on}" = "off" ] && exit 0

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
