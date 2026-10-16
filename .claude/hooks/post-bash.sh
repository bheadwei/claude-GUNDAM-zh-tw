#!/bin/bash
# Post Bash Hook — PostToolUse(Bash) **與** PostToolUseFailure(Bash)
#
# 兩個事件都要接，缺一不可：官方定義 PostToolUse 只在工具**成功**時觸發，
# 指令非零結束屬於失敗，走的是 PostToolUseFailure。只接前者的話，
# 本檔的兩個功能都會在最需要它的那一刻收不到事件：
#   - 有衝突的 merge 退出碼非零 → 不記 → 下一次合併跳過驗證
#   - 「連續失敗後成功」數的就是失敗 → 計數永遠是 0 → 踩坑偵測從沒觸發過
# 兩種事件的 payload 形狀不同：失敗事件**沒有** tool_response，錯誤資訊在
# 頂層的 `error`（首行 `Exit code N`，之後是 stdout／stderr 交錯）與 `is_interrupt`。
# 見 context/learned/2026-10-15-posttooluse-skips-failures.md。
#
# 職責：偵測「踩到坑」的時刻並累積候選，讓 learned/ 不再靠使用者記得下 /learn。
#
# 為什麼需要：`using-taskmaster` 要求「解完非平凡問題後寫一筆進 learned/」，
# 但那是文字規則——沒有任何機制在該寫的當下提出來，所以實際上幾乎不會發生。
# 而「踩到坑」有一個機器判斷得出的訊號：**同一件事連續失敗好幾次、然後成功**。
# 一次就過的不是坑；試了四次才過的就是。
#
# 這裡只累積候選 + 提醒一次，不要求當下停下來處理（那會打斷正在解問題的人）。
# session-start.sh 在下次開場提醒清單還沒清空。
#
# 逃生門：LEARN_CAPTURE=off、或 .suggest-mode 為 off

INPUT=$(cat)

source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/lib/cmd-segments.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$INPUT"
else
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    MAIN_CLAUDE="$MAIN_ROOT/.claude"; WORK_CLAUDE="$MAIN_CLAUDE"
fi

CLAUDE_DIR="$MAIN_CLAUDE"                  # log 集中
DATA_DIR="$WORK_CLAUDE/taskmaster-data"    # 失敗計數：每個 worktree 各自

[ "${LEARN_CAPTURE:-on}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# 讀主 checkout 優先：/suggest-mode 是專案級設定，不該每個 worktree 各設一次。
# 曾經只讀 WORK_CLAUDE，於是主 checkout 設了 off 關不掉 worktree 裡的這道閘門
# （而隔離表一直把它列為 MAIN_CLAUDE 的專案級設定）。寫法與 pre-tool-use.sh 一致。
for smf in "$MAIN_CLAUDE/taskmaster-data/.suggest-mode" "$DATA_DIR/.suggest-mode"; do
    if [ -f "$smf" ]; then
        sm=$(tr -d '[:space:]' < "$smf" 2>/dev/null)
        [ "$sm" = "off" ] && exit 0
        break
    fi
done

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -n "$CMD" ] || exit 0

mkdir -p "$DATA_DIR" 2>/dev/null || true

# 回應時 hookEventName 必須等於觸發的事件，所以要記下來。
#
# 失敗判定以事件本身為準。tool_response 的三個欄位是更早的寫法留下的：
# 實際上 Bash 的 PostToolUse 只會在成功時來，tool_response 形如
# {stdout, stderr, interrupted, isImage}，is_error／exit_code 不會出現。
# 留著是因為無害，而且萬一哪個版本又在成功事件裡帶了失敗資訊，照樣接得住。
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null)
[ -n "$EVENT" ] || EVENT="PostToolUse"
FAILED=0
if [ "$EVENT" = "PostToolUseFailure" ] || printf '%s' "$INPUT" | jq -e '
      (.tool_response.is_error == true)
   or (.tool_response.interrupted == true)
   or ((.tool_response.exit_code // 0) != 0)
' >/dev/null 2>&1; then
    FAILED=1
fi

# ---------------------------------------------------------------- 合併待驗證
#
# 執行了合併（成功或衝突皆然）→ 記一筆待驗證。lib/merge-gate.sh 會在這筆被 /verify 清掉之前
# 擋下下一次合併，`/verify` 通過時刪除本檔。
#
# 為什麼不是「合併完自己跑一次測試就好」：使用者要的不只是測試綠，是
# **合併結果仍符合原本的 plan 與 WBS 目標**。那個比對在 `/verify` 裡
# （plan 驗收標準 + spec-convergence），不是 hook 該做的事——hook 只負責
# 「不准跳過那一步」。
#
# 偵測用「以 git 開頭的指令段 + 前後空白錨定的子指令」，**不是**子字串比對。
# 子字串比對（`case "$CMD" in *"git merge"*`）會把這些都記成一次合併：
#   - `git merge-base --is-ancestor A B` —— 純唯讀祖先查詢，前綴剛好相同
#   - heredoc／echo／grep 內文提到指令名 —— 寫文件、寫測試、寫 plan 都會中
# 然後 merge-gate.sh 拿這些幽靈紀錄擋下**下一次真正的合併**。
# 2026-09-11 累計誤擋五次，其中一次擋下了「修好它自己」的那次編輯，
# 細節見 context/learned/2026-09-11-gate-blocks-its-own-fix.md。
#
# 切段邏輯與 git-backup-gate.sh 共用 lib/cmd-segments.sh（同一個坑不修第二遍）。
# lib/merge-gate.sh 刻意**不**跟進：它只在 .merge-pending 非空這個罕見狀態下才
# 進入比對，誤判成本低，改它是沒必要的風險。
#
# 子指令只看 `git` 後面第一個非選項字（cmd_git_subcmd），不看整段任何位置：
# `git log --grep merge`、`git commit -m "…merge…"` 都不是合併。
MP_OP=""; MP_SEG=""
if [ "${MERGE_GATE:-on}" != "off" ] && declare -F cmd_git_subcmd >/dev/null 2>&1; then
    while IFS= read -r _seg; do
        [ -n "$_seg" ] || continue
        case "$(cmd_git_subcmd "$_seg")" in
            merge|cherry-pick|rebase) MP_OP=$(cmd_git_subcmd "$_seg") ;;
            *) continue ;;
        esac
        MP_SEG="$_seg"; break
    done <<< "$(cmd_segments "$CMD")"
fi

if [ "${MERGE_GATE:-on}" != "off" ]; then
    case "$MP_OP" in
        merge|cherry-pick|rebase)
            case "$MP_SEG" in
                # --abort 是放棄這次合併 → 清掉它的待驗證紀錄
                #
                # 但 --abort **失敗**時不清。它失敗最常見的原因是「沒有進行中的
                # 合併可以放棄」——也就是上一個合併早就完成並 commit 了，清單裡那筆
                # 是真的待驗證。這時清掉等於讓一次誤打的 --abort 抹掉驗證義務。
                # 反方向（abort 其實成功、是鏈在後面的指令失敗）只會多留一筆，
                # 代價是多跑一次 /verify，可以接受。
                *--abort*|*--quit*)
                    if [ "$FAILED" -eq 0 ]; then
                        rm -f "$DATA_DIR/.merge-pending" 2>/dev/null || true
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] merge-pending cleared (abort)" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
                    else
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] merge-pending kept (abort failed)" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
                    fi
                    ;;
                *--continue*|*--skip*) ;;
                *)
                    # 成功、衝突、與「非零結束但看不出原因」**一律**記。
                    #
                    # 衝突的 merge 退出碼非零。曾經以為在這裡用 exit_code 判斷就接住了，
                    # 但 settings.json 當時只接 PostToolUse，**失敗的指令根本不會
                    # 呼叫本檔** → 不記 → conflict-resolver 解完 commit 之後清單是空的
                    # → 下一次合併直接放行，**跳過驗證**。衝突解完的結果比乾淨合併
                    # 更需要驗證，不是更不需要。
                    #
                    # 非零但沒衝突的情況也記：`git merge x && 後面某個指令失敗` 時合併
                    # 其實成功了，只是整條指令被判失敗（2026-10-15 實際漏記的就是這種）。
                    # 合併根本沒發生（分支名打錯、工作區不乾淨被拒）也會被記，代價是
                    # 多跑一次 /verify；反方向的代價是跳過驗證。寧可多記。
                    #
                    # 標記是哪一種操作。三者被同一個 case 收進同一份清單，但合併後
                    # 要驗的東西不同：merge 驗兩邊 plan 的驗收標準都還成立；
                    # cherry-pick 驗被挑過來的 commit 在新脈絡下仍成立（它的前後文
                    # 沒跟過來）；rebase 整段歷史都被重寫，每個 commit 都是新的。
                    # （MP_OP 已由上面的切段偵測決定。）
                    #
                    # 記**目標 ref**，不是整條指令。這份清單唯一的用途是讓 /verify
                    # 分辨「哪些分支合進來了、該比對哪幾份 plan 的驗收標準」，
                    # 存整條指令的話每一筆長得幾乎一樣，那個用途就沒了。
                    #
                    # 抽 ref 要先懂 shell 的引號。曾經只用 sed 剪掉 `-m "訊息"`，
                    # 遇到 `-m "$(cat "$M/msg.txt")"`（引號裡再套引號）或 `-F <檔>`
                    # 就把 shell 片段當成 ref，記成 `[merge] $M/merge-msg.txt")"`。
                    # 後來改成在這裡逐字元自己切 token——等於把 cmd-segments.sh 的
                    # 引號、heredoc、全域選項處理**再寫一份**，而那一份只認 `-C`／`-c`、
                    # 不認註解：`git --git-dir /x merge y` 與「上一行是含單引號的註解」
                    # 都記成整條指令（2026-10-16 code review）。
                    # 現在直接用 MP_SEG：它來自 cmd_segments，引號內容已清空（`-m ""`）、
                    # heredoc 與註解已拿掉、全域選項已去掉、已在 && || ; | 處切開，
                    # 所以第 3 個字起就是子指令的參數。帶值的選項（-m／-F／-s／-X 與長名）
                    # 連同它的值一起跳過；含引號或 `$` 的字（變數、被清空的字串）不當 ref。
                    MP_REF=$(printf '%s\n' "$MP_SEG" | awk -v q="'" '{
                        for (i = 3; i <= NF; i++) {
                            if ($i ~ /^(-m|-F|-s|-X|--file|--message|--strategy|--strategy-option)$/) { i++; continue }
                            if ($i ~ /^-/) continue
                            if (index($i, "\"") || index($i, q) || index($i, "$") || index($i, "(") || index($i, "`")) continue
                            sub(/;+$/, "", $i); print $i; exit
                        }
                    }')
                    # 抽不到就退回記整條指令（沒見過的指令形式、或續做時讀 MERGE_HEAD）。
                    #
                    # 截斷務必用 bash 的 ${var:0:n} —— 它算的是**字元**。
                    # `cut -c`／`cut -b` 在 Git Bash 算的是 byte，會把中文腰斬成
                    # 半個字元（實際踩過）。iconv 也不行：這台機器沒裝，
                    # `|| printf` 的 fallback 會讓它靜默退回腰斬。
                    if [ -z "$MP_REF" ]; then
                        MP_REF=$(printf '%s' "$CMD" | tr '\n' ' ')
                        MP_REF="${MP_REF:0:100}"
                    fi
                    BR="[$MP_OP] $MP_REF"
                    MP="$DATA_DIR/.merge-pending"
                    grep -qxF "$BR" "$MP" 2>/dev/null || echo "$BR" >> "$MP" 2>/dev/null || true

                    # 衝突判定：退出碼非零不等於衝突（見上），要看證據。
                    #   ① 工作樹還有未合併路徑（`ls-files -u`）—— merge／cherry-pick／
                    #      rebase 三者通用，而且不受輸出被 `>/dev/null` 吃掉影響。
                    #      成功事件也查：`git merge x; echo done` 整條是 0，衝突照樣在
                    #   ② 輸出裡有 git 的衝突字樣 —— ①查不到時的後備
                    #      （指令用 `git -C 別處` 跑、或 cwd 已經不在那個 repo）
                    CONFLICTED=0
                    MP_DIR=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
                    [ -n "$MP_DIR" ] || MP_DIR="${WORK_ROOT:-$MAIN_ROOT}"
                    if [ -n "$(git -C "$MP_DIR" ls-files -u 2>/dev/null | head -1)" ]; then
                        CONFLICTED=1
                    elif printf '%s' "$INPUT" | jq -e '
                            [.error, .tool_response.stdout, .tool_response.stderr]
                            | map(strings) | join("\n")
                            | test("CONFLICT \\(|Automatic merge failed|could not apply|fix conflicts")
                         ' >/dev/null 2>&1; then
                        CONFLICTED=1
                    fi

                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] merge-pending: $BR (conflicted=$CONFLICTED, event=$EVENT)" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true

                    if [ "$CONFLICTED" -eq 1 ]; then
                        jq -n --arg ev "$EVENT" '{
                          hookSpecificOutput: {
                            hookEventName: $ev,
                            additionalContext: ("⚠️ 合併有衝突。\n\n**委派 `conflict-resolver`**（`subagent_type: \"conflict-resolver\"`）。它只碰處於衝突狀態的檔案，理解兩邊各自的意圖後保留雙方，解完跑測試；遇到**設計決策**（API 語意、資料結構取捨、migration 順序）會 `git merge --abort` 並回報，不自己決定。\n\n**它不會 commit。** 解完之後由你跑 `/verify`——閘門會擋住下一次合併直到它通過。衝突解完的結果比乾淨合併**更**需要驗證。\n\n順便一件事：衝突代表那份 plan 的 `files:` 估算有漏，補正它，否則下次同樣組合又會被判成可平行。\n（關閉：MERGE_GATE=off）")
                          }
                        }' 2>/dev/null || true
                    elif [ "$FAILED" -eq 1 ]; then
                        jq -n --arg ev "$EVENT" --arg br "$BR" '{
                          hookSpecificOutput: {
                            hookEventName: $ev,
                            additionalContext: ("⚠️ 這條含合併的指令**非零結束**，但沒偵測到衝突狀態。已保守記為待驗證：`" + $br + "`\n\n兩種可能，`git log -1 --oneline` 看一眼就分得出來：\n\n- **合併其實成功了**，是鏈在後面的指令失敗（`git merge … && 其他指令`）→ 照常跑 `/verify`\n- **合併根本沒執行**（分支名打錯、工作區不乾淨被拒）→ 這筆是多記的；向使用者說明後再清掉，不要自己默默刪\n\n在 `/verify` 通過前，`pre-tool-use.sh` 會擋下下一次 merge／cherry-pick／rebase。\n（關閉：MERGE_GATE=off）")
                          }
                        }' 2>/dev/null || true
                    else
                        jq -n --arg ev "$EVENT" '{
                          hookSpecificOutput: {
                            hookEventName: $ev,
                            additionalContext: ("🔀 合併完成，**這一步還沒驗證**。\n\n各 worktree 自己 `/verify` 過，不代表合併結果是對的——它們看不到彼此，合併才第一次讓兩邊的程式碼真的碰面。\n\n**下一步跑 `/verify`。** 在它通過之前，`pre-tool-use.sh` 會擋下下一次 merge／cherry-pick／rebase（避免疊了好幾個才發現紅、還得回頭二分找元凶）。\n\n`/verify` 除了建置／型別／lint／測試，還會比對已合併任務的 plan 驗收標準；若這是平行開發的最後一個合併，它會再跑一次 `spec-convergence` 確認整體仍符合 WBS 與當初的規格。\n（關閉：MERGE_GATE=off）")
                          }
                        }' 2>/dev/null || true
                    fi
                    exit 0
                    ;;
            esac
            ;;
    esac
fi

# 失敗判定（FAILED）在檔頭已算好。這段是本檔最早的功能，寫的時候假設
# 「失敗的指令也會呼叫本檔」——在 PostToolUseFailure 接上之前這個假設不成立，
# 計數從沒累加過，踩坑偵測自 2026-09-08 裝上後一次都沒觸發。

STREAK="$DATA_DIR/.bash-fail-streak"
CAND="$DATA_DIR/.learned-candidates"
NOTIFIED="$DATA_DIR/.learned-notified"

# 連續失敗門檻。1-2 次失敗是打錯字，不是坑。
THRESHOLD="${LEARN_CAPTURE_THRESHOLD:-3}"

if [ "$FAILED" -eq 1 ]; then
    n=$(cat "$STREAK" 2>/dev/null | tr -dc '0-9')
    n=$(( ${n:-0} + 1 ))
    echo "$n" > "$STREAK" 2>/dev/null || true
    exit 0
fi

# 成功了 —— 看它前面失敗了幾次
n=$(cat "$STREAK" 2>/dev/null | tr -dc '0-9')
n=${n:-0}
: > "$STREAK" 2>/dev/null || true
[ "$n" -lt "$THRESHOLD" ] && exit 0

# 記一筆候選（單行，供 /learn 逐筆判斷）。指令截短避免整份 heredoc 進清單。
SHORT=$(printf '%s' "$CMD" | tr '\n' ' ' | cut -c1-120)
echo "[$(date '+%Y-%m-%d %H:%M')] ${n} 次失敗後成功：${SHORT}" >> "$CAND" 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] learn-candidate: streak=$n" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true

# 本任務只提醒一次，避免正在除錯的人被反覆打斷
[ -f "$NOTIFIED" ] && exit 0
: > "$NOTIFIED" 2>/dev/null || true

jq -n --arg n "$n" --arg ev "$EVENT" '{
  hookSpecificOutput: {
    hookEventName: $ev,
    additionalContext: ("🧠 這是一個坑：剛才那個指令失敗 " + $n + " 次才成功。\n\n候選已記進 `.claude/taskmaster-data/.learned-candidates`。**現在不用停下來**——繼續把手上的問題解完。\n\n收尾時（或下次開場被提醒時）判斷這筆值不值得留：真的是環境／工具／平台的坑就用 `/learn` 寫進 `.claude/context/learned/`（`pre-tool-use.sh` 之後會在碰到同一個檔案時把它貼出來，同一個坑不會踩第二次）；只是自己打錯字就從清單刪掉。\n（本任務只提醒這一次。關閉：LEARN_CAPTURE=off）")
  }
}' 2>/dev/null || true

exit 0
