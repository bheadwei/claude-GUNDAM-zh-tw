#!/bin/bash
# rm-state-gate.sh — `rm` 的權限改由這裡判斷：只刪 hook 狀態檔就自動同意，其他一律問
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
# 狀態檔＝`<WORK_ROOT 或 MAIN_ROOT>/.claude/taskmaster-data/.<名稱>`，名稱不含 `/`。
# 包含閘門的待辦標記（`.merge-pending`、`.doc-impact`…）：使用者明確決定這些也不用問。
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

# 每段一行，字之間用 \t 分隔，每個字前綴 S（字面值）或 U（含展開，判斷不了）
_rm_tokenize() {
    printf '%s\n' "$1" | awk '
    BEGIN { RS = "\001"; q = "\047"; T = "\t" }
    function flush_tok() { if (tok != "" || had_q) { seg = seg (seg == "" ? "" : T) (unsafe ? "U" : "S") tok }; tok = ""; unsafe = 0; had_q = 0 }
    function flush_seg() { flush_tok(); if (seg != "") print seg; seg = "" }
    {
        s = $0; n = length(s); st = ""; tok = ""; seg = ""; unsafe = 0; had_q = 0
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
            if (c == "\n" || c == ";" || c == "(" || c == ")") { flush_seg(); continue }
            if (c == "|") { if (nx == "|" || nx == "&") i++; flush_seg(); continue }
            if (c == "&") {
                if (nx == "&") { i++; flush_seg(); continue }
                if (substr(tok, length(tok), 1) ~ /[<>]/) { tok = tok c; continue }
                flush_seg(); continue
            }
            if (c ~ /[$`*?[~{}]/) unsafe = 1
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

# _rm_state_target <字（含 S/U 前綴）> <base> <root...> —— 是狀態檔就回 0
# base 與 root 都要先過 _rm_norm "$(_rm_native …)"（rm_state_gate 只算一次）
_rm_state_target() {
    local t="$1" base="$2"; shift 2
    [ "${t:0:1}" = S ] || return 1
    t="${t:1}"
    case "$t" in *\\*|'') return 1 ;; esac
    case "/$t/" in */../*) return 1 ;; esac
    local p
    if _rm_is_abs "$t"; then p=$(_rm_norm "$(_rm_native "$t")")
    else [ -n "$base" ] || return 1; p=$(_rm_norm "$base/$t"); fi
    local r name
    for r in "$@"; do
        [ -n "$r" ] || continue
        name="${p#"$r/.claude/taskmaster-data/."}"
        [ "$name" != "$p" ] && [ -n "$name" ] && [[ $name != */* ]] && [ "$name" != . ] && return 0
    done
    return 1
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

    local base="" seg first t targets opts_done n_seg=0 other=0 skip_next red
    [ -n "$cwd" ] && base=$(_rm_norm "$(_rm_native "$cwd")")
    local -a roots=()
    for t in "$@"; do [ -n "$t" ] && roots+=("$(_rm_norm "$(_rm_native "$t")")"); done
    local -a toks
    while IFS= read -r seg; do
        [ -n "$seg" ] || continue
        IFS=$'\t' read -r -a toks <<< "$seg"
        first="${toks[0]}"
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
        n_seg=$((n_seg + 1)); targets=0; opts_done=0; skip_next=0
        for t in "${toks[@]:1}"; do
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
                    *) _rm_emit ask "rm 帶了 ${t:1}：只有刪 .claude/taskmaster-data/ 底下的狀態檔才免確認，其他都要問。" ;;
                esac
            fi
            _rm_state_target "$t" "$base" "${roots[@]}" \
                || _rm_emit ask "要刪的 ${t:1} 不是 hook 狀態檔（或路徑判斷不了）：只有刪 .claude/taskmaster-data/ 底下的狀態檔才免確認。"
            targets=$((targets + 1))
        done
        [ "$skip_next" -eq 1 ] && _rm_emit ask "rm 指令的重導向沒有目標，請確認。"
        [ "$targets" -gt 0 ] || _rm_emit ask "rm 沒有可判斷的目標，請確認要刪什麼。"
    done < <(_rm_tokenize "$body")

    # 指令裡的 rm 比切段認出來的多 → 有 rm 藏在 $(…)、引號、heredoc、`\rm` 之類的地方
    [ "$n_word" -gt "$n_seg" ] \
        && _rm_emit ask "指令裡有判斷不了的 rm（在 \$(…)、反引號、引號、heredoc 裡，或是 \\rm、command rm、VAR=x rm 這類寫法；說明文字提到 rm 也會被算進來）。請確認會刪什麼。"

    [ "$n_seg" -gt 0 ] && [ "$other" -eq 0 ] && [ "$heredoc" -eq 0 ] \
        && _rm_emit allow "只刪 hook 狀態檔（.claude/taskmaster-data/.*），免確認。"
    return 0
}
