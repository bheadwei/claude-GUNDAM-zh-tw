---
agent: skill-curator
date: 2026-11-03-1400
area: decisions
target: .claude/hooks/session-start.sh、CLAUDE_TEMPLATE.md、scripts/update-template.{sh,ps1}
severity: info
status: resolved
---

# 移除 CLAUDE_TEMPLATE.md 哨兵，初始化狀態只看 project.json

接續 `skill-curator-2026-11-03-1200-update-skip-root-assets.md`（同分支、同樣未 commit）。

## TL;DR
- `session-start.sh` 的初始化判斷改成只看 `.claude/taskmaster-data/project.json`。沒有這個檔就提示 `/task-init`，但模板 repo 本身不提示。有這個檔、也有 `wbs.md`，就提示用 `/task-next` 接續。
- 已用 `git rm` 刪掉 `CLAUDE_TEMPLATE.md`。`task-init.md` 拿掉「刪除哨兵檔」那一步。update-template 不再同步這個檔，結尾會提示可以手動刪。
- 修好的 bug：舊流程中，`/task-init` 完成時會刪掉哨兵，導致「有 WBS → 提示接續」那段永遠跑不到。另外，模板 repo 本身也會被誤判成「尚未初始化」。

## 改了哪些檔

| 檔案 | 位置 | 內容 |
|---|---|---|
| `.claude/hooks/session-start.sh` | 161-172（新增） | 把 `_IS_TEMPLATE_REPO` 的判斷搬到 `CURATION_REMINDERS` 逃生門外面，註解也一起搬過來。原因：關掉維護提醒時，模板 repo 不應該跑出 init 提示 |
| 同上 | 192 | ②③段的註解改成指向上方的判斷 |
| 同上 | 329-390（改寫原本的 323-382） | 外層不再檢查 `CLAUDE_TEMPLATE.md`。沒有 `project.json` 時：模板 repo 直接 `finish`，否則顯示原本的 init banner 和 note。有 `project.json` 時：有 `wbs.md` 就顯示原本的 WBS banner 和 note，最後 `finish`。banner 與 note 的文字都沒改。上方「進行中任務」那段（`.current-task`）沒動 |
| `CLAUDE_TEMPLATE.md` | — | `git rm`。內容裡的「記憶系統規則」已有其他來源：`guides/MECHANISMS.md` 的記憶分層表、`guides/PAUSE_RESUME_GUIDE.md` FAQ 的 Auto-memory 說明。而且 Claude Code 本來就不會自動載入這個檔，所以那段規則從來沒有生效過，刪掉不會少掉任何資訊 |
| `.claude/commands/task-init.md` | 原 238 行 | 刪除步驟 8「刪除根目錄的 `CLAUDE_TEMPLATE.md`」。它是清單最後一項，1-7 的編號不用改。這份檔案沒有其他地方引用它 |
| `scripts/update-template.sh` | 48-51 | `SYNC_ROOT_FILES=(.gitattributes)`，並加上「已廢除」與 bash 3.2 的註解 |
| 同上 | 136、138 | 迴圈和 echo 改用 `${arr[@]+"${arr[@]}"}`。清單哪天刪到一個都不剩時，`set -u` 也不會讓腳本中止 |
| 同上 | 191 | `--claude-only` 的說明拿掉 `CLAUDE_TEMPLATE.md` |
| 同上 | 196-197 | 結尾的手動清理提示加上「`CLAUDE_TEMPLATE.md` 已廢除，可直接刪除」 |
| `scripts/update-template.ps1` | 22、46-47、217、223-224 | 跟 sh 一致：`-ClaudeOnly` 參數說明、`$syncRootFiles = @('.gitattributes')`、跳過時的說明、結尾提示 |
| `README.md` | 原 83 行 | 目錄樹刪掉 `CLAUDE_TEMPLATE.md` 那一行 |
| `.claude/hooks/README.md` | 54 | `session-start.sh` 那一列改成描述新的判斷方式（只看 project.json，模板 repo 不提示） |
| `.claude/hooks/tests/run-tests.sh` | 985-1019（新 section） | 9 條測試：沒有 project.json 時要提示 init；有 project.json 和 wbs、但沒有哨兵時要提示 `/task-next`；有 project.json、沒有 wbs 時兩種都不提示；殘留的哨兵不影響結果；模板 repo 不提示 init（`CURATION_REMINDERS=off` 時也一樣） |
| 同上 | 1037、1046、1051 | 用 copy-template 真的建一個新專案：確認沒有 `CLAUDE_TEMPLATE.md`、會出現 `/task-init` 提示。對照組是補上 `sync-ui-sources.sh` 之後，提示要消失 |
| `scripts/sync-ui-sources.test.sh` | 229-230、237 | `assert_dest` 四份（copy／update × sh／ps1）都加上「沒有 `CLAUDE_TEMPLATE.md`」。update 另外驗證 `.gitattributes` 有同步過去，證明同步清單沒有變成空跑 |
| 同上 | 257-262 | 新增 `--claude-only` 的冒煙測試：exit 0、不碰根目錄檔案、結尾提示已廢除 |

## 決定與理由
- **copy-template.{sh,ps1} 沒有改**：這兩份腳本沒有特別列出 `CLAUDE_TEMPLATE.md`，複製的是來源工作樹的根目錄。哨兵已經 `git rm`，就不會被帶過去，兩份腳本的行為一致。不加排除規則的原因：為一個不存在的檔案加規則只是雜訊；而且純檔名樣式在 rsync 裡會比對任何層級。有測試把關（`sync-ui-sources.test.sh` 四份＋`run-tests.sh` 的真實 copy）。
- **模板 repo 的判斷沿用 `scripts/sync-ui-sources.sh` 存不存在**，不另外發明新訊號。那四份 copy/update 腳本的排除規則已經保證新專案不會有這個檔，也已經有測試。
- **docs-init 也會寫 `project.json`**：沒跑 `/task-init` 而直接跑 `/docs-init` 的專案，也會被判成「已初始化」。我認為這是正確的，因為那個專案已經有規格與專案資訊。

## 沒動的範圍
- `workshop/` 完全沒碰（使用者指示）。`context/`、`sessions/`、`logs/` 的歷史紀錄沒碰，changelog 也沒碰。
- `.claude/ui/` 底下的命中（grep 結果）都跟哨兵無關，沒動。

## 已知未處理
- 「模板 repo 不提示 init」這條測試在舊程式上也會通過，因為沙箱裡沒有哨兵。它只能防新程式退化，證明不了舊 bug 存在。真正打中舊 bug 的是「有 project.json＋wbs.md、沒有哨兵 → `/task-next`」和「沒有 project.json → `/task-init`」，這兩條在舊程式上都會失敗。
- `.skill-impact` 跟上一輪一樣沒有清除：裡面累積的是更早任務的 hook 變更，這一輪沒有審。
- 行為驗證：這次改的是 hook 注入的觸發條件，note 的文字沒動，所以沒有跑 `skill-compliance`。

## 計數同步
- 案例數從 739 改成 751：`.claude/guides/WORKFLOW.md`、`.claude/hooks/tests/README.md`、`README.md`（目錄樹）。這是 check-counts 提示的三處。
- 根目錄 `CLAUDE.md`「改動時的連帶檢查」還寫著「737 個 hook 測試」。check-counts 不檢查這裡，本輪也沒改。

## 驗證
- `bash .claude/hooks/tests/run-tests.sh`：通過 751、失敗 0
- `bash scripts/sync-ui-sources.test.sh`：123 通過、0 失敗（含 ps1 兩份）
- `bash .claude/scripts/check-counts.sh --tests 751`：檢查 698 項，全部一致
- 行為驗證（skill-compliance）：沒跑，原因見上方「已知未處理」

STATUS: DONE_WITH_CONCERNS
