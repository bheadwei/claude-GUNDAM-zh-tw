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
#   bash run-compliance.sh -n 3            每份 prompt 連跑 3 輪（算 pass@k／pass^k）
#
# 單次結果不能下結論——行為有隨機性。要判斷「注入有沒有效」就跑 -n 3，
# 看命中次數：正向題 pass@3 ≥ 2/3，反向題（03／06）要 pass^3 = 3/3。
# 門檻與四種評分者見同目錄 README.md。
#
# 需求：claude CLI 在 PATH 上。

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
OUT="$DIR/results/$(date +%Y%m%d-%H%M%S)"

BASELINE=0
RUNS=1
PICK=()
while [ $# -gt 0 ]; do
    case "$1" in
        --baseline) BASELINE=1 ;;
        -n|--runs)
            RUNS="${2:-}"
            case "$RUNS" in
                ''|*[!0-9]*) echo "✗ -n 要跟一個正整數" >&2; exit 1 ;;
            esac
            [ "$RUNS" -ge 1 ] || { echo "✗ -n 要 ≥ 1" >&2; exit 1; }
            shift
            ;;
        -h|--help) sed -n '2,21p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) PICK+=("$1") ;;
    esac
    shift
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
echo "  每份輪數：$RUNS"
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

    hits=0
    for r in $(seq 1 "$RUNS"); do
        if [ "$RUNS" -eq 1 ]; then
            out="$OUT/$name.out"
        else
            out="$OUT/$name.r$r.out"
        fi

        # -p 走非互動模式，單輪即結束
        if [ "${#env_args[@]}" -gt 0 ]; then
            ( cd "$ROOT" && env "${env_args[@]}" claude -p "$prompt" ) \
                > "$out" 2>"${out%.out}.err" || true
        else
            ( cd "$ROOT" && claude -p "$prompt" ) \
                > "$out" 2>"${out%.out}.err" || true
        fi

        # code grader：有沒有點名 agent、有沒有宣告任務模式
        agents=$(grep -oE 'planner|architect|tdd-guide|code-quality-specialist|debug-investigator|build-error-resolver|refactor-cleaner|ui-builder|deployment-expert|documentation-specialist|workflow-template-manager|e2e-validation-specialist|test-automation-engineer|security-infrastructure-auditor' \
                 "$out" 2>/dev/null | sort -u | tr '\n' ' ')
        mode_decl=$(grep -oE '判定 \*\*(quick|standard|critical)\*\*|判定 (quick|standard|critical)' \
                    "$out" 2>/dev/null | head -1)

        if [ "$RUNS" -eq 1 ]; then printf '     '; else printf '     [r%s] ' "$r"; fi
        printf '提到的 agent：%s' "${agents:-（無）}"
        [ -n "$mode_decl" ] && printf '｜模式宣告：%s' "$mode_decl"
        printf '\n'

        # 有任一訊號就算一次命中。**這只是粗篩**——是否真的做到期望行為由人判
        if [ -n "$agents" ] || [ -n "$mode_decl" ]; then
            hits=$((hits + 1))
        fi
    done

    if [ "$RUNS" -gt 1 ]; then
        echo "     code grader 命中 $hits/$RUNS（粗篩：有點名 agent 或有模式宣告）"
        echo "     正向題看 pass@$RUNS（多數輪命中才算注入有效）；反向題 03／06 要每輪都不命中"
    fi
    echo ""
done

cat > "$OUT/_判讀.md" <<EOF
# 壓力測試判讀 — $(date '+%Y-%m-%d %H:%M')

模式：$mode
跑了 $n 份 prompt，每份 $RUNS 輪

每份逐項填。**第 3 欄最有價值**——模型的理由要逐字抄，不要概括。
第 2 欄填「幾輪做到／共幾輪」：正向題看 pass@k（≥2/3 才算注入有效），
反向題 03／06 要 pass^k（每一輪都不該壓過使用者的明確指示）。

| # | 做到幾輪／共幾輪 | 它用了什麼理由（逐字） | 是新藉口嗎 |
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
