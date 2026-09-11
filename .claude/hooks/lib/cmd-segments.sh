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
# 這份是 `git-backup-gate.sh` 與 `post-bash.sh` 的**共用來源**。
# 同一個坑之所以要修第二次，正是因為兩支 hook 各寫各的比對——
# 要改比對邏輯只改這裡，不要在呼叫端各複製一份。
#
# 取捨（有意留下的漏網，與原 `_gbg_segments` 一致）：
#   - `sudo git reset --hard`、`env X=1 git rebase` 會漏抓
#   - 文件裡**整行只有指令本身**（行首就是 `git ...`）仍會誤抓
#   - 引號／heredoc 內文的 `&& || ; |` 也被當分隔符切開——切碎只會讓段落更難命中，
#     方向偏保守（寧可漏抓也不誤擋），與本模板其他閘門的「判斷不了就放行」一致
# 判準是：**真的要執行時，那一段幾乎一定以 `git ` 開頭。**
#
# 用法：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/cmd-segments.sh" 2>/dev/null || true
#   declare -F cmd_segments >/dev/null 2>&1 || return 0      # 缺檔就放行
#   segs=$(cmd_segments "$CMD")
#   cmd_match "$seg" '[[:space:]]rebase([[:space:]]|$)'

# cmd_match <字串> <ERE> —— 前後補一個空白再比對
# 不用 `[[ =~ ]]` 的 \b：不同 bash／grep 實作對它的支援不一致。
# 補空白讓 '[[:space:]]merge([[:space:]]|$)' 這種前後錨定的樣式能命中字串開頭／結尾，
# 同時確保 `merge-base` 不會被當成 `merge`。
cmd_match() {
    printf '%s' " $1 " | grep -qE "$2"
}

# cmd_segments <整條指令> —— 取出「以 git 開頭的指令段」（一行一段）
cmd_segments() {
    printf '%s\n' "$1" \
        | sed -e 's/&&/\n/g' -e 's/||/\n/g' -e 's/[;|]/\n/g' \
        | sed -e 's/^[[:space:]]*[({][[:space:]]*//' -e 's/^[[:space:]]*//' \
        | grep -E '^git[[:space:]]'
}
