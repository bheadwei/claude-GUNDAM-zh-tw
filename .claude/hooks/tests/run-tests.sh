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
trap 'rm -rf "$SANDBOX" 2>/dev/null || true' EXIT

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

# expect_eq <名稱> <期望（整串相等）> <實際>
expect_eq() { [ "$3" = "$2" ] && ok "$1" || ng "$1" "${2:-（空輸出）}" "${3:-（空輸出）}"; }

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
to: ui-builder
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
expect_contains "pending 會注入"             "planner → ui-builder" "$out"
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
expect_contains "low 模式保留 high"          "planner → ui-builder" "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset; cp "$HOOK_DIR/../coordination/handoffs/_HANDOFF_TEMPLATE.md" "$HANDOFF_DIR/" 2>/dev/null
expect_empty   "範本檔不被當成交接"          "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

# =========================================================================
section "handoff 自動歸檔 — completed/cancelled 移出掃描路徑"
# =========================================================================
#
# 為什麼要這組：範本原本寫「完成後不刪除，作為審計軌跡」，於是 completed 的交接
# 永遠留在平坦的 handoffs/ 裡——每次 subagent 結束都要 for-loop 掃全部檔案，
# 才發現 0 個 pending。歸檔做成 hook（不是指令，指令要有人記得打），
# 這裡釘住三件會靜默壞掉的事：搬錯月份、覆蓋掉舊軌跡、逃生門失效。

ARCH="$HANDOFF_DIR/archive"

mk_ho() { # <檔名> <status> <date>
    cat > "$HANDOFF_DIR/$1" <<EOF
---
from: planner
to: ui-builder
date: $3
priority: high
status: $2
---

# Handoff

## 起因
測試用交接。
EOF
}

reset; mk_ho done.md completed 2026-03-04-1200
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$ARCH/2026-03/done.md" ] \
    && ok "completed 被搬進 archive/YYYY-MM/（月份取 date:）" \
    || ng "completed 被搬進 archive/YYYY-MM/（月份取 date:）" "archive/2026-03/done.md" \
          "$(find "$HANDOFF_DIR" -name 'done.md' 2>/dev/null | sed "s|$SANDBOX||" | tr '\n' ' ')"
[ -f "$HANDOFF_DIR/done.md" ] \
    && ng "已歸檔的不留在平坦層" "平坦層無 done.md" "還在" \
    || ok "已歸檔的不留在平坦層"

reset; mk_ho cancel.md cancelled 2026-07-31-0900
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$ARCH/2026-07/cancel.md" ] \
    && ok "cancelled 也被歸檔" \
    || ng "cancelled 也被歸檔" "archive/2026-07/cancel.md" \
          "$(find "$HANDOFF_DIR" -type f 2>/dev/null | sed "s|$SANDBOX||" | tr '\n' ' ')"

reset; mk_ho keep.md pending 2026-03-04-1200
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$HANDOFF_DIR/keep.md" ] \
    && ok "pending 留在平坦層" \
    || ng "pending 留在平坦層" "handoffs/keep.md 還在" "被搬走了"

# 範本的 frontmatter 字面就含 completed（`<pending|accepted|completed|cancelled>`）
reset; cp "$HOOK_DIR/../coordination/handoffs/_HANDOFF_TEMPLATE.md" "$HANDOFF_DIR/" 2>/dev/null
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$HANDOFF_DIR/_HANDOFF_TEMPLATE.md" ] \
    && ok "範本檔不被歸檔（frontmatter 字面含 completed）" \
    || ng "範本檔不被歸檔（frontmatter 字面含 completed）" "範本原地不動" "被搬走了"

# 審計軌跡不能被吃掉：同名一律加後綴
reset; mk_ho dup.md completed 2026-03-04-1200
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
mk_ho dup.md completed 2026-03-04-1200
echo "第二份的指紋" >> "$HANDOFF_DIR/dup.md"
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
if [ -f "$ARCH/2026-03/dup-2.md" ] \
   && ! grep -q "第二份的指紋" "$ARCH/2026-03/dup.md" 2>/dev/null \
   && grep -q "第二份的指紋" "$ARCH/2026-03/dup-2.md" 2>/dev/null; then
    ok "同名不覆蓋：加 -2 後綴且原檔一字不動"
else
    ng "同名不覆蓋：加 -2 後綴且原檔一字不動" "dup.md 保持原樣＋dup-2.md 是新的" \
       "$(ls "$ARCH/2026-03" 2>/dev/null | tr '\n' ' ')"
fi

reset; mk_ho done.md completed 2026-03-04-1200; echo off > "$SM_FILE"
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$HANDOFF_DIR/done.md" ] \
    && ok "suggest-mode=off 不歸檔（逃生門連歸檔一起關）" \
    || ng "suggest-mode=off 不歸檔（逃生門連歸檔一起關）" "檔案原地不動" "被搬走了"

# archive/ 不能被 pending 掃描撈到，否則歸檔等於沒用（glob 不遞迴）
reset; mkdir -p "$ARCH/2026-03"; mk_ho tmp.md pending 2026-03-04-1200
mv "$HANDOFF_DIR/tmp.md" "$ARCH/2026-03/old-pending.md"
expect_empty "archive/ 裡的 pending 不被掃描" "$(run post-agent-report.sh '{"tool_name":"Agent"}')"

reset
printf '%s\n' '---' 'from: x' 'to: y' 'status: completed' '---' > "$HANDOFF_DIR/nodate.md"
touch -d '2025-11-15' "$HANDOFF_DIR/nodate.md" 2>/dev/null
run post-agent-report.sh '{"tool_name":"Agent"}' >/dev/null
[ -f "$ARCH/2025-11/nodate.md" ] \
    && ok "無 date: 時退回 mtime 的月份" \
    || ng "無 date: 時退回 mtime 的月份" "archive/2025-11/nodate.md" \
          "$(find "$ARCH" -type f 2>/dev/null | sed "s|$SANDBOX||" | tr '\n' ' ')"

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

# 執行期 bug 與建置錯誤要分流到不同 agent
reset
expect_contains "執行期 bug → debug-investigator"  "debug-investigator" "$(run user-prompt-submit.sh "$(p '登入之後頁面沒反應，怪怪的')")"
expect_contains "建置錯誤 → build-error-resolver"  "build-error-resolver" "$(run user-prompt-submit.sh "$(p 'tsc 型別錯誤修不掉')")"
expect_contains "開 PR → /pr"                "/pr"                   "$(run user-prompt-submit.sh "$(p '幫我開 PR')")"
expect_contains "依賴維護 → /deps"           "/deps"                 "$(run user-prompt-submit.sh "$(p '幫我升級套件')")"
expect_contains "技術選型 → /adr"            "/adr"                  "$(run user-prompt-submit.sh "$(p 'Redux 還是 Zustand 比較好？要用哪個')")"

reset
expect_contains "文件維護 → documentation-specialist" "documentation-specialist" \
    "$(run user-prompt-submit.sh "$(p '幫我整理更新文件')")"
expect_contains "更新 README → documentation-specialist" "documentation-specialist" \
    "$(run user-prompt-submit.sh "$(p '更新一下 README 和 API 文檔')")"
expect_contains "PRD/ADR → workflow-template-manager" "workflow-template-manager" \
    "$(run user-prompt-submit.sh "$(p '把 PRD 的架構文檔同步一下')")"
expect_contains "路由用命令式而非建議式"      'subagent_type' \
    "$(run user-prompt-submit.sh "$(p '幫我整理更新文件')")"

reset; echo off > "$SM_FILE"
expect_empty   "suggest-mode=off 不注入"     "$(run user-prompt-submit.sh "$(p '實作登入認證')")"

# critical 關鍵字分兩級：login／session 單獨出現（UI、文案）不建議 critical，
# 要碰到認證或授權邏輯本身才算。舊規則把「改登入頁的按鈕顏色」也推成 critical
# （必須 /plan＋最嚴的覆蓋率門檻）。
expect_not_contains() { # <說明> <不該出現的字串> <實際輸出>
    case "$3" in
        *"$2"*) ng "$1" "（不含）$2" "$3" ;;
        *) ok "$1" ;;
    esac
}
reset
expect_not_contains "login 頁的 UI 改動不建議 critical" "critical" \
    "$(run user-prompt-submit.sh "$(p '改 login 頁的按鈕顏色')")"
expect_not_contains "session 逾時提示文字不建議 critical" "critical" \
    "$(run user-prompt-submit.sh "$(p '把 session 逾時的提示文字改短一點')")"
expect_contains "login 的密碼驗證邏輯 → critical" "critical" \
    "$(run user-prompt-submit.sh "$(p '改 login 的密碼驗證邏輯')")"
expect_contains "session＋token 過期處理 → critical" "critical" \
    "$(run user-prompt-submit.sh "$(p 'session 過期時要自動 refresh token')")"
expect_contains "認證訊息不再重述覆蓋率百分比" "testing-standards" \
    "$(run user-prompt-submit.sh "$(p '實作登入認證')")"

# subagent 交回的報告不是使用者提問。實測（2026-09-17 transcript）harness 把報告
# 當成一則 user 訊息送進來、UserPromptSubmit 照樣觸發，報告內文的關鍵字於是
# 注入一串無關建議。開頭三行有 hand-back 標記就跳過路由。
HANDBACK=$(printf '%s\n%s\n%s\n%s' 'Another Claude session sent a message:' \
    '<agent-message from="a0cf8e0e9898705e7">' \
    '[Subagent hand-back] The text below is the final report of a subagent this session delegated to.' \
    '  改了認證邏輯、部署設定與測試覆蓋率，請 code review')
reset
expect_empty "subagent hand-back 不做意圖路由" "$(run user-prompt-submit.sh "$(p "$HANDBACK")")"
expect_empty "背景工作完成通知不做意圖路由" \
    "$(run user-prompt-submit.sh "$(p "$(printf '<task-notification>\n<task-id>x</task-id>\n<summary>認證 部署 測試</summary>')")")"
expect_contains "使用者原話中途引用 [Subagent hand-back] 仍照常路由" "critical" \
    "$(run user-prompt-submit.sh "$(p "$(printf '幫我改認證邏輯\n第二行\n第三行\n剛才看到 [Subagent hand-back] 的字樣')")")"

# 前端路由（D10）：`ui`／`css` 曾是裸子字串，quick、build、guide、access 都會命中；
# 反過來「做個官網」「這個形象頁」這種從不講 UI 的說法又漏接
reset
for q in 'quick fix 一下 build 腳本' '看一下 guide' 'QUICK BUILD GUIDE' '這個 access token 的 test suite'; do
    expect_not_contains "前端路由不被「$q」誤觸發" "ui-style-compliance" \
        "$(run user-prompt-submit.sh "$(p "$q")")"
done
for q in '幫我做一個 landing page' '做餐廳的官網' 'UI 調整一下' '這個形象頁' '改一下ui的間距' '改 style.css 的顏色' '幫我做一個咖啡店的形象網站'; do
    expect_contains "前端路由接得到「$q」" "ui-style-compliance" \
        "$(run user-prompt-submit.sh "$(p "$q")")"
done

# =========================================================================
section "pre-tool-use.sh — 坑閘門（context/learned/）"
# =========================================================================
# 建一份坑紀錄：files: 用區塊寫法，另一份用行內寫法，兩種都要能觸發
mk_pitfall() {
    mkdir -p "$SANDBOX/.claude/context/learned"
    cat > "$SANDBOX/.claude/context/learned/$1.md" <<EOF
---
date: 2026-08-19
title: $2
files:
  - "$3"
symptom: 換 site 後回 401
root-cause: token 快取沒把 site 併進 key
guard: 快取 key 必須含 site_id
severity: high
---
EOF
}

reset; echo standard > "$MODE_FILE"
mk_pitfall "oauth-site-scope" "OAuth token 不能跨 site 重用" "backend/mcp/*.py"
out=$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/client.py")")
expect_decision "命中 learned 的檔案被擋一次"      deny  "$out"
expect_contains "deny 理由含根因"                  "token 快取沒把 site 併進 key" "$out"
expect_contains "deny 理由含避法"                  "快取 key 必須含 site_id"      "$out"
expect_decision "同檔案第二次放行（deny-once）"    allow "$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/client.py")")"
expect_decision "無關檔案不受影響"                 allow "$(run pre-tool-use.sh "$(w "$SANDBOX/frontend/Button.tsx")")"

reset; echo standard > "$MODE_FILE"
mk_pitfall "inline-form" "行內 files 寫法" "x"
printf -- '---\ndate: 2026-08-19\ntitle: 行內寫法\nfiles: ["src/api/**/*.ts"]\nsymptom: s\nroot-cause: r\nguard: g\nseverity: low\n---\n' \
    > "$SANDBOX/.claude/context/learned/inline-form.md"
expect_decision "files 行內寫法也能觸發"           deny  "$(run pre-tool-use.sh "$(w "$SANDBOX/src/api/v1/h.ts")")"

reset; echo standard > "$MODE_FILE"
mkdir -p "$SANDBOX/.claude/context/learned"
cp "$SANDBOX/../.gitkeep" /dev/null 2>/dev/null || true
printf -- '---\ndate: 2026-01-01\ntitle: 範本\nfiles:\n  - "backend/models.py"\nsymptom: s\nroot-cause: r\nguard: g\n---\n' \
    > "$SANDBOX/.claude/context/learned/_PITFALL_TEMPLATE.md"
expect_decision "_ 開頭的範本檔不被當真紀錄"       allow "$(run pre-tool-use.sh "$(w "$SANDBOX/backend/models.py")")"

reset; echo standard > "$MODE_FILE"
mk_pitfall "escape" "逃生門測試" "backend/mcp/*.py"
expect_decision "PITFALL_GATE=off 關閉坑閘門"      allow "$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/a.py")" PITFALL_GATE=off)"

reset; echo standard > "$MODE_FILE"
expect_decision "沒有 learned 目錄時不誤擋"        allow "$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/a.py")")"

# 任務模式閘門優先於坑閘門（沒判級時先要求判級，訊息不該混淆）
reset
mk_pitfall "order" "順序測試" "backend/mcp/*.py"
out=$(run pre-tool-use.sh "$(w "$SANDBOX/backend/mcp/a.py")")
expect_decision "無模式檔時仍先擋任務模式"         deny  "$out"
expect_contains "且理由是判級而非坑"               "尚未判定任務模式" "$out"

# =========================================================================
section "post-write.sh — 文件影響偵測"
# =========================================================================
IMPACT="$SANDBOX/.claude/taskmaster-data/.doc-impact"
NOTIFIED="$SANDBOX/.claude/taskmaster-data/.doc-impact-notified"
pw() { run post-write.sh "$(w "$SANDBOX/$1")"; }

reset
out=$(pw "src/api/reconcile/route.ts")
expect_contains "API 檔第一次命中會注入提醒"   "文件影響提醒" "$out"
expect_contains "提醒指向 /verify 會擋"        "/verify"      "$out"
expect_empty   "同任務第二次不再吵"            "$(pw "src/models/ledger.ts")"
if grep -qxF "src/models/ledger.ts" "$IMPACT" 2>/dev/null; then ok "不吵但仍累積進清單"
else ng "不吵但仍累積進清單" "清單含 src/models/ledger.ts" "$(cat "$IMPACT" 2>/dev/null)"; fi

reset
expect_empty   "一般實作檔不觸發"              "$(pw "src/utils/format.ts")"
if [ ! -f "$IMPACT" ]; then ok "一般實作檔不建清單"
else ng "一般實作檔不建清單" "無 .doc-impact" "$(cat "$IMPACT")"; fi

# 各類「文件會描述的檔案」都要認得
for f in "src/routes/user.ts" "api/openapi.yaml" "proto/svc.proto" \
         "db/migrations/001_init.sql" "src/entities/Order.ts" "src/lib/index.ts" \
         "types/global.d.ts" "src/cli/main.ts" ".env.example"; do
    reset
    expect_contains "認得 $f" "文件影響提醒" "$(pw "$f")"
done

# 排除項
#
# 注意 `.claude/hooks/x.sh` 已從這份清單移出：它現在會命中「擴充維護提醒」
# （見下一組測試）。文件影響偵測仍然不管它——兩個提醒的判斷是分開的。
for f in "src/api/route.test.ts" "src/api/user.spec.ts" "docs/api.md" \
         "node_modules/pkg/index.js" "dist/index.js" \
         "__tests__/api/index.ts"; do
    reset
    expect_empty "排除 $f" "$(pw "$f")"
done

reset
expect_empty   "DOC_SYNC_GATE=off 關閉偵測" \
    "$(run post-write.sh "$(w "$SANDBOX/src/api/x.ts")" DOC_SYNC_GATE=off)"

reset; echo off > "$SM_FILE"
expect_empty   "suggest-mode=off 也關閉偵測"   "$(pw "src/api/x.ts")"

# =========================================================================
section "post-write.sh — 前端寫入檢查（lib/ui-lint.sh）"
# =========================================================================
#
# 檢查的是磁碟上的檔案（Edit 的 payload 只有被換掉的那段），所以每個案例都真的建檔。
UI_JSON="$SANDBOX/.claude/taskmaster-data/ui-style.json"
uw() { # <相對路徑> <內容> [ENV=VAL ...] → post-write 的 additionalContext
    local rel="$1" body="$2"; shift 2
    mkdir -p "$(dirname "$SANDBOX/$rel")"
    printf '%s\n' "$body" > "$SANDBOX/$rel"
    run post-write.sh "$(w "$SANDBOX/$rel")" "$@" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
ui_clean() { rm -rf "$SANDBOX/src" "$SANDBOX/docs"; }

reset; ui_clean
out=$(uw "src/components/Hero.tsx" "$(printf 'export const Hero = () => (\n  <h1 style={{ color: %s }}>Hi</h1>\n)' "'#1D1D1F'")")
expect_contains "元件寫死色碼 → 提醒"                 "寫死色碼"   "$out"
expect_contains "提醒帶行號與色碼"                    'L2 `#1D1D1F`' "$out"
expect_contains "提醒說明只提醒不擋"                  "只提醒，不擋" "$out"

reset; ui_clean
expect_empty "tokens 檔的 CSS 變數宣告不提醒" "$(uw "src/styles/tokens.css" "$(printf ':root {\n  --color-primary: #1D1D1F;\n}')")"
expect_empty "tokens 檔裡的一般 hex 也不提醒" "$(uw "src/styles/tokens.css" '.a { color: #fff; }')"
expect_empty "一行內的 :root 自訂屬性不提醒"  "$(uw "src/app.css" ':root { --c: #fff; }')"
expect_empty "var() 的備援值不算寫死"         "$(uw "src/app.css" '.a { color: var(--c, #000); }')"
expect_empty "頁內錨點 #face 不是色碼"        "$(uw "src/Nav.tsx" '<a href="#face">x</a>')"
expect_empty "HTML 實體 &#8212; 不是色碼"     "$(uw "src/Nav.html" '<p>a &#8212; b</p>')"
expect_empty "theme 檔不提醒"                 "$(uw "src/theme.css" '.a { color: #fff; }')"
expect_empty "測試檔不提醒"                   "$(uw "src/Hero.test.tsx" "expect(c).toBe('#fff')")"
expect_empty "非前端副檔名不提醒"             "$(uw "src/colors.ts" "export const c = '#fff'")"
expect_empty "docs/ 不提醒"                   "$(uw "docs/demo.html" '<p style="color:#fff">x</p>')"
reset; mkdir -p "$SANDBOX/.claude/ui/x"
printf '<p style="color:#fff">x</p>\n' > "$SANDBOX/.claude/ui/x/preview.html"
expect_empty ".claude/** 不提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/ui/x/preview.html")" | jq -r '.hookSpecificOutput.additionalContext // ""')"

# payload 沒帶 cwd 時 WORK_ROOT 退回主 checkout，worktree 裡的檔案相對路徑會以 .claude/worktrees/ 開頭
reset; mkdir -p "$SANDBOX/.claude/worktrees/wt1/src"
printf "<p style={{color: '#fff'}}>x</p>\n" > "$SANDBOX/.claude/worktrees/wt1/src/Hero.tsx"
expect_contains "worktree 裡的前端檔照樣檢查" "寫死色碼" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/worktrees/wt1/src/Hero.tsx")" | jq -r '.hookSpecificOutput.additionalContext // ""')"

# 動畫等級：沒有 ui-style.json＝還沒定調，不檢查
GSAP_SRC="$(printf "import gsap from 'gsap'\nexport const A = () => null")"
reset; ui_clean
expect_empty "沒有 ui-style.json → 不做 motion 檢查" "$(uw "src/Anim.tsx" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"
out=$(uw "src/Anim.tsx" "$GSAP_SRC")
expect_contains "L1 卻 import gsap → 提醒"       "動畫等級不符" "$out"
expect_contains "motion 提醒帶 import 的行號"     "L1 \`import gsap from 'gsap'\`" "$out"
reset; ui_clean; echo '{"motion":"L2"}' > "$UI_JSON"
expect_empty "L2 import gsap → 不提醒" "$(uw "src/Anim.tsx" "$GSAP_SRC")"
expect_contains "L2 import three → 提醒" "動畫等級不符" "$(uw "src/Scene.tsx" "import * as THREE from 'three'")"
expect_contains "L2 用 CDN 載 three.js → 提醒" "動畫等級不符" \
    "$(uw "src/index.html" '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>')"
reset; ui_clean; echo '{"motion":"L3"}' > "$UI_JSON"
expect_empty "L3 import three → 不提醒" "$(uw "src/Scene.tsx" "import * as THREE from 'three'")"
reset; ui_clean; echo '{"source":"vercel"}' > "$UI_JSON"
expect_contains "ui-style.json 沒有 motion → 當 L1（motion.md 的規定）" "動畫等級不符" "$(uw "src/Anim.tsx" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"
expect_empty "L1 但文字裡提到 three 不算 import" "$(uw "src/Copy.tsx" '<p>three steps to motion</p>')"
expect_contains "L1 的 framer-motion 也算" "動畫等級不符" "$(uw "src/M.tsx" 'import { motion } from "framer-motion"')"

# AI 痕跡（P0，改寫自 avoid-ai-design 的 detect.mjs：C6／C1／K1）
reset; ui_clean
out=$(uw "src/Title.tsx" '<h1 className="bg-gradient-to-r from-indigo-500 to-purple-600 bg-clip-text text-transparent">Hi</h1>')
expect_contains "Tailwind 漸層字 → C6" "**C6**" "$out"
expect_contains "Tailwind 紫靛漸層 → C1" "**C1**" "$out"
expect_contains "AI 痕跡提醒附出處" "avoid-ai-design" "$out"
expect_contains "CSS background-clip:text＋透明字 → C6" "**C6**" \
    "$(uw "src/t.css" "$(printf '.t {\n  background-clip: text;\n  -webkit-text-fill-color: transparent;\n}')")"
expect_contains "shadcn 預設 --primary → K1" "**K1**" \
    "$(uw "src/globals.css" "$(printf ':root {\n  --primary: oklch(0.205 0 0);\n}')")"
expect_empty "改過的 --primary 不算 K1" \
    "$(uw "src/globals.css" "$(printf ':root {\n  --primary: oklch(0.45 0.12 30);\n}')")"
expect_empty "藍綠漸層不算 C1" "$(uw "src/B.tsx" '<div className="bg-gradient-to-r from-sky-500 to-emerald-500">x</div>')"
expect_empty "上一行 avoid-ai-design-ignore: C6 → 豁免" \
    "$(uw "src/I.tsx" "$(printf '{/* avoid-ai-design-ignore: C6 */}\n<h1 className="bg-clip-text text-transparent">x</h1>')")"
out=$(uw "src/J.css" "$(printf '/* avoid-ai-design-ignore-file: K1 */\n:root {\n  --primary: oklch(0.205 0 0);\n}\n.t { background-clip: text; color: transparent; }')")
expect_not_contains "整檔豁免 K1 → 不報 K1"   "**K1**" "$out"
expect_contains     "整檔豁免 K1 → 仍報 C6"   "**C6**" "$out"
expect_empty "整檔豁免不帶 ID → 全部豁免" \
    "$(uw "src/K.tsx" "$(printf '{/* avoid-ai-design-ignore-file */}\n<h1 className="bg-clip-text text-transparent">x</h1>')")"

# 動畫等級以單頁 IA snippet 為準（motion.md 開頭）。對應得到才用單頁等級；
# 對應不到（元件檔、沒有 snippet 的頁）就取「專案與所有單頁中最寬鬆的那級」——寧可漏提醒也不誤報。
IA_DOC="$SANDBOX/docs/17_frontend_information_architecture.md"
ia_page() { # <頁面路徑> <動畫等級那一行的值> —— append 一份最小 IA snippet
    mkdir -p "$(dirname "$IA_DOC")"
    printf '## 某頁（%s）\n\n### 實作筆記\n- 狀態管理：無\n- 動畫等級：%s\n\n' "$1" "$2" >> "$IA_DOC"
}
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"; ia_page / '本頁另外調為 L2'
expect_empty "專案 L1、首頁另外調為 L2 → app/page.tsx import gsap 不提醒" "$(uw "src/app/page.tsx" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L2"}' > "$UI_JSON"; ia_page /pricing '本頁另外調為 L1'
out=$(uw "src/app/pricing/page.tsx" "$GSAP_SRC")
expect_contains "專案 L2、定價頁另外調為 L1 → 該頁 import gsap 要提醒" "動畫等級不符" "$out"
expect_contains "提醒講明等級來自單頁 IA snippet" "IA snippet" "$out"
expect_contains "pages router（pages/about.vue）也對應得到" "動畫等級不符" \
    "$(ia_page /about '本頁另外調為 L1'; uw "src/pages/about.vue" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"; ia_page /pricing '本頁另外調為 L2'
expect_empty "route group (marketing) 去掉後對應到 /pricing（L2）→ 不提醒" \
    "$(uw "src/app/(marketing)/pricing/page.tsx" "$GSAP_SRC")"
expect_empty "對應不到頁面的元件、有單頁調到 L2 → 不提醒（保守）" \
    "$(uw "src/components/sections/PricingCards.tsx" "$GSAP_SRC")"
expect_contains "對應不到時仍守最寬鬆那級：L2 之上的 three 照樣提醒" "動畫等級不符" \
    "$(uw "src/components/sections/Scene.tsx" "import * as THREE from 'three'")"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"; ia_page /pricing '沿用專案 L1'
expect_contains "單頁寫「沿用專案」→ 照專案 L1 提醒" "動畫等級不符" "$(uw "src/app/pricing/page.tsx" "$GSAP_SRC")"
reset; ui_clean; echo '{"motion":"L2"}' > "$UI_JSON"; ia_page /pricing '本頁另外調為 L1'
expect_empty "只有單頁往下調時，對應不到的元件照專案 L2 → gsap 不提醒" "$(uw "src/components/A.tsx" "$GSAP_SRC")"
ui_clean

# 路徑排除與 hooks/README.md、post-write.sh 一致：測試、fixtures、vendor、壓縮過的 css
HEXSRC="<p style={{color: '#fff'}}>x</p>"
ui_xclean() { rm -rf "$SANDBOX/test" "$SANDBOX/tests" "$SANDBOX/fixtures" "$SANDBOX/vendor" "$SANDBOX/public"; ui_clean; }
reset; ui_xclean
expect_empty "test/ 不提醒"            "$(uw "test/Hero.tsx" "$HEXSRC")"
expect_empty "tests/ 不提醒"           "$(uw "src/tests/Hero.tsx" "$HEXSRC")"
expect_empty "fixtures 不提醒"         "$(uw "src/__fixtures__/Hero.tsx" "$HEXSRC")"
expect_empty "vendor/ 不提醒"          "$(uw "vendor/lib.css" '.a { color: #fff; }')"
expect_empty "public/vendor/ 不提醒"   "$(uw "public/vendor/x/lib.css" '.a { color: #fff; }')"
expect_empty "*.min.css 不提醒"        "$(uw "src/styles/app.min.css" '.a{color:#fff}')"
expect_contains "名稱只是含 test 的元件照樣檢查（Testimonials.tsx）" "寫死色碼" \
    "$(uw "src/components/Testimonials.tsx" "$HEXSRC")"
ui_xclean

# 逃生門與合併輸出
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"
BOTH="$(printf "import gsap from 'gsap'\nexport const A = () => <p style={{color: '#fff'}}>x</p>")"
expect_empty "UI_LINT=off → 兩種提醒都沒有" "$(uw "src/Both.tsx" "$BOTH" UI_LINT=off)"
reset; ui_clean; echo '{"motion":"L1"}' > "$UI_JSON"; echo off > "$SM_FILE"
expect_empty "suggest-mode=off → 也不檢查" "$(uw "src/Both.tsx" "$BOTH")"
reset; ui_clean
raw=$(mkdir -p "$SANDBOX/src/components" && printf "export const A = () => <p style={{color: '#fff'}}>x</p>\n" > "$SANDBOX/src/components/index.tsx" \
      && run post-write.sh "$(w "$SANDBOX/src/components/index.tsx")")
if echo "$raw" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1; then
    ok "同時命中文件影響與色碼 → 仍是一個合法 JSON"
else
    ng "同時命中文件影響與色碼 → 仍是一個合法 JSON" "單一 PostToolUse JSON" "${raw:0:120}"
fi
out=$(echo "$raw" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
expect_contains "合併輸出含文件影響提醒" "文件影響提醒" "$out"
expect_contains "合併輸出含寫死色碼"     "寫死色碼"     "$out"
ui_clean

# post-write 先用副檔名與路徑篩過才啟動 ui-lint：每次寫檔多開一個 bash 在這台機器要好幾百毫秒，
# 而絕大多數寫入是 .claude/**、.md、.ts。用一份 hooks 複本把 ui-lint 換成「被叫就留記號」來驗。
PW_COPY="$SANDBOX/hookcopy"; PW_MARK="$SANDBOX/ui-lint-called"
rm -rf "$PW_COPY"; mkdir -p "$PW_COPY"
cp "$HOOK_DIR"/*.sh "$PW_COPY/"; cp -r "$HOOK_DIR/lib" "$PW_COPY/lib"
printf '#!/bin/bash\necho "$2" >> "%s"\n' "$PW_MARK" > "$PW_COPY/lib/ui-lint.sh"
pw_called() { # <相對路徑> → 印出 yes／no
    rm -f "$PW_MARK"; mkdir -p "$(dirname "$SANDBOX/$1")"; echo x > "$SANDBOX/$1"
    printf '%s' "$(w "$SANDBOX/$1")" | env CLAUDE_PROJECT_DIR="$SANDBOX" bash "$PW_COPY/post-write.sh" >/dev/null 2>&1
    [ -s "$PW_MARK" ] && echo yes || echo no
}
reset
expect_eq "寫 .claude/skills/x/SKILL.md 不啟動 ui-lint" no  "$(pw_called .claude/skills/x/SKILL.md)"
expect_eq "寫 .claude/ui/x/preview.html 不啟動 ui-lint" no "$(pw_called .claude/ui/x/preview.html)"
expect_eq "寫 src/a.ts 不啟動 ui-lint"                 no  "$(pw_called src/a.ts)"
expect_eq "寫 README.md 不啟動 ui-lint"                no  "$(pw_called README.md)"
expect_eq "寫 src/A.tsx 照樣啟動 ui-lint"              yes "$(pw_called src/A.tsx)"
expect_eq "寫 src/A.CSS（大寫副檔名）照樣啟動"         yes "$(pw_called src/A.CSS)"
expect_eq "worktree 裡的 .claude/worktrees/w/src/A.vue 照樣啟動" yes "$(pw_called .claude/worktrees/w/src/A.vue)"
rm -rf "$PW_COPY" "$PW_MARK" "$SANDBOX/README.md" "$SANDBOX/.claude/worktrees"; ui_clean

# =========================================================================
section "post-write.sh — 擴充維護提醒（.claude/ 底下的改動）"
# =========================================================================
#
# 為什麼要這組：改 skill／agent 有三件事會安靜失效（接線沒接上、INDEX 沒同步、
# description 是內容摘要），而使用者不會知道要主動跑稽核。判斷得出時機就由 hook 提出。

# 應命中的五種擴充
for f in ".claude/skills/x/SKILL.md" ".claude/agents/x.md" ".claude/commands/x.md" \
         ".claude/rules/x.md" ".claude/hooks/x.sh"; do
    reset
    expect_contains "擴充提醒認得 $f" "擴充維護提醒" "$(pw "$f")"
done

# 排除：測試與執行時產物（跑測試或寫報告時不該自己觸發自己）
for f in ".claude/hooks/tests/run-tests.sh" ".claude/tests/skill-compliance/README.md" \
         ".claude/context/quality/r.md" ".claude/coordination/handoffs/x.md" \
         ".claude/taskmaster-data/.current-task-mode"; do
    reset
    expect_empty "擴充提醒排除 $f" "$(pw "$f")"
done

# 專案自己的同名目錄不該被誤命中
reset
expect_empty "擴充提醒不誤命中 src/hooks/useAuth.ts" "$(pw "src/hooks/useAuth.ts")"

# 本任務只提醒一次
reset
pw ".claude/skills/x/SKILL.md" >/dev/null
expect_empty "擴充提醒只發一次" "$(pw ".claude/agents/y.md")"

# 逃生門
reset
expect_empty "SKILL_CURATOR_GATE=off 關閉擴充提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/skills/x/SKILL.md")" SKILL_CURATOR_GATE=off)"

# 關掉擴充提醒不該影響文件影響偵測
reset
expect_contains "關掉擴充提醒後文件偵測仍運作" "文件影響提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/src/api/x.ts")" SKILL_CURATOR_GATE=off)"

# 反之：關掉文件偵測不該影響擴充提醒
reset
expect_contains "關掉文件偵測後擴充提醒仍運作" "擴充維護提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/skills/x/SKILL.md")" DOC_SYNC_GATE=off)"

# 變更清單要累積且去重
reset
pw ".claude/skills/a/SKILL.md" >/dev/null
pw ".claude/agents/b.md" >/dev/null
pw ".claude/agents/b.md" >/dev/null
SK_LIST="$SANDBOX/.claude/taskmaster-data/.skill-impact"
if [ "$(wc -l < "$SK_LIST" 2>/dev/null | tr -d ' ')" = "2" ]; then ok "擴充變更清單去重累積"
else ng "擴充變更清單去重累積" "2 行" "$(wc -l < "$SK_LIST" 2>/dev/null | tr -d ' ')"; fi

# WBS 歷史紀錄（原有行為不能被新功能弄壞）
reset
run post-write.sh "$(w "$SANDBOX/.claude/taskmaster-data/wbs.md")" >/dev/null
if [ -f "$SANDBOX/.claude/taskmaster-data/wbs-history.log" ]; then ok "WBS 寫入仍記歷史"
else ng "WBS 寫入仍記歷史" "有 wbs-history.log" "（無）"; fi

# ---- WBS 格子長度提醒 ----
#
# 長度必須以「字」計：一個中文字在 UTF-8 是 3 bytes，用位元組算的話
# 14 個中文字就超標，短格子會被誤報。連結的 `](目標)` 不計入。
WBS_F="$SANDBOX/.claude/taskmaster-data/wbs.md"
wbs_doc() {   # $1 = 13.1 那一列的「狀態」格，$2 = 「連結」格
    printf '%s\n' "# WBS — 測試" "" "## 現況" "" \
        "| 里程碑 | 進度 | 狀態 | 目標日 |" "|---|---|---|---|" "| M1 測試 | ░░░░░ 0/1 | 🔄 進行中 | 11-15 |" "" \
        "## M1 測試" "" \
        "| # | 任務 | 狀態 | 優先 | 依賴 | 預估 | 連結 |" "|---|---|---|---|---|---|---|" \
        "| 13.1 | 地端 rerank 拒答門檻 | $1 | 高 | — | 4h | $2 |" > "$WBS_F"
}
LONG_ZH='✅ 09-23 hit@5 達百分之九十五點八，帶到下一任務的疑慮有三項，選型理由是延遲較低且主機已確認'
SHORT_ZH='進行中，三十個中文字以內的狀態說明大約就是這樣長度而已不會更多了'   # 32 字、96 bytes
LONG_LINK='[計畫](plans/archive/13.1-a-very-long-plan-slug-that-goes-on-and-on-and-on.md) ・ [報告](../context/test/2026-09-23-evaluation-report-with-a-really-long-name.md)'

reset; wbs_doc "$LONG_ZH" "—"
WBS_OUT=$(run post-write.sh "$(w "$WBS_F")")
expect_contains "WBS 中文超長格子會提醒"       "WBS 格子太長"   "$WBS_OUT"
expect_contains "WBS 提醒指出任務編號與欄位"   "13.1 的「狀態」" "$WBS_OUT"
expect_contains "WBS 提醒附長內容去處"         "執行帳本"       "$WBS_OUT"

reset; wbs_doc "$SHORT_ZH" "—"
expect_empty "WBS 短中文格子不提醒（以字計、非位元組）" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc "🔄 進行中" "$LONG_LINK"
expect_empty "WBS 長連結網址不誤報" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc "🔄 進行中" "—"
sed -i "s/| 地端 rerank 拒答門檻 |/| ${LONG_ZH} |/" "$WBS_F"
expect_empty "WBS 任務欄寫完整名稱不提醒" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc "$LONG_ZH" "—"
expect_empty "WBS 長度提醒逃生門 WBS_CELL_CHECK=off" "$(run post-write.sh "$(w "$WBS_F")" WBS_CELL_CHECK=off)"
if [ -f "$SANDBOX/.claude/taskmaster-data/wbs-history.log" ]; then ok "WBS 長度提醒關閉時仍記歷史"
else ng "WBS 長度提醒關閉時仍記歷史" "有 wbs-history.log" "（無）"; fi

# 8 欄版面（預估與連結之間有「負責」）：欄名依表頭取，不能依位置
wbs_doc8() {   # $1 = 「狀態」格，$2 = 「負責」格，$3 = 「連結」格
    printf '%s\n' "# WBS — 測試" "" "## 現況" "" \
        "| 里程碑 | 進度 | 狀態 | 目標日 |" "|---|---|---|---|" "| M1 測試 | ░░░░░ 0/1 | 🔄 進行中 | 11-15 |" "" \
        "## M1 測試" "" \
        "| # | 任務 | 狀態 | 優先 | 依賴 | 預估 | 負責 | 連結 |" "|---|---|---|---|---|---|---|---|" \
        "| 13.1 | 地端 rerank 拒答門檻 | $1 | 高 | — | 4h | $2 | $3 |" > "$WBS_F"
}

reset; wbs_doc8 "🔄 進行中" "$LONG_ZH" "—"
WBS_OUT=$(run post-write.sh "$(w "$WBS_F")")
expect_contains     "WBS 8 欄：超長負責格標「負責」"     "13.1 的「負責」" "$WBS_OUT"
expect_not_contains "WBS 8 欄：超長負責格不誤標成「連結」" "13.1 的「連結」" "$WBS_OUT"

reset; wbs_doc8 "🔄 進行中" "alice" "—"
expect_empty "WBS 8 欄：短負責格不提醒" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc8 "$LONG_ZH" "alice" "—"
expect_contains "WBS 8 欄：超長狀態格仍標「狀態」" "13.1 的「狀態」" "$(run post-write.sh "$(w "$WBS_F")")"

reset; wbs_doc8 "🔄 進行中" "alice" "$LONG_LINK"
expect_empty "WBS 8 欄：長連結網址不誤報" "$(run post-write.sh "$(w "$WBS_F")")"

# 舊版面（沒有「現況」區）要順帶指向 /task-status 的轉換
reset
printf '%s\n' "# WBS" "| # | 任務 | 狀態 | 優先級 | 依賴 | 預估 | Plan | 備註 |" "|---|---|---|---|---|---|---|---|" \
    "| 2.1 | 架構 | $LONG_ZH | 高 | - | 2h | - | |" > "$WBS_F"
expect_contains "WBS 舊版面提醒指向 /task-status 轉換" "/task-status" "$(run post-write.sh "$(w "$WBS_F")")"

# ---- hook 語法檢查 ----
#
# 把 hook 改壞的當下沒有任何人告訴你（PostToolUse 不會抱怨），要等下一條指令
# 噴 syntax error 才發現——而改 hook 在這個 repo 是日常。只出聲不擋。
reset; mkdir -p "$SANDBOX/.claude/hooks"
printf 'if true; then\n  echo hi\n' > "$SANDBOX/.claude/hooks/broken.sh"   # 少一個 fi
expect_contains "改壞 hook 會當場報語法錯誤" "語法錯誤" "$(pw ".claude/hooks/broken.sh")"

# 沒壞就完全不出聲，否則每次改 hook 都被洗版
# （關掉擴充提醒以隔離受測對象——它本來就會對 .claude/hooks/* 出聲）
reset; mkdir -p "$SANDBOX/.claude/hooks"
printf 'if true; then\n  echo hi\nfi\n' > "$SANDBOX/.claude/hooks/ok.sh"
expect_empty "語法正常的 hook 不出聲" \
    "$(run post-write.sh "$(w "$SANDBOX/.claude/hooks/ok.sh")" SKILL_CURATOR_GATE=off)"

# =========================================================================
section "user-prompt-submit.sh — planner / architect 路由"
# =========================================================================
reset; echo "# WBS" > "$SANDBOX/.claude/taskmaster-data/wbs.md"
expect_contains "新功能／CR → planner"  'subagent_type: "planner"' \
    "$(run user-prompt-submit.sh "$(p '客戶提了新的 CR，要加一個對帳 API')")"
expect_contains "新功能提醒文件同步"    "必須同步文件" \
    "$(run user-prompt-submit.sh "$(p '我要新增一個匯出報表的功能')")"
reset
expect_contains "技術選型 → architect"  'subagent_type: "architect"' \
    "$(run user-prompt-submit.sh "$(p '這次的技術選型要決定')")"

# =========================================================================
section "報告稽核 — 非同步延後檢查"
# =========================================================================
EXPECT_FILE="$SANDBOX/.claude/taskmaster-data/.report-expectations.jsonl"
CHECKER="$HOOK_DIR/lib/check-report-expectations.sh"

# Agent payload：$1=agent 名稱，$2=async|sync
ag() {
    if [ "$2" = "async" ]; then
        jq -nc --arg a "$1" '{tool_name:"Agent", tool_input:{subagent_type:$a},
            tool_response:{response:"{\"isAsync\": true, \"status\": \"async_launched\"}"}}'
    else
        jq -nc --arg a "$1" '{tool_name:"Agent", tool_input:{subagent_type:$a},
            tool_response:"完成"}'
    fi
}
# 把期望的 epoch 往回推 N 秒，模擬時間流逝
age_expectations() {
    jq -c --argjson n "$1" '.epoch -= $n' "$EXPECT_FILE" > "$EXPECT_FILE.t" \
        && mv -f "$EXPECT_FILE.t" "$EXPECT_FILE"
}

reset; mkdir -p "$SANDBOX/.claude/context/quality"
out=$(run post-agent-report.sh "$(ag code-quality-specialist async)")
expect_empty   "非同步啟動當下不誤報"            "$out"
if [ -s "$EXPECT_FILE" ]; then ok "非同步啟動會記下報告期望"
else ng "非同步啟動會記下報告期望" "期望檔非空" "（空）"; fi
expect_contains "log 記 DEFER 而非 WARN"  "DEFER" \
    "$(cat "$SANDBOX/.claude/logs/context-reports.log" 2>/dev/null)"

expect_empty   "寬限期內（<120s）完全安靜"       "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

age_expectations 300
expect_contains "過寬限期且缺報告 → 要求補寫"    "code-quality-specialist" \
    "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"
expect_empty   "已通知過不重複吵（notified=1）"  "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
echo "# 報告" > "$SANDBOX/.claude/context/quality/code-quality-specialist-2026-09-07-1000.md"
expect_empty   "報告已寫 → 不再要求"             "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"
if [ ! -s "$EXPECT_FILE" ]; then ok "報告已寫 → 期望被清除"
else ng "報告已寫 → 期望被清除" "期望檔為空" "$(cat "$EXPECT_FILE")"; fi

# 舊報告（啟動前就存在）不該被誤認成這次的產出 —— 靠 -newermt 而非 -mmin
reset; mkdir -p "$SANDBOX/.claude/context/quality"
echo "# 舊報告" > "$SANDBOX/.claude/context/quality/code-quality-specialist-2026-01-01-0000.md"
touch -d '2026-01-01' "$SANDBOX/.claude/context/quality/code-quality-specialist-2026-01-01-0000.md" 2>/dev/null
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
expect_contains "啟動前的舊報告不算數"           "code-quality-specialist" \
    "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

# 超過 deadline → 放棄追蹤，不再吵
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 99999
expect_empty   "逾 deadline 放棄追蹤"            "$(bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

# 逃生門
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
expect_empty   "REPORT_AUDIT=off 關閉稽核" \
    "$(REPORT_AUDIT=off bash "$CHECKER" "$SANDBOX/.claude" 2>/dev/null)"

# 同步完成的 agent 仍走當下稽核（沿用舊行為）
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist sync)" >/dev/null
if [ ! -s "$EXPECT_FILE" ]; then ok "同步 agent 不記期望（當下稽核）"
else ng "同步 agent 不記期望（當下稽核）" "期望檔為空" "$(cat "$EXPECT_FILE")"; fi
expect_contains "同步且缺報告 → log 記 WARN"     "WARN" \
    "$(cat "$SANDBOX/.claude/logs/context-reports.log" 2>/dev/null)"

# debug-investigator 曾經不在 AREA 映射裡 → 完全不稽核
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag debug-investigator async)" >/dev/null
if [ -s "$EXPECT_FILE" ]; then ok "debug-investigator 已納入稽核"
else ng "debug-investigator 已納入稽核" "期望檔非空" "（空）"; fi

# 但 quick 模式下它依定義不寫報告（agents/debug-investigator.md 模式表）→ 不能記成缺報告
CR_LOG="$SANDBOX/.claude/logs/context-reports.log"
reset; mkdir -p "$SANDBOX/.claude/context/quality"; echo quick > "$MODE_FILE"
run post-agent-report.sh "$(ag debug-investigator sync)" >/dev/null
if grep -q 'WARN: debug-investigator' "$CR_LOG" 2>/dev/null; then
    ng "quick 模式同步派 debug-investigator 不記 WARN" "無 WARN" "$(cat "$CR_LOG")"
else ok "quick 模式同步派 debug-investigator 不記 WARN"; fi
expect_contains "quick 模式記 SKIP 一行" "SKIP: debug-investigator quick 模式不寫報告" \
    "$(cat "$CR_LOG" 2>/dev/null)"

reset; mkdir -p "$SANDBOX/.claude/context/quality"; echo quick > "$MODE_FILE"
run post-agent-report.sh "$(ag debug-investigator async)" >/dev/null
if grep -q '"agent":"debug-investigator"' "$EXPECT_FILE" 2>/dev/null; then
    ng "quick 模式非同步派 debug-investigator 不記期望" "無該列" "$(cat "$EXPECT_FILE")"
else ok "quick 模式非同步派 debug-investigator 不記期望"; fi

reset; mkdir -p "$SANDBOX/.claude/context/quality"; echo standard > "$MODE_FILE"
run post-agent-report.sh "$(ag debug-investigator sync)" >/dev/null
expect_contains "standard 模式缺報告仍記 WARN" "WARN: debug-investigator completed but no report" \
    "$(cat "$CR_LOG" 2>/dev/null)"

# skill-curator 同一個坑：它寫報告到 context/decisions/，但 AREA 映射沒它，
# 稽核永遠找不到那份報告（CLAUDE.md 的「連帶檢查」明文警告過這一條）
reset; mkdir -p "$SANDBOX/.claude/context/decisions"
run post-agent-report.sh "$(ag skill-curator async)" >/dev/null
if [ -s "$EXPECT_FILE" ]; then ok "skill-curator 已納入稽核"
else ng "skill-curator 已納入稽核" "期望檔非空" "（空）"; fi
if grep -q '"area":"decisions"' "$EXPECT_FILE" 2>/dev/null; then ok "skill-curator 的 area 是 decisions"
else ng "skill-curator 的 area 是 decisions" '"area":"decisions"' "$(cat "$EXPECT_FILE" 2>/dev/null)"; fi

# conflict-resolver 是刻意不列的那一個：它的 tools 沒有 Write，機制上寫不了報告檔。
# 加進映射會變成每次解衝突都發一次假警報 —— 這個「刻意」需要測試釘住，
# 否則下次有人「補齊漏掉的 agent」時會順手加回去
reset
run post-agent-report.sh "$(ag conflict-resolver async)" >/dev/null
if [ ! -s "$EXPECT_FILE" ]; then ok "conflict-resolver 刻意不稽核（tools 無 Write）"
else ng "conflict-resolver 刻意不稽核（tools 無 Write）" "期望檔為空" "$(cat "$EXPECT_FILE")"; fi

# 稽核訊息會被注入（不只寫 log）—— 這是原本「沒有牙齒」的核心問題
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
inj=$(run post-agent-report.sh "$(ag planner sync)")
if echo "$inj" | jq -e '.hookSpecificOutput.additionalContext | test("沒寫報告")' >/dev/null 2>&1; then
    ok "缺報告會經 additionalContext 注入"
else
    ng "缺報告會經 additionalContext 注入" "含「沒寫報告」的注入" "${inj:0:80}"
fi

# 斜線指令也要收到稽核（使用者下一句常是 /verify）
reset; mkdir -p "$SANDBOX/.claude/context/quality"
run post-agent-report.sh "$(ag code-quality-specialist async)" >/dev/null
age_expectations 300
expect_contains "斜線指令仍收到稽核"             "code-quality-specialist" \
    "$(run user-prompt-submit.sh "$(p '/verify')")"

# =========================================================================
section "session-start.sh — 委派指示注入"
# =========================================================================
reset
# 沙箱內備一份 skill：session-start 會讀 $CLAUDE_PROJECT_DIR/.claude/skills/... 注入
mkdir -p "$SANDBOX/.claude/skills/using-taskmaster"
cp "$HOOK_DIR/../skills/using-taskmaster/SKILL.md" \
   "$SANDBOX/.claude/skills/using-taskmaster/SKILL.md" 2>/dev/null || true
sess_out=$(run session-start.sh '{}')
if echo "$sess_out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1; then
    ok "session-start 輸出合法 JSON"
else
    ng "session-start 輸出合法 JSON" "可被 jq 解析的 SessionStart 事件" "${sess_out:0:80}"
fi
sess_ctx=$(echo "$sess_out" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
expect_contains "注入 using-taskmaster 全文"       "using-taskmaster"  "$sess_ctx"
expect_contains "注入含強制委派標記"               "EXTREMELY"         "$sess_ctx"
expect_contains "注入含 documentation-specialist"  "documentation-specialist" "$sess_ctx"
expect_contains "注入含坑目錄指示"                 "context/learned"   "$sess_ctx"

# =========================================================================
section "session-start.sh — 風格庫提醒只在模板 repo 出現"
# =========================================================================
#
# 判斷依據是 scripts/sync-ui-sources.sh 在不在（四份 copy／update 腳本都排除它）。
# 新專案拿到的 .claude/ui/ 是快照、也沒有 taskmaster-data/，以前每個 session 都會被叫去「更新素材庫」。
ss_ctx() { run session-start.sh '{}' | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null; }
days_ago() { jq -nr --argjson d "$1" '(now - $d * 86400) | strftime("%Y-%m-%d")'; }
ss_sources() { # <voltagent 的 last_synced（null 或日期）> —— self-extracted 永遠是 null，不該被算進去
    local v="$1"; [ "$v" = "null" ] || v="\"$v\""
    mkdir -p "$SANDBOX/.claude/ui"
    printf '{"sources":[{"id":"voltagent","repo":"VoltAgent/awesome-design-md","last_synced":%s},{"id":"self-extracted","repo":null,"last_synced":null}]}\n' \
        "$v" > "$SANDBOX/.claude/ui/_sources.json"
}
ss_template() { mkdir -p "$SANDBOX/scripts"; : > "$SANDBOX/scripts/sync-ui-sources.sh"; }
ss_clean() { rm -rf "$SANDBOX/scripts"; }

reset; ss_clean; ss_template; ss_sources "$(days_ago 100)"
out=$(ss_ctx)
expect_contains "模板 repo、上游 100 天沒同步 → 提醒跑同步腳本" "sync-ui-sources.sh" "$out"
expect_contains "提醒寫出是哪個來源"                           "voltagent"          "$out"
expect_not_contains "沒有上游的 self-extracted 不算"           "self-extracted"     "$out"
reset; ss_clean; ss_template; ss_sources null
expect_contains "模板 repo、上游從未同步 → 提醒" "從未同步" "$(ss_ctx)"
reset; ss_clean; ss_template; ss_sources "$(days_ago 10)"
expect_not_contains "上游 10 天前同步過 → 不提醒" "sync-ui-sources.sh" "$(ss_ctx)"
reset; ss_clean; ss_sources "$(days_ago 100)"
expect_not_contains "沒有 sync-ui-sources.sh（不是模板 repo）→ 不提醒同步" "sync-ui-sources.sh" "$(ss_ctx)"

# 既有的「設計走向 90 天」提醒（使用者決定 3：一樣只在模板 repo）
reset; ss_clean; ss_template; ss_sources "$(days_ago 10)"
out=$(ss_ctx)
expect_contains     "模板 repo、從未更新設計走向 → 提醒"       "設計走向"   "$out"
expect_contains     "設計走向提醒指向 anti-ai.md（不是舊的 2.6 節）" "anti-ai.md" "$out"
reset; ss_clean; ss_sources "$(days_ago 10)"
expect_not_contains "不是模板 repo → 不提醒設計走向"           "設計走向"   "$(ss_ctx)"
reset; ss_clean; ss_template; ss_sources "$(days_ago 10)"; : > "$SANDBOX/.claude/taskmaster-data/.ui-catalog-refreshed"
expect_not_contains "模板 repo、設計走向剛更新 → 不提醒"       "設計走向"   "$(ss_ctx)"
reset; ss_clean

# 真的用 copy-template.sh 建一個新專案再開 session：上面的沙箱只證明「條件寫對了」，
# 這組證明「新專案真的不滿足那個條件」——排除清單哪天漏了，這裡會紅
NEWPROJ=$(mktemp -d)
bash "$HOOK_DIR/../../scripts/copy-template.sh" "$NEWPROJ/app" >/dev/null 2>&1 </dev/null
if [ -f "$NEWPROJ/app/.claude/ui/_sources.json" ] && [ -d "$NEWPROJ/app/.claude/hooks" ]; then
    ok "copy-template 建出的新專案帶著 .claude/ui/_sources.json（前提成立）"
else
    ng "copy-template 建出的新專案帶著 .claude/ui/_sources.json（前提成立）" "有 _sources.json 與 hooks" "$(ls -A "$NEWPROJ/app/.claude" 2>/dev/null | tr '\n' ' ')"
fi
[ ! -e "$NEWPROJ/app/scripts/sync-ui-sources.sh" ] && ok "新專案沒有 scripts/sync-ui-sources.sh" \
    || ng "新專案沒有 scripts/sync-ui-sources.sh" "不存在" "存在"
# 換成一定過期的來源資料：真實的 _sources.json 哪天全部剛同步過，下面的反向測試就會變成空跑
printf '{"sources":[{"id":"voltagent","repo":"VoltAgent/awesome-design-md","last_synced":null}]}\n' \
    > "$NEWPROJ/app/.claude/ui/_sources.json" 2>/dev/null
np_ctx=$(printf '{}' | env CLAUDE_PROJECT_DIR="$NEWPROJ/app" bash "$NEWPROJ/app/.claude/hooks/session-start.sh" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
expect_contains     "新專案的 session-start 正常注入"          "using-taskmaster"   "$np_ctx"
expect_not_contains "新專案不出現同步提醒"                     "sync-ui-sources.sh" "$np_ctx"
expect_not_contains "新專案不出現設計走向提醒"                 "設計走向"           "$np_ctx"
: > "$NEWPROJ/app/scripts/sync-ui-sources.sh"
np_ctx=$(printf '{}' | env CLAUDE_PROJECT_DIR="$NEWPROJ/app" bash "$NEWPROJ/app/.claude/hooks/session-start.sh" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
expect_contains "對照組：同一個新專案補上那支腳本 → 提醒出現（證明上面不是空跑）" "sync-ui-sources.sh" "$np_ctx"
rm -rf "$NEWPROJ"

# =========================================================================
section "worktree 感知 — 狀態隔離邊界"
# =========================================================================
# 官方：「Hook paths don't follow the worktree. ${CLAUDE_PROJECT_DIR} stays put;
# the cwd field in the hook's input JSON is the worktree root.」
# 所以短命旗標必須跟著 worktree，共享產物必須留在主 checkout。

# 在沙箱裡造一個真的 linked worktree
WT_SEQ=0
setup_worktree() {
    reset
    # reset 刪掉 .claude（含 worktree 目錄）但 git 仍記著它 → 先 prune，
    # 並用遞增名稱避免分支重複
    ( cd "$SANDBOX" && git init -q . 2>/dev/null       && echo x > seed && git add seed       && git -c user.email=t@t -c user.name=t commit -qm init       && git worktree prune ) >/dev/null 2>&1
    WT_SEQ=$((WT_SEQ + 1))
    WT="$SANDBOX/.claude/worktrees/wt$WT_SEQ"
    ( cd "$SANDBOX" && git worktree add -q "$WT" -b "wt$WT_SEQ" ) >/dev/null 2>&1
    mkdir -p "$WT/.claude/taskmaster-data" "$WT/src/deep" "$WT/src/api" 2>/dev/null
}
# payload 帶 cwd（模擬 worktree session）
wcwd() { jq -nc --arg f "$1" --arg c "$2" \
    '{tool_name:"Write", tool_input:{file_path:$f}, cwd:$c}'; }

setup_worktree
if [ -f "$WT/.git" ]; then ok "沙箱能建出 linked worktree（.git 是檔案）"
else ng "沙箱能建出 linked worktree（.git 是檔案）" ".git 為檔案" "不是"; fi

# 主 checkout 有模式檔、worktree 沒有 → 在 worktree 裡應該被擋
echo standard > "$MODE_FILE"
expect_decision "worktree 不吃主 checkout 的模式檔" deny \
    "$(run pre-tool-use.sh "$(wcwd "$WT/src/a.ts" "$WT")")"
expect_decision "同一時間主 checkout 仍放行" allow \
    "$(run pre-tool-use.sh "$(wcwd "$SANDBOX/src/a.ts" "$SANDBOX")")"

# worktree 自己的模式檔才算
echo quick > "$WT/.claude/taskmaster-data/.current-task-mode"
expect_decision "worktree 有自己的模式檔就放行" allow \
    "$(run pre-tool-use.sh "$(wcwd "$WT/src/a.ts" "$WT")")"

# cwd 是 worktree 子目錄（Claude 跑過 cd）也要認得
expect_decision "cwd 為子目錄仍解析到 worktree 根" allow \
    "$(run pre-tool-use.sh "$(wcwd "$WT/src/a.ts" "$WT/src/deep")")"

# 坑紀錄是共享的：只放在主 checkout 也要在 worktree 生效
setup_worktree
echo standard > "$WT/.claude/taskmaster-data/.current-task-mode"
mkdir -p "$SANDBOX/.claude/context/learned"
printf -- '---\ndate: 2026-09-07\ntitle: 共享的坑\nfiles:\n  - "src/*.ts"\nsymptom: s\nroot-cause: r\nguard: g\n---\n' \
    > "$SANDBOX/.claude/context/learned/shared.md"
out=$(run pre-tool-use.sh "$(wcwd "$WT/src/a.ts" "$WT")")
expect_decision "主 checkout 的坑在 worktree 也會擋"  deny "$out"
expect_contains "且貼出的是共享那筆"  "共享的坑" "$out"

# .doc-impact 跟著 worktree
setup_worktree
run post-write.sh "$(wcwd "$WT/src/api/x.ts" "$WT")" >/dev/null
if [ -f "$WT/.claude/taskmaster-data/.doc-impact" ]; then ok "doc-impact 寫進 worktree"
else ng "doc-impact 寫進 worktree" "worktree 有 .doc-impact" "沒有"; fi
if [ ! -f "$SANDBOX/.claude/taskmaster-data/.doc-impact" ]; then ok "doc-impact 沒污染主 checkout"
else ng "doc-impact 沒污染主 checkout" "主 checkout 無此檔" "有"; fi

# 非 worktree 情境（無 cwd 欄位）行為不變
reset
expect_decision "無 cwd 欄位時沿用舊行為（被擋）" deny \
    "$(run pre-tool-use.sh "$(w /p/src/api.ts)")"

# =========================================================================
section "post-bash.sh — 踩坑偵測（連續失敗後成功）"
# =========================================================================
#
# 為什麼要這個 hook：`using-taskmaster` 要求解完非平凡問題後寫一筆進 learned/，
# 但那是文字規則，沒有機制在該寫的當下提出來。「連續失敗 N 次然後成功」
# 是機器判斷得出的踩坑訊號——一次就過的不是坑。

# pb <失敗?> <指令> —— 模擬一次 Bash 工具呼叫的 PostToolUse
pb() {
    local failed="$1" cmd="$2" payload
    if [ "$failed" = "fail" ]; then
        payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"tool_response":{"is_error":true}}' "$cmd")
    else
        payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"tool_response":{"is_error":false}}' "$cmd")
    fi
    run post-bash.sh "$payload"
}
CAND_F="$SANDBOX/.claude/taskmaster-data/.learned-candidates"

# 一次就過 → 不是坑
reset
expect_empty "一次就成功不算坑" "$(pb ok "npm test")"

# 失敗次數未達門檻 → 不算坑
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_empty "失敗 2 次後成功未達門檻" "$(pb ok "x")"

# 達門檻 → 提醒 + 記候選
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_contains "失敗 3 次後成功會提醒" "這是一個坑" "$(pb ok "x")"
if grep -q '3 次失敗後成功' "$CAND_F" 2>/dev/null; then ok "候選已記入 .learned-candidates"
else ng "候選已記入 .learned-candidates" "有紀錄" "$(cat "$CAND_F" 2>/dev/null)"; fi

# 成功後計數歸零 —— 不會把上一輪的失敗算進下一輪
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
pb ok "x" >/dev/null
pb fail "y" >/dev/null
expect_empty "成功後失敗計數歸零" "$(pb ok "y")"

# 本任務只提醒一次
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
pb ok "x" >/dev/null
pb fail "y" >/dev/null; pb fail "y" >/dev/null; pb fail "y" >/dev/null
expect_empty "踩坑提醒只發一次" "$(pb ok "y")"

# 逃生門
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_empty "LEARN_CAPTURE=off 關閉偵測" \
    "$(run post-bash.sh '{"tool_name":"Bash","tool_input":{"command":"x"},"tool_response":{"is_error":false}}' LEARN_CAPTURE=off)"

reset; echo off > "$SM_FILE"
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_empty "suggest-mode=off 也關閉偵測" "$(pb ok "x")"

# exit_code 形式的失敗也要認得（不同版本欄位名不一致）
reset
for _ in 1 2 3; do
    run post-bash.sh '{"tool_name":"Bash","tool_input":{"command":"x"},"tool_response":{"exit_code":1}}' >/dev/null
done
expect_contains "exit_code 非零也算失敗" "這是一個坑" "$(pb ok "x")"

# 無指令的 payload 不爆炸
reset
expect_empty "空 command 不處理" "$(run post-bash.sh '{"tool_name":"Bash","tool_input":{}}')"

# 「同一件事」以指令前 40 字為準（2026-10-20）：三個不相干的指令各錯一次，
# 接著任何一個成功都不是坑——以前會被記成「3 次失敗後成功」
reset
pb fail "npm test" >/dev/null; pb fail "cat no-such" >/dev/null; pb fail "ls nope" >/dev/null
expect_empty "不同指令各失敗一次後成功不算坑" "$(pb ok "ls nope")"
reset
pb fail "x" >/dev/null; pb fail "x" >/dev/null; pb fail "x" >/dev/null
expect_empty "同一件事失敗 3 次後、成功的是別的指令 → 不算坑" "$(pb ok "y")"
# 重試常只改尾巴：前 40 字相同就是同一件事
LONGP="uv run pytest tests/integration/test_billing_flow.py"
reset
pb fail "$LONGP -x" >/dev/null; pb fail "$LONGP -k a" >/dev/null; pb fail "$LONGP -k b" >/dev/null
expect_contains "前 40 字相同、尾巴不同 → 仍算同一件事" "這是一個坑" "$(pb ok "$LONGP -vv")"
reset; mkdir -p "$SANDBOX/.claude/taskmaster-data"; echo 5 > "$SANDBOX/.claude/taskmaster-data/.bash-fail-streak"
expect_empty "舊格式（只有數字）的計數檔視同不同指令，不誤報" "$(pb ok "x")"

# =========================================================================
section "合併閘門 — 合併未驗證前不得再合併"
# =========================================================================
#
# 使用者的實際痛點：平行開發最後那段序列合併。痛在兩處——
# ①各 worktree 自己 verify 過不代表合併結果對（它們看不到彼此）
# ②一次疊好幾個之後測試紅了，得回頭二分找元凶。
# 原本「一次一個 merge、每次都驗」只寫在 worktree-orchestration skill 裡（自律）。

MP_FILE="$SANDBOX/.claude/taskmaster-data/.merge-pending"
# bash <command> —— 模擬 Bash 工具的 PreToolUse
bg() { run pre-tool-use.sh "$(printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$SANDBOX" "$1")"; }
# pbash <command> [ENV=VAL] —— 模擬 Bash 工具的 PostToolUse（成功）
pbash() { local c="$1"; shift; run post-bash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"tool_response":{"is_error":false}}' "$c")" MERGE_REFLOG_CHECK=off "$@"; }

# 偵測：合併成功要記進 .merge-pending 並提醒
reset
expect_contains "合併成功會提醒未驗證" "還沒驗證" "$(pbash 'git merge --no-ff worktree-search')"
# 清單記的是「[操作類型] 目標 ref」而不是整條指令 —— /verify 靠它分辨
# 哪些分支合進來了、該比對哪幾份 plan 的驗收標準。
if grep -qx '\[merge\] worktree-search' "$MP_FILE" 2>/dev/null; then ok "合併記入 .merge-pending（帶類型與 ref）"
else ng "合併記入 .merge-pending（帶類型與 ref）" "[merge] worktree-search" "$(cat "$MP_FILE" 2>/dev/null)"; fi

# 衝突的合併：見下一節「失敗事件」——衝突的 merge 退出碼非零，
# Claude Code 送的是 PostToolUseFailure，不是帶 is_error 的 PostToolUse。

# --abort 要清掉待驗證紀錄（放棄了就沒有東西待驗證）
reset; mkdir -p "$(dirname "$MP_FILE")"; echo 'git merge x' > "$MP_FILE"
run post-bash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"git merge --abort"},"tool_response":{"is_error":false}}')" >/dev/null
if [ ! -s "$MP_FILE" ]; then ok "git merge --abort 清掉待驗證紀錄"
else ng "git merge --abort 清掉待驗證紀錄" "空" "$(cat "$MP_FILE" 2>/dev/null)"; fi

# --continue 不動清單（那是解完衝突要完成合併，仍需驗證）
reset; mkdir -p "$(dirname "$MP_FILE")"; echo 'git merge x' > "$MP_FILE"
run post-bash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"git merge --continue"},"tool_response":{"is_error":false}}')" >/dev/null
if grep -q 'git merge x' "$MP_FILE" 2>/dev/null; then ok "git merge --continue 保留待驗證紀錄"
else ng "git merge --continue 保留待驗證紀錄" "仍有紀錄" "$(cat "$MP_FILE" 2>/dev/null)"; fi

# ---- 誤判回歸：偵測必須是「真的執行了合併」，不是「字串裡有那幾個字」 ----
#
# post-bash.sh 原本用 `case "$CMD" in *"git merge"*)` 子字串比對，於是
# `git merge-base --is-ancestor`（純唯讀祖先查詢）與任何提到指令名的
# heredoc／echo／grep 都被記成一次合併，merge-gate.sh 再拿那些幽靈紀錄擋下
# **下一次真正的合併**。2026-09-11 累計誤擋五次，其中一次擋下了
# 「修好它自己」的那次編輯（context/learned/2026-09-11-gate-blocks-its-own-fix.md）。
# 現在改用 lib/cmd-segments.sh 切段（與 git-backup-gate.sh 同一份實作）。

# pbashj <command> —— 同 pbash，但用 jq 組 payload（指令含引號／換行時要用這個）
pbashj() { run post-bash.sh "$(jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c},tool_response:{is_error:false}}')" MERGE_REFLOG_CHECK=off; }
mp_empty() {
    if [ ! -s "$MP_FILE" ]; then ok "$1"
    else ng "$1" "（不記錄）" "$(cat "$MP_FILE" 2>/dev/null)"; fi
}
mp_has() {
    if grep -qxF "$2" "$MP_FILE" 2>/dev/null; then ok "$1"
    else ng "$1" "$2" "$(cat "$MP_FILE" 2>/dev/null)"; fi
}

# merge-base 不是 merge —— 這是 2026-09-11 實際復現的那一條
reset
expect_empty "merge-base（唯讀查詢）不觸發合併提醒" \
    "$(pbashj 'git merge-base --is-ancestor 6d8d48c main')"
mp_empty "merge-base（唯讀查詢）不記入 .merge-pending"

reset; pbashj 'git log --oneline -1 6d8d48c && git merge-base --is-ancestor 6d8d48c main' >/dev/null
mp_empty "鏈式唯讀查詢（含 merge-base）不記入 .merge-pending"

reset; pbashj 'cat > d.md <<EOF
合併用 git merge --no-ff，衝突時 git rebase --abort 退回
EOF' >/dev/null
mp_empty "heredoc 內文提到指令不記入 .merge-pending"

reset; pbashj 'grep -rn "git cherry-pick" .claude/' >/dev/null
mp_empty "grep 樣式提到指令不記入 .merge-pending"

# 2026-10-16：commit 訊息用 heredoc 帶（Claude Code 預設的 commit 寫法），內文一句
# 「衝突的 merge 結束碼非 0」→ 清單被記成 `[merge] 結束碼非`。
# 上面那條 heredoc 案例沒抓到，是因為它的內文**沒有一行以 `git ` 開頭**、也沒有真的 merge。
reset; pbashj "git commit -q -m \"\$(cat <<'EOF'
fix: x

- 衝突的 merge 結束碼非 0，過去從未被記錄
EOF
)\"" >/dev/null
mp_empty "heredoc commit 訊息提到 merge 不記入 .merge-pending"

reset; pbashj "git commit -q -F - <<'EOF'
fix: x
git merge 是這樣用的
EOF" >/dev/null
mp_empty "heredoc 內文某行以 git merge 開頭也不記"

# 10-16 的實際形狀：同一條指令先 heredoc commit、再真的 merge。合併該記，
# 但 ref 曾從 heredoc 內文抽出來。
reset; pbashj "git add -A && git commit -q -F - <<'EOF'
fix: x

- 衝突的 merge 結束碼非 0，過去從未被記錄
EOF
git switch -q main && git merge --no-ff -m \"merge: y\" feat/real" >/dev/null
mp_has "heredoc commit 之後真的 merge → ref 取自真正的 merge" '[merge] feat/real'

reset; pbashj 'git commit -m "說明 git merge foo 的用法"' >/dev/null
mp_empty "引號內的 commit 訊息提到 git merge 不記"

reset; pbashj "echo 'x
git merge feature/y'" >/dev/null
mp_empty "跨行單引號字串裡以 git merge 開頭的行不記"

# 子指令只看 git 後第一個非選項字，不看整段任何位置
reset; pbashj 'git log --oneline --grep merge' >/dev/null
mp_empty "git log --grep merge 不是合併"

reset; pbashj 'git -C /some/path merge feature/x' >/dev/null
mp_has "git -C <路徑> merge 仍記錄（跳過全域選項）" '[merge] feature/x'

reset; pbashj 'git -c core.editor=true --no-pager rebase main' >/dev/null
mp_has "git -c k=v --no-pager rebase 仍記錄" '[rebase] main'

# 正向：真的執行的仍然要記，且類型與 ref 不能跑掉
reset; pbashj 'git merge feature/x' >/dev/null
mp_has "真正的 merge 仍記錄（ref 正確抽出）" '[merge] feature/x'

reset; pbashj 'cd /some/path && git cherry-pick abc123' >/dev/null
mp_has "鏈式 cd && cherry-pick 仍記錄（類型正確）" '[cherry-pick] abc123'

# 合併訊息改用 -F <檔> 或 -m "$(cat ...)" 傳入時，ref 曾被記成 shell 片段
# （實例：`[merge] $M/merge-msg.txt")"`）。抽 ref 要懂引號與 $( )，並跳過帶值的選項。
reset; pbashj 'git merge --no-ff -F "$M/merge-msg.txt" feature/a' >/dev/null
mp_has "merge -F <檔> 抽出正確的 ref" '[merge] feature/a'
reset; pbashj 'git merge --no-ff -m "$(cat "$M/merge-msg.txt")" feature/b' >/dev/null
mp_has "merge -m \"\$(cat ...)\" 抽出正確的 ref" '[merge] feature/b'
reset; pbashj 'git merge --no-ff -m "merge: 加入匯出功能; 修正分頁" feature/c' >/dev/null
mp_has "merge --no-ff -m \"含空白與分號的訊息\" 抽出正確的 ref" '[merge] feature/c'

reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] x' > "$MP_FILE"
pbashj 'git rebase --abort' >/dev/null
mp_empty "git rebase --abort 仍清掉待驗證紀錄"

# 閘門：清單非空時擋下下一次合併
reset; mkdir -p "$(dirname "$MP_FILE")"; echo 'git merge --no-ff worktree-search' > "$MP_FILE"
expect_decision "待驗證時擋下下一次 merge"       deny  "$(bg 'git merge --no-ff worktree-cart')"
expect_decision "待驗證時擋下 cherry-pick"       deny  "$(bg 'git cherry-pick abc1234')"
expect_decision "待驗證時擋下 rebase"            deny  "$(bg 'git rebase main')"
expect_decision "merge --abort 放行（收拾現場）" allow "$(bg 'git merge --abort')"
expect_decision "rebase --continue 放行"         allow "$(bg 'git rebase --continue')"
expect_decision "無關指令放行"                   allow "$(bg 'git status')"
# 指令帶 --no-ff：關掉 MERGE_GATE 之後**下一道** lib 閘門（merge-noff-gate）
# 仍然在線，裸的 `git merge x` 會被它擋下，那不是本案例要測的事。
expect_decision "MERGE_GATE=off 關閉閘門"        allow \
    "$(run pre-tool-use.sh "$(printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"git merge --no-ff x"}}' "$SANDBOX")" MERGE_GATE=off)"

# 清單為空 → 放行（/verify 通過後的狀態）
reset; mkdir -p "$(dirname "$MP_FILE")"; : > "$MP_FILE"
expect_decision "清單為空時放行 merge" allow "$(bg 'git merge --no-ff worktree-cart')"

# =========================================================================
section "post-bash.sh — 失敗事件（PostToolUseFailure）"
# =========================================================================
#
# PostToolUse 只在工具**成功**時觸發；指令非零結束走 PostToolUseFailure。
# 本檔曾經只接 PostToolUse，於是：衝突的 merge 從沒被記過（下一次合併跳過驗證）、
# 踩坑偵測的失敗計數從沒累加過。舊測試抓不到，因為它們直接餵
# `tool_response.is_error` 給腳本——那是 Claude Code 從來不會送出的形狀。
# 這一節的 payload 一律照官方文件的 PostToolUseFailure 形狀：沒有 tool_response，
# 錯誤在頂層 `error`（首行 `Exit code N`）。
# 見 context/learned/2026-10-15-posttooluse-skips-failures.md。

# pbf <command> <error> [cwd] —— 模擬 Bash 的 PostToolUseFailure
pbf() {
    run post-bash.sh "$(jq -nc --arg c "$1" --arg e "$2" --arg d "${3:-}" '
        {hook_event_name:"PostToolUseFailure",tool_name:"Bash",tool_input:{command:$c},
         error:$e,is_interrupt:false} + (if $d == "" then {} else {cwd:$d} end)')" MERGE_REFLOG_CHECK=off
}
STREAK_F="$SANDBOX/.claude/taskmaster-data/.bash-fail-streak"

# 真正的 bug 在接線，不在腳本：下面的 payload 測試全綠也證明不了 Claude Code
# 會在失敗時呼叫本檔。這兩條釘住 settings.json。
SETTINGS="$HOOK_DIR/../settings.json"
for ev in PostToolUse PostToolUseFailure; do
    if jq -e --arg ev "$ev" '[.hooks[$ev][]? | select((.matcher // "") | split("|") | index("Bash")) | .hooks[] | select(.command | contains("post-bash.sh"))] | length > 0' "$SETTINGS" >/dev/null 2>&1; then
        ok "settings.json 把 post-bash.sh 接在 $ev(Bash)"
    else ng "settings.json 把 post-bash.sh 接在 $ev(Bash)" "有接線" "沒有"; fi
done

# ---- 合併 ----

reset
out=$(pbf 'git merge --no-ff feat/x' 'Exit code 1
Auto-merging a.txt
CONFLICT (content): Merge conflict in a.txt
Automatic merge failed; fix conflicts and then commit the result.')
expect_contains "衝突的 merge（失敗事件）導向 conflict-resolver" "conflict-resolver" "$out"
mp_has "衝突的 merge（失敗事件）記入 .merge-pending" '[merge] feat/x'
if grep -q 'feat/x (conflicted=1, event=PostToolUseFailure)' "$SANDBOX/.claude/logs/hooks.log" 2>/dev/null; then
    ok "衝突的 merge 在 log 標 conflicted=1"
else ng "衝突的 merge 在 log 標 conflicted=1" "conflicted=1" "$(tail -1 "$SANDBOX/.claude/logs/hooks.log" 2>/dev/null)"; fi
# 回應的 hookEventName 必須等於觸發的事件，否則注入會被丟掉
expect_contains "失敗事件的回應帶 hookEventName=PostToolUseFailure" '"PostToolUseFailure"' "$out"

# 2026-10-15 實際漏記的那一條：合併成功，是鏈在後面的指令失敗
reset
out=$(pbf 'git switch -q main && git merge --no-ff -m "merge: x" feat/x >/dev/null && cat no-such-file' 'Exit code 1
cat: no-such-file: No such file or directory')
mp_has "合併成功但後段指令失敗仍記入 .merge-pending" '[merge] feat/x'

# 10-16 那筆就是失敗事件送來的（event=PostToolUseFailure）
reset; pbf "git commit -q -F - <<'EOF'
fix: x
- 衝突的 merge 結束碼非 0
EOF
git switch -q main && git merge --no-ff -m \"merge: y\" feat/real && cat no-such-file" 'Exit code 1' >/dev/null
mp_has "失敗事件：heredoc commit + 真 merge → ref 取自真正的 merge" '[merge] feat/real'
expect_contains "非零但無衝突 → 提示「非零結束」而非衝突" "非零結束" "$out"
case "$out" in *conflict-resolver*) ng "非零但無衝突不導向 conflict-resolver" "不含 conflict-resolver" "$out" ;;
                *) ok "非零但無衝突不導向 conflict-resolver" ;; esac

reset; pbf 'git cherry-pick abc123' 'Exit code 1
error: could not apply abc123... fix
hint: after resolving the conflicts, mark the corrected paths' >/dev/null
mp_has "衝突的 cherry-pick（失敗事件）記入 .merge-pending" '[cherry-pick] abc123'

# 失敗事件也要走切段比對，不能退回子字串
reset; pbf 'grep -rn "git merge" .claude/ | head -1 && false' 'Exit code 1' >/dev/null
mp_empty "失敗的 grep 提到指令名不記入 .merge-pending"
reset; pbf 'git merge-base --is-ancestor abc main' 'Exit code 1' >/dev/null
mp_empty "失敗的 merge-base（唯讀查詢）不記入 .merge-pending"

# --abort 失敗不清：最常見的原因是「沒有進行中的合併」，清單裡那筆是真的待驗證
reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] done-before' > "$MP_FILE"
pbf 'git merge --abort' 'Exit code 128
fatal: There is no merge to abort (MERGE_HEAD missing).' >/dev/null
mp_has "--abort 失敗時保留待驗證紀錄" '[merge] done-before'

# 真的 repo 狀態：輸出被 >/dev/null 吃掉、error 裡沒有衝突字樣時，
# 仍要靠 `ls-files -u` 認出衝突。成功事件（`; true` 讓整條變 0）也一樣。
GR="$SANDBOX/gitrepo"
rm -rf "$GR"; mkdir -p "$GR"
(
    cd "$GR" || exit 1
    g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=base "$@" >/dev/null 2>&1; }
    g init -q; echo a > f.txt; g add f.txt; g commit -qm base
    g checkout -q -b side; echo side > f.txt; g commit -qam side
    g checkout -q -; echo main > f.txt; g commit -qam main
    g merge side
)
if [ -n "$(git -C "$GR" ls-files -u 2>/dev/null | head -1)" ]; then
    reset
    expect_contains "輸出被吃掉時靠 repo 狀態認出衝突" "conflict-resolver" \
        "$(pbf 'git merge side >/dev/null 2>&1' 'Exit code 1' "$GR")"
    reset
    expect_contains "成功事件（; true）但 repo 有衝突 → 仍導向 conflict-resolver" "conflict-resolver" \
        "$(run post-bash.sh "$(jq -nc --arg d "$GR" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$d,tool_input:{command:"git merge side; true"},tool_response:{stdout:"",stderr:"",interrupted:false,isImage:false}}')")"
else
    ng "建立衝突中的測試 repo" "有未合併路徑" "git 無法建出衝突狀態"
fi
rm -rf "$GR"

# ---- 一般失敗指令 ----

reset
expect_empty "失敗的非 git 指令不輸出" "$(pbf 'npm test' 'Exit code 1
Error: Cannot find module')"
mp_empty "失敗的非 git 指令不記入 .merge-pending"
if [ "$(cut -f1 "$STREAK_F" 2>/dev/null)" = "1" ]; then ok "失敗事件讓 .bash-fail-streak 累加"
else ng "失敗事件讓 .bash-fail-streak 累加" "1" "$(cut -f1 "$STREAK_F" 2>/dev/null)"; fi

# 踩坑偵測端到端：真實形狀的失敗事件 ×3 → 成功 → 提醒
reset
for _ in 1 2 3; do pbf 'uv run pytest' 'Exit code 1
FAILED tests/test_x.py' >/dev/null; done
expect_contains "失敗事件 ×3 後成功會提醒踩坑" "這是一個坑" "$(pb ok "uv run pytest")"

# 被中斷的失敗也算一次（與舊有 interrupted 語意一致）
reset
run post-bash.sh '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"sleep 99"},"error":"aborted","is_interrupt":true}' >/dev/null
if [ "$(cut -f1 "$STREAK_F" 2>/dev/null)" = "1" ]; then ok "is_interrupt 的失敗事件也累加"
else ng "is_interrupt 的失敗事件也累加" "1" "$(cut -f1 "$STREAK_F" 2>/dev/null)"; fi

# 逃生門在失敗事件下照樣有效
reset; run post-bash.sh '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"npm test"},"error":"Exit code 1"}' LEARN_CAPTURE=off >/dev/null
if [ ! -s "$STREAK_F" ]; then ok "LEARN_CAPTURE=off 時失敗事件不計數"
else ng "LEARN_CAPTURE=off 時失敗事件不計數" "空" "$(cat "$STREAK_F" 2>/dev/null)"; fi

# =========================================================================
section "cmd-segments.sh — 切段邊界（註解、算術位移、全域選項、heredoc 結束字）"
# =========================================================================
#
# 四個都是「切段讓真的指令消失或多出假指令」，而且都不報錯：
# 消失 → git-backup-gate 放行、post-bash 不記；多出 → 清單多一筆假合併，擋下一次真的合併。
# 這裡直接驗 cmd_segments 的輸出（四支閘門共用它），閘門層的回歸放在各自的節。

cs() { ( source "$HOOK_DIR/lib/cmd-segments.sh"; cmd_segments "$1" ); }
csub() { ( source "$HOOK_DIR/lib/cmd-segments.sh"; cmd_git_subcmd "$1" ); }

# ① 註解裡的單引號被當成引號開頭 → 後面整段被遮掉
expect_eq "整行註解含單引號，下一行的 reset --hard 還在" 'git reset --hard HEAD~1' \
    "$(cs $'# reset because it\'s broken\ngit reset --hard HEAD~1')"
expect_eq "行尾註解含單引號，下一行的 rebase 還在" $'git status\ngit rebase main' \
    "$(cs $'git status # it\'s fine\ngit rebase main')"
expect_eq "引號內的 # 不是註解" $'git commit -m ""\ngit merge feat/a' \
    "$(cs $'git commit -m "fix #1 don\'t" && git merge feat/a')"
expect_eq "\$# 不是註解" 'git rebase main' "$(cs '[ $# -gt 0 ] && git rebase main')"
expect_eq "\${#var} 不是註解" 'git rebase main' "$(cs 'echo ${#arr[@]} && git rebase main')"
expect_eq "URL 錨點（字中間的 #）不是註解" 'git rebase main' "$(cs 'curl http://x/#top && git rebase main')"
expect_eq "註解裡提到的指令不算一段" '' "$(cs '# git merge feat/x')"

# ② 算術裡的位元左移被當成 heredoc 開頭 → 之後全部被當成 heredoc 內文吃掉
expect_eq "\$((1<<x)) 不是 heredoc" 'git rebase main' "$(cs $'echo $((1<<x))\ngit rebase main')"
expect_eq "((y = 1<<x)) 不是 heredoc" 'git rebase main' "$(cs $'(( y = 1<<x ))\ngit rebase main')"
expect_eq "<<< here-string 不是 heredoc" 'git rebase main' "$(cs $'cat <<<x\ngit rebase main')"
expect_eq "同一行先算術、後真的 heredoc：heredoc 照樣剝掉" 'git rebase main' \
    "$(cs $'echo $((1<<2)) && cat <<EOF\ngit merge fake\nEOF\ngit rebase main')"

# ⑤ 值放在下一個字的全域選項
expect_eq "--git-dir <路徑> merge" 'git merge feat' "$(cs 'git --git-dir /x/.git merge feat')"
expect_eq "--git-dir=<路徑> merge" 'git merge feat' "$(cs 'git --git-dir=/x/.git merge feat')"
expect_eq "--work-tree <路徑> --git-dir=<路徑> merge" 'git merge feat' \
    "$(cs 'git --work-tree /w --git-dir=/x/.git merge feat')"
expect_eq "--namespace <名稱> rebase" 'git rebase main' "$(cs 'git --namespace ns rebase main')"
expect_eq "--config-env <k=v> --attr-source <tree> rebase" 'git rebase main' \
    "$(cs 'git --config-env core.x=HOME --attr-source HEAD rebase main')"
expect_eq "--exec-path=<路徑> merge" 'git merge feat' "$(cs 'git --exec-path=/p merge feat')"
# 不帶 = 的 --exec-path 是「印出路徑就結束」（git 2.53 實測），後面的字都不會執行
expect_eq "裸 --exec-path 之後沒有子指令" '' "$(csub 'git --exec-path merge feat')"
expect_eq "cmd_git_subcmd 也跳過 --git-dir <路徑>" 'merge' "$(csub 'git --git-dir /x/.git merge feat')"

# ⑥ 一般 <<WORD 的結束行必須一字不差；只有 <<-WORD 允許行首 tab（不是空白）
expect_eq "<<EOF 內文縮排的 EOF 不會提早結束" 'git status' \
    "$(cs $'cat <<EOF\n  EOF\ngit merge fake\nEOF\ngit status')"
expect_eq "<<-EOF 的 tab 縮排結束行照樣結束" 'git rebase main' \
    "$(cs $'cat <<-EOF\n\tbody\n\tEOF\ngit rebase main')"
expect_eq "<<-EOF 用空白縮排的 EOF 不算結束" 'git status' \
    "$(cs $'cat <<-EOF\n  EOF\ngit merge fake\nEOF\ngit status')"

# 閘門層：post-bash.sh 的合併紀錄（pbashj／mp_has／mp_empty 定義在「合併閘門」節）
reset; pbashj $'# merge because it\'s ready\ngit merge feat/x' >/dev/null
mp_has "註解含單引號之後的 merge 仍記錄" '[merge] feat/x'
reset; pbashj 'git --git-dir /x/.git merge feat' >/dev/null
mp_has "git --git-dir <路徑> merge 記成正確的 ref" '[merge] feat'
reset; pbashj $'cat > n.md <<EOF\n  EOF\ngit merge fake\nEOF' >/dev/null
mp_empty "heredoc 內文縮排的 EOF 之後的內文不記成合併"

# =========================================================================
section "git backup 閘門 — destructive 操作前必須有安全快照"
# =========================================================================
#
# 這四種指令（reset --hard／push --force／branch -D／rebase）會讓一段 commit
# 失去所有 ref，撿回來只剩 reflog——而 reflog 是「通常還在」不是「保證還在」。
# 原本這條只寫在 rules/git-workflow.md 裡（自律），現在由 lib/git-backup-gate.sh 強制。
#
# 這組測試需要**真的 git repo**：閘門的判準是「HEAD 有沒有 backup/* tag 指著」，
# 只有真的打 tag、真的往前 commit 才驗得到「tag 指向舊 commit 時仍要擋」。
# 直接把沙箱本身 git init（CLAUDE_PROJECT_DIR 已指向它 → WORK_ROOT 就是它）。
# 本區塊之後的案例不碰 git，所以多一個 .git 目錄不影響它們。

git -c init.defaultBranch=main init -q "$SANDBOX" >/dev/null 2>&1

gitq() { git -C "$SANDBOX" -c user.email=t@example.com -c user.name=t "$@" >/dev/null 2>&1; }
# 清掉殘留的 backup tag —— reset() 只清 .claude/，tag 會跨案例活著
gbg_untag() {
    local t
    while IFS= read -r t; do
        [ -n "$t" ] || continue
        git -C "$SANDBOX" tag -d "$t" >/dev/null 2>&1
    done <<< "$(git -C "$SANDBOX" tag -l 'backup/*' 2>/dev/null)"
}
gbp() { jq -nc --arg cwd "$SANDBOX" --arg c "$1" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}'; }
gb()  { local c="$1"; shift; run pre-tool-use.sh "$(gbp "$c")" "$@"; }
# gbo <command> <root> —— 換一個 root（run() 已帶 CLAUDE_PROJECT_DIR，後面的覆寫前面的）
gbo() {
    run pre-tool-use.sh \
        "$(jq -nc --arg cwd "$2" --arg c "$1" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')" \
        CLAUDE_PROJECT_DIR="$2"
}

reset; gitq commit --allow-empty -m c1; gbg_untag

# 沒有快照 → 四種 destructive 指令都要擋
expect_decision "reset --hard 沒快照時被擋"      deny "$(gb 'git reset --hard HEAD~1')"
expect_decision "push --force 沒快照時被擋"      deny "$(gb 'git push --force origin main')"
expect_decision "push -f 沒快照時被擋"           deny "$(gb 'git push -f origin main')"
# --force-with-lease 防的是覆蓋**別人**的 push，不是防自己弄丟本地工作 → 不特例放行
expect_decision "push --force-with-lease 不特例放行" deny "$(gb 'git push --force-with-lease origin main')"
gitq branch feat/x
expect_decision "branch -D 沒快照時被擋"         deny "$(gb 'git branch -D feat/x')"
expect_decision "rebase 沒快照時被擋"            deny "$(gb 'git rebase main')"
# 真實用法常是鏈式的，指令段不是整條指令的開頭
expect_decision "鏈式 cd x && git reset --hard 也擋" deny "$(gb 'cd /tmp && git reset --hard HEAD~1')"

# deny 訊息要能直接複製，不能只說「請先打 tag」
expect_contains "deny 訊息給出可複製的 tag 指令" "git tag backup/" \
    "$(gb 'git reset --hard HEAD~1' | jq -r '.hookSpecificOutput.permissionDecisionReason')"

# 有快照 → 放行；但快照必須指向**當前** HEAD
reset; gbg_untag; gitq tag "backup/main-test"
expect_decision "backup tag 指向 HEAD 時放行"    allow "$(gb 'git reset --hard HEAD~1')"

gitq commit --allow-empty -m c2      # HEAD 前進，tag 留在舊 commit
expect_decision "tag 指向舊 commit 時仍擋"       deny  "$(gb 'git reset --hard HEAD~1')"
gbg_untag

# --continue / --abort / --skip 是收拾當前狀態，不是新的 destructive 操作
expect_decision "rebase --continue 放行"         allow "$(gb 'git rebase --continue')"
expect_decision "rebase --abort 放行"            allow "$(gb 'git rebase --abort')"
expect_decision "rebase --skip 放行"             allow "$(gb 'git rebase --skip')"

# 不該擋的
expect_decision "無害的 git 指令放行"            allow "$(gb 'git status')"
expect_decision "reset 沒帶 --hard 放行"         allow "$(gb 'git reset HEAD~1')"
expect_decision "branch -d（小寫）放行"          allow "$(gb 'git branch -d feat/x')"
expect_decision "不含 git 的指令放行"            allow "$(gb 'npm run reset -- --hard')"
# 誤擋回歸：子字串比對會讓「寫文件時提到這些指令」也被擋。本閘門幾乎每個 session
# 都處於「沒有 backup tag」的狀態，所以這個誤擋會天天發生——實際踩過一次。
expect_decision "只是提到指令（heredoc 內文）不擋" allow \
    "$(gb 'cat > d.md <<EOF
先打 tag 再 git reset --hard
EOF')"
# 上面那條的內文不以 git 開頭；這兩條是真的會撞的形狀（heredoc 內某行以 git 開頭、
# 引號內的訊息）——2026-10-16 在 post-bash.sh 那邊實際撞到同一個切段缺陷
expect_decision "heredoc commit 內文某行以 git reset --hard 開頭不擋" allow \
    "$(gb "git commit -q -F - <<'EOF'
docs: 說明
git reset --hard 之前先打 tag
EOF")"
expect_decision "commit -m 訊息含 git reset --hard 不擋" allow \
    "$(gb 'git commit -m "改用 tag，取代直接 git reset --hard"')"
expect_decision "git -C <路徑> reset --hard 仍擋（跳過全域選項）" deny \
    "$(gb "git -C $SANDBOX reset --hard HEAD~1")"
# 切段把真的指令弄丟的兩種形狀（cmd-segments 節有單元測試）
expect_decision "註解含單引號之後的 reset --hard 仍擋" deny \
    "$(gb $'# reset because it\'s broken\ngit reset --hard HEAD~1')"
expect_decision "\$((1<<x)) 之後的 rebase 仍擋" deny \
    "$(gb $'echo $((1<<x))\ngit rebase main')"

# ---- 被保護的對象不一定是 HEAD（2026-10-20）----
# branch -D 會弄丟的是**那條分支的 tip**：站在 main 上刪 feat/x，HEAD 的 tag 保不到它
reset; gbg_untag; gitq branch -f feat/x; gitq commit --allow-empty -m moved; gitq tag backup/head-only
expect_decision "branch -D：HEAD 有 tag 但被刪的分支沒有 → 仍擋" deny "$(gb 'git branch -D feat/x')"
expect_contains "branch -D：建議指令對著那條分支打 tag" "feat/x" \
    "$(gb 'git branch -D feat/x' | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -o 'git tag backup/feat/x-[0-9-]* feat/x')"
gbg_untag; gitq checkout -q -b feat/tip; gitq commit --allow-empty -m tip; gitq tag backup/feat-tip; gitq checkout -q main
expect_decision "branch -D：被刪的分支 tip 有 tag → 放行（HEAD 沒有也一樣）" allow "$(gb 'git branch -D feat/tip')"
expect_decision "branch -D：分支不存在 → 放行（讓 git 自己報錯）" allow "$(gb 'git branch -D no-such-branch')"
gbg_untag; gitq branch -D feat/tip
# reset --hard 沒帶目標：HEAD 不動，tag 救不到的是未 commit 的改動
reset; gbg_untag
expect_decision "reset --hard（無目標）工作區乾淨 → 放行" allow "$(gb 'git reset --hard')"
expect_decision "reset --hard HEAD 工作區乾淨 → 放行"    allow "$(gb 'git reset --hard HEAD')"
echo v1 > "$SANDBOX/tracked.txt"; gitq add tracked.txt; gitq commit -m tracked; echo v2 > "$SANDBOX/tracked.txt"
expect_decision "reset --hard（無目標）有未 commit 改動 → 擋" deny "$(gb 'git reset --hard')"
expect_contains "有改動時講實話：tag 救不到" "backup tag 救不到這些" \
    "$(gb 'git reset --hard' | jq -r '.hookSpecificOutput.permissionDecisionReason')"
gitq tag backup/main-has-tag
expect_decision "有改動時打 tag 也沒用（仍擋）" deny "$(gb 'git reset --hard HEAD')"
gbg_untag; gitq checkout -- tracked.txt

# 逃生門
expect_decision "GIT_BACKUP_GATE=off 關閉閘門"   allow "$(gb 'git reset --hard HEAD~1' GIT_BACKUP_GATE=off)"
reset; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門"    allow "$(gb 'git reset --hard HEAD~1')"

# 判斷不了就放行（缺依賴／狀態不明時寧可放行也不誤擋）
reset
GBG_EMPTY="$SANDBOX/emptyrepo"; mkdir -p "$GBG_EMPTY"
git -c init.defaultBranch=main init -q "$GBG_EMPTY" >/dev/null 2>&1
expect_decision "空 repo（unborn HEAD）放行"     allow "$(gbo 'git reset --hard HEAD~1' "$GBG_EMPTY")"

GBG_NOREPO=$(mktemp -d)
expect_decision "不在 git repo 裡放行"           allow "$(gbo 'git reset --hard HEAD~1' "$GBG_NOREPO")"
rm -rf "$GBG_NOREPO"

# =========================================================================
section "merge --no-ff 閘門 — 合併本地 topic 分支必須留下 merge commit"
# =========================================================================
#
# 為什麼要這組：2026-09-16 一個在獨立 worktree 做完的任務（WBS 11.26）合併回
# main 時漏了 `--no-ff`，主線零分歧 → fast-forward → **任務邊界在歷史上消失**，
# `git log --first-parent` 看不出那是一個任務、`git revert -m 1` 也無從整批回退。
# 這件事當時**已經寫在兩份文件裡**（commands/worktree.md、worktree-orchestration
# skill）還是漏了，所以改由 lib/merge-noff-gate.sh 強制。
#
# 這組沿用上一區塊 git init 過的 $SANDBOX（本閘門要查 `git remote` 才分得出
# `fork/main` 是遠端 ref 而 `feat/x` 是本地分支）。merge --no-ff 不屬於
# git-backup-gate 管的四種 destructive 指令，兩者不會互相干擾。

gitq remote add fork https://example.invalid/fork.git
gbg_untag
reset
# mn <command> [ENV=VAL] —— 用 jq 組 payload（指令含引號／換行時必須這樣）
mn() {
    local c="$1"; shift
    run pre-tool-use.sh \
        "$(jq -nc --arg cwd "$SANDBOX" --arg c "$c" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')" \
        "$@"
}

# 事故原型：worktree 分支合回 main，沒帶旗標
expect_decision "合併本地分支沒帶 --no-ff → 擋" deny "$(mn 'git merge worktree-agent-a4c461cf622a61062')"
expect_decision "帶 --no-ff → 放行"             allow "$(mn 'git merge --no-ff worktree-agent-a4c461cf622a61062')"

# 意圖已明確表達的另外兩種
expect_decision "--squash 放行（明確不要 merge 節點）" allow "$(mn 'git merge --squash feat/x')"
expect_decision "--ff-only 放行（明確就是要 ff）"     allow "$(mn 'git merge --ff-only feat/x')"

# 純同步合併不該被逼出一個空的 merge 節點
expect_decision "git merge origin/main 放行"    allow "$(mn 'git merge origin/main')"
expect_decision "git merge upstream/main 放行"  allow "$(mn 'git merge upstream/main')"
expect_decision "任意 <remote>/… 放行（fork/main）" allow "$(mn 'git merge fork/main')"
expect_decision "FETCH_HEAD 放行"               allow "$(mn 'git merge FETCH_HEAD')"
expect_decision "@{u} 放行"                     allow "$(mn 'git merge @{u}')"
# 有斜線不代表是遠端——`feat/x` 是本地 topic 分支，正是最該擋的那一類。
# 判準是「第一段是不是真的 remote 名稱」，不是「有沒有斜線」。
expect_decision "feat/x（有斜線的本地分支）仍擋" deny "$(mn 'git merge feat/x')"

# 誤判回歸：merge-base 是唯讀查詢，不是合併（cmd-segments.sh 存在的理由）
expect_decision "git merge-base 不被誤擋"       allow "$(mn 'git merge-base --is-ancestor 6d8d48c main')"
expect_decision "鏈式唯讀查詢（含 merge-base）放行" allow \
    "$(mn 'git log --oneline -1 6d8d48c && git merge-base --is-ancestor 6d8d48c main')"
expect_decision "heredoc 內文提到指令不擋"      allow "$(mn 'cat > d.md <<EOF
合併任務分支時用 git merge task-branch
EOF')"

# 收拾當前狀態，不是新合併
expect_decision "merge --abort 放行"            allow "$(mn 'git merge --abort')"
expect_decision "merge --continue 放行"         allow "$(mn 'git merge --continue')"

# `-m` 會吃掉下一個 token。引號內文若直接刪掉，`mybr` 會被 `-m` 誤吃，
# 然後「沒有 ref 參數」讓閘門靜默放行——所以引號字串換成佔位 token 而不是刪除。
expect_decision "-m \"…\" 之後的分支不會被吃掉" deny "$(mn 'git merge -m "merge: 11.26 搜尋結果分頁" mybr')"
expect_decision "--no-ff 搭配 -m 放行"          allow "$(mn 'git merge --no-ff -m "merge: 11.26 搜尋結果分頁" mybr')"
# 引號內文提到旗標不算數（它是訊息，不是旗標）
expect_decision "-m 內文提到 --no-ff 不算帶旗標" deny "$(mn 'git merge -m "這次改用 --no-ff" mybr')"

# 其他形狀
expect_decision "鏈式 cd x && git merge 也擋"   deny  "$(mn 'cd /tmp && git merge mybr')"
expect_decision "沒有 ref 參數時放行"           allow "$(mn 'git merge')"
expect_decision "git pull 不是 merge，放行"     allow "$(mn 'git pull origin main')"
expect_decision "不含 git 的指令放行"           allow "$(mn 'npm run merge -- mybr')"
expect_decision "-X ours 的值不會被當成 ref"    deny  "$(mn 'git merge --strategy-option ours mybr')"
# 反向：**值是選配的**選項不吃下一個 token（`--log[=<n>]` 必須寫成 `--log=5`）。
# 把它誤列進「吃下一個 token」那串的代價是靜默放行——分支名被當成 --log 的值。
expect_decision "--log 不會吃掉後面的分支名"    deny  "$(mn 'git merge --log mybr')"
expect_decision "--log=5 附著值一樣擋"          deny  "$(mn 'git merge --log=5 mybr')"

# deny 訊息要能直接複製，而且要誠實
MN_MSG=$(mn 'git merge mybr' | jq -r '.hookSpecificOutput.permissionDecisionReason')
expect_contains "deny 訊息給出補好旗標的完整指令" "git merge --no-ff mybr" "$MN_MSG"
expect_contains "deny 訊息講 --first-parent 的具體效益" "first-parent"      "$MN_MSG"
expect_contains "deny 訊息講 revert -m 1 可整批回退"    "revert -m 1"       "$MN_MSG"
expect_contains "deny 訊息誠實說明它不是平行的證據"    "不是平行做過的證據" "$MN_MSG"
expect_contains "deny 訊息給永久解（含 pull.rebase 配套）" "pull.rebase true" "$MN_MSG"

# **刻意沒有 deny-once**：這是「指令形狀」閘門，補上旗標重打同一條就過，
# 天然自清。記旗標反而會讓「第二次真的漏掉」時靜默放行。
mn 'git merge mybr' >/dev/null
expect_decision "沒有 deny-once：第二次仍擋"    deny  "$(mn 'git merge mybr')"

# 逃生門
expect_decision "MERGE_NOFF_GATE=off 關閉閘門"  allow "$(mn 'git merge mybr' MERGE_NOFF_GATE=off)"
reset; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門"   allow "$(mn 'git merge mybr')"
reset

# 上一道閘門優先：待驗證的合併是**狀態**問題，該先講；--no-ff 只是這條指令的
# 形狀，補上旗標重打就好。接線順序（merge_gate → merge_noff_gate）釘在這裡。
mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] worktree-search' > "$MP_FILE"
expect_contains "merge-gate 排在 --no-ff 閘門之前" "上一次合併還沒驗證過" \
    "$(mn 'git merge mybr' | jq -r '.hookSpecificOutput.permissionDecisionReason')"
reset

# =========================================================================
section "分支切換閘門 — 站在 topic 分支上不得直接開新分支"
# =========================================================================
#
# 事故（2026-09-17）：主 checkout 站在 `fix/stream-token-ledger` 上、一個 subagent
# 正在那條分支上工作，此時要開第二個任務。模型講得出「`git checkout -b` 會把它
# 腳下的分支抽掉」這個危險——但是在被使用者推了之後。沒有任何機制在它真的要打
# 那條指令時攔下來。第二個情境沒有 agent 也成立：切到 topic 分支之後開新分支，
# 基底會混進前一個任務的 commit。現在由 lib/branch-switch-gate.sh 強制。
#
# 這組沿用上面 git init 過的 $SANDBOX（閘門要問「當前分支」與「預設分支」，
# 只有真的切分支才驗得到）。**結束時務必切回 main**——後面的 worktree 那組
# 從這個 repo 開 worktree。

bs() {
    local c="$1"; shift
    run pre-tool-use.sh \
        "$(jq -nc --arg cwd "$SANDBOX" --arg c "$c" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')" \
        "$@"
}
BS_LOG="$SANDBOX/.claude/logs/agent-activity.jsonl"
# in-flight 的判準與 pre-agent-gate 共用 lib/agent-inflight.sh：agent_id 配對、
# 60 分鐘窗、缺 agent_type 印 `-`。這裡帶 agent_type 是因為攔截訊息要印出名單。
bs_start() {
    mkdir -p "$(dirname "$BS_LOG")"
    echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"agent_id\":\"$1\",\"agent_type\":\"$2\"}" >> "$BS_LOG"
}
bs_msg() { bs "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason'; }

gbg_untag
# 沙箱的初始分支名取決於跑測試那台機器的 `init.defaultBranch`（可能是 master）。
# 本閘門的判斷正是「當前分支 == 預設分支嗎」，所以名字必須是確定的——先釘成 main。
# 其他區塊都不依賴分支名（它們只是把 `main` 當字串寫進指令），改名不影響。
gitq branch -M main
gitq checkout main
reset

# ---- 第一格：站在預設分支上 → 放行（這正是 git-workflow.md 第 1 條要的流程）
expect_decision "在 main 上開新分支放行"          allow "$(bs 'git checkout -b feat/x')"
expect_decision "在 main 上 git switch -c 放行"   allow "$(bs 'git switch -c feat/x')"
# 有 agent 在跑也照放：它們也站在 main 上，但「從 main 開分支」是本模板的主流程，
# 擋它等於擋掉正常開發。這一格的取捨寫在 branch-switch-gate.sh 檔頭。
reset; bs_start a1 ui-builder
expect_decision "在 main 上即使有 agent 在跑也放行" allow "$(bs 'git checkout -b feat/x')"

# ---- 不該誤擋的形狀（不帶 -b/-c 的 checkout/switch 都只是換分支或還原檔案）
reset
expect_decision "git checkout <既有分支> 不擋"    allow "$(bs 'git checkout main')"
expect_decision "git switch <既有分支> 不擋"      allow "$(bs 'git switch main')"
expect_decision "git checkout -- <file> 不擋"     allow "$(bs 'git checkout -- src/a.ts')"
expect_decision "git checkout . 不擋"             allow "$(bs 'git checkout .')"
expect_decision "git status 不擋"                 allow "$(bs 'git status')"
expect_decision "不含 git 的指令不擋"             allow "$(bs 'npm run checkout -- -b x')"
expect_decision "heredoc 內文提到指令不擋"        allow "$(bs 'cat > d.md <<EOF
開新任務前先 git checkout -b feat/x
EOF')"

# ---- 第三格：站在 topic 分支、沒有 in-flight agent → 擋一次
gitq checkout -b feat/a
reset
expect_decision "站在 topic 分支上開新分支 → 擋"  deny  "$(bs 'git checkout -b feat/x')"

reset
BS_MSG=$(bs_msg 'git checkout -b feat/x')
expect_contains "訊息講出「一個 checkout 只能站一個分支」" "一個 checkout 同時只能站一個分支" "$BS_MSG"
expect_contains "訊息給出可複製的明確基底指令" "git checkout -b feat/x main" "$BS_MSG"
expect_contains "訊息給出 worktree 的開法"     "claude --worktree feat/x"    "$BS_MSG"
expect_contains "訊息點名當前分支"             "feat/a"                     "$BS_MSG"

# deny-once：同一條分支只講一次
reset
bs 'git checkout -b feat/x' >/dev/null
expect_decision "同一條 topic 分支只擋一次"       allow "$(bs 'git checkout -b feat/y')"

# 標記記的是分支名 —— 換一條 topic 分支是新的現場，該再擋一次
gitq checkout -b feat/b
expect_decision "換一條 topic 分支重新受檢"       deny  "$(bs 'git checkout -b feat/y')"

# 回到預設分支會清掉標記，下次站上 topic 分支重新受檢
gitq checkout main
expect_decision "回到 main 放行（順手清標記）"    allow "$(bs 'git checkout -b feat/y')"
gitq checkout feat/b
expect_decision "清掉標記後再站上 topic 分支又擋" deny  "$(bs 'git checkout -b feat/y')"

# 明確帶 start-point → 基底已表達清楚，那本來就是本閘門推薦的繞法，不能反過來擋它
reset
expect_decision "git checkout -b x main（帶基底）放行" allow "$(bs 'git checkout -b feat/x main')"
expect_decision "git switch -c x main（帶基底）放行"   allow "$(bs 'git switch -c feat/x main')"

# ---- 第二格：站在 topic 分支且有 in-flight agent → 持續擋（不採 deny-once）
reset; bs_start a1 ui-builder
expect_decision "有 agent 在跑時擋"               deny  "$(bs 'git checkout -b feat/x')"
bs 'git checkout -b feat/x' >/dev/null
expect_decision "有 agent 在跑時不採 deny-once"   deny  "$(bs 'git checkout -b feat/x')"
# start-point 解決「基底錯了」，解決不了「HEAD 被搬走，站在上面的 agent 跟著被搬」
expect_decision "有 agent 在跑時帶基底也擋"       deny  "$(bs 'git checkout -b feat/x main')"

reset; bs_start a1 ui-builder; bs_start a2 debug-investigator
BS_MSG=$(bs_msg 'git checkout -b feat/x')
expect_contains "訊息說出有幾個 agent 在跑"    "2 個 subagent 還在跑" "$BS_MSG"
expect_contains "訊息點名是哪幾個 agent"       "debug-investigator"            "$BS_MSG"
expect_contains "訊息誠實說明計數可能含自己"   "你自己就是那個 subagent" "$BS_MSG"

# in-flight 的判準與 pre-agent-gate 共用同一份 lib（agent-inflight.sh）。
# 抽成共用函式之後兩邊必須看到**同一個數字**——各寫各的就是同一個坑修兩次。
expect_decision "同一份 log 下 pre-agent-gate 也擋" deny \
    "$(run pre-agent-gate.sh "$(printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"ui-builder"},"tool_use_id":"tX"}' "$SANDBOX")")"
# agent 完成後歸零 → 兩邊都放行（共用實作的 agent_id 配對沒被抽壞）
echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_complete\",\"agent_id\":\"a1\"}" >> "$BS_LOG"
echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_complete\",\"agent_id\":\"a2\"}" >> "$BS_LOG"
expect_decision "agent 全部完成後 pre-agent-gate 放行" allow \
    "$(run pre-agent-gate.sh "$(printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"ui-builder"},"tool_use_id":"tX"}' "$SANDBOX")")"
expect_decision "agent 全部完成後回到擋一次那一格" deny "$(bs 'git checkout -b feat/x')"

# ---- 逃生門
reset
expect_decision "BRANCH_SWITCH_GATE=off 關閉閘門" allow "$(bs 'git checkout -b feat/x' BRANCH_SWITCH_GATE=off)"
reset; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門"     allow "$(bs 'git checkout -b feat/x')"

# ---- 判斷不了就放行
reset
gitq checkout --detach
expect_decision "detached HEAD 放行（從那裡開分支通常是在救東西）" allow "$(bs 'git checkout -b feat/x')"
gitq checkout feat/b

BS_NOREPO=$(mktemp -d)
expect_decision "不在 git repo 裡放行" allow \
    "$(run pre-tool-use.sh \
        "$(jq -nc --arg cwd "$BS_NOREPO" --arg c 'git checkout -b feat/x' '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')" \
        CLAUDE_PROJECT_DIR="$BS_NOREPO")"
rm -rf "$BS_NOREPO"

# 後面的 worktree 那組從這個 repo 開 worktree，一定要還原成 main
gitq checkout main
reset

# =========================================================================
section "pre-agent-gate.sh — 擋同時派多個無隔離 agent"
# =========================================================================
#
# 為什麼要這個閘門：沒帶 isolation 的 subagent 全部在同一個工作目錄動手，
# 兩個改到同一檔案時後寫的直接覆蓋前面的——沒有衝突提示、沒有錯誤。
# 原本的保護只有 rules/agent-orchestration.md 的一行文字（自律）。

AG_LOG="$SANDBOX/.claude/logs/agent-activity.jsonl"
WARNED_FILE="$SANDBOX/.claude/taskmaster-data/.parallel-agent-warned"
# 對應鍵是 agent_id（不是 tool_use_id）——tool_use_id 屬於「派工這次呼叫」，
# 跨不到 SubagentStop；agent_id 才是同一個 agent 從頭到尾的身分。
ag_start()    { echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"agent_id\":\"$1\"}" >> "$AG_LOG"; }
ag_complete() { echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_complete\",\"agent_id\":\"$1\"}" >> "$AG_LOG"; }
# ag <subagent_type> [isolation]
ag() {
    local iso=""
    [ -n "${2:-}" ] && iso=",\"isolation\":\"$2\""
    run pre-agent-gate.sh "$(printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"%s"%s},"tool_use_id":"tX"}' "$SANDBOX" "$1" "$iso")"
}

reset; mkdir -p "$SANDBOX/.claude/logs"
expect_decision "無 in-flight 時放行" allow "$(ag ui-builder)"

# 兩個不同 agent 都在跑 → 照擋（確認 unique 去重沒把正常情況也吃掉）
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1; ag_start a2
expect_decision "兩筆不同 agent_id 的 start → 仍擋" deny "$(ag ui-builder)"

# 同一個 agent_id 重複寫入不該被算成兩個
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1; ag_start a1; ag_complete a1
expect_decision "重複的 start 由 unique 去重（complete 後歸零）" allow "$(ag ui-builder)"

# 舊格式（只有 tool_use_id、沒有 agent_id）一律忽略，不該讓閘門誤擋
reset; mkdir -p "$SANDBOX/.claude/logs"
echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"tool_use_id\":\"old1\"}" >> "$AG_LOG"
expect_decision "升級前的舊紀錄（無 agent_id）被忽略" allow "$(ag ui-builder)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "有 1 個 in-flight 且新的無隔離 → deny" deny "$(ag ui-builder)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
ag ui-builder >/dev/null
expect_decision "同一批只擋一次（deny-once）" allow "$(ag debug-investigator)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "帶 isolation: worktree 直接放行" allow "$(ag refactor-cleaner worktree)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "帶 isolation: remote 也放行" allow "$(ag ui-builder remote)"

# in-flight 歸零 → 標記清除，下一批重新受檢
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
ag ui-builder >/dev/null                       # 第一批擋一次
ag_complete a1                              # 前一個完成
ag ui-builder >/dev/null                       # 歸零，標記應被清掉
ag_start a2                                 # 新的一批
expect_decision "下一批平行會重新被擋" deny "$(ag ui-builder)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "PARALLEL_AGENT_GATE=off 關閉閘門" allow \
    "$(run pre-agent-gate.sh "$(printf '{"cwd":"%s","tool_input":{"subagent_type":"ui-builder"}}' "$SANDBOX")" PARALLEL_AGENT_GATE=off)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門" allow "$(ag ui-builder)"

# 攔截訊息要先給一個推薦，不是把三個選項丟回去讓使用者自己判斷。
# 推薦只依兩件閘門算得出來的事：工作區乾不乾淨（**WORK_ROOT 下**的 git status）、
# plans/ 有沒有帶 `files:` 的 plan（排除 archive/）。後者為「零」時壓過前者。
#
# 算不出來就不推薦——上面所有案例的沙箱都不是 git repo，它們的攔截訊息因此一律
# 沒有推薦行，順便釘住了「沒有 git／非 repo 時安靜退回中立三選項」。
# 這三條**不能用共用的 $SANDBOX 當 repo**：前面區塊在它底下留了巢狀 git repo
# （git-backup 那組的 emptyrepo 等），`git add -A` 清不乾淨，「乾淨」那條會假失敗。
# 自己開一個獨立 root，順便不必在結束時把 $SANDBOX 的 .git 清掉。
#
# pg_setup <root> <clean|dirty> <plan|noplan>
pg_setup() {
    rm -rf "$1"
    mkdir -p "$1/.claude/logs" "$1/.claude/taskmaster-data/plans"
    git -c init.defaultBranch=main init -q "$1" >/dev/null 2>&1
    # 短命旗標與 log 在真實專案是 gitignore 的，否則閘門自己寫的檔會讓工作區變髒
    printf '.claude/logs/\n.claude/taskmaster-data/.*\n' > "$1/.gitignore"
    if [ "$3" = plan ]; then
        printf -- '---\nfiles:\n  - "src/a.ts"\n---\n' > "$1/.claude/taskmaster-data/plans/p1.md"
    else
        printf -- '---\ntitle: 沒有 files 欄\n---\n' > "$1/.claude/taskmaster-data/plans/p0.md"
    fi
    if [ "$2" = clean ]; then
        git -C "$1" add -A >/dev/null 2>&1
        git -C "$1" -c user.email=t@t -c user.name=t commit -qm base >/dev/null 2>&1
    fi
    echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"agent_id\":\"a1\"}" \
        >> "$1/.claude/logs/agent-activity.jsonl"
}
# pg_gate <root> —— 用該 root 當 CLAUDE_PROJECT_DIR 與 cwd 跑閘門，取回攔截理由
pg_gate() {
    printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"ui-builder"},"tool_use_id":"tX"}' "$1" \
        | env CLAUDE_PROJECT_DIR="$1" bash "$HOOK_DIR/pre-agent-gate.sh" 2>/dev/null \
        | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null
}

PG_RECO="$SANDBOX/pg-reco"
pg_setup "$PG_RECO" dirty plan
expect_contains "工作區不乾淨 → 推薦序列化" "推薦：序列化" "$(pg_gate "$PG_RECO")"

pg_setup "$PG_RECO" clean plan
expect_contains "工作區乾淨 → 推薦帶隔離" "推薦：帶隔離" "$(pg_gate "$PG_RECO")"

# plans/ 存在但沒有任何帶 `files:` 的檔案 → 壓成序列化（工作區乾淨也一樣），
# 且要說出是為什麼
pg_setup "$PG_RECO" clean noplan
expect_contains "沒有帶 files: 的 plan → 序列化並點出原因" \
    '序列化（選項 1）** —— `taskmaster-data/plans/` 裡**沒有任何帶' "$(pg_gate "$PG_RECO")"
rm -rf "$PG_RECO"

# ---- 讀寫衝突盲區（2026-09-16）----
#
# 原本的選項 3 寫「確認**檔案範圍不重疊**後重試即可通過」。掃描／驗證類 agent
# 的**寫入集是空的**，所以那個條件對它永遠成立——閘門親手把模型引導到錯誤結論，
# 再加上 deny-once 就放行了。兩起真實事故：auditor 讀到改到一半的產品碼回報
# 假 failed；審查類 agent 把 debug-investigator 留的 RED 測試檔刪了。
#
# 修法要釘住三件事：推薦改成序列化且理由講讀寫衝突、**收掉選項 3**、
# **不套用 deny-once**（持續擋到 in-flight 歸零或帶 isolation）。
# 一般情境的 deny-once 行為必須**完全不變**。

# ag_start_t <agent_id> <agent_type> —— 帶 agent_type 的 in-flight 紀錄
ag_start_t() {
    echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"agent_id\":\"$1\",\"agent_type\":\"$2\"}" >> "$AG_LOG"
}
ag_reason() { echo "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null; }

# in-flight 是掃描類（這次派的是普通 agent）
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 code-quality-specialist
expect_decision "in-flight 有掃描類 → 擋" deny "$(ag ui-builder)"
SCAN_MSG=$(ag_reason "$(ag ui-builder)")
expect_contains "掃描類推薦序列化"             "推薦：序列化"   "$SCAN_MSG"
expect_contains "理由講的是讀寫衝突"           "讀撞到寫"       "$SCAN_MSG"
expect_contains "附上假 failed 那起事故"       "假 failed"      "$SCAN_MSG"
expect_contains "附上 RED 測試被刪那起事故"    "刻意留紅"       "$SCAN_MSG"
expect_contains "收掉選項 3"                   "這個情境沒有第三條路" "$SCAN_MSG"
case "$SCAN_MSG" in
    *"確認範圍無交集後重試"*) ng "掃描類不得出現選項 3 的原文" "（不出現）" "出現了" ;;
    *) ok "掃描類不得出現選項 3 的原文" ;;
esac
expect_contains "掃描類註明不採 deny-once"     "不採 deny-once" "$SCAN_MSG"

# 不套用 deny-once：連續三次都要擋（一般情境第二次就放行）
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 security-infrastructure-auditor
ag ui-builder >/dev/null
ag ui-builder >/dev/null
expect_decision "掃描類不套用 deny-once（第三次仍擋）" deny "$(ag ui-builder)"

# 這次要派的是掃描類（in-flight 是普通 agent）
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 ui-builder
expect_decision "要派的是掃描類 → 擋" deny "$(ag test-automation-engineer)"
ag test-automation-engineer >/dev/null
expect_decision "要派的是掃描類 → 不套用 deny-once" deny "$(ag e2e-validation-specialist)"
expect_contains "訊息點名這次要派的掃描類 agent" "e2e-validation-specialist" \
    "$(ag_reason "$(ag e2e-validation-specialist)")"

# 兩個出口：帶 isolation、或 in-flight 歸零。少了任何一個這個閘門會鎖死。
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 refactor-cleaner
expect_decision "掃描類帶 isolation 仍直接放行" allow "$(ag code-quality-specialist worktree)"
ag_complete a1
expect_decision "in-flight 歸零後放行"          allow "$(ag code-quality-specialist)"

# 一般情境**完全不變**：三個選項都在、deny-once 照舊
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 ui-builder
NORM_MSG=$(ag_reason "$(ag debug-investigator)")
expect_contains "一般情境仍是三個選擇"         "三個選擇"               "$NORM_MSG"
expect_contains "一般情境保留選項 3"           "確認範圍無交集後重試"   "$NORM_MSG"
expect_contains "一般情境仍是 deny-once"       "本批只擋這一次"         "$NORM_MSG"
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start_t a1 ui-builder
ag debug-investigator >/dev/null
expect_decision "一般情境 deny-once 不變（第二次放行）" allow "$(ag general-purpose)"

# 舊格式（無 agent_type）不能讓 in-flight 計數消失——jq 把它印成 "-" 而不是空行
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_contains "無 agent_type 的 in-flight 仍算 1 個" "已經有 1 個" "$(ag_reason "$(ag ui-builder)")"

# =========================================================================
section "agent-monitor.sh × pre-agent-gate.sh — 非同步派工的完成時機"
# =========================================================================
#
# 為什麼要這組：閘門本身邏輯一直是對的，錯的是它讀的那本帳。
# agent_complete 曾由 PostToolUse(Agent) 寫，而 Agent 工具是**非同步**的——
# 呼叫立刻返回 {"isAsync":true,"status":"async_launched"}。實測 start→complete
# 間隔 2 秒，那個 agent 實際跑了 44 分鐘。於是 in-flight 永遠是 0，
# **閘門從裝上去那天就沒攔截過任何一次**，而它只在攔截時才寫 log，所以無聲無息。
#
# 這組不造假 JSONL，一律走真的 agent-monitor.sh，payload 用實測的欄位形狀。
# 上面那組只測「閘門怎麼讀帳」，這組測「帳記得對不對」——bug 在後者。

am_pre() {
    run agent-monitor.sh "$(jq -nc --arg t "$1" '{
        hook_event_name:"PreToolUse", tool_name:"Agent", session_id:"s1",
        tool_use_id:"tu-pre", tool_input:{subagent_type:$t,description:"d",prompt:"p"}}')"
}
# am_post_async <subagent_type> <agent_id> —— 派工返回（agent 才剛開始跑）
am_post_async() {
    run agent-monitor.sh "$(jq -nc --arg t "$1" --arg a "$2" '{
        hook_event_name:"PostToolUse", tool_name:"Agent", session_id:"s1",
        tool_use_id:("tu-"+$a), tool_input:{subagent_type:$t,description:"d",prompt:"p"},
        tool_response:{isAsync:true,status:"async_launched",agentId:$a}}')"
}
# am_post_sync <subagent_type> <tool_use_id> —— 同步完成（tool_response 沒有 agentId）
am_post_sync() {
    run agent-monitor.sh "$(jq -nc --arg t "$1" --arg u "$2" '{
        hook_event_name:"PostToolUse", tool_name:"Agent", session_id:"s1",
        tool_use_id:$u, tool_input:{subagent_type:$t,description:"d"},
        tool_response:{response:"{\"status\":\"completed\"}"}}')"
}
# am_stop <agent_id> [agent_type] —— agent 真正結束
am_stop() {
    run agent-monitor.sh "$(jq -nc --arg a "$1" --arg t "${2-}" '{
        hook_event_name:"SubagentStop", session_id:"s1", agent_id:$a, agent_type:$t,
        last_assistant_message:"done"}')"
}
ag_events() { jq -rs '[.[]|.event]|join(",")' "$AG_LOG" 2>/dev/null; }

# PreToolUse 不寫帳：agentId 只在 PostToolUse 拿得到，寫在 PreToolUse 就配不到
# SubagentStop。這也是為什麼閘門不再需要「排除自己那一筆」——它跑在 PreToolUse，
# 帳上不可能有自己。
reset; mkdir -p "$SANDBOX/.claude/logs"; am_pre ui-builder >/dev/null
[ -s "$AG_LOG" ] \
    && ng "PreToolUse 不寫 JSONL agent_start" "空的 jsonl" "$(ag_events)" \
    || ok "PreToolUse 不寫 JSONL agent_start"
expect_decision "只派一個 agent 時不擋（自己不算 in-flight）" allow "$(ag ui-builder)"
[ -f "$WARNED_FILE" ] \
    && ng "誤擋不該吃掉 deny-once 額度" "無 warned 標記" "有標記" \
    || ok "誤擋不該吃掉 deny-once 額度"

# 這是本 bug 的核心案例：agent 還在跑（有 PostToolUse、沒有 SubagentStop）
reset; mkdir -p "$SANDBOX/.claude/logs"; am_post_async ui-builder ag001 >/dev/null
expect_contains "派工返回只記 agent_start" "agent_start" "$(ag_events)"
expect_decision "真的 in-flight（未收到 SubagentStop）→ 再派一個要擋" deny "$(ag debug-investigator)"

reset; mkdir -p "$SANDBOX/.claude/logs"
am_post_async ui-builder ag001 >/dev/null; am_stop ag001 ui-builder >/dev/null
expect_decision "收到 SubagentStop 後 → 再派一個放行" allow "$(ag debug-investigator)"

# 實測會收到 agent_type 為空字串的 SubagentStop。不能因此跳過寫入——
# 漏一筆 complete 就讓那個 agent 的 in-flight 永遠不歸零，閘門會從此誤擋每一次委派。
reset; mkdir -p "$SANDBOX/.claude/logs"
am_post_async ui-builder ag002 >/dev/null; am_stop ag002 "" >/dev/null
expect_decision "agent_type 空字串的 SubagentStop 仍能沖銷 in-flight" allow "$(ag debug-investigator)"

# 實測也會收到這個 session 從沒派過的 agent_id
reset; mkdir -p "$SANDBOX/.claude/logs"; am_stop never-dispatched Explore >/dev/null
expect_decision "沒見過的 agent_id 的 SubagentStop → 不爆炸、計數不轉負" allow "$(ag ui-builder)"
reset; mkdir -p "$SANDBOX/.claude/logs"
am_post_async ui-builder ag003 >/dev/null; am_stop never-dispatched Explore >/dev/null
expect_decision "多餘的 complete 不會沖掉別人的 in-flight" deny "$(ag debug-investigator)"

# 同步完成的 agent：PostToolUse 觸發時它已經結束，start/complete 一起寫，淨變化 0
reset; mkdir -p "$SANDBOX/.claude/logs"; am_post_sync Explore tu9 >/dev/null
expect_contains "同步完成同時記 start 與 complete" "agent_start,agent_complete" "$(ag_events)"
expect_decision "同步完成的 agent 不算 in-flight" allow "$(ag ui-builder)"

# 既有行為不能壞：帶隔離的一律放行（有自己的 checkout 與分支）
reset; mkdir -p "$SANDBOX/.claude/logs"; am_post_async ui-builder ag004 >/dev/null
expect_decision "真 in-flight 下帶 isolation: worktree 仍放行" allow "$(ag refactor-cleaner worktree)"

# 不是 Agent 工具的 PostToolUse 不該進這本帳
reset; mkdir -p "$SANDBOX/.claude/logs"
run agent-monitor.sh '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/p/a.ts"}}' >/dev/null
expect_empty "非 Agent 工具不寫 agent 帳" "$(ag_events)"

# =========================================================================
section "resolve-roots.sh — CLAUDE_PROJECT_DIR 未設時的 fallback"
# =========================================================================
#
# 為什麼要這組：其餘 163 個案例的 run() 一律帶 CLAUDE_PROJECT_DIR="$SANDBOX"，
# 所以 fallback 分支從來沒被測到。它曾經寫錯——在被 source 的檔案裡
# ${BASH_SOURCE[0]} 指的是 lib/resolve-roots.sh 自己，`../..` 只回到 `.claude/`，
# 讓所有狀態檔掉進 `.claude/.claude/taskmaster-data/`。
# 平常有環境變數遮住，**CI 裡沒設**，所以那條路徑必須有測試釘住。

reset
# 直接 source 這支 lib，把 MAIN_ROOT 解出來比對
RR_OUT=$(env -u CLAUDE_PROJECT_DIR bash -c '
    source "'"$HOOK_DIR"'/lib/resolve-roots.sh" 2>/dev/null || exit 1
    resolve_roots ""
    printf "%s" "$MAIN_ROOT"
' 2>/dev/null)
RR_EXPECT=$(cd "$HOOK_DIR/../.." && pwd)
if [ "$RR_OUT" = "$RR_EXPECT" ]; then ok "無 CLAUDE_PROJECT_DIR 時 MAIN_ROOT = repo root"
else ng "無 CLAUDE_PROJECT_DIR 時 MAIN_ROOT = repo root" "$RR_EXPECT" "${RR_OUT:-（空）}"; fi

# 反向驗證：不該解到 .claude/（那正是修掉的 bug）
case "$RR_OUT" in
    */.claude) ng "MAIN_ROOT 不該停在 .claude/" "repo root" "$RR_OUT" ;;
    *) ok "MAIN_ROOT 不該停在 .claude/" ;;
esac

# 狀態檔落點：不能出現 .claude/.claude/
RR_DATA=$(env -u CLAUDE_PROJECT_DIR bash -c '
    source "'"$HOOK_DIR"'/lib/resolve-roots.sh" 2>/dev/null || exit 1
    resolve_roots ""
    printf "%s" "$WORK_CLAUDE/taskmaster-data"
' 2>/dev/null)
case "$RR_DATA" in
    *.claude/.claude/*) ng "狀態檔落點不含 .claude/.claude/" "單層" "$RR_DATA" ;;
    *) ok "狀態檔落點不含 .claude/.claude/" ;;
esac

# 帶 cwd（非 worktree）時行為不變
RR_CWD=$(env -u CLAUDE_PROJECT_DIR bash -c '
    source "'"$HOOK_DIR"'/lib/resolve-roots.sh" 2>/dev/null || exit 1
    resolve_roots "{\"cwd\":\"'"$RR_EXPECT"'\"}"
    printf "%s|%s" "$MAIN_ROOT" "$IN_WORKTREE"
' 2>/dev/null)
if [ "$RR_CWD" = "$RR_EXPECT|0" ]; then ok "無環境變數但有 cwd 時仍解到 repo root 且非 worktree"
else ng "無環境變數但有 cwd 時仍解到 repo root 且非 worktree" "$RR_EXPECT|0" "${RR_CWD:-（空）}"; fi

# =========================================================================
section "/suggest-mode 是專案級設定 — worktree 內也要吃主 checkout 的值"

# 隔離表一直把 .suggest-mode 列為 MAIN_CLAUDE 的專案級設定，但這三支曾經只讀
# WORK_CLAUDE，於是主 checkout 打了 /suggest-mode off 也關不掉 worktree 裡的閘門與注入
# （你會以為自己關了）。pre-tool-use.sh 早就是「MAIN 優先、WORK 當 fallback」，
# 這三支改成同一個寫法。每組都配一條對照：沒設 off 時要照樣出聲，否則測的是別的東西。
#
# worktree 只開一次共用——每條各開一個要跑 7 次 git init + worktree add，在 Windows 上
# 是整套測試最慢的一段。代價是必須自己把跨案例的狀態清乾淨，而那正好堵掉三個假通過：
#   .parallel-agent-warned  deny-once：第 1 條擋下後留的旗標會讓第 2 條放行（不是因為修對了）
#   .doc-impact             post-write 每任務只提醒一次：最後一條可能只是被對照那條吃掉
#   .merge-pending          同理
# 原本每條重建 worktree 剛好掩蓋了這三件事。

wt_agent() { jq -nc --arg c "$1" '{tool_name:"Agent", cwd:$c, tool_input:{subagent_type:"ui-builder"}}'; }
wt_bash()  { jq -nc --arg c "$1" '{tool_name:"Bash",  cwd:$c, tool_input:{command:"git merge feature/x"}}'; }
wt_write() { jq -nc --arg c "$1" --arg f "$2" '{tool_name:"Write", cwd:$c, tool_input:{file_path:$f}}'; }

# 清掉會跨案例污染的狀態，但保留 worktree 本身
wt_clear() {
    rm -f "$SM_FILE" \
          "$WT/.claude/taskmaster-data/.suggest-mode" \
          "$WT/.claude/taskmaster-data/.parallel-agent-warned" \
          "$WT/.claude/taskmaster-data/.merge-pending" \
          "$WT/.claude/taskmaster-data/.doc-impact" 2>/dev/null || true
    : > "$AG_LOG" 2>/dev/null || true
}

setup_worktree

wt_clear; ag_start a1
expect_decision "（對照）worktree 沒設 off 時平行閘門仍擋" deny \
    "$(run pre-agent-gate.sh "$(wt_agent "$WT")")"

wt_clear; ag_start a1; echo off > "$SM_FILE"
expect_decision "主 checkout 的 off 關得掉 worktree 的平行閘門" allow \
    "$(run pre-agent-gate.sh "$(wt_agent "$WT")")"

wt_clear; ag_start a1; echo off > "$WT/.claude/taskmaster-data/.suggest-mode"
expect_decision "worktree 自己的 off 仍有效（fallback 沒壞）" allow \
    "$(run pre-agent-gate.sh "$(wt_agent "$WT")")"

wt_clear
out=$(run post-bash.sh "$(wt_bash "$WT")" MERGE_REFLOG_CHECK=off)
[ -n "$out" ] && ok "（對照）worktree 沒設 off 時 post-bash 仍出聲" \
              || ng "（對照）worktree 沒設 off 時 post-bash 仍出聲" "有輸出" "空的"

wt_clear; echo off > "$SM_FILE"
expect_empty "主 checkout 的 off 關得掉 worktree 的合併偵測" \
    "$(run post-bash.sh "$(wt_bash "$WT")" MERGE_REFLOG_CHECK=off)"

wt_clear
out=$(run post-write.sh "$(wt_write "$WT" "$WT/src/api/x.ts")")
[ -n "$out" ] && ok "（對照）worktree 沒設 off 時 post-write 仍出聲" \
              || ng "（對照）worktree 沒設 off 時 post-write 仍出聲" "有輸出" "空的"

wt_clear; echo off > "$SM_FILE"
expect_empty "主 checkout 的 off 關得掉 worktree 的文件債偵測" \
    "$(run post-write.sh "$(wt_write "$WT" "$WT/src/api/x.ts")")"

# =========================================================================
section "2026-10-20 複查修正 — 閘門失效、誤擋、接力注入"
# =========================================================================
#
# 每一條都是獨立複查確認成立的問題。前三條是「閘門安靜地不攔」，最該先修。

NOW_TS() { date '+%Y-%m-%d %H:%M:%S'; }
AGL="$SANDBOX/.claude/logs/agent-activity.jsonl"
ag2() { # <subagent_type> [isolation] —— 派工 PreToolUse
    local iso=""; [ -n "${2:-}" ] && iso=",\"isolation\":\"$2\""
    run pre-agent-gate.sh "$(printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_input":{"subagent_type":"%s"%s},"tool_use_id":"tX"}' "$SANDBOX" "$1" "$iso")"
}
st2() { # <agent_id> <agent_type> [isolation]
    mkdir -p "$SANDBOX/.claude/logs"
    jq -nc --arg ts "$(NOW_TS)" --arg a "$1" --arg t "$2" --arg i "${3:-}" \
        '{timestamp:$ts,event:"agent_start",agent_id:$a,agent_type:$t,isolation:$i}' >> "$AGL"
}

# ---- #1 in-flight 計數遇壞行不能歸零 ----
# 2026-10-16 真實 log 第 992 行只剩 `ord"}`（併發寫入截斷）。`jq -s` 整檔吞 → parse error
# → 計數 0 → 兩道閘門一起靜默失效。
reset; st2 a1 ui-builder; echo 'ord"}' >> "$AGL"
printf '{\n  "timestamp": "x",\n  "event": "agent_start"\n}\n' >> "$AGL"   # 升級前的多行舊格式
expect_decision "jsonl 有壞行時 in-flight 照算（仍擋）" deny "$(ag2 debug-investigator)"
reset; echo 'garbage' >> "$AGL"; st2 a1 ui-builder
expect_decision "壞行在前、正常紀錄在後也照算" deny "$(ag2 debug-investigator)"

# ---- #2 帶隔離、定義自帶隔離、唯讀名單 ----
reset; st2 a1 ui-builder worktree
expect_decision "in-flight 帶 isolation: worktree 不算進計數" allow "$(ag2 debug-investigator)"
reset; st2 a1 ui-builder remote
expect_decision "in-flight 帶 isolation: remote 不算進計數" allow "$(ag2 debug-investigator)"
reset; mkdir -p "$SANDBOX/.claude/agents"
printf -- '---\nname: refactor-cleaner\ntools: ["Read","Bash"]\nisolation: worktree\n---\n\n正文 isolation: none\n' > "$SANDBOX/.claude/agents/refactor-cleaner.md"
st2 a1 refactor-cleaner
expect_decision "in-flight 的定義檔自帶 isolation: worktree → 不算" allow "$(ag2 debug-investigator)"
reset; mkdir -p "$SANDBOX/.claude/agents"
printf -- '---\nname: refactor-cleaner\nisolation: worktree\n---\n' > "$SANDBOX/.claude/agents/refactor-cleaner.md"
st2 a1 ui-builder
expect_decision "要派的 agent 定義檔自帶隔離 → 視同帶隔離放行" allow "$(ag2 refactor-cleaner)"
reset; mkdir -p "$SANDBOX/.claude/agents"
printf -- '---\nname: x\n---\n\nisolation: worktree\n' > "$SANDBOX/.claude/agents/ui-builder.md"
st2 a1 debug-investigator
expect_decision "isolation 寫在 frontmatter 之外不算（只看第一個區塊）" deny "$(ag2 ui-builder)"
for ro in Explore Plan claude-code-guide planner architect workflow-template-manager; do
    reset; st2 a1 ui-builder
    expect_decision "唯讀名單：要派 $ro → 放行" allow "$(ag2 "$ro")"
    reset; st2 a1 "$ro"
    expect_decision "唯讀名單：在跑的 $ro 不算 in-flight" allow "$(ag2 ui-builder)"
done
reset; st2 a1 ui-builder
expect_decision "general-purpose 不在唯讀名單（仍擋）" deny "$(ag2 general-purpose)"
reset; st2 a1 planner; st2 a2 code-quality-specialist
expect_decision "唯讀 agent 不會讓掃描類的讀寫衝突消失" deny "$(ag2 ui-builder)"
# branch-switch-gate 用同一個 lib，自動受惠
BSW="$SANDBOX/bsw-repo"; rm -rf "$BSW"
git -c init.defaultBranch=main init -q "$BSW" >/dev/null 2>&1
git -C "$BSW" -c user.email=t@t -c user.name=t commit -q --allow-empty -m c >/dev/null 2>&1
git -C "$BSW" checkout -q -b feat/topic >/dev/null 2>&1
mkdir -p "$BSW/.claude/logs"
jq -nc --arg ts "$(NOW_TS)" '{timestamp:$ts,event:"agent_start",agent_id:"r1",agent_type:"planner"}' >> "$BSW/.claude/logs/agent-activity.jsonl"
bsw() { jq -nc --arg cwd "$BSW" --arg c "$1" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}' \
        | env CLAUDE_PROJECT_DIR="$BSW" bash "$HOOK_DIR/pre-tool-use.sh" 2>/dev/null; }
case "$(bsw 'git checkout -b feat/x' | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')" in
    *"subagent 還在跑"*) ng "branch-switch：在跑的只有唯讀 agent → 不走「持續擋」那一格" "deny-once 那一格" "持續擋" ;;
    *) ok "branch-switch：在跑的只有唯讀 agent → 不走「持續擋」那一格" ;;
esac
rm -rf "$BSW"

# agent-monitor 把派工參數的 isolation 記進帳
reset; mkdir -p "$SANDBOX/.claude/logs"
run agent-monitor.sh "$(jq -nc '{hook_event_name:"PostToolUse",tool_name:"Agent",session_id:"s",tool_use_id:"t",
    tool_input:{subagent_type:"ui-builder",isolation:"worktree"},tool_response:{isAsync:true,status:"async_launched",agentId:"iso1"}}')" >/dev/null
expect_eq "agent_start 記下 isolation" "worktree" "$(jq -r 'select(.event=="agent_start") | .isolation' "$AGL" 2>/dev/null)"

# ---- #3 效能：沒有 git 的指令跳過四道 git 閘門；lib 單獨用時仍自己切段 ----
reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] pending' > "$MP_FILE"
expect_decision "不含 git 的指令完全不進 git 閘門" allow "$(bg 'npm test -- --grep merge')"
( source "$HOOK_DIR/lib/merge-gate.sh"; unset CMD_SEGS
  out=$(merge_gate "git rebase main" "$SANDBOX/.claude/taskmaster-data")
  case "$out" in *deny*) exit 0 ;; *) exit 1 ;; esac ) \
    && ok "lib 單獨呼叫（沒有 CMD_SEGS）仍自己切段" \
    || ng "lib 單獨呼叫（沒有 CMD_SEGS）仍自己切段" "deny" "沒擋"
SETTINGS="$HOOK_DIR/../settings.json"
expect_eq "pre-tool-use 的 timeout 是 30（超時＝放行，不能貼著實測值）" "30" \
    "$(jq -r '[.hooks.PreToolUse[].hooks[] | select(.command | contains("pre-tool-use.sh")) | .timeout][0]' "$SETTINGS")"

# ---- #4 PowerShell 工具也要過 git 閘門 ----
psg() { run pre-tool-use.sh "$(jq -nc --arg cwd "$SANDBOX" --arg c "$1" '{cwd:$cwd,tool_name:"PowerShell",tool_input:{command:$c}}')"; }
reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] pending' > "$MP_FILE"
expect_decision "PowerShell 的 git rebase 也被合併閘門擋" deny "$(psg 'git rebase main')"
reset
expect_decision "PowerShell 的裸 cd 不擋（那條只管 Bash）" allow "$(psg 'cd C:\temp')"
for ev in PreToolUse PostToolUse PostToolUseFailure; do
    if jq -e --arg ev "$ev" '[.hooks[$ev][]? | select((.matcher // "") | split("|") | index("PowerShell"))] | length > 0' "$SETTINGS" >/dev/null 2>&1; then
        ok "settings.json 的 $ev 有接 PowerShell"
    else ng "settings.json 的 $ev 有接 PowerShell" "matcher 含 PowerShell" "沒有"; fi
done

# ---- #5 判級訊息寫出**這個 checkout** 的模式檔實際路徑 ----
reset
M5=$(run pre-tool-use.sh "$(w /p/src/a.ts)" | jq -r '.hookSpecificOutput.permissionDecisionReason')
expect_contains "判級訊息寫出展開後的模式檔路徑" "$SANDBOX/.claude/taskmaster-data/.current-task-mode" "$M5"
case "$M5" in *'$CLAUDE_PROJECT_DIR'*) ng "判級訊息不再寫未展開的 \$CLAUDE_PROJECT_DIR" "不含" "含" ;;
              *) ok "判級訊息不再寫未展開的 \$CLAUDE_PROJECT_DIR" ;; esac

# ---- #6 模式檔不在 → 依契約從 plan 還原 ----
PL="$SANDBOX/.claude/taskmaster-data/plans"
reset; mkdir -p "$PL"; echo "13.2" > "$SANDBOX/.claude/taskmaster-data/.current-task"
printf -- '---\ntitle: x\nmode: critical\n---\n' > "$PL/13.2-login.md"
R6=$(run pre-tool-use.sh "$(w /p/src/a.ts)")
expect_decision "有 .current-task＋plan 的 mode → 放行" allow "$R6"
expect_contains "放行時告知已從 plan 還原" "已從 plan 還原任務模式 mode=critical" "$R6"
expect_eq "模式檔被寫回 plan 的值" "critical" "$(cat "$MODE_FILE" 2>/dev/null)"
reset; mkdir -p "$PL"; echo "adhoc-2026-10-20-fix-login" > "$SANDBOX/.claude/taskmaster-data/.current-task"
printf -- '---\nmode: quick\n---\n' > "$PL/adhoc-2026-10-20-fix-login.md"
echo standard > "$MODE_FILE"; touch -d '9 hours ago' "$MODE_FILE"
expect_decision "TTL 過期後從 ad-hoc plan 還原（不變相重新判級）" allow "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"
expect_eq "還原的是 plan 的值，不是過期前的值" "quick" "$(cat "$MODE_FILE" 2>/dev/null)"
reset; mkdir -p "$PL/archive"; echo "13.2" > "$SANDBOX/.claude/taskmaster-data/.current-task"
printf -- '---\nmode: quick\n---\n' > "$PL/archive/13.2-old.md"
expect_decision "archive/ 裡的 plan 不算" deny "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"
reset; mkdir -p "$PL"; echo "13.2" > "$SANDBOX/.claude/taskmaster-data/.current-task"
printf -- '---\nmode: fast\n---\n' > "$PL/13.2.md"
expect_decision "plan 的 mode 不是三者之一 → 照舊擋" deny "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"
reset
expect_decision "沒有 .current-task → 照舊擋" deny "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"

# ---- #7 merge-gate 改用切段，不再誤擋 ----
bgj() { run pre-tool-use.sh "$(jq -nc --arg cwd "$SANDBOX" --arg c "$1" '{cwd:$cwd,tool_name:"Bash",tool_input:{command:$c}}')"; }
reset; mkdir -p "$(dirname "$MP_FILE")"; echo '[merge] pending' > "$MP_FILE"
expect_decision "待驗證期間 git merge-base 放行" allow "$(bgj 'git merge-base HEAD main')"
expect_decision "待驗證期間 git log | grep \"git merge\" 放行" allow "$(bgj 'git log --oneline | grep "git merge"')"
expect_decision "待驗證期間 commit 訊息提到 git merge 放行" allow "$(bgj 'git commit -m "docs: git merge 說明"')"
expect_decision "--abort 之後鏈上真的合併仍擋（逐段判斷）" deny "$(bgj 'git merge --abort && git rebase main')"

# ---- #8 / #16 真的 repo：reflog 判斷合併有沒有發生、合併帶回文件債 ----
GR2="$SANDBOX/merge-repo"; rm -rf "$GR2"; mkdir -p "$GR2"
gr2() { git -C "$GR2" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
gr2 init -q -b main; echo a > "$GR2/README.md"; gr2 add -A; gr2 commit -qm base
gr2 checkout -q -b feat; mkdir -p "$GR2/src/api" "$GR2/src/ui"
echo x > "$GR2/src/api/users.ts"; echo y > "$GR2/src/ui/button.css"; echo t > "$GR2/src/api/users.test.ts"
gr2 add -A; gr2 commit -qm feat; gr2 checkout -q main
gr2 merge --no-ff -m "merge: feat" feat
pbr() { # <event: ok|fail> <command> [ENV=VAL…] —— 帶 cwd 的真實形狀（不關 reflog 檢查）
    local ev="$1" c="$2"; shift 2
    if [ "$ev" = ok ]; then
        run post-bash.sh "$(jq -nc --arg d "$GR2" --arg c "$c" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$d,tool_input:{command:$c},tool_response:{stdout:"",stderr:""}}')" "$@"
    else
        run post-bash.sh "$(jq -nc --arg d "$GR2" --arg c "$c" '{hook_event_name:"PostToolUseFailure",tool_name:"Bash",cwd:$d,tool_input:{command:$c},error:"Exit code 1"}')" "$@"
    fi
}
DI_F="$SANDBOX/.claude/taskmaster-data/.doc-impact"
reset
OUT16=$(pbr ok 'git merge --no-ff -m "merge: feat" feat')
mp_has "真的合併成功 → 記待驗證" '[merge] feat'
if grep -qxF 'src/api/users.ts' "$DI_F" 2>/dev/null; then ok "合併帶進的 API 檔補進 .doc-impact"
else ng "合併帶進的 API 檔補進 .doc-impact" "src/api/users.ts" "$(cat "$DI_F" 2>/dev/null)"; fi
if grep -qE 'button\.css|users\.test\.ts|README' "$DI_F" 2>/dev/null; then
    ng "非文件對象（樣式、測試、README）不進 .doc-impact" "只有 users.ts" "$(cat "$DI_F")"
else ok "非文件對象（樣式、測試、README）不進 .doc-impact"; fi
expect_contains "合併成功訊息提到補進的文件債" "已補進" "$OUT16"
reset; pbr ok 'git merge --no-ff -m "merge: feat" feat' DOC_SYNC_GATE=off >/dev/null
[ -s "$DI_F" ] && ng "DOC_SYNC_GATE=off 時合併不補 .doc-impact" "空" "$(cat "$DI_F")" \
               || ok "DOC_SYNC_GATE=off 時合併不補 .doc-impact"
# 合併之後又有別的 commit → reflog 最新一筆不是合併 → 這次失敗的 merge 沒發生
gr2 commit -q --allow-empty -m later
reset; pbr fail 'git merge --no-ff no-such-branch' >/dev/null
mp_empty "失敗且 reflog 最新不是合併 → 不記（分支名打錯）"
# 成功事件不查 reflog（2026-10-21）：查了會連 merge --squash／--no-commit 一起濾掉（見 #18）。
# 代價是這種「; 吃掉失敗」的形狀會多記一筆——多跑一次 /verify，方向偏多記。
reset; pbr ok 'git merge --no-ff no-such-branch; echo done' >/dev/null
mp_has "整條成功（; 吃掉失敗）→ 照舊記（成功事件不查 reflog）" '[merge] no-such-branch'
reset; pbr fail 'git merge --no-ff no-such-branch' MERGE_REFLOG_CHECK=off >/dev/null
mp_has "MERGE_REFLOG_CHECK=off 恢復一律記" '[merge] no-such-branch'
# 合併真的成功、是鏈在後面的指令失敗 → reflog 證實 → 記，且訊息講清楚
gr2 checkout -q -b feat2; echo z > "$GR2/src/api/orders.ts"; gr2 add -A; gr2 commit -qm feat2; gr2 checkout -q main
gr2 merge --no-ff -m "merge: feat2" feat2
reset; OUT8=$(pbr fail 'git merge --no-ff -m "merge: feat2" feat2 && false')
mp_has "失敗事件但 reflog 證實合併已發生 → 記" '[merge] feat2'
expect_contains "訊息說明合併本身已完成" "合併本身已經完成" "$OUT8"
# ---- #18 merge --squash 成功不動 HEAD、不留合併類 reflog，仍要記（2026-10-21 審查 M2）----
gr2 checkout -q -b feat3; echo s > "$GR2/src/api/squash.ts"; gr2 add -A; gr2 commit -qm feat3; gr2 checkout -q main
gr2 merge --squash feat3
reset; pbr ok 'git merge --squash feat3' >/dev/null
mp_has "merge --squash 成功（reflog 最新是 checkout）→ 仍記待驗證" '[merge] feat3'
if grep -qxF 'src/api/squash.ts' "$DI_F" 2>/dev/null; then ok "merge --squash 帶進的 API 檔補進 .doc-impact"
else ng "merge --squash 帶進的 API 檔補進 .doc-impact" "src/api/squash.ts" "$(cat "$DI_F" 2>/dev/null)"; fi
# ---- #19 reflog 濾掉的失敗 merge 仍進連續失敗計數（2026-10-21 審查 M3：曾整支 exit 0）----
gr2 commit -qm squashed; gr2 commit -q --allow-empty -m later2
reset; pbr fail 'git merge --no-ff no-such-branch' >/dev/null
mp_empty "（前提）失敗且 reflog 最新不是合併 → 不記"
expect_eq "被濾掉的失敗 merge 仍計入 .bash-fail-streak" "1	git merge --no-ff no-such-branch" \
    "$(cat "$SANDBOX/.claude/taskmaster-data/.bash-fail-streak" 2>/dev/null | tr -d '\r')"
rm -rf "$GR2"

# ---- #11 報告稽核：agent 還沒結束就不催；refactor-cleaner 改成提醒落檔 ----
EXP="$SANDBOX/.claude/taskmaster-data/.report-expectations.jsonl"
exp_line() { # <agent> <area> <agent_id> <幾秒前>
    jq -nc --arg a "$1" --arg ar "$2" --arg id "$3" --argjson ep "$(( $(date +%s) - $4 ))" \
        '{ts:"x",epoch:$ep,agent:$a,area:$ar,agent_id:$id,notified:0}' >> "$EXP"
}
cre() { bash "$HOOK_DIR/lib/check-report-expectations.sh" "$SANDBOX/.claude" "$SANDBOX/.claude" 2>/dev/null; }
reset; mkdir -p "$SANDBOX/.claude/logs"; exp_line ui-builder quality agX 600
st2 agX ui-builder
expect_empty "agent 還沒收到 SubagentStop → 先不催報告" "$(cre)"
expect_contains "還在跑的期望原樣留著（記下 running_seen）" "running_seen" "$(cat "$EXP")"
jq -nc --arg ts "$(NOW_TS)" '{timestamp:$ts,event:"agent_complete",agent_id:"agX"}' >> "$AGL"
expect_contains "結束之後才催補寫" "ui-builder" "$(cre)"
reset; mkdir -p "$SANDBOX/.claude/logs"; exp_line ui-builder quality "" 600
expect_contains "沒有 agent_id 的期望照舊只看時間" "ui-builder" "$(cre)"
reset; mkdir -p "$SANDBOX/.claude/logs"; exp_line refactor-cleaner quality "" 600
O11=$(cre)
expect_contains "refactor-cleaner 沒檔案 → 提醒主模型從回應落檔" "最終回應" "$O11"
case "$O11" in *"完成後沒寫報告"*) ng "refactor-cleaner 不被當成缺報告" "不含缺漏措辭" "$O11" ;;
               *) ok "refactor-cleaner 不被當成缺報告" ;; esac
# post-agent-report 記期望時一起記 agent_id
reset; mkdir -p "$SANDBOX/.claude/logs"
run post-agent-report.sh "$(jq -nc --arg d "$SANDBOX" '{cwd:$d,tool_name:"Agent",tool_input:{subagent_type:"ui-builder"},tool_response:{isAsync:true,status:"async_launched",agentId:"agY"}}')" >/dev/null
expect_eq "期望帶 agent_id" "agY" "$(jq -r '.agent_id' "$EXP" 2>/dev/null)"

# ---- #13 坑閘門的 files: 樣式不被 glob 展開 ----
reset; mkdir -p "$SANDBOX/.claude/context/learned" "$SANDBOX/g13/src/x"; : > "$SANDBOX/g13/src/x/real.ts"
printf -- '---\ntitle: 星號樣式\nfiles: ["src/*/*.ts"]\nguard: g\n---\n' > "$SANDBOX/.claude/context/learned/glob.md"
echo standard > "$MODE_FILE"
expect_decision "樣式在 cwd 有同名檔時不被展開（仍命中坑閘門）" deny \
    "$(cd "$SANDBOX/g13" && run pre-tool-use.sh "$(w "$SANDBOX/src/other/b.ts")")"
rm -rf "$SANDBOX/g13"

# ---- #14 pending handoff 也從 UserPromptSubmit 注入 ----
reset; mk_handoff "h14.md" pending high
expect_contains "使用者下一句話時注入 pending 交接" "planner → ui-builder" "$(run user-prompt-submit.sh "$(p '今天天氣如何')")"
expect_contains "斜線指令也注入（交接是既成事實）" "待處理 agent 交接" "$(run user-prompt-submit.sh "$(p '/task-next')")"
expect_contains "agent 交回訊息也注入（接力的時點）" "待處理 agent 交接" "$(run user-prompt-submit.sh "$(p "$HANDBACK")")"
expect_eq "格式與 post-agent-report 一致" \
    "$(run post-agent-report.sh '{"tool_name":"Agent"}' | jq -r '.hookSpecificOutput.additionalContext' | tr -d '\r')" \
    "$(run user-prompt-submit.sh "$(p '/task-next')" | tr -d '\r')"
reset; mk_handoff "h14.md" completed high
expect_empty "沒有 pending 時不注入" "$(run user-prompt-submit.sh "$(p '/task-next')")"
reset; for i in 1 2 3 4 5 6 7; do mk_handoff "h$i.md" pending high; done
expect_contains "上限 5 筆" "偵測到 5 個" "$(run user-prompt-submit.sh "$(p '/task-next')")"

# ---- #15 跨 session 接續 ----
reset; echo "13.2" > "$SANDBOX/.claude/taskmaster-data/.current-task"
mkdir -p "$PL"; printf -- '---\nmode: critical\n---\n' > "$PL/13.2-x.md"
mkdir -p "$SANDBOX/.claude/sessions"; : > "$SANDBOX/.claude/sessions/2026-10-20-a.md"
S15=$(run session-start.sh '{}' | jq -r '.hookSpecificOutput.additionalContext')
expect_contains "開場注入進行中任務與 mode（mode 取自 plan）" "進行中任務 \`13.2\`（mode critical）" "$S15"
expect_contains "附最新 session 存檔路徑" ".claude/sessions/2026-10-20-a.md" "$S15"
reset
case "$(run session-start.sh '{}')" in *"進行中任務"*) ng "沒有 .current-task 不注入" "不含" "含" ;; *) ok "沒有 .current-task 不注入" ;; esac
reset; mkdir -p "$SANDBOX/.claude/taskmaster-data"; echo x > "$SANDBOX/.claude/taskmaster-data/.learned-candidates"
expect_contains "踩坑候選改成收尾時處理" "收尾時處理" "$(run session-start.sh '{}')"

# ---- #17 Windows 反斜線路徑的正規化 ----
reset
expect_decision "反斜線路徑的 .claude/** 仍放行" allow \
    "$(run pre-tool-use.sh "$(jq -nc --arg f 'C:\p\.claude\hooks\x.sh' '{tool_name:"Write",tool_input:{file_path:$f}}')")"
expect_decision "反斜線路徑的程式碼檔仍擋（未判級）" deny \
    "$(run pre-tool-use.sh "$(jq -nc --arg f 'C:\p\src\a.ts' '{tool_name:"Write",tool_input:{file_path:$f}}')")"

# ---- #20 branch -D 的分支名不是字面值 → 退回看 HEAD（2026-10-21 審查 H1）----
# cmd_segments 把引號內容清成 `""`；`$B`、`$(…)` 也不是分支名。曾經「查不到就當不存在」→ 全部放行。
BD="$SANDBOX/bd-repo"; rm -rf "$BD"
git -c init.defaultBranch=main init -q "$BD" >/dev/null 2>&1
bdq() { git -C "$BD" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
bdq commit --allow-empty -m c1; bdq branch feat/q
reset
expect_decision "branch -D \"feat/q\"（雙引號）→ 擋" deny "$(gbo 'git branch -D "feat/q"' "$BD")"
expect_decision "branch -D 'feat/q'（單引號）→ 擋" deny "$(gbo "git branch -D 'feat/q'" "$BD")"
expect_decision "branch -D \$B（變數）→ 擋" deny "$(gbo 'B=feat/q; git branch -D $B' "$BD")"
expect_decision "branch -D \$(…)（指令替換）→ 擋" deny "$(gbo 'git branch -D $(git branch --list "feat/*")' "$BD")"
expect_decision "字面且不存在的分支 → 仍放行" allow "$(gbo 'git branch -D no-such' "$BD")"
expect_decision "字面且存在、tip 沒 tag → 擋" deny "$(gbo 'git branch -D feat/q' "$BD")"
bdq tag backup/feat-q feat/q; bdq commit --allow-empty -m c2
expect_decision "字面且存在、tip 有 tag（HEAD 沒有）→ 放行" allow "$(gbo 'git branch -D feat/q' "$BD")"
expect_decision "引號形式退回看 HEAD：HEAD 沒 tag → 擋（即使 tip 有）" deny "$(gbo 'git branch -D "feat/q"' "$BD")"
bdq tag backup/main-head
expect_decision "引號形式退回看 HEAD：HEAD 有 tag → 放行" allow "$(gbo 'git branch -D "feat/q"' "$BD")"
rm -rf "$BD"

# ---- #21 文件影響的測試排除錨定在目錄／檔名邊界（2026-10-21 審查 M6）----
( source "$HOOK_DIR/lib/doc-impact.sh"
  for p in src/api/latest/routes.ts src/contest/api/x.ts src/inspector/routes/a.ts src/api/specification/schema.json; do
      doc_bearing "$p" && echo "IN $p" || echo "OUT $p"
  done
  for p in src/api/routes.test.ts src/api/routes.spec.ts tests/api/x.py test/api/x.py src/__tests__/api/x.ts \
           spec/api/x.rb src/api/test_users.py src/api/users_test.go src/api/fixtures/x.json; do
      doc_bearing "$p" && echo "IN $p" || echo "OUT $p"
  done ) > "$SANDBOX/di21.txt" 2>/dev/null
for p in src/api/latest/routes.ts src/contest/api/x.ts src/inspector/routes/a.ts src/api/specification/schema.json; do
    grep -qxF "IN $p" "$SANDBOX/di21.txt" && ok "路徑含 test/spec 子字串仍是文件對象：$p" \
        || ng "路徑含 test/spec 子字串仍是文件對象：$p" "IN" "$(grep -F " $p" "$SANDBOX/di21.txt")"
done
for p in src/api/routes.test.ts src/api/routes.spec.ts tests/api/x.py test/api/x.py src/__tests__/api/x.ts \
         spec/api/x.rb src/api/test_users.py src/api/users_test.go src/api/fixtures/x.json; do
    grep -qxF "OUT $p" "$SANDBOX/di21.txt" && ok "測試檔／目錄仍排除：$p" \
        || ng "測試檔／目錄仍排除：$p" "OUT" "$(grep -F " $p" "$SANDBOX/di21.txt")"
done
rm -f "$SANDBOX/di21.txt"
reset
expect_contains "post-write：src/api/latest/routes.ts 觸發文件影響提醒" "文件影響提醒" \
    "$(run post-write.sh "$(w "$SANDBOX/src/api/latest/routes.ts")")"

# =========================================================================
section "pre-tool-use.sh — rm 權限（lib/rm-state-gate.sh）"
# =========================================================================
# 取代 settings.json 的 ask: Bash(rm:*)。三種結果：allow（只刪狀態檔）、ask（其他 rm）、
# none（只刪狀態檔但混了別的指令，交回 Claude Code 原本的流程）
reset
# rmd <指令> [cwd] [tool] [ENV=VAL ...] —— 印出 allow／ask／none
rmd() {
    local c="$1" cwd="${2-$SANDBOX}" tool="${3:-Bash}" out
    shift $(( $# < 3 ? $# : 3 ))
    out=$(run pre-tool-use.sh "$(jq -nc --arg c "$c" --arg cwd "$cwd" --arg t "$tool" '{cwd:$cwd,tool_name:$t,tool_input:{command:$c}}')" "$@")
    [ -n "$out" ] && echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"' || echo none
}
TD=.claude/taskmaster-data
expect_eq "只刪狀態檔（相對路徑）→ allow"            allow "$(rmd "rm $TD/.merge-pending")"
expect_eq "只刪狀態檔（絕對路徑、-f、多個）→ allow"  allow "$(rmd "rm -f \"$SANDBOX/$TD/.doc-impact\" $TD/.doc-impact-notified")"
expect_eq "先 cd 到專案根再刪 → allow"               allow "$(rmd "cd \"$SANDBOX\" && rm $TD/.pitfall-seen" /elsewhere)"
expect_eq "cwd 在子目錄、用 ../ 相對路徑 → ask"      ask   "$(rmd "rm ../$TD/.merge-pending" "$SANDBOX/src")"
if command -v cygpath >/dev/null 2>&1; then
    expect_eq "Windows 形式的絕對路徑 → allow"       allow "$(rmd "rm \"$(cygpath -m "$SANDBOX")/$TD/.merge-pending\"")"
fi
# 2026-10-27 使用者回報的那條：/verify 清合併閘門時串了 echo 與 git status
expect_eq "只刪狀態檔但串了其他指令 → 不表態"         none  "$(rmd "cd \"$SANDBOX\" && rm $TD/.merge-pending && echo \"[\$(date '+%Y-%m-%d')] cleared\" >> .claude/logs/hooks.log && git status -sb | head -1")"
expect_eq "刪程式碼 → ask"                            ask   "$(rmd "rm src/app.py")"
expect_eq "刪資料庫檔 → ask"                          ask   "$(rmd "rm -f data/app.db")"
expect_eq "狀態檔與程式碼一起刪 → ask"                ask   "$(rmd "rm $TD/.a && rm db.sqlite")"
expect_eq "狀態檔與程式碼在同一個 rm → ask"           ask   "$(rmd "rm $TD/.a src/x.ts")"
expect_eq "-r 刪整個目錄 → ask"                       ask   "$(rmd "rm -rf $TD")"
expect_eq "用 .. 跳出 taskmaster-data → ask"          ask   "$(rmd "rm $TD/.x/../../../src/a.py")"
expect_eq "萬用字元 → ask"                            ask   "$(rmd "rm $TD/.*")"
expect_eq "變數 → ask"                                ask   "$(rmd 'rm "$F"')"
expect_eq "指令替換 → ask"                            ask   "$(rmd 'rm $(cat list.txt)')"
expect_eq "taskmaster-data 底下不是 . 開頭的檔 → ask" ask   "$(rmd "rm $TD/wbs.md")"
expect_eq "不知道 cwd 的相對路徑 → ask"               ask   "$(rmd "rm $TD/.merge-pending" "")"
expect_eq "cd 到變數之後的相對路徑 → ask"             ask   "$(rmd "cd \$D && rm $TD/.merge-pending")"
expect_eq "heredoc 餵給 bash 的 rm → ask"             ask   "$(rmd $'bash <<EOF\nrm -rf src\nEOF')"
expect_eq "commit 訊息提到 rm → ask（寧可多問）"     ask   "$(rmd 'git commit -m "rm the old file"')"
expect_eq "echo 的參數有 rm → ask（寧可多問）"        ask   "$(rmd 'echo rm is fine')"
expect_eq "沒有 rm → 不表態"                          none  "$(rmd 'ls -la')"
expect_eq "RM_STATE_GATE=off → 不表態"               none  "$(rmd 'rm src/a.py' "$SANDBOX" Bash RM_STATE_GATE=off)"
expect_eq "PowerShell 不管 → 不表態"                  none  "$(rmd 'rm src/a.py' "$SANDBOX" PowerShell)"
expect_eq "rm 狀態檔 > 程式碼檔 → ask（會清空 src）"   ask   "$(rmd "rm $TD/.a > src/main.py")"
expect_eq "rm 狀態檔 >> 程式碼檔 → ask"               ask   "$(rmd "rm $TD/.a >> src/main.py")"
expect_eq "rm 狀態檔 1> 程式碼檔 → ask"               ask   "$(rmd "rm $TD/.a 1> src/main.py")"
expect_eq "rm 狀態檔 >src/x（黏著）→ ask"             ask   "$(rmd "rm $TD/.a >src/main.py")"
expect_eq "rm 狀態檔 2>/dev/null → allow"             allow "$(rmd "rm -f $TD/.a 2>/dev/null")"
expect_eq "rm 狀態檔 2>&1 → allow"                    allow "$(rmd "rm -f $TD/.a 2>&1")"
expect_eq "cd . > src/x 再 rm 狀態檔 → 不是 allow"   none  "$(rmd "cd . > src/main.py; rm $TD/.a")"
expect_eq "rm 在 \$() 裡 → ask"                       ask   "$(rmd 'echo "$(rm src/x)"')"
expect_eq "rm 在反引號裡 → ask"                       ask   "$(rmd 'echo `rm src/x`')"
expect_eq "rm 在 { } 裡 → ask"                        ask   "$(rmd '{ rm src/x; }')"
expect_eq "rm 在 then 後 → ask"                       ask   "$(rmd 'if true; then rm src/x; fi')"
expect_eq "rm 在 do 後 → ask"                         ask   "$(rmd 'for f in a; do rm src/x; done')"
expect_eq "\\rm → ask"                                ask   "$(rmd '\rm src/x')"
expect_eq "command rm → ask"                          ask   "$(rmd 'command rm src/x')"
expect_eq "VAR=1 rm → ask"                            ask   "$(rmd 'VAR=1 rm src/x')"
expect_eq "bash -c 'rm …' → ask"                      ask   "$(rmd "bash -c 'rm src/x'")"
expect_eq "/bin/rm → ask"                             ask   "$(rmd '/bin/rm src/x')"
expect_eq "git rm --cached → 不表態"                  none  "$(rmd 'git rm --cached src/x')"
expect_eq "git -C . rm -q 串 git status → 不表態"     none  "$(rmd 'git -C . rm -q src/x && git status')"
expect_eq "TASKMODE_GATE=off 刪程式碼仍 ask"         ask   "$(rmd 'rm src/x' "$SANDBOX" Bash TASKMODE_GATE=off)"
expect_eq "TASKMODE_GATE=off 刪狀態檔仍 allow"       allow "$(rmd "rm $TD/.a" "$SANDBOX" Bash TASKMODE_GATE=off)"
echo off > "$SM_FILE"
expect_eq ".suggest-mode=off 刪程式碼仍 ask"         ask   "$(rmd 'rm src/x')"
expect_eq ".suggest-mode=off 刪狀態檔仍 allow"       allow "$(rmd "rm $TD/.a")"
rm -f "$SM_FILE"
expect_eq "settings.json 已沒有 rm 的 ask 規則"       "" "$(jq -r '.permissions.ask // [] | map(select(startswith("Bash(rm"))) | .[]' "$HOOK_DIR/../settings.json")"

# =========================================================================
section "全體 hooks — 語法與健壯性"
# =========================================================================
for h in "$HOOK_DIR"/*.sh; do
    n=$(basename "$h")
    bash -n "$h" 2>/dev/null && ok "$n 語法正確" || ng "$n 語法正確" "可解析" "語法錯誤"
done

# lib/ 底下的被 source 進來，語法錯會讓呼叫端整支軟失效（`source ... || true` 吞掉錯誤）
for h in "$HOOK_DIR"/lib/*.sh; do
    n="lib/$(basename "$h")"
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
