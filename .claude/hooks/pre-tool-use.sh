#!/bin/bash
# Pre Tool Use Hook — 任務模式閘門
#
# 這是模板裡「唯一能真正攔截」的位置。它負責把 task-mode.md 的「入口自動分級」
# 從散文變成機器強制：
#
#   1. 寫入程式碼檔前，若 .current-task-mode 不存在 → deny，要求主模型先判級再重試
#   2. TTL 過期自動清除 —— 解掉「/verify 沒清 → 判級永久不觸發」的互鎖
#   3. 裸 cd 偵測（Bash）—— 取代已移除的 rules/bash-cwd.md，改由機器強制
#   4. 輕量 log
#
# 逃生門（任一成立即完全不攔）：
#   - .suggest-mode 內容為 off
#   - 環境變數 TASKMODE_GATE=off
#   - jq 不可用（無法解析輸入，寧可放行也不誤擋）
#
# 可調參數：
#   TASKMODE_TTL_HOURS  模式檔多久算過期（預設 8，即一個工作 session）

set -u

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
DATA_DIR="$CLAUDE_DIR/taskmaster-data"
MODE_FILE="$DATA_DIR/.current-task-mode"
TTL_HOURS="${TASKMODE_TTL_HOURS:-8}"

mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] pre-tool: $*" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
}

INPUT=$(cat)

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
if [ -f "$DATA_DIR/.suggest-mode" ]; then
    SUGGEST_MODE=$(tr -d '[:space:]' < "$DATA_DIR/.suggest-mode" 2>/dev/null || echo "medium")
    [ -z "$SUGGEST_MODE" ] && SUGGEST_MODE="medium"
fi
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
NORM=$(printf '%s' "$FILE_PATH" | tr '\\' '/')

# 排除：模板自身設定、依賴、建置產物 —— 這些不算「實作型」寫入
case "$NORM" in
    */.claude/*|.claude/*) exit 0 ;;
    */node_modules/*|*/.venv/*|*/venv/*|*/dist/*|*/build/*|*/.next/*|*/target/*) exit 0 ;;
    */docs/*|*/.git/*) exit 0 ;;
esac

# 只有這些副檔名視為程式碼
case "$NORM" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.vue|*.svelte) ;;
    *.py|*.go|*.rs|*.rb|*.php|*.java|*.kt|*.scala|*.swift|*.cs|*.ex|*.exs) ;;
    *.c|*.cc|*.cpp|*.h|*.hpp|*.sql|*.sh|*.ps1) ;;
    *) exit 0 ;;
esac

# 模式已存在 → 放行（一個任務只會擋第一次）
[ -f "$MODE_FILE" ] && [ -s "$MODE_FILE" ] && exit 0

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
