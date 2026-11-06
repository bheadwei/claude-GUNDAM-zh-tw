#!/bin/bash
set -f

# ════════════════════════════════════════════════════════════
#  ⚙️  能量條樣式 — 改這一行即可（存檔後 statusline 下次刷新生效）
#     可選值：segmented / solid / dots / squares / braille / gradient
#     即時預覽：bash .claude/statusline.sh preview
# ════════════════════════════════════════════════════════════
BAR_STYLE="solid"

# 預覽模式不讀 stdin（直接跑 statusline.sh 才不會卡在等待輸入）
if [ "$1" = "preview" ] || [ "$1" = "demo" ]; then
    PREVIEW_MODE=1
else
    input=$(cat)
    if [ -z "$input" ]; then
        printf "Claude"
        exit 0
    fi
fi

# ── jq PATH fix (cross-platform) ────────────────────────
if ! command -v jq >/dev/null 2>&1; then
    # Windows Git Bash: jq installed via winget/chocolatey may not be in PATH
    if [ -n "$LOCALAPPDATA" ] || [ -d "/c/Windows" ]; then
        for p in \
            "$LOCALAPPDATA/Microsoft/WinGet/Links/jq.exe" \
            "$HOME/AppData/Local/Microsoft/WinGet/Links/jq.exe" \
            "/c/ProgramData/chocolatey/bin/jq.exe" \
            "/c/tools/jq.exe"; do
            if [ -f "$p" ]; then
                jq() { "$p" "$@"; }
                export -f jq 2>/dev/null
                break
            fi
        done
        if ! command -v jq >/dev/null 2>&1; then
            found=$(find "$HOME/AppData/Local/Microsoft/WinGet/Packages" -name "jq.exe" 2>/dev/null | head -1)
            if [ -n "$found" ]; then
                jq() { "$found" "$@"; }
                export -f jq 2>/dev/null
            fi
        fi
    fi
    # Linux: suggest install
    # Ubuntu/Debian: sudo apt install jq
    # RHEL/CentOS:   sudo yum install jq  or  sudo dnf install jq
fi

if ! command -v jq >/dev/null 2>&1; then
    printf "Claude (jq not found - install: apt/dnf/yum install jq)"
    exit 0
fi

# ── Colors ──────────────────────────────────────────────
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;175;80m'
cyan='\033[38;2;86;182;194m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
magenta='\033[38;2;180;140;255m'
dim='\033[2m'
reset='\033[0m'

sep=" ${dim}│${reset} "

# ── Helpers ─────────────────────────────────────────────
format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.1fm\", $num / 1000000}"
    elif [ "$num" -ge 1000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.0fk\", $num / 1000}"
    else
        printf "%d" "$num"
    fi
}

color_for_pct() {
    local pct=$1
    # 標準號誌配色：低用量綠 → 橙 → 黃 → 高用量紅
    if [ "$pct" -ge 90 ] 2>/dev/null; then printf "$red"
    elif [ "$pct" -ge 70 ] 2>/dev/null; then printf "$yellow"
    elif [ "$pct" -ge 50 ] 2>/dev/null; then printf "$orange"
    else printf "$green"
    fi
}

build_bar() {
    local pct=$1
    local width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100

    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local col
    col=$(color_for_pct "$pct")

    local f="" e="" i
    # 依 BAR_STYLE 切換樣式（改檔案頂部的 BAR_STYLE 變數即可；預覽：statusline.sh preview）
    case "$BAR_STYLE" in
        dots)        # ●○ 圓點（最早的樣式）
            for ((i=0; i<filled; i++)); do f+="●"; done
            for ((i=0; i<empty; i++)); do e+="○"; done
            printf "${col}${f}${dim}${e}${reset}" ;;
        solid)       # ▐██░░▌ 實心條 + 外框
            for ((i=0; i<filled; i++)); do f+="█"; done
            for ((i=0; i<empty; i++)); do e+="░"; done
            printf "${dim}▐${reset}${col}${f}${dim}${e}▌${reset}" ;;
        squares)     # ■□ 粗方塊
            for ((i=0; i<filled; i++)); do f+="■"; done
            for ((i=0; i<empty; i++)); do e+="□"; done
            printf "${col}${f}${dim}${e}${reset}" ;;
        braille)     # ▕⣿⣀▏ 點陣粒子
            for ((i=0; i<filled; i++)); do f+="⣿"; done
            for ((i=0; i<empty; i++)); do e+="⣀"; done
            printf "${dim}▕${reset}${col}${f}${dim}${e}▏${reset}" ;;
        gradient)    # ▐██▓▒░▌ 漸層消散
            if [ "$filled" -ge 1 ]; then for ((i=0; i<filled-1; i++)); do f+="█"; done; f+="▓"; fi
            if [ "$empty" -ge 1 ]; then e+="▒"; for ((i=0; i<empty-1; i++)); do e+="░"; done; fi
            printf "${dim}▐${reset}${col}${f}${dim}${e}▌${reset}" ;;
        *)           # segmented（分段槽，預設）：▕▰▱▏
            for ((i=0; i<filled; i++)); do f+="▰"; done
            for ((i=0; i<empty; i++)); do e+="▱"; done
            printf "${dim}▕${reset}${col}${f}${dim}${e}▏${reset}" ;;
    esac
}

# ── 預覽模式輸出（bash statusline.sh preview [style]）──────
# 一次列出所有樣式在 20% / 55% / 90% 下的樣子，即時確認，不必等刷新
if [ -n "$PREVIEW_MODE" ]; then
    current_style="$BAR_STYLE"
    if [ -n "$2" ]; then styles="$2"; else styles="segmented solid dots squares braille gradient"; fi
    printf "能量條樣式預覽（填充 20%% / 55%% / 90%%）：\n\n"
    for s in $styles; do
        BAR_STYLE="$s"
        if [ "$s" = "$current_style" ]; then printf "  ▶ %-10s " "$s"; else printf "    %-10s " "$s"; fi
        for p in 20 55 90; do build_bar "$p" 14; printf "   "; done
        printf "\n"
    done
    printf "\n目前設定 BAR_STYLE=\"%s\"（改 .claude/statusline.sh 頂部那行）\n" "$current_style"
    exit 0
fi

iso_to_epoch() {
    local iso_str="$1"
    local epoch
    epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi
    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi
    return 1
}

format_reset_time() {
    local iso_str="$1"
    local style="$2"
    [ -z "$iso_str" ] || [ "$iso_str" = "null" ] && return

    local epoch
    epoch=$(iso_to_epoch "$iso_str")
    [ -z "$epoch" ] && return

    local result=""
    case "$style" in
        time)
            result=$(date -d "@$epoch" +"%H:%M" 2>/dev/null)
            [ -z "$result" ] && result=$(date -j -r "$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
            ;;
        datetime)
            result=$(date -d "@$epoch" +"%m/%d %H:%M" 2>/dev/null)
            [ -z "$result" ] && result=$(date -j -r "$epoch" +"%b %-d, %l:%M%p" 2>/dev/null | sed 's/  / /g; s/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
            ;;
    esac
    printf "%s" "$result"
}

# ── Extract JSON data ───────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')

size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
[ "$size" -eq 0 ] 2>/dev/null && size=200000

input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
current=$(( input_tokens + cache_create + cache_read ))

used_tokens=$(format_tokens $current)
total_tokens=$(format_tokens $size)

if [ "$size" -gt 0 ] 2>/dev/null; then
    pct_used=$(( current * 100 / size ))
else
    pct_used=0
fi

# ── Session duration from cost.total_duration_ms ────────
session_duration=""
total_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
if [ "$total_duration_ms" -gt 0 ] 2>/dev/null; then
    elapsed=$(( total_duration_ms / 1000 ))
    if [ "$elapsed" -ge 3600 ] 2>/dev/null; then
        session_duration="$(( elapsed / 3600 ))h$(( (elapsed % 3600) / 60 ))m"
    elif [ "$elapsed" -ge 60 ] 2>/dev/null; then
        session_duration="$(( elapsed / 60 ))m"
    else
        session_duration="${elapsed}s"
    fi
fi

# ── Cost ────────────────────────────────────────────────
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' | awk '{printf "$%.2f", $1}')

# ── Context used percentage (from API) ──────────────────
pct_used_api=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$pct_used_api" ] && [ "$pct_used_api" != "null" ]; then
    pct_used=$pct_used_api
fi

# ── LINE 1 ──────────────────────────────────────────────
pct_color=$(color_for_pct "$pct_used")
cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)
dirname=$(basename "$cwd")

git_branch=""
git_dirty=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
        git_dirty="*"
    fi
fi

# Build line 1: Model | pct% (used/total) | dir (branch) | session | cost
line1="${blue}${model_name}${reset}"
line1+="${sep}"
line1+="${pct_color}${pct_used}%${reset} ${dim}(${used_tokens}/${total_tokens})${reset}"
line1+="${sep}"
line1+="${cyan}${dirname}${reset}"
if [ -n "$git_branch" ]; then
    line1+=" ${green}(${git_branch}${red}${git_dirty}${green})${reset}"
fi
if [ -n "$session_duration" ]; then
    line1+="${sep}"
    line1+="${white}${session_duration}${reset}"
fi
if [ "$total_cost" != "\$0.00" ]; then
    line1+="${sep}"
    line1+="${yellow}${total_cost}${reset}"
fi

# ── WBS task + plan progress ────────────────────────────
task_dir="$cwd/.claude/taskmaster-data"
if [ -f "$task_dir/.current-task" ]; then
    curr_task=$(head -1 "$task_dir/.current-task" 2>/dev/null | tr -d '[:space:]\r')
    if [ -n "$curr_task" ]; then
        line1+="${sep}"
        line1+="${cyan}task ${curr_task}${reset}"
        plan_file=$(ls "$task_dir/plans/${curr_task}"-*.md 2>/dev/null | head -1)
        if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
            curr_phase=$(grep '^current_phase:' "$plan_file" 2>/dev/null | head -1 | tr -dc '0-9')
            total_phase=$(grep -c '^### 階段' "$plan_file" 2>/dev/null || echo 0)
            if [ -n "$curr_phase" ] && [ "$total_phase" -gt 0 ] 2>/dev/null; then
                line1+=" ${dim}(plan ${curr_phase}/${total_phase})${reset}"
            fi
        fi
    fi
fi

# ── Agent activity (this session) + Level/XP ────────────
sl_session=$(echo "$input" | jq -r '.session_id // ""')
agent_log_file="$cwd/.claude/logs/agent-activity.jsonl"
agent_count=0
if [ -f "$agent_log_file" ] && [ -n "$sl_session" ]; then
    agent_count=$(jq -r --arg s "$sl_session" \
        'select(.event=="agent_start" and .session_id==$s) | .session_id' \
        "$agent_log_file" 2>/dev/null | wc -l | tr -d ' ')
fi
[ -z "$agent_count" ] && agent_count=0
if [ "$agent_count" -gt 0 ] 2>/dev/null; then
    line1+="${sep}${magenta}🤖 ${agent_count}${reset}"
fi

# Level：XP 由下面三項加權而成（跨 session 持久）
# 想換指標 → 改下面 xp 這一行即可（檔尾「等級機制」說明有其他來源範例）
# 複合戰功值 XP = commits×10 + 累計開發時數×5 + 累計 agent 指揮數×3
xp_commits=$(git -C "$cwd" rev-list --count HEAD 2>/dev/null); [ -z "$xp_commits" ] && xp_commits=0
xp_hours=0
timelog_file="$cwd/.claude/taskmaster-data/timelog.jsonl"
if [ -f "$timelog_file" ]; then
    total_ms=$(jq -s 'map(.duration_ms // 0) | add // 0' "$timelog_file" 2>/dev/null)
    [ -n "$total_ms" ] && [ "$total_ms" -gt 0 ] 2>/dev/null && xp_hours=$(( total_ms / 3600000 ))
fi
xp_agents=0
if [ -f "$agent_log_file" ]; then
    xp_agents=$(jq -r 'select(.event=="agent_start") | .event' "$agent_log_file" 2>/dev/null | wc -l | tr -d ' ')
    [ -z "$xp_agents" ] && xp_agents=0
fi
xp=$(( xp_commits * 10 + xp_hours * 5 + xp_agents * 3 ))
if [ "$xp" -gt 0 ] 2>/dev/null; then
    lvl_max=100
    lvl_icons=("🔩" "⚙️" "🔧" "🛡️" "⚔️" "🚀" "⚡" "🌟" "☄️" "👑")
    lvl_titles=(
        "鋼球" "薩克II" "吉姆" "鋼坦克" "德安專用薩克"
        "古夫" "鋼加農" "祖達" "德姆" "高機動型薩克"
        "夏亞專用薩克" "傑爾古格" "陸戰型鋼彈" "Ez8" "肯普法"
        "吉翁號" "鋼彈 RX-78-2" "鋼彈 EX" "精神感應薩克" "全裝甲鋼彈"
        "鋼彈 NT-1 Alex" "鋼彈 Mk-II" "GP01 玉蘭" "GP01Fb" "百式"
        "GP02 酸漿果" "G-SAVIOUR 鋼彈" "Z 鋼彈" "The O" "ZZ 鋼彈"
        "全裝甲 ZZ" "GP03 石斛蘭" "沙薩比" "ν 鋼彈" "鋼彈 F91"
        "V 鋼彈" "V2 鋼彈" "V2 突擊破壞型" "G-自我" "AGE-1"
        "AGE-2" "AGE-3" "攻擊鋼彈" "神盾鋼彈" "觀星者鋼彈"
        "衝擊鋼彈" "鋼彈 X" "沙漠鋼彈" "重武裝鋼彈" "死神鋼彈"
        "神龍鋼彈" "飛翼鋼彈" "閃光鋼彈" "能天使鋼彈" "力天使鋼彈"
        "主天使鋼彈" "德天使鋼彈" "創制強襲鋼彈" "創制燃燒鋼彈" "鋼彈00潛網者"
        "獵魔鋼彈" "古辛鋼彈" "拜爾鋼彈" "自由鋼彈" "正義鋼彈"
        "天意鋼彈" "命運鋼彈" "傳說鋼彈" "曉" "次代鋼彈"
        "飛翼鋼彈零式" "鋼彈 DX" "AGE-FX" "獵魔鋼彈天狼" "00 鋼彈"
        "Ξ 鋼彈" "敘事鋼彈" "路布莉斯" "風靈鋼彈" "卡利班鋼彈"
        "尊者鋼彈" "攻擊自由鋼彈" "無限正義鋼彈" "獵魔鋼彈天狼王" "風靈鋼彈改修型"
        "報喪女妖·諾恩" "00 Raiser" "紅鋼彈" "GQuuuuuuX" "獨角獸鋼彈"
        "菲尼克斯鋼彈" "崛起自由鋼彈" "不朽正義鋼彈" "無限正義鋼彈貳式" "非凡強襲自由鋼彈"
        "神鋼彈" "00 Qan[T]" "全裝甲獨角獸鋼彈" "倒X鋼彈" "∀ 鋼彈"
    )
    # 第 n 級門檻 = 10×(n-1)²；用迴圈逼近而非 sqrt，避免在常跑的 statusline 多開子行程
    lvl=1
    while [ "$lvl" -lt "$lvl_max" ] && [ "$xp" -ge $(( 10 * lvl * lvl )) ]; do
        lvl=$((lvl + 1))
    done
    if [ "$lvl" -lt "$lvl_max" ]; then
        lvl_prog="${dim}(${xp}/$(( 10 * lvl * lvl )))${reset}"
    else
        lvl_prog="${dim}(MAX)${reset}"
    fi
    line1+="${sep}${yellow}Lv.${lvl} ${lvl_icons[$(( (lvl - 1) / 10 ))]} ${lvl_titles[$((lvl - 1))]}${reset} ${lvl_prog}"
fi

# ══════════════════════════════════════════════════════════
# 等級機制（Level）說明 — 想自訂時改這裡
# ──────────────────────────────────────────────────────────
# 原理三步：(1) 取一個會成長的 XP → (2) 用門檻公式換算等級 → (3) 配對 icon/稱號。
# 預設 XP = 複合戰功值：commits×10 + 累計開發時數×5 + 累計 agent 數×3（會頻繁變動，最有感）。
# 調整權重 → 改上面 xp=$(( ... )) 的係數。改用單一來源範例：
#   • 純 commit 數：         xp=$xp_commits
#   • 純累計開發時數：       xp=$xp_hours
#   • 純累計 agent 指揮數：   xp=$xp_agents
#   • 本 session 新增行數：   xp=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
# 門檻：第 n 級需要 10×(n-1)² XP（Lv.2=10、Lv.10=810、Lv.50=24010、Lv.100=98010），上限 lvl_max=100。
#   想升得快/慢 → 改 while 條件與 lvl_prog 兩處 `10 * lvl * lvl` 的係數（兩處要一致）。
# 稱號：lvl_titles 共 100 個鋼彈機體名，第 1 個是 Lv.1；改 lvl_max 時陣列長度要跟著一致。
# icon：lvl_icons 共 10 個，每 10 級換一個（索引 = (lvl-1)/10）。
# 註：換 XP 來源後記得同步調整門檻係數的量級。
# ══════════════════════════════════════════════════════════

# ── OAuth token resolution ──────────────────────────────
get_oauth_token() {
    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi
    if command -v security >/dev/null 2>&1; then
        local blob
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            local token
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"; return 0
            fi
        fi
    fi
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        local token
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"; return 0
        fi
    fi
    if command -v secret-tool >/dev/null 2>&1; then
        local blob
        blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        if [ -n "$blob" ]; then
            local token
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"; return 0
            fi
        fi
    fi
    echo ""
}

# ── Fetch usage data (cached) ──────────────────────────
cache_dir="${TEMP:-/tmp}/claude"
cache_file="${cache_dir}/statusline-usage-cache.json"
cache_max_age=60
mkdir -p "$cache_dir"

needs_refresh=true
usage_data=""

if [ -f "$cache_file" ]; then
    cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
    now=$(date +%s)
    cache_age=$(( now - cache_mtime ))
    if [ "$cache_age" -lt "$cache_max_age" ] 2>/dev/null; then
        needs_refresh=false
        usage_data=$(cat "$cache_file" 2>/dev/null)
    fi
fi

if $needs_refresh; then
    token=$(get_oauth_token)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        response=$(curl -s --max-time 5 \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/2.1.34" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
            usage_data="$response"
            echo "$response" > "$cache_file"
        fi
    fi
    if [ -z "$usage_data" ] && [ -f "$cache_file" ]; then
        usage_data=$(cat "$cache_file" 2>/dev/null)
    fi
fi

# ── Rate limit lines ────────────────────────────────────
rate_lines=""

if [ -n "$usage_data" ] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
    bar_width=16

    five_hour_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    five_hour_reset_iso=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
    five_hour_reset=$(format_reset_time "$five_hour_reset_iso" "time")
    five_hour_bar=$(build_bar "$five_hour_pct" "$bar_width")
    five_hour_pct_color=$(color_for_pct "$five_hour_pct")
    five_hour_pct_fmt=$(printf "%3d" "$five_hour_pct")

    rate_lines+="${white}current${reset} ${five_hour_bar} ${five_hour_pct_color}${five_hour_pct_fmt}%${reset}"
    [ -n "$five_hour_reset" ] && rate_lines+=" ${dim}⟳${reset} ${white}${five_hour_reset}${reset}"

    seven_day_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    seven_day_reset_iso=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
    seven_day_reset=$(format_reset_time "$seven_day_reset_iso" "datetime")
    seven_day_bar=$(build_bar "$seven_day_pct" "$bar_width")
    seven_day_pct_color=$(color_for_pct "$seven_day_pct")
    seven_day_pct_fmt=$(printf "%3d" "$seven_day_pct")

    rate_lines+="\n${white}weekly${reset}  ${seven_day_bar} ${seven_day_pct_color}${seven_day_pct_fmt}%${reset}"
    [ -n "$seven_day_reset" ] && rate_lines+=" ${dim}⟳${reset} ${white}${seven_day_reset}${reset}"

    extra_enabled=$(echo "$usage_data" | jq -r '.extra_usage.is_enabled // false')
    if [ "$extra_enabled" = "true" ]; then
        extra_pct=$(echo "$usage_data" | jq -r '.extra_usage.utilization // 0' | awk '{printf "%.0f", $1}')
        extra_used=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.2f", $1/100}')
        extra_limit=$(echo "$usage_data" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.2f", $1/100}')
        extra_bar=$(build_bar "$extra_pct" "$bar_width")
        extra_pct_color=$(color_for_pct "$extra_pct")

        rate_lines+="\n${white}extra${reset}   ${extra_bar} ${extra_pct_color}\$${extra_used}${dim}/${reset}${white}\$${extra_limit}${reset}"
    fi
fi

# ── Persist session duration for time tracking ──────────
# Write current session's duration to a temp file so session-start can finalize it
timelog_dir="$cwd/.claude/taskmaster-data"
if [ -d "$timelog_dir" ] && [ "$total_duration_ms" -gt 0 ] 2>/dev/null; then
    session_id=$(echo "$input" | jq -r '.session_id // ""')
    today=$(date '+%Y-%m-%d' 2>/dev/null)
    start_time=""
    [ -f "$timelog_dir/.session-start" ] && start_time=$(cat "$timelog_dir/.session-start" 2>/dev/null | head -1)
    total_cost_raw=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
    # Read current task if any
    current_task=""
    [ -f "$timelog_dir/.current-task" ] && current_task=$(cat "$timelog_dir/.current-task" 2>/dev/null | head -1)
    # Write snapshot (overwrite each time)
    cat > "$timelog_dir/.session-snapshot" 2>/dev/null <<SNAPSHOT
{"session_id":"${session_id}","date":"${today}","start":"${start_time}","duration_ms":${total_duration_ms},"cost_usd":${total_cost_raw},"task":"${current_task}"}
SNAPSHOT
fi

# ── Output ──────────────────────────────────────────────
printf "%b" "$line1"
[ -n "$rate_lines" ] && printf "\n%b" "$rate_lines"

exit 0
