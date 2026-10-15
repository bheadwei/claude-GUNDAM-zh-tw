# skill-curator：WBS 版面收斂為唯一來源（方案 A）＋格子長度提醒

日期：2026-10-15　分支：`feat/wbs-dashboard-format`（未 commit，交主模型審）

## 背景

實際專案的 `wbs.md` 被當工作日誌寫（狀態／備註格塞驗證數據、疑慮、選型理由、IP、SHA），
且模板內有兩套 WBS 格式（`task-init.md` 內嵌範本 vs. 無人引用的 16 號範本，後者 §9 還教「計畫連結放備註欄」）。
使用者已拍板「方案 A」版面並要求收斂成唯一來源。

## 層級判斷（writing-extensions 五層決策表）

| 需求 | 層 | 理由 |
|---|---|---|
| 版面定義 | 檔案範本（`.claude/templates/`，非 skill） | 只在寫 WBS 時由指令讀；不需被「想起來」，指令內文給完整路徑 |
| 格子過長 | **Hook（PostToolUse additionalContext）** | 有機器判斷得出的時機（寫入 wbs.md）。只提醒不擋——擋了會連「先記下來」都做不到 |
| 舊格式轉換 | Command（`/task-status` 節） | 需 AskUserQuestion 與判斷，使用者觸發 |

## 唯一來源邊界

| 內容 | 唯一來源 |
|---|---|
| wbs.md／wbs-archive.md 版面、欄位規則、現況重算、長內容去處 | `.claude/templates/wbs.template.md` |
| 歸檔**程序** | `commands/task-status.md`「WBS 歸檔」節（不變） |
| 舊格式轉換程序 | `commands/task-status.md`「舊格式轉換」節（取代原「Plan 欄回填」） |
| WBS↔Plan 連結同步 | `plan-format` skill「與 WBS 的雙向同步」 |

已知的第二份：`post-write.sh` 訊息內的去處對照是範本第 4 節的**簡短版**，兩處都標註了要同步。

## 裁決

| 對象 | 裁決 | 理由 |
|---|---|---|
| `task-init.md` 步驟 5 內嵌範本 | Merge into `templates/wbs.template.md`（整段範本搬走，留三條建立時要點＋指標） | 與 16 號範本並存兩套格式；內嵌副本是漂移源 |
| `16_wbs_development_plan_template.md` | Improve：刪除 §3 工時樹、工作包統計、§4 詳細任務分解、§5 進度摘要中的整體進度、§6 風險表、§7 狀態欄；保留 Pitch／Appetite／角色／節奏；新增高階模組對照表（編號組↔里程碑）；§9 備註欄範例改成連結欄 | 任務表與 wbs.md 重疊，§9 教的是已廢除的備註欄寫法 |
| `/task-status`「Plan 欄回填」 | Merge into 新「舊格式轉換」節（回填成為其步驟 4） | 新版面同時取代 Plan 與備註欄，兩次遷移併成一次 |

## 驗證

- `scripts/check-counts.sh`：313 項全部一致；`--tests 364`：316 項中 1 項不一致（根 `README.md` 仍寫 356，不在寫入範圍）
- `.claude/hooks/tests/run-tests.sh`：通過 364・失敗 0（新增 8 個 WBS 格子長度案例；WORKFLOW.md 與 hooks/tests/README.md 的案例數已同步為 364）
- **未驗證行為改變**：沒有跑 skill-compliance，也沒有在真實專案驗證模型是否照範本寫、是否每次重算「現況」

## 未處理／疑慮

- 根目錄 `README.md` 測試案例數 356 → 364；第 70 行（「Plan 欄」回填提示）與第 113 行（`templates/` 寫「僅 /task-init 讀」）已過時——不在本 agent 寫入範圍
- 「現況」重算是自律（指令內文），沒有機器檢查；長度提醒只看格子，不看現況數字是否對得上
