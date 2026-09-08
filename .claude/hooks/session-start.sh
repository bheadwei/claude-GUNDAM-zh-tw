#!/bin/bash

# TaskMaster Session Start Hook
# 當 Claude Code 會話開始時自動執行
# 跨平台支援：Windows (Git Bash)、Windows WSL、macOS、Linux

# ============================================================================
# 平台檢測和兼容性設置
# ============================================================================

# 檢測操作系統平台
detect_platform() {
    local uname_output="$(uname -s)"

    # 優先檢查環境變量（更準確）
    # WSL_DISTRO_NAME 只存在於 WSL 環境
    if [ -n "$WSL_DISTRO_NAME" ]; then
        echo "wsl"
        return
    fi

    # 檢查是否在 Windows Git Bash
    # MSYSTEM 環境變量存在於 Git Bash
    if [ -n "$MSYSTEM" ]; then
        echo "windows"
        return
    fi

    # 使用 uname 判斷
    case "$uname_output" in
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        Linux)
            # 二次確認是否為 WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

PLATFORM=$(detect_platform)

# Windows 兼容性：不使用 set -e，改為手動錯誤處理
# set -e 會導致在 Windows 環境下任何非零退出碼都中斷執行

# 跨平台路徑處理
# CLAUDE_PROJECT_DIR 優先（與其他 hook 一致，也讓 tests/ 能在沙箱內隔離執行）；
# 缺席時退回腳本位置推導。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

# SessionStart 也可能在 worktree 裡啟動（claude --worktree）。
# log 與時間紀錄集中主 checkout；短命旗標則跟著當前 checkout。
SS_INPUT=$(cat 2>/dev/null || echo '{}')
source "$SCRIPT_DIR/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$SS_INPUT"
    PROJECT_ROOT="$MAIN_ROOT"
else
    PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)}"
    MAIN_CLAUDE="$PROJECT_ROOT/.claude"; WORK_CLAUDE="$MAIN_CLAUDE"; WORK_ROOT="$PROJECT_ROOT"; IN_WORKTREE=0
fi
CLAUDE_DIR="$PROJECT_ROOT/.claude"

# 路徑驗證（所有平台）
if [ -z "$PROJECT_ROOT" ] || [ -z "$CLAUDE_DIR" ]; then
    echo "❌ 無法確定專案路徑 (Platform: $PLATFORM)" >&2
    exit 0  # 改為 exit 0，避免中斷 Claude Code
fi

# 確保 logs 目錄存在
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null

# 日誌函數（跨平台兼容、只寫檔案不污染 stdout）
log() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '????-??-?? ??:??:??')]"
    echo "$timestamp $1" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
}

log "🪝 TaskMaster Session Start Hook 觸發 (Platform: $PLATFORM)"

# ============================================================================
# 輸出通道分流
#
# 本 hook 的 stdout 必須是單一 JSON（hookSpecificOutput.additionalContext），
# 混入裝飾性 banner 會讓 Claude Code 解析失敗。因此：
#   - 給人看的 ANSI banner → /dev/tty（直寫終端，繞過 stdout）
#   - 給模型看的指示       → 累積進 CONTEXT_NOTES，最後由 finish() 一次輸出
# 無 tty 時（CI、非互動）banner 直接丟棄，指示仍然送達。
# ============================================================================
# -c/-w 測試會誤判：Git Bash 下 /dev/tty 存在且看似可寫，但 stdin 被重導時
# 實際開啟會噴 "No such device or address"。唯一可靠的判斷是真的試寫一次。
BANNER_SINK="/dev/null"
if { printf '' > /dev/tty; } 2>/dev/null; then BANNER_SINK="/dev/tty"; fi

CONTEXT_NOTES=""
note() { CONTEXT_NOTES="${CONTEXT_NOTES}$1
"; }

banner() { echo -e "$1" > "$BANNER_SINK" 2>/dev/null || true; }

# 把 using-taskmaster skill 全文包成強制指示注入。
# 這是「主模型會不會主動委派 agent」的唯一機器保證——rules/ 是軟規則，
# 對撞 Claude Code 內建的「非必要不開 Agent」預設會輸；SessionStart 注入不會。
emit_context() {
    local skill_file="$WORK_CLAUDE/skills/using-taskmaster/SKILL.md"
    [ -f "$skill_file" ] || skill_file="$CLAUDE_DIR/skills/using-taskmaster/SKILL.md"
    local payload="" skill_body=""

    [ -f "$skill_file" ] && skill_body=$(cat "$skill_file" 2>/dev/null)

    if [ -n "$skill_body" ]; then
        payload="<EXTREMELY_IMPORTANT>
你在一個 TaskMaster 專案裡。以下是 \`using-taskmaster\` skill 全文——它規定了
你何時**必須**委派專業 subagent、以及動工前必須先讀專案踩過的坑。
其餘 skill 用 Skill 工具按需載入。

${skill_body}
</EXTREMELY_IMPORTANT>"
    fi

    [ -n "$CONTEXT_NOTES" ] && payload="${payload}

${CONTEXT_NOTES}"

    [ -z "$payload" ] && return 0

    if command -v jq >/dev/null 2>&1; then
        jq -n --arg c "$payload" '{
            hookSpecificOutput: {
                hookEventName: "SessionStart",
                additionalContext: $c
            }
        }'
    else
        # jq 缺席時的純 bash 轉義（每個 ${s//old/new} 是一次 C 層掃描，夠快）
        local s="$payload"
        s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
        s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
        printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$s"
    fi
}

finish() { emit_context; exit 0; }

# 依賴健檢：多個 hook（agent-monitor、handoff 注入、意圖路由）依賴 jq；缺少時提示使用者
if ! command -v jq >/dev/null 2>&1; then
    log "⚠️ jq 未安裝：agent 監控與 handoff 自動注入將靜默停用"
    note "⚠️ jq 未安裝 — agent 監控與 handoff 自動注入會停用。安裝：Windows \`winget install jqlang.jq\`、macOS \`brew install jq\`、Linux \`apt install jq\`。"
fi

# ============================================================================
# 待收割的擴充維護工作
#
# 這兩件事都靠使用者「記得下指令」就會無限延後——而它們的時機機器判斷得出來，
# 所以由 SessionStart 提出。兩者都是提醒，不阻擋任何操作。
# 逃生門：CURATION_REMINDERS=off
# ============================================================================
if [ "${CURATION_REMINDERS:-on}" != "off" ]; then
    _DATA="$CLAUDE_DIR/taskmaster-data"

    # ① 踩過的坑還沒寫進 learned/
    #    候選由 post-bash.sh 在「連續失敗後成功」時累積——那就是踩到坑的訊號。
    _CAND="$_DATA/.learned-candidates"
    if [ -s "$_CAND" ]; then
        _N=$(grep -c . "$_CAND" 2>/dev/null || echo 0)
        note "🧠 有 ${_N} 筆「踩過的坑」候選還沒寫進 \`.claude/context/learned/\`（清單在 \`taskmaster-data/.learned-candidates\`）。這些是連續失敗後才解掉的問題——同一個坑不該踩第二次。**現在就處理掉**：讀清單、逐筆判斷值不值得留，值得的用 \`/learn\` 寫進 \`learned/\`，不值得的直接從清單刪。處理完清空該檔。"
    fi

    # ② UI 素材庫太久沒跟上潮流
    #    90 天：設計走向與瀏覽器支援度大約這個週期會有實質變化。
    _UIREF="$_DATA/.ui-catalog-refreshed"
    _UISTALE=0
    if [ ! -f "$_UIREF" ]; then
        _UISTALE=1; _UIAGE="從未"
    elif [ -n "$(find "$_UIREF" -mtime +90 2>/dev/null)" ]; then
        _UISTALE=1; _UIAGE="超過 90 天"
    fi
    if [ "$_UISTALE" -eq 1 ] && [ -d "$CLAUDE_DIR/ui" ]; then
        note "🎨 UI 素材庫（\`.claude/ui/\`）${_UIAGE}更新。**使用者若要做前端工作**，可委派 \`skill-curator\`（\`subagent_type: \"skill-curator\"\`）查一輪當前設計走向並更新——跨風格通用的規則進 \`ui-style-compliance\` 的 2.6 節，個別品牌改版才動那份 DESIGN.md。不做前端就忽略這條，別主動打斷使用者。"
    fi
fi

# ============================================================================
# Log 輪替：僅在 session 啟動時執行一次（避免 per-call 成本），
# 將各 log 截尾保留最後 N 行，防止無限長大拖慢 /agent-log 等查詢。
# ============================================================================
rotate_log() {
    local file="$1" max="$2" lines tmp
    [ -f "$file" ] || return 0
    lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
    [ -z "$lines" ] && return 0
    if [ "$lines" -gt "$max" ] 2>/dev/null; then
        tmp="${file}.tmp.$$"
        if tail -n "$max" "$file" > "$tmp" 2>/dev/null; then
            mv -f "$tmp" "$file" 2>/dev/null || rm -f "$tmp" 2>/dev/null
            log "🧹 已輪替 $(basename "$file")（$lines → $max 行）"
        else
            rm -f "$tmp" 2>/dev/null
        fi
    fi
}
rotate_log "$CLAUDE_DIR/logs/agent-activity.log"   8000   # 多行/筆，約 ~570 筆
rotate_log "$CLAUDE_DIR/logs/agent-activity.jsonl" 5000   # 單行/筆
rotate_log "$CLAUDE_DIR/logs/hooks.log"            2000
rotate_log "$CLAUDE_DIR/logs/context-reports.log"  1000

# ============================================================================
# 時間追蹤：歸檔上一次 Session 的時間
# ============================================================================
TIMELOG_DIR="$CLAUDE_DIR/taskmaster-data"
SNAPSHOT_FILE="$TIMELOG_DIR/.session-snapshot"
TIMELOG_FILE="$TIMELOG_DIR/timelog.jsonl"

if [ -f "$SNAPSHOT_FILE" ]; then
    # 讀取上次 session 的快照
    snapshot=$(cat "$SNAPSHOT_FILE" 2>/dev/null)
    if [ -n "$snapshot" ] && command -v jq >/dev/null 2>&1; then
        snap_duration=$(echo "$snapshot" | jq -r '.duration_ms // 0' 2>/dev/null)
        if [ "$snap_duration" -gt 0 ] 2>/dev/null; then
            # 追加到 timelog.jsonl（不覆蓋，追加）
            echo "$snapshot" >> "$TIMELOG_FILE" 2>/dev/null
            log "⏱️ 上次 Session 時間已歸檔 (${snap_duration}ms)"
        fi
    fi
    # 清除快照
    rm -f "$SNAPSHOT_FILE" 2>/dev/null
fi

# 記錄本次 session 開始時間
mkdir -p "$TIMELOG_DIR" 2>/dev/null
date '+%H:%M' > "$TIMELOG_DIR/.session-start" 2>/dev/null

# 坑閘門的「本 session 已提示過」清單：每個 session 重新開始，
# 否則第二個 session 就不會再提醒同一個檔案的坑。
rm -f "$TIMELOG_DIR/.pitfall-seen" 2>/dev/null
rm -f "$WORK_CLAUDE/taskmaster-data/.pitfall-seen" 2>/dev/null

# 檢查是否存在 CLAUDE_TEMPLATE.md
if [ -f "$PROJECT_ROOT/CLAUDE_TEMPLATE.md" ]; then
    log "📄 偵測到 CLAUDE_TEMPLATE.md"

    # 檢查是否已經初始化過
    if [ ! -f "$CLAUDE_DIR/taskmaster-data/project.json" ]; then
        log "🚀 準備自動觸發 TaskMaster 初始化"

        # 顯示提示訊息（Jobs 式極簡設計）
        banner ""
        banner "\033[1;37m╭─────────────────────────────────────────────────────────────╮\033[0m"
        banner "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m     \033[1;97m🚀 TaskMaster Ready\033[0m                                  \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m     \033[0;90mTemplate detected. Start with:\033[0m                      \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m     \033[1;36m/task-init [project-name]\033[0m                           \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        banner "\033[1;37m├─────────────────────────────────────────────────────────────┤\033[0m"
        banner "\033[1;37m│\033[0m \033[1;97mWorkflow\033[0m                                                   \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m   \033[1;32m①\033[0m  \033[0;37mCollect requirements\033[0m           \033[0;90m→ Human review\033[0m    \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m   \033[1;33m②\033[0m  \033[0;37mGenerate project docs\033[0m          \033[0;90m→ Quality gate\033[0m    \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m   \033[1;36m③\033[0m  \033[0;37mStart development\033[0m              \033[0;90m→ After approval\033[0m  \033[1;37m│\033[0m"
        banner "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        banner "\033[1;37m╰─────────────────────────────────────────────────────────────╯\033[0m"
        banner ""

        note "📄 這是尚未初始化的 TaskMaster 專案。使用者若還沒說要做什麼，請引導他跑 \`/task-init\`。"

        finish
    else
        log "ℹ️ TaskMaster 已初始化"

        # 檢查是否有現有 WBS 檔案，提示恢復
        if [ -f "$CLAUDE_DIR/taskmaster-data/wbs.md" ]; then
            log "📋 偵測到現有 WBS 任務清單"

            banner ""
            banner "\033[1;37m╭─────────────────────────────────────────────────────────────╮\033[0m"
            banner "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
            banner "\033[1;37m│\033[0m     \033[1;97m📋 WBS 任務清單已載入\033[0m                              \033[1;37m│\033[0m"
            banner "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
            banner "\033[1;37m│\033[0m     \033[0;90mResume with:\033[0m                                        \033[1;37m│\033[0m"
            banner "\033[1;37m│\033[0m     \033[1;36m/task-status\033[0m  查看進度                              \033[1;37m│\033[0m"
            banner "\033[1;37m│\033[0m     \033[1;36m/task-next\033[0m    取得下一個任務                        \033[1;37m│\033[0m"
            banner "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
            banner "\033[1;37m╰─────────────────────────────────────────────────────────────╯\033[0m"
            banner ""

            note "📋 本專案已有 WBS。使用者若要繼續開發，用 \`/task-next\` 取任務，不要憑印象猜下一步。"
        fi

        finish
    fi
else
    log "ℹ️ 未偵測到 CLAUDE_TEMPLATE.md，TaskMaster 待命中"
    finish
fi