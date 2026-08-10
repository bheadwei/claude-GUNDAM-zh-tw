#!/bin/bash
# User Prompt Submit Hook
#   (1) 偵測 /task-init，確保資料目錄存在（沿用）
#   (2) 意圖路由：依關鍵字注入「建議任務模式 + 建議 agent 鏈」提示，
#       協助主模型更主動委派。純文字 stdout 即會被加入 context（exit 0）。
#
# 受 .suggest-mode 控制：off→不注入、low→僅高訊號(安全/金流)、medium·high→全部。

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null || true

INPUT=$(cat)
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

# 斜線指令不路由（使用者已明確指定流程）
case "$USER_INPUT" in
    /*) exit 0 ;;
esac

# 讀 suggest-mode（預設 medium）
SUGGEST_MODE="medium"
SM_FILE="$CLAUDE_DIR/taskmaster-data/.suggest-mode"
if [ -f "$SM_FILE" ]; then
    SUGGEST_MODE=$(tr -d '[:space:]' < "$SM_FILE" 2>/dev/null || echo "medium")
    [ -z "$SUGGEST_MODE" ] && SUGGEST_MODE="medium"
fi
[ "$SUGGEST_MODE" = "off" ] && exit 0

# 小工具：關鍵字命中判斷（大小寫不敏感；中文以位元組比對）
has() { echo "$USER_INPUT" | grep -iqE "$1"; }

HINTS=""
add() { HINTS="${HINTS}
  - $1"; }

HIGH_SIGNAL=0  # 安全/金流等高訊號，low 模式也會顯示

# --- 高訊號：安全 / 金流 / 認證 ---
if has 'auth|login|oauth|jwt|session|password|認證|授權|登入|密碼' \
   || has 'payment|billing|stripe|checkout|金流|支付|付款|帳務'; then
    HIGH_SIGNAL=1
    add "偵測到認證/金流關鍵字 → 建議任務模式 **critical**；critical 一律需要 /plan（見 plan-format skill），實作後啟動 security-infrastructure-auditor，覆蓋率目標 100%。"
fi

# --- migration / schema ---
if has 'migration|migrate|資料庫遷移|schema 變更|遷移'; then
    HIGH_SIGNAL=1
    add "偵測到資料庫遷移 → 建議 **critical**；先 /plan，務必含回滾策略與資料備份。"
fi

# 以下為一般訊號（low 模式略過）
if [ "$SUGGEST_MODE" != "low" ]; then
    if has 'deploy|部署|發布|上線|ci/cd|docker|kubernetes|k8s|rollback|回滾'; then
        add "偵測到部署/維運 → 建議委派 deployment-expert。"
    fi
    if has 'refactor|重構|dead code|死碼|cleanup|清理|整併'; then
        add "偵測到重構/清理 → 建議委派 refactor-cleaner（分批移除、每批測試+commit）。"
    fi
    if has 'build error|compile|編譯錯誤|型別錯誤|tsc|建置失敗|build failed'; then
        add "偵測到建置/型別錯誤 → 建議委派 build-error-resolver（最小差異修復）。"
    fi
    if has 'ui|前端|頁面|畫面|component|元件|tailwind|css|pencil|設計稿'; then
        add "偵測到前端 UI/設計稿 → **先載入 \`ui-style-compliance\` skill**（風格三階段檢查已從常駐 rules 移出）；可用 /ui-page 或委派 ui-builder。"
    fi
    if has 'npm|pnpm|bun|yarn|package\.json|node_modules|lockfile|套件安裝'; then
        add "偵測到 Node 套件操作 → **先載入 \`node-package-manager\` skill**，讀 package-manager.json 決定用哪個 PM，勿自選。"
    fi
    if has 'pip|poetry|uv |virtualenv|venv|pyproject|requirements\.txt'; then
        add "偵測到 Python 環境操作 → **先載入 \`python-uv\` skill**（一律 uv，禁 pip/poetry）。"
    fi
    if has 'test|測試|coverage|覆蓋率|pytest|jest|vitest'; then
        add "偵測到測試相關 → **先載入 \`testing-standards\` skill** 確認當前任務模式的覆蓋率門檻（quick 免檢）。"
    fi
fi

# low 模式且非高訊號 → 不注入
[ "$SUGGEST_MODE" = "low" ] && [ "$HIGH_SIGNAL" -eq 0 ] && exit 0
[ -z "$HINTS" ] && exit 0

echo "💡 意圖路由提示（依關鍵字，僅供參考；可用 /suggest-mode 調整密度）：${HINTS}"
exit 0
