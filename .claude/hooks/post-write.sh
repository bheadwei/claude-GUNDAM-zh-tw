#!/bin/bash
# Post Write Hook — PostToolUse(Write|Edit)
#
# 職責：
#   (1) WBS 寫入歷史（沿用）＋ WBS 格子長度提醒（只提醒，不擋；見下方該節）
#   (2) 文件影響偵測：寫到「文件會描述的檔案」（API 路由、schema、對外介面…）時，
#       記進 .doc-impact 並在本任務第一次命中時注入提醒。
#       /verify 在標記 WBS ✅ 前必須處理這份清單。
#   (3) 前端寫入檢查：寫死色碼、動畫等級不符、AI 痕跡（P0）→ lib/ui-lint.sh（只提醒，不擋）
#
# 為什麼需要 (2)：新需求／客戶 CR 的程式都會寫出來，但文件常常沒跟上。
# 原因是 documentation-specialist 在「任務完成路徑」上完全沒有位置——
# /verify 只驗建置/型別/lint/測試，從不問文件。靠自律記得同步文件是行不通的，
# 所以改成：機器在改動當下就標記，並在任務收尾時擋一次。
#
# 逃生門：DOC_SYNC_GATE=off、UI_LINT=off、或 .suggest-mode 為 off

INPUT=$(cat)

source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-roots.sh" 2>/dev/null || true
if declare -F resolve_roots >/dev/null 2>&1; then
    resolve_roots "$INPUT"
else
    MAIN_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    MAIN_CLAUDE="$MAIN_ROOT/.claude"; WORK_ROOT="$MAIN_ROOT"; WORK_CLAUDE="$MAIN_CLAUDE"; IN_WORKTREE=0
fi

PROJECT_ROOT="$WORK_ROOT"                  # 判斷寫入檔案是否為「文件描述的對象」
CLAUDE_DIR="$MAIN_CLAUDE"                  # log 集中
DATA_DIR="$WORK_CLAUDE/taskmaster-data"    # .doc-impact：每個 worktree 各自累積
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true
FILE_PATH=""
command -v jq >/dev/null 2>&1 && FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# WBS 更新時記錄歷史
# 比對前先把 `\` 轉成 `/`：Windows 的 payload 帶反斜線路徑，原本的字面比對在那裡永遠不中
if [[ "$(printf '%s' "$FILE_PATH" | tr '\\' '/')" == *"taskmaster-data/wbs.md"* ]]; then
    mkdir -p "$DATA_DIR" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WBS updated" >> "$DATA_DIR/wbs-history.log" 2>/dev/null
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] post-write: $FILE_PATH" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true

# ============================================================================
# (2) 文件影響偵測
# ============================================================================
[ -z "$FILE_PATH" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# ---------------------------------------------------------------- hook 語法檢查
#
# 把 hook 改壞的當下**沒有任何人告訴你**，要等下一條指令噴 syntax error 才發現——
# 而「改 hook」在這個 repo 是日常。只出聲，**不擋、不修、不還原、不備份**：
# 壞掉的 hook 本來就得再被編輯才能修好，擋住等於重演「閘門擋下修好它自己的那次編輯」。
#
# 放在 .suggest-mode 之前、擴充提醒之前：這不是建議密度的問題（檔案是真的壞的），
# 而且擴充提醒命中 .claude/hooks/* 之後會 exit，放後面就永遠輪不到。
# 沒壞時完全不出聲，所以常態成本是零。
#
# post-write.sh 自己被改壞時這段不會跑。那無解，**刻意不做自舉保護**。
#
# 逃生門：HOOK_SYNTAX_CHECK=off
if [ "${HOOK_SYNTAX_CHECK:-on}" != "off" ]; then
    case "$(printf '%s' "$FILE_PATH" | tr '\\' '/')" in
        */.claude/hooks/*.sh)
            if [ -f "$FILE_PATH" ] && ! SYN_ERR=$(bash -n "$FILE_PATH" 2>&1); then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] hook syntax error: $FILE_PATH" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
                jq -n --arg f "$FILE_PATH" --arg e "$SYN_ERR" '{
                  hookSpecificOutput: {
                    hookEventName: "PostToolUse",
                    additionalContext: ("🚨 `" + $f + "` 語法錯誤，這支 hook 現在是壞的：\n\n```\n" + $e + "\n```\n\n**先修好再繼續。** 壞掉的 hook 不會報錯，只會安靜地不執行——它負責的注入、閘門、紀錄從這一刻起全部消失，而你要等下一條指令噴錯才會發現。\n（關閉：HOOK_SYNTAX_CHECK=off）")
                  }
                }' 2>/dev/null || true
                exit 0
            fi
            ;;
    esac
fi

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

NORM=$(printf '%s' "$FILE_PATH" | tr '\\' '/')
ROOT_NORM=$(printf '%s' "$PROJECT_ROOT" | tr '\\' '/')
REL="${NORM#"$ROOT_NORM"/}"

# ---------------------------------------------------------------- 前端寫入檢查
#
# 寫死色碼、動畫等級不符、AI 痕跡（P0）。判斷全在 lib/ui-lint.sh（含範圍、出處、取捨）。
# 這裡先算好、不馬上輸出：前端檔也可能同時命中下面的文件影響偵測（例如 `src/components/index.tsx`），
# 而一次 hook 只能輸出一個 JSON，所以由 finish_with 合併成一則。
# 會走到 WBS、擴充維護兩節的都是 `.claude/**`，ui-lint 本來就跳過，不必在那裡合併。
# 只接在 PostToolUse：寫檔失敗時磁碟內容沒變，沒有東西可檢查（理由見 ui-lint.sh 開頭）。
# 逃生門：UI_LINT=off
UI_MSG=""
if [ "${UI_LINT:-on}" != "off" ] && [ -f "$FILE_PATH" ]; then
    UI_MSG=$(bash "$(dirname "${BASH_SOURCE[0]}")/lib/ui-lint.sh" "$FILE_PATH" "$REL" "$WORK_CLAUDE" "$MAIN_CLAUDE" 2>/dev/null || true)
fi

finish_with() { # [文件影響提醒] —— 與 UI_MSG 合併後輸出一則 additionalContext，然後結束
    local msg="${1:-}"
    if [ -n "$UI_MSG" ]; then
        if [ -n "$msg" ]; then msg="$msg"$'\n\n'"$UI_MSG"; else msg="$UI_MSG"; fi
    fi
    if [ -n "$msg" ]; then
        jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}}' 2>/dev/null || true
    fi
    exit 0
}

# ---------------------------------------------------------------- WBS 格子長度提醒
#
# WBS 會悄悄變成工作日誌：狀態／備註格塞進驗證數據、疑慮清單、選型理由、commit SHA，
# 一列撐半個螢幕，打開再也看不出專案狀態。版面規則寫在範本裡，但「寫的當下」沒人看範本——
# 判斷得出時機（寫入 wbs.md）的事就由機器提出。只提醒不擋：擋住會讓「先記下來、等等再搬」
# 也做不到，而那比格子長更糟。
#
# 長度以 codepoint 計（jq 的 length），所以中文一字算一，不受 Git Bash 位元組計數影響。
# 連結只算顯示文字，`](目標)` 不計——長路徑本來就該放在連結裡。
# 每次寫入最多一則訊息。去處對照是範本第 4 節的簡短版，改範本那張表時同步這裡。
#
# 逃生門：WBS_CELL_CHECK=off（門檻 WBS_CELL_MAX，預設 40）
case "$NORM" in
    */taskmaster-data/wbs.md)
        if [ "${WBS_CELL_CHECK:-on}" != "off" ] && [ -f "$NORM" ]; then
            WBS_MSG=$(jq -Rsr --argjson max "${WBS_CELL_MAX:-40}" '
                def cells: gsub("\\\\\\|"; "\u0001")
                  | sub("^\\s*\\|"; "") | sub("\\|\\s*$"; "")
                  | split("|") | map(gsub("\u0001"; "|") | gsub("^\\s+|\\s+$"; ""));
                def visible: gsub("!?\\[(?<t>[^\\]]*)\\]\\([^)]*\\)"; "\(.t)")
                  | gsub("<[a-z]+://[^>]*>"; "")
                  | gsub("\\*\\*|__|`"; "");
                def is_row: test("^\\s*\\|");
                def is_sep: test("^\\s*\\|?(\\s*:?-{3,}:?\\s*\\|)+\\s*(:?-{3,}:?\\s*)?$");
                gsub("\r"; "") as $doc
                | (reduce ($doc | split("\n")[]) as $l
                    ({hdr: [], prev: "", intable: false, hits: []};
                     (if ($l | is_row | not) then .intable = false
                      elif ($l | is_sep) then .intable = true | .hdr = (.prev | cells)
                      elif .intable then
                        .hdr as $h
                        | ($l | cells) as $c
                        | .hits += [ range(0; $c | length) as $i
                                     | ($c[$i] | visible) as $v
                                     | select(($v | length) > $max)
                                     | {id: $c[0], col: ($h[$i] // "第\($i + 1)欄"), len: ($v | length)} ]
                      else . end)
                     | .prev = $l)
                  | .hits) as $hits
                | if ($hits | length) == 0 then empty else
                    "📏 WBS 格子太長：`wbs.md` 有 \($hits | length) 格超過 \($max) 字。WBS 是打開就要能掌握專案狀態的文件，**每格只寫一行**——長內容搬出去，格子裡只留連結或風險 ID。\n\n"
                    + ([$hits[:8][] | "- \(.id) 的「\(.col)」（\(.len) 字）"] | join("\n"))
                    + (if ($hits | length) > 8 then "\n- …另有 \(($hits | length) - 8) 格" else "" end)
                    + "\n\n該搬去哪：驗證數據／執行結果 → 評估報告或 plan 該階段的「驗收」・進度／派工／commit SHA → 執行帳本 `plans/*.progress.md`・帶給下一任務的疑慮 → 下一任務 plan 的「風險與緩解」・選型理由 → `context/decisions/` 或 ADR・阻塞原因 → 「風險與阻塞」表（任務列只寫風險 ID）・任務等級 → plan frontmatter。"
                    + (if ($doc | test("(^|\n)## 現況")) then "" else "\n\n這份 WBS 沒有「現況」區，是舊版面——`/task-status` 會提議整份轉換（長內容搬出、不丟資料）。" end)
                    + "\n\n版面唯一來源：`.claude/templates/wbs.template.md`。（只提醒，不擋。關閉：WBS_CELL_CHECK=off）"
                  end
            ' < "$NORM" 2>/dev/null)
            if [ -n "$WBS_MSG" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] wbs-cell-check: long cells in $REL" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
                jq -n --arg m "$WBS_MSG" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}}' 2>/dev/null || true
            fi
        fi
        exit 0
        ;;
esac

# ---------------------------------------------------------------- 擴充維護提醒
#
# 為什麼是 hook 而不是指令：`/learn`、`/skill-audit` 這類入口都要使用者自己想起來
# 並手動輸入，而「改了 skill 卻沒接線／沒更新 INDEX」的當下使用者不會知道要跑。
# 判斷得出時機的事就該由機器提出——照 writing-extensions 的五層決策表。
#
# 這裡刻意**不跑** check-counts.sh：hook 在這台機器上單次已要 7-9 秒，
# 再加一次全掃會讓每次寫檔都變慢。累積清單就好，skill-curator 自己會跑。
if [ "${SKILL_CURATOR_GATE:-on}" != "off" ]; then
    # 這裡刻意比對絕對路徑 $NORM 而非相對化的 $REL：`.claude/` 本身就是要找的錨點，
    # 而 payload 沒帶 `cwd` 時 PROJECT_ROOT 會解析深一層、讓 REL 掉掉 `.claude/` 前綴。
    # worktree 內的 `.claude/skills/` 也該命中——那是真的在改擴充。
    EXT_BEARING=0
    case "/$NORM" in
        */.claude/skills/*|*/.claude/agents/*|*/.claude/commands/*|*/.claude/rules/*|*/.claude/hooks/*)
            EXT_BEARING=1 ;;
    esac
    # 排除測試與執行時產物，避免跑測試或寫報告時自己觸發自己
    case "/$NORM" in
        */.claude/hooks/tests/*|*/.claude/tests/*|*/.claude/context/*|*/.claude/coordination/*|*/.claude/taskmaster-data/*)
            EXT_BEARING=0 ;;
    esac

    if [ "$EXT_BEARING" -eq 1 ]; then
        mkdir -p "$DATA_DIR" 2>/dev/null || true
        SK_IMPACT="$DATA_DIR/.skill-impact"
        SK_NOTIFIED="$DATA_DIR/.skill-impact-notified"

        grep -qxF "$REL" "$SK_IMPACT" 2>/dev/null || echo "$REL" >> "$SK_IMPACT" 2>/dev/null || true

        if [ ! -f "$SK_NOTIFIED" ]; then
            : > "$SK_NOTIFIED" 2>/dev/null || true
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] skill-impact: $REL" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true
            jq -n --arg f "$REL" '{
              hookSpecificOutput: {
                hookEventName: "PostToolUse",
                additionalContext: ("🧩 擴充維護提醒：你剛改了 `" + $f + "`。\n\n改動 `.claude/` 底下的擴充有三件事會**安靜失效**（不會報錯）：接線沒接上（agent 拿不到 `Skill` 工具，只認完整路徑）、`INDEX.md` 沒同步、description 是內容摘要所以永遠不會被喚起。\n\n變更清單累積在 `.claude/taskmaster-data/.skill-impact`。現在不用停下來，繼續做即可；**收尾時委派 `skill-curator`**（`subagent_type: \"skill-curator\"`）一次處理完並跑 `scripts/check-counts.sh`。\n（本任務只提醒這一次。關閉：SKILL_CURATOR_GATE=off）")
              }
            }' 2>/dev/null || true
            exit 0
        fi
    fi
fi

[ "${DOC_SYNC_GATE:-on}" = "off" ] && finish_with ""

# 先排除：模板自身、依賴、建置產物、文件本身、測試
case "$REL" in
    .claude/*|*/.claude/*) finish_with "" ;;
    docs/*|*/docs/*) finish_with "" ;;
    node_modules/*|*/node_modules/*|.venv/*|*/.venv/*|venv/*|*/venv/*) finish_with "" ;;
    dist/*|*/dist/*|build/*|*/build/*|.next/*|*/.next/*|target/*|*/target/*) finish_with "" ;;
    .git/*|*/.git/*) finish_with "" ;;
    *test*|*spec*|*__tests__*|*fixtures*) finish_with "" ;;
esac

# 文件會描述的檔案 —— 改到這些，文件就有機會過期
DOC_BEARING=0
case "$REL" in
    */api/*|api/*|*/routes/*|routes/*|*/router/*|*/controllers/*|*/handlers/*|*/endpoints/*)
        DOC_BEARING=1 ;;
    *openapi*|*swagger*|*.proto|*.graphql|*schema.*|*/schema/*|*/schemas/*)
        DOC_BEARING=1 ;;
    */migrations/*|*/models/*|*/entities/*|*/dto/*)
        DOC_BEARING=1 ;;
    */index.ts|*/index.js|*/index.tsx|*.d.ts|*/public-api.ts)
        DOC_BEARING=1 ;;
    */cli/*|*/commands/*|.env.example)
        DOC_BEARING=1 ;;
esac
[ "$DOC_BEARING" -eq 0 ] && finish_with ""

mkdir -p "$DATA_DIR" 2>/dev/null || true
IMPACT_FILE="$DATA_DIR/.doc-impact"
NOTIFIED="$DATA_DIR/.doc-impact-notified"

# 去重後累積（/verify 會讀這份清單）
grep -qxF "$REL" "$IMPACT_FILE" 2>/dev/null || echo "$REL" >> "$IMPACT_FILE" 2>/dev/null || true

# 本任務只提醒一次，避免每次寫檔都吵
[ -f "$NOTIFIED" ] && finish_with ""
: > "$NOTIFIED" 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] doc-impact: $REL" >> "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || true

DOC_MSG=$(jq -rn --arg f "$REL" '"📘 文件影響提醒：你剛改了 `" + $f + "`——這類檔案（API／路由／schema／對外介面／CLI）是文件描述的對象，改了文件就可能過期。\n\n本任務的影響清單累積在 `.claude/taskmaster-data/.doc-impact`，**`/verify` 在標記 WBS ✅ 前會擋下來要求處理**（同步文件或明確豁免）。現在不用停下來，繼續實作即可；收尾時委派 `documentation-specialist` 一次處理完。\n（本任務只提醒這一次。關閉：DOC_SYNC_GATE=off）"' 2>/dev/null || true)

finish_with "$DOC_MSG"
