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
#   ② 把引號內的內容清空（`"…"` → `""`、`'…'` → `''`），引號本身留著當佔位
# 兩者之後內文裡的 `&& || ; |` 與換行也不會再把一句話切成好幾段。
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
# 判準是：**真的要執行時，那一段幾乎一定以 `git ` 開頭，而且不在引號或 heredoc 裡。**
#
# 用法：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/cmd-segments.sh" 2>/dev/null || true
#   declare -F cmd_segments >/dev/null 2>&1 || return 0      # 缺檔就放行
#   segs=$(cmd_segments "$CMD")
#   [ "$(cmd_git_subcmd "$seg")" = rebase ]                   # 子指令比對用這個
#   cmd_match "$seg" '[[:space:]]--hard([[:space:]]|$)'        # 旗標比對用這個

# cmd_match <字串> <ERE> —— 前後補一個空白再比對
# 不用 `[[ =~ ]]` 的 \b：不同 bash／grep 實作對它的支援不一致。
# 補空白讓 '[[:space:]]merge([[:space:]]|$)' 這種前後錨定的樣式能命中字串開頭／結尾，
# 同時確保 `merge-base` 不會被當成 `merge`。
#
# 注意：它看的是**整段任何位置**。拿來判斷子指令會把 `git log --grep merge`
# 當成 merge——判斷子指令請用 cmd_git_subcmd。
cmd_match() {
    printf '%s' " $1 " | grep -qE "$2"
}

# cmd_strip_heredoc —— stdin → stdout，拿掉 heredoc 內文與結束行，開頭那行保留
# 一行可以開好幾個 heredoc（`cmd <<A <<B`），依序吃掉。
# `<<<`（here-string）不是 heredoc；`$((1<<2))` 的 `<<` 後面是數字，不會被當成 WORD。
cmd_strip_heredoc() {
    awk '
    BEGIN { q = "\047"; dq = "\"" }
    {
        if (nw > 0) {
            line = $0
            sub(/^[ \t]+/, "", line); sub(/[ \t\r]+$/, "", line)
            if (line == w[wi]) { wi++; if (wi > nw) { nw = 0; wi = 0 } }
            next
        }
        print
        rest = $0; base = 0
        while (match(rest, /<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
            pos = RSTART; len = RLENGTH
            prev = (pos > 1) ? substr(rest, pos - 1, 1) : ""
            tok = substr(rest, pos, len)
            rest = substr(rest, pos + len)
            if (prev == "<") continue
            word = tok
            sub(/^<<-?[ \t]*/, "", word); gsub(/["\047]/, "", word)
            if (word != "") { if (nw == 0) wi = 1; w[++nw] = word }
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

# cmd_segments <整條指令> —— 取出「以 git 開頭的指令段」（一行一段）
# 輸出的每一段已經拿掉 git 的全域選項（`-C <路徑>`、`-c <k=v>`、`--no-pager`…），
# 所以第二個字一定是子指令：`git -C /x merge y` → `git merge y`。
cmd_segments() {
    printf '%s\n' "$1" \
        | cmd_strip_heredoc \
        | cmd_mask_quotes \
        | sed -e 's/&&/\n/g' -e 's/||/\n/g' -e 's/[;|]/\n/g' \
        | sed -e 's/^[[:space:]]*[({][[:space:]]*//' -e 's/^[[:space:]]*//' \
        | grep -E '^git[[:space:]]' \
        | awk '{
            n = split($0, t, /[ \t]+/); i = 2
            while (i <= n) {
                if (t[i] == "-C" || t[i] == "-c") { i += 2; continue }
                if (t[i] ~ /^-/) { i++; continue }
                break
            }
            out = "git"; for (; i <= n; i++) out = out " " t[i]
            print out
        }'
}

# cmd_git_subcmd <段落> —— 印出子指令（`git` 之後第一個非選項字）
# 段落應該來自 cmd_segments；自己傳未正規化的字串進來也照樣跳過全域選項。
cmd_git_subcmd() {
    printf '%s\n' "$1" | awk '{
        if ($1 != "git") exit
        i = 2
        while (i <= NF) {
            if ($i == "-C" || $i == "-c") { i += 2; continue }
            if ($i ~ /^-/) { i++; continue }
            break
        }
        if (i <= NF) print $i
        exit
    }'
}
