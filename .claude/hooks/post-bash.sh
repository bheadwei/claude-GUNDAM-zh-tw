#!/bin/bash
# Post Bash Hook — PostToolUse(Bash)
#
# 職責：偵測「踩到坑」的時刻並累積候選，讓 learned/ 不再靠使用者記得下 /learn。
#
# 為什麼需要：`using-taskmaster` 要求「解完非平凡問題後寫一筆進 learned/」，
# 但那是文字規則——沒有任何機制在該寫的當下提出來，所以實際上幾乎不會發生。
# 而「踩到坑」有一個機器判斷得出的訊號：**同一件事連續失敗好幾次、然後成功**。
# 一次就過的不是坑；試了四次才過的就是。
#
# 這裡只累積候選 + 提醒一次，不要求當下停下來處理（那會打斷正在解問題的人）。
# session-start.sh 在下次開場提醒清單還沒清空。
#
# 逃生門：LEARN_CAPTURE=off、或 .suggest-mode 為 off

INPUT=$(cat)

source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$INPUT"
else
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    MAIN_CLAUDE="$MAIN_ROOT/.claude"; WORK_CLAUDE="$MAIN_CLAUDE"
fi

CLAUDE_DIR="$MAIN_CLAUDE"                  # log 集中
DATA_DIR="$WORK_CLAUDE/taskmaster-data"    # 失敗計數：每個 worktree 各自

[ "${LEARN_CAPTURE:-on}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

if [ -f "$DATA_DIR/.suggest-mode" ]; then
    sm=$(tr -d '[:space:]' < "$DATA_DIR/.suggest-mode" 2>/dev/null)
    [ "$sm" = "off" ] && exit 0
fi

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -n "$CMD" ] || exit 0

# 失敗判定：PostToolUse 的 tool_response 在指令非零退出時帶錯誤資訊。
# 不同版本的欄位名不一致，所以三個都看；都沒有就當成功。
FAILED=0
if printf '%s' "$INPUT" | jq -e '
      (.tool_response.is_error == true)
   or (.tool_response.interrupted == true)
   or ((.tool_response.exit_code // 0) != 0)
' >/dev/null 2>&1; then
    FAILED=1
fi

mkdir -p "$DATA_DIR" 2>/dev/null || true
STREAK="$DATA_DIR/.bash-fail-streak"
CAND="$DATA_DIR/.learned-candidates"
NOTIFIED="$DATA_DIR/.learned-notified"

# 連續失敗門檻。1-2 次失敗是打錯字，不是坑。
THRESHOLD="${LEARN_CAPTURE_THRESHOLD:-3}"

if [ "$FAILED" -eq 1 ]; then
    n=$(cat "$STREAK" 2>/dev/null | tr -dc '0-9')
    n=$(( ${n:-0} + 1 ))
    echo "$n" > "$STREAK" 2>/dev/null || true
    exit 0
fi

# 成功了 —— 看它前面失敗了幾次
n=$(cat "$STREAK" 2>/dev/null | tr -dc '0-9')
n=${n:-0}
: > "$STREAK" 2>/dev/null || true
[ "$n" -lt "$THRESHOLD" ] && exit 0

# 記一筆候選（單行，供 /learn 逐筆判斷）。指令截短避免整份 heredoc 進清單。
SHORT=$(printf '%s' "$CMD" | tr '\n' ' ' | cut -c1-120)
echo "[$(date '+%Y-%m-%d %H:%M')] ${n} 次失敗後成功：${SHORT}" >> "$CAND" 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] learn-candidate: streak=$n" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true

# 本任務只提醒一次，避免正在除錯的人被反覆打斷
[ -f "$NOTIFIED" ] && exit 0
: > "$NOTIFIED" 2>/dev/null || true

jq -n --arg n "$n" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("🧠 這是一個坑：剛才那個指令失敗 " + $n + " 次才成功。\n\n候選已記進 `.claude/taskmaster-data/.learned-candidates`。**現在不用停下來**——繼續把手上的問題解完。\n\n收尾時（或下次開場被提醒時）判斷這筆值不值得留：真的是環境／工具／平台的坑就用 `/learn` 寫進 `.claude/context/learned/`（`pre-tool-use.sh` 之後會在碰到同一個檔案時把它貼出來，同一個坑不會踩第二次）；只是自己打錯字就從清單刪掉。\n（本任務只提醒這一次。關閉：LEARN_CAPTURE=off）")
  }
}' 2>/dev/null || true

exit 0
