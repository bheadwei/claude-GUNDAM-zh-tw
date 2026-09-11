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
to: tdd-guide
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
expect_contains "失敗 3 次後成功會提醒" "這是一個坑" "$(pb ok "uv run pytest")"
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
pbash() { local c="$1"; shift; run post-bash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"tool_response":{"is_error":false}}' "$c")" "$@"; }

# 偵測：合併成功要記進 .merge-pending 並提醒
reset
expect_contains "合併成功會提醒未驗證" "還沒驗證" "$(pbash 'git merge --no-ff worktree-search')"
# 清單記的是「[操作類型] 目標 ref」而不是整條指令 —— /verify 靠它分辨
# 哪些分支合進來了、該比對哪幾份 plan 的驗收標準。
if grep -qx '\[merge\] worktree-search' "$MP_FILE" 2>/dev/null; then ok "合併記入 .merge-pending（帶類型與 ref）"
else ng "合併記入 .merge-pending（帶類型與 ref）" "[merge] worktree-search" "$(cat "$MP_FILE" 2>/dev/null)"; fi

# 衝突的合併**也要**記 —— 曾經只記成功的，那是個洞：
# 衝突退出碼非零 → 不記 → conflict-resolver 解完 commit 後清單是空的
# → 下一次合併直接放行、跳過驗證。解過衝突的結果更需要驗證，不是更不需要。
reset
expect_contains "衝突的合併會導向 conflict-resolver" "conflict-resolver" \
    "$(run post-bash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"git merge x"},"tool_response":{"is_error":true}}')")"
if grep -qx '\[merge\] x' "$MP_FILE" 2>/dev/null; then ok "衝突的合併也記入 .merge-pending"
else ng "衝突的合併也記入 .merge-pending" "[merge] x" "$(cat "$MP_FILE" 2>/dev/null)"; fi

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
pbashj() { run post-bash.sh "$(jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c},tool_response:{is_error:false}}')"; }
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

# 正向：真的執行的仍然要記，且類型與 ref 不能跑掉
reset; pbashj 'git merge feature/x' >/dev/null
mp_has "真正的 merge 仍記錄（ref 正確抽出）" '[merge] feature/x'

reset; pbashj 'cd /some/path && git cherry-pick abc123' >/dev/null
mp_has "鏈式 cd && cherry-pick 仍記錄（類型正確）" '[cherry-pick] abc123'

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
expect_decision "MERGE_GATE=off 關閉閘門"        allow \
    "$(run pre-tool-use.sh "$(printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"git merge x"}}' "$SANDBOX")" MERGE_GATE=off)"

# 清單為空 → 放行（/verify 通過後的狀態）
reset; mkdir -p "$(dirname "$MP_FILE")"; : > "$MP_FILE"
expect_decision "清單為空時放行 merge" allow "$(bg 'git merge --no-ff worktree-cart')"

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
expect_decision "reset --hard 沒快照時被擋"      deny "$(gb 'git reset --hard HEAD')"
expect_decision "push --force 沒快照時被擋"      deny "$(gb 'git push --force origin main')"
expect_decision "push -f 沒快照時被擋"           deny "$(gb 'git push -f origin main')"
# --force-with-lease 防的是覆蓋**別人**的 push，不是防自己弄丟本地工作 → 不特例放行
expect_decision "push --force-with-lease 不特例放行" deny "$(gb 'git push --force-with-lease origin main')"
expect_decision "branch -D 沒快照時被擋"         deny "$(gb 'git branch -D feat/x')"
expect_decision "rebase 沒快照時被擋"            deny "$(gb 'git rebase main')"
# 真實用法常是鏈式的，指令段不是整條指令的開頭
expect_decision "鏈式 cd x && git reset --hard 也擋" deny "$(gb 'cd /tmp && git reset --hard HEAD')"

# deny 訊息要能直接複製，不能只說「請先打 tag」
expect_contains "deny 訊息給出可複製的 tag 指令" "git tag backup/" \
    "$(gb 'git reset --hard HEAD' | jq -r '.hookSpecificOutput.permissionDecisionReason')"

# 有快照 → 放行；但快照必須指向**當前** HEAD
reset; gbg_untag; gitq tag "backup/main-test"
expect_decision "backup tag 指向 HEAD 時放行"    allow "$(gb 'git reset --hard HEAD')"

gitq commit --allow-empty -m c2      # HEAD 前進，tag 留在舊 commit
expect_decision "tag 指向舊 commit 時仍擋"       deny  "$(gb 'git reset --hard HEAD')"
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

# 逃生門
expect_decision "GIT_BACKUP_GATE=off 關閉閘門"   allow "$(gb 'git reset --hard HEAD' GIT_BACKUP_GATE=off)"
reset; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門"    allow "$(gb 'git reset --hard HEAD')"

# 判斷不了就放行（缺依賴／狀態不明時寧可放行也不誤擋）
reset
GBG_EMPTY="$SANDBOX/emptyrepo"; mkdir -p "$GBG_EMPTY"
git -c init.defaultBranch=main init -q "$GBG_EMPTY" >/dev/null 2>&1
expect_decision "空 repo（unborn HEAD）放行"     allow "$(gbo 'git reset --hard HEAD' "$GBG_EMPTY")"

GBG_NOREPO=$(mktemp -d)
expect_decision "不在 git repo 裡放行"           allow "$(gbo 'git reset --hard HEAD' "$GBG_NOREPO")"
rm -rf "$GBG_NOREPO"

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
expect_decision "無 in-flight 時放行" allow "$(ag planner)"

# 兩個不同 agent 都在跑 → 照擋（確認 unique 去重沒把正常情況也吃掉）
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1; ag_start a2
expect_decision "兩筆不同 agent_id 的 start → 仍擋" deny "$(ag planner)"

# 同一個 agent_id 重複寫入不該被算成兩個
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1; ag_start a1; ag_complete a1
expect_decision "重複的 start 由 unique 去重（complete 後歸零）" allow "$(ag planner)"

# 舊格式（只有 tool_use_id、沒有 agent_id）一律忽略，不該讓閘門誤擋
reset; mkdir -p "$SANDBOX/.claude/logs"
echo "{\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"agent_start\",\"tool_use_id\":\"old1\"}" >> "$AG_LOG"
expect_decision "升級前的舊紀錄（無 agent_id）被忽略" allow "$(ag planner)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "有 1 個 in-flight 且新的無隔離 → deny" deny "$(ag planner)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
ag planner >/dev/null
expect_decision "同一批只擋一次（deny-once）" allow "$(ag tdd-guide)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "帶 isolation: worktree 直接放行" allow "$(ag refactor-cleaner worktree)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "帶 isolation: remote 也放行" allow "$(ag planner remote)"

# in-flight 歸零 → 標記清除，下一批重新受檢
reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
ag planner >/dev/null                       # 第一批擋一次
ag_complete a1                              # 前一個完成
ag planner >/dev/null                       # 歸零，標記應被清掉
ag_start a2                                 # 新的一批
expect_decision "下一批平行會重新被擋" deny "$(ag planner)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1
expect_decision "PARALLEL_AGENT_GATE=off 關閉閘門" allow \
    "$(run pre-agent-gate.sh "$(printf '{"cwd":"%s","tool_input":{"subagent_type":"planner"}}' "$SANDBOX")" PARALLEL_AGENT_GATE=off)"

reset; mkdir -p "$SANDBOX/.claude/logs"; ag_start a1; echo off > "$SM_FILE"
expect_decision "suggest-mode=off 也關閉閘門" allow "$(ag planner)"

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
reset; mkdir -p "$SANDBOX/.claude/logs"; am_pre planner >/dev/null
[ -s "$AG_LOG" ] \
    && ng "PreToolUse 不寫 JSONL agent_start" "空的 jsonl" "$(ag_events)" \
    || ok "PreToolUse 不寫 JSONL agent_start"
expect_decision "只派一個 agent 時不擋（自己不算 in-flight）" allow "$(ag planner)"
[ -f "$WARNED_FILE" ] \
    && ng "誤擋不該吃掉 deny-once 額度" "無 warned 標記" "有標記" \
    || ok "誤擋不該吃掉 deny-once 額度"

# 這是本 bug 的核心案例：agent 還在跑（有 PostToolUse、沒有 SubagentStop）
reset; mkdir -p "$SANDBOX/.claude/logs"; am_post_async planner ag001 >/dev/null
expect_contains "派工返回只記 agent_start" "agent_start" "$(ag_events)"
expect_decision "真的 in-flight（未收到 SubagentStop）→ 再派一個要擋" deny "$(ag tdd-guide)"

reset; mkdir -p "$SANDBOX/.claude/logs"
am_post_async planner ag001 >/dev/null; am_stop ag001 planner >/dev/null
expect_decision "收到 SubagentStop 後 → 再派一個放行" allow "$(ag tdd-guide)"

# 實測會收到 agent_type 為空字串的 SubagentStop。不能因此跳過寫入——
# 漏一筆 complete 就讓那個 agent 的 in-flight 永遠不歸零，閘門會從此誤擋每一次委派。
reset; mkdir -p "$SANDBOX/.claude/logs"
am_post_async planner ag002 >/dev/null; am_stop ag002 "" >/dev/null
expect_decision "agent_type 空字串的 SubagentStop 仍能沖銷 in-flight" allow "$(ag tdd-guide)"

# 實測也會收到這個 session 從沒派過的 agent_id
reset; mkdir -p "$SANDBOX/.claude/logs"; am_stop never-dispatched Explore >/dev/null
expect_decision "沒見過的 agent_id 的 SubagentStop → 不爆炸、計數不轉負" allow "$(ag planner)"
reset; mkdir -p "$SANDBOX/.claude/logs"
am_post_async planner ag003 >/dev/null; am_stop never-dispatched Explore >/dev/null
expect_decision "多餘的 complete 不會沖掉別人的 in-flight" deny "$(ag tdd-guide)"

# 同步完成的 agent：PostToolUse 觸發時它已經結束，start/complete 一起寫，淨變化 0
reset; mkdir -p "$SANDBOX/.claude/logs"; am_post_sync Explore tu9 >/dev/null
expect_contains "同步完成同時記 start 與 complete" "agent_start,agent_complete" "$(ag_events)"
expect_decision "同步完成的 agent 不算 in-flight" allow "$(ag planner)"

# 既有行為不能壞：帶隔離的一律放行（有自己的 checkout 與分支）
reset; mkdir -p "$SANDBOX/.claude/logs"; am_post_async planner ag004 >/dev/null
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
