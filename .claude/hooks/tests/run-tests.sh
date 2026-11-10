#!/bin/bash
# .claude/hooks/tests/run-tests.sh — hooks 回歸測試
#
# 為什麼需要：pre-tool-use.sh 現在是硬閘門。它壞掉的兩種方式都很難察覺——
# 誤擋（所有程式碼寫入被 deny）或靜默失效（該擋沒擋，就像當初 .current-task-mode
# 沒人清那個 bug，壞了半年沒發現）。這些測試把每個分支釘住。
#
# 用法：
#   bash .claude/hooks/tests/run-tests.sh                    整套（何時跑見 commands/verify.md 步驟 4）
#   bash .claude/hooks/tests/run-tests.sh <關鍵字>...        只跑標題含任一關鍵字的節（不分大小寫）
#                                                            例：run-tests.sh overview post-write
#   bash .claude/hooks/tests/run-tests.sh --changed <起點>   依 git diff --name-only <起點>（含未追蹤檔）挑節，
#                                                            對應表見下方 _changed_rule（唯一來源）
#   bash .claude/hooks/tests/run-tests.sh --changed -        改動清單從 stdin 讀（一行一個 repo 相對路徑）
#   bash .claude/hooks/tests/run-tests.sh --list             列出所有節
#   加 --dry-run                                             只印會跑哪些節，不跑
#   加 --full                                                --changed 判成整套時照跑（worktree 裡不加就拒絕，exit 3）
# 需求：bash + jq（無 jq 時 hooks 會軟降級，測試會提示跳過相關案例）
#
# 隔離：所有測試在 mktemp 沙箱內跑（CLAUDE_PROJECT_DIR 指向沙箱），
#       絕不碰真實的 .claude/taskmaster-data/ 或 coordination/。

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

# ---------------------------------------------------------------- 選節
#
# 為什麼要：整套在 Windows/Git Bash 上要跑約 50 分鐘（開一個程序 ~0.14 秒，跑一次
# post-write.sh ~3 秒），只改一支 hook 也跑整套，合併後的 /verify 就卡在這裡。
#
# 為什麼不是讓 section() 設旗標：節的本體是直接寫在頂層的指令，旗標擋不住它們執行，
# 只會讓 ok/ng 不計數——該開的程序一個也沒省。所以選節時改成讀本檔、按 `section "` 開頭
# 的行切塊：選中的塊 eval，沒選中的塊只取出**頂層的函式定義與純變數指派**。
# 後面的節會用前面節定義的輔助函式（fs、gbo、mk_handoff…）與路徑變數（MP_FILE、AG_LOG…），
# 整塊跳過會讓它們壞掉；而只取定義不會開任何程序，也不會動到沙箱。
#
# 單獨跑某一節而它依賴前面節留下的**檔案狀態**（不是函式或變數）時會紅——方向是吵，不是靜默；
# 修法是讓那一節自己 reset／setup。整套模式（不帶參數）完全不經過這段，行為與以往相同。

# 改動檔 → 要跑的節（唯一來源；commands/verify.md 步驟 4 依改動挑節時用的就是這張表）
#
# 由上往下，第一個符合的規則生效。輸出：
#   ALL       跑整套
#   NONE      不跑 hook 測試（/verify 只跑 check-counts）
#   =<字串>   標題或節內文提到這個字串的節——新增的節只要寫到那支 hook 的檔名就自動被挑到，
#             不必回來改這張表
#   SELF      本檔：用 `git diff -U0` 的行號找出改到哪幾節，只跑那幾節（加上呼叫了那幾節所
#             定義函式的節）。改到第一個 section 之前的框架（含 section() 與共用函式）或結尾
#             統計 → ALL。改動清單從 stdin 來（沒有起點可比）→ ALL
# 只要有一個檔是 ALL 就跑整套；其餘結果取聯集，再加上「全體 hooks」那節（語法檢查）。
_changed_rule() {
    case "$1" in
        .claude/hooks/tests/run-tests.sh) echo SELF ;;
        # 共用程式：影響面從檔名看不出來
        .claude/hooks/lib/*|.claude/settings.json) echo ALL ;;
        # 測試會讀進沙箱的非程式檔——必須排在下面的 *.md 之前
        .claude/skills/using-taskmaster/SKILL.md)            echo "=using-taskmaster" ;;
        .claude/coordination/handoffs/_HANDOFF_TEMPLATE.md)  echo "=_HANDOFF_TEMPLATE.md" ;;
        .claude/ui/_sources.json)                            echo "=_sources.json" ;;
        scripts/copy-template.sh)                            echo "=copy-template.sh" ;;
        .claude/templates/overview/*)                        echo "=overview.sh" ;;
        .claude/hooks/tests/fixtures/overview/*)             echo "=overview" ;;
        # hook 與被測的腳本：跑提到它的節
        .claude/hooks/*.sh|.claude/scripts/overview.sh|.claude/scripts/overview-scan.sh)      echo "=${1##*/}" ;;
        # 只挑常數檢查那節：寫 =check-counts.sh 會連帶挑到只是提到檔名的 copy-template 節
        .claude/scripts/check-counts.sh)                     echo "=專案圖解常數對範本" ;;
        # 不被 hook 測試執行的東西
        *.md|docs/*|workshop/*|.claude/templates/*|.claude/ui/*|.claude/skills/*|.claude/output-styles/*) echo NONE ;;
        .claude/context/*|.claude/coordination/*|.claude/qa-history/*|.claude/taskmaster-data/*|.claude/logs/*) echo NONE ;;
        .claude/scripts/*|scripts/*|.claude/tests/skill-compliance/*|.github/*|.claude/statusline*.sh) echo NONE ;;
        .gitignore|.worktreeinclude|.mcp.json.*|LICENSE)     echo NONE ;;
        # 對應不到的：保守跑整套
        *) echo ALL ;;
    esac
}

_SEL_KEYS=() _SEL_CHANGED="" _SEL_DRY=0 _SEL_LIST=0 _SEL_MODE=0 _SEL_FULL=0
_root="$(cd "$HOOK_DIR/../.." && pwd)"
while [ $# -gt 0 ]; do
    case "$1" in
        --changed)
            [ $# -ge 2 ] || { echo "✗ --changed 要帶起點（commit／分支），或 - 從 stdin 讀清單" >&2; exit 2; }
            _SEL_CHANGED="$2"; shift 2 ;;
        --dry-run) _SEL_DRY=1; shift ;;
        --full)    _SEL_FULL=1; shift ;;
        --list)    _SEL_LIST=1; shift ;;
        -*) echo "✗ 不認得的選項：$1（用法見本檔開頭）" >&2; exit 2 ;;
        *)  _SEL_KEYS+=("$1"); shift ;;
    esac
done
if [ -n "$_SEL_CHANGED" ] && [ ${#_SEL_KEYS[@]} -gt 0 ]; then
    echo "✗ --changed 與節關鍵字不能同時用" >&2; exit 2
fi

_SEC_TITLES=() _SEC_BODIES=() _SEC_ON=() _SEC_START=() _EPI_LINE=0
_load_sections() {
    local __l __t="" __b="" __in=0 __n=0
    while IFS= read -r __l || [ -n "$__l" ]; do
        __n=$((__n + 1))
        if [[ $__l == 'section "'* ]]; then
            [ "$__in" = 1 ] && { _SEC_TITLES+=("$__t"); _SEC_BODIES+=("$__b"); }
            _SEC_START+=("$__n")
            __t=${__l#section \"}; __t=${__t%\"*}; __b=""; __in=1
            continue
        fi
        [ "$__l" = finish_tests ] && { _EPI_LINE=$__n; break; }
        [ "$__in" = 1 ] && __b+="$__l"$'\n'
    done < "${BASH_SOURCE[0]}"
    [ "$_EPI_LINE" -gt 0 ] || _EPI_LINE=$((__n + 1))
    [ "$__in" = 1 ] && { _SEC_TITLES+=("$__t"); _SEC_BODIES+=("$__b"); }
    local __i; for __i in "${!_SEC_TITLES[@]}"; do _SEC_ON[$__i]=0; done
}

# _sel_title <關鍵字> —— 標題含關鍵字（不分大小寫）的節全部選上；一個都沒有回 1
_sel_title() {
    local __i __hit=1 __k="${1,,}"
    for __i in "${!_SEC_TITLES[@]}"; do
        [[ ${_SEC_TITLES[$__i],,} == *"$__k"* ]] && { _SEC_ON[$__i]=1; __hit=0; }
    done
    return $__hit
}

# _sel_mention <字串> —— 標題或內文提到字串的節全部選上；一個都沒有回 1
_sel_mention() {
    local __i __hit=1
    for __i in "${!_SEC_TITLES[@]}"; do
        case "${_SEC_TITLES[$__i]}"$'\n'"${_SEC_BODIES[$__i]}" in
            *"$1"*) _SEC_ON[$__i]=1; __hit=0 ;;
        esac
    done
    return $__hit
}

# _sel_self_diff <起點> —— 本檔被改了：依 `git diff -U0` 的新檔行號選出改到的節。
# 回 1 = 判斷不了或改到框架／結尾統計 → 呼叫端當成整套；原因放 _SELF_WHY。
# 被改的節若定義了輔助函式，呼叫那些函式的節也一起選（後面的節會共用前面節的 helper；
# 寧可多挑——判斷「這次改的是不是 helper 本體」不值得那份複雜度）。
_sel_self_diff() {
    local __d __l __s __e __i __end __first="${_SEC_START[0]:-0}" __re='^@@ -[0-9,]+ \+([0-9]+)(,([0-9]+))? @@'
    local -a __hit=()
    _SELF_WHY=""
    __d=$(git -C "$_root" diff -U0 --no-renames "$1" -- .claude/hooks/tests/run-tests.sh 2>/dev/null) \
        || { _SELF_WHY="取不到本檔的 diff"; return 1; }
    while IFS= read -r __l; do
        [[ $__l =~ $__re ]] || continue
        __s=${BASH_REMATCH[1]}; __e=${BASH_REMATCH[3]:-1}
        if [ "$__e" -eq 0 ]; then __e=$__s; else __e=$((__s + __e - 1)); fi   # 純刪除：落在第 s 行之後
        if [ "$__s" -lt "$__first" ] || [ "$__e" -ge "$_EPI_LINE" ]; then
            _SELF_WHY="改到第一節之前的框架或結尾統計（第 $__s 行）"; return 1
        fi
        for __i in "${!_SEC_START[@]}"; do
            __end=$(( ${_SEC_START[$((__i + 1))]:-$_EPI_LINE} - 1 ))
            [ "$__s" -le "$__end" ] && [ "$__e" -ge "${_SEC_START[$__i]}" ] && __hit[$__i]=1
        done
    done <<< "$__d"
    [ ${#__hit[@]} -gt 0 ] || { _SELF_WHY="diff 裡沒有可對應的行"; return 1; }
    local __fn __j
    for __i in "${!__hit[@]}"; do
        _SEC_ON[$__i]=1
        printf '  .claude/hooks/tests/run-tests.sh → 改到「%s」\n' "${_SEC_TITLES[$__i]}"
        while IFS= read -r __l; do
            [[ $__l =~ ^([A-Za-z_][A-Za-z0-9_]*)\(\) ]] || continue
            __fn=${BASH_REMATCH[1]}
            for __j in "${!_SEC_TITLES[@]}"; do
                [ "$__j" = "$__i" ] && continue
                [[ ${_SEC_BODIES[$__j]} =~ (^|[^A-Za-z0-9_-])$__fn([^A-Za-z0-9_-]|$) ]] && _SEC_ON[$__j]=1
            done
        done <<< "${_SEC_BODIES[$__i]}"
    done
    return 0
}

_in_worktree() {
    case "$(git -C "$_root" rev-parse --git-dir 2>/dev/null)" in */worktrees/*) return 0 ;; esac
    return 1
}

if [ "$_SEL_LIST" = 1 ]; then
    _load_sections
    for _si in "${!_SEC_TITLES[@]}"; do printf '%2d  %s\n' "$((_si + 1))" "${_SEC_TITLES[$_si]}"; done
    exit 0
fi

if [ -n "$_SEL_CHANGED" ]; then
    _load_sections
    if [ "$_SEL_CHANGED" = - ]; then
        _files=$(cat)
    else
        if ! _files=$(git -C "$_root" -c core.quotepath=off diff --name-only --no-renames "$_SEL_CHANGED" -- 2>/dev/null); then
            echo "⚠ 取不到改動清單（起點：$_SEL_CHANGED）→ 跑整套"
            _files="__UNKNOWN__"
        else
            _files+=$'\n'$(git -C "$_root" -c core.quotepath=off ls-files --others --exclude-standard 2>/dev/null)
        fi
    fi
    _all="" _none=0 _nfiles=0
    while IFS= read -r _f; do
        _f=${_f%$'\r'}
        [ -n "$_f" ] || continue
        _nfiles=$((_nfiles + 1))
        if [ "$_f" = __UNKNOWN__ ]; then _all="取不到改動清單"; continue; fi
        _r=$(_changed_rule "$_f")
        case "$_r" in
            SELF) if [ "$_SEL_CHANGED" = - ]; then
                      printf '  %s → 整套（清單從 stdin 來，沒有起點可比行號）\n' "$_f"; _all="${_all:-$_f}"
                  elif ! _sel_self_diff "$_SEL_CHANGED"; then
                      printf '  %s → 整套（%s）\n' "$_f" "$_SELF_WHY"; _all="${_all:-$_f}"
                  fi ;;
            ALL)  printf '  %s → 整套\n' "$_f"; _all="${_all:-$_f}" ;;
            NONE) _none=$((_none + 1)) ;;
            =*)   if _sel_mention "${_r#=}"; then printf '  %s → 提到「%s」的節\n' "$_f" "${_r#=}"
                  else printf '  %s → 沒有節提到「%s」，只跑語法檢查\n' "$_f" "${_r#=}"; fi ;;
        esac
    done <<< "$_files"
    [ "$_none" -gt 0 ] && printf '  （另有 %d 個檔不需要 hook 測試：文件／範本／執行時產物）\n' "$_none"

    if [ -n "$_all" ]; then
        printf '依改動挑節：%s → 整套\n' "$_all"
        # worktree 裡不默默跑整套：N 條線各跑一份就是 full-suite-gate 要擋的事故，
        # 而 --changed 帶了參數，閘門從指令上看不出它會變成整套
        if [ "$_SEL_FULL" != 1 ] && _in_worktree; then
            echo "✗ 在 worktree 裡，不自動跑整套（Windows 上約 50 分鐘）。"
            echo "  確定要跑：同一條指令加 --full，放背景執行（full-suite-gate 會再擋一次，重試即放行）。"
            echo "  或者改成只跑幾節：run-tests.sh <節關鍵字>...（--list 看全部）"
            [ "$_SEL_DRY" = 1 ] && exit 0
            exit 3
        fi
        [ "$_SEL_DRY" = 1 ] && exit 0
        _SEC_ON=()                                    # 走下面的整套路徑
    elif [ "$_nfiles" -eq 0 ]; then
        echo "依改動挑節：沒有改動檔 → 不跑 hook 測試"
        exit 0
    elif [ "$_nfiles" -eq "$_none" ]; then
        printf '依改動挑節：%d 個改動檔都不需要 hook 測試 → 不跑（只跑 check-counts）\n' "$_nfiles"
        exit 0
    else
        _sel_title "全體 hooks" || { echo "✗ 找不到「全體 hooks」那節（改了標題要同步這裡）" >&2; exit 2; }
        _SEL_MODE=1
    fi
elif [ ${#_SEL_KEYS[@]} -gt 0 ]; then
    _load_sections
    _miss=()
    for _k in "${_SEL_KEYS[@]}"; do _sel_title "$_k" || _miss+=("$_k"); done
    if [ ${#_miss[@]} -gt 0 ]; then
        echo "✗ 沒有任何節的標題含：${_miss[*]}（--list 看全部）" >&2; exit 2
    fi
    _SEL_MODE=1
fi

_SEC_NRUN=0
if [ "$_SEL_MODE" = 1 ]; then
    for _si in "${!_SEC_ON[@]}"; do [ "${_SEC_ON[$_si]}" = 1 ] && _SEC_NRUN=$((_SEC_NRUN + 1)); done
    printf '部分執行：%d 節／共 %d 節\n' "$_SEC_NRUN" "${#_SEC_TITLES[@]}"
    for _si in "${!_SEC_ON[@]}"; do [ "${_SEC_ON[$_si]}" = 1 ] && printf '  - %s\n' "${_SEC_TITLES[$_si]}"; done
    [ "$_SEL_DRY" = 1 ] && exit 0
elif [ "$_SEL_DRY" = 1 ]; then
    printf '整套：%d 節\n' "$(grep -c '^section "' "${BASH_SOURCE[0]}")"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "✗ 找不到 jq — hooks 會軟降級成不攔截，測試無意義。請先安裝 jq。"
    exit 1
fi

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX" 2>/dev/null || true' EXIT

MODE_FILE="$SANDBOX/.claude/taskmaster-data/.current-task-mode"
SM_FILE="$SANDBOX/.claude/taskmaster-data/.suggest-mode"
HANDOFF_DIR="$SANDBOX/.claude/coordination/handoffs"

# ---------------------------------------------------------------- 測試框架

reset() {
    rm -rf "$SANDBOX/.claude"
    mkdir -p "$SANDBOX/.claude/taskmaster-data" "$HANDOFF_DIR" "$SANDBOX/.claude/logs"
}

# run <script> <payload> [ENV=VAL ...]
run() {
    local script="$1" payload="$2"
    shift 2
    printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$SANDBOX" "$@" bash "$HOOK_DIR/$script" 2>/dev/null
}

decision() {
    [ -z "$1" ] && { echo allow; return; }
    echo "$1" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null || echo allow
}

ok() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng() {
    FAIL=$((FAIL + 1))
    printf '  \033[31m✗\033[0m %s\n      期望：%s\n      實得：%s\n' "$1" "$2" "$3"
}

# expect_decision <名稱> <期望> <實際輸出>
expect_decision() {
    local got; got=$(decision "$3")
    [ "$got" = "$2" ] && ok "$1" || ng "$1" "$2" "$got"
}

# expect_contains <名稱> <子字串> <實際輸出>
expect_contains() {
    case "$3" in *"$2"*) ok "$1" ;; *) ng "$1" "含「$2」" "${3:-（空輸出）}" ;; esac
}

# expect_empty <名稱> <實際輸出>
expect_empty() {
    [ -z "$2" ] && ok "$1" || ng "$1" "（空輸出）" "$2"
}

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# expect_eq <名稱> <期望（整串相等）> <實際>
expect_eq() { [ "$3" = "$2" ] && ok "$1" || ng "$1" "${2:-（空輸出）}" "${3:-（空輸出）}"; }

# payload 產生器
w()  { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1"; }
e()  { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }
b()  { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
p()  { jq -nc --arg t "$1" '{prompt:$t}'; }

# 結尾統計。CI 與 check-counts --tests 用 regex 抓整套那行的「通過 N」；部分執行改用「通過數」，
# 抓不到就不會被誤當成整套的案例數
finish_tests() {
    if [ "$_SEL_MODE" = 1 ]; then
        printf '\n\033[1m部分執行（%d 節／共 %d 節，不是整套）\033[0m  通過數 %d ・ 失敗數 %d\n\n' \
            "$_SEC_NRUN" "${#_SEC_TITLES[@]}" "$PASS" "$FAIL"
    else
        printf '\n\033[1m結果\033[0m  通過 %d ・ 失敗 %d\n\n' "$PASS" "$FAIL"
    fi
    [ "$FAIL" -eq 0 ] || exit 1
    exit 0
}

# _hoist_defs <節內容> —— 只執行沒選中那節的頂層函式定義與純變數指派（理由見檔頭「選節」）。
# 靠 bash 自己的 parser：把整節包成函式再 declare -f，輸出是正規化過的（頂層述句固定縮排 4 格），
# 不必自己處理引號與 heredoc。變數只收「整行就是一個指派」的：`X=1 cmd` 這種前綴指派會執行
# cmd，值裡有 $( 或反引號也會執行東西（`$(printf …)` 例外），兩者都不收。
_hoist_defs() {
    local __l __o="" __fn=0 __r
    local __dq='"[^"]*"' __sq="'[^']*'" __bare='[^[:space:];"'"'"'`]*' __pf='\$\(printf [^`]*\)'
    local __re="^    [A-Za-z_][A-Za-z0-9_]*=($__dq|$__sq|$__bare|$__pf);\$"
    eval "__hoist_probe() {
$1
}" 2>/dev/null || { echo "✗ 節的內容解析失敗（bash -n 看看語法）" >&2; exit 2; }
    while IFS= read -r __l; do
        if [ "$__fn" = 1 ]; then
            __o+="$__l"$'\n'
            [[ $__l =~ ^\ {4}\}\;?$ ]] && __fn=0
            continue
        fi
        if [[ $__l =~ ^\ {4}(function\ )?[A-Za-z_][A-Za-z0-9_]*\ \(\)\ *$ ]]; then
            __fn=1; __o+="$__l"$'\n'; continue
        fi
        if [[ $__l =~ $__re ]]; then
            __r=${__l/'$(printf '/}
            case "$__r" in *'$('*|*'`'*) continue ;; esac
            __o+="$__l"$'\n'
        fi
    done <<< "$(declare -f __hoist_probe)"
    unset -f __hoist_probe
    set +u; eval "$__o"; set -u
}

if [ "$_SEL_MODE" = 1 ]; then
    for _si in "${!_SEC_TITLES[@]}"; do
        if [ "${_SEC_ON[$_si]}" = 1 ]; then
            section "${_SEC_TITLES[$_si]}"
            eval "${_SEC_BODIES[$_si]}"
        else
            _hoist_defs "${_SEC_BODIES[$_si]}"
        fi
    done
    finish_tests
fi

# =========================================================================
section "pre-tool-use.sh — 任務模式閘門（無模式檔）"
# =========================================================================
reset
expect_decision "程式碼檔 .ts 被擋"          deny  "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"
expect_decision "程式碼檔 .py 被擋"          deny  "$(run pre-tool-use.sh "$(w /p/main.py)")"
expect_decision "Edit 也走同一條路"          deny  "$(run pre-tool-use.sh "$(e /p/src/a.go)")"
expect_decision "專案腳本 .sh 被擋"          deny  "$(run pre-tool-use.sh "$(w /p/scripts/deploy.sh)")"
expect_decision "文件 .md 放行"              allow "$(run pre-tool-use.sh "$(w /p/README.md)")"
expect_decision "設定 .json 放行"            allow "$(run pre-tool-use.sh "$(w /p/tsconfig.json)")"
expect_decision ".claude/** 放行（免自鎖）"  allow "$(run pre-tool-use.sh "$(w /p/.claude/hooks/x.sh)")"
expect_decision "docs/** 放行"               allow "$(run pre-tool-use.sh "$(w /p/docs/a.py)")"
expect_decision "node_modules 放行"          allow "$(run pre-tool-use.sh "$(w /p/node_modules/x/i.js)")"
expect_decision "dist 產物放行"              allow "$(run pre-tool-use.sh "$(w /p/dist/bundle.js)")"
expect_contains "deny 訊息含判級指引"        "quick" "$(run pre-tool-use.sh "$(w /p/src/api.ts)" | jq -r '.hookSpecificOutput.permissionDecisionReason')"

# =========================================================================
section "pre-tool-use.sh — 有模式檔"
# =========================================================================
reset; echo standard > "$MODE_FILE"
expect_decision "有效模式檔放行"             allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

reset; : > "$MODE_FILE"
expect_decision "空模式檔視同無（被擋）"     deny  "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

reset; echo standard > "$MODE_FILE"; touch -d '1 hour ago' "$MODE_FILE"
expect_decision "1h 前的模式檔仍有效"        allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"
[ -f "$MODE_FILE" ] && ok "未過期不應被清除" || ng "未過期不應被清除" "檔案還在" "已被刪除"

reset; echo standard > "$MODE_FILE"; touch -d '9 hours ago' "$MODE_FILE"
expect_decision "9h 前的模式檔過期被擋"      deny  "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"
[ -f "$MODE_FILE" ] && ng "過期應被清除（解互鎖）" "檔案已刪" "檔案還在" || ok "過期應被清除（解互鎖）"

reset; echo standard > "$MODE_FILE"; touch -d '9 hours ago' "$MODE_FILE"
expect_decision "TTL 可用環境變數調長"       allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)" TASKMODE_TTL_HOURS=24)"

# =========================================================================
section "pre-tool-use.sh — 逃生門"
# =========================================================================
reset; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 全放行"    allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

reset
expect_decision "TASKMODE_GATE=off 全放行"   allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)" TASKMODE_GATE=off)"

reset; echo low > "$SM_FILE"
expect_decision "suggest-mode=low 仍會攔"    deny  "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

# =========================================================================
section "pre-tool-use.sh — 裸 cd 偵測"
# =========================================================================
reset; echo standard > "$MODE_FILE"
expect_decision "裸 cd 被擋"                 deny  "$(run pre-tool-use.sh "$(b 'cd subdir')")"
expect_decision "cd && 鏈式放行"             allow "$(run pre-tool-use.sh "$(b 'cd subdir && npm test')")"
expect_decision "subshell 隔離放行"          allow "$(run pre-tool-use.sh "$(b '(cd subdir && npm test)')")"
expect_decision "cd ; 分號放行"              allow "$(run pre-tool-use.sh "$(b 'cd subdir; ls')")"
expect_decision "非 cd 指令放行"             allow "$(run pre-tool-use.sh "$(b 'ls -la')")"
expect_decision "含 cd 字樣但非指令放行"     allow "$(run pre-tool-use.sh "$(b 'echo cd foo')")"

# =========================================================================
section "post-agent-report.sh — handoff 注入"
# =========================================================================
mk_handoff() { # <檔名> <status> <priority>
    cat > "$HANDOFF_DIR/$1" <<EOF
---
from: planner
to: ui-builder
date: 2026-01-01-0000
priority: $3
status: $2
---

# Handoff

## 起因
測試用交接。
EOF
}

reset; mk_handoff "a.md" pending high
out=$(run post-agent-report.sh '{"tool_name":"Agent"}')
expect_contains "pending 會注入"             "planner → ui-builder" "$out"
expect_contains "注入含優先級"               "[high]"              "$out"
expect_contains "注入含起因"                 "測試用交接"           "$out"

reset; mk_handoff "a.md" completed high
expect_empty   "completed 不注入"            "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset
expect_empty   "無交接時不注入"              "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset; mk_handoff "a.md" pending high; echo off > "$SM_FILE"
expect_empty   "suggest-mode=off 不注入"     "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset; mk_handoff "a.md" pending medium; echo low > "$SM_FILE"
expect_empty   "low 模式濾掉 medium"         "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset; mk_handoff "a.md" pending high; echo low > "$SM_FILE"
expect_contains "low 模式保留 high"          "planner → ui-builder" "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset; cp "$HOOK_DIR/../coordination/handoffs/_HANDOFF_TEMPLATE.md" "$HANDOFF_DIR/" 2>/dev/null
expect_empty   "範本檔不被當成交接"          "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

# =========================================================================
section "handoff 自動歸檔 — completed/cancelled 移出掃描路徑"
# =========================================================================
#
# 為什麼要這組：範本原本寫「完成後不刪除，作為審計軌跡」，於是 completed 的交接
# 永遠留在平坦的 handoffs/ 裡——每次 subagent 結束都要 for-loop 掃全部檔案，
# 才發現 0 個 pending。歸檔做成 hook（不是指令，指令要有人記得打），
# 這裡釘住三件會靜默壞掉的事：搬錯月份、覆蓋掉舊軌跡、逃生門失效。

ARCH="$HANDOFF_DIR/archive"

mk_ho() { # <檔名> <status> <date>
    cat > "$HANDOFF_DIR/$1" <<EOF
---
from: planner
to: ui-builder
date: $3
priority: high
status: $2
---

# Handoff

## 起因
測試用交接。
EOF
}

reset; mk_ho done.md completed 2026-03-04-1200
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$ARCH/2026-03/done.md" ] \
    && ok "completed 被搬進 archive/YYYY-MM/（月份取 date:）" \
    || ng "completed 被搬進 archive/YYYY-MM/（月份取 date:）" "archive/2026-03/done.md" \
          "$(find "$HANDOFF_DIR" -name 'done.md' 2>/dev/null | sed "s|$SANDBOX||" | tr '\n' ' ')"
[ -f "$HANDOFF_DIR/done.md" ] \
    && ng "已歸檔的不留在平坦層" "平坦層無 done.md" "還在" \
    || ok "已歸檔的不留在平坦層"

reset; mk_ho cancel.md cancelled 2026-07-31-0900
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$ARCH/2026-07/cancel.md" ] \
    && ok "cancelled 也被歸檔" \
    || ng "cancelled 也被歸檔" "archive/2026-07/cancel.md" \
          "$(find "$HANDOFF_DIR" -type f 2>/dev/null | sed "s|$SANDBOX||" | tr '\n' ' ')"

reset; mk_ho keep.md pending 2026-03-04-1200
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$HANDOFF_DIR/keep.md" ] \
    && ok "pending 留在平坦層" \
    || ng "pending 留在平坦層" "handoffs/keep.md 還在" "被搬走了"

# 範本的 frontmatter 字面就含 completed（`<pending|accepted|completed|cancelled>`）
reset; cp "$HOOK_DIR/../coordination/handoffs/_HANDOFF_TEMPLATE.md" "$HANDOFF_DIR/" 2>/dev/null
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$HANDOFF_DIR/_HANDOFF_TEMPLATE.md" ] \
    && ok "範本檔不被歸檔（frontmatter 字面含 completed）" \
    || ng "範本檔不被歸檔（frontmatter 字面含 completed）" "範本原地不動" "被搬走了"

# 審計軌跡不能被吃掉：同名一律加後綴
reset; mk_ho dup.md completed 2026-03-04-1200
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
mk_ho dup.md completed 2026-03-04-1200
echo "第二份的指紋" >> "$HANDOFF_DIR/dup.md"
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
if [ -f "$ARCH/2026-03/dup-2.md" ] \
   && ! grep -q "第二份的指紋" "$ARCH/2026-03/dup.md" 2>/dev/null \
   && grep -q "第二份的指紋" "$ARCH/2026-03/dup-2.md" 2>/dev/null; then
    ok "同名不覆蓋：加 -2 後綴且原檔一字不動"
else
    ng "同名不覆蓋：加 -2 後綴且原檔一字不動" "dup.md 保持原樣＋dup-2.md 是新的" \
       "$(ls "$ARCH/2026-03" 2>/dev/null | tr '\n' ' ')"
fi

reset; mk_ho done.md completed 2026-03-04-1200; echo off > "$SM_FILE"
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$HANDOFF_DIR/done.md" ] \
    && ok "suggest-mode=off 不歸檔（逃生門連歸檔一起關）" \
    || ng "suggest-mode=off 不歸檔（逃生門連歸檔一起關）" "檔案原地不動" "被搬走了"

# archive/ 不能被 pending 掃描撈到，否則歸檔等於沒用（glob 不遞迴）
reset; mkdir -p "$ARCH/2026-03"; mk_ho tmp.md pending 2026-03-04-1200
mv "$HANDOFF_DIR/tmp.md" "$ARCH/2026-03/old-pending.md"
expect_empty "archive/ 裡的 pending 不被掃描" "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset
printf '%s\n' '---' 'from: x' 'to: y' 'status: completed' '---' > "$HANDOFF_DIR/nodate.md"
touch -d '2025-11-15' "$HANDOFF_DIR/nodate.md" 2>/dev/null
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$ARCH/2025-11/nodate.md" ] \
    && ok "無 date: 時退回 mtime 的月份" \
    || ng "無 date: 時退回 mtime 的月份" "archive/2025-11/nodate.md" \
          "$(find "$ARCH" -type f 2>/dev/null | sed "s|$SANDBOX||" | tr '\n' ' ')"

# =========================================================================
section "user-prompt-submit.sh — 意圖路由"
# =========================================================================
reset
expect_contains "auth 關鍵字 → critical"     "critical"              "$(run user-prompt-submit.sh "$(p '實作登入認證')")"
expect_contains "UI 關鍵字 → 提示載入 skill" "ui-style-compliance"   "$(run user-prompt-submit.sh "$(p '做一個前端頁面')")"
expect_contains "npm 關鍵字 → 提示載入 skill" "node-package-manager" "$(run user-prompt-submit.sh "$(p '幫我 npm install react')")"
expect_contains "測試關鍵字 → 提示載入 skill" "testing-standards"    "$(run user-prompt-submit.sh "$(p '補一下測試覆蓋率')")"
expect_contains "migration → 提示先 /plan"   "/plan"                 "$(run user-prompt-submit.sh "$(p '做資料庫遷移')")"
expect_empty   "斜線指令不路由"              "$(run user-prompt-submit.sh "$(p '/task-next')")"
expect_empty   "無關鍵字不注入"              "$(run user-prompt-submit.sh "$(p '今天天氣如何')")"

# 新增功能提示：只有在 wbs.md 存在時才該出現（沒 WBS 談不上追加）
reset
expect_empty   "無 WBS 時不提 /task-add"     "$(run user-prompt-submit.sh "$(p '我想加一個通知功能')")"
reset; : > "$SANDBOX/.claude/taskmaster-data/wbs.md"
expect_contains "有 WBS 時提示 /task-add"    "/task-add"             "$(run user-prompt-submit.sh "$(p '我想加一個通知功能')")"

# 執行期 bug 與建置錯誤要分流到不同 agent
reset
expect_contains "執行期 bug → debug-investigator"  "debug-investigator" "$(run user-prompt-submit.sh "$(p '登入之後頁面沒反應，怪怪的')")"
expect_contains "建置錯誤 → build-error-resolver"  "build-error-resolver" "$(run user-prompt-submit.sh "$(p 'tsc 型別錯誤修不掉')")"
expect_contains "開 PR → /pr"                "/pr"                   "$(run user-prompt-submit.sh "$(p '幫我開 PR')")"
expect_contains "依賴維護 → /deps"           "/deps"                 "$(run user-prompt-submit.sh "$(p '幫我升級套件')")"
expect_contains "技術選型 → /adr"            "/adr"                  "$(run user-prompt-submit.sh "$(p 'Redux 還是 Zustand 比較好？要用哪個')")"

reset
expect_contains "文件維護 → documentation-specialist" "documentation-specialist" \
    "$(run user-prompt-submit.sh "$(p '幫我整理更新文件')")"
expect_contains "更新 README → documentation-specialist" "documentation-specialist" \
    "$(run user-prompt-submit.sh "$(p '更新一下 README 和 API 文檔')")"
expect_contains "PRD／架構文檔 → /docs-init" "/docs-init" \
    "$(run user-prompt-submit.sh "$(p '把 PRD 的架構文檔同步一下')")"
expect_contains "路由用命令式而非建議式"      'subagent_type' \
    "$(run user-prompt-submit.sh "$(p '幫我整理更新文件')")"

reset; echo off > "$SM_FILE"
expect_empty   "suggest-mode=off 不注入"     "$(run user-prompt-submit.sh "$(p '實作登入認證')")"

# critical 關鍵字分兩級：login／session 單獨出現（UI、文案）不建議 critical，
# 要碰到認證或授權邏輯本身才算。舊規則把「改登入頁的按鈕顏色」也推成 critical
# （必須 /plan＋最嚴的覆蓋率門檻）。
expect_not_contains() { # <說明> <不該出現的字串> <實際輸出>
    case "$3" in
        *"$2"*) ng "$1" "（不含）$2" "$3" ;;
        *) ok "$1" ;;
    esac
}
reset
expect_not_contains "login 頁的 UI 改動不建議 critical" "critical" \
    "$(run user-prompt-submit.sh "$(p '改 login 頁的按鈕顏色')")"
expect_not_contains "session 逾時提示文字不建議 critical" "critical" \
    "$(run user-prompt-submit.sh "$(p '把 session 逾時的提示文字改短一點')")"
expect_contains "login 的密碼驗證邏輯 → critical" "critical" \
    "$(run user-prompt-submit.sh "$(p '改 login 的密碼驗證邏輯')")"
expect_contains "session＋token 過期處理 → critical" "critical" \
    "$(run user-prompt-submit.sh "$(p 'session 過期時要自動 refresh token')")"
expect_contains "認證訊息不再重述覆蓋率百分比" "testing-standards" \
    "$(run user-prompt-submit.sh "$(p '實作登入認證')")"

# 流程模板 agent 退場（ADR-2026-11-05-004）：PRD／架構文件走 /docs-init，ADR 走 /adr 或 architect。
# 「幫我寫一份 PRD」不含「文件」：舊規則要先命中文件類關鍵字才看 PRD，整句沒有任何注入
reset
expect_contains     "寫 PRD（沒說「文件」）→ /docs-init" "/docs-init" \
    "$(run user-prompt-submit.sh "$(p '幫我寫一份 PRD')")"
expect_not_contains "PRD 路由不再指向已退場的流程模板 agent" "template-manager" \
    "$(run user-prompt-submit.sh "$(p '把 PRD 的架構文檔同步一下')")"
DOC_ADR=$(run user-prompt-submit.sh "$(p '幫我補一份 ADR')")
expect_contains     "補 ADR → ADR 路由（/adr 或 architect）" "偵測到 ADR" "$DOC_ADR"
expect_not_contains "補 ADR 不會被導去 /docs-init" "/docs-init" "$DOC_ADR"
expect_contains     "複數 ADRs 也命中 ADR 路由" "偵測到 ADR" \
    "$(run user-prompt-submit.sh "$(p '這次要寫幾份 ADRs')")"
expect_contains     "複數 PRDs 也命中 /docs-init" "/docs-init" \
    "$(run user-prompt-submit.sh "$(p '兩個子系統各有 PRDs 要寫')")"
# 「同步／更新既有架構文件」是文件維護，不是產初稿：主訊息要是 documentation-specialist
DOC_ARCH_SYNC=$(run user-prompt-submit.sh "$(p '同步架構文件')")
expect_contains     "同步架構文件 → 文件維護（documentation-specialist）" "偵測到文件維護" "$DOC_ARCH_SYNC"
expect_not_contains "同步架構文件不會被導去 /docs-init" "/docs-init" "$DOC_ARCH_SYNC"
expect_contains     "更新架構文件 → 文件維護（documentation-specialist）" "偵測到文件維護" \
    "$(run user-prompt-submit.sh "$(p '程式改完了，幫我更新一下架構文件')")"
expect_contains     "補架構文件 → /docs-init" "/docs-init" \
    "$(run user-prompt-submit.sh "$(p '幫我補一份架構文件')")"
DOC_README=$(run user-prompt-submit.sh "$(p '順便更新 README')")
expect_contains     "順便更新 README → documentation-specialist" "documentation-specialist" "$DOC_README"
expect_not_contains "文件維護的注入不再提 codemap" "codemap" "$DOC_README"

# subagent 交回的報告不是使用者提問。實測（2026-09-17 transcript）harness 把報告
# 當成一則 user 訊息送進來、UserPromptSubmit 照樣觸發，報告內文的關鍵字於是
# 注入一串無關建議。開頭三行有 hand-back 標記就跳過路由。
HANDBACK=$(printf '%s\n%s\n%s\n%s' 'Another Claude session sent a message:' \
    '<agent-message from="a0cf8e0e9898705e7">' \
    '[Subagent hand-back] The text below is the final report of a subagent this session delegated to.' \
    '  改了認證邏輯、部署設定與測試覆蓋率，請 code review')
reset
expect_empty "subagent hand-back 不做意圖路由" "$(run user-prompt-submit.sh "$(p "$HANDBACK")")"
expect_empty "背景工作完成通知不做意圖路由" \
    "$(run user-prompt-submit.sh "$(p "$(printf '<task-notification>\n<task-id>x</task-id>\n<summary>認證 部署 測試</summary>')")")"
expect_contains "使用者原話中途引用 [Subagent hand-back] 仍照常路由" "critical" \
    "$(run user-prompt-submit.sh "$(p "$(printf '幫我改認證邏輯\n第二行\n第三行\n剛才看到 [Subagent hand-back] 的字樣')")")"

# 前端路由（D10）：`ui`／`css` 曾是裸子字串，quick、build、guide、access 都會命中；
# 反過來「做個官網」「這個形象頁」這種從不講 UI 的說法又漏接
reset
for q in 'quick fix 一下 build 腳本' '看一下 guide' 'QUICK BUILD GUIDE' '這個 access token 的 test suite'; do
    expect_not_contains "前端路由不被「$q」誤觸發" "ui-style-compliance" \
        "$(run user-prompt-submit.sh "$(p "$q")")"
done
for q in '幫我做一個 landing page' '做餐廳的官網' 'UI 調整一下' '這個形象頁' '改一下ui的間距' '改 style.css 的顏色' '幫我做一個咖啡店的形象網站'; do
    expect_contains "前端路由接得到「$q」" "ui-style-compliance" \
        "$(run user-prompt-submit.sh "$(p "$q")")"
done

# =========================================================================
section "pre-tool-use.sh — 坑閘門（context/learned/）"
# =========================================================================
# 建一份坑紀錄：files: 用區塊寫法，另一份用行內寫法，兩種都要能觸發
mk_pitfall() {
    mkdir -p "$SANDBOX/.claude/context/learned"
    cat > "$SANDBOX/.claude/context/learned/$1.md" <<EOF
---
date: 2026-08-19
title: $2
files:
  - "$3"
symptom: 換 site 後回 401
root-cause: token 快取沒把 site 併進 key
guard: 快取 key 必須含 site_id
severity: high
---
EOF
}

reset; echo standard > "$MODE_FILE"
mk_pitfall "oauth-site-scope" "OAuth token 不能跨 site 重用" "backend/mcp/*.py"
out=$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/client.py")")
expect_decision "命中 learned 的檔案被擋一次"      deny  "$out"
expect_contains "deny 理由含根因"                  "token 快取沒把 site 併進 key" "$out"
expect_contains "deny 理由含避法"                  "快取 key 必須含 site_id"      "$out"
expect_decision "同檔案第二次放行（deny-once）"    allow "$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/client.py")")"
expect_decision "無關檔案不受影響"                 allow "$(run pre-tool-use.sh "$(w "$SANDBOX/frontend/Button.tsx")")"

reset; echo standard > "$MODE_FILE"
mk_pitfall "inline-form" "行內 files 寫法" "x"
printf -- '---\ndate: 2026-08-19\ntitle: 行內寫法\nfiles: ["src/api/**/*.ts"]\nsymptom: s\nroot-cause: r\nguard: g\nseverity: low\n---\n' \
    > "$SANDBOX/.claude/context/learned/inline-form.md"
expect_decision "files 行內寫法也能觸發"           deny  "$(run pre-tool-use.sh "$(w "$SANDBOX/src/api/v1/h.ts")")"

reset; echo standard > "$MODE_FILE"
mkdir -p "$SANDBOX/.claude/context/learned"
cp "$SANDBOX/../.gitkeep" /dev/null 2>/dev/null || true
printf -- '---\ndate: 2026-01-01\ntitle: 範本\nfiles:\n  - "backend/models.py"\nsymptom: s\nroot-cause: r\nguard: g\n---\n' \
    > "$SANDBOX/.claude/context/learned/_PITFALL_TEMPLATE.md"
expect_decision "_ 開頭的範本檔不被當真紀錄"       allow "$(run pre-tool-use.sh "$(w "$SANDBOX/backend/models.py")")"

reset; echo standard > "$MODE_FILE"
mk_pitfall "escape" "逃生門測試" "backend/mcp/*.py"
expect_decision "PITFALL_GATE=off 關閉坑閘門"      allow "$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/a.py")" PITFALL_GATE=off)"

reset; echo standard > "$MODE_FILE"
expect_decision "沒有 learned 目錄時不誤擋"        allow "$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/a.py")")"

# 任務模式閘門優先於坑閘門（沒判級時先要求判級，訊息不該混淆）
reset
mk_pitfall "order" "順序測試" "backend/mcp/*.py"
out=$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/a.py")")
expect_decision "無模式檔時仍先擋任務模式"         deny  "$out"
expect_contains "且理由是判級而非坑"               "尚未判定任務模式" "$out"

# =========================================================================
section "post-write.sh — 文件影響偵測"
# =========================================================================
IMPACT="$SANDBOX/.claude/taskmaster-data/.doc-impact"
NOTIFIED="$SANDBOX/.claude/taskmaster-data/.doc-impact-notified"
pw() { run post-write.sh "$(w "$SANDBOX/$1")"; }

reset
out=$(pw "src/api/reconcile/route.ts")
expect_contains "API 檔第一次命中會注入提醒"   "文件影響提醒" "$out"
expect_contains "提醒指向 /verify 會擋"        "/verify"      "$out"
expect_empty   "同任務第二次不再吵"            "$(pw "src/models/ledger.ts")"
if grep -qxF "src/models/ledger.ts" "$IMPACT" 2>/dev/null; then ok "不吵但仍累積進清單"
else ng "不吵但仍累積進清單" "清單含 src/models/ledger.ts" "$(cat "$IMPACT" 2>/dev/null)"; fi

reset
expect_empty   "一般實作檔不觸發"              "$(pw "src/utils/format.ts")"
if [ ! -f "$IMPACT" ]; then ok "一般實作檔不建清單"
else ng "一般實作檔不建清單" "無 .doc-impact" "$(cat "$IMPACT")"; fi

# 各類「文件會描述的檔案」都要認得
for f in "src/routes/user.ts" "api/openapi.yaml" "proto/svc.proto" \
         "db/migrations/001_init.sql" "src/entities/Order.ts" "src/lib/index.ts" \
         "types/global.d.ts" "src/cli/main.ts" ".env.example"; do
    reset
    expect_contains "認得 $f" "文件影響提醒" "$(pw "$f")"
done

# 排除項
#
# 注意 `.claude/hooks/x.sh` 已從這份清單移出：它現在會命中「擴充維護提醒」
# （見下一組測試）。文件影響偵測仍然不管它——兩個提醒的判斷是分開的。
for f in "src/api/route.test.ts" "src/api/user.spec.ts" "docs/api.md" \
         "node_modules/pkg/index.js" "dist/index.js" \
         "__tests__/api/index.ts"; do
    reset
    expect_empty "排除 $f" "$(pw "$f")"
done

reset
expect_empty   "DOC_SYNC_GATE=off 關閉偵測" \
    "$(run post-write.sh "$(w "$SANDBOX/src/api/x.ts")" DOC_SYNC_GATE=off)"

reset; echo off > "$SM_FILE"
expect_empty   "suggest-mode=off 也關閉偵測"   "$(pw "src/api/x.ts")"

# =========================================================================
section "post-write.sh — 前端寫入檢查（lib/ui-lint.sh）"
# =========================================================================
#
# 檢查的是磁碟上的檔案（Edit 的 payload 只有被換掉的那段），所以每個案例都真的建檔。
UI_JSON="$SANDBOX/.claude/taskmaster-data/ui-style.json"
uw() { # <相對路徑> <內容> [ENV=VAL ...] → post-write 的 additionalContext
    local rel="$1" body="$2"; shift 2
    mkdir -p "$(dirname "$SANDBOX/$rel")"
    printf '%s\n' "$body" > "$SANDBOX/$rel"
    run post-write.sh "$(w "$SANDBOX/$rel")" "$@" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
ui_clean() { rm -rf "$SANDBOX/src" "$SANDBOX/docs"; }

reset; ui_clean
out=$(uw "src/components/Hero.tsx" "$(printf 'export const Hero = () => (\n  <h1 style={{ color: %s }}>Hi</h1>\n)' "'#1D1D1F'")")
expect_contains "元件寫死色碼 → 提醒"                 "寫死色碼"   "$out"
expect_contains "提醒帶行號與色碼"                    'L2 `#1D1D1F`' "$out"
expect_contains "提醒說明只提醒不擋"                  "只提醒，不擋" "$out"

reset; ui_clean
expect_empty "tokens 檔的 CSS 變數宣告不提醒" "$(uw "src/styles/tokens.css" "$(printf ':root {\n  --color-primary: #1D1D1F;\n}')")"
expect_empty "tokens 檔裡的一般 hex 也不提醒" "$(uw "src/styles/tokens.css" '.a { color: #fff; }')"
expect_empty "一行內的 :root 自訂屬性不提醒"  "$(uw "src/app.css" ':root { --c: #fff; }')"
expect_empty "var() 的備援值不算寫死"         "$(uw "src/app.css" '.a { color: var(--c, #000); }')"
expect_empty "頁內錨點 #face 不是色碼"        "$(uw "src/Nav.tsx" '<a href="#face">x</a>')"
expect_empty "HTML 實體 &#8212; 不是色碼"     "$(uw "src/Nav.html" '<p>a &#8212; b</p>')"
expect_empty "theme 檔不提醒"                 "$(uw "src/theme.css" '.a { color: #fff; }')"
expect_empty "測試檔不提醒"                   "$(uw "src/Hero.test.tsx" "expect(c).toBe('#fff')")"
expect_empty "非前端副檔名不提醒"             "$(uw "src/colors.ts" "export const c = '#fff'")"
expect_empty "docs/ 不提醒"                   "$(uw "docs/demo.html" '<p style="color:#fff">x</p>')"
reset; mkdir -p "$SANDBOX/.claude/ui/x"
printf '<p style="color:#fff">x</p>\n' > "$SANDBOX/.claude/ui/x/preview.html"
expect_empty ".claude/** 不提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/ui/x/preview.html")" | jq -r '.hookSpecificOutput.additionalContext // ""')"

# payload 沒帶 cwd 時 WORK_ROOT 退回主 checkout，worktree 裡的檔案相對路徑會以 .claude/worktrees/ 開頭
reset; mkdir -p "$SANDBOX/.claude/worktrees/wt1/src"
printf "<p style={{color: '#fff'}}>x</p>\n" > "$SANDBOX/.claude/worktrees/wt1/src/Hero.tsx"
expect_contains "worktree 裡的前端檔照樣檢查" "寫死色碼" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/worktrees/wt1/src/Hero.tsx")" | jq -r '.hookSpecificOutput.additionalContext // ""')"

# 動畫等級：沒有 ui-style.json＝還沒定調，不檢查
GSAP_SRC="$(printf "import gsap from 'gsap'\nexport const A = () => null")"
reset; ui_clean
expect_empty "沒有 ui-style.json → 不做 motion 檢查" "$(uw "src/Anim.tsx" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"
out=$(uw "src/Anim.tsx" "$GSAP_SRC")
expect_contains "L1 卻 import gsap → 提醒"       "動畫等級不符" "$out"
expect_contains "motion 提醒帶 import 的行號"     "L1 \`import gsap from 'gsap'\`" "$out"
reset; ui_clean; echo '{"motion":"L2"}' > "$UI_JSON"
expect_empty "L2 import gsap → 不提醒" "$(uw "src/Anim.tsx" "$GSAP_SRC")"
expect_contains "L2 import three → 提醒" "動畫等級不符" "$(uw "src/Scene.tsx" "import * as THREE from 'three'")"
expect_contains "L2 用 CDN 載 three.js → 提醒" "動畫等級不符" \
    "$(uw "src/index.html" '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>')"
reset; ui_clean; echo '{"motion":"L3"}' > "$UI_JSON"
expect_empty "L3 import three → 不提醒" "$(uw "src/Scene.tsx" "import * as THREE from 'three'")"
reset; ui_clean; echo '{"source":"vercel"}' > "$UI_JSON"
expect_contains "ui-style.json 沒有 motion → 當 L1（motion.md 的規定）" "動畫等級不符" "$(uw "src/Anim.tsx" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"
expect_empty "L1 但文字裡提到 three 不算 import" "$(uw "src/Copy.tsx" '<p>three steps to motion</p>')"
expect_contains "L1 的 framer-motion 也算" "動畫等級不符" "$(uw "src/M.tsx" 'import { motion } from "framer-motion"')"

# AI 痕跡（P0，改寫自 avoid-ai-design 的 detect.mjs：C6／C1／K1）
reset; ui_clean
out=$(uw "src/Title.tsx" '<h1 className="bg-gradient-to-r from-indigo-500 to-purple-600 bg-clip-text text-transparent">Hi</h1>')
expect_contains "Tailwind 漸層字 → C6" "**C6**" "$out"
expect_contains "Tailwind 紫靛漸層 → C1" "**C1**" "$out"
expect_contains "AI 痕跡提醒附出處" "avoid-ai-design" "$out"
expect_contains "CSS background-clip:text＋透明字 → C6" "**C6**" \
    "$(uw "src/t.css" "$(printf '.t {\n  background-clip: text;\n  -webkit-text-fill-color: transparent;\n}')")"
expect_contains "shadcn 預設 --primary → K1" "**K1**" \
    "$(uw "src/globals.css" "$(printf ':root {\n  --primary: oklch(0.205 0 0);\n}')")"
expect_empty "改過的 --primary 不算 K1" \
    "$(uw "src/globals.css" "$(printf ':root {\n  --primary: oklch(0.45 0.12 30);\n}')")"
expect_empty "藍綠漸層不算 C1" "$(uw "src/B.tsx" '<div className="bg-gradient-to-r from-sky-500 to-emerald-500">x</div>')"
expect_empty "上一行 avoid-ai-design-ignore: C6 → 豁免" \
    "$(uw "src/I.tsx" "$(printf '{/* avoid-ai-design-ignore: C6 */}\n<h1 className="bg-clip-text text-transparent">x</h1>')")"
out=$(uw "src/J.css" "$(printf '/* avoid-ai-design-ignore-file: K1 */\n:root {\n  --primary: oklch(0.205 0 0);\n}\n.t { background-clip: text; color: transparent; }')")
expect_not_contains "整檔豁免 K1 → 不報 K1"   "**K1**" "$out"
expect_contains     "整檔豁免 K1 → 仍報 C6"   "**C6**" "$out"
expect_empty "整檔豁免不帶 ID → 全部豁免" \
    "$(uw "src/K.tsx" "$(printf '{/* avoid-ai-design-ignore-file */}\n<h1 className="bg-clip-text text-transparent">x</h1>')")"

# 動畫等級以單頁 IA snippet 為準（motion.md 開頭）。對應得到才用單頁等級；
# 對應不到（元件檔、沒有 snippet 的頁）就取「專案與所有單頁中最寬鬆的那級」——寧可漏提醒也不誤報。
IA_DOC="$SANDBOX/docs/17_frontend_information_architecture.md"
ia_page() { # <頁面路徑> <動畫等級那一行的值> —— append 一份最小 IA snippet
    mkdir -p "$(dirname "$IA_DOC")"
    printf '## 某頁（%s）\n\n### 實作筆記\n- 狀態管理：無\n- 動畫等級：%s\n\n' "$1" "$2" >> "$IA_DOC"
}
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"; ia_page / '本頁另外調為 L2'
expect_empty "專案 L1、首頁另外調為 L2 → app/page.tsx import gsap 不提醒" "$(uw "src/app/page.tsx" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L2"}' > "$UI_JSON"; ia_page /pricing '本頁另外調為 L1'
out=$(uw "src/app/pricing/page.tsx" "$GSAP_SRC")
expect_contains "專案 L2、定價頁另外調為 L1 → 該頁 import gsap 要提醒" "動畫等級不符" "$out"
expect_contains "提醒講明等級來自單頁 IA snippet" "IA snippet" "$out"
expect_contains "pages router（pages/about.vue）也對應得到" "動畫等級不符" \
    "$(ia_page /about '本頁另外調為 L1'; uw "src/pages/about.vue" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"; ia_page /pricing '本頁另外調為 L2'
expect_empty "route group (marketing) 去掉後對應到 /pricing（L2）→ 不提醒" \
    "$(uw "src/app/(marketing)/pricing/page.tsx" "$GSAP_SRC")"
expect_empty "對應不到頁面的元件、有單頁調到 L2 → 不提醒（保守）" \
    "$(uw "src/components/sections/PricingCards.tsx" "$GSAP_SRC")"
expect_contains "對應不到時仍守最寬鬆那級：L2 之上的 three 照樣提醒" "動畫等級不符" \
    "$(uw "src/components/sections/Scene.tsx" "import * as THREE from 'three'")"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"; ia_page /pricing '沿用專案 L1'
expect_contains "單頁寫「沿用專案」→ 照專案 L1 提醒" "動畫等級不符" "$(uw "src/app/pricing/page.tsx" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L2"}' > "$UI_JSON"; ia_page /pricing '本頁另外調為 L1'
expect_empty "只有單頁往下調時，對應不到的元件照專案 L2 → gsap 不提醒" "$(uw "src/components/A.tsx" "$GSAP_SRC")"
ui_clean

# 路徑排除與 hooks/README.md、post-write.sh 一致：測試、fixtures、vendor、壓縮過的 css
HEXSRC="<p style={{color: '#fff'}}>x</p>"
ui_xclean() { rm -rf "$SANDBOX/test" "$SANDBOX/tests" "$SANDBOX/fixtures" "$SANDBOX/vendor" "$SANDBOX/public"; ui_clean; }
reset; ui_xclean
expect_empty "test/ 不提醒"            "$(uw "test/Hero.tsx" "$HEXSRC")"
expect_empty "tests/ 不提醒"           "$(uw "src/tests/Hero.tsx" "$HEXSRC")"
expect_empty "fixtures 不提醒"         "$(uw "src/__fixtures__/Hero.tsx" "$HEXSRC")"
expect_empty "vendor/ 不提醒"          "$(uw "vendor/lib.css" '.a { color: #fff; }')"
expect_empty "public/vendor/ 不提醒"   "$(uw "public/vendor/x/lib.css" '.a { color: #fff; }')"
expect_empty "*.min.css 不提醒"        "$(uw "src/styles/app.min.css" '.a{color:#fff}')"
expect_contains "名稱只是含 test 的元件照樣檢查（Testimonials.tsx）" "寫死色碼" \
    "$(uw "src/components/Testimonials.tsx" "$HEXSRC")"
ui_xclean

# 逃生門與合併輸出
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"
BOTH="$(printf "import gsap from 'gsap'\nexport const A = () => <p style={{color: '#fff'}}>x</p>")"
expect_empty "UI_LINT=off → 兩種提醒都沒有" "$(uw "src/Both.tsx" "$BOTH" UI_LINT=off)"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"; echo off > "$SM_FILE"
expect_empty "suggest-mode=off → 也不檢查" "$(uw "src/Both.tsx" "$BOTH")"
reset; ui_clean
raw=$(mkdir -p "$SANDBOX/src/components" && printf "export const A = () => <p style={{color: '#fff'}}>x</p>\n" > "$SANDBOX/src/components/index.tsx" \
      && run post-write.sh "$(w "$SANDBOX/src/components/index.tsx")")
if echo "$raw" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1; then
    ok "同時命中文件影響與色碼 → 仍是一個合法 JSON"
else
    ng "同時命中文件影響與色碼 → 仍是一個合法 JSON" "單一 PostToolUse JSON" "${raw:0:120}"
fi
out=$(echo "$raw" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
expect_contains "合併輸出含文件影響提醒" "文件影響提醒" "$out"
expect_contains "合併輸出含寫死色碼"     "寫死色碼"     "$out"
ui_clean

# post-write 先用副檔名與路徑篩過才啟動 ui-lint：每次寫檔多開一個 bash 在這台機器要好幾百毫秒，
# 而絕大多數寫入是 .claude/**、.md、.ts。用一份 hooks 複本把 ui-lint 換成「被叫就留記號」來驗。
PW_COPY="$SANDBOX/hookcopy"; PW_MARK="$SANDBOX/ui-lint-called"
rm -rf "$PW_COPY"; mkdir -p "$PW_COPY"
cp "$HOOK_DIR"/*.sh "$PW_COPY/"; cp -r "$HOOK_DIR/lib" "$PW_COPY/lib"
printf '#!/bin/bash\necho "$2" >> "%s"\n' "$PW_MARK" > "$PW_COPY/lib/ui-lint.sh"
pw_called() { # <相對路徑> → 印出 yes／no
    rm -f "$PW_MARK"; mkdir -p "$(dirname "$SANDBOX/$1")"; echo x > "$SANDBOX/$1"
    printf '%s' "$(w "$SANDBOX/$1")" | env CLAUDE_PROJECT_DIR="$SANDBOX" bash "$PW_COPY/post-write.sh" >/dev/null 2>&1
    [ -s "$PW_MARK" ] && echo yes || echo no
}
reset
expect_eq "寫 .claude/skills/x/SKILL.md 不啟動 ui-lint" no  "$(pw_called .claude/skills/x/SKILL.md)"
expect_eq "寫 .claude/ui/x/preview.html 不啟動 ui-lint" no "$(pw_called .claude/ui/x/preview.html)"
expect_eq "寫 src/a.ts 不啟動 ui-lint"                 no  "$(pw_called src/a.ts)"
expect_eq "寫 README.md 不啟動 ui-lint"                no  "$(pw_called README.md)"
expect_eq "寫 src/A.tsx 照樣啟動 ui-lint"              yes "$(pw_called src/A.tsx)"
expect_eq "寫 src/A.CSS（大寫副檔名）照樣啟動"         yes "$(pw_called src/A.CSS)"
expect_eq "worktree 裡的 .claude/worktrees/w/src/A.vue 照樣啟動" yes "$(pw_called .claude/worktrees/w/src/A.vue)"
rm -rf "$PW_COPY" "$PW_MARK" "$SANDBOX/README.md" "$SANDBOX/.claude/worktrees"; ui_clean

# =========================================================================
section "post-write.sh — 擴充維護提醒（.claude/ 底下的改動）"
# =========================================================================
#
# 為什麼要這組：改 skill／agent 有三件事會安靜失效（接線沒接上、INDEX 沒同步、
# description 是內容摘要），而使用者不會知道要主動跑稽核。判斷得出時機就由 hook 提出。

# 應命中的五種擴充
for f in ".claude/skills/x/SKILL.md" ".claude/agents/x.md" ".claude/commands/x.md" \
         ".claude/rules/x.md" ".claude/hooks/x.sh"; do
    reset
    expect_contains "擴充提醒認得 $f" "擴充維護提醒" "$(pw "$f")"
done

# 排除：測試與執行時產物（跑測試或寫報告時不該自己觸發自己）
for f in ".claude/hooks/tests/run-tests.sh" ".claude/tests/skill-compliance/README.md" \
         ".claude/context/quality/r.md" ".claude/coordination/handoffs/x.md" \
         ".claude/taskmaster-data/.current-task-mode"; do
    reset
    expect_empty "擴充提醒排除 $f" "$(pw "$f")"
done

# 專案自己的同名目錄不該被誤命中
reset
expect_empty "擴充提醒不誤命中 src/hooks/useAuth.ts" "$(pw "src/hooks/useAuth.ts")"

# 本任務只提醒一次
reset
pw ".claude/skills/x/SKILL.md" >/dev/null
expect_empty "擴充提醒只發一次" "$(pw ".claude/agents/y.md")"

# 逃生門
reset
expect_empty "SKILL_CURATOR_GATE=off 關閉擴充提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/skills/x/SKILL.md")" SKILL_CURATOR_GATE=off)"

# 關掉擴充提醒不該影響文件影響偵測
reset
expect_contains "關掉擴充提醒後文件偵測仍運作" "文件影響提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/src/api/x.ts")" SKILL_CURATOR_GATE=off)"

# 反之：關掉文件偵測不該影響擴充提醒
reset
expect_contains "關掉文件偵測後擴充提醒仍運作" "擴充維護提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/skills/x/SKILL.md")" DOC_SYNC_GATE=off)"

# 變更清單要累積且去重
reset
pw ".claude/skills/a/SKILL.md" >/dev/null
pw ".claude/agents/b.md" >/dev/null
pw ".claude/agents/b.md" >/dev/null
SK_LIST="$SANDBOX/.claude/taskmaster-data/.skill-impact"
if [ "$(wc -l < "$SK_LIST" 2>/dev/null | tr -d ' ')" = "2" ]; then ok "擴充變更清單去重累積"
else ng "擴充變更清單去重累積" "2 行" "$(wc -l < "$SK_LIST" 2>/dev/null | tr -d ' ')"; fi

# WBS 歷史紀錄（原有行為不能被新功能弄壞）
reset
run post-write.sh "$(w "$SANDBOX/.claude/taskmaster-data/wbs.md")" >/dev/null
if [ -f "$SANDBOX/.claude/taskmaster-data/wbs-history.log" ]; then ok "WBS 寫入仍記歷史"
else ng "WBS 寫入仍記歷史" "有 wbs-history.log" "（無）"; fi

# ---- WBS 格子長度提醒 ----
#
# 長度必須以「字」計：一個中文字在 UTF-8 是 3 bytes，用位元組算的話
# 14 個中文字就超標，短格子會被誤報。連結的 `](目標)` 不計入。
WBS_F="$SANDBOX/.claude/taskmaster-data/wbs.md"
wbs_doc() {   # $1 = 13.1 那一列的「狀態」格，$2 = 「連結」格
    printf '%s\n' "# WBS — 測試" "" "## 現況" "" \
        "| 里程碑 | 進度 | 狀態 | 目標日 |" "|---|---|---|---|" "| M1 測試 | ░░░░░ 0/1 | 🔄 進行中 | 11-15 |" "" \
        "## M1 測試" "" \
        "| # | 任務 | 狀態 | 優先 | 依賴 | 預估 | 連結 |" "|---|---|---|---|---|---|---|" \
        "| 13.1 | 地端 rerank 拒答門檻 | $1 | 高 | — | 4h | $2 |" > "$WBS_F"
}
LONG_ZH='✅ 09-23 hit@5 達百分之九十五點八，帶到下一任務的疑慮有三項，選型理由是延遲較低且主機已確認'
SHORT_ZH='進行中，三十個中文字以內的狀態說明大約就是這樣長度而已不會更多了'   # 32 字、96 bytes
LONG_LINK='[計畫](plans/archive/13.1-a-very-long-plan-slug-that-goes-on-and-on-and-on.md) ・ [報告](../context/test/2026-09-23-evaluation-report-with-a-really-long-name.md)'

reset; wbs_doc "$LONG_ZH" "—"
WBS_OUT=$(run post-write.sh "$(w "$WBS_F")")
expect_contains "WBS 中文超長格子會提醒"       "WBS 格子太長"   "$WBS_OUT"
expect_contains "WBS 提醒指出任務編號與欄位"   "13.1 的「狀態」" "$WBS_OUT"
expect_contains "WBS 提醒附長內容去處"         "執行帳本"       "$WBS_OUT"
expect_contains "WBS 提醒：疑慮的去處是「發現與決策」" "「發現與決策」或該階段的「注意」" "$WBS_OUT"
expect_not_contains "WBS 提醒不再指向舊 plan 的「風險與緩解」" "風險與緩解" "$WBS_OUT"

reset; wbs_doc "$SHORT_ZH" "—"
expect_empty "WBS 短中文格子不提醒（以字計、非位元組）" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc "🔄 進行中" "$LONG_LINK"
expect_empty "WBS 長連結網址不誤報" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc "🔄 進行中" "—"
sed -i "s/| 地端 rerank 拒答門檻 |/| ${LONG_ZH} |/" "$WBS_F"
expect_empty "WBS 任務欄寫完整名稱不提醒" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc "$LONG_ZH" "—"
expect_empty "WBS 長度提醒逃生門 WBS_CELL_CHECK=off" "$(run post-write.sh "$(w "$WBS_F")" WBS_CELL_CHECK=off)"
if [ -f "$SANDBOX/.claude/taskmaster-data/wbs-history.log" ]; then ok "WBS 長度提醒關閉時仍記歷史"
else ng "WBS 長度提醒關閉時仍記歷史" "有 wbs-history.log" "（無）"; fi

# 8 欄版面（預估與連結之間有「負責」）：欄名依表頭取，不能依位置
wbs_doc8() {   # $1 = 「狀態」格，$2 = 「負責」格，$3 = 「連結」格
    printf '%s\n' "# WBS — 測試" "" "## 現況" "" \
        "| 里程碑 | 進度 | 狀態 | 目標日 |" "|---|---|---|---|" "| M1 測試 | ░░░░░ 0/1 | 🔄 進行中 | 11-15 |" "" \
        "## M1 測試" "" \
        "| # | 任務 | 狀態 | 優先 | 依賴 | 預估 | 負責 | 連結 |" "|---|---|---|---|---|---|---|---|" \
        "| 13.1 | 地端 rerank 拒答門檻 | $1 | 高 | — | 4h | $2 | $3 |" > "$WBS_F"
}

reset; wbs_doc8 "🔄 進行中" "$LONG_ZH" "—"
WBS_OUT=$(run post-write.sh "$(w "$WBS_F")")
expect_contains     "WBS 8 欄：超長負責格標「負責」"     "13.1 的「負責」" "$WBS_OUT"
expect_not_contains "WBS 8 欄：超長負責格不誤標成「連結」" "13.1 的「連結」" "$WBS_OUT"

reset; wbs_doc8 "🔄 進行中" "alice" "—"
expect_empty "WBS 8 欄：短負責格不提醒" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc8 "$LONG_ZH" "alice" "—"
expect_contains "WBS 8 欄：超長狀態格仍標「狀態」" "13.1 的「狀態」" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc8 "🔄 進行中" "alice" "$LONG_LINK"
expect_empty "WBS 8 欄：長連結網址不誤報" "$(run post-write.sh "$(w "$WBS_F")")"

# 舊版面（沒有「現況」區）要順帶指向 /task-status 的轉換
reset
printf '%s\n' "# WBS" "| # | 任務 | 狀態 | 優先級 | 依賴 | 預估 | Plan | 備註 |" "|---|---|---|---|---|---|---|---|" \
    "| 2.1 | 架構 | $LONG_ZH | 高 | - | 2h | - | |" > "$WBS_F"
expect_contains "WBS 舊版面提醒指向 /task-status 轉換" "/task-status" "$(run post-write.sh "$(w "$WBS_F")")"

# ---- hook 語法檢查 ----
#
# 把 hook 改壞的當下沒有任何人告訴你（PostToolUse 不會抱怨），要等下一條指令
# 噴 syntax error 才發現——而改 hook 在這個 repo 是日常。只出聲不擋。
reset; mkdir -p "$SANDBOX/.claude/hooks"
printf 'if true; then\n  echo hi\n' > "$SANDBOX/.claude/hooks/broken.sh"   # 少一個 fi
expect_contains "改壞 hook 會當場報語法錯誤" "語法錯誤" "$(pw ".claude/hooks/broken.sh")"

# 沒壞就完全不出聲，否則每次改 hook 都被洗版
# （關掉擴充提醒以隔離受測對象——它本來就會對 .claude/hooks/* 出聲）
reset; mkdir -p "$SANDBOX/.claude/hooks"
printf 'if true; then\n  echo hi\nfi\n' > "$SANDBOX/.claude/hooks/ok.sh"
expect_empty "語法正常的 hook 不出聲" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/hooks/ok.sh")" SKILL_CURATOR_GATE=off)"

# =========================================================================
section "user-prompt-submit.sh — planner / architect 路由"
# =========================================================================
reset; echo "# WBS" > "$SANDBOX/.claude/taskmaster-data/wbs.md"
expect_contains "新功能／CR → planner"  'subagent_type: "planner"' \
    "$(run user-prompt-submit.sh "$(p '客戶提了新的 CR，要加一個對帳 API')")"
expect_contains "新功能提醒文件同步"    "必須同步文件" \
    "$(run user-prompt-submit.sh "$(p '我要新增一個匯出報表的功能')")"
reset
expect_contains "技術選型 → architect"  'subagent_type: "architect"' \
    "$(run user-prompt-submit.sh "$(p '這次的技術選型要決定')")"

# =========================================================================
section "報告稽核 — 非同步延後檢查"
# =========================================================================
EXPECT_FILE="$SANDBOX/.claude/taskmaster-data/.report-expectations.jsonl"
CHECKER="$HOOK_DIR/lib/check-report-expectations.sh"

# Agent payload：$1=agent 名稱，$2=async|sync
ag() {
    if [ "$2" = "async" ]; then
        jq -nc --arg a "$1" '{tool_name:"Agent", tool_input:{subagent_type:$a},
            tool_response:{response:"{\"isAsync\": true, \"status\": \"async_launched\"}"}}'
    else
        jq -nc --arg a "$1" '{tool_name:"Agent", tool_input:{subagent_type:$a},
            tool_response:"完成"}'
    fi
}
# 把期望的 epoch 往回推 N 秒，模擬時間流逝
age_expectations() {
    jq -c --argjson n "$1" '.epoch -= $n' "$EXPECT_FILE" > "$EXPECT_FILE.t" \
        && mv -f "$EXPECT_FILE.t" "$EXPECT_FILE"
}

reset; mkdir -p "$SANDBOX/.claude/context/quality"
out=$(run post-agent-report.sh "$(ag code-quality-specialist async)")
expect_empty   "非同步啟動當下不誤報"            "$out"
if [ -s "$EXPECT_FILE" ]; then ok "非同步啟動會記下報告期望"
else ng "非同步啟動會記下報告期望" "期望檔非空" "（空）"; fi
expect_contains "log 記 DEFER 而非 WARN"  "DEFER" \
    "$(cat "$SANDBOX/.claude/logs/context-reports.log" 2>/dev/null)"

expect_empty   "寬限期內（<120s）完全安靜"       "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

age_expectations 300
expect_contains "過寬限期且缺報告 → 要求補寫"    "code-quality-specialist" \
    "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"
expect_empty   "已通知過不重複吵（notified=1）"  "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
echo "# 報告" > "$SANDBOX/.claude/context/quality/code-quality-specialist-2026-09-07-1000.md"
expect_empty   "報告已寫 → 不再要求"             "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"
if [ ! -s "$EXPECT_FILE" ]; then ok "報告已寫 → 期望被清除"
else ng "報告已寫 → 期望被清除" "期望檔為空" "$(cat "$EXPECT_FILE")"; fi

# 舊報告（啟動前就存在）不該被誤認成這次的產出 —— 靠 -newermt 而非 -mmin
reset; mkdir -p "$SANDBOX/.claude/context/quality"
echo "# 舊報告" > "$SANDBOX/.claude/context/quality/code-quality-specialist-2026-01-01-0000.md"
touch -d '2026-01-01' "$SANDBOX/.claude/context/quality/code-quality-specialist-2026-01-01-0000.md" 2>/dev/null
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
expect_contains "啟動前的舊報告不算數"           "code-quality-specialist" \
    "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

# 超過 deadline → 放棄追蹤，不再吵
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 99999
expect_empty   "逾 deadline 放棄追蹤"            "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

# 逃生門
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
expect_empty   "REPORT_AUDIT=off 關閉稽核" \
    "$(REPORT_AUDIT=off bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

# 同步完成的 agent 仍走當下稽核（沿用舊行為）
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist sync)" >/dev/null
if [ ! -s "$EXPECT_FILE" ]; then ok "同步 agent 不記期望（當下稽核）"
else ng "同步 agent 不記期望（當下稽核）" "期望檔為空" "$(cat "$EXPECT_FILE")"; fi
expect_contains "同步且缺報告 → log 記 WARN"     "WARN" \
    "$(cat "$SANDBOX/.claude/logs/context-reports.log" 2>/dev/null)"

# debug-investigator 曾經不在 AREA 映射裡 → 完全不稽核
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag debug-investigator async)" >/dev/null
if [ -s "$EXPECT_FILE" ]; then ok "debug-investigator 已納入稽核"
else ng "debug-investigator 已納入稽核" "期望檔非空" "（空）"; fi

# 但 quick 模式下它依定義不寫報告（agents/debug-investigator.md 模式表）→ 不能記成缺報告
CR_LOG="$SANDBOX/.claude/logs/context-reports.log"
reset; mkdir -p "$SANDBOX/.claude/context/quality"; echo quick > "$MODE_FILE"
run post-agent-report.sh "$(ag debug-investigator sync)" >/dev/null
if grep -q 'WARN: debug-investigator' "$CR_LOG" 2>/dev/null; then
    ng "quick 模式同步派 debug-investigator 不記 WARN" "無 WARN" "$(cat "$CR_LOG")"
else ok "quick 模式同步派 debug-investigator 不記 WARN"; fi
expect_contains "quick 模式記 SKIP 一行" "SKIP: debug-investigator quick 模式不寫報告" \
    "$(cat "$CR_LOG" 2>/dev/null)"

reset; mkdir -p "$SANDBOX/.claude/context/quality"; echo quick > "$MODE_FILE"
run post-agent-report.sh "$(ag debug-investigator async)" >/dev/null
if grep -q '"agent":"debug-investigator"' "$EXPECT_FILE" 2>/dev/null; then
    ng "quick 模式非同步派 debug-investigator 不記期望" "無該列" "$(cat "$EXPECT_FILE")"
else ok "quick 模式非同步派 debug-investigator 不記期望"; fi

reset; mkdir -p "$SANDBOX/.claude/context/quality"; echo standard > "$MODE_FILE"
run post-agent-report.sh "$(ag debug-investigator sync)" >/dev/null
expect_contains "standard 模式缺報告仍記 WARN" "WARN: debug-investigator completed but no report" \
    "$(cat "$CR_LOG" 2>/dev/null)"

# skill-curator 同一個坑：它寫報告到 context/decisions/，但 AREA 映射沒它，
# 稽核永遠找不到那份報告（CLAUDE.md 的「連帶檢查」明文警告過這一條）
reset; mkdir -p "$SANDBOX/.claude/context/decisions"
run post-agent-report.sh "$(ag skill-curator async)" >/dev/null
if [ -s "$EXPECT_FILE" ]; then ok "skill-curator 已納入稽核"
else ng "skill-curator 已納入稽核" "期望檔非空" "（空）"; fi
if grep -q '"area":"decisions"' "$EXPECT_FILE" 2>/dev/null; then ok "skill-curator 的 area 是 decisions"
else ng "skill-curator 的 area 是 decisions" '"area":"decisions"' "$(cat "$EXPECT_FILE" 2>/dev/null)"; fi

# conflict-resolver 是刻意不列的那一個：它的 tools 沒有 Write，機制上寫不了報告檔。
# 加進映射會變成每次解衝突都發一次假警報 —— 這個「刻意」需要測試釘住，
# 否則下次有人「補齊漏掉的 agent」時會順手加回去
reset
run post-agent-report.sh "$(ag conflict-resolver async)" >/dev/null
if [ ! -s "$EXPECT_FILE" ]; then ok "conflict-resolver 刻意不稽核（tools 無 Write）"
else ng "conflict-resolver 刻意不稽核（tools 無 Write）" "期望檔為空" "$(cat "$EXPECT_FILE")"; fi

# 稽核訊息會被注入（不只寫 log）—— 這是原本「沒有牙齒」的核心問題
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
inj=$(run post-agent-report.sh "$(ag planner sync)")
if echo "$inj" | jq -e '.hookSpecificOutput.additionalContext | test("沒寫報告")' >/dev/null 2>&1; then
    ok "缺報告會經 additionalContext 注入"
else
    ng "缺報告會經 additionalContext 注入" "含「沒寫報告」的注入" "${inj:0:80}"
fi

# 斜線指令也要收到稽核（使用者下一句常是 /verify）
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
expect_contains "斜線指令仍收到稽核"             "code-quality-specialist" \
    "$(run user-prompt-submit.sh "$(p '/verify')")"

# =========================================================================
section "session-start.sh — 委派指示注入"
# =========================================================================
reset
# 沙箱內備一份 skill：session-start 會讀 $CLAUDE_PROJECT_DIR/.claude/skills/... 注入
mkdir -p "$SANDBOX/.claude/skills/using-taskmaster"
cp "$HOOK_DIR/../skills/using-taskmaster/SKILL.md" \
   "$SANDBOX/.claude/skills/using-taskmaster/SKILL.md" 2>/dev/null || true
sess_out=$(run session-start.sh '{}')
if echo "$sess_out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1; then
    ok "session-start 輸出合法 JSON"
else
    ng "session-start 輸出合法 JSON" "可被 jq 解析的 SessionStart 事件" "${sess_out:0:80}"
fi
sess_ctx=$(echo "$sess_out" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
expect_contains "注入 using-taskmaster 全文"       "using-taskmaster"  "$sess_ctx"
expect_contains "注入含強制委派標記"               "EXTREMELY"         "$sess_ctx"
expect_contains "注入含 documentation-specialist"  "documentation-specialist" "$sess_ctx"
expect_contains "注入含坑目錄指示"                 "context/learned"   "$sess_ctx"

# =========================================================================
section "session-start.sh — jq 最低版本 1.7.1"
# =========================================================================
#
# 假 jq 放 PATH 前面：--version 印指定字串，其餘 exec 真的 jq（hook 其他地方還要用）。
reset
REAL_JQ=$(command -v jq)
FAKE_JQ_DIR="$SANDBOX/fakejq"; mkdir -p "$FAKE_JQ_DIR"
cat > "$FAKE_JQ_DIR/jq" <<FAKE
#!/usr/bin/env bash
[ "\$1" = "--version" ] && { echo "\$FAKE_JQ_VERSION"; exit 0; }
exec "$REAL_JQ" "\$@"
FAKE
chmod +x "$FAKE_JQ_DIR/jq"
jqv_ctx() {
    run session-start.sh '{}' PATH="$FAKE_JQ_DIR:$PATH" FAKE_JQ_VERSION="$1"         | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
JQV_MARK="最低要求 1.7.1"
expect_contains     "jq-1.6 → 警告"                  "$JQV_MARK" "$(jqv_ctx jq-1.6)"
expect_contains     "警告點名實際版本"                "jq-1.6"    "$(jqv_ctx jq-1.6)"
expect_contains     "警告附手動下載連結"              "github.com/jqlang/jq/releases" "$(jqv_ctx jq-1.6)"
expect_contains     "jq-1.7（兩段，第三段當 0）→ 警告" "$JQV_MARK" "$(jqv_ctx jq-1.7)"
expect_not_contains "jq-1.7.1 → 不警告"              "$JQV_MARK" "$(jqv_ctx jq-1.7.1)"
expect_not_contains "jq-1.8.1 → 不警告"              "$JQV_MARK" "$(jqv_ctx jq-1.8.1)"
expect_not_contains "jq-1.7.1-dirty（尾綴）→ 不警告" "$JQV_MARK" "$(jqv_ctx jq-1.7.1-dirty)"
expect_not_contains "jq-garbage（解析不出）→ 不警告" "$JQV_MARK" "$(jqv_ctx jq-garbage)"
run session-start.sh '{}' PATH="$FAKE_JQ_DIR:$PATH" FAKE_JQ_VERSION=jq-1.6 >/dev/null
expect_contains     "警告也寫進 hooks.log"           "$JQV_MARK" "$(cat "$SANDBOX/.claude/logs/hooks.log" 2>/dev/null)"

# =========================================================================
section "session-start.sh — bash 最低版本 4"
# =========================================================================
#
# BASH_VERSINFO 是唯讀的、測試機也找不到 bash 3.2，只能靠 hook 認的 TM_TEST_BASH_VERSION 假裝版本。
reset
bashv_ctx() {
    run session-start.sh '{}' ${1:+TM_TEST_BASH_VERSION="$1"} | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
BASHV_MARK="最低要求 bash 4"
expect_contains     "bash 3.2 → 警告"                "$BASHV_MARK"          "$(bashv_ctx '3.2.57(1)-release')"
expect_contains     "警告點名實際版本"                "3.2.57"               "$(bashv_ctx '3.2.57(1)-release')"
expect_contains     "警告附 macOS 安裝方式"           "brew install bash"    "$(bashv_ctx '3.2.57(1)-release')"
expect_contains     "警告提醒確認 PATH 解析到新版"    "/opt/homebrew/bin/bash" "$(bashv_ctx '3.2.57(1)-release')"
expect_contains     "只警告不擋：後面的注入照常"      "/task-init"           "$(bashv_ctx '3.2.57(1)-release')"
expect_not_contains "bash 4.0 → 不警告"              "$BASHV_MARK"          "$(bashv_ctx '4.0.0(1)-release')"
expect_not_contains "bash 5.2 → 不警告"              "$BASHV_MARK"          "$(bashv_ctx '5.2.37(1)-release')"
expect_not_contains "不注入、用真的 bash（≥4）→ 不警告" "$BASHV_MARK"        "$(bashv_ctx '')"
reset
run session-start.sh '{}' TM_TEST_BASH_VERSION='3.2.57(1)-release' >/dev/null
expect_contains     "警告也寫進 hooks.log"           "$BASHV_MARK"          "$(cat "$SANDBOX/.claude/logs/hooks.log" 2>/dev/null)"

# =========================================================================
section "session-start.sh — 風格庫提醒只在模板 repo 出現"
# =========================================================================
#
# 判斷依據是 scripts/sync-ui-sources.sh 在不在（copy-template 排除整個根目錄 scripts/、update-template 不碰它）。
# 新專案拿到的 .claude/ui/ 是快照、也沒有 taskmaster-data/，以前每個 session 都會被叫去「更新素材庫」。
ss_ctx() { run session-start.sh '{}' | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null; }
days_ago() { jq -nr --argjson d "$1" '(now - $d * 86400) | strftime("%Y-%m-%d")'; }
ss_sources() { # <voltagent 的 last_synced（null 或日期）> —— self-extracted 永遠是 null，不該被算進去
    local v="$1"; [ "$v" = "null" ] || v="\"$v\""
    mkdir -p "$SANDBOX/.claude/ui"
    printf '{"sources":[{"id":"voltagent","repo":"VoltAgent/awesome-design-md","last_synced":%s},{"id":"self-extracted","repo":null,"last_synced":null}]}\n' \
        "$v" > "$SANDBOX/.claude/ui/_sources.json"
}
ss_template() { mkdir -p "$SANDBOX/scripts"; : > "$SANDBOX/scripts/sync-ui-sources.sh"; }
ss_clean() { rm -rf "$SANDBOX/scripts"; }

reset; ss_clean; ss_template; ss_sources "$(days_ago 100)"
out=$(ss_ctx)
expect_contains "模板 repo、上游 100 天沒同步 → 提醒跑同步腳本" "sync-ui-sources.sh" "$out"
expect_contains "提醒寫出是哪個來源"                           "voltagent"          "$out"
expect_not_contains "沒有上游的 self-extracted 不算"           "self-extracted"     "$out"
reset; ss_clean; ss_template; ss_sources null
expect_contains "模板 repo、上游從未同步 → 提醒" "從未同步" "$(ss_ctx)"
reset; ss_clean; ss_template; ss_sources "$(days_ago 10)"
expect_not_contains "上游 10 天前同步過 → 不提醒" "sync-ui-sources.sh" "$(ss_ctx)"
reset; ss_clean; ss_sources "$(days_ago 100)"
expect_not_contains "沒有 sync-ui-sources.sh（不是模板 repo）→ 不提醒同步" "sync-ui-sources.sh" "$(ss_ctx)"

# 既有的「設計走向 90 天」提醒（使用者決定 3：一樣只在模板 repo）
reset; ss_clean; ss_template; ss_sources "$(days_ago 10)"
out=$(ss_ctx)
expect_contains     "模板 repo、從未更新設計走向 → 提醒"       "設計走向"   "$out"
expect_contains     "設計走向提醒指向 anti-ai.md（不是舊的 2.6 節）" "anti-ai.md" "$out"
reset; ss_clean; ss_sources "$(days_ago 10)"
expect_not_contains "不是模板 repo → 不提醒設計走向"           "設計走向"   "$(ss_ctx)"
reset; ss_clean; ss_template; ss_sources "$(days_ago 10)"; : > "$SANDBOX/.claude/taskmaster-data/.ui-catalog-refreshed"
expect_not_contains "模板 repo、設計走向剛更新 → 不提醒"       "設計走向"   "$(ss_ctx)"
reset; ss_clean

# =========================================================================
section "session-start.sh — 初始化狀態只看 project.json"
# =========================================================================
# 舊做法以根目錄 CLAUDE_TEMPLATE.md 當哨兵，但 /task-init 完成時會刪它 →
# 「已初始化且有 WBS」那段永遠走不到；模板 repo 本身也被當成未初始化的專案。
ss_init() { : > "$SANDBOX/.claude/taskmaster-data/project.json"; }
ss_wbs()  { echo "# WBS" > "$SANDBOX/.claude/taskmaster-data/wbs.md"; }
rm -f "$SANDBOX/CLAUDE_TEMPLATE.md"

reset; ss_clean
out=$(ss_ctx)
expect_contains     "沒有 project.json → 提示 /task-init"          "/task-init" "$out"
expect_not_contains "沒有 project.json → 不提 WBS 接續"           "/task-next" "$out"

reset; ss_clean; ss_init; ss_wbs
out=$(ss_ctx)
expect_contains     "有 project.json＋wbs.md、沒有哨兵檔 → 提示 /task-next 接續" "/task-next" "$out"
expect_not_contains "已初始化 → 不再提示 /task-init"                         "/task-init" "$out"

reset; ss_clean; ss_init
out=$(ss_ctx)
expect_not_contains "有 project.json、沒有 wbs.md → 不提 /task-init"  "/task-init" "$out"
expect_not_contains "有 project.json、沒有 wbs.md → 不提 /task-next"  "/task-next" "$out"

# 舊專案 update 前留下的哨兵檔不再有作用：有 WBS 照樣提示接續
reset; ss_clean; ss_init; ss_wbs; : > "$SANDBOX/CLAUDE_TEMPLATE.md"
expect_contains "殘留的 CLAUDE_TEMPLATE.md 不影響 WBS 接續提示" "/task-next" "$(ss_ctx)"
rm -f "$SANDBOX/CLAUDE_TEMPLATE.md"

reset; ss_clean; ss_template
expect_not_contains "模板 repo 本身（沒有 project.json）→ 不提示 /task-init" "/task-init" "$(ss_ctx)"
# 判斷放在 CURATION_REMINDERS 逃生門外：關掉維護提醒不該讓 init 提示冒出來
expect_not_contains "模板 repo、CURATION_REMINDERS=off → 仍不提示 /task-init" "/task-init" \
    "$(run session-start.sh '{}' CURATION_REMINDERS=off | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)"
reset; ss_clean

# 真的用 copy-template.sh 建一個新專案再開 session：上面的沙箱只證明「條件寫對了」，
# 這組證明「新專案真的不滿足那個條件」——排除清單哪天漏了，這裡會紅
NEWPROJ=$(mktemp -d)
bash "$HOOK_DIR/../../scripts/copy-template.sh" "$NEWPROJ/app" >/dev/null 2>&1 </dev/null
if [ -f "$NEWPROJ/app/.claude/ui/_sources.json" ] && [ -d "$NEWPROJ/app/.claude/hooks" ]; then
    ok "copy-template 建出的新專案帶著 .claude/ui/_sources.json（前提成立）"
else
    ng "copy-template 建出的新專案帶著 .claude/ui/_sources.json（前提成立）" "有 _sources.json 與 hooks" "$(ls -A "$NEWPROJ/app/.claude" 2>/dev/null | tr '\n' ' ')"
fi
[ ! -e "$NEWPROJ/app/scripts/sync-ui-sources.sh" ] && ok "新專案沒有 scripts/sync-ui-sources.sh" \
    || ng "新專案沒有 scripts/sync-ui-sources.sh" "不存在" "存在"
# 根目錄 scripts/ 整個不帶（專案有自己的 scripts/），但錨定要對：.claude/scripts/ 必須還在
[ ! -e "$NEWPROJ/app/scripts/check-counts.sh" ] && ok "新專案沒有根目錄 scripts/check-counts.sh" \
    || ng "新專案沒有根目錄 scripts/check-counts.sh" "不存在" "存在"
[ -f "$NEWPROJ/app/.claude/scripts/check-counts.sh" ] && ok "新專案有 .claude/scripts/check-counts.sh（排除沒誤傷 .claude/scripts/）" \
    || ng "新專案有 .claude/scripts/check-counts.sh（排除沒誤傷 .claude/scripts/）" "存在" "不存在"
[ ! -e "$NEWPROJ/app/CLAUDE_TEMPLATE.md" ] && ok "新專案沒有 CLAUDE_TEMPLATE.md（哨兵已廢除）"     || ng "新專案沒有 CLAUDE_TEMPLATE.md（哨兵已廢除）" "不存在" "存在"
# 換成一定過期的來源資料：真實的 _sources.json 哪天全部剛同步過，下面的反向測試就會變成空跑
printf '{"sources":[{"id":"voltagent","repo":"VoltAgent/awesome-design-md","last_synced":null}]}\n' \
    > "$NEWPROJ/app/.claude/ui/_sources.json" 2>/dev/null
np_ctx=$(printf '{}' | env CLAUDE_PROJECT_DIR="$NEWPROJ/app" bash "$NEWPROJ/app/.claude/hooks/session-start.sh" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
expect_contains     "新專案的 session-start 正常注入"          "using-taskmaster"   "$np_ctx"
expect_not_contains "新專案不出現同步提醒"                     "sync-ui-sources.sh" "$np_ctx"
expect_not_contains "新專案不出現設計走向提醒"                 "設計走向"           "$np_ctx"
expect_contains     "新專案（還沒 project.json）出現 /task-init 提示" "/task-init"   "$np_ctx"
mkdir -p "$NEWPROJ/app/scripts" && : > "$NEWPROJ/app/scripts/sync-ui-sources.sh"
np_ctx=$(printf '{}' | env CLAUDE_PROJECT_DIR="$NEWPROJ/app" bash "$NEWPROJ/app/.claude/hooks/session-start.sh" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
expect_contains "對照組：同一個新專案補上那支腳本 → 提醒出現（證明上面不是空跑）" "sync-ui-sources.sh" "$np_ctx"
expect_not_contains "對照組：補上那支腳本就判成模板 repo → /task-init 提示消失" "/task-init" "$np_ctx"
rm -rf "$NEWPROJ"

# =========================================================================
section "worktree 感知 — 狀態隔離邊界"
# =========================================================================
# 官方：「Hook paths don't follow the worktree. ${CLAUDE_PROJECT_DIR} stays put;
# the cwd field in the hook's input JSON is the worktree root.」
# 所以短命旗標必須跟著 worktree，共享產物必須留在主 checkout。

# 在沙箱裡造一個真的 linked worktree
WT_SEQ=0
setup_worktree() {
    reset
    # reset 刪掉 .claude（含 worktree 目錄）但 git 仍記著它 → 先 prune，
    # 並用遞增名稱避免分支重複
    ( cd "$SANDBOX" && git -c init.defaultBranch=main init -q . 2>/dev/null       && echo x > seed && git add seed       && git -c user.email=t@t -c user.name=t commit -qm init       && git worktree prune ) >/dev/null 2>&1
    WT_SEQ=$((WT_SEQ + 1))
    WT="$SANDBOX/.claude/worktrees/wt$WT_SEQ"
    ( cd "$SANDBOX" && git worktree add -q "$WT" -b "wt$WT_SEQ" ) >/dev/null 2>&1
    mkdir -p "$WT/.claude/taskmaster-data" "$WT/src/deep" "$WT/src/api" 2>/dev/null
}
# payload 帶 cwd（模擬 worktree session）
wcwd() { jq -nc --arg f "$1" --arg c "$2" \
    '{tool_name:"Write", tool_input:{file_path:$f}, cwd:$c}'; }

setup_worktree
if [ -f "$WT/.git" ]; then ok "沙箱能建出 linked worktree（.git 是檔案）"
else ng "沙箱能建出 linked worktree（.git 是檔案）" ".git 為檔案" "不是"; fi

# 主 checkout 有模式檔、worktree 沒有 → 在 worktree 裡應該被擋
echo standard > "$MODE_FILE"
expect_decision "worktree 不吃主 checkout 的模式檔" deny \
    "$(run pre-tool-use.sh "$(wcwd "$WT/src/a.ts" "$WT")")"
expect_decision "同一時間主 checkout 仍放行" allow \
    "$(run pre-tool-use.sh "$(wcwd "$SANDBOX/src/a.ts" "$SANDBOX")")"

# worktree 自己的模式檔才算
echo quick > "$WT/.claude/taskmaster-data/.current-task-mode"
expect_decision "worktree 有自己的模式檔就放行" allow \
    "$(run pre-tool-use.sh "$(wcwd "$WT/src/a.ts" "$WT")")"

# cwd 是 worktree 子目錄（Claude 跑過 cd）也要認得
expect_decision "cwd 為子目錄仍解析到 worktree 根" allow \
    "$(run pre-tool-use.sh "$(wcwd "$WT/src/a.ts" "$WT/src/deep")")"

# log 集中在主 checkout，[wt] 是唯一分得出來源的標記：IN_WORKTREE 一定是 0 或 1，不能用「有沒有值」判斷
run pre-tool-use.sh "$(wcwd "$SANDBOX/src/a.ts" "$SANDBOX")" >/dev/null
expect_eq "主 checkout 的 log 行不帶 [wt]" "pre-tool:" \
    "$(grep -o 'pre-tool[^ ]*' "$SANDBOX/.claude/logs/hooks.log" 2>/dev/null | tail -1)"
run pre-tool-use.sh "$(wcwd "$WT/src/a.ts" "$WT")" >/dev/null
expect_eq "worktree 的 log 行帶 [wt]" "pre-tool[wt]:" \
    "$(grep -o 'pre-tool[^ ]*' "$SANDBOX/.claude/logs/hooks.log" 2>/dev/null | tail -1)"

# 坑紀錄是共享的：只放在主 checkout 也要在 worktree 生效
setup_worktree
echo standard > "$WT/.claude/taskmaster-data/.current-task-mode"
mkdir -p "$SANDBOX/.claude/context/learned"
printf -- '---\ndate: 2026-09-07\ntitle: 共享的坑\nfiles:\n  - "src/*.ts"\nsymptom: s\nroot-cause: r\nguard: g\n---\n' \
    > "$SANDBOX/.claude/context/learned/shared.md"
out=$(run pre-tool-use.sh "$(wcwd "$WT/src/a.ts" "$WT")")
expect_decision "主 checkout 的坑在 worktree 也會擋"  deny "$out"
expect_contains "且貼出的是共享那筆"  "共享的坑" "$out"

# .doc-impact 跟著 worktree
setup_worktree
run post-write.sh "$(wcwd "$WT/src/api/x.ts" "$WT")" >/dev/null
if [ -f "$WT/.claude/taskmaster-data/.doc-impact" ]; then ok "doc-impact 寫進 worktree"
else ng "doc-impact 寫進 worktree" "worktree 有 .doc-impact" "沒有"; fi
if [ ! -f "$SANDBOX/.claude/taskmaster-data/.doc-impact" ]; then ok "doc-impact 沒污染主 checkout"
else ng "doc-impact 沒污染主 checkout" "主 checkout 無此檔" "有"; fi

# 非 worktree 情境（無 cwd 欄位）行為不變
reset
expect_decision "無 cwd 欄位時沿用舊行為（被擋）" deny \
    "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

# =========================================================================
section "整套測試閘門 — worktree 裡沒帶路徑的 pytest／vitest／jest 擋一次"
# =========================================================================
# 事故（2026-11-02，另一個專案）：4 條平行線每輪都跑整套 tests/unit（約 1.5 萬條、
# 20～40 分鐘）。「只跑相關測試」原本只是 testing-standards 的文字規則。
# 現在由 lib/full-suite-gate.sh 強制：只在 worktree、deny-once（消耗性）、
# `# full-suite` 註解是 /deps、/refactor-clean 的合法出口（worktree 裡的 /verify 不跑整套）。

setup_worktree
FS_FLAG="$WT/.claude/taskmaster-data/.full-suite-warned"
# fs <指令> [cwd] [ENV=VAL ...] —— 預設 cwd 是 worktree
fs() {
    local c="$1" cwd="${2:-$WT}"; shift; [ $# -gt 0 ] && shift
    run pre-tool-use.sh "$(jq -nc --arg c "$c" --arg cwd "$cwd" '{tool_name:"Bash",tool_input:{command:$c},cwd:$cwd}')" "$@"
}
# fs1：每次先清掉 deny-once 標記，測「第一次會不會擋」
fs1() { rm -f "$FS_FLAG"; fs "$@"; }
fs_msg() { fs1 "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason'; }

# ---- 要擋：沒帶路徑也沒篩選
expect_decision "uv run pytest -q → 擋"                     deny  "$(fs1 'uv run pytest -q')"
expect_decision "pytest（裸跑）→ 擋"                        deny  "$(fs1 'pytest')"
expect_decision "python -m pytest → 擋"                     deny  "$(fs1 'python -m pytest -q')"
expect_decision "tests/unit 整個測試根（事故原型）→ 擋"     deny  "$(fs1 'uv run pytest tests/unit -q 2>&1 | tail -40')"
expect_decision "tests/ 整個測試根 → 擋"                    deny  "$(fs1 'uv run pytest tests/ -q')"
expect_decision "vitest run → 擋"                           deny  "$(fs1 'npx vitest run')"
expect_decision "jest --coverage → 擋"                      deny  "$(fs1 'npx jest --coverage')"
expect_decision "npm test → 擋"                             deny  "$(fs1 'npm test')"
expect_decision "pnpm run test → 擋"                        deny  "$(fs1 'pnpm run test')"
expect_decision "bun test → 擋"                             deny  "$(fs1 'bun test')"
expect_decision "串在 cd … && 後面也認得"                   deny  "$(fs1 'cd sub && uv run pytest')"
expect_decision "timeout／環境變數前綴也認得"               deny  "$(fs1 'CI=1 timeout 600 uv run pytest -q')"
expect_decision "--cov 的值不當成測試路徑"                  deny  "$(fs1 'uv run pytest --cov src -q')"
expect_decision "重導向的檔名不當成測試路徑"                deny  "$(fs1 'uv run pytest -q > out.txt')"
expect_decision "PowerShell 工具也擋"                       deny \
    "$(rm -f "$FS_FLAG"; run pre-tool-use.sh "$(jq -nc --arg cwd "$WT" '{tool_name:"PowerShell",tool_input:{command:"uv run pytest -q"},cwd:$cwd}')")"

FS_MSG=$(fs_msg 'uv run pytest -q')
expect_contains "訊息講為什麼擋（平行搶資源）"              "N 份整套"                                  "$FS_MSG"
expect_contains "訊息附帶路徑的指令範例"                    "uv run pytest tests/test_order.py -q"     "$FS_MSG"
expect_contains "訊息指向 testing-standards 的完整路徑"     ".claude/skills/testing-standards/SKILL.md" "$FS_MSG"
expect_contains "訊息給出 /deps 等的合法出口"               "# full-suite"                              "$FS_MSG"
# worktree 裡的 /verify 不跑整套（commands/verify.md 步驟 4），訊息不能再把它列成合法出口
expect_not_contains "訊息不再把 /verify 列為整套出口"       '`/verify`、`/deps`'                        "$FS_MSG"
expect_contains "訊息把「何時跑整套」指向 verify.md"       "什麼時候跑整套見 \`commands/verify.md\` 步驟 4" "$FS_MSG"
expect_contains "訊息寫出逃生門"                            "FULL_SUITE_GATE=off"                       "$FS_MSG"
expect_contains "vitest 給 vitest 的範例"                   "vitest run src/order/refund.test.ts"       "$(fs_msg 'npx vitest run')"

# ---- 放行：帶了路徑或篩選
expect_decision "帶測試檔 → 放行"                           allow "$(fs1 'uv run pytest tests/test_order.py -q')"
expect_decision "帶 :: 節點 → 放行"                         allow "$(fs1 'uv run pytest tests/test_order.py::test_refund')"
expect_decision "帶 -k → 放行"                              allow "$(fs1 'uv run pytest -k refund -q')"
expect_decision "範圍夠窄的目錄 → 放行"                     allow "$(fs1 'uv run pytest tests/order/ -q')"
expect_decision "vitest 帶檔名 → 放行"                      allow "$(fs1 'pnpm vitest run src/order/a.test.ts')"
expect_decision "jest -t → 放行"                            allow "$(fs1 'npx jest -t "refund"')"
expect_decision "npm test -- <檔> → 放行"                   allow "$(fs1 'npm test -- src/a.test.ts')"
expect_decision "--collect-only 不是在跑測試 → 放行"        allow "$(fs1 'uv run pytest --collect-only -q')"
expect_decision "npm run build 不是測試 → 放行"             allow "$(fs1 'npm run build')"

# ---- 不誤擋：flock／heredoc／引號內文提到 pytest
expect_decision "flock -c \"…pytest\"（引號內）→ 放行"      allow "$(fs1 'flock -s /tmp/db.lock -c "uv run pytest"')"
expect_decision "flock 包住的 pytest → 放行（有意的漏網）"  allow "$(fs1 'flock /tmp/db.lock uv run pytest')"
expect_decision "heredoc 內文的 pytest → 放行"              allow "$(fs1 'cat > notes.md <<EOF
uv run pytest -q
npm test
EOF')"
expect_decision "commit 訊息提到 pytest → 放行"             allow "$(fs1 'git commit -m "test: uv run pytest 只跑相關檔"')"
expect_decision "echo pytest → 放行"                        allow "$(fs1 'echo pytest')"
[ -f "$FS_FLAG" ] && ng "放行的指令不寫標記" "無 .full-suite-warned" "有" || ok "放行的指令不寫標記"

# ---- 本模板自己的 hook 測試：整套在 Windows 上約 50 分鐘，worktree 裡不帶參數就擋
expect_decision "run-tests.sh 不帶參數 → 擋"                deny  "$(fs1 'bash .claude/hooks/tests/run-tests.sh')"
expect_decision "run-tests.sh 接管線也擋"                   deny  "$(fs1 'bash .claude/hooks/tests/run-tests.sh 2>&1 | tail -5')"
expect_decision "直接執行 ./…/run-tests.sh 也擋"            deny  "$(fs1 './.claude/hooks/tests/run-tests.sh')"
expect_decision "run-tests.sh --changed <起點> → 放行"      allow "$(fs1 'bash .claude/hooks/tests/run-tests.sh --changed main')"
expect_decision "run-tests.sh <節關鍵字> → 放行"            allow "$(fs1 'bash .claude/hooks/tests/run-tests.sh overview')"
expect_decision "run-tests.sh # full-suite → 放行"          allow "$(fs1 'bash .claude/hooks/tests/run-tests.sh  # full-suite')"
expect_decision "專案自己的 scripts/run-tests.sh 不管"      allow "$(fs1 'bash scripts/run-tests.sh')"
expect_decision "run-tests.sh --full → 擋（它就是整套）"   deny  "$(fs1 'bash .claude/hooks/tests/run-tests.sh --changed main --full')"
expect_decision "bash -x run-tests.sh → 擋"                 deny  "$(fs1 'bash -x .claude/hooks/tests/run-tests.sh')"
expect_decision "nohup bash run-tests.sh … & → 擋"          deny  "$(fs1 'nohup bash .claude/hooks/tests/run-tests.sh > /tmp/t.log 2>&1 &')"
expect_decision "引號包住的 run-tests.sh 路徑 → 擋"         deny  "$(fs1 'bash ".claude/hooks/tests/run-tests.sh"')"
expect_decision "引號包住的路徑＋節關鍵字 → 放行"           allow "$(fs1 'bash ".claude/hooks/tests/run-tests.sh" overview')"
expect_contains "run-tests.sh 的訊息給依改動挑節的範例"     "run-tests.sh --changed <起點>" "$(fs_msg 'bash .claude/hooks/tests/run-tests.sh')"

# ---- deny-once（消耗性）
rm -f "$FS_FLAG"
expect_decision "deny-once：第一次擋"                       deny  "$(fs 'uv run pytest -q')"
[ -f "$FS_FLAG" ] && ok "deny-once 標記寫在 worktree 的 taskmaster-data" || ng "deny-once 標記寫在 worktree 的 taskmaster-data" "$FS_FLAG 存在" "不存在"
[ -f "$SANDBOX/.claude/taskmaster-data/.full-suite-warned" ] && ng "標記沒污染主 checkout" "主 checkout 無此檔" "有" || ok "標記沒污染主 checkout"
expect_decision "deny-once：換一條整套 → 仍擋"              deny  "$(fs 'uv run pytest')"
expect_decision "deny-once：同一條重試 → 放行"              allow "$(fs 'uv run pytest')"
[ -f "$FS_FLAG" ] && ng "放行後清掉標記" "標記已刪" "還在" || ok "放行後清掉標記"
expect_decision "deny-once：下一輪同一條整套再擋一次"       deny  "$(fs 'uv run pytest')"
rm -f "$FS_FLAG"
expect_decision "多行指令也能重試放行（第一次）"            deny  "$(fs 'uv run pytest -q
echo done')"
expect_decision "多行指令也能重試放行（重試）"              allow "$(fs 'uv run pytest -q
echo done')"

# ---- 合法出口與逃生門
expect_decision "# full-suite 註解 → 放行（/deps 等）"      allow "$(fs1 'uv run pytest -q  # full-suite')"
expect_decision "# full-suite: 說明 → 放行"                 allow "$(fs1 'npm test  # full-suite: /deps 基準')"
[ -f "$FS_FLAG" ] && ng "# full-suite 不寫標記" "無標記" "有" || ok "# full-suite 不寫標記"
expect_decision "# full-suite-x 不算宣告 → 擋"              deny  "$(fs1 'uv run pytest -q  # full-suite-x')"
expect_decision "FULL_SUITE_GATE=off → 放行"                allow "$(rm -f "$FS_FLAG"; fs 'uv run pytest -q' "$WT" FULL_SUITE_GATE=off)"
expect_decision "TASKMODE_GATE=off 一併關掉 → 放行"         allow "$(rm -f "$FS_FLAG"; fs 'uv run pytest -q' "$WT" TASKMODE_GATE=off)"

# ---- 主 checkout 不擋（事故成本來自平行；主 checkout 是 /verify 跑整套的地方）
expect_decision "主 checkout：uv run pytest -q → 放行"      allow "$(fs 'uv run pytest -q' "$SANDBOX")"
expect_decision "主 checkout：npm test → 放行"              allow "$(fs 'npm test' "$SANDBOX")"
expect_decision "沒有 cwd 欄位 → 放行"                      allow "$(run pre-tool-use.sh "$(b 'uv run pytest -q')")"
expect_decision "worktree 子目錄也認得是 worktree"          deny  "$(fs1 'uv run pytest -q' "$WT/src/deep")"
reset

# =========================================================================
section "run-tests.sh 選節 — 關鍵字、依改動挑節、跳過的節只取定義"
# =========================================================================
# 對應表（_changed_rule）是 /verify 依改動挑節的唯一來源，挑錯的方向是「該跑的沒跑」——
# 靜默的那種。這裡釘住每一類規則。
#
# hook 檔名刻意拆成兩段字串（"post-""write.sh"）：依改動挑節會選上「內文提到那支 hook」的節，
# 本節若照寫檔名，改那支 hook 時本節也會被挑進去，而「沒有節提到」那條案例會永遠不成立。
RT="$HOOK_DIR/tests/run-tests.sh"
sel() { printf '%s\n' "$1" | bash "$RT" --changed - --dry-run 2>&1; }

expect_contains "只改文件／範本 → 不跑 hook 測試" "不跑" \
    "$(sel $'README.md\ndocs/a.md\n.claude/commands/verify.md\n.claude/templates/wbs.template.md\n.claude/ui/x/DESIGN.md')"
SEL_PW=$(sel ".claude/hooks/post-""write.sh")
expect_contains "改一支 hook → 部分執行"               "部分執行"                    "$SEL_PW"
expect_contains "改一支 hook → 挑到標題是它的節"       "post-""write.sh — 文件影響偵測" "$SEL_PW"
expect_contains "改一支 hook → 挑到只在內文提到它的節" "worktree 感知 — 狀態隔離邊界" "$SEL_PW"
expect_contains "改一支 hook → 附帶全體 hooks 語法檢查" "全體 hooks — 語法與健壯性"   "$SEL_PW"
expect_not_contains "改一支 hook → 不挑沒提到它的節"   "合併閘門 — 合併未驗證前"     "$SEL_PW"
expect_contains "overview 的畫面範本 → 挑 overview 那節" "專案地圖" "$(sel .claude/templates/overview/index.html)"
expect_contains "會被讀進沙箱的 .md 排在 *.md 規則之前" "session-""start.sh — 委派指示注入" \
    "$(sel ".claude/skills/using-""taskmaster/SKILL.md")"
expect_contains "hooks/lib/ 共用程式 → 整套"            "→ 整套" "$(sel .claude/hooks/lib/cmd-segments.sh)"
expect_contains "run-tests.sh 本身、清單從 stdin 來 → 整套" "沒有起點可比行號" "$(sel .claude/hooks/tests/run-tests.sh)"
expect_contains "settings.json → 整套"                  "→ 整套" "$(sel .claude/settings.json)"
expect_contains "對應不到規則的檔 → 整套（保守）"       "→ 整套" "$(sel $'docs/a.md\n.gitattributes')"
expect_contains "沒有節提到的 hook → 只跑語法檢查"      "只跑語法檢查" "$(sel ".claude/hooks/zz-no""body.sh")"
expect_contains "改動清單是空的 → 不跑"                 "沒有改動檔"   "$(printf '' | bash "$RT" --changed - --dry-run 2>&1)"
expect_contains "起點取不到 → 整套"                     "取不到改動清單" "$(bash "$RT" --changed zz-no-such-ref --dry-run 2>&1)"
expect_contains "關鍵字選節 → 寫明部分執行節數"         "部分執行：1 節" "$(bash "$RT" '裸 cd' --dry-run 2>&1)"
bash "$RT" zz-no-such-title --dry-run >/dev/null 2>&1
expect_eq "關鍵字一節都對不到 → exit 2（不默默跑 0 節）" 2 "$?"
expect_eq "--list 列出每一節" "$(grep -c '^section "' "$RT")" "$(bash "$RT" --list 2>/dev/null | grep -c .)"

# 跳過的節只取定義：用一支迷你測試檔（本檔的框架＋四節）驗。
# 節的內容用 printf 寫，不用 heredoc——heredoc 內行首的 section 會被本檔的切節當成真的節
RT_FAKE="$SANDBOX/rtfake/tests/run-tests.sh"
RT_PROBE="$SANDBOX/rtprobe"
mkdir -p "${RT_FAKE%/*}" "$RT_PROBE"
{ sed '/^section "/,$d' "$RT"
  printf '%s\n' \
    'section "甲 — 定義"' \
    '# 甲-mark' \
    'helper_a() { echo A; }' \
    'VAR_A="va"' \
    'HOIST_X=1 touch "$RT_PROBE/prefix-ran"' \
    'VAR_B=$(touch "$RT_PROBE/subst-ran"; echo b)' \
    'ok "甲"' \
    'section "乙 — 使用"' \
    '[ "$(helper_a 2>&1)" = A ] && ok "函式" || ng "函式" A "$(helper_a 2>&1)"' \
    '[ "${VAR_A:-}" = va ] && ok "變數" || ng "變數" va "${VAR_A:-}"' \
    '[ -z "${HOIST_X:-}" ] && ok "前綴指派不留下" || ng "前綴指派不留下" 空 "$HOIST_X"' \
    'section "丙 — 獨立"' \
    '# 丙-mark' \
    'ok "丙"' \
    'section "全體 hooks — 假"' \
    'ok "全體"' \
    'finish_tests'
} > "$RT_FAKE"
RT_OUT=$(RT_PROBE="$RT_PROBE" bash "$RT_FAKE" 乙 2>&1)
expect_contains "跳過的節：後面的節拿得到它的函式與變數" "通過數 3 ・ 失敗數 0" "$RT_OUT"
expect_contains "部分執行的結尾寫明節數"                 "部分執行（1 節／共 4 節" "$RT_OUT"
printf '%s' "$RT_OUT" | grep -qE '通過 [0-9]' && ng "部分執行的結尾抓不到「通過 N」" "抓不到" "抓得到" \
    || ok "部分執行的結尾抓不到「通過 N」（CI／check-counts 的 regex 不會誤讀）"
[ -e "$RT_PROBE/prefix-ran" ] && ng "跳過的節：前綴指派的指令沒執行" "沒執行" "執行了" || ok "跳過的節：前綴指派的指令沒執行"
[ -e "$RT_PROBE/subst-ran" ]  && ng "跳過的節：指派裡的 \$( ) 沒執行"  "沒執行" "執行了" || ok "跳過的節：指派裡的 \$( ) 沒執行"
RT_OUT=$(RT_PROBE="$RT_PROBE" bash "$RT_FAKE" 2>&1)
expect_contains "不帶參數照舊跑整套"                     "通過 6 ・ 失敗 0" "$RT_OUT"
expect_not_contains "整套的結尾不寫部分執行"             "部分執行"         "$RT_OUT"

# 改到本檔：用 git diff -U0 的行號只挑改到的節。迷你測試檔放進一個真的 repo
RG="$SANDBOX/rtrepo"; RGF="$RG/.claude/hooks/tests/run-tests.sh"; RGW="$SANDBOX/rtwt"
rgq() { git -C "$RG" -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@" >/dev/null 2>&1; }
rg_sel() { bash "$RGF" --changed HEAD --dry-run 2>&1; }
rg_edit() { sed -i "s/$1/$1 x/" "$RGF"; }   # 改一行
rg_undo() { rgq checkout -- .claude/hooks/tests/run-tests.sh; }
mkdir -p "${RGF%/*}"; cp "$RT_FAKE" "$RGF"
rgq init -q; rgq add -A; rgq commit -qm init
rg_edit '# 丙-mark'; RT_OUT=$(rg_sel); rg_undo
expect_contains "改到本檔某一節 → 只挑那一節"            "改到「丙 — 獨立」" "$RT_OUT"
expect_contains "改到本檔某一節 → 部分執行"              "部分執行"           "$RT_OUT"
expect_not_contains "改到本檔某一節 → 不挑別的節"        "乙 — 使用"          "$RT_OUT"
rg_edit '# 甲-mark'; RT_OUT=$(rg_sel); rg_undo
expect_contains "改到定義 helper 的節 → 呼叫它的節一起挑" "乙 — 使用"         "$RT_OUT"
rg_edit '# 隔離：所有測試'; RT_OUT=$(rg_sel); rg_undo
expect_contains "改到框架（第一節之前）→ 整套"           "框架或結尾統計"     "$RT_OUT"

# worktree 裡 --changed 判成整套：不默默跑，要 --full
rgq worktree add -q "$RGW" -b rtwt
RT_OUT=$(printf '.claude/hooks/lib/x.sh\n' | bash "$RGW/.claude/hooks/tests/run-tests.sh" --changed - 2>&1); rc=$?
expect_eq "worktree 裡判成整套 → exit 3"                 3 "$rc"
expect_contains "worktree 裡判成整套 → 說要加 --full"     "--full" "$RT_OUT"
RT_OUT=$(printf '.claude/hooks/lib/x.sh\n' | RT_PROBE="$RT_PROBE" bash "$RGW/.claude/hooks/tests/run-tests.sh" --changed - --full 2>&1)
expect_contains "加了 --full → 照跑整套"                  "通過 6 ・ 失敗 0" "$RT_OUT"
rgq worktree remove --force "$RGW"; rm -rf "$RG" "$RGW"
reset

# =========================================================================
section "post-bash.sh — 踩坑偵測（連續失敗後成功）"
# =========================================================================
#
# 為什麼要這個 hook：`using-taskmaster` 要求解完非平凡問題後寫一筆進 learned/，
# 但那是文字規則，沒有機制在該寫的當下提出來。「連續失敗 N 次然後成功」
# 是機器判斷得出的踩坑訊號——一次就過的不是坑。

# pb <失敗?> <指令> —— 模擬一次 Bash 工具呼叫的 PostToolUse
pb() {
    local failed="$1" cmd="$2" payload
    if [ "$failed" = "fail" ]; then
        payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"tool_response":{"is_error":true}}' "$cmd")
    else
        payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"tool_response":{"is_error":false}}' "$cmd")
    fi
    run post-bash.sh "$payload"
}
CAND_F="$SANDBOX/.claude/taskmaster-data/.learned-candidates"

# 一次就過 → 不是坑
reset
expect_empty "一次就成功不算坑" "$(pb ok "npm test")"

# 失敗次數未達門檻 → 不算坑
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_empty "失敗 2 次後成功未達門檻" "$(pb ok "x")"

# 達門檻 → 提醒 + 記候選
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_contains "失敗 3 次後成功會提醒" "這是一個坑" "$(pb ok "x")"
if grep -q '3 次失敗後成功' "$CAND_F" 2>/dev/null; then ok "候選已記入 .learned-candidates"
else ng "候選已記入 .learned-candidates" "有紀錄" "$(cat "$CAND_F" 2>/dev/null)"; fi

# 成功後計數歸零 —— 不會把上一輪的失敗算進下一輪
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
pb ok "x" >/dev/null
pb fail "y" >/dev/null
expect_empty "成功後失敗計數歸零" "$(pb ok "y")"

# 本任務只提醒一次
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
pb ok "x" >/dev/null
pb fail "y" >/dev/null; pb fail "y" >/dev/null; pb fail "y" >/dev/null
expect_empty "踩坑提醒只發一次" "$(pb ok "y")"

# 逃生門
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_empty "LEARN_CAPTURE=off 關閉偵測" \
    "$(run post-bash.sh '{"tool_name":"Bash","tool_input":{"command":"x"},"tool_response":{"is_error":false}}' LEARN_CAPTURE=off)"

reset; echo off > "$SM_FILE"
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_empty "suggest-mode=off 也關閉偵測" "$(pb ok "x")"

# exit_code 形式的失敗也要認得（不同版本欄位名不一致）
reset
for _ in 1 2 3; do
    run post-bash.sh '{"tool_name":"Bash","tool_input":{"command":"x"},"tool_response":{"exit_code":1}}' >/dev/null
done
expect_contains "exit_code 非零也算失敗" "這是一個坑" "$(pb ok "x")"

# 無指令的 payload 不爆炸
reset
expect_empty "空 command 不處理" "$(run post-bash.sh '{"tool_name":"Bash","tool_input":{}}')"

# 「同一件事」以指令前 40 字為準（2026-10-20）：三個不相干的指令各錯一次，
# 接著任何一個成功都不是坑——以前會被記成「3 次失敗後成功」
reset
pb fail "npm test" >/dev/null; pb fail "cat no-such" >/dev/null; pb fail "ls nope" >/dev/null
expect_empty "不同指令各失敗一次後成功不算坑" "$(pb ok "ls nope")"
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_empty "同一件事失敗 3 次後、成功的是別的指令 → 不算坑" "$(pb ok "y")"
# 重試常只改尾巴：前 40 字相同就是同一件事
LONGP="uv run pytest tests/integration/test_billing_flow.py"
reset
pb fail "$LONGP -x" >/dev/null; pb fail "$LONGP -k a" >/dev/null; pb fail "$LONGP -k b" >/dev/null
expect_contains "前 40 字相同、尾巴不同 → 仍算同一件事" "這是一個坑" "$(pb ok "$LONGP -vv")"
reset; mkdir -p "$SANDBOX/.claude/taskmaster-data"; echo 5 > "$SANDBOX/.claude/taskmaster-data/.bash-fail-streak"
expect_empty "舊格式（只有數字）的計數檔視同不同指令，不誤報" "$(pb ok "x")"

# =========================================================================
section "合併閘門 — 合併未驗證前不得再合併"
# =========================================================================
#
# 使用者的實際痛點：平行開發最後那段序列合併。痛在兩處——
# ①各 worktree 自己 verify 過不代表合併結果對（它們看不到彼此）
# ②一次疊好幾個之後測試紅了，得回頭二分找元凶。
# 原本「一次一個 merge、每次都驗」只寫在 worktree-orchestration skill 裡（自律）。

MP_FILE="$SANDBOX/.claude/taskmaster-data/.merge-pending"
# bash <command> —— 模擬 Bash 工具的 PreToolUse
bg() { run pre-tool-use.sh "$(printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$SANDBOX" "$1")"; }
# pbash <command> [ENV=VAL] —— 模擬 Bash 工具的 PostToolUse（成功）
pbash() { local c="$1"; shift; run post-bash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"tool_response":{"is_error":false}}' "$c")" MERGE_REFLOG_CHECK=off "$@"; }

# 偵測：合併成功要記進 .merge-pending 並提醒
reset
expect_contains "合併成功會提醒未驗證" "還沒驗證" "$(pbash 'git merge --no-ff worktree-search')"
# 清單記的是「[操作類型] 目標 ref」而不是整條指令 —— /verify 靠它分辨
# 哪些分支合進來了、該比對哪幾份 plan 的驗收標準。
if grep -qx '\[merge\] worktree-search' "$MP_FILE" 2>/dev/null; then ok "合併記入 .merge-pending（帶類型與 ref）"
else ng "合併記入 .merge-pending（帶類型與 ref）" "[merge] worktree-search" "$(cat "$MP_FILE" 2>/dev/null)"; fi

# 衝突的合併：見下一節「失敗事件」——衝突的 merge 退出碼非零，
# Claude Code 送的是 PostToolUseFailure，不是帶 is_error 的 PostToolUse。

# --abort 要清掉待驗證紀錄（放棄了就沒有東西待驗證）
reset; mkdir -p "$(dirname "$MP_FILE")"; echo 'git merge x' > "$MP_FILE"
run post-bash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"git merge --abort"},"tool_response":{"is_error":false}}')" >/dev/null
if [ ! -s "$MP_FILE" ]; then ok "git merge --abort 清掉待驗證紀錄"
else ng "git merge --abort 清掉待驗證紀錄" "空" "$(cat "$MP_FILE" 2>/dev/null)"; fi

# --continue 不動清單（那是解完衝突要完成合併，仍需驗證）
reset; mkdir -p "$(dirname "$MP_FILE")"; echo 'git merge x' > "$MP_FILE"
run post-bash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"git merge --continue"},"tool_response":{"is_error":false}}')" >/dev/null
if grep -q 'git merge x' "$MP_FILE" 2>/dev/null; then ok "git merge --continue 保留待驗證紀錄"
else ng "git merge --continue 保留待驗證紀錄" "仍有紀錄" "$(cat "$MP_FILE" 2>/dev/null)"; fi

# ---- 誤判回歸：偵測必須是「真的執行了合併」，不是「字串裡有那幾個字」 ----
#
# post-bash.sh 原本用 `case "$CMD" in *"git merge"*)` 子字串比對，於是
# `git merge-base --is-ancestor`（純唯讀祖先查詢）與任何提到指令名的
# heredoc／echo／grep 都被記成一次合併，merge-gate.sh 再拿那些幽靈紀錄擋下
# **下一次真正的合併**。2026-09-11 累計誤擋五次，其中一次擋下了
# 「修好它自己」的那次編輯（context/learned/2026-09-11-gate-blocks-its-own-fix.md）。
# 現在改用 lib/cmd-segments.sh 切段（與 git-backup-gate.sh 同一份實作）。

# pbashj <command> —— 同 pbash，但用 jq 組 payload（指令含引號／換行時要用這個）
pbashj() { run post-bash.sh "$(jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c},tool_response:{is_error:false}}')" MERGE_REFLOG_CHECK=off; }
mp_empty() {
    if [ ! -s "$MP_FILE" ]; then ok "$1"
    else ng "$1" "（不記錄）" "$(cat "$MP_FILE" 2>/dev/null)"; fi
}
mp_has() {
    if grep -qxF "$2" "$MP_FILE" 2>/dev/null; then ok "$1"
    else ng "$1" "$2" "$(cat "$MP_FILE" 2>/dev/null)"; fi
}

# merge-base 不是 merge —— 這是 2026-09-11 實際復現的那一條
reset
expect_empty "merge-base（唯讀查詢）不觸發合併提醒" \
    "$(pbashj 'git merge-base --is-ancestor 6d8d48c main')"
mp_empty "merge-base（唯讀查詢）不記入 .merge-pending"

reset; pbashj 'git log --oneline -1 6d8d48c && git merge-base --is-ancestor 6d8d48c main' >/dev/null
mp_empty "鏈式唯讀查詢（含 merge-base）不記入 .merge-pending"

reset; pbashj 'cat > d.md <<EOF
合併用 git merge --no-ff，衝突時 git rebase --abort 退回
EOF' >/dev/null
mp_empty "heredoc 內文提到指令不記入 .merge-pending"

reset; pbashj 'grep -rn "git cherry-pick" .claude/' >/dev/null
mp_empty "grep 樣式提到指令不記入 .merge-pending"

# 2026-10-16：commit 訊息用 heredoc 帶（Claude Code 預設的 commit 寫法），內文一句
# 「衝突的 merge 結束碼非 0」→ 清單被記成 `[merge] 結束碼非`。
# 上面那條 heredoc 案例沒抓到，是因為它的內文**沒有一行以 `git ` 開頭**、也沒有真的 merge。
reset; pbashj "git commit -q -m \"\$(cat <<'EOF'
fix: x

- 衝突的 merge 結束碼非 0，過去從未被記錄
EOF
)\"" >/dev/null
mp_empty "heredoc commit 訊息提到 merge 不記入 .merge-pending"

reset; pbashj "git commit -q -F - <<'EOF'
fix: x
git merge 是這樣用的
EOF" >/dev/null
mp_empty "heredoc 內文某行以 git merge 開頭也不記"

# 10-16 的實際形狀：同一條指令先 heredoc commit、再真的 merge。合併該記，
# 但 ref 曾從 heredoc 內文抽出來。
reset; pbashj "git add -A && git commit -q -F - <<'EOF'
fix: x

- 衝突的 merge 結束碼非 0，過去從未被記錄
EOF
git switch -q main && git merge --no-ff -m \"merge: y\" feat/real" >/dev/null
mp_has "heredoc commit 之後真的 merge → ref 取自真正的 merge" '[merge] feat/real'

reset; pbashj 'git commit -m "說明 git merge foo 的用法"' >/dev/null
mp_empty "引號內的 commit 訊息提到 git merge 不記"

reset; pbashj "echo 'x
git merge feature/y'" >/dev/null
mp_empty "跨行單引號字串裡以 git merge 開頭的行不記"

# 子指令只看 git 後第一個非選項字，不看整段任何位置
reset; pbashj 'git log --oneline --grep merge' >/dev/null
mp_empty "git log --grep merge 不是合併"

reset; pbashj 'git -C /some/path merge feature/x' >/dev/null
mp_has "git -C <路徑> merge 仍記錄（跳過全域選項）" '[merge] feature/x'

reset; pbashj 'git -c core.editor=true --no-pager rebase main' >/dev/null
mp_has "git -c k=v --no-pager rebase 仍記錄" '[rebase] main'

# 正向：真的執行的仍然要記，且類型與 ref 不能跑掉
reset; pbashj 'git merge feature/x' >/dev/null
mp_has "真正的 merge 仍記錄（ref 正確抽出）" '[merge] feature/x'

reset; pbashj 'cd /some/path && git cherry-pick abc123' >/dev/null
mp_has "鏈式 cd && cherry-pick 仍記錄（類型正確）" '[cherry-pick] abc123'

# 合併訊息改用 -F <檔> 或 -m "$(cat ...)" 傳入時，ref 曾被記成 shell 片段
# （實例：`[merge] $M/merge-msg.txt")"`）。抽 ref 要懂引號與 $( )，並跳過帶值的選項。
reset; pbashj 'git merge --no-ff -F "$M/merge-msg.txt" feature/a' >/dev/null
mp_has "merge -F <檔> 抽出正確的 ref" '[merge] feature/a'
reset; pbashj 'git merge --no-ff -m "$(cat "$M/merge-msg.txt")" feature/b' >/dev/null
mp_has "merge -m \"\$(cat ...)\" 抽出正確的 ref" '[merge] feature/b'
reset; pbashj 'git merge --no-ff -m "merge: 加入匯出功能; 修正分頁" feature/c' >/dev/null
mp_has "merge --no-ff -m \"含空白與分號的訊息\" 抽出正確的 ref" '[merge] feature/c'

reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] x' > "$MP_FILE"
pbashj 'git rebase --abort' >/dev/null
mp_empty "git rebase --abort 仍清掉待驗證紀錄"

# 閘門：清單非空時擋下下一次合併
reset; mkdir -p "$(dirname "$MP_FILE")"; echo 'git merge --no-ff worktree-search' > "$MP_FILE"
expect_decision "待驗證時擋下下一次 merge"       deny  "$(bg 'git merge --no-ff worktree-cart')"
expect_decision "待驗證時擋下 cherry-pick"       deny  "$(bg 'git cherry-pick abc1234')"
expect_decision "待驗證時擋下 rebase"            deny  "$(bg 'git rebase main')"
expect_decision "merge --abort 放行（收拾現場）" allow "$(bg 'git merge --abort')"
expect_decision "rebase --continue 放行"         allow "$(bg 'git rebase --continue')"
expect_decision "無關指令放行"                   allow "$(bg 'git status')"
# 中間合併只快檢（commands/verify.md「合併驗證關卡」）：deny 訊息要讓模型知道快檢通過就夠清清單，
# 否則它會以為每次合併都得跑整套——那正是這次精簡要拿掉的重工。
MG_MSG=$(bg 'git merge --no-ff worktree-cart' | jq -r '.hookSpecificOutput.permissionDecisionReason')
expect_contains "deny 訊息說中間合併只快檢"      "只快檢"       "$MG_MSG"
expect_contains "deny 訊息說快檢通過也清清單"    "快檢通過也算" "$MG_MSG"
expect_contains "deny 訊息把測試範圍指向 verify.md" "\`commands/verify.md\`「合併驗證關卡」" "$MG_MSG"

# 本輪起點：合併**執行前**記下 HEAD（不事後讀會被 reset／rebase 改寫的 ORIG_HEAD）
RS_FILE="$SANDBOX/.claude/taskmaster-data/.merge-round-start"
rs_repo() { ( cd "$SANDBOX" && { [ -d .git ] || git -c init.defaultBranch=main init -q . ; } \
    && { git rev-parse -q --verify HEAD >/dev/null || { echo x > seed && git add seed \
         && git -c user.email=t@t -c user.name=t commit -qm init; }; } ) >/dev/null 2>&1; }
reset; rs_repo; bg 'git merge --no-ff feature/x' >/dev/null
expect_eq "合併前記下本輪起點（HEAD）"           "$(git -C "$SANDBOX" rev-parse HEAD 2>/dev/null)" "$(cat "$RS_FILE" 2>/dev/null)"
reset; mkdir -p "${RS_FILE%/*}"; echo abc123 > "$RS_FILE"; bg 'git merge --no-ff feature/y' >/dev/null
expect_eq "本輪起點已有內容不覆寫"               abc123 "$(cat "$RS_FILE" 2>/dev/null)"
reset; bg 'git status' >/dev/null
[ -e "$RS_FILE" ] && ng "不是合併的 git 指令不記起點" "無檔" "有" || ok "不是合併的 git 指令不記起點"
reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] a' > "$MP_FILE"; bg 'git merge --no-ff feature/z' >/dev/null
[ -e "$RS_FILE" ] && ng "被擋下的合併不記起點" "無檔" "有" || ok "被擋下的合併不記起點"
reset
PB_MSG=$(pbash 'git merge --no-ff worktree-search')
expect_contains "合併成功訊息說中間只快檢" "中間的只快檢" "$PB_MSG"
expect_contains "合併成功訊息把各驗什麼指向 verify.md" "\`commands/verify.md\`「合併驗證關卡」" "$PB_MSG"
reset; mkdir -p "$(dirname "$MP_FILE")"; echo 'git merge --no-ff worktree-search' > "$MP_FILE"
# 指令帶 --no-ff：關掉 MERGE_GATE 之後**下一道** lib 閘門（merge-noff-gate）
# 仍然在線，裸的 `git merge x` 會被它擋下，那不是本案例要測的事。
expect_decision "MERGE_GATE=off 關閉閘門"        allow \
    "$(run pre-tool-use.sh "$(printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"git merge --no-ff x"}}' "$SANDBOX")" MERGE_GATE=off)"

# 清單為空 → 放行（/verify 通過後的狀態）
reset; mkdir -p "$(dirname "$MP_FILE")"; : > "$MP_FILE"
expect_decision "清單為空時放行 merge" allow "$(bg 'git merge --no-ff worktree-cart')"

# =========================================================================
section "post-bash.sh — 失敗事件（PostToolUseFailure）"
# =========================================================================
#
# PostToolUse 只在工具**成功**時觸發；指令非零結束走 PostToolUseFailure。
# 本檔曾經只接 PostToolUse，於是：衝突的 merge 從沒被記過（下一次合併跳過驗證）、
# 踩坑偵測的失敗計數從沒累加過。舊測試抓不到，因為它們直接餵
# `tool_response.is_error` 給腳本——那是 Claude Code 從來不會送出的形狀。
# 這一節的 payload 一律照官方文件的 PostToolUseFailure 形狀：沒有 tool_response，
# 錯誤在頂層 `error`（首行 `Exit code N`）。
# 見 context/learned/2026-10-15-posttooluse-skips-failures.md。

# pbf <command> <error> [cwd] —— 模擬 Bash 的 PostToolUseFailure
pbf() {
    run post-bash.sh "$(jq -nc --arg c "$1" --arg e "$2" --arg d "${3:-}" '
        {hook_event_name:"PostToolUseFailure",tool_name:"Bash",tool_input:{command:$c},
         error:$e,is_interrupt:false} + (if $d == "" then {} else {cwd:$d} end)')" MERGE_REFLOG_CHECK=off
}
STREAK_F="$SANDBOX/.claude/taskmaster-data/.bash-fail-streak"

# 真正的 bug 在接線，不在腳本：下面的 payload 測試全綠也證明不了 Claude Code
# 會在失敗時呼叫本檔。這兩條釘住 settings.json。
SETTINGS="$HOOK_DIR/../settings.json"
for ev in PostToolUse PostToolUseFailure; do
    if jq -e --arg ev "$ev" '[.hooks[$ev][]? | select((.matcher // "") | split("|") | index("Bash")) | .hooks[] | select(.command | contains("post-bash.sh"))] | length > 0' "$SETTINGS" >/dev/null 2>&1; then
        ok "settings.json 把 post-bash.sh 接在 $ev(Bash)"
    else ng "settings.json 把 post-bash.sh 接在 $ev(Bash)" "有接線" "沒有"; fi
done

# ---- 合併 ----

reset
out=$(pbf 'git merge --no-ff feat/x' 'Exit code 1
Auto-merging a.txt
CONFLICT (content): Merge conflict in a.txt
Automatic merge failed; fix conflicts and then commit the result.')
expect_contains "衝突的 merge（失敗事件）導向 conflict-resolver" "conflict-resolver" "$out"
mp_has "衝突的 merge（失敗事件）記入 .merge-pending" '[merge] feat/x'
if grep -q 'feat/x (conflicted=1, event=PostToolUseFailure)' "$SANDBOX/.claude/logs/hooks.log" 2>/dev/null; then
    ok "衝突的 merge 在 log 標 conflicted=1"
else ng "衝突的 merge 在 log 標 conflicted=1" "conflicted=1" "$(tail -1 "$SANDBOX/.claude/logs/hooks.log" 2>/dev/null)"; fi
# 回應的 hookEventName 必須等於觸發的事件，否則注入會被丟掉
expect_contains "失敗事件的回應帶 hookEventName=PostToolUseFailure" '"PostToolUseFailure"' "$out"

# 2026-10-15 實際漏記的那一條：合併成功，是鏈在後面的指令失敗
reset
out=$(pbf 'git switch -q main && git merge --no-ff -m "merge: x" feat/x >/dev/null && cat no-such-file' 'Exit code 1
cat: no-such-file: No such file or directory')
mp_has "合併成功但後段指令失敗仍記入 .merge-pending" '[merge] feat/x'

# 10-16 那筆就是失敗事件送來的（event=PostToolUseFailure）
reset; pbf "git commit -q -F - <<'EOF'
fix: x
- 衝突的 merge 結束碼非 0
EOF
git switch -q main && git merge --no-ff -m \"merge: y\" feat/real && cat no-such-file" 'Exit code 1' >/dev/null
mp_has "失敗事件：heredoc commit + 真 merge → ref 取自真正的 merge" '[merge] feat/real'
expect_contains "非零但無衝突 → 提示「非零結束」而非衝突" "非零結束" "$out"
case "$out" in *conflict-resolver*) ng "非零但無衝突不導向 conflict-resolver" "不含 conflict-resolver" "$out" ;;
                *) ok "非零但無衝突不導向 conflict-resolver" ;; esac

reset; pbf 'git cherry-pick abc123' 'Exit code 1
error: could not apply abc123... fix
hint: after resolving the conflicts, mark the corrected paths' >/dev/null
mp_has "衝突的 cherry-pick（失敗事件）記入 .merge-pending" '[cherry-pick] abc123'

# 失敗事件也要走切段比對，不能退回子字串
reset; pbf 'grep -rn "git merge" .claude/ | head -1 && false' 'Exit code 1' >/dev/null
mp_empty "失敗的 grep 提到指令名不記入 .merge-pending"
reset; pbf 'git merge-base --is-ancestor abc main' 'Exit code 1' >/dev/null
mp_empty "失敗的 merge-base（唯讀查詢）不記入 .merge-pending"

# --abort 失敗不清：最常見的原因是「沒有進行中的合併」，清單裡那筆是真的待驗證
reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] done-before' > "$MP_FILE"
pbf 'git merge --abort' 'Exit code 128
fatal: There is no merge to abort (MERGE_HEAD missing).' >/dev/null
mp_has "--abort 失敗時保留待驗證紀錄" '[merge] done-before'

# 真的 repo 狀態：輸出被 >/dev/null 吃掉、error 裡沒有衝突字樣時，
# 仍要靠 `ls-files -u` 認出衝突。成功事件（`; true` 讓整條變 0）也一樣。
GR="$SANDBOX/gitrepo"
rm -rf "$GR"; mkdir -p "$GR"
(
    cd "$GR" || exit 1
    g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=base "$@" >/dev/null 2>&1; }
    g init -q; echo a > f.txt; g add f.txt; g commit -qm base
    g checkout -q -b side; echo side > f.txt; g commit -qam side
    g checkout -q -; echo main > f.txt; g commit -qam main
    g merge side
)
if [ -n "$(git -C "$GR" ls-files -u 2>/dev/null | head -1)" ]; then
    reset
    expect_contains "輸出被吃掉時靠 repo 狀態認出衝突" "conflict-resolver" \
        "$(pbf 'git merge side >/dev/null 2>&1' 'Exit code 1' "$GR")"
    reset
    expect_contains "成功事件（; true）但 repo 有衝突 → 仍導向 conflict-resolver" "conflict-resolver" \
        "$(run post-bash.sh "$(jq -nc --arg d "$GR" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$d,tool_input:{command:"git merge side; true"},tool_response:{stdout:"",stderr:"",interrupted:false,isImage:false}}')")"
else
    ng "建立衝突中的測試 repo" "有未合併路徑" "git 無法建出衝突狀態"
fi
rm -rf "$GR"

# ---- 一般失敗指令 ----

reset
expect_empty "失敗的非 git 指令不輸出" "$(pbf 'npm test' 'Exit code 1
Error: Cannot find module')"
mp_empty "失敗的非 git 指令不記入 .merge-pending"
if [ "$(cut -f1 "$STREAK_F" 2>/dev/null)" = "1" ]; then ok "失敗事件讓 .bash-fail-streak 累加"
else ng "失敗事件讓 .bash-fail-streak 累加" "1" "$(cut -f1 "$STREAK_F" 2>/dev/null)"; fi

# 踩坑偵測端到端：真實形狀的失敗事件 ×3 → 成功 → 提醒
reset
for _ in 1 2 3; do pbf 'uv run pytest' 'Exit code 1
FAILED tests/test_x.py' >/dev/null; done
expect_contains "失敗事件 ×3 後成功會提醒踩坑" "這是一個坑" "$(pb ok "uv run pytest")"

# 被中斷的失敗也算一次（與舊有 interrupted 語意一致）
reset
run post-bash.sh '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"sleep 99"},"error":"aborted","is_interrupt":true}' >/dev/null
if [ "$(cut -f1 "$STREAK_F" 2>/dev/null)" = "1" ]; then ok "is_interrupt 的失敗事件也累加"
else ng "is_interrupt 的失敗事件也累加" "1" "$(cut -f1 "$STREAK_F" 2>/dev/null)"; fi

# 逃生門在失敗事件下照樣有效
reset; run post-bash.sh '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"npm test"},"error":"Exit code 1"}' LEARN_CAPTURE=off >/dev/null
if [ ! -s "$STREAK_F" ]; then ok "LEARN_CAPTURE=off 時失敗事件不計數"
else ng "LEARN_CAPTURE=off 時失敗事件不計數" "空" "$(cat "$STREAK_F" 2>/dev/null)"; fi

# =========================================================================
section "cmd-segments.sh — 切段邊界（註解、算術位移、全域選項、heredoc 結束字）"
# =========================================================================
#
# 四個都是「切段讓真的指令消失或多出假指令」，而且都不報錯：
# 消失 → git-backup-gate 放行、post-bash 不記；多出 → 清單多一筆假合併，擋下一次真的合併。
# 這裡直接驗 cmd_segments 的輸出（四支閘門共用它），閘門層的回歸放在各自的節。

cs() { ( source "$HOOK_DIR/lib/cmd-segments.sh"; cmd_segments "$1" ); }
csub() { ( source "$HOOK_DIR/lib/cmd-segments.sh"; cmd_git_subcmd "$1" ); }

# ① 註解裡的單引號被當成引號開頭 → 後面整段被遮掉
expect_eq "整行註解含單引號，下一行的 reset --hard 還在" 'git reset --hard HEAD~1' \
    "$(cs $'# reset because it\'s broken\ngit reset --hard HEAD~1')"
expect_eq "行尾註解含單引號，下一行的 rebase 還在" $'git status\ngit rebase main' \
    "$(cs $'git status # it\'s fine\ngit rebase main')"
expect_eq "引號內的 # 不是註解" $'git commit -m ""\ngit merge feat/a' \
    "$(cs $'git commit -m "fix #1 don\'t" && git merge feat/a')"
expect_eq "\$# 不是註解" 'git rebase main' "$(cs '[ $# -gt 0 ] && git rebase main')"
expect_eq "\${#var} 不是註解" 'git rebase main' "$(cs 'echo ${#arr[@]} && git rebase main')"
expect_eq "URL 錨點（字中間的 #）不是註解" 'git rebase main' "$(cs 'curl http://x/#top && git rebase main')"
expect_eq "註解裡提到的指令不算一段" '' "$(cs '# git merge feat/x')"

# ② 算術裡的位元左移被當成 heredoc 開頭 → 之後全部被當成 heredoc 內文吃掉
expect_eq "\$((1<<x)) 不是 heredoc" 'git rebase main' "$(cs $'echo $((1<<x))\ngit rebase main')"
expect_eq "((y = 1<<x)) 不是 heredoc" 'git rebase main' "$(cs $'(( y = 1<<x ))\ngit rebase main')"
expect_eq "<<< here-string 不是 heredoc" 'git rebase main' "$(cs $'cat <<<x\ngit rebase main')"
expect_eq "同一行先算術、後真的 heredoc：heredoc 照樣剝掉" 'git rebase main' \
    "$(cs $'echo $((1<<2)) && cat <<EOF\ngit merge fake\nEOF\ngit rebase main')"

# ⑤ 值放在下一個字的全域選項
expect_eq "--git-dir <路徑> merge" 'git merge feat' "$(cs 'git --git-dir /x/.git merge feat')"
expect_eq "--git-dir=<路徑> merge" 'git merge feat' "$(cs 'git --git-dir=/x/.git merge feat')"
expect_eq "--work-tree <路徑> --git-dir=<路徑> merge" 'git merge feat' \
    "$(cs 'git --work-tree /w --git-dir=/x/.git merge feat')"
expect_eq "--namespace <名稱> rebase" 'git rebase main' "$(cs 'git --namespace ns rebase main')"
expect_eq "--config-env <k=v> --attr-source <tree> rebase" 'git rebase main' \
    "$(cs 'git --config-env core.x=HOME --attr-source HEAD rebase main')"
expect_eq "--exec-path=<路徑> merge" 'git merge feat' "$(cs 'git --exec-path=/p merge feat')"
# 不帶 = 的 --exec-path 是「印出路徑就結束」（git 2.53 實測），後面的字都不會執行
expect_eq "裸 --exec-path 之後沒有子指令" '' "$(csub 'git --exec-path merge feat')"
expect_eq "cmd_git_subcmd 也跳過 --git-dir <路徑>" 'merge' "$(csub 'git --git-dir /x/.git merge feat')"

# ⑥ 一般 <<WORD 的結束行必須一字不差；只有 <<-WORD 允許行首 tab（不是空白）
expect_eq "<<EOF 內文縮排的 EOF 不會提早結束" 'git status' \
    "$(cs $'cat <<EOF\n  EOF\ngit merge fake\nEOF\ngit status')"
expect_eq "<<-EOF 的 tab 縮排結束行照樣結束" 'git rebase main' \
    "$(cs $'cat <<-EOF\n\tbody\n\tEOF\ngit rebase main')"
expect_eq "<<-EOF 用空白縮排的 EOF 不算結束" 'git status' \
    "$(cs $'cat <<-EOF\n  EOF\ngit merge fake\nEOF\ngit status')"

# 閘門層：post-bash.sh 的合併紀錄（pbashj／mp_has／mp_empty 定義在「合併閘門」節）
reset; pbashj $'# merge because it\'s ready\ngit merge feat/x' >/dev/null
mp_has "註解含單引號之後的 merge 仍記錄" '[merge] feat/x'
reset; pbashj 'git --git-dir /x/.git merge feat' >/dev/null
mp_has "git --git-dir <路徑> merge 記成正確的 ref" '[merge] feat'
reset; pbashj $'cat > n.md <<EOF\n  EOF\ngit merge fake\nEOF' >/dev/null
mp_empty "heredoc 內文縮排的 EOF 之後的內文不記成合併"

# =========================================================================
section "git backup 閘門 — destructive 操作前必須有安全快照"
# =========================================================================
#
# 這四種指令（reset --hard／push --force／branch -D／rebase）會讓一段 commit
# 失去所有 ref，撿回來只剩 reflog——而 reflog 是「通常還在」不是「保證還在」。
# 原本這條只寫在 rules/git-workflow.md 裡（自律），現在由 lib/git-backup-gate.sh 強制。
#
# 這組測試需要**真的 git repo**：閘門的判準是「HEAD 有沒有 backup/* tag 指著」，
# 只有真的打 tag、真的往前 commit 才驗得到「tag 指向舊 commit 時仍要擋」。
# 直接把沙箱本身 git init（CLAUDE_PROJECT_DIR 已指向它 → WORK_ROOT 就是它）。
# 本區塊之後的案例不碰 git，所以多一個 .git 目錄不影響它們。

git -c init.defaultBranch=main init -q "$SANDBOX" >/dev/null 2>&1

gitq() { git -C "$SANDBOX" -c user.email=t@example.com -c user.name=t "$@" >/dev/null 2>&1; }
# 清掉殘留的 backup tag —— reset() 只清 .claude/，tag 會跨案例活著
gbg_untag() {
    local t
    while IFS= read -r t; do
        [ -n "$t" ] || continue
        git -C "$SANDBOX" tag -d "$t" >/dev/null 2>&1
    done <<< "$(git -C "$SANDBOX" tag -l 'backup/*' 2>/dev/null)"
}
gbp() { jq -nc --arg cwd "$SANDBOX" --arg c "$1" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}'; }
gb()  { local c="$1"; shift; run pre-tool-use.sh "$(gbp "$c")" "$@"; }
# gbo <command> <root> —— 換一個 root（run() 已帶 CLAUDE_PROJECT_DIR，後面的覆寫前面的）
gbo() {
    run pre-tool-use.sh \
        "$(jq -nc --arg cwd "$2" --arg c "$1" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')" \
        CLAUDE_PROJECT_DIR="$2"
}

reset; gitq commit --allow-empty -m c1; gbg_untag

# 沒有快照 → 四種 destructive 指令都要擋
expect_decision "reset --hard 沒快照時被擋"      deny "$(gb 'git reset --hard HEAD~1')"
expect_decision "push --force 沒快照時被擋"      deny "$(gb 'git push --force origin main')"
expect_decision "push -f 沒快照時被擋"           deny "$(gb 'git push -f origin main')"
# --force-with-lease 防的是覆蓋**別人**的 push，不是防自己弄丟本地工作 → 不特例放行
expect_decision "push --force-with-lease 不特例放行" deny "$(gb 'git push --force-with-lease origin main')"
gitq branch feat/x
expect_decision "branch -D 沒快照時被擋"         deny "$(gb 'git branch -D feat/x')"
expect_decision "rebase 沒快照時被擋"            deny "$(gb 'git rebase main')"
# 真實用法常是鏈式的，指令段不是整條指令的開頭
expect_decision "鏈式 cd x && git reset --hard 也擋" deny "$(gb 'cd /tmp && git reset --hard HEAD~1')"

# deny 訊息要能直接複製，不能只說「請先打 tag」
expect_contains "deny 訊息給出可複製的 tag 指令" "git tag backup/" \
    "$(gb 'git reset --hard HEAD~1' | jq -r '.hookSpecificOutput.permissionDecisionReason')"

# 有快照 → 放行；但快照必須指向**當前** HEAD
reset; gbg_untag; gitq tag "backup/main-test"
expect_decision "backup tag 指向 HEAD 時放行"    allow "$(gb 'git reset --hard HEAD~1')"

gitq commit --allow-empty -m c2      # HEAD 前進，tag 留在舊 commit
expect_decision "tag 指向舊 commit 時仍擋"       deny  "$(gb 'git reset --hard HEAD~1')"
gbg_untag

# --continue / --abort / --skip 是收拾當前狀態，不是新的 destructive 操作
expect_decision "rebase --continue 放行"         allow "$(gb 'git rebase --continue')"
expect_decision "rebase --abort 放行"            allow "$(gb 'git rebase --abort')"
expect_decision "rebase --skip 放行"             allow "$(gb 'git rebase --skip')"

# 不該擋的
expect_decision "無害的 git 指令放行"            allow "$(gb 'git status')"
expect_decision "reset 沒帶 --hard 放行"         allow "$(gb 'git reset HEAD~1')"
expect_decision "branch -d（小寫）放行"          allow "$(gb 'git branch -d feat/x')"
expect_decision "不含 git 的指令放行"            allow "$(gb 'npm run reset -- --hard')"
# 誤擋回歸：子字串比對會讓「寫文件時提到這些指令」也被擋。本閘門幾乎每個 session
# 都處於「沒有 backup tag」的狀態，所以這個誤擋會天天發生——實際踩過一次。
expect_decision "只是提到指令（heredoc 內文）不擋" allow \
    "$(gb 'cat > d.md <<EOF
先打 tag 再 git reset --hard
EOF')"
# 上面那條的內文不以 git 開頭；這兩條是真的會撞的形狀（heredoc 內某行以 git 開頭、
# 引號內的訊息）——2026-10-16 在 post-bash.sh 那邊實際撞到同一個切段缺陷
expect_decision "heredoc commit 內文某行以 git reset --hard 開頭不擋" allow \
    "$(gb "git commit -q -F - <<'EOF'
docs: 說明
git reset --hard 之前先打 tag
EOF")"
expect_decision "commit -m 訊息含 git reset --hard 不擋" allow \
    "$(gb 'git commit -m "改用 tag，取代直接 git reset --hard"')"
expect_decision "git -C <路徑> reset --hard 仍擋（跳過全域選項）" deny \
    "$(gb "git -C $SANDBOX reset --hard HEAD~1")"
# 切段把真的指令弄丟的兩種形狀（cmd-segments 節有單元測試）
expect_decision "註解含單引號之後的 reset --hard 仍擋" deny \
    "$(gb $'# reset because it\'s broken\ngit reset --hard HEAD~1')"
expect_decision "\$((1<<x)) 之後的 rebase 仍擋" deny \
    "$(gb $'echo $((1<<x))\ngit rebase main')"

# ---- 被保護的對象不一定是 HEAD（2026-10-20）----
# branch -D 會弄丟的是**那條分支的 tip**：站在 main 上刪 feat/x，HEAD 的 tag 保不到它
reset; gbg_untag; gitq branch -f feat/x; gitq commit --allow-empty -m moved; gitq tag backup/head-only
expect_decision "branch -D：HEAD 有 tag 但被刪的分支沒有 → 仍擋" deny "$(gb 'git branch -D feat/x')"
expect_contains "branch -D：建議指令對著那條分支打 tag" "feat/x" \
    "$(gb 'git branch -D feat/x' | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -o 'git tag backup/feat/x-[0-9-]* feat/x')"
gbg_untag; gitq checkout -q -b feat/tip; gitq commit --allow-empty -m tip; gitq tag backup/feat-tip; gitq checkout -q main
expect_decision "branch -D：被刪的分支 tip 有 tag → 放行（HEAD 沒有也一樣）" allow "$(gb 'git branch -D feat/tip')"
expect_decision "branch -D：分支不存在 → 放行（讓 git 自己報錯）" allow "$(gb 'git branch -D no-such-branch')"
gbg_untag; gitq branch -D feat/tip
# reset --hard 沒帶目標：HEAD 不動，tag 救不到的是未 commit 的改動
reset; gbg_untag
expect_decision "reset --hard（無目標）工作區乾淨 → 放行" allow "$(gb 'git reset --hard')"
expect_decision "reset --hard HEAD 工作區乾淨 → 放行"    allow "$(gb 'git reset --hard HEAD')"
echo v1 > "$SANDBOX/tracked.txt"; gitq add tracked.txt; gitq commit -m tracked; echo v2 > "$SANDBOX/tracked.txt"
expect_decision "reset --hard（無目標）有未 commit 改動 → 擋" deny "$(gb 'git reset --hard')"
expect_contains "有改動時講實話：tag 救不到" "backup tag 救不到這些" \
    "$(gb 'git reset --hard' | jq -r '.hookSpecificOutput.permissionDecisionReason')"
gitq tag backup/main-has-tag
expect_decision "有改動時打 tag 也沒用（仍擋）" deny "$(gb 'git reset --hard HEAD')"
gbg_untag; gitq checkout -- tracked.txt

# 逃生門
expect_decision "GIT_BACKUP_GATE=off 關閉閘門"   allow "$(gb 'git reset --hard HEAD~1' GIT_BACKUP_GATE=off)"
reset; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門"    allow "$(gb 'git reset --hard HEAD~1')"

# 判斷不了就放行（缺依賴／狀態不明時寧可放行也不誤擋）
reset
GBG_EMPTY="$SANDBOX/emptyrepo"; mkdir -p "$GBG_EMPTY"
git -c init.defaultBranch=main init -q "$GBG_EMPTY" >/dev/null 2>&1
expect_decision "空 repo（unborn HEAD）放行"     allow "$(gbo 'git reset --hard HEAD~1' "$GBG_EMPTY")"

GBG_NOREPO=$(mktemp -d)
expect_decision "不在 git repo 裡放行"           allow "$(gbo 'git reset --hard HEAD~1' "$GBG_NOREPO")"
rm -rf "$GBG_NOREPO"

# =========================================================================
section "merge --no-ff 閘門 — 合併本地 topic 分支必須留下 merge commit"
# =========================================================================
#
# 為什麼要這組：2026-09-16 一個在獨立 worktree 做完的任務（WBS 11.26）合併回
# main 時漏了 `--no-ff`，主線零分歧 → fast-forward → **任務邊界在歷史上消失**，
# `git log --first-parent` 看不出那是一個任務、`git revert -m 1` 也無從整批回退。
# 這件事當時**已經寫在兩份文件裡**（commands/worktree.md、worktree-orchestration
# skill）還是漏了，所以改由 lib/merge-noff-gate.sh 強制。
#
# 這組沿用上一區塊 git init 過的 $SANDBOX（本閘門要查 `git remote` 才分得出
# `fork/main` 是遠端 ref 而 `feat/x` 是本地分支）。merge --no-ff 不屬於
# git-backup-gate 管的四種 destructive 指令，兩者不會互相干擾。

gitq remote add fork https://example.invalid/fork.git
gbg_untag
reset
# mn <command> [ENV=VAL] —— 用 jq 組 payload（指令含引號／換行時必須這樣）
mn() {
    local c="$1"; shift
    run pre-tool-use.sh \
        "$(jq -nc --arg cwd "$SANDBOX" --arg c "$c" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')" \
        "$@"
}

# 事故原型：worktree 分支合回 main，沒帶旗標
expect_decision "合併本地分支沒帶 --no-ff → 擋" deny "$(mn 'git merge worktree-agent-a4c461cf622a61062')"
expect_decision "帶 --no-ff → 放行"             allow "$(mn 'git merge --no-ff worktree-agent-a4c461cf622a61062')"

# 意圖已明確表達的另外兩種
expect_decision "--squash 放行（明確不要 merge 節點）" allow "$(mn 'git merge --squash feat/x')"
expect_decision "--ff-only 放行（明確就是要 ff）"     allow "$(mn 'git merge --ff-only feat/x')"

# 純同步合併不該被逼出一個空的 merge 節點
expect_decision "git merge origin/main 放行"    allow "$(mn 'git merge origin/main')"
expect_decision "git merge upstream/main 放行"  allow "$(mn 'git merge upstream/main')"
expect_decision "任意 <remote>/… 放行（fork/main）" allow "$(mn 'git merge fork/main')"
expect_decision "FETCH_HEAD 放行"               allow "$(mn 'git merge FETCH_HEAD')"
expect_decision "@{u} 放行"                     allow "$(mn 'git merge @{u}')"
# 有斜線不代表是遠端——`feat/x` 是本地 topic 分支，正是最該擋的那一類。
# 判準是「第一段是不是真的 remote 名稱」，不是「有沒有斜線」。
expect_decision "feat/x（有斜線的本地分支）仍擋" deny "$(mn 'git merge feat/x')"

# 誤判回歸：merge-base 是唯讀查詢，不是合併（cmd-segments.sh 存在的理由）
expect_decision "git merge-base 不被誤擋"       allow "$(mn 'git merge-base --is-ancestor 6d8d48c main')"
expect_decision "鏈式唯讀查詢（含 merge-base）放行" allow \
    "$(mn 'git log --oneline -1 6d8d48c && git merge-base --is-ancestor 6d8d48c main')"
expect_decision "heredoc 內文提到指令不擋"      allow "$(mn 'cat > d.md <<EOF
合併任務分支時用 git merge task-branch
EOF')"

# 收拾當前狀態，不是新合併
expect_decision "merge --abort 放行"            allow "$(mn 'git merge --abort')"
expect_decision "merge --continue 放行"         allow "$(mn 'git merge --continue')"

# `-m` 會吃掉下一個 token。引號內文若直接刪掉，`mybr` 會被 `-m` 誤吃，
# 然後「沒有 ref 參數」讓閘門靜默放行——所以引號字串換成佔位 token 而不是刪除。
expect_decision "-m \"…\" 之後的分支不會被吃掉" deny "$(mn 'git merge -m "merge: 11.26 搜尋結果分頁" mybr')"
expect_decision "--no-ff 搭配 -m 放行"          allow "$(mn 'git merge --no-ff -m "merge: 11.26 搜尋結果分頁" mybr')"
# 引號內文提到旗標不算數（它是訊息，不是旗標）
expect_decision "-m 內文提到 --no-ff 不算帶旗標" deny "$(mn 'git merge -m "這次改用 --no-ff" mybr')"

# 其他形狀
expect_decision "鏈式 cd x && git merge 也擋"   deny  "$(mn 'cd /tmp && git merge mybr')"
expect_decision "沒有 ref 參數時放行"           allow "$(mn 'git merge')"
expect_decision "git pull 不是 merge，放行"     allow "$(mn 'git pull origin main')"
expect_decision "不含 git 的指令放行"           allow "$(mn 'npm run merge -- mybr')"
expect_decision "-X ours 的值不會被當成 ref"    deny  "$(mn 'git merge --strategy-option ours mybr')"
# 反向：**值是選配的**選項不吃下一個 token（`--log[=<n>]` 必須寫成 `--log=5`）。
# 把它誤列進「吃下一個 token」那串的代價是靜默放行——分支名被當成 --log 的值。
expect_decision "--log 不會吃掉後面的分支名"    deny  "$(mn 'git merge --log mybr')"
expect_decision "--log=5 附著值一樣擋"          deny  "$(mn 'git merge --log=5 mybr')"

# deny 訊息要能直接複製，而且要誠實
MN_MSG=$(mn 'git merge mybr' | jq -r '.hookSpecificOutput.permissionDecisionReason')
expect_contains "deny 訊息給出補好旗標的完整指令" "git merge --no-ff mybr" "$MN_MSG"
expect_contains "deny 訊息講 --first-parent 的具體效益" "first-parent"      "$MN_MSG"
expect_contains "deny 訊息講 revert -m 1 可整批回退"    "revert -m 1"       "$MN_MSG"
expect_contains "deny 訊息誠實說明它不是平行的證據"    "不是平行做過的證據" "$MN_MSG"
expect_contains "deny 訊息給永久解（含 pull.rebase 配套）" "pull.rebase true" "$MN_MSG"

# **刻意沒有 deny-once**：這是「指令形狀」閘門，補上旗標重打同一條就過，
# 天然自清。記旗標反而會讓「第二次真的漏掉」時靜默放行。
mn 'git merge mybr' >/dev/null
expect_decision "沒有 deny-once：第二次仍擋"    deny  "$(mn 'git merge mybr')"

# 逃生門
expect_decision "MERGE_NOFF_GATE=off 關閉閘門"  allow "$(mn 'git merge mybr' MERGE_NOFF_GATE=off)"
reset; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門"   allow "$(mn 'git merge mybr')"
reset

# 上一道閘門優先：待驗證的合併是**狀態**問題，該先講；--no-ff 只是這條指令的
# 形狀，補上旗標重打就好。接線順序（merge_gate → merge_noff_gate）釘在這裡。
mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] worktree-search' > "$MP_FILE"
expect_contains "merge-gate 排在 --no-ff 閘門之前" "上一次合併還沒驗證過" \
    "$(mn 'git merge mybr' | jq -r '.hookSpecificOutput.permissionDecisionReason')"
reset

# =========================================================================
section "分支切換閘門 — 站在 topic 分支上不得直接開新分支"
# =========================================================================
#
# 事故（2026-09-17）：主 checkout 站在 `fix/stream-token-ledger` 上、一個 subagent
# 正在那條分支上工作，此時要開第二個任務。模型講得出「`git checkout -b` 會把它
# 腳下的分支抽掉」這個危險——但是在被使用者推了之後。沒有任何機制在它真的要打
# 那條指令時攔下來。第二個情境沒有 agent 也成立：切到 topic 分支之後開新分支，
# 基底會混進前一個任務的 commit。現在由 lib/branch-switch-gate.sh 強制。
#
# 這組沿用上面 git init 過的 $SANDBOX（閘門要問「當前分支」與「預設分支」，
# 只有真的切分支才驗得到）。**結束時務必切回 main**——後面的 worktree 那組
# 從這個 repo 開 worktree。

bs() {
    local c="$1"; shift
    run pre-tool-use.sh \
        "$(jq -nc --arg cwd "$SANDBOX" --arg c "$c" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')" \
        "$@"
}
BS_LOG="$SANDBOX/.claude/logs/agent-activity.jsonl"
# in-flight 的判準與 pre-agent-gate 共用 lib/agent-inflight.sh：agent_id 配對、
# 60 分鐘窗、缺 agent_type 印 `-`。這裡帶 agent_type 是因為攔截訊息要印出名單。
bs_start() {
    mkdir -p "$(dirname "$BS_LOG")"
    echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"agent_id\":\"$1\",\"agent_type\":\"$2\"}" >> "$BS_LOG"
}
bs_msg() { bs "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason'; }

gbg_untag
# 本閘門的判斷正是「當前分支 == 預設分支嗎」，所以分支名必須是確定的。本檔每個 git init 都帶
# `-c init.defaultBranch=main`（「全體 hooks」那節有檢查擋新增的），不看跑測試那台機器的設定；
# 前面的區塊會真的 `checkout main`（例如 backup 閘門那組）。下面兩行是保險：萬一 HEAD 停在別的分支，
# 改名成 main 再切過去。
gitq branch -M main
gitq checkout main
reset

# ---- 第一格：站在預設分支上 → 放行（這正是 git-workflow.md 第 1 條要的流程）
expect_decision "在 main 上開新分支放行"          allow "$(bs 'git checkout -b feat/x')"
expect_decision "在 main 上 git switch -c 放行"   allow "$(bs 'git switch -c feat/x')"
# 有 agent 在跑也照放：它們也站在 main 上，但「從 main 開分支」是本模板的主流程，
# 擋它等於擋掉正常開發。這一格的取捨寫在 branch-switch-gate.sh 檔頭。
reset; bs_start a1 ui-builder
expect_decision "在 main 上即使有 agent 在跑也放行" allow "$(bs 'git checkout -b feat/x')"

# ---- 不該誤擋的形狀（不帶 -b/-c 的 checkout/switch 都只是換分支或還原檔案）
reset
expect_decision "git checkout <既有分支> 不擋"    allow "$(bs 'git checkout main')"
expect_decision "git switch <既有分支> 不擋"      allow "$(bs 'git switch main')"
expect_decision "git checkout -- <file> 不擋"     allow "$(bs 'git checkout -- src/a.ts')"
expect_decision "git checkout . 不擋"             allow "$(bs 'git checkout .')"
expect_decision "git status 不擋"                 allow "$(bs 'git status')"
expect_decision "不含 git 的指令不擋"             allow "$(bs 'npm run checkout -- -b x')"
expect_decision "heredoc 內文提到指令不擋"        allow "$(bs 'cat > d.md <<EOF
開新任務前先 git checkout -b feat/x
EOF')"

# ---- 第三格：站在 topic 分支、沒有 in-flight agent → 擋一次
gitq checkout -b feat/a
reset
expect_decision "站在 topic 分支上開新分支 → 擋"  deny  "$(bs 'git checkout -b feat/x')"

reset
BS_MSG=$(bs_msg 'git checkout -b feat/x')
expect_contains "訊息講出「一個 checkout 只能站一個分支」" "一個 checkout 同時只能站一個分支" "$BS_MSG"
expect_contains "訊息給出可複製的明確基底指令" "git checkout -b feat/x main" "$BS_MSG"
expect_contains "訊息給出 worktree 的開法"     "claude --worktree feat/x"    "$BS_MSG"
expect_contains "訊息點名當前分支"             "feat/a"                     "$BS_MSG"

# deny-once：同一條分支只講一次
reset
bs 'git checkout -b feat/x' >/dev/null
expect_decision "同一條 topic 分支只擋一次"       allow "$(bs 'git checkout -b feat/y')"

# 標記記的是分支名 —— 換一條 topic 分支是新的現場，該再擋一次
gitq checkout -b feat/b
expect_decision "換一條 topic 分支重新受檢"       deny  "$(bs 'git checkout -b feat/y')"

# 回到預設分支會清掉標記，下次站上 topic 分支重新受檢
gitq checkout main
expect_decision "回到 main 放行（順手清標記）"    allow "$(bs 'git checkout -b feat/y')"
gitq checkout feat/b
expect_decision "清掉標記後再站上 topic 分支又擋" deny  "$(bs 'git checkout -b feat/y')"

# 明確帶 start-point → 基底已表達清楚，那本來就是本閘門推薦的繞法，不能反過來擋它
reset
expect_decision "git checkout -b x main（帶基底）放行" allow "$(bs 'git checkout -b feat/x main')"
expect_decision "git switch -c x main（帶基底）放行"   allow "$(bs 'git switch -c feat/x main')"

# ---- 第二格：站在 topic 分支且有 in-flight agent → 持續擋（不採 deny-once）
reset; bs_start a1 ui-builder
expect_decision "有 agent 在跑時擋"               deny  "$(bs 'git checkout -b feat/x')"
bs 'git checkout -b feat/x' >/dev/null
expect_decision "有 agent 在跑時不採 deny-once"   deny  "$(bs 'git checkout -b feat/x')"
# start-point 解決「基底錯了」，解決不了「HEAD 被搬走，站在上面的 agent 跟著被搬」
expect_decision "有 agent 在跑時帶基底也擋"       deny  "$(bs 'git checkout -b feat/x main')"

reset; bs_start a1 ui-builder; bs_start a2 debug-investigator
BS_MSG=$(bs_msg 'git checkout -b feat/x')
expect_contains "訊息說出有幾個 agent 在跑"    "2 個 subagent 還在跑" "$BS_MSG"
expect_contains "訊息點名是哪幾個 agent"       "debug-investigator"            "$BS_MSG"
expect_contains "訊息誠實說明計數可能含自己"   "你自己就是那個 subagent" "$BS_MSG"

# in-flight 的判準與 pre-agent-gate 共用同一份 lib（agent-inflight.sh）。
# 抽成共用函式之後兩邊必須看到**同一個數字**——各寫各的就是同一個坑修兩次。
expect_decision "同一份 log 下 pre-agent-gate 也擋" deny \
    "$(run pre-agent-gate.sh "$(printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"ui-builder"},"tool_use_id":"tX"}' "$SANDBOX")")"
# agent 完成後歸零 → 兩邊都放行（共用實作的 agent_id 配對沒被抽壞）
echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_complete\",\"agent_id\":\"a1\"}" >> "$BS_LOG"
echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_complete\",\"agent_id\":\"a2\"}" >> "$BS_LOG"
expect_decision "agent 全部完成後 pre-agent-gate 放行" allow \
    "$(run pre-agent-gate.sh "$(printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"ui-builder"},"tool_use_id":"tX"}' "$SANDBOX")")"
expect_decision "agent 全部完成後回到擋一次那一格" deny "$(bs 'git checkout -b feat/x')"

# ---- 逃生門
reset
expect_decision "BRANCH_SWITCH_GATE=off 關閉閘門" allow "$(bs 'git checkout -b feat/x' BRANCH_SWITCH_GATE=off)"
reset; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門"     allow "$(bs 'git checkout -b feat/x')"

# ---- 判斷不了就放行
reset
gitq checkout --detach
expect_decision "detached HEAD 放行（從那裡開分支通常是在救東西）" allow "$(bs 'git checkout -b feat/x')"
gitq checkout feat/b

BS_NOREPO=$(mktemp -d)
expect_decision "不在 git repo 裡放行" allow \
    "$(run pre-tool-use.sh \
        "$(jq -nc --arg cwd "$BS_NOREPO" --arg c 'git checkout -b feat/x' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')" \
        CLAUDE_PROJECT_DIR="$BS_NOREPO")"
rm -rf "$BS_NOREPO"

# 後面的 worktree 那組從這個 repo 開 worktree，一定要還原成 main
gitq checkout main
reset

# =========================================================================
section "pre-agent-gate.sh — 擋同時派多個無隔離 agent"
# =========================================================================
#
# 為什麼要這個閘門：沒帶 isolation 的 subagent 全部在同一個工作目錄動手，
# 兩個改到同一檔案時後寫的直接覆蓋前面的——沒有衝突提示、沒有錯誤。
# 原本的保護只有 rules/agent-orchestration.md 的一行文字（自律）。

AG_LOG="$SANDBOX/.claude/logs/agent-activity.jsonl"
WARNED_FILE="$SANDBOX/.claude/taskmaster-data/.parallel-agent-warned"
# 對應鍵是 agent_id（不是 tool_use_id）——tool_use_id 屬於「派工這次呼叫」，
# 跨不到 SubagentStop；agent_id 才是同一個 agent 從頭到尾的身分。
ag_start()    { echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"agent_id\":\"$1\"}" >> "$AG_LOG"; }
ag_complete() { echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_complete\",\"agent_id\":\"$1\"}" >> "$AG_LOG"; }
# ag <subagent_type> [isolation]
ag() {
    local iso=""
    [ -n "${2:-}" ] && iso=",\"isolation\":\"$2\""
    run pre-agent-gate.sh "$(printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"%s"%s},"tool_use_id":"tX"}' "$SANDBOX" "$1" "$iso")"
}

reset; mkdir -p "$SANDBOX/.claude/logs"
expect_decision "無 in-flight 時放行" allow "$(ag ui-builder)"

# 兩個不同 agent 都在跑 → 照擋（確認 unique 去重沒把正常情況也吃掉）
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1; ag_start a2
expect_decision "兩筆不同 agent_id 的 start → 仍擋" deny "$(ag ui-builder)"

# 同一個 agent_id 重複寫入不該被算成兩個
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1; ag_start a1; ag_complete a1
expect_decision "重複的 start 由 unique 去重（complete 後歸零）" allow "$(ag ui-builder)"

# 舊格式（只有 tool_use_id、沒有 agent_id）一律忽略，不該讓閘門誤擋
reset; mkdir -p "$SANDBOX/.claude/logs"
echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"tool_use_id\":\"old1\"}" >> "$AG_LOG"
expect_decision "升級前的舊紀錄（無 agent_id）被忽略" allow "$(ag ui-builder)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "有 1 個 in-flight 且新的無隔離 → deny" deny "$(ag ui-builder)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
ag ui-builder >/dev/null
expect_decision "同一批只擋一次（deny-once）" allow "$(ag debug-investigator)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "帶 isolation: worktree 直接放行" allow "$(ag refactor-cleaner worktree)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "帶 isolation: remote 也放行" allow "$(ag ui-builder remote)"

# in-flight 歸零 → 標記清除，下一批重新受檢
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
ag ui-builder >/dev/null                       # 第一批擋一次
ag_complete a1                              # 前一個完成
ag ui-builder >/dev/null                       # 歸零，標記應被清掉
ag_start a2                                 # 新的一批
expect_decision "下一批平行會重新被擋" deny "$(ag ui-builder)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "PARALLEL_AGENT_GATE=off 關閉閘門" allow \
    "$(run pre-agent-gate.sh "$(printf '{"cwd":"%s","tool_input":{"subagent_type":"ui-builder"}}' "$SANDBOX")" PARALLEL_AGENT_GATE=off)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門" allow "$(ag ui-builder)"

# 攔截訊息要先給一個推薦，不是把三個選項丟回去讓使用者自己判斷。
# 推薦只依兩件閘門算得出來的事：工作區乾不乾淨（**WORK_ROOT 下**的 git status）、
# plans/ 有沒有帶 `files:` 的 plan（排除 archive/）。後者為「零」時壓過前者。
#
# 算不出來就不推薦——上面所有案例的沙箱都不是 git repo，它們的攔截訊息因此一律
# 沒有推薦行，順便釘住了「沒有 git／非 repo 時安靜退回中立三選項」。
# 這三條**不能用共用的 $SANDBOX 當 repo**：前面區塊在它底下留了巢狀 git repo
# （git-backup 那組的 emptyrepo 等），`git add -A` 清不乾淨，「乾淨」那條會假失敗。
# 自己開一個獨立 root，順便不必在結束時把 $SANDBOX 的 .git 清掉。
#
# pg_setup <root> <clean|dirty> <plan|noplan>
pg_setup() {
    rm -rf "$1"
    mkdir -p "$1/.claude/logs" "$1/.claude/taskmaster-data/plans"
    git -c init.defaultBranch=main init -q "$1" >/dev/null 2>&1
    # 短命旗標與 log 在真實專案是 gitignore 的，否則閘門自己寫的檔會讓工作區變髒
    printf '.claude/logs/\n.claude/taskmaster-data/.*\n' > "$1/.gitignore"
    if [ "$3" = plan ]; then
        printf -- '---\nfiles:\n  - "src/a.ts"\n---\n' > "$1/.claude/taskmaster-data/plans/p1.md"
    else
        printf -- '---\ntitle: 沒有 files 欄\n---\n' > "$1/.claude/taskmaster-data/plans/p0.md"
    fi
    if [ "$2" = clean ]; then
        git -C "$1" add -A >/dev/null 2>&1
        git -C "$1" -c user.email=t@t -c user.name=t commit -qm base >/dev/null 2>&1
    fi
    echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"agent_id\":\"a1\"}" \
        >> "$1/.claude/logs/agent-activity.jsonl"
}
# pg_gate <root> —— 用該 root 當 CLAUDE_PROJECT_DIR 與 cwd 跑閘門，取回攔截理由
pg_gate() {
    printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"ui-builder"},"tool_use_id":"tX"}' "$1" \
        | env CLAUDE_PROJECT_DIR="$1" bash "$HOOK_DIR/pre-agent-gate.sh" 2>/dev/null \
        | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null
}

PG_RECO="$SANDBOX/pg-reco"
pg_setup "$PG_RECO" dirty plan
expect_contains "工作區不乾淨 → 推薦序列化" "推薦：序列化" "$(pg_gate "$PG_RECO")"

pg_setup "$PG_RECO" clean plan
expect_contains "工作區乾淨 → 推薦帶隔離" "推薦：帶隔離" "$(pg_gate "$PG_RECO")"

# plans/ 存在但沒有任何帶 `files:` 的檔案 → 壓成序列化（工作區乾淨也一樣），
# 且要說出是為什麼
pg_setup "$PG_RECO" clean noplan
expect_contains "沒有帶 files: 的 plan → 序列化並點出原因" \
    '序列化（選項 1）** —— `taskmaster-data/plans/` 裡**沒有任何帶' "$(pg_gate "$PG_RECO")"
rm -rf "$PG_RECO"

# ---- 讀寫衝突盲區（2026-09-16）----
#
# 原本的選項 3 寫「確認**檔案範圍不重疊**後重試即可通過」。掃描／驗證類 agent
# 的**寫入集是空的**，所以那個條件對它永遠成立——閘門親手把模型引導到錯誤結論，
# 再加上 deny-once 就放行了。兩起真實事故：auditor 讀到改到一半的產品碼回報
# 假 failed；審查類 agent 把 debug-investigator 留的 RED 測試檔刪了。
#
# 修法要釘住三件事：推薦改成序列化且理由講讀寫衝突、**收掉選項 3**、
# **不套用 deny-once**（持續擋到 in-flight 歸零或帶 isolation）。
# 一般情境的 deny-once 行為必須**完全不變**。

# ag_start_t <agent_id> <agent_type> —— 帶 agent_type 的 in-flight 紀錄
ag_start_t() {
    echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"agent_id\":\"$1\",\"agent_type\":\"$2\"}" >> "$AG_LOG"
}
ag_reason() { echo "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null; }

# in-flight 是掃描類（這次派的是普通 agent）
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 code-quality-specialist
expect_decision "in-flight 有掃描類 → 擋" deny "$(ag ui-builder)"
SCAN_MSG=$(ag_reason "$(ag ui-builder)")
expect_contains "掃描類推薦序列化"             "推薦：序列化"   "$SCAN_MSG"
expect_contains "理由講的是讀寫衝突"           "讀撞到寫"       "$SCAN_MSG"
expect_contains "附上假 failed 那起事故"       "假 failed"      "$SCAN_MSG"
expect_contains "附上 RED 測試被刪那起事故"    "刻意留紅"       "$SCAN_MSG"
expect_contains "收掉選項 3"                   "這個情境沒有第三條路" "$SCAN_MSG"
case "$SCAN_MSG" in
    *"確認範圍無交集後重試"*) ng "掃描類不得出現選項 3 的原文" "（不出現）" "出現了" ;;
    *) ok "掃描類不得出現選項 3 的原文" ;;
esac
expect_contains "掃描類註明不採 deny-once"     "不採 deny-once" "$SCAN_MSG"

# 不套用 deny-once：連續三次都要擋（一般情境第二次就放行）
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 security-infrastructure-auditor
ag ui-builder >/dev/null
ag ui-builder >/dev/null
expect_decision "掃描類不套用 deny-once（第三次仍擋）" deny "$(ag ui-builder)"

# 這次要派的是掃描類（in-flight 是普通 agent）
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 ui-builder
expect_decision "要派的是掃描類 → 擋" deny "$(ag test-automation-engineer)"
ag test-automation-engineer >/dev/null
expect_decision "要派的是掃描類 → 不套用 deny-once" deny "$(ag e2e-validation-specialist)"
expect_contains "訊息點名這次要派的掃描類 agent" "e2e-validation-specialist" \
    "$(ag_reason "$(ag e2e-validation-specialist)")"

# 兩個出口：帶 isolation、或 in-flight 歸零。少了任何一個這個閘門會鎖死。
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 refactor-cleaner
expect_decision "掃描類帶 isolation 仍直接放行" allow "$(ag code-quality-specialist worktree)"
ag_complete a1
expect_decision "in-flight 歸零後放行"          allow "$(ag code-quality-specialist)"

# 一般情境**完全不變**：三個選項都在、deny-once 照舊
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 ui-builder
NORM_MSG=$(ag_reason "$(ag debug-investigator)")
expect_contains "一般情境仍是三個選擇"         "三個選擇"               "$NORM_MSG"
expect_contains "一般情境保留選項 3"           "確認範圍無交集後重試"   "$NORM_MSG"
expect_contains "一般情境仍是 deny-once"       "本批只擋這一次"         "$NORM_MSG"
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 ui-builder
ag debug-investigator >/dev/null
expect_decision "一般情境 deny-once 不變（第二次放行）" allow "$(ag general-purpose)"

# 舊格式（無 agent_type）不能讓 in-flight 計數消失——jq 把它印成 "-" 而不是空行
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_contains "無 agent_type 的 in-flight 仍算 1 個" "已經有 1 個" "$(ag_reason "$(ag ui-builder)")"

# =========================================================================
section "agent-monitor.sh × pre-agent-gate.sh — 非同步派工的完成時機"
# =========================================================================
#
# 為什麼要這組：閘門本身邏輯一直是對的，錯的是它讀的那本帳。
# agent_complete 曾由 PostToolUse(Agent) 寫，而 Agent 工具是**非同步**的——
# 呼叫立刻返回 {"isAsync":true,"status":"async_launched"}。實測 start→complete
# 間隔 2 秒，那個 agent 實際跑了 44 分鐘。於是 in-flight 永遠是 0，
# **閘門從裝上去那天就沒攔截過任何一次**，而它只在攔截時才寫 log，所以無聲無息。
#
# 這組不造假 JSONL，一律走真的 agent-monitor.sh，payload 用實測的欄位形狀。
# 上面那組只測「閘門怎麼讀帳」，這組測「帳記得對不對」——bug 在後者。

am_pre() {
    run agent-monitor.sh "$(jq -nc --arg t "$1" '{
        hook_event_name:"PreToolUse", tool_name:"Agent", session_id:"s1",
        tool_use_id:"tu-pre", tool_input:{subagent_type:$t,description:"d",prompt:"p"}}')"
}
# am_post_async <subagent_type> <agent_id> —— 派工返回（agent 才剛開始跑）
am_post_async() {
    run agent-monitor.sh "$(jq -nc --arg t "$1" --arg a "$2" '{
        hook_event_name:"PostToolUse", tool_name:"Agent", session_id:"s1",
        tool_use_id:("tu-"+$a), tool_input:{subagent_type:$t,description:"d",prompt:"p"},
        tool_response:{isAsync:true,status:"async_launched",agentId:$a}}')"
}
# am_post_sync <subagent_type> <tool_use_id> —— 同步完成（tool_response 沒有 agentId）
am_post_sync() {
    run agent-monitor.sh "$(jq -nc --arg t "$1" --arg u "$2" '{
        hook_event_name:"PostToolUse", tool_name:"Agent", session_id:"s1",
        tool_use_id:$u, tool_input:{subagent_type:$t,description:"d"},
        tool_response:{response:"{\"status\":\"completed\"}"}}')"
}
# am_stop <agent_id> [agent_type] —— agent 真正結束
am_stop() {
    run agent-monitor.sh "$(jq -nc --arg a "$1" --arg t "${2-}" '{
        hook_event_name:"SubagentStop", session_id:"s1", agent_id:$a, agent_type:$t,
        last_assistant_message:"done"}')"
}
ag_events() { jq -rs '[.[]|.event]|join(",")' "$AG_LOG" 2>/dev/null; }

# PreToolUse 不寫帳：agentId 只在 PostToolUse 拿得到，寫在 PreToolUse 就配不到
# SubagentStop。這也是為什麼閘門不再需要「排除自己那一筆」——它跑在 PreToolUse，
# 帳上不可能有自己。
reset; mkdir -p "$SANDBOX/.claude/logs"; am_pre ui-builder >/dev/null
[ -s "$AG_LOG" ] \
    && ng "PreToolUse 不寫 JSONL agent_start" "空的 jsonl" "$(ag_events)" \
    || ok "PreToolUse 不寫 JSONL agent_start"
expect_decision "只派一個 agent 時不擋（自己不算 in-flight）" allow "$(ag ui-builder)"
[ -f "$WARNED_FILE" ] \
    && ng "誤擋不該吃掉 deny-once 額度" "無 warned 標記" "有標記" \
    || ok "誤擋不該吃掉 deny-once 額度"

# 這是本 bug 的核心案例：agent 還在跑（有 PostToolUse、沒有 SubagentStop）
reset; mkdir -p "$SANDBOX/.claude/logs"; am_post_async ui-builder ag001 >/dev/null
expect_contains "派工返回只記 agent_start" "agent_start" "$(ag_events)"
expect_decision "真的 in-flight（未收到 SubagentStop）→ 再派一個要擋" deny "$(ag debug-investigator)"

reset; mkdir -p "$SANDBOX/.claude/logs"
am_post_async ui-builder ag001 >/dev/null; am_stop ag001 ui-builder >/dev/null
expect_decision "收到 SubagentStop 後 → 再派一個放行" allow "$(ag debug-investigator)"

# 實測會收到 agent_type 為空字串的 SubagentStop。不能因此跳過寫入——
# 漏一筆 complete 就讓那個 agent 的 in-flight 永遠不歸零，閘門會從此誤擋每一次委派。
reset; mkdir -p "$SANDBOX/.claude/logs"
am_post_async ui-builder ag002 >/dev/null; am_stop ag002 "" >/dev/null
expect_decision "agent_type 空字串的 SubagentStop 仍能沖銷 in-flight" allow "$(ag debug-investigator)"

# 實測也會收到這個 session 從沒派過的 agent_id
reset; mkdir -p "$SANDBOX/.claude/logs"; am_stop never-dispatched Explore >/dev/null
expect_decision "沒見過的 agent_id 的 SubagentStop → 不爆炸、計數不轉負" allow "$(ag ui-builder)"
reset; mkdir -p "$SANDBOX/.claude/logs"
am_post_async ui-builder ag003 >/dev/null; am_stop never-dispatched Explore >/dev/null
expect_decision "多餘的 complete 不會沖掉別人的 in-flight" deny "$(ag debug-investigator)"

# 同步完成的 agent：PostToolUse 觸發時它已經結束，start/complete 一起寫，淨變化 0
reset; mkdir -p "$SANDBOX/.claude/logs"; am_post_sync Explore tu9 >/dev/null
expect_contains "同步完成同時記 start 與 complete" "agent_start,agent_complete" "$(ag_events)"
expect_decision "同步完成的 agent 不算 in-flight" allow "$(ag ui-builder)"

# 既有行為不能壞：帶隔離的一律放行（有自己的 checkout 與分支）
reset; mkdir -p "$SANDBOX/.claude/logs"; am_post_async ui-builder ag004 >/dev/null
expect_decision "真 in-flight 下帶 isolation: worktree 仍放行" allow "$(ag refactor-cleaner worktree)"

# 不是 Agent 工具的 PostToolUse 不該進這本帳
reset; mkdir -p "$SANDBOX/.claude/logs"
run agent-monitor.sh '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/p/a.ts"}}' >/dev/null
expect_empty "非 Agent 工具不寫 agent 帳" "$(ag_events)"

# =========================================================================
section "resolve-roots.sh — CLAUDE_PROJECT_DIR 未設時的 fallback"
# =========================================================================
#
# 為什麼要這組：其餘 163 個案例的 run() 一律帶 CLAUDE_PROJECT_DIR="$SANDBOX"，
# 所以 fallback 分支從來沒被測到。它曾經寫錯——在被 source 的檔案裡
# ${BASH_SOURCE[0]} 指的是 lib/resolve-roots.sh 自己，`../..` 只回到 `.claude/`，
# 讓所有狀態檔掉進 `.claude/.claude/taskmaster-data/`。
# 平常有環境變數遮住，**CI 裡沒設**，所以那條路徑必須有測試釘住。

reset
# 直接 source 這支 lib，把 MAIN_ROOT 解出來比對
RR_OUT=$(env -u CLAUDE_PROJECT_DIR bash -c '
    source "'"$HOOK_DIR"'/lib/resolve-roots.sh" 2>/dev/null || exit 1
    resolve_roots ""
    printf "%s" "$MAIN_ROOT"
' 2>/dev/null)
RR_EXPECT=$(cd "$HOOK_DIR/../.." && pwd)
if [ "$RR_OUT" = "$RR_EXPECT" ]; then ok "無 CLAUDE_PROJECT_DIR 時 MAIN_ROOT = repo root"
else ng "無 CLAUDE_PROJECT_DIR 時 MAIN_ROOT = repo root" "$RR_EXPECT" "${RR_OUT:-（空）}"; fi

# 反向驗證：不該解到 .claude/（那正是修掉的 bug）
case "$RR_OUT" in
    */.claude) ng "MAIN_ROOT 不該停在 .claude/" "repo root" "$RR_OUT" ;;
    *) ok "MAIN_ROOT 不該停在 .claude/" ;;
esac

# 狀態檔落點：不能出現 .claude/.claude/
RR_DATA=$(env -u CLAUDE_PROJECT_DIR bash -c '
    source "'"$HOOK_DIR"'/lib/resolve-roots.sh" 2>/dev/null || exit 1
    resolve_roots ""
    printf "%s" "$WORK_CLAUDE/taskmaster-data"
' 2>/dev/null)
case "$RR_DATA" in
    *.claude/.claude/*) ng "狀態檔落點不含 .claude/.claude/" "單層" "$RR_DATA" ;;
    *) ok "狀態檔落點不含 .claude/.claude/" ;;
esac

# 帶 cwd（非 worktree）時行為不變
RR_CWD=$(env -u CLAUDE_PROJECT_DIR bash -c '
    source "'"$HOOK_DIR"'/lib/resolve-roots.sh" 2>/dev/null || exit 1
    resolve_roots "{\"cwd\":\"'"$RR_EXPECT"'\"}"
    printf "%s|%s" "$MAIN_ROOT" "$IN_WORKTREE"
' 2>/dev/null)
if [ "$RR_CWD" = "$RR_EXPECT|0" ]; then ok "無環境變數但有 cwd 時仍解到 repo root 且非 worktree"
else ng "無環境變數但有 cwd 時仍解到 repo root 且非 worktree" "$RR_EXPECT|0" "${RR_CWD:-（空）}"; fi

# =========================================================================
section "/suggest-mode 是專案級設定 — worktree 內也要吃主 checkout 的值"

# 隔離表一直把 .suggest-mode 列為 MAIN_CLAUDE 的專案級設定，但這三支曾經只讀
# WORK_CLAUDE，於是主 checkout 打了 /suggest-mode off 也關不掉 worktree 裡的閘門與注入
# （你會以為自己關了）。pre-tool-use.sh 早就是「MAIN 優先、WORK 當 fallback」，
# 這三支改成同一個寫法。每組都配一條對照：沒設 off 時要照樣出聲，否則測的是別的東西。
#
# worktree 只開一次共用——每條各開一個要跑 7 次 git init + worktree add，在 Windows 上
# 是整套測試最慢的一段。代價是必須自己把跨案例的狀態清乾淨，而那正好堵掉三個假通過：
#   .parallel-agent-warned  deny-once：第 1 條擋下後留的旗標會讓第 2 條放行（不是因為修對了）
#   .doc-impact             post-write 每任務只提醒一次：最後一條可能只是被對照那條吃掉
#   .merge-pending          同理
# 原本每條重建 worktree 剛好掩蓋了這三件事。

wt_agent() { jq -nc --arg c "$1" '{tool_name:"Agent", cwd:$c, tool_input:{subagent_type:"ui-builder"}}'; }
wt_bash()  { jq -nc --arg c "$1" '{tool_name:"Bash",  cwd:$c, tool_input:{command:"git merge feature/x"}}'; }
wt_write() { jq -nc --arg c "$1" --arg f "$2" '{tool_name:"Write", cwd:$c, tool_input:{file_path:$f}}'; }

# 清掉會跨案例污染的狀態，但保留 worktree 本身
wt_clear() {
    rm -f "$SM_FILE" \
          "$WT/.claude/taskmaster-data/.suggest-mode" \
          "$WT/.claude/taskmaster-data/.parallel-agent-warned" \
          "$WT/.claude/taskmaster-data/.merge-pending" \
          "$WT/.claude/taskmaster-data/.doc-impact" 2>/dev/null || true
    : > "$AG_LOG" 2>/dev/null || true
}

setup_worktree

wt_clear; ag_start a1
expect_decision "（對照）worktree 沒設 off 時平行閘門仍擋" deny \
    "$(run pre-agent-gate.sh "$(wt_agent "$WT")")"

wt_clear; ag_start a1; echo off > "$SM_FILE"
expect_decision "主 checkout 的 off 關得掉 worktree 的平行閘門" allow \
    "$(run pre-agent-gate.sh "$(wt_agent "$WT")")"

wt_clear; ag_start a1; echo off > "$WT/.claude/taskmaster-data/.suggest-mode"
expect_decision "worktree 自己的 off 仍有效（fallback 沒壞）" allow \
    "$(run pre-agent-gate.sh "$(wt_agent "$WT")")"

wt_clear
out=$(run post-bash.sh "$(wt_bash "$WT")" MERGE_REFLOG_CHECK=off)
[ -n "$out" ] && ok "（對照）worktree 沒設 off 時 post-bash 仍出聲" \
              || ng "（對照）worktree 沒設 off 時 post-bash 仍出聲" "有輸出" "空的"

wt_clear; echo off > "$SM_FILE"
expect_empty "主 checkout 的 off 關得掉 worktree 的合併偵測" \
    "$(run post-bash.sh "$(wt_bash "$WT")" MERGE_REFLOG_CHECK=off)"

wt_clear
out=$(run post-write.sh "$(wt_write "$WT" "$WT/src/api/x.ts")")
[ -n "$out" ] && ok "（對照）worktree 沒設 off 時 post-write 仍出聲" \
              || ng "（對照）worktree 沒設 off 時 post-write 仍出聲" "有輸出" "空的"

wt_clear; echo off > "$SM_FILE"
expect_empty "主 checkout 的 off 關得掉 worktree 的文件債偵測" \
    "$(run post-write.sh "$(wt_write "$WT" "$WT/src/api/x.ts")")"

# =========================================================================
section "2026-10-20 複查修正 — 閘門失效、誤擋、接力注入"
# =========================================================================
#
# 每一條都是獨立複查確認成立的問題。前三條是「閘門安靜地不攔」，最該先修。

NOW_TS() { date '+%Y-%m-%d %H:%M:%S'; }
AGL="$SANDBOX/.claude/logs/agent-activity.jsonl"
ag2() { # <subagent_type> [isolation] —— 派工 PreToolUse
    local iso=""; [ -n "${2:-}" ] && iso=",\"isolation\":\"$2\""
    run pre-agent-gate.sh "$(printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"%s"%s},"tool_use_id":"tX"}' "$SANDBOX" "$1" "$iso")"
}
st2() { # <agent_id> <agent_type> [isolation]
    mkdir -p "$SANDBOX/.claude/logs"
    jq -nc --arg ts "$(NOW_TS)" --arg a "$1" --arg t "$2" --arg i "${3:-}" \
        '{timestamp:$ts,event:"agent_start",agent_id:$a,agent_type:$t,isolation:$i}' >> "$AGL"
}

# ---- #1 in-flight 計數遇壞行不能歸零 ----
# 2026-10-16 真實 log 第 992 行只剩 `ord"}`（併發寫入截斷）。`jq -s` 整檔吞 → parse error
# → 計數 0 → 兩道閘門一起靜默失效。
reset; st2 a1 ui-builder; echo 'ord"}' >> "$AGL"
printf '{\n  "timestamp": "x",\n  "event": "agent_start"\n}\n' >> "$AGL"   # 升級前的多行舊格式
expect_decision "jsonl 有壞行時 in-flight 照算（仍擋）" deny "$(ag2 debug-investigator)"
reset; echo 'garbage' >> "$AGL"; st2 a1 ui-builder
expect_decision "壞行在前、正常紀錄在後也照算" deny "$(ag2 debug-investigator)"

# ---- #2 帶隔離、定義自帶隔離、唯讀名單 ----
reset; st2 a1 ui-builder worktree
expect_decision "in-flight 帶 isolation: worktree 不算進計數" allow "$(ag2 debug-investigator)"
reset; st2 a1 ui-builder remote
expect_decision "in-flight 帶 isolation: remote 不算進計數" allow "$(ag2 debug-investigator)"
reset; mkdir -p "$SANDBOX/.claude/agents"
printf -- '---\nname: refactor-cleaner\ntools: ["Read","Bash"]\nisolation: worktree\n---\n\n正文 isolation: none\n' > "$SANDBOX/.claude/agents/refactor-cleaner.md"
st2 a1 refactor-cleaner
expect_decision "in-flight 的定義檔自帶 isolation: worktree → 不算" allow "$(ag2 debug-investigator)"
reset; mkdir -p "$SANDBOX/.claude/agents"
printf -- '---\nname: refactor-cleaner\nisolation: worktree\n---\n' > "$SANDBOX/.claude/agents/refactor-cleaner.md"
st2 a1 ui-builder
expect_decision "要派的 agent 定義檔自帶隔離 → 視同帶隔離放行" allow "$(ag2 refactor-cleaner)"
reset; mkdir -p "$SANDBOX/.claude/agents"
printf -- '---\nname: x\n---\n\nisolation: worktree\n' > "$SANDBOX/.claude/agents/ui-builder.md"
st2 a1 debug-investigator
expect_decision "isolation 寫在 frontmatter 之外不算（只看第一個區塊）" deny "$(ag2 ui-builder)"
for ro in Explore Plan claude-code-guide planner architect; do
    reset; st2 a1 ui-builder
    expect_decision "唯讀名單：要派 $ro → 放行" allow "$(ag2 "$ro")"
    reset; st2 a1 "$ro"
    expect_decision "唯讀名單：在跑的 $ro 不算 in-flight" allow "$(ag2 ui-builder)"
done
reset; st2 a1 ui-builder
expect_decision "general-purpose 不在唯讀名單（仍擋）" deny "$(ag2 general-purpose)"
expect_eq "唯讀名單恰好是這五個（退場的流程模板 agent 已移除）" "Explore Plan claude-code-guide planner architect" \
    "$(source "$HOOK_DIR/lib/agent-inflight.sh"; printf '%s' "$AGENT_INFLIGHT_READONLY")"
reset; st2 a1 planner; st2 a2 code-quality-specialist
expect_decision "唯讀 agent 不會讓掃描類的讀寫衝突消失" deny "$(ag2 ui-builder)"
# branch-switch-gate 用同一個 lib，自動受惠
BSW="$SANDBOX/bsw-repo"; rm -rf "$BSW"
git -c init.defaultBranch=main init -q "$BSW" >/dev/null 2>&1
git -C "$BSW" -c user.email=t@t -c user.name=t commit -q --allow-empty -m c >/dev/null 2>&1
git -C "$BSW" checkout -q -b feat/topic >/dev/null 2>&1
mkdir -p "$BSW/.claude/logs"
jq -nc --arg ts "$(NOW_TS)" '{timestamp:$ts,event:"agent_start",agent_id:"r1",agent_type:"planner"}' >> "$BSW/.claude/logs/agent-activity.jsonl"
bsw() { jq -nc --arg cwd "$BSW" --arg c "$1" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}' \
        | env CLAUDE_PROJECT_DIR="$BSW" bash "$HOOK_DIR/pre-tool-use.sh" 2>/dev/null; }
case "$(bsw 'git checkout -b feat/x' | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')" in
    *"subagent 還在跑"*) ng "branch-switch：在跑的只有唯讀 agent → 不走「持續擋」那一格" "deny-once 那一格" "持續擋" ;;
    *) ok "branch-switch：在跑的只有唯讀 agent → 不走「持續擋」那一格" ;;
esac
rm -rf "$BSW"

# agent-monitor 把派工參數的 isolation 記進帳
reset; mkdir -p "$SANDBOX/.claude/logs"
run agent-monitor.sh "$(jq -nc '{hook_event_name:"PostToolUse",tool_name:"Agent",session_id:"s",tool_use_id:"t",
    tool_input:{subagent_type:"ui-builder",isolation:"worktree"},tool_response:{isAsync:true,status:"async_launched",agentId:"iso1"}}')" >/dev/null
expect_eq "agent_start 記下 isolation" "worktree" "$(jq -r 'select(.event=="agent_start") | .isolation' "$AGL" 2>/dev/null)"

# ---- #3 效能：沒有 git 的指令跳過四道 git 閘門；lib 單獨用時仍自己切段 ----
reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] pending' > "$MP_FILE"
expect_decision "不含 git 的指令完全不進 git 閘門" allow "$(bg 'npm test -- --grep merge')"
( source "$HOOK_DIR/lib/merge-gate.sh"; unset CMD_SEGS
  out=$(merge_gate "git rebase main" "$SANDBOX/.claude/taskmaster-data")
  case "$out" in *deny*) exit 0 ;; *) exit 1 ;; esac ) \
    && ok "lib 單獨呼叫（沒有 CMD_SEGS）仍自己切段" \
    || ng "lib 單獨呼叫（沒有 CMD_SEGS）仍自己切段" "deny" "沒擋"
SETTINGS="$HOOK_DIR/../settings.json"
expect_eq "pre-tool-use 的 timeout 是 30（超時＝放行，不能貼著實測值）" "30" \
    "$(jq -r '[.hooks.PreToolUse[].hooks[] | select(.command | contains("pre-tool-use.sh")) | .timeout][0]' "$SETTINGS")"

# ---- #4 PowerShell 工具也要過 git 閘門 ----
psg() { run pre-tool-use.sh "$(jq -nc --arg cwd "$SANDBOX" --arg c "$1" '{cwd:$cwd,tool_name:"PowerShell",tool_input:{command:$c}}')"; }
reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] pending' > "$MP_FILE"
expect_decision "PowerShell 的 git rebase 也被合併閘門擋" deny "$(psg 'git rebase main')"
reset
expect_decision "PowerShell 的裸 cd 不擋（那條只管 Bash）" allow "$(psg 'cd C:\temp')"
for ev in PreToolUse PostToolUse PostToolUseFailure; do
    if jq -e --arg ev "$ev" '[.hooks[$ev][]? | select((.matcher // "") | split("|") | index("PowerShell"))] | length > 0' "$SETTINGS" >/dev/null 2>&1; then
        ok "settings.json 的 $ev 有接 PowerShell"
    else ng "settings.json 的 $ev 有接 PowerShell" "matcher 含 PowerShell" "沒有"; fi
done

# ---- #5 判級訊息寫出**這個 checkout** 的模式檔實際路徑 ----
reset
M5=$(run pre-tool-use.sh "$(w /p/src/a.ts)" | jq -r '.hookSpecificOutput.permissionDecisionReason')
expect_contains "判級訊息寫出展開後的模式檔路徑" "$SANDBOX/.claude/taskmaster-data/.current-task-mode" "$M5"
case "$M5" in *'$CLAUDE_PROJECT_DIR'*) ng "判級訊息不再寫未展開的 \$CLAUDE_PROJECT_DIR" "不含" "含" ;;
              *) ok "判級訊息不再寫未展開的 \$CLAUDE_PROJECT_DIR" ;; esac

# ---- #6 模式檔不在 → 依契約從 plan 還原 ----
PL="$SANDBOX/.claude/taskmaster-data/plans"
reset; mkdir -p "$PL"; echo "13.2" > "$SANDBOX/.claude/taskmaster-data/.current-task"
printf -- '---\ntitle: x\nmode: critical\n---\n' > "$PL/13.2-login.md"
R6=$(run pre-tool-use.sh "$(w /p/src/a.ts)")
expect_decision "有 .current-task＋plan 的 mode → 放行" allow "$R6"
expect_contains "放行時告知已從 plan 還原" "已從 plan 還原任務模式 mode=critical" "$R6"
expect_eq "模式檔被寫回 plan 的值" "critical" "$(cat "$MODE_FILE" 2>/dev/null)"
reset; mkdir -p "$PL"; echo "adhoc-2026-10-20-fix-login" > "$SANDBOX/.claude/taskmaster-data/.current-task"
printf -- '---\nmode: quick\n---\n' > "$PL/adhoc-2026-10-20-fix-login.md"
echo standard > "$MODE_FILE"; touch -d '9 hours ago' "$MODE_FILE"
expect_decision "TTL 過期後從 ad-hoc plan 還原（不變相重新判級）" allow "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"
expect_eq "還原的是 plan 的值，不是過期前的值" "quick" "$(cat "$MODE_FILE" 2>/dev/null)"
reset; mkdir -p "$PL/archive"; echo "13.2" > "$SANDBOX/.claude/taskmaster-data/.current-task"
printf -- '---\nmode: quick\n---\n' > "$PL/archive/13.2-old.md"
expect_decision "archive/ 裡的 plan 不算" deny "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"
reset; mkdir -p "$PL"; echo "13.2" > "$SANDBOX/.claude/taskmaster-data/.current-task"
printf -- '---\nmode: fast\n---\n' > "$PL/13.2.md"
expect_decision "plan 的 mode 不是三者之一 → 照舊擋" deny "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"
reset
expect_decision "沒有 .current-task → 照舊擋" deny "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"

# ---- #7 merge-gate 改用切段，不再誤擋 ----
bgj() { run pre-tool-use.sh "$(jq -nc --arg cwd "$SANDBOX" --arg c "$1" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')"; }
reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] pending' > "$MP_FILE"
expect_decision "待驗證期間 git merge-base 放行" allow "$(bgj 'git merge-base HEAD main')"
expect_decision "待驗證期間 git log | grep \"git merge\" 放行" allow "$(bgj 'git log --oneline | grep "git merge"')"
expect_decision "待驗證期間 commit 訊息提到 git merge 放行" allow "$(bgj 'git commit -m "docs: git merge 說明"')"
expect_decision "--abort 之後鏈上真的合併仍擋（逐段判斷）" deny "$(bgj 'git merge --abort && git rebase main')"

# ---- #8 / #16 真的 repo：reflog 判斷合併有沒有發生、合併帶回文件債 ----
GR2="$SANDBOX/merge-repo"; rm -rf "$GR2"; mkdir -p "$GR2"
gr2() { git -C "$GR2" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
gr2 init -q -b main; echo a > "$GR2/README.md"; gr2 add -A; gr2 commit -qm base
gr2 checkout -q -b feat; mkdir -p "$GR2/src/api" "$GR2/src/ui"
echo x > "$GR2/src/api/users.ts"; echo y > "$GR2/src/ui/button.css"; echo t > "$GR2/src/api/users.test.ts"
gr2 add -A; gr2 commit -qm feat; gr2 checkout -q main
gr2 merge --no-ff -m "merge: feat" feat
pbr() { # <event: ok|fail> <command> [ENV=VAL…] —— 帶 cwd 的真實形狀（不關 reflog 檢查）
    local ev="$1" c="$2"; shift 2
    if [ "$ev" = ok ]; then
        run post-bash.sh "$(jq -nc --arg d "$GR2" --arg c "$c" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$d,tool_input:{command:$c},tool_response:{stdout:"",stderr:""}}')" "$@"
    else
        run post-bash.sh "$(jq -nc --arg d "$GR2" --arg c "$c" '{hook_event_name:"PostToolUseFailure",tool_name:"Bash",cwd:$d,tool_input:{command:$c},error:"Exit code 1"}')" "$@"
    fi
}
DI_F="$SANDBOX/.claude/taskmaster-data/.doc-impact"
reset
OUT16=$(pbr ok 'git merge --no-ff -m "merge: feat" feat')
mp_has "真的合併成功 → 記待驗證" '[merge] feat'
if grep -qxF 'src/api/users.ts' "$DI_F" 2>/dev/null; then ok "合併帶進的 API 檔補進 .doc-impact"
else ng "合併帶進的 API 檔補進 .doc-impact" "src/api/users.ts" "$(cat "$DI_F" 2>/dev/null)"; fi
if grep -qE 'button\.css|users\.test\.ts|README' "$DI_F" 2>/dev/null; then
    ng "非文件對象（樣式、測試、README）不進 .doc-impact" "只有 users.ts" "$(cat "$DI_F")"
else ok "非文件對象（樣式、測試、README）不進 .doc-impact"; fi
expect_contains "合併成功訊息提到補進的文件債" "已補進" "$OUT16"
reset; pbr ok 'git merge --no-ff -m "merge: feat" feat' DOC_SYNC_GATE=off >/dev/null
[ -s "$DI_F" ] && ng "DOC_SYNC_GATE=off 時合併不補 .doc-impact" "空" "$(cat "$DI_F")" \
               || ok "DOC_SYNC_GATE=off 時合併不補 .doc-impact"
# 合併之後又有別的 commit → reflog 最新一筆不是合併 → 這次失敗的 merge 沒發生
gr2 commit -q --allow-empty -m later
reset; pbr fail 'git merge --no-ff no-such-branch' >/dev/null
mp_empty "失敗且 reflog 最新不是合併 → 不記（分支名打錯）"
# 成功事件不查 reflog（2026-10-21）：查了會連 merge --squash／--no-commit 一起濾掉（見 #18）。
# 代價是這種「; 吃掉失敗」的形狀會多記一筆——多跑一次 /verify，方向偏多記。
reset; pbr ok 'git merge --no-ff no-such-branch; echo done' >/dev/null
mp_has "整條成功（; 吃掉失敗）→ 照舊記（成功事件不查 reflog）" '[merge] no-such-branch'
reset; pbr fail 'git merge --no-ff no-such-branch' MERGE_REFLOG_CHECK=off >/dev/null
mp_has "MERGE_REFLOG_CHECK=off 恢復一律記" '[merge] no-such-branch'
# 合併真的成功、是鏈在後面的指令失敗 → reflog 證實 → 記，且訊息講清楚
gr2 checkout -q -b feat2; echo z > "$GR2/src/api/orders.ts"; gr2 add -A; gr2 commit -qm feat2; gr2 checkout -q main
gr2 merge --no-ff -m "merge: feat2" feat2
reset; OUT8=$(pbr fail 'git merge --no-ff -m "merge: feat2" feat2 && false')
mp_has "失敗事件但 reflog 證實合併已發生 → 記" '[merge] feat2'
expect_contains "訊息說明合併本身已完成" "合併本身已經完成" "$OUT8"
# ---- #18 merge --squash 成功不動 HEAD、不留合併類 reflog，仍要記（2026-10-21 審查 M2）----
gr2 checkout -q -b feat3; echo s > "$GR2/src/api/squash.ts"; gr2 add -A; gr2 commit -qm feat3; gr2 checkout -q main
gr2 merge --squash feat3
reset; pbr ok 'git merge --squash feat3' >/dev/null
mp_has "merge --squash 成功（reflog 最新是 checkout）→ 仍記待驗證" '[merge] feat3'
if grep -qxF 'src/api/squash.ts' "$DI_F" 2>/dev/null; then ok "merge --squash 帶進的 API 檔補進 .doc-impact"
else ng "merge --squash 帶進的 API 檔補進 .doc-impact" "src/api/squash.ts" "$(cat "$DI_F" 2>/dev/null)"; fi
# ---- #19 reflog 濾掉的失敗 merge 仍進連續失敗計數（2026-10-21 審查 M3：曾整支 exit 0）----
gr2 commit -qm squashed; gr2 commit -q --allow-empty -m later2
reset; pbr fail 'git merge --no-ff no-such-branch' >/dev/null
mp_empty "（前提）失敗且 reflog 最新不是合併 → 不記"
expect_eq "被濾掉的失敗 merge 仍計入 .bash-fail-streak" "1	git merge --no-ff no-such-branch" \
    "$(cat "$SANDBOX/.claude/taskmaster-data/.bash-fail-streak" 2>/dev/null | tr -d '\r')"
rm -rf "$GR2"

# ---- #11 報告稽核：agent 還沒結束就不催；refactor-cleaner 改成提醒落檔 ----
EXP="$SANDBOX/.claude/taskmaster-data/.report-expectations.jsonl"
exp_line() { # <agent> <area> <agent_id> <幾秒前>
    jq -nc --arg a "$1" --arg ar "$2" --arg id "$3" --argjson ep "$(( $(date +%s) - $4 ))" \
        '{ts:"x",epoch:$ep,agent:$a,area:$ar,agent_id:$id,notified:0}' >> "$EXP"
}
cre() { bash "$HOOK_DIR/lib/check-report-expectations.sh" "$SANDBOX/.claude" "$SANDBOX/.claude" 2>/dev/null; }
reset; mkdir -p "$SANDBOX/.claude/logs"; exp_line ui-builder quality agX 600
st2 agX ui-builder
expect_empty "agent 還沒收到 SubagentStop → 先不催報告" "$(cre)"
expect_contains "還在跑的期望原樣留著（記下 running_seen）" "running_seen" "$(cat "$EXP")"
jq -nc --arg ts "$(NOW_TS)" '{timestamp:$ts,event:"agent_complete",agent_id:"agX"}' >> "$AGL"
expect_contains "結束之後才催補寫" "ui-builder" "$(cre)"
reset; mkdir -p "$SANDBOX/.claude/logs"; exp_line ui-builder quality "" 600
expect_contains "沒有 agent_id 的期望照舊只看時間" "ui-builder" "$(cre)"
reset; mkdir -p "$SANDBOX/.claude/logs"; exp_line refactor-cleaner quality "" 600
O11=$(cre)
expect_contains "refactor-cleaner 沒檔案 → 提醒主模型從回應落檔" "最終回應" "$O11"
case "$O11" in *"完成後沒寫報告"*) ng "refactor-cleaner 不被當成缺報告" "不含缺漏措辭" "$O11" ;;
               *) ok "refactor-cleaner 不被當成缺報告" ;; esac
# post-agent-report 記期望時一起記 agent_id
reset; mkdir -p "$SANDBOX/.claude/logs"
run post-agent-report.sh "$(jq -nc --arg d "$SANDBOX" '{cwd:$d,tool_name:"Agent",tool_input:{subagent_type:"ui-builder"},tool_response:{isAsync:true,status:"async_launched",agentId:"agY"}}')" >/dev/null
expect_eq "期望帶 agent_id" "agY" "$(jq -r '.agent_id' "$EXP" 2>/dev/null)"

# ---- #13 坑閘門的 files: 樣式不被 glob 展開 ----
reset; mkdir -p "$SANDBOX/.claude/context/learned" "$SANDBOX/g13/src/x"; : > "$SANDBOX/g13/src/x/real.ts"
printf -- '---\ntitle: 星號樣式\nfiles: ["src/*/*.ts"]\nguard: g\n---\n' > "$SANDBOX/.claude/context/learned/glob.md"
echo standard > "$MODE_FILE"
expect_decision "樣式在 cwd 有同名檔時不被展開（仍命中坑閘門）" deny \
    "$(cd "$SANDBOX/g13" && run pre-tool-use.sh "$(w "$SANDBOX/src/other/b.ts")")"
rm -rf "$SANDBOX/g13"

# ---- #14 pending handoff 也從 UserPromptSubmit 注入 ----
reset; mk_handoff "h14.md" pending high
expect_contains "使用者下一句話時注入 pending 交接" "planner → ui-builder" "$(run user-prompt-submit.sh "$(p '今天天氣如何')")"
expect_contains "斜線指令也注入（交接是既成事實）" "待處理 agent 交接" "$(run user-prompt-submit.sh "$(p '/task-next')")"
expect_contains "agent 交回訊息也注入（接力的時點）" "待處理 agent 交接" "$(run user-prompt-submit.sh "$(p "$HANDBACK")")"
expect_eq "格式與 post-agent-report 一致" \
    "$(run post-agent-report.sh '{"tool_name":"Agent"}' | jq -r '.hookSpecificOutput.additionalContext' | tr -d '\r')" \
    "$(run user-prompt-submit.sh "$(p '/task-next')" | tr -d '\r')"
reset; mk_handoff "h14.md" completed high
expect_empty "沒有 pending 時不注入" "$(run user-prompt-submit.sh "$(p '/task-next')")"
reset; for i in 1 2 3 4 5 6 7; do mk_handoff "h$i.md" pending high; done
expect_contains "上限 5 筆" "偵測到 5 個" "$(run user-prompt-submit.sh "$(p '/task-next')")"

# ---- #15 跨 session 接續 ----
reset; echo "13.2" > "$SANDBOX/.claude/taskmaster-data/.current-task"
mkdir -p "$PL"; printf -- '---\nmode: critical\n---\n' > "$PL/13.2-x.md"
mkdir -p "$SANDBOX/.claude/sessions"; : > "$SANDBOX/.claude/sessions/2026-10-20-a.md"
S15=$(run session-start.sh '{}' | jq -r '.hookSpecificOutput.additionalContext')
expect_contains "開場注入進行中任務與 mode（mode 取自 plan）" "進行中任務 \`13.2\`（mode critical）" "$S15"
expect_contains "附最新 session 存檔路徑" ".claude/sessions/2026-10-20-a.md" "$S15"
reset
case "$(run session-start.sh '{}')" in *"進行中任務"*) ng "沒有 .current-task 不注入" "不含" "含" ;; *) ok "沒有 .current-task 不注入" ;; esac
reset; mkdir -p "$SANDBOX/.claude/taskmaster-data"; echo x > "$SANDBOX/.claude/taskmaster-data/.learned-candidates"
expect_contains "踩坑候選改成收尾時處理" "收尾時處理" "$(run session-start.sh '{}')"

# ---- #17 Windows 反斜線路徑的正規化 ----
reset
expect_decision "反斜線路徑的 .claude/** 仍放行" allow \
    "$(run pre-tool-use.sh "$(jq -nc --arg f 'C:\p\.claude\hooks\x.sh' '{tool_name:"Write",tool_input:{file_path:$f}}')")"
expect_decision "反斜線路徑的程式碼檔仍擋（未判級）" deny \
    "$(run pre-tool-use.sh "$(jq -nc --arg f 'C:\p\src\a.ts' '{tool_name:"Write",tool_input:{file_path:$f}}')")"

# ---- #20 branch -D 的分支名不是字面值 → 退回看 HEAD（2026-10-21 審查 H1）----
# cmd_segments 把引號內容清成 `""`；`$B`、`$(…)` 也不是分支名。曾經「查不到就當不存在」→ 全部放行。
BD="$SANDBOX/bd-repo"; rm -rf "$BD"
git -c init.defaultBranch=main init -q "$BD" >/dev/null 2>&1
bdq() { git -C "$BD" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
bdq commit --allow-empty -m c1; bdq branch feat/q
reset
expect_decision "branch -D \"feat/q\"（雙引號）→ 擋" deny "$(gbo 'git branch -D "feat/q"' "$BD")"
expect_decision "branch -D 'feat/q'（單引號）→ 擋" deny "$(gbo "git branch -D 'feat/q'" "$BD")"
expect_decision "branch -D \$B（變數）→ 擋" deny "$(gbo 'B=feat/q; git branch -D $B' "$BD")"
expect_decision "branch -D \$(…)（指令替換）→ 擋" deny "$(gbo 'git branch -D $(git branch --list "feat/*")' "$BD")"
expect_decision "字面且不存在的分支 → 仍放行" allow "$(gbo 'git branch -D no-such' "$BD")"
expect_decision "字面且存在、tip 沒 tag → 擋" deny "$(gbo 'git branch -D feat/q' "$BD")"
bdq tag backup/feat-q feat/q; bdq commit --allow-empty -m c2
expect_decision "字面且存在、tip 有 tag（HEAD 沒有）→ 放行" allow "$(gbo 'git branch -D feat/q' "$BD")"
expect_decision "引號形式退回看 HEAD：HEAD 沒 tag → 擋（即使 tip 有）" deny "$(gbo 'git branch -D "feat/q"' "$BD")"
bdq tag backup/main-head
expect_decision "引號形式退回看 HEAD：HEAD 有 tag → 放行" allow "$(gbo 'git branch -D "feat/q"' "$BD")"
rm -rf "$BD"

# ---- #21 文件影響的測試排除錨定在目錄／檔名邊界（2026-10-21 審查 M6）----
( source "$HOOK_DIR/lib/doc-impact.sh"
  for p in src/api/latest/routes.ts src/contest/api/x.ts src/inspector/routes/a.ts src/api/specification/schema.json; do
      doc_bearing "$p" && echo "IN $p" || echo "OUT $p"
  done
  for p in src/api/routes.test.ts src/api/routes.spec.ts tests/api/x.py test/api/x.py src/__tests__/api/x.ts \
           spec/api/x.rb src/api/test_users.py src/api/users_test.go src/api/fixtures/x.json; do
      doc_bearing "$p" && echo "IN $p" || echo "OUT $p"
  done ) > "$SANDBOX/di21.txt" 2>/dev/null
for p in src/api/latest/routes.ts src/contest/api/x.ts src/inspector/routes/a.ts src/api/specification/schema.json; do
    grep -qxF "IN $p" "$SANDBOX/di21.txt" && ok "路徑含 test/spec 子字串仍是文件對象：$p" \
        || ng "路徑含 test/spec 子字串仍是文件對象：$p" "IN" "$(grep -F " $p" "$SANDBOX/di21.txt")"
done
for p in src/api/routes.test.ts src/api/routes.spec.ts tests/api/x.py test/api/x.py src/__tests__/api/x.ts \
         spec/api/x.rb src/api/test_users.py src/api/users_test.go src/api/fixtures/x.json; do
    grep -qxF "OUT $p" "$SANDBOX/di21.txt" && ok "測試檔／目錄仍排除：$p" \
        || ng "測試檔／目錄仍排除：$p" "OUT" "$(grep -F " $p" "$SANDBOX/di21.txt")"
done
rm -f "$SANDBOX/di21.txt"
reset
expect_contains "post-write：src/api/latest/routes.ts 觸發文件影響提醒" "文件影響提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/src/api/latest/routes.ts")")"

# =========================================================================
section "pre-tool-use.sh — rm 權限（lib/rm-state-gate.sh）"
# =========================================================================
# 取代 settings.json 的 ask: Bash(rm:*)。三種結果：allow（只刪狀態檔）、ask（其他 rm）、
# none（只刪狀態檔但混了別的指令，交回 Claude Code 原本的流程）
reset
# rmd <指令> [cwd] [tool] [ENV=VAL ...] —— 印出 allow／ask／none
rmd() {
    local c="$1" cwd="${2-$SANDBOX}" tool="${3:-Bash}" out
    shift $(( $# < 3 ? $# : 3 ))
    out=$(run pre-tool-use.sh "$(jq -nc --arg c "$c" --arg cwd "$cwd" --arg t "$tool" '{cwd:$cwd,tool_name:$t,tool_input:{command:$c}}')" "$@")
    [ -n "$out" ] && echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' || echo none
}
TD=.claude/taskmaster-data
expect_eq "只刪狀態檔（相對路徑）→ allow"            allow "$(rmd "rm $TD/.merge-pending")"
expect_eq "只刪狀態檔（絕對路徑、-f、多個）→ allow"  allow "$(rmd "rm -f \"$SANDBOX/$TD/.doc-impact\" $TD/.doc-impact-notified")"
expect_eq "先 cd 到專案根再刪 → allow"               allow "$(rmd "cd \"$SANDBOX\" && rm $TD/.pitfall-seen" /elsewhere)"
expect_eq "cwd 在子目錄、用 ../ 相對路徑 → ask"      ask   "$(rmd "rm ../$TD/.merge-pending" "$SANDBOX/src")"
if command -v cygpath >/dev/null 2>&1; then
    expect_eq "Windows 形式的絕對路徑 → allow"       allow "$(rmd "rm \"$(cygpath -m "$SANDBOX")/$TD/.merge-pending\"")"
else
    # 補一個 ok 讓兩平台案例數相同：CI 拿 Ubuntu 的總數比對文件，文件寫的是本機 Windows 的
    ok "（沒有 cygpath，略過 Windows 路徑案例）"
fi
# 2026-10-27 使用者回報的那條：/verify 清合併閘門時串了 echo 與 git status
expect_eq "只刪狀態檔但串了其他指令 → 不表態"         none  "$(rmd "cd \"$SANDBOX\" && rm $TD/.merge-pending && echo \"[\$(date '+%Y-%m-%d')] cleared\" >> .claude/logs/hooks.log && git status -sb | head -1")"
expect_eq "刪程式碼 → ask"                            ask   "$(rmd "rm src/app.py")"
expect_eq "刪資料庫檔 → ask"                          ask   "$(rmd "rm -f data/app.db")"
expect_eq "狀態檔與程式碼一起刪 → ask"                ask   "$(rmd "rm $TD/.a && rm db.sqlite")"
expect_eq "狀態檔與程式碼在同一個 rm → ask"           ask   "$(rmd "rm $TD/.a src/x.ts")"
expect_eq "-r 刪整個目錄 → ask"                       ask   "$(rmd "rm -rf $TD")"
expect_eq "用 .. 跳出 taskmaster-data → ask"          ask   "$(rmd "rm $TD/.x/../../../src/a.py")"
expect_eq "萬用字元 → ask"                            ask   "$(rmd "rm $TD/.*")"
expect_eq "變數 → ask"                                ask   "$(rmd 'rm "$F"')"
expect_eq "指令替換 → ask"                            ask   "$(rmd 'rm $(cat list.txt)')"
expect_eq "taskmaster-data 底下不是 . 開頭的檔 → ask" ask   "$(rmd "rm $TD/wbs.md")"
expect_eq "不知道 cwd 的相對路徑 → ask"               ask   "$(rmd "rm $TD/.merge-pending" "")"
expect_eq "cd 到變數之後的相對路徑 → ask"             ask   "$(rmd "cd \$D && rm $TD/.merge-pending")"
expect_eq "heredoc 餵給 bash 的 rm → ask"             ask   "$(rmd $'bash <<EOF\nrm -rf src\nEOF')"
expect_eq "commit 訊息提到 rm → ask（寧可多問）"     ask   "$(rmd 'git commit -m "rm the old file"')"
expect_eq "echo 的參數有 rm → ask（寧可多問）"        ask   "$(rmd 'echo rm is fine')"
expect_eq "沒有 rm → 不表態"                          none  "$(rmd 'ls -la')"
expect_eq "RM_STATE_GATE=off → 不表態"               none  "$(rmd 'rm src/a.py' "$SANDBOX" Bash RM_STATE_GATE=off)"
expect_eq "PowerShell 不管 → 不表態"                  none  "$(rmd 'rm src/a.py' "$SANDBOX" PowerShell)"
expect_eq "rm 狀態檔 > 程式碼檔 → ask（會清空 src）"   ask   "$(rmd "rm $TD/.a > src/main.py")"
expect_eq "rm 狀態檔 >> 程式碼檔 → ask"               ask   "$(rmd "rm $TD/.a >> src/main.py")"
expect_eq "rm 狀態檔 1> 程式碼檔 → ask"               ask   "$(rmd "rm $TD/.a 1> src/main.py")"
expect_eq "rm 狀態檔 >src/x（黏著）→ ask"             ask   "$(rmd "rm $TD/.a >src/main.py")"
expect_eq "rm 狀態檔 2>/dev/null → allow"             allow "$(rmd "rm -f $TD/.a 2>/dev/null")"
expect_eq "rm 狀態檔 2>&1 → allow"                    allow "$(rmd "rm -f $TD/.a 2>&1")"
expect_eq "cd . > src/x 再 rm 狀態檔 → 不是 allow"   none  "$(rmd "cd . > src/main.py; rm $TD/.a")"
expect_eq "rm 在 \$() 裡 → ask"                       ask   "$(rmd 'echo "$(rm src/x)"')"
expect_eq "rm 在反引號裡 → ask"                       ask   "$(rmd 'echo `rm src/x`')"
expect_eq "rm 在 { } 裡 → ask"                        ask   "$(rmd '{ rm src/x; }')"
expect_eq "rm 在 then 後 → ask"                       ask   "$(rmd 'if true; then rm src/x; fi')"
expect_eq "rm 在 do 後 → ask"                         ask   "$(rmd 'for f in a; do rm src/x; done')"
expect_eq "\\rm → ask"                                ask   "$(rmd '\rm src/x')"
expect_eq "command rm → ask"                          ask   "$(rmd 'command rm src/x')"
expect_eq "VAR=1 rm → ask"                            ask   "$(rmd 'VAR=1 rm src/x')"
expect_eq "bash -c 'rm …' → ask"                      ask   "$(rmd "bash -c 'rm src/x'")"
expect_eq "/bin/rm → ask"                             ask   "$(rmd '/bin/rm src/x')"
expect_eq "git rm --cached → 不表態"                  none  "$(rmd 'git rm --cached src/x')"
expect_eq "git -C . rm -q 串 git status → 不表態"     none  "$(rmd 'git -C . rm -q src/x && git status')"
expect_eq "TASKMODE_GATE=off 刪程式碼仍 ask"         ask   "$(rmd 'rm src/x' "$SANDBOX" Bash TASKMODE_GATE=off)"
expect_eq "TASKMODE_GATE=off 刪狀態檔仍 allow"       allow "$(rmd "rm $TD/.a" "$SANDBOX" Bash TASKMODE_GATE=off)"
echo off > "$SM_FILE"
expect_eq ".suggest-mode=off 刪程式碼仍 ask"         ask   "$(rmd 'rm src/x')"
expect_eq ".suggest-mode=off 刪狀態檔仍 allow"       allow "$(rmd "rm $TD/.a")"
rm -f "$SM_FILE"
# scratchpad 暫存區：Claude Code 給每個 session 的暫存目錄，可帶 -rf。
# 2026-10-27 使用者回報：agent 在 scratchpad 組乾淨副本跑比對，`rm -rf $S` 每次都要人按
SP=/tmp/claude-0/-root-Projects-x/340c7bf6-7409-45d6-b9c4-648eb75579e2/scratchpad
SPW=C:/Users/U/AppData/Local/Temp/claude/D-----x/38423b36-a9a7-4bb6-b1da-62a819c8f65c/scratchpad
expect_eq "scratchpad：rm -rf 子目錄 → allow"           allow "$(rmd "rm -rf $SP/base")"
expect_eq "scratchpad：rm -rf 整個 scratchpad → allow"   allow "$(rmd "rm -rf $SP")"
expect_eq "scratchpad：Windows 路徑（含短檔名 ~1）→ allow" allow "$(rmd "rm -rf ${SPW/\/U\//\/KUANWE~1\/}/base")"
expect_eq "scratchpad：S=字面值 後 rm -rf \$S → allow"   allow "$(rmd "S=$SP/base && rm -rf \$S")"
expect_eq "scratchpad：\"\$S\" 與 \${S}/子路徑 → allow"  allow "$(rmd "S=$SP/base; rm -rf \"\$S\" \${S}/sub")"
expect_eq "scratchpad：使用者回報的整條（混了 git archive／pytest）→ 不表態" none \
    "$(rmd "S=$SP/base && rm -rf \$S && mkdir -p \$S && git archive 7357ec0 backend | tar -x -C \$S && (cd \$S && python -m pytest -q 2>&1 | tail -30)")"
expect_eq "只到 claude-<uid> 那層 → ask"                 ask   "$(rmd "rm -rf /tmp/claude-0")"
expect_eq "只到專案那層 → ask"                           ask   "$(rmd "rm -rf /tmp/claude-0/-root-Projects-x")"
expect_eq "一般 /tmp 目錄 → ask"                         ask   "$(rmd "rm -rf /tmp/foo")"
expect_eq "從 scratchpad 用 .. 跳出去 → ask"             ask   "$(rmd "rm -rf $SP/../../x")"
expect_eq "\$S/.. 跳出去 → ask"                          ask   "$(rmd "S=$SP/base && rm -rf \$S/../../..")"
expect_eq "S 設了兩次 → ask"                             ask   "$(rmd "S=$SP/base && S=/root/Projects && rm -rf \$S")"
expect_eq "S=\$(…) → ask"                                ask   "$(rmd 'S=$(pwd) && rm -rf $S')"
expect_eq "export S=… → ask"                             ask   "$(rmd "export S=$SP/base && rm -rf \$S")"
expect_eq "沒設過的 \$S → ask"                           ask   "$(rmd 'rm -rf $S')"
expect_eq "\$S/* 萬用字元 → ask"                         ask   "$(rmd "S=$SP/base && rm -rf \$S/*")"
expect_eq "值含空白 → ask"                               ask   "$(rmd "S=\"$SP/base x\" && rm -rf \$S")"
expect_eq "scratchpad 與程式碼一起刪 → ask"              ask   "$(rmd "S=$SP/base && rm -rf \$S src")"
expect_eq "狀態檔帶 -rf → ask（-r 只給暫存區）"          ask   "$(rmd "rm -rf $TD/.a")"
expect_eq "~/ 開頭 → ask"                                ask   "$(rmd 'rm -rf ~/x')"
# 審查 2026-10-27-1330 的兩個 HIGH：相對路徑不得吃 scratchpad、特殊變數讓 $S 不能信
expect_eq "cd 到 scratchpad 失敗後 rm -rf 相對路徑 → ask" ask "$(rmd "cd $SP/nonexist; rm -rf src")"
expect_eq "子 shell 裡 cd 之後 rm -rf 相對路徑 → ask"      ask "$(rmd "(cd $SP/b); rm -rf src")"
expect_eq "cd 到 scratchpad 再 rm -rf 相對路徑 → ask"      ask "$(rmd "cd $SP && rm -rf base")"
expect_eq "S= 之後設 IFS → ask"                           ask "$(rmd "S=$SP/b; IFS=/; rm -rf \$S")"
expect_eq "先設 IFS 再 S= → ask"                           ask "$(rmd "IFS=/; S=$SP/b; rm -rf \$S")"
expect_eq "子 shell 裡的 S= → ask"                         ask "$(rmd "(S=$SP/b); rm -rf \$S")"
expect_eq "條件式的 S=（false && S=…）→ ask"               ask "$(rmd "false && S=$SP/b; rm -rf \$S")"
expect_eq "S= 前面已有其他指令 → ask"                     ask "$(rmd "ls; S=$SP/b; rm -rf \$S")"
expect_eq "開頭連設兩個變數 → allow"                       allow "$(rmd "S=$SP/b; T=$SP/c; rm -rf \$S \$T")"
# symlink：scratchpad 裡指到專案的連結，刪連結底下的東西 → ask；刪連結本身 → allow（rm 不跟隨）
# Git Bash 的 ln -s 預設是複製，建不出真的 symlink 就跳過
SPL=/tmp/claude-$$/p/s1/scratchpad
mkdir -p "$SPL" "$SANDBOX/src"
if ln -s "$SANDBOX" "$SPL/link" 2>/dev/null && [ -L "$SPL/link" ]; then
    expect_eq "scratchpad 裡 symlink 底下的目錄 → ask"     ask   "$(rmd "rm -rf $SPL/link/src")"
    expect_eq "scratchpad 裡 symlink 本身 → allow"         allow "$(rmd "rm -rf $SPL/link")"
else
    # 補成同樣 2 個 ok，兩平台案例數才相同（理由同上面的 cygpath）
    ok "（建不出真的 symlink，略過：symlink 底下的目錄）"
    ok "（建不出真的 symlink，略過：symlink 本身）"
fi
rm -rf "/tmp/claude-$$"
# 容器與套件管理的 rm 子指令：舊的 Bash(rm:*) 不會問，字數規則也不能誤問
# 2026-10-27 使用者回報：`podman rm -f tmp-725-host …` 被當成看不懂的 rm
expect_eq "podman rm -f 容器（使用者回報的整條）→ 不表態" none "$(rmd 'podman rm -f tmp-725-host tmp-725-prod; podman ps -a | grep tmp-725; echo "grep_exit=$?"')"
expect_eq "docker container rm／image rm → 不表態"        none  "$(rmd 'docker container rm web && docker image rm nginx')"
expect_eq "podman --remote rm → 不表態"                  none  "$(rmd 'podman --remote rm -f x')"
expect_eq "npm rm／pnpm rm 套件 → 不表態"                none  "$(rmd 'npm rm lodash && pnpm rm -D vitest')"
expect_eq "podman volume rm（資料庫資料）→ ask"          ask   "$(rmd 'podman volume rm pgdata')"
expect_eq "docker volume rm → ask"                       ask   "$(rmd 'docker volume rm db_data')"
expect_eq "docker rm 後面接 rm -rf src → ask"            ask   "$(rmd 'docker rm -f web && rm -rf src')"
expect_eq "settings.json 已沒有 rm 的 ask 規則"       "" "$(jq -r '.permissions.ask // [] | map(select(startswith("Bash(rm"))) | .[]' "$HOOK_DIR/../settings.json")"

# =========================================================================
section "overview.sh — 專案地圖"
# =========================================================================
# 產生器在沙箱裡跑：把 overview.sh 與畫面原檔複製進沙箱的 .claude（post-write 找的是
# $MAIN_CLAUDE/scripts/overview.sh，而沙箱就是主 checkout），改原檔的測試才不會碰到真的範本。
OV_SRC="$HOOK_DIR/../scripts/overview.sh"
OV_SCAN="$HOOK_DIR/../scripts/overview-scan.sh"
OV_TPL="$HOOK_DIR/../templates/overview/index.html"
OVD="$SANDBOX/.claude/taskmaster-data"
OVO="$OVD/overview"

# 背景模式不得等腳本：放一支睡 10 秒的假腳本，hook 要遠早於它返回。
# 用獨立的子目錄，免得假腳本還在跑時後面的 reset 刪不掉它（Windows 會鎖住執行中的檔）。
# 放在本節最前面，後面的案例跑完時它早已結束。
T21="$SANDBOX/t21"
mkdir -p "$T21/.claude/scripts" "$T21/.claude/taskmaster-data"
printf '#!/bin/bash\nsleep 10\n' > "$T21/.claude/scripts/overview.sh"
echo '{"name":"t","mode":"mvp"}' > "$T21/.claude/taskmaster-data/project.json"
SECONDS=0
out=$(run post-write.sh "$(w "$T21/.claude/taskmaster-data/plans/1.1-x.md")" CLAUDE_PROJECT_DIR="$T21")
t21=$SECONDS
[ "$t21" -lt 8 ] && ok "背景模式 hook 不等產生器（${t21} 秒，假腳本睡 10 秒）" \
    || ng "背景模式 hook 不等產生器" "< 8 秒" "${t21} 秒"
expect_empty "背景模式 hook 沒有輸出" "$out"

ov_reset() {
    reset
    rm -rf "$SANDBOX/docs" "$SANDBOX/src"
    ( cd "$SANDBOX" && { [ -d .git ] || git -c init.defaultBranch=main init -q . ; } \
      && { git rev-parse -q --verify HEAD >/dev/null || { echo x > seed && git add seed \
           && git -c user.email=t@t -c user.name=t commit -qm init; }; } \
      && git worktree prune ) >/dev/null 2>&1
    mkdir -p "$SANDBOX/.claude/scripts" "$SANDBOX/.claude/templates/overview" "$SANDBOX/docs"
    cp "$OV_SRC" "$SANDBOX/.claude/scripts/overview.sh"
    cp "$OV_SCAN" "$SANDBOX/.claude/scripts/overview-scan.sh"
    cp "$OV_TPL" "$SANDBOX/.claude/templates/overview/index.html"
}
ov()      { bash "$SANDBOX/.claude/scripts/overview.sh" "$SANDBOX" >/dev/null 2>&1; }
ov_data() { sed -n 's/^window\.OVERVIEW = //; s/;$//p' "$OVO/data.js" 2>/dev/null; }
ovq()     { ov_data | jq -r "$1" 2>/dev/null; }
ov_proj() { printf '{"name":"測試專案","mode":"%s"}\n' "${1:-mvp}" > "$OVD/project.json"; }
# 架構文件：5.1 三個節點（web→api→db）、5.5 三列。$1 附加在 mermaid 內、$2 附加在模組表後
# （造不一致用）；OV_ARCH_HEAD 放在檔頭（草稿標記用）
ov_arch() {
    {
        echo "${OV_ARCH_HEAD:-}"
        echo "# 架構"; echo; echo "### 5.1 容器圖"; echo; echo '```mermaid'; echo "graph TD"
        echo '    subgraph g1["用戶端"]'; echo "        web[Web App]"; echo "    end"
        echo '    subgraph g2["服務層"]'; echo "        api[API 服務]"; echo "    end"
        echo '    subgraph g3["資料層"]'; echo "        db[(資料庫)]"; echo "    end"
        echo "    web --> api"; echo "    api --> db"
        [ -n "${1:-}" ] && echo "$1"
        echo '```'; echo; echo "### 5.5 MVP 範圍與模組清單"; echo
        echo "| id | 模組 | 路徑 | 對應 BDD | 職責 | API 設計 | 資料模型 |"
        echo "|---|---|---|---|---|---|---|"
        echo '| web | Web App | `src/web/**` | — | 前端 | — | — |'
        echo '| api | API 服務 | `src/api/**` | — | 對外 REST | — | — |'
        echo '| db | 資料庫 | `migrations/**` | — | 持久化 | — | — |'
        [ -n "${2:-}" ] && echo "$2"
    } > "$SANDBOX/docs/05_architecture.md"
}
# 每個參數一列「編號|模組|狀態」；OV_NOCOL=1 時用沒有模組欄的舊表頭
ov_wbs() {
    {
        echo "# WBS — 測試"; echo; echo "## M1 基礎"; echo
        if [ -n "${OV_NOCOL:-}" ]; then echo "| # | 任務 | 狀態 | 優先 |"; echo "|---|---|---|---|"
        else echo "| # | 任務 | 模組 | 狀態 | 優先 |"; echo "|---|---|---|---|---|"; fi
        local r id mod st
        for r in "$@"; do
            IFS='|' read -r id mod st <<< "$r"
            if [ -n "${OV_NOCOL:-}" ]; then echo "| $id | 任務 $id | $st | 高 |"
            else echo "| $id | 任務 $id | $mod | $st | 高 |"; fi
        done
    } > "$OVD/wbs.md"
}

ov_reset; ov_arch; ov_wbs "1.1|api|✅ 11-01"
ov; rc=$?
expect_eq "沒有 project.json → exit 0" 0 "$rc"
[ ! -e "$OVO" ] && [ ! -e "$OVD/overview.md" ] && ok "沒有 project.json → 不建 overview/ 也不建 overview.md（模板 repo 不被污染）" \
    || ng "沒有 project.json → 不建任何檔" "沒有 overview/、overview.md" "$(ls "$OVD")"

ov_reset; ov_proj demo; ov
expect_eq "demo → modules 為空"                 0 "$(ovq '.modules | length')"
expect_eq "demo → notices 指向 /docs-init --mvp" 1 "$(ovq '[.notices[] | select(.action == "/docs-init --mvp")] | length')"

ov_reset; ov_proj; ov_arch; ov_wbs
ov
expect_eq "三個模組、WBS 無任務 → 都是 todo" "todo todo todo" "$(ovq '[.modules[].status] | join(" ")')"
expect_contains "overview.md 含 class web todo" "class web todo" "$(cat "$OVO/overview.md" 2>/dev/null)"
expect_contains "產生的 mermaid 連線箭頭兩端留空格" "  web --> api" "$(cat "$OVO/overview.md" 2>/dev/null)"
expect_eq "版面依 5.1 群組排欄（web／api／db 各一欄）" "0 1 2" "$(ovq '[.modules[].pos.col] | map(tostring) | join(" ")')"

ov_wbs "1.1|api|✅ 11-01" "1.2|api|🔄 進行中"; ov
expect_eq "api 有 ✅ 與 🔄 → wip" wip "$(ovq '.modules[] | select(.id == "api") | .status')"

ov_wbs "1.1|api|✅ 11-01" "1.3|db|🚫 阻塞"; ov
expect_eq       "db 只有 🚫 → issue"          issue "$(ovq '.modules[] | select(.id == "db") | .status')"
expect_contains "issue 的 statusReason 含 1.3" "1.3"  "$(ovq '.modules[] | select(.id == "db") | .statusReason')"

ov_wbs "2.1|web|✅ 11-01" "2.2|web|⏭️ 跳過"; ov
expect_eq "全 ✅／⏭️（至少一個 ✅）→ done" done "$(ovq '.modules[] | select(.id == "web") | .status')"

OV_NOCOL=1 ov_wbs "1.1||✅ 11-01" "1.2||⏳ 待處理"; ov; rc=$?
expect_eq       "WBS 舊格式（沒有模組欄）→ 不報錯"        0 "$rc"
expect_eq       "沒有模組欄 → 任務全進 unmappedTasks"    "1.1 1.2" "$(ovq '.unmappedTasks | join(" ")')"
expect_contains "沒有模組欄 → notices 說明"              "WBS 沒有模組欄" "$(ovq '[.notices[].text] | join("\n")')"

# overview.md 有「## 落差」（階段 2）：api 從沒有檔變成有檔，md 本來就該變。先 commit 一個 api 的檔，
# 第二次只差在未 commit 的 new.ts，驗的才是「工作區的改動（本次改動清單）不進 md」。驗完刪掉，不留給後面的案例
mkdir -p "$SANDBOX/src/api"; echo x > "$SANDBOX/src/api/base.ts"
( cd "$SANDBOX" && git add src/api/base.ts && git -c user.email=t@t -c user.name=t commit -qm base ) >/dev/null 2>&1
ov_wbs "1.1|api|✅ 11-01"; ov; cp "$OVO/overview.md" "$SANDBOX/ov-first.md" 2>/dev/null
echo x > "$SANDBOX/src/api/new.ts"
ov
cmp -s "$SANDBOX/ov-first.md" "$OVO/overview.md" && ok "同一組輸入連跑兩次 → overview.md 相同（工作區的改動不進 md）" \
    || ng "同一組輸入連跑兩次 → overview.md 相同" "cmp 相同" "$(diff "$SANDBOX/ov-first.md" "$OVO/overview.md" | head -5)"
expect_eq "data.js 去掉賦值外殼後可被 jq 解析，schema 為 2" 2 "$(ovq '.schema')"
expect_eq "data.js 只有一句賦值（畫面靠它判斷寫到一半）" 1 "$(grep -cv '^//' "$OVO/data.js" 2>/dev/null)"
expect_eq "未追蹤的新檔歸到路徑對得上的模組" "api true" "$(ovq '.changes[] | select(.file == "src/api/new.ts") | "\(.module) \(.new)"')"
expect_eq "模組的 changed 計數" 1 "$(ovq '.modules[] | select(.id == "api") | .changed')"
( cd "$SANDBOX" && git rm -q src/api/base.ts && git -c user.email=t@t -c user.name=t commit -qm rm-base ) >/dev/null 2>&1

expect_eq "overview/.gitignore 內容恰為 *" "*" "$(cat "$OVO/.gitignore" 2>/dev/null)"
expect_eq "git status 不出現 overview/ 底下的檔" "" \
    "$(cd "$SANDBOX" && git status --porcelain --untracked-files=all 2>/dev/null | grep 'taskmaster-data/overview/' || true)"
[ -f "$OVO/overview.md" ] && [ ! -e "$OVD/overview.md" ] && ok "overview.md 寫在 overview/ 裡、舊位置 taskmaster-data/overview.md 不再產生" \
    || ng "overview.md 寫在 overview/ 裡" "overview/overview.md 有、taskmaster-data/overview.md 沒有" "$(ls "$OVD" "$OVO")"

# md.jq 失敗：兩份都保留上一版、錯誤寫進 .last-error（不再被 2>/dev/null 吞掉）。
# 用 PATH 前面的假 jq 只讓 md.jq 那一支失敗，data.js 那一支照常——這正是舊寫法會讓兩份不同步的情況。
OVFAKE="$SANDBOX/fakejq"; mkdir -p "$OVFAKE"
printf '#!/bin/bash\ncase "$*" in *md.jq*) echo "boom: md.jq 壞了" >&2; exit 5 ;; esac\nexec %q "$@"\n' "$(command -v jq)" > "$OVFAKE/jq"
chmod +x "$OVFAKE/jq"
cp "$OVO/data.js" "$SANDBOX/ov-prev.js"; cp "$OVO/overview.md" "$SANDBOX/ov-prev.md"
ov_wbs "1.1|api|✅ 11-01" "1.2|web|🚫 阻塞"
PATH="$OVFAKE:$PATH" bash "$SANDBOX/.claude/scripts/overview.sh" "$SANDBOX" >/dev/null 2>&1
cmp -s "$SANDBOX/ov-prev.js" "$OVO/data.js" && ok "md.jq 失敗 → 保留上一份 data.js（兩份不會一新一舊）" \
    || ng "md.jq 失敗 → 保留上一份 data.js" "cmp 相同" "data.js 被換成新的"
cmp -s "$SANDBOX/ov-prev.md" "$OVO/overview.md" && ok "md.jq 失敗 → 保留上一份 overview.md" \
    || ng "md.jq 失敗 → 保留上一份 overview.md" "cmp 相同" "不同或不存在"
expect_contains "md.jq 失敗 → stderr 寫進 .last-error" "boom: md.jq 壞了" "$(cat "$OVO/.last-error" 2>/dev/null)"
ov
[ ! -e "$OVO/.last-error" ] && ok "下一次成功 → .last-error 被清掉" || ng "下一次成功 → .last-error 被清掉" "沒有 .last-error" "還在"
expect_eq "下一次成功 → data.js 反映新輸入" issue "$(ovq '.modules[] | select(.id == "web") | .status')"

cmp -s "$OV_TPL" "$OVO/index.html" && ok "overview/index.html 與畫面原檔相同" \
    || ng "overview/index.html 與畫面原檔相同" "cmp 相同" "不同或不存在"
echo "<!-- v2 -->" >> "$SANDBOX/.claude/templates/overview/index.html"; ov
cmp -s "$SANDBOX/.claude/templates/overview/index.html" "$OVO/index.html" && ok "畫面原檔改了 → 下一次被覆蓋成新版" \
    || ng "畫面原檔改了 → 下一次被覆蓋成新版" "cmp 相同" "仍是舊版"
touch -d '2000-01-01' "$OVO/index.html"; touch -d '2010-01-01' "$SANDBOX/.claude/templates/overview/index.html"; ov
[ "$OVO/index.html" -nt "$SANDBOX/.claude/templates/overview/index.html" ] && ok "畫面原檔內容沒變、只有時間較新 → index.html 仍更新時間（開 session 才不會每次重產）" \
    || ng "畫面原檔內容沒變、只有時間較新 → index.html 仍更新時間" "index.html 比原檔新" "仍比原檔舊"
expect_contains "--print-path 印出 file:// 路徑" "taskmaster-data/overview/index.html" \
    "$(bash "$SANDBOX/.claude/scripts/overview.sh" --print-path "$SANDBOX" 2>/dev/null)"

# 鎖：兩支同時跑 → 結果合法、鎖不殘留；過期的鎖要接手；新鮮的鎖讓位並留下 .dirty
rm -f "$OVO/data.js"
ov & ov & wait
expect_eq "兩個 overview.sh 同時跑 → data.js 合法" 2 "$(ovq '.schema')"
[ ! -e "$OVO/.lock" ] && ok "同時跑完後鎖目錄不存在" || ng "同時跑完後鎖目錄不存在" "沒有 .lock" "還在"
rm -f "$OVO/data.js"; mkdir -p "$OVO/.lock"; echo $(( $(date +%s) - 300 )) > "$OVO/.lock/at"; ov
expect_eq "鎖超過 120 秒 → 視為過期並接手產生" 2 "$(ovq '.schema')"
# --actual 最多等 60 秒；過期門檻若不比它長，等鎖的那支會把還活著的持鎖者當成過期搶走
expect_eq "鎖的過期門檻（LOCK_STALE_SEC）比 --actual 的等待時間（60 秒）長" 1 \
    "$(awk -F= '/^LOCK_STALE_SEC=/ { print ($2 + 0 > 60) ? 1 : 0 }' "$OV_SRC")"
rm -f "$OVO/data.js" "$OVO/.dirty"; mkdir -p "$OVO/.lock"; date +%s > "$OVO/.lock/at"; ov
[ ! -e "$OVO/data.js" ] && [ -e "$OVO/.dirty" ] && ok "鎖還新 → 讓位、留下 .dirty 給持鎖者重跑" \
    || ng "鎖還新 → 讓位、留下 .dirty" "沒有 data.js、有 .dirty" "$(ls -a "$OVO")"
rm -rf "$OVO/.lock"

ov_reset; ov_proj; OV_ARCH_HEAD='<!-- overview: draft -->' ov_arch; ov_wbs
mkdir -p "$SANDBOX/src/web"; echo 'export const a = 1' > "$SANDBOX/src/web/a.ts"; echo 'export const b = 2' > "$SANDBOX/src/web/b.ts"
ov
expect_eq       "架構草稿 → 地圖照畫（由程式碼掃出）"   true "$(ovq '.modules | length > 0')"
expect_eq       "架構草稿 → architectureDraft 為 true" true "$(ovq '.project.architectureDraft')"
expect_eq       "架構草稿 → 模組名稱不取自草稿（web 是目錄名，不是「Web App」）" "web dir" \
    "$(ovq '.modules[] | select(.id == "web") | "\(.name) \(.nameSource)"')"
rm -rf "$SANDBOX/src"
expect_contains "架構草稿 → notices 為「架構草稿待確認」" "架構草稿待確認" "$(ovq '[.notices[].text] | join("\n")')"

ov_reset; ov_proj; ov_wbs
ov_arch "    api --> cache[(快取)]" '| search | 搜尋 | `src/search/**` | — | 搜尋 | — | — |'
ov
expect_eq       "5.1 有、5.5 沒有的節點照畫並標成未宣告" false "$(ovq '.modules[] | select(.id == "cache") | .declared')"
expect_contains "5.1 有、5.5 沒有 → notices 列出"        "cache" "$(ovq '[.notices[].text] | join("\n")')"
expect_eq       "5.5 有、5.1 沒有 → 放進未分組"          _ungrouped "$(ovq '.modules[] | select(.id == "search") | .group')"
expect_eq       "未分組群組存在且標為「未分組」"          未分組 "$(ovq '.groups[] | select(.id == "_ungrouped") | .label')"

ov_reset; ov_proj; ov_wbs; ov_arch "    cache -- 讀取 --> db"; ov
expect_eq "「a -- 文字 --> b」畫成連線，文字不會變成節點名稱" "1 cache" \
    "$(ovq '"\([.edges[] | select(.from == "cache" and .to == "db")] | length) \(.modules[] | select(.id == "cache") | .name)"')"

# post-write 觸發段（OVERVIEW_SYNC=1 讓它前景跑，才能斷言）
ov_reset; ov_proj; ov_arch; ov_wbs
out=$(run post-write.sh "$(w "$SANDBOX/.claude/taskmaster-data/plans/1.2-x.md")" OVERVIEW_SYNC=1)
expect_empty "寫 plan → post-write 沒有輸出" "$out"
[ -f "$OVO/data.js" ] && ok "寫 plan → data.js 被產生" || ng "寫 plan → data.js 被產生" "有 data.js" "沒有"

ov_reset; ov_proj; ov_arch; ov_wbs
run post-write.sh "$(w "$SANDBOX/src/docs/architecture.md")" OVERVIEW_SYNC=1 >/dev/null
[ ! -e "$OVO/data.js" ] && ok "docs/ 比對錨定開頭（src/docs/ 不算）" || ng "docs/ 比對錨定開頭" "沒有 data.js" "有"
run post-write.sh "$(w "$SANDBOX/.claude/taskmaster-data/plans/1.2-x.md")" OVERVIEW_SYNC=1 OVERVIEW=off >/dev/null
[ ! -e "$OVO/data.js" ] && ok "OVERVIEW=off → 不產生" || ng "OVERVIEW=off → 不產生" "沒有 data.js" "有"
echo off > "$SM_FILE"
run post-write.sh "$(w "$SANDBOX/docs/05_architecture.md")" OVERVIEW_SYNC=1 >/dev/null
[ -f "$OVO/data.js" ] && ok ".suggest-mode=off 仍會產生（圖不是建議）" || ng ".suggest-mode=off 仍會產生" "有 data.js" "沒有"

# 寫程式碼檔 → 節流重掃：替身 overview.sh 每被呼叫一次就記一行。路徑含中文與空格
PW="$SANDBOX/節流 測試"; PWO="$PW/.claude/taskmaster-data/overview"
pw_reset() {
    rm -rf "$PW"; mkdir -p "$PW/.claude/scripts" "$PW/.claude/taskmaster-data/plans"
    printf '#!/bin/bash\necho x >> "%s"\n' "$PW/calls" > "$PW/.claude/scripts/overview.sh"
    echo '{"name":"t","mode":"mvp"}' > "$PW/.claude/taskmaster-data/project.json"
    git -C "$PW" -c init.defaultBranch=main init -q >/dev/null 2>&1
}
pw_calls() { if [ -f "$PW/calls" ]; then grep -c . "$PW/calls"; else echo 0; fi; }
pw_write() { local f="$1"; shift; run post-write.sh "$(w "$PW/$f")" CLAUDE_PROJECT_DIR="$PW" OVERVIEW_SYNC=1 "$@"; }
pw_ago()   { mkdir -p "$PWO"; echo $(( $(date +%s) - $1 )) > "$PWO/.scan-at"; rm -f "$PW/calls"; }
pw_reset
out=$(pw_write src/app.py)
expect_eq "寫程式碼檔、沒有 .scan-at → 呼叫 overview.sh 1 次、主 checkout 出現 .scan-at" "1 1" \
    "$(pw_calls) $([ -f "$PWO/.scan-at" ] && echo 1 || echo 0)"
pw_ago 5; out=$(pw_write src/app.py)
expect_eq "寫程式碼檔、.scan-at 是 5 秒前 → 不呼叫、hook 沒有輸出" "0 " "$(pw_calls) $out"
pw_ago 31; pw_write src/app.py >/dev/null
expect_eq "寫程式碼檔、.scan-at 是 31 秒前 → 呼叫 1 次" 1 "$(pw_calls)"
pw_ago 5; rm -f "$PWO/.dirty"; mkdir -p "$PWO/.lock"; pw_write src/app.py >/dev/null
[ -e "$PWO/.dirty" ] && ok "節流視窗內、overview/.lock 存在 → 留下 overview/.dirty（持鎖者會再跑一輪）" \
    || ng "節流視窗內、.lock 存在 → 留下 .dirty" "有 .dirty" "$(ls -a "$PWO")"
rm -rf "$PWO/.lock"
pw_ago 5; pw_write .claude/taskmaster-data/plans/1.1-x.md >/dev/null
expect_eq "節流視窗內寫 plan → 仍會觸發（不受節流）" 1 "$(pw_calls)"
for f in .claude/scripts/x.py docs/x.py src/readme.md; do
    rm -rf "$PWO" "$PW/calls"; pw_write "$f" >/dev/null
    expect_eq "寫 $f → 不觸發" 0 "$(pw_calls)"
done
rm -rf "$PWO" "$PW/calls"; pw_write src/App.PY >/dev/null
expect_eq "寫 src/App.PY（副檔名大寫）→ 一樣觸發 1 次" 1 "$(pw_calls)"
rm -rf "$PWO" "$PW/calls"; pw_write src/app.ts OVERVIEW=off >/dev/null
expect_eq "OVERVIEW=off → 寫程式碼檔不觸發" 0 "$(pw_calls)"
expect_eq "post-write 與 overview-scan.sh 的 OVERVIEW_CODE_EXT 相同" \
    "$(grep -m1 '^OVERVIEW_CODE_EXT=' "$OV_SCAN")" "$(grep -m1 '^OVERVIEW_CODE_EXT=' "$HOOK_DIR/post-write.sh")"
rm -rf "$PW"

ov_reset; ov_proj; ov_arch; ov_wbs
OVWT="$SANDBOX/.claude/worktrees/ovwt"
( cd "$SANDBOX" && git worktree add -q -B ovwt "$OVWT" ) >/dev/null 2>&1
mkdir -p "$OVWT/.claude/taskmaster-data/plans"
run post-write.sh "$(wcwd "$OVWT/.claude/taskmaster-data/plans/1.2-x.md" "$OVWT")" OVERVIEW_SYNC=1 >/dev/null
[ -f "$OVO/data.js" ] && ok "worktree 裡寫 plan → data.js 寫在主 checkout" || ng "worktree 裡寫 plan → data.js 寫在主 checkout" "主 checkout 有 data.js" "沒有"
[ ! -e "$OVWT/.claude/taskmaster-data/overview" ] && ok "worktree 底下沒有 overview/" || ng "worktree 底下沒有 overview/" "沒有" "有"
rm -f "$OVO/data.js" "$OVO/.scan-at"
run post-write.sh "$(wcwd "$OVWT/src/app.py" "$OVWT")" OVERVIEW_SYNC=1 >/dev/null
expect_eq "worktree 裡寫程式碼檔 → .scan-at 與 data.js 都寫在主 checkout、worktree 底下沒有 overview/" "1 1 0" \
    "$([ -f "$OVO/.scan-at" ] && echo 1 || echo 0) $([ -f "$OVO/data.js" ] && echo 1 || echo 0) $([ -e "$OVWT/.claude/taskmaster-data/overview" ] && echo 1 || echo 0)"
( cd "$SANDBOX" && git worktree remove --force "$OVWT" && git branch -D ovwt ) >/dev/null 2>&1

# 主 checkout 路徑含中文與空格（這個模板自己就在 D:\模板\…）：從它底下的 worktree 觸發，
# CLAUDE_PROJECT_DIR 指向 worktree（`claude -w` 的實況），產物要落在主 checkout。
ov_reset; ov_proj; ov_arch; ov_wbs "1.1|api|✅ 11-01"
OVCJK="$SANDBOX/中文 目錄/模板 專案"
rm -rf "$SANDBOX/中文 目錄"
mkdir -p "$OVCJK/.claude/taskmaster-data" "$OVCJK/docs"
cp -r "$SANDBOX/.claude/scripts" "$SANDBOX/.claude/templates" "$OVCJK/.claude/"
cp "$OVD/project.json" "$OVD/wbs.md" "$OVCJK/.claude/taskmaster-data/"
cp "$SANDBOX/docs/05_architecture.md" "$OVCJK/docs/"
OVCJKWT="$OVCJK/.claude/worktrees/工作 樹"
( cd "$OVCJK" && git -c init.defaultBranch=main init -q . && git add -A && git -c user.email=t@t -c user.name=t commit -qm init \
  && git worktree add -q -b cjkwt "$OVCJKWT" ) >/dev/null 2>&1
mkdir -p "$OVCJKWT/.claude/taskmaster-data/plans"
run post-write.sh "$(wcwd "$OVCJKWT/.claude/taskmaster-data/plans/1.2-x.md" "$OVCJKWT")" \
    OVERVIEW_SYNC=1 CLAUDE_PROJECT_DIR="$OVCJKWT" >/dev/null
OVCJKO="$OVCJK/.claude/taskmaster-data/overview"
expect_eq "主 checkout 路徑含中文與空格 → data.js 寫在主 checkout、三個模組都在" 3 \
    "$(sed -n 's/^window\.OVERVIEW = //; s/;$//p' "$OVCJKO/data.js" 2>/dev/null | jq -r '.modules | length' 2>/dev/null)"
expect_contains "主 checkout 路徑含中文與空格 → overview.md 有內容" "class api done" "$(cat "$OVCJKO/overview.md" 2>/dev/null)"
[ ! -e "$OVCJKWT/.claude/taskmaster-data/overview" ] && ok "主 checkout 路徑含中文與空格 → worktree 底下沒有 overview/" \
    || ng "主 checkout 路徑含中文與空格 → worktree 底下沒有 overview/" "沒有" "有"
expect_contains "主 checkout 路徑含中文與空格 → --print-path 保留原字元" "模板 專案/.claude/taskmaster-data/overview/index.html" \
    "$(bash "$OVCJK/.claude/scripts/overview.sh" --print-path "$OVCJKWT" 2>/dev/null)"
( cd "$OVCJK" && git worktree remove --force "$OVCJKWT" ) >/dev/null 2>&1
rm -rf "$SANDBOX/中文 目錄"

# ---- 任務圖（階段 4）
# 獨立的假專案、每個案例重開 repo（沙箱根目錄有別節留下的檔，會混進「計畫外」）。
# 路徑刻意含中文與空格：jq 讀中文絕對路徑會失敗（context/learned/2026-11-04-jq-windows-non-ascii-path.md）。
TG="$SANDBOX/任務 圖/專 案"; TGD="$TG/.claude/taskmaster-data"; TGO="$TGD/overview"
tg_git()  { git -C "$TG" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
tg_ov()   { bash "$TG/.claude/scripts/overview.sh" "$TG" >/dev/null 2>&1; }
tgq()     { sed -n 's/^window\.OVERVIEW = //; s/;$//p' "$TGO/data.js" 2>/dev/null | jq -r "$1" 2>/dev/null; }
tgp()     { tgq ".plans[] | select(.file == \"plans/${2:-1.2-x.md}\") | $1"; }
tg_reset() {
    rm -rf "$SANDBOX/任務 圖"
    mkdir -p "$TG/.claude/scripts" "$TG/.claude/templates/overview" "$TGD/plans" "$TG/docs" "$TG/src/api" "$SANDBOX/docs"
    cp "$OV_SRC" "$TG/.claude/scripts/overview.sh"; cp "$OV_SCAN" "$TG/.claude/scripts/overview-scan.sh"
    cp "$OV_TPL" "$TG/.claude/templates/overview/index.html"
    printf '{"name":"任務圖","mode":"mvp"}\n' > "$TGD/project.json"
    ov_arch; cp "$SANDBOX/docs/05_architecture.md" "$TG/docs/"
    OVD="$TGD" ov_wbs "${@:-1.2|api|🔄 進行中}"
    printf '1\n2\n' > "$TG/src/api/old.ts"
    git -C "$TG" init -q -b main; tg_git add -A; tg_git commit -qm init; tg_git checkout -q -b feat/x
}
# plan：p1（階段 1）、p2（階段 2）；$2 $3 是兩個階段的狀態；TP_A／TP_B 換掉兩個部件的檔案
tg_plan() {
    local a="${TP_A:-src/api/a.ts}" b="${TP_B:-src/api/b.ts}"
    { echo '---'; echo "wbs_task: \"${TP_TASK:-1.2}\""; echo "status: \"${TP_STATUS:-⏳ 未開始}\""; echo 'current_phase: 1'
      echo 'mode: "standard"'; echo 'files:'; echo "  - \"$a\""; echo "  - \"$b\""; echo '---'; echo
      echo '# 實作計畫：測試計畫'; echo; echo '## 一眼看懂'; echo
      echo '| id | 部件 | 階段 | 檔案 | 驗收 |'; echo '|---|---|---|---|---|'
      echo "| p1 | A 部件 | 1 | \`$a\` | 呼叫 a → 回 1 |"; echo "| p2 | B 部件 | 2 | \`$b\` | 呼叫 b → 回 2 |"; echo
      echo '## 階段拆解'; echo; echo "### 階段 1: 介面 ${2:-⏳}"; echo; echo "### 階段 2: 核心 ${3:-⏳}"
    } > "$TGD/plans/${1:-1.2-x.md}"
}
tg_actual() { bash "$TG/.claude/scripts/overview.sh" --actual "$TGD/plans/1.2-x.md" "$@" >/dev/null 2>&1; }
# plan 拿掉 actual 區塊後的內容（驗「區塊外不動」用）
tg_outside() { awk '/^<!-- overview:actual:start/ { s = 1 } !s { print } /^<!-- overview:actual:end/ { s = 0 }' "$TGD/plans/1.2-x.md"; }

tg_reset; tg_plan 1.2-x.md ⏳ ⏳; echo 1.2 > "$TGD/.current-task"; tg_ov
expect_eq "兩階段都 ⏳ → 兩個部件都是 planned" "planned planned" "$(tgp '[.parts[].state] | join(" ")')"
expect_contains "overview.md 任務圖：p1 是 planned" "class p1 planned" "$(cat "$TGO/overview.md" 2>/dev/null)"
expect_contains "overview.md 任務圖：p2 是 planned" "class p2 planned" "$(cat "$TGO/overview.md" 2>/dev/null)"

printf '1\n2\n3\n' > "$TG/src/api/a.ts"; printf 'x\n' > "$TG/src/api/c.ts"; printf '1\n' > "$TG/src/api/old.ts"
tg_git add -A; tg_git commit -qm a
tg_plan 1.2-x.md ✅ ⏳; tg_ov
expect_eq "階段 1 ✅、src/api/a.ts 在 diff 裡 → p1 done" done "$(tgp '.parts[] | select(.id == "p1") | .state')"
expect_eq "diff 裡有不在部件也不在 files: 的檔 → extra 部件、planned:false" "src/api/c.ts false" \
    "$(tgp '.parts[] | select(.state == "extra" and .name == "src/api/c.ts") | "\(.name) \(.planned)"')"
expect_eq "changes 的 +/− 等於 git diff --numstat <base>..HEAD" \
    "$(git -C "$TG" diff --numstat main..HEAD -- . ':(exclude).claude' | awk '{ print $3 " " $1 " " $2 }' | sort | paste -sd, -)" \
    "$(tgp '[.changes[] | "\(.file) \(.added) \(.removed)"] | sort | join(",")')"
expect_eq "沒有帳本 → 基準是與預設分支的 merge-base" "$(git -C "$TG" rev-parse --short main)" "$(tgp '.base')"

{ echo "# 執行帳本 — plan: x"; echo "## 階段 1: 介面"; echo "- 10:00 派工｜BASE=$(git -C "$TG" rev-parse HEAD)"
  echo "- 10:20 階段完成 → plan 標 ✅｜摘要=新增 token 解析｜測試=12/12"; } > "$TGD/plans/1.2-x.progress.md"
printf 'y\n' > "$TG/src/api/b.ts"; tg_git add -A; tg_git commit -qm b
tg_ov
expect_eq "帳本有 BASE= → 用它當基準（只剩之後的改動）" "$(git -C "$TG" rev-parse --short=7 HEAD~1) src/api/b.ts" \
    "$(tgp '"\(.base) \([.changes[].file] | join(","))"')"
expect_eq "帳本「階段完成」的摘要／測試 → 該階段部件的 ai" "新增 token 解析 12/12 phase" \
    "$(tgp '.parts[] | select(.id == "p1") | "\(.ai.summary) \(.ai.tests) \(.ai.source)"')"
echo "- 10:30 部件 p1 完成｜摘要=部件層摘要｜測試=3/3" >> "$TGD/plans/1.2-x.progress.md"; tg_ov
expect_eq "帳本有「部件 p1 完成」行 → 以部件行為準" "部件層摘要 3/3 part" \
    "$(tgp '.parts[] | select(.id == "p1") | "\(.ai.summary) \(.ai.tests) \(.ai.source)"')"

tg_reset; tg_plan 1.2-x.md ✅ ⏳; echo 1.2 > "$TGD/.current-task"; tg_ov
expect_eq "階段 1 ✅、但 p1 的檔案不在 diff 裡 → skipped" skipped "$(tgp '.parts[] | select(.id == "p1") | .state')"
tg_git branch -m main trunk; tg_ov
expect_eq "沒有帳本、也找不到預設分支 → changes 為空、base 為 null" "0 null" "$(tgp '"\(.changes | length) \(.base)"')"
expect_contains "找不到基準 → notices 說明" "找不到比較基準" "$(tgq '[.notices[].text] | join("\n")')"

# 已完成的 plan 不算改動（status 含 ✅，或階段全部 ✅）：帳本 BASE 再舊也不拿來對現在的工作區 diff
tg_completed_case() {
    tg_reset; TP_STATUS="$1" tg_plan 1.2-x.md ✅ ✅; echo 1.2 > "$TGD/.current-task"
    { echo "# 執行帳本 — plan: x"; echo "## 階段 1: 介面"; echo "- 10:00 派工｜BASE=$(git -C "$TG" rev-parse HEAD)"; } > "$TGD/plans/1.2-x.progress.md"
    printf 'a\n' > "$TG/src/api/a.ts"; tg_git add -A; tg_git commit -qm a
    printf 'c\n' > "$TG/src/api/c.ts"; tg_git add -A; tg_git commit -qm c
    tg_ov
}
tg_completed_case "✅ 完成"
expect_eq "status ✅ 完成、帳本 BASE 在 2 個 commit 前 → changes 0、extraCount 0、base null、changesFrom completed、部件 done done" \
    "0 0 null completed true done done" \
    "$(tgp '"\(.changes | length) \(.extraCount) \(.base) \(.changesFrom) \(.completed) \([.parts[].state] | join(" "))"')"
tg_completed_case "🔄 進行中"
expect_eq "status 🔄 但兩個階段都 ✅ → 同樣算已完成" "0 0 null completed true done done" \
    "$(tgp '"\(.changes | length) \(.extraCount) \(.base) \(.changesFrom) \(.completed) \([.parts[].state] | join(" "))"')"
rm -f "$TGD/plans/1.2-x.progress.md"; tg_git branch -m main trunk; tg_ov
expect_eq "已完成的 plan（沒帳本、也找不到預設分支）→ notices 沒有「找不到比較基準」" 0 \
    "$(tgq '[.notices[].text | select(test("找不到比較基準"))] | length')"

# 沒有帳本的 plan：只有 .current-task 明確指到的那份拿工作區改動
tg_two_plans() {
    tg_reset; tg_plan 1.2-x.md ⏳ ⏳; TP_TASK=1.3 tg_plan 1.3-y.md ⏳ ⏳
    OVD="$TGD" ov_wbs "1.2|api|⏳ 待處理" "1.3|api|⏳ 待處理"
    printf 'c\n' > "$TG/src/api/c.ts"
}
tg_two_plans; echo 1.3 > "$TGD/.current-task"; tg_ov
expect_eq ".current-task 是 1.3、工作區新增 src/api/c.ts → 1.3 的 changes 含它、changesFrom current" "true current" \
    "$(tgp '"\([.changes[].file] | index("src/api/c.ts") != null) \(.changesFrom)"' 1.3-y.md)"
expect_eq "非本次、沒帳本的 1.2 → changes 0、changesFrom none、base null" "0 none null" \
    "$(tgp '"\(.changes | length) \(.changesFrom) \(.base)"')"
tg_git branch -m main trunk; tg_ov
expect_eq "changesFrom none 的 plan 不進「找不到比較基準」（本次那份照列）" "1 0" \
    "$(tgq '[.notices[].text | select(test("找不到比較基準"))] | "\(map(select(test("1.3-y.md"))) | length) \(map(select(test("1.2-x.md"))) | length)"')"
tg_two_plans; tg_ov
expect_eq "沒有 .current-task（本次是猜的）→ 沒有 plan 拿到 c.ts、地圖 changes 仍有、currents[0].guessed" "0 true true" \
    "$(tgq '"\([.plans[].changes[] | select(.file == "src/api/c.ts")] | length) \([.changes[].file] | index("src/api/c.ts") != null) \(.currents[0].guessed)"')"

# --actual 指定的 plan 不套「已完成」與「只歸本次」：/verify 寫計畫 vs 實際時 plan 多半已全部 ✅
tg_reset; TP_STATUS="✅ 完成" tg_plan 1.2-x.md ✅ ✅; printf 'a\n' > "$TG/src/api/a.ts"; tg_git add -A; tg_git commit -qm a
tg_actual --result PASS
expect_contains "已完成、沒帳本、不是本次的 plan 跑 --actual → 計畫 vs 實際列得出分支上改的 src/api/a.ts" \
    '`src/api/a.ts` | +1 / −0' "$(sed -n '/overview:actual:start/,/overview:actual:end/p' "$TGD/plans/1.2-x.md")"

# 計畫外很多：mermaid 收成一個節點；data.js 帶總數
tg_reset; tg_plan 1.2-x.md 🔄 ⏳; echo 1.2 > "$TGD/.current-task"; mkdir -p "$TG/src/x"
for i in $(seq 1 35); do echo x > "$TG/src/x/f$i.ts"; done
tg_git add -A; tg_git commit -qm many; tg_ov
expect_eq "本次 plan 有 35 個計畫外檔 → extraCount 35" 35 "$(tgp '.extraCount')"
expect_eq "overview.md 的任務圖：「＋ 計畫外 35 個檔」節點恰好 1 個、沒有逐檔的「＋ 計畫外 src/」" "1 0" \
    "$(grep -c '＋ 計畫外 35 個檔' "$TGO/overview.md") $(grep -c '＋ 計畫外 src/' "$TGO/overview.md")"

tg_reset; tg_plan 1.2-x.md 🔄 ⏳; printf 'a\n' > "$TG/src/api/a.ts"; tg_git add -A; tg_git commit -qm a
cp "$TGD/plans/1.2-x.md" "$SANDBOX/tg-plan-orig.md"
tg_actual --result FAIL --reason "2 個測試失敗：token 過期"; rc=$?
expect_eq "--actual FAIL → exit 0" 0 "$rc"
expect_contains "--actual FAIL → plan 有 actual 區塊、含 ❌ FAIL 與原因" "❌ FAIL" "$(sed -n '/overview:actual:start/,/overview:actual:end/p' "$TGD/plans/1.2-x.md")"
expect_contains "--actual FAIL → 區塊含原因" "token 過期" "$(sed -n '/overview:actual:start/,/overview:actual:end/p' "$TGD/plans/1.2-x.md")"
expect_eq "--actual 第一次 → 原內容一字不差留在區塊前" "" \
    "$(tg_outside | head -n "$(wc -l < "$SANDBOX/tg-plan-orig.md")" | cmp -s - "$SANDBOX/tg-plan-orig.md" || echo 不同)"
expect_eq "plan 驗證 FAIL → 碰到的模組 status 為 issue" issue "$(tgq '.modules[] | select(.id == "api") | .status')"
expect_contains "plan 驗證 FAIL → statusReason 含原因" "token 過期" "$(tgq '.modules[] | select(.id == "api") | .statusReason')"
printf '\n## 區塊後面的手寫段落\n\n不能被動到。\n' >> "$TGD/plans/1.2-x.md"
tg_outside > "$SANDBOX/tg-out1.md"
tg_actual --result PASS
expect_eq "再跑 --actual PASS → 區塊被取代（只剩一個）" 1 "$(grep -c 'overview:actual:start' "$TGD/plans/1.2-x.md")"
expect_contains "再跑 --actual PASS → 內含 ✅ PASS" "✅ PASS" "$(sed -n '/overview:actual:start/,/overview:actual:end/p' "$TGD/plans/1.2-x.md")"
tg_outside | cmp -s - "$SANDBOX/tg-out1.md" && ok "--actual 只動標記區塊內：區塊外（含區塊後的段落）前後相同" \
    || ng "--actual 只動標記區塊內" "cmp 相同" "$(tg_outside | diff - "$SANDBOX/tg-out1.md" | head -5)"
out=$(bash "$TG/.claude/scripts/overview.sh" --actual "$TGD/plans/1.2-x.md" --result FAIL 2>&1); rc=$?
expect_eq "--actual FAIL 沒帶 --reason → exit 2、不寫" "2 1" "$rc $(grep -c 'overview:actual:start' "$TGD/plans/1.2-x.md")"

# CRLF 的 plan（Windows 上常見）：標記外的位元組一個都不能變、整份不能混進單獨的 LF。
# 比對用 bash 讀整份（awk／sed 在 Git Bash 會吃掉 CR，拿它們比對會看不出差別）
tg_crlf()   { local l; while IFS= read -r l; do printf '%s\r\n' "$l"; done < "$1" > "$1.crlf" && mv "$1.crlf" "$1"; }
tg_bytes()  { local s; IFS= read -r -d '' s < "$1"; printf '%sx' "$s"; }
tg_lone_lf() { echo $(( $(tr -cd '\n' < "$1" | wc -c) - $(tr -cd '\r' < "$1" | wc -c) )); }
TGP="$TGD/plans/1.2-x.md"
tg_plan 1.2-x.md 🔄 ⏳; tg_crlf "$TGP"; tgc_orig=$(tg_bytes "$TGP"); tgc_orig=${tgc_orig%x}
tg_actual --result FAIL --reason "CRLF 第一次"; rc=$?; tgc_now=$(tg_bytes "$TGP")
expect_eq "CRLF plan 第一次 --actual → exit 0、原內容一字不差（含 CR）留在區塊前、整份沒有單獨的 LF" "0 same 0" \
    "$rc $([[ $tgc_now == "$tgc_orig"* ]] && echo same || echo diff) $(tg_lone_lf "$TGP")"
tg_plan 1.2-x.md 🔄 ⏳
printf '%s\n' '<!-- overview:actual:start -->' '舊區塊' '<!-- overview:actual:end -->' '' '## 區塊後面的手寫段落' '' '不能被動到。' >> "$TGP"
tg_crlf "$TGP"; tgc_orig=$(tg_bytes "$TGP")
tg_actual --result PASS; rc=$?; tgc_now=$(tg_bytes "$TGP")
expect_eq "CRLF plan 已有區塊再跑 --actual → exit 0、區塊前後的位元組不變（含 CR）、整份沒有單獨的 LF、舊區塊被取代" "0 same same 0 0" \
    "$rc $([ "${tgc_now%%<!-- overview:actual:start*}" = "${tgc_orig%%<!-- overview:actual:start*}" ] && echo same || echo diff) $([ "${tgc_now#*<!-- overview:actual:end -->}" = "${tgc_orig#*<!-- overview:actual:end -->}" ] && echo same || echo diff) $(tg_lone_lf "$TGP") $(grep -c '舊區塊' "$TGP")"

# 標記壞掉（只有 start、兩組、end 在 start 前）→ 一個 byte 都不動、非 0 結束、說明怎麼修。
# 曾經只有 start 時會從 start 一路跳到檔尾，把使用者寫在後面的段落整段刪掉還回報「已寫入」。
tg_bad_markers() {
    local name="$1"; shift
    tg_plan 1.2-x.md 🔄 ⏳; printf '%s\n' "$@" >> "$TGD/plans/1.2-x.md"
    cp "$TGD/plans/1.2-x.md" "$SANDBOX/tg-bad.md"
    out=$(bash "$TG/.claude/scripts/overview.sh" --actual "$TGD/plans/1.2-x.md" --result PASS 2>&1); rc=$?
    cmp -s "$TGD/plans/1.2-x.md" "$SANDBOX/tg-bad.md" && [ "$rc" -ne 0 ] && [[ $out == *標記* ]] \
        && ok "--actual 遇到$name → 不寫、非 0、訊息指出標記" \
        || ng "--actual 遇到$name → 不寫、非 0、訊息指出標記" "plan 不變、rc≠0、訊息含「標記」" \
              "rc=$rc 不變=$(cmp -s "$TGD/plans/1.2-x.md" "$SANDBOX/tg-bad.md" && echo 是 || echo 否) $out"
}
tg_bad_markers "只有 start 沒有 end" '<!-- overview:actual:start -->' '舊區塊' '' '## 使用者寫在後面的段落' '不能被刪。'
tg_bad_markers "兩組區塊" '<!-- overview:actual:start -->' 'a' '<!-- overview:actual:end -->' '中間' \
    '<!-- overview:actual:start -->' 'b' '<!-- overview:actual:end -->'
tg_bad_markers "end 在 start 前" '<!-- overview:actual:end -->' '中間' '<!-- overview:actual:start -->'

tg_reset; tg_plan 1.2-x.md ⏳ ⏳; echo 1.2 > "$TGD/.current-task"; tg_ov
expect_eq "主 checkout 的 .current-task 是 1.2 → 任務 1.2 的模組 current:true" true "$(tgq '.modules[] | select(.id == "api") | .current')"
rm -f "$TGD/.current-task"
TP_TASK=1.3 TP_A=migrations/1.sql TP_B=migrations/2.sql tg_plan 1.3-y.md ⏳ ⏳
touch -d '2020-01-01' "$TGD/plans/1.2-x.md"; OVD="$TGD" ov_wbs "1.2|api|⏳ 待處理" "1.3|db|⏳ 待處理"; tg_ov
expect_eq "沒有 .current-task → 取 mtime 最新、還沒完成的 plan 當本次" "1.3 true false" \
    "$(tgq '"\(.current.task) \(.modules[] | select(.id == "db") | .current) \(.modules[] | select(.id == "api") | .current)"')"

tg_reset; mkdir -p "$TG/src/web"; TP_A=src/web/form.tsx TP_B=src/web/list.tsx tg_plan 1.2-x.md 🔄 ⏳
printf 'f\n' > "$TG/src/web/form.tsx"; tg_git add -A; tg_git commit -qm web; tg_ov
expect_eq "WBS 標 api、plan 只碰 web → api 帶 declared-not-touched" declared-not-touched "$(tgq '.modules[] | select(.id == "api") | .mismatch[0].kind')"
expect_eq "WBS 標 api、plan 只碰 web → web 帶 touched-not-declared" touched-not-declared "$(tgq '.modules[] | select(.id == "web") | .mismatch[0].kind')"

tg_reset; tg_plan 1.2-x.md ⏳ ⏳; tg_git add -A; tg_git commit -qm plan
TGWT="$TG/.claude/worktrees/wt1"
tg_git worktree add -q -b wt1 "$TGWT"
mkdir -p "$TGWT/.claude/taskmaster-data/plans"
( TGD="$TGWT/.claude/taskmaster-data"; tg_plan 1.2-x.md ✅ 🔄 )
OVD="$TGD" ov_wbs "1.2|api|🔄 進行中" "1.3|db|⏳ 待處理"
echo 1.3 > "$TGD/.current-task"; echo 1.2 > "$TGWT/.claude/taskmaster-data/.current-task"
mkdir -p "$TGWT/src/api"; printf 'w\n' > "$TGWT/src/api/w.ts"
tg_ov
expect_eq "worktree 的 plan 進度較新 → data.js 取 worktree 那份" "worktree:wt1 skipped" \
    "$(tgp '"\(.source) \(.parts[] | select(.id == "p1") | .state)"')"
expect_contains "worktree overlay 不進 overview.md（仍是主 checkout 的 planned）" "class p1 planned" "$(cat "$TGO/overview.md" 2>/dev/null)"
expect_eq "主 checkout 與 worktree 各有 .current-task → 兩個本次都標出" "1.3 1.2 true true" \
    "$(tgq '"\([.currents[].task] | join(" ")) \(.modules[] | select(.id == "db") | .current) \(.modules[] | select(.id == "api") | .current)"')"
expect_eq "worktree 的改動出現在地圖的本次改動（帶來源）" "worktree:wt1 api" \
    "$(tgq '.changes[] | select(.file == "src/api/w.ts") | "\(.source) \(.module)"')"
tg_git worktree remove --force "$TGWT"

# worktree 自己的 plan（隨版控帶進來、還沒改過）跑 --actual → 來源判成 worktree:<名>、寫在 worktree 那份、再跑是原地取代
tg_reset; tg_plan 1.2-x.md 🔄 ⏳; tg_git add -A; tg_git commit -qm plan
TGWT="$TG/.claude/worktrees/wt2"; TGWD="$TGWT/.claude/taskmaster-data"
tg_git worktree add -q -b wt2 "$TGWT"
bash "$TG/.claude/scripts/overview.sh" --actual "$TGWD/plans/1.2-x.md" --result FAIL --reason "第一次" >/dev/null 2>&1; rc1=$?
bash "$TG/.claude/scripts/overview.sh" --actual "$TGWD/plans/1.2-x.md" --result PASS >/dev/null 2>&1; rc2=$?
expect_eq "worktree 的 plan 跑 --actual 兩次 → exit 0、data.js 取 worktree:wt2、該份只有一個區塊且是 PASS、主 checkout 那份沒被寫" \
    "0 0 worktree:wt2 1 PASS 0" \
    "$rc1 $rc2 $(tgp '.source') $(grep -c 'overview:actual:start' "$TGWD/plans/1.2-x.md") $(tgp '.verify.result') $(grep -c 'overview:actual:start' "$TGD/plans/1.2-x.md")"
tg_git worktree remove --force "$TGWT"

# worktree 的 .current-task 指到、但 overlay 選了主 checkout 的同名 plan（worktree 那份沒改過）
# → 那張卡仍算本次，改動取 worktree 的預設基準改動
tg_reset; tg_plan 1.2-x.md ⏳ ⏳; tg_git add -A; tg_git commit -qm plan
TGWT="$TG/.claude/worktrees/wt5"
tg_git worktree add -q -b wt5 "$TGWT"
mkdir -p "$TGWT/.claude/taskmaster-data" "$TGWT/src/api"; echo 1.2 > "$TGWT/.claude/taskmaster-data/.current-task"
printf 'w\n' > "$TGWT/src/api/w.ts"; tg_ov
expect_eq "worktree 的 .current-task 指到、overlay 取主 checkout 同名 plan → 卡片 current、changesFrom current、changes 含 worktree 的 src/api/w.ts" \
    "main true current true" \
    "$(tgp '"\(.source) \(.current) \(.changesFrom) \([.changes[].file] | index("src/api/w.ts") != null)"')"
tg_git worktree remove --force "$TGWT"

# worktree 帶著主 checkout 已歸檔的 plan 副本（版控帶進來、沒改過）→ 不進 plans[]、不被猜成本次
tg_reset; tg_plan 1.2-x.md 🔄 ⏳; tg_git add -A; tg_git commit -qm plan
TGWT="$TG/.claude/worktrees/wt3"
tg_git worktree add -q -b wt3 "$TGWT"
mkdir -p "$TGD/plans/archive"; tg_git mv "$TGD/plans/1.2-x.md" "$TGD/plans/archive/1.2-x.md"; tg_git commit -qm archive
tg_ov
expect_eq "worktree 裡沒改過的版控 plan 副本（主 checkout 已歸檔）→ 不進 plans[]、currents 為空" "0 0" \
    "$(tgq '"\([.plans[] | select(.file == "plans/1.2-x.md")] | length) \(.currents | length)"')"
tg_git worktree remove --force "$TGWT"

# 平行開發時 implementer 每完成一階段就在 worktree 分支上 commit（plan 狀態一起）：
# 比的是與主 checkout HEAD 的 merge-base，不是 worktree 的 HEAD，否則一 commit 就從任務圖消失
tg_reset; tg_plan 1.2-x.md ⏳ ⏳; tg_git add -A; tg_git commit -qm plan
TGWT="$TG/.claude/worktrees/wt4"
tg_git worktree add -q -b wt4 "$TGWT"
( TGD="$TGWT/.claude/taskmaster-data"; tg_plan 1.2-x.md ✅ 🔄 )
git -C "$TGWT" -c user.email=t@t -c user.name=t commit -qam 階段1 >/dev/null 2>&1
tg_ov
expect_eq "worktree 改了 plan 並 commit 到自己的分支（工作區乾淨）→ 仍在 plans[]、來源是 worktree" \
    "worktree:wt4 0" "$(tgp '.source') $(git -C "$TGWT" status --porcelain | wc -l)"
tg_git worktree remove --force "$TGWT"

tg_reset; tg_plan 1.2-x.md ⏳ ⏳; mkdir -p "$TGD/plans/archive"
printf -- '---\nwbs_task: "0.9"\nstatus: "✅ 完成"\nfiles:\n  - "src/api/old.ts"\n---\n\n# 實作計畫：舊的\n' > "$TGD/plans/archive/0.9-old.md"
tg_ov
expect_eq "已歸檔的 plan 不進 plans[]，只計入模組的完成數" "plans/1.2-x.md 1" \
    "$(tgq '"\([.plans[].file] | join(",")) \(.modules[] | select(.id == "api") | .counts.archivedDone)"')"

# ---- 階段 5：已歸檔完成數、大小上限、沒有 jq、畫不出地圖的提示、開 session 補產
# wbs-archive.md：舊節沒有模組欄 → 歸「未標模組」；新節照模組欄；同一任務另有已歸檔 plan → 只算一次；
# 沒有模組欄的那列有已歸檔 plan → 用 plan 的 files: 對模組；⏭️ 不算完成；WBS 還在的任務不重算。
# 第二張表前面只有說明文字、沒有標題：驗「濾掉說明文字後兩張表不會黏成一張」
tg_reset; tg_plan 1.2-x.md ⏳ ⏳; mkdir -p "$TGD/plans/archive"
{ echo "# WBS 歸檔"; echo; echo "## M0 舊節（還沒有模組欄）"; echo
  echo "| # | 任務 | 狀態 | 優先 |"; echo "|---|---|---|---|"
  echo "| 0.1 | 舊 a | ✅ 10-01 | 高 |"; echo "| 0.2 | 舊 b | ✅ 10-01 | 高 |"; echo "| 0.3 | 舊 c | ⏭️ 跳過 | 高 |"
  echo; echo "中間的說明文字"; echo
  echo "| # | 任務 | 模組 | 狀態 | 優先 | 實際 |"; echo "|---|---|---|---|---|---|"
  echo "| 0.8 | 新 d | api | ✅ 10-02 | 高 | 1h |"; echo "| 0.9 | 新 e | api | ✅ 10-02 | 高 | 1h |"
  echo "| 1.2 | 還在 WBS | api | ✅ 10-02 | 高 | 1h |"
} > "$TGD/wbs-archive.md"
for t in 0.9 0.2; do
    printf -- '---\nwbs_task: "%s"\nstatus: "✅ 完成"\nfiles:\n  - "src/api/old.ts"\n---\n\n# 實作計畫：舊的\n' "$t" > "$TGD/plans/archive/$t-old.md"
done
tg_ov
expect_eq "wbs-archive 舊節無模組欄不報錯；api 已歸檔完成 3（0.9 與 plan 去重、0.2 靠 plan 對到）、未標模組 1、共 4" \
    "ok 3 1 4" "$([ -e "$TGO/.last-error" ] && echo err || echo ok) $(tgq '"\(.modules[] | select(.id == "api") | .counts.archivedDone) \(.archived.unmapped) \(.archived.done)"')"
expect_contains "overview.md 說明已歸檔任務有幾個沒標模組" "1 個沒有標模組" "$(cat "$TGO/overview.md" 2>/dev/null)"

# 改動超過 200 個：plan 與地圖都只列前 200（依檔名排序），其餘依第一層目錄彙總
tg_reset; tg_plan 1.2-x.md 🔄 ⏳; echo 1.2 > "$TGD/.current-task"; mkdir -p "$TG/lib" "$TG/src/gen"
for i in $(seq 1 100); do echo x > "$TG/lib/l$i.ts"; done
for i in $(seq 1 150); do echo x > "$TG/src/gen/g$i.ts"; done
tg_git add -A; tg_git commit -qm many; tg_ov
expect_eq "250 個改動 → plan 列 200、其餘依第一層目錄彙總成 src/ 50 個（+50）、truncated" "200 src/:50:50 true" \
    "$(tgp '"\(.changes | length) \([.changesRollup[] | "\(.dir):\(.files):\(.added)"] | join(","))"') $(tgq '.truncated')"
expect_eq "地圖的本次改動同樣只列 200、其餘彙總" "200 50" "$(tgq '"\(.changes | length) \([.changesRollup[].files] | add)"')"
expect_contains "overview.md 的任務圖列出彙總列" "未逐一列出" "$(cat "$TGO/overview.md" 2>/dev/null)"
OVERVIEW_MAX_BYTES=20000 tg_ov
expect_eq "超過 OVERVIEW_MAX_BYTES、只有本次 plan → 本次 plan 明細保留 200、地圖本次改動改彙總、四級丟完仍放不下 → 加一則 warn" "200 0 true" \
    "$(tgp '.changes | length') $(tgq '.changes | length') $(tgq '[.notices[] | select(.level == "warn") | .text] | any(test("仍超過"))')"
expect_contains "大小上限只動 data.js：overview.md 仍列得出彙總前的計畫外部件" "＋ 計畫外" "$(cat "$TGO/overview.md" 2>/dev/null)"
TP_TASK=1.3 tg_plan 1.3-y.md 🔄 ⏳; echo 1.2 > "$TGD/.current-task"; OVD="$TGD" ov_wbs "1.2|api|🔄 進行中" "1.3|api|🔄 進行中"
OVERVIEW_MAX_BYTES=40000 tg_ov
expect_eq "超過上限、另有非本次 plan → 放得下、本次 plan 明細保留 200、非本次 plan 明細改彙總、沒有 warn" "1 200 0 false" \
    "$([ "$(wc -c < "$TGO/data.js")" -le 40000 ] && echo 1 || echo 0) $(tgp '.changes | length') $(tgp '.changes | length' 1.3-y.md) $(tgq '[.notices[].level] | any(. == "warn")')"
rm -f "$TGD/plans/1.3-y.md" "$TGD/.current-task"

# 提案階段 5 驗收 1 的量級：300 個任務、20 份 plan、每份 500 個改動
tg_reset
OV_ROWS=(); for i in $(seq 1 300); do OV_ROWS+=("9.$i|api|⏳ 待處理"); done
OVD="$TGD" ov_wbs "${OV_ROWS[@]}"
# 每份都有帳本：沒帳本、不是本次的 plan 不列改動
for i in $(seq 1 20); do TP_TASK="9.$i" tg_plan "9.$i-p.md" 🔄 ⏳
    echo "- 10:00 派工｜BASE=$(git -C "$TG" rev-parse HEAD)" > "$TGD/plans/9.$i-p.progress.md"; done
mkdir -p "$TG/src/big"; for i in $(seq 1 500); do echo x > "$TG/src/big/f$i.ts"; done
tg_git add -A; tg_git commit -qm big; tg_ov
expect_eq "300 任務・20 份 plan・每份 500 個改動 → data.js ≤ 512KB、truncated、20 份都是 changes ≤ 200 且明細＋彙總＝500" \
    "1 true 20" "$([ "$(wc -c < "$TGO/data.js" 2>/dev/null || echo 999999999)" -le 524288 ] && echo 1 || echo 0) $(tgq '.truncated') $(tgq '[.plans[] | select((.changes | length) <= 200 and ((.changes | length) + ([.changesRollup[].files] | add // 0)) == 500)] | length')"
OVERVIEW_MAX_BYTES=60000 tg_ov
expect_eq "縮到非本次 plan 變 stub → stub 仍帶 changesFrom（不會在畫面上變回「找不到比較基準」）" "true true" \
    "$(tgq '[.plans[] | select(.stub)] | "\(length > 0) \(all(.changesFrom != null))"')"
expect_eq "縮到非本次 plan 變 stub → stub 仍帶 plannedModules" "true true" \
    "$(tgq '[.plans[] | select(.stub)] | "\(length > 0) \(all(.plannedModules | type == "array"))"')"

# 沒有 jq：PATH 拿掉 jq 所在的目錄。jq 跟 bash 同一個目錄（Linux 的 /usr/bin）時，
# 改放一個除了 jq 以外全部 symlink 過去的目錄頂替
nojq_path() {
    local d out="" farm="$SANDBOX/nojq-farm" parts
    IFS=':' read -ra parts <<< "$PATH"
    for d in "${parts[@]}"; do
        if [ -e "$d/jq" ] || [ -e "$d/jq.exe" ]; then
            if [ ! -d "$farm" ]; then
                mkdir -p "$farm"
                ln -s "$d"/* "$farm/" 2>/dev/null
                rm -f "$farm/jq" "$farm/jq.exe"
            fi
            out="$out:$farm"
        else
            out="$out:$d"
        fi
    done
    printf '%s' "${out#:}"
}
tg_reset; tg_plan 1.2-x.md 🔄 ⏳
NOJQ_PATH=$(nojq_path)
if env PATH="$NOJQ_PATH" "$BASH" -c 'command -v jq' >/dev/null 2>&1; then
    ng "沒有 jq 的情境造不出來" "PATH 裡找不到 jq" "$(env PATH="$NOJQ_PATH" "$BASH" -c 'command -v jq')"
else
    env PATH="$NOJQ_PATH" "$BASH" "$TG/.claude/scripts/overview.sh" "$TG" >/dev/null 2>&1; rc=$?
    expect_eq "沒有 jq → exit 0、data.js 只有 schema 2 與一則「需要 jq」、畫面照樣複製" "0 notices,schema 2 1 1" \
        "$rc $(tgq 'keys | join(",")') $(tgq '.schema') $(tgq '[.notices[] | select(.text | startswith("需要 jq"))] | length') $(cmp -s "$OV_TPL" "$TGO/index.html" && echo 1 || echo 0)"
    env PATH="$NOJQ_PATH" "$BASH" "$TG/.claude/scripts/overview.sh" --actual "$TGD/plans/1.2-x.md" --result PASS >/dev/null 2>&1; rc=$?
    expect_eq "沒有 jq 時 --actual → exit 1（讓 /verify 知道沒寫）、plan 沒被動" "1 0" \
        "$rc $(grep -c 'overview:actual:start' "$TGD/plans/1.2-x.md")"
fi

tg_reset; tg_plan 1.2-x.md ⏳ ⏳
tg_pp() { bash "$TG/.claude/scripts/overview.sh" --print-path "$TG" 2>/dev/null; }
expect_eq "--print-path：有正式架構文件 → 只印路徑、沒有提示" 0 "$(tg_pp | grep -c '^提示：')"
{ echo '<!-- overview: draft -->'; cat "$TG/docs/05_architecture.md"; } > "$SANDBOX/tg-arch.md" && mv "$SANDBOX/tg-arch.md" "$TG/docs/05_architecture.md"
expect_contains "--print-path：架構是草稿 → 提示不拿它覆寫模組名稱、確認後移除標記" "不拿它覆寫模組名稱" "$(tg_pp)"
rm -f "$TG/docs/05_architecture.md"
expect_eq "--print-path：沒有架構文件 → 不提示（地圖改由程式碼掃出）" 0 "$(tg_pp | grep -c '^提示：')"
printf '{"name":"x","mode":"demo"}\n' > "$TGD/project.json"
expect_eq "--print-path：demo 沒有架構是正常的 → 不提示" 0 "$(tg_pp | grep -c '^提示：')"
rm -rf "$SANDBOX/任務 圖"

# 舊專案 update-template 之後還沒寫過 wbs／plan：開 session 就補產，使用者不用手動做任何事
ov_reset; ov_proj; ov_arch; ov_wbs "1.1|api|✅ 11-01"
out=$(run session-start.sh '{}' OVERVIEW_SYNC=1)
expect_eq "有 project.json、還沒有 data.js → 開 session 就產生（stdout 仍是合法 JSON）" "2 1" \
    "$(ovq '.schema') $(printf '%s' "$out" | jq -e . >/dev/null 2>&1 && echo 1 || echo 0)"
echo sentinel > "$OVO/data.js"; touch -d '2000-01-01' "$SANDBOX/.claude/templates/overview/index.html"
run session-start.sh '{}' OVERVIEW_SYNC=1 >/dev/null
expect_eq "已經產過、畫面原檔沒有比較新 → 開 session 不重產" sentinel "$(cat "$OVO/data.js" 2>/dev/null)"
touch -d '2099-01-01' "$SANDBOX/.claude/templates/overview/index.html"
run session-start.sh '{}' OVERVIEW_SYNC=1 >/dev/null
expect_eq "畫面原檔比現有的新（update-template 帶來新版畫面）→ 開 session 重產" 2 "$(ovq '.schema')"
rm -f "$OVO/data.js"
run session-start.sh '{}' OVERVIEW_SYNC=1 OVERVIEW=off >/dev/null
[ ! -e "$OVO/data.js" ] && ok "OVERVIEW=off → 開 session 不補產" || ng "OVERVIEW=off → 開 session 不補產" "沒有 data.js" "有"

# =========================================================================
section "overview fixture — 測試資料產生器"
# =========================================================================
# make-fixture.sh／gen-large.sh 是 overview.sh 與 overview-scan.sh 的測試輸入。目標目錄刻意含中文與空格。
FXD="$HOOK_DIR/tests/fixtures/overview"
FXR="$SANDBOX/任務 圖/fx"
rm -rf "$SANDBOX/任務 圖"
fx_repo() {
    ( cd "$1" && git -c init.defaultBranch=main init -q . && git add -A && git -c user.email=t@t -c user.name=t commit -qm base ) >/dev/null 2>&1
}
fx_ovq() { sed -n 's/^window\.OVERVIEW = //; s/;$//p' "$1/.claude/taskmaster-data/overview/data.js" 2>/dev/null | jq -r "$2" 2>/dev/null; }

bash "$FXD/make-fixture.sh" shop-clean "$FXR/shop" >/dev/null 2>&1; rc=$?
expect_eq "shop-clean → 產生成功" 0 "$rc"
fx_repo "$FXR/shop"
bash "$OV_SRC" "$FXR/shop" >/dev/null 2>&1
expect_eq "shop-clean → data.js 有 6 個模組" 6 "$(fx_ovq "$FXR/shop" '.modules | length')"
expect_eq "shop-clean → unmappedTasks 為空" 0 "$(fx_ovq "$FXR/shop" '.unmappedTasks | length')"
[ ! -e "$FXR/shop/.claude/taskmaster-data/overview/.last-error" ] && ok "shop-clean → 沒有 .last-error" \
    || ng "shop-clean → 沒有 .last-error" "沒有" "$(cat "$FXR/shop/.claude/taskmaster-data/overview/.last-error")"
expect_eq "shop-clean → 每個模組 2–5 個程式檔" "" "$(cd "$FXR/shop" && git ls-files -- 'src/*' migrations | grep -E '\.(py|ts|tsx)$' \
    | awk '{ m = $0; if (m ~ /^src\/services\//) { split(m, p, "/"); m = p[1] "/" p[2] "/" p[3] } else if (m ~ /^migrations\//) m = "src/db"; else { split(m, p, "/"); m = p[1] "/" p[2] } n[m]++ } END { for (k in n) if (n[k] > 5) print k, n[k] }')"
expect_eq "shop-clean → 現行 overview.sh 的模組、群組、邊與 shop-clean.golden 一致" "" \
    "$(fx_ovq "$FXR/shop" '(.modules[] | "module \(.id) \(.group)"), (.groups[] | "group \(.id) \(.label)"), (.edges[] | "edge \(.from) \(.to)")' \
        | tr -d '\r' | diff - <(tr -d '\r' < "$FXD/shop-clean.golden"))"
MAKE_FIXTURE_CHANGES=1 bash "$FXD/make-fixture.sh" shop-clean "$FXR/shop" >/dev/null 2>&1
bash "$OV_SRC" "$FXR/shop" >/dev/null 2>&1
expect_eq "shop-clean MAKE_FIXTURE_CHANGES=1 → 改動清單恰好是參考資料的三個檔" "src/services/a/create.ts src/web/Cart.tsx src/web/a.ts" \
    "$(fx_ovq "$FXR/shop" '[.changes[].file] | sort | join(" ")')"

bash "$FXD/make-fixture.sh" messy-fullstack "$FXR/messy" >/dev/null 2>&1; rc=$?
expect_eq "messy-fullstack → 產生成功" 0 "$rc"
expect_eq "messy-fullstack → docs/architecture/ 底下有檔名含 architecture 的 md" 1 \
    "$(find "$FXR/messy/docs/architecture" -name '*architecture*.md' | wc -l | tr -d ' ')"
expect_eq "messy-fullstack → wbs.md 任務表頭沒有「模組」" 0 "$(grep -c '^| # .*模組' "$FXR/messy/.claude/taskmaster-data/wbs.md")"
expect_eq "messy-fullstack → wbs.md 任務列恰好 32 列" 32 "$(grep -c '^| [0-9]' "$FXR/messy/.claude/taskmaster-data/wbs.md")"
expect_eq "messy-fullstack → plan 28 份、其中 24 份帶 files:" "28 24" \
    "$(ls "$FXR/messy/.claude/taskmaster-data/plans" | wc -l | tr -d ' ') $(grep -l '^files:' "$FXR/messy/.claude/taskmaster-data"/plans/*.md | wc -l | tr -d ' ')"
expect_eq "messy-fullstack → 沒有有效的 5.5（架構文件沒有含 id、路徑 欄的表）" 0 "$(grep -c '^| id | .*路徑' "$FXR/messy/docs/architecture/01_system_architecture.md")"
expect_contains "messy-fullstack → 架構圖標籤含 <br/> 與 &amp;" "<br/>" "$(cat "$FXR/messy/docs/architecture/01_system_architecture.md")"
expect_contains "messy-fullstack → 有 FastAPI 路由" '@router.get("/")' "$(cat "$FXR/messy/backend/app/api/users.py")"
fx_repo "$FXR/messy"
expect_contains "messy-fullstack → 有路徑含非 ASCII 字元，core.quotepath=off 列得出原字元" "報表匯出與排程作業" \
    "$(cd "$FXR/messy" && git -c core.quotepath=off ls-files)"
bash "$OV_SRC" "$FXR/messy" >/dev/null 2>&1
expect_eq "messy-fullstack → 現行 overview.sh 跑得出來（schema 2）、沒有 .last-error" "2 0" \
    "$(fx_ovq "$FXR/messy" '.schema') $([ -e "$FXR/messy/.claude/taskmaster-data/overview/.last-error" ] && echo 1 || echo 0)"

out=$(bash "$FXD/make-fixture.sh" 不存在的名稱 "$FXR/x" 2>&1 >/dev/null); rc=$?
expect_eq       "make-fixture.sh 不認得的名稱 → exit 2" 2 "$rc"
expect_contains "make-fixture.sh 不認得的名稱 → stderr 印用法" "用法" "$out"
bash "$FXD/make-fixture.sh" shop-clean >/dev/null 2>&1; rc=$?
expect_eq       "make-fixture.sh 少了目標目錄 → exit 2" 2 "$rc"
bash "$FXD/make-fixture.sh" shop-clean "$FXR/x" extra >/dev/null 2>&1; rc=$?
expect_eq       "make-fixture.sh 多了參數 → exit 2" 2 "$rc"
[ ! -e "$FXR/x" ] && ok "make-fixture.sh 參數錯誤 → 不建目標目錄" || ng "make-fixture.sh 參數錯誤 → 不建目標目錄" "沒有" "有"

out=$(bash "$FXD/gen-large.sh" abc "$FXR/big" 2>&1 >/dev/null); rc=$?
expect_eq       "gen-large.sh 檔案數不是正整數 → exit 2" 2 "$rc"
expect_contains "gen-large.sh 檔案數不是正整數 → stderr 印用法" "用法" "$out"
bash "$FXD/gen-large.sh" 5000 "$FXR/big" >/dev/null 2>&1; rc=$?
expect_eq "gen-large.sh 5000 → 產生成功" 0 "$rc"
fx_repo "$FXR/big"
expect_eq "gen-large.sh 5000 → git ls-files 恰好 5000 個" 5000 "$(cd "$FXR/big" && git ls-files | wc -l | tr -d ' ')"
expect_eq "gen-large.sh → 分散在 60 個目錄" 60 "$(cd "$FXR/big" && git ls-files | sed 's|/[^/]*$||' | sort -u | wc -l | tr -d ' ')"
expect_eq "gen-large.sh → 同時有 .py 與 .ts，且都帶 import" "1 1" \
    "$(cd "$FXR/big" && grep -q '^from src\.' src/m00/f0.py && echo 1 || echo 0) $(cd "$FXR/big" && grep -q "^import " src/m00/f60.ts && echo 1 || echo 0)"
rm -rf "$SANDBOX/任務 圖"

out=$(printf '%s\n' .claude/scripts/overview-scan.sh | bash "$HOOK_DIR/tests/run-tests.sh" --changed - --dry-run 2>&1)
expect_contains "--changed：overview-scan.sh 挑到 overview 的節（不是 NONE）" "overview fixture" "$out"
out=$(printf '%s\n' .claude/hooks/tests/fixtures/overview/make-fixture.sh | bash "$HOOK_DIR/tests/run-tests.sh" --changed - --dry-run 2>&1)
expect_contains "--changed：fixtures/overview 底下的檔挑到 overview 的節（含地圖節）" "overview.sh — 專案地圖" "$out"

# =========================================================================
section "overview-scan.sh — 骨架掃描與 5.5 合併"
# =========================================================================
# 每組資料一個獨立 repo，放在含中文與空格的目錄（主 checkout 在 D:\模板\… 的實況）。
# 跑的是 repo 裡的 overview.sh（它從自己的目錄找 overview-scan.sh）。
FXD="$HOOK_DIR/tests/fixtures/overview"
SC="$SANDBOX/掃描 測試"
rm -rf "$SC"; mkdir -p "$SC"
sc_ov()  { bash "$OV_SRC" "$SC/$1" >/dev/null 2>&1; }
sc_q()   { sed -n 's/^window\.OVERVIEW = //; s/;$//p' "$SC/$1/.claude/taskmaster-data/overview/data.js" 2>/dev/null | jq -r "$2" 2>/dev/null; }
sc_sk()  { jq -r "$2" < "$SC/$1/.claude/taskmaster-data/overview/skeleton.json" 2>/dev/null; }
sc_fx()  { rm -rf "$SC/$2"; bash "$FXD/make-fixture.sh" "$1" "$SC/$2" >/dev/null 2>&1; }
sc_git() { ( cd "$SC/$1" && git -c init.defaultBranch=main init -q . 2>/dev/null; git add -A && git -c user.email=t@t -c user.name=t commit -qm base ) >/dev/null 2>&1; }
sc_new() { rm -rf "$SC/$1"; mkdir -p "$SC/$1/.claude/taskmaster-data" "$SC/$1/docs"; echo '{"name":"掃描","mode":"mvp"}' > "$SC/$1/.claude/taskmaster-data/project.json"; }
# sc_put <repo> <檔> <內容（printf 格式）>
sc_put() { mkdir -p "$(dirname "$SC/$1/$2")"; printf "$3" > "$SC/$1/$2"; }
sc_err() { [ -e "$SC/$1/.claude/taskmaster-data/overview/.last-error" ] && cat "$SC/$1/.claude/taskmaster-data/overview/.last-error" || echo none; }

# ---- shop-clean：5.5 有效 → id 照 5.5，與階段 0 的 golden 相同
sc_fx shop-clean shop; sc_git shop; sc_ov shop
expect_eq "shop-clean（5.5 有效）→ 模組 id 排序後與 shop-clean.golden 相同、unmappedTasks 為空" \
    "$(awk '$1 == "module" { print $2 }' "$FXD/shop-clean.golden" | tr -d '\r' | sort | paste -sd' ' -) 0" \
    "$(sc_q shop '[.modules[].id] | sort | join(" ")') $(sc_q shop '.unmappedTasks | length')"
expect_eq "shop-clean → 每個模組的 source 都是 both" both "$(sc_q shop '[.modules[].source] | unique | join(",")')"
expect_eq "shop-clean → 沒有 .last-error" none "$(sc_err shop)"
# status 在階段 1 是 null，階段 2（一頁現況）起填值——這裡只驗欄位在、是物件
expect_eq "data.js schema 2 合約：drift 五個 key 都是陣列、模組 description null／planned false（沒有 plan）、currents 的 phase／phases null 與 activePhases []、有 status 物件" \
    "2 codeNotInDoc,docNotInCode,taskModuleMismatch,tasksInferred,wbsUnknownModule true true true true" \
    "$(sc_q shop '"\(.schema) \(.drift | keys | join(",")) \(.drift | [.[] | type == "array"] | all) \(all(.modules[]; .description == null and .planned == false)) \((.currents | length > 0) and all(.currents[]; .phase == null and .phases == null and .activePhases == [])) \(has("status") and (.status | type) == "object")"')"
sc_put shop src/search/a.py 'def a():\n    return 1\n'; sc_put shop src/search/b.py 'def b():\n    return 2\n'
# 接在 5.5 表最後一列（cache）之後：fixture 的表後面還有第 4、5 節，附加到檔尾就不在表裡了
sed -i '/^| cache | /a | legacy | 舊系統 | `src/legacy/**` | 已停用 |' "$SC/shop/docs/05_architecture.md"
sc_ov shop
expect_eq "5.5 多一列 src/legacy/**、沒有對應檔 → legacy 存在且 source:doc" "doc 0" \
    "$(sc_q shop '.modules[] | select(.id == "legacy") | "\(.source) \(.fileCount)"')"
expect_eq "程式多一個 src/search/（2 個檔）、5.5 沒寫 → search 模組 source:scan" "scan 2" \
    "$(sc_q shop '.modules[] | select(.id == "search") | "\(.source) \(.fileCount)"')"

# ---- 快取
SCK="$SC/shop/.claude/taskmaster-data/overview/skeleton.json"
touch -d '2001-01-01 00:00:00' "$SCK"; sck0=$(stat -c %Y "$SCK"); sc_ov shop
expect_eq "第二次執行、HEAD 與工作區都沒變 → skeleton.json 的 mtime 不變、scan.cached 為 true" "$sck0 true" \
    "$(stat -c %Y "$SCK") $(sc_q shop '.scan.cached')"
scf0=$(sc_q shop '.scan.files'); [[ $scf0 =~ ^[0-9]+$ ]] || scf0=-1; sc_put shop src/search/c.py 'from src.db.session import connect\n'; sc_ov shop
expect_eq "新增一個程式檔 → scan.cached 為 false、scan.files 加 1" "false $((scf0 + 1))" "$(sc_q shop '"\(.scan.cached) \(.scan.files)"')"
touch -d '2001-01-01 00:00:00' "$SC/shop/.claude/taskmaster-data/overview/.scan-files"
sc_put shop src/search/a.py 'from src.cache.client import get\n'; sc_ov shop
expect_eq "已在改動清單裡的檔再改一次（清單沒變）→ 仍重掃、新的 import 進得來" "false 1" \
    "$(sc_q shop '"\(.scan.cached) \([.edges[] | select(.from == "search" and .to == "cache")] | length)"')"

# ---- messy-fullstack：沒有 5.5 → 完全用掃描結果
sc_fx messy-fullstack messy
sc_put messy docs/gen.py 'x = 1\n'; sc_put messy .claude/hooks/tool.py 'y = 2\n'
sc_put messy backend/app/api/orders.py 'from app.services.orders import create\n\ndef post():\n    return create()\n'
sc_put messy backend/app/services/orders.py 'def create():\n    return 1\n'
sc_put messy frontend/src/pages/Cart.tsx "import React from 'react'\nimport { useCart } from '@/stores/cart'\n\nexport const Cart = () => useCart()\n"
sc_put messy frontend/src/stores/cart.ts 'export const useCart = () => 1\n'
sc_git messy; sc_ov messy
expect_eq "messy-fullstack → 主 checkout 路徑含中文與空格，掃描與合併成功、沒有 .last-error" "none true" "$(sc_err messy) $(sc_q messy '.modules | length > 0')"
expect_eq "messy-fullstack → 模組含 backend-api 與 frontend-api（跨套件撞名加套件目錄名）" "true true" \
    "$(sc_q messy '[.modules[].id] | "\(index("backend-api") != null) \(index("frontend-api") != null)"')"
expect_eq "messy-fullstack → 沒有 fileCount 為 0 的模組（C4 的使用者、LDAP、MSSQL、Redis 不畫）" 0 \
    "$(sc_q messy '[.modules[] | select(.fileCount == 0)] | length')"
expect_eq "messy-fullstack → 沒有以 tests／__tests__ 結尾的模組，測試檔只計數" "0 4" \
    "$(sc_q messy '[.modules[].id | select(test("(tests|__tests__)$"))] | length') $(sc_q messy '.scan.tests')"
expect_eq "messy-fullstack → 掃描的檔案不含 docs/、.claude/ 底下的檔" 0 \
    "$(sc_sk messy '[.files | keys[] | select(startswith("docs/") or startswith(".claude/"))] | length')"
scid=$(sc_q messy '.modules[] | select(.name == "報表匯出與排程作業") | .id')
rm -f "$SC/messy/.claude/taskmaster-data/overview/skeleton.json"; sc_ov messy
expect_eq "中文目錄 → id 符合 ^[a-z0-9-]+\$、name 是原目錄名、重掃後 id 相同" "1 $scid" \
    "$(printf '%s' "$scid" | grep -cE '^[a-z0-9-]+$') $(sc_q messy '.modules[] | select(.name == "報表匯出與排程作業") | .id')"
expect_eq "只有 1 個檔的目錄（utils）→ 不單獨成模組，檔案計入 other" "0 other" \
    "$(sc_q messy '[.modules[] | select(.name == "utils")] | length') $(sc_sk messy '.files["backend/app/utils/helpers.py"]')"
expect_eq "api/orders.py 寫 from app.services.orders import create → backend-api→services、source:import 的邊" 1 \
    "$(sc_q messy '[.edges[] | select(.from == "backend-api" and .to == "services" and .source == "import")] | length')"
expect_eq "Cart.tsx 寫 import … from '@/stores/cart' → pages→stores 的邊；import React from 'react' 不產生邊" "1 0" \
    "$(sc_q messy '[.edges[] | select(.from == "pages" and .to == "stores")] | length') $(sc_q messy '[.modules[].id] as $ids | [.edges[] | select(.from as $f | .to as $t | ($ids | index($f)) == null or ($ids | index($t)) == null)] | length')"
expect_eq "逐檔紀錄保留第三方 import（給階段 5 的 fileEdges）" 1 \
    "$(sc_sk messy '[.imports[] | select(. == ["frontend/src/pages/Cart.tsx", "pkg:react", "import"])] | length')"
OVERVIEW_SCAN_MAX_FILES=10 bash "$OV_SRC" "$SC/messy" >/dev/null 2>&1
expect_eq "OVERVIEW_SCAN_MAX_FILES=10 → import 邊 0、scan.truncated true、notices 有一則說明" "0 true 1" \
    "$(sc_q messy '[.edges[] | select(.source == "import")] | length') $(sc_q messy '.scan.truncated') $(sc_q messy '[.notices[] | select(.text | test("掃描上限"))] | length')"

# ---- 找架構文件（A1）
printf '%s' "$(jq -c 'del(.overview)' < "$SC/messy/.claude/taskmaster-data/project.json")" > "$SC/messy/.claude/taskmaster-data/project.json"
sc_ov messy
expect_eq "架構文件在 docs/architecture/x_architecture.md、project.json 沒有覆寫 → 自動指向它" \
    "docs/architecture/01_system_architecture.md" "$(sc_q messy '.project.architectureDoc')"
sc_new arch; sc_put arch docs/12_frontend_architecture.md '# 前端\n'; sc_put arch docs/architecture.md '# 系統\n'; sc_git arch; sc_ov arch
expect_eq "docs/12_frontend_architecture.md 與 docs/architecture.md 並存 → 用 docs/architecture.md" docs/architecture.md "$(sc_q arch '.project.architectureDoc')"
echo '{"name":"掃描","mode":"mvp","overview":{"architectureDoc":"docs/my.md"}}' > "$SC/arch/.claude/taskmaster-data/project.json"
sc_put arch docs/my.md '# 自訂\n'; sc_ov arch
expect_eq "project.json 設 overview.architectureDoc → 優先用它（docs/architecture.md 也在）" docs/my.md "$(sc_q arch '.project.architectureDoc')"
sc_new arch; sc_put arch docs/12_frontend_architecture.md '# 前端\n'; sc_git arch; sc_ov arch
expect_eq "只有 docs/12_frontend_architecture.md → architectureDoc 為 null" null "$(sc_q arch '.project.architectureDoc')"
expect_eq "沒有任何架構文件 → notices 沒有「找不到架構文件」" 0 "$(sc_q arch '[.notices[] | select(.text | test("找不到架構文件"))] | length')"

# ---- 標籤正規化（X8）
sc_new lab; sc_put lab src/ord/a.py 'x = 1\n'; sc_put lab src/ord/b.py 'y = 2\n'
{ echo '# 架構'; echo; echo '### 5.1 容器圖'; echo; echo '```mermaid'; echo 'graph TD'
  echo '    subgraph g1["前端&amp;<b>後端</b>"]'; echo '        ord["訂單<br/>處理&amp;出貨"]'; echo '    end'; echo '```'; echo
  echo '### 5.5 模組'; echo; echo '| id | 模組 | 路徑 | 職責 |'; echo '|---|---|---|---|'; echo '| ord |  | `src/ord/**` | 訂單 |'
} > "$SC/lab/docs/architecture.md"
sc_git lab; sc_ov lab
expect_eq "5.1 標籤 訂單<br/>處理&amp;出貨 → 名稱為「訂單 處理&出貨」" "訂單 處理&出貨" "$(sc_q lab '.modules[] | select(.id == "ord") | .name')"
expect_eq "data.js 的 name、label 都不含 <、&lt;、換行" 0 "$(sc_q lab '[.. | objects | (.name?, .label?) | strings | select(test("<|&lt;|\n"))] | length')"

# ---- 路由、上限、其他語言
sc_new rt
sc_put rt src/orders/api.py 'from fastapi import APIRouter\n\nrouter = APIRouter(prefix="/orders")\n\n@router.get("")\ndef list_all():\n    return []\n\n@router.post("")\ndef create():\n    return 1\n\n@router.get("/{order_id}")\ndef one(order_id: int):\n    return 1\n'
sc_put rt src/orders/models.py 'class Order:\n    id = 0\n'
sc_git rt; sc_ov rt
expect_eq "模組裡 3 個 FastAPI decorator → routes.count 3、sample 含 GET /orders" "3 true" \
    "$(sc_q rt '.modules[] | select(.id == "orders") | "\(.routes.count) \(.routes.sample | index("GET /orders") != null)"')"

sc_new big; bash "$FXD/gen-large.sh" 300 "$SC/big" >/dev/null 2>&1; sc_git big; sc_ov big
expect_eq "60 個各 ≥ 2 檔的目錄 → 模組 40 個，其中一個是 other" "40 1" "$(sc_q big '"\(.modules | length) \([.modules[] | select(.id == "other")] | length)"')"

sc_new poly
sc_put poly go.mod 'module example.com/shop\n\ngo 1.22\n'
sc_put poly gosvc/a.go 'package gosvc\n\nimport (\n\t"fmt"\n\t"example.com/shop/gostore"\n)\n\nfunc A() { fmt.Println(gostore.S) }\n'
sc_put poly gosvc/b.go 'package gosvc\n'; sc_put poly gostore/s.go 'package gostore\n\nvar S = 1\n'; sc_put poly gostore/t.go 'package gostore\n'
sc_put poly jorder/OrderController.java 'package com.shop.jorder;\n\nimport com.shop.jstore.Repo;\n\n@RequestMapping("/api/orders")\npublic class OrderController {\n    @GetMapping("/{id}")\n    public Repo one() { return null; }\n}\n'
sc_put poly jorder/Order.java 'package com.shop.jorder;\n'; sc_put poly jstore/Repo.java 'package com.shop.jstore;\npublic class Repo {}\n'; sc_put poly jstore/Db.java 'package com.shop.jstore;\n'
sc_put poly csorders/OrdersController.cs 'using Shop.CsStore;\n\nnamespace Shop.CsOrders;\n\n[Route("api/[controller]")]\npublic class OrdersController {\n    [HttpGet("{id}")]\n    public int One() => 1;\n}\n'
sc_put poly csorders/X.cs 'namespace Shop.CsOrders;\n'; sc_put poly csstore/Repo.cs 'namespace Shop.CsStore;\n'; sc_put poly csstore/Y.cs 'namespace Shop.CsStore;\n'
sc_put poly web/server.js "const router = require('express').Router()\n\nrouter.get('/items', (req, res) => res.json([]))\n"
sc_put poly web/util.js 'module.exports = {}\n'
sc_git poly; sc_ov poly
scedges=$(sc_q poly '[.edges[] | select(.source == "import") | "\(.from)>\(.to)"] | join(" ")')
expect_contains "Go：依 go.mod 的 module 前綴 → gosvc→gostore" "gosvc>gostore" "$scedges"
expect_contains "Java：package／import 對照 → jorder→jstore" "jorder>jstore" "$scedges"
expect_contains "C#：namespace／using 對照 → csorders→csstore" "csorders>csstore" "$scedges"
expect_eq "路由：Express、Spring、ASP.NET 各 1 條" "GET /items|GET /api/orders/{id}|GET /api/Orders/{id}" \
    "$(sc_q poly '[(.modules[] | select(.id == "web") | .routes.sample[0]), (.modules[] | select(.id == "jorder") | .routes.sample[0]), (.modules[] | select(.id == "csorders") | .routes.sample[0])] | join("|")')"

# ---- git 出錯不可吞掉：不寫骨架、不留快取（git grep 的 exit 1 只代表沒命中，要放行）
# 假 git 放在 PATH 最前面：FAKE_GIT_FAIL 指定的子指令回 128，其餘轉給真的 git
SCBIN="$SANDBOX/scbin"; mkdir -p "$SCBIN"
printf '#!/bin/bash\nREAL=%q\n' "$(command -v git)" > "$SCBIN/git"
cat >> "$SCBIN/git" <<'FAKEGIT'
a=("$@"); i=0
while [ "$i" -lt "${#a[@]}" ]; do case "${a[$i]}" in -C|-c) i=$((i + 2)) ;; -*) i=$((i + 1)) ;; *) break ;; esac; done
[ -n "${FAKE_GIT_FAIL:-}" ] && [ "${a[$i]:-}" = "$FAKE_GIT_FAIL" ] && { echo "fatal: 測試注入的 git $FAKE_GIT_FAIL 錯誤" >&2; exit 128; }
exec "$REAL" "$@"
FAKEGIT
chmod +x "$SCBIN/git"
# sc_scan <repo> [要失敗的 git 子指令] → 「out=<stdout> exit=<退出碼>」
sc_scan() { local o; o=$(PATH="$SCBIN:$PATH" FAKE_GIT_FAIL="${2:-}" bash "$OV_SCAN" "$SC/$1" 2>/dev/null); echo "out=$o exit=$?"; }
sc_new gnone; sc_put gnone src/a/x.py 'x = 1\n'; sc_put gnone src/a/y.py 'y = 2\n'; sc_git gnone
expect_eq "沒有任何 import 或路由（git grep exit 1）→ 照常 scanned、骨架有 2 個檔" "out=scanned exit=0 2" \
    "$(sc_scan gnone) $(sc_sk gnone '.scan.files')"
sc_new gerr
sc_put gerr src/a/x.py 'import os\n'; sc_put gerr src/a/y.py 'x = 1\n'; sc_put gerr src/b/z.py 'y = 2\n'; sc_put gerr src/b/w.py 'z = 3\n'
sc_git gerr; SCOV="$SC/gerr/.claude/taskmaster-data/overview"
expect_eq "git ls-files 出錯、還沒有骨架 → exit 1、stdout 空、不產生 skeleton.json" "out= exit=1 0" \
    "$(sc_scan gerr ls-files) $([ -f "$SCOV/skeleton.json" ] && echo 1 || echo 0)"
sc_put gerr src/a/y.py 'from src.b.z import y\n'
expect_eq "git 恢復正常（y.py 已在改動清單）→ scanned" "out=scanned exit=0" "$(sc_scan gerr)"
cp "$SCOV/skeleton.json" "$SANDBOX/sk-before.json"
# y.py 再改一次：改動清單不變（key 不變），只靠「比 .scan-files 新」判斷要重掃
sc_put gerr src/a/y.py 'from src.b.w import z\n'; touch -d '2001-01-01 00:00:00' "$SCOV/.scan-files"
expect_eq "git ls-files 出錯、已有骨架 → exit 1、skeleton.json 一個 byte 都沒變" "out= exit=1 0" \
    "$(sc_scan gerr ls-files) $(cmp -s "$SANDBOX/sk-before.json" "$SCOV/skeleton.json"; echo $?)"
expect_eq "git grep 出錯（exit 128，ls-files 正常）→ exit 1、skeleton.json 一個 byte 都沒變" "out= exit=1 0" \
    "$(sc_scan gerr grep) $(cmp -s "$SANDBOX/sk-before.json" "$SCOV/skeleton.json"; echo $?)"
expect_eq "失敗後 git 恢復 → 重掃（不是 cached）、新的 import 進得來" "out=scanned exit=0 1" \
    "$(sc_scan gerr) $(sc_sk gerr '[.imports[] | select(. == ["src/a/y.py", "src/b/w.py", "import"])] | length')"
sc_put gerr src/b/n.py 'q = 1\n'
PATH="$SCBIN:$PATH" FAKE_GIT_FAIL=grep bash "$OV_SRC" "$SC/gerr" >/dev/null 2>&1
expect_eq "overview.sh 遇到 git grep 出錯 → data.js 有「骨架掃描失敗」、.scan-error 記下 git 的訊息" "1 1" \
    "$(sc_q gerr '[.notices[] | select(.text | test("骨架掃描失敗"))] | length') $(grep -c '測試注入的 git grep 錯誤' "$SCOV/.scan-error" 2>/dev/null)"
rm -rf "$SCBIN" "$SANDBOX/sk-before.json"
rm -rf "$SC"

# =========================================================================
section "overview.sh — 落差、任務推斷、plan 疊層、架構自動段、一頁現況"
# =========================================================================
# 每組資料一個獨立 repo，放在含中文與空格的目錄。跑的是 repo 外的 overview.sh（OV_SRC），
# 它從自己的目錄找 overview-scan.sh。
DS="$SANDBOX/落差 測試"
rm -rf "$DS"; mkdir -p "$DS"
ds_ov()  { bash "$OV_SRC" "$DS/$1" >/dev/null 2>&1; }
ds_q()   { sed -n 's/^window\.OVERVIEW = //; s/;$//p' "$DS/$1/.claude/taskmaster-data/overview/data.js" 2>/dev/null | jq -r "$2" 2>/dev/null | tr -d '\r'; }
ds_md()  { tr -d '\r' < "$DS/$1/.claude/taskmaster-data/overview/overview.md" 2>/dev/null; }
ds_new() { rm -rf "$DS/$1"; mkdir -p "$DS/$1/.claude/taskmaster-data/plans" "$DS/$1/docs"; echo '{"name":"落差","mode":"mvp"}' > "$DS/$1/.claude/taskmaster-data/project.json"; }
ds_put() { mkdir -p "$(dirname "$DS/$1/$2")"; printf "$3" > "$DS/$1/$2"; }
ds_git() { ( cd "$DS/$1" && { [ -d .git ] || git init -q -b main . ; } && git add -A && git -c user.email=t@t -c user.name=t commit -qm "${2:-c}" ) >/dev/null 2>&1; }
# ds_two <repo> <目錄…>：每個目錄放兩個 .py
ds_two() { local r="$1" d; shift; for d in "$@"; do ds_put "$r" "$d/a.py" 'a = 1\n'; ds_put "$r" "$d/b.py" 'b = 2\n'; done; }
# ds_wbs <repo> <列…>：列為「編號|模組|狀態」；DS_NOCOL=1 時表頭沒有模組欄
ds_wbs() {
    local r="$1" row id mod st; shift
    {
        echo "# WBS"; echo; echo "## M1 基礎"; echo
        if [ -n "${DS_NOCOL:-}" ]; then echo "| # | 任務 | 狀態 | 優先 |"; echo "|---|---|---|---|"
        else echo "| # | 任務 | 模組 | 狀態 | 優先 |"; echo "|---|---|---|---|---|"; fi
        for row in "$@"; do
            IFS='|' read -r id mod st <<< "$row"
            if [ -n "${DS_NOCOL:-}" ]; then echo "| $id | 任務 $id | $st | 高 |"; else echo "| $id | 任務 $id | $mod | $st | 高 |"; fi
        done
    } > "$DS/$r/.claude/taskmaster-data/wbs.md"
}
# ds_plan <repo> <任務> <files（空白分隔，可空）> [各階段標題狀態…]：每個階段標題下一行是「依賴」行（ADR-006 四段格式）
ds_plan() {
    local r="$1" t="$2" i=1 s x; local -a fs=()
    read -r -a fs <<< "$3"; shift 3
    mkdir -p "$DS/$r/.claude/taskmaster-data/plans"
    {
        echo '---'; echo "wbs_task: \"$t\""; echo 'status: "🔄 進行中"'; echo "current_phase: ${DS_CP:-1}"; echo 'mode: "standard"'
        if [ ${#fs[@]} -gt 0 ]; then echo 'files:'; for x in "${fs[@]}"; do echo "  - \"$x\""; done; fi
        echo '---'; echo; echo "# 實作計畫：任務 $t"; echo
        echo '| id | 部件 | 階段 | 檔案 |'; echo '|---|---|---|---|'; echo "| p1 | 第一件 | 1 | \`${fs[0]:-src/x.py}\` |"; echo
        for s in "${@:-⏳}"; do echo "### 階段 $i: 第 $i 段 $s"; echo; echo "- **依賴**：階段 $((i - 1))"; echo; i=$((i + 1)); done
    } > "$DS/$r/.claude/taskmaster-data/plans/$t-x.md"
}
# 5.5 有效的架構文件：web、api 兩列；$2 附加在表後
ds_arch() {
    { echo '# 架構'; echo; echo '### 5.5 模組'; echo; echo '| id | 模組 | 路徑 | 職責 |'; echo '|---|---|---|---|'
      echo '| web | 前端 | `src/web/**` | 畫面 |'; echo '| api | 介面 | `src/api/**` | REST |'; [ -n "${2:-}" ] && echo "$2"; } > "$DS/$1/docs/architecture.md"
}

# ---- 落差：codeNotInDoc／docNotInCode／taskModuleMismatch
ds_new cd; ds_two cd src/web src/api src/search src/pay; ds_arch cd; ds_wbs cd "1.2|api|🔄 進行中"
ds_plan cd 1.2 "src/web/**"; ds_git cd; ds_ov cd
expect_eq "有效 5.5 沒寫、程式有 src/search/ → drift.codeNotInDoc 含 search" true "$(ds_q cd '[.drift.codeNotInDoc[].module] | index("search") != null')"
expect_eq "5.5 的路徑全部對得到檔 → drift.docNotInCode 為空陣列" "[]" "$(ds_q cd '.drift.docNotInCode | tojson')"
expect_eq "WBS 標 api、plan files: 只有 src/web/** → taskModuleMismatch 一筆 1.2：declared api、actual web" "1 api web" \
    "$(ds_q cd '[.drift.taskModuleMismatch[] | select(.task == "1.2")] | "\(length) \(.[0].declared | join(",")) \(.[0].actual | join(","))"')"
expect_eq "WBS 明標 api → 即使 plan files: 在別處，該任務 inferred 不是 true" false "$(ds_q cd '.tasks[] | select(.id == "1.2") | .inferred')"
expect_contains "有落差 → overview.md 有「## 落差」" "## 落差" "$(ds_md cd)"
expect_contains "有落差 → overview.md 的落差節列出各類數量（search、pay 兩個 5.5 沒寫）" "2 項" "$(ds_md cd | sed -n '/^## 落差/,/^## 任務圖/p' | grep search)"
ds_arch cd '| legacy | 舊系統 | `src/legacy/**` | 停用 |'; ds_ov cd
expect_eq "5.5 寫了 src/legacy/**、沒有對應檔 → drift.docNotInCode 含 legacy" true "$(ds_q cd '[.drift.docNotInCode[].module] | index("legacy") != null')"
ds_plan cd 1.2 "src/web/** src/api/**"; ds_ov cd
expect_eq "plan 同時碰 web 與 api（WBS 標 api）→ taskModuleMismatch 沒有 1.2" 0 "$(ds_q cd '[.drift.taskModuleMismatch[] | select(.task == "1.2")] | length')"

# ---- wbsUnknownModule
ds_wbs cd "1.2|api|🔄 進行中" "1.3|payment|⏳ 待處理"; ds_plan cd 1.3 "src/pay/**"; ds_ov cd
expect_eq "WBS 模組欄寫 payment、骨架沒有、plan files: 在 src/pay/** → wbsUnknownModule 有 payment、suggest pay" "1.3 payment pay" \
    "$(ds_q cd '.drift.wbsUnknownModule[] | select(.module == "payment") | "\(.task) \(.module) \(.suggest)"')"
ds_wbs cd "1.2|api|🔄 進行中" "1.3|—|⏳ 待處理"; ds_ov cd
expect_eq "WBS 模組欄寫 — → wbsUnknownModule 沒有 1.3" 0 "$(ds_q cd '[.drift.wbsUnknownModule[] | select(.task == "1.3")] | length')"
expect_eq "WBS 模組欄寫 —、plan files: 在 src/pay/** → 推斷成 pay（plan-files）" "pay true plan-files" \
    "$(ds_q cd '.tasks[] | select(.id == "1.3") | "\(.modules | join(",")) \(.inferred) \(.inferredBy)"')"

ds_new eight; ds_two eight src/m1 src/m2 src/m3 src/m4 src/m5 src/m6 src/m7 src/m8; ds_git eight; ds_ov eight
expect_eq "沒有架構文件、掃到 8 個模組 → codeNotInDoc 為空陣列" "8 []" "$(ds_q eight '"\(.modules | length) \(.drift.codeNotInDoc | tojson)"')"

# ---- 任務推斷：plan files: → 帳本 BASE 之後的 diff → 推斷不出
ds_new inf
ds_put inf backend/pyproject.toml '[project]\nname = "b"\n'; ds_two inf backend/app/services backend/app/api
ds_put inf frontend/package.json '{"name":"f"}\n'
ds_put inf frontend/src/pages/A.tsx 'export const A = 1\n'; ds_put inf frontend/src/pages/B.tsx 'export const B = 2\n'
ds_put inf frontend/src/stores/s.ts 'export const s = 1\n'; ds_put inf frontend/src/stores/t.ts 'export const t = 1\n'
DS_NOCOL=1 ds_wbs inf "2.1||🚫 阻塞" "2.2||⏳ 待處理" "2.3||⏳ 待處理"
ds_plan inf 2.1 "backend/app/services/**"; ds_plan inf 2.2 ""
ds_git inf
printf -- '# 執行帳本\n## 階段 1: 實作\n- 10:00 派工｜BASE=%s\n' "$(git -C "$DS/inf" rev-parse HEAD)" > "$DS/inf/.claude/taskmaster-data/plans/2.2-x.progress.md"
ds_put inf frontend/src/pages/A.tsx 'export const A = 2\n'
ds_ov inf
expect_eq "WBS 沒有模組欄、plan files: 全在 backend/app/services/** → modules [services]、inferred、plan-files" "services true plan-files" \
    "$(ds_q inf '.tasks[] | select(.id == "2.1") | "\(.modules | join(",")) \(.inferred) \(.inferredBy)"')"
expect_eq "plan 沒寫 files:、帳本 BASE 之後的 diff 落在 frontend/src/pages/ → modules [pages]、diff" "pages true diff" \
    "$(ds_q inf '.tasks[] | select(.id == "2.2") | "\(.modules | join(",")) \(.inferred) \(.inferredBy)"')"
expect_eq "沒有 plan 的任務推斷不出 → 留在 unmappedTasks" "2.3" "$(ds_q inf '.unmappedTasks | join(",")')"
expect_eq "推斷出 services 的任務是 🚫 阻塞 → services 模組 status 為 issue" issue "$(ds_q inf '.modules[] | select(.id == "services") | .status')"
expect_eq "推斷的任務列進 drift.tasksInferred" "2.1 2.2" "$(ds_q inf '[.drift.tasksInferred[].task] | join(" ")')"
expect_eq "--print-inferred → 一行一筆、3 欄 tab 分隔" "2.1	services	plan-files|2.2	pages	diff" \
    "$(bash "$OV_SRC" --print-inferred "$DS/inf" 2>/dev/null | tr -d '\r' | paste -sd'|' -)"
expect_contains "有推斷結果 → --print-path 有一行「提示：」含「推斷」" "推斷" "$(bash "$OV_SRC" --print-path "$DS/inf" 2>/dev/null | grep '^提示：')"
expect_eq "沒有推斷結果 → --print-inferred 輸出為空" "" "$(bash "$OV_SRC" --print-inferred "$DS/eight" 2>/dev/null)"
expect_eq "WBS 沒有模組欄 → 「還沒對到模組」的 notice 只有 1 則" 1 "$(ds_q inf '[.notices[] | select(.text | test("還沒對到模組"))] | length')"

# messy-fullstack：24 份帶 files:、4 份只有帳本 diff、4 個任務沒有 plan（X4）
bash "$FXD/make-fixture.sh" messy-fullstack "$DS/messy" >/dev/null 2>&1; ds_git messy
MAKE_FIXTURE_CHANGES=1 bash "$FXD/make-fixture.sh" messy-fullstack "$DS/messy" >/dev/null 2>&1; ds_ov messy
expect_eq "messy-fullstack → 有模組的任務 28 個（24 plan-files、4 diff）、unmappedTasks 恰好 4 個" "28 24 4 4" \
    "$(ds_q messy '"\([.tasks[] | select(.modules | length > 0)] | length) \([.tasks[] | select(.inferredBy == "plan-files")] | length) \([.tasks[] | select(.inferredBy == "diff")] | length) \(.unmappedTasks | length)"')"
expect_eq "messy-fullstack →「還沒對到模組」的 notice 只出現 1 則" 1 "$(ds_q messy '[.notices[] | select(.text | test("還沒對到模組"))] | length')"
expect_eq "messy-fullstack → --print-inferred 28 行、每行 3 欄 tab 分隔" "28 28" \
    "$(bash "$OV_SRC" --print-inferred "$DS/messy" 2>/dev/null | tr -d '\r' | awk -F'\t' 'NF == 3 && $2 != "" { n++ } END { print NR, n + 0 }')"

# shop-clean（5.5 有效、WBS 全標）→ 什麼落差都沒有
bash "$FXD/make-fixture.sh" shop-clean "$DS/shop" >/dev/null 2>&1; ds_git shop; ds_ov shop
expect_eq "shop-clean → drift 五類全空、tasks[] 沒有 inferred、overview.md 沒有「## 落差」" "0 0 0" \
    "$(ds_q shop '[.drift[] | length] | add') $(ds_q shop '[.tasks[] | select(.inferred == true)] | length') $(ds_md shop | grep -c '^## 落差')"

# ---- plan 疊層（A3）：shop-clean 的 .current-task 是 1.2
DS_CP=2 ds_plan shop 1.2 "src/services/a/**" ✅ 🔄 🔄 ⏳; ds_ov shop
expect_eq "本次任務 plan 的 files: 只有 src/services/a/** → 只有 svc-a 是 planned" "svc-a" "$(ds_q shop '[.modules[] | select(.planned) | .id] | join(",")')"
ds_plan shop 1.7 "src/web/**"; ds_ov shop
expect_eq "兩份 plan（files: src/services/a/**、src/web/**，本次是 1.2）→ plannedModules 各為 [svc-a]、[web]，planned 仍只有 svc-a" '["svc-a"] ["web"] svc-a' \
    "$(ds_q shop '"\([.plans[] | select(.task == "1.2") | .plannedModules] | first | tojson) \([.plans[] | select(.task == "1.7") | .plannedModules] | first | tojson) \([.modules[] | select(.planned) | .id] | join(","))"')"
rm -f "$DS/shop/.claude/taskmaster-data/plans/1.7-x.md"
expect_eq "plan 的階段 2、3 標題都是 🔄 → currents[].activePhases 為 [2,3]、phases 4、phase 取 current_phase" "[2,3] 4 2" \
    "$(ds_q shop '.currents[0] | "\(.activePhases | tojson) \(.phases) \(.phase)"')"
expect_eq "四段格式 plan（階段標題下一行是「依賴」）→ 階段名稱不含「依賴」、階段數等於 ### 階段 的數量、部件表照舊抽得到" "false 4 true" \
    "$(ds_q shop '.plans[] | select(.task == "1.2") | "\([.phases[].name] | any(test("依賴"))) \(.phases | length) \(.hasParts)"')"
DS_CP=1 ds_plan shop 1.2 "" ✅ ⏳ ⏳ ⏳; ds_ov shop
expect_eq "plan 沒有 files: → 沒有任何模組 planned" 0 "$(ds_q shop '[.modules[] | select(.planned)] | length')"
expect_eq "plan 沒有 files: → plannedModules 是 []" "[]" "$(ds_q shop '.plans[] | select(.task == "1.2") | .plannedModules | tojson')"
expect_eq "階段標題都不是 🔄、current_phase: 1 → activePhases 為 [1]" "[1]" "$(ds_q shop '.currents[0].activePhases | tojson')"

# ---- 架構文件自動段（--sync-arch）
DS_GS='<!-- overview:generated:start -->'; DS_GE='<!-- overview:generated:end -->'
# 去掉標記區（含標記行）後的內容：驗「標記外的位元組不變」
ds_outside() { awk '/^<!-- overview:generated:start/ { s = 1 } !s { print } /^<!-- overview:generated:end/ { s = 0 }' "$1"; }
ds_region()  { sed -n '/^<!-- overview:generated:start/,/^<!-- overview:generated:end/p' "$1" | tr -d '\r'; }
# 架構文件：第 4 節是標記區，第 5 節「資料流」緊接在 end 之後；檔尾刻意沒有換行
ds_genarch() {
    { printf '# 架構\n\n## 4. 模組與依賴\n\n%s\n舊的自動段\n%s\n## 5. 資料流\n\n手寫的流程，不能被動到。\n' "$DS_GS" "$DS_GE"; printf '最後一行沒有換行'; } > "$1"
}
ds_new arch; ds_two arch src/web src/api; ds_genarch "$DS/arch/docs/architecture.md"; ds_git arch
DSA="$DS/arch/docs/architecture.md"
ds_outside "$DSA" > "$SANDBOX/ds-out0.md"
out=$(bash "$OV_SRC" --sync-arch "$DS/arch" 2>&1); rc=$?
ds_outside "$DSA" | cmp -s - "$SANDBOX/ds-out0.md" && [ "$(tail -c 24 "$DSA")" = "最後一行沒有換行" ] \
    && ok "--sync-arch 有標記 → 標記外的位元組不變（含 end 之後的資料流節、檔尾沒有換行）" \
    || ng "--sync-arch 有標記 → 標記外的位元組不變" "cmp 相同、檔尾仍無換行" "$(ds_outside "$DSA" | diff - "$SANDBOX/ds-out0.md" | head -5)"
expect_eq "--sync-arch → exit 0、標記區含模組表表頭、舊內容被取代" "0 1 0" \
    "$rc $(ds_region "$DSA" | grep -cF '| id | 模組 | 分組 | 路徑 | 檔數 | 路由數 | 說明 |') $(ds_region "$DSA" | grep -c '舊的自動段')"
expect_eq "--sync-arch → end 標記前一行是模組表的列（沒有多出的空行）" "|" "$(ds_region "$DSA" | tail -n 2 | head -n 1 | cut -c1)"
cp "$DSA" "$SANDBOX/ds-arch-1.md"; bash "$OV_SRC" --sync-arch "$DS/arch" >/dev/null 2>&1
cmp -s "$SANDBOX/ds-arch-1.md" "$DSA" && ok "連跑兩次 --sync-arch → 架構文件 byte 相同" \
    || ng "連跑兩次 --sync-arch → 架構文件 byte 相同" "cmp 相同" "$(diff "$SANDBOX/ds-arch-1.md" "$DSA" | head -5)"

# CRLF 的架構文件（Windows 上常見）：標記外的位元組一個都不能變、標記區也要用 CRLF。
# 比對用 bash 讀整份（awk／sed 在 Git Bash 會吃掉 CR，拿它們比對會看不出差別）
ds_new crlf; ds_two crlf src/web src/api
printf '# 架構\r\n\r\n## 4. 模組與依賴\r\n\r\n%s\r\n舊的自動段\r\n%s\r\n## 5. 資料流\r\n\r\n手寫的流程。\r\n' "$DS_GS" "$DS_GE" > "$DS/crlf/docs/architecture.md"
ds_git crlf; DSC="$DS/crlf/docs/architecture.md"
ds_bytes() { local s; IFS= read -r -d '' s < "$1"; printf '%s' "$s"; }
ds_pre()  { local s; s=$(ds_bytes "$1"; printf x); s=${s%x}; printf '%s' "${s%%"$DS_GS"*}"; }
ds_post() { local s; s=$(ds_bytes "$1"; printf x); s=${s%x}; printf '%s' "${s#*"$DS_GE"}"; }
dsc_pre=$(ds_pre "$DSC"; printf x); dsc_post=$(ds_post "$DSC"; printf x)
bash "$OV_SRC" --sync-arch "$DS/crlf" >/dev/null 2>&1
expect_eq "CRLF 架構文件 --sync-arch → 標記外的位元組不變（含 CR）" "same same" \
    "$([ "$(ds_pre "$DSC"; printf x)" = "$dsc_pre" ] && echo same || echo diff) $([ "$(ds_post "$DSC"; printf x)" = "$dsc_post" ] && echo same || echo diff)"
expect_eq "CRLF 架構文件 --sync-arch → 整份沒有單獨的 LF（標記區內也是 CRLF）、區內有模組表" "0 1" \
    "$(( $(tr -cd '\n' < "$DSC" | wc -c) - $(tr -cd '\r' < "$DSC" | wc -c) )) $(grep -cF '| id | 模組 | 分組 |' "$DSC")"
ds_ov arch
expect_eq "標記區裡有模組表、標記區外沒有 5.5 → 沒有模組的 nameSource 是 doc" 0 "$(ds_q arch '[.modules[] | select(.nameSource == "doc")] | length')"
{ printf '# 架構\n\n### 5.5 模組\n\n| id | 模組 | 路徑 |\n|---|---|---|\n| web | 前端畫面 | `src/web/**` |\n\n'; cat "$DSA"; } > "$SANDBOX/ds-arch.md" && mv "$SANDBOX/ds-arch.md" "$DSA"
ds_ov arch
expect_eq "標記區外由 architect 撰寫的 5.5（舊格式）→ 照舊覆寫名稱" "前端畫面 doc" "$(ds_q arch '.modules[] | select(.id == "web") | "\(.name) \(.nameSource)"')"

ds_new nomark; ds_two nomark src/web src/api; printf '# 架構\n\n沒有標記\n' > "$DS/nomark/docs/architecture.md"; ds_git nomark
touch -d '2001-01-01 00:00:00' "$DS/nomark/docs/architecture.md"; cp "$DS/nomark/docs/architecture.md" "$SANDBOX/ds-nomark.md"
dsm0=$(stat -c %Y "$DS/nomark/docs/architecture.md")
out=$(bash "$OV_SRC" --sync-arch "$DS/nomark" 2>/dev/null)
expect_eq "沒有標記 → 檔案 mtime 與內容不變、stdout 有一行含「自動段標記」" "$dsm0 0 1" \
    "$(stat -c %Y "$DS/nomark/docs/architecture.md") $(cmp -s "$SANDBOX/ds-nomark.md" "$DS/nomark/docs/architecture.md"; echo $?) $(printf '%s\n' "$out" | grep -c '自動段標記')"
printf '# 架構\n\n%s\n舊\n\n## 5. 資料流\n' "$DS_GS" > "$DS/nomark/docs/architecture.md"; cp "$DS/nomark/docs/architecture.md" "$SANDBOX/ds-nomark.md"
bash "$OV_SRC" --sync-arch "$DS/nomark" >/dev/null 2>&1; rc=$?
expect_eq "只有 start 沒有 end → 檔案不變、exit 非 0" "0 1" \
    "$(cmp -s "$SANDBOX/ds-nomark.md" "$DS/nomark/docs/architecture.md"; echo $?) $([ "$rc" -ne 0 ] && echo 1 || echo 0)"

ds_new wt; ds_two wt src/web src/api; ds_genarch "$DS/wt/docs/architecture.md"; ds_git wt
DSWT="$DS/wt/.claude/worktrees/w1"
git -C "$DS/wt" worktree add -q -b w1 "$DSWT" >/dev/null 2>&1
cp "$DS/wt/docs/architecture.md" "$SANDBOX/ds-wt-main.md"; cp "$DSWT/docs/architecture.md" "$SANDBOX/ds-wt-wt.md"
bash "$OV_SRC" --sync-arch "$DSWT" >/dev/null 2>&1
expect_eq "在 worktree 執行 --sync-arch → 主 checkout 與 worktree 的架構文件都不變" "0 0" \
    "$(cmp -s "$SANDBOX/ds-wt-main.md" "$DS/wt/docs/architecture.md"; echo $?) $(cmp -s "$SANDBOX/ds-wt-wt.md" "$DSWT/docs/architecture.md"; echo $?)"
git -C "$DS/wt" worktree remove --force "$DSWT" >/dev/null 2>&1

# 邊超過 60 條：mermaid 只畫跨分組的邊，模組表照列。src/a1–a8 兩兩互相 import（56 條），
# web/ 是另一個套件：b1–b4 兩兩互相 import（12 條）、各 import 一次 src/a1（4 條跨分組）
ds_new big
for k in 1 2 3 4 5 6 7 8; do
    imp=""; for j in 1 2 3 4 5 6 7 8; do [ "$j" = "$k" ] || imp+="import { v } from '../a$j/x'\n"; done
    ds_put big "src/a$k/x.ts" "${imp}export const v = $k\n"; ds_put big "src/a$k/y.ts" 'export const w = 1\n'
done
ds_put big web/package.json '{"name":"w"}\n'
for k in 1 2 3 4; do
    imp="import { v } from '../../../src/a1/x'\n"; for j in 1 2 3 4; do [ "$j" = "$k" ] || imp+="import { v } from '../b$j/x'\n"; done
    ds_put big "web/src/b$k/x.ts" "${imp}export const v = $k\n"; ds_put big "web/src/b$k/y.ts" 'export const w = 1\n'
done
ds_genarch "$DS/big/docs/architecture.md"; ds_git big
bash "$OV_SRC" --sync-arch "$DS/big" >/dev/null 2>&1
expect_eq "掃到超過 60 條邊 → 自動段的 mermaid 只含跨分組的邊、模組表列數等於模組數" \
    "$(ds_q big '[.edges[] | select(.source == "import" or .source == "http")] as $e | (.modules | map({key: .id, value: .group}) | from_entries) as $g | "\($e | length > 60) \([$e[] | select($g[.from] != $g[.to])] | length) \(.modules | length)"')" \
    "true $(ds_region "$DS/big/docs/architecture.md" | grep -c ' --> ') $(( $(ds_region "$DS/big/docs/architecture.md" | grep -c '^| ') - 1 ))"

# ---- 一頁現況（--status）：shop-clean 加一份進行中 plan（階段 2、3 平行）；1.5 本來就是 🚫
DS_CP=2 ds_plan shop 1.2 "src/services/a/**" ✅ 🔄 🔄 ⏳; ds_ov shop
st=$(bash "$OV_SRC" --status "$DS/shop" 2>/dev/null | tr -d '\r')
expect_eq "--status 在 shop-clean 上 → ≤ 30 行，含「進行中」「阻塞」「下一個」「落差」" "1 1 1 1 1" \
    "$([ "$(printf '%s\n' "$st" | wc -l)" -le 30 ] && [ -n "$st" ] && echo 1 || echo 0) $(for k in 進行中 阻塞 下一個 落差; do printf '%s\n' "$st" | grep -q "$k" && printf '1 ' || printf '0 '; done | sed 's/ $//')"
expect_eq "overview.md 第一個二級標題是 ## 現況" 1 "$(ds_md shop | grep -m1 '^## ' | grep -c '^## 現況')"
expect_contains "進行中任務的 plan activePhases 為 [2,3]、共 4 階段 →「進行中」那行含 第 2、3／4 階段" "第 2、3／4 階段" "$(printf '%s\n' "$st" | grep 進行中)"
expect_contains "--status 的「阻塞」列出 🚫 任務 1.5" "1.5" "$(printf '%s\n' "$st" | grep 阻塞)"
expect_eq "沒有 docs/00_brief.md → --status 照常輸出、沒有一句話" "1 0" "$([ -n "$st" ] && echo 1 || echo 0) $(printf '%s\n' "$st" | grep -c '賣東西給大家')"
printf '# 簡介\n\n## 一句話\n\n賣東西給大家\n\n## 要解決的問題\n' > "$DS/shop/docs/00_brief.md"; ds_ov shop
expect_contains "有 docs/00_brief.md → --status 有「## 一句話」那一句" "賣東西給大家" "$(bash "$OV_SRC" --status "$DS/shop" 2>/dev/null)"
expect_eq "跑完後 data.js 的 status 不是 null" true "$(ds_q shop '.status != null and (.status | type) == "object"')"
expect_eq "跑完後 data.js 的 status.line 是非空字串（畫面頁首用，X17）" "true M1 基礎 4/7・進行中 1 項・阻塞 1 項" \
    "$(ds_q shop '"\((.status.line | type) == "string" and (.status.line | length) > 0) \(.status.line | sub("・落差.*$"; ""))"')"
expect_eq "task-status.md 含 overview.sh --sync-arch 與 overview.sh --status" "1 1" \
    "$(grep -q 'overview.sh --sync-arch' "$HOOK_DIR/../commands/task-status.md" && echo 1 || echo 0) $(grep -q 'overview.sh --status' "$HOOK_DIR/../commands/task-status.md" && echo 1 || echo 0)"

# =========================================================================
section "overview-scan.sh — 前後端 HTTP 連線、Maven／Gradle 慣例路徑"
# =========================================================================
# 沿用上一節的 ds_* 輔助函式（單獨跑這一節時上一節只取定義，所以這裡自己建目錄）
mkdir -p "$DS"

# ---- 前端 fetch 對後端路由（X6）
ds_new http
ds_put http backend/pyproject.toml '[project]\nname = "b"\n'
ds_put http backend/app/api/orders.py 'from fastapi import APIRouter\n\nrouter = APIRouter(prefix="/orders")\n\n@router.get("/{order_id}")\ndef one(order_id: int):\n    return 1\n'
ds_put http backend/app/api/deps.py 'x = 1\n'
ds_put http frontend/package.json '{"name":"f"}\n'
ds_put http frontend/src/api/orders.ts 'export const one = (id: string) => fetch(`/api/orders/${id}`)\n'
ds_put http frontend/src/api/client.ts 'export const base = 1\n'
ds_git http; ds_ov http
expect_eq "前端 fetch(\`/api/orders/\${id}\`)、後端 APIRouter(prefix=\"/orders\") 的 @router.get(\"/{order_id}\") → 一條 frontend-api→backend-api、source:http 的邊" \
    "1 backend-api" "$(ds_q http '[.edges[] | select(.from == "frontend-api" and .source == "http")] | "\(length) \(.[0].to)"')"
ds_put http frontend/src/api/orders.ts "export const x = () => fetch('https://example.com/x')\nexport const y = () => fetch('/api/nothing/here')\n"
ds_ov http
expect_eq "fetch 外部網址、或打到後端沒有的路徑 → 不產生 http 邊" 0 "$(ds_q http '[.edges[] | select(.source == "http")] | length')"

# ---- Maven／Gradle 慣例路徑（X16）：src/main/<lang>/ 剝掉套件前綴鏈，在第一個分岔切模組
ds_new mvn
for p in order payment user; do
    ds_put mvn "src/main/java/com/acme/shop/$p/A.java" "package com.acme.shop.$p;\n\npublic class A {}\n"
    ds_put mvn "src/main/java/com/acme/shop/$p/B.java" "package com.acme.shop.$p;\n\npublic class B {}\n"
done
ds_git mvn; ds_ov mvn
expect_eq "src/main/java/com/acme/shop/{order,payment,user}/*.java → 模組 id 恰為 order payment user（沒有 java、main、com、acme、shop）" \
    "order payment user" "$(ds_q mvn '[.modules[].id] | sort | join(" ")')"
ds_new kt
for p in billing report; do
    ds_put kt "src/main/kotlin/com/acme/$p/A.kt" "package com.acme.$p\n\nclass A\n"; ds_put kt "src/main/kotlin/com/acme/$p/B.kt" "package com.acme.$p\n\nclass B\n"
done
ds_git kt; ds_ov kt
expect_eq "src/main/kotlin/com/acme/{billing,report}/*.kt → 模組 billing report" "billing report" "$(ds_q kt '[.modules[].id] | sort | join(" ")')"
rm -rf "$DS/mm"; bash "$FXD/make-fixture.sh" maven-multi "$DS/mm" >/dev/null 2>&1; rc=$?
ds_git mm; ds_ov mm
expect_eq "maven-multi：api／worker 兩個子專案都有 order → 模組 api-order、worker-order，其餘套件照名" \
    "0 api-order mail payment report user worker-order" "$rc $(ds_q mm '[.modules[].id] | sort | join(" ")')"
# overview.scan.roots 在 Git Bash（gawk）上原本整個壞掉：awk 用了 gawk 內建變數名 RT 當陣列。這條同時驗修好了
echo '{"name":"落差","mode":"mvp","overview":{"scan":{"roots":["src/main/java"]}}}' > "$DS/mvn/.claude/taskmaster-data/project.json"; ds_ov mvn
expect_eq "同一份 Maven 樹、設了 overview.scan.roots → 以設定為準（src/main/java 的下一層 com），不自動偵測" "com" "$(ds_q mvn '[.modules[].id] | sort | join(" ")')"
# 期望值是 2-D 之前（03fe95f）的 overview.sh 在同樣兩份 fixture 上的結果
for fx in shop-clean messy-fullstack; do rm -rf "$DS/$fx"; bash "$FXD/make-fixture.sh" "$fx" "$DS/$fx" >/dev/null 2>&1; ds_git "$fx"; ds_ov "$fx"; done
expect_eq "Maven 自動切模組不影響 shop-clean、messy-fullstack 的模組 id（與 2-D 之前相同）" \
    "cache db gateway svc-a svc-b web|backend-api components core frontend-api m-5d3b69 models other pages services stores" \
    "$(ds_q shop-clean '[.modules[].id] | sort | join(" ")')|$(ds_q messy-fullstack '[.modules[].id] | sort | join(" ")')"

# =========================================================================
section "overview.sh — 說明層（module-notes.md、--check-notes、過期判定、--notes-todo）"
# =========================================================================
# 每組資料一個獨立 repo，放在含中文與空格的目錄（notes 檔的讀取要走暫存 ASCII 檔名，見 learned 2026-11-04）。
# 跑的是 repo 外的 overview.sh（OV_SRC）；post-write 的案例另把 overview.sh 複製進 repo 的 .claude/scripts。
MN="$SANDBOX/說明 測試"
FXD="$HOOK_DIR/tests/fixtures/overview"
rm -rf "$MN"; mkdir -p "$MN"
mn_ov()  { bash "$OV_SRC" "$MN/$1" >/dev/null 2>&1; }
mn_q()   { sed -n 's/^window\.OVERVIEW = //; s/;$//p' "$MN/$1/.claude/taskmaster-data/overview/data.js" 2>/dev/null | jq -r "$2" 2>/dev/null | tr -d '\r'; }
mn_new() { rm -rf "$MN/$1"; mkdir -p "$MN/$1/.claude/taskmaster-data" "$MN/$1/docs"; echo '{"name":"說明","mode":"mvp"}' > "$MN/$1/.claude/taskmaster-data/project.json"; }
mn_put() { mkdir -p "$(dirname "$MN/$1/$2")"; printf "$3" > "$MN/$1/$2"; }
mn_git() { ( cd "$MN/$1" && { [ -d .git ] || git init -q -b main . ; } && git add -A && git -c user.email=t@t -c user.name=t commit -qm "${2:-c}" ) >/dev/null 2>&1; }
mn_head() { git -C "$MN/$1" rev-parse --short "${2:-HEAD}" 2>/dev/null; }
# mn_notes <repo> <based_on> <列…>：列為「id|名稱|分組|說明|依據」；MN_HEAD 換掉表頭
mn_notes() {
    local r="$1" b="$2" row; shift 2
    { printf -- '---\nbased_on: %s   # 寫說明時的 HEAD\ngenerated: 2026-11-06\n---\n' "$b"
      echo "${MN_HEAD:-| id | 名稱 | 分組 | 說明 | 依據 |}"; echo '|---|---|---|---|---|'
      for row in "$@"; do echo "| ${row//|/ | } |"; done
    } > "$MN/$r/.claude/taskmaster-data/module-notes.md"
}
# mn_chk <repo>：--check-notes 的 stdout 與 exit code，印成「<rc>|<stdout>」
mn_chk() { local o rc; o=$(bash "$OV_SRC" --check-notes "$MN/$1" 2>/dev/null); rc=$?; printf '%s|%s' "$rc" "$(printf '%s' "$o" | tr -d '\r')"; }
mn_rep() { printf '%s' "$1" | grep -o "$2"; }
# n：後端 api、services 兩個模組，各兩個檔
mn_new n
mn_put n backend/pyproject.toml '[project]\nname = "b"\n'
for d in api services; do mn_put n "backend/app/$d/a.py" 'a = 1\n'; mn_put n "backend/app/$d/b.py" 'b = 2\n'; done
mn_git n; mn_ov n
GOOD_API='api|後端介面|後端|提供報表與使用者的查詢介面|`backend/app/api/a.py`'
GOOD_SVC='services|查詢服務|後端|依條件查詢報表資料|`backend/app/services/a.py`、`backend/app/services/b.py`'

# ---- --check-notes：規則照提案 5.3
rm -f "$MN/n/.claude/taskmaster-data/module-notes.md"
expect_eq "沒有 module-notes.md → --check-notes exit 0、stdout 為空" "0|" "$(mn_chk n)"
mn_notes n "$(mn_head n)" "$GOOD_API" "$GOOD_SVC"
expect_eq "格式正確、id 都在骨架裡 → --check-notes exit 0、stdout 為空" "0|" "$(mn_chk n)"
mn_notes n "$(mn_head n)" "$GOOD_API" 'nope|不存在的|後端|一句說明|`backend/app/api/a.py`'
out=$(mn_chk n)
expect_eq       "id 是 nope、骨架沒有 → exit 1" 1 "${out%%|*}"
expect_contains "id 是 nope → 一行「第 2 列 nope：…」" "第 2 列 nope：" "$out"
expect_contains "id 是 nope → 原因含「不存在」" "不存在" "$out"
expect_eq "id 是 nope → 合格的第 1 列沒有被報" "" "$(mn_rep "$out" '第 1 列')"
N12=$(printf '測%.0s' {1..12}); N13=$(printf '測%.0s' {1..13}); D60=$(printf '說%.0s' {1..60}); D61=$(printf '說%.0s' {1..61})
mn_notes n "$(mn_head n)" "api|$N13||一句說明|\`backend/app/api/a.py\`" "api|$N12||一句說明|\`backend/app/api/a.py\`" \
    "api|||$D61|\`backend/app/api/a.py\`" "api|||$D60|\`backend/app/api/a.py\`"
out=$(mn_chk n)
expect_eq "名稱 13 字違規、12 字不違規；說明 61 字違規、60 字不違規 → 只報第 1、3 列" "第 1 列|第 3 列" \
    "$(mn_rep "$out" '第 [0-9]* 列' | sort -u | paste -sd'|' -)"
expect_contains "名稱超過 → 原因含「名稱」與上限 12" "名稱 13 字" "$out"
expect_contains "說明超過 → 原因含「說明」與上限 60" "說明 61 字" "$out"
mn_notes n "$(mn_head n)" 'api|||一句說明|`backend/app/api/zz.py`' 'api|||一句說明|`backend/app/services/a.py`' 'api|||一句說明|'
out=$(mn_chk n)
expect_contains "依據的檔案不存在 → 違規" "第 1 列 api：依據 backend/app/api/zz.py 不存在" "$out"
expect_contains "依據存在但不在該模組路徑內 → 違規" "第 2 列 api：依據 backend/app/services/a.py 不在模組 api 的路徑內" "$out"
expect_contains "依據是空的 → 違規" "第 3 列 api：依據" "$out"
mn_notes n "$(mn_head n)" 'api|||連到 10.1.2.3 查資料|`backend/app/api/a.py`' 'api|||用 Server=db01 連線|`backend/app/api/a.py`' \
    'api|||設定 Data Source=x|`backend/app/api/a.py`' 'api|||檢查 PASSWORD 欄位|`backend/app/api/a.py`' \
    'api|||帶 PWD=1 登入|`backend/app/api/a.py`' 'api|||呼叫 https://u:p@host/x|`backend/app/api/a.py`' \
    'api|||通知 a@b.com|`backend/app/api/a.py`' 'api|||相容版本 1.2.3 的格式|`backend/app/api/a.py`'
out=$(mn_chk n)
expect_eq "機密樣式（IPv4、Server=、Data Source=、password、pwd=、網址帳密、Email，不分大小寫）→ 7 列各自違規；版本 1.2.3 不違規" \
    "第 1 列|第 2 列|第 3 列|第 4 列|第 5 列|第 6 列|第 7 列" "$(mn_rep "$out" '第 [0-9]* 列' | sort -u | paste -sd'|' -)"
expect_contains "password 違規 → 訊息提示改用中文「密碼」描述功能" "密碼" "$(printf '%s\n' "$out" | grep '^第 4 列')"
# 修復迴圈 R1（安全稽核）：句尾句點、不帶帳密的網址、全形與零寬字元、內網主機名要擋；套件版本、版本號、Node.js、「密碼」不擋
ZW=$(printf '\342\200\213')
mn_notes n "$(mn_head n)" 'api|||連到 10.1.2.3.|`backend/app/api/a.py`' 'api|||讀 postgresql://u@h 的資料|`backend/app/api/a.py`' \
    'api|||用 Server＝db01 連線|`backend/app/api/a.py`' "api|||檢查 pass${ZW}word 欄位|\`backend/app/api/a.py\`" \
    'api|||連到 １０．１．２．３|`backend/app/api/a.py`' 'api|||呼叫 db01.corp.local 的服務|`backend/app/api/a.py`' \
    'api|||相容 lodash@4.17.21 的格式|`backend/app/api/a.py`' 'api|||相容版本 1.2.3 的格式|`backend/app/api/a.py`' \
    'api|||用 Node.js 產生報表|`backend/app/api/a.py`' 'api|||處理密碼重設流程|`backend/app/api/a.py`'
out=$(mn_chk n)
expect_eq "句尾句點的 IP、postgresql://、全形 ＝、夾零寬字元的 password、全形 IP、*.corp.local → 6 列各自違規；lodash@4.17.21、版本 1.2.3、Node.js、密碼重設流程不違規" \
    "第 1 列|第 2 列|第 3 列|第 4 列|第 5 列|第 6 列" "$(mn_rep "$out" '第 [0-9]* 列' | sort -u | paste -sd'|' -)"
mn_notes n "$(mn_head n)" "$GOOD_API"; printf '\n備註：正式機是 Server=db01\n' >> "$MN/n/.claude/taskmaster-data/module-notes.md"
out=$(mn_chk n)
expect_eq       "表格以外的行含 Server=db01 → exit 1" 1 "${out%%|*}"
expect_contains "表格以外的行含 Server=db01 → 回報「表外第 9 行」" "表外第 9 行：" "$out"
mn_notes n "$(mn_head n)" 'api|||一句說明|`backend/app/api/../../../etc/passwd`' 'api|||一句說明|`/etc/passwd`'
out=$(mn_chk n)
expect_contains "依據含 .. 路徑段 → 違規（不去 stat）" "第 1 列 api：依據 backend/app/api/../../../etc/passwd 路徑不能含 .. 或絕對路徑" "$out"
expect_contains "依據以 / 開頭 → 違規" "第 2 列 api：依據 /etc/passwd 路徑不能含 .. 或絕對路徑" "$out"
MN_HEAD='| id | 名稱 | 分組 | 說明 |' mn_notes n "$(mn_head n)" 'api|後端介面|後端|提供查詢介面'
out=$(mn_chk n)
expect_eq       "表頭少了「依據」欄 → exit 1" 1 "${out%%|*}"
expect_contains "表頭少了「依據」欄 → 原因含「表頭」與缺的欄名" "表頭" "$out"
expect_contains "表頭少了「依據」欄 → 指出缺「依據」" "依據" "$out"

# ---- post-write：寫入 module-notes.md 時前景驗證並注入；其他寫入不跑
mkdir -p "$MN/n/.claude/scripts" "$MN/n/.claude/templates/overview"
cp "$OV_SRC" "$MN/n/.claude/scripts/overview.sh"; cp "$OV_SCAN" "$MN/n/.claude/scripts/overview-scan.sh"
cp "$OV_TPL" "$MN/n/.claude/templates/overview/index.html"
mn_pw() { local f="$1"; shift; run post-write.sh "$(w "$MN/n/$f")" CLAUDE_PROJECT_DIR="$MN/n" OVERVIEW_SYNC=1 "$@"; }
mn_notes n "$(mn_head n)" "$GOOD_API" 'services|||用 Server=db01 連線|`backend/app/services/a.py`'
out=$(mn_pw .claude/taskmaster-data/module-notes.md)
expect_eq       "post-write 寫入含 Server=db01 的 notes → stdout 是 JSON" PostToolUse "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)"
expect_contains "post-write 注入的 additionalContext 含該列的列號與 id" "第 2 列 services" \
    "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
expect_eq "post-write 寫入 notes 時也重產地圖（OVERVIEW_SYNC=1 前景）→ 合格的 api 有說明、違規的 services 沒有" "提供報表與使用者的查詢介面|null" \
    "$(mn_q n '"\(.modules[] | select(.id == "api") | .description.text)|\(.modules[] | select(.id == "services") | .description)"')"
out=$(mn_pw .claude/taskmaster-data/plans/1.1-x.md)
expect_empty "notes 有違規、但寫入的是 plan → post-write 不跑 --check-notes、沒有輸出" "$out"
mkdir -p "$MN/n/.claude/worktrees/w/.claude/taskmaster-data"
out=$(mn_pw .claude/worktrees/w/.claude/taskmaster-data/module-notes.md)
expect_empty "寫入 .claude/worktrees/ 底下的 notes（相對 WORK_ROOT 不是 .claude/taskmaster-data/module-notes.md）→ 不驗證、沒有輸出" "$out"
rm -rf "$MN/n/.claude/worktrees"
echo off > "$MN/n/.claude/taskmaster-data/.suggest-mode"
out=$(mn_pw .claude/taskmaster-data/module-notes.md)
expect_contains ".suggest-mode 為 off 時寫入含違規的 notes → 仍注入" "第 2 列 services" "$out"
rm -f "$MN/n/.claude/taskmaster-data/.suggest-mode"
mn_notes n "$(mn_head n)" "$GOOD_API" "$GOOD_SVC"
expect_empty "post-write 寫入合格的 notes → stdout 為空" "$(mn_pw .claude/taskmaster-data/module-notes.md)"

# ---- 讀 notes：違規的列當作沒有說明；名稱、分組的優先序 5.5 → notes → 目錄名
mn_notes n "$(mn_head n)" "$GOOD_API" 'services|查詢服務|後端|依條件查詢報表資料|`backend/app/api/a.py`'
mn_ov n
expect_eq "某列違規 → 該模組 description 為 null，其他合格列照常填入（text、evidence、stale）" \
    "null|提供報表與使用者的查詢介面|backend/app/api/a.py|false" \
    "$(mn_q n '"\(.modules[] | select(.id == "services") | .description)|\(.modules[] | select(.id == "api") | .description | "\(.text)|\(.evidence | join(","))|\(.stale)")"')"
expect_eq "沒有 5.5 → 名稱取 notes、nameSource notes；違規列的名稱不採用（仍是目錄名）" "後端介面 notes|services dir" \
    "$(mn_q n '[.modules[] | select(.id == "api" or .id == "services") | "\(.name) \(.nameSource)"] | join("|")')"
expect_eq "沒有 5.5 → 分組取 notes 寫的「後端」" "後端" \
    "$(mn_q n '(.modules[] | select(.id == "api") | .group) as $g | .groups[] | select(.id == $g) | .label')"
mn_new doc
for f in a b; do mn_put doc "src/auth/$f.py" 'x = 1\n'; mn_put doc "src/web/$f.ts" 'export const x = 1\n'; done
{ echo '# 架構'; echo; echo '### 5.5 模組'; echo; echo '| id | 模組 | 路徑 | 職責 |'; echo '|---|---|---|---|'
  echo '| auth | 認證中心 | `src/auth/**` | 登入 |'; echo '| web | 前端 | `src/web/**` | 畫面 |'; } > "$MN/doc/docs/architecture.md"
mn_git doc
mn_notes doc "$(mn_head doc)" 'auth|登入與權限|後端|驗證帳號並簽發登入憑證|`src/auth/a.py`'
mn_ov doc
expect_eq "notes 有 auth、5.5 也有 auth → 名稱取 5.5、nameSource doc，說明照填" "認證中心|doc|驗證帳號並簽發登入憑證" \
    "$(mn_q doc '.modules[] | select(.id == "auth") | "\(.name)|\(.nameSource)|\(.description.text)"')"
rm -f "$MN/doc/docs/architecture.md"; mn_git doc; mn_ov doc
expect_eq "同一份 notes、沒有 5.5 → 名稱取 notes、nameSource notes" "登入與權限|notes" \
    "$(mn_q doc '.modules[] | select(.id == "auth") | "\(.name)|\(.nameSource)"')"

# ---- 過期判定（提案 5.4）
mn_put n README.md 'r\n'; mn_git n second
mn_notes n "$(mn_head n HEAD~1)" "$GOOD_API" "$GOOD_SVC"
mn_put n backend/app/services/a.py 'a = 2\n'
mn_ov n
expect_eq "based_on 是 HEAD~1、之後改了 backend/app/services/a.py → services stale true、api false" "true false" \
    "$(mn_q n '"\(.modules[] | select(.id == "services") | .description.stale) \(.modules[] | select(.id == "api") | .description.stale)"')"
mn_notes n 0123abcd "$GOOD_API" "$GOOD_SVC"; mn_ov n
expect_eq "based_on 是不存在的 sha → 所有有說明的模組 stale 為 true" "true true" \
    "$(mn_q n '[.modules[] | select(.description != null) | .description.stale] | map(tostring) | join(" ")')"
expect_eq "based_on 是不存在的 sha → notices 有一則說明（含 based_on）" 1 "$(mn_q n '[.notices[] | select(.text | test("based_on"))] | length')"
git -C "$MN/n" checkout -q -- backend/app/services/a.py 2>/dev/null

# ---- --print-path 提示與 overview.notes: off
mn_new ten
for i in 1 2 3 4 5 6 7 8 9 10; do mn_put ten "src/m$i/a.py" 'a = 1\n'; mn_put ten "src/m$i/b.py" 'b = 2\n'; done
mn_git ten
rows=(); for i in 1 2 3 4 5 6 7; do rows+=("m$i|模組 $i||第 $i 個模組的用途|\`src/m$i/a.py\`"); done
mn_notes ten "$(mn_head ten)" "${rows[@]}"
mn_put ten src/m1/a.py 'a = 9\n'; mn_put ten src/m2/b.py 'b = 9\n'
mn_ov ten
expect_eq "10 個模組中 3 個沒說明、2 個過期 → --print-path 有「提示：3 個模組沒有說明、2 個可能過期」" 1 \
    "$(bash "$OV_SRC" --print-path "$MN/ten" 2>/dev/null | grep -c '^提示：3 個模組沒有說明、2 個可能過期')"
out=$(bash "$OV_SRC" --notes-todo "$MN/ten" 2>/dev/null | tr -d '\r')
expect_eq "--notes-todo → 只列沒有說明或過期的模組（m1 m2 stale、m8 m9 m10 missing）" "m1 stale|m10 missing|m2 stale|m8 missing|m9 missing" \
    "$(printf '%s\n' "$out" | awk -F'\t' '{ print $1, $4 }' | sort | paste -sd'|' -)"
expect_eq "--notes-todo → 每行 4 欄、第 3 欄 1–3 個檔且都在該模組路徑內" "" \
    "$(printf '%s\n' "$out" | awk -F'\t' '{ n = split($3, f, ","); if (NF != 4 || n < 1 || n > 3) print "欄數或檔數不對：" $0; for (i = 1; i <= n; i++) if (index(f[i], "src/" $1 "/") != 1) print "不在模組內：" f[i] }')"
echo '{"name":"說明","mode":"mvp","overview":{"notes":"off"}}' > "$MN/ten/.claude/taskmaster-data/project.json"; mn_ov ten
expect_eq "overview.notes: off → 所有 description 為 null" 0 "$(mn_q ten '[.modules[] | select(.description != null)] | length')"
expect_eq "overview.notes: off → --print-path 沒有說明層的提示行" 0 \
    "$(bash "$OV_SRC" --print-path "$MN/ten" 2>/dev/null | grep -c '^提示：.*說明')"

# ---- 不可退化：沒有 module-notes.md 時名稱、分組與階段 2 相同（期望值是階段 2 完成時 f219d59 在 messy-fullstack 上的結果）
rm -rf "$MN/messy"; bash "$FXD/make-fixture.sh" messy-fullstack "$MN/messy" >/dev/null 2>&1; mn_git messy; mn_ov messy
expect_eq "沒有 module-notes.md → messy-fullstack 的 id／名稱／分組與階段 2 相同、description 全為 null" \
    "backend-api api pkg-backend|components components pkg-frontend|core core pkg-backend|frontend-api api pkg-frontend|m-5d3b69 報表匯出與排程作業 pkg-backend|models models pkg-backend|other 其他 _ungrouped|pages pages pkg-frontend|services services pkg-backend|stores stores pkg-frontend|0" \
    "$(mn_q messy '([.modules[] | "\(.id) \(.name) \(.group)"] | sort | join("|")) + "|" + ([.modules[] | select(.description != null)] | length | tostring)')"
expect_eq "沒有 module-notes.md → 有程式檔的模組都算「沒有說明」（other 不算）" 1 \
    "$(bash "$OV_SRC" --print-path "$MN/messy" 2>/dev/null | grep -c '^提示：9 個模組沒有說明、0 個可能過期')"

# ---- make-fixture.sh 的 notes 選項：messy-fullstack 的 module-notes.md，含刻意違規的列
MAKE_FIXTURE_NOTES=1 bash "$FXD/make-fixture.sh" messy-fullstack "$MN/messy" >/dev/null 2>&1; rc=$?
expect_eq "MAKE_FIXTURE_NOTES=1 → 產生成功、寫出 module-notes.md、based_on 是目前的 HEAD" "0 $(mn_head messy)" \
    "$rc $(sed -n 's/^based_on:[[:space:]]*\([0-9a-f]*\).*/\1/p' "$MN/messy/.claude/taskmaster-data/module-notes.md" 2>/dev/null)"
out=$(bash "$OV_SRC" --check-notes "$MN/messy" 2>/dev/null | tr -d '\r'); rc=$?
expect_eq "fixture 的 notes → --check-notes exit 1，違規的是 nope、機密與依據不在模組內那三列" "1 frontend-api|m-5d3b69|nope" \
    "$rc $(printf '%s\n' "$out" | sed -n 's/^第 [0-9]* 列 \([^：]*\)：.*/\1/p' | sort -u | paste -sd'|' -)"
mn_ov messy
expect_eq "fixture 的 notes → 合格的列有說明（backend-api、services、pages），違規的沒有" "backend-api pages services" \
    "$(mn_q messy '[.modules[] | select(.description != null) | .id] | sort | join(" ")')"
rm -rf "$MN"

# =========================================================================
section "overview.sh — 模組展開資料（fileEdges、inner、資料流）"
# =========================================================================
# 地圖計畫階段 5（ADR-2026-11-06-002 決策 1–3）。每組資料一個獨立 repo，放在含中文與空格的目錄。
MX="$SANDBOX/展開 測試"
FXD="$HOOK_DIR/tests/fixtures/overview"
rm -rf "$MX"; mkdir -p "$MX"
mx_ov()  { bash "$OV_SRC" "$MX/$1" >/dev/null 2>&1; }
mx_q()   { sed -n 's/^window\.OVERVIEW = //; s/;$//p' "$MX/$1/.claude/taskmaster-data/overview/data.js" 2>/dev/null | jq -r "$2" 2>/dev/null | tr -d '\r'; }
mx_sk()  { jq -r "$2" < "$MX/$1/.claude/taskmaster-data/overview/skeleton.json" 2>/dev/null | tr -d '\r'; }
mx_new() { rm -rf "$MX/$1"; mkdir -p "$MX/$1/.claude/taskmaster-data" "$MX/$1/docs"; echo '{"name":"展開","mode":"mvp"}' > "$MX/$1/.claude/taskmaster-data/project.json"; }
mx_put() { mkdir -p "$(dirname "$MX/$1/$2")"; printf -- "$3" > "$MX/$1/$2"; }
mx_git() { ( cd "$MX/$1" && { [ -d .git ] || git init -q -b main . ; } && git add -A && git -c user.email=t@t -c user.name=t commit -qm "${2:-c}" ) >/dev/null 2>&1; }
# mx_in <repo> <模組 id> <jq>：對該模組的 inner 跑 jq
mx_in()  { mx_q "$1" ".modules[] | select(.id == \"$2\") | .inner | $3"; }
mx_region() { sed -n '/^<!-- overview:generated:start/,/^<!-- overview:generated:end/p' "$1" | tr -d '\r'; }
mx_after()  { local s; IFS= read -r -d '' s < "$1"; printf '%s' "${s#*"<!-- overview:generated:end -->"}"; }

# ---- x：後端 orders（api.py→service.py、資料庫、外部套件、標準庫）＋前端 pages／stores（@/ 別名、HTTP、React）
mx_new x
mx_put x backend/pyproject.toml '[project]\nname = "b"\n'
mx_put x backend/app/orders/api.py 'from app.orders.service import x\nfrom sqlalchemy.orm import Session\nimport httpx\nimport os\nimport mydb\nfrom fastapi import APIRouter\n\nrouter = APIRouter(prefix="/orders")\n\n@router.get("/{order_id}")\ndef one(order_id: int):\n    return x\n'
mx_put x backend/app/orders/service.py 'x = 1\n'
mx_put x frontend/package.json '{"name":"f"}\n'
mx_put x frontend/src/pages/Cart.tsx "import React from 'react'\nimport cart from '@/stores/cart'\nimport { readFileSync } from 'node:fs'\n\nexport const one = (id: string) => fetch(\`/api/orders/\${id}\`)\n"
mx_put x frontend/src/pages/Home.tsx 'export const Home = 1\n'
mx_put x frontend/src/stores/cart.ts 'export default 1\n'
mx_put x frontend/src/stores/user.ts 'export const u = 1\n'
mx_put x backend/app/orders/test_api.py 'from app.orders.service import x\nimport pytest\n\ndef test_x():\n    assert x\n'
mx_git x; mx_ov x
expect_eq "api.py 寫 from app.orders.service import x → orders 的 inner.edges 有一條 api.py→service.py" 1 \
    "$(mx_in x orders '(.nodes | index("api.py")) as $a | (.nodes | index("service.py")) as $s | [.edges[] | select(.[0] == $a and .[1] == $s)] | length')"
expect_eq "api.py 寫 from sqlalchemy.orm import Session、import httpx、import os → orders 的 inner.out 含 db:sqlalchemy 與 pkg:httpx，沒有指向 os 的項目" \
    "true true 0" "$(mx_in x orders '"\(any(.out[]; .[1] == "db:sqlalchemy")) \(any(.out[]; .[1] == "pkg:httpx")) \([.out[] | select(.[1] | test(":os$"))] | length)"')"
expect_eq "skeleton.json 的 fileEdges：檔對檔 to 填路徑、ext null；資料庫 to null、ext db:sqlalchemy；標準庫 os 不進" "1 1 0" \
    "$(mx_sk x '"\([.fileEdges[] | select(. == {from: "backend/app/orders/api.py", to: "backend/app/orders/service.py", ext: null, source: "import"})] | length) \([.fileEdges[] | select(. == {from: "backend/app/orders/api.py", to: null, ext: "db:sqlalchemy", source: "import"})] | length) \([.fileEdges[] | select((.ext // "") | test(":os$"))] | length)"')"
expect_eq "前端 import … from '@/stores/cart'（stores 是另一模組）→ pages 的 inner.out 有一筆 m:stores、import（從 Cart.tsx）" 1 \
    "$(mx_in x pages '(.nodes | index("Cart.tsx")) as $c | [.out[] | select(.[0] == $c and .[1] == "m:stores" and .[3] == "import")] | length')"
expect_eq "前端 fetch 對到後端路由（X6）→ pages 的 inner.out 有一筆 m:orders、http" 1 \
    "$(mx_in x pages '[.out[] | select(.[1] == "m:orders" and .[3] == "http")] | length')"
expect_eq "import React from 'react' → 模組層 edges 只有 pages→orders（http）與 pages→stores（import）；pages 的 inner.out 多一筆 pkg:react；node:fs 不進" \
    "pages>orders:http pages>stores:import|1 0" \
    "$(mx_q x '[.edges[] | "\(.from)>\(.to):\(.source)"] | sort | join(" ")')|$(mx_in x pages '"\([.out[] | select(.[1] == "pkg:react")] | length) \([.out[] | select(.[1] | test("fs$"))] | length)"')"
expect_eq "inner 的欄位照 ADR 決策 1：root 是模組的共同目錄、nodes 是相對路徑、folded 0、outMore 0；data.js schema 仍為 2" \
    "backend/app/orders|api.py,service.py|0 0|2" \
    "$(mx_in x orders '"\(.root)|\(.nodes | join(","))|\(.folded) \(.outMore)"')|$(mx_q x '.schema')"
expect_eq "測試檔（orders/test_api.py）不進 inner：不是節點、它的 import pytest 不在 out" "false 0" \
    "$(mx_in x orders '"\(.nodes | index("test_api.py") != null) \([.out[] | select(.[1] == "pkg:pytest")] | length)"')"
expect_eq "框外依「其他模組 → 資料庫 → 外部套件」排序（pages：m、m、pkg；orders：db 在 pkg 前）" "m m pkg|db pkg pkg pkg" \
    "$(mx_in x pages '[.out[][1] | split(":")[0]] | join(" ")')|$(mx_in x orders '[.out[][1] | split(":")[0]] | join(" ")')"
OVERVIEW_INNER_MAX_OUT=2 mx_ov x
expect_eq "OVERVIEW_INNER_MAX_OUT=2 → orders 的 out 只留 2 筆（db 優先、同類同次數依名稱）、其餘 2 個目標計入 outMore" "2|db:sqlalchemy,pkg:fastapi|2" \
    "$(mx_in x orders '"\(.out | length)|\([.out[][1]] | join(","))|\(.outMore)"')"
mx_ov x
expect_eq "沒設 overview.scan.dbPackages → import mydb 歸成 pkg:mydb" "1 0" \
    "$(mx_in x orders '"\([.out[] | select(.[1] == "pkg:mydb")] | length) \([.out[] | select(.[1] == "db:mydb")] | length)"')"
echo '{"name":"展開","mode":"mvp","overview":{"scan":{"dbPackages":["mydb"]}}}' > "$MX/x/.claude/taskmaster-data/project.json"; mx_ov x
expect_eq "project.json 設 overview.scan.dbPackages: [\"mydb\"]、程式寫 import mydb → inner.out 含 db:mydb、不含 pkg:mydb" "1 0" \
    "$(mx_in x orders '"\([.out[] | select(.[1] == "db:mydb")] | length) \([.out[] | select(.[1] == "pkg:mydb")] | length)"')"

# ---- 資料流節（決策 3）：三條流程＋第 6 節裡的 ###（不是資料流節，不算）
{ printf '# 架構\n\n## 4. 模組與依賴\n\n<!-- overview:generated:start -->\n<!-- overview:generated:end -->\n## 5. 資料流\n\n'
  printf '### orders 結帳 — 正常結帳（ORD-01）\n\n```mermaid\nsequenceDiagram\n    participant orders as 訂單服務\n    participant pay as 金流商（外部）\n    orders->>pay: 請款\n```\n\n'
  printf '### pages 前端 — 看購物車（CART-01）\n\n```mermaid\nsequenceDiagram\n    actor user as 顧客\n    participant pkg-frontend as 前端\n    user->>pkg-frontend: 打開購物車\n```\n\n'
  printf '### billing 對帳 — 每日對帳（排程：每日 02:00）\n\n```mermaid\nsequenceDiagram\n    participant billing as 對帳服務\n    participant bank as 銀行（外部）\n    billing->>bank: 下載對帳檔\n```\n\n'
  printf '## 6. 其他\n\n### 不是流程\n\n```mermaid\nsequenceDiagram\n    participant orders as 訂單\n```\n'
} > "$MX/x/docs/architecture.md"
mx_ov x
expect_eq "資料流節有一條流程宣告 participant orders、participant pay → flows[0] 的 participants 為 orders,pay、modules 為 [\"orders\"]、orders 的 flows 含 0" \
    "orders,pay|[\"orders\"]|true" \
    "$(mx_q x '"\(.flows[0].participants | join(","))|\(.flows[0].modules | tojson)|\(.modules[] | select(.id == "orders") | .flows | index(0) != null)"')"
expect_eq "flows[].title 是 ### 後的整段標題、line 是它在架構文件的行號；資料流節以外的 ### 不算" \
    "3|orders 結帳 — 正常結帳（ORD-01）|$(grep -n '^### orders 結帳' "$MX/x/docs/architecture.md" | cut -d: -f1)" \
    "$(mx_q x '"\(.flows | length)|\(.flows[0].title)|\(.flows[0].line)"')"
expect_eq "流程參與者 id 等於分組 id（pkg-frontend）→ 該分組每個模組（pages、stores）的 flows 都含 1；每個模組都有 flows 陣列" "true true true" \
    "$(mx_q x '"\(.modules[] | select(.id == "pages") | .flows | index(1) != null) \(.modules[] | select(.id == "stores") | .flows | index(1) != null) \(all(.modules[]; (.flows | type) == "array"))"')"
expect_eq "參與者全部對不到模組的流程 → notices 恰好一則「對不到任何模組」、含該流程標題；部分對不到（pay、user）的沒有" "1 1" \
    "$(mx_q x '[.notices[] | select(.text | test("對不到任何模組"))] | "\(length) \([.[] | select(.text | contains("billing 對帳 — 每日對帳（排程：每日 02:00）"))] | length)"')"
printf '# 架構\n\n## 4. 模組與依賴\n\n手寫的說明，沒有資料流節。\n' > "$MX/x/docs/architecture.md"; mx_ov x
expect_eq "架構文件沒有資料流節 → flows 為 []、notices 沒有資料流相關的項目" "[] 0" "$(mx_q x '"\(.flows | tojson) \([.notices[] | select(.text | test("資料流"))] | length)"')"
rm -f "$MX/x/docs/architecture.md"; mx_ov x
expect_eq "沒有架構文件 → flows 為 []、每個模組的 flows 為 []" "[] true" "$(mx_q x '"\(.flows | tojson) \(all(.modules[]; .flows == []))"')"
# 唯一的 mermaid 區塊是資料流節的 sequenceDiagram → 不被當成 5.1 容器圖（容器圖相關欄位與拿掉該區塊時相同）
mx_seq() {
    { printf '# 架構\n\n### 5.5 模組\n\n| id | 模組 | 路徑 |\n|---|---|---|\n| orders | 訂單 | `backend/app/orders/**` |\n| pages | 頁面 | `frontend/src/pages/**` |\n\n## 5. 資料流\n\n### orders 結帳 — 正常結帳\n\n'
      [ "$1" = with ] && printf '```mermaid\nsequenceDiagram\n    participant orders as 訂單\n    participant pages as 頁面\n    pages->>orders: 結帳\n```\n'
    } > "$MX/x/docs/architecture.md"
    mx_ov x
    mx_q x '[.groups, [.modules[] | {id, name, group, pos, declared}], .edges, [.notices[] | select(.text | test("容器圖"))]] | tojson'
}
mxs_with=$(mx_seq with); mxs_without=$(mx_seq without)
expect_eq "架構文件唯一的 mermaid 是資料流節的 sequenceDiagram → 容器圖相關欄位與拿掉該區塊時相同、仍有「沒有可解析的容器圖」" "same 1" \
    "$([ -n "$mxs_with" ] && [ "$mxs_with" = "$mxs_without" ] && echo same || echo diff) $(printf '%s' "$mxs_with" | grep -o '沒有可解析的容器圖' | wc -l | tr -d ' ')"
rm -f "$MX/x/docs/architecture.md"

# ---- 模組有 61 個檔、分在 3 個子目錄（make-fixture.sh 的 MAKE_FIXTURE_LARGE，見 fixture 檔頭）
rm -rf "$MX/big"; MAKE_FIXTURE_LARGE=1 bash "$FXD/make-fixture.sh" messy-fullstack "$MX/big" >/dev/null 2>&1; mx_git big; mx_ov big
expect_eq "模組有 61 個檔、分在 3 個子目錄 → inner.nodes 含 3 個以 / 結尾的節點（根目錄的檔照舊）、folded 0" "61 3 catalog.py 0" \
    "$(mx_q big '.modules[] | select(.id == "catalog") | "\(.fileCount) \([.inner.nodes[] | select(endswith("/"))] | length) \([.inner.nodes[] | select(endswith("/") | not)] | join(",")) \(.inner.folded)"')"
expect_eq "子目錄併成節點後，碰到它的模組內邊合併計次（rules/→parsers/ 20 次）" 20 \
    "$(mx_in big catalog '(.nodes | index("rules/")) as $r | (.nodes | index("parsers/")) as $p | [.edges[] | select(.[0] == $r and .[1] == $p) | .[2]] | add')"
expect_eq "MAKE_FIXTURE_LARGE 只多 catalog 一個模組：其餘 id 與 messy-fullstack 相同" \
    "backend-api catalog components core frontend-api m-5d3b69 models other pages services stores" "$(mx_q big '[.modules[].id] | sort | join(" ")')"
OVERVIEW_SCAN_MAX_FILES=10 bash "$OV_SRC" "$MX/big" >/dev/null 2>&1
expect_eq "OVERVIEW_SCAN_MAX_FILES=10 → 所有模組的 inner 為 null、skeleton.json 沒有 fileEdges 項目" "true 0" \
    "$(mx_q big 'all(.modules[]; has("inner") and .inner == null)') $(mx_sk big '(.fileEdges // []) | length')"

# ---- 大小上限：alpha 是本次 plan 預計會動的模組，beta（40 個長檔名）不是、也沒有改動
mx_new sh
mx_put sh src/alpha/a.py 'a = 1\n'; mx_put sh src/alpha/b.py 'from src.alpha.a import a\n'
for i in $(seq 10 49); do mx_put sh "src/beta/long_module_name_for_size_$i.py" "from src.beta.long_module_name_for_size_$((i == 49 ? 10 : i + 1)) import v\nv = $i\n"; done
mx_put sh .claude/taskmaster-data/plans/1.1-x.md '---\nwbs_task: "1.1"\nstatus: "🔄 進行中"\nmode: "standard"\nfiles:\n  - "src/alpha/**"\n---\n\n# 實作計畫：任務 1.1\n\n### 階段 1: 實作 🔄\n'
printf '1.1\n' > "$MX/sh/.claude/taskmaster-data/.current-task"
mx_git sh; mx_ov sh
mxfull=$(sed -n 's/^window\.OVERVIEW = //; s/;$//p' "$MX/sh/.claude/taskmaster-data/overview/data.js" | wc -c | tr -d ' ')
expect_eq "大小上限前提：alpha planned、beta 不是 planned 也沒有改動、兩個 inner 都在" "true false 0 true true" \
    "$(mx_q sh '"\(.modules[] | select(.id == "alpha") | .planned) \(.modules[] | select(.id == "beta") | "\(.planned) \(.changed)") \(.modules[] | select(.id == "alpha") | .inner != null) \(.modules[] | select(.id == "beta") | .inner != null)"')"
# 少 200 位元組：只要丟掉 beta 的 inner（約 3KB）就放得下。mxfull 含 sed 補的換行，貼著邊界（+79）會差 1 而不觸發
OVERVIEW_MAX_BYTES=$((mxfull - 200)) mx_ov sh
expect_eq "OVERVIEW_MAX_BYTES 容不下全部 inner → planned 為 false 且沒有本次改動的 beta 的 inner 為 null，planned 的 alpha 的 inner 仍在" "null true" \
    "$(mx_q sh '"\(.modules[] | select(.id == "beta") | .inner) \(.modules[] | select(.id == "alpha") | .inner != null)"')"
OVERVIEW_MAX_BYTES=1500 mx_ov sh
expect_eq "再調小到既有四級都丟完仍超過 → 全部 inner 為 null、仍有「仍超過上限」的 warn" "true true" \
    "$(mx_q sh 'all(.modules[]; has("inner") and .inner == null)') $(mx_q sh '[.notices[] | select(.level == "warn") | .text] | any(test("仍超過"))')"

# ---- fixture：shop-clean、messy-fullstack 加了資料庫／外部套件／標準庫的 import 與資料流節
rm -rf "$MX/shop"; bash "$FXD/make-fixture.sh" shop-clean "$MX/shop" >/dev/null 2>&1; mx_git shop; mx_ov shop
expect_eq "shop-clean（加了 import 與資料流節）→ 模組、群組、邊仍與 shop-clean.golden 一致" "" \
    "$(mx_q shop '(.modules[] | "module \(.id) \(.group)"), (.groups[] | "group \(.id) \(.label)"), (.edges[] | "edge \(.from) \(.to)")' | diff - <(tr -d '\r' < "$FXD/shop-clean.golden"))"
expect_eq "shop-clean → db 模組的 inner.out 有 db:sqlalchemy、db:pg；svc-a 有 pkg:httpx、沒有 os" "true true true 0" \
    "$(mx_in shop db '"\(any(.out[]; .[1] == "db:sqlalchemy")) \(any(.out[]; .[1] == "db:pg"))"') $(mx_in shop svc-a '"\(any(.out[]; .[1] == "pkg:httpx")) \([.out[] | select(.[1] | test(":os$"))] | length)"')"
expect_eq "shop-clean → 有資料流、每條的參與者都對得到模組、沒有「對不到任何模組」" "true true 0" \
    "$(mx_q shop '([.modules[].id]) as $ids | "\(.flows | length > 0) \(all(.flows[]; all(.participants[]; . as $p | $ids | index($p) != null))) \([.notices[] | select(.text | test("對不到任何模組"))] | length)"')"
MXA="$MX/shop/docs/05_architecture.md"; mxa0=$(mx_after "$MXA"; printf x)
bash "$OV_SRC" --sync-arch "$MX/shop" >/dev/null 2>&1
expect_eq "--sync-arch 前後，架構文件 end 標記之後的資料流節位元組相同" same "$([ "$(mx_after "$MXA"; printf x)" = "$mxa0" ] && echo same || echo diff)"
expect_eq "--sync-arch 的自動段不含檔案層級：模組表列數、mermaid 節點數都等於模組數" "6 6" \
    "$(( $(mx_region "$MXA" | grep -c '^| ') - 1 )) $(mx_region "$MXA" | grep -cE '^    [A-Za-z0-9_-]+\[')"
rm -rf "$MX/messy"; bash "$FXD/make-fixture.sh" messy-fullstack "$MX/messy" >/dev/null 2>&1; mx_git messy; mx_ov messy
expect_eq "messy-fullstack → 參與者全部對不到模組的流程恰好一則 notice；分組 id（pkg-backend）那條對到後端模組" "1 true" \
    "$(mx_q messy '"\([.notices[] | select(.text | test("對不到任何模組"))] | length) \(.flows[0].modules | index("services") != null)"')"
expect_eq "messy-fullstack（加了 import 與資料流節）→ 模組 id 與階段 2 相同" \
    "backend-api components core frontend-api m-5d3b69 models other pages services stores" "$(mx_q messy '[.modules[].id] | sort | join(" ")')"

# ---- gen-large.sh 5000：上限與 fileEdges 總數
rm -rf "$MX/g5k"; mx_new g5k; bash "$FXD/gen-large.sh" 5000 "$MX/g5k" >/dev/null 2>&1; mx_git g5k; mx_ov g5k
expect_eq "gen-large.sh 5000 → 每個模組都有 inner、nodes ≤ 60、edges ≤ 200、out ≤ 15" "40 0" \
    "$(mx_q g5k '"\([.modules[] | select(.inner != null)] | length) \([.modules[] | .inner | select((.nodes | length) > 60 or (.edges | length) > 200 or (.out | length) > 15)] | length)"')"
expect_eq "gen-large.sh 5000 → 逐檔超過 60 的模組留 59 個節點、其餘計入 folded；other 依子目錄併成節點" "true true" \
    "$(mx_q g5k '"\(all(.modules[] | select(.id != "other" and .fileCount > 60); (.inner.nodes | length) == 59 and .inner.folded == .fileCount - 59)) \(.modules[] | select(.id == "other") | all(.inner.nodes[]; endswith("/")))"')"
mxfe=$(mx_sk g5k '.fileEdges | length'); mxsum=$(mx_q g5k '[.modules[].inner | select(. != null) | (.edges | length) + (.out | length)] | add')
[ -n "$mxfe" ] && [ -n "$mxsum" ] && [ "$mxfe" -ge "$mxsum" ] 2>/dev/null && [ "$mxsum" -gt 0 ] 2>/dev/null \
    && ok "gen-large.sh 5000 → skeleton.json 的 fileEdges 數（$mxfe）≥ 各模組 inner.edges＋inner.out 的總和（$mxsum）" \
    || ng "gen-large.sh 5000 → fileEdges 數 ≥ inner.edges＋inner.out 總和" "fileEdges ≥ 總和 > 0" "fileEdges=$mxfe 總和=$mxsum"
rm -rf "$MX"

# =========================================================================
section "update-template — .gitignore 只補缺少的短命狀態行"
# =========================================================================
# 舊專案的 .gitignore 沒有後來新增的狀態檔（.last-verify 等）→ 會被 commit。
# 用假模板跑（真模板整包同步太慢）：只放 update-template.sh、.gitignore、.worktreeinclude 與一個 agent
UT_SRC="$HOOK_DIR/../../scripts/update-template.sh"
UT_GI="$HOOK_DIR/../../.gitignore"
if [ -f "$UT_SRC" ] && [ -f "$UT_GI" ]; then
    for l in .full-suite-warned .last-verify .merge-round-open; do
        grep -qxF ".claude/taskmaster-data/$l" "$UT_GI" && ok "模板 .gitignore 列了 $l" || ng "模板 .gitignore 列了 $l" "有這一行" "沒有"
    done
    UT="$SANDBOX/ut"; rm -rf "$UT"; mkdir -p "$UT/tpl/scripts" "$UT/tpl/.claude/agents" "$UT/dst/.claude" "$UT/dst2/.claude"
    cp "$UT_SRC" "$UT/tpl/scripts/"; echo a > "$UT/tpl/.claude/agents/a.md"; echo x > "$UT/tpl/.worktreeinclude"
    printf '# x\n.env\n.claude/taskmaster-data/.current-task\n.claude/taskmaster-data/.last-verify\n.claude/taskmaster-data/.merge-round-open\n.claude/taskmaster-data/.full-suite-warned\n.claude/worktrees/\n' > "$UT/tpl/.gitignore"
    ut() { bash "$UT/tpl/scripts/update-template.sh" "$@" --no-backup </dev/null 2>&1; }
    # 目標：CRLF、檔尾沒有換行、已經有 .current-task、還有一行自己的規則
    printf 'node_modules/\r\n.claude/taskmaster-data/.current-task\r\nmy-rule' > "$UT/dst/.gitignore"
    cp "$UT/dst/.gitignore" "$UT/gi-before"
    out=$(ut "$UT/dst")
    expect_contains "補上缺的三行並列出來" "已補 3 行" "$out"
    expect_eq "原有內容一個 byte 都沒動（新內容只接在後面）" 0 \
        "$(head -c "$(wc -c < "$UT/gi-before")" "$UT/dst/.gitignore" | cmp -s - "$UT/gi-before"; echo $?)"
    expect_eq "補的是缺的那三行、已有的 .current-task 沒重複" "1 1 1 1" \
        "$(for l in .current-task .last-verify .merge-round-open .full-suite-warned; do tr -d '\r' < "$UT/dst/.gitignore" | grep -cxF ".claude/taskmaster-data/$l"; done | paste -sd' ' -)"
    UT_LINES=$(grep -c '' "$UT/dst/.gitignore"); UT_CR=$(tr -cd '\r' < "$UT/dst/.gitignore" | wc -c | tr -d ' ')
    expect_eq "目標是 CRLF → 補的行也是 CRLF；原本檔尾沒換行的那行被補上換行" "0 my-rule" \
        "$((UT_LINES - UT_CR)) $(tr -d '\r' < "$UT/dst/.gitignore" | sed -n '3p')"
    cp "$UT/dst/.gitignore" "$UT/gi-after1"
    out=$(ut "$UT/dst")
    cmp -s "$UT/gi-after1" "$UT/dst/.gitignore" && expect_contains "再跑一次 → 已齊全、檔案不變" "已齊全" "$out" \
        || ng "再跑一次 → 檔案不變" "cmp 相同" "$(diff "$UT/gi-after1" "$UT/dst/.gitignore" | head -5)"
    ut "$UT/dst2" --dry-run >/dev/null
    [ ! -e "$UT/dst2/.gitignore" ] && ok "--dry-run → 不寫" || ng "--dry-run → 不寫" "沒有 .gitignore" "有"
    ut "$UT/dst2" --claude-only >/dev/null
    [ ! -e "$UT/dst2/.gitignore" ] && ok "--claude-only → 不碰根目錄的 .gitignore" || ng "--claude-only → 不碰 .gitignore" "沒有 .gitignore" "有"
    ut "$UT/dst2" >/dev/null
    expect_eq "目標沒有 .gitignore → 建一份，只含這幾行" 4 "$(grep -c '^\.claude/taskmaster-data/' "$UT/dst2/.gitignore" 2>/dev/null)"
    rm -rf "$UT"
else
    ok "（不是模板 repo，沒有 scripts/update-template.sh，略過）"
fi

# =========================================================================
section "check-counts.sh — 專案圖解常數對範本（notes 表頭、附屬檔路徑、自動段標記、資料流節名）"
# =========================================================================
# 地圖計畫階段 7。overview.sh 靠常數抽 module-notes.md 表頭、架構文件的自動段標記與資料流節，
# 範本改了字而常數沒跟上，地圖會靜默抽不到東西。用假模板跑（真模板整份 check-counts 在 Windows 要 2 分鐘以上）：
# 只放這幾項檢查讀的檔，加上讓其餘檢查在假模板裡也全綠的最少檔案；目錄含中文與空格。
CC_SRC="$HOOK_DIR/../scripts/check-counts.sh"
CC_DS="$HOOK_DIR/../agents/documentation-specialist.md"
if [ -f "$CC_SRC" ] && [ -f "$CC_DS" ] && [ -d "$HOOK_DIR/../skills/project-docs" ]; then
    CC="$SANDBOX/常數 檢查"; CC_BAK="$SANDBOX/cc-bak"
    rm -rf "$CC" "$CC_BAK"
    mkdir -p "$CC/.claude/scripts" "$CC/.claude/agents" "$CC/.claude/templates/overview" "$CC_BAK" \
        "$CC/.claude/skills/node-package-manager" "$CC/.claude/skills/api-design" "$CC/.claude/skills/plan-format"
    cp "$CC_SRC" "$OV_SRC" "$CC/.claude/scripts/"
    cp "$CC_DS" "$CC/.claude/agents/"
    cp -R "$HOOK_DIR/../skills/project-docs" "$CC/.claude/skills/"
    for s in node-package-manager api-design plan-format; do cp "$HOOK_DIR/../skills/$s/SKILL.md" "$CC/.claude/skills/$s/"; done
    printf -- '- project-docs\n- node-package-manager\n- api-design\n- plan-format\n' > "$CC/.claude/skills/INDEX.md"
    cp "$HOOK_DIR/../templates/overview/index.html" "$CC/.claude/templates/overview/"
    cp "$HOOK_DIR/../templates/wbs.template.md" "$CC/.claude/templates/"
    CC_NOTES=.claude/skills/project-docs/module-notes.md
    CC_T05=.claude/skills/project-docs/templates/05_architecture_and_design_document.md
    cc_run() {
        CC_OUT=$(bash "$CC/.claude/scripts/check-counts.sh" 2>&1 </dev/null); CC_RC=$?
        CC_OUT=$(printf '%s' "$CC_OUT" | sed $'s/\033\\[[0-9;]*m//g')
    }
    # cc_case <說明> <檔（相對假模板）> <sed 運算式> <失敗訊息要含的字>：改壞 → exit 1 且訊息含該字；改回 → exit 0 且不含
    cc_case() {
        cp "$CC/$2" "$CC_BAK/f"
        sed -i "$3" "$CC/$2"
        if cmp -s "$CC/$2" "$CC_BAK/f"; then ng "$1（改壞）" "sed 改到檔案" "檔案沒變（sed 沒命中）"; return; fi
        cc_run
        [ "$CC_RC" = 1 ] && printf '%s\n' "$CC_OUT" | grep '✗' | grep -qF -- "$4" \
            && ok "$1 → check-counts 失敗並指出 $4" \
            || ng "$1 → check-counts 失敗並指出 $4" "exit 1、✗ 行含 $4" "exit $CC_RC：$(printf '%s\n' "$CC_OUT" | grep '✗' | head -3 | tr '\n' ' ')"
        cp "$CC_BAK/f" "$CC/$2"
        cc_run
        [ "$CC_RC" = 0 ] && ! printf '%s\n' "$CC_OUT" | grep -qF -- "$4" \
            && ok "$1 → 改回後通過" \
            || ng "$1 → 改回後通過" "exit 0、不提 $4" "exit $CC_RC：$(printf '%s\n' "$CC_OUT" | grep '✗' | head -3 | tr '\n' ' ')"
    }
    cc_run
    expect_eq "假模板的基準：check-counts 全綠" "exit 0" \
        "exit $CC_RC$([ "$CC_RC" = 0 ] || printf '：%s' "$(printf '%s\n' "$CC_OUT" | grep '✗' | head -3 | tr '\n' ' ')")"
    cc_case "module-notes.md 說明表表頭「依據」改成「來源」" "$CC_NOTES" '/^| id | 名稱 /s/| 依據 |/| 來源 |/' OVERVIEW_COLS_NOTES
    cc_case "documentation-specialist.md 的附屬檔路徑 module-notes.md 少一個字" .claude/agents/documentation-specialist.md \
        's#skills/project-docs/module-notes\.md#skills/project-docs/module-note.md#' "module-note.md"
    cc_case "05 範本的 <!-- overview:generated:start --> 改成 <!-- overview:gen:start -->" "$CC_T05" \
        's/<!-- overview:generated:start -->/<!-- overview:gen:start -->/' OVERVIEW_GEN_START
    cc_case "05 範本的 <!-- overview:generated:end --> 改成 <!-- overview:gen:end -->" "$CC_T05" \
        's/<!-- overview:generated:end -->/<!-- overview:gen:end -->/' OVERVIEW_GEN_END
    cc_case "05 範本的「## 5. 資料流」改成「## 5. 跨服務流程」" "$CC_T05" 's/^## 5\. 資料流/## 5. 跨服務流程/' OVERVIEW_FLOW_SECTION
    cc_case "overview.sh 的 OVERVIEW_FLOW_SECTION 改成 \"流程\"" .claude/scripts/overview.sh \
        's/^OVERVIEW_FLOW_SECTION="資料流"/OVERVIEW_FLOW_SECTION="流程"/' OVERVIEW_FLOW_SECTION
    rm -rf "$CC" "$CC_BAK"
    out=$(printf '%s\n' .claude/scripts/check-counts.sh | bash "$HOOK_DIR/tests/run-tests.sh" --changed - --dry-run 2>&1)
    expect_contains "改 check-counts.sh → --changed 挑到本節" "專案圖解常數對範本" "$out"
    expect_not_contains "改 check-counts.sh → 不挑只提到檔名的 copy-template 那節" "初始化狀態只看 project.json" "$out"
else
    ok "（不是模板 repo，沒有 check-counts.sh 或 documentation-specialist.md，略過）"
fi

# =========================================================================
section "全體 hooks — 語法與健壯性"
# =========================================================================
for h in "$HOOK_DIR"/*.sh; do
    n=$(basename "$h")
    bash -n "$h" 2>/dev/null && ok "$n 語法正確" || ng "$n 語法正確" "可解析" "語法錯誤"
done

# lib/ 底下的被 source 進來，語法錯會讓呼叫端整支軟失效（`source ... || true` 吞掉錯誤）
for h in "$HOOK_DIR"/lib/*.sh; do
    n="lib/$(basename "$h")"
    bash -n "$h" 2>/dev/null && ok "$n 語法正確" || ng "$n 語法正確" "可解析" "語法錯誤"
done

# macOS 內建 bash 3.2 沒有大小寫轉換展開（兩個逗號、兩個 ^ 與單字元版），執行到那行就 bad substitution
# 讓整支中止；bash -n 與 Linux／Git Bash 的 bash 4+ 都抓不到。已知的四處早於這條檢查
# （rm-state-gate.sh 同檔另用了 local -A，本來就要 bash 4；run-tests.sh 是選節的關鍵字比對）——只擋新增的
CASEMOD_RE='\$\{[#!]?([A-Za-z_][A-Za-z0-9_]*|[0-9]+|[@*])(\[[^]]*\])?[,^]'
expect_eq ".claude/hooks/**、.claude/scripts/** 的 .sh 沒有新增 bash 4 的大小寫轉換展開" \
    "hooks/lib/rm-state-gate.sh:2 hooks/tests/run-tests.sh:2" \
    "$(cd "$HOOK_DIR/.." && grep -rcE --include='*.sh' "$CASEMOD_RE" hooks scripts | grep -v ':0$' | sort | paste -sd' ' -)"

# 沙箱的初始分支名不能取決於跑測試那台機器的 init.defaultBranch：CI 的 Windows runner 是 master，
# 本機是 main。2026-11-09 setup_worktree 沒釘分支名，分支切換閘門 4 個案例只在 CI Windows 紅了兩週
GITINIT_RE='(^|[^[:alnum:]_./-])git( +-[Cc] +[^ ]+)* +init( |$)'
expect_eq "run-tests.sh 的 git init 都釘了分支名（-c init.defaultBranch=… 或 -b …）——印出沒釘的行號" "" \
    "$(grep -nE "$GITINIT_RE" "$HOOK_DIR/tests/run-tests.sh" | grep -vE '^[0-9]+:[[:space:]]*#' \
        | grep -vE 'init\.defaultBranch=|init( +-q)? +-b ' | cut -d: -f1 | paste -sd' ' -)"

reset
for h in pre-tool-use.sh post-agent-report.sh user-prompt-submit.sh post-write.sh; do
    run "$h" '{}' >/dev/null 2>&1
    [ $? -le 1 ] && ok "$h 收到空 payload 不爆炸" || ng "$h 收到空 payload 不爆炸" "exit ≤ 1" "exit $?"
done

# =========================================================================
finish_tests
