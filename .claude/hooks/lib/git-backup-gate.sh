#!/bin/bash
# git-backup-gate.sh — destructive git 操作前必須有安全快照（供 pre-tool-use.sh source）
#
# 為什麼需要：`git reset --hard`／`git push --force`／`git branch -D`／`git rebase`
# 這四種指令會讓一段 commit 失去所有 ref。撿回來的手段只有 reflog，而 reflog 是
# 「通常還在」不是「保證還在」——90 天過期、每個 worktree 各有自己一份、
# gc 之後就沒了。而且模型執行這些指令時**不會覺得自己在冒險**：它剛剛才產生那段
# 歷史，所以「弄丟」不在它的想像裡。
#
# 打一個 tag 是兩秒鐘的事，純機械動作、零判斷 —— 正是該由閘門強制而不是寫成
# 文字規則的形狀（rules/git-workflow.md 第 3 條只寫「這條由本閘門強制」）。
#
# 判準（單一規則，四種指令一致）：**當前 HEAD 有 `backup/*` tag 指著 → 放行**。
# 不比對 tag 名稱裡的分支，因為快照的保護力來自「這個 oid 有 ref 指著它」，
# 跟 tag 叫什麼無關；比對分支名只會在 `feat/x` 這種帶斜線的分支上誤擋。
#
# **刻意沒有 deny-once。** 坑閘門與平行 agent 閘門擋一次就放行（它們要傳達的是
# 資訊），這一條擋的是「還沒有快照」這個**狀態**——放行一次就等於沒有閘門。
# 正確的循環是：擋 → 打 tag → 重試 → 通過。
#
# 逃生門：GIT_BACKUP_GATE=off
# `.suggest-mode` = off 由 pre-tool-use.sh 在呼叫本函式**之前**處理（它讀 MAIN_CLAUDE，
# 因為 /suggest-mode 是專案級設定），所以本檔不重複讀。
#
# 用法（pre-tool-use.sh 內，確定是 Bash 工具且取得 COMMAND 之後）：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/git-backup-gate.sh"
#   git_backup_gate "$COMMAND" "$WORK_ROOT"   # 命中時自行輸出 deny JSON 並 exit 0

# 指令切段與樣式比對是 `lib/cmd-segments.sh`（cmd_segments／cmd_match）——
# 為什麼不用 merge-gate 那種子字串比對，以及有意留下的漏網取捨，都寫在那支檔案裡。
# post-bash.sh 的合併偵測用的是**同一份**：同一個坑修過兩次，就是因為當初兩邊各寫各的。
source "$(dirname "${BASH_SOURCE[0]}")/cmd-segments.sh" 2>/dev/null || true

git_backup_gate() {
    local cmd="$1" root="$2"
    [ "${GIT_BACKUP_GATE:-on}" = "off" ] && return 0
    [ -n "$cmd" ] || return 0

    # 缺共用切段函式就放行 —— 與本閘門其他「判斷不了就放行」的分支一致
    declare -F cmd_segments >/dev/null 2>&1 || return 0

    local segs
    segs=$(cmd_segments "$cmd")
    [ -n "$segs" ] || return 0

    local kind="" seg
    while IFS= read -r seg; do
        [ -n "$seg" ] || continue

        # --continue / --abort / --skip / --quit / --edit-todo 是在收拾**當前**狀態，
        # 不是新的 destructive 操作。照 merge-gate.sh 既有的做法排除。
        cmd_match "$seg" '[[:space:]]--(continue|abort|skip|quit|edit-todo)([[:space:]]|$)' && continue

        if cmd_match "$seg" '[[:space:]]reset([[:space:]]|$)' \
           && cmd_match "$seg" '[[:space:]]--hard([[:space:]]|$)'; then
            kind="git reset --hard"; break
        elif cmd_match "$seg" '[[:space:]]push([[:space:]]|$)' \
           && cmd_match "$seg" '[[:space:]](-f|--force|--force-with-lease|--force-if-includes)([[:space:]=]|$)'; then
            kind="git push --force"; break
        elif cmd_match "$seg" '[[:space:]]branch([[:space:]]|$)' \
           && cmd_match "$seg" '[[:space:]](-[a-zA-Z]*D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)([[:space:]]|$)'; then
            kind="git branch -D"; break
        elif cmd_match "$seg" '[[:space:]]rebase([[:space:]]|$)'; then
            kind="git rebase"; break
        fi
    done <<< "$segs"

    [ -n "$kind" ] || return 0

    # 判斷不了就放行 —— 與本模板其他閘門一致（缺依賴時寧可放行也不誤擋）
    command -v git >/dev/null 2>&1 || return 0
    command -v jq  >/dev/null 2>&1 || return 0
    [ -n "$root" ] || return 0
    git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 0

    # 空 repo（unborn HEAD）沒有東西可弄丟
    git -C "$root" rev-parse --verify --quiet HEAD >/dev/null 2>&1 || return 0

    # 已有 backup tag 指著當前 HEAD → 快照有效，放行
    local snap
    snap=$(git -C "$root" tag --points-at HEAD --list 'backup/*' 2>/dev/null | head -1)
    [ -n "$snap" ] && return 0

    local branch tag short extra=""
    branch=$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=""
    [ -n "$branch" ] || branch="detached"
    tag="backup/${branch}-$(date '+%Y-%m-%d-%H%M')"
    short=$(git -C "$root" rev-parse --short HEAD 2>/dev/null)

    # force push 覆蓋的是**遠端**那段歷史，本地 HEAD 的 tag 保不到它
    case "$kind" in
        "git push --force")
            extra="另外：tag 保的是你本地的 HEAD。force push 真正覆蓋掉的是**遠端**那一段，要保住它得另外打一個：\`git tag backup/upstream-$(date '+%Y-%m-%d-%H%M') @{upstream}\`" ;;
    esac

    jq -n --arg kind "$kind" --arg tag "$tag" --arg short "$short" --arg extra "$extra" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("⛔ 這是 destructive 操作（`" + $kind + "`），而當前 HEAD **沒有任何安全快照**。\n\n**為什麼擋**：這條指令會讓一段 commit 失去所有 ref。撿回來只剩 reflog，而 reflog 是「通常還在」不是「保證還在」——90 天過期、每個 worktree 各有一份、gc 之後就沒了。打一個 tag 是兩秒鐘的事。\n\n**照這個做（可直接複製）：**\n\n1. `git tag " + $tag + " " + $short + "`\n2. 重試**同一條指令**（有 tag 指向 HEAD 時本閘門自動放行）\n3. 確認結果沒問題之後再刪：`git tag -d " + $tag + "`\n\n`--force-with-lease` **不例外**——它防的是覆蓋別人的 push，不是防你弄丟自己的工作，兩者是不同的事。" + (if $extra == "" then "" else "\n\n" + $extra end) + "\n\n（本閘門沒有「擋一次就過」：它擋的是「還沒有快照」這個狀態，放行一次等於沒有閘門。確實不需要快照時：GIT_BACKUP_GATE=off）")
      }
    }' 2>/dev/null || true
    exit 0
}
