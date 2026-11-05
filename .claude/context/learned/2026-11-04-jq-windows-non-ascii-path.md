---
date: 2026-11-04
title: Windows 的 jq 用旗標讀含中文的絕對路徑會開不了檔
files:
  - ".claude/hooks/*.sh"
  - ".claude/hooks/lib/*.sh"
  - ".claude/scripts/*.sh"
symptom: 'jq 回「Could not open … Unknown error」，只在主 checkout 路徑含非 ASCII 字元時發生（例如 D:\模板\…）。overview.sh 因此永遠產不出地圖，只會留下 .last-error'
root-cause: Windows 版 jq 1.8.1 用 --rawfile、--slurpfile、-f 讀含非 ASCII 字元的絕對路徑時，會開不了檔。同樣的檔改用位置參數傳入，或改用相對路徑都能讀；路徑只含空格也沒問題。
guard: hook 或腳本要用 jq 的 --rawfile／--slurpfile／-f 讀 repo 裡的檔時，先把檔案複製到暫存目錄並改成 ASCII 檔名，在暫存目錄裡用相對檔名呼叫 jq（overview.sh 的 generate()／run_once() 就是這樣做）。測試要涵蓋主 checkout 路徑含中文與空格的情況，這個模板本身就放在這種路徑。
severity: high
---

2026-11-04 在專案圖解階段 3 的修正中，由新加的中文路徑測試抓到（commit a4eb4dd）。
階段 3 原本的 47 個測試都在 ASCII 路徑的沙箱裡跑，所以都通過，沒有發現這個問題。
