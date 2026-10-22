#!/bin/bash
# cmd-segments.sh — 把一整條 Bash 指令切成「真的會被執行的 git 指令段」
#
# 為什麼需要：hook 要判斷的是「這條指令**會不會真的執行**某個動作」，
# 不是「這條指令裡**有沒有出現**那幾個字」。用 `case "$CMD" in *"git merge"*)`
# 這種子字串比對，寫文件、寫測試、寫 plan 只要內文提到指令名就命中；
# 唯讀查詢（`git merge-base --is-ancestor`）也會因為前綴相同而被誤判。
#
# 2026-09-11 實測一天誤擋四次，最嚴重的一次是**擋下「修好它自己」的那次編輯**
# （見 context/learned/2026-09-11-gate-blocks-its-own-fix.md）。
#
# 2026-10-16 又一次：commit 訊息用 heredoc 帶，內文一行「衝突的 merge 結束碼非 0」，
# 結果被記成 `[merge] 結束碼非`。當時只靠「段落以 `git ` 開頭」過濾，
# 所以 heredoc／引號內文**只要有一行剛好以 `git ` 開頭**就成了一段假指令；
# 而 `git commit -m "說明 git merge 的用法"` 這種整段都在同一行的，連開頭都不用撞。
# 現在切段前先做兩件事：
#   ① 拿掉 heredoc 內文（`<<[-]['"]WORD['"]` 到單獨一行的 `WORD`）
#   ② 把引號內的內容清空（`"…"` → `""`、`'…'` → `''`），引號本身留著當佔位；
#      同一趟拿掉引號外的 `#` 註解（否則 `# it's broken` 的單引號會吃掉後面整段）
# 兩者之後內文裡的 `&& || ; |` 與換行也不會再把一句話切成好幾段。
#
# 2026-10-16 code review 又補四個「切段讓真的指令消失或多出假指令」的洞（測試在
# run-tests.sh 的「cmd-segments.sh — 切段邊界」節）：註解裡的單引號、`$((1<<x))`
# 被當成 heredoc、`--git-dir <路徑>` 被當成子指令、`<<WORD` 內文縮排的 `  EOF` 提早結束 heredoc。
#
# 這份是 `git-backup-gate.sh`、`post-bash.sh`、`merge-noff-gate.sh`、
# `branch-switch-gate.sh` 的**共用來源**。同一個坑之所以要修第二次，正是因為
# 兩支 hook 各寫各的比對——要改比對邏輯只改這裡，不要在呼叫端各複製一份。
#
# 取捨（有意留下的漏網，方向一律偏「寧可漏抓也不誤擋」）：
#   - `sudo git reset --hard`、`env X=1 git rebase` 會漏抓
#   - 引號沒配對（`echo don't && git merge x`）時，後面整段被當成引號內容清掉 → 漏抓
#   - `"$(git reset --hard)"` 這種包在引號裡的指令替換會漏抓（清空引號的代價）
#   - 引號內出現 `<<WORD` 會被當成 heredoc 開頭，直到單獨一行的 WORD 為止全部略過 → 漏抓
#   - 註解裡出現 `<<WORD` 也一樣（heredoc 剝除在註解處理之前，它不知道那是註解）→ 漏抓
#   - 算術式跨行（`$((1` 換行接 `<< x))`）時，`<<` 仍會被當成 heredoc → 漏抓
#   - `$( … )` 寫在引號外時不追蹤巢狀，裡面的 `#` 照一般規則判斷
# 判準是：**真的要執行時，那一段幾乎一定以 `git ` 開頭，而且不在引號或 heredoc 裡。**
#
# 用法：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/cmd-segments.sh" 2>/dev/null || true
#   declare -F cmd_segments >/dev/null 2>&1 || return 0      # 缺檔就放行
#   segs=$(cmd_segments "$CMD")
#   segs=${CMD_SEGS-$(cmd_segments "$cmd")}                   # 閘門 lib 的寫法：見下
#   [ "$(cmd_git_subcmd "$seg")" = rebase ]                   # 子指令比對用這個
#   cmd_match "$seg" '[[:space:]]--hard([[:space:]]|$)'        # 旗標比對用這個
#
# CMD_SEGS：pre-tool-use.sh 只切**一次**、放進這個變數，四道閘門 lib 都用
# `${CMD_SEGS-$(cmd_segments "$cmd")}` 取（變數有設就用，連空字串也算；lib 單獨跑時自己切）。
# 切一次要開 6 個行程，在 Windows 上約 1 秒；四道各切一次曾讓 `git checkout -b`
# 跑到 12～15 秒，超過 hook 的 timeout——而超時等於放行。

# cmd_match <字串> <ERE> —— 前後補一個空白再比對
# 不用 `[[ =~ ]]` 的 \b：不同 bash／grep 實作對它的支援不一致。
# 補空白讓 '[[:space:]]merge([[:space:]]|$)' 這種前後錨定的樣式能命中字串開頭／結尾，
# 同時確保 `merge-base` 不會被當成 `merge`。
#
# 注意：它看的是**整段任何位置**。拿來判斷子指令會把 `git log --grep merge`
# 當成 merge——判斷子指令請用 cmd_git_subcmd。
#
# 用 bash 內建的 `[[ =~ ]]`（POSIX ERE，與 grep -E 同一套語法）而不是開 grep：
# 這台 Windows 機器開一個行程要 ~170ms，git-backup-gate 一段指令最多比對 8 次，
# 光這裡就吃掉 1 秒多，而 pre-tool-use 的 timeout 是硬上限、超時等於閘門放行。
# 輸入一律是單行的指令段（cmd_segments 的輸出），所以 `$` 只會對到段尾。
cmd_match() {
    local s=" $1 " re="$2"
    [[ $s =~ $re ]]
}

# cmd_strip_heredoc —— stdin → stdout，拿掉 heredoc 內文與結束行，開頭那行保留
# 一行可以開好幾個 heredoc（`cmd <<A <<B`），依序吃掉。
# `<<<`（here-string）不是 heredoc；`$((1<<2))` 的 `<<` 後面是數字，不會被當成 WORD。
# `$((1<<x))`、`((y <<= n))` 是算術位移：`<<` 之前未配對的 `((` 多於 `))` 就跳過
# （只看同一行；跨行的算術式會漏，方向是「漏剝 heredoc」，而 heredoc 內文本來就很少以 `git ` 開頭）。
# 結束行照 bash 的規則一字不差比對：只有 `<<-WORD` 允許行首 **tab**（不是空白），
# 一般 `<<WORD` 內文裡縮排的 `  EOF` 不算結束——以前兩種都去掉行首空白，heredoc 提早結束，
# 剩下的內文變成假的指令段。行尾只去 `\r`（CRLF 的殘留）。
cmd_strip_heredoc() {
    awk '
    function arith_open(s,   o, c) {
        o = gsub(/\(\(/, "", s); c = gsub(/\)\)/, "", s)
        return o - c
    }
    {
        if (nw > 0) {
            line = $0
            sub(/\r$/, "", line)
            if (dash[wi]) sub(/^\t+/, "", line)
            if (line == w[wi]) { wi++; if (wi > nw) { nw = 0; wi = 0 } }
            next
        }
        print
        s = $0; off = 0
        while (match(substr(s, off + 1), /<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
            pos = off + RSTART; len = RLENGTH; off = pos + len - 1
            prev = (pos > 1) ? substr(s, pos - 1, 1) : ""
            if (prev == "<") continue
            if (arith_open(substr(s, 1, pos - 1)) > 0) continue
            tok = substr(s, pos, len)
            word = tok
            sub(/^<<-?[ \t]*/, "", word); gsub(/["\047]/, "", word)
            if (word != "") { if (nw == 0) wi = 1; w[++nw] = word; dash[nw] = (substr(tok, 3, 1) == "-") }
        }
    }'
}

# cmd_mask_quotes —— stdin → stdout，引號內容清空，引號本身留下
# 雙引號裡的 `$( … )` 會追蹤巢狀，所以 `"$(cat "$f")"` 整串視為同一個引號。
# 跨行的引號字串整段消失（換行也一起），內文不會再被切成新的一段。
cmd_mask_quotes() {
    awk '
    BEGIN { q = "\047"; RS = "\001" }
    {
        s = $0; out = ""; st = ""
        for (i = 1; i <= length(s); i++) {
            c = substr(s, i, 1); top = substr(st, length(st), 1)
            if (st == "") {
                if (c == "\\") { out = out c substr(s, i + 1, 1); i++; continue }
                # 引號外、字的開頭的 `#` 是註解：拿掉到行尾（換行留著）。不先拿掉的話，
                # 註解裡的單引號（英文縮寫）會被當成引號開頭，後面整段指令一起被遮掉。
                # 「字的開頭」＝行首或前一個字元是空白／`;&|()`——所以 `$#`、`${#a}`、
                # `http://x/#top`、`a#b` 都不是註解（與 bash 相同）。
                if (c == "#" && (i == 1 || index(" \t\n;&|()", substr(s, i - 1, 1)) > 0)) {
                    j = index(substr(s, i), "\n")
                    if (j == 0) break
                    i = i + j - 2; continue
                }
                if (c == q || c == "\"") { st = c; out = out c; continue }
                out = out c; continue
            }
            if (top == q) {
                if (c == q) { st = substr(st, 1, length(st) - 1); if (st == "") out = out c }
            } else if (top == "\"") {
                if (c == "\\") i++
                else if (c == "\"") { st = substr(st, 1, length(st) - 1); if (st == "") out = out c }
                else if (c == "$" && substr(s, i + 1, 1) == "(") { st = st "("; i++ }
            } else if (top == "(") {
                if (c == "(") st = st "("
                else if (c == ")") st = substr(st, 1, length(st) - 1)
                else if (c == "\"" || c == q) st = st c
            }
        }
        printf "%s", out
    }'
}

# git 的全域選項（awk 函式，cmd_segments 與 cmd_git_subcmd 共用）——回傳子指令所在的欄位
#   值放在下一個字的：-C -c --git-dir --work-tree --namespace --config-env --attr-source --super-prefix
#   （`--git-dir=/x` 這種值寫在同一個字的，走「其他 `-` 開頭的跳一個字」）
#   印完就結束、後面的字都不會執行的：--exec-path --html-path --man-path --info-path
#   --version --help --list-cmds=…（git 2.53 實測 `git --exec-path status` 只印路徑）→ 回傳 NF+1（沒有子指令）
_CMD_GIT_SUBCMD_AWK='
function git_sub_index(   i) {
    i = 2
    while (i <= NF) {
        if ($i ~ /^(-C|-c|--git-dir|--work-tree|--namespace|--config-env|--attr-source|--super-prefix)$/) { i += 2; continue }
        if ($i ~ /^--(exec-path|html-path|man-path|info-path|version|help)$/ || $i ~ /^--list-cmds=/) return NF + 1
        if ($i ~ /^-/) { i++; continue }
        break
    }
    return i
}'

# cmd_segments <整條指令> —— 取出「以 git 開頭的指令段」（一行一段）
# 輸出的每一段已經拿掉 git 的全域選項（`-C <路徑>`、`--git-dir <路徑>`、`-c <k=v>`、`--no-pager`…），
# 所以第二個字一定是子指令：`git -C /x merge y` → `git merge y`。字與字之間正規化成一個空白。
cmd_segments() {
    printf '%s\n' "$1" \
        | cmd_strip_heredoc \
        | cmd_mask_quotes \
        | sed -e 's/&&/\n/g' -e 's/||/\n/g' -e 's/[;|]/\n/g' \
        | sed -e 's/^[[:space:]]*[({][[:space:]]*//' -e 's/^[[:space:]]*//' \
        | grep -E '^git[[:space:]]' \
        | awk "$_CMD_GIT_SUBCMD_AWK"'
        {
            i = git_sub_index()
            out = "git"; for (; i <= NF; i++) out = out " " $i
            print out
        }'
}

# cmd_git_subcmd <段落> —— 印出子指令（`git` 之後第一個非選項字）
# 段落應該來自 cmd_segments；自己傳未正規化的字串進來也照樣跳過全域選項。
cmd_git_subcmd() {
    printf '%s\n' "$1" | awk "$_CMD_GIT_SUBCMD_AWK"'
    {
        if ($1 != "git") exit
        i = git_sub_index()
        if (i <= NF) print $i
        exit
    }'
}
