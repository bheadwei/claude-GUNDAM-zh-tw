#!/usr/bin/env bash
# run-compliance.sh — skill／rule／注入的遵從度壓力測試
#
# 這**不是** pass/fail 測試。模型行為有隨機性，同一個 prompt 跑兩次可能不同，
# 所以這裡只負責「把每一輪跑出來並存檔」，判讀是人的事。
# 方法論見 `writing-extensions` skill 的「壓力測試法」；判讀方式見同目錄 README.md。
#
# 用法：
#   bash run-compliance.sh                 全部
#   bash run-compliance.sh 01 05           只跑指定編號
#   bash run-compliance.sh --baseline      關掉注入與閘門跑對照組（RED 那一步）
#
# 需求：claude CLI 在 PATH 上。

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
OUT="$DIR/results/$(date +%Y%m%d-%H%M%S)"

BASELINE=0
PICK=()
for a in "$@"; do
    case "$a" in
        --baseline) BASELINE=1 ;;
        -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) PICK+=("$a") ;;
    esac
done

command -v claude >/dev/null 2>&1 || {
    echo "✗ 找不到 claude CLI。這個測試需要實際跑一輪對話。" >&2
    exit 1
}

mkdir -p "$OUT"

mode="正常（注入與閘門啟用）"
env_args=()
if [ "$BASELINE" -eq 1 ]; then
    mode="BASELINE（注入與閘門停用 —— 這是 RED 那一步）"
    env_args=(SUGGEST_MODE=off TASKMODE_GATE=off PITFALL_GATE=off DOC_SYNC_GATE=off)
fi

echo ""
echo "Skill 遵從度壓力測試"
echo "  模式：$mode"
echo "  輸出：${OUT#"$ROOT"/}"
echo ""
echo "⚠️  每份 prompt 都是一輪完整對話，會實際消耗 token。"
echo ""

n=0
for f in "$DIR"/prompts/*.txt; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .txt)
    num="${name%%-*}"

    # 有指定編號時只跑那幾份
    if [ "${#PICK[@]}" -gt 0 ]; then
        hit=0
        for p in "${PICK[@]}"; do [ "$p" = "$num" ] && hit=1; done
        [ "$hit" -eq 1 ] || continue
    fi

    n=$((n + 1))
    prompt=$(cat "$f")
    echo "──── $name"
    echo "     prompt: $prompt"

    # -p 走非互動模式，單輪即結束
    if [ "${#env_args[@]}" -gt 0 ]; then
        ( cd "$ROOT" && env "${env_args[@]}" claude -p "$prompt" ) \
            > "$OUT/$name.out" 2>"$OUT/$name.err" || true
    else
        ( cd "$ROOT" && claude -p "$prompt" ) \
            > "$OUT/$name.out" 2>"$OUT/$name.err" || true
    fi

    # 快速訊號：有沒有提到委派、提到哪個 agent
    agents=$(grep -oE 'planner|architect|tdd-guide|code-quality-specialist|debug-investigator|build-error-resolver|refactor-cleaner|ui-builder|deployment-expert|documentation-specialist|workflow-template-manager|e2e-validation-specialist|test-automation-engineer|security-infrastructure-auditor' \
             "$OUT/$name.out" 2>/dev/null | sort -u | tr '\n' ' ')
    mode_decl=$(grep -oE '判定 \*\*(quick|standard|critical)\*\*|判定 (quick|standard|critical)' \
                "$OUT/$name.out" 2>/dev/null | head -1)
    echo "     提到的 agent：${agents:-（無）}"
    [ -n "$mode_decl" ] && echo "     任務模式宣告：$mode_decl"
    echo ""
done

cat > "$OUT/_判讀.md" <<EOF
# 壓力測試判讀 — $(date '+%Y-%m-%d %H:%M')

模式：$mode
跑了 $n 份 prompt

每份逐項填。**第 2 欄最有價值**——模型的理由要逐字抄，不要概括。

| # | 有做到期望行為 | 它用了什麼理由（逐字） | 是新藉口嗎 |
|---|---|---|---|

## 抓到的新藉口

（逐字補進 \`.claude/skills/using-taskmaster/SKILL.md\` 的 Red Flags 表）

## 結論

- 哪些注入有效：
- 哪些注入無效或太硬（03／06 被硬壓過就是太硬）：
- 要調整什麼：
EOF

echo "完成 $n 份。判讀表：${OUT#"$ROOT"/}/_判讀.md"
echo ""
echo "期望行為對照見同目錄 README.md 的表格。"
[ "$BASELINE" -eq 1 ] && echo "⚠️  剛才用的是 baseline 模式，逃生門只在該次子行程生效，未寫入設定檔。"
echo ""
