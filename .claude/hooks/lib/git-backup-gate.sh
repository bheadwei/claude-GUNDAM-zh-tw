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
# 判準：**會失去 ref 的那個 commit 有 `backup/*` tag 指著 → 放行**。
# 不比對 tag 名稱裡的分支，因為快照的保護力來自「這個 oid 有 ref 指著它」，
# 跟 tag 叫什麼無關；比對分支名只會在 `feat/x` 這種帶斜線的分支上誤擋。
# 「那個 commit」通常是當前 HEAD，兩個例外（2026-10-20 修，以前一律看 HEAD）：
#   - `branch -D <b>` 看 **<b> 的 tip**——站在 main 上刪 feat/x，HEAD 有沒有 tag 與它無關
#   - `reset --hard` 沒帶目標（或目標是 HEAD）：HEAD 不動，沒有 commit 會失去 ref。
#     工作區乾淨 → 放行；有未 commit 的改動 → 擋，並講實話：tag 救不到它們
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
declare -F cmd_segments >/dev/null 2>&1 || source "${BASH_SOURCE[0]%/*}/cmd-segments.sh" 2>/dev/null || true

git_backup_gate() {
    local cmd="$1" root="$2"
    [ "${GIT_BACKUP_GATE:-on}" = "off" ] && return 0
    [ -n "$cmd" ] || return 0

    # 缺共用切段函式就放行 —— 與本閘門其他「判斷不了就放行」的分支一致
    declare -F cmd_segments >/dev/null 2>&1 || return 0

    local segs
    segs=${CMD_SEGS-$(cmd_segments "$cmd")}
    [ -n "$segs" ] || return 0

    # kind 之外還要記「這一段的參數」：branch -D 要知道刪哪條、reset --hard 要知道
    # 有沒有指定目標。參數從 cmd_segments 正規化過的段落取（第 3 個字起），
    # 引號內容已清空、全域選項已拿掉。
    local kind="" seg args=""
    while IFS= read -r seg; do
        [ -n "$seg" ] || continue

        # --continue / --abort / --skip / --quit / --edit-todo 是在收拾**當前**狀態，
        # 不是新的 destructive 操作。照 merge-gate.sh 既有的做法排除。
        cmd_match "$seg" '[[:space:]]--(continue|abort|skip|quit|edit-todo)([[:space:]]|$)' && continue

        if cmd_match "$seg" '[[:space:]]reset([[:space:]]|$)' \
           && cmd_match "$seg" '[[:space:]]--hard([[:space:]]|$)'; then
            kind="git reset --hard"
        elif cmd_match "$seg" '[[:space:]]push([[:space:]]|$)' \
           && cmd_match "$seg" '[[:space:]](-f|--force|--force-with-lease|--force-if-includes)([[:space:]=]|$)'; then
            kind="git push --force"
        elif cmd_match "$seg" '[[:space:]]branch([[:space:]]|$)' \
           && cmd_match "$seg" '[[:space:]](-[a-zA-Z]*D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)([[:space:]]|$)'; then
            kind="git branch -D"
        elif cmd_match "$seg" '[[:space:]]rebase([[:space:]]|$)'; then
            kind="git rebase"
        fi
        if [ -n "$kind" ]; then
            args="${seg#git }"; args="${args#* }"
            [ "$args" = "${seg#git }" ] && args=""     # 子指令後面沒有東西
            break
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

    # 非選項的參數（token 切分關掉 glob，理由同 merge-noff-gate.sh）
    local restore_f=0 tok positional=""
    case "$-" in *f*) ;; *) restore_f=1; set -f ;; esac
    for tok in $args; do
        case "$tok" in --|-*) continue ;; esac
        positional="${positional:+$positional }$tok"
    done
    [ "$restore_f" -eq 1 ] && set +f

    # ---- 被保護的對象（target）：預設是 HEAD，兩種情況例外 ----
    #
    # `branch -D <b>`：會失去 ref 的是 **<b> 的 tip**，不是你站的 HEAD。
    # 以前一律看 HEAD——站在 main 上刪 feat/x，HEAD 有沒有 tag 跟 feat/x 弄不弄丟毫無關係，
    # 照著訊息打的 tag 也保錯了東西。多條時逐條看，第一條沒有快照的就擋。
    # 分支不存在 → 放行，讓 git 自己報錯（沒有東西可弄丟）。
    # 但「不存在」只對乾淨的字面名成立：cmd_segments 把引號內容清成 `""`，`$B`、`$(…)`、
    # glob 也不是真實分支名——查不到不代表不存在。任一 token 不是字面名 → 退回看 HEAD
    # （2026-10-21：`git branch -D "feat/x"` 曾因此整個放行）。
    #
    # `reset --hard` **沒帶目標（或目標是 HEAD／@）**：HEAD 不會動，沒有 commit 會失去 ref；
    # 真正會消失的是**未 commit 的改動**，而 tag 救不到它們。所以：工作區乾淨 → 放行
    # （這條指令什麼都不會弄丟）；有改動 → 換一則講實話的訊息。
    local target="HEAD" target_label="當前 HEAD"
    case "$kind" in
        "git branch -D")
            case "$positional" in
                *[\"\'\$\*\?\[\(\)\`\{\}\\]*)
                    target_label="當前 HEAD（分支名不是字面值——引號、變數或指令替換——判斷不了要刪的是哪條，退回看 HEAD）"
                    ;;
                *)
                    local b found_unprotected=""
                    for b in $positional; do
                        git -C "$root" rev-parse --verify --quiet "refs/heads/$b" >/dev/null 2>&1 || continue
                        if [ -z "$(git -C "$root" tag --points-at "refs/heads/$b" --list 'backup/*' 2>/dev/null | head -1)" ]; then
                            found_unprotected="$b"; break
                        fi
                    done
                    [ -n "$found_unprotected" ] || return 0
                    target="$found_unprotected"; target_label="分支 \`$found_unprotected\` 的 tip"
                    ;;
            esac
            ;;
        "git reset --hard")
            local rt="${positional%% *}"
            case "$rt" in
                ""|HEAD|@)
                    local dirty
                    dirty=$(git -C "$root" status --porcelain --untracked-files=no 2>/dev/null | head -1)
                    [ -n "$dirty" ] || return 0
                    jq -n '{
                      hookSpecificOutput: {
                        hookEventName: "PreToolUse",
                        permissionDecision: "deny",
                        permissionDecisionReason: ("⛔ `git reset --hard`（沒帶目標）會**丟掉工作區裡所有未 commit 的改動**。\n\n**backup tag 救不到這些**：tag 指的是 commit，而這些改動還不在任何 commit 裡。HEAD 本身不會動，所以打 tag 重試是沒有意義的——本閘門這個情況不看 tag。\n\n**照這個順序想：**\n\n1. 這些改動要留嗎？要 → 先 commit（WIP commit 也行，之後 `git reset --soft HEAD~1` 拆回來）\n2. 確定要丟 → **先跟使用者確認**是哪些檔案、確定不要了，再設 `GIT_BACKUP_GATE=off` 重跑\n3. 想用 `git stash` 頂替 → 一樣先跟使用者確認。stash 沒有名字、沒有歷史，下一次 stash 就疊上去，它是臨時挪開，不是保存\n\n看清楚會丟什麼：`git status --short`、`git diff --stat`\n\n（工作區乾淨時本閘門直接放行——那時這條指令什麼都不會弄丟。關閉：GIT_BACKUP_GATE=off）")
                      }
                    }' 2>/dev/null || true
                    exit 0
                    ;;
            esac
            ;;
    esac

    # 已有 backup tag 指著被保護的對象 → 快照有效，放行
    local snap
    snap=$(git -C "$root" tag --points-at "$target" --list 'backup/*' 2>/dev/null | head -1)
    [ -n "$snap" ] && return 0

    local branch tag short extra=""
    if [ "$target" = "HEAD" ]; then
        branch=$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=""
        [ -n "$branch" ] || branch="detached"
    else
        branch="$target"
    fi
    tag="backup/${branch}-$(date '+%Y-%m-%d-%H%M')"
    short=$(git -C "$root" rev-parse --short "$target" 2>/dev/null)

    # force push 覆蓋的是**遠端**那段歷史，本地 HEAD 的 tag 保不到它
    case "$kind" in
        "git push --force")
            extra="另外：tag 保的是你本地的 HEAD。force push 真正覆蓋掉的是**遠端**那一段，要保住它得另外打一個：\`git tag backup/upstream-$(date '+%Y-%m-%d-%H%M') @{upstream}\`" ;;
        "git branch -D")
            # 建議指令直接寫分支名，不寫短 SHA：讀的人一眼看得出保的是哪條
            short="$target" ;;
    esac

    jq -n --arg kind "$kind" --arg tag "$tag" --arg short "$short" --arg extra "$extra" --arg tl "$target_label" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("⛔ 這是 destructive 操作（`" + $kind + "`），而" + $tl + " **沒有任何安全快照**。\n\n**為什麼擋**：這條指令會讓一段 commit 失去所有 ref。撿回來只剩 reflog，而 reflog 是「通常還在」不是「保證還在」——90 天過期、每個 worktree 各有一份、gc 之後就沒了。打一個 tag 是兩秒鐘的事。\n\n**照這個做（可直接複製）：**\n\n1. `git tag " + $tag + " " + $short + "`\n2. 重試**同一條指令**（有 backup tag 指著它時本閘門自動放行）\n3. 確認結果沒問題之後再刪：`git tag -d " + $tag + "`\n\n`--force-with-lease` **不例外**——它防的是覆蓋別人的 push，不是防你弄丟自己的工作，兩者是不同的事。" + (if $extra == "" then "" else "\n\n" + $extra end) + "\n\n（本閘門沒有「擋一次就過」：它擋的是「還沒有快照」這個狀態，放行一次等於沒有閘門。確實不需要快照時：GIT_BACKUP_GATE=off）")
      }
    }' 2>/dev/null || true
    exit 0
}
