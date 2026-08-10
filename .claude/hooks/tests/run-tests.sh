#!/bin/bash
# .claude/hooks/tests/run-tests.sh — hooks 回歸測試
#
# 為什麼需要：pre-tool-use.sh 現在是硬閘門。它壞掉的兩種方式都很難察覺——
# 誤擋（所有程式碼寫入被 deny）或靜默失效（該擋沒擋，就像當初 .current-task-mode
# 沒人清那個 bug，壞了半年沒發現）。這些測試把每個分支釘住。
#
# 用法：bash .claude/hooks/tests/run-tests.sh
# 需求：bash + jq（無 jq 時 hooks 會軟降級，測試會提示跳過相關案例）
#
# 隔離：所有測試在 mktemp 沙箱內跑（CLAUDE_PROJECT_DIR 指向沙箱），
#       絕不碰真實的 .claude/taskmaster-data/ 或 coordination/。

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

if ! command -v jq >/dev/null 2>&1; then
    echo "✗ 找不到 jq — hooks 會軟降級成不攔截，測試無意義。請先安裝 jq。"
    exit 1
fi

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

MODE_FILE="$SANDBOX/.claude/taskmaster-data/.current-task-mode"
SM_FILE="$SANDBOX/.claude/taskmaster-data/.suggest-mode"
HANDOFF_DIR="$SANDBOX/.claude/coordination/handoffs"

# ---------------------------------------------------------------- 測試框架

reset() {
    rm -rf "$SANDBOX/.claude"
    mkdir -p "$SANDBOX/.claude/taskmaster-data" "$HANDOFF_DIR" "$SANDBOX/.claude/logs"
}

# run <script> <payload> [ENV=VAL ...]
run() {
    local script="$1" payload="$2"
    shift 2
    printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$SANDBOX" "$@" bash "$HOOK_DIR/$script" 2>/dev/null
}

decision() {
    [ -z "$1" ] && { echo allow; return; }
    echo "$1" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null || echo allow
}

ok() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng() {
    FAIL=$((FAIL + 1))
    printf '  \033[31m✗\033[0m %s\n      期望：%s\n      實得：%s\n' "$1" "$2" "$3"
}

# expect_decision <名稱> <期望> <實際輸出>
expect_decision() {
    local got; got=$(decision "$3")
    [ "$got" = "$2" ] && ok "$1" || ng "$1" "$2" "$got"
}

# expect_contains <名稱> <子字串> <實際輸出>
expect_contains() {
    case "$3" in *"$2"*) ok "$1" ;; *) ng "$1" "含「$2」" "${3:-（空輸出）}" ;; esac
}

# expect_empty <名稱> <實際輸出>
expect_empty() {
    [ -z "$2" ] && ok "$1" || ng "$1" "（空輸出）" "$2"
}

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# payload 產生器
w()  { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1"; }
e()  { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }
b()  { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
p()  { jq -nc --arg t "$1" '{prompt:$t}'; }

# =========================================================================
section "pre-tool-use.sh — 任務模式閘門（無模式檔）"
# =========================================================================
reset
expect_decision "程式碼檔 .ts 被擋"          deny  "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"
expect_decision "程式碼檔 .py 被擋"          deny  "$(run pre-tool-use.sh "$(w /p/main.py)")"
expect_decision "Edit 也走同一條路"          deny  "$(run pre-tool-use.sh "$(e /p/src/a.go)")"
expect_decision "專案腳本 .sh 被擋"          deny  "$(run pre-tool-use.sh "$(w /p/scripts/deploy.sh)")"
expect_decision "文件 .md 放行"              allow "$(run pre-tool-use.sh "$(w /p/README.md)")"
expect_decision "設定 .json 放行"            allow "$(run pre-tool-use.sh "$(w /p/tsconfig.json)")"
expect_decision ".claude/** 放行（免自鎖）"  allow "$(run pre-tool-use.sh "$(w /p/.claude/hooks/x.sh)")"
expect_decision "docs/** 放行"               allow "$(run pre-tool-use.sh "$(w /p/docs/a.py)")"
expect_decision "node_modules 放行"          allow "$(run pre-tool-use.sh "$(w /p/node_modules/x/i.js)")"
expect_decision "dist 產物放行"              allow "$(run pre-tool-use.sh "$(w /p/dist/bundle.js)")"
expect_contains "deny 訊息含判級指引"        "quick" "$(run pre-tool-use.sh "$(w /p/src/api.ts)" | jq -r '.hookSpecificOutput.permissionDecisionReason')"

# =========================================================================
section "pre-tool-use.sh — 有模式檔"
# =========================================================================
reset; echo standard > "$MODE_FILE"
expect_decision "有效模式檔放行"             allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

reset; : > "$MODE_FILE"
expect_decision "空模式檔視同無（被擋）"     deny  "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

reset; echo standard > "$MODE_FILE"; touch -d '1 hour ago' "$MODE_FILE"
expect_decision "1h 前的模式檔仍有效"        allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"
[ -f "$MODE_FILE" ] && ok "未過期不應被清除" || ng "未過期不應被清除" "檔案還在" "已被刪除"

reset; echo standard > "$MODE_FILE"; touch -d '9 hours ago' "$MODE_FILE"
expect_decision "9h 前的模式檔過期被擋"      deny  "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"
[ -f "$MODE_FILE" ] && ng "過期應被清除（解互鎖）" "檔案已刪" "檔案還在" || ok "過期應被清除（解互鎖）"

reset; echo standard > "$MODE_FILE"; touch -d '9 hours ago' "$MODE_FILE"
expect_decision "TTL 可用環境變數調長"       allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)" TASKMODE_TTL_HOURS=24)"

# =========================================================================
section "pre-tool-use.sh — 逃生門"
# =========================================================================
reset; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 全放行"    allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

reset
expect_decision "TASKMODE_GATE=off 全放行"   allow "$(run pre-tool-use.sh "$(w /p/src/api.ts)" TASKMODE_GATE=off)"

reset; echo low > "$SM_FILE"
expect_decision "suggest-mode=low 仍會攔"    deny  "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

# =========================================================================
section "pre-tool-use.sh — 裸 cd 偵測"
# =========================================================================
reset; echo standard > "$MODE_FILE"
expect_decision "裸 cd 被擋"                 deny  "$(run pre-tool-use.sh "$(b 'cd subdir')")"
expect_decision "cd && 鏈式放行"             allow "$(run pre-tool-use.sh "$(b 'cd subdir && npm test')")"
expect_decision "subshell 隔離放行"          allow "$(run pre-tool-use.sh "$(b '(cd subdir && npm test)')")"
expect_decision "cd ; 分號放行"              allow "$(run pre-tool-use.sh "$(b 'cd subdir; ls')")"
expect_decision "非 cd 指令放行"             allow "$(run pre-tool-use.sh "$(b 'ls -la')")"
expect_decision "含 cd 字樣但非指令放行"     allow "$(run pre-tool-use.sh "$(b 'echo cd foo')")"

# =========================================================================
section "post-agent-report.sh — handoff 注入"
# =========================================================================
mk_handoff() { # <檔名> <status> <priority>
    cat > "$HANDOFF_DIR/$1" <<EOF
---
from: planner
to: tdd-guide
date: 2026-01-01-0000
priority: $3
status: $2
---

# Handoff

## 起因
測試用交接。
EOF
}

reset; mk_handoff "a.md" pending high
out=$(run post-agent-report.sh '{"tool_name":"Agent"}')
expect_contains "pending 會注入"             "planner → tdd-guide" "$out"
expect_contains "注入含優先級"               "[high]"              "$out"
expect_contains "注入含起因"                 "測試用交接"           "$out"

reset; mk_handoff "a.md" completed high
expect_empty   "completed 不注入"            "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset
expect_empty   "無交接時不注入"              "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset; mk_handoff "a.md" pending high; echo off > "$SM_FILE"
expect_empty   "suggest-mode=off 不注入"     "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset; mk_handoff "a.md" pending medium; echo low > "$SM_FILE"
expect_empty   "low 模式濾掉 medium"         "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset; mk_handoff "a.md" pending high; echo low > "$SM_FILE"
expect_contains "low 模式保留 high"          "planner → tdd-guide" "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset; cp "$HOOK_DIR/../coordination/handoffs/_HANDOFF_TEMPLATE.md" "$HANDOFF_DIR/" 2>/dev/null
expect_empty   "範本檔不被當成交接"          "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

# =========================================================================
section "user-prompt-submit.sh — 意圖路由"
# =========================================================================
reset
expect_contains "auth 關鍵字 → critical"     "critical"              "$(run user-prompt-submit.sh "$(p '實作登入認證')")"
expect_contains "UI 關鍵字 → 提示載入 skill" "ui-style-compliance"   "$(run user-prompt-submit.sh "$(p '做一個前端頁面')")"
expect_contains "npm 關鍵字 → 提示載入 skill" "node-package-manager" "$(run user-prompt-submit.sh "$(p '幫我 npm install react')")"
expect_contains "測試關鍵字 → 提示載入 skill" "testing-standards"    "$(run user-prompt-submit.sh "$(p '補一下測試覆蓋率')")"
expect_contains "migration → 提示先 /plan"   "/plan"                 "$(run user-prompt-submit.sh "$(p '做資料庫遷移')")"
expect_empty   "斜線指令不路由"              "$(run user-prompt-submit.sh "$(p '/task-next')")"
expect_empty   "無關鍵字不注入"              "$(run user-prompt-submit.sh "$(p '今天天氣如何')")"

# 新增功能提示：只有在 wbs.md 存在時才該出現（沒 WBS 談不上追加）
reset
expect_empty   "無 WBS 時不提 /task-add"     "$(run user-prompt-submit.sh "$(p '我想加一個通知功能')")"
reset; : > "$SANDBOX/.claude/taskmaster-data/wbs.md"
expect_contains "有 WBS 時提示 /task-add"    "/task-add"             "$(run user-prompt-submit.sh "$(p '我想加一個通知功能')")"

reset; echo off > "$SM_FILE"
expect_empty   "suggest-mode=off 不注入"     "$(run user-prompt-submit.sh "$(p '實作登入認證')")"

# =========================================================================
section "全體 hooks — 語法與健壯性"
# =========================================================================
for h in "$HOOK_DIR"/*.sh; do
    n=$(basename "$h")
    bash -n "$h" 2>/dev/null && ok "$n 語法正確" || ng "$n 語法正確" "可解析" "語法錯誤"
done

reset
for h in pre-tool-use.sh post-agent-report.sh user-prompt-submit.sh post-write.sh; do
    run "$h" '{}' >/dev/null 2>&1
    [ $? -le 1 ] && ok "$h 收到空 payload 不爆炸" || ng "$h 收到空 payload 不爆炸" "exit ≤ 1" "exit $?"
done

# =========================================================================
printf '\n\033[1m結果\033[0m  通過 %d ・ 失敗 %d\n\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
