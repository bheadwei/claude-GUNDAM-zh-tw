---
description: 切換 statusline 能量條樣式（打指令直接問答選一個，立即生效不需重啟）。
---

# /statusline-style — 切換能量條樣式

打 `/statusline-style` 就**直接進入問答**選樣式，不需要記任何參數。選完寫入 `.claude/taskmaster-data/statusline.conf`，statusline 下次刷新即生效。

配色固定為「綠 → 橙 → 黃 → 紅」（越滿越警示），不需選。

## 執行步驟（每次都這樣做）

### 1. 先渲染真實彩色預覽
跑下方腳本，讓使用者看到 6 種樣式的實際外觀（AskUserQuestion 預覽框無法上色，故用終端機）：

```bash
g=$'\033[38;2;0;175;80m'; d=$'\033[2m'; n=$'\033[0m'
bar(){ local st=$1 p=${2:-65} w=${3:-12}; local fl=$((p*w/100)) em=$((w-fl)) f="" e="" i
  case $st in
   dots) for((i=0;i<fl;i++));do f+="●";done;for((i=0;i<em;i++));do e+="○";done;printf "${g}${f}${d}${e}${n}";;
   segmented) for((i=0;i<fl;i++));do f+="▰";done;for((i=0;i<em;i++));do e+="▱";done;printf "${d}▕${n}${g}${f}${d}${e}▏${n}";;
   solid) for((i=0;i<fl;i++));do f+="█";done;for((i=0;i<em;i++));do e+="░";done;printf "${d}▐${n}${g}${f}${d}${e}▌${n}";;
   squares) for((i=0;i<fl;i++));do f+="■";done;for((i=0;i<em;i++));do e+="□";done;printf "${g}${f}${d}${e}${n}";;
   braille) for((i=0;i<fl;i++));do f+="⣿";done;for((i=0;i<em;i++));do e+="⣀";done;printf "${d}▕${n}${g}${f}${d}${e}▏${n}";;
   gradient) if [ $fl -ge 1 ];then for((i=0;i<fl-1;i++));do f+="█";done;f+="▓";fi; if [ $em -ge 1 ];then e+="▒";for((i=0;i<em-1;i++));do e+="░";done;fi;printf "${d}▐${n}${g}${f}${d}${e}▌${n}";; esac; }
echo "目前可選樣式（用量 65%）："; for s in dots segmented solid squares braille gradient;do printf "  %-10s " "$s";bar "$s";echo;done
```

### 2. 用 AskUserQuestion 問樣式
一題即可（遵守 `.claude/rules/interactive-qa.md`）。6 種樣式塞不進 4 個選項，故顯示 4 個常用 + 其餘用「Other」輸入名稱：

- 選項（附 preview 形狀）：`segmented`、`solid`、`dots`、`braille`
- 在題目說明：「其餘可選 squares、gradient — 選 Other 直接輸入名稱」
- 合法值：dots / segmented / solid / squares / braille / gradient

### 3. 寫入設定檔
```bash
conf="$CLAUDE_PROJECT_DIR/.claude/taskmaster-data/statusline.conf"
mkdir -p "$(dirname "$conf")"
printf 'bar_style=%s\n' "$SEL_BAR" > "$conf"
echo "✅ 已套用 bar_style=$SEL_BAR（statusline 下次刷新生效）"
```

### 4. 渲染結果確認
跑一次 statusline 把套用後的樣子顯示給使用者（用任意合理的 mock JSON 餵 `bash .claude/statusline.sh`）。

## 樣式一覽

| 值 | 外觀 |
|---|---|
| `dots` | `●●●○○` 圓點 |
| `segmented` | `▕▰▰▱▏` 分段槽（預設） |
| `solid` | `▐██░▌` 實心條+外框 |
| `squares` | `■■■□□` 粗方塊 |
| `braille` | `▕⣿⣿⣀▏` 點陣粒子 |
| `gradient` | `▐██▓▒░▌` 漸層消散 |

## 相關
- `.claude/statusline.sh` — 讀 statusline.conf 的 bar_style 渲染
- `.claude/taskmaster-data/statusline.conf` — 設定檔（gitignore，per-project）
