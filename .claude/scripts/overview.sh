#!/bin/bash
# overview.sh — 專案圖解產生器（專案地圖＋任務圖）
#
# 地圖骨架來自程式碼（scripts/overview-scan.sh 掃出的 skeleton.json）；架構文件 5.5 有效時，
# 路徑對得上的檔案改歸 5.5 的模組（id、名稱、分組照 5.5），沒有或格式不合就完全用掃描結果。
# 再讀人寫的 md（架構文件 5.1 容器圖＋5.5 模組表、wbs.md、plans/*.md 與帳本、project.json）與
# git 狀態，產生兩份衍生物。md 才是正本，這兩份隨時可以刪掉重產：
#
#   .claude/taskmaster-data/overview/overview.md  只反映主 checkout；輸入沒變就 byte 相同，
#                                                 所以不含時間戳、不含「本次」標記
#   .claude/taskmaster-data/overview/data.js      給 overview/index.html 讀，含時間戳、本次改動，
#                                                 並疊上各 worktree 的 plan 進度（worktree overlay）
#
# 兩份都不進 git（資料夾裡的 .gitignore 是 `*`）。overview.md 曾經進 git，但背景重產會讓
# 主 checkout 剛 commit 完又冒出未 commit 的變更，撞上 git-workflow 第 1 條與 /pr 的前置檢查。
#
# 背景重產**不寫**任何模型會 Edit 的檔（wbs、plan、架構文件）：背景改那些檔會讓模型下一次
# Edit 因「讀取後被改過」而失敗。唯一的例外是 --actual，它由 /verify 在前景明確呼叫，
# 只改 plan 裡 overview:actual 標記區塊之內的文字。
#
# 主 checkout 用 git common dir 自己算，不信 CLAUDE_PROJECT_DIR：`claude -w` 開的 session 裡
# 它指向 worktree（2026-11-04 實測），用它會把 overview 寫進 worktree。
#
# 用法：
#   bash .claude/scripts/overview.sh [<工作目錄>]                重產，不輸出任何東西
#   bash .claude/scripts/overview.sh --print-path [<工作目錄>]   印 index.html 的 file:// 路徑；
#        架構文件是草稿、或有任務的模組是推斷出來的，再多印一行「提示：…」，給 /task-status 轉告使用者
#   bash .claude/scripts/overview.sh --print-inferred [<工作目錄>]
#        模組由 plan 推斷的任務，一行一筆：任務編號<TAB>模組 id（逗號分隔）<TAB>依據（plan-files／diff）。
#        給 /task-status 預覽「寫回 WBS」用（模型不讀 data.js）。讀現有的 data.js，沒有才先重產
#   bash .claude/scripts/overview.sh --status [<工作目錄>]
#        只印 overview.md 的「## 現況」一節（≤ 30 行），/task-status 直接印它。讀現有的，沒有才先重產
#   bash .claude/scripts/overview.sh --sync-arch [<工作目錄>]
#        重產，再把架構文件兩個自動段標記之間換成模組表＋依賴圖（ADR-007）。只在主 checkout 寫；
#        沒有標記就不碰、印一行提示；標記不成對時整份不寫、exit 1。由 /verify、/task-status 在前景呼叫，
#        背景重產不寫架構文件（hook 不寫模型會 Edit 的檔）
#   bash .claude/scripts/overview.sh --actual <plan> --result PASS|FAIL [--reason "<一句>"]
#        把「計畫 vs 實際」寫進 plan 的標記區塊（再跑一次是取代，不會重複）並重產。FAIL 必須帶 reason
#   bash .claude/scripts/overview.sh --check-notes [<工作目錄>]
#        驗證說明層 module-notes.md（提案 5.3）：有違規時 stdout 一行一筆「第 N 列 <id>：<原因>」（N 是表格第幾列資料）、
#        exit 1；沒有違規或沒有這個檔時 stdout 為空、exit 0。post-write 寫入 notes 時在前景呼叫
#   bash .claude/scripts/overview.sh --notes-todo [<工作目錄>]
#        沒有說明或可能過期的模組，一行一筆：id<TAB>路徑<TAB>代表檔（最多 3 個）<TAB>missing|stale。
#        給 documentation-specialist 決定要讀哪些檔（模型不讀 data.js）
#
# 說明層：.claude/taskmaster-data/module-notes.md（格式與寫作標準的唯一來源是
# .claude/skills/project-docs/module-notes.md）。通過驗證的列填進模組的 description、名稱與分組
# （名稱、分組的優先序：5.5 → notes → 目錄名）；based_on 之後改過的模組標 stale。
# project.json 的 overview.notes 為 "off" 時不讀、--print-path 也不提示。
# --check-notes／--notes-todo 只讀現有的 skeleton.json（沒有才先重產一次），不搶鎖、不重掃：
# 背景重產正持鎖重掃時，它們不必等。代價是剛新增、還沒掃到的檔會被判成不在模組內，重產後再驗一次就對了
#
# 沒有 taskmaster-data/project.json（模板 repo 本身、還沒 /task-init 的專案）一律 exit 0、不建任何檔。
# 沒有 jq：只寫一份帶「需要 jq」提示的 data.js（用 printf），畫面照樣打得開。
# 逃生門：OVERVIEW=off。大小上限：OVERVIEW_MAX_BYTES（data.js 的位元組數，預設 512KB）

# 欄名常數。check-counts.sh 會比對它們與 05 範本 5.5、wbs.template.md、plan-format 的表頭；
# 改那幾份範本的欄名時同步這裡，否則這支會靜默抽不到東西。
OVERVIEW_COLS_MODULE="id 路徑"          # 05 範本 5.5 模組表的必要欄
OVERVIEW_COLS_MODULE_OPT="模組 職責"    # 05 範本 5.5 模組表的選用欄（顯示名稱、職責）
OVERVIEW_COLS_WBS="# 任務 狀態"         # wbs.template.md 任務表的必要欄
OVERVIEW_COL_WBS="模組"                 # wbs.template.md 任務表的模組欄
OVERVIEW_COLS_PART="id 部件 階段 檔案"  # plan-format「一眼看懂」部件表的必要欄（驗收欄選用）
OVERVIEW_COLS_NOTES="id 名稱 分組 說明 依據"  # project-docs/module-notes.md 說明表的必要欄

DRAFT_MARK='<!-- overview: draft -->'
# 架構文件自動段的標記：與 05 範本（project-docs/templates/05_architecture_and_design_document.md）第 4 節同一字串
OVERVIEW_GEN_START='<!-- overview:generated:start -->'
OVERVIEW_GEN_END='<!-- overview:generated:end -->'
LOCK_STALE_SEC=120                 # 要比 --actual 的等待（60 秒）長，否則等鎖的那支會搶走還活著的鎖
MAX_CHANGES=200                    # 每份 plan、地圖各列幾個改動檔，其餘依第一層目錄彙總進 changesRollup
MAX_BYTES=${OVERVIEW_MAX_BYTES:-524288}
[[ $MAX_BYTES =~ ^[0-9]+$ ]] || MAX_BYTES=524288
# 架構文件資料流節的節名（`## <數字>. 資料流`，不綁節號）：與 05 範本同一字串
OVERVIEW_FLOW_SECTION="資料流"
# 模組展開（modules[].inner，ADR-2026-11-06-002 決策 1）：每模組節點、模組內邊、框外項目的上限
OVERVIEW_INNER_MAX_NODES=${OVERVIEW_INNER_MAX_NODES:-60}
OVERVIEW_INNER_MAX_EDGES=${OVERVIEW_INNER_MAX_EDGES:-200}
OVERVIEW_INNER_MAX_OUT=${OVERVIEW_INNER_MAX_OUT:-15}
[[ $OVERVIEW_INNER_MAX_NODES =~ ^[1-9][0-9]*$ ]] || OVERVIEW_INNER_MAX_NODES=60
[[ $OVERVIEW_INNER_MAX_EDGES =~ ^[0-9]+$ ]] || OVERVIEW_INNER_MAX_EDGES=200
[[ $OVERVIEW_INNER_MAX_OUT =~ ^[0-9]+$ ]] || OVERVIEW_INNER_MAX_OUT=15

ACTUAL_PLAN="" ACTUAL_RESULT="" ACTUAL_REASON="" PRINT_PATH=0 PRINT_INFERRED=0 PRINT_STATUS=0 SYNC_ARCH=0 NOTES_MODE=""
case "${1:-}" in
    --print-path) PRINT_PATH=1; shift ;;
    --check-notes) NOTES_MODE=check; shift ;;
    --notes-todo) NOTES_MODE=todo; shift ;;
    --print-inferred) PRINT_INFERRED=1; shift ;;
    --status) PRINT_STATUS=1; shift ;;
    --sync-arch) SYNC_ARCH=1; shift ;;
    --actual)
        ACTUAL_PLAN="${2:-}"
        if [ $# -ge 2 ]; then shift 2; else shift $#; fi
        while [ $# -gt 0 ]; do
            case "$1" in
                --result) ACTUAL_RESULT="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
                --reason) ACTUAL_REASON="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
                *) shift ;;
            esac
        done
        [ -n "$ACTUAL_PLAN" ] || ACTUAL_PLAN="（沒給）" ;;
esac

die_actual() { printf 'overview.sh --actual：%s\n' "$1" >&2; exit 2; }

# overview:actual 標記只能是零組或一組（start、end 各一行，start 在前）。印出壞在哪，正常時不印。
# splice_actual 與 parse_plan 都靠這個假設：只有 start 時 awk 會從 start 跳到檔尾，把後面的內容整段刪掉。
actual_markers_bad() {
    awk '/^<!-- overview:actual:start/ { s++; if (!sl) sl = NR }
         /^<!-- overview:actual:end/   { e++; if (!el) el = NR }
         END {
             if (s == 0 && e == 0) exit
             if (s == 1 && e == 1 && sl < el) exit
             printf "start %d 個（第一個在第 %d 行）、end %d 個（第一個在第 %d 行）", s, sl, e, el
         }' "$1"
}
markers_msg() {
    printf 'plan 的 overview:actual 標記壞了（%s），整份沒有寫入。\n修法：打開 %s，刪掉多餘或落單的 <!-- overview:actual:start/end --> 標記行，只留一組完整的（start 在前）；或全部刪掉，讓下一次 --actual 在檔尾重寫。' "$1" "$2"
}

if [ "${OVERVIEW:-on}" = "off" ]; then
    [ -n "$ACTUAL_PLAN" ] && echo "overview.sh：OVERVIEW=off，沒有寫入「計畫 vs 實際」" >&2
    [ "$SYNC_ARCH" -eq 1 ] && echo "overview.sh：OVERVIEW=off，沒有同步架構文件自動段"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

if [ -n "$ACTUAL_PLAN" ]; then
    [ -f "$ACTUAL_PLAN" ] || die_actual "找不到 plan 檔：$ACTUAL_PLAN"
    case "$ACTUAL_RESULT" in PASS|FAIL) ;; *) die_actual "--result 要是 PASS 或 FAIL" ;; esac
    [ "$ACTUAL_RESULT" = FAIL ] && [ -z "$ACTUAL_REASON" ] && die_actual 'FAIL 必須帶 --reason "<一句失敗原因>"'
    ACTUAL_DIR=$(cd "$(dirname "$ACTUAL_PLAN")" 2>/dev/null && pwd) || die_actual "讀不到 plan 所在目錄"
    ACTUAL_NAME=${ACTUAL_PLAN##*/}
    case "$ACTUAL_DIR" in */.claude/taskmaster-data/plans) ;; *) die_actual "plan 要在 .claude/taskmaster-data/plans/ 底下（已歸檔的不寫）" ;; esac
    ACTUAL_PLAN="$ACTUAL_DIR/$ACTUAL_NAME"
    bad=$(actual_markers_bad "$ACTUAL_PLAN")
    [ -z "$bad" ] || die_actual "$(markers_msg "$bad" "$ACTUAL_PLAN")"
    WORK_ROOT="${ACTUAL_DIR%/.claude/taskmaster-data/plans}"
else
    WORK_ROOT="${1:-$PWD}"
fi

MAIN_ROOT=""
GCD=$(git -C "$WORK_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$GCD" ] && MAIN_ROOT=$(cd "$GCD/.." 2>/dev/null && pwd)
[ -n "$MAIN_ROOT" ] || MAIN_ROOT=$(cd "$WORK_ROOT" 2>/dev/null && pwd)
[ -n "$MAIN_ROOT" ] || exit 0

DATA="$MAIN_ROOT/.claude/taskmaster-data"
OUT="$DATA/overview"
if [ ! -f "$DATA/project.json" ]; then
    [ -n "$ACTUAL_PLAN" ] && echo "overview.sh：沒有 taskmaster-data/project.json，沒有寫入「計畫 vs 實際」" >&2
    exit 0
fi

PJ_TEXT=""
IFS= read -r -d '' PJ_TEXT < "$DATA/project.json"
IS_DEMO=0
[[ $PJ_TEXT =~ \"mode\"[[:space:]]*:[[:space:]]*\"demo\" ]] && IS_DEMO=1
NOTES_OFF=0
[[ $PJ_TEXT =~ \"notes\"[[:space:]]*:[[:space:]]*\"off\" ]] && NOTES_OFF=1

# 架構文件：project.json 的 overview.architectureDoc（選填覆寫）→ docs/architecture.md → docs/*architecture*.md
# → docs/**/*architecture*.md → docs/tech-spec.md。檔名含 frontend 的跳過：/ui-site 產的
# docs/12_frontend_architecture.md 依字母序排在 architecture.md 前面，會被當成系統架構文件。
# docs/** 用 find 不用 globstar（bash 3.2 沒有）。
find_arch() {
    local f b best="" re='"architectureDoc"[[:space:]]*:[[:space:]]*"([^"]*)"'
    if [[ $PJ_TEXT =~ $re ]] && [ -n "${BASH_REMATCH[1]}" ] && [ -f "$MAIN_ROOT/${BASH_REMATCH[1]}" ]; then
        echo "${BASH_REMATCH[1]}"; return
    fi
    [ -f "$MAIN_ROOT/docs/architecture.md" ] && { echo docs/architecture.md; return; }
    for f in "$MAIN_ROOT"/docs/*architecture*.md; do
        b=${f##*/}; [[ $b == *[Ff][Rr][Oo][Nn][Tt][Ee][Nn][Dd]* ]] && continue
        [ -f "$f" ] && { echo "${f#"$MAIN_ROOT"/}"; return; }
    done
    if [ -d "$MAIN_ROOT/docs" ]; then
        while IFS= read -r -d '' f; do
            b=${f##*/}; [[ $b == *[Ff][Rr][Oo][Nn][Tt][Ee][Nn][Dd]* ]] && continue
            f=${f#"$MAIN_ROOT"/}
            if [ -z "$best" ] || [[ $f < $best ]]; then best=$f; fi
        done < <(find "$MAIN_ROOT/docs" -mindepth 2 -type f -name '*architecture*.md' -print0 2>/dev/null)
        [ -n "$best" ] && { echo "$best"; return; }
    fi
    [ -f "$MAIN_ROOT/docs/tech-spec.md" ] && echo "docs/tech-spec.md"
}

TPL="$SCRIPT_DIR/../templates/overview/index.html"
copy_page() {
    [ -f "$TPL" ] || return 0
    if ! cmp -s "$TPL" "$OUT/index.html"; then
        cp -f "$TPL" "$OUT/.index.tmp-$$" && mv -f "$OUT/.index.tmp-$$" "$OUT/index.html"
    else
        # 內容相同也要更新時間：session-start 用 -nt 判斷要不要補產，不 touch 的話
        # 範本只有時間變新（例如切分支再切回）時，每個 session 都會白跑一次
        touch "$OUT/index.html"
    fi
}

if [ "$PRINT_PATH" -eq 1 ]; then
    p="$OUT/index.html"
    command -v cygpath >/dev/null 2>&1 && p=$(cygpath -m "$p")
    printf 'file:///%s\n' "${p#/}"
    # 草稿要讓 /task-status 講出來：模型不讀 data.js，只看得到這裡印的字。沒有架構文件不提：
    # 地圖由程式碼掃出，照樣畫得出來。demo 不提（使用者決定：demo 的升級提示只放畫面與 overview.md）
    if [ "$IS_DEMO" -eq 0 ]; then
        a=$(find_arch)
        if [ -n "$a" ] && grep -qF -- "$DRAFT_MARK" "$MAIN_ROOT/$a" 2>/dev/null; then
            echo "提示：$a 是架構草稿（帶 $DRAFT_MARK），地圖照畫，但不拿它覆寫模組名稱；確認模組切分後移除這行標記"
        fi
        # data.js 是 jq -c 的輸出（沒有空白），tasks[] 每個推斷出的任務恰有一個 "inferred":true；
        # 說明層的數量在頂層 "notes":{"missing":N,"stale":M}（off 時是 null）。一支 awk 兩樣都數
        if [ -f "$OUT/data.js" ]; then
            n=0 nm=0 ns=0
            read -r n nm ns <<< "$(awk '
                match($0, /"notes":\{"missing":[0-9]+,"stale":[0-9]+\}/) {
                    s = substr($0, RSTART + 19, RLENGTH - 20); split(s, a, /,"stale":/); m = a[1]; st = a[2] }
                { n += gsub(/"inferred":true/, "") }
                END { print n + 0, m + 0, st + 0 }' "$OUT/data.js" 2>/dev/null)"
            [ "${n:-0}" -gt 0 ] 2>/dev/null && echo "提示：$n 個任務的模組是由 plan 推斷的，/task-status 可提議寫回 WBS（預覽：overview.sh --print-inferred）"
            if [ "$NOTES_OFF" -eq 0 ] && { [ "${nm:-0}" -gt 0 ] || [ "${ns:-0}" -gt 0 ]; } 2>/dev/null; then
                echo "提示：$nm 個模組沒有說明、$ns 個可能過期（說明層：/task-status 會問要不要請 documentation-specialist 補寫；清單：overview.sh --notes-todo）"
            fi
        fi
    fi
    exit 0
fi

if [ "$PRINT_INFERRED" -eq 1 ]; then
    command -v jq >/dev/null 2>&1 || exit 0
    [ -f "$OUT/data.js" ] || bash "${BASH_SOURCE[0]}" "$WORK_ROOT" >/dev/null 2>&1
    [ -f "$OUT/data.js" ] || exit 0
    # data.js 用位置參數給 jq（Windows 的 jq 開不了含中文的絕對路徑只限 --rawfile／--slurpfile／-f）
    jq -R -r 'select(startswith("window.OVERVIEW = ")) | ltrimstr("window.OVERVIEW = ") | rtrimstr(";") | fromjson
              | (.tasks // [])[] | select(.inferred == true) | [.id, (.modules | join(",")), .inferredBy] | @tsv' \
        "$OUT/data.js" 2>/dev/null
    exit 0
fi

if [ "$PRINT_STATUS" -eq 1 ]; then
    [ -f "$OUT/overview.md" ] || bash "${BASH_SOURCE[0]}" "$WORK_ROOT" >/dev/null 2>&1
    [ -f "$OUT/overview.md" ] && awk '/^## 現況/ { p = 1; print; next } p && /^## / { exit } p' "$OUT/overview.md"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    if [ -n "$NOTES_MODE" ]; then
        echo "overview.sh --$([ "$NOTES_MODE" = check ] && echo check-notes || echo notes-todo)：需要 jq，沒有執行" >&2
        exit 0
    fi
    if [ -n "$ACTUAL_PLAN" ]; then
        echo "overview.sh --actual：需要 jq，沒有寫入「計畫 vs 實際」" >&2
        exit 1
    fi
    if [ "$SYNC_ARCH" -eq 1 ]; then
        echo "overview.sh --sync-arch：需要 jq，沒有同步架構文件自動段" >&2
        exit 1
    fi
    # 只靠 printf 寫一份提示，畫面才不會停在「找不到 data.js」而讓人以為壞了
    mkdir -p "$OUT" 2>/dev/null || exit 0
    [ -f "$OUT/.gitignore" ] || printf '*\n' > "$OUT/.gitignore"
    {
        printf '// 給瀏覽器讀的資料，模型不要讀——要狀態請讀 wbs.md\n'
        printf 'window.OVERVIEW = {"schema":2,"notices":[{"text":"需要 jq：安裝 jq 後跑一次 /task-status，專案圖解就會產生"}]};\n'
    } > "$OUT/.data.tmp-$$" && mv -f "$OUT/.data.tmp-$$" "$OUT/data.js"
    copy_page
    exit 0
fi
mkdir -p "$OUT" 2>/dev/null || exit 0
[ -f "$OUT/.gitignore" ] || printf '*\n' > "$OUT/.gitignore"

# --actual 寫的是哪一份 plan：主 checkout 的叫 main，worktree 的叫 worktree:<資料夾名>（與 overlay 同名）。
# 用 git-dir 是否等於 common dir 判斷，不比路徑字串：Windows 的 8.3 短檔名（KUANWE~1）會讓同一個目錄比不相等。
ACTUAL_SRC="" SYNC_IN_WT=0
if [ -n "$ACTUAL_PLAN" ] || [ "$SYNC_ARCH" -eq 1 ]; then
    ACTUAL_SRC=main
    gd=$(git -C "$WORK_ROOT" rev-parse --path-format=absolute --git-dir 2>/dev/null)
    if [ -n "$gd" ] && [ "$gd" != "$GCD" ]; then
        wr=$(git -C "$WORK_ROOT" rev-parse --show-toplevel 2>/dev/null)
        ACTUAL_SRC="worktree:${wr##*/}"
        SYNC_IN_WT=1
    fi
    [ -n "$ACTUAL_PLAN" ] || ACTUAL_SRC=""
fi

# ---------------------------------------------------------------- 鎖
#
# 每次寫 wbs／plan 都會觸發，連續寫幾次就會有幾支同時跑。拿不到鎖的那支只留下 .dirty
# 就走，由持鎖者做完後再跑一輪——不排隊、不丟更新。--actual 例外：它要寫 plan，不能
# 讓位，所以最多等 60 秒。當掉的前一次會留下鎖，超過 LOCK_STALE_SEC（120）秒視為過期並接手。
LOCK="$OUT/.lock"
lock_age() {
    local at
    at=$(cat "$LOCK/at" 2>/dev/null)
    [ -n "$at" ] || at=$(date -r "$LOCK" +%s 2>/dev/null)
    [ -n "$at" ] || at=$(date +%s)
    echo $(( $(date +%s) - at ))
}
take_lock() {
    mkdir "$LOCK" 2>/dev/null && return 0
    if [ "$(lock_age)" -gt "$LOCK_STALE_SEC" ]; then
        rm -rf "$LOCK" 2>/dev/null
        mkdir "$LOCK" 2>/dev/null && return 0
    fi
    return 1
}
# --check-notes／--notes-todo 只讀不寫共享產物，不搶鎖（理由見檔頭的用法）
if [ -n "$NOTES_MODE" ]; then
    TMP="$OUT/.tmp-$$"
    mkdir -p "$TMP" 2>/dev/null
    trap 'rm -rf "$TMP" 2>/dev/null' EXIT
else
    if ! take_lock; then
        if [ -z "$ACTUAL_PLAN" ] && [ "$SYNC_ARCH" -eq 0 ]; then
            : > "$OUT/.dirty" 2>/dev/null
            exit 0
        fi
        got=0
        for ((i = 0; i < 120; i++)); do
            sleep 0.5
            take_lock && { got=1; break; }
        done
        who=--sync-arch; [ -n "$ACTUAL_PLAN" ] && who=--actual
        [ "$got" -eq 1 ] || { echo "overview.sh $who：等不到 overview/.lock（60 秒），沒有寫入" >&2; exit 1; }
    fi
    date +%s > "$LOCK/at" 2>/dev/null
    TMP="$OUT/.tmp-$$"
    mkdir -p "$TMP" 2>/dev/null
    trap 'rm -rf "$LOCK" "$TMP" 2>/dev/null' EXIT
fi

# ---------------------------------------------------------------- 輸入

# 一個來源（主 checkout 或某個 worktree）的改動，寫進 changes.tsv（以 \001C 標記行分段）。
# 比較基準：
#   主 checkout 站在預設分支上 → HEAD（只看未 commit 的）；站在 topic 分支 → 與預設分支的 merge-base；
#   找不到預設分支 → 仍用 HEAD 畫地圖，但 kind=fallback，plan 不拿它當基準（見 changes_for）
#   worktree → 與主 checkout 當前分支的 merge-base（那是它要合回去的地方）
# 未追蹤的新檔另成一段，added 帶 `+` 前綴。.claude/ 底下不算。
MAIN_BRANCH="" DEF_BRANCH=""
collect_changes() {
    local src="$1" root="$2"
    local g=(git -C "$root" -c core.quotePath=false)
    if ! "${g[@]}" rev-parse -q --verify HEAD >/dev/null 2>&1; then
        printf '%s\tdefault\t\tnone\t\n' "$src" >> "$TMP/bases.tsv"
        return 0
    fi
    local base=HEAD kind=head cur target
    if [ "$src" = main ]; then
        DEF_BRANCH=$("${g[@]}" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
        if [ -z "$DEF_BRANCH" ]; then
            for b in main master; do
                "${g[@]}" show-ref -q --verify "refs/heads/$b" && { DEF_BRANCH=$b; break; }
            done
        fi
        cur=$("${g[@]}" symbolic-ref -q --short HEAD 2>/dev/null)
        MAIN_BRANCH=$cur
        target=$DEF_BRANCH
        [ -n "$DEF_BRANCH" ] || kind=fallback
        [ -n "$cur" ] && [ "$cur" = "${DEF_BRANCH#origin/}" ] && target=""
    else
        target=${MAIN_BRANCH:-$DEF_BRANCH}
        [ -n "$target" ] || kind=fallback
    fi
    if [ -n "$target" ]; then
        base=$("${g[@]}" merge-base HEAD "$target" 2>/dev/null) && [ -n "$base" ] && kind=merge-base \
            || { base=HEAD; kind=fallback; }
    fi
    printf '%s\tdefault\t%s\t%s\t%s\n' "$src" "$("${g[@]}" rev-parse --short "$base" 2>/dev/null)" "$kind" "$DEF_BRANCH" >> "$TMP/bases.tsv"
    {
        printf '\001C\t%s\tdefault\n' "$src"
        "${g[@]}" diff --numstat --no-renames "$base" -- . ':(exclude).claude' 2>/dev/null
        printf '\001C\t%s\tuntracked\n' "$src"
        # 新檔沒有 numstat：用一支 awk 數行數（逐檔開 wc 在 Windows 每個要上百毫秒）；空檔記 0
        "${g[@]}" ls-files -z --others --exclude-standard -- . ':(exclude).claude' 2>/dev/null \
            | head -z -n "$MAX_CHANGES" \
            | ( cd "$root" && xargs -0 -r awk 'BEGIN { for (i = 1; i < ARGC; i++) seen[ARGV[i]] = 1 }
                  { n[FILENAME]++ } END { for (f in seen) printf "+%d\t0\t%s\n", n[f], f }' 2>/dev/null )
    } >> "$TMP/changes.tsv"
}

# 帳本第一個 BASE= 就是這份 plan 動工前的 commit（subagent-execution 的帳本格式）。
# 用 bash 內建的 read 掃，不開行程；結果放在 LB。
ledger_base() {
    local l
    LB=""
    while IFS= read -r l; do
        [[ $l =~ BASE=([0-9a-fA-F]{4,40}) ]] && { LB=${BASH_REMATCH[1]}; return; }
    done < "$1"
}

# 一個來源的 plan、帳本、.current-task、改動。worktree 沒有 plan 也沒有 .current-task 就整個略過
# （實驗用的 worktree 不該出現在圖上）。
#
# worktree 的 plan 只收「分出來之後動過」（相對它的 HEAD 與主 checkout HEAD 的 merge-base，含 commit、
# staged、工作區改動）或「沒進版控」的檔：plans/ 進版控，每個 worktree 一建立就帶著一份建立當下的副本，
# 沒動過的副本不是它在做的事（主 checkout 歸檔之後，舊 worktree 的副本會讓已完成的 plan 重新出現、
# 還被猜成「本次」）。不比 worktree 的 HEAD：implementer 每完成一階段就連同 plan 一起 commit，
# 比 HEAD 的話 plan 一 commit 就從任務圖消失。找不到 merge-base 才退回 HEAD。
# --actual 指定的那一份例外，一定收。
declare -A SEEN_BASE
gather_source() {
    local src="$1" root="$2" pd="$2/.claude/taskmaster-data/plans" f b ct="" L p
    local -a plans=() ledgers=()
    local -A pristine=()
    if [ "$src" != main ]; then
        local rel=.claude/taskmaster-data/plans
        while IFS= read -r -d '' p; do
            [ "${p%/*}" = "$rel" ] && pristine[${p##*/}]=1
        done < <(git -C "$root" -c core.quotePath=false ls-files -z -- "$rel" 2>/dev/null)
        local mhead fork
        mhead=$(git -C "$MAIN_ROOT" rev-parse -q --verify HEAD 2>/dev/null)
        [ -n "$mhead" ] && fork=$(git -C "$root" merge-base HEAD "$mhead" 2>/dev/null)
        while IFS= read -r -d '' p; do
            [ "${p%/*}" = "$rel" ] && unset 'pristine[${p##*/}]'
        done < <(git -C "$root" -c core.quotePath=false diff -z --name-only "${fork:-HEAD}" -- "$rel" 2>/dev/null)
    fi
    for f in "$pd"/*.md; do
        [ -f "$f" ] || continue
        b=${f##*/}
        case "$b" in INDEX.md|*.progress.md) continue ;; esac
        if [ -n "${pristine[$b]:-}" ] && ! { [ "$src" = "$ACTUAL_SRC" ] && [ "$b" = "$ACTUAL_NAME" ]; }; then
            continue
        fi
        plans+=("$b")
        [ -f "$pd/${b%.md}.progress.md" ] && ledgers+=("${b%.md}.progress.md")
    done
    [ -f "$root/.claude/taskmaster-data/.current-task" ] && IFS= read -r ct < "$root/.claude/taskmaster-data/.current-task"
    ct=${ct//[[:space:]]/}
    [ "$src" = main ] || [ ${#plans[@]} -gt 0 ] || [ -n "$ct" ] || return 0
    [ -n "$ct" ] && printf '%s\t%s\n' "$src" "$ct" >> "$TMP/currents.tsv"
    if [ ${#plans[@]} -gt 0 ]; then
        ( cd "$pd" && stat -c "$src"$'\t''%Y'$'\t''%n' -- "${plans[@]}" ) >> "$TMP/mtimes.tsv" 2>/dev/null
        ( cd "$pd" && awk -v s="$src" 'FNR == 1 { print "\001F\t" s "\t" FILENAME } { print }' "${plans[@]}" "${ledgers[@]}" ) >> "$TMP/bundle.txt" 2>/dev/null
    fi
    collect_changes "$src" "$root"
    for L in "${ledgers[@]}"; do
        ledger_base "$pd/$L"
        [ -n "$LB" ] || continue
        printf '%s\t%s\t%s\n' "$src" "${L%.progress.md}.md" "$LB" >> "$TMP/planbase.tsv"
        [ -n "${SEEN_BASE[$src|$LB]:-}" ] && continue
        SEEN_BASE[$src|$LB]=1
        local out
        # BASE 不是有效的 commit → 不寫這段，changes_for 會退回預設基準
        if out=$(git -C "$root" -c core.quotePath=false diff --numstat --no-renames "$LB" -- . ':(exclude).claude' 2>/dev/null); then
            { printf '\001C\t%s\t%s\n' "$src" "$LB"; [ -n "$out" ] && printf '%s\n' "$out"; } >> "$TMP/changes.tsv"
        fi
    done
}

gather() {
    local f wt
    for f in bundle.txt mtimes.tsv changes.tsv bases.tsv currents.tsv planbase.tsv archive.txt; do : > "$TMP/$f"; done
    SEEN_BASE=()
    gather_source main "$MAIN_ROOT"
    while IFS= read -r wt; do
        [ -n "$wt" ] && [ -d "$wt" ] || continue
        gather_source "worktree:${wt##*/}" "$wt"
    done < <(git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null \
             | awk '/^worktree / { n++; if (n > 1) { sub(/^worktree /, ""); print } }')
    # 已歸檔的 plan 只讀 frontmatter（數量會一直長，不整份讀）
    if compgen -G "$DATA/plans/archive/*.md" >/dev/null; then
        ( cd "$DATA/plans/archive" && awk 'FNR == 1 { fm = 0; print "\001A\t" FILENAME }
              /^---[[:space:]]*$/ { fm++; if (fm == 2) nextfile; next } fm == 1 { print }' *.md ) > "$TMP/archive.txt" 2>/dev/null
    fi
}

# 骨架掃描：結果（共享產物）在 OUT/skeleton.json。jq 在 TMP（OUT 的子目錄）裡用相對路徑 ../skeleton.json 讀
# （理由同 generate 的註解），不複製進 TMP：命中快取時省一個 cp 行程。
# 失敗不擋整張圖：地圖退回只有架構文件寫的模組，錯誤留在 .scan-error、data.js 加一則 notice。
SCAN_STATE=skipped SCAN_MS=0
scan() {
    local t0 t1
    printf '{}\n' > "$TMP/skel.json"; SKEL=skel.json
    [ "$IS_DEMO" -eq 0 ] || return 0
    if [ ! -f "$SCRIPT_DIR/overview-scan.sh" ]; then SCAN_STATE=missing; return 0; fi
    t0=${EPOCHREALTIME//[!0-9]/}
    if SCAN_STATE=$(bash "$SCRIPT_DIR/overview-scan.sh" "$MAIN_ROOT" 2> "$TMP/scan.err") && [ -f "$OUT/skeleton.json" ]; then
        SKEL=../skeleton.json
        [ -f "$OUT/.scan-error" ] && rm -f "$OUT/.scan-error"
    else
        SCAN_STATE=failed
        cp -f "$TMP/scan.err" "$OUT/.scan-error" 2>/dev/null
    fi
    t1=${EPOCHREALTIME//[!0-9]/}
    [ -n "$t0" ] && [ -n "$t1" ] && SCAN_MS=$(( (t1 - t0) / 1000 ))
}

# ---------------------------------------------------------------- 產生

# 一頁現況的「一句話」：docs/00_brief.md 的「## 一句話」節第一行有內容的字（範本佔位的 [...] 與註解不算）。
# 用 bash 內建逐行讀，不開行程
ONE_LINER=""
read_brief() {
    local l inb=0
    ONE_LINER=""
    [ -f "$MAIN_ROOT/docs/00_brief.md" ] || return 0
    while IFS= read -r l || [ -n "$l" ]; do
        l=${l%$'\r'}
        if [ "$inb" = 1 ]; then
            [[ $l == '#'* ]] && break
            [[ -z ${l//[[:space:]]/} || $l == '<!--'* || $l =~ ^\[.*\]$ ]] && continue
            ONE_LINER=$l; break
        fi
        [[ $l =~ ^##[[:space:]]+一句話 ]] && inb=1
    done < "$MAIN_ROOT/docs/00_brief.md"
}

# 說明層的輸入：notes 檔複製成 TMP/notes.md（Windows 的 jq 開不了含中文的絕對路徑）；「依據」可能用到的
# 路徑哪些存在（jq 不能 stat）寫進 notesexist.txt；based_on 之後改過的檔寫進 notesdiff.txt。
# 存在與否用 bash 內建逐行切詞＋test -f，不開行程：表格列裡含 / 或 . 的詞都試一次，多試的不影響結果
# （路徑含空白的「依據」不支援）。check 不需要過期判定，省掉兩個 git 行程
NOTES_FILE="" NOTES_ROOT="" NOTES_BASE="" NOTES_BASE_OK=null
notes_prep() {
    local mode="$1" l tok fm=0 n=0 b=""
    local -a toks
    : > "$TMP/notes.md"; : > "$TMP/notesexist.txt"; : > "$TMP/notesdiff.txt"
    NOTES_BASE="" NOTES_BASE_OK=null
    [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ] || return 0
    cp -f "$NOTES_FILE" "$TMP/notes.md" 2>/dev/null || return 0
    while IFS= read -r l || [ -n "$l" ]; do
        l=${l%$'\r'}; n=$((n + 1))
        if [ "$n" -eq 1 ] && [[ $l =~ ^---[[:space:]]*$ ]]; then fm=1; continue; fi
        if [ "$fm" -eq 1 ]; then
            if [[ $l =~ ^---[[:space:]]*$ ]]; then fm=2
            elif [[ $l =~ ^based_on:[[:space:]]*([^[:space:]#]*) ]]; then b=${BASH_REMATCH[1]}; b=${b//\"/}; b=${b//\'/}
            fi
            continue
        fi
        [[ $l == *'|'* ]] || continue
        l=${l//\`/ }; l=${l//|/ }; l=${l//,/ }; l=${l//，/ }; l=${l//、/ }
        read -r -a toks <<< "$l"
        for tok in "${toks[@]}"; do
            tok=${tok#./}
            [[ $tok == */* || $tok == *.* ]] || continue
            # 走出 repo 的詞不 stat（jq 端的 badpath 會判違規）：含 .. 路徑段、以 / 或磁碟代號開頭、含反斜線
            [[ $tok == /* || $tok == ..* || $tok == */..* || $tok == *\\* || $tok =~ ^[A-Za-z]: ]] && continue
            [ -f "$NOTES_ROOT/$tok" ] && printf '%s\n' "$tok"
        done
    done < "$NOTES_FILE" > "$TMP/notesexist.txt"
    NOTES_BASE=$b
    [ "$mode" = check ] && return 0
    # 不像 commit 的值不交給 git（以 - 開頭會被當成選項）；git diff 對不到 commit 時 exit 128
    if [[ $b =~ ^[0-9a-fA-F]{4,40}$ ]] \
       && git -C "$NOTES_ROOT" -c core.quotePath=false diff --name-only "$b" -- > "$TMP/notesdiff.txt" 2>/dev/null; then
        NOTES_BASE_OK=true
        git -C "$NOTES_ROOT" -c core.quotePath=false ls-files --others --exclude-standard >> "$TMP/notesdiff.txt" 2>/dev/null
    else
        NOTES_BASE_OK=false
        : > "$TMP/notesdiff.txt"
    fi
}

# $1：full（重產）／check（--check-notes）／todo（--notes-todo）。後兩者只讀現有骨架、不收 plan 與改動
generate() {
    local mode="${1:-full}" arch_rel now f
    arch_rel=$(find_arch)
    : > "$TMP/arch.md"; [ -n "$arch_rel" ] && cp -f "$MAIN_ROOT/$arch_rel" "$TMP/arch.md"
    : > "$TMP/wbs.md"; : > "$TMP/wbsarch.md"
    cp -f "$DATA/project.json" "$TMP/proj.json" 2> "$TMP/err" || return 1
    if [ "$mode" = full ]; then
        [ -f "$DATA/wbs.md" ] && cp -f "$DATA/wbs.md" "$TMP/wbs.md"
        # wbs-archive.md 只會越長越大，而這裡只要表格（數已歸檔的完成數）：只留標題、表格列、code fence，
        # 其餘每段換成一個空行（保住「表格到這裡結束」的邊界）
        [ -f "$DATA/wbs-archive.md" ] && awk '/^[[:space:]]*(\||#|```)/ { print; b = 0; next } !b { print ""; b = 1 }' \
            "$DATA/wbs-archive.md" > "$TMP/wbsarch.md" 2>/dev/null
        scan
        gather
        read_brief
        NOTES_FILE="" NOTES_ROOT=$MAIN_ROOT
        [ "$NOTES_OFF" -eq 1 ] || NOTES_FILE="$DATA/module-notes.md"
    else
        printf '{}\n' > "$TMP/skel.json"; SKEL=skel.json
        [ -f "$OUT/skeleton.json" ] && SKEL=../skeleton.json
        for f in bundle.txt mtimes.tsv changes.tsv bases.tsv currents.tsv planbase.tsv archive.txt; do : > "$TMP/$f"; done
    fi
    notes_prep "$mode"
    now=$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')

    # 一支 jq 算完全部，輸出兩行：第 1 行是 data.js 的物件（疊上 worktree），第 2 行是只看主 checkout
    # 的那份、給 overview.md 用。兩份圖由同一段程式算出，不可能各說各話。
    # 輸入先複製進 TMP、在 TMP 裡用相對檔名給 jq：Windows 的 jq 1.8.1 遇到含非 ASCII 字元的
    # 絕對路徑，--rawfile／--slurpfile／-f 一律「Could not open」（位置參數的輸入檔不受影響），
    # 主 checkout 在 D:\模板\ 這類路徑時整張圖會靜默不產生。
    ( cd "$TMP" && LC_ALL=C.UTF-8 jq -n -c -r \
        --rawfile arch arch.md --arg archPath "$arch_rel" \
        --rawfile wbs wbs.md --rawfile wbsArch wbsarch.md \
        --slurpfile proj proj.json \
        --rawfile bundle bundle.txt --rawfile mtimes mtimes.tsv --rawfile changes changes.tsv \
        --rawfile bases bases.tsv --rawfile planbase planbase.tsv --rawfile currents currents.tsv \
        --rawfile archive archive.txt \
        --slurpfile skel "$SKEL" --arg scanState "$SCAN_STATE" --argjson scanMs "$SCAN_MS" \
        --arg now "$now" --arg draftMark "$DRAFT_MARK" --arg oneLiner "$ONE_LINER" \
        --arg genStart "$OVERVIEW_GEN_START" --arg genEnd "$OVERVIEW_GEN_END" \
        --arg colsMod "$OVERVIEW_COLS_MODULE" --arg colsModOpt "$OVERVIEW_COLS_MODULE_OPT" \
        --arg colsWbs "$OVERVIEW_COLS_WBS" --arg colWbs "$OVERVIEW_COL_WBS" --arg colsPart "$OVERVIEW_COLS_PART" \
        --arg vSrc "$ACTUAL_SRC" --arg vFile "${ACTUAL_PLAN:+$ACTUAL_NAME}" --arg vResult "$ACTUAL_RESULT" \
        --arg vReason "$ACTUAL_REASON" --arg vAt "$(date '+%m-%d %H:%M')" \
        --argjson maxChanges "$MAX_CHANGES" \
        --rawfile notes notes.md --rawfile notesExist notesexist.txt --rawfile notesDiff notesdiff.txt \
        --arg notesBase "$NOTES_BASE" --argjson notesBaseOk "$NOTES_BASE_OK" \
        --argjson notesOff "$([ "$NOTES_OFF" -eq 1 ] && echo true || echo false)" \
        --arg colsNotes "$OVERVIEW_COLS_NOTES" --arg outMode "$mode" --arg flowSec "$OVERVIEW_FLOW_SECTION" \
        --argjson inMaxN "$OVERVIEW_INNER_MAX_NODES" --argjson inMaxE "$OVERVIEW_INNER_MAX_EDGES" --argjson inMaxO "$OVERVIEW_INNER_MAX_OUT" \
        -f overview.jq > out.json 2> err ) || return 1
    [ "$mode" = full ] || return 0
    local l1="" l2=""
    { IFS= read -r l1; IFS= read -r l2; } < "$TMP/out.json"
    [ -n "$l1" ] && [ -n "$l2" ] || { echo "overview.jq 沒有輸出兩行" >> "$TMP/err"; return 1; }
    printf '%s\n' "$l1" > "$TMP/data.json"
    printf '%s\n' "$l2" > "$TMP/md.json"
    DATA_LINE=$l1
}

# jq 程式與 bash 放在同一檔，存在變數裡、要用時才寫成暫存檔再 jq -f（避免拆成兩個要一起改的檔）

# 產生器與大小上限共用：超過 MAX_CHANGES 的改動依第一層目錄彙總成 {dir, files, added, removed}；
# 可以混入已經彙總過的項目（再彙總一次會合併同目錄）
IFS= read -r -d '' JQ_ROLLUP <<'JQ'
def rollup:
  map(if has("dir") then .
      else {dir: (.file | split("/") | if length > 1 then .[0] + "/" else "." end),
            files: 1, added: (.added // 0), removed: (.removed // 0)} end)
  | group_by(.dir)
  | map({dir: .[0].dir, files: (map(.files) | add), added: (map(.added) | add), removed: (map(.removed) | add)});
JQ

# data.js 超過 OVERVIEW_MAX_BYTES 時一級一級丟（每級都是在上一級的結果上再丟）：
#   0 非本次相關模組（不是本次 plan 預計會動、也沒有本次改動）的 inner（ADR-2026-11-06-002：最先丟）
#   1 模組的路由清單（只留數量）   2 非本次 plan 的改動明細 → 目錄彙總   3 非本次 plan 的部件驗收
#   4 非本次 plan 只留狀態（畫面仍列得出有哪些 plan）   5 落差明細（各類數量寫進那則 notice）
#   6 地圖的本次改動清單 → 目錄彙總   8 全部模組的 inner（最後丟）
#   7 不丟東西，只加一則「仍超過上限」（前面都丟完還放不下時才跑）。執行順序見 shrink_data
# 只動寫進 data.js 的那份：--actual 寫回 plan 用的是沒丟過的資料，overview.md 不受影響。
IFS= read -r -d '' JQ_SHRINK <<'JQ'
def note($what): .notices += [{level: "info", text: "資料超過 \($kb) KB 上限，已省略：\($what)", action: null}];
def dropinner(f; $what): if any(.modules[]; .inner != null and f) then .modules |= map(if f then .inner = null else . end) | note($what) else . end;
.truncated = true
| if $level == 0 then
    dropinner(.planned != true and (.changed // 0) == 0; "非本次相關模組的內部細節（模組展開）")
  elif $level == 8 then
    dropinner(true; "所有模組的內部細節（模組展開）")
  elif $level == 1 then
    .modules |= map(if .routes then .routes.sample = [] else . end)
    | note("模組的路由清單（只留數量）")
  elif $level == 2 then
    .plans |= map(if .current then . else
        .changesRollup = ((.changes + (.changesRollup // [])) | rollup) | .changes = [] end)
    | note("非本次 plan 的改動明細（改成依目錄彙總）")
  elif $level == 3 then
    .plans |= map(if .current then . else .parts |= map(.acceptance = []) end)
    | note("非本次 plan 的部件驗收")
  elif $level == 4 then
    .plans |= map(if .current then . else
        {file, task, title, mode, status, currentPhase, source, base, verify, modules, plannedModules, current, completed, changesFrom, extraCount,
         phases: [], hasParts: false, parts: [], extraMore: 0, changes: [], changesRollup: [], stub: true} end)
    | note("非本次 plan 的內容（只留狀態）")
  elif $level == 5 then
    ([.drift // {} | to_entries[] | select((.value | length) > 0) | "\(.key) \(.value | length)"] | join("、")) as $c
    | .drift |= map_values([])
    | note("落差明細（只留數量：\($c)）")
  elif $level == 6 then
    .changesRollup = ((.changes + (.changesRollup // [])) | rollup) | .changes = []
    | note("地圖上的本次改動清單（改成依目錄彙總）")
  else
    .notices += [{level: "warn", text: "能省略的都省略了，資料仍超過 \($kb) KB 上限，畫面可能變慢", action: "調高 OVERVIEW_MAX_BYTES"}]
  end
JQ

IFS= read -r -d '' JQ_MAIN <<'JQ'
def trim: gsub("^\\s+|\\s+$"; "");
def unq: trim | if test("^\".*\"$") then .[1:-1] else . end;
def unbt: gsub("`"; "") | trim;
def lines: gsub("\r"; "") | split("\n");
def cells: gsub("\\\\\\|"; "\u0001") | sub("^\\s*\\|"; "") | sub("\\|\\s*$"; "")
  | split("|") | map(gsub("\u0001"; "|") | trim);
def is_row: test("^\\s*\\|");
def is_sep: test("^\\s*\\|?(\\s*:?-{3,}:?\\s*\\|)+\\s*(:?-{3,}:?\\s*)?$");
def heading: test("^#{1,6}\\s");
def htext: sub("^#+\\s*"; "") | trim;
def words: split(" ") | map(select(. != ""));
def blank: . == null or . == "" or . == "—" or . == "-" or test("^\\[.*\\]$");
def splitlist: split("[,，、]"; null) | map(unbt) | map(select(blank | not));
def tsv: lines | map(select(. != "") | split("\t"));
def cap($n): if type == "string" and length > $n then .[:$n - 1] + "…" else . end;

# ---- 說明層（module-notes.md）。樣式來自安全稽核（security-infrastructure-auditor-2026-11-06-1649）。
# 一律不分大小寫，比對前先 norm（全形轉半形、U+3000 轉空白、刪零寬字元），否則「Server＝」「pass​word」繞得過。
# IPv4 要四段、每段 1–3 位數，可接句尾句點（「版本 1.2.3」「1.2.3.4.5」不算）。Email 最後一段要字母（lodash@4.17.21 不算）。
# 開頭不用 \b：Oniguruma 把中文也當成字元，「呼叫db01.corp.local」「帳號uid=」前面沒有字界
def norm: explode | map(if . >= 65281 and . <= 65374 then . - 65248 elif . == 12288 then 32
                        elif (. >= 8203 and . <= 8205) or . == 8288 or . == 65279 or . == 173 then empty else . end) | implode;
def SECRETS: [
  {re: "(^|[^0-9.])([0-9]{1,3}\\.){3}[0-9]{1,3}($|[^0-9.]|\\.($|[^0-9]))", why: "IP 位址"},
  {re: "[a-z][a-z0-9+.-]*://", why: "網址或連線網址"},
  {re: "[a-z0-9-]+(\\.[a-z0-9-]+)*\\.(local|internal|intra|intranet|corp)($|[^a-z0-9-])", why: "內網主機名"},
  {re: "server\\s*=", why: "連線字串（Server=）"},
  {re: "data\\s+source\\s*=", why: "連線字串（Data Source=）"},
  {re: "(^|[^a-z0-9_])(user\\s*id|uid|initial\\s+catalog|host|username)\\s*=", why: "連線字串欄位"},
  {re: "passw(or)?d", why: "password 字樣；功能請用中文「密碼」描述"},
  {re: "pwd\\s*=", why: "pwd= 字樣"},
  {re: "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}", why: "Email"},
  {re: "AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|xox[abprs]-|-----BEGIN|eyJ[A-Za-z0-9_-]{8,}\\.", why: "存取權杖或金鑰"}];
def secret_hits: norm as $t | SECRETS[] | select(. as $s | $t | test($s.re; "i")) | .why;
# 「依據」不准走出 repo：含 .. 路徑段、以 / 或磁碟代號開頭的一律違規（bash 端也不去 stat）
def badpath: test("(^|[/\\\\])\\.\\.([/\\\\]|$)") or test("^[/\\\\]") or test("^[A-Za-z]:");
# 「依據」格：有反引號就只取反引號裡的，沒有就照逗號、頓號切
def evlist: if test("`") then [match("`([^`]+)`"; "g") | .captures[0].string | trim | sub("^\\./"; "")] | map(select(. != ""))
            else split("[,，、]"; null) | map(trim | sub("^\\./"; "")) | map(select(. != "" and . != "—" and . != "-")) end;
# 來自 md 的名稱：<br> 換空白、解碼實體、去標籤（mermaid 標籤常寫 `訂單<br/>處理&amp;出貨`）。&amp; 最後解，
# `&amp;lt;` 才會留成字面的 `&lt;`
def clean: gsub("\\\\n"; " ") | gsub("<br\\s*/?>"; " "; "i")
  | gsub("&lt;"; "<") | gsub("&gt;"; ">") | gsub("&quot;"; "\"") | gsub("&#39;"; "'") | gsub("&amp;"; "&")
  | gsub("<br\\s*/?>"; " "; "i") | gsub("<[^>]*>"; "") | gsub("\\s+"; " ") | trim;

# Markdown 表格：[{h: 所在標題, header: [...], rows: [[...]]}]；程式碼區塊裡的不算
def tables:
  reduce lines[] as $l ({out: [], prev: null, cur: null, h: "", fence: false};
    if ($l | test("^\\s*```")) then .fence = (.fence | not) | .cur = null | .prev = null
    elif .fence then .
    elif ($l | heading) then .h = ($l | htext) | .cur = null | .prev = null
    elif ($l | is_row | not) then .cur = null | .prev = null
    elif .cur != null then .out[.cur].rows += [$l | cells]
    elif ($l | is_sep) and .prev != null then
      .out += [{h: .h, header: (.prev | cells), rows: []}] | .cur = (.out | length - 1)
    else .prev = $l end)
  | .out;
def rowobj($header): . as $r | reduce range(0; $header | length) as $i ({}; .[$header[$i]] = ($r[$i] // ""));

# 合併檔（bash 用 \001<tag>\t<欄>… 分段）拆成 [{head: [...], text}]
def chunks($tag):
  ("\u0001" + $tag + "\t") as $m
  | reduce lines[] as $l ([];
      if ($l | startswith($m)) then . + [{head: ($l | ltrimstr($m) | split("\t")), lines: []}]
      elif length > 0 then .[-1].lines += [$l]
      else . end)
  | map({head, text: (.lines | join("\n"))});

# ---- mermaid（只支援子集：subgraph、id[...]／id[(...)]／id((...))、a --> b、a -->|x| b、a -.-> b、a & b --> c）
def mermaid_blocks:
  reduce lines[] as $l ({out: [], cur: null, h: ""};
    if .cur == null then
      if ($l | test("^\\s*```\\s*mermaid")) then .out += [{h: .h, lines: []}] | .cur = (.out | length - 1)
      elif ($l | heading) then .h = ($l | htext)
      else . end
    elif ($l | test("^\\s*```")) then .cur = null
    else .out[.cur].lines += [$l] end)
  | .out;
# `a -- 文字 --> b` 的文字也吃掉（不吃的話會被當成 a 的顯示名稱）
def ARROW: "\\s*(--\\s+[^|>]*?\\s+-{2,}>|-\\.+->|-\\.+-|-{2,}>|-{3,}|={2,}>|={3,})\\s*(\\|(?<lab>[^|]*)\\|)?\\s*";
def node_ref:
  capture("^(?<id>[A-Za-z0-9_-]+)\\s*(?<rest>.*)$")
  | (.rest | sub(":::.*$"; "") | trim) as $r
  | {id,
     label: (if ($r | test("^[\\[\\(\\{>]") | not) then null
             else ($r | sub("^[\\[\\(\\{>/\\\\]+"; "") | sub("[\\]\\)\\}/\\\\]+$"; "") | unq | clean) end),
     shape: (if ($r | startswith("[(")) then "db" else "box" end)};
def addnode($n; $g):
  if any(.nodes[]; .id == $n.id) then
    .nodes |= map(if .id == $n.id then .label //= $n.label | .group //= $g else . end)
  else .nodes += [$n + {group: $g}] end;
def parse_block:
  reduce (.lines[] | sub("%%.*$"; "") | trim | select(. != "")) as $l
    ({kind: null, stack: [], groups: [], nodes: [], edges: []};
     .stack[-1] as $g
     | if .kind == null then .kind = (if ($l | test("^(graph|flowchart)\\b")) then "flow" else "other" end)
       elif .kind != "flow" then .
       elif ($l | test("^subgraph\\b")) then
         ($l | sub("^subgraph\\s*"; "") | trim) as $s
         | (($s | capture("^(?<id>[A-Za-z0-9_-]+)\\s*\\[(?<lab>.*)\\]$")) // {id: $s, lab: $s}) as $sg
         | .groups += [{id: $sg.id, label: ($sg.lab | unq | clean)}] | .stack += [$sg.id]
       elif $l == "end" then .stack |= .[:-1]
       elif ($l | test("^(classDef|class|style|linkStyle|click|direction)\\b")) then .
       elif ($l | test(ARROW)) then
         [$l | splits(ARROW)] as $segs
         | [$l | match(ARROW; "g") | .captures[1].string // ""] as $labs
         | [$segs[] | [splits("\\s*&\\s*") | node_ref]] as $refs
         | reduce ($refs[][]) as $n (.; addnode($n; $g))
         | reduce range(0; ($refs | length) - 1) as $i (.;
             reduce $refs[$i][] as $a (.; reduce $refs[$i + 1][] as $b (.;
               .edges += [{from: $a.id, to: $b.id, label: (($labs[$i] // "") | trim)}])))
       else (([$l | node_ref] | first) // null) as $n | if $n then addnode($n; $g) else . end
       end);

# ---- glob → regex：`**/` 可為零層、`**` 跨目錄、`*` 不跨 `/`；結尾 `/` 視同 `/**`；沒有萬用字元視同目錄前綴
def glob2re:
  sub("^\\./"; "") | sub("^/"; "") | (if endswith("/") then . + "**" else . end) as $g
  | ($g | gsub("(?<c>[.+^$(){}\\[\\]|\\\\])"; "\\\(.c)")
        | gsub("\\*\\*/"; "\u0002") | gsub("\\*\\*"; "\u0001")
        | gsub("\\*"; "[^/]*") | gsub("\\?"; "[^/]")
        | gsub("\u0002"; "(.*/)?") | gsub("\u0001"; ".*")) as $r
  | if ($g | test("[*?]")) then "^" + $r + "$" else "^" + $r + "(/.*)?$" end;

def tstate: if test("✅") then "done" elif test("🔄") then "wip" elif test("🚫") then "blocked"
            elif test("⏭") then "skip" else "todo" end;
def temoji: {done: "✅", wip: "🔄", blocked: "🚫", skip: "⏭️", todo: "⏳"}[.];
# plan 階段標題的狀態（plan-format：⏳ 未開始／🔄 進行中／✅ 完成）
def pstate: if test("✅") then "done" elif test("🔄") then "wip" else "planned" end;
def strip_state: sub("\\s*(✅|🔄|⏳|🚫|❌|⏭️?)\\s*$"; "");

# 燈號規則唯一來源：.claude/templates/wbs.template.md 第 3 節「里程碑狀態」
def modstatus:
  . as $s
  | if ($s | length) == 0 then "todo"
    elif all($s[]; . == "done" or . == "skip") and any($s[]; . == "done") then "done"
    elif any($s[]; . == "wip") or any($s[]; . == "done") then "wip"
    elif any($s[]; . == "blocked") then "issue"
    else "todo" end;

# ---- plan 檔：frontmatter、標題、階段、「一眼看懂」部件表、overview:actual 區塊裡的驗證結果。
# 解析時先把 actual 區塊拿掉，免得它自己寫出來的表格被當成輸入。
def parse_plan($needPart):
  lines as $L
  | (if (($L[0] // "") | trim) == "---" then ([range(1; $L | length) | select(($L[.] | trim) == "---")] | first) else null end) as $e
  | (if $e != null then $L[1:$e] else [] end) as $F
  | (if $e != null then $L[$e + 1:] else $L end) as $B
  | (reduce $F[] as $l ({fm: {}, files: [], inF: false};
       if ($l | test("^[A-Za-z_]+:")) then
         ($l | capture("^(?<k>[A-Za-z_]+):\\s*(?<v>.*)$")) as $c
         | .inF = ($c.k == "files")
         | .fm[$c.k] = ($c.v | sub("\\s+#.*$"; "") | unq)
         | if $c.k == "files" and (.fm.files | startswith("[")) then .files += ((.fm.files | fromjson?) // []) else . end
       elif .inF and ($l | test("^\\s+-")) then .files += [$l | sub("^\\s+-\\s*"; "") | sub("\\s+#.*$"; "") | unq]
       else . end)) as $H
  # 與 actual_markers_bad 同一條假設：start、end 各一行且 start 在前才算有區塊；不成對就當作沒有
  | ([range(0; $B | length) | select($B[.] | test("^<!-- overview:actual:start"))]) as $starts
  | ([range(0; $B | length) | select($B[.] | test("^<!-- overview:actual:end"))]) as $ends
  | (if ($starts | length) == 1 and ($ends | length) == 1 and $starts[0] < $ends[0]
     then {body: ($B[:$starts[0]] + $B[$ends[0] + 1:]), blk: $B[$starts[0] + 1:$ends[0]]}
     else {body: ($B | map(select(test("^<!-- overview:actual:(start|end)") | not))), blk: []} end) as $S
  | ([$S.blk[] | capture("^驗證：\\s*(✅|❌)?\\s*(?<r>PASS|FAIL)\\s*(（(?<at>[^）]*)）)?\\s*(—\\s*(?<reason>.*))?$")] | first) as $v
  | {fm: $H.fm, files: $H.files,
     title: ([$S.body[] | select(test("^#\\s")) | sub("^#\\s+"; "") | sub("^實作計畫[:：]\\s*"; "")] | first),
     phases: ([$S.body[] | select(test("^###\\s*階段\\s*\\d"))
               | capture("^###\\s*階段\\s*(?<n>\\d+)[^:：\\s]*\\s*[:：]?\\s*(?<rest>.*)$")
               | {n: (.n | tonumber), name: (.rest | strip_state | trim), state: (.rest | pstate)}] | unique_by(.n)),
     partsTable: ([$S.body | join("\n") | tables[] | select(.header as $h | all($needPart[]; . as $c | $h | index($c)))] | first),
     verify: (if $v then {result: $v.r, at: $v.at, reason: (($v.reason // "") | trim | if . == "" then null else . end)} else null end)};

# ---- 帳本：每個階段最後一筆「階段完成」行的 摘要=／測試=，以及「部件 pN 完成」行（格式見 subagent-execution）
def parse_ledger:
  reduce lines[] as $l ({ph: null, phase: {}, part: {}};
    if ($l | test("^##\\s*階段\\s*\\d")) then .ph = ($l | capture("階段\\s*(?<n>\\d+)").n)
    else
      {s: ([$l | capture("摘要=(?<s>[^｜|]*)") | .s | trim] | first),
       t: ([$l | capture("測試=(?<t>[^｜|\\s]*)") | .t] | first)} as $x
      | if $x.s == null and $x.t == null then .
        elif ($l | test("部件\\s*[A-Za-z0-9_-]+\\s*完成")) then .part[$l | capture("部件\\s*(?<p>[A-Za-z0-9_-]+)\\s*完成").p] = $x
        elif ($l | test("階段完成")) and .ph != null then .phase[.ph] = $x
        else . end
    end);

($proj[0] // {}) as $p
| ($skel[0] // {}) as $sk
| ($colsMod | words) as $needMod
| ($colsPart | words) as $needPart
| ($colWbs) as $wcol
| ($p.mode // "none") as $mode
| ($mode == "demo") as $demo
| ($archPath != "") as $hasArch
| ($hasArch and ($arch | contains($draftMark))) as $draft
| ($demo or ($hasArch | not) or $draft) as $nodoc
# 自動段（--sync-arch 寫的模組表與依賴圖）是這支自己的輸出，不能再當 5.5／5.1 讀回來。
# 標記不成對時不剝（--sync-arch 也拒寫），照整份讀
| ($arch | lines as $L
   | ([range(0; $L | length) | select($L[.] | startswith($genStart))]) as $a
   | ([range(0; $L | length) | select($L[.] | startswith($genEnd))]) as $b
   | if ($a | length) == 1 and ($b | length) == 1 and $a[0] < $b[0] then $L[:$a[0]] + $L[$b[0] + 1:] | join("\n") else . end) as $archBody

# ---- 5.5 模組表：第一張表頭同時有 id 與 路徑 的表
| (if $nodoc then null else
    [$archBody | tables[] | select(.header as $h | all($needMod[]; . as $c | $h | index($c)))] | first
   end) as $mt
| ([$mt // empty | .header as $h | .rows[] | rowobj($h)
    | {id: (.id | unbt), name: ((.["模組"] // "") | unbt | clean),
       paths: ((.["路徑"] // "") | splitlist),
       responsibility: ((.["職責"] // "") | trim)}
    | select(.id | blank | not)]) as $rows
| (($rows | length) > 0) as $docValid

# ---- 5.1 容器圖：節點 id 與模組表重疊最多的 graph／flowchart 區塊；同分取前面的
| (if ($docValid | not) then null else
    [$archBody | mermaid_blocks | to_entries[] | (.value | parse_block) as $b
     | select($b.kind == "flow" and ($b.nodes | length) > 0)
     | {i: .key, b: $b, score: ([$b.nodes[].id as $n | $rows[] | select(.id == $n)] | length)}]
    | sort_by(-.score, .i) | first | .b
   end) as $dg

| ([$rows[].id]) as $tblIds
| ([($dg // {}).nodes // [] | .[].id]) as $dgIds
| ([(($dg // {}).nodes // [])[] as $n
     | ([$rows[] | select(.id == $n.id)] | first) as $r
     | {id: $n.id, name: (($r.name // "") | if . == "" then ($n.label // $n.id) else . end),
        group: ($n.group // "_ungrouped"), shape: $n.shape,
        paths: ($r.paths // []), responsibility: ($r.responsibility // ""), declared: ($r != null)}]
   + [$rows[] | select(.id as $i | $dgIds | index($i) | not)
      | {id, name: (if .name == "" then .id else .name end), group: "_ungrouped", shape: "box",
         paths, responsibility, declared: true}]
   | map(. + {nameSource: "doc"})) as $docMods

# ---- 與骨架合併（提案 3.2）：5.5 有效時，路徑對得上的檔改歸 5.5 的模組，其餘留在掃描模組。
# 以檔為單位合併，不以掃描模組為單位：5.5 常把一個目錄拆成兩個模組（src/services/a、b）
| ([$docMods[].id]) as $docIds
| ([$docMods[] | {id, res: [.paths[] | glob2re]}]) as $dres
| def docmod: . as $f | [$dres[] | select(any(.res[]; . as $r | $f | test($r))) | .id] | first // null;
  ([($sk.modules // [])[] | .id as $i | {key: $i, value: (if ($docIds | index($i)) != null then $i + "-scan" else $i end)}]
   | from_entries) as $ren
| (($sk.files // {}) | with_entries(.value = ((if $docValid then (.key | docmod) else null end) // $ren[.value] // .value))) as $FM
| ($FM | to_entries | group_by(.value) | map({key: .[0].value, value: length}) | from_entries) as $FC
| ([($sk.modules // [])[] | $ren[.id] as $id | select($FC[$id] != null)
    | {id: $id, name, group, shape: "box", paths, responsibility: "", declared: true, nameSource: "dir", source: "scan"}]) as $scanMods
| ([$docMods[] | . + {source: (if ($FC[.id] // 0) > 0 then "both" else "doc" end)}] + $scanMods) as $mods0
| (reduce ($sk.routes // [])[] as $r ({}; $FM[$r[0]] as $m | if $m == null then . else .[$m] += [$r[1]] end)) as $RT
| ([$mods0[].id]) as $modIds
| ([$mods0[] | {id, res: [.paths[] | glob2re]}]) as $res
| def modof: . as $f | $FM[$f] // ([$res[] | select(any(.res[]; . as $r | $f | test($r))) | .id] | first // null);
  # plan files: 的 glob 對模組：萬用字元換成一般字元再比對（寬鬆側誤差，只用來找「碰到哪些模組」）
  def globmod: gsub("\\*\\*"; "x") | gsub("[*?]"; "x") | modof;

# ---- 說明層（提案第 5 節）：module-notes.md 的第一張表。表頭缺欄 → 整份當作沒有；某列違規 → 那一列當作沒有。
# 列號 n 是表格的第幾列資料（--check-notes 印的「第 N 列」）。「依據」存不存在由 bash 先 test -f（$notesExist）
  ($colsNotes | words) as $needNotes
| ($notesExist | lines | map(select(. != "") | {key: ., value: true}) | from_entries) as $EX
# span：第一張表在檔案裡的行範圍 [起, 迄)，同 tables 的判法（表頭列的下一行是分隔列、code fence 裡的不算）
| (if $notes == "" then null
   else $notes | lines as $L
     | (if (($L[0] // "") | trim) == "---" then ([range(1; $L | length) | select(($L[.] | trim) == "---")] | first) else null end) as $e
     | (if $e != null then $e + 1 else 0 end) as $from
     | (reduce range($from; $L | length) as $i ({fence: false, s: null, e: null};
          if .e != null then .
          elif ($L[$i] | test("^\\s*```")) then (if .s != null then .e = $i else .fence = (.fence | not) end)
          elif .fence then .
          elif .s != null then (if ($L[$i] | is_row) then . else .e = $i end)
          elif ($L[$i] | is_row) and (($L[$i + 1] // "") | is_sep) then .s = $i
          else . end)) as $sp
     | {lines: $L, span: (if $sp.s == null then null else [$sp.s, ($sp.e // ($L | length))] end),
        table: ($L[$from:] | join("\n") | tables | first)}
   end) as $nt
| (if $nt == null then {header: null, rows: []}
   elif $nt.table == null then {header: "找不到說明表（表頭要有 \($needNotes | join("、"))）", rows: []}
   else ([$needNotes[] | select(. as $c | $nt.table.header | index($c) | not)]) as $miss
     | if ($miss | length) > 0 then {header: "缺\($miss | map("「\(.)」") | join(""))欄（表頭要有 \($needNotes | join("、"))）", rows: []}
       else {header: null,
             rows: [$nt.table.header as $h | $nt.table.rows | to_entries[] | (.key + 1) as $n | .value | rowobj($h)
                    | {n: $n, id: (.id | unbt),
                       name: ((.["名稱"] // "") | unbt | if blank then "" else . end),
                       group: ((.["分組"] // "") | unbt | if blank then "" else . end),
                       text: ((.["說明"] // "") | trim | if blank then "" else . end),
                       evidence: ((.["依據"] // "") | evlist)}]} end
   end) as $NR
| ([$NR.rows[] | . as $r
    | ($r.id != "" and ($modIds | index($r.id)) != null) as $known
    | {n, id, why: [
        (if $r.id == "" then "id 是空的" elif ($known | not) then "id 不存在於專案地圖（可用的 id 見 overview.sh --notes-todo 或地圖）" else empty end),
        (($r.name | length) as $l | if $l > 12 then "名稱 \($l) 字，上限 12" else empty end),
        (($r.text | length) as $l | if $l == 0 then "說明是空的" elif $l > 60 then "說明 \($l) 字，上限 60" else empty end),
        (if ($r.evidence | length) == 0 then "依據沒有寫檔案（至少一個，包在反引號裡）" else empty end),
        ($r.evidence[] | . as $f
         | if ($f | badpath) then "依據 \($f) 路徑不能含 .. 或絕對路徑"
           elif $EX[$f] != true then "依據 \($f) 不存在"
           elif $known and (($f | modof) != $r.id) then "依據 \($f) 不在模組 \($r.id) 的路徑內"
           else empty end),
        ([$r.name, $r.group, $r.text] | join("\n") | secret_hits
         | "含機密樣式（\(.)）：名稱、分組、說明不准寫主機、帳密、Email")]}]) as $NV
# 表格以外的行（frontmatter、註記、第二張表）也不准寫機密；表頭不對時整份都算表外。行號 l 從 1 起
| (if $nt == null then []
   else ($nt.span // [0, 0]) as $s | (if $NR.header != null then [0, 0] else $s end) as $s
     | [range(0; $nt.lines | length) | select(. < $s[0] or . >= $s[1]) as $i
        | ($nt.lines[$i] | [secret_hits] | unique) as $w | select(($w | length) > 0)
        | {l: ($i + 1), why: [$w[] | "含機密樣式（\(.)）：表格外也不准寫主機、帳密、Email"]}]
   end) as $OUTV
| ([$NV[] | select((.why | length) == 0) | .n]) as $okN
| ([$NR.rows[] | select(.n as $n | any($okN[]; . == $n))]) as $okRows
| (reduce $okRows[] as $r ({}; if .[$r.id] != null then . else .[$r.id] = $r end)) as $NOTE
# based_on 之後改過的檔（含工作區、未追蹤）落在哪些模組；based_on 不是有效 commit 時全部算過期
| ([$notesDiff | lines[] | select(. != "") | modof | select(. != null)] | unique) as $chgMods
# 分組：notes 寫的字與既有分組的 label 或 id 相同就併進去，否則開一個新分組（id 依出現順序 notes-1、notes-2…）
| ([(($dg // {}).groups // [])[], (($sk.groups // [])[])]) as $G0
| (reduce ($okRows[] | .group | select(. != "")) as $g ({map: {}, new: []};
     if .map[$g] != null then .
     else ([$G0[] | select(.label == $g or .id == $g) | .id] | first) as $hit
       | if $hit != null then .map[$g] = $hit
         else "notes-\(.new | length + 1)" as $nid | .map[$g] = $nid | .new += [{id: $nid, label: $g}] end
     end)) as $NG
| ([$mods0[] | . as $m | $NOTE[.id] as $nr
    | if $nr == null then . + {description: null}
      else . + {description: {text: $nr.text, evidence: $nr.evidence,
                              stale: ($notesBaseOk == false or ($chgMods | index($m.id)) != null)}}
        # 名稱、分組的優先序：5.5 → notes → 目錄名
        + (if .nameSource == "doc" then {}
           else (if $nr.name != "" then {name: $nr.name, nameSource: "notes"} else {} end)
                + (if $nr.group != "" then {group: $NG.map[$nr.group]} else {} end) end)
      end]) as $mods0
# 可以寫說明的模組：有程式檔、不是「其他」。--print-path 的提示與 --notes-todo 都只算這些
| ([$mods0[] | select(.id != "other" and ($FC[.id] // 0) > 0)]) as $notable

# ---- 資料流節（ADR-2026-11-06-002 決策 3）：`## <數字>. <節名>` 一節裡每個 ### 是一條流程，只取其後
# mermaid 區塊的 participant／actor 宣告行。行號照原檔（含自動段）。id＝模組 id → 該模組；＝分組 id → 該分組全部模組
| def uniq: reduce .[] as $x ([]; if index($x) != null then . else . + [$x] end);
  (if ($hasArch | not) or $demo then []
   else [$arch | lines | to_entries | reduce .[] as $e ({sec: 0, fence: false, mer: false, out: []};
      $e.value as $l
      | if .fence then
          (if ($l | test("^\\s*```")) then .fence = false | .mer = false
           elif .mer and .sec == 1 and (.out | length) > 0 then
             (($l | capture("^\\s*(participant|actor)\\s+(?<id>[^\\s]+)")) // null) as $c
             | if $c != null then .out[-1].participants += [$c.id] else . end
           else . end)
        elif ($l | test("^\\s*```")) then .fence = true | .mer = ($l | test("^\\s*```\\s*mermaid"))
        elif ($l | test("^#{1,2}\\s")) then .sec = (if ($l | test("^##\\s+[0-9]+\\.\\s*" + $flowSec)) then 1 elif .sec == 1 then 2 else .sec end)
        elif .sec == 1 and ($l | test("^###\\s")) then .out += [{title: ($l | htext), line: ($e.key + 1), participants: []}]
        else . end)
      | .out[]]
   end) as $flows0
| ($mods0 | group_by(.group) | map({key: .[0].group, value: map(.id)}) | from_entries) as $GMODS
| ([$flows0[] | (.participants | uniq) as $ps
    | {title, line, participants: $ps,
       modules: ([$ps[] | . as $p | if ($modIds | index($p)) != null then $p else ($GMODS[$p] // [])[] end] | uniq)}]) as $flows
| (reduce range(0; $flows | length) as $i ({}; reduce $flows[$i].modules[] as $m (.; .[$m] += [$i]))) as $MFLOWS

# ---- WBS 任務：表頭有 # 任務 狀態 的表，依表頭找欄（舊節少欄也照讀）
| ($colsWbs | words) as $needWbs
| ([$wbs | tables[] | select(.header as $h | all($needWbs[]; . as $c | $h | index($c)))]) as $wt
| ([$wt[] | .h as $ms | (.header | index($wcol) != null) as $hasCol | .header as $h | .rows[] | rowobj($h)
    | select(.["#"] | unbt | blank | not)
    | (.["狀態"] | tstate) as $st
    | {id: (.["#"] | unbt), title: (.["任務"] | trim), status: ($st | temoji), state: $st, statusText: (.["狀態"] // ""),
       milestone: $ms, hasCol: $hasCol,
       modules: (if $hasCol then (.[$wcol] | splitlist) else [] end)}]) as $tasks0
| ([$tasks0[] | .id as $t | .modules[] | select(. as $m | $modIds | index($m) | not) | "\($t)（\(.)）"]) as $unknownMods
| ($tasks0 | map(select(.hasCol | not)) | length) as $noColCount

# ---- 改動與比較基準（bash 收集，見 collect_changes／gather_source）
| ($changes | chunks("C") | map({key: (.head[0] + "|" + .head[1]),
    value: [.text | lines[] | select(. != "") | split("\t") | select(length >= 3)
            | {file: (.[2:] | join("\t")),
               added: (.[0] | ltrimstr("+") | tonumber? // null),
               removed: (.[1] | tonumber? // null),
               new: (.[0] | startswith("+"))}]}) | from_entries) as $CH
| ($bases | tsv | map({key: (.[0] + "|" + .[1]), value: {short: (.[2] // ""), kind: (.[3] // "none"), def: (.[4] // "")}}) | from_entries) as $BS
| ($planbase | tsv | map({key: (.[0] + "|" + .[1]), value: .[2]}) | from_entries) as $PB
| ($mtimes | tsv | map({key: (.[0] + "|" + (.[2:] | join("\t"))), value: (.[1] | tonumber? // 0)}) | from_entries) as $MT
| ($bundle | chunks("F")) as $FILES
| ([$FILES[] | select(.head[1] | endswith(".progress.md"))
    | {key: (.head[0] + "|" + (.head[1] | sub("\\.progress\\.md$"; ".md"))), value: (.text | parse_ledger)}] | from_entries) as $LG

# plan 的改動（from 說明來源）：已完成 → 不算；帳本的 BASE 有效 → 它之後的改動；
# .current-task 明確指到（同檔名、任一來源）→ 指到它的那個來源的預設基準（merge-base）；其他 → 不列。
# 預設基準是整個工作區的改動，分給每份沒帳本的 plan 會讓同一批改動出現在每張卡上。
# --actual 指定的那份照舊：/verify 寫「計畫 vs 實際」時 plan 多半已全部 ✅
| def srcchanges($s): (($CH[$s + "|default"] // []) + ($CH[$s + "|untracked"] // [])) | unique_by(.file);
  def changes_for($rec; $completed):
    ($rec.src) as $src | ($rec.name) as $name
    | ($PB[$src + "|" + $name]) as $lb
    | ($vSrc == $src and $vFile == $name) as $forced
    | if $completed and ($forced | not) then {base: null, ledger: false, list: [], from: "completed"}
      elif $lb != null and $CH[$src + "|" + $lb] != null then
        {base: $lb[:7], ledger: true, list: ((($CH[$src + "|" + $lb] // []) + ($CH[$src + "|untracked"] // [])) | unique_by(.file)), from: "ledger"}
      elif $rec.curSrc != null or $forced then (if $forced then $src else $rec.curSrc end) as $cs
        | ($BS[$cs + "|default"] // {kind: "none"}) as $d
        | if $d.kind == "none" or $d.kind == "fallback" then {base: null, ledger: false, list: [], from: "current"}
          else {base: $d.short, ledger: false, list: srcchanges($cs), from: "current"} end
      else {base: null, ledger: false, list: [], from: "none"}
      end;

  def build_plan($rec):
    $rec.pp as $pp
    | ($LG[$rec.src + "|" + $rec.name] // {phase: {}, part: {}}) as $lg
    | ((($pp.fm.status // "") | test("✅")) or (($pp.phases | length) > 0 and all($pp.phases[]; .state == "done"))) as $completed
    | changes_for($rec; $completed) as $cf
    | (if $vSrc == $rec.src and $vFile == $rec.name
       then {result: $vResult, at: $vAt, reason: (if $vReason == "" then null else ($vReason | gsub("[\r\n]+"; " ")) end)}
       else $pp.verify end) as $verify
    | ($verify.result // "") as $vr
    | ([($pp.partsTable // {header: [], rows: []}) | .header as $h | .rows[] | rowobj($h)
        | {id: (.id | unbt), name: ((.["部件"] // "") | trim), phase: ((.["階段"] // "") | unbt | tonumber? // null),
           files: ((.["檔案"] // "") | splitlist),
           acceptance: ((.["驗收"] // "") | trim | if blank then [] else [.] end)}
        | select(.id | blank | not)]) as $parts0
    | ([$parts0[] | {id, res: [.files[] | glob2re]}]) as $pres
    | ([$pp.files[] | glob2re]) as $fres
    | ([$cf.list[:$maxChanges][] | .file as $f
        | ([$pres[] | select(any(.res[]; . as $r | $f | test($r))) | .id] | first // null) as $pt
        | . + {part: $pt, planned: ($pt != null or any($fres[]; . as $r | $f | test($r))), module: ($f | modof)}]) as $ch1
    | ([$ch1[] | select(.planned | not)] | to_entries | map(.value + {xid: "x\(.key + 1)"})) as $ex
    | ([$ch1[] | if .planned then . else (.file as $f | .part = ([$ex[] | select(.file == $f) | .xid] | first)) end]) as $ch
    | ([$pp.phases[] | {key: (.n | tostring), value: .state}] | from_entries) as $phs
    | ([$parts0[] | .id as $id
        | [$ch[] | select(.part == $id)] as $mine
        | ($phs[(.phase // -1) | tostring] // "planned") as $ps
        | (($mine | length) > 0) as $t
        | ($lg.part[$id] // {}) as $lp
        | ($lg.phase[(.phase // -1) | tostring] // {}) as $lph
        | . + {state: (if $cf.from == "completed" then $ps
                       elif $ps == "done" then (if $t then "done" else "skipped" end)
                       elif $vr == "FAIL" then (if $t then "failed" else "skipped" end)
                       elif $vr == "PASS" then (if $t then "done" else "skipped" end)
                       elif $ps == "wip" or $t then "wip" else "planned" end),
               planned: true,
               ai: {summary: (($lp.s // $lph.s) | cap(80)), tests: ($lp.t // $lph.t),
                    source: (if $lp.s != null or $lp.t != null then "part" elif $lph.s != null or $lph.t != null then "phase" else null end),
                    added: ([$mine[].added // 0] | add // 0), removed: ([$mine[].removed // 0] | add // 0)}}]) as $parts
    | ($ex[:30] | map({id: .xid, name: .file, phase: null, files: [.file], acceptance: [], state: "extra", planned: false,
                       ai: {summary: null, tests: null, source: null, added: .added, removed: .removed}})) as $xparts
    | ([$ch[] | select(.module != null) | {module, file}]
       + [$pp.files[] | {module: globmod, file: .} | select(.module != null)]) as $touch
    | {file: "plans/\($rec.name)",
       task: (($pp.fm.wbs_task // "") | if . == "" or . == "none" then null else . end),
       title: ($pp.title // $rec.name), mode: ($pp.fm.mode // null), status: ($pp.fm.status // ""),
       currentPhase: (($pp.fm.current_phase // "") | tonumber? // null),
       source: $rec.src, base: $cf.base, completed: $completed, changesFrom: $cf.from,
       phases: [$pp.phases[] | .n as $n
                | if .state != "done" and any($parts[]; .phase == $n and .state == "failed") then .state = "failed" else . end],
       hasParts: ($pp.partsTable != null),
       parts: ($parts + $xparts), extraMore: ([($ex | length) - 30, 0] | max), extraCount: ($ex | length),
       verify: $verify,
       changes: [$ch[] | {file, added, removed, new, part, planned, module}],
       changesRollup: ($cf.list[$maxChanges:] | rollup),
       modules: ($touch | map(.module) | unique),
       # 任務推斷的兩個來源（提案 3.3）：files: 對到的模組；帳本 BASE 之後的 diff 對到的模組。
       # 沒有帳本時的預設基準是整條分支的改動，每份 plan 都一樣，不能拿來推斷某個任務
       plannedModules: ([$pp.files[] | globmod | select(. != null)] | unique),
       _diffMods: (if $cf.ledger then [$cf.list[] | .file | modof | select(. != null)] | unique else [] end),
       _touch: $touch, _mtime: $rec.mtime, _text: $rec.text};
  def progress: [(.phases | map(select(.state == "done")) | length), (.verify != null), ._mtime];

  ([$FILES[] | select(.head[1] | endswith(".progress.md") | not)
    | {src: .head[0], name: .head[1], text, mtime: ($MT[.head[0] + "|" + .head[1]] // 0), pp: (.text | parse_plan($needPart))}]) as $recs0
| ($currents | tsv | map({src: .[0], v: .[1]})) as $cur0
# .current-task 明確指到的 plan 檔名（比對規則與下方 plan_of 相同）。不限同來源：worktree 沒改過的 plan
# 副本不收，overlay 也可能選主 checkout 的同名那份；同檔名的每一份都算本次，改動取指到它的來源
| ([$cur0[] | . as $c
    | [$recs0[]
       | select((.name | rtrimstr(".md")) as $b | $b == $c.v or ($b | startswith($c.v + "-"))
                or (.pp.fm.wbs_task // "") == $c.v)]
    | sort_by(.src != $c.src, .name) | first | select(. != null) | {name, src: $c.src}]) as $curKeys
| ([$recs0[] | .name as $n | .src as $s
    | . + {curSrc: ([$curKeys[] | select(.name == $n) | .src] | sort_by(. != $s) | first)}]) as $recs
| ([$recs[] | . as $r | build_plan($r)]) as $built
| ([$built[] | select(.source == "main")] | sort_by(.file)) as $mainPlans

# ---- 任務對到模組（提案 3.3）：WBS 明標的一律優先；沒有模組欄、或該列是 — → plan 的 files:，
# 沒有 files:（或對不到模組）再用帳本 BASE 之後的 diff。只看主 checkout 的 plan：overview.md 與 data.js 才一致。
# 同一任務有多份 plan 時取檔名排序第一份推斷得出的
| (reduce $mainPlans[] as $pl ({};
     if $pl.task == null or .[$pl.task] != null then .
     elif ($pl.plannedModules | length) > 0 then .[$pl.task] = {mods: $pl.plannedModules, by: "plan-files"}
     elif ($pl._diffMods | length) > 0 then .[$pl.task] = {mods: $pl._diffMods, by: "diff"}
     else . end)) as $PM
| ([$tasks0[] | ($PM[.id] // null) as $pm
    | if (.modules | length) > 0 then . + {modules: [.modules[] | select(. as $m | $modIds | index($m))], inferred: false, inferredBy: null}
      elif $pm != null then . + {modules: $pm.mods, inferred: true, inferredBy: $pm.by}
      else . + {inferred: false, inferredBy: null} end]) as $tasks

# ---- 落差（提案第 4 節）。給畫面與 overview.md；項目的欄位見 data.js 的 drift
| {codeNotInDoc: (if $docValid then [$mods0[] | select(.source == "scan" and .id != "other")
                                     | {module: .id, name, paths, fileCount: ($FC[.id] // 0)}] else [] end),
   docNotInCode: (if $docValid then [$mods0[] | select(.source == "doc" and (.paths | length) > 0) | {module: .id, name, paths}] else [] end),
   taskModuleMismatch: [$tasks[] | select((.inferred | not) and (.modules | length) > 0) | . as $t | ($PM[.id] // null) as $pm
                        | select($pm != null and ([$pm.mods[] | select(. as $m | $t.modules | index($m))] | length) == 0)
                        | {task: .id, declared: .modules, actual: $pm.mods, by: $pm.by}],
   wbsUnknownModule: [$tasks0[] | .id as $t | ($PM[$t].mods // []) as $pmm | .modules[] | select(. as $m | $modIds | index($m) | not)
                      | . as $m
                      | {task: $t, module: $m,
                         suggest: (([$pmm[] | select(. != $m)] | first)
                                   // ([$modIds[] | select(. != "other") | . as $i
                                        | select(($i | length) >= 3 and ($m | length) >= 3 and (($m | startswith($i)) or ($i | startswith($m))))] | first)
                                   // null)}],
   tasksInferred: [$tasks[] | select(.inferred) | {task: .id, modules, inferredBy}]} as $drift

# worktree overlay：同名 plan 取進度較新的那份（內容相同就算主 checkout 的）。進到這裡的 worktree plan
# 只有它改過或沒進版控的（沒動過的版控副本在 gather_source 就濾掉了），所以主 checkout 已歸檔的不會復活。
# --actual 指定的那份一定入選，畫面才會顯示剛寫進去的結果。
| ($built | group_by(.file) | map(
    (map(select(.source == "main")) | first) as $m
    | (map(select(.source == $vSrc and .file == ("plans/" + $vFile))) | first) as $forced
    | if $forced != null then $forced
      elif $m == null then (sort_by(progress) | last)
      else (([.[] | select(.source != "main" and ._text != $m._text and (progress > ($m | progress)))]
             | sort_by(progress) | last) // $m)
      end)) as $plans0

# 「本次」：主 checkout 與各 worktree 的 .current-task 全部標出；都沒有 → 最近改過、還沒完成的 plan
| def plan_of($v):
    [$plans0[] | select((.file | ltrimstr("plans/") | rtrimstr(".md")) as $b
                        | $b == $v or ($b | startswith($v + "-")) or .task == $v)] | first;
  ([$cur0[] | . as $c | plan_of($c.v) as $pl
    | {task: (if ($c.v | startswith("adhoc-")) then ($pl.task // null) else $c.v end),
       plan: ($pl.file // null), source: $c.src}]) as $cur1
| (if ($cur1 | length) > 0 then $cur1
   else [[$plans0[] | select(.status | test("⏳|🔄"))] | sort_by(._mtime) | last // empty
         | {task, plan: .file, source, guessed: true}] end) as $currents
| ([$currents[].task | select(. != null)]) as $curTasks
| ($plans0 | map((.file as $f | any($currents[]; .plan == $f)) as $c
     | . + {current: $c, changesFrom: (if $c and .changesFrom == "none" then "guessed" else .changesFrom end)})
   | sort_by([(if .current then 0 else 1 end), .file])) as $plans
| ([$plans[] | select(.current and .task == null) | .modules[]] | unique) as $curMods

# ---- plan 疊層（ADR-007 第 3 點）：本次 plan 的進度與「預計會動的模組」（files: 對到的模組）。
# 「預計但沒動／沒預計卻動了」沿用 mods_with 的 mismatch，不另比
| def phinfo($pl):
    if $pl == null then {phase: null, phases: null, activePhases: []}
    else ([$pl.phases[] | select(.state == "wip") | .n]) as $w
      | {phase: $pl.currentPhase, phases: ($pl.phases | length),
         activePhases: (if ($w | length) > 0 then $w elif $pl.currentPhase != null then [$pl.currentPhase] else [] end)} end;
  ($currents | map(. as $c | . + phinfo([$plans[] | select(.file == $c.plan)] | first))) as $cx
| ([$cx[] | .plan as $f | $plans[] | select(.file == $f) | .plannedModules[]] | unique) as $plannedMods

# ---- 一頁現況（ADR-007 第 2 點）：overview.md 開頭「## 現況」與 data.js 的 status 是同一份，只看主 checkout。
# WBS 的完成日多半只寫 MM-DD：當作今年，比今天晚就算去年
| def daynum($y; $m; $d):
    (if $m <= 2 then $y - 1 else $y end) as $Y
    | ($Y / 400 | floor) as $era | ($Y - $era * 400) as $yoe
    | (((153 * (if $m > 2 then $m - 3 else $m + 9 end) + 2) / 5 | floor) + $d - 1) as $doy
    | $era * 146097 + $yoe * 365 + ($yoe / 4 | floor) - ($yoe / 100 | floor) + $doy;
  ($now[:10] | split("-") | map(tonumber)) as $today
| daynum($today[0]; $today[1]; $today[2]) as $todayN
| def doneday:
    ((.statusText | capture("(?<y>[0-9]{4})-(?<m>[0-9]{1,2})-(?<d>[0-9]{1,2})"))
     // (.statusText | capture("(?<m>[0-9]{1,2})[-/](?<d>[0-9]{1,2})") | . + {y: null})
     // null)
    | if . == null then null
      else (.m | tonumber) as $m | (.d | tonumber) as $d
        | if .y != null then daynum(.y | tonumber; $m; $d)
          else daynum($today[0]; $m; $d) as $n | if $n > $todayN then daynum($today[0] - 1; $m; $d) else $n end end
      end;
  (reduce ($tasks[] | .milestone) as $m ([]; if any(.[]; . == $m) then . else . + [$m] end)) as $msNames
| ([$tasks[] | select(.state == "wip") | . as $t | ([$mainPlans[] | select(.task == $t.id)] | first) as $pl
    | {task: .id, title, plan: ($pl.file // null)} + phinfo($pl)]) as $wip
| ({name: ($p.name // "（未命名專案）"),
   oneLiner: (if $oneLiner == "" then null else $oneLiner end),
   milestones: [$msNames[] as $m | [$tasks[] | select(.milestone == $m)] as $ts
                | {name: $m, done: ([$ts[] | select(.state == "done")] | length),
                   total: ([$ts[] | select(.state != "skip")] | length), state: ([$ts[].state] | modstatus)}],
   inProgress: $wip[:5], inProgressMore: ([($wip | length) - 5, 0] | max),
   blocked: [$tasks[] | select(.state == "blocked") | {task: .id, title}],
   next: ([$tasks[] | select(.state == "todo") | {task: .id, title}] | first // null),
   recentDays: 14,
   recentDone: ([$tasks[] | select(.state == "done") | doneday | select(. != null and $todayN - . >= 0 and $todayN - . < 14)] | length),
   drift: ({total: ([$drift[] | length] | add // 0)} + ($drift | map_values(length)))}
  # line：畫面頁首的一行摘要（X17，畫面讀到物件就顯示 status.line）。第一個還沒完成的里程碑＋三個數
  | . + {line: ([(.milestones | map(select(.state != "done")) | first // empty | "\(.name) \(.done)/\(.total)"),
                "進行中 \($wip | length) 項", "阻塞 \(.blocked | length) 項", "落差 \(.drift.total) 項"] | join("・"))})
  as $status

# ---- 地圖上的「本次改動」：主 checkout ＋ 有 plan 或 .current-task 的 worktree
| ([$BS | keys[] | select(endswith("|default")) | rtrimstr("|default") | select(. != "main")] | sort) as $wtSrcs
| ([(srcchanges("main")[] + {source: "main"})] + [$wtSrcs[] as $s | srcchanges($s)[] + {source: $s}]) as $chAll
| ([$plans[] | .source as $s | .parts as $pa | .changes[] | select(.planned and .part != null) | .part as $pt
    | {key: ($s + "|" + .file), value: ([$pa[] | select(.id == $pt) | .ai.summary] | first)} | select(.value != null)]
   | from_entries) as $SUM
| ([$chAll[:$maxChanges][] | .file as $f | . + {module: ($f | modof), summary: ($SUM[.source + "|" + $f] // null)}]) as $changesList

# ---- 已歸檔的完成數：wbs-archive.md 的 ✅ 列＋plans/archive/ 的 plan，依任務編號去重；WBS 裡還在的任務已經算過，不重算。
# 模組取法：wbs-archive 那列的模組欄 → 同編號 plan 的 files: 對到的模組 → 都沒有就算「未標模組」
# （舊節沒有模組欄、填 —、或填了模組表沒有的 id）。沒有 wbs_task 的 ad-hoc plan 各算一份、只進模組不進未標模組。
| ([$tasks0[].id]) as $wbsIds
| ([$wbsArch | tables[] | select(.header as $h | all($needWbs[]; . as $c | $h | index($c)))
    | (.header | index($wcol) != null) as $hasCol | .header as $h | .rows[] | rowobj($h)
    | select((.["#"] | unbt | blank | not) and ((.["狀態"] | tstate) == "done"))
    | {task: (.["#"] | unbt),
       mods: (if $hasCol then (.[$wcol] | splitlist | map(select(. as $m | $modIds | index($m)))) else [] end)}]) as $waRows
| ([$archive | chunks("A")[] | ("---\n" + .text + "\n---") | parse_plan($needPart)
    | {task: (.fm.wbs_task // "none" | if . == "" then "none" else . end),
       mods: ([.files[] | globmod | select(. != null)] | unique)}]) as $apRows
| ([$apRows[] | select(.task == "none")]) as $adhoc
| ([($waRows + $apRows)[] | select(.task != "none") | .task] | unique
   | map(. as $t | select($wbsIds | index($t) | not)
         | {task: $t,
            mods: (([$waRows[] | select(.task == $t) | .mods[]] | unique) as $w
                   | if ($w | length) > 0 then $w else ([$apRows[] | select(.task == $t) | .mods[]] | unique) end)})) as $arch1
| (reduce ($arch1 + $adhoc)[] as $a ({}; reduce $a.mods[] as $m (.; .[$m] += 1))) as $AD
| ({done: ($arch1 | length), unmapped: ([$arch1[] | select(.mods | length == 0)] | length)}) as $archived

# ---- 版面由這裡決定（畫面只換算像素、節點不可拖）：群組由左到右排成欄；
# 群組內依「群組內連線」的深度再分子欄（gateway → svc-a 會排在 gateway 右邊），每欄最多 4 列
| ((($dg // {}).groups // []) + ($sk.groups // []) + $NG.new | map(select(.id as $g | $mods0 | any(.group == $g)))
   + (if any($mods0[]; .group == "_ungrouped") then [{id: "_ungrouped", label: "未分組"}] else [] end)) as $groups
| ([($dg // {}).edges // [] | .[] | select(.from != .to)
    | select(.from as $a | .to as $b | ($modIds | index($a)) and ($modIds | index($b)))]
   | reduce .[] as $e ([]; if any(.[]; .from == $e.from and .to == $e.to) then . else . + [$e] end)
   | map(. + {source: "doc"})) as $dedges
# 程式碼邊：逐檔紀錄（import、前端呼叫後端路由的 http）依合併後的歸屬彙總；第三方（pkg:…）與模組內的不成邊。
# 與文件邊重複的不另畫
| ([($sk.imports // [])[] | select(.[2] == "import" or .[2] == "http") | [$FM[.[0]], $FM[.[1]], .[2]]
    | select(.[0] != null and .[1] != null and .[0] != .[1])]
   | group_by(.) | map({from: .[0][0], to: .[0][1], label: "", weight: length, source: .[0][2]})) as $iedges
| ($dedges | map({key: "\(.from)\t\(.to)", value: true}) | from_entries) as $dpair
| ($dedges + [$iedges[] | select($dpair["\(.from)\t\(.to)"] | not)]) as $edges
| (reduce $groups[] as $g ({col: 0, pos: {}};
    [$mods0[] | select(.group == $g.id) | .id] as $ids
    | ([$edges[] | select(.from as $a | .to as $b | ($ids | index($a)) and ($ids | index($b)))]
       | group_by(.to) | map({key: .[0].to, value: map(.from)}) | from_entries) as $inc
    | (reduce range(0; $ids | length) as $_
        ([$ids[] | {key: ., value: 0}] | from_entries;
         . as $d | with_entries(.key as $k
           | .value = ([0] + [($inc[$k] // [])[] | $d[.] + 1] | max | [., ($ids | length) - 1] | min)))) as $depth
    | reduce ($ids | group_by($depth[.]) | sort_by($depth[.[0]]))[] as $colIds (.;
        reduce range(0; $colIds | length) as $i (.;
          .pos[$colIds[$i]] = {col: (.col + (($i / 4) | floor)), row: ($i % 4)})
        | .col += ((($colIds | length) + 3) / 4 | floor))
   ) | .pos) as $pos

# ---- 模組燈號：WBS 的判法（modstatus）＋「掛在這個模組的 plan 最近一次 /verify 是 FAIL → 有問題」
| def mods_with($plans; $curTasks; $curMods; $chg; $planned):
    $mods0 | map(
      .id as $id
      | [$tasks[] | select(.modules | index($id))] as $own
      | [$own[].id] as $ownIds
      | ([$own[].state] | modstatus) as $st0
      | ([$own[] | select(.state == "done")] | length) as $done
      | ([$own[] | select(.state != "skip")] | length) as $total
      | [$plans[] | select(.verify.result == "FAIL")
         | select((.modules | index($id)) or (.task != null and (.task as $t | $ownIds | index($t))))] as $failed
      | . + {status: (if ($failed | length) > 0 then "issue" else $st0 end),
             statusReason: ((if ($own | length) == 0 then "WBS 沒有任務掛在這個模組"
               else "\($done)/\($total) 完成"
                 + ([$own[] | select(.state == "wip") | .id] | if length > 0 then "；\(join("、")) 進行中" else "" end)
                 + ([$own[] | select(.state == "blocked") | .id] | if length > 0 then "；\(join("、")) 阻塞" else "" end)
               end)
               + ($failed | map("；\(.task // .file) 驗證失敗：\(.verify.reason // "（沒寫原因）")") | join(""))),
             counts: {done: $done, total: $total, archivedDone: ($AD[$id] // 0)},
             tasks: $ownIds,
             current: (any($ownIds[]; . as $t | $curTasks | index($t)) or ($curMods | index($id) != null)),
             changed: ([$chg[] | select(.module == $id)] | length),
             mismatch: [$plans[] | select(.task != null) | .task as $t
                        | ([$tasks[] | select(.id == $t and (.inferred | not)) | .modules[]]) as $decl
                        | .modules as $tch
                        | select(($decl | length) > 0 and ($tch | length) > 0)
                        | if ($decl | index($id)) and ($tch | index($id) | not) then {task: $t, kind: "declared-not-touched", files: []}
                          elif ($tch | index($id)) and ($decl | index($id) | not) then
                            {task: $t, kind: "touched-not-declared", files: ([._touch[] | select(.module == $id) | .file] | unique | .[:5])}
                          else empty end],
             pos: $pos[$id],
             fileCount: ($FC[$id] // 0),
             routes: {count: (($RT[$id] // []) | length), sample: (($RT[$id] // [])[:20])},
             planned: ($planned | index($id) != null)});
  def notices_for($plans): [
    (if $demo then {level: "info", text: "demo 情境沒有架構文件，專案地圖不會出現（之後的任務圖仍可用）", action: "/docs-init --mvp"} else empty end),
    (if $draft then {level: "warn", text: "架構草稿待確認：\($archPath) 帶 `\($draftMark)` 標記，地圖照畫，但不拿它覆寫模組名稱；確認模組切分後移除標記", action: "確認後由主模型移除標記"} else empty end),
    (if $scanState == "failed" then {level: "warn", text: "骨架掃描失敗，地圖只有架構文件寫的模組", action: "錯誤訊息在 taskmaster-data/overview/.scan-error"}
     elif $scanState == "missing" then {level: "warn", text: "找不到 .claude/scripts/overview-scan.sh，地圖只有架構文件寫的模組", action: "跑 update-template 補齊"} else empty end),
    (if $docValid and $dg == null then {level: "info", text: "架構文件沒有可解析的容器圖（5.1 mermaid），模組全部放在「未分組」", action: null} else empty end),
    ([$docMods[] | select(.declared | not) | .id] | if length > 0 then {level: "warn", text: "容器圖有、模組表沒有的節點（灰色虛線）：\(join("、"))", action: "在 5.5 補上這幾列"} else empty end),
    ([$rows[] | select(.id as $i | $dgIds | index($i) | not) | .id] | if length > 0 and $dg != null then {level: "info", text: "模組表有、容器圖沒畫的模組（放在「未分組」）：\(join("、"))", action: "在 5.1 補上節點"} else empty end),
    # 「還沒對到模組」只出一則：推斷補上的不算，推斷不出的才算
    (([$tasks[] | select(.inferred)] | length) as $ni | ([$tasks[] | select(.modules | length == 0)] | length) as $nu
     | ([(if $ni > 0 then "\($ni) 個任務的模組由 plan 推斷" else empty end), (if $nu > 0 then "\($nu) 個任務還沒對到模組" else empty end)]
        | join("，")) as $why
     | if ($demo | not) and ($tasks0 | length) > 0 and $noColCount == ($tasks0 | length) then
         {level: (if $nu > 0 then "warn" else "info" end), text: "WBS 沒有模組欄：\($why)", action: "/task-status（會提議補欄並寫回推斷結果）"}
       elif ($demo | not) and $noColCount > 0 then
         {level: "warn", text: "WBS 有 \($noColCount) 個任務所在的節沒有模組欄\(if $why != "" then "：\($why)" else "" end)", action: "/task-status（會提議補欄並寫回推斷結果）"}
       else empty end),
    ($unknownMods | if length > 0 and ($demo | not) then {level: "warn", text: "任務標了模組表沒有的模組：\(.[:8] | join("、"))", action: "改 WBS 模組欄或補架構文件 5.5"} else empty end),
    (($sk.notices // [])[]),
    ($flows[] | select((.modules | length) == 0)
     | {level: "warn", text: "資料流「\(.title)」對不到任何模組（模組改名？）",
        action: "\($archPath) 第 \(.line) 行：participant id 寫模組 id 或分組 id"}),
    ([$plans[] | select(.base == null and (.changesFrom == "ledger" or .changesFrom == "current")) | .file] | if length > 0 then {level: "warn", text: "找不到比較基準（帳本沒有 BASE=，也找不到預設分支），列不出這幾份 plan 改了哪些檔：\(join("、"))", action: "帳本記 BASE=<commit>（subagent-execution）"} else empty end),
    ([$plans[] | select((.hasParts | not) and (.status | test("✅") | not)) | .file] | if length > 0 then {level: "info", text: "這幾份 plan 沒有「一眼看懂」部件表，任務圖只列得出改了哪些檔：\(join("、"))", action: "格式見 plan-format skill"} else empty end),
    (([$NV[] | select((.why | length) > 0)] | length) as $bad
     | if $NR.header != null then {level: "warn", text: "module-notes.md 的表頭不對（\($NR.header)），地圖上沒有任何說明", action: "bash .claude/scripts/overview.sh --check-notes"}
       elif $bad > 0 then {level: "warn", text: "module-notes.md 有 \($bad) 列沒通過檢查，那幾個模組當成沒有說明", action: "bash .claude/scripts/overview.sh --check-notes"}
       else empty end),
    (if ($OUTV | length) > 0 then {level: "warn", text: "module-notes.md 表格以外有 \($OUTV | length) 行含機密樣式（主機、帳密、Email 之類）", action: "bash .claude/scripts/overview.sh --check-notes"} else empty end),
    (if $notesBaseOk == false and ($NOTE | length) > 0 then
       {level: "info", text: "module-notes.md 的 based_on（\(if $notesBase == "" then "沒寫" else $notesBase end)）不是有效的 commit，所有說明都標成可能過期", action: "請 documentation-specialist 重寫說明，based_on 填當下的 HEAD"}
     else empty end)
  ];
  def public: map(del(._touch, ._mtime, ._text, ._diffMods));
  def taskout: [$tasks[] | {id, title, status, state, milestone, modules, inferred, inferredBy}];

  # --check-notes：一行一筆違規
  if $outMode == "check" then
    (if $NR.header != null then "表頭：\($NR.header)"
     else $NV[] | .n as $n | (if .id == "" then "（沒有 id）" else .id end) as $id | .why[] | "第 \($n) 列 \($id)：\(.)" end),
    ($OUTV[] | .l as $l | .why[] | "表外第 \($l) 行：\(.)")
  # --notes-todo：沒有說明或可能過期的模組，代表檔最多 3 個：路由最多的檔 → 進入點 → 被引用最多的檔
  #（5.2 寫的是「最大的檔」；腳本不量檔案大小，改用被引用次數，同樣挑得出核心檔）
  elif $outMode == "todo" then
    ($FM | to_entries | group_by(.value) | map({key: .[0].value, value: map(.key)}) | from_entries) as $MF
    | (reduce ($sk.routes // [])[] as $r ({}; .[$r[0]] += 1)) as $RC
    | (reduce ($sk.imports // [])[] as $i ({}; .[$i[1]] += 1)) as $IN
    | $notable[] | select(.description == null or .description.stale)
    | ($MF[.id] // []) as $fs
    | (([$fs[] | select($RC[.] != null)] | sort_by(-($RC[.]), .) | .[:1])
       + ([$fs[] | select(split("/") | last | test("^(main|index|app|server|program|application)\\.[A-Za-z0-9]+$"; "i"))] | sort | .[:1])
       + ($fs | sort_by(-($IN[.] // 0), .))
       | reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end) | .[:3]) as $rep
    | "\(.id)\t\(.paths | join(","))\t\($rep | join(","))\t\(if .description == null then "missing" else "stale" end)"
  else
  # ---- 模組展開（ADR-2026-11-06-002 決策 1）：只進 data.js（overview.md 與架構自動段不放檔案層級）。
  # 掃描截斷時 null；沒有檔的模組是空的 inner（畫面顯示「沒有內部資料」）
  ($sk.scan.truncated == true) as $innerOff
  | ([($sk.fileEdges // [])[] | select($FM[.from] != null)] | group_by($FM[.from])
     | map({key: $FM[.[0].from], value: .}) | from_entries) as $FEM
  | ($FM | to_entries | group_by(.value) | map({key: .[0].value, value: (map(.key) | sort)}) | from_entries) as $MFS
  | def lcp($a; $b): ([$a, $b] | map(length) | min) as $n
      | $a[:([range(0; $n) | select($a[.] != $b[.])] | first) // $n];
    def commondir: map(split("/") | .[:-1]) | if length == 0 then "" else reduce .[1:][] as $d (.[0]; lcp(.; $d)) | join("/") end;
    def krank: {m: 0, db: 1, pkg: 2}[split(":")[0]] // 3;
    # 摺疊：逐檔 → 超過上限時根下一層的子目錄各併成 <名>/ → 仍超過就依進出邊數留前 N-1 個，其餘計入 folded
    def mkinner($id; $fs; $es):
      ($fs | commondir) as $root
      | (if $root == "" then 0 else ($root | length) + 1 end) as $cut
      | ($fs | map({key: ., value: .[$cut:]}) | from_entries) as $REL
      | (if ($fs | length) <= $inMaxN then $REL else $REL | map_values(if test("/") then sub("/.*$"; "/") else . end) end) as $N
      | ([$N[]] | unique) as $u
      | (if ($u | length) <= $inMaxN then $u
         else (reduce $es[] as $e ({};
                 .[$N[$e.from]] += 1
                 | if $e.to != null and $FM[$e.to] == $id and $N[$e.to] != $N[$e.from] then .[$N[$e.to]] += 1 else . end)) as $deg
           | $u | sort_by(-($deg[.] // 0), .) | .[:($inMaxN - 1)] | sort
         end) as $keep
      | ($keep | to_entries | map({key: .value, value: .key}) | from_entries) as $IX
      | ([$es[] | select(.to != null and $FM[.to] == $id) | [$IX[$N[.from]], $IX[$N[.to]]]
          | select(.[0] != null and .[1] != null and .[0] != .[1])]
         | group_by(.) | map(.[0] + [length]) | sort_by(-.[2], .[0], .[1]) | .[:$inMaxE]) as $ie
      | ([$es[] | (if .to == null then .ext elif ($FM[.to] // $id) != $id then "m:" + $FM[.to] else null end) as $t
          | select($t != null) | {i: $IX[$N[.from]], t: $t, s: .source}]) as $ext
      | ([$ext[] | select(.i != null) | [.i, .t, .s]] | group_by(.) | map([.[0][0], .[0][1], length, .[0][2]])) as $o0
      | (reduce $o0[] as $x ({}; .[$x[1]] += $x[2])) as $TW
      | ($o0 | sort_by((.[1] | krank), -$TW[.[1]], .[1], -.[2], .[0]) | .[:$inMaxO]) as $out
      | {root: $root, nodes: $keep, folded: ([$fs[] | select($IX[$N[.]] == null)] | length),
         edges: $ie, out: $out, outMore: (([$ext[].t] | unique | length) - ([$out[][1]] | unique | length))};
    def inner_for($id): if $innerOff then null else mkinner($id; $MFS[$id] // []; $FEM[$id] // []) end;
  {schema: 2,
   generatedAt: $now,
   generator: {script: "overview.sh", version: 3},
   truncated: (($chAll | length) > $maxChanges or any($plans[]; (.changesRollup | length) > 0)),
   project: {name: ($p.name // "（未命名專案）"), docsMode: $mode,
             architectureDoc: (if $hasArch then $archPath else null end), architectureDraft: $draft},
   scan: (if $sk.scan == null then null
          else $sk.scan + {modules: ($mods0 | length), edges: ($iedges | length), ms: $scanMs, cached: ($scanState == "cached")} end),
   status: $status,
   notices: notices_for($plans),
   current: ($cx[0] // null),
   currents: $cx,
   groups: $groups,
   modules: (mods_with($plans; $curTasks; $curMods; $changesList; $plannedMods)
             | map(. + {inner: inner_for(.id), flows: ($MFLOWS[.id] // [])})),
   edges: $edges,
   flows: $flows,
   tasks: taskout,
   drift: $drift,
   unmappedTasks: [$tasks[] | select(.modules | length == 0) | .id],
   changesBase: (($BS["main|default"] // {}) | if (.short // "") != "" then {commit: .short, defaultBranch: .def} else null end),
   changes: $changesList,
   changesRollup: ($chAll[$maxChanges:] | rollup),
   archived: $archived,
   # --print-path 用 awk 抓這個物件（key 順序固定）；off 時是 null，不提示
   notes: (if $notesOff then null
           else {missing: ([$notable[] | select(.description == null)] | length),
                 stale: ([$notable[] | select(.description.stale == true)] | length)} end),
   plans: ($plans | public)},
  {project: {name: ($p.name // "（未命名專案）")},
   notices: notices_for($mainPlans),
   groups: $groups,
   modules: mods_with($mainPlans; []; []; []; []),
   edges: $edges,
   codeEdges: $iedges,
   tasks: taskout,
   drift: $drift,
   status: $status,
   unmappedTasks: [$tasks[] | select(.modules | length == 0) | .id],
   archived: $archived,
   plans: ($mainPlans | public)}
  end
JQ

# overview.md 與 plan 的「計畫 vs 實際」共用的 markdown 產生器
IFS= read -r -d '' JQ_MDDEFS <<'JQ'
def light: {done: "🟢", wip: "🟡", issue: "🔴", todo: "⚪"}[.];
def word: {done: "完成", wip: "開發中", issue: "有問題", todo: "未開始"}[.];
def lab: gsub("\""; "#quot;") | gsub("[\\[\\]]"; " ");
def cell: gsub("\\|"; "\\|") | gsub("\n"; " ");
def RESERVED: ["end", "graph", "subgraph", "style", "class", "classDef", "click", "linkStyle", "flowchart", "direction"];
def nid: if test("^[A-Za-z][A-Za-z0-9_]*$") and (. as $i | RESERVED | index($i) | not) then . else "n_" + gsub("[^A-Za-z0-9_]"; "_") end;
def sicon: {planned: "⬜", wip: "🟡", done: "✅", skipped: "⬚", failed: "❌", extra: "＋"}[.] // "";
def sword: {planned: "計畫中", wip: "進行中", done: "完成", skipped: "計畫內沒做", failed: "失敗", extra: "計畫外"}[.] // .;
# 這一行會被 overview.sh 讀回來當作驗證結果（parse_plan），格式改了要同步那邊的 regex
def vline: if . == null then empty
  else "驗證：\(if .result == "PASS" then "✅" else "❌" end) \(.result)\(if .at then "（\(.at)）" else "" end)\(if .reason then " — \(.reason | gsub("\n"; " "))" else "" end)" end;
def delta: if (.added // 0) + (.removed // 0) > 0 then "+\(.added // 0) / −\(.removed // 0)" else "—" end;
# 線條：虛線＝還沒走到；實線＝兩端都完成。部件外框虛線＝計畫、實線＝已做
def taskgraph:
  . as $p
  | [$p.parts[] | select(.planned)] as $pl
  | ($p.extraCount // 0) as $xn
  | [$p.phases[].n] as $pns
  | if ($p.parts | length) == 0 then "（plan 沒有「一眼看懂」部件表，也沒有計畫外的改動）" else
    ("```mermaid",
     "flowchart LR",
     "  classDef planned fill:#ffffff,stroke:#9ca3af,stroke-dasharray:5 5,color:#6b7280",
     "  classDef wip fill:#fef3c7,stroke:#d97706,color:#78350f",
     "  classDef done fill:#d1fae5,stroke:#059669,color:#064e3b",
     "  classDef skipped fill:#f9fafb,stroke:#d1d5db,stroke-dasharray:2 4,color:#9ca3af",
     "  classDef failed fill:#fee2e2,stroke:#dc2626,color:#7f1d1d",
     "  classDef extra fill:#ede9fe,stroke:#7c3aed,color:#4c1d95",
     ($p.phases[] as $ph | [$pl[] | select(.phase == $ph.n)] as $ps | select(($ps | length) > 0)
       | "  subgraph ph\($ph.n)[\"階段 \($ph.n) \($ph.state | sicon) \($ph.name | lab)\"]",
         ($ps[] | "    \(.id | nid)[\"\(.state | sicon) \(.name | lab)\"]"),
         "  end"),
     ($pl[] | select(.phase as $n | $pns | index($n) | not) | "  \(.id | nid)[\"\(.state | sicon) \(.name | lab)\"]"),
     (if $xn > 0 then "  xall[\"＋ 計畫外 \($xn) 個檔\"]" else empty end),
     (range(0; ($pl | length) - 1) as $i
       | "  \($pl[$i].id | nid) \(if $pl[$i].state == "done" and $pl[$i + 1].state == "done" then "-->" else "-.->" end) \($pl[$i + 1].id | nid)"),
     ($pl[] | "  class \(.id | nid) \(.state)"),
     (if $xn > 0 then "  class xall extra" else empty end),
     "```") end;
def ptable:
  . as $p
  | "| 部件 | 狀態 | AI 做了什麼 | 檔案 | +/− | 測試 |",
    "|---|---|---|---|---|---|",
    ($p.parts[] | .id as $id | [$p.changes[] | select(.part == $id) | .file] as $cf
     | "| \(if .planned then "\(.id) \(.name | cell)" else "＋" end) | \(.state | sicon) \(.state | sword) | \(if .ai.summary then (.ai.summary | cell) + (if .ai.source == "phase" then "（階段摘要）" else "" end) elif .planned then "—" else "（帳本無紀錄）" end) | \((if ($cf | length) > 0 then $cf else .files end) | .[:4] | map("`\(.)`") | join(" ") | if . == "" then "—" else . end) | \(.ai | delta) | \(.ai.tests // "—") |"),
    ([$p.changes[] | select(.planned and .part == null)] | select(length > 0)
     | "| — | 計畫內（沒對到部件） | — | \(.[:4] | map("`\(.file)`") | join(" ")) | \({added: (map(.added // 0) | add), removed: (map(.removed // 0) | add)} | delta) | — |"),
    (if ($p.extraMore // 0) > 0 then "| ＋ | 計畫外 | 另有 \($p.extraMore) 個檔沒列出 | — | — | — |" else empty end),
    (($p.changesRollup // [])[] | "| — | 未逐一列出 | 改動太多，依目錄彙總 | `\(.dir)` \(.files) 個檔 | \(delta) | — |");
JQ

# overview.md：只反映主 checkout（md.json），不含 generatedAt、「本次」、地圖的本次改動
IFS= read -r -d '' JQ_MD <<'JQ'
def dname: {codeNotInDoc: "程式有、架構文件沒寫的模組", docNotInCode: "架構文件寫了、程式沒有的模組",
            taskModuleMismatch: "WBS 標的模組與 plan 碰到的不同", wbsUnknownModule: "WBS 標了不存在的模組",
            tasksInferred: "模組由 plan 推斷的任務"}[.] // .;
def dnext: {codeNotInDoc: "委派 architect 補進架構文件，或不理它", docNotInCode: "程式已搬家或刪掉，架構文件要跟著改",
            taskModuleMismatch: "改 WBS 的模組欄，或確認是跨模組任務", wbsUnknownModule: "照括號裡的建議改 WBS 的模組 id",
            tasksInferred: "/task-status 可提議寫回 WBS"}[.] // "";
def ditem($k):
  if $k == "codeNotInDoc" then "`\(.module)`"
  elif $k == "docNotInCode" then "`\(.module)`（\(.paths | map("`\(.)`") | join(", "))）"
  elif $k == "taskModuleMismatch" then "\(.task) 標 \(.declared | join("、"))、實際在 \(.actual | join("、"))"
  elif $k == "wbsUnknownModule" then "\(.task) 的 `\(.module)`\(if .suggest then "（可能是 `\(.suggest)`）" else "" end)"
  else "\(.task) → \(.modules | join("、"))（\(.inferredBy)）" end;
def dshort: {codeNotInDoc: "文件沒寫的模組", docNotInCode: "程式沒有的模組", taskModuleMismatch: "任務模組不符",
             wbsUnknownModule: "WBS 寫錯的模組", tasksInferred: "推斷的任務"}[.] // .;
def bar($n; $t): (if $t > 0 then ($n * 5 / $t | round) else 0 end) as $f | [(range(0; $f) | "█"), (range($f; 5) | "░")] | join("");
def msicon: {done: "✅", wip: "🔄", issue: "🚫", todo: "⏳"}[.] // "";
def phtext: if (.activePhases | length) > 0 and .phases != null then "（plan 第 \(.activePhases | map(tostring) | join("、"))／\(.phases) 階段）"
            elif .plan != null then "（plan 未開始）" else "" end;
# 一頁現況（≤ 30 行）：--status 只印這一節，/task-status 直接轉貼。每一列都以關鍵字開頭，空的寫「無」
def statuslines:
  . as $s
  | "## 現況 — \($s.name)", "",
    ($s.oneLiner // empty | ., ""),
    (if ($s.milestones | length) == 0 then "- 里程碑 （WBS 沒有任務）"
     else ($s.milestones[:8][] | "- 里程碑 \(.name) \(bar(.done; .total)) \(.done)/\(.total) \(.state | msicon)"),
          (if ($s.milestones | length) > 8 then "- 里程碑 另有 \(($s.milestones | length) - 8) 個沒列出" else empty end) end),
    "- 進行中 \(if ($s.inProgress | length) == 0 then "無"
               else ([$s.inProgress[] | "\(.task) \(.title)\(phtext)"] | join(" ・ "))
                    + (if $s.inProgressMore > 0 then " 等另 \($s.inProgressMore) 個" else "" end) end)",
    "- 阻塞 \(if ($s.blocked | length) == 0 then "無"
             else ([$s.blocked[:5][] | "\(.task) \(.title)"] | join(" ・ "))
                  + (if ($s.blocked | length) > 5 then " 等共 \($s.blocked | length) 個" else "" end) end)",
    "- 下一個 \(if $s.next then "\($s.next.task) \($s.next.title)" else "無" end)",
    "- 最近 \($s.recentDays) 天 完成 \($s.recentDone) 項",
    "- 落差 \(if $s.drift.total == 0 then "無"
             else "\($s.drift.total) 項（\([$s.drift | to_entries[] | select(.key != "total" and .value > 0) | "\(.key | dshort) \(.value)"] | join("・"))；見地圖）" end)",
    "";
. as $d
| ($d.modules | to_entries | map({key: .value.id,
    value: (if (.value.id | test("^[A-Za-z0-9_-]+$")) and (.value.id as $i | RESERVED | index($i) | not)
            then .value.id else "m\(.key + 1)" end)}) | from_entries) as $sid
| [
  "<!-- 由 .claude/scripts/overview.sh 產生，勿手改。互動版：.claude/taskmaster-data/overview/index.html -->",
  "# 專案圖解 — \($d.project.name)",
  "",
  # 現況在最前面（第一個二級標題）；提示放進專案地圖節，--status 才不會把它們一起印出去
  ($d.status | statuslines),
  "## 專案地圖",
  "",
  ($d.notices[] | "> \(if .level == "warn" then "⚠️" else "ℹ️" end) \(.text)\(if .action then "（→ \(.action)）" else "" end)"),
  (if ($d.notices | length) > 0 then "" else empty end),
  (if ($d.modules | length) == 0 then "（沒有可畫的模組，原因見上方提示）" else
    ("```mermaid",
     "flowchart LR",
     "  classDef done fill:#d1fae5,stroke:#059669,color:#064e3b",
     "  classDef wip fill:#fef3c7,stroke:#d97706,color:#78350f",
     "  classDef issue fill:#fee2e2,stroke:#dc2626,color:#7f1d1d",
     "  classDef todo fill:#f3f4f6,stroke:#9ca3af,color:#374151",
     ($d.groups | to_entries[] | .key as $gi | .value as $g
       | "  subgraph sg\($gi + 1)[\"\($g.label | lab)\"]",
         ($d.modules[] | select(.group == $g.id)
           | "    \($sid[.id])\(if .shape == "db" then "[(" else "[" end)\"\(.status | light) \(.name | lab)\"\(if .shape == "db" then ")]" else "]" end)"),
         "  end"),
     ($d.edges[] | "  \($sid[.from]) -->\(if .label != "" then "|\(.label | lab | gsub("\\|"; " "))|" else "" end) \($sid[.to])"),
     ($d.modules[] | "  class \($sid[.id]) \(.status)"),
     "```",
     "",
     "| 燈號 | 模組 | 路徑 | 任務 | 說明 |",
     "|---|---|---|---|---|",
     ($d.modules[] | .id as $mid
       | "| \(.status | light) \(.status | word) | \(.name | cell)（`\(.id)`）\(if .declared then "" else "（模組表沒有）" end) | \(if (.paths | length) > 0 then (.paths | map("`\(.)`") | join(", ")) else "—" end) | \(if (.tasks | length) > 0 then ([$d.tasks[] | select(.modules | index($mid)) | "\(.id) \(.status)"] | .[:6] | join(" ・ ")) + (if (.tasks | length) > 6 then " …" else "" end) else "—" end)\(if .counts.archivedDone > 0 then "（另 \(.counts.archivedDone) 個已歸檔完成）" else "" end) | \(.statusReason | cell)\(.mismatch | map(" ・ \(.task) \(if .kind == "touched-not-declared" then "改到這裡但 WBS 沒標" else "WBS 標了但沒改到" end)") | join("")) |"))
  end),
  (if ($d.unmappedTasks | length) > 0 then ("", "沒有對到模組的任務：\($d.unmappedTasks | join("、"))") else empty end),
  (if ($d.archived.unmapped // 0) > 0 then ("", "已歸檔的完成任務有 \($d.archived.unmapped) 個沒有標模組（歸檔時還沒有模組欄），不算進任何模組") else empty end),
  # 五類都是 0 時整節不出現；每類列數量與前 10 項
  (($d.drift // {}) | [to_entries[] | select((.value | length) > 0)] as $ds
   | if ($ds | length) == 0 then empty
     else ("", "## 落差", "",
           ($ds[] | .key as $k
            | "- **\($k | dname)** \(.value | length) 項（→ \($k | dnext)）：\(.value[:10] | map(ditem($k)) | join("、"))\(if (.value | length) > 10 then " 等" else "" end)"))
     end),
  "",
  "## 任務圖",
  "",
  (if ($d.plans | length) == 0 then "（plans/ 底下沒有進行中的計畫）" else
    ($d.plans[]
     | "### \(if .task then "\(.task) " else "" end)\(.title | cell)（`\(.file)`）\(.status | sub("\\s.*$"; ""))",
       "",
       (.verify | vline | ., ""),
       (if .base then "比較基準：`\(.base)`" else "比較基準：找不到（列不出改了哪些檔）" end),
       "",
       taskgraph,
       "",
       ptable,
       "")
  end)
] | join("\n")
JQ

# plan 的「計畫 vs 實際」區塊（--actual）
IFS= read -r -d '' JQ_ACTUAL <<'JQ'
[.plans[] | select(.source == $src and .file == $file)] | first // error("data.js 裡找不到這份 plan")
| [
  "<!-- overview:actual:start — 由 /verify 經 overview.sh --actual 寫入，勿手改 -->",
  "## 計畫 vs 實際",
  "",
  (.verify | vline),
  "",
  (if (.parts | length) > 0 then (taskgraph, "") else empty end),
  "### 這次 AI 改了什麼",
  "",
  ptable,
  "",
  (if .base then "比較基準：`\(.base)`（AI 摘要取自執行帳本；帳本沒寫的顯示 —）" else "找不到比較基準（帳本沒有 BASE=，也找不到預設分支），列不出改了哪些檔" end),
  "<!-- overview:actual:end -->"
] | join("\n")
JQ

# 架構文件自動段（--sync-arch，ADR-007 第 1 點、提案 7.2）：一行說明、mermaid（每個分組一個 subgraph，
# 邊取程式碼的 import 與 http；超過 60 條只畫跨分組的）、模組表。只看主 checkout（md.json）
IFS= read -r -d '' JQ_ARCH <<'JQ'
. as $d
| ($d.modules | to_entries | map({key: .value.id,
    value: (if (.value.id | test("^[A-Za-z0-9_-]+$")) and (.value.id as $i | RESERVED | index($i) | not)
            then .value.id else "m\(.key + 1)" end)}) | from_entries) as $sid
| ($d.modules | map({key: .id, value: .group}) | from_entries) as $G
| ($d.groups | map({key: .id, value: .label}) | from_entries) as $GL
| ([($d.codeEdges // [])[] | select($sid[.from] != null and $sid[.to] != null)]) as $E
| (if ($E | length) > 60 then [$E[] | select($G[.from] != $G[.to])] else $E end) as $E2
| [
  "（此段由專案地圖產生，手改會被覆蓋。改模組名稱或分組請改 `.claude/taskmaster-data/module-notes.md`）",
  "",
  (if ($d.modules | length) == 0 then "（沒有掃到模組）" else
    ("```mermaid",
     "flowchart LR",
     ($d.groups | to_entries[] | .key as $gi | .value as $g | [$d.modules[] | select(.group == $g.id)] as $ms
       | select(($ms | length) > 0)
       | "  subgraph sg\($gi + 1)[\"\($g.label | lab)\"]", ($ms[] | "    \($sid[.id])[\"\(.name | lab)\"]"), "  end"),
     ($E2[] | "  \($sid[.from]) -->\(if .source == "http" then "|HTTP|" else "" end) \($sid[.to])"),
     "```",
     (if ($E | length) > 60 then ("", "依賴線共 \($E | length) 條，超過 60 條只畫跨分組的 \($E2 | length) 條。") else empty end))
  end),
  "",
  "| id | 模組 | 分組 | 路徑 | 檔數 | 路由數 | 說明 |",
  "|---|---|---|---|---|---|---|",
  ($d.modules[] | "| \(.id) | \(.name | cell) | \(($GL[.group] // .group) | cell) | \(if (.paths | length) > 0 then (.paths | map("`\(.)`") | join(", ")) else "—" end) | \(.fileCount // 0) | \(.routes.count // 0) | \((.description.text // .responsibility // "") | if . == "" then "—" else cell end) |")
] | join("\n")
JQ

# 換掉架構文件兩個標記之間的內容。整份讀成一筆（RS 用不會出現的 \001），用 index 找行首的標記，
# 標記外原樣 printf 回去——檔尾有沒有換行、CRLF 都保留；標記區用文件 start 那一行的換行。
# exit 3＝沒有標記；4＝不成對（stderr 說明）。
# BINMODE=3（呼叫端也用 -v 給）：Git Bash 的 gawk 預設讀檔就把 CRLF 的 CR 吃掉，寫回去整份變 LF；
# mawk 沒有這個變數，當一般變數無害。區塊要先用預設的 RS 逐行讀完才換 RS，否則整份 gen.md 會變成一筆
IFS= read -r -d '' AWK_SPLICE_GEN <<'AWK'
BEGIN {
    BINMODE = 3
    while ((getline l < blk) > 0) { sub(/\r$/, "", l); B[++nb] = l }
    close(blk)
    RS = "\001"
}
{ s = NR > 1 ? s RS $0 : $0 }
END {
    t = "\n" s; ns = 0; ne = 0
    for (p = 1; (i = index(substr(t, p), "\n" S)) > 0; p += i) { ns++; if (ns == 1) sp = p + i - 1 }
    for (p = 1; (i = index(substr(t, p), "\n" E)) > 0; p += i) { ne++; if (ne == 1) ep = p + i - 1 }
    if (ns == 0 && ne == 0) exit 3
    if (ns != 1 || ne != 1 || ep < sp) { printf "start %d 個、end %d 個%s", ns, ne, (ns == 1 && ne == 1 ? "（end 在 start 前）" : "") > "/dev/stderr"; exit 4 }
    j = index(substr(s, sp), "\n")
    if (j == 0) { printf "start 標記後面沒有換行" > "/dev/stderr"; exit 4 }
    head = substr(s, 1, sp + j - 1)
    nl = substr(s, sp + j - 2, 1) == "\r" ? "\r\n" : "\n"
    printf "%s", head
    for (k = 1; k <= nb; k++) printf "%s%s", B[k], nl
    printf "%s", substr(s, ep)
}
AWK

# 把區塊換進 plan：有舊區塊就原地取代，沒有就接在檔尾。區塊外一個 byte 都不動。
# 標記在啟動時檢查過，這裡再查一次：等鎖與產生的期間 plan 可能被人改過。
splice_actual() {
    local bad
    bad=$(actual_markers_bad "$ACTUAL_PLAN")
    if [ -n "$bad" ]; then markers_msg "$bad" "$ACTUAL_PLAN" > "$OUT/.last-error"; return 1; fi
    # BINMODE=3：理由同 AWK_SPLICE_GEN（Git Bash 的 gawk 會把 CRLF 的 plan 整份改成 LF）。區塊用 plan 第一行的換行
    awk -v BINMODE=3 -v blk="$TMP/actual.md" '
        function blockout(   k) { for (k = 1; k <= nb; k++) printf "%s%s", B[k], nl }
        BEGIN { BINMODE = 3; nl = "\n"; while ((getline l < blk) > 0) { sub(/\r$/, "", l); B[++nb] = l } }
        NR == 1 && /\r$/ { nl = "\r\n" }
        /^<!-- overview:actual:start/ { blockout(); done = 1; skip = 1; next }
        skip && /^<!-- overview:actual:end/ { skip = 0; next }
        skip { next }
        { print; last = $0 }
        END { if (!done) { if (NR > 0 && last != "" && last != "\r") printf "%s", nl; blockout() } }
    ' "$ACTUAL_PLAN" > "$TMP/plan.md" && mv -f "$TMP/plan.md" "$ACTUAL_PLAN"
}

# --sync-arch：用這一輪產生的 md.json（主 checkout 的資料）寫架構文件的自動段。寫入走「暫存檔＋mv」，
# 內容沒變就不動檔（mtime 也不變）。只在主 checkout 寫：worktree 裡的架構文件會隨分支合回來，兩邊各寫會衝突
sync_arch() {
    local a rc why
    if [ "$SYNC_IN_WT" = 1 ]; then
        echo "overview.sh --sync-arch：只在主 checkout 改寫架構文件（目前在 worktree），這次沒有寫"
        return 0
    fi
    a=$(find_arch)
    if [ -z "$a" ]; then echo "overview.sh --sync-arch：沒有架構文件，略過自動段"; return 0; fi
    if ! ( cd "$TMP" && LC_ALL=C.UTF-8 jq -r -f arch.jq md.json > gen.md 2> err ); then
        echo "overview.sh --sync-arch：自動段產生失敗（arch.jq）：$(cat "$TMP/err")" >&2
        return 1
    fi
    ( cd "$TMP" && LC_ALL=C awk -v BINMODE=3 -v blk=gen.md -v S="$OVERVIEW_GEN_START" -v E="$OVERVIEW_GEN_END" \
          "$AWK_SPLICE_GEN" "$MAIN_ROOT/$a" > arch.new 2> err ); rc=$?
    case $rc in
        0)  if cmp -s "$TMP/arch.new" "$MAIN_ROOT/$a"; then
                echo "架構文件自動段已是最新：$a"
            else
                mv -f "$TMP/arch.new" "$MAIN_ROOT/$a" && echo "已更新架構文件自動段：$a"
            fi ;;
        3)  echo "$a 沒有自動段標記（$OVERVIEW_GEN_START／$OVERVIEW_GEN_END），沒有寫入；標記放在哪見 05 範本第 4 節" ;;
        *)  why=$(cat "$TMP/err" 2>/dev/null)
            echo "overview.sh --sync-arch：$a 的自動段標記不成對（${why:-awk 失敗}），整份沒有寫入。修法：只留一組 $OVERVIEW_GEN_START 與 $OVERVIEW_GEN_END（start 在前、各占一行），或兩行都刪掉" >&2
            return 1 ;;
    esac
}

# data.js 超過上限就照 JQ_SHRINK 的順序一級一級丟，直到放得下（都丟完仍超過就照寫，另加一則「仍超過上限」）。
# 常態只多一次 wc：放得下就什麼都不做。80 是 data.js 外殼（註解行＋賦值）的位元組數。
shrink_data() {
    local level size
    size=$(wc -c < "$TMP/data.json")
    [ $((size + 80)) -le "$MAX_BYTES" ] && return 0
    cp -f "$TMP/data.json" "$TMP/view.json"
    for level in 0 1 2 3 4 5 6 8 7; do
        ( cd "$TMP" && LC_ALL=C.UTF-8 jq -c --argjson level "$level" --argjson kb $((MAX_BYTES / 1024)) \
            -f shrink.jq view.json > shrunk.json 2> err ) || return 1
        mv -f "$TMP/shrunk.json" "$TMP/view.json"
        size=$(wc -c < "$TMP/view.json")
        [ $((size + 80)) -le "$MAX_BYTES" ] && break
    done
    IFS= read -r DATA_LINE < "$TMP/view.json"
}

run_once() {
    # 全部在 TMP 產好才搬：任一步失敗都保留上一份 data.js／overview.md（畫面照常顯示舊資料），
    # 錯誤留在 .last-error 供除錯。先搬 data.js 再算 md 的話，md 失敗時兩份會不同步。
    if ! generate; then cp -f "$TMP/err" "$OUT/.last-error" 2>/dev/null; return 1; fi
    if ! ( cd "$TMP" && LC_ALL=C.UTF-8 jq -r -f md.jq md.json > overview.md 2> err ); then
        { echo "overview.md 產生失敗（md.jq）："; cat "$TMP/err"; } > "$OUT/.last-error" 2>/dev/null
        return 1
    fi
    if [ -n "$ACTUAL_PLAN" ]; then
        if ! ( cd "$TMP" && LC_ALL=C.UTF-8 jq -r --arg src "$ACTUAL_SRC" --arg file "plans/$ACTUAL_NAME" \
                 -f actual.jq data.json > actual.md 2> err ) || [ ! -s "$TMP/actual.md" ]; then
            { echo "「計畫 vs 實際」產生失敗（actual.jq）："; cat "$TMP/err"; } > "$OUT/.last-error" 2>/dev/null
            return 1
        fi
        splice_actual || return 1
    fi
    if ! shrink_data; then
        { echo "大小上限處理失敗（shrink.jq）："; cat "$TMP/err"; } > "$OUT/.last-error" 2>/dev/null
        return 1
    fi
    rm -f "$OUT/.last-error" 2>/dev/null
    {
        printf '// 給瀏覽器讀的資料，模型不要讀——要狀態請讀 wbs.md\n'
        # 必須是單一一句賦值：畫面在載入前把 window.OVERVIEW 設成 null、載入後仍是 null 就當作
        # 讀到寫一半的檔。拆成多句的話，半份檔案可能已執行前幾句，畫面會半新半舊。
        printf 'window.OVERVIEW = %s;\n' "$DATA_LINE"
    } > "$TMP/data.js" && mv -f "$TMP/data.js" "$OUT/data.js"

    cmp -s "$TMP/overview.md" "$OUT/overview.md" || mv -f "$TMP/overview.md" "$OUT/overview.md"

    copy_page
    return 0
}

printf '%s\n%s\n' "$JQ_ROLLUP" "$JQ_MAIN" > "$TMP/overview.jq"
printf '%s\n%s\n' "$JQ_ROLLUP" "$JQ_SHRINK" > "$TMP/shrink.jq"
printf '%s\n%s\n' "$JQ_MDDEFS" "$JQ_MD" > "$TMP/md.jq"
printf '%s\n%s\n' "$JQ_MDDEFS" "$JQ_ACTUAL" > "$TMP/actual.jq"
printf '%s\n%s\n' "$JQ_MDDEFS" "$JQ_ARCH" > "$TMP/arch.jq"

# --check-notes／--notes-todo：讀寫入的那個 checkout 的 notes（worktree 裡寫的就驗 worktree 那份），沒有才讀主 checkout 的。
# 骨架與模組歸屬一律是主 checkout 的
if [ -n "$NOTES_MODE" ]; then
    NOTES_ROOT=$MAIN_ROOT NOTES_FILE="$DATA/module-notes.md"
    if [ -f "$WORK_ROOT/.claude/taskmaster-data/module-notes.md" ]; then
        NOTES_ROOT=$(cd "$WORK_ROOT" && pwd) && NOTES_FILE="$NOTES_ROOT/.claude/taskmaster-data/module-notes.md"
    fi
    if [ "$NOTES_MODE" = check ]; then
        [ -f "$NOTES_FILE" ] || exit 0
    elif [ "$NOTES_OFF" -eq 1 ]; then
        echo "overview.sh --notes-todo：project.json 的 overview.notes 是 off，說明層關閉中" >&2
        exit 0
    fi
    [ -f "$OUT/skeleton.json" ] || [ "$IS_DEMO" -eq 1 ] || bash "${BASH_SOURCE[0]}" "$WORK_ROOT" >/dev/null 2>&1
    if ! generate "$NOTES_MODE"; then
        printf 'overview.sh --%s：執行失敗：%s\n' "$([ "$NOTES_MODE" = check ] && echo check-notes || echo notes-todo)" "$(cat "$TMP/err" 2>/dev/null)" >&2
        exit 2
    fi
    [ -s "$TMP/out.json" ] || exit 0
    cat "$TMP/out.json"
    [ "$NOTES_MODE" = check ] && exit 1
    exit 0
fi

RC=0 SYNC_RC=0
for _ in 1 2 3; do
    rm -f "$OUT/.dirty" 2>/dev/null
    if ! run_once; then RC=1; break; fi
    if [ -n "$ACTUAL_PLAN" ]; then
        printf '已寫入「計畫 vs 實際」（%s）：%s\n' "$ACTUAL_RESULT" "$ACTUAL_PLAN"
        ACTUAL_PLAN="" ACTUAL_SRC="" ACTUAL_NAME="" ACTUAL_RESULT="" ACTUAL_REASON=""
    fi
    if [ "$SYNC_ARCH" -eq 1 ]; then
        sync_arch || SYNC_RC=1
        SYNC_ARCH=0
    fi
    [ -f "$OUT/.dirty" ] || break
done
# --actual 失敗要讓 /verify 知道；背景重產失敗只留 .last-error、照舊 exit 0
if [ "$RC" -ne 0 ] && [ -n "$ACTUAL_PLAN" ]; then
    { echo "overview.sh --actual：沒有寫入，原因："; cat "$OUT/.last-error" 2>/dev/null; } >&2
    exit 1
fi
if [ "$RC" -ne 0 ] && [ "$SYNC_ARCH" -eq 1 ]; then
    { echo "overview.sh --sync-arch：重產失敗，沒有同步架構文件，原因："; cat "$OUT/.last-error" 2>/dev/null; } >&2
    exit 1
fi
[ "$SYNC_RC" -eq 0 ] || exit 1
exit 0
