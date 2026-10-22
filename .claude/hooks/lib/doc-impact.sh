#!/bin/bash
# doc-impact.sh — 「這個檔案改了，文件會不會過期」的判斷規則（供 hook source）
#
# 為什麼獨立成 lib：兩個入口需要**同一套**規則——
#   - post-write.sh：寫檔當下，一次一個檔
#   - post-bash.sh ：合併成功後，`git diff --name-only ORIG_HEAD HEAD` 的整批檔案
# 後者是 2026-10-20 補的：worktree 裡累積的 `.doc-impact` 是**短命旗標**，跟著 worktree
# 走、不進 git，所以合併回主 checkout 時那份文件債**整份消失**——主 checkout 的
# `/verify` 看到的是空清單，放行了一批動過 API／schema 卻沒同步文件的改動。
# 兩邊各寫一份規則，就是 cmd-segments.sh 檔頭講的「同一個坑修兩次」。
#
# 用法：
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/doc-impact.sh" 2>/dev/null || true
#   doc_bearing "src/api/users.ts" && echo 文件會描述它      # 相對 checkout root 的路徑
#   doc_impact_add "$DATA_DIR" "src/api/users.ts"            # 去重後累積進 .doc-impact

# doc_bearing <相對路徑> —— 0 = 是文件描述的對象
# 先排除（模板自身、文件本身、依賴、建置產物、測試），再比對「文件會描述的檔案」。
doc_bearing() {
    local rel="$1"
    [ -n "$rel" ] || return 1
    case "$rel" in
        .claude/*|*/.claude/*) return 1 ;;
        docs/*|*/docs/*) return 1 ;;
        node_modules/*|*/node_modules/*|.venv/*|*/.venv/*|venv/*|*/venv/*) return 1 ;;
        dist/*|*/dist/*|build/*|*/build/*|.next/*|*/.next/*|target/*|*/target/*) return 1 ;;
        .git/*|*/.git/*) return 1 ;;
    esac
    # 測試排除要錨定在目錄名或檔名邊界：裸子字串 `*test*|*spec*` 會把 `latest/`、`contest/`、
    # `inspector/`、`specification/` 底下的 API／schema 一起排掉（2026-10-21 審查）
    case "/$rel" in
        */test/*|*/tests/*|*/__tests__/*|*/spec/*|*/specs/*|*/fixtures/*|*/__fixtures__/*) return 1 ;;
    esac
    case "${rel##*/}" in
        *.test.*|*.spec.*|test_*|*_test.*|*_spec.*) return 1 ;;
    esac
    case "$rel" in
        */api/*|api/*|*/routes/*|routes/*|*/router/*|*/controllers/*|*/handlers/*|*/endpoints/*)
            return 0 ;;
        *openapi*|*swagger*|*.proto|*.graphql|*schema.*|*/schema/*|*/schemas/*)
            return 0 ;;
        */migrations/*|*/models/*|*/entities/*|*/dto/*)
            return 0 ;;
        */index.ts|*/index.js|*/index.tsx|*.d.ts|*/public-api.ts)
            return 0 ;;
        */cli/*|*/commands/*|.env.example)
            return 0 ;;
    esac
    return 1
}

# doc_impact_add <taskmaster-data 目錄> <相對路徑> —— 去重後追加；新加的回 0、已存在回 1
doc_impact_add() {
    local dir="$1" rel="$2" f
    f="$dir/.doc-impact"
    mkdir -p "$dir" 2>/dev/null || true
    grep -qxF "$rel" "$f" 2>/dev/null && return 1
    echo "$rel" >> "$f" 2>/dev/null || true
    return 0
}
