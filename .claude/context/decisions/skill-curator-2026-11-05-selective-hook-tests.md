# hook 測試改成依改動挑節

- 日期：2026-11-05
- 作者：skill-curator（在 worktree 執行，由主模型落檔）
- 分支：`worktree-agent-aa114decd3484e9f2`，commit **6d1e852**，起點 e40a70d，改了 17 個檔

## 決策

- **規則**：hook 測試改成只跑改動相關的節。整套只在兩個時機跑：`/verify pre-pr` 和 CI。
- **原因**：整套共 869 個案例，在 Windows/Git Bash 要跑 51 分鐘。以前每次合併都跑整套，連只改 `.md` 也一樣。
- **用法**：
  - `run-tests.sh <關鍵字>...`：只跑標題含關鍵字的節。
  - `run-tests.sh --changed <起點|->`：依改動自動挑節。
  - `run-tests.sh --list`：列出所有節。
  - `run-tests.sh --dry-run`：只顯示會跑哪些節，不實際執行。
  - 不帶參數時照舊跑整套。
- **唯一來源**：
  - 「改動檔 → 要跑哪些節」的對應表，只寫在 `run-tests.sh` 的 `_changed_rule`。
  - 「什麼時候跑整套」只寫在 `verify.md` 步驟 4。
- **放在哪一層**：選節屬於 runner 的 CLI。「在 worktree 裡跑整套」在呼叫當下就判斷得出來，所以放進既有的 `full-suite-gate`，現在它也會擋不帶參數的 `run-tests.sh`。
- **選節怎麼實作**：
  - 被選中的節整段執行。
  - 沒選中的節只取出它的函式定義和簡單的變數指派，不執行裡面的指令。原因是後面的節會用到前面的節定義的東西，例如 `fs`、`gbo`、`mk_handoff`、`setup_worktree`、`MP_FILE`。
  - 某一節如果依賴前面的節留下的「檔案狀態」，單獨跑時會失敗，但會報錯，不會悄悄通過。
- **否決過的做法**：
  - 在 `section()` 設旗標：擋不住寫在頂層的指令。
  - 用 DEBUG trap 加 extdebug：原型實測時會進入無限迴圈。
- **`verify.md` 的語意改動**：
  - `.merge-round-open` 改成記錄本輪的起點 sha。
  - `.last-verify` 的 `suite` 多一個值 `changed`。
  - 第 0 步的標記從 `FULL-COVERED` 改名為 `COVERED`。
  - 「在 worktree 裡」的判斷排在 pre-pr 前面。
- **已知取捨**：如果合併後兩邊的改動互相影響，而問題出在沒被挑到的節，要到 pre-pr 或 CI 跑整套時才抓得到。另外，只要改到 `run-tests.sh` 本身，就會跑整套，所以凡是新增測試的改動都會跑整套。

## 驗證

- 實際跑過 4 個節，全部通過。另外用假的 diff 驗了 10 種情況，自動挑節的結果都正確。
- 整套沒跑。這次改到 lib，照對應表本來就該跑整套，留給主模型合併後統一跑。
- check-counts：只差根目錄 `README.md:95` 的測試數。
- 還沒驗證：
  - 其他 29 節單獨跑時會不會失敗。
  - 用新的 `verify.md` 實際走一輪合併。
  - 模型會不會照新規則做（skill-compliance 沒跑）。

STATUS: DONE_WITH_CONCERNS
