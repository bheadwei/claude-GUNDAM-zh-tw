#!/bin/bash
# overview-serve.sh — 起／停專案圖解的本機伺服器（ADR-2026-11-12-003 第 2、3、4 節）
#
#   bash .claude/scripts/overview-serve.sh [<工作目錄>]          確保伺服器在跑，印網址（stdout 最後一行一定是網址）
#   bash .claude/scripts/overview-serve.sh --stop [<工作目錄>]   經 POST /<token>/.shutdown 關掉；沒在跑也 exit 0
#
# 只在「新起」時開瀏覽器；伺服器已在跑只印網址。開瀏覽器失敗不影響 exit code。
# 沒有 Python 3.7 以上、或起不來時印 file:// 路徑與原因，exit 0。沒有 project.json 什麼都不印。
# 環境變數：OVERVIEW_SERVE_PLATFORM（覆寫 uname -s，測試用）；其餘見 overview-serve.py。
#
# Windows Git Bash：用 nohup … & 起原生 python.exe，shell 結束後會不會被收掉未實測（ADR 第 5 節待實測）。
# 若實測不通過，依 ADR 改試 `cmd //c start "" /b <python> …`、再試 PowerShell Start-Process。

STOP=0 WORK=""
for a in "$@"; do
    case "$a" in
        --stop) STOP=1 ;;
        *) WORK="$a" ;;
    esac
done
WORK_ROOT="${WORK:-$PWD}"

MAIN_ROOT=""
GCD=$(git -C "$WORK_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$GCD" ] && MAIN_ROOT=$(cd "$GCD/.." 2>/dev/null && pwd)
[ -n "$MAIN_ROOT" ] || MAIN_ROOT=$(cd "$WORK_ROOT" 2>/dev/null && pwd)
[ -n "$MAIN_ROOT" ] || exit 0

DATA="$MAIN_ROOT/.claude/taskmaster-data"
[ -f "$DATA/project.json" ] || exit 0
OV="$DATA/overview"
mkdir -p "$OV" 2>/dev/null || exit 0
SERVE="$OV/.serve"
LOCK="$OV/.serve.lock"
SELF="${BASH_SOURCE[0]}"; [[ $SELF == */* ]] || SELF="./$SELF"
SCRIPT_DIR="$(cd "${SELF%/*}" && pwd)"

# 讀 .serve 的欄位（Python 寫成單行 JSON）
serve_field() { sed -n "s/.*\"$1\": *\"\{0,1\}\([A-Za-z0-9_-]*\).*/\1/p;/\"$1\"/q" "$SERVE" 2>/dev/null; }

# http_status <port> <GET|POST> <路徑> —— 印狀態碼，連不上印空
http_status() {
    local line
    line=$( { exec 3<>"/dev/tcp/127.0.0.1/$1" \
        && printf '%s %s HTTP/1.0\r\nHost: 127.0.0.1\r\nContent-Length: 0\r\n\r\n' "$2" "$3" >&3 \
        && IFS= read -r -t 3 line <&3 && printf '%s' "$line"; } 2>/dev/null )
    set -- $line
    printf '%s' "${2:-}"
}

# 讀 .serve，身分確認通過才設 PORT／TOKEN 並回 0
running() {
    PORT=$(serve_field port) TOKEN=$(serve_field token)
    [ -n "$PORT" ] && [ -n "$TOKEN" ] && [ "$(http_status "$PORT" GET "/$TOKEN/.serve-id")" = 200 ]
}

url() { printf 'http://127.0.0.1:%s/%s/index.html' "$PORT" "$TOKEN"; }

fallback() {
    echo "$1"
    echo "file://$OV/index.html"
    exit 0
}

if [ "$STOP" -eq 1 ]; then
    if running; then
        http_status "$PORT" POST "/$TOKEN/.shutdown" >/dev/null
        for ((k = 0; k < 20; k++)); do
            [ -f "$SERVE" ] || break
            sleep 0.1
        done
    fi
    [ -f "$SERVE" ] && ! running && rm -f "$SERVE"
    exit 0
fi

if running; then
    echo "$(url)"
    exit 0
fi

LOCKED=0
trap '[ "$LOCKED" = 1 ] && rmdir "$LOCK" 2>/dev/null' EXIT
for ((i = 1; i <= 100; i++)); do
    if mkdir "$LOCK" 2>/dev/null; then LOCKED=1; break; fi
    if running; then echo "$(url)"; exit 0; fi
    # 等了 10 秒還鎖著：持鎖的那支當掉了，清掉重來一次
    [ "$i" = 100 ] && rmdir "$LOCK" 2>/dev/null
    sleep 0.1
done
if [ "$LOCKED" != 1 ]; then
    mkdir "$LOCK" 2>/dev/null && LOCKED=1 || fallback "拿不到啟動鎖，改用檔案開啟；SSH 遠端請改用 Live Preview"
fi

if running; then echo "$(url)"; exit 0; fi

PY=""
for c in "python3" "python" "py -3"; do
    if [ "$($c -c 'import sys;print(sys.version_info>=(3,7))' 2>/dev/null)" = True ]; then PY=$c; break; fi
done
[ -n "$PY" ] || fallback "找不到 Python 3.7 以上，改用檔案開啟；SSH 遠端請改用 Live Preview"

rm -f "$SERVE" "$OV/.serve.err"
PID=$( umask 077; nohup $PY "$SCRIPT_DIR/overview-serve.py" "$OV" >/dev/null 2>"$OV/.serve.err" </dev/null & echo $! )

STARTED=0
for ((k = 0; k < 30; k++)); do
    if [ -f "$SERVE" ] && running; then STARTED=1; break; fi
    kill -0 "$PID" 2>/dev/null || { [ -f "$SERVE" ] && running && STARTED=1; break; }
    sleep 0.1
done
if [ "$STARTED" != 1 ]; then
    reason=$(sed -n '$p' "$OV/.serve.err" 2>/dev/null)
    fallback "本機伺服器起不來${reason:+（$reason）}，改用檔案開啟；SSH 遠端請改用 Live Preview"
fi
rm -f "$OV/.serve.err"

URL=$(url)
opened=0
open_with() { "$@" >/dev/null 2>&1 </dev/null || true; opened=1; }
PLATFORM="${OVERVIEW_SERVE_PLATFORM:-$(uname -s 2>/dev/null)}"
if [ -n "${BROWSER:-}" ]; then
    open_with "$BROWSER" "$URL"
else
    case "$PLATFORM" in
        Linux)
            if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v xdg-open >/dev/null 2>&1; then
                open_with xdg-open "$URL"
            fi ;;
        Darwin) open_with open "$URL" ;;
        MINGW*|MSYS*|CYGWIN*) open_with cmd //c start "" "$URL" ;;
    esac
fi
if [ "$opened" = 0 ] && [ -n "${SSH_CONNECTION:-}" ]; then
    echo "遠端機器沒有桌面，在你自己的電腦另開終端機轉發 port 後貼上網址："
    echo "ssh -L $PORT:127.0.0.1:$PORT <你的主機>"
fi
echo "$URL"
