#!/bin/bash

# TaskMaster Session Start Hook
# 當 Claude Code 會話開始時自動執行
# 跨平台支援：Windows (Git Bash)、Windows WSL、macOS、Linux

# ============================================================================
# 平台檢測和兼容性設置
# ============================================================================

# 檢測操作系統平台
detect_platform() {
    local uname_output="$(uname -s)"

    # 優先檢查環境變量（更準確）
    # WSL_DISTRO_NAME 只存在於 WSL 環境
    if [ -n "$WSL_DISTRO_NAME" ]; then
        echo "wsl"
        return
    fi

    # 檢查是否在 Windows Git Bash
    # MSYSTEM 環境變量存在於 Git Bash
    if [ -n "$MSYSTEM" ]; then
        echo "windows"
        return
    fi

    # 使用 uname 判斷
    case "$uname_output" in
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        Linux)
            # 二次確認是否為 WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

PLATFORM=$(detect_platform)

# Windows 兼容性：不使用 set -e，改為手動錯誤處理
# set -e 會導致在 Windows 環境下任何非零退出碼都中斷執行

# 跨平台路徑處理
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"

# 路徑驗證（所有平台）
if [ -z "$PROJECT_ROOT" ] || [ -z "$CLAUDE_DIR" ]; then
    echo "❌ 無法確定專案路徑 (Platform: $PLATFORM)" >&2
    exit 0  # 改為 exit 0，避免中斷 Claude Code
fi

# 確保 logs 目錄存在
mkdir -p "$CLAUDE_DIR/logs" 2>/dev/null

# 日誌函數（跨平台兼容）
log() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '????-??-?? ??:??:??')]"
    echo "$timestamp $1" | tee -a "$CLAUDE_DIR/logs/hooks.log" 2>/dev/null || echo "$timestamp $1"
}

log "🪝 TaskMaster Session Start Hook 觸發 (Platform: $PLATFORM)"

# ============================================================================
# 時間追蹤：歸檔上一次 Session 的時間
# ============================================================================
TIMELOG_DIR="$CLAUDE_DIR/taskmaster-data"
SNAPSHOT_FILE="$TIMELOG_DIR/.session-snapshot"
TIMELOG_FILE="$TIMELOG_DIR/timelog.jsonl"

if [ -f "$SNAPSHOT_FILE" ]; then
    # 讀取上次 session 的快照
    snapshot=$(cat "$SNAPSHOT_FILE" 2>/dev/null)
    if [ -n "$snapshot" ] && command -v jq >/dev/null 2>&1; then
        snap_duration=$(echo "$snapshot" | jq -r '.duration_ms // 0' 2>/dev/null)
        if [ "$snap_duration" -gt 0 ] 2>/dev/null; then
            # 追加到 timelog.jsonl（不覆蓋，追加）
            echo "$snapshot" >> "$TIMELOG_FILE" 2>/dev/null
            log "⏱️ 上次 Session 時間已歸檔 (${snap_duration}ms)"
        fi
    fi
    # 清除快照
    rm -f "$SNAPSHOT_FILE" 2>/dev/null
fi

# 記錄本次 session 開始時間
mkdir -p "$TIMELOG_DIR" 2>/dev/null
date '+%H:%M' > "$TIMELOG_DIR/.session-start" 2>/dev/null

# 檢查是否存在 CLAUDE_TEMPLATE.md
if [ -f "$PROJECT_ROOT/CLAUDE_TEMPLATE.md" ]; then
    log "📄 偵測到 CLAUDE_TEMPLATE.md"

    # 檢查是否已經初始化過
    if [ ! -f "$CLAUDE_DIR/taskmaster-data/project.json" ]; then
        log "🚀 準備自動觸發 TaskMaster 初始化"

        # 顯示提示訊息（Jobs 式極簡設計）
        echo ""
        echo -e "\033[1;37m╭─────────────────────────────────────────────────────────────╮\033[0m"
        echo -e "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m     \033[1;97m🚀 TaskMaster Ready\033[0m                                  \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m     \033[0;90mTemplate detected. Start with:\033[0m                      \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m     \033[1;36m/task-init [project-name]\033[0m                           \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        echo -e "\033[1;37m├─────────────────────────────────────────────────────────────┤\033[0m"
        echo -e "\033[1;37m│\033[0m \033[1;97mWorkflow\033[0m                                                   \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m   \033[1;32m①\033[0m  \033[0;37mCollect requirements\033[0m           \033[0;90m→ Human review\033[0m    \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m   \033[1;33m②\033[0m  \033[0;37mGenerate project docs\033[0m          \033[0;90m→ Quality gate\033[0m    \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m   \033[1;36m③\033[0m  \033[0;37mStart development\033[0m              \033[0;90m→ After approval\033[0m  \033[1;37m│\033[0m"
        echo -e "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
        echo -e "\033[1;37m╰─────────────────────────────────────────────────────────────╯\033[0m"
        echo ""

        # 觸發 TaskMaster Node.js 處理器（可選，不存在則跳過）
        if [ -f "$CLAUDE_DIR/taskmaster.js" ]; then
            log "🔗 調用 TaskMaster Node.js 處理器"
            cd "$PROJECT_ROOT" 2>/dev/null || exit 0
            node "$CLAUDE_DIR/taskmaster.js" --hook-trigger=session-start || true
        fi

        exit 0
    else
        log "ℹ️ TaskMaster 已初始化"

        # 檢查是否有現有 WBS 檔案，提示恢復
        if [ -f "$CLAUDE_DIR/taskmaster-data/wbs.md" ]; then
            log "📋 偵測到現有 WBS 任務清單"

            echo ""
            echo -e "\033[1;37m╭─────────────────────────────────────────────────────────────╮\033[0m"
            echo -e "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
            echo -e "\033[1;37m│\033[0m     \033[1;97m📋 WBS 任務清單已載入\033[0m                              \033[1;37m│\033[0m"
            echo -e "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
            echo -e "\033[1;37m│\033[0m     \033[0;90mResume with:\033[0m                                        \033[1;37m│\033[0m"
            echo -e "\033[1;37m│\033[0m     \033[1;36m/task-status\033[0m  查看進度                              \033[1;37m│\033[0m"
            echo -e "\033[1;37m│\033[0m     \033[1;36m/task-next\033[0m    取得下一個任務                        \033[1;37m│\033[0m"
            echo -e "\033[1;37m│\033[0m                                                             \033[1;37m│\033[0m"
            echo -e "\033[1;37m╰─────────────────────────────────────────────────────────────╯\033[0m"
            echo ""
        fi

        exit 0
    fi
else
    log "ℹ️ 未偵測到 CLAUDE_TEMPLATE.md，TaskMaster 待命中"
    exit 0
fi