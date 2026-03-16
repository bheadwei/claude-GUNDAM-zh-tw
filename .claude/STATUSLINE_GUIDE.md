# StatusLine 自訂指南

> 檔案位置：`.claude/statusline.sh`

---

## 運作原理

```
Claude Code 每次互動時
    │
    │  stdin 傳入 JSON（model、context、session、cwd）
    ▼
statusline.sh 解析 + 格式化
    │
    │  stdout 回傳格式化字串
    ▼
Claude Code 渲染到終端底部
```

StatusLine 不是即時更新，而是**每次你送出訊息或收到回覆時刷新**。

---

## 目前顯示格式

```
Opus 4.6 (1M context) │ 26% (266k/1.0m) │ project-name (main*) │ 15m │ ◑ default
current ●●●○○○○○○○  28% ⟳ 19:00
weekly  ●●●●●●●●○○  79% ⟳ 03/23 10:00
extra   ○○○○○○○○○○ $0.00/$50.00
```

**第一行：** 模型名 │ Context 使用率 │ 工作目錄 (Git 分支) │ Session 時間 │ Effort
**第二行起：** Rate Limit（5 小時 / 7 天 / 額外用量）

---

## 修改方式

### 1. 顏色

在腳本開頭的 `Colors` 區段，格式為 `\033[38;2;R;G;Bm`：

```bash
# 目前值
blue='\033[38;2;0;153;255m'      # 模型名稱
green='\033[38;2;0;175;80m'      # 低使用率
cyan='\033[38;2;86;182;194m'     # 目錄名稱
white='\033[38;2;220;220;220m'   # 一般文字
yellow='\033[38;2;230;200;0m'    # 中使用率
orange='\033[38;2;255;176;85m'   # 高使用率
red='\033[38;2;255;85;85m'       # 極高使用率
magenta='\033[38;2;180;140;255m' # Effort high
dim='\033[2m'                    # 淡化
reset='\033[0m'                  # 重置
```

**修改範例 — 把模型名改成綠色：**
```bash
blue='\033[38;2;0;200;100m'
```

**顏色對照（常用 RGB）：**

| 顏色 | R | G | B |
|------|---|---|---|
| 紅 | 255 | 85 | 85 |
| 橘 | 255 | 176 | 85 |
| 黃 | 230 | 200 | 0 |
| 綠 | 0 | 175 | 80 |
| 青 | 86 | 182 | 194 |
| 藍 | 0 | 153 | 255 |
| 紫 | 180 | 140 | 255 |
| 白 | 220 | 220 | 220 |
| 灰 | 128 | 128 | 128 |

---

### 2. 分隔符

```bash
# 目前值
sep=" ${dim}│${reset} "

# 其他選擇
sep=" ${dim}|${reset} "        # 普通 pipe
sep=" ${dim}·${reset} "        # 中點
sep="  "                        # 純空格
sep=" ${dim}/${reset} "        # 斜線
sep=" ${dim}»${reset} "        # 箭頭
```

---

### 3. 進度條

在 `build_bar` 函式中修改 `filled_str` 和 `empty_str`：

```bash
# 目前值
for ((i=0; i<filled; i++)); do filled_str+="●"; done
for ((i=0; i<empty; i++)); do empty_str+="○"; done

# 方塊風格
for ((i=0; i<filled; i++)); do filled_str+="█"; done
for ((i=0; i<empty; i++)); do empty_str+="░"; done

# ASCII 風格
for ((i=0; i<filled; i++)); do filled_str+="="; done
for ((i=0; i<empty; i++)); do empty_str+="-"; done

# 方形風格
for ((i=0; i<filled; i++)); do filled_str+="■"; done
for ((i=0; i<empty; i++)); do empty_str+="□"; done
```

**進度條寬度：** 搜尋 `bar_width=10`，改為想要的格數。

---

### 4. 第一行元素

在 `# Build line 1` 區段，可以調整順序、刪減元素：

```bash
# 目前順序
line1="${blue}${model_name}${reset}"               # 1. 模型名
line1+="${sep}"
line1+="${pct_color}${pct_used}%${reset} ..."      # 2. Context %
line1+="${sep}"
line1+="${cyan}${dirname}${reset}"                  # 3. 目錄名
# if git_branch → 4. Git 分支
# if session_duration → 5. Session 時間
line1+="${sep}"
# case effort → 6. Effort 指示
```

**刪除 Session 時間：** 把以下區塊註解掉
```bash
# if [ -n "$session_duration" ]; then
#     line1+="${sep}"
#     line1+="${white}${session_duration}${reset}"
# fi
```

**刪除 Effort 指示：** 把 `case "$effort"` 整個區塊註解掉

**只顯示 % 不顯示 token 數：**
```bash
# 目前
line1+="${pct_color}${pct_used}%${reset} ${dim}(${used_tokens}/${total_tokens})${reset}"

# 精簡版
line1+="${pct_color}${pct_used}%${reset}"
```

---

### 5. Effort 指示符號

```bash
# 目前值
case "$effort" in
    high)   line1+="${magenta}● high${reset}" ;;
    medium) line1+="${dim}◑ medium${reset}" ;;
    low)    line1+="${dim}◔ low${reset}" ;;
    *)      line1+="${dim}◑ default${reset}" ;;
esac

# 方括號風格
    high)   line1+="${magenta}[H]${reset}" ;;
    medium) line1+="${dim}[M]${reset}" ;;
    low)    line1+="${dim}[L]${reset}" ;;

# emoji 風格（macOS/某些 Linux 終端）
    high)   line1+="🔥 high" ;;
    medium) line1+="⚡ medium" ;;
    low)    line1+="🌙 low" ;;
```

---

### 6. Rate Limit 區段

**修改標籤：**
```bash
# 目前
rate_lines+="${white}current${reset} ..."
rate_lines+="${white}weekly${reset}  ..."
rate_lines+="${white}extra${reset}   ..."

# 縮寫
rate_lines+="${white}5h${reset} ..."
rate_lines+="${white}7d${reset} ..."
rate_lines+="${white}ex${reset} ..."
```

**修改重置符號：**
```bash
# 目前
${dim}⟳${reset}

# 替代
${dim}reset${reset}
${dim}@${reset}
${dim}→${reset}
```

**完全隱藏 Rate Limit：** 把輸出區段最後一行註解掉
```bash
printf "%b" "$line1"
# [ -n "$rate_lines" ] && printf "\n%b" "$rate_lines"
```

**隱藏 Extra 用量：** 把 `extra_enabled` 整個 if 區塊註解掉

---

### 7. 使用率顏色閾值

在 `color_for_pct` 函式中調整：

```bash
# 目前值
if [ "$pct" -ge 90 ]; then printf "$red"       # >= 90% 紅色
elif [ "$pct" -ge 70 ]; then printf "$yellow"   # >= 70% 黃色
elif [ "$pct" -ge 50 ]; then printf "$orange"   # >= 50% 橘色
else printf "$green"                             # < 50% 綠色
fi

# 更寬鬆
if [ "$pct" -ge 95 ]; then printf "$red"
elif [ "$pct" -ge 80 ]; then printf "$yellow"
elif [ "$pct" -ge 60 ]; then printf "$orange"
else printf "$green"
fi
```

---

### 8. Rate Limit 快取時間

```bash
# 目前值（60 秒查一次 API）
cache_max_age=60

# 更頻繁（30 秒）
cache_max_age=30

# 更省流量（5 分鐘）
cache_max_age=300
```

---

## 預設樣式範本

### 精簡風格

```
Opus 4.6 | 26% | project (main*) | [M]
```

做法：移除 token 數、session 時間、整個 rate limit 區段。

### 完整風格（目前）

```
Opus 4.6 (1M context) │ 26% (266k/1.0m) │ project (main*) │ 15m │ ◑ default
current ●●●○○○○○○○  28% ⟳ 19:00
weekly  ●●●●●●●●○○  79% ⟳ 03/23 10:00
```

### 方塊風格

```
Opus 4.6 │ 26% (266k/1.0m) │ project (main*) │ 15m │ [M]
5h █░░░░░░░░░  12%  reset 19:00
7d ████████░░  79%  reset 03/23
```

做法：進度條改 `█░`、標籤改 `5h/7d`、重置符號改 `reset`、effort 改 `[M]`。

---

## 修改後生效

改完 `statusline.sh` 後，**不需要重啟 Claude Code**。下次互動時會自動使用新腳本。

## 除錯

手動測試腳本輸出：

```bash
echo '{"model":{"display_name":"Test"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":260000}},"cwd":"'$(pwd)'","session":{}}' | bash .claude/statusline.sh
```
