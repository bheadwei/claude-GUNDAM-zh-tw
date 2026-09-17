#!/bin/bash
# Pre Agent Gate — PreToolUse(Agent)
#
# 職責：擋下「同時派多個沒有隔離的 subagent」。
#
# 為什麼需要：沒帶 isolation 的 subagent 全部在**同一個工作目錄**裡動手。
# 兩個 agent 改到同一個檔案時，**後寫的直接覆蓋前面的，沒有衝突提示、沒有錯誤**——
# 你會拿到一個「看起來完成了」但其中一份工作被靜默吃掉的結果。
#
# 原本對這件事的保護只有 rules/agent-orchestration.md 的一行文字：
#   ❌ 同時平行啟動會互改同一批檔案的 agent（序列化或用 worktree 隔離）
# 那是自律。這支是機器。
#
# 判斷方式：從 agent-activity.jsonl 算「已 start 但還沒 complete」的 agent 數，
# 對應鍵是 **agent_id**（不是 tool_use_id）。
# 帶了 isolation 的直接放行——它有自己的 checkout 與分支，**改不到別人的檔案**。
#
# **「改不到別人」只成立在檔案層。** 隔離擋的是寫入，擋不住「執行到誰的程式碼」：
# `settings.json` 的 `worktree.symlinkDirectories` 若含環境目錄或建置產物
# （`.venv`／`.next`／`dist`／`build`、以及 workspace 形態下的 `node_modules`），
# 那個目錄是**指回主 checkout 的 symlink**——帶隔離的 agent 跑測試時，import 到的
# 是別人那份 source。2026-09-17 實測：worktree 裡 `router.__file__` 指向主 checkout，
# 測試結果是另一條線的程式碼，**沒有任何錯誤訊息**。
# 這是繼「寫撞寫」「讀撞寫」之後的第三類：**執行撞執行**。
# 判準與修法見 worktree-orchestration skill 的 `symlinkDirectories` 節（唯一來源）；
# 本模板的預設已改成 `[]`。
#
# **本閘門刻意不管這一類**：派工當下檢查不了目標 worktree 的 venv 狀態
# （worktree 還沒建），而誤擋帶隔離的派工代價很高——那正是我們要推廣的做法。
# 這一格由設定預設值 + skill 判準負責，不是閘門。
#
# 這個計數曾經永遠是 0，等於閘門從裝上去那天就沒攔過任何一次（2026-09-11 查出）：
# 當時 agent_complete 由 PostToolUse(Agent) 寫，而 Agent 工具是**非同步**的，
# PostToolUse 記的是「派工動作返回了」而非「agent 做完了」。修法見
# agent-monitor.sh 檔頭——完成改由 SubagentStop 寫。本檔只需知道：
# **agent_complete 現在代表 agent 真的結束了。**
#
# deny-once：擋第一次、把理由貼出來，重試就通過（跟任務模式閘門同一個模式）。
# 每一「批」平行只擋一次：in-flight 歸零時自動清除標記，下一批會再擋一次。
#
# ---------------------------------------------------------------- 讀寫衝突盲區
#
# 2026-09-16 補：本閘門原本的攔截訊息有一個**自己造成的**盲區。選項 3 寫著
# 「確認檔案範圍不重疊後重試即可通過」——但**掃描／驗證類 agent 的寫入集是空的**
# （它只讀、只跑測試，最多寫一份報告）。於是「範圍不重疊」對它**永遠成立**，
# 閘門親手把模型引導到錯誤結論，再加上 deny-once 就放行了。
#
# 真正的根因不是「平行」，是**併行讀寫**：這類 agent 讀或執行**整個 repo**，
# 必然撞上任何併行的寫入者。兩起真實事故：
#   1. security-infrastructure-auditor 跑測試時讀到 code-quality-specialist
#      改到一半的產品碼 → 回報 2 個假 failed
#   2. 一個審查類 agent 把 debug-investigator 留下的 RED 測試檔刪了——
#      在審查者眼裡那就是一個壞掉的產物
#
# 修法（本次要派的 agent 或任何 in-flight agent 落在 SCAN_AGENTS 時）：
#   - 推薦改成序列化，理由明講讀寫衝突並附上這兩起事故
#   - **收掉選項 3**：這個情境下「範圍不重疊」不是有效的理由
#   - **不套用 deny-once**：持續擋到 in-flight 歸零、或這次帶 isolation。
#     兩個出口閘門自己都驗得出來（isolation 在上方直接放行、INFLIGHT=0 也是
#     放行路徑），所以這個持續擋不會鎖死任何人。
#   一般情境的 deny-once 行為**完全不變**。
#
# 完整教訓見 context/learned/2026-09-16-concurrent-read-write-not-file-overlap.md，
# 判準的文字版見 rules/agent-orchestration.md「安全平行」。
#
# 同一則訊息連派多個時擋在第幾個：實測（另一個專案的 3 個 agent 批次）
# 第 1 個的 PostToolUse 早於第 2 個的 PreToolUse 5 秒，所以**第 2 個會被擋**；
# 但第 3 個的 PreToolUse 早於第 2 個的 PostToolUse，可見這條鏈不是嚴格交錯的。
# 不影響本閘門的設計——deny-once 本來就是一批只擋一次。
#
# 逃生門：PARALLEL_AGENT_GATE=off、或 .suggest-mode 為 off

INPUT=$(cat)

source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$INPUT"
else
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    MAIN_CLAUDE="$MAIN_ROOT/.claude"; WORK_CLAUDE="$MAIN_CLAUDE"
fi

CLAUDE_DIR="$MAIN_CLAUDE"                  # log 集中在主 checkout
DATA_DIR="$WORK_CLAUDE/taskmaster-data"
LOG_JSONL="$CLAUDE_DIR/logs/agent-activity.jsonl"
WARNED="$DATA_DIR/.parallel-agent-warned"

[ "${PARALLEL_AGENT_GATE:-on}" = "off" ] && exit 0
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

# 這次要派的 agent 有沒有帶隔離
ISOLATION=$(printf '%s' "$INPUT" | jq -r '.tool_input.isolation // ""' 2>/dev/null)
SUBAGENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // "general-purpose"' 2>/dev/null)

# 這裡以前有一段「排除本次呼叫自己的 tool_use_id」的邏輯，**已不再需要**：
# agent_start 現在由 PostToolUse(Agent) 寫，而本檔跑在 PreToolUse，
# 也就是**必然早於自己那次 PostToolUse**。帳上根本還沒有自己這一筆，
# 無從誤算。原本那個誤擋（閒置超過 60 分鐘後的第一次委派必被擋一次）
# 一併消失，因為它的成因就是「monitor 在 PreToolUse 先寫了 start」。

# 帶了 isolation → 有自己的 checkout，改不到別人，直接放行
case "$ISOLATION" in
    worktree|remote) exit 0 ;;
esac

# 算 in-flight：start 過但沒有對應 complete 的 agent_id。
# 實作與所有取捨（60 分鐘窗、agent_id 去重、缺 agent_type 印 `-`）都在
# lib/agent-inflight.sh —— branch-switch-gate.sh 需要**同一個答案**，
# 各寫各的就是 cmd-segments.sh 檔頭講的那種「同一個坑修兩次」。
#
# 要的是**每個 in-flight agent 的 agent_type，一行一個**（不是只有筆數）：
# 下面的讀寫衝突判斷需要知道在跑的是誰。
source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-inflight.sh" 2>/dev/null || true

INFLIGHT=0
INFLIGHT_TYPES=""
if declare -F agent_inflight_types >/dev/null 2>&1; then
    INFLIGHT_TYPES=$(agent_inflight_types "$LOG_JSONL")
    INFLIGHT=$(agent_inflight_count "$INFLIGHT_TYPES")
fi
case "${INFLIGHT:-}" in ''|*[!0-9]*) INFLIGHT=0 ;; esac

# ------------------------------------------------- 掃描／驗證類 agent（讀寫衝突）
#
# 這些 agent 讀或執行**整個 repo**，而不是一個宣告過的檔案集。它們的寫入集
# 是空的或很小，所以「檔案範圍不重疊」對它永遠成立——但併行的寫入者一定會
# 被它讀到（半成品的產品碼、刻意留紅的測試）。判準與事故見本檔頭。
SCAN_AGENTS="security-infrastructure-auditor code-quality-specialist test-automation-engineer e2e-validation-specialist refactor-cleaner"

is_scan_agent() {
    case " $SCAN_AGENTS " in *" $1 "*) return 0 ;; esac
    return 1
}

SCAN_NEXT=""
SCAN_INFLIGHT=""
is_scan_agent "$SUBAGENT" && SCAN_NEXT="$SUBAGENT"
if [ -n "$INFLIGHT_TYPES" ]; then
    while IFS= read -r _t; do
        [ -n "$_t" ] || continue
        is_scan_agent "$_t" || continue
        case " $SCAN_INFLIGHT " in *" $_t "*) continue ;; esac
        SCAN_INFLIGHT="${SCAN_INFLIGHT:+$SCAN_INFLIGHT }$_t"
    done <<< "$INFLIGHT_TYPES"
fi
SCAN_HIT=0
{ [ -n "$SCAN_NEXT" ] || [ -n "$SCAN_INFLIGHT" ]; } && SCAN_HIT=1

mkdir -p "$DATA_DIR" 2>/dev/null || true

# in-flight 歸零 → 上一批平行已結束，清掉標記讓下一批重新受檢
if [ "$INFLIGHT" -eq 0 ]; then
    rm -f "$WARNED" 2>/dev/null || true
    exit 0
fi

# 掃描／驗證類牽涉其中 → **不套用 deny-once**：既不吃既有標記、也不寫新標記。
# 持續擋到 in-flight 歸零（上方已是放行路徑）或這次帶 isolation（更上方已放行）。
if [ "$SCAN_HIT" -eq 0 ]; then
    # 這一批已經擋過一次 → 放行（deny-once）
    [ -f "$WARNED" ] && exit 0
    : > "$WARNED" 2>/dev/null || true
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] parallel-agent-gate: deny (inflight=$INFLIGHT, next=$SUBAGENT, scan=$SCAN_HIT)" \
    >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true

# ------------------------------------------------------------------ 推薦哪一個
#
# 只列三個選項等於把判斷丟回給使用者。閘門算得出來的部分就該先講。
#
# **這整段只在攔截路徑跑**（上面所有 exit 0 都已經返回了）。放行時不會多跑一次
# `git status`——它在大 repo 上不便宜，而放行是絕對多數的情況。
#
# **算不出來就不推薦。** 任何一項失敗（沒有 git、不是 repo、status 失敗、
# plans/ 不存在）都讓 RECO 留空，訊息安靜退回原本的中立三選項。
# 攔截比推薦重要：推薦錯了會誤導，攔截漏了會靜默覆蓋別人的工作。

# 檢查一：工作區乾不乾淨。**必須在 WORK_ROOT 下跑**——worktree session 裡
# 主 checkout 的狀態跟這次派工無關。
GIT_DIRTY=unknown
DIRTY_N=0
if command -v git >/dev/null 2>&1 && [ -n "${WORK_ROOT:-}" ] && [ -d "${WORK_ROOT:-}" ]; then
    if PORCELAIN=$(git -C "$WORK_ROOT" status --porcelain 2>/dev/null); then
        # **不要在這裡接 `|| echo`**：`grep -c` 數到 0 時會印出 "0" 並**回傳 1**，
        # fallback 於是把第二行也塞進來（"0\nx"），乾淨的工作區會被判成數不出來。
        # 計數本身一律會印出來，command substitution 的結束碼在這裡無所謂。
        DIRTY_N=$(printf '%s\n' "$PORCELAIN" | grep -c '[^[:space:]]' 2>/dev/null)
        # 數不出來就留 unknown。**不要退回 "no"**——那會變成宣稱「工作區乾淨」
        # 並推薦 worktree，是唯一一種會主動誤導的失敗方式。
        case "$DIRTY_N" in
            ''|*[!0-9]*) GIT_DIRTY=unknown ;;
            0)           GIT_DIRTY=no ;;
            *)           GIT_DIRTY=yes ;;
        esac
    fi
fi

# 檢查二：有沒有任何帶 `files:` 的 plan（排除 archive/，那是做完的）。
# **只有「零」這個答案敢講**：零就是真的沒有平行的依據。非零時不聲稱任何事——
# 從這次派工反查不到對應的 plan，講「你有 plan」等於暗示範圍已確認過。
#
# `plans/` 整個不存在時留 unknown 而不是 "no"：那種專案根本沒在用 plan，
# 說「你沒有任何帶 files: 的 plan」是用模板的慣例去指責它。兩個檢查各自獨立，
# 這種情況下推薦仍可能由檢查一給出（它的理由不涉及 plan）。
HAS_FILES_PLAN=unknown
PLANS_DIR="$WORK_CLAUDE/taskmaster-data/plans"
if [ -d "$PLANS_DIR" ]; then
    if grep -rlE '^files:' --include='*.md' --exclude-dir=archive "$PLANS_DIR" >/dev/null 2>&1; then
        HAS_FILES_PLAN=yes
    else
        HAS_FILES_PLAN=no
    fi
fi

# 掃描／驗證類壓過上面兩個檢查：工作區乾不乾淨、有沒有 plan，都改變不了
# 「它讀整個 repo」這件事。這裡是本閘門唯一敢直接推薦的硬情境。
SCAN_WHO=""
if [ "$SCAN_HIT" -eq 1 ]; then
    _SCAN_LIST=$(printf '%s' "$SCAN_INFLIGHT" | sed 's/ /`、`/g')
    if [ -n "$SCAN_NEXT" ] && [ -n "$SCAN_INFLIGHT" ]; then
        SCAN_WHO="你正要派的 \`$SCAN_NEXT\`，以及正在跑的 \`$_SCAN_LIST\`，"
    elif [ -n "$SCAN_NEXT" ]; then
        SCAN_WHO="你正要派的 \`$SCAN_NEXT\` "
    else
        SCAN_WHO="正在跑的 \`$_SCAN_LIST\` "
    fi
fi

# 檢查二壓過檢查一：沒有 plan 就沒有平行的依據，工作區再乾淨也一樣
RECO=""
if [ "$SCAN_HIT" -eq 1 ]; then
    RECO="👉 **推薦：序列化（選項 1）** —— ${SCAN_WHO}屬於**掃描／驗證類 agent**：它讀或執行**整個 repo**，而不是一個宣告過的檔案集。

**這裡的風險不是「寫入撞寫入」，是「讀撞到寫」。** 這類 agent 的寫入集是空的或很小，所以「檔案範圍不重疊」對它**永遠成立**——但它會讀到、跑到任何併行寫入者留在工作區的半成品。真的發生過兩次：

- \`security-infrastructure-auditor\` 跑測試時讀到 \`code-quality-specialist\` 改到一半的產品碼，回報了 **2 個假 failed**
- 一個審查類 agent 把 \`debug-investigator\` 刻意留紅的測試檔**刪掉**了——在審查者眼裡那就是一個壞掉的產物

要平行只能靠隔離（選項 2）：各自一份 checkout，掃描者讀不到別人的工作區。"
elif [ "$HAS_FILES_PLAN" = "no" ]; then
    RECO="👉 **推薦：序列化（選項 1）** —— \`taskmaster-data/plans/\` 裡**沒有任何帶 \`files:\` 的 plan**，所以無法確認這幾個 agent 的檔案範圍不重疊。沒有依據就不要平行。"
elif [ "$GIT_DIRTY" = "yes" ]; then
    RECO="👉 **推薦：序列化（選項 1）** —— 工作區有 ${DIRTY_N} 個未 commit 的變更。worktree 從 HEAD 開一份乾淨 checkout，**看不到這些改動**；agent 進去會發現缺東西，然後自己重建一份——而且沒有任何錯誤訊息，你要到對帳時才發現。要走選項 2 就先 commit。"
elif [ "$GIT_DIRTY" = "no" ]; then
    RECO="👉 **推薦：帶隔離（選項 2）** —— 工作區乾淨，worktree 拿得到完整 baseline。合併時**依相依順序、一次合一個**，每合完立刻 \`/verify\`。"
fi

# 選項清單與結尾註記隨情境換。
# 掃描／驗證類時**收掉選項 3**——「確認範圍無交集後重試」在那個情境下
# 不是有效的理由（它的寫入集本來就不重疊），留著等於閘門自己教人繞過自己。
OPT_1='1. **序列化** —— 等前一個回來再派下一個。任務有依賴、或會動到同一批檔案時就選這個'
OPT_2='2. **帶隔離** —— `Agent` 工具加 `isolation: "worktree"`。各自一份 checkout 與分支，衝突變成看得見的 git 衝突。適合檔案範圍無交集且每個任務 ≥30 分鐘（開 worktree 有固定成本，短任務是淨虧損）'
OPT_3='3. **確認範圍無交集後重試** —— 若你已確認這幾個 agent 的檔案範圍不重疊（例如各寫不同的報告檔），**用一句話說出各自要寫哪些檔案**，然後重試同一次呼叫即可通過'

if [ "$SCAN_HIT" -eq 1 ]; then
    OPTS="**兩個選擇，挑一個：**

$OPT_1
$OPT_2

**這個情境沒有第三條路。** 「確認檔案範圍不重疊後重試」對掃描／驗證類 agent **永遠成立**（它幾乎不寫檔），所以那不是一個理由——衝突發生在它**讀**的那一邊。"
    TAIL='（**這個情境不採 deny-once**：會一直擋到 in-flight 歸零、或這次呼叫帶 `isolation`。關閉：PARALLEL_AGENT_GATE=off）'
else
    OPTS="**三個選擇，挑一個：**

$OPT_1
$OPT_2
$OPT_3"
    TAIL='（本批只擋這一次；前一批跑完會自動重新受檢。關閉：PARALLEL_AGENT_GATE=off）'
fi

jq -n --arg n "$INFLIGHT" --arg next "$SUBAGENT" --arg reco "$RECO" \
      --arg opts "$OPTS" --arg tail "$TAIL" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: (($reco | if . == "" then "" else . + "\n\n" end) + "⚠️ 已經有 " + $n + " 個沒有隔離的 agent 在跑，你正要再派一個 `" + $next + "`。\n\n沒帶 `isolation` 的 subagent 全部在**同一個工作目錄**動手。兩個 agent 改到同一個檔案時，後寫的會**直接覆蓋前面的**——沒有衝突提示、沒有錯誤訊息。你會拿到「看起來完成了」但其中一份工作被靜默吃掉的結果，而且通常要到很後面才發現。\n\n" + $opts + "\n\n**閘門沒判斷的三件事**：這幾個 agent 實際會碰哪些檔案、每個任務會跑多久（這決定選項 2 值不值得）、以及 prompt 寫了「不要改程式碼」並**不保證** agent 不改。這三件只有你知道。\n\n" + $tail)
  }
}' 2>/dev/null || true

exit 0
