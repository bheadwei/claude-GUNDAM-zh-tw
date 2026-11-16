#!/bin/bash
# agent-events.sh — SessionStart／SubagentStart／SubagentStop／Notification／PermissionRequest／UserPromptSubmit／Stop／
#                   PreToolUse(AskUserQuestion|Bash|PowerShell)／PostToolUse(全部工具)
#
# 把事件壓成一行附加到 $MAIN_CLAUDE/logs/live-events.jsonl，給專案圖解的「現況」分頁用。
# 契約（事件格式、白名單、need 規則、為什麼不能當閘門）：ADR-2026-11-12-002。
#
# SessionStart 只記 source（startup／resume／clear／compact）到 ss 欄，給 --live 判斷「被中斷的 agent」；
# 其他事件 ss 為空字串。v 仍是 1（只加欄位，讀取端容忍舊行沒有 ss）。
#
# 只寫不讀、永遠無輸出、永遠 exit 0；全部接線都是 async（順序不保證，所以有 ms 欄）。
# 閘門不得讀這份檔（pre-agent-gate.sh、lib/agent-inflight.sh 看的是 agent-activity.jsonl）。
#
# 逃生門：OVERVIEW=off 或 OVERVIEW_LIVE=off（不寫、不觸發）；
# OVERVIEW_SYNC=1 改前景觸發（測試用）；OVERVIEW_LIVE_WINDOW_SEC 觸發視窗秒數（預設 2）

# 時間戳放最前面，越早取越接近事件發生時刻。EPOCHREALTIME 是 bash 5 才有；
# 沒有時改用 GNU date 的毫秒，再不行（macOS）只有整秒、ms 記 0
if [ -n "${EPOCHREALTIME:-}" ]; then
    AE_T=${EPOCHREALTIME%[.,]*}
    AE_F="${EPOCHREALTIME#*[.,]}000"
    AE_MS=$((10#${AE_F:0:3}))
else
    AE_D=$(date +%s%3N 2>/dev/null)
    if [[ $AE_D =~ ^[0-9]{13,}$ ]]; then
        AE_T=${AE_D::${#AE_D}-3}
        AE_MS=$((10#${AE_D: -3}))
    else
        AE_T=$(date +%s 2>/dev/null)
        AE_MS=0
    fi
fi

[ "${OVERVIEW:-on}" = "off" ] && exit 0
[ "${OVERVIEW_LIVE:-on}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
[ -n "$INPUT" ] || exit 0

AE_DIR=${BASH_SOURCE[0]%/*}
[ "$AE_DIR" = "${BASH_SOURCE[0]}" ] && AE_DIR=.
source "$AE_DIR/lib/resolve-roots.sh" 2>/dev/null || exit 0
resolve_roots "$INPUT"

AE_ROOT="${WORK_ROOT//'\'//}"
AE_SRC=main
[ "$IN_WORKTREE" = "1" ] && AE_SRC="worktree:${AE_ROOT##*/}"

AE_LINE=$(printf '%s' "$INPUT" | jq -c --argjson tt "${AE_T:-0}" --argjson msv "$AE_MS" \
    --arg srcv "$AE_SRC" --arg rootv "$AE_ROOT" '
  def str: if type == "string" then . elif . == null then "" else tostring end;
  def cap(n): if length > n then .[:n] else . end;
  def tailcap(n): if length > n then "…" + .[length - (n - 1):] else . end;
  def norm: str | gsub("\\\\"; "/");
  def fname: norm | sub("^.*/"; "");
  def word:
    str
    | until(test("^\\s*[A-Za-z_][A-Za-z0-9_]*=") | not;
            sub("^\\s*[A-Za-z_][A-Za-z0-9_]*=(\"[^\"]*\"|\\x27[^\\x27]*\\x27|\\S*)"; ""))
    | sub("^\\s+"; "")
    | (capture("^(?<w>\\S+)") // {w: ""}).w
    | sub("^.*[/\\\\]"; "")
    | if test("^[A-Za-z0-9_.+-]+$") then . else "" end;
  def fit:
    def over: (tojson | utf8bytelength) > 1000;
    (if over then .text |= cap(40) else . end)
    | (if over then .act |= cap(40) else . end)
    | (if over then .file |= (split("/") | last // "") else . end)
    | (if over then (.file = "" | .text |= cap(20) | .act |= cap(20)) else . end);

  select(type == "object" and (.hook_event_name | type) == "string" and .hook_event_name != "")
  | . as $p
  | ($p.hook_event_name) as $ev
  | ($p.tool_name | str) as $tool
  | (["Write", "Edit", "MultiEdit", "Bash", "PowerShell", "AskUserQuestion"] | index($tool) != null) as $listed
  | (($ev == "PreToolUse" or $ev == "PostToolUse") and ($listed | not)) as $other
  | (if ($p.tool_input | type) == "object" and ($other | not) then $p.tool_input else {} end) as $ti
  | ($ti.file_path | norm) as $fp
  | ($ti.description | str) as $desc
  | ($ti.command | word) as $w
  | ($p.notification_type | str) as $ntype
  | (if $fp == "" then ""
     elif ($fp | startswith($rootv + "/")) then $fp[($rootv | length) + 1:]
     elif ($fp | test("^(/|[A-Za-z]:)")) then ""
     else $fp end) as $rel
  | (($tool == "Bash" or $tool == "PowerShell")) as $isshell
  | ($tool == "Write" or $tool == "Edit" or $tool == "MultiEdit") as $iswrite
  | (if ($ev == "PreToolUse" or $ev == "PostToolUse") and $isshell then
       (if $desc != "" then "跑 " + $desc elif $w != "" then "跑 " + $w else "跑指令" end)
     elif ($ev == "PreToolUse" or $ev == "PostToolUse") and $iswrite and $fp != "" then "編輯 " + ($fp | fname)
     elif $other then "用 " + ($tool | cap(40))
     else "" end) as $act
  | (if $ev == "PermissionRequest" then
       (if $isshell then $tool + "：" + (if $desc != "" then $desc elif $w != "" then $w else "指令" end)
        elif $iswrite and $fp != "" then $tool + "：" + ($fp | fname)
        else $tool end)
     elif $ev == "Notification" then ($p.message | str)
     elif $ev == "PreToolUse" and $tool == "AskUserQuestion" then
       ((($ti.questions // []) | if type == "array" then .[0] else null end)
        | if type == "object" then .question | str else "" end)
     else "" end) as $text
  | (if $ev == "PermissionRequest" then "approve"
     elif $ev == "Notification" then
       (if $ntype == "permission_prompt" then "approve"
        elif $ntype == "idle_prompt" or $ntype == "elicitation_dialog" then "reply"
        else null end)
     elif $ev == "PreToolUse" and $tool == "AskUserQuestion" then "reply"
     else null end) as $need
  | {v: 1, t: $tt, ms: $msv, ev: ($ev | cap(40)),
     sid: ($p.session_id | str | cap(64)), aid: ($p.agent_id | str | cap(40)), at: ($p.agent_type | str | cap(40)),
     src: ($srcv | cap(60)), tool: ($tool | cap(40)), file: ($rel | tailcap(120)),
     act: ($act | cap(80)), need: $need, nt: ($ntype | cap(30)), text: ($text | cap(120)),
     ss: (if $ev == "SessionStart" then ($p.source | str | cap(10)) else "" end)}
  | fit' 2>/dev/null)

[ -n "$AE_LINE" ] || exit 0

mkdir -p "$MAIN_CLAUDE/logs" 2>/dev/null
printf '%s\n' "$AE_LINE" >> "$MAIN_CLAUDE/logs/live-events.jsonl" 2>/dev/null

# ---------------------------------------------------------------- 觸發 overview.sh --live
#
# 沒有 project.json（模板 repo 本身）不觸發。視窗內只留 .live-dirty，由 --live 自己再跑一輪；
# 視窗判斷只用 bash 內建（寫法同 post-write.sh 的 .scan-at）。
# 戳記與 dirty 旗標是共享產物（一份聚合、多條線寫），放主 checkout 的 overview 目錄。
OV_SH="$MAIN_CLAUDE/scripts/overview.sh"
[ -f "$OV_SH" ] || exit 0
[ -f "$MAIN_CLAUDE/taskmaster-data/project.json" ] || [ -f "$WORK_CLAUDE/taskmaster-data/project.json" ] || exit 0

OV_DIR="$MAIN_CLAUDE/taskmaster-data/overview"
AE_AT=0
[ -f "$OV_DIR/.live-at" ] && read -r AE_AT _ < "$OV_DIR/.live-at"
[[ $AE_AT =~ ^[0-9]+$ ]] || AE_AT=0
AE_WIN=${OVERVIEW_LIVE_WINDOW_SEC:-2}
[[ $AE_WIN =~ ^[0-9]+$ ]] || AE_WIN=2
[[ $AE_T =~ ^[0-9]+$ ]] || exit 0

if (( AE_T - AE_AT < AE_WIN )); then
    [ -d "$OV_DIR" ] && : > "$OV_DIR/.live-dirty" 2>/dev/null
    exit 0
fi

if [ ! -d "$OV_DIR" ]; then
    mkdir -p "$OV_DIR" 2>/dev/null && printf '*\n' > "$OV_DIR/.gitignore" 2>/dev/null
fi
# 過渡守衛：overview.sh 還不認 --live 時會把它當成 WORK_ROOT。只在真的要觸發時才檢查
if ! grep -q -- '--live' "$OV_SH" 2>/dev/null; then
    : > "$OV_DIR/.live-dirty" 2>/dev/null
    exit 0
fi
# 視窗秒數一起記：--live 跑完要持鎖等到視窗結束、補跑視窗內留下的 .live-dirty，用的是這裡同一個值
printf '%s %s\n' "$AE_T" "$AE_WIN" > "$OV_DIR/.live-at" 2>/dev/null

if [ "${OVERVIEW_SYNC:-}" = "1" ]; then
    bash "$OV_SH" --live "$WORK_ROOT" </dev/null >/dev/null 2>&1
else
    ( nohup bash "$OV_SH" --live "$WORK_ROOT" </dev/null >/dev/null 2>&1 & )
fi
exit 0
