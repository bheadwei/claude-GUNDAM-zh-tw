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
#   bash scripts/check-counts.sh              # 只檢查靜態計數
#   bash scripts/check-counts.sh --tests 137  # 連測試案例數一起檢查
#
# 退出碼：0 = 一致，1 = 有 drift（可直接掛 CI）

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
N_BACKUP_SKILLS=$(find '.claude/custom-rule&skill/skills' -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
# project-docs 的 VibeCoding 範本：INDEX.md 本身不算範本
# （曾經有兩處寫 21，就是把 INDEX 算進去了）
N_DOCTPL=$(find .claude/skills/project-docs/templates -maxdepth 1 -name '*.md' ! -name 'INDEX.md' 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "檔案系統實況"
printf '  agents %-4s skills %-4s commands %-4s rules %-4s hooks %-4s 備份池 %-4s 文件範本 %s
' \
    "$N_AGENTS" "$N_SKILLS" "$N_CMDS" "$N_RULES" "$N_HOOKS" "$N_BACKUP_SKILLS" "$N_DOCTPL"
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
verify "備份池 skill 數"     "$N_BACKUP_SKILLS" README.md '更多 skill（[0-9]+ 個）'

W=.claude/guides/WORKFLOW.md
verify "五層表 Hooks"        "$N_HOOKS"  "$W" '\*\*Hooks\*\* \| [0-9]+ '
verify "五層表 Rules"        "$N_RULES"  "$W" '\*\*Rules\*\* \| [0-9]+ '
verify "五層表 Skills"       "$N_SKILLS" "$W" '\*\*Skills\*\* \| [0-9]+ '
verify "五層表 Commands"     "$N_CMDS"   "$W" '\*\*Commands\*\* \| [0-9]+ '
verify "五層表 Agents"       "$N_AGENTS" "$W" '\*\*Agents\*\* \| [0-9]+ '

verify "INDEX 開頭 skill 數" "$N_SKILLS" .claude/skills/INDEX.md '^[0-9]+ 個 skill'

# VibeCoding 文件範本數（六處寫過這個數字，曾漂走兩處）
verify "範本數 project-docs skill" "$N_DOCTPL" .claude/skills/project-docs/SKILL.md '[0-9]+ 種文件範本|[0-9]+ 種範本'
verify "範本數 skills/INDEX"       "$N_DOCTPL" .claude/skills/INDEX.md '[0-9]+ 種範本自帶'
verify "範本數 README skill 表"    "$N_DOCTPL" README.md '[0-9]+ 份範本自帶'
verify "範本數 README 章節標題"    "$N_DOCTPL" README.md 'VibeCoding 工作流模板（[0-9]+ 份）'
verify "範本數 templates/INDEX"    "$N_DOCTPL" .claude/skills/project-docs/templates/INDEX.md '模板清單（[0-9]+ 份'

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
