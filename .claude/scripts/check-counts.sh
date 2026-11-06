#!/usr/bin/env bash
# check-counts.sh — 文件裡的計數 vs 檔案系統實況
#
# 為什麼需要：這個模板的文件在四個地方重複寫著同樣的計數
# （README.md、.claude/README.md、guides/WORKFLOW.md、skills/INDEX.md）。
# 每次新增 agent／skill／command 都要同步四處，人一定會漏。
# 開發過程中已實際發生過六次 drift（測試 56→83→99→127→137、
# skills 12→13→14→15、commands 25→28→29）——那是完全可以自動化的檢查。
#
# 用法：
#   bash .claude/scripts/check-counts.sh              # 只檢查靜態計數
#   bash .claude/scripts/check-counts.sh --tests 137  # 連測試案例數一起檢查
#
# 退出碼：0 = 一致，1 = 有 drift（可直接掛 CI）

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

TESTS_ACTUAL=""
while [ $# -gt 0 ]; do
    case "$1" in
        --tests) TESTS_ACTUAL="${2:-}"; shift 2 ;;
        *) echo "未知選項: $1" >&2; exit 1 ;;
    esac
done

FAIL=0
CHECKED=0

red()   { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
dim()   { printf '\033[90m%s\033[0m' "$1"; }

# verify <說明> <期望值> <檔案> <ERE，需含一個擷取數字的群組>
verify() {
    local label="$1" want="$2" file="$3" re="$4"
    [ -f "$file" ] || return 0

    # 排除版本記錄表：`| v5.3 | ... 63 案例回歸測試 ...` 是歷史事實，
    # 不該被當成 drift（開發時真的誤改過一次 v5.3 那列）
    local hits found=0
    hits=$(grep -vE '^\| v[0-9]+\.[0-9]+ \|' "$file" 2>/dev/null            | grep -oE "$re" 2>/dev/null) || true
    [ -n "$hits" ] || return 0

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        local got
        got=$(printf '%s' "$line" | grep -oE '[0-9]+' | head -1)
        [ -n "$got" ] || continue
        found=1
        CHECKED=$((CHECKED + 1))
        if [ "$got" != "$want" ]; then
            FAIL=$((FAIL + 1))
            printf '  %s %s\n      %s\n      文件寫 %s，實際 %s\n' \
                "$(red '✗')" "$label" "$(dim "$file: $line")" "$got" "$want"
        fi
    done <<< "$hits"

    return 0
}

# ---------------------------------------------------------------- 實際計數

N_AGENTS=$(find .claude/agents -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
N_SKILLS=$(find .claude/skills -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
N_CMDS=$(find .claude/commands -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
N_RULES=$(find .claude/rules -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
# hook 腳本：watch-agents.sh 是 /agent-log 的輔助工具，不是 hook，不計入
N_HOOKS=$(find .claude/hooks -maxdepth 1 -name '*.sh' ! -name 'watch-agents.sh' 2>/dev/null | wc -l | tr -d ' ')
# project-docs 的文件範本：INDEX.md 本身不算範本（曾經有兩處寫 21，就是把 INDEX 算進去了）；
# 12、17 是 /ui-site 的 UI 鏈，不算文件體系（ADR-2026-11-05-004）
N_DOCTPL=$(find .claude/skills/project-docs/templates -maxdepth 1 -name '*.md' ! -name 'INDEX.md' ! -name '12_*' ! -name '17_*' 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "檔案系統實況"
N_UI=$(find .claude/ui -mindepth 1 -maxdepth 1 -type d ! -name '_*' 2>/dev/null | wc -l | tr -d ' ')
printf '  agents %-4s skills %-4s commands %-4s rules %-4s hooks %-4s UI 風格 %-4s 文件範本 %s
' \
    "$N_AGENTS" "$N_SKILLS" "$N_CMDS" "$N_RULES" "$N_HOOKS" "$N_UI" "$N_DOCTPL"
echo ""
echo "比對文件"

# ---------------------------------------------------------------- 比對

for f in README.md .claude/README.md; do
    verify "目錄樹 agents"   "$N_AGENTS" "$f" 'agents/ *\( *[0-9]+ 個\)'
    verify "目錄樹 skills"   "$N_SKILLS" "$f" 'skills/ *\( *[0-9]+ 個\)'
    verify "目錄樹 commands" "$N_CMDS"   "$f" 'commands/ *\( *[0-9]+ 個\)'
    verify "目錄樹 rules"    "$N_RULES"  "$f" 'rules/ *\( *[0-9]+ 個\)'
    verify "章節標題 Agent"  "$N_AGENTS" "$f" '## Agents?（[0-9]+ 個'
    verify "章節標題 Skills" "$N_SKILLS" "$f" '## Skills（[0-9]+ 個'
    verify "章節標題 Rules"  "$N_RULES"  "$f" '## Rules（[0-9]+ 個'
done

verify "指令速查標題"        "$N_CMDS"   README.md '指令速查（[0-9]+ 個）'

W=.claude/guides/WORKFLOW.md
verify "五層表 Hooks"        "$N_HOOKS"  "$W" '\*\*Hooks\*\* \| [0-9]+ '
verify "五層表 Rules"        "$N_RULES"  "$W" '\*\*Rules\*\* \| [0-9]+ '
verify "五層表 Skills"       "$N_SKILLS" "$W" '\*\*Skills\*\* \| [0-9]+ '
verify "五層表 Commands"     "$N_CMDS"   "$W" '\*\*Commands\*\* \| [0-9]+ '
verify "五層表 Agents"       "$N_AGENTS" "$W" '\*\*Agents\*\* \| [0-9]+ '

verify "INDEX 開頭 skill 數" "$N_SKILLS" .claude/skills/INDEX.md '^[0-9]+ 個 skill'

# 文件範本數（六處寫過這個數字，曾漂走兩處）
verify "範本數 project-docs skill" "$N_DOCTPL" .claude/skills/project-docs/SKILL.md '[0-9]+ 種文件範本|[0-9]+ 種範本'
verify "範本數 skills/INDEX"       "$N_DOCTPL" .claude/skills/INDEX.md '[0-9]+ 種範本自帶'
verify "範本數 README skill 表"    "$N_DOCTPL" README.md '[0-9]+ 份範本自帶'
verify "範本數 README 章節標題"    "$N_DOCTPL" README.md '專案文件範本（[0-9]+ 份）'
verify "範本數 templates/INDEX"    "$N_DOCTPL" .claude/skills/project-docs/templates/INDEX.md '模板清單（[0-9]+ 份'

# 淘汰範本的檔名不得殘留
#
# 為什麼：13 份範本已刪（ADR-2026-11-05-004）。指令或 agent 還寫著舊檔名，模型會去讀不存在的檔、
# 或照舊流程產出已淘汰的文件，都不報錯。12、17 是 /ui-site 的 UI 鏈，不在名單裡。
# workflow-template-manager.md 暫時例外：它退場時整檔刪除（文件計畫階段 5），屆時拿掉這個 --exclude。
RETIRED_TPL='01_workflow_manual|03_behavior_driven_development_guide|06_api_design_specification|07_module_specification_and_tests|08_project_structure_guide|09_design_and_dependencies|11_code_review_and_refactoring_guide|13_security_and_readiness_checklists|15_documentation_and_maintenance_guide|16_wbs_development_plan_template|18_data_model_and_migration_spec|19_observability_and_slo_spec|21_ai_llm_integration_spec'
CHECKED=$((CHECKED + 1))
RESIDUE=$(grep -rnoE --exclude=check-counts.sh --exclude=workflow-template-manager.md "$RETIRED_TPL" \
    .claude/agents .claude/commands .claude/rules .claude/skills .claude/guides .claude/hooks \
    .claude/scripts .claude/templates .claude/README.md README.md 2>/dev/null || true)
if [ -n "$RESIDUE" ]; then
    FAIL=$((FAIL + 1))
    printf '  %s 引用了已淘汰的文件範本：\n' "$(red '✗')"
    while IFS= read -r rl; do
        [ -n "$rl" ] || continue
        printf '      %s\n' "$(dim "$rl")"
    done <<< "$RESIDUE"
    printf '      改成指向 .claude/skills/project-docs/SKILL.md（6 份文件與淘汰範本的去處）\n'
fi

# 每個 skill 目錄都要有 SKILL.md，且要在 INDEX 裡被提到
for d in .claude/skills/*/; do
    name=$(basename "$d")
    if [ ! -f "$d/SKILL.md" ]; then
        FAIL=$((FAIL + 1))
        printf '  %s skill 缺 SKILL.md：%s\n' "$(red '✗')" "$name"
    fi
    CHECKED=$((CHECKED + 1))
    if ! grep -q "$name" .claude/skills/INDEX.md 2>/dev/null; then
        FAIL=$((FAIL + 1))
        printf '  %s skill 未列入 INDEX.md：%s（沒人知道它存在）\n' "$(red '✗')" "$name"
    fi
done

# 每個 agent 都要有 model 欄
for f in .claude/agents/*.md; do
    CHECKED=$((CHECKED + 1))
    if ! grep -qE '^model: (haiku|sonnet|opus|fable)$' "$f" 2>/dev/null; then
        FAIL=$((FAIL + 1))
        printf '  %s agent 的 model 欄缺失或不是合法別名：%s\n' "$(red '✗')" "$(basename "$f")"
    fi
done

# agent 的 tools: 不得出現 "Skill"
#
# 實測：限縮的 tools 白名單不認 `Skill`，未知項被**靜默丟掉**而非報錯。
# 加了它會做出「看起來完全正確、實際一個字都不載入」的東西，且沒有任何訊號。
# 完整紀錄：.claude/context/learned/2026-09-08-subagent-no-skill-tool.md
#
# 為什麼這條檢查必須在這裡而不是坑閘門：pre-tool-use.sh 對 `.claude/*` 直接放行
# （避免自鎖），且只對程式碼副檔名生效——`.md` 不在其中。所以關於模板自身擴充的
# 教訓，坑閘門一輩子貼不出來，只能靠這個腳本擋。
for f in .claude/agents/*.md; do
    CHECKED=$((CHECKED + 1))
    if grep -qE '^tools:.*"Skill"' "$f" 2>/dev/null; then
        FAIL=$((FAIL + 1))
        printf '  %s agent 的 tools: 含 "Skill"：%s\n' "$(red '✗')" "$(basename "$f")"
        printf '      subagent 拿不到 Skill 工具，寫進限縮清單會被靜默丟掉（不報錯）。\n'
        printf '      改法：在該 agent 開頭寫「必讀規範：.claude/skills/<name>/SKILL.md」（完整路徑）。\n'
    fi
done

# agent → skill 接線：引用的路徑必須存在
#
# 為什麼這是真的相依而非註解：subagent **拿不到 `Skill` 工具**——把 "Skill" 寫進
# 限縮的 `tools:` 會被靜默丟掉（實測過，不報錯）。agent 取得 skill 內容的唯一途徑
# 是自己的定義給它一個可 Read 的路徑。路徑寫錯不會有任何訊號。
for f in .claude/agents/*.md .claude/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    refs=$(grep -ohE '\.claude/skills/[a-z0-9-]+/SKILL\.md' "$f" 2>/dev/null | sort -u)
    [ -n "$refs" ] || continue
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        CHECKED=$((CHECKED + 1))
        if [ ! -f "$ref" ]; then
            FAIL=$((FAIL + 1))
            printf '  %s 引用了不存在的 skill 路徑：%s → %s\n' \
                "$(red '✗')" "$(basename "$f")" "$ref"
        fi
    done <<< "$refs"
done

# 壓力測試的 code grader 不得殘留硬編碼的 agent 名單
#
# 為什麼：run-compliance.sh 的 grader 用 grep 比對「這一輪點名了哪些 agent」。
# 那份名單寫死過一次就漂開過一次——v5.6 新增兩個 agent 時它沒跟著改，
# grader 對它們一律印「（無）」，判讀會被誤導成「模型根本沒委派」。
# 判準：同一行出現 ≥2 個 agent 名稱＝寫死的 alternation。
RC=.claude/tests/skill-compliance/run-compliance.sh
if [ -f "$RC" ]; then
    CHECKED=$((CHECKED + 1))
    if ! grep -q '\.claude/agents' "$RC"; then
        FAIL=$((FAIL + 1))
        printf '  %s 壓力測試 grader 沒有從 .claude/agents/ 取名單：%s\n' "$(red '✗')" "$RC"
        printf '      改法：AGENT_RE 用 find .claude/agents 的 basename 動態產生，\n'
        printf '      並在名單為空時 fallback 成不可能匹配的樣式。\n'
    fi

    CHECKED=$((CHECKED + 1))
    HARDCODED=$(find .claude/agents -maxdepth 1 -name '*.md' 2>/dev/null \
        | sed 's#.*/##; s#\.md$##' \
        | awk 'NR==FNR { names[FNR]=$0; n=FNR; next }
               { c = 0
                 for (i = 1; i <= n; i++) if (index($0, names[i])) c++
                 if (c >= 2) printf "%d: %s\n", FNR, $0 }' - "$RC")
    if [ -n "$HARDCODED" ]; then
        FAIL=$((FAIL + 1))
        printf '  %s 壓力測試 grader 殘留硬編碼 agent 名單：%s\n' "$(red '✗')" "$RC"
        while IFS= read -r hl; do
            [ -n "$hl" ] || continue
            printf '      %s\n' "$(dim "$hl")"
        done <<< "$HARDCODED"
        printf '      同一行有 ≥2 個 agent 名稱＝寫死的清單，下次新增 agent 必漂且無訊號。\n'
        printf '      改法：改成從 .claude/agents/ 動態產生（見該檔的 AGENT_RE）。\n'
    fi
fi

# UI 風格：每個 .claude/ui/<name>/ 都要有 DESIGN.md、SOURCE.json，要被 CATALOG.md 列到，
# 而且 DESIGN.md 抽得到配色與字型段落
#
# 為什麼：`/ui-style` 只從 CATALOG.md 挑選。目錄建了卻沒進 CATALOG，
# 那個風格就永遠選不到——跟孤兒 skill 一樣，不會報錯。
# SOURCE.json 是同步腳本判斷「上游有沒有更新、本地有沒有改過」的依據，缺了就無從比對。
# 配色／字型段落：mixed 模式照段落標題抽內容，標題對不上時抽到空的也不會報錯。
#
# 段落標題別名的唯一來源是 `ui-style-compliance` 1.2 節的 mixed 對照表。
# 這裡只複製其中「配色」「字型」兩列；改那張表時要同步下面兩個樣式。
# 比對時忽略標題前的編號（`## 2. Color Palette & Roles` 與 `## Colors` 都算）。
UI_COLOR_RE='^##[[:space:]]+([0-9]+\.[[:space:]]*)?(Color Palette & Roles|Colors)[[:space:]]*$'
UI_TYPO_RE='^##[[:space:]]+([0-9]+\.[[:space:]]*)?(Typography Rules|Typography)[[:space:]]*$'
if [ -d .claude/ui ]; then
    for d in .claude/ui/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        # `_` 前綴＝不是風格（`_project` 是反推出來的、`_licenses` 是授權原文），整個跳過
        case "$name" in _*) continue ;; esac
        CHECKED=$((CHECKED + 1))
        if [ ! -f "$d/DESIGN.md" ]; then
            FAIL=$((FAIL + 1))
            printf '  %s UI 風格缺 DESIGN.md：%s\n' "$(red '✗')" "$name"
        else
            CHECKED=$((CHECKED + 1))
            if ! grep -qE "$UI_COLOR_RE" "$d/DESIGN.md" 2>/dev/null; then
                FAIL=$((FAIL + 1))
                printf '  %s UI 風格找不到配色段落：%s（mixed 模式抽不到 color）\n' "$(red '✗')" "$name"
            fi
            CHECKED=$((CHECKED + 1))
            if ! grep -qE "$UI_TYPO_RE" "$d/DESIGN.md" 2>/dev/null; then
                FAIL=$((FAIL + 1))
                printf '  %s UI 風格找不到字型段落：%s（mixed 模式抽不到 typography）\n' "$(red '✗')" "$name"
            fi
        fi
        CHECKED=$((CHECKED + 1))
        if [ ! -f "$d/SOURCE.json" ]; then
            FAIL=$((FAIL + 1))
            printf '  %s UI 風格缺 SOURCE.json：%s（同步腳本無從判斷來源與本地修改）\n' "$(red '✗')" "$name"
        fi
        CHECKED=$((CHECKED + 1))
        if ! grep -qF "$name" .claude/ui/CATALOG.md 2>/dev/null; then
            FAIL=$((FAIL + 1))
            printf '  %s UI 風格未列入 CATALOG.md：%s（/ui-style 選不到它）\n' "$(red '✗')" "$name"
        fi
    done
fi

# 每個 skill 要嘛被 agent 引用，要嘛在「僅主模型使用」白名單裡
#
# 白名單不是豁免，是宣告：這些由主模型載入，agent 不該讀
# （`using-taskmaster` 甚至帶 <SUBAGENT-STOP>）。新增 skill 時必須二選一，
# 否則它會變成沒有任何召喚路徑的孤兒。
MAIN_MODEL_ONLY="using-taskmaster subagent-execution worktree-orchestration writing-extensions spec-convergence deep-research plan-format mcp-builder cost-aware-llm-pipeline"
for d in .claude/skills/*/; do
    name=$(basename "$d")
    CHECKED=$((CHECKED + 1))
    grep -qE "skills/$name/SKILL\.md" .claude/agents/*.md 2>/dev/null && continue
    case " $MAIN_MODEL_ONLY " in
        *" $name "*) continue ;;
    esac
    FAIL=$((FAIL + 1))
    printf '  %s skill 沒有召喚路徑：%s\n' "$(red '✗')" "$name"
    printf '      沒有任何 agent 引用它，也不在 MAIN_MODEL_ONLY 白名單裡。\n'
    printf '      修法：在相關 agent 加「必讀規範：.claude/skills/%s/SKILL.md」，\n' "$name"
    printf '      或（若它本來就只給主模型用）把它加進本腳本的白名單。\n'
done

# 短命旗標不該進版控
#
# 判準：`taskmaster-data/` 底下 `.` 開頭的檔案都是 hook 寫的
# 「單一 session／單一 worktree 私有」旗標（`.current-task-mode`、`.ui-catalog-refreshed` …）。
# 被 git 追蹤會有兩個後果：hook 每次寫入就讓工作區莫名變髒；而且它會被
# copy-template 帶到新專案，讓「超過 N 天沒更新」這類判斷從模板作者的日期起算。
# 實際發生過：`.ui-catalog-refreshed` 漏在 .gitignore 的清單外，被 commit 進版控。
if git rev-parse --git-dir >/dev/null 2>&1; then
    CHECKED=$((CHECKED + 1))
    STRAY=$(git ls-files .claude/taskmaster-data/ 2>/dev/null | awk -F/ '$NF ~ /^\./ { print }')
    if [ -n "$STRAY" ]; then
        FAIL=$((FAIL + 1))
        printf '  %s 短命旗標被 git 追蹤：\n' "$(red '✗')"
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            printf '      %s\n' "$(dim "$f")"
        done <<< "$STRAY"
        printf '      修法：加進 .gitignore 的「執行時短命狀態」清單，\n'
        printf '      再跑 git rm --cached <檔案>（只 --cached，不要刪本地檔）。\n'
    fi
fi

WBST=.claude/templates/wbs.template.md
if [ -f "$WBST" ]; then
    CHECKED=$((CHECKED + 1))
    BAD_HDR=$(grep -nE '^\| # \| 任務 \|' "$WBST" | grep -v '| 模組 |' || true)
    if [ -z "$(grep -E '^\| # \| 任務 \|' "$WBST")" ] || [ -n "$BAD_HDR" ]; then
        FAIL=$((FAIL + 1))
        printf '  %s wbs.template.md 的任務表頭缺「模組」欄：\n' "$(red '✗')"
        printf '      %s\n' "$(dim "${BAD_HDR:-找不到任務表頭}")"
    fi
    CHECKED=$((CHECKED + 1))
    if ! awk '/^## 2\./{s=1; next} s && /^## /{exit} s && /^\| 模組 \|/{f=1} END{exit !f}' "$WBST"; then
        FAIL=$((FAIL + 1))
        printf '  %s wbs.template.md 第 2 節欄位規則缺「模組」列\n' "$(red '✗')"
    fi
fi

# 專案圖解產生器的欄名常數 vs 範本表頭
#
# 為什麼：overview.sh 依欄名抽 WBS 任務表與 plan 部件表。範本改了欄名、常數沒跟上，
# 地圖會靜默變空白（不報錯）——跟孤兒 skill 同類的安靜失效，只有這裡擋得住。
OVSH=.claude/scripts/overview.sh
if [ -f "$OVSH" ]; then
    cols_of() { printf '%s\n' "$1" | tr '|' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$'; }
    ov_const() { sed -n "s/^$1=\"\([^\"]*\)\".*/\1/p" "$OVSH" | head -1; }
    WBS_COLS=$(cols_of "$(grep -m1 -E '^\| # \| 任務 \|' "$WBST" 2>/dev/null)")
    PART_COLS=$(cols_of "$(grep -m1 -E '^\| id \| 部件 \|' .claude/skills/plan-format/SKILL.md 2>/dev/null)")
    for pair in OVERVIEW_COLS_WBS:WBS OVERVIEW_COL_WBS:WBS OVERVIEW_COLS_PART:PART; do
        name=${pair%:*}
        case "${pair#*:}" in
            WBS) have=$WBS_COLS; where="wbs.template.md 任務表頭" ;;
            *)   have=$PART_COLS; where="plan-format「一眼看懂」部件表表頭" ;;
        esac
        val=$(ov_const "$name")
        miss=""
        [ -n "$val" ] || miss=" （找不到這個常數）"
        for c in $val; do printf '%s\n' "$have" | grep -qxF -- "$c" || miss="$miss $c"; done
        CHECKED=$((CHECKED + 1))
        if [ -n "$miss" ]; then
            FAIL=$((FAIL + 1))
            printf '  %s overview.sh 的 %s 有「%s」沒有的欄：%s\n' "$(red '✗')" "$name" "$where" "$miss"
            printf '      改了範本欄名就同步 %s 的常數，否則地圖會靜默抽不到東西\n' "$OVSH"
        fi
    done
fi

# 02 範本的 PRD 骨架：用語表、功能兩節，範例情境編號 `<代碼>-<序號>`
#
# 為什麼：PRD 情境編號是 plan 的「PRD 情境變更」與 /verify 套回的對照鍵，
# 範本範例寫成小寫或沒有序號，照抄的專案之後就沒有鍵可對。
TPL02=.claude/skills/project-docs/templates/02_project_brief_and_prd.md
if [ -f "$TPL02" ]; then
    for sec in 用語表 功能; do
        CHECKED=$((CHECKED + 1))
        if ! grep -qE "^## $sec( |$)" "$TPL02"; then
            FAIL=$((FAIL + 1))
            printf '  %s 02 範本的 PRD 骨架缺「## %s」一節：%s\n' "$(red '✗')" "$sec" "$TPL02"
        fi
    done
    CHECKED=$((CHECKED + 1))
    SCN=$(grep -E '^#### ' "$TPL02" || true)
    BAD_SCN=$(printf '%s\n' "$SCN" | grep -v '^$' | grep -vE '^#### [A-Z]+-[0-9]+( |$)' || true)
    if [ -z "$SCN" ] || [ -n "$BAD_SCN" ]; then
        FAIL=$((FAIL + 1))
        printf '  %s 02 範本的範例情境標題要是「#### <大寫代碼>-<序號> 標題」：%s\n' "$(red '✗')" "${BAD_SCN:-（找不到任何情境）}"
    fi
fi

# plan-format 範例：status 是四值之一、每個階段標題下一行是「依賴」
#
# 為什麼：status 加附註是 60 多種寫法的來源；依賴行是 /tdd 判斷哪些階段可平行的唯一依據。
PFSKILL=.claude/skills/plan-format/SKILL.md
if [ -f "$PFSKILL" ]; then
    CHECKED=$((CHECKED + 1))
    PF_STATUS=$(awk -F'"' '/^wbs_task:/{f=1} f && /^```/{exit} f && /^status:/{print $2; exit}' "$PFSKILL")
    case "$PF_STATUS" in
        "⏳ 未開始"|"🔄 進行中"|"🚫 阻塞"|"✅ 完成") ;;
        *)
            FAIL=$((FAIL + 1))
            printf '  %s plan-format 範例的 status 只准 ⏳ 未開始／🔄 進行中／🚫 阻塞／✅ 完成（不加附註）：%s\n' "$(red '✗')" "${PF_STATUS:-（找不到）}"
            ;;
    esac
    CHECKED=$((CHECKED + 1))
    NO_DEP=$(awk '/^wbs_task:/{f=1} f && /^```/{exit}
                  f && /^### 階段 [0-9]/{ t=$0; getline nx; if (nx !~ /^- \*\*依賴\*\*：/) print t }' "$PFSKILL")
    N_PHASES=$(awk '/^wbs_task:/{f=1} f && /^```/{exit} f && /^### 階段 [0-9]/{n++} END{print n+0}' "$PFSKILL")
    if [ "$N_PHASES" -eq 0 ] || [ -n "$NO_DEP" ]; then
        FAIL=$((FAIL + 1))
        printf '  %s plan-format 範例的階段標題下一行必須是「- **依賴**：」：%s\n' "$(red '✗')" "${NO_DEP:-（範例沒有任何階段）}"
    fi
    CHECKED=$((CHECKED + 1))
    DF_PLAN=$(awk '/^wbs_task:/{f=1} f && /^```/{exit}
                   f && /^### PRD 情境變更/{seen=1}
                   f && /^### 資料流變更/{if(!seen){print "順序錯：在 PRD 情境變更之前"} has=1; s=1; next}
                   s && /^#/{s=0}
                   s && /^- /{n++; if ($0 !~ /^- (ADDED|MODIFIED|REMOVED) /) print "項目開頭錯：" $0}
                   END{if(!has) print "沒有「### 資料流變更」"; else if(n==0) print "「### 資料流變更」底下沒有項目"}' "$PFSKILL")
    if [ -n "$DF_PLAN" ]; then
        FAIL=$((FAIL + 1))
        printf '  %s plan-format 範例要在「### PRD 情境變更」之後有「### 資料流變更」，項目以 ADDED／MODIFIED／REMOVED 開頭：%s\n' "$(red '✗')" "$(printf '%s' "$DF_PLAN" | tr '\n' ';')"
    fi
fi

# 05 範本的資料流節：位在自動段之後、至少一張 sequenceDiagram、每個小標題以全形括號結尾
#
# 為什麼：圖要連到 PRD 情境（括號裡的編號）；順序由大到小（模組與依賴在前、資料流在後）。
TPL05=.claude/skills/project-docs/templates/05_architecture_and_design_document.md
if [ -f "$TPL05" ]; then
    CHECKED=$((CHECKED + 1))
    DF_TPL=$(awk '/^<!-- overview:generated:end -->/{after=1; next}
                  /^## [0-9]+\. 資料流/{has=1; s=1; if (!after) print "資料流節在自動段結束標記之前"; next}
                  s && /^## /{s=0}
                  s && /^```mermaid/{getline nx; if (nx ~ /^sequenceDiagram/) seq++}
                  s && /^### /{sub(/\r$/, ""); if ($0 !~ /）$/) print "小標題沒有以「）」結尾：" $0}
                  END{if(!has) print "沒有資料流節"; else if(seq==0) print "節內沒有首行為 sequenceDiagram 的 mermaid 區塊"}' "$TPL05")
    if [ -n "$DF_TPL" ]; then
        FAIL=$((FAIL + 1))
        printf '  %s 05 範本要在自動段之後有「## N. 資料流」節（含 sequenceDiagram、小標題以全形括號結尾）：%s\n' "$(red '✗')" "$(printf '%s' "$DF_TPL" | tr '\n' ';')"
    fi
fi

# 專案圖解畫面：≤ 64KB、不載外部網址、不用 module script（file:// 下會被 CORS 擋）、
# 顏色只寫在 :root token 區塊（深淺雙主題靠它切換，散在別處的 hex 不會跟著換）
OVTPL=.claude/templates/overview/index.html
if [ -f "$OVSH" ]; then
    CHECKED=$((CHECKED + 1))
    if [ ! -f "$OVTPL" ]; then
        FAIL=$((FAIL + 1))
        printf '  %s 缺專案圖解畫面原檔：%s（overview.sh 靠它複製到 taskmaster-data/overview/）\n' "$(red '✗')" "$OVTPL"
    else
        OVSIZE=$(wc -c < "$OVTPL" | tr -d ' ')
        if [ "$OVSIZE" -gt 65536 ]; then
            FAIL=$((FAIL + 1))
            printf '  %s %s 有 %s bytes，超過 64KB 上限\n' "$(red '✗')" "$OVTPL" "$OVSIZE"
        fi
        CHECKED=$((CHECKED + 1))
        if grep -qE 'type=["'"'"']module' "$OVTPL"; then
            FAIL=$((FAIL + 1))
            printf '  %s %s 用了 module script（file:// 下會被 CORS 擋）\n' "$(red '✗')" "$OVTPL"
        fi
        CHECKED=$((CHECKED + 1))
        OVEXT=$(grep -nE 'https?:|@import|(src|href)=["'"'"']?//|url\(["'"'"']?//' "$OVTPL" \
            | sed 's#http://www\.w3\.org/2000/svg##g' \
            | grep -E 'https?:|@import|(src|href)=["'"'"']?//|url\(["'"'"']?//' | cut -c1-160)
        if [ -n "$OVEXT" ]; then
            FAIL=$((FAIL + 1))
            printf '  %s %s 有外部網址（離線 file:// 會打不開；SVG 命名空間除外）：\n' "$(red '✗')" "$OVTPL"
            printf '%s\n' "$OVEXT" | sed 's/^\([0-9]*\):/      第 \1 行：/'
        fi
        CHECKED=$((CHECKED + 1))
        OVHEX=$(awk '/^:root/{t=1} !t{print NR ":" $0} t && /}/{t=0}' "$OVTPL" \
            | grep -E '#[0-9a-fA-F]{3,8}\b' | cut -c1-160)
        if [ -n "$OVHEX" ]; then
            FAIL=$((FAIL + 1))
            printf '  %s %s 在 :root token 區塊以外寫了 hex 色碼（改用 CSS 變數）：\n' "$(red '✗')" "$OVTPL"
            printf '%s\n' "$OVHEX" | sed 's/^\([0-9]*\):/      第 \1 行：/'
        fi
    fi
fi

# docs-init 的架構文件步驟：指向 05 範本、不內嵌模組表
#
# 為什麼：模組表只該出現在架構文件第 4 節的自動段。指令裡再抄一份表頭，
# 照抄的專案就會手寫模組表，跟自動段兩份漂開。
DOCSINIT=.claude/commands/docs-init.md
if [ -f "$DOCSINIT" ]; then
    ARCHSTEP=$(awk '/^### 步驟 [0-9]+：架構文件/{s=1; next} s && /^### /{exit} s{print}' "$DOCSINIT")
    CHECKED=$((CHECKED + 1))
    if ! printf '%s' "$ARCHSTEP" | grep -q '05_architecture_and_design_document\.md'; then
        FAIL=$((FAIL + 1))
        printf '  %s docs-init.md 的「架構文件」步驟沒有指向 05 範本（格式的唯一來源）\n' "$(red '✗')"
    fi
    CHECKED=$((CHECKED + 1))
    if printf '%s\n' "$ARCHSTEP" | grep -qE '^\|[[:space:]]*id[[:space:]]*\|'; then
        FAIL=$((FAIL + 1))
        printf '  %s docs-init.md 的「架構文件」步驟內嵌了模組表表頭（`| id |`）——模組表由自動段產生，不要留第二份\n' "$(red '✗')"
    fi
fi

# 測試案例數（需由呼叫端提供實跑結果）
if [ -n "$TESTS_ACTUAL" ]; then
    verify "WORKFLOW 測試案例數" "$TESTS_ACTUAL" "$W" '[0-9]+ 個案例，全綠'
    verify "tests/README 案例數" "$TESTS_ACTUAL" .claude/hooks/tests/README.md '[0-9]+ 個案例，全數通過'
    verify "README 目錄樹案例數" "$TESTS_ACTUAL" README.md '[0-9]+ 案例回歸測試'
else
    printf '  %s 未提供 --tests N，跳過測試案例數比對\n' "$(dim 'ℹ')"
fi

# ---------------------------------------------------------------- 結果

echo ""
if [ "$FAIL" -eq 0 ]; then
    printf '%s 檢查 %s 項，全部一致\n\n' "$(green '結果')" "$CHECKED"
    exit 0
else
    printf '%s 檢查 %s 項，%s 項不一致\n\n' "$(red '結果')" "$CHECKED" "$FAIL"
    echo "修法：改文件裡的數字，或（若計數本身該變）確認檔案系統是對的。"
    echo "CLAUDE.md 的「改動時的連帶檢查」列了每種新增各要同步哪些檔案。"
    echo ""
    exit 1
fi
