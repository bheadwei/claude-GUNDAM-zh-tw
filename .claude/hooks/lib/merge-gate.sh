#!/bin/bash
# merge-gate.sh — 合併未驗證前不得再合併（供 pre-tool-use.sh source）
#
# 為什麼需要：平行開發最後那段序列合併是使用者實際的痛點，而痛在兩處——
#
#   1. **每個 worktree 各自 /verify 過了，不代表合併結果是對的。**
#      各 worktree 看不到彼此，合併才第一次讓兩邊的程式碼真的碰面。
#      那些互動是全新的、沒有任何人驗過的程式碼。
#   2. **一次合併多個之後就分不出是誰弄壞的。** 三個 branch 一起 merge 完才發現
#      測試紅，要回頭二分找元凶——那正是「一次一個 merge」規則存在的理由，
#      但那條規則寫在 worktree-orchestration skill 裡，是自律。
#
# 所以：merge 成功後記一筆待驗證；在那筆被 /verify 清掉之前，**擋下下一次 merge**。
#
# 標記檔由 post-bash.sh 在偵測到 merge 成功時寫入，由 /verify 通過後刪除。
#
# 逃生門：MERGE_GATE=off
#
# 用法（pre-tool-use.sh 內，確定是 Bash 工具且取得 COMMAND 之後）：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/merge-gate.sh"
#   merge_gate "$COMMAND" "$DATA_DIR"      # 命中時自行輸出 deny JSON 並 exit 0

merge_gate() {
    local cmd="$1" data_dir="$2"
    [ "${MERGE_GATE:-on}" = "off" ] && return 0
    [ -n "$cmd" ] || return 0

    local pending="$data_dir/.merge-pending"
    [ -s "$pending" ] || return 0

    # 只擋「會產生新合併」的指令。cherry-pick 與 rebase 同樣把別的分支的
    # 改動帶進來，未驗證前一樣不該疊上去。
    case "$cmd" in
        *"git merge"*|*"git cherry-pick"*|*"git rebase"*) ;;
        *) return 0 ;;
    esac
    # --abort / --continue / --skip 是在收拾當前狀態，不是新合併，放行
    case "$cmd" in
        *--abort*|*--continue*|*--skip*|*--quit*) return 0 ;;
    esac

    local n first
    n=$(grep -c . "$pending" 2>/dev/null || echo 0)
    first=$(head -1 "$pending" 2>/dev/null)

    command -v jq >/dev/null 2>&1 || return 0
    jq -n --arg n "$n" --arg first "$first" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("⛔ 上一次合併還沒驗證過，不能再合併下一個。\n\n待驗證：" + $n + " 筆，最早一筆是 `" + $first + "`\n\n**為什麼擋**：每個 worktree 自己 /verify 過，不代表合併結果是對的——各 worktree 看不到彼此，**合併才第一次讓兩邊的程式碼真的碰面**，那些互動是全新的、沒人驗過的。而且一次疊好幾個之後測試紅了，你得回頭二分找元凶。\n\n**照這個順序做：**\n\n1. 跑 `/verify`（它會驗建置／型別／lint／測試，並比對已合併任務的 plan 驗收標準）\n2. **PASS** → `/verify` 自動清掉待驗證清單 → 回來繼續合下一個\n3. **FAIL** → 在主 checkout 修好再驗；修不動就 `git merge --abort` 退回\n\n（關閉：MERGE_GATE=off）")
      }
    }' 2>/dev/null || true
    exit 0
}
