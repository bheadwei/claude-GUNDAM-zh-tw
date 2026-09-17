#!/bin/bash
# merge-noff-gate.sh — 合併本地 topic 分支必須帶 --no-ff（供 pre-tool-use.sh source）
#
# 為什麼需要：一個在獨立 worktree 做完的任務合併回 main 時，若主線期間沒有新
# commit，`git merge <branch>` 會走 fast-forward——**任務邊界在歷史上完全消失**。
# 之後 `git log --first-parent` 看不出那是一個任務、`git revert -m 1` 也沒有
# merge commit 可退。事後補不回來（要補只能改寫歷史）。
#
# 這件事**已經寫在兩份文件裡**（commands/worktree.md、worktree-orchestration skill），
# 2026-09-16 還是漏了一次。文字寫第三份不會有幫助——它是純機械、判斷得出來的
# 指令形狀問題，正是該由閘門強制的形狀（writing-extensions 決策表第一列）。
# 所以**刻意不在 rules/git-workflow.md 再寫一條**（該檔頭的收錄判準禁止重述）。
#
# 判準（只看指令形狀，不看 repo 狀態）：
#   放行 — 帶 --no-ff / --squash / --ff-only 的（意圖已明確表達）
#   放行 — --abort / --continue / --skip / --quit（在收拾當前狀態，不是新合併）
#   放行 — 合併對象是遠端 ref 或同步用的 ref（<remote>/…、FETCH_HEAD、@{u}）：
#          `git merge origin/main` 是把上游拉平，不該被逼出一個空的 merge 節點
#   放行 — 剝掉選項後沒有任何 ref 參數（形狀判斷不出來）
#   擋   — 其餘，也就是「合併本地 topic 分支卻沒有 --no-ff」
#
# 「這個 ref 是不是遠端的」用 `git remote` 的實際清單判斷，不是看有沒有斜線——
# `feat/x` 有斜線但它是本地 topic 分支，正是最該擋的那一類。拿不到 git 時退回
# {origin, upstream}，方向偏放行。
#
# **刻意沒有 deny-once。** git-backup-gate 的檔頭區分過兩種閘門：擋「狀態」的
# 不能放行一次（放行一次等於沒有閘門），擋「指令形狀」的則天然自清——
# 使用者補上 --no-ff 重打**同一條指令**就通過了，沒有任何理由需要記一個旗標。
# 記旗標反而會讓「第二次真的漏掉」時靜默放行。
#
# 逃生門：MERGE_NOFF_GATE=off
#
# 用法（pre-tool-use.sh 內，確定是 Bash 工具且取得 COMMAND 之後）：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/merge-noff-gate.sh"
#   merge_noff_gate "$COMMAND" "$WORK_ROOT"   # 命中時自行輸出 deny JSON 並 exit 0

# 指令切段一律走共用實作。子字串比對會把 `git merge-base --is-ancestor`（唯讀查詢）
# 與文件內文當成真的合併——原因與取捨都寫在 cmd-segments.sh 檔頭。
source "$(dirname "${BASH_SOURCE[0]}")/cmd-segments.sh" 2>/dev/null || true

# _mng_is_sync_ref <ref> <remotes>
# 遠端 ref 或同步用 ref → 0（放行）
_mng_is_sync_ref() {
    local ref="$1" remotes="$2" first
    case "$ref" in
        FETCH_HEAD|ORIG_HEAD|MERGE_HEAD) return 0 ;;
        '@{u}'|'@{upstream}'|*'@{u}'|*'@{upstream}') return 0 ;;
    esac
    first="${ref%%/*}"
    [ "$first" = "$ref" ] && return 1        # 沒有斜線 → 本地分支
    case " $remotes " in *" $first "*) return 0 ;; esac
    return 1
}

merge_noff_gate() {
    local cmd="$1" root="$2"
    [ "${MERGE_NOFF_GATE:-on}" = "off" ] && return 0
    [ -n "$cmd" ] || return 0

    # 缺共用切段函式就放行 —— 與本模板其他閘門「判斷不了就放行」一致
    declare -F cmd_segments >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0

    local segs
    segs=$(cmd_segments "$cmd")
    [ -n "$segs" ] || return 0

    # 遠端名稱清單。拿不到 git／不是 repo 時退回慣例值（方向偏放行）。
    local remotes="origin upstream"
    if command -v git >/dev/null 2>&1 && [ -n "$root" ]; then
        local rl
        rl=$(git -C "$root" remote 2>/dev/null | tr '\n' ' ')
        [ -n "$rl" ] && remotes="$remotes $rl"
    fi

    # token 切分用的是 shell word splitting，關掉 glob 展開：指令裡的 `*`
    # 不該被當成當前目錄的檔名展開成一串假 ref。
    local restore_f=0
    case "$-" in *f*) ;; *) restore_f=1; set -f ;; esac

    local seg hit="" hit_ref=""
    while IFS= read -r seg; do
        [ -n "$seg" ] || continue

        # 先把引號字串換成**單一佔位 token** 再做所有比對：`-m "改用 --no-ff"`
        # 的訊息內容既不該被當成旗標、也不該被當成 ref。
        # 換成佔位而不是直接刪掉，是因為 `-m` 會吃掉下一個 token——刪掉的話
        # `git merge -m "…" mybr` 裡的 `mybr` 會被 `-m` 誤吃，然後「沒有 ref
        # 參數」讓閘門靜默放行（實測過）。
        # 剝不乾淨時最壞是多出幾個看起來像 ref 的 token，而那只會讓判斷更保守
        # （多一個非遠端 ref → 擋），不會誤放行。
        local stripped
        stripped=$(printf '%s' "$seg" | sed -e 's/"[^"]*"/ _mng_q_ /g' -e "s/'[^']*'/ _mng_q_ /g")

        # 真的是 merge 子指令嗎（`merge-base` 不算，cmd_match 前後錨定空白）
        cmd_match "$stripped" '[[:space:]]merge([[:space:]]|$)' || continue

        # 收拾當前狀態，不是新合併
        cmd_match "$stripped" '[[:space:]]--(abort|continue|skip|quit)([[:space:]]|$)' && continue

        # 意圖已明確表達 → 放行
        cmd_match "$stripped" '[[:space:]]--(no-ff|squash|ff-only)([[:space:]]|$)' && continue

        local tok seen_merge=0 skip_next=0 refs=""
        for tok in $stripped; do
            if [ "$skip_next" -eq 1 ]; then skip_next=0; continue; fi
            if [ "$seen_merge" -eq 0 ]; then
                [ "$tok" = "merge" ] && seen_merge=1
                # `git -C <path> merge` 的 <path> 也會在這裡被跳過（還沒到 merge）
                continue
            fi
            case "$tok" in
                --) continue ;;
                # 會吃掉下一個 token 的選項。**值是選配的一律不列入**——它們的值
                # 必須用 = 附著（`--log=5`、`-S<keyid>`），所以裸寫時不吃下一個 token。
                # 列錯的代價是**靜默放行**：`git merge --log mybr` 會把 mybr 當成
                # --log 的值吃掉，然後「沒有 ref 參數」讓閘門放行。
                -m|--message|-s|--strategy|-X|--strategy-option|-F|--file|--into-name)
                    skip_next=1; continue ;;
                -*) continue ;;
                *)  refs="$refs $tok" ;;
            esac
        done

        [ "$seen_merge" -eq 1 ] || continue
        # 沒有 ref 參數 → 形狀判斷不出合併對象，放行
        [ -n "${refs// /}" ] || continue

        local r local_ref=""
        for r in $refs; do
            if ! _mng_is_sync_ref "$r" "$remotes"; then local_ref="$r"; break; fi
        done
        # 全部都是遠端／同步 ref → 純同步合併，不該被逼出 merge 節點
        [ -n "$local_ref" ] || continue

        hit="$seg"; hit_ref="$local_ref"; break
    done <<< "$segs"

    [ "$restore_f" -eq 1 ] && set +f

    [ -n "$hit" ] || return 0

    # 補好旗標的完整指令（單行，s/// 無 g → 只換第一個 merge）
    local fixed
    fixed=$(printf '%s' "$hit" | sed -e 's/\([[:space:]]\)merge\([[:space:]]\)/\1merge --no-ff\2/')

    jq -n --arg fixed "$fixed" --arg ref "$hit_ref" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("⛔ 合併本地分支 `" + $ref + "` 但沒帶 `--no-ff`。\n\n**照這個做（可直接複製）：**\n\n```\n" + $fixed + "\n```\n\n訊息建議寫成 `-m \"merge: <WBS 編號> <任務標題>\"`，例如 `-m \"merge: 11.26 搜尋結果分頁\"` —— `--first-parent` 讀起來才像一本任務帳本。\n\n**為什麼擋**：主線期間沒有新 commit 時 `git merge <branch>` 會 fast-forward，**任務邊界在歷史上直接消失**，而且事後補不回來（要補只能改寫歷史）。留下 merge commit 換到三件具體的事：\n\n- `git log --first-parent` —— 一個任務一行，主線讀得像帳本\n- `git revert -m 1 <merge>` —— 整批回退這個任務，不用一個一個挑 commit\n- `git bisect start --first-parent` —— 先二分到「是不是這個任務造成的」，再進去細找\n\n**要誠實的一點**：`--no-ff` 記錄的是**任務邊界與意圖**，**不是平行做過的證據**。分支期間主線沒有 commit 時，在 git 的視角裡那段工作本來就沒有分歧——`--no-ff` 沒有把它變成有分歧，只是替你把「這裡是一個任務」這件事寫進歷史。\n\n**確定要 fast-forward 時**（例如只是把本地拉平到已經包含你工作的分支）：明講一句理由，然後改用 `--ff-only` 或設 `MERGE_NOFF_GATE=off` 重試。合併遠端 ref（`origin/*`、`FETCH_HEAD`、`@{u}`）本閘門不攔，不必為純同步多開一個空節點。\n\n**永久解（選配）**：`git config merge.ff false` 讓這個 repo 預設就不 fast-forward，搭配 `git config pull.rebase true` —— 後者是配套，少了它 `git pull` 會開始生出一堆無意義的同步 merge 節點，`--first-parent` 又髒回去。\n\n**`git revert -m 1` 的後遺症**（先知道再用）：退掉之後那個分支在 git 眼裡仍算「已合併」，日後要重新合進來得先 revert 掉那個 revert。\n\n（本閘門沒有「擋一次就過」，也不需要——補上旗標重打同一條指令就通過。關閉：MERGE_NOFF_GATE=off）")
      }
    }' 2>/dev/null || true
    exit 0
}
