#!/bin/bash
# Pre Tool Use Hook — 任務模式閘門
#
# 這是模板裡「唯一能真正攔截」的位置。它負責把 task-mode.md 的「入口自動分級」
# 從散文變成機器強制：
#
#   1. 寫入程式碼檔前，若 .current-task-mode 不存在 → deny，要求主模型先判級再重試
#   2. TTL 過期自動清除 —— 解掉「/verify 沒清 → 判級永久不觸發」的互鎖
#   3. 坑閘門 —— 要寫的檔案在 context/learned/ 有紀錄時擋一次，把教訓貼給模型
#   4. 裸 cd 偵測（Bash）—— 取代已移除的 rules/bash-cwd.md，改由機器強制
#   5. 輕量 log
#
# 逃生門（任一成立即完全不攔）：
#   - .suggest-mode 內容為 off
#   - 環境變數 TASKMODE_GATE=off
#   - jq 不可用（無法解析輸入，寧可放行也不誤擋）
#
# 可調參數：
#   TASKMODE_TTL_HOURS  模式檔多久算過期（預設 8，即一個工作 session）
#   PITFALL_GATE=off    只關坑閘門，保留任務模式閘門

set -u

INPUT=$(cat)

# worktree 感知：任務模式等短命旗標跟著 worktree，坑紀錄與 log 留在主 checkout
source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$INPUT"
else
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    MAIN_CLAUDE="$MAIN_ROOT/.claude"; WORK_ROOT="$MAIN_ROOT"; WORK_CLAUDE="$MAIN_CLAUDE"; IN_WORKTREE=0
fi

PROJECT_ROOT="$WORK_ROOT"          # 閘門要判斷的檔案在當前 checkout 裡
CLAUDE_DIR="$MAIN_CLAUDE"          # log 集中主 checkout
DATA_DIR="$WORK_CLAUDE/taskmaster-data"   # 任務模式：每個 worktree 獨立
MODE_FILE="$DATA_DIR/.current-task-mode"
LEARNED_ROOT="$MAIN_CLAUDE"        # 坑紀錄：跨 worktree 共享
TTL_HOURS="${TASKMODE_TTL_HOURS:-8}"

mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] pre-tool${IN_WORKTREE:+[wt]}: $*" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
}

# jq 不可用 → 只 log 不攔（避免因環境缺依賴而擋住所有寫入）
if ! command -v jq >/dev/null 2>&1; then
    log "jq missing — gate skipped"
    exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

log "$TOOL_NAME ${FILE_PATH:-${COMMAND:0:60}}"

# ---------- 逃生門 ----------
[ "${TASKMODE_GATE:-on}" = "off" ] && exit 0

SUGGEST_MODE="medium"
# 讀主 checkout：/suggest-mode 是專案級設定，不該每個 worktree 各設一次
for smf in "$MAIN_CLAUDE/taskmaster-data/.suggest-mode" "$DATA_DIR/.suggest-mode"; do
    if [ -f "$smf" ]; then
        SUGGEST_MODE=$(tr -d '[:space:]' < "$smf" 2>/dev/null || echo "medium")
        [ -z "$SUGGEST_MODE" ] && SUGGEST_MODE="medium"
        break
    fi
done
[ "$SUGGEST_MODE" = "off" ] && exit 0

# 輸出 deny 決策（reason 會回饋給主模型，讓它自我修正後重試）
deny() {
    jq -n --arg r "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $r
        }
    }'
    exit 0
}

# ============================================================================
# Bash：裸 cd 偵測
# ============================================================================
if [ "$TOOL_NAME" = "Bash" ] && [ -n "$COMMAND" ]; then
    # 只擋「以 cd 開頭且整條指令沒有用 subshell/&& 收尾」的情況。
    # 允許：(cd x && y)、cd x && y、cd "$VAR" && y
    if printf '%s' "$COMMAND" | grep -qE '^[[:space:]]*cd[[:space:]]' \
       && ! printf '%s' "$COMMAND" | grep -qE '&&|;'; then
        log "bare cd blocked: ${COMMAND:0:80}"
        deny "偵測到裸 cd —— Bash tool 的 CWD 會跨呼叫持續存在，這會污染後續所有相對路徑指令。

請改用以下任一方式：
  • 絕對路徑：ls \"\$CLAUDE_PROJECT_DIR/.claude/hooks/\"
  • subshell 隔離：(cd subdir && npm test)
  • 鏈式：cd subdir && npm test

若確實要長駐該目錄（使用者明確要求），設 TASKMODE_GATE=off 後重試。"
    fi

    # 合併閘門：上一次合併未經 /verify 前，不得再合併下一個。
    # 拆成 lib 是照 CLAUDE.md 的提醒——本檔已是最複雜的一支。
    source "$(dirname "${BASH_SOURCE[0]}")/lib/merge-gate.sh" 2>/dev/null || true
    if declare -F merge_gate >/dev/null 2>&1; then
        merge_gate "$COMMAND" "$DATA_DIR"
    fi
fi

# 非 Write/Edit → 到此為止
case "$TOOL_NAME" in
    Write|Edit|MultiEdit) ;;
    *) exit 0 ;;
esac

[ -z "$FILE_PATH" ] && exit 0

# ============================================================================
# TTL 過期清除（先於閘門判斷，這是解互鎖的關鍵）
# ============================================================================
if [ -f "$MODE_FILE" ]; then
    now=$(date +%s)
    mtime=$(stat -c %Y "$MODE_FILE" 2>/dev/null || stat -f %m "$MODE_FILE" 2>/dev/null || echo "$now")
    age_h=$(( (now - mtime) / 3600 ))
    if [ "$age_h" -ge "$TTL_HOURS" ]; then
        rm -f "$MODE_FILE" 2>/dev/null
        log "mode expired (${age_h}h >= ${TTL_HOURS}h) — cleared"
    fi
fi

# ============================================================================
# 任務模式閘門：只攔「程式碼檔」
# ============================================================================

# 正規化成正斜線，方便比對
NORM=$(printf '%s' "$FILE_PATH" | tr '\' '/')

# 轉成「相對當前 checkout root」再比對排除規則。
#
# 為什麼不能用絕對路徑做子字串比對：worktree 住在 `.claude/worktrees/<name>/`，
# 所以 worktree 裡**每個**檔案的絕對路徑都含有 `/.claude/`。用 `*/.claude/*`
# 比對會把整個 worktree 的檔案都當成「模板自身設定」放行，任務模式閘門與
# 坑閘門在 worktree 裡就全部失效。（此 bug 由 tests 的 worktree 案例抓出。）
WORK_NORM=$(printf '%s' "$WORK_ROOT" | tr '\' '/')
REL_PATH="${NORM#"$WORK_NORM"/}"

if [ "$REL_PATH" != "$NORM" ]; then
    # 成功相對化 → 樣式錨定在開頭，不會被路徑中段的同名目錄誤命中
    case "$REL_PATH" in
        .claude/*) exit 0 ;;
        node_modules/*|.venv/*|venv/*|dist/*|build/*|.next/*|target/*) exit 0 ;;
        docs/*|.git/*) exit 0 ;;
    esac
    # monorepo 的巢狀依賴／產物
    case "$REL_PATH" in
        */node_modules/*|*/.venv/*|*/venv/*|*/dist/*|*/build/*|*/.next/*|*/target/*) exit 0 ;;
        */.git/*) exit 0 ;;
    esac
else
    # 檔案不在當前 checkout 內（或無法相對化）→ 退回絕對路徑比對，維持舊行為，
    # 但 worktree 內的檔案不套用 .claude 放行
    case "$NORM" in
        */.claude/worktrees/*) ;;
        */.claude/*|.claude/*) exit 0 ;;
    esac
    case "$NORM" in
        */node_modules/*|*/.venv/*|*/venv/*|*/dist/*|*/build/*|*/.next/*|*/target/*) exit 0 ;;
        */docs/*|*/.git/*) exit 0 ;;
    esac
fi

# 只有這些副檔名視為程式碼
case "$NORM" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.vue|*.svelte) ;;
    *.py|*.go|*.rs|*.rb|*.php|*.java|*.kt|*.scala|*.swift|*.cs|*.ex|*.exs) ;;
    *.c|*.cc|*.cpp|*.h|*.hpp|*.sql|*.sh|*.ps1) ;;
    *) exit 0 ;;
esac

# ============================================================================
# 坑閘門：這個檔案以前踩過坑嗎
#
# 為什麼要攔而不是提示：PreToolUse 不支援 additionalContext（只認
# permissionDecision / permissionDecisionReason），所以「提醒」在這個 hook 事件
# 裡無法非阻斷式送達。改用與任務模式閘門相同的 deny-once 模式：擋第一次、
# 把坑貼給模型看、記錄後放行。同一個檔案一個 session 只會擋一次。
#
# 逃生門：PITFALL_GATE=off（或 .suggest-mode off，已於上方處理）
# ============================================================================
LEARNED_DIR="$LEARNED_ROOT/context/learned"   # 共享
SEEN_FILE="$DATA_DIR/.pitfall-seen"          # 每個 worktree 各自提醒一次

# 取 frontmatter 的純量欄位
fm_field() {
    awk -v key="$2" '
        NR==1 && $0 !~ /^---/ { exit }
        /^---[[:space:]]*$/ { fm++; if (fm==2) exit; next }
        fm==1 && index($0, key ":") == 1 {
            sub("^" key ":[[:space:]]*", "", $0)
            gsub(/^["'"'"']|["'"'"']$/, "", $0)
            print; exit
        }
    ' "$1" 2>/dev/null
}

# 取 frontmatter 的 files: 樣式（同時支援 inline ["a","b"] 與區塊 - "a" 兩種寫法）
fm_files() {
    awk '
        NR==1 && $0 !~ /^---/ { exit }
        /^---[[:space:]]*$/ { fm++; if (fm==2) exit; next }
        fm==1 {
            if (index($0, "files:") == 1) {
                rest = $0; sub(/^files:[[:space:]]*/, "", rest)
                if (rest != "") { print rest } else { inlist = 1 }
                next
            }
            if (inlist && $0 ~ /^[[:space:]]*-[[:space:]]*/) {
                sub(/^[[:space:]]*-[[:space:]]*/, "", $0); print; next
            }
            if (inlist && $0 ~ /^[^[:space:]-]/) { inlist = 0 }
        }
    ' "$1" 2>/dev/null | tr -d '[]",' | tr "'" ' '
}

pitfall_gate() {
    local target="$1"
    [ "${PITFALL_GATE:-on}" = "off" ] && return 0
    [ -d "$LEARNED_DIR" ] || return 0

    # 專案根相對路徑：learned 的 files: 用相對路徑寫，但工具給的是絕對路徑
    local root_norm rel
    root_norm=$(printf '%s' "$PROJECT_ROOT" | tr '\\' '/')
    rel="${target#"$root_norm"/}"

    local hits="" f base pat title guard symptom cause sev matched
    for f in "$LEARNED_DIR"/*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        case "$base" in _*|README.md) continue ;; esac

        matched=0
        for pat in $(fm_files "$f"); do
            [ -n "$pat" ] || continue
            case "$rel" in $pat) matched=1 ;; esac
            case "$target" in $pat|*/$pat) matched=1 ;; esac
            [ "$matched" -eq 1 ] && break
        done
        [ "$matched" -eq 1 ] || continue

        # 同一 session 同一 (檔案, 坑) 只擋一次
        grep -qxF "$rel|$base" "$SEEN_FILE" 2>/dev/null && continue

        title=$(fm_field "$f" title);      [ -z "$title" ] && title="$base"
        guard=$(fm_field "$f" guard)
        symptom=$(fm_field "$f" symptom)
        cause=$(fm_field "$f" root-cause)
        sev=$(fm_field "$f" severity);     [ -z "$sev" ] && sev="medium"

        hits="${hits}
▸ [$sev] $title
   症狀：${symptom:-（未記錄）}
   根因：${cause:-（未記錄）}
   避法：${guard:-（未記錄）}
   全文：.claude/context/learned/$base
"
        mkdir -p "$DATA_DIR" 2>/dev/null
        printf '%s|%s\n' "$rel" "$base" >> "$SEEN_FILE" 2>/dev/null || true
    done

    [ -z "$hits" ] && return 0

    log "pitfall gate: $rel"
    deny "⚠️ 這個檔案以前踩過坑，先讀完再改：
${hits}
這些紀錄來自 \`.claude/context/learned/\`（本專案累積的教訓）。

請確認你的修改沒有重蹈覆轍，然後**重試同一次編輯**即可通過（同一檔案一個 session 只擋一次）。
若判斷該紀錄已過期或不再適用，改掉或刪掉那份 learned 檔，不要繞過閘門。
（完全關閉：環境變數 PITFALL_GATE=off）"
}

# 模式已存在 → 任務模式閘門放行，但仍要過坑閘門
if [ -f "$MODE_FILE" ] && [ -s "$MODE_FILE" ]; then
    pitfall_gate "$NORM"
    exit 0
fi

log "gate triggered: no task mode for $NORM"
deny "尚未判定任務模式，不能開始寫程式碼（rules/task-mode.md 的入口自動分級）。

請依啟發式判定並用一句話宣告理由，然後寫入模式檔再重試本次編輯：

  quick     單檔 + <30min + 文案/樣式/設定/小 bug
  standard  跨檔 / 新功能 / 重構
  critical  auth / 金流 / 安全 / migration / 核心商業邏輯

寫入方式（擇一）：
  echo standard > \"\$CLAUDE_PROJECT_DIR/.claude/taskmaster-data/.current-task-mode\"

判不準時往上一級靠。使用者可當場一句話否決你的判定。
（不想被攔：/suggest-mode off，或設環境變數 TASKMODE_GATE=off）"
