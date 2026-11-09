#!/usr/bin/env bash
# update-template.sh — 將 claude_v2026 模板的「最新資產」更新到既有專案
#
# 與 copy-template.sh 的差異：
#   copy-template   = 開新專案（複製到空資料夾）
#   update-template = 更新既有專案（只更新模板資產，保留該專案的 log/plan/qa-history/sessions）
#
# 用法:
#   ./scripts/update-template.sh /path/to/my-app
#   ./scripts/update-template.sh /path/to/my-app --dry-run    # 只預覽不寫入
#   ./scripts/update-template.sh /path/to/my-app --prune       # 連目標多出來的模板檔一起清掉
#   ./scripts/update-template.sh /path/to/my-app --no-backup   # 不先備份（不建議）
#   ./scripts/update-template.sh /path/to/my-app --claude-only # 只更新 .claude/，完全不碰根目錄資產

set -euo pipefail

DEST=""
DRY_RUN=0
PRUNE=0
NO_BACKUP=0
CLAUDE_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=1 ;;
    --prune)       PRUNE=1 ;;
    --no-backup)   NO_BACKUP=1 ;;
    --claude-only) CLAUDE_ONLY=1 ;;
    -*)            echo "未知選項: $arg" >&2; exit 1 ;;
    *)             DEST="$arg" ;;
  esac
done

if [ -z "$DEST" ]; then
  echo "用法: $0 <目標專案路徑> [--dry-run] [--prune] [--no-backup] [--claude-only]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- 分類設定 ----
SYNC_CLAUDE_DIRS=(agents commands rules skills hooks guides output-styles plugins templates ui scripts)
SYNC_CLAUDE_FILES=(statusline.sh statusline-debug.sh settings.json README.md)
# 根目錄的 scripts/ 與 .mcp.json.*.example 刻意不同步：專案有自己的 scripts/，
# 模板的維護腳本混進去只會讓使用者每次手動刪；mcp 範例只在開新專案時有用（copy-template 帶）。
# 目標端已經有的也不刪——可能是使用者自己的檔案。update-template.ps1 要一致
# CLAUDE_TEMPLATE.md 已廢除（初始化狀態改看 taskmaster-data/project.json），不再同步。
# 迴圈用 ${arr[@]+"${arr[@]}"}：bash 3.2（macOS 內建）在 set -u 下展開空陣列會直接中止，
# 這份清單哪天刪到只剩零個就會踩到
SYNC_ROOT_FILES=(.gitattributes)
# SEED：只在目標「不存在」時建立，永不覆寫。
# 這兩份檔案專案會自己加規則（.gitignore 加自家建置產物、.worktreeinclude 加自家秘密檔），
# 而 update-template 的備份只包 .claude/，根目錄檔案沒備份 —— 覆寫等於無備份的破壞。
SEED_ROOT_FILES=(.worktreeinclude)
MERGE_CLAUDE_DIRS=(context coordination)
# rsync 不會幫你補執行位——來源的 mode 才是權威。所有 .sh 在 repo 裡都是 100755
# （`git update-index --chmod=+x`），所以 clone/pull 下來就有執行位，
# 目標端不需要 chmod。若目標端曾手動 chmod 過，rsync 會把 mode 一起同步回來。
PRESERVE_NOTE=("settings.local.json" "taskmaster-data/" "sessions/" "logs/" "qa-history/" "worktrees/" "(root) .mcp.json / .env")

# ---- 驗證 ----
if [ ! -d "$DEST" ]; then
  echo "❌ 目標資料夾不存在: $DEST" >&2
  echo "   若要開新專案，請改用 copy-template.sh" >&2
  exit 1
fi
DEST="$(cd "$DEST" && pwd)"
if [ "$DEST" = "$SOURCE" ]; then
  echo "❌ 目標不能是模板本身" >&2
  exit 1
fi
if [ ! -d "$DEST/.claude" ]; then
  echo "⚠️  目標沒有 .claude 目錄，看起來不是既有專案。若要從零建立請用 copy-template.sh" >&2
  read -r -p "仍要繼續？[y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }
fi

# ---- 備份 ----
if [ "$DRY_RUN" -eq 0 ] && [ "$NO_BACKUP" -eq 0 ] && [ -d "$DEST/.claude" ]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$DEST/.claude-backups"
  mkdir -p "$BACKUP_DIR"
  BACKUP="$BACKUP_DIR/claude-backup-$TS.tar.gz"
  echo "🛟 備份目標 .claude → $BACKUP"
  tar -czf "$BACKUP" -C "$DEST" .claude
fi

# ---- rsync 包裝（無 rsync 時 fallback 到 cp）----
have_rsync=0; command -v rsync >/dev/null 2>&1 && have_rsync=1

sync_dir() {  # $1=src $2=dst $3=mode(mirror|additive) $4=不同步的頂層子目錄名（選填）
  local src="$1" dst="$2" m="$3" skip="${4:-}"
  [ -d "$src" ] || return 0
  mkdir -p "$dst"
  if [ "$have_rsync" -eq 1 ]; then
    local flags=(-a)
    [ "$DRY_RUN" -eq 1 ] && flags+=(-n -v)
    [ "$m" = "mirror" ] && [ "$PRUNE" -eq 1 ] && flags+=(--delete)
    # 只用 --exclude、不加 --delete-excluded：目標端既有的被排除目錄原樣留著
    [ -n "$skip" ] && flags+=(--exclude="/$skip/")
    rsync "${flags[@]}" "$src/" "$dst/"
  else
    [ "$DRY_RUN" -eq 1 ] && { echo "   [dry] $dst/"; return 0; }
    local e
    for e in "$src"/* "$src"/.[!.]*; do
      [ -e "$e" ] || continue
      [ -n "$skip" ] && [ "$(basename "$e")" = "$skip" ] && continue
      cp -a "$e" "$dst/"
    done
  fi
}

copy_file() {  # $1=src $2=dst
  local src="$1" dst="$2"
  [ -f "$src" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then echo "   [dry] $dst"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  # -p 才會帶 mode 過去。裸 `cp -f` 覆寫既有檔案時保留的是**目標端**的權限，
  # 所以 statusline.sh 的執行位會傳不過去（sync_dir 走 rsync -a 沒這個問題）。
  cp -pf "$src" "$dst"
}

# ---- 執行 ----
MODE="SYNC（不刪除）"
[ "$PRUNE" -eq 1 ] && MODE="SYNC + PRUNE"
[ "$DRY_RUN" -eq 1 ] && MODE="DRY-RUN（不寫入）"
[ "$CLAUDE_ONLY" -eq 1 ] && MODE="$MODE · CLAUDE-ONLY"

echo ""
echo "🔄 更新模板資產 [$MODE]"
echo "   來源: $SOURCE"
echo "   目標: $DEST"
[ "$CLAUDE_ONLY" -eq 1 ] && echo "   範圍: 僅 .claude/（跳過根目錄資產）"
echo ""

echo "▶ SYNC 模板目錄..."
for d in "${SYNC_CLAUDE_DIRS[@]}"; do
  skip=""
  # hooks/tests/ 是模板自己的測試，不同步；目標端已有的不刪（專案裡的破壞性操作）。
  # copy-template.{sh,ps1} 的排除、update-template.ps1 要一致
  [ "$d" = "hooks" ] && skip="tests"
  sync_dir "$SOURCE/.claude/$d" "$DEST/.claude/$d" mirror "$skip"
done
for t in hooks/tests tests; do
  [ -d "$DEST/.claude/$t" ] && echo "   ℹ  .claude/$t/ 是模板自己的測試，已不再同步；可自行刪除"
done

echo "▶ SYNC 模板檔案..."
for f in "${SYNC_CLAUDE_FILES[@]}"; do copy_file "$SOURCE/.claude/$f" "$DEST/.claude/$f"; done
if [ "$CLAUDE_ONLY" -eq 0 ]; then
  for f in ${SYNC_ROOT_FILES[@]+"${SYNC_ROOT_FILES[@]}"}; do copy_file "$SOURCE/$f" "$DEST/$f"; done
else
  echo "   ⏭  跳過根目錄檔案: ${SYNC_ROOT_FILES[*]+"${SYNC_ROOT_FILES[*]}"}"
fi

echo "▶ SEED 根目錄檔案（只補缺少的，永不覆寫）..."
for f in "${SEED_ROOT_FILES[@]}"; do
  if [ -e "$DEST/$f" ]; then
    echo "   ⏭  已存在，跳過: $f"
  elif [ "$DRY_RUN" -eq 1 ]; then
    echo "   [dry] $DEST/$f"
  else
    cp -f "$SOURCE/$f" "$DEST/$f" && echo "   ✚ 已建立: $f"
  fi
done

# .gitignore 不能整份覆寫（專案自己加過規則、根目錄檔案沒備份），但模板新增的短命狀態檔
# （.last-verify、.merge-round-open…）不補進去的話會被 commit。所以只做一件事：
# 模板 .gitignore 裡 `.claude/taskmaster-data/` 開頭的行，目標沒有的才接在檔尾。
# 既有的行一行都不動、不排序、不去重；換行符照目標原本的（CRLF 就補 CRLF）。update-template.ps1 要一致
echo "▶ 補 .gitignore 的執行時短命狀態（只補缺少的行，不動既有的）..."
if [ "$CLAUDE_ONLY" -eq 1 ]; then
  echo "   ⏭  --claude-only：跳過"
elif [ -f "$SOURCE/.gitignore" ]; then
  GI="$DEST/.gitignore"
  GI_HAVE=/dev/null; [ -f "$GI" ] && GI_HAVE="$GI"
  # 用 FILENAME 分辨兩個檔，不用 NR == FNR：目標沒有 .gitignore 時第一個檔是空的 /dev/null，
  # NR == FNR 會在整份模板 .gitignore 上成立，結果什麼都不補
  GI_MISSING=$(awk 'FILENAME == ARGV[1] { sub(/[ \t\r]+$/, ""); have[$0] = 1; next }
                    { sub(/[ \t\r]+$/, "") }
                    /^\.claude\/taskmaster-data\// && !($0 in have) && !seen[$0]++' "$GI_HAVE" "$SOURCE/.gitignore")
  if [ -z "$GI_MISSING" ]; then
    echo "   ✓ 已齊全"
  elif [ "$DRY_RUN" -eq 1 ]; then
    printf '   [dry] 會補進 .gitignore：%s\n' "$(printf '%s' "$GI_MISSING" | tr '\n' ' ')"
  else
    GI_NL=$'\n'
    # 用 tr 找 CR：Git Bash 的 grep 認 $'\r$' 不可靠
    [ -f "$GI" ] && [ -n "$(tr -cd '\r' < "$GI" | head -c 1)" ] && GI_NL=$'\r\n'
    {
      # 檔尾沒有換行就先補一個，免得第一行接到別人的規則後面
      [ -s "$GI" ] && [ -n "$(tail -c 1 "$GI")" ] && printf '%s' "$GI_NL"
      printf '%s# 執行時短命狀態（update-template 補上；理由見模板的 .gitignore）%s' "$GI_NL" "$GI_NL"
      printf '%s\n' "$GI_MISSING" | while IFS= read -r l; do printf '%s%s' "$l" "$GI_NL"; done
    } >> "$GI"
    printf '   ✚ 已補 %s 行：%s\n' "$(printf '%s\n' "$GI_MISSING" | wc -l | tr -d ' ')" "$(printf '%s' "$GI_MISSING" | tr '\n' ' ')"
  fi
fi

echo "▶ MERGE 骨架目錄（保留執行資料）..."
# 只補「骨架檔」：README.md、_*_TEMPLATE.md、以及各 area 的目錄與 .gitkeep。
#
# 為什麼不能用 sync_dir additive：那是 rsync -a 整包複製，會把**模板 repo 自己**
# 累積的 agent 報告（context/quality/*.md 等）灌進使用者專案。骨架是模板資產，
# 報告是專案資料，兩者必須分開。與 copy-template.{sh,ps1} 的後置處理同一套規則。
for d in "${MERGE_CLAUDE_DIRS[@]}"; do
  src="$SOURCE/.claude/$d"
  [ -d "$src" ] || continue

  # 目錄結構（含 _archive）先補齊，但不搬任何內容
  while IFS= read -r dir; do
    rel="${dir#"$src"/}"
    [ "$dir" = "$src" ] && rel=""
    target="$DEST/.claude/$d${rel:+/$rel}"
    if [ "$DRY_RUN" -eq 1 ]; then
      [ -d "$target" ] || echo "   [dry] mkdir $target"
    else
      mkdir -p "$target"
    fi
  done < <(find "$src" -type d 2>/dev/null)

  # 骨架檔逐檔覆寫
  while IFS= read -r f; do
    rel="${f#"$src"/}"
    copy_file "$f" "$DEST/.claude/$d/$rel"
  done < <(find "$src" -type f \( -name 'README.md' -o -name '_*.md' -o -name '.gitkeep' \) 2>/dev/null)
done

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "✅ DRY-RUN 完成（未寫入任何檔案）"
else
  echo "✅ 模板更新完成"
fi
echo ""
echo "🔒 以下專案紀錄完全未被更動："
for p in "${PRESERVE_NOTE[@]}"; do echo "     - $p"; done
echo "     - (root) scripts/、.mcp.json.*.example（模板不再同步這兩者）"
[ "$CLAUDE_ONLY" -eq 1 ] && echo "     - (root) 所有根層檔案（CLAUDE.md / .gitignore / .gitattributes 等）"
echo ""
echo "🧹 舊版同步過來的 scripts/update-template.*、copy-template.*、check-counts.sh"
echo "   與 .mcp.json.*.example 若不需要可手動刪除（本腳本不會刪，避免誤刪專案自己的檔案）"
echo "   （check-counts.sh 已搬到 .claude/scripts/，會隨 .claude/ 一起同步）"
echo "🧹 根目錄的 CLAUDE_TEMPLATE.md 已廢除，可直接刪除"
echo "   （初始化狀態改看 .claude/taskmaster-data/project.json，留著它不會再有任何作用）"
echo ""
if [ "$DRY_RUN" -eq 0 ] && [ "$NO_BACKUP" -eq 0 ]; then
  echo "🛟 如需還原：解壓 .claude-backups/ 內最新的 tar.gz 覆蓋回 .claude/"
fi
if [ "$DRY_RUN" -eq 0 ]; then
  echo ""
  echo "👉 下一步：到目標專案開 Claude Code 跑一次 /task-status"
  echo "   若 wbs.md 還是舊版面（沒有「現況」區），它會提議轉換成新版面（一次性遷移，長內容搬出不丟資料）"
  echo "   專案圖解在開 session 時自動產生，/task-status 最後一行印畫面路徑；"
  echo "   地圖從程式碼掃出，沒有架構文件也畫得出來；要補 brief、PRD、架構文件時跑 /docs-init"
fi
echo ""
