#!/bin/bash
# branch-switch-gate.sh — 站在 topic 分支上不得直接開新分支（供 pre-tool-use.sh source）
#
# 為什麼需要（真實事故，2026-09-17）：主 checkout 站在 `fix/stream-token-ledger` 上，
# 一個 subagent 正在那條分支上工作。此時要開第二個任務，模型的第一反應是「不能平行」，
# 被使用者追問後才講出真正的原因：
#
#   檔案確實零衝突——但擋住的不是檔案衝突，是**一個 checkout 同時只能站一個分支**。
#   那個 agent 此刻就站在這個 checkout 的 `fix/...` 上，`git checkout -b` 會把它
#   腳下的分支抽掉，它接著寫檔／commit 就落到錯的分支。
#
# **模型講得出這個危險，但是在被推了之後。** 沒有任何機制在它真的要打那條指令時
# 攔下來——正是 writing-extensions 決策表第一列的形狀（判斷得出時機就別靠自律）。
#
# 第二個情境沒有 agent 也成立：切到 topic 分支之後，遇到新任務**不會想到要切回
# 預設分支再開**，於是新分支的基底混進了前一個任務的 commit。rules/git-workflow.md
# 第 1 條要的是「先開分支再寫程式」，但它三種要停下來問的情況**全部假設只有一個
# 工作者**，沒有涵蓋這兩種。
#
# 判準（三格，依序）：
#   放行 — 當前分支 = 預設分支：正常流程，這正是 git-workflow.md 第 1 條要的
#   放行 — 指令自己帶了 start-point（`git checkout -b x main`）**且**沒有
#          in-flight agent：基底已明確表達，那本來就是本閘門推薦的繞法
#   擋   — 當前分支 ≠ 預設分支 **且** 有 in-flight agent：你會把它腳下的分支抽掉
#   擋一次 — 當前分支 ≠ 預設分支、沒有 in-flight agent：新分支的基底會是這條
#          topic 分支，獨立任務該從預設分支開
#
# **有 in-flight agent 那一格刻意不套用 deny-once**，其餘那一格套用。
# 判準沿用 git-backup-gate.sh 檔頭對兩種閘門的區分：擋「狀態」的放行一次就等於
# 沒有閘門（那個 agent 還站在那裡，重試一次它照樣被抽掉）；擋「資訊」的只是要
# 把話講一次，講完就該讓路。deny-once 的標記記的是**分支名**，換一條 topic 分支
# 會再擋一次——那是一個新的現場，不是同一件事。
#
# 第一格（站在預設分支）**即使有 in-flight agent 也放行**。嚴格說那時 HEAD 一樣
# 會被搬走，但「從預設分支開一條新分支」是本模板的主流程（git-workflow.md 第 1 條、
# /task-next、/pr 全都走這條），擋它等於擋掉正常開發。這個閘門要處理的是站錯地方
# 那一類，不是把所有 checkout 都變成要解釋的事。
#
# 「預設分支」不寫死 `main`：origin/HEAD → init.defaultBranch → 本地有沒有
# main/master，三層都問不出來就**放行**（沿用本模板所有閘門「判斷不了就放行」）。
#
# 本閘門判斷不了的兩件事（寫在這裡也寫進攔截訊息，不要假裝它們不存在）：
#   1. **subagent 自己打這條指令時，in-flight 的計數包含它自己。** PreToolUse 的
#      payload 分不出「誰在打」，所以那一格會顯示 1 而那 1 就是你。結論仍然成立
#      （subagent 在共用 checkout 裡換分支本來就該改用 worktree），但數字的歸屬
#      不精確——訊息裡明講，不要讓人以為閘門知道它不知道的事。
#   2. detached HEAD 一律放行：從那裡開分支通常正是在救回東西。
#
# 逃生門：BRANCH_SWITCH_GATE=off
# `.suggest-mode` = off 由 pre-tool-use.sh 在呼叫本函式之前處理，本檔不重複讀。
#
# 用法（pre-tool-use.sh 內，確定是 Bash 工具且取得 COMMAND 之後）：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/branch-switch-gate.sh"
#   branch_switch_gate "$COMMAND" "$WORK_ROOT" "$MAIN_CLAUDE" "$DATA_DIR"

# 指令切段一律走共用實作。子字串比對會把文件內文、以及 `git checkout -- file`
# 這種還原檔案的用法誤判——原因與取捨都寫在 cmd-segments.sh 檔頭。
source "$(dirname "${BASH_SOURCE[0]}")/cmd-segments.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/agent-inflight.sh" 2>/dev/null || true

# _bsg_default_branch <root> —— 印出預設分支名；問不出來印空字串
_bsg_default_branch() {
    local root="$1" b=""

    # 1. 遠端告訴我們的（最可信）。`origin/main` → `main`
    b=$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
    b="${b#origin/}"
    [ -n "$b" ] && { printf '%s' "$b"; return 0; }

    # 2. 使用者自己設的慣例。**要求本地真的有這條分支**——init.defaultBranch 講的是
    #    「新 repo 預設叫什麼」，不保證這個 repo 就長這樣。
    b=$(git -C "$root" config --get init.defaultBranch 2>/dev/null)
    if [ -n "$b" ] && git -C "$root" show-ref --verify --quiet "refs/heads/$b" 2>/dev/null; then
        printf '%s' "$b"; return 0
    fi

    # 3. 退回慣例值。兩條都沒有 → 印空字串，呼叫端放行
    for b in main master; do
        git -C "$root" show-ref --verify --quiet "refs/heads/$b" 2>/dev/null && { printf '%s' "$b"; return 0; }
    done
    printf ''
}

branch_switch_gate() {
    local cmd="$1" root="$2" main_claude="$3" data_dir="$4"
    [ "${BRANCH_SWITCH_GATE:-on}" = "off" ] && return 0
    [ -n "$cmd" ] || return 0

    # 缺共用切段函式就放行 —— 與本模板其他閘門一致
    declare -F cmd_segments >/dev/null 2>&1 || return 0
    command -v jq  >/dev/null 2>&1 || return 0
    command -v git >/dev/null 2>&1 || return 0
    [ -n "$root" ] || return 0
    git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 0

    local segs
    segs=$(cmd_segments "$cmd")
    [ -n "$segs" ] || return 0

    # token 切分用 shell word splitting，關掉 glob：指令裡的 `*` 不該被展開成檔名
    local restore_f=0
    case "$-" in *f*) ;; *) restore_f=1; set -f ;; esac

    local seg hit="" new_branch="" start_point=""
    while IFS= read -r seg; do
        [ -n "$seg" ] || continue

        # 引號字串換成單一佔位 token，理由同 merge-noff-gate.sh：
        # `git commit -m "改用 git checkout -b"` 的訊息內容不該被當成旗標或分支名
        local stripped
        stripped=$(printf '%s' "$seg" | sed -e 's/"[^"]*"/ _bsg_q_ /g' -e "s/'[^']*'/ _bsg_q_ /g")

        # 真的是 checkout／switch 嗎（前後錨定空白，`switch-something` 不算）
        cmd_match "$stripped" '[[:space:]](checkout|switch)([[:space:]]|$)' || continue

        local tok seen_cmd=0 creates=0 want_branch=0 nb="" sp=""
        for tok in $stripped; do
            if [ "$seen_cmd" -eq 0 ]; then
                case "$tok" in checkout|switch) seen_cmd=1 ;; esac
                continue
            fi
            case "$tok" in
                # `--` 之後全是路徑（`git checkout -- src/a.ts` 還原檔案）。
                # 這裡直接收工：路徑不是 start-point，收進來會讓判斷變假。
                --) break ;;
                --create=*|--force-create=*)
                    creates=1; nb="${tok#*=}" ;;
                -b|-B|-c|-C|--create|--force-create)
                    creates=1; want_branch=1 ;;
                -*) continue ;;
                *)
                    if [ "$want_branch" -eq 1 ]; then
                        nb="$tok"; want_branch=0
                    elif [ -z "$sp" ]; then
                        sp="$tok"
                    fi ;;
            esac
        done

        [ "$seen_cmd" -eq 1 ] && [ "$creates" -eq 1 ] || continue
        hit="$seg"; new_branch="$nb"; start_point="$sp"; break
    done <<< "$segs"

    [ "$restore_f" -eq 1 ] && set +f
    [ -n "$hit" ] || return 0

    # detached HEAD → 判斷不了「你站在誰的分支上」，放行
    local branch
    branch=$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=""
    [ -n "$branch" ] || return 0

    local default_branch
    default_branch=$(_bsg_default_branch "$root")
    [ -n "$default_branch" ] || return 0

    local flag="$data_dir/.branch-switch-warned"

    # 站在預設分支上 → 正常流程，放行。順手清掉 deny-once 標記：
    # 回到預設分支就是一個新的起點，下一次站上 topic 分支該重新受檢。
    if [ "$branch" = "$default_branch" ]; then
        rm -f "$flag" 2>/dev/null || true
        return 0
    fi

    local inflight_types inflight
    inflight_types=""
    inflight=0
    if declare -F agent_inflight_types >/dev/null 2>&1; then
        inflight_types=$(agent_inflight_types "$main_claude/logs/agent-activity.jsonl")
        inflight=$(agent_inflight_count "$inflight_types")
    fi

    # 指令自己帶了 start-point（`git checkout -b x main`）→ 基底已明確表達，
    # 那正是本閘門推薦的繞法之一，不能反過來擋它。
    # **但只有在沒有 in-flight agent 時才放行**：start-point 解決的是「基底錯了」，
    # 解決不了「這個 checkout 的 HEAD 還是會被搬走，站在上面的 agent 跟著被搬」。
    if [ -n "$start_point" ] && [ "$inflight" -eq 0 ]; then
        return 0
    fi

    [ -n "$new_branch" ] || new_branch="<新分支名>"

    local who="" tail="" why="" caveat=""
    if [ "$inflight" -gt 0 ]; then
        # 名單用 sed 接成 Markdown code span，寫法與 pre-agent-gate.sh 一致
        local list
        list=$(printf '%s\n' "$inflight_types" | grep '[^[:space:]]' | sort -u \
               | tr '\n' ' ' | sed -e 's/[[:space:]]*$//' -e 's/ /`、`/g')
        who="**現在有 ${inflight} 個 subagent 還在跑**（\`${list}\`），而它們就站在這個 checkout 的 \`$branch\` 上。"
        why="\`git checkout -b\` 會把**它們腳下的分支抽掉**——agent 接著寫檔、commit，全都落到新分支上。沒有錯誤訊息，要到對帳時才發現一個任務的 commit 散在兩條分支。"
        tail='（**這個情境不採 deny-once**：那個 agent 還站在那裡，放行一次它照樣被抽掉。等它跑完、或改用 worktree。關閉：BRANCH_SWITCH_GATE=off）'
        # 這段只在有 in-flight 時才有意義——沒有 agent 在跑時講「數字包含你自己」
        # 會印出「0 個在跑」這種沒有意義的話。
        caveat="**閘門沒判斷的事**：如果**你自己就是那個 subagent**，上面那個「${inflight} 個在跑」的數字包含你自己——PreToolUse 的 payload 分不出誰在打這條指令。結論不變（subagent 在共用 checkout 裡換分支本來就該改用 worktree），但數字的歸屬不精確，先知道再判斷。"
    else
        who="你現在站在 topic 分支 \`$branch\` 上，不是預設分支 \`$default_branch\`。"
        why="從這裡 \`git checkout -b\` 開出來的新分支，**基底是 \`$branch\` 的 tip**——前一個任務的 commit 會整批混進新任務。獨立的任務該從 \`$default_branch\` 開。"
        tail='（本分支只擋這一次；切回預設分支或換一條分支會重新受檢。關閉：BRANCH_SWITCH_GATE=off）'

        # deny-once：標記記的是分支名。換一條 topic 分支是新的現場，該再講一次。
        mkdir -p "$data_dir" 2>/dev/null || true
        if [ -f "$flag" ] && [ "$(cat "$flag" 2>/dev/null)" = "$branch" ]; then
            return 0
        fi
        printf '%s' "$branch" > "$flag" 2>/dev/null || true
    fi

    jq -n --arg who "$who" --arg why "$why" --arg tail "$tail" --arg caveat "$caveat" \
          --arg nb "$new_branch" --arg db "$default_branch" --arg br "$branch" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("⛔ " + $who + "\n\n**一個 checkout 同時只能站一個分支。** " + $why + "\n\n**兩個做法，挑一個（可直接複製）：**\n\n1. **要平行做兩件事 → 用 worktree**，各自一份 checkout 與分支，誰也抽不走誰的：\n\n```\nclaude --worktree " + $nb + "\n```\n\n   派 subagent 時則是 `Agent` 工具帶 `isolation: \"worktree\"`。完整程序（狀態隔離邊界、依相依順序合併、清理判準）見 `worktree-orchestration` skill。\n\n2. **只是要開下一個任務、不需要平行 → 明確指定基底**，不要靠「當前站在哪」：\n\n```\ngit checkout -b " + $nb + " " + $db + "\n```\n\n   帶了 start-point 本閘門就不攔（沒有 in-flight agent 時）。也可以先 `git checkout " + $db + "` 再開——但工作區有未 commit 的改動時**不要用 `git stash` 頂替**：它沒有名字、沒有歷史，下一次 stash 就疊上去。\n\n" + (if $caveat == "" then "" else $caveat + "\n\n" end) + $tail)
      }
    }' 2>/dev/null || true
    exit 0
}
