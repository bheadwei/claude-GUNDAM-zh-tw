# vscode-live-server.sh — 讓 Live Server 忽略專案地圖資料夾（copy-template.sh、update-template.sh 共用，用 source 載入）
#
# 專案地圖的資料每幾秒更新一次，Live Server 會整頁重載、畫面一直閃。
# `liveServer.settings.ignoreFiles` 一設就整個蓋掉預設值，所以新建與補鍵時要帶上預設值
# （預設值來源：https://ritwickdey.github.io/vscode-live-server/docs/settings.html）。
# 讀不懂的檔（註解、尾逗號）或沒有 jq：一個 byte 都不動，只印手動那行。copy／update 的 .ps1 要一致

LIVE_SERVER_GLOB='.claude/taskmaster-data/overview/**'
LIVE_SERVER_DEFAULTS='[".vscode/**","**/*.scss","**/*.sass"]'

ensure_live_server_ignore() {  # $1=專案根 $2=--dry-run（選填）
    local root="$1" dry=0 f key="liveServer.settings.ignoreFiles"
    [ "${2:-}" = "--dry-run" ] && dry=1
    f="$root/.vscode/settings.json"
    local manual="   ⚠ .vscode/settings.json 有註解或不是標準 JSON，沒有自動修改。請手動加入：\"$key\": [\"$LIVE_SERVER_GLOB\"]（已有這個鍵就把字串加進陣列）"
    local want
    want=$(printf '%s' "$LIVE_SERVER_DEFAULTS" | sed "s|\]\$|,\"$LIVE_SERVER_GLOB\"]|")

    if ! command -v jq >/dev/null 2>&1; then
        echo "   ⚠ 找不到 jq，沒有自動修改 .vscode/settings.json。請手動加入：\"$key\": [\"$LIVE_SERVER_GLOB\"]（已有這個鍵就把字串加進陣列）"
        return 0
    fi

    if [ ! -e "$f" ]; then
        if [ "$dry" -eq 1 ]; then echo "   [dry] 會建立 $f（Live Server 忽略專案地圖資料夾）"; return 0; fi
        mkdir -p "$root/.vscode"
        jq -n --arg k "$key" --argjson v "$want" '{($k): $v}' > "$f"
        echo "   ✚ 已建立 .vscode/settings.json（Live Server 忽略專案地圖資料夾）"
        return 0
    fi

    if ! jq -e 'type == "object"' "$f" >/dev/null 2>&1; then echo "$manual"; return 0; fi

    local state
    state=$(jq -r --arg k "$key" --arg g "$LIVE_SERVER_GLOB" '
        .[$k] | if . == null then "missing"
                elif type == "array" then (if any(.[]; . == $g) then "has" else "append" end)
                else "bad" end' "$f")
    case "$state" in
        has) echo "   ✓ .vscode/settings.json 已設定 Live Server 忽略專案地圖資料夾"; return 0 ;;
        bad) echo "   ⚠ .vscode/settings.json 的 $key 不是陣列，沒有自動修改。請手動加入：\"$key\": [\"$LIVE_SERVER_GLOB\"]（把字串加進陣列）"; return 0 ;;
    esac
    if [ "$dry" -eq 1 ]; then echo "   [dry] 會在 $f 加上 $key 的 $LIVE_SERVER_GLOB"; return 0; fi

    local ind n=2 flag=() crlf=0 tmp
    ind=$(awk '/^[ \t]+"/ { match($0, /^[ \t]+/); print substr($0, 1, RLENGTH); exit }' "$f")
    case "$ind" in
        $'\t'*) flag=(--tab) ;;
        ?*) n=${#ind}; [ "$n" -gt 7 ] && n=7; flag=(--indent "$n") ;;
        *) flag=(--indent 2) ;;
    esac
    [ -n "$(tr -cd '\r' < "$f" | head -c 1)" ] && crlf=1

    tmp=$(mktemp "$f.XXXXXX") || return 0
    cp -p "$f" "$tmp"
    jq "${flag[@]}" --arg k "$key" --arg g "$LIVE_SERVER_GLOB" --argjson d "$want" '
        .[$k] = (if .[$k] == null then $d else .[$k] + [$g] end)' "$f" > "$tmp" || { rm -f "$tmp"; echo "$manual"; return 0; }
    if [ "$crlf" -eq 1 ]; then
        sed 's/$/\r/' "$tmp" > "$tmp.crlf" && mv -f "$tmp.crlf" "$tmp"
    fi
    mv -f "$tmp" "$f"
    echo "   ✚ 已更新 .vscode/settings.json（Live Server 忽略專案地圖資料夾）"
}
