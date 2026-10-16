#!/bin/bash
# ui-lint.sh — 寫前端檔的當下，提出三種「寫的人自己不會發現」的問題（只提醒，不擋）
#
#   ① 寫死色碼：元件裡出現 hex，而不是引用 tokens／CSS 變數
#   ② 動畫等級不符：ui-style.json 的 motion 是 L1，檔案卻 import 了動畫函式庫（L2 則是 3D／WebGL）
#   ③ AI 痕跡（P0）：從 avoid-ai-design 的 detect.mjs 挑出 grep 判斷得準的三條，用 bash 改寫
#
# 為什麼是 hook：這三件事以前只靠 ui-builder 寫完自己 grep（ui-style-compliance 階段 3）。
# 主模型直接改前端檔時沒有人 grep，而「寫進一個 .tsx」這個時機機器判斷得出來。
#
# 由 post-write.sh 呼叫，不自己掛事件（settings.json 不需要新接線）。
# **刻意不接 PostToolUseFailure**：寫檔失敗代表磁碟上的內容沒變，沒有新東西可以檢查；
# 而這支檢查的對象是「磁碟上的檔案」，不是 payload（Edit 的 payload 只有被換掉的那一段，
# 行號也對不上）——所以失敗那一次就算收到事件也無事可做。
#
# 用法：bash ui-lint.sh <檔案絕對路徑> <相對 WORK_ROOT 的路徑> <WORK_CLAUDE> [MAIN_CLAUDE]
#   stdout：有事要講時輸出純文字（呼叫端負責包成 additionalContext）；沒事則無輸出
#   exit ：一律 0
#
# 逃生門：UI_LINT=off（三種一起關）。個別 AI 痕跡規則照上游的寫法豁免：
#   該行或上一行寫 `avoid-ai-design-ignore: C6`；整份檔案寫 `avoid-ai-design-ignore-file`（不帶 ID＝全部）
#
# ── ③ 的出處與取捨 ─────────────────────────────────────────────────────────────
# 上游：funboy322/avoid-ai-design 的 scripts/detect.mjs（commit 2b7c718，2026-09-24，v0.4.0）
# 授權：MIT，Copyright (c) 2026 ungspirit，原文在 .claude/ui/_licenses/avoid-ai-design.txt
# 規則 ID 沿用上游，方便對照與豁免。detect.mjs 的 P0 有六條，只收三條：
#
#   收  C6 漸層填色的標題字   Tailwind `bg-clip-text`＋`text-transparent`；CSS `background-clip: text`＋透明字色
#   收  C1 紫／靛藍漸層       只收 Tailwind 那半（`bg-gradient-to-*`／`bg-linear-*`＋`from|via|to-indigo|violet|purple|fuchsia`）
#                             CSS 那半要把色碼換成 HSL 判色相，bash 判不準 → 不收
#   收  K1 沒改過的 shadcn    `--primary` 等於 shadcn 四種預設基底色之一（字面比對，最準）
#   不收 T1 Inter 當主字型     風格庫 69 份裡有 26 份的 DESIGN.md 本身就指定 Inter，照風格寫反而會被叫
#   不收 L1 膠囊徽章＋置中 hero、L2 三張圖示卡  要看 <h1> 前 900 字的結構、CSS 規則與 class 的對應，grep 會亂叫
#
# 上游是以「同一個 class 屬性／同一條 CSS 規則」為單位，這裡以「同一行」或「同一份檔案」近似：
# class 拆成多行（clsx）會漏抓；CSS 的 background-clip 與透明字色寫在不同規則會多抓。方向偏漏抓。

set -uo pipefail

FILE="${1:-}"
REL="${2:-}"
WORK_CLAUDE="${3:-}"
MAIN_CLAUDE="${4:-$WORK_CLAUDE}"

[ "${UI_LINT:-on}" = "off" ] && exit 0
[ -n "$FILE" ] && [ -f "$FILE" ] || exit 0

REL=$(printf '%s' "$REL" | tr '\\' '/')
REL="${REL#./}"
# payload 沒帶 cwd 時 WORK_ROOT 會退回主 checkout，worktree 裡的檔案就變成 .claude/worktrees/<名>/src/…
case "$REL" in
    .claude/worktrees/*/*) REL="${REL#.claude/worktrees/*/}" ;;
esac

case "$REL" in
    .claude/*|docs/*) exit 0 ;;
    node_modules/*|*/node_modules/*|dist/*|*/dist/*|build/*|*/build/*|.next/*|*/.next/*|out/*|coverage/*) exit 0 ;;
    __tests__/*|*/__tests__/*) exit 0 ;;
esac

BASE="${REL##*/}"
BASE_LC=$(printf '%s' "$BASE" | tr '[:upper:]' '[:lower:]')
case "$BASE_LC" in
    *.tsx|*.jsx|*.vue|*.svelte|*.html|*.css|*.scss) ;;
    *) exit 0 ;;
esac
case "$BASE_LC" in
    *.test.*|*.spec.*|*.stories.*) exit 0 ;;
esac

# grep 的 -n 輸出 → 「- L12 `內容`」，最多 5 行，內容截到 70 字
fmt_hits() {
    tr -d '\r' | awk -F: '
        NR <= 5 {
            n = $1; sub(/^[^:]*:/, "")
            gsub(/^[ \t]+|[ \t]+$/, "")
            gsub(/`/, "\x27")
            if (length($0) > 70) $0 = substr($0, 1, 70) "…"
            printf "- L%s `%s`\n", n, $0
        }
        END { if (NR > 5) printf "- …另有 %d 處\n", NR - 5 }'
}

SECTIONS=""
add_section() {
    if [ -n "$SECTIONS" ]; then SECTIONS="$SECTIONS"$'\n\n'"$1"; else SECTIONS="$1"; fi
}

# ---------------------------------------------------------------- ① 寫死色碼
#
# tokens／theme 檔就是放 hex 的地方（ui-style-compliance 2.1：第一次建 tokens 時可以從 DESIGN.md 抄 hex）。
# 自訂屬性的宣告（`--c: #fff`）與 var() 的備援值是在**定義** token，先拿掉再找。
# 頁內錨點（`href="#face"`、SVG 的 `url(#grad)`）長得像 hex，也先拿掉；`&#8212;` 這類 HTML 實體前面是 &，不算。
# 列出的是色碼本身而不是整行——一行很長時，截斷後常常看不到是哪個色碼。
case "$BASE_LC" in
    *tokens*|*theme*|tailwind.config*) ;;
    *)
        HEX_HITS=$(sed -E -e 's/var\(--[^)]*\)//g' -e 's/--[A-Za-z0-9_-]+[[:space:]]*:[^;]*//g' \
                          -e "s/href=[\"']#[^\"']*//g" -e 's/url\(#[^)]*\)//g' "$FILE" 2>/dev/null \
            | grep -noE '(^|[^&A-Za-z0-9_])#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})([^0-9A-Za-z_]|$)' 2>/dev/null \
            | sed -E 's/^([0-9]+):[^#]*(#[0-9A-Fa-f]+).*/\1:\2/')
        if [ -n "$HEX_HITS" ]; then
            HEX_N=$(printf '%s\n' "$HEX_HITS" | grep -c .)
            add_section "**寫死色碼 ${HEX_N} 處**——元件要引用 tokens／CSS 變數，hex 只該出現在 tokens 檔（\`ui-style-compliance\` 2.1）。沒有對應的 token 就先在 tokens 檔加一個，不要就地寫色碼：
$(printf '%s\n' "$HEX_HITS" | fmt_hits)"
        fi
        ;;
esac

# ---------------------------------------------------------------- ② 動畫等級
#
# 等級來源與「沒有 motion 欄位就當 L1」都是 ui-style-compliance/motion.md 開頭的規定（唯一來源）。
# 沒有 ui-style.json＝使用者還沒定調，不檢查。ui-style.json 進版控，worktree 會帶一份，先讀 worktree 的。
UI_JSON=""
for f in "$WORK_CLAUDE/taskmaster-data/ui-style.json" "$MAIN_CLAUDE/taskmaster-data/ui-style.json"; do
    [ -n "$WORK_CLAUDE" ] && [ -f "$f" ] && { UI_JSON="$f"; break; }
done

if [ -n "$UI_JSON" ] && command -v jq >/dev/null 2>&1; then
    MOTION=$(jq -r '(.motion // "L1") | ascii_upcase' "$UI_JSON" 2>/dev/null || echo "")
    HEAVY_PKG='three|@react-three/[a-z0-9-]+|vanta|@splinetool/[a-z0-9-]+'
    HEAVY_CDN='[/@](three|vanta)[@./]'
    case "$MOTION" in
        L1)
            PKG="gsap|@gsap/[a-z0-9-]+|lenis|@studio-freight/lenis|locomotive-scroll|framer-motion|motion|aos|animejs|${HEAVY_PKG}"
            CDN='[/@](gsap|three|vanta|lenis|locomotive-scroll|aos|animejs|anime)[@./]'
            ALLOWED="L1（安靜）只用 CSS \`transition\`／\`animation\`，不 import 任何動畫函式庫"
            ;;
        L2)
            PKG="$HEAVY_PKG"
            CDN="$HEAVY_CDN"
            ALLOWED="L2（有節奏）不用 WebGL／3D（three.js、Vanta、Spline）"
            ;;
        *) PKG="" ;;
    esac
    if [ -n "$PKG" ]; then
        IMPORT_RE="(from|import|require[[:space:]]*\\(|import[[:space:]]*\\()[[:space:]]*['\"](${PKG})(/[^'\"]*)?['\"]"
        SCRIPT_RE="<script[^>]*src=['\"][^'\"]*${CDN}"
        MOTION_HITS=$(grep -nE -e "$IMPORT_RE" -e "$SCRIPT_RE" "$FILE" 2>/dev/null)
        if [ -n "$MOTION_HITS" ]; then
            add_section "**動畫等級不符**：\`ui-style.json\` 的動畫等級是 **${MOTION}**——${ALLOWED}。這個檔卻載入了：
$(printf '%s\n' "$MOTION_HITS" | fmt_hits)
改用原生 CSS，或先跑 \`/ui-style\` 把等級調高（每一級允許什麼見 \`ui-style-compliance/motion.md\` 第 2 節）。"
        fi
    fi
fi

# ---------------------------------------------------------------- ③ AI 痕跡（P0）
AAD_IGNORE_ALL=0
AAD_IGNORED=""
FILE_IGNORE=$(grep -oE 'avoid-ai-design-ignore-file(:[[:space:]]*[A-Z0-9, ]+)?' "$FILE" 2>/dev/null | head -n 1)
if [ -n "$FILE_IGNORE" ]; then
    case "$FILE_IGNORE" in
        *:*) AAD_IGNORED="${FILE_IGNORE#*:}" ;;
        *) AAD_IGNORE_ALL=1 ;;
    esac
fi

# 該行或上一行有 `avoid-ai-design-ignore: <ID>` → 豁免（上游 scanFile 的規則）
aad_kept() { # <規則 ID> ← stdin 為 grep -n 輸出
    local id="$1" line n near
    while IFS= read -r line; do
        n="${line%%:*}"
        near=$(sed -n "$(( n > 1 ? n - 1 : 1 )),${n}p" "$FILE" 2>/dev/null)
        printf '%s' "$near" | grep -qE "avoid-ai-design-ignore:[A-Z0-9, ]*\\b${id}\\b" && continue
        printf '%s\n' "$line"
    done
}

aad_rule() { # <ID> <說明> <grep -n 結果>
    local id="$1" name="$2" hits="$3"
    [ -n "$hits" ] || return 0
    printf '%s' "$AAD_IGNORED" | grep -qE "\\b${id}\\b" && return 0
    hits=$(printf '%s\n' "$hits" | aad_kept "$id")
    [ -n "$hits" ] || return 0
    AAD_OUT="${AAD_OUT}- **${id}** ${name}
$(printf '%s\n' "$hits" | fmt_hits | sed 's/^/  /')
"
}

AAD_OUT=""
if [ "$AAD_IGNORE_ALL" -eq 0 ]; then
    C6=$(grep -nE 'bg-clip-text' "$FILE" 2>/dev/null | grep -E 'text-transparent')
    if grep -qE '(text-fill-color|(^|[^-])color)[[:space:]]*:[[:space:]]*transparent' "$FILE" 2>/dev/null; then
        C6_CSS=$(grep -nE 'background-clip[[:space:]]*:[[:space:]]*text' "$FILE" 2>/dev/null)
        [ -n "$C6_CSS" ] && C6=$(printf '%s\n%s' "$C6" "$C6_CSS" | grep . | sort -t: -k1,1n -u)
    fi
    aad_rule C6 "漸層填色的標題字（可讀性也差）" "$C6"

    C1=$(grep -nE '(^|[^A-Za-z0-9-])bg-(gradient-to-|linear-|radial|conic)' "$FILE" 2>/dev/null \
        | grep -E '(^|[^A-Za-z0-9-])(from|via|to)-(indigo|violet|purple|fuchsia)-[0-9]{2,3}')
    aad_rule C1 "紫／靛藍漸層（沒人選過的預設漸層）" "$C1"

    K1=$(grep -nE -- '--primary[[:space:]]*:[[:space:]]*(oklch\(0\.205 0 0\)|222\.2 47\.4% 11\.2%|240 5\.9% 10%|0 0% 9%)' "$FILE" 2>/dev/null)
    aad_rule K1 "沒改過的 shadcn/ui 預設主題（\`--primary\` 還是初始值）" "$K1"
fi

if [ -n "$AAD_OUT" ]; then
    add_section "**AI 痕跡（P0）**——這幾種是「沒人選過的預設」，對照 \`ui-style-compliance/anti-ai.md\` 的「產出後」清單：
${AAD_OUT%$'\n'}
規則取自 avoid-ai-design（MIT）。是題材真的需要、刻意保留的，在該行或上一行加 \`avoid-ai-design-ignore: <ID>\`。"
fi

[ -n "$SECTIONS" ] || exit 0

printf '🎨 前端寫入檢查：`%s`（只提醒，不擋）\n\n%s\n\n（關閉：UI_LINT=off）\n' "$REL" "$SECTIONS"
exit 0
