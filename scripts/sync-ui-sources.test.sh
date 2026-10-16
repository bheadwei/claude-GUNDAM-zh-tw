#!/usr/bin/env bash
# sync-ui-sources.test.sh — sync-ui-sources.sh 與 copy／update 排除規則的測試
#
# 全部用 --upstream-dir 假上游，不連網。每組情境在 mktemp -d 的沙箱裡跑：
# 沙箱 = 這個 repo 的 .claude/ui/ 複本 + 兩支腳本，所以真實的 SOURCE.json
# （含 claude 那份 hash 不同、semrush／self-extracted 沒有上游）都會被測到，
# 而 repo 本身一個 byte 都不動。
#
# 用法：bash scripts/sync-ui-sources.test.sh
# 退出碼：0 = 全過，1 = 有失敗

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO/scripts/sync-ui-sources.sh"
export SYNC_UI_LINT=off   # lint 會用 npx 連網裝套件

PASS=0; FAIL=0
TMP_ALL="$(mktemp -d)"
trap 'rm -rf "$TMP_ALL"' EXIT

ok()   { PASS=$((PASS + 1)); printf '  ✓ %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  ✗ %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | head -20 | sed 's/^/      /'; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

sha() { sha256sum "$1" | cut -d' ' -f1; }
tree_sum() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum) | sha256sum | cut -d' ' -f1; }

# 建一個沙箱，印出路徑。假上游 voltagent 的內容＝本地每份的現況（等於「上游沒動」），
# 再由各情境改動。
new_sandbox() {
    local sb up uppath
    sb="$(mktemp -d "$TMP_ALL/sb.XXXX")"
    mkdir -p "$sb/scripts" "$sb/.claude"
    cp "$SCRIPT" "$REPO/scripts/check-counts.sh" "$sb/scripts/"
    cp -r "$REPO/.claude/ui" "$sb/.claude/ui"
    up="$sb/upstream/voltagent"
    mkdir -p "$up"
    echo "fake0000voltagent" > "$up/.upstream-commit"
    # 一次 jq 讀完（逐檔叫 jq 在 Windows 上很慢）
    local name
    while IFS=$'\t' read -r name uppath; do
        mkdir -p "$up/${uppath%/*}"
        cp "$sb/.claude/ui/$name/DESIGN.md" "$up/$uppath"
    done < <(cd "$sb/.claude/ui" && jq -r 'select(.source == "voltagent")
        | [(input_filename | split("/") | .[0]), .upstream_path] | @tsv' */SOURCE.json | tr -d '\r')
    printf '%s\n' "$sb"
}

run() {  # $1=沙箱，其餘為參數；輸出存在 $OUT，退出碼在 $RC
    local sb="$1"; shift
    OUT="$(bash "$sb/scripts/sync-ui-sources.sh" --upstream-dir "$sb/upstream" "$@" 2>&1)"; RC=$?
}

section() {  # 從 $OUT 取出某個清單段落
    printf '%s\n' "$OUT" | awk -v t="■ $1" 'index($0, t) == 1 {on=1; next} /^■ / {on=0} /^  ── / {on=0} on'
}

echo "▶ 1. 上游有更新、本地沒動 → 預覽列出且不寫任何檔"
SB="$(new_sandbox)"
printf '\n## Extra upstream section\n' >> "$SB/upstream/voltagent/design-md/apple/DESIGN.md"
before="$(tree_sum "$SB/.claude")"
run "$SB"
check "預覽 exit 0" '[ "$RC" -eq 0 ]' "$OUT"
check "apple 列在「上游有更新」" 'section "上游有更新" | grep -qx "  - apple"' "$OUT"
check "沒有變更的項目不出現在任何清單（airbnb）" '! printf "%s\n" "$OUT" | grep -qx "  - airbnb"'
check "預覽後 .claude/ 完全沒變（含 _sources.json 的 last_synced）" '[ "$(tree_sum "$SB/.claude")" = "$before" ]'
check "self-extracted 來源被跳過、不報錯" 'printf "%s\n" "$OUT" | grep -q "self-extracted：沒有上游，跳過"'
check "semrush（沒有上游）不出現在任何清單" '! printf "%s\n" "$OUT" | grep -q "  - semrush"'
check "沒有假上游的 jp／omd 略過、不中斷" 'printf "%s\n" "$OUT" | grep -q "沒有 jp/，略過"'

echo "▶ 2. 同一情境加 --apply → 覆蓋並更新 SOURCE.json"
run "$SB" --apply
check "--apply exit 0" '[ "$RC" -eq 0 ]' "$OUT"
check "apple/DESIGN.md 變成上游內容" 'cmp -s "$SB/.claude/ui/apple/DESIGN.md" "$SB/upstream/voltagent/design-md/apple/DESIGN.md"'
check "apple upstream_commit 更新" '[ "$(jq -r .upstream_commit "$SB/.claude/ui/apple/SOURCE.json" | tr -d "\r")" = "fake0000voltagent" ]'
check "apple imported_sha256 等於新內容的 hash" '[ "$(jq -r .imported_sha256 "$SB/.claude/ui/apple/SOURCE.json" | tr -d "\r")" = "$(sha "$SB/.claude/ui/apple/DESIGN.md")" ]'
check "apple locally_modified 變 false" '[ "$(jq -r .locally_modified "$SB/.claude/ui/apple/SOURCE.json" | tr -d "\r")" = "false" ]'
check "voltagent last_synced 更新成今天" '[ "$(jq -r ".sources[] | select(.id==\"voltagent\") | .last_synced" "$SB/.claude/ui/_sources.json" | tr -d "\r")" = "$(date +%Y-%m-%d)" ]'
check "jp last_synced 沒被動（這次沒抓 jp）" '[ "$(jq -r ".sources[] | select(.id==\"jp\") | .last_synced" "$SB/.claude/ui/_sources.json" | tr -d "\r")" = "null" ]'
check "SOURCE.json 的中文欄位沒被 jq 弄壞（claude）" 'jq -r .local_changes "$SB/.claude/ui/claude/SOURCE.json" | grep -q "標題用字"'
run "$SB"
check "apply 後再預覽，apple 不再列為有更新" '! section "上游有更新" | grep -qx "  - apple"' "$OUT"

echo "▶ 3. 本地手改過＋上游也改 → 一個 byte 都不動，列在「本地已修改」並印 diff"
SB="$(new_sandbox)"
printf '\nLOCAL EDIT\n' >> "$SB/.claude/ui/stripe/DESIGN.md"
printf '\nUPSTREAM EDIT\n' >> "$SB/upstream/voltagent/design-md/stripe/DESIGN.md"
stripe_before="$(sha "$SB/.claude/ui/stripe/DESIGN.md")"
stripe_sj_before="$(sha "$SB/.claude/ui/stripe/SOURCE.json")"
run "$SB" --apply
check "stripe/DESIGN.md 沒變" '[ "$(sha "$SB/.claude/ui/stripe/DESIGN.md")" = "$stripe_before" ]'
check "stripe/SOURCE.json 沒變" '[ "$(sha "$SB/.claude/ui/stripe/SOURCE.json")" = "$stripe_sj_before" ]'
check "stripe 列在「本地已修改」" 'section "本地已修改" | grep -qx "  - stripe"' "$OUT"
check "印出 diff（含本地與上游兩邊的改動）" 'printf "%s\n" "$OUT" | grep -q "^    -LOCAL EDIT" && printf "%s\n" "$OUT" | grep -q "^    +UPSTREAM EDIT"' "$OUT"
check "stripe 不在「上游有更新」" '! section "上游有更新" | grep -qx "  - stripe"'

echo "▶ 4. claude（imported_sha256 本來就和現況不同）＋上游改 → 不覆蓋"
SB="$(new_sandbox)"
printf '\nUPSTREAM EDIT\n' >> "$SB/upstream/voltagent/design-md/claude/DESIGN.md"
claude_before="$(sha "$SB/.claude/ui/claude/DESIGN.md")"
run "$SB" --apply
check "claude/DESIGN.md 沒變" '[ "$(sha "$SB/.claude/ui/claude/DESIGN.md")" = "$claude_before" ]'
check "claude 列在「本地已修改」" 'section "本地已修改" | grep -qx "  - claude"' "$OUT"

echo "▶ 5. 只差第一行標題的那 20 份（hash 等於 imported_sha256）＋上游原版 → 視為沒改過，可覆蓋"
SB="$(new_sandbox)"
up_apple="$SB/upstream/voltagent/design-md/apple/DESIGN.md"
{ echo "# Upstream Original Title"; tail -n +2 "$SB/.claude/ui/apple/DESIGN.md"; } > "$up_apple.new" && mv "$up_apple.new" "$up_apple"
run "$SB" --apply
check "apple 被覆蓋成上游版（第一行換掉）" '[ "$(head -n 1 "$SB/.claude/ui/apple/DESIGN.md")" = "# Upstream Original Title" ]'

echo "▶ 6. 上游新格式（檔頭 YAML）→ 以整份檔案比對與覆蓋"
SB="$(new_sandbox)"
up_wise="$SB/upstream/voltagent/design-md/wise/DESIGN.md"
{ printf -- '---\nversion: alpha\ncolors:\n  primary: "#9FE870"\n---\n\n'; cat "$SB/.claude/ui/wise/DESIGN.md"; } > "$up_wise.new" && mv "$up_wise.new" "$up_wise"
run "$SB"
check "只在 YAML 檔頭不同也算上游有更新" 'section "上游有更新" | grep -qx "  - wise"' "$OUT"
run "$SB" --apply
check "覆蓋後 YAML 檔頭在本地" 'grep -q "primary: \"#9FE870\"" "$SB/.claude/ui/wise/DESIGN.md"'
check "upstream_format 偵測為 google-alpha" '[ "$(jq -r .upstream_format "$SB/.claude/ui/wise/SOURCE.json" | tr -d "\r")" = "google-alpha" ]'
printf 'x' >> "$SB/upstream/voltagent/design-md/wise/DESIGN.md"
sed -i 's/#9FE870/#000000/' "$SB/.claude/ui/wise/DESIGN.md"
wise_before="$(sha "$SB/.claude/ui/wise/DESIGN.md")"
run "$SB" --apply
check "本地只改 YAML 裡的色碼也算本地已修改、不覆蓋" '[ "$(sha "$SB/.claude/ui/wise/DESIGN.md")" = "$wise_before" ] && section "本地已修改" | grep -qx "  - wise"' "$OUT"

echo "▶ 7. 上游新增 starbucks → 預覽列出；--apply 不建目錄"
SB="$(new_sandbox)"
mkdir -p "$SB/upstream/voltagent/design-md/starbucks"
printf '# Starbucks\n\n## Colors\n\n## Typography\n' > "$SB/upstream/voltagent/design-md/starbucks/DESIGN.md"
run "$SB"
check "starbucks 列在「上游新增」" 'section "上游新增" | grep -q "  - starbucks ← voltagent:starbucks"' "$OUT"
run "$SB" --apply
check "--apply 後 .claude/ui/starbucks/ 不存在" '[ ! -e "$SB/.claude/ui/starbucks" ]'
mkdir -p "$SB/upstream/voltagent/design-md/attio"
cp "$SB/.claude/ui/attio/DESIGN.md" "$SB/upstream/voltagent/design-md/attio/DESIGN.md"
run "$SB"
check "上游新增的 id 和本地 self-extracted 撞名 → 標出撞名" 'section "上游新增" | grep -q "attio.*本地已有同名目錄"' "$OUT"

echo "▶ 8. 上游刪掉 bmw → 本地檔保留，只標 upstream_status: removed"
SB="$(new_sandbox)"
rm -rf "$SB/upstream/voltagent/design-md/bmw"
run "$SB"
check "bmw 列在「上游已刪除」" 'section "上游已刪除" | grep -qx "  - bmw"' "$OUT"
check "預覽不改 upstream_status" '[ "$(jq -r .upstream_status "$SB/.claude/ui/bmw/SOURCE.json" | tr -d "\r")" = "present" ]'
run "$SB" --apply
check "--apply 後 bmw/DESIGN.md 還在" '[ -f "$SB/.claude/ui/bmw/DESIGN.md" ]'
check "--apply 後 upstream_status 是 removed" '[ "$(jq -r .upstream_status "$SB/.claude/ui/bmw/SOURCE.json" | tr -d "\r")" = "removed" ]'
run "$SB"
check "已標 removed 的不再重複列出" '! section "上游已刪除" | grep -qx "  - bmw"' "$OUT"
check "semrush（上游欄位全 null）的 SOURCE.json 沒被動" 'cmp -s "$SB/.claude/ui/semrush/SOURCE.json" "$REPO/.claude/ui/semrush/SOURCE.json"'

echo "▶ 9. --source 只看一個來源"
SB="$(new_sandbox)"
printf '\nchange\n' >> "$SB/upstream/voltagent/design-md/apple/DESIGN.md"
mkdir -p "$SB/upstream/jp/design-md/ippodo"
printf '# 一保堂茶舗のデザイン\n\n## 2. Color Palette & Roles\n\n## 3. Typography Rules\n' > "$SB/upstream/jp/design-md/ippodo/DESIGN.md"
run "$SB" --source jp
check "--source jp 不列 voltagent 的項目" '! printf "%s\n" "$OUT" | grep -qx "  - apple"' "$OUT"
check "--source jp 列出 jp 的新增（帶 jp- 前綴）" 'section "上游新增" | grep -q "  - jp-ippodo ← jp:ippodo"' "$OUT"
check "jp 沒有授權檔 → 提醒" 'printf "%s\n" "$OUT" | grep -q "授權檔缺"' "$OUT"
run "$SB" --source nope
check "--source 不存在的來源 → exit 1" '[ "$RC" -eq 1 ]'

echo "▶ 10. --import jp:ippodo → 建 DESIGN.md＋SOURCE.json，check-counts 擋 CATALOG"
run "$SB" --import jp:ippodo
check "--import exit 0" '[ "$RC" -eq 0 ]' "$OUT"
check "jp-ippodo/DESIGN.md 存在且等於上游" 'cmp -s "$SB/.claude/ui/jp-ippodo/DESIGN.md" "$SB/upstream/jp/design-md/ippodo/DESIGN.md"'
check "SOURCE.json：source=jp、license=MIT、imported_sha256 正確" '
    sj="$SB/.claude/ui/jp-ippodo/SOURCE.json";
    [ "$(jq -r .source "$sj" | tr -d "\r")" = "jp" ] &&
    [ "$(jq -r .license "$sj" | tr -d "\r")" = "MIT" ] &&
    [ "$(jq -r .upstream_path "$sj" | tr -d "\r")" = "design-md/ippodo/DESIGN.md" ] &&
    [ "$(jq -r .imported_sha256 "$sj" | tr -d "\r")" = "$(sha "$SB/.claude/ui/jp-ippodo/DESIGN.md")" ]'
check "language 依內容判成 ja" '[ "$(jq -r .language "$SB/.claude/ui/jp-ippodo/SOURCE.json" | tr -d "\r")" = "ja" ]'
check "提醒去 CATALOG.md 加兩處" 'printf "%s\n" "$OUT" | grep -q "CATALOG.md 加兩處"' "$OUT"
check "提醒授權檔缺" 'printf "%s\n" "$OUT" | grep -q "授權檔缺"' "$OUT"
check "CATALOG.md 沒被腳本改（留給人寫繁中說明）" 'cmp -s "$SB/.claude/ui/CATALOG.md" "$REPO/.claude/ui/CATALOG.md"'
CC="$(bash "$SB/scripts/check-counts.sh" 2>&1)"
check "check-counts 出現 ✗ 未列入 CATALOG.md：jp-ippodo" 'printf "%s\n" "$CC" | grep -q "未列入 CATALOG.md：jp-ippodo"' "$CC"
run "$SB"
check "剛匯入的不會出現在「本地已修改」" '! section "本地已修改" | grep -q "jp-ippodo"' "$OUT"
check "剛匯入的不再列為上游新增" '! section "上游新增" | grep -q "jp-ippodo"' "$OUT"
run "$SB" --import jp:ippodo
check "重複 --import 同一份 → exit 1 不覆蓋" '[ "$RC" -eq 1 ]'
run "$SB" --import jp:nosuch
check "--import 上游沒有的 id → exit 1" '[ "$RC" -eq 1 ] && [ ! -e "$SB/.claude/ui/jp-nosuch" ]'
run "$SB" --import self-extracted:foo
check "--import 沒有上游的來源 → exit 1" '[ "$RC" -eq 1 ]'
run "$SB" --import ippodo
check "--import 沒寫來源 → exit 1" '[ "$RC" -eq 1 ]'

echo "▶ 11. 沒有 gh、也沒給 --upstream-dir → exit 2"
NOGH_PATH="$(printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r p; do
    [ -x "$p/gh" ] || [ -x "$p/gh.exe" ] || printf '%s:' "$p"; done)"
OUT="$(PATH="${NOGH_PATH%:}" bash "$SB/scripts/sync-ui-sources.sh" 2>&1)"; RC=$?
check "exit 2" '[ "$RC" -eq 2 ]' "$OUT"
check "訊息含「需要 gh」" 'printf "%s\n" "$OUT" | grep -q "需要 gh"' "$OUT"

echo "▶ 12. 新專案不帶同步腳本（copy／update 四份）"
NORSYNC_PATH="$(printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r p; do
    [ -x "$p/rsync" ] || [ -x "$p/rsync.exe" ] || printf '%s:' "$p"; done)"
NORSYNC_PATH="${NORSYNC_PATH%:}"
assert_dest() {  # $1=標籤 $2=目標（check 用 eval，所以先存進 DT）
    DT="$2"
    check "$1：沒有 scripts/sync-ui-sources*" '! ls "$DT"/scripts/sync-ui-sources* >/dev/null 2>&1'
    check "$1：有 .claude/ui/_licenses/" '[ -f "$DT/.claude/ui/_licenses/voltagent-awesome-design-md.txt" ]'
    check "$1：其他 scripts 照常帶過去" '[ -f "$DT/scripts/check-counts.sh" ]'
}
D="$TMP_ALL/copy-sh"
bash "$REPO/scripts/copy-template.sh" "$D" >/dev/null 2>&1 </dev/null
assert_dest "copy-template.sh" "$D"
D="$TMP_ALL/copy-sh-norsync"
PATH="$NORSYNC_PATH" bash "$REPO/scripts/copy-template.sh" "$D" >/dev/null 2>&1 </dev/null
assert_dest "copy-template.sh（沒有 rsync）" "$D"

D="$TMP_ALL/update-sh"; mkdir -p "$D/.claude" "$D/scripts"
echo old > "$D/scripts/sync-ui-sources.sh"   # 模擬舊版 update 漏過去的
bash "$REPO/scripts/update-template.sh" "$D" --no-backup >/dev/null 2>&1 </dev/null
assert_dest "update-template.sh" "$D"
D="$TMP_ALL/update-sh-norsync"; mkdir -p "$D/.claude" "$D/scripts"
echo old > "$D/scripts/sync-ui-sources.sh"
PATH="$NORSYNC_PATH" bash "$REPO/scripts/update-template.sh" "$D" --no-backup >/dev/null 2>&1 </dev/null
assert_dest "update-template.sh（沒有 rsync）" "$D"

if command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    D="$TMP_ALL/copy-ps1"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$REPO/scripts/copy-template.ps1")" "$(cygpath -w "$D")" >/dev/null 2>&1 </dev/null
    assert_dest "copy-template.ps1" "$D"
    D="$TMP_ALL/update-ps1"; mkdir -p "$D/.claude" "$D/scripts"
    echo old > "$D/scripts/sync-ui-sources.sh"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$REPO/scripts/update-template.ps1")" "$(cygpath -w "$D")" -NoBackup >/dev/null 2>&1 </dev/null
    assert_dest "update-template.ps1" "$D"
else
    echo "  - 略過 ps1（沒有 powershell.exe）"
fi

echo ""
echo "結果：$PASS 通過、$FAIL 失敗"
[ "$FAIL" -eq 0 ]
