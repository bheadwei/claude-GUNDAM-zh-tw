# skill-curator：/code-review 第 1～9 項修正（hook 切段、ui-lint、sync-ui-sources）

日期：2026-10-16　分支：feat/frontend-style-library（未 commit）　第 10 項不做（另排重構）

每一項都先寫會失敗的測試、確認紅燈，再修。

| # | 檔案 | 怎麼修 | 測試 |
|---|---|---|---|
| 1 | `hooks/lib/cmd-segments.sh` `cmd_mask_quotes` | 引號外、字開頭的 `#` 到行尾先拿掉（前一字元是行首／空白／`;&\|()` 才算），`$#`、`${#a}`、URL 錨點不算 | run-tests「cmd-segments.sh — 切段邊界」＋ git backup 節 1 條 |
| 2 | 同檔 `cmd_strip_heredoc` | `<<` 之前同一行未配對的 `((` 多於 `))` 就跳過；`<<<` 照舊 | 同上 |
| 5 | 同檔 `cmd_segments`／`cmd_git_subcmd` | 兩者共用一個 awk 函式 `git_sub_index`：`-C -c --git-dir --work-tree --namespace --config-env --attr-source --super-prefix` 跳兩個字；`--exec-path` 等「印完就結束」的回傳沒有子指令（git 2.53 實測） | 同上＋post-bash 合併紀錄 |
| 5' | `hooks/post-bash.sh` 抽 ref | 原本自己再切一次 token（只認 `-C`／`-c`、不認註解），改成直接用 `MP_SEG`（cmd_segments 的輸出）——刪掉第二份切段邏輯 | 同上 |
| 6 | `cmd_strip_heredoc` | 一般 `<<WORD` 結束行一字不差（只去 `\r`）；`<<-WORD` 只去行首 tab | 同上 |
| 3 | `hooks/lib/ui-lint.sh` 動畫等級 | 頁面檔（`app/**/page.*`、`pages/**`、`routes/**/+page.*`，去掉 route group）對應到 `docs/17_frontend_information_architecture.md` 的 snippet 時用單頁等級；對應不到時取專案與各頁中最寬鬆的那級 | run-tests 前端寫入檢查節 9 條 |
| 8 | 同檔路徑排除 | 加 `test/` `tests/` `*fixtures*` `vendor/` `.git/` `*.min.css`；hooks/README.md 改成逐項列出 | 同節 7 條 |
| 9 | `hooks/post-write.sh` | 啟動 ui-lint 前先 `case` 篩副檔名與 `.claude/`（worktree 除外）；完整範圍規則仍只在 ui-lint | 同節 7 條（hooks 複本 + 假 ui-lint 留記號） |
| 4 | `scripts/sync-ui-sources.sh` | 新增 `sha256_many`，批次 hash 走與 `sha256()` 相同的 `shasum -a 256` 退路 | sync test 第 13 情境（造一條只少 sha256sum 的 PATH） |
| 7 | 同檔 | `upstream_status: removed` 且上游檔又出現 → `--apply` 改回 present；內容相同時列在「上游有更新」並標明 | sync test 第 8 情境 5 條 |

驗證：run-tests.sh 529／0（479 → 529）、sync-ui-sources.test.sh 84／0、check-counts --tests 529 全部一致。
測試數已同步：README.md、CLAUDE.md、guides/WORKFLOW.md、hooks/tests/README.md（並補「切段邊界」一列、git backup 22→27）、writing-extensions L118。

留下的漏網（寫在 cmd-segments.sh 檔頭「取捨」）：註解裡的 `<<WORD`、跨行算術式、引號外 `$( )` 內的 `#`。方向都是漏抓、不誤擋。
