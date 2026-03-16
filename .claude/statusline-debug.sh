#!/bin/bash
# 把 Claude Code 傳給 statusline 的原始 JSON 存到檔案，用於除錯
input=$(cat)
echo "$input" > /tmp/statusline-debug.json
# 同時正常執行 statusline
echo "$input" | bash .claude/statusline.sh
