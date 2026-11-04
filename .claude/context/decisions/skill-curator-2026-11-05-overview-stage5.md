# 專案圖解 — 階段 5（舊專案升級、大小上限、收尾）

- 日期：2026-11-05
- 作者：skill-curator。它在 worktree 裡工作，這份紀錄由主模型落檔。
- 分支：`worktree-agent-ad15930e1cfd2a304`，從 19a35de 開出，commit **f4d4fa2**

## 做了什麼

- **`overview.sh`**
  - `archivedDone`：把 wbs-archive 的 ✅ 和 `plans/archive/` 合起來算，依任務編號去重。對不到模組的任務記在 `archived.unmapped`。
  - 大小上限：
    - changes 每份最多 200 筆，超過的部分依第一層目錄彙總成 `changesRollup`，並標 `truncated`。
    - data.js 超過 `OVERVIEW_MAX_BYTES`（預設 512KB）時，分四級逐步丟資料，每丟一級就加一則 notice。
    - AI 摘要最多 80 字。
  - 沒裝 jq 時：寫出只含 notice 的 data.js。`--actual` 改成 exit 1，不再假裝成功。
  - `--print-path`：找不到架構文件、或架構仍是草稿時，多印一行「提示：」。
- **`index.html`**：補上缺欄位時的處理，顯示彙總列、已歸檔數、未標模組數。檔案 34.5KB。
- **`session-start.sh`**：有 `project.json`、但缺 data.js，或畫面原檔較新時，在背景補產一次。可用 `OVERVIEW=off` 關掉。
- **`task-status.md`**：收到「提示：」時，用 AskUserQuestion 問要不要委派 documentation-specialist 反推架構草稿。
- **`update-template.{sh,ps1}`**：模板 `.gitignore` 裡 `.claude/taskmaster-data/` 開頭、而目標專案還沒有的行，自動補上。不動既有行，換行符跟著目標檔。
- **其他**：
  - 壓力測試新增第 11 題（舊專案的圖解）。
  - 更新 WORKFLOW 的「想看整體長什麼樣」一節，以及 hooks README。

## 跟任務字面不同的地方

1. `.gitignore` 不只補指定的三行，而是補所有缺少的 taskmaster-data 行。以後模板新增狀態檔，不用再改腳本。
2. 「舊專案升級後不必手動就看得到圖」是靠 session-start 補產，不是讓 update-template 去跑產生器。這樣 sh 和 ps1 兩版、以及新 clone 的專案都適用。

## 驗證

- 新增 29 個測試（908 → 937）。
- overview 節 114/114、update-template 節 11/11、session-start 三節 35/35 全部通過。
- ps1 手動測過，輸出與 sh 版逐位元組相同。
- 整套測試沒跑（使用者要求等全部合併後一起跑）。

## 未驗證

- 拿真實舊專案走一整輪：升級 → 開 session → `/task-status` → 反推草稿 → 地圖出現。
- 壓力測試第 11 題。
- 新畫面還沒在瀏覽器裡實際看過。
- 模型收到「提示：」後，會不會真的去問。

## 附帶發現

- full-suite 閘門把 `bash -n run-tests.sh`（只做語法檢查）誤判成跑整套而擋下。

STATUS: DONE_WITH_CONCERNS
