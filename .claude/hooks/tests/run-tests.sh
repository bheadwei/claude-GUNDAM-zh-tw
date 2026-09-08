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
