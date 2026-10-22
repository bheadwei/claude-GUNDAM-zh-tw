#!/bin/bash
# User Prompt Submit Hook
#   (1) 偵測 /task-init，確保資料目錄存在（沿用）
#   (2) 意圖路由：依關鍵字注入「建議任務模式 + 建議 agent 鏈」提示，
#       協助主模型更主動委派。純文字 stdout 即會被加入 context（exit 0）。
#
# 受 .suggest-mode 控制：off→不注入、low→僅高訊號(安全/金流)、medium·high→全部。

INPUT=$(cat)

source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$INPUT"
else
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    MAIN_CLAUDE="$MAIN_ROOT/.claude"; WORK_ROOT="$MAIN_ROOT"; WORK_CLAUDE="$MAIN_CLAUDE"; IN_WORKTREE=0
fi

PROJECT_ROOT="$WORK_ROOT"
CLAUDE_DIR="$MAIN_CLAUDE"                  # suggest-mode / wbs.md 偵測 / log 都在主 checkout
WORK_DATA="$WORK_CLAUDE/taskmaster-data"   # 報告期望：每個 worktree 各自
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true
USER_INPUT=""
# UserPromptSubmit 的欄位是 .prompt（舊版誤用 .content）；保留 fallback
command -v jq >/dev/null 2>&1 && USER_INPUT=$(echo "$INPUT" | jq -r '.prompt // .content // .message // ""' 2>/dev/null)

# ============================================================================
# (1) /task-init 偵測
# ============================================================================
if [[ "$USER_INPUT" == *"/task-init"* ]]; then
    mkdir -p "$CLAUDE_DIR/taskmaster-data" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] user-prompt: /task-init detected" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
fi

# ============================================================================
# (2) 意圖路由
# ============================================================================

# 讀 suggest-mode（預設 medium）
SUGGEST_MODE="medium"
SM_FILE="$CLAUDE_DIR/taskmaster-data/.suggest-mode"
if [ -f "$SM_FILE" ]; then
    SUGGEST_MODE=$(tr -d '[:space:]' < "$SM_FILE" 2>/dev/null || echo "medium")
    [ -z "$SUGGEST_MODE" ] && SUGGEST_MODE="medium"
fi
[ "$SUGGEST_MODE" = "off" ] && exit 0

# 延後式報告稽核
#
# 刻意放在斜線指令判斷「之前」：非同步 agent 到這個對話邊界通常已跑完，
# 而使用者下一句常常正是 /verify 或 /task-next——那時最需要知道報告缺了沒。
# post-agent-report.sh 也會呼叫同一支腳本，覆蓋「agent 連續接力」的情形。
REPORT_AUDIT_MSG=$(bash "$(dirname "${BASH_SOURCE[0]}")/lib/check-report-expectations.sh" "$WORK_CLAUDE" "$MAIN_CLAUDE" 2>/dev/null || echo "")

# pending handoff 注入（與 post-agent-report.sh 同一份 lib、同格式、同上限）。
# 為什麼這裡也要：Agent 是非同步的，agent 建的 handoff 在它自己那次 PostToolUse 時還不存在，
# 只接 PostToolUse(Agent) 的話要等**下一次**派工才看得到——而這個提示本來就是要觸發
# 下一次派工。非同步 agent 交回時 harness 會送一則訊息進來，這裡就是接力的時點。
# 只在有 pending 時輸出；交接已在主 checkout 共享（coordination/）。
HANDOFF_MSG=""
source "$(dirname "${BASH_SOURCE[0]}")/lib/handoff-scan.sh" 2>/dev/null || true
if declare -F handoff_pending_message >/dev/null 2>&1; then
    HANDOFF_MSG=$(handoff_pending_message "$MAIN_CLAUDE/coordination/handoffs" "$SUGGEST_MODE")
fi
# 既成事實（報告稽核、待接手的交接）——不受「是不是斜線指令／agent 交回」影響，一律送達
emit_facts() {
    local first=1
    if [ -n "$HANDOFF_MSG" ]; then echo "$HANDOFF_MSG"; first=0; fi
    if [ -n "$REPORT_AUDIT_MSG" ]; then [ "$first" -eq 0 ] && echo; echo "$REPORT_AUDIT_MSG"; fi
    return 0
}

# 斜線指令不做意圖路由（使用者已明確指定流程），但稽核結果仍要送達
case "$USER_INPUT" in
    /*)
        emit_facts
        exit 0
        ;;
esac

# subagent 交回的報告不是使用者提問，不做意圖路由
#
# 非同步 subagent 結束時，harness 把它的報告當成一則 user 訊息送進來，
# UserPromptSubmit 照樣觸發。報告裡滿是「認證」「部署」「測試」這類字，
# 於是每次 agent 交回都被注入一串跟使用者意圖無關的建議（實測：skill-curator
# 的回報 → 「偵測到認證/金流 → critical」）。
#
# 實測的訊息開頭（2026-09-17 transcript，hook 的 attachment 緊接在這則訊息之後）：
#   Another Claude session sent a message:
#   <agent-message from="a0cf...">
#   [Subagent hand-back] The text below is the final report of a subagent ...
# 背景工作完成通知則是 <task-notification> 開頭。
# 只看開頭三行：報告「內文」引用到這些字，不該讓真正的使用者提問被略過。
# 報告稽核照樣送達——agent 剛交回時正是最該知道報告缺了沒的時候。
HEAD_LINES=$(printf '%s\n' "$USER_INPUT" | head -n 3)
case "$HEAD_LINES" in
    *'<agent-message from='*|*'[Subagent hand-back]'*|'<task-notification>'*)
        emit_facts
        exit 0
        ;;
esac

# 小工具：關鍵字命中判斷（大小寫不敏感；中文以位元組比對）
has() { echo "$USER_INPUT" | grep -iqE "$1"; }

HINTS=""
add() { HINTS="${HINTS}
  - $1"; }

HIGH_SIGNAL=0  # 安全/金流等高訊號，low 模式也會顯示

# --- 高訊號：安全 / 金流 / 認證 ---
#
# 認證分兩級。`login`／`session`／`登入` 這類字常出現在純 UI 或文案的需求裡
# （「改 login 頁的按鈕顏色」「session 逾時的提示文字」），單獨出現就建議 critical
# 會把一堆小改動推成「覆蓋率門檻最嚴＋必須 /plan」。所以：
#   強訊號（單獨成立）：認證／授權邏輯本身才會出現的字
#   弱訊號：要再搭配「邏輯」類的字才成立
#
# 2026-10-20 複查的三個誤判（都會被推成「critical＋必須 /plan」）：
#   - `permission` 曾在強訊號：「settings 的 permission 怎麼設」講的是 Claude Code 權限設定
#     → 移到弱訊號，要搭配邏輯字才成立
#   - 裸 `token` 曾在邏輯字：「session 的 token 用量」（session 弱訊號＋token）→ critical。
#     在這個模板裡 token 多半是 LLM 的 token；認證語境的 token 幾乎總帶著別的字
#     （refresh／過期／驗證／jwt），所以只留 `access token`／`bearer`
#   - 金流的 `checkout` 會命中 `git checkout`（「git checkout 回 main」）→ 比對前先拿掉
AUTH_STRONG='oauth|jwt|password|passwd|credential|rbac|authoriz|authenticat|認證|授權|密碼|權限|憑證'
AUTH_WEAK='login|logout|signin|sign-in|session|auth|permission|登入|登出|會員'
AUTH_LOGIC='驗證|邏輯|檢查|判斷|access.?token|bearer|cookie|hash|加密|過期|expire|refresh|middleware|guard|verify|validat'
PAY_INPUT=$(printf '%s' "$USER_INPUT" | sed -E 's/git[[:space:]]+checkout//gI' 2>/dev/null) || PAY_INPUT="$USER_INPUT"
if has "$AUTH_STRONG" \
   || { has "$AUTH_WEAK" && has "$AUTH_LOGIC"; } \
   || printf '%s\n' "$PAY_INPUT" | grep -iqE 'payment|billing|stripe|checkout|金流|支付|付款|帳務'; then
    HIGH_SIGNAL=1
    add "偵測到認證/授權邏輯或金流 → 建議任務模式 **critical**；critical 一律需要 /plan（見 plan-format skill），實作後啟動 security-infrastructure-auditor，覆蓋率門檻見 testing-standards skill。"
fi

# --- migration / schema ---
# 兩段式：窄關鍵字升級 critical；廣關鍵字（使用者沒說「migration」的情境）只提示載入 skill，
# 不誤升 critical——「加欄位」也可能是前端表格欄位。
if has 'migration|migrate|資料庫遷移|schema 變更|遷移'; then
    HIGH_SIGNAL=1
    add "偵測到資料庫遷移 → 建議 **critical**；先 /plan，務必含回滾策略與資料備份。**先載入 \`database-migrations\` skill**（zero-downtime DDL、expand/contract、不停機建索引、分批 backfill）。"
elif has 'alter table|create index|drop column|add column|backfill|加欄位|新增欄位|移除欄位|刪除欄位|重命名欄位|改資料型別|資料回填|改 schema'; then
    add "偵測到 schema／欄位變更（未出現「migration」字樣）→ **先載入 \`database-migrations\` skill**，確認 zero-downtime 作法與回滾；若動的是線上資料，升級為 **critical**。"
fi

# 以下為一般訊號（low 模式略過）
if [ "$SUGGEST_MODE" != "low" ]; then
    if has 'deploy|部署|發布|上線|ci/cd|docker|kubernetes|k8s|rollback|回滾'; then
        add "偵測到部署/維運 → **委派 deployment-expert**（\`subagent_type: \"deployment-expert\"\`）。先過 security 閘門。"
    fi
    if has 'refactor|重構|dead code|死碼|cleanup|清理|整併'; then
        add "偵測到重構/清理 → **委派 refactor-cleaner**（\`subagent_type: \"refactor-cleaner\"\`），分批移除、每批測試+commit。"
    fi
    if has 'build error|compile|編譯錯誤|型別錯誤|tsc|建置失敗|build failed'; then
        add "偵測到建置/型別錯誤 → **委派 build-error-resolver**（\`subagent_type: \"build-error-resolver\"\`），最小差異修復。"
    fi
    # 執行期 bug —— 與上面的建置錯誤分流：這裡是「跑起來行為不對」
    if has '壞了|不動了|沒反應|不work|不 work|怪怪的|為什麼會|怎麼會|異常|出錯|報錯|失敗了' \
       || has '(^|[^a-z])bugs?([^a-z]|$)|broken|not working|unexpected|crash|當掉|閃退|卡住|重現'; then
        add "偵測到執行期 bug → **委派 debug-investigator**（\`subagent_type: \"debug-investigator\"\`）。它強制先穩定重現 → 二分縮小 → 可證偽假設 → 寫重現測試才動手修，並且會先讀 \`context/learned/\` 確認這個坑踩過沒有。建置/型別錯誤請改用 build-error-resolver。"
    fi
    # 文件維護 —— 這條以前不存在，是 documentation-specialist 與
    # workflow-template-manager 從未被啟動過的直接原因（agent-activity.jsonl 可查）
    if has '文件|文檔|docs|documentation|readme|codemap|api 文件|api 文檔|註解文件|技術文件' \
       || has '整理.{0,10}(文件|文檔|docs)|更新.{0,10}(文件|文檔|docs|readme)|同步.{0,10}(文件|文檔|docs)'; then
        if has 'prd|adr|架構文檔|設計文檔|規格書|流程模板'; then
            add "偵測到流程性文件（PRD/ADR/設計文檔）→ **委派 workflow-template-manager**（\`subagent_type: \"workflow-template-manager\"\`）。"
        else
            add "偵測到文件維護 → **委派 documentation-specialist**（\`subagent_type: \"documentation-specialist\"\`），它會從程式碼反推 codemap／API 文檔／技術 README。不要自己一個一個檔案改。"
        fi
    fi
    # `ui`／`css` 前後不能是英文字母：裸子字串會命中 quick、build、guide、suite、access，
    # 把一堆跟前端無關的提問也導去載入 ui-style-compliance。
    # 反過來，使用者說「做個官網」「這個形象頁」時從不講 UI 或前端，所以要列出網站類的說法。
    if has '(^|[^a-z])(ui|css)([^a-z]|$)|前端|頁面|畫面|component|元件|tailwind|pencil|設計稿' \
       || has '網站|官網|landing|形象頁|一頁式|首頁|版型|配色|字型'; then
        add "偵測到前端 UI/設計稿 → **先載入 \`ui-style-compliance\` skill**（風格三階段檢查已從常駐 rules 移出）；可用 /ui-page 或委派 ui-builder。"
    fi
    if has 'npm|pnpm|bun|yarn|package\.json|node_modules|lockfile|套件安裝'; then
        add "偵測到 Node 套件操作 → **先載入 \`node-package-manager\` skill**，讀 package-manager.json 決定用哪個 PM，勿自選。"
    fi
    # pip／uv／test／bug 加單字邊界，寫法同上面的 ui|css：裸子字串會命中
    # pipeline、latest、debug（「debug 模式」被導去 debug-investigator），
    # 而 `uv ` 舊寫法要求後面接空白，句尾的 uv 反而接不到。test 只錨左邊：tests、testing 仍要命中。
    if has '(^|[^a-z])(pip3?|uv)([^a-z]|$)|poetry|virtualenv|venv|pyproject|requirements\.txt'; then
        add "偵測到 Python 環境操作 → **先載入 \`python-uv\` skill**（一律 uv，禁 pip/poetry）。"
    fi
    if has '(^|[^a-z])test|測試|coverage|覆蓋率|pytest|jest|vitest'; then
        add "偵測到測試相關 → **先載入 \`testing-standards\` skill** 當前任務模式的覆蓋率門檻（quick 免檢）、只跑相關的測試檔、輸出只回摘要。"
    fi
    # 新增功能 → 提醒先補 WBS 那一行，否則 plan 會被迫兼差當 backlog
    #
    # 匹配策略：強動詞（新增/實作/做一個…）單獨成立；弱動詞（支援/想要…）需搭配名詞。
    # 舊規則要求「加」與「功能」字面相鄰，但真實需求會把功能名夾在中間
    # （「加一個匯出 CSV 的功能」），因此漏掉大多數實際開口方式。
    # 第二個條件排除 bug 回報與疑問句，避免與 debug-investigator 那條重複觸發。
    if [ -f "$CLAUDE_DIR/taskmaster-data/wbs.md" ] \
       && has '(新增|實作|實現|開發|加一個|加個|加上|做一個|做個|追加|建一個|建個)|(支援|要有|想要|需要).{0,45}(功能|頁面|模組|元件|API|端點|介面|服務|系統|報表|流程|機制)|新功能|擴充功能|下一階段|第二階段|還想做' \
       && ! has '壞了|不動|沒反應|報錯|出錯|失敗了|為什麼|怎麼|如何|是什麼|(^|[^a-z])bugs?([^a-z]|$)|broken|crash'; then
        add "偵測到新功能需求／CR → ①先用 **/task-add** 追加進 WBS（自動拆解、接編號、算依賴、重算現況）②達 /plan 門檻（唯一來源：plan-format skill「何時不該用 /plan」）就**委派 planner**（\`subagent_type: \"planner\"\`）產分階段藍圖。跳過 WBS 會讓進度與時間統計失真。**若這筆會動到 API／路由／schema／對外介面，任務結束前必須同步文件**——/verify 會擋。"
    fi
    if has 'pull request|開 pr|發 pr|送審|merge request|合併請求'; then
        add "偵測到要開 PR → 用 **/pr**（分析完整 commit 歷史與 \`diff base...HEAD\`、可選先跑把關鏈、產出含測試計畫的內容）。"
    fi
    if has '升級套件|更新依賴|依賴升級|過期套件|outdated|npm audit|漏洞修復|dependabot|套件更新'; then
        add "偵測到依賴維護 → 用 **/deps**（依風險分批：安全 → patch → minor → major，每批測試後才 commit；major 一次一個並先讀遷移指南）。"
    fi
    if has '要用哪個|選哪個|該用|哪個比較好|A 還是 B|決定用|技術選型|取捨|trade-?off'; then
        add "偵測到技術選型 → 影響跨模組或難以回頭的決策，**委派 architect**（\`subagent_type: \"architect\"\`）做評估並產 ADR；單點選型則直接用 **/adr** 記錄「為什麼選 A 不選 B」，含被否決的方案。否則下個 session 會重新爭論已經決定過的事。"
    fi
fi

# low 模式且非高訊號 → 只剩報告稽核（那是既成事實，不是建議）
if [ "$SUGGEST_MODE" = "low" ] && [ "$HIGH_SIGNAL" -eq 0 ]; then
    HINTS=""
fi

if [ -n "$HINTS" ]; then
    echo "🎯 意圖路由（依關鍵字命中；委派前先用一句話宣告理由，使用者可當場否決。密度調整：/suggest-mode）：${HINTS}"
fi

if [ -n "$HANDOFF_MSG" ] || [ -n "$REPORT_AUDIT_MSG" ]; then
    [ -n "$HINTS" ] && echo
    emit_facts
fi

exit 0
