#!/bin/bash
# overview-scan.sh — 從程式碼掃出專案地圖的骨架
#
# 給 overview.sh 與瀏覽器讀，模型不要讀（skeleton.json 動輒數百 KB；要狀態請讀 wbs.md）。
#
# 用法：bash .claude/scripts/overview-scan.sh <主 checkout 根目錄>
#   寫 <根>/.claude/taskmaster-data/overview/skeleton.json，stdout 印一個字：
#   cached（HEAD、工作區改動清單與設定都沒變，沒有重掃）或 scanned。
#   失敗時非 0，既有的 skeleton.json 不動。
#
# skeleton.json 只放逐檔的事實（檔案屬於哪個掃描模組、逐檔 import 與 http、逐檔路由）；彙總成模組邊、
# 路由數、與架構文件 5.5 合併都在 overview.sh 做——5.5 有效時檔案會改歸 5.5 的模組，
# 在這裡先彙總就得在那邊拆回來。第三方 import 也留著（`pkg:<名稱>`），模組邊才丟。
#
# 演算法：提案 architect-2026-11-05-1500.md 3.1 第 1–8 步，加上計畫的 X2（跨套件撞名加套件
# 目錄名）、X3（目錄名含非 ASCII 時 id 用 m- 加 6 碼雜湊：mermaid 節點 id 必須是 ASCII）、
# X6（前端 fetch／axios 的路徑常值對到後端路由，只連得上唯一一個後端檔時記一筆 http）。
#
# 相容：Git Bash 是 gawk、Ubuntu 是 mawk——awk 一律 LC_ALL=C 逐位元組，不以 \0 切欄（先 tr），
# 雜湊每步取模保持在 2^31 以下；JSON 跳脫全交給 jq，而 jq 只從 stdin 讀（Windows 的 jq 開不了
# 含中文的絕對路徑）。
#
# 行程預算（5,000 檔在 Windows 3 秒內）：命中快取時只有 git status 一個；重掃時
# status、ls-files、tr、awk、grep、tr、awk、jq、mv 共 9 個（設定了 overview.scan 再多一個 jq）。
#
# 環境變數：OVERVIEW_MAX_MODULES（預設 40）、OVERVIEW_SCAN_MAX_FILES（預設 20000，
# 超過只切模組、不掃 import 與路由）。project.json 的 overview.scan.{exclude,roots,depth} 可覆寫。

SCAN_VERSION=3
# 與 hooks/post-write.sh 的同名常數相同（測試會比對）
OVERVIEW_CODE_EXT="py ts tsx js jsx mjs cjs vue svelte go java kt cs rs"

MAX_MODULES=${OVERVIEW_MAX_MODULES:-40}
[[ $MAX_MODULES =~ ^[1-9][0-9]*$ ]] || MAX_MODULES=40
MAX_FILES=${OVERVIEW_SCAN_MAX_FILES:-20000}
[[ $MAX_FILES =~ ^[0-9]+$ ]] || MAX_FILES=20000

ROOT="${1:-}"
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
    echo "用法：overview-scan.sh <主 checkout 根目錄>" >&2
    exit 2
fi
OUT="$ROOT/.claude/taskmaster-data/overview"
[ -d "$OUT" ] || mkdir -p "$OUT" || exit 1
[ -f "$OUT/.gitignore" ] || printf '*\n' > "$OUT/.gitignore"
G=(git -C "$ROOT" -c core.quotepath=off)

# ---------------------------------------------------------------- 設定與快取 key

PJ=""
[ -f "$ROOT/.claude/taskmaster-data/project.json" ] && IFS= read -r -d '' PJ < "$ROOT/.claude/taskmaster-data/project.json"
ROOTS="" DEPTH="" EXCL=()
if [[ $PJ == *'"scan"'* ]]; then
    { IFS= read -r ROOTS; IFS= read -r DEPTH; mapfile -t EXCL; } < <(printf '%s' "$PJ" | jq -r '
        (.overview.scan // {}) as $s
        | (($s.roots // []) | map(tostring | sub("^\\./"; "") | sub("/+$"; "")) | join("\u0001")),
          (($s.depth // "") | tostring),
          (($s.exclude // [])[] | tostring | sub("^\\./"; ""))' 2>/dev/null | tr -d '\r')
else
    PJ=""   # 設定沒有 scan 段時，project.json 其他欄位的改動不必讓骨架重掃
fi
PS=(-- . ':(exclude).claude' ':(exclude)docs')
for e in "${EXCL[@]}"; do [ -n "$e" ] && PS+=(":(exclude,glob)$e"); done

# key＝版本與上限＋scan 設定＋HEAD＋工作區改動清單。只看清單的話，同一個檔第二次修改不會
# 讓 key 變，所以另外比對清單裡每個檔是不是比上次掃描新（-nt 是 bash 內建，不開行程）。
KEY="v$SCAN_VERSION $MAX_MODULES $MAX_FILES"$'\n'"$PJ"$'\n'
HEAD="" CHANGED=() skip=0
while IFS= read -r -d '' rec; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case "$rec" in
        '# branch.oid '*) HEAD=${rec#'# branch.oid '} ;;
        '#'*) continue ;;   # branch.ab 之類，fetch 一次就變，與程式碼無關
        '1 '*) CHANGED+=("${rec#* * * * * * * * }") ;;
        '2 '*) CHANGED+=("${rec#* * * * * * * * * }"); skip=1 ;;   # 下一筆是改名前的路徑
        'u '*) CHANGED+=("${rec#* * * * * * * * * * }") ;;
        '? '*) CHANGED+=("${rec#? }") ;;
    esac
    KEY+="$rec"$'\n'
done < <("${G[@]}" status --porcelain=v2 --branch -z -uall "${PS[@]}" 2>/dev/null)
KEY+="HEAD $HEAD"$'\n'

if [ -f "$OUT/skeleton.json" ] && [ -f "$OUT/.scan-key" ] && [ -f "$OUT/.scan-files" ]; then
    OLD=""
    IFS= read -r -d '' OLD < "$OUT/.scan-key"
    if [ "$OLD" = "$KEY" ]; then
        fresh=1
        for p in "${CHANGED[@]}"; do
            [ "$ROOT/$p" -nt "$OUT/.scan-files" ] && { fresh=0; break; }
        done
        if [ "$fresh" = 1 ]; then echo cached; exit 0; fi
    fi
fi

# ---------------------------------------------------------------- 第 1–5 步：檔案 → 模組

IFS= read -r -d '' AWK_LAYOUT <<'AWK'
function dirname(p,   i) { i = match(p, /\/[^\/]*$/); return i ? substr(p, 1, i - 1) : "" }
function basename(p) { sub(/^.*\//, "", p); return p }
function under(p, d) { return d == "" || substr(p, 1, length(d) + 1) == d "/" }
function firstseg(p) { sub(/\/.*$/, "", p); return p }
# 每步取模 2^24：乘 31 加一個位元組後仍遠小於 2^31，gawk 與 mawk 算出來一樣
function hash6(s,   h, i) {
    h = 0
    for (i = 1; i <= length(s); i++) h = (h * 31 + ord[substr(s, i, 1)]) % 16777216
    return sprintf("%06x", h)
}
function kebab(s,   out, i, c, prev) {
    for (i = 1; i <= length(s); i++) if (ord[substr(s, i, 1)] >= 128) return "m-" hash6(s)
    out = ""; prev = ""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c ~ /[A-Z]/) { if (prev ~ /[a-z0-9]/) out = out "-"; out = out tolower(c) }
        else if (c ~ /[a-z0-9]/) out = out c
        else out = out "-"
        prev = c
    }
    gsub(/-+/, "-", out); sub(/^-/, "", out); sub(/-$/, "", out)
    return out == "" ? "m-" hash6(s) : out
}
function srcroot(P,   pre) {
    if (P in SR) return SR[P]
    pre = P == "" ? "" : P "/"
    if ((pre "src") in hasdir) SR[P] = pre "src"
    else if ((pre "app") in hasdir) SR[P] = pre "app"
    else if ((pre "lib") in hasdir) SR[P] = pre "lib"
    else if (P != "" && (pre basename(P)) in hasdir) SR[P] = pre basename(P)
    else SR[P] = P
    return SR[P]
}
# Maven／Gradle 慣例路徑（X16）：從 src/main/<lang> 往下剝掉「只有一個子目錄、沒有程式檔」的套件前綴鏈
# （com/acme/shop/），停在第一個分岔的層級；下一層就有程式檔時也停（那一層本身就是模組）
function mvnbase(r,   d, c) {
    if (r in MB) return MB[r]
    d = r
    while (nchild[d] == 1 && !(d in hasfile)) { c = d "/" onlykid[d]; if (c in hasfile) break; d = c }
    MB[r] = d
    return d
}
# 排序：檔案多的在前，同數依路徑
function before(a, b) { return cnt[a] > cnt[b] || (cnt[a] == cnt[b] && a < b) }
BEGIN {
    n = split(codeext, A, " "); for (i = 1; i <= n; i++) isext[A[i]] = 1
    n = split("node_modules dist build .venv venv __pycache__ .next .nuxt .svelte-kit .turbo target vendor coverage .git site-packages .tox .mypy_cache .pytest_cache .gradle bin obj .idea .vscode .claude", A, " ")
    for (i = 1; i <= n; i++) vend[A[i]] = 1
    n = split("tests test __tests__ spec specs __mocks__ e2e", A, " "); for (i = 1; i <= n; i++) tdir[A[i]] = 1
    n = split("package.json pyproject.toml go.mod Cargo.toml pom.xml build.gradle build.gradle.kts", A, " "); for (i = 1; i <= n; i++) mani[A[i]] = 1
    for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i
    # 不能叫 RT：那是 gawk 的內建變數（記錄分隔符實際值），拿來當陣列會 fatal——mawk 沒有它，所以只在 Git Bash 壞
    nroot = roots == "" ? 0 : split(roots, ROOTA, "\001")
    autod = depth !~ /^[1-9]$/
    if (autod) depth = 1
    OTHER = "\001"
}
{
    p = $0
    if (p == "" || substr(p, length(p)) == "/" || (p in seen)) next
    seen[p] = 1
    ns = split(p, S, "/")
    for (i = 1; i < ns; i++) if (S[i] in vend) next
    b = S[ns]
    if (ns > 1 && ((b in mani) || b ~ /\.csproj$/)) { pkg[dirname(p)] = 1; next }
    if (index(b, ".") == 0 || b ~ /\.min\.js$/) next
    e = tolower(b); sub(/^.*\./, "", e)
    if (!(e in isext)) next
    for (i = 1; i < ns; i++) if (S[i] in tdir) { ntest++; next }
    if (b ~ /\.(test|spec)\.[A-Za-z]+$/ || b ~ /^test_.*\.py$/ || b ~ /_test\.(py|go)$/) { ntest++; next }
    nf++; FP[nf] = p; lang[e]++
    d = dirname(p); hasfile[d] = 1
    while (d != "" && !(d in hasdir)) { hasdir[d] = 1; pd = dirname(d); nchild[pd]++; onlykid[pd] = basename(d); d = pd }
}
END {
    for (i = 1; i <= nf; i++) {
        p = FP[i]
        mvl = ""
        if (nroot) {
            base = OTHER
            for (r = 1; r <= nroot; r++) if (under(p, ROOTA[r]) && (base == OTHER || length(ROOTA[r]) > length(base))) base = ROOTA[r]
            if (base == OTHER) { M[i] = OTHER; continue }
            gk = base; mpk = base
        } else {
            # 設了 overview.scan.depth（autod 為 0）就不自動偵測 Maven 路徑，以設定為準
            if (autod && substr(p, 1, 9) == "src/main/" && match(p, /^src\/main\/(java|kotlin|scala)\//)) mvl = substr(p, 1, RLENGTH - 1)
            else if (autod && match(p, /\/src\/main\/(java|kotlin|scala)\//)) mvl = substr(p, 1, RSTART + RLENGTH - 2)
            if (mvl != "") {
                # 子專案（mvl 去掉 src/main/<lang>）當群組與撞名前綴（X2）：api-order、worker-order
                base = mvnbase(mvl); gk = mvl; sub(/\/?src\/main\/[a-z]+$/, "", gk); mpk = gk
            } else {
                P = dirname(p); while (P != "" && !(P in pkg)) P = dirname(P)
                base = srcroot(P)
                if (!under(p, base)) base = P
                gk = P != "" ? P : base; mpk = P
            }
        }
        rel = base == "" ? p : substr(p, length(base) + 2)
        nd = split(rel, R, "/") - 1
        if (nd < 1) { M[i] = OTHER; continue }
        cut = R[1]; for (k = 2; k <= depth && k <= nd; k++) cut = cut "/" R[k]
        md = base == "" ? cut : base "/" cut
        M[i] = md; GK[md] = gk; MPK[md] = mpk
        cnt[md]++
    }
    # 某個目錄占全部檔案 40% 以上、又有兩個以上含程式碼的子目錄 → 再往下切一層（只切一次）
    if (autod) {
        for (i = 1; i <= nf; i++) {
            md = M[i]; if (md == OTHER) continue
            rest = substr(FP[i], length(md) + 2); j = index(rest, "/")
            if (j && !((md SUBSEP substr(rest, 1, j - 1)) in kids)) { kids[md, substr(rest, 1, j - 1)] = 1; nkid[md]++ }
        }
        for (i = 1; i <= nf; i++) {
            md = M[i]; if (md == OTHER || cnt[md] < 0.4 * nf || nkid[md] < 2) continue
            split_[md] = 1
            rest = substr(FP[i], length(md) + 2); j = index(rest, "/")
            if (j) { nmd = md "/" substr(rest, 1, j - 1); M[i] = nmd; GK[nmd] = GK[md]; MPK[nmd] = MPK[md] }
        }
        delete cnt
        for (i = 1; i <= nf; i++) if (M[i] != OTHER) cnt[M[i]]++
    }
    nm = 0; nother = 0
    for (md in cnt) if (cnt[md] >= 2) L[++nm] = md
    for (i = 2; i <= nm; i++) { v = L[i]; j = i - 1; while (j >= 1 && before(v, L[j])) { L[j + 1] = L[j]; j-- } L[j + 1] = v }
    for (i = 1; i <= nf; i++) if (M[i] == OTHER || cnt[M[i]] < 2) nother++
    if (nm + (nother > 0) > maxmod) nm = maxmod - 1
    for (i = 1; i <= nm; i++) kept[L[i]] = 1
    for (i = 2; i <= nm; i++) { v = L[i]; j = i - 1; while (j >= 1 && v < L[j]) { L[j + 1] = L[j]; j-- } L[j + 1] = v }
    nother = 0
    for (i = 1; i <= nf; i++) if (!(M[i] in kept)) nother++

    # id：撞名時跨套件加套件目錄名、同套件加父層（X2）；仍撞就加 -2、-3
    for (i = 1; i <= nm; i++) { md = L[i]; ID[md] = kebab(basename(md)); mem[ID[md]] = mem[ID[md]] "\n" md; nid[ID[md]]++ }
    for (id in nid) {
        if (nid[id] < 2) continue
        k = split(substr(mem[id], 2), MM, "\n")
        distinct = 1; delete seenp
        for (j = 1; j <= k; j++) { if (MPK[MM[j]] in seenp) distinct = 0; seenp[MPK[MM[j]]] = 1 }
        for (j = 1; j <= k; j++) {
            md = MM[j]
            if (distinct) pre = MPK[md] != "" ? basename(MPK[md]) : firstseg(md)
            else { pre = basename(dirname(md)); if (pre == "") pre = "root" }
            ID[md] = kebab(pre) "-" id
        }
    }
    if (nother) used["other"] = 1
    for (i = 1; i <= nm; i++) {
        md = L[i]; id = ID[md]; bid = id; c = 2
        while (id in used) id = bid "-" c++
        used[id] = 1; ID[md] = id
    }

    printf "N\t%d\t%d\n", nf, ntest
    for (e in lang) printf "L\t%s\t%d\n", e, lang[e]
    for (i = 1; i <= nm; i++) {
        gk = GK[L[i]]
        if (!(gk in gid)) { gid[gk] = gk == "" ? "pkg-root" : "pkg-" kebab(gk); printf "G\t%s\t%s\n", gid[gk], gk }
    }
    for (i = 1; i <= nm; i++) {
        md = L[i]
        printf "M\t%s\t%s\t%s\t%s\t%d\t%s\n", ID[md], basename(md), md, gid[GK[md]], cnt[md], md (md in split_ ? "/*" : "/**")
    }
    if (nother) printf "M\tother\t\t\t_ungrouped\t%d\t\n", nother
    for (i = 1; i <= nf; i++) printf "F\t%s\t%s\n", FP[i], (M[i] in kept) ? ID[M[i]] : "other"
    for (P in pkg) printf "P\t%s\n", P
}
AWK

# ---------------------------------------------------------------- 第 6–7 步：逐檔 import 與路由

IFS= read -r -d '' AWK_EDGES <<'AWK'
function dirname(p,   i) { i = match(p, /\/[^\/]*$/); return i ? substr(p, 1, i - 1) : "" }
function basename(p) { sub(/^.*\//, "", p); return p }
function stem(p) { p = basename(p); sub(/\.[^.]*$/, "", p); return p }
function extof(p) { p = basename(p); if (!index(p, ".")) return ""; sub(/^.*\./, "", p); return tolower(p) }
function join(d, p) { return d == "" ? p : (p == "" ? d : d "/" p) }
function normpath(p,   n, A, i, k, O, out) {
    n = split(p, A, "/"); k = 0
    for (i = 1; i <= n; i++) {
        if (A[i] == "" || A[i] == ".") continue
        if (A[i] == "..") { if (k > 0) k--; continue }
        O[++k] = A[i]
    }
    out = ""; for (i = 1; i <= k; i++) out = out (i > 1 ? "/" : "") O[i]
    return out
}
function pkgof(f,   d) {
    d = dirname(f)
    if (d in PK) return PK[d]
    while (d != "" && !(d in pkg)) d = dirname(d)
    PK[dirname(f)] = d
    return d
}
function rec(f, t) {
    if (t == "" || t == f || ((f SUBSEP t) in done)) return
    done[f, t] = 1
    printf "I\t%s\t%s\timport\n", f, t
}
function trimq(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
# 第一個字串常值（呼叫端給的是左括號之後的內容）；沒有就回 \001
function strarg(s,   q, j) {
    sub(/^[ \t]*((value|path)[ \t]*=[ \t]*)?/, "", s)
    q = substr(s, 1, 1)
    if (q != "\"" && q != "'" && q != "`") return "\001"
    s = substr(s, 2); j = index(s, q)
    return j ? substr(s, 1, j - 1) : "\001"
}
function addroute(f, m, p) {
    if (p == "\001") return
    if (!(f in rn)) rorder[++nrf] = f
    rn[f]++; RM[f, rn[f]] = toupper(m); RP[f, rn[f]] = p
}
function joinpath(pre, p,   r) {
    r = pre "/" p; gsub(/\/+/, "/", r)
    if (r !~ /^\//) r = "/" r
    if (length(r) > 1) sub(/\/$/, "", r)
    return r
}

# ---- Python
function pyfile(s) {
    if ((s ".py") in FS_) return s ".py"
    if ((s "/__init__.py") in FS_) return s "/__init__.py"
    return ""
}
function pyabs(f, dotted,   P, s, t) {
    P = pkgof(f); s = dotted; gsub(/\./, "/", s)
    t = pyfile(join(P, s)); if (t != "") return t
    t = pyfile(join(join(P, "src"), s)); if (t != "") return t
    if (P != "") { t = pyfile(s); if (t != "") return t }
    return pyfile("src/" s)
}
function pyname(s) { sub(/[ \t]+as[ \t].*$/, "", s); gsub(/[ \t\\]/, "", s); return s }
function py(f, l,   mod, names, dots, n, i, nm, base, k, t, got, NM, s, m, ms, w) {
    sub(/#.*$/, "", l)
    if (l ~ /^[ \t]*@/) {
        if (!match(l, /^[ \t]*@[A-Za-z_][A-Za-z0-9_.]*\.(get|post|put|delete|patch|route)\(/)) return
        m = substr(l, RSTART, RLENGTH - 1); sub(/^.*\./, "", m)
        s = strarg(substr(l, RSTART + RLENGTH))
        if (m != "route") { addroute(f, m, s); return }
        ms = l
        if (!sub(/^.*methods[ \t]*=[ \t]*[[(]/, "", ms)) { addroute(f, "GET", s); return }
        sub(/[])].*$/, "", ms); n = split(ms, NM, ",")
        for (i = 1; i <= n; i++) { w = NM[i]; gsub(/[^A-Za-z]/, "", w); if (w != "") addroute(f, w, s) }
        return
    }
    if (l ~ /(APIRouter|Blueprint)\(/) {
        if (match(l, /(url_)?prefix[ \t]*=[ \t]*["'][^"']*["']/)) {
            s = substr(l, RSTART, RLENGTH); sub(/^[^"']*["']/, "", s); sub(/["']$/, "", s); prefix[f] = s
        }
        return
    }
    if (l ~ /^[ \t]*from[ \t]+/) {
        sub(/^[ \t]*from[ \t]+/, "", l)
        mod = l; sub(/[ \t].*$/, "", mod)
        names = l; if (!sub(/^[^ \t]+[ \t]+import[ \t]+/, "", names)) return
        gsub(/[()]/, "", names)
        dots = mod; sub(/[^.].*$/, "", dots); mod = substr(mod, length(dots) + 1)
        n = split(names, NM, ",")
        got = 0
        if (dots != "") {
            base = dirname(f); for (k = 2; k <= length(dots); k++) base = dirname(base)
            s = mod; gsub(/\./, "/", s); base = join(base, s)
            for (i = 1; i <= n; i++) { nm = pyname(NM[i]); if (nm == "" || nm == "*") continue; t = pyfile(join(base, nm)); if (t != "") { rec(f, t); got = 1 } }
            if (!got && mod != "") rec(f, pyfile(base))
            return
        }
        for (i = 1; i <= n; i++) { nm = pyname(NM[i]); if (nm == "" || nm == "*") continue; t = pyabs(f, mod "." nm); if (t != "") { rec(f, t); got = 1 } }
        if (got) return
        t = pyabs(f, mod)
        if (t == "") { t = mod; sub(/\..*$/, "", t); t = "pkg:" t }
        rec(f, t)
        return
    }
    if (l ~ /^[ \t]*import[ \t]+/) {
        sub(/^[ \t]*import[ \t]+/, "", l)
        n = split(l, NM, ",")
        for (i = 1; i <= n; i++) {
            nm = pyname(NM[i]); if (nm == "") continue
            t = pyabs(f, nm)
            if (t == "") { t = nm; sub(/\..*$/, "", t); t = "pkg:" t }
            rec(f, t)
        }
    }
}

# ---- TS／JS：只解析相對路徑與 @/（對應所在套件的 src/）；其餘記成套件名
function jsfile(p,   i, n, X, q) {
    if (p in FS_) return p
    n = split("ts tsx js jsx mjs cjs vue svelte", X, " ")
    for (i = 1; i <= n; i++) if ((p "." X[i]) in FS_) return p "." X[i]
    for (i = 1; i <= 4; i++) if ((p "/index." X[i]) in FS_) return p "/index." X[i]
    if (p ~ /\.js$/) { q = substr(p, 1, length(p) - 3); if ((q ".ts") in FS_) return q ".ts"; if ((q ".tsx") in FS_) return q ".tsx" }
    return ""
}
function jsimp(f, s,   p, P, name, X) {
    if (s ~ /^\.\.?(\/|$)/) p = normpath(join(dirname(f), s))
    else if (s ~ /^@\//) { P = pkgof(f); p = join(join(P, "src"), substr(s, 3)) }
    else {
        if (s ~ /^@/) { split(s, X, "/"); name = X[1] "/" X[2] } else { name = s; sub(/\/.*$/, "", name) }
        if (name ~ /^(@[a-z0-9][^\/]*\/)?[a-z0-9][a-z0-9._-]*$/ || name ~ /^node:/) rec(f, "pkg:" name)
        return
    }
    rec(f, jsfile(p))
}
# ---- 前端 HTTP 呼叫（X6）：fetch('…')／fetch(`…`)／axios.<method>('…') 的路徑常值，留到最後對後端路由。
# fetch 的 method 只看同一行的 `method: '…'`，看不到就不限（多行的 options 很常見）
function jshttp(f, l,   s, m, ms) {
    while (match(l, /(fetch|axios\.(get|post|put|delete|patch))\([ \t]*["'`][^"'`]*["'`]/)) {
        s = substr(l, RSTART, RLENGTH); l = substr(l, RSTART + RLENGTH)
        m = ""
        if (s ~ /^axios\./) { m = s; sub(/^axios\./, "", m); sub(/\(.*$/, "", m) }
        else if (match(l, /method[ \t]*:[ \t]*["'][A-Za-z]+["']/)) { ms = substr(l, RSTART, RLENGTH); sub(/^[^"']*["']/, "", ms); sub(/["']$/, "", ms); m = ms }
        sub(/^[^"'`]*["'`]/, "", s); sub(/["'`]$/, "", s)
        hc[++nh] = f "\t" toupper(m) "\t" s
    }
}
# 路徑正規化：外部網址回空字串；開頭的 `${BASE}` 拿掉；查詢字串拿掉；參數（`${x}`、`{x}`、`<x>`、`:x`）一律 *。
# 前端再去掉 /api 前綴（後端常把它寫在 prefix 裡，也常由反向代理加上；比對是後綴比對，兩種都對得到）
function hnorm(p, front) {
    if (p ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\//) return ""
    sub(/^\$\{[^}]*\}/, "", p); sub(/[?#].*$/, "", p)
    gsub(/\$\{[^}]*\}/, "*", p); gsub(/\{[^}]*\}/, "*", p); gsub(/<[^>]*>/, "*", p); gsub(/\/:[A-Za-z_][A-Za-z0-9_]*/, "/*", p)
    if (front) { if (p ~ /^\/?api$/) p = "/"; else sub(/^\/?api\//, "/", p) }
    return p
}
function hsegs(p, A,   n, i, k, T) { n = split(p, T, "/"); k = 0; for (i = 1; i <= n; i++) if (T[i] != "") A[++k] = T[i]; return k }
# 兩條路徑從尾端逐段對齊（* 對任何段），短的那條整條對上、而且至少有一段是字面相同才算
function hmatch(a, b,   A, B, na, nb, n, i, lit) {
    na = hsegs(a, A); nb = hsegs(b, B); n = na < nb ? na : nb
    if (n == 0) return 0
    lit = 0
    for (i = 0; i < n; i++) {
        if (A[na - i] == "*" || B[nb - i] == "*") continue
        if (A[na - i] != B[nb - i]) return 0
        lit = 1
    }
    return lit
}
function js(f, l,   s, m) {
    jshttp(f, l)
    if (match(l, /^[ \t]*(app|router|server|api)\.(get|post|put|delete|patch)\(/)) {
        m = substr(l, RSTART, RLENGTH - 1); sub(/^.*\./, "", m)
        addroute(f, m, strarg(substr(l, RSTART + RLENGTH)))
        return
    }
    while (match(l, /(from[ \t]*|^[ \t]*import[ \t]*|require\([ \t]*|import\([ \t]*)["'][^"']+["']/)) {
        s = substr(l, RSTART, RLENGTH); l = substr(l, RSTART + RLENGTH)
        sub(/^[^"']*["']/, "", s); sub(/["']$/, "", s)
        jsimp(f, s)
    }
}

# ---- Java／Kotlin：package 宣告建 類別→檔 對照，import 留到最後解析（宣告可能在後面的檔）
function jv(f, l,   s, p) {
    sub(/\/\/.*$/, "", l)
    if (l ~ /^[ \t]*package[ \t]/) {
        s = l; sub(/^[ \t]*package[ \t]+/, "", s); gsub(/[ \t;]/, "", s)
        if (!(s in jpkg)) jpkg[s] = f
        jcls[s "." stem(f)] = f
        return
    }
    if (l ~ /^[ \t]*import[ \t]/) {
        s = l; sub(/^[ \t]*import[ \t]+/, "", s); sub(/^static[ \t]+/, "", s); sub(/[ \t]+as[ \t].*$/, "", s); gsub(/[ \t;]/, "", s)
        jimp[++njimp] = f "\t" s
        return
    }
    if (match(l, /^[ \t]*@(Get|Post|Put|Delete|Patch|Request)Mapping/)) {
        s = substr(l, RSTART, RLENGTH); sub(/^[ \t]*@/, "", s); sub(/Mapping$/, "", s)
        l = substr(l, RSTART + RLENGTH)
        if (match(l, /"[^"]*"/)) p = substr(l, RSTART + 1, RLENGTH - 2); else p = ""
        if (s != "Request") addroute(f, s, p)
        else if (l ~ /RequestMethod\./) { s = l; sub(/^.*RequestMethod\./, "", s); sub(/[^A-Za-z].*$/, "", s); addroute(f, s, p) }
        else prefix[f] = p
    }
}

# ---- C#：namespace 建 namespace→檔 對照，using 留到最後解析
function cs(f, l,   s, p) {
    sub(/\/\/.*$/, "", l)
    if (l ~ /^[ \t]*namespace[ \t]/) {
        s = l; sub(/^[ \t]*namespace[ \t]+/, "", s); sub(/[ \t;{].*$/, "", s)
        if (!(s in csns)) csns[s] = f
        return
    }
    if (l ~ /^[ \t]*using[ \t]/) {
        if (l ~ /^[ \t]*using[ \t]+(var|await)[ \t]/) return
        s = l; sub(/^[ \t]*using[ \t]+/, "", s); sub(/^static[ \t]+/, "", s)
        if (index(s, "=")) sub(/^[^=]*=[ \t]*/, "", s)
        sub(/[ \t]*;.*$/, "", s)
        if (s ~ /^[A-Za-z_][A-Za-z0-9_.]*$/) csimp[++ncs] = f "\t" s
        return
    }
    if (match(l, /^[ \t]*\[(Http(Get|Post|Put|Delete|Patch)|Route)/)) {
        s = substr(l, RSTART, RLENGTH); sub(/^[ \t]*\[(Http)?/, "", s)
        l = substr(l, RSTART + RLENGTH)
        if (match(l, /"[^"]*"/)) p = substr(l, RSTART + 1, RLENGTH - 2); else p = ""
        if (s == "Route") { s = stem(f); sub(/Controller$/, "", s); gsub(/\[controller\]/, s, p); prefix[f] = p }
        else addroute(f, s, p)
    }
}

FNR == NR {
    print
    split($0, T, "\t")
    if (T[1] == "F") { FS_[T[2]] = 1; if (T[2] ~ /\.go$/ && !((d = dirname(T[2])) in gofirst)) gofirst[d] = T[2] }
    else if (T[1] == "P") pkg[T[2]] = 1
    next
}
{
    t1 = index($0, "\t"); if (!t1) next
    f = substr($0, 1, t1 - 1); rest = substr($0, t1 + 1)
    t2 = index(rest, "\t"); if (!t2) next
    l = substr(rest, t2 + 1); sub(/\r$/, "", l)
    if (basename(f) == "go.mod") {
        if (l ~ /^[ \t]*module[ \t]/) { sub(/^[ \t]*module[ \t]+/, "", l); sub(/[ \t]*(\/\/.*)?$/, "", l); gsub(/"/, "", l); gomod[dirname(f)] = l }
        next
    }
    if (!(f in FS_)) next
    e = extof(f)
    if (e == "py") py(f, l)
    else if (e ~ /^(ts|tsx|js|jsx|mjs|cjs|vue|svelte)$/) js(f, l)
    else if (e == "go") goimp[++ngo] = f "\t" l
    else if (e == "java" || e == "kt") jv(f, l)
    else if (e == "cs") cs(f, l)
}
END {
    for (i = 1; i <= ngo; i++) {
        j = index(goimp[i], "\t"); f = substr(goimp[i], 1, j - 1); l = substr(goimp[i], j + 1)
        if (!match(l, /"[^"]+"/)) continue
        s = substr(l, RSTART + 1, RLENGTH - 2); best = "\001"
        for (d in gomod) if ((s == gomod[d] || index(s, gomod[d] "/") == 1) && (best == "\001" || length(gomod[d]) > length(gomod[best]))) best = d
        if (best == "\001") { rec(f, "pkg:" s); continue }
        rel = s == gomod[best] ? "" : substr(s, length(gomod[best]) + 2)
        d = join(best, rel)
        if (d in gofirst) rec(f, gofirst[d])
    }
    for (i = 1; i <= njimp; i++) {
        j = index(jimp[i], "\t"); f = substr(jimp[i], 1, j - 1); s = substr(jimp[i], j + 1)
        if (s ~ /\.\*$/) { s = substr(s, 1, length(s) - 2); t = s in jpkg ? jpkg[s] : "" }
        else { t = s in jcls ? jcls[s] : ""; if (t == "") { p = s; sub(/\.[^.]*$/, "", p); t = p in jcls ? jcls[p] : (p in jpkg ? jpkg[p] : "") } }
        if (t == "") { t = s; sub(/\.[^.]*$/, "", t); t = "pkg:" t }
        rec(f, t)
    }
    for (i = 1; i <= ncs; i++) {
        j = index(csimp[i], "\t"); f = substr(csimp[i], 1, j - 1); s = substr(csimp[i], j + 1)
        rec(f, s in csns ? csns[s] : "pkg:" s)
    }
    for (i = 1; i <= nrf; i++) {
        f = rorder[i]
        for (j = 1; j <= rn[f]; j++) { RF[f, j] = hnorm(joinpath(prefix[f], RP[f, j]), 0); printf "R\t%s\t%s %s\n", f, RM[f, j], joinpath(prefix[f], RP[f, j]) }
    }
    # 前端呼叫 → 後端路由：只連得上唯一一個後端檔才記（後綴比對可能誤連，多個候選就寧可不畫）
    for (i = 1; i <= nh; i++) {
        split(hc[i], H, "\t"); f = H[1]; m = H[2]; p = hnorm(H[3], 1)
        if (p == "") continue
        nc = 0; cand = ""
        for (k = 1; k <= nrf; k++) {
            g = rorder[k]; if (g == f) continue
            for (j = 1; j <= rn[g]; j++) {
                if (m != "" && RM[g, j] != m) continue
                if (hmatch(p, RF[g, j])) { nc++; cand = g; break }
            }
        }
        if (nc == 1 && !((f SUBSEP cand) in hdone)) { hdone[f, cand] = 1; printf "I\t%s\t%s\thttp\n", f, cand }
    }
}
AWK

IFS= read -r -d '' JQ_SKEL <<'JQ'
[inputs | split("\t")] as $L
| ([$L[] | select(.[0] == "N")] | first // ["N", "0", "0"]) as $n
| ($n[1] | tonumber) as $files
| {version: 1,
   scan: {head: (if $head == "" or $head == "(initial)" then null else $head[:7] end),
          files: $files, tests: ($n[2] | tonumber), truncated: $trunc,
          languages: ([$L[] | select(.[0] == "L") | {key: .[1], value: (.[2] | tonumber)}] | sort_by(.key) | from_entries)},
   groups: [$L[] | select(.[0] == "G") | {id: .[1], label: (if .[2] == "" then "根目錄" else .[2] end)}],
   modules: [$L[] | select(.[0] == "M")
             | {id: .[1], name: (if .[1] == "other" then "其他" else .[2] end), dir: .[3], group: .[4],
                fileCount: (.[5] | tonumber), paths: (if .[6] == "" then [] else [.[6]] end)}],
   files: ([$L[] | select(.[0] == "F") | {key: .[1], value: .[2]}] | from_entries),
   imports: [$L[] | select(.[0] == "I") | .[1:4]],
   routes: [$L[] | select(.[0] == "R") | .[1:3]],
   notices: (if $trunc then [{level: "info",
               text: "程式檔 \($files) 個，超過掃描上限 \($maxFiles)：只依目錄切模組，沒有掃 import 與路由（地圖上沒有依賴線）",
               action: "調高 OVERVIEW_SCAN_MAX_FILES"}] else [] end)}
JQ

# ---------------------------------------------------------------- 掃描

# 下面任一步失敗都不寫 key，但 .scan-files 可能已換新：舊 key 配上新的 mtime，下一次會把舊骨架
# 當快取（改動清單裡的檔都不比 .scan-files 新）。先清掉 key（內建，不開行程）
: > "$OUT/.scan-key"
# git 出錯（exit 128）不可吞掉：會寫出沒有檔案或沒有邊的骨架，而且被快取。git grep 只放行 exit 1（沒命中）
set -o pipefail
"${G[@]}" ls-files -z --cached --others --exclude-standard "${PS[@]}" | tr '\0' '\n' \
    | LC_ALL=C awk -v codeext="$OVERVIEW_CODE_EXT" -v roots="$ROOTS" -v depth="$DEPTH" -v maxmod="$MAX_MODULES" "$AWK_LAYOUT" \
    > "$OUT/.scan-files" || exit 1
NFILES=0
IFS=$'\t' read -r _ NFILES _ < "$OUT/.scan-files"
TRUNC=false
[ "${NFILES:-0}" -gt "$MAX_FILES" ] && TRUNC=true

GREP_PS=(--)
for e in $OVERVIEW_CODE_EXT; do GREP_PS+=("*.$e"); done
GREP_PS+=(go.mod '*/go.mod' ':(exclude).claude' ':(exclude)docs')
for e in "${EXCL[@]}"; do [ -n "$e" ] && GREP_PS+=(":(exclude,glob)$e"); done

if [ "$TRUNC" = false ]; then
    { "${G[@]}" grep -z -n -I -E --untracked \
        -e '^[[:space:]]*(from|import|package|namespace|using|module)[[:space:]]' \
        -e '^[[:space:]]*export[[:space:]].*[[:space:]]from[[:space:]]' \
        -e '^[[:space:]]*}[[:space:]]*from[[:space:]]' \
        -e 'require\(' -e 'import\(' \
        -e '^[[:space:]]*([A-Za-z_.][A-Za-z0-9_]*[[:space:]]+)?"[^"]+"[[:space:]]*$' \
        -e '^[[:space:]]*@[A-Za-z_][A-Za-z0-9_.]*\.(get|post|put|delete|patch|route)\(' \
        -e 'APIRouter\(|Blueprint\(' \
        -e '(fetch|axios\.(get|post|put|delete|patch))\(' \
        -e '^[[:space:]]*(app|router|server|api)\.(get|post|put|delete|patch)\(' \
        -e '^[[:space:]]*@(Get|Post|Put|Delete|Patch|Request)Mapping' \
        -e '^[[:space:]]*\[(Http(Get|Post|Put|Delete|Patch)|Route)' \
        "${GREP_PS[@]}" || [ $? -eq 1 ]; } | tr '\0' '\t'
fi | LC_ALL=C awk "$AWK_EDGES" "$OUT/.scan-files" - \
   | LC_ALL=C.UTF-8 jq -R -n -c --arg head "$HEAD" --argjson trunc "$TRUNC" --argjson maxFiles "$MAX_FILES" "$JQ_SKEL" \
   > "$OUT/.skeleton.tmp" || exit 1
set +o pipefail
mv -f "$OUT/.skeleton.tmp" "$OUT/skeleton.json" || exit 1
printf '%s' "$KEY" > "$OUT/.scan-key"
echo scanned
