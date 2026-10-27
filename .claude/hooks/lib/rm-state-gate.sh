#!/bin/bash
# rm-state-gate.sh — `rm` 的權限改由這裡判斷：只刪 hook 狀態檔或 scratchpad 暫存區就自動同意，其他一律問
#
# 為什麼不用 settings.json 的規則：
#   - `"ask": ["Bash(rm:*)"]` 在 auto mode 下也強制詢問，連刪 `.merge-pending` 這種
#     模板自己的狀態檔都要人按（2026-10-27 使用者回報，`/verify` 清合併閘門那一步）
#   - hook 回 `allow` 蓋不過 settings 的 ask／deny 規則（官方 hooks 文件明寫），
#     所以那條 ask 規則拿掉了，「其他 rm 都要問」改由本檔回 `ask` 保證
#   - 萬用字元的 allow 規則擋不住 `rm .claude/taskmaster-data/../../src`
#
# 判斷（逐段：`&& || ; |`、換行、`(`）：
#   - 有任何一段 `rm` 的目標不是狀態檔，或判斷不了 → `ask`
#     判斷不了＝含 `$`、反引號、萬用字元、`~`、`\`、`..`、`-r` 等旗標、沒有目標、
#     相對路徑卻不知道 cwd、寫到 /dev/null 以外的重導向（`rm .a > src/x` 會清空 src/x）
#   - 指令裡「rm」這個字（`git rm` 除外）比認出來的 rm 段多 → `ask`
#     抓 `$(rm x)`、`bash -c 'rm x'`、`\rm`、`command rm`、`VAR=1 rm`、`then rm`、heredoc 內文。
#     說明文字裡的 rm（commit 訊息）也會被算進來，多問一次；方向是寧可多問不漏問
#   - 每段 `rm` 都只刪狀態檔，且整條指令除了 `cd` 沒有別的 → `allow`
#   - 每段 `rm` 都只刪狀態檔，但混了其他指令 → 不表態，交回 Claude Code 原本的流程
#     （回 `allow` 會連同其他指令一起放行，範圍超過「刪狀態檔」這個授權）
#
# 安全目標有兩種：
#   - 狀態檔＝`<WORK_ROOT 或 MAIN_ROOT>/.claude/taskmaster-data/.<名稱>`，名稱不含 `/`，**不得帶 -r**。
#     包含閘門的待辦標記（`.merge-pending`、`.doc-impact`…）：使用者明確決定這些也不用問
#   - scratchpad 暫存區（`_rm_scratch`）：Claude Code 給每個 session 的暫存目錄，可帶 `-rf`。
#     agent 常在這裡組乾淨副本跑比對（2026-10-27 使用者回報：`rm -rf $S && git archive … | tar -x -C $S`）
#
#     scratchpad 只認絕對路徑（cd 失敗或子 shell 的 cd 會讓相對路徑猜錯位置）；目標存在時
#     上層目錄的實際位置（解開 symlink）也要在 scratchpad 裡
#
# 變數：**整條指令開頭**、不在括號裡、單獨成一段的 `S=/字面路徑` 會被記下，之後的 `$S`、`"$S"`、
# `${S}`、`$S/子路徑` 換成字面值再判斷。設兩次、`export`、`S=$(…)`、值含空白、前面已有其他指令、
# `(S=…)` → 不記，`$S` 照樣問。設定 IFS／PATH／CDPATH 等會改變展開方式的變數 → 不給 allow。
#
# 已知漏網：不叫 rm 的刪除——`find -delete`、`unlink`、`git clean`、`python -c 'os.remove(…)'`。
# 舊的 `Bash(rm:*)` 規則同樣管不到。
# hook 本身失效（jq 缺失、超時、lib 載入失敗）時 rm 走 Claude Code 預設流程：一般模式照樣會問，
# auto mode 交給分類器，不再是硬性詢問。
# 只管 Bash：PowerShell 的 `rm`／`Remove-Item` 原本就不在 ask 規則裡，行為不變。
#
# 用法（pre-tool-use.sh）：rm_state_gate "$COMMAND" "$CWD" "$WORK_ROOT" "$MAIN_ROOT"
# 有決定時印出 JSON 並 exit 0；不表態時 return 0。
# 逃生門：RM_STATE_GATE=off（連 ask 一起關——那時 rm 完全走 Claude Code 原本的流程）。
# TASKMODE_GATE=off 與 .suggest-mode=off **不會**關掉它（pre-tool-use.sh 在那兩個出口前先呼叫）

# 每段一行，字之間用 \t 分隔。第一欄是 D<括號深度>（`( … )`、`$( … )` 裡大於 0），
# 之後每個字前綴 S（字面值）或 U（含展開，判斷不了）
_rm_tokenize() {
    printf '%s\n' "$1" | awk '
    BEGIN { RS = "\001"; q = "\047"; T = "\t" }
    function flush_tok() { if (tok != "" || had_q) { seg = seg (seg == "" ? "" : T) (unsafe ? "U" : "S") tok }; tok = ""; unsafe = 0; had_q = 0 }
    function flush_seg() { flush_tok(); if (seg != "") print "D" depth T seg; seg = "" }
    {
        s = $0; n = length(s); st = ""; tok = ""; seg = ""; unsafe = 0; had_q = 0; depth = 0
        for (i = 1; i <= n; i++) {
            c = substr(s, i, 1); nx = substr(s, i + 1, 1)
            if (st == q) { if (c == q) st = ""; else tok = tok c; continue }
            if (st == "\"") {
                if (c == "\\") { tok = tok nx; i++; continue }
                if (c == "\"") { st = ""; continue }
                if (c == "$" || c == "`") unsafe = 1
                if (c == "$" && nx == "(") { depth = 1; i++; tok = tok "$("
                    while (depth > 0 && i < n) { i++; d = substr(s, i, 1); tok = tok d
                        if (d == "(") depth++; else if (d == ")") depth--
                        else if (d == "\"" || d == q) { j = index(substr(s, i + 1), d); if (j == 0) { i = n; break }; tok = tok substr(s, i + 1, j); i += j } }
                    continue }
                tok = tok c; continue
            }
            if (c == "\\") { unsafe = 1; tok = tok nx; i++; continue }
            if (c == q || c == "\"") { st = c; had_q = 1; continue }
            if (c == "#" && tok == "" && !had_q) { j = index(substr(s, i), "\n"); if (j == 0) break; i += j - 2; continue }
            if (c == " " || c == "\t" || c == "\r") { flush_tok(); continue }
            if (c == "\n" || c == ";") { flush_seg(); continue }
            if (c == "(") { flush_seg(); depth++; continue }
            if (c == ")") { flush_seg(); if (depth > 0) depth--; continue }
            if (c == "|") { if (nx == "|" || nx == "&") i++; flush_seg(); continue }
            if (c == "&") {
                if (nx == "&") { i++; flush_seg(); continue }
                if (substr(tok, length(tok), 1) ~ /[<>]/) { tok = tok c; continue }
                flush_seg(); continue
            }
            if (c ~ /[$`*?[{}]/) unsafe = 1
            if (c == "~" && (tok == "" || substr(tok, length(tok), 1) ~ /[=:]/)) unsafe = 1
            tok = tok c
        }
        flush_seg()
    }'
}

# 路徑正規化：`\` 換 `/`、msys 的 `/d/` 換 `d:/`、磁碟代號小寫、拿掉 `/./` 與重複的 `/`
_rm_norm() {
    local p="${1//\\//}"
    [[ $p =~ ^/([A-Za-z])(/|$)(.*)$ ]] && p="${BASH_REMATCH[1]}:/${BASH_REMATCH[3]}"
    [[ $p =~ ^([A-Za-z]):(.*)$ ]] && p="${BASH_REMATCH[1],,}:${BASH_REMATCH[2]}"
    while [[ $p == *//* ]]; do p="${p//\/\//\/}"; done
    while [[ $p == */./* ]]; do p="${p//\/.\//\/}"; done
    p="${p#./}"; p="${p%/}"
    printf '%s' "$p"
}

_rm_is_abs() { [[ $1 == /* || $1 =~ ^[A-Za-z]:[/\\] ]]; }

# Git Bash 下同一個目錄有兩種寫法：hook 的 CLAUDE_PROJECT_DIR 可能是 `/tmp/x`，
# 而 Claude Code（或任何經過原生 exe 的路徑）給的 cwd 是 `C:/Users/…/Temp/x`。
# `/d/…` 這種 _rm_norm 自己換得掉；其他 `/` 開頭的 msys 掛載點只有 cygpath 知道。
# 只對「`/` 開頭、不是 `/<磁碟>/`」的路徑開 cygpath，一般 Windows 路徑不多開行程。
_rm_native() {
    if [[ $1 == /* && ! $1 =~ ^/[A-Za-z](/|$) ]] && command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1" 2>/dev/null || printf '%s' "$1"
    else
        printf '%s' "$1"
    fi
}

# _rm_scratch <正規化後的路徑> —— 在 Claude Code 的 scratchpad 裡就回 0
# 結構固定是 <暫存根>/claude[-<uid>]/<專案>/<session>/scratchpad[/…]：
#   Linux  /tmp/claude-0/-root-Projects-x/340c…/scratchpad/base
#   Windows C:/Users/<u>/AppData/Local/Temp/claude/D-----x/3842…/scratchpad
#   macOS  /private/tmp/claude-501/… 或 /var/folders/xx/yy/T/claude-501/…
# 單獨的 /tmp、或只有 claude 這一層都不算——那裡可能有別的 session 或別的程式的東西。
_rm_scratch_path() {
    local tail='/claude(-[0-9]+)?/[^/]+/[^/]+/scratchpad(/.+)?$' lp="${1,,}"
    [[ $1 =~ ^(/private)?/tmp$tail ]] \
        || [[ $1 =~ ^(/private)?/var/folders/[^/]+/[^/]+/T$tail ]] \
        || [[ $lp =~ ^[a-z]:/users/[^/]+/appdata/local/temp$tail ]]
}

# 字串比對過了，再確認上層目錄的實際位置也在 scratchpad 裡：`<sp>/link/src` 的 link
# 若指到專案，rm -rf 刪的是專案的 src。最後一層本身是 symlink 沒關係（rm 不跟隨）。
_rm_scratch() {
    _rm_scratch_path "$1" || return 1
    local dir="${1%/*}" real
    [ -d "$dir" ] || return 0
    command -v readlink >/dev/null 2>&1 || return 0
    real=$(readlink -f -- "$dir" 2>/dev/null) || return 1
    _rm_scratch_path "$(_rm_norm "$(_rm_native "$real")")/x"
}

# _rm_safe_target <字（含 S/U 前綴）> <recursive 0/1> <base> <root...>
# 狀態檔（不得帶 -r）或暫存區（可帶 -r）就回 0。
# base 與 root 都要先過 _rm_norm "$(_rm_native …)"（rm_state_gate 只算一次）
_rm_safe_target() {
    local t="$1" rec="$2" base="$3"; shift 3
    [ "${t:0:1}" = S ] || return 1
    t="${t:1}"
    case "$t" in *\\*|'') return 1 ;; esac
    case "/$t/" in */../*) return 1 ;; esac
    local p abs=0
    if _rm_is_abs "$t"; then abs=1; p=$(_rm_norm "$(_rm_native "$t")")
    else [ -n "$base" ] || return 1; p=$(_rm_norm "$base/$t"); fi
    # scratchpad 只認絕對路徑：`cd <sp>/不存在; rm -rf src`、`(cd <sp>); rm -rf src` 的
    # 相對路徑實際上落在專案裡。狀態檔照舊吃相對路徑（不得帶 -r，猜錯也只是刪一個 . 開頭的檔）
    [ "$abs" -eq 1 ] && _rm_scratch "$p" && return 0
    [ "$rec" -eq 0 ] || return 1
    local r name
    for r in "$@"; do
        [ -n "$r" ] || continue
        name="${p#"$r/.claude/taskmaster-data/."}"
        [ "$name" != "$p" ] && [ -n "$name" ] && [[ $name != */* ]] && [ "$name" != . ] && return 0
    done
    return 1
}

# _rm_subst <字> —— `$S`、`${S}`、`$S/子路徑` 換成同一條指令裡設過的字面值（換得了才換）
# 只認 `S=/字面路徑` 單獨成一段的設定；值含空白或展開、設過兩次、`export S=…`、
# `S=$(…)` 都不會進 _rm_vars，於是 `$S` 維持 U，照樣問。
# _rm_vars 是 rm_state_gate 的 local -A，靠 bash 動態作用域讀到。
_rm_subst() {
    local t="$1" raw="${1:1}" name rest
    [ "${t:0:1}" = U ] || { printf '%s' "$t"; return; }
    if [[ $raw =~ ^\$([A-Za-z_][A-Za-z0-9_]*)(/.*)?$ || $raw =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}(/.*)?$ ]]; then
        name="${BASH_REMATCH[1]}"; rest="${BASH_REMATCH[2]}"
        if [[ -n ${_rm_vars[$name]+x} && ${_rm_vars[$name]} != '' && ! $rest =~ [\$\`*?\[{}~\\] ]]; then
            printf 'S%s%s' "${_rm_vars[$name]}" "$rest"; return
        fi
    fi
    printf '%s' "$t"
}

_rm_emit() {
    jq -n --arg d "$1" --arg r "$2" '{
        hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r }
    }'
    exit 0
}

# _rm_word_count <指令> —— 「rm」這個字出現幾次（`git rm` 不算）
# 刻意寬：前面可以是 `\`、引號、反引號、`$(`、`/`（`/bin/rm`）、`=`，後面可以是引號或 `)`。
# 用來抓切段器認不出來的 rm：`echo "$(rm x)"`、`bash -c 'rm x'`、`\rm`、`x=1 rm`、`then rm`、
# heredoc 內文。代價是說明文字裡出現 rm 這個字（commit 訊息、`echo rm`）也會多問一次。
_rm_word_count() {
    local rest="$1" n=0
    local re_git=$'git([ \t]+[^ \t\n;&|]+)*[ \t]+rm([ \t\n;&|]|$)'
    while [[ $rest =~ $re_git ]]; do rest="${rest/"${BASH_REMATCH[0]}"/ }"; done
    # 容器與套件管理的 rm 子指令（舊的 Bash(rm:*) 也不會問）。中間只准 `-` 開頭的選項，
    # 所以 `podman volume rm`（volume 常放資料庫資料）不會被排除，照樣算進字數 → 問
    local re_ctr=$'(docker|podman|nerdctl)([ \t]+-[^ \t\n;&|]+)*[ \t]+((container|image)[ \t]+)?rm([ \t\n;&|]|$)'
    local re_pkg=$'(npm|pnpm|bun)([ \t]+-[^ \t\n;&|]+)*[ \t]+rm([ \t\n;&|]|$)'
    while [[ $rest =~ $re_ctr ]]; do rest="${rest/"${BASH_REMATCH[0]}"/ }"; done
    while [[ $rest =~ $re_pkg ]]; do rest="${rest/"${BASH_REMATCH[0]}"/ }"; done
    local re=$'(^|[[:space:];&|(){}`\'"\\\\$=/])rm([[:space:];&|)`\'"]|$)'
    while [[ $rest =~ $re ]]; do
        n=$((n + 1)); rest="${rest#*"${BASH_REMATCH[0]}"}"
    done
    echo "$n"
}

# 重導向的寫入目標：/dev/null 與 &N（dup）不寫檔，其他都會建立或截斷檔案
_rm_redirect_harmless() { [ "$1" = /dev/null ] || [[ $1 =~ ^\&[0-9-]+$ ]]; }

rm_state_gate() {
    [ "${RM_STATE_GATE:-on}" = "off" ] && return 0
    local cmd="$1" cwd="$2"; shift 2
    local n_word; n_word=$(_rm_word_count "$cmd")
    [ "$n_word" -gt 0 ] || return 0

    local body="$cmd" heredoc=0
    local _hd='<<-?[[:space:]]*["'"'"']?[A-Za-z_]'
    if [[ $cmd =~ $_hd ]] && declare -F cmd_strip_heredoc >/dev/null 2>&1; then
        heredoc=1
        body=$(printf '%s\n' "$cmd" | cmd_strip_heredoc)
    fi

    local base="" seg first t targets opts_done n_seg=0 other=0 skip_next red rec depth lead=1
    local -A _rm_vars=()
    [ -n "$cwd" ] && base=$(_rm_norm "$(_rm_native "$cwd")")
    local -a roots=()
    for t in "$@"; do [ -n "$t" ] && roots+=("$(_rm_norm "$(_rm_native "$t")")"); done
    local -a toks
    while IFS= read -r seg; do
        [ -n "$seg" ] || continue
        IFS=$'\t' read -r -a toks <<< "$seg"
        depth="${toks[0]#D}"; toks=("${toks[@]:1}")
        [ "${#toks[@]}" -gt 0 ] || continue
        first="${toks[0]}"
        # 單獨成一段的 `S=值`：字面值才記；設第二次、或值判斷不了 → 記成空（之後 $S 照樣問）
        if [ "${#toks[@]}" -eq 1 ] && [[ ${first:1} =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local _n="${BASH_REMATCH[1]}" _v="${BASH_REMATCH[2]}"
            # IFS 等會改變展開或找指令的方式：`S=<sp>/b; IFS=/; rm -rf $S` 實際切成好幾個字
            # 設了之後整條指令的 $S 都不能照字面值替換：清空已記的變數、之後也不再記
            case "$_n" in IFS|PATH|CDPATH|GLOBIGNORE|SHELLOPTS|BASHOPTS|BASH_ENV|ENV)
                other=1; lead=0
                for _k in "${!_rm_vars[@]}"; do _rm_vars[$_k]=""; done ;;
            esac
            # 只信「整條指令開頭、不在括號裡」的賦值：`(S=…)`、`false && S=…` 之後的 $S
            # 可能是外面環境變數的值
            if [ "$lead" -eq 1 ] && [ "$depth" -eq 0 ] \
               && [ "${first:0:1}" = S ] && [ -z "${_rm_vars[$_n]+x}" ] && [ -n "$_v" ] && [[ ! $_v =~ [[:space:]] ]]; then
                _rm_vars[$_n]="$_v"
            else
                _rm_vars[$_n]=""
            fi
            continue
        fi
        lead=0
        [ "${#toks[@]}" -ge 2 ] && toks[1]=$(_rm_subst "${toks[1]}")
        case "$first" in
            Scd)
                # cd 後面除了目錄還有東西（重導向、多餘參數）→ 不算單純的 cd
                [ "${#toks[@]}" -eq 2 ] || other=1
                if [ "${#toks[@]}" -ge 2 ] && [ "${toks[1]:0:1}" = S ]; then
                    t="${toks[1]:1}"
                    if _rm_is_abs "$t"; then base=$(_rm_norm "$(_rm_native "$t")")
                    elif [ -n "$base" ]; then
                        case "/$t/" in */../*) base="" ;; *) base=$(_rm_norm "$base/$t") ;; esac
                    fi
                else base=""; fi
                continue ;;
            Srm) ;;
            *) other=1; continue ;;
        esac
        n_seg=$((n_seg + 1)); targets=0; opts_done=0; skip_next=0; rec=0
        local -a args=()
        for t in "${toks[@]:1}"; do
            if [ "$opts_done" -eq 0 ] && [ "${t:0:1}" = S ] && [[ ${t:1} =~ ^-[rRfv]+$ || ${t:1} == --recursive ]]; then
                [[ ${t:1} == *[rR]* || ${t:1} == --recursive ]] && rec=1
            fi
            [ "${t:1}" = -- ] && opts_done=1
            args+=("$(_rm_subst "$t")")
        done
        opts_done=0
        for t in "${args[@]}"; do
            if [ "$skip_next" -eq 1 ]; then
                skip_next=0
                [ "${t:0:1}" = S ] && _rm_redirect_harmless "${t:1}" \
                    || _rm_emit ask "rm 指令帶了寫到 ${t:1} 的重導向，會建立或清空那個檔案，請確認。"
                continue
            fi
            [ "$skip_next" -eq 2 ] && { skip_next=0; continue; }
            if [[ ${t:1} =~ ^[0-9]*\<(.*)$ ]]; then [ -n "${BASH_REMATCH[1]}" ] || skip_next=2; continue; fi
            if [[ ${t:1} =~ ^[0-9]*\>\>?(.*)$ ]]; then
                red="${BASH_REMATCH[1]}"
                if [ -z "$red" ]; then skip_next=1; continue; fi
                [ "${t:0:1}" = S ] && _rm_redirect_harmless "$red" \
                    || _rm_emit ask "rm 指令帶了寫到 $red 的重導向，會建立或清空那個檔案，請確認。"
                continue
            fi
            if [ "$opts_done" -eq 0 ] && [ "${t:0:1}" = S ] && [[ ${t:1} == -* ]]; then
                case "${t:1}" in
                    --) opts_done=1; continue ;;
                    -f|-v|-fv|-vf|--force|--verbose) continue ;;
                    --recursive) continue ;;
                    *) [[ ${t:1} =~ ^-[rRfv]+$ ]] && continue
                       _rm_emit ask "rm 帶了 ${t:1}：只有刪 hook 狀態檔、或 Claude Code 的 scratchpad 暫存區才免確認，其他都要問。" ;;
                esac
            fi
            if ! _rm_safe_target "$t" "$rec" "$base" "${roots[@]}"; then
                [ "$rec" -eq 1 ] \
                    && _rm_emit ask "rm -r 要刪的 ${t:1} 不在 Claude Code 的 scratchpad 暫存區裡（或路徑判斷不了）：刪整個目錄只有暫存區免確認。"
                _rm_emit ask "要刪的 ${t:1} 不是 hook 狀態檔、也不在 scratchpad 暫存區（或路徑判斷不了），請確認。"
            fi
            targets=$((targets + 1))
        done
        [ "$skip_next" -eq 1 ] && _rm_emit ask "rm 指令的重導向沒有目標，請確認。"
        [ "$targets" -gt 0 ] || _rm_emit ask "rm 沒有可判斷的目標，請確認要刪什麼。"
    done < <(_rm_tokenize "$body")

    # 指令裡的 rm 比切段認出來的多 → 有 rm 藏在 $(…)、引號、heredoc、`\rm` 之類的地方
    [ "$n_word" -gt "$n_seg" ] \
        && _rm_emit ask "指令裡有判斷不了的 rm（在 \$(…)、反引號、引號、heredoc 裡，或是 \\rm、command rm、VAR=x rm 這類寫法；說明文字提到 rm 也會被算進來）。請確認會刪什麼。"

    [ "$n_seg" -gt 0 ] && [ "$other" -eq 0 ] && [ "$heredoc" -eq 0 ] \
        && _rm_emit allow "只刪 hook 狀態檔或 Claude Code 的 scratchpad 暫存區，免確認。"
    return 0
}
