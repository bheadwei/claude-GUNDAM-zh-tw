#!/bin/bash
# full-suite-gate.sh — worktree 裡跑整套測試前擋一次（供 pre-tool-use.sh source）
#
# 為什麼需要（真實事故，2026-11-02，另一個用本模板的專案）：4 條 critical 平行線＋
# 1 個 debug-investigator，各線 RED／GREEN **每一輪**都跑整套 tests/unit（約 1.5 萬條、
# 20～40 分鐘），N 份整套同時搶同一台機器的 CPU 與同一個測試 DB。
# 「每輪只跑相關測試、整套留給 /verify」早就寫在 testing-standards「執行測試」節，
# 但那是文字規則，在那個專案裡沒被遵守——而「這條指令是不是沒帶路徑的整套」
# 在工具呼叫當下判斷得出來，正是 writing-extensions 決策表第一列的形狀。
#
# 判準：**在 linked worktree 裡**、某一段指令是測試執行器（pytest／`uv run pytest`／
# `python -m pytest`／vitest／jest／`npm|pnpm|yarn|bun test`），而且**沒有任何**：
#   - 測試檔或範圍夠窄的目錄（`tests/test_x.py`、`src/order/`；`tests`、`tests/unit`、
#     `src`、`.` 這種「整個測試根」視同整套——事故裡跑的正是 `tests/unit`）
#   - 篩選：`::`、pytest 的 `-k`／`-m`／`--lf`、jest／vitest 的 `-t`／`--testPathPattern`／
#     `--changed`／`--onlyChanged`／`--findRelatedTests`、`vitest related`
# → 擋一次。
#
# **只在 worktree 裡擋，主 checkout 不擋。** 理由：
#   - 事故的成本來自**平行**：N 條線同時跑整套才互相拖慢。主 checkout 同一時間只有一條線
#   - 主 checkout 是 `/verify` 驗合併結果的地方（見 merge-gate.sh），在那裡跑整套是本分
#   - 單線開發每輪跑整套也是浪費，但那條規則留給 testing-standards（文字）；
#     要擴大到主 checkout，先拿真實資料證明它在單線也造成問題
#
# **deny-once，而且「一次」是消耗性的**：擋下時記下整條指令，**同一條**重試 → 放行並清掉
# 標記；下次再跑同一條整套會再擋一次。理由：事故的形狀正是「同一條指令每輪都跑」，
# 只擋第一次的話第二輪起就沒有任何提醒。代價是每次整套多一個來回（幾秒），
# 相對 20～40 分鐘的整套可以忽略。本閘門擋的是「資訊」不是「狀態」（區分見
# git-backup-gate.sh 檔頭），所以重試一定放行，不會卡死。
#
# 合法的整套（`/verify`、`/deps`、`/refactor-clean` 的基準與每批）→ 指令裡加註解
# `# full-suite`，本閘門直接放行。為什麼用註解而不是 `.merge-pending` 那種旗標檔：
#   - 旗標檔要有人寫、有人刪；忘了刪就是永久放行，而且 refactor-cleaner 在 worktree 裡跑，
#     旗標要寫在哪一邊又是一個要想清楚的邊界
#   - `FULL_SUITE=1 pytest` 這種前綴在 PowerShell 是語法錯誤；`#` 在 bash 與 PowerShell
#     都是註解，對指令本身零影響
#   - 宣告寫在指令上，transcript 裡看得到「這次是刻意跑整套」
#
# 有意留下的漏網（方向一律偏「寧可漏抓也不誤擋」）：
#   - 包在別的指令裡的不看：`flock … pytest`、`bash -c "pytest"`、`docker compose run app pytest`、
#     `make test`、`tox`、`nox`、`poetry run`、`npm run test:unit` 這種自訂 script 名
#   - 引號裡的路徑一律當成「有帶路徑」（cmd-segments 把引號內容清空了，看不到是什麼）
#   - 原始指令任何地方出現 `# full-suite` 都放行（含 heredoc 內文）
#   - 目錄是不是「整個測試根」只看名字，不看檔案系統（Windows 上每查一次 ~170ms）
#
# 逃生門：FULL_SUITE_GATE=off
# `.suggest-mode` = off、`TASKMODE_GATE=off` 由 pre-tool-use.sh 在呼叫本函式之前處理。
#
# 用法（pre-tool-use.sh 內，Bash／PowerShell 且取得 COMMAND 之後）：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/full-suite-gate.sh"
#   full_suite_gate "$COMMAND" "$IN_WORKTREE" "$DATA_DIR"   # 命中時自行輸出 deny JSON 並 exit 0
#
# 狀態檔 `$DATA_DIR/.full-suite-warned`：短命旗標、跟著 worktree（DATA_DIR 是 WORK_CLAUDE 那份），
# 邊界判準見 worktree-orchestration skill 與 resolve-roots.sh 檔頭。

declare -F cmd_split >/dev/null 2>&1 || source "${BASH_SOURCE[0]%/*}/cmd-segments.sh" 2>/dev/null || true

# _fsg_broad_path <token> —— 0 = 這個路徑等於「整個測試根」
_fsg_broad_path() {
    local p="$1"
    p="${p//'\'//}"
    while [ "${p%/}" != "$p" ]; do p="${p%/}"; done
    p="${p#./}"
    case "$p" in ""|.|./) return 0 ;; esac
    local base="${p##*/}"
    case "$base" in
        *.*) return 1 ;;      # 檔名（test_x.py、x.test.ts）
        tests|test|unit|units|integration|integrations|__tests__|spec|specs|src|e2e|functional|app|lib) return 0 ;;
    esac
    return 1
}

# _fsg_is_full <指令段> —— 0 = 這一段是「沒帶路徑也沒篩選」的測試執行；runner 名放 FSG_RUNNER
_fsg_is_full() {
    local -a t
    read -ra t <<< "$1"
    local n=${#t[@]} i=0 w nx
    FSG_RUNNER=""

    # 前綴：環境變數設定、env／time／nice、timeout <秒數>
    while [ "$i" -lt "$n" ]; do
        case "${t[$i]}" in
            [A-Za-z_]*=*|env|time|nice|command) i=$((i + 1)) ;;
            timeout) i=$((i + 2)) ;;
            *) break ;;
        esac
    done
    [ "$i" -lt "$n" ] || return 1

    w="${t[$i]##*/}"; w="${w##*'\'}"; w="${w%.exe}"; w="${w%.cmd}"
    nx="${t[$((i + 1))]:-}"
    case "$w" in
        uv)
            [ "$nx" = run ] || return 1
            i=$((i + 2))
            while [ "$i" -lt "$n" ]; do
                case "${t[$i]}" in
                    --with|--python|-p|--extra|--group|--package|--directory|--project|--env-file|--index|--with-requirements) i=$((i + 2)) ;;
                    -*) i=$((i + 1)) ;;
                    *) break ;;
                esac
            done
            [ "$i" -lt "$n" ] || return 1
            w="${t[$i]##*/}"; w="${w%.exe}"; nx="${t[$((i + 1))]:-}"
            ;;
        npx|bunx)
            i=$((i + 1))
            while [ "$i" -lt "$n" ]; do case "${t[$i]}" in -*) i=$((i + 1)) ;; *) break ;; esac; done
            [ "$i" -lt "$n" ] || return 1
            w="${t[$i]}"; nx="${t[$((i + 1))]:-}"
            ;;
        npm|pnpm|yarn|bun)
            case "$nx" in
                test|t)
                    FSG_RUNNER="$w test"; i=$((i + 2)) ;;
                run|run-script)
                    case "${t[$((i + 2))]:-}" in
                        test) FSG_RUNNER="$w run test"; i=$((i + 3)) ;;
                        vitest|jest) i=$((i + 2)); w="${t[$i]}"; nx="${t[$((i + 1))]:-}" ;;
                        *) return 1 ;;
                    esac ;;
                exec|dlx|x)
                    i=$((i + 2)); w="${t[$i]:-}"; nx="${t[$((i + 1))]:-}" ;;
                vitest|jest)
                    i=$((i + 1)); w="$nx"; nx="${t[$((i + 1))]:-}" ;;
                *) return 1 ;;
            esac
            ;;
    esac

    if [ -z "$FSG_RUNNER" ]; then
        case "$w" in
            python|python3|py)
                [ "$nx" = -m ] && [ "${t[$((i + 2))]:-}" = pytest ] || return 1
                FSG_RUNNER="python -m pytest"; i=$((i + 3)) ;;
            pytest|py.test)
                FSG_RUNNER="pytest"; i=$((i + 1)) ;;
            vitest)
                FSG_RUNNER="vitest"; i=$((i + 1))
                case "$nx" in
                    run|watch|dev) i=$((i + 1)) ;;
                    related|bench|list|init) return 1 ;;
                esac ;;
            jest)
                FSG_RUNNER="jest"; i=$((i + 1)) ;;
            *) return 1 ;;
        esac
    fi

    local tok skip=0
    for tok in "${t[@]:$i}"; do
        if [ "$skip" -eq 1 ]; then skip=0; continue; fi
        case "$tok" in
            --|'&') continue ;;
            *'>'|*'<') skip=1; continue ;;          # 單獨的重導向運算子，下一個字是檔名
            *'>'*|*'<'*) continue ;;                # 2>&1、>out.txt
            *::*) return 1 ;;
            # 不是在跑測試
            --version|-V|--help|-h|--collect-only|--co|--listTests|--showConfig|--fixtures|--markers) return 1 ;;
        esac
        case "$FSG_RUNNER" in
            pytest|"python -m pytest")
                case "$tok" in
                    -k*|-m*|--lf|--last-failed|--sw|--stepwise) return 1 ;;
                    -n|-p|-c|-o|-W|-r|--cov|--cov-report|--cov-config|--maxfail|--rootdir|--durations|--tb|--junitxml|--junit-xml|--basetemp|--confcutdir|--import-mode|--log-level|--dist|--timeout|--ignore|--ignore-glob|--deselect) skip=1; continue ;;
                esac ;;
            vitest|jest)
                case "$tok" in
                    -t*|--testNamePattern*|--testPathPattern*|--changed*|--onlyChanged|-o|--findRelatedTests|--related) return 1 ;;
                    -c|--config|--reporter|--outputFile|--maxWorkers|-w|--pool|--environment|--testEnvironment|--collectCoverageFrom|--coverageDirectory|--coverageReporters|--testTimeout|--root|-r|--dir|--mode|--project|--selectProjects|--shard) skip=1; continue ;;
                esac ;;
            *)  # npm/pnpm/yarn/bun test：不知道底下是哪個框架，篩選取聯集
                case "$tok" in
                    -k*|-m*|-t*|--testNamePattern*|--testPathPattern*|--changed*|--onlyChanged|-o|--findRelatedTests|--related|--lf|--last-failed) return 1 ;;
                esac ;;
        esac
        case "$tok" in
            -*) continue ;;
            \"\"|\'\') return 1 ;;                  # 引號內容被清空，看不到 → 當成有帶路徑
        esac
        _fsg_broad_path "$tok" || return 1
    done
    return 0
}

full_suite_gate() {
    local cmd="$1" in_worktree="$2" data_dir="$3"
    [ "${FULL_SUITE_GATE:-on}" = "off" ] && return 0
    [ "$in_worktree" = 1 ] || return 0
    [ -n "$cmd" ] || return 0

    # 便宜的預篩：連這幾個字都沒有就不切段（切段要開 5 個行程，Windows 上約 1 秒）
    case "$cmd" in
        *pytest*|*py.test*|*vitest*|*jest*|*[[:space:]]test*|*[[:space:]]t|*[[:space:]]t[[:space:]]*) ;;
        *) return 0 ;;
    esac

    # 合法的整套：指令上宣告了
    local marker_re='(^|[[:space:]])#[[:space:]]*full-suite([^[:alnum:]_-]|$)'
    [[ $cmd =~ $marker_re ]] && return 0

    declare -F cmd_split >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0

    local segs seg hit="" runner=""
    segs=$(cmd_split "$cmd")
    [ -n "$segs" ] || return 0
    while IFS= read -r seg; do
        [ -n "$seg" ] || continue
        if _fsg_is_full "$seg"; then hit="$seg"; runner="$FSG_RUNNER"; break; fi
    done <<< "$segs"
    [ -n "$hit" ] || return 0

    # deny-once（消耗性）：同一條重試 → 放行並清掉標記
    local key="${cmd//$'\r'/}" flag="$data_dir/.full-suite-warned" prev=""
    key="${key//$'\n'/ }"
    if [ -f "$flag" ]; then
        IFS= read -r prev < "$flag" 2>/dev/null || true
        if [ "$prev" = "$key" ]; then
            rm -f "$flag" 2>/dev/null || true
            return 0
        fi
    fi
    mkdir -p "$data_dir" 2>/dev/null || true
    printf '%s\n' "$key" > "$flag" 2>/dev/null || true

    local ex
    case "$runner" in
        pytest|"python -m pytest")
            ex='uv run pytest tests/test_order.py -q
uv run pytest tests/test_order.py::test_refund_over_limit -q
uv run pytest tests/order/ -k refund -q' ;;
        vitest)
            ex='<pm> vitest run src/order/refund.test.ts
<pm> vitest run src/order/ -t "refund over limit"' ;;
        jest)
            ex='<pm> jest src/order/refund.test.ts
<pm> jest src/order/ -t "refund over limit"' ;;
        *)
            ex='<pm> test -- src/order/refund.test.ts
（pytest 專案：uv run pytest tests/test_order.py -q）' ;;
    esac

    jq -n --arg hit "$hit" --arg ex "$ex" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("⛔ 你在 worktree 裡跑**整套**測試：`" + $hit + "`——沒帶測試檔路徑，也沒有 `::`／`-k`／`-t` 這類篩選（`tests`、`tests/unit`、`src` 這種整個測試根也算整套）。\n\n**為什麼擋**：平行開發時每條 worktree 線各跑一份整套，就是 N 份整套同時搶同一台機器的 CPU 與同一個測試 DB。實際發生過：約 1.5 萬條測試、每輪 20～40 分鐘，4 條線每一輪都這樣跑。RED／GREEN 每一輪只需要跑**這次相關的測試檔**；整套是 `/verify` 收尾時的事，它一定會跑。\n\n**改成只跑相關的（照這個形狀改寫）：**\n\n```\n" + $ex + "\n```\n\n「相關」＝新寫的測試檔，加上 `git diff --name-only <階段起點>` 列出的那些模組對應的測試檔。規則的唯一來源：`.claude/skills/testing-standards/SKILL.md` 的「執行測試」節。\n\n**確定這次就是要整套：**\n\n- `/verify`、`/deps`、`/refactor-clean` 的基準與每批 → 指令尾端加註解 `# full-suite`（例：`uv run pytest -q  # full-suite`），本閘門不攔\n- 其他理由 → 重試**同一條指令**即通過（每次整套擋一次，重試就放行）\n\n（只在 worktree 裡擋，主 checkout 不擋。關閉：FULL_SUITE_GATE=off）")
      }
    }' 2>/dev/null || true
    exit 0
}
