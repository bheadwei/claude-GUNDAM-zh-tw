#!/usr/bin/env bash
# sync-ui-sources.sh — 比對 .claude/ui/ 的風格檔與上游，預設只預覽
#
# 只給模板維護者用：copy-template／update-template（sh 與 ps1 四份）都把它排除在新專案之外。
#
# 用法：
#   bash scripts/sync-ui-sources.sh                          # 預覽四種清單，不寫任何檔
#   bash scripts/sync-ui-sources.sh --source voltagent       # 只看一個來源
#   bash scripts/sync-ui-sources.sh --apply                  # 只更新「上游有更新」且本地沒改過的
#   bash scripts/sync-ui-sources.sh --import jp:ippodo       # 明確匯入一份（一次一份）
#   bash scripts/sync-ui-sources.sh --upstream-dir <路徑>    # 用本機目錄當上游（測試用，不連網）
#
# --upstream-dir 的目錄結構：<路徑>/<來源 id>/ 等同該上游 repo 的根目錄；
# 可放一個 <路徑>/<來源 id>/.upstream-commit 檔指定 commit 字串。
#
# 資料定義的唯一來源是 .claude/ui/_sources.json 的 notes，本檔不重述。這裡只寫判斷規則：
#   - 本地有沒有改過 ＝ 目前 DESIGN.md 的 sha256 ≠ SOURCE.json 的 imported_sha256
#     （不信 locally_modified：那是「匯入時和上游差多少」，不是「匯入後有沒有再改」）
#   - 比對與覆蓋一律以整份檔案為單位（上游新格式把色碼放在檔頭 YAML，只比內文會漏）
#   - 沒有上游的來源（repo 為 null，例如 self-extracted）整個跳過
#
# 退出碼：0 = 正常；1 = 用法或資料錯誤；2 = 缺必要工具（gh、jq）

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI_DIR="$ROOT/.claude/ui"
SOURCES_JSON="$UI_DIR/_sources.json"
TODAY="$(date +%Y-%m-%d)"

MODE="preview"
ONLY_SOURCE=""
IMPORT_SPEC=""
UPSTREAM_DIR=""

usage() {
    sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --apply)        MODE="apply"; shift ;;
        --source)       ONLY_SOURCE="${2:-}"; [ -n "$ONLY_SOURCE" ] || { echo "--source 需要來源 id" >&2; exit 1; }; shift 2 ;;
        --import)       MODE="import"; IMPORT_SPEC="${2:-}"; [ -n "$IMPORT_SPEC" ] || { echo "--import 需要 <來源>:<上游 id>" >&2; exit 1; }; shift 2 ;;
        --upstream-dir) UPSTREAM_DIR="${2:-}"; [ -d "$UPSTREAM_DIR" ] || { echo "--upstream-dir 不是目錄：${2:-}" >&2; exit 1; }; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo "未知選項: $1" >&2; usage >&2; exit 1 ;;
    esac
done

command -v jq >/dev/null 2>&1 || { echo "需要 jq（讀寫 _sources.json／SOURCE.json）" >&2; exit 2; }
if [ -z "$UPSTREAM_DIR" ] && ! command -v gh >/dev/null 2>&1; then
    echo "需要 gh（GitHub CLI）才能抓上游。安裝並 gh auth login 後重試，或用 --upstream-dir 指定本機目錄" >&2
    exit 2
fi
[ -f "$SOURCES_JSON" ] || { echo "找不到 $SOURCES_JSON" >&2; exit 1; }

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
    else shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# Windows 原生 jq 可能輸出 CRLF；比對前一律去掉 \r
jqr() { jq -r "$@" | tr -d '\r'; }

src_field() {  # $1=來源 id $2=欄位
    jqr --arg id "$1" --arg f "$2" '.sources[] | select(.id == $id) | .[$f] // empty' "$SOURCES_JSON"
}

json_set() {  # $1=檔案，其餘為 jq 參數與表達式；寫到暫存檔再搬，避免半寫入
    local file="$1"; shift
    local tmp="$file.tmp.$$"
    jq "$@" "$file" > "$tmp" && mv "$tmp" "$file"
}

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# 把一個來源的上游內容準備成目錄，印出「<目錄>\t<commit>」。失敗回傳非 0。
# 走 gh 時固定在當下解析出的 commit 下載 tarball，解到 repo 外的暫存目錄，只解 DESIGN.md。
fetch_upstream() {
    local id="$1" repo ref pattern dir commit
    repo="$(src_field "$id" repo)"
    ref="$(src_field "$id" ref)"
    pattern="$(src_field "$id" path_pattern)"
    if [ -n "$UPSTREAM_DIR" ]; then
        dir="$UPSTREAM_DIR/$id"
        [ -d "$dir" ] || { echo "  （--upstream-dir 底下沒有 $id/，略過這個來源）" >&2; return 1; }
        commit="upstream-dir"
        [ -f "$dir/.upstream-commit" ] && commit="$(tr -d '\r\n' < "$dir/.upstream-commit")"
        printf '%s\t%s\n' "$dir" "$commit"
        return 0
    fi
    commit="$(gh api "repos/$repo/commits/${ref:-HEAD}" --jq .sha 2>/dev/null | tr -d '\r')" || commit=""
    [ -n "$commit" ] || { echo "  （gh api 查不到 $repo 的 ${ref:-HEAD}，略過這個來源）" >&2; return 1; }
    dir="$TMP_ROOT/$id"
    mkdir -p "$dir"
    gh api "repos/$repo/tarball/$commit" > "$TMP_ROOT/$id.tar.gz" 2>/dev/null \
        || { echo "  （下載 $repo@$commit 失敗，略過這個來源）" >&2; return 1; }
    # --force-local：Windows 路徑的 C: 不要被 tar 當成遠端主機
    tar --force-local -xzf "$TMP_ROOT/$id.tar.gz" -C "$dir" --strip-components=1 \
        --wildcards "*/${pattern//\{id\}/*}" 2>/dev/null \
        || { echo "  （解開 $repo@$commit 失敗，略過這個來源）" >&2; return 1; }
    printf '%s\t%s\n' "$dir" "$commit"
}

# 列出上游目錄裡符合 path_pattern 的所有 id
list_upstream_ids() {  # $1=上游目錄 $2=path_pattern
    local root="$1" pattern="$2" pre post f id
    pre="${pattern%%\{id\}*}"
    post="${pattern#*\{id\}}"
    for f in "$root/$pre"*"$post"; do
        [ -f "$f" ] || continue
        id="${f#"$root/$pre"}"
        id="${id%"$post"}"
        case "$id" in */*) continue ;; esac
        printf '%s\n' "$id"
    done
}

detect_format() {  # $1=檔案 $2=來源 id
    if [ "$(head -n 1 "$1" | tr -d '\r')" = "---" ]; then
        echo "google-alpha"
    else
        jqr --arg id "$2" '[.sources[] | select(.id == $id) | .format[] | select(. != "google-alpha")][0] // "unknown"' "$SOURCES_JSON"
    fi
}

detect_language() {  # 只看內容：有假名 → ja，有諺文 → ko，否則 en
    if grep -qP '[\x{3040}-\x{30FF}]' "$1" 2>/dev/null; then echo "ja"
    elif grep -qP '[\x{AC00}-\x{D7AF}]' "$1" 2>/dev/null; then echo "ko"
    else echo "en"
    fi
}

# google-alpha 格式才 lint；只提醒不擋。SYNC_UI_LINT=off 可關（測試用，lint 會連網裝套件）
maybe_lint() {  # $1=檔案 $2=顯示名
    [ "$(head -n 1 "$1" | tr -d '\r')" = "---" ] || return 0
    if [ "${SYNC_UI_LINT:-on}" = "off" ]; then
        echo "    略過 lint（SYNC_UI_LINT=off）"
    elif ! command -v npx >/dev/null 2>&1; then
        echo "    略過 lint（沒有 npx）"
    elif ! npx --yes @google/design.md lint "$1" >/dev/null 2>&1 </dev/null; then
        echo "    ⚠ lint 有錯誤：npx @google/design.md lint .claude/ui/$2/DESIGN.md"
    fi
}

warn_license() {  # $1=來源 id
    local lf
    lf="$(src_field "$1" license_file)"
    if [ -z "$lf" ]; then
        echo "  ⚠ 授權檔缺：_sources.json 的 $1 沒有 license_file。先把上游 LICENSE 原文放進 .claude/ui/_licenses/ 並登記"
    elif [ ! -f "$ROOT/$lf" ]; then
        echo "  ⚠ 授權檔缺：$lf 不存在。上游 LICENSE 原文要附（gh api 抓，不要手打）"
    fi
}

write_source_json() {  # $1=目標 $2=來源 id $3=上游路徑 $4=commit $5=格式 $6=hash $7=語言
    local repo license lf
    repo="$(src_field "$2" repo)"
    license="$(src_field "$2" license)"
    lf="$(src_field "$2" license_file)"
    jq -n --arg source "$2" --arg repo "$repo" --arg path "$3" --arg commit "$4" \
          --arg fmt "$5" --arg date "$TODAY" --arg sha "$6" --arg lic "$license" \
          --arg lf "$lf" --arg lang "$7" '{
        source: $source,
        upstream_repo: $repo,
        upstream_path: $path,
        upstream_commit: $commit,
        upstream_format: $fmt,
        upstream_status: "present",
        imported_at: $date,
        imported_sha256: $sha,
        license: (if $lic == "" then null else $lic end),
        license_file: (if $lf == "" then null else $lf end),
        locally_modified: false,
        local_changes: "",
        language: $lang,
        extraction_method: "upstream"
    }' > "$1"
}

# ============================================================================
# --import <來源>:<上游 id>
# ============================================================================
if [ "$MODE" = "import" ]; then
    case "$IMPORT_SPEC" in
        *:*) ;;
        *) echo "--import 的格式是 <來源>:<上游 id>，例如 jp:ippodo" >&2; exit 1 ;;
    esac
    src="${IMPORT_SPEC%%:*}"
    upid="${IMPORT_SPEC#*:}"
    jq -e --arg id "$src" '.sources[] | select(.id == $id)' "$SOURCES_JSON" >/dev/null \
        || { echo "_sources.json 沒有來源 $src" >&2; exit 1; }
    [ -n "$(src_field "$src" repo)" ] || { echo "來源 $src 沒有上游（repo 是 null），不能匯入" >&2; exit 1; }
    case "$upid" in ""|*/*|.*) echo "上游 id 不合法：$upid" >&2; exit 1 ;; esac

    codename="$(src_field "$src" prefix)$upid"
    dest="$UI_DIR/$codename"
    [ ! -e "$dest" ] || { echo "已經有 .claude/ui/$codename/，--import 不覆蓋。要更新請用 --apply" >&2; exit 1; }

    fetched="$(fetch_upstream "$src")" || exit 1
    updir="${fetched%%$'\t'*}"
    commit="${fetched#*$'\t'}"
    pattern="$(src_field "$src" path_pattern)"
    uppath="${pattern//\{id\}/$upid}"
    [ -f "$updir/$uppath" ] || { echo "上游 $src 沒有 $uppath" >&2; exit 1; }

    mkdir -p "$dest"
    cp "$updir/$uppath" "$dest/DESIGN.md"
    write_source_json "$dest/SOURCE.json" "$src" "$uppath" "$commit" \
        "$(detect_format "$dest/DESIGN.md" "$src")" "$(sha256 "$dest/DESIGN.md")" \
        "$(detect_language "$dest/DESIGN.md")"

    echo "✚ 已匯入 .claude/ui/$codename/（$src:$upid @ $commit）"
    maybe_lint "$dest/DESIGN.md" "$codename"
    warn_license "$src"
    echo ""
    echo "下一步（漏了 /ui-style 選不到它，check-counts 會擋）："
    echo "  1. CATALOG.md 加兩處：分類清單一行（附繁中一句話說明）＋底部分類索引"
    echo "  2. 跑 bash scripts/check-counts.sh 確認配色、字型段落抽得到"
    exit 0
fi

# ============================================================================
# 預覽／--apply
# ============================================================================
if [ -n "$ONLY_SOURCE" ]; then
    jq -e --arg id "$ONLY_SOURCE" '.sources[] | select(.id == $id)' "$SOURCES_JSON" >/dev/null \
        || { echo "_sources.json 沒有來源 $ONLY_SOURCE" >&2; exit 1; }
fi

UPDATED=(); ADDED=(); REMOVED=(); MODIFIED=(); APPLIED=()
DIFF_DIR="$TMP_ROOT/diffs"
mkdir -p "$DIFF_DIR"

# 外層迴圈讀 fd 3：迴圈內的 jq／gh／diff 不會吃掉來源清單
while IFS= read -r src <&3; do
    [ -n "$ONLY_SOURCE" ] && [ "$src" != "$ONLY_SOURCE" ] && continue
    if [ -z "$(src_field "$src" repo)" ]; then
        echo "⏭  $src：沒有上游，跳過"
        continue
    fi
    echo "▶ $src（$(src_field "$src" repo)）"
    fetched="$(fetch_upstream "$src")" || continue
    updir="${fetched%%$'\t'*}"
    commit="${fetched#*$'\t'}"
    pattern="$(src_field "$src" path_pattern)"
    echo "  上游 commit：$commit"
    warn_license "$src"

    # 一次讀完這個來源的所有 SOURCE.json、一次算完兩邊的 hash：
    # 逐檔叫 jq／sha256sum，在 Windows 上一輪預覽要好幾分鐘
    meta="$TMP_ROOT/meta-$src"
    (cd "$UI_DIR" && jq -r --arg src "$src" '
        select(.source == $src)
        | [(input_filename | gsub("\\\\"; "/") | split("/") | .[-2]),
           (.upstream_path // ""), (.upstream_status // ""), (.imported_sha256 // "")]
        | @tsv' */SOURCE.json) | tr -d '\r' > "$meta" || true
    lfiles=(); ufiles=()
    while IFS=$'\t' read -r name uppath _; do
        [ -f "$UI_DIR/$name/DESIGN.md" ] && lfiles+=("$name/DESIGN.md")
        [ -n "$uppath" ] && [ -f "$updir/$uppath" ] && ufiles+=("$uppath")
    done < "$meta"
    lsums="$TMP_ROOT/lsum-$src"; usums="$TMP_ROOT/usum-$src"
    : > "$lsums"; : > "$usums"
    if [ ${#lfiles[@]} -gt 0 ]; then (cd "$UI_DIR" && sha256sum -- "${lfiles[@]}") | tr -d '\r' > "$lsums"; fi
    if [ ${#ufiles[@]} -gt 0 ]; then (cd "$updir" && sha256sum -- "${ufiles[@]}") | tr -d '\r' > "$usums"; fi
    # 空欄位補 "-"：read 用 tab 切欄時，連續的 tab 會被併成一個
    rows="$TMP_ROOT/rows-$src"
    awk -F'\t' -v L="$lsums" -v U="$usums" '
        BEGIN {
            while ((getline line < L) > 0) lh[substr(line, 67)] = substr(line, 1, 64)
            while ((getline line < U) > 0) uh[substr(line, 67)] = substr(line, 1, 64)
        }
        function v(x) { return x == "" ? "-" : x }
        { print v($1) "\t" v($2) "\t" v($3) "\t" v($4) "\t" v(lh[$1 "/DESIGN.md"]) "\t" v(uh[$2]) }
    ' "$meta" > "$rows"

    known_paths=$'\n'"$(cut -f2 "$rows")"$'\n'
    while IFS=$'\t' read -r name uppath status base_sha local_sha up_sha; do
        case "$name" in _*) continue ;; esac
        [ "$uppath" != "-" ] || continue
        sj="$UI_DIR/$name/SOURCE.json"
        local_md="$UI_DIR/$name/DESIGN.md"
        upfile="$updir/$uppath"

        if [ "$up_sha" = "-" ]; then
            [ "$status" = "removed" ] && continue
            REMOVED+=("$name")
            if [ "$MODE" = "apply" ]; then
                json_set "$sj" '.upstream_status = "removed"'
                APPLIED+=("$name：upstream_status → removed（本地檔保留）")
            fi
            continue
        fi

        [ "$local_sha" != "-" ] || { echo "  ⚠ $name 有 SOURCE.json 但沒有 DESIGN.md，略過" >&2; continue; }
        [ "$local_sha" = "$up_sha" ] && continue

        if [ "$local_sha" != "$base_sha" ]; then
            MODIFIED+=("$name")
            diff -u --label "本地 .claude/ui/$name/DESIGN.md" --label "上游 $uppath@$commit" \
                "$local_md" "$upfile" > "$DIFF_DIR/$name.diff" || true
            continue
        fi

        UPDATED+=("$name")
        if [ "$MODE" = "apply" ]; then
            cp "$upfile" "$local_md"
            json_set "$sj" --arg c "$commit" --arg s "$up_sha" --arg d "$TODAY" \
                --arg f "$(detect_format "$local_md" "$src")" '
                .upstream_commit = $c | .imported_sha256 = $s | .imported_at = $d
                | .upstream_format = $f | .upstream_status = "present"
                | .locally_modified = false | .local_changes = ""'
            APPLIED+=("$name：已更新為 $commit")
            maybe_lint "$local_md" "$name"
        fi
    done < "$rows"

    prefix="$(src_field "$src" prefix)"
    while IFS= read -r upid; do
        uppath="${pattern//\{id\}/$upid}"
        case "$known_paths" in *$'\n'"$uppath"$'\n'*) continue ;; esac
        note=""
        [ -e "$UI_DIR/$prefix$upid" ] && note="（本地已有同名目錄、來源不同，不能直接匯入）"
        ADDED+=("$prefix$upid ← $src:$upid$note")
    done < <(list_upstream_ids "$updir" "$pattern")

    if [ "$MODE" = "apply" ]; then
        json_set "$SOURCES_JSON" --arg id "$src" --arg d "$TODAY" \
            '(.sources[] | select(.id == $id) | .last_synced) = $d'
        APPLIED+=("_sources.json：$src.last_synced → $TODAY")
    fi
done 3< <(jqr '.sources[].id' "$SOURCES_JSON")

print_list() {  # $1=標題 $2=說明，其餘為項目
    local title="$1" hint="$2"; shift 2
    echo ""
    echo "■ $title（$#）$hint"
    [ $# -eq 0 ] && { echo "  （無）"; return 0; }
    local item
    for item in "$@"; do echo "  - $item"; done
}

print_list "上游有更新" "——本地沒改過，--apply 會覆蓋" ${UPDATED[@]+"${UPDATED[@]}"}
print_list "上游新增" "——--apply 不會加；要收就 --import <來源>:<上游 id>" ${ADDED[@]+"${ADDED[@]}"}
print_list "上游已刪除" "——--apply 只標 upstream_status: removed，不刪本地檔" ${REMOVED[@]+"${REMOVED[@]}"}
print_list "本地已修改" "——hash 和 imported_sha256 不同，任何模式都不覆蓋；差異如下" ${MODIFIED[@]+"${MODIFIED[@]}"}
for name in ${MODIFIED[@]+"${MODIFIED[@]}"}; do
    echo ""
    echo "  ── $name ──"
    sed 's/^/    /' "$DIFF_DIR/$name.diff"
done

echo ""
if [ "$MODE" = "apply" ]; then
    echo "✅ --apply 完成，寫入 ${#APPLIED[@]} 項："
    for a in ${APPLIED[@]+"${APPLIED[@]}"}; do echo "  - $a"; done
    echo "   跑 bash scripts/check-counts.sh 確認新內容的配色、字型段落抽得到"
else
    echo "（預覽模式，沒有寫入任何檔。確認後加 --apply）"
fi
