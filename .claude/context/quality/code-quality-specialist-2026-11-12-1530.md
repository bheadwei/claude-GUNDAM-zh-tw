---
agent: code-quality-specialist
date: 2026-11-12
scope: "專案地圖改版 階段 3（git diff 9858cea..f3046f8，worktree-agent-a4fd8188db58d6d0d）"
status: PASS
---

# 階段 3 審查：agent 事件記錄 hook

（審查者在 worktree 內寫不進主 checkout，由主模型依其回覆落檔。）

結論：PASS。CRITICAL 0、HIGH 0、MEDIUM 2、LOW 3。沒有測試缺口，不建 handoff。
審查者只在 /tmp 臨時沙箱手動跑過一次 hook 確認 jq 可編譯、寫出一行、exit 0 無 stdout。

## 發現
- [MEDIUM-1] agent-events.sh:142-146：`overview.sh --live` 在階段 6 前不存在（overview.sh:85-104 沒有此參數，:142 `WORK_ROOT="${1:-$PWD}"` 會把 `--live` 當路徑）。有 project.json 的專案在階段 3 合併後、階段 6 前每 2 秒觸發一次，結果未驗證。建議加過渡守衛或與階段 6 一起合併。模板 repo 沒有 project.json 不受影響。（信心約 60%）
- [MEDIUM-2] run-tests.sh:5053-5260：沒有斷言 settings.json 中每條 agent-events 接線都是 `async: true`。
- [LOW-1] agent-events.sh:84-96：description 與 AskUserQuestion 題目是模型寫的自由文字，原樣進 act/text（有長度上限），符合 ADR 白名單。
- [LOW-2] agent-events.sh:113：`printf >>` 在 MSYS 非嚴格原子；整行 <1024 bytes 一次寫，已是最小風險，不用改。
- [LOW-3] agent-events.sh:106：`src` 上限 60 字，過長 worktree 資料夾名會截斷，階段 6 比對可能對不上。

## 逐項確認
1. 敏感資料：通過。只寫白名單欄位；不讀 prompt、tool_input 整體、old/new_string、content、last_assistant_message、permission_suggestions；Bash 第一個詞不符 `^[A-Za-z0-9_.+-]+$` 記「跑指令」；checkout 外絕對路徑 file 清空。
2. hook 安全：通過。無輸出、恆 exit 0；各降級與逃生門不寫檔；背景觸發雙層 fork 不阻塞不留殭屍；`.live-at` 競態最壞多觸發一次。
3. settings.json：通過。diff 無刪除行、不動既有順序、不動 permissions；全部 async:true。
4. jq 1.6 相容：通過。無保留字變數名，程式在單引號內，無中文檔名路徑問題。
5. 狀態檔位置：`.live-at`／`.live-dirty` 在 MAIN_CLAUDE overview/，與邊界表一致。
6. rotate_log 3000 與 README 一致，測試驗 3500→3000。
7. 與 ADR 的差異（EPOCHREALTIME 退路、2 次 jq、第四步縮短、第一個詞規則）皆可接受。
8. 新測試節以哨兵字串反向斷言，確實驗到行為；唯一缺口是 MEDIUM-2。

STATUS: DONE_WITH_CONCERNS
