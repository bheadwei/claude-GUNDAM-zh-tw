# skill-curator：平行線共用執行資源、審查加輪、整套測試殘留

分支 `fix/parallel-test-resources`。起因是另一個用本模板的專案的事故：4 條 critical 平行線＋1 個
debug-investigator 共用本機 SQL Server 與 `serial_timing` 計時測試，主模型自製 `flock` 讀寫鎖，
獨占請求被擋 23 分鐘（load 2.4）；各線每輪跑整套 tests/unit（約 1.5 萬條，20～40 分鐘）；
code-quality 複審每輪約 18 分鐘且一直加輪。

## 層級判斷（依 writing-extensions 決策表）

| 項目 | 落在哪層 | 理由 |
|---|---|---|
| 共用執行資源的判斷與排程 | Skill（`worktree-orchestration`） | 工具呼叫當下判斷不出「這幾條線會不會搶同一個 DB」——要讀專案設定與各線範圍。只在平行時適用，不該常駐 |
| 審查嚴重度 → BLOCKING 對應、複審範圍 | Skill 子檔（`reviewer-prompt.md`，唯一來源）＋ agent 自身行為 | 是主模型分流時的判準；agent 端需要知道「複審時只驗清單」 |
| debug-investigator 跑整套 | Agent 定義修正 | 純粹是 7a88996 漏改 |

## 改動

| 檔案 | 行 | 內容 |
|---|---|---|
| `skills/worktree-orchestration/SKILL.md` | 3 | description 補觸發情境（共用 DB／port／計時測試／CPU、「要不要加個鎖排隊」） |
| 同上 | 153-184 | 新節「共用的執行資源：worktree 隔離不到的東西」（資源表、派工前判斷、不要自己寫鎖＋三個替代） |
| 同上 | 341 | 反模式加一條 |
| `rules/agent-orchestration.md` | 77-78 | 「安全平行」加一行指標 |
| `skills/subagent-execution/reviewer-prompt.md` | 87-103 | 嚴重度對應表（CRITICAL/HIGH→BLOCKING；只剩 MEDIUM/LOW→技術債不加輪）＋複審範圍與派工句 |
| `skills/subagent-execution/SKILL.md` | 158-160 | 審查節指向上述分流（唯一來源） |
| `agents/code-quality-specialist.md` | 115-124 | 批准標準：「警告（HIGH）可謹慎合併」改為合併前應修、階段審查中進修復迴圈；通過時 MEDIUM/LOW 不需再審；複審模式只驗清單 |
| `commands/tdd.md` | 123-124 | 步驟 4 加分流指標（/tdd 直接實作路徑原本沒有任何複審規則） |
| `agents/debug-investigator.md` | 129-130, 175 | 步驟 6 與報告範本改為只跑相關測試檔、整套留給 /verify |
| `commands/refactor-clean.md` | 31-37 | 每個項目各跑兩次整套 → 基準一次、每批一次（同時與 refactor-cleaner agent 的「每批次後測試」對齊） |
| `skills/testing-standards/SKILL.md` | 28, 32, 35 | 「執行測試」加第五條：批次變更（/deps、/refactor-clean）基準一次＋每批一次；第一列註明含除錯修復 |

## 整套測試殘留 grep 結果

| 位置 | 裁決 | 理由 |
|---|---|---|
| `agents/debug-investigator.md:129,174` | 已修 | 與 testing-standards 直接矛盾 |
| `commands/refactor-clean.md:32` | 已修 | 每項各跑兩次整套；與自家 agent（每批）也不一致 |
| `commands/deps.md:28,38` | Keep（不改文字） | 依賴升級的影響面對不到特定測試檔，每批跑整套是必要的；改由 testing-standards 新列把它納入唯一來源 |
| `commands/verify.md:24` | Keep | 它就是跑整套的那一棒 |
| `agents/refactor-cleaner.md:114`、`refactor-clean.md:65`、project-docs 範本 | Keep | 「所有測試通過」是結果指標，不是執行時機 |

## Hook 建議（本次未實作）

1. **PreToolUse(Bash) 偵測 `flock -s`／`--shared`** → deny-once 指向「共用的執行資源」節。時機判斷得出來，命中率高、誤擋低
2. **PreToolUse(Bash) 偵測「worktree 內、沒帶測試路徑的 pytest／vitest／jest」** → deny-once 指向 testing-standards「執行測試」。這是每輪整套那筆 20～40 分鐘的直接來源；`/verify` 需要放行（可比照 `.merge-pending` 用旗標）
3. **PreToolUse(Agent) 派 `code-quality-specialist` 時**，若同任務上一份 quality 報告的 CRITICAL＋HIGH 為 0 → deny-once「只剩 MEDIUM/LOW 不加輪」。需要報告格式可機讀，脆弱度中等，優先序最低

## 未處理

- `.skill-impact` 有 28 筆累積項（多為先前 hook 變更），本次只處理了其中 5 個檔，**未清除**，留給下一輪盤點
- `commands/refactor-clean.md`、`agents/refactor-cleaner.md` 硬編 `npx`（應依 `package-manager.json`），範圍外未改

## 驗證

- `check-counts.sh`：695 項全部一致
- hook 未動，未跑 run-tests.sh
- **未驗證行為改變**（未跑 skill-compliance；模板 repo 沒有可平行的應用程式碼，這題得在有 DB 的專案裡跑）
