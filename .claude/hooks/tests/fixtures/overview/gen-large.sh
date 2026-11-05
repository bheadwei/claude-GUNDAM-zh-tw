#!/bin/bash
# gen-large.sh — 產生 N 個帶 import 的 .py／.ts，分散在 60 個目錄（src/m00 … src/m59）
# 用法：gen-large.sh <檔案數> <目標目錄>
# 只寫檔案，不 git init。不放任何設定檔，所以 git ls-files 的數量恰好是 N。

usage() { printf '用法：%s <檔案數> <目標目錄>\n' "${0##*/}" >&2; exit 2; }
[ $# -eq 2 ] || usage
[[ $1 =~ ^[1-9][0-9]*$ ]] || usage
N=$1
mkdir -p "$2" || exit 1
DEST=$(cd "$2" && pwd) || exit 1
DIRS=60

for ((d = 0; d < DIRS; d++)); do printf -v dir 'm%02d' "$d"; mkdir -p "$DEST/src/$dir"; done

for ((i = 0; i < N; i++)); do
    d=$(( i % DIRS )); ext=py; [ $(( (i / DIRS) % 2 )) -eq 1 ] && ext=ts
    j=$(( (i * 7 + 13) % N ))
    if [ $(( (j / DIRS) % 2 )) -ne $(( (i / DIRS) % 2 )) ]; then
        if [ $(( j + DIRS )) -lt "$N" ]; then j=$(( j + DIRS )); else j=$(( j - DIRS )); fi
    fi
    [ "$j" -ge 0 ] || j=$i
    jd=$(( j % DIRS ))
    printf -v dir 'm%02d' "$d"; printf -v jdir 'm%02d' "$jd"
    if [ "$ext" = py ]; then
        printf 'from src.%s.f%d import value as other\n\nvalue = %d\n' "$jdir" "$j" "$i"
    else
        printf "import { value as other } from '../%s/f%d'\n\nexport const value = %d\n" "$jdir" "$j" "$i"
    fi > "$DEST/src/$dir/f$i.$ext"
done
