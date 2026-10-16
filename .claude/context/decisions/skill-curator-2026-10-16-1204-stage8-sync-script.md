# 階段 8：同步腳本 `scripts/sync-ui-sources.sh`

- 計畫：`.claude/taskmaster-data/plans/adhoc-2026-10-16-frontend-style-library.md` 階段 8
- 分支：worktree 分支（基底 `f729d1b`）

## 產出

| 檔案 | 內容 |
|---|---|
| `scripts/sync-ui-sources.sh` | 新增。預覽／`--apply`／`--import <來源>:<id>`／`--source`／`--upstream-dir` |
| `scripts/sync-ui-sources.test.sh` | 新增。12 組情境，全部用假上游，不連網 |
| `scripts/copy-template.sh` | `EXCLUDES` 加 `scripts/sync-ui-sources*`（rsync 與 cp 退路共用） |
| `scripts/copy-template.ps1` | `$excludeFiles` 加 `sync-ui-sources*` |
| `scripts/update-template.sh` | `sync_dir` 加第 4 個參數（第一層排除樣式）；rsync 走 `--exclude`，複製後兩條路徑都刪掉目標端的同名檔（清掉舊版漏過去的） |
| `scripts/update-template.ps1` | `Invoke-Sync -ExcludeTop`：robocopy `/XF`＋複製後刪掉目標端同名檔 |

## 判斷規則（寫在腳本檔頭，這裡只記取捨）

- **本地有沒有改過只看 hash**：目前 DESIGN.md 的 sha256 ≠ `imported_sha256` 就是改過。
  `locally_modified` 不參與判斷（它記的是「匯入時和上游差多少」）
- **「上游有更新」＝本地沒改過，而且上游內容 ≠ 本地內容**。沒有額外存上游 hash，
  所以只差第一行標題的那 20 份會一直列在「上游有更新」，直到跑過一次 `--apply`。
  這是刻意的：它們本來就該覆蓋，而 `_sources.json` 的 notes 沒有定義「上游 hash」欄位，
  為此加欄位要改階段 2 的資料定義
- **`--apply` 更新 SOURCE.json 的** `upstream_commit`、`imported_sha256`、`imported_at`、
  `upstream_format`（檔頭 `---` → `google-alpha`）、`upstream_status: present`、
  `locally_modified: false`、`local_changes: ""`
- **抓取**：`gh api repos/<repo>/commits/<ref>` 解出 commit → 下載該 commit 的 tarball 到
  `mktemp -d` → 只解 `path_pattern` 對到的 DESIGN.md
- **lint**：只對 google-alpha 格式、只提醒不擋；`SYNC_UI_LINT=off` 可關
  （`npx --yes` 會連網裝套件，測試一律關掉）
- **`--import` 不改 CATALOG.md**：計畫的驗收要 check-counts 對新目錄報 ✗，
  而 check-counts 的 CATALOG 檢查是 `grep -F <codename>`——腳本寫任何標記進 CATALOG 都會讓那個 ✗ 消失。
  改成在輸出提醒「CATALOG.md 加兩處（附繁中一句話說明）」，靠 check-counts 擋

## 實測（唯讀）

對真實上游跑 `--source voltagent` 預覽（commit `3b60532`）：上游有更新 50、上游新增 26、
本地已修改 1（`claude`）、上游已刪除 0。26 份新增與階段 3 的候選數一致。
**沒有跑 `--apply`**——50 份會整批換成 google-alpha 新格式，這是要使用者決定的事。

## 驗證

- `bash scripts/sync-ui-sources.test.sh`：75 通過、0 失敗（含 copy／update 的 sh 無 rsync 路徑與兩支 ps1）
- `bash scripts/check-counts.sh`：520 項全部一致
- 沒有改 hook，未跑 `run-tests.sh`
- 行為驗證：不適用（腳本，不是給模型讀的文字）

## 已知限制

- 這台機器沒有 rsync，`copy-template.sh`／`update-template.sh` 的 rsync 路徑**沒有實測**，
  只測了 cp 退路和兩支 ps1
- 測試要跑約 6 分鐘（Windows 上每次 jq／sha256sum 起程序都慢；check-counts 一次就要數十秒）
- `language` 用內容判斷（假名 → ja、諺文 → ko、否則 en），需要 `grep -P` 和 UTF-8 locale；
  macOS 內建 grep 沒有 `-P`，會一律判成 en
