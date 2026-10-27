# skill-curator — WBS 新增「負責」欄（2026-10-27 11:32）

來源規格：使用者桌面 `SYNC.md`（來源專案的變更說明）。附檔 `owner-column.patch`、改好的 `wbs.template.md` 都不在桌面，照「要改的檔案」表手動套。分支 `feat/wbs-owner-column`，沒有 commit。

## 版面

```
任務表：| # | 任務 | 狀態 | 優先 | 依賴 | 預估 | 負責 | 連結 |
歸檔表：| # | 任務 | 狀態 | 優先 | 依賴 | 預估 | 實際 | 負責 | 連結 |
```

## 改了哪些檔

| 檔案 | 改了什麼 |
|---|---|
| `.claude/templates/wbs.template.md` | 第 1 節的兩張範例表改成 8 欄（人名用 alice／bob 佔位）；第 2 節欄位表加一列「負責」；第 5 節歸檔表改成 9 欄，並加上「負責原樣帶過來」與「每節自帶表頭、加欄前歸檔的舊節不回填、讀檔依表頭取欄」。注意：這個模板的欄位表在第 2 節、不是 SYNC.md 寫的第 3 節（模板的章節編號和來源專案不同） |
| `.claude/commands/task-add.md` | 寫回規則：負責欄填 `—`，使用者指名時才填；步驟 1：掃 archive 編號要依各節表頭找 `#` 欄 |
| `.claude/commands/task-status.md` | 歸檔第 2 步：負責欄原樣帶過去，舊節不回填；舊格式轉換第 4 步：負責欄一律 `—`；`--detailed` 讀 archive 時依表頭取欄 |
| `.claude/commands/time-log.md` | 第 4 步：兩個檔都依表頭欄名找欄位（SYNC 點名的讀檔指令） |
| `.claude/commands/task-init.md` | 新建任務時負責欄填 `—`（SYNC 沒列，grep 時找到的寫入點） |
| `.claude/commands/verify.md` | ad-hoc 補登那一行負責欄填 `—`（SYNC 沒列，grep 時找到的寫入點） |
| `.claude/skills/project-docs/templates/16_wbs_development_plan_template.md` | 職責分工表加上「負責」；範例小標改成「負責欄、連結欄」；範例列補 `alice`；補一句填寫規則 |
| `.claude/hooks/tests/run-tests.sh` | 新增 `wbs_doc8` 測試資料和 5 條斷言：超長負責格標成「負責」、不被誤標成「連結」、短負責格不提醒、超長狀態格仍標「狀態」、長網址不誤報。舊的 7 欄 `wbs_doc` 刻意保留，繼續測舊版面相容 |
| `.claude/guides/WORKFLOW.md`、`.claude/hooks/tests/README.md` | 測試案例數 647→652 |

## grep 找到、判定不用改的地方

| 位置 | 理由 |
|---|---|
| `.claude/hooks/post-write.sh` 的格子長度檢查 | 它把分隔線前一行當表頭（`.hdr = (.prev \| cells)`），用欄名取值（`$h[$i]`）；只有 `$c[0]` 是用位置取的，那是 `#` 欄，永遠在第一欄。新加的 8 欄測試證實運作正常 |
| `.claude/statusline.sh` | 只讀 `.current-task` 和 plan 的 frontmatter，不解析 WBS 表格 |
| `.claude/hooks/session-start.sh`、`user-prompt-submit.sh` | 只檢查 `wbs.md` 存不存在 |
| `scripts/check-counts.sh`、`scripts/update-template.{sh,ps1}` | 不解析 WBS 表格；update-template 只印一行說明文字 |
| `/task-next`、`/plan`、`planner`、`plan-format` skill | 只用欄名（「狀態」「依賴」「連結」）描述，沒寫死欄位位置或欄數 |
| `task-add.md` 步驟 4 的預覽表 | 那是給使用者看的預覽，不是 WBS 格式。照 SYNC.md 的規則，負責欄預設 `—`，不需要在預覽表加欄 |

## `.gitignore`

照指示沒有套 SYNC.md 的白名單建議。已確認：`git check-ignore -v .claude/templates/wbs.template.md` 回傳 exit 1，表示這個檔沒有被忽略。

## 驗證

- hook 測試：`run-tests.sh` 通過 652、失敗 0
- 計數檢查：`check-counts.sh --tests 652` 共 698 項，有 1 項不一致——根目錄 `README.md:93` 還寫 647。root 不在 skill-curator 的寫入範圍內，交給主模型改
- `CLAUDE.md:21` 也寫「647 個 hook 測試」。check-counts 不檢查這一處，但數字一樣過期了
- 行為驗證：**沒有驗證**模型實際跑 `/task-add`、`/task-status` 時會不會照新規則填負責欄。只驗了格式和接線

## `.skill-impact`

沒有清除。裡面那些項目（post-write.sh、agent-inflight.sh 等）是之前的 hook 變更累積下來的，不屬於這個任務，這次也沒有盤點它們對 skill 的影響。
