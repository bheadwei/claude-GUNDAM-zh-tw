# skill-curator：整套測試閘門（worktree 裡沒帶路徑的 pytest／vitest／jest 擋一次）

分支 `fix/parallel-test-resources`，接續 `skill-curator-2026-11-02-1546-parallel-test-resources.md`
的 hook 建議第 2 項。起因：「RED／GREEN 每輪只跑相關測試」是 `testing-standards` 的文字規則，
在另一個專案沒被遵守——4 條平行線每輪跑整套 tests/unit（約 1.5 萬條、20～40 分鐘）。

## 層級判斷

writing-extensions 決策表第一列：「這條指令是不是沒帶路徑的整套」在工具呼叫當下判斷得出 → PreToolUse hook。
掛在既有的 `pre-tool-use.sh` Bash／PowerShell 段，邏輯拆成 `lib/full-suite-gate.sh`（比照 git-backup-gate 的 lib 結構）。
沒有另開腳本、沒有新事件接線（matcher 已含 `Bash|PowerShell`），所以 `settings.json` 不動。

## 設計決定

| 決定 | 選擇 | 理由 |
|---|---|---|
| 範圍 | **只在 worktree**（`IN_WORKTREE=1`）；主 checkout 連 lib 都不 source | 事故成本來自平行（N 份整套搶同一台機器與 DB）；主 checkout 同時只有一條線，且是 `/verify` 驗合併結果、本來就該跑整套的地方。要擴大到主 checkout 先拿真實資料證明單線也造成問題 |
| 什麼算整套 | 測試執行器段落沒有任何「測試檔／夠窄的目錄」也沒有篩選 | `tests`、`tests/unit`、`src`、`.` 等「整個測試根」的目錄名視同整套——事故跑的正是 `tests/unit`，只看「有沒有帶路徑」會漏掉它 |
| deny-once | **消耗性**：記下整條指令，同一條重試放行並清掉標記；下次再跑再擋 | 事故的形狀是「同一條每輪都跑」，只擋第一次的話第二輪起就沒提醒；每次整套多一個來回（實測 hook 多 0.5～1 秒），相對 20～40 分鐘可忽略。擋的是資訊不是狀態，重試必過，不會卡死 |
| `/verify`、`/deps`、`/refactor-clean` 的出口 | 指令帶註解 `# full-suite` | 旗標檔要有人寫有人刪、忘了刪是永久放行，而且 refactor-cleaner 跑在 worktree 裡，旗標該寫哪一邊又是一個邊界；`FULL_SUITE=1 pytest` 前綴在 PowerShell 是語法錯誤；`#` 在兩個 shell 都是註解、零副作用、transcript 看得到 |
| 狀態檔 | `WORK_CLAUDE/taskmaster-data/.full-suite-warned` | 短命旗標、跟著 worktree（邊界表同 `.pitfall-seen`） |
| 逃生門 | `FULL_SUITE_GATE=off`；`TASKMODE_GATE=off`／`.suggest-mode=off` 照舊一併關 | 命名比照 `GIT_BACKUP_GATE` |
| 指令切段 | 在 `cmd-segments.sh` 抽出 `cmd_split`（不限 git 的切段），`cmd_segments` 改用它 | heredoc／引號／註解處理只留一份；git 閘門行為不變（既有測試全過） |

`gates-fail-open-silently` 三題：(a) 標記檔只讀一行、壞掉只會多擋一次 (b) Windows 實測 worktree 內測試指令 1.8～2.3 秒、主 checkout 無增量，遠低於 30 秒 timeout (c) Bash 與 PowerShell 都管。

有意的漏網（寫在 lib 檔頭）：`flock … pytest`、`bash -c`、`make test`、`tox`、`poetry run`、`npm run test:unit` 這種自訂 script 名；引號內路徑一律當有帶路徑；原始指令任何地方出現 `# full-suite` 都放行。

## 改動

| 檔案 | 行 | 內容 |
|---|---|---|
| `hooks/lib/full-suite-gate.sh` | 新檔 1-250 | 閘門本體（判準、消耗性 deny-once、`# full-suite` 出口、依 runner 給範例的訊息） |
| `hooks/lib/cmd-segments.sh` | 164-180 | 抽出 `cmd_split`；`cmd_segments` 改呼叫它 |
| `hooks/pre-tool-use.sh` | 16-20, 34, 215-225 | 檔頭清單第 6 項、`FULL_SUITE_GATE` 參數說明、只在 worktree 時 source 並呼叫 |
| `hooks/tests/run-tests.sh` | 1076-1172 | 新節「整套測試閘門」（見下方測試數） |
| `hooks/README.md` | 12, 18, 20, 57 | 檔案樹、cmd-segments 共用者、功能表 ⑥（rm 權限改為 ⑦） |
| `skills/testing-standards/SKILL.md` | 38-42 | 「執行測試」表下：第一列在 worktree 由 hook 強制、`# full-suite` 出口、逃生門 |
| `commands/verify.md` | 24-26 | 步驟 4 整套指令加 `# full-suite` |
| `commands/deps.md` | 38-40 | 基準與每批加 `# full-suite` |
| `commands/refactor-clean.md` | 32-33 | 同上（refactor-cleaner 跑在 worktree） |
| `agents/refactor-cleaner.md` | 78-79 | 每批整套加 `# full-suite` |
| `agents/conflict-resolver.md` | 65, 68 | 解完衝突的整套加 `# full-suite`（worktree 裡 rebase 衝突時會走到） |

## 驗證

- `run-tests.sh`：通過 793 ・ 失敗 0（改動前 738；新增 55 條斷言）
- `check-counts.sh`（不帶 --tests）：695 項全部一致；`--tests 793`：698 項中 1 項不一致——根目錄 `README.md:93` 仍寫 737，在寫入邊界外，已建 handoff 給 documentation-specialist
- 測試數文件同步：`.claude/guides/WORKFLOW.md:443`、`.claude/hooks/tests/README.md:7`、`.claude/skills/writing-extensions/SKILL.md:118` 由 737 改 793（737 改動前就已過時，HEAD 實為 738）
- **未驗證行為改變**：閘門邏輯有測試釘住，但「模型被擋之後會改成帶路徑，還是直接重試／加 `# full-suite`」沒跑過。模板 repo 沒有測試套件，這題要在有 pytest／vitest 的專案、開兩條 worktree 線實跑

## 未處理／疑慮

- `.skill-impact`：本輪與上一輪處理過的 13 筆已移除；其餘 25 筆（多為先前 hook 變更）留給下一輪盤點
- `writing-extensions` 決策表第二列與 skill-curator 定義寫「PreToolUse 不支援 `additionalContext`」，但 `pre-tool-use.sh` 的坑閘門註解說官方已支援、且「從 plan 還原」段已在用。兩處說法矛盾，需要查官方文件後統一（本輪未動）
- `commands/refactor-clean.md` 的 HEAD blob 本來就是 CRLF（git 提示會正規化），非本次造成
