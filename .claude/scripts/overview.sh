#!/bin/bash
# overview.sh — 專案圖解產生器（專案地圖）
#
# 讀人寫的 md（架構文件 5.1 容器圖＋5.5 模組表、wbs.md、project.json）與 git 狀態，
# 產生兩份衍生物。md 才是正本，這兩份隨時可以刪掉重產：
#
#   .claude/taskmaster-data/overview.md        進 git。確定性輸出：輸入沒變就 byte 相同，
#                                              所以不含時間戳、不含「本次」與未 commit 的改動
#   .claude/taskmaster-data/overview/data.js   不進 git（資料夾裡的 .gitignore 是 `*`）。
#                                              給 overview/index.html 讀，含時間戳與本次改動
#
# 這支**不寫**任何模型會 Edit 的檔（wbs、plan、架構文件）：背景改那些檔會讓模型下一次
# Edit 因「讀取後被改過」而失敗。
#
# 主 checkout 用 git common dir 自己算，不信 CLAUDE_PROJECT_DIR：`claude -w` 開的 session 裡
# 它指向 worktree（2026-11-04 實測），用它會把 overview 寫進 worktree。
#
# 用法：
#   bash .claude/scripts/overview.sh [<工作目錄>]                重產，不輸出任何東西
#   bash .claude/scripts/overview.sh --print-path [<工作目錄>]   只印 index.html 的 file:// 路徑
#
# 沒有 taskmaster-data/project.json（模板 repo 本身、還沒 /task-init 的專案）一律 exit 0、不建任何檔。
# 逃生門：OVERVIEW=off

# 欄名常數。check-counts.sh 會比對它們與 05 範本 5.5、wbs.template.md 的表頭；
# 改那兩份範本的欄名時同步這裡，否則這支會靜默抽不到東西。
OVERVIEW_COLS_MODULE="id 路徑"          # 05 範本 5.5 模組表的必要欄
OVERVIEW_COLS_MODULE_OPT="模組 職責"    # 05 範本 5.5 模組表的選用欄（顯示名稱、職責）
OVERVIEW_COLS_WBS="# 任務 狀態"         # wbs.template.md 任務表的必要欄
OVERVIEW_COL_WBS="模組"                 # wbs.template.md 任務表的模組欄

DRAFT_MARK='<!-- overview: draft -->'
LOCK_STALE_SEC=60
MAX_CHANGES=200

[ "${OVERVIEW:-on}" = "off" ] && exit 0

PRINT_PATH=0
if [ "${1:-}" = "--print-path" ]; then PRINT_PATH=1; shift; fi
WORK_ROOT="${1:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

MAIN_ROOT=""
GCD=$(git -C "$WORK_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$GCD" ] && MAIN_ROOT=$(cd "$GCD/.." 2>/dev/null && pwd)
[ -n "$MAIN_ROOT" ] || MAIN_ROOT=$(cd "$WORK_ROOT" 2>/dev/null && pwd)
[ -n "$MAIN_ROOT" ] || exit 0

DATA="$MAIN_ROOT/.claude/taskmaster-data"
OUT="$DATA/overview"
[ -f "$DATA/project.json" ] || exit 0

if [ "$PRINT_PATH" -eq 1 ]; then
    p="$OUT/index.html"
    command -v cygpath >/dev/null 2>&1 && p=$(cygpath -m "$p")
    printf 'file:///%s\n' "${p#/}"
    exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0
mkdir -p "$OUT" 2>/dev/null || exit 0
[ -f "$OUT/.gitignore" ] || printf '*\n' > "$OUT/.gitignore"

# ---------------------------------------------------------------- 鎖
#
# 每次寫 wbs／plan 都會觸發，連續寫幾次就會有幾支同時跑。拿不到鎖的那支只留下 .dirty
# 就走，由持鎖者做完後再跑一輪——不排隊、不丟更新。
# 當掉的前一次會留下鎖，超過 LOCK_STALE_SEC 秒視為過期並接手。
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
if ! take_lock; then
    : > "$OUT/.dirty" 2>/dev/null
    exit 0
fi
date +%s > "$LOCK/at" 2>/dev/null
TMP="$OUT/.tmp-$$"
mkdir -p "$TMP" 2>/dev/null
trap 'rm -rf "$LOCK" "$TMP" 2>/dev/null' EXIT

# ---------------------------------------------------------------- 輸入

# 架構文件：project.json 的 overview.architectureDoc（選填覆寫）→ docs/*architecture*.md → docs/tech-spec.md
find_arch() {
    local f
    f=$(jq -r '.overview.architectureDoc // empty' "$DATA/project.json" 2>/dev/null | tr -d '\r')
    if [ -n "$f" ] && [ -f "$MAIN_ROOT/$f" ]; then echo "$f"; return; fi
    for f in "$MAIN_ROOT"/docs/*architecture*.md; do
        [ -f "$f" ] && { echo "${f#"$MAIN_ROOT"/}"; return; }
    done
    [ -f "$MAIN_ROOT/docs/tech-spec.md" ] && echo "docs/tech-spec.md"
}

# 本次改動：分支上已 commit 的＋工作區未 commit 的＋未追蹤的新檔。
# 比較基準：站在預設分支上 → HEAD（只看未 commit 的）；站在 topic 分支 → 與預設分支的 merge-base。
# 輸出 TSV：<added>\t<removed>\t<path>；未追蹤的新檔 added 帶 `+` 前綴。.claude/ 底下不算。
collect_changes() {
    local g=(git -C "$MAIN_ROOT" -c core.quotePath=false)
    "${g[@]}" rev-parse -q --verify HEAD >/dev/null 2>&1 || return 0
    local def cur base=HEAD
    def=$("${g[@]}" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
    if [ -z "$def" ]; then
        for b in main master; do
            "${g[@]}" show-ref -q --verify "refs/heads/$b" && { def=$b; break; }
        done
    fi
    cur=$("${g[@]}" symbolic-ref -q --short HEAD 2>/dev/null)
    if [ -n "$def" ] && [ -n "$cur" ] && [ "$cur" != "${def#origin/}" ]; then
        base=$("${g[@]}" merge-base HEAD "$def" 2>/dev/null) || base=HEAD
        [ -n "$base" ] || base=HEAD
    fi
    printf '%s\n' "$("${g[@]}" rev-parse --short "$base" 2>/dev/null)" > "$TMP/base"
    printf '%s\n' "${def:-}" >> "$TMP/base"
    "${g[@]}" diff --numstat --no-renames "$base" -- . ':(exclude).claude' 2>/dev/null
    # 新檔沒有 numstat：用一支 awk 數行數（逐檔開 wc 在 Windows 每個要上百毫秒）；空檔記 0
    "${g[@]}" ls-files -z --others --exclude-standard -- . ':(exclude).claude' 2>/dev/null \
        | head -z -n "$MAX_CHANGES" \
        | ( cd "$MAIN_ROOT" && xargs -0 -r awk 'BEGIN { for (i = 1; i < ARGC; i++) seen[ARGV[i]] = 1 }
              { n[FILENAME]++ } END { for (f in seen) printf "+%d\t0\t%s\n", n[f], f }' 2>/dev/null )
}

# ---------------------------------------------------------------- 產生

generate() {
    local arch_rel arch_file wbs_file cur_task now
    : > "$TMP/empty"
    arch_rel=$(find_arch)
    arch_file="$TMP/empty"; [ -n "$arch_rel" ] && arch_file="$MAIN_ROOT/$arch_rel"
    wbs_file="$TMP/empty"; [ -f "$DATA/wbs.md" ] && wbs_file="$DATA/wbs.md"
    cur_task=$(tr -d '[:space:]' < "$DATA/.current-task" 2>/dev/null)
    : > "$TMP/base"
    collect_changes | head -n $((MAX_CHANGES * 2)) > "$TMP/changes.tsv"
    now=$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')

    # 一支 jq 算完全部：資料是 data.js 的物件，overview.md 再由第二支 jq 從同一份物件產出，
    # 兩份圖不可能各說各話。
    LC_ALL=C.UTF-8 jq -n -c \
        --rawfile arch "$arch_file" --arg archPath "$arch_rel" \
        --rawfile wbs "$wbs_file" \
        --slurpfile proj "$DATA/project.json" \
        --rawfile changes "$TMP/changes.tsv" --rawfile base "$TMP/base" \
        --arg current "$cur_task" --arg now "$now" --arg draftMark "$DRAFT_MARK" \
        --arg colsMod "$OVERVIEW_COLS_MODULE" --arg colsModOpt "$OVERVIEW_COLS_MODULE_OPT" \
        --arg colsWbs "$OVERVIEW_COLS_WBS" --arg colWbs "$OVERVIEW_COL_WBS" \
        --argjson maxChanges "$MAX_CHANGES" \
        -f "$TMP/overview.jq" > "$TMP/data.json" 2>"$TMP/err" && [ -s "$TMP/data.json" ]
}

# jq 程式與 bash 放在同一檔，用 heredoc 落到暫存檔再 jq -f（避免拆成兩個要一起改的檔）
write_jq() {
cat > "$TMP/overview.jq" <<'JQ'
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
             else ($r | sub("^[\\[\\(\\{>/\\\\]+"; "") | sub("[\\]\\)\\}/\\\\]+$"; "") | unq) end),
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
         | .groups += [{id: $sg.id, label: ($sg.lab | unq)}] | .stack += [$sg.id]
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

# 燈號規則唯一來源：.claude/templates/wbs.template.md 第 3 節「里程碑狀態」
def modstatus:
  . as $s
  | if ($s | length) == 0 then "todo"
    elif all($s[]; . == "done" or . == "skip") and any($s[]; . == "done") then "done"
    elif any($s[]; . == "wip") or any($s[]; . == "done") then "wip"
    elif any($s[]; . == "blocked") then "issue"
    else "todo" end;

($proj[0] // {}) as $p
| ($colsMod | words) as $needMod
| ($colWbs) as $wcol
| ($p.mode // "none") as $mode
| ($archPath != "") as $hasArch
| ($hasArch and ($arch | contains($draftMark))) as $draft
| ($mode == "demo" or ($hasArch | not) or $draft) as $nomap

# ---- 5.5 模組表：第一張表頭同時有 id 與 路徑 的表
| (if $nomap then null else
    [$arch | tables[] | select(.header as $h | all($needMod[]; . as $c | $h | index($c)))] | first
   end) as $mt
| ([$mt // empty | .header as $h | .rows[] | rowobj($h)
    | {id: (.id | unbt), name: ((.["模組"] // "") | unbt),
       paths: ((.["路徑"] // "") | split("[,，、]"; null) | map(unbt) | map(select(blank | not))),
       responsibility: ((.["職責"] // "") | trim)}
    | select(.id | blank | not)]) as $rows

# ---- 5.1 容器圖：節點 id 與模組表重疊最多的 graph／flowchart 區塊；同分取前面的
| (if $nomap then null else
    [$arch | mermaid_blocks | to_entries[] | (.value | parse_block) as $b
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
         paths, responsibility, declared: true}]) as $mods0
| ([$mods0[].id]) as $modIds

# ---- WBS 任務：表頭有 # 任務 狀態 的表，依表頭找欄（舊節少欄也照讀）
| ($colsWbs | words) as $needWbs
| ([$wbs | tables[] | select(.header as $h | all($needWbs[]; . as $c | $h | index($c)))]) as $wt
| ([$wt[] | .h as $ms | (.header | index($wcol) != null) as $hasCol | .header as $h | .rows[] | rowobj($h)
    | select(.["#"] | unbt | blank | not)
    | (.["狀態"] | tstate) as $st
    | {id: (.["#"] | unbt), title: (.["任務"] | trim), status: ($st | temoji), state: $st,
       milestone: $ms, hasCol: $hasCol,
       modules: (if $hasCol then (.[$wcol] | split("[,，、]"; null) | map(unbt) | map(select(blank | not))) else [] end)}]) as $tasks0
| ([$tasks0[] | .modules |= map(select(. as $m | $modIds | index($m)))]) as $tasks
| ([$tasks0[] | .id as $t | .modules[] | select(. as $m | $modIds | index($m) | not) | "\($t)（\(.)）"]) as $unknownMods
| ($tasks0 | map(select(.hasCol | not)) | length) as $noColCount

# ---- 本次改動
| ($base | split("\n")) as $baseL
| ([$changes | lines[] | select(. != "") | split("\t") | select(length >= 3)
    | {file: (.[2:] | join("\t")),
       added: (.[0] | ltrimstr("+") | tonumber? // null),
       removed: (.[1] | tonumber? // null),
       new: (.[0] | startswith("+"))}]
   | unique_by(.file)) as $ch0
| ([$mods0[] | {id, res: [.paths[] | glob2re]}]) as $res
| ([$ch0[:$maxChanges][] | .file as $f
    | . + {module: ([$res[] | select(any(.res[]; . as $r | $f | test($r))) | .id] | first // null)}]) as $changesList

# ---- 模組燈號與版面
| ($mods0 | map(
    .id as $id
    | [$tasks[] | select(.modules | index($id))] as $own
    | [$own[].state] as $s
    | ($s | modstatus) as $status
    | ([$own[] | select(.state == "done")] | length) as $done
    | ([$own[] | select(.state != "skip")] | length) as $total
    | . + {status: $status,
           statusReason: (if ($own | length) == 0 then "WBS 沒有任務掛在這個模組"
             else "\($done)/\($total) 完成"
               + ([$own[] | select(.state == "wip") | .id] | if length > 0 then "；\(join("、")) 進行中" else "" end)
               + ([$own[] | select(.state == "blocked") | .id] | if length > 0 then "；\(join("、")) 阻塞" else "" end)
             end),
           counts: {done: $done, total: $total},
           tasks: [$own[].id],
           current: ($current != "" and ([$own[].id] | index($current) != null)),
           changed: ([$changesList[] | select(.module == $id)] | length)})) as $mods1

| ((($dg // {}).groups // []) | map(select(.id as $g | $mods1 | any(.group == $g)))
   + (if any($mods1[]; .group == "_ungrouped") then [{id: "_ungrouped", label: "未分組"}] else [] end)) as $groups
| ([($dg // {}).edges // [] | .[] | select(.from != .to)
    | select(.from as $a | .to as $b | ($modIds | index($a)) and ($modIds | index($b)))]
   | reduce .[] as $e ([]; if any(.[]; .from == $e.from and .to == $e.to) then . else . + [$e] end)) as $edges

# 版面由這裡決定（畫面只換算像素、節點不可拖）：群組由左到右排成欄；
# 群組內依「群組內連線」的深度再分子欄（gateway → svc-a 會排在 gateway 右邊），每欄最多 4 列
| (reduce $groups[] as $g ({col: 0, pos: {}};
    [$mods1[] | select(.group == $g.id) | .id] as $ids
    | [$edges[] | select(.from as $a | .to as $b | ($ids | index($a)) and ($ids | index($b)))] as $ie
    | (reduce range(0; $ids | length) as $_
        ([$ids[] | {key: ., value: 0}] | from_entries;
         . as $d | with_entries(.key as $k
           | .value = ([0] + [$ie[] | select(.to == $k) | $d[.from] + 1] | max | [., ($ids | length) - 1] | min)))) as $depth
    | reduce ($ids | group_by($depth[.]) | sort_by($depth[.[0]]))[] as $colIds (.;
        reduce range(0; $colIds | length) as $i (.;
          .pos[$colIds[$i]] = {col: (.col + (($i / 4) | floor)), row: ($i % 4)})
        | .col += ((($colIds | length) + 3) / 4 | floor))
   ) | .pos) as $pos
| ($mods1 | map(. + {pos: $pos[.id]})) as $mods

| ([
    (if $mode == "demo" then {level: "info", text: "demo 情境沒有架構文件，專案地圖不會出現（之後的任務圖仍可用）", action: "/docs-init --mvp"} else empty end),
    (if $mode != "demo" and ($hasArch | not) then {level: "warn", text: "找不到架構文件（docs/*architecture*.md 或 docs/tech-spec.md），畫不出專案地圖", action: "委派 documentation-specialist 從程式碼反推草稿"} else empty end),
    (if $draft then {level: "warn", text: "架構草稿待確認：\($archPath) 帶 `\($draftMark)` 標記，確認模組切分後移除標記，地圖才會出現", action: "確認後由主模型移除標記"} else empty end),
    (if ($nomap | not) and $mt == null then {level: "warn", text: "架構文件沒有含 `id`、`路徑` 欄的模組表（05 範本 5.5），模組全部顯示為灰色", action: "委派 documentation-specialist 補欄"} else empty end),
    (if ($nomap | not) and $dg == null and ($rows | length) > 0 then {level: "info", text: "架構文件沒有可解析的容器圖（5.1 mermaid），模組全部放在「未分組」", action: null} else empty end),
    ([$mods[] | select(.declared | not) | .id] | if length > 0 then {level: "warn", text: "容器圖有、模組表沒有的節點（灰色虛線）：\(join("、"))", action: "在 5.5 補上這幾列"} else empty end),
    ([$rows[] | select(.id as $i | $dgIds | index($i) | not) | .id] | if length > 0 and $dg != null then {level: "info", text: "模組表有、容器圖沒畫的模組（放在「未分組」）：\(join("、"))", action: "在 5.1 補上節點"} else empty end),
    (if ($tasks0 | length) > 0 and $noColCount == ($tasks0 | length) and ($nomap | not) then {level: "warn", text: "WBS 沒有模組欄，任務無法對到模組", action: "/task-status（會提議補欄）"}
     elif $noColCount > 0 and ($nomap | not) then {level: "warn", text: "WBS 有 \($noColCount) 個任務所在的節沒有模組欄", action: "/task-status（會提議補欄）"} else empty end),
    ($unknownMods | if length > 0 and ($nomap | not) then {level: "warn", text: "任務標了模組表沒有的模組：\(.[:8] | join("、"))", action: "改 WBS 模組欄或補架構文件 5.5"} else empty end)
  ]) as $notices

| {schema: 1,
   generatedAt: $now,
   generator: {script: "overview.sh", version: 1},
   truncated: (($ch0 | length) > $maxChanges),
   project: {name: ($p.name // "（未命名專案）"), docsMode: $mode,
             architectureDoc: (if $hasArch then $archPath else null end), architectureDraft: $draft},
   notices: $notices,
   current: (if $current != "" then {task: $current, source: "main"} else null end),
   groups: $groups,
   modules: $mods,
   edges: $edges,
   tasks: [$tasks[] | del(.hasCol)],
   unmappedTasks: [$tasks0[] | select(.modules | length == 0) | .id],
   changesBase: (if ($baseL[0] // "") != "" then {commit: $baseL[0], defaultBranch: ($baseL[1] // "")} else null end),
   changes: $changesList}
JQ
}

# overview.md：只用確定性欄位（不含 generatedAt、current、changes）
write_md_jq() {
cat > "$TMP/md.jq" <<'JQ'
def light: {done: "🟢", wip: "🟡", issue: "🔴", todo: "⚪"}[.];
def word: {done: "完成", wip: "開發中", issue: "有問題", todo: "未開始"}[.];
def lab: gsub("\""; "#quot;") | gsub("[\\[\\]]"; " ");
def cell: gsub("\\|"; "\\|") | gsub("\n"; " ");
def RESERVED: ["end", "graph", "subgraph", "style", "class", "classDef", "click", "linkStyle", "flowchart", "direction"];
. as $d
| ($d.modules | to_entries | map({key: .value.id,
    value: (if (.value.id | test("^[A-Za-z0-9_-]+$")) and (.value.id as $i | RESERVED | index($i) | not)
            then .value.id else "m\(.key + 1)" end)}) | from_entries) as $sid
| [
  "<!-- 由 .claude/scripts/overview.sh 產生，勿手改。互動版：.claude/taskmaster-data/overview/index.html -->",
  "# 專案圖解 — \($d.project.name)",
  "",
  ($d.notices[] | "> \(if .level == "warn" then "⚠️" else "ℹ️" end) \(.text)\(if .action then "（→ \(.action)）" else "" end)"),
  (if ($d.notices | length) > 0 then "" else empty end),
  "## 專案地圖",
  "",
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
       | "| \(.status | light) \(.status | word) | \(.name | cell)（`\(.id)`）\(if .declared then "" else "（模組表沒有）" end) | \(if (.paths | length) > 0 then (.paths | map("`\(.)`") | join(", ")) else "—" end) | \(if (.tasks | length) > 0 then ([$d.tasks[] | select(.modules | index($mid)) | "\(.id) \(.status)"] | .[:6] | join(" ・ ")) + (if (.tasks | length) > 6 then " …" else "" end) else "—" end) | \(.statusReason | cell) |"))
  end),
  (if ($d.unmappedTasks | length) > 0 then ("", "沒有對到模組的任務：\($d.unmappedTasks | join("、"))") else empty end)
] | join("\n")
JQ
}

run_once() {
    # 失敗時保留上一份 data.js（畫面照常顯示舊資料），錯誤留在 .last-error 供除錯
    if ! generate; then cp -f "$TMP/err" "$OUT/.last-error" 2>/dev/null; return 1; fi
    rm -f "$OUT/.last-error" 2>/dev/null
    {
        printf '// 給瀏覽器讀的資料，模型不要讀——要狀態請讀 wbs.md\n'
        # 必須是單一一句賦值：畫面在載入前把 window.OVERVIEW 設成 null、載入後仍是 null 就當作
        # 讀到寫一半的檔。拆成多句的話，半份檔案可能已執行前幾句，畫面會半新半舊。
        printf 'window.OVERVIEW = %s;\n' "$(cat "$TMP/data.json")"
    } > "$TMP/data.js" && mv -f "$TMP/data.js" "$OUT/data.js"

    LC_ALL=C.UTF-8 jq -r -f "$TMP/md.jq" "$TMP/data.json" > "$TMP/overview.md" 2>/dev/null \
        && { cmp -s "$TMP/overview.md" "$DATA/overview.md" || mv -f "$TMP/overview.md" "$DATA/overview.md"; }

    local tpl="$SCRIPT_DIR/../templates/overview/index.html"
    if [ -f "$tpl" ] && ! cmp -s "$tpl" "$OUT/index.html"; then
        cp -f "$tpl" "$TMP/index.html" && mv -f "$TMP/index.html" "$OUT/index.html"
    fi
    return 0
}

write_jq
write_md_jq
for _ in 1 2 3; do
    rm -f "$OUT/.dirty" 2>/dev/null
    run_once || break
    [ -f "$OUT/.dirty" ] || break
done
exit 0
