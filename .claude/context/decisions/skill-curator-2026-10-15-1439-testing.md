# skill-curator 盤點：測試設計是否過度（2026-10-15 14:39）

> 純分析，未改任何檔案。另一個 agent 正在改 `commands/verify.md`、`task-*.md`、`plan-format`、`post-write.sh`，
> 下面涉及 verify.md 的建議要等它收工後再動。
> **所有「省多少」都是依流程結構推估，不是量測值**——模板 repo 沒有應用程式碼，也沒有 agent-activity 紀錄可查。

## 結論

有過度設計。主因不是任何一條規則太嚴，而是**四件事疊在一起**：

1. 大部分工作會被判成 standard 以上
2. standard 鏈裡有兩個 opus agent 寫同一批測試
3. 每一步都跑**整套**測試＋覆蓋率，輸出整份讀進 context
4. 「必測」清單寫成「全部都要」

## Token 花在哪（依影響排序）

### 1. 同一功能被兩個 opus agent 測兩次
- `using-taskmaster/SKILL.md:35` 新功能鏈無條件串 `tdd-guide → code-quality-specialist → test-automation-engineer`；`:41` 重構鏈同樣如此
- `code-quality-specialist.md:65` 把「缺少測試」列為 HIGH，`:24-25` 一發現就建 handoff 給 test-automation-engineer
- `using-taskmaster/SKILL.md:114-116` 要求看到 handoff 就直接派，不停下來問 → 鏈會自己往下走
- `test-automation-engineer.md:25-28` 開工先讀 quality、e2e、testing 三份報告；`:34` 要「補強前後覆蓋率對比」＝至少跑兩次 coverage
- 兩者都是 `model: opus`（`tdd-guide.md:5`、`test-automation-engineer.md:5`）
- `test-automation-engineer.md:17-20` 自己說是「實作後補強既有程式碼」，但 tdd-guide 剛用 test-first 寫完的東西不是「既有程式碼」，職責在這條鏈上實際是重疊的

### 2. 每一步都跑整套測試＋覆蓋率，輸出全文進 context
- `tdd-guide.md:84` `npm test`、`:97` `npm run test:coverage`、`:100` 四個維度都要算；`commands/tdd.md:110,123` 同上——沒有一處叫你「只跑相關的測試」或「只回報失敗」
- `python-testing/SKILL.md:48` 建議 `--cov-report=term-missing --cov-report=html`，term-missing 會把每個檔案的未覆蓋行號全部印出來
- 走 `subagent-execution` 時每個階段都要：implementer 跑 RED/GREEN/coverage（`implementer-prompt.md:38,57,73`）→ code-quality 審查（`SKILL.md:148`，又可能建 handoff）→ 修復迴圈最多 5 輪（`:158-164`）→ slop 清理後再跑一次（`:187`）→ 最後 `/verify` 整套再跑（`verify.md:24-26`）
- 粗估：一個 4 階段的 standard 任務，整套測試＋覆蓋率會跑 15-25 次

### 3. quick 的門檻太窄，判不準時一律往上
- `task-mode.md:15` quick 要**同時**滿足四個條件：單檔、少於 30 分鐘、文案/樣式/設定/小 bug。只要是小的新功能、或是動到兩個檔的 bug 修復，就不算 quick
- `task-mode.md:19` 判不準時往上一級靠 → 實際上大部分工作都會變 standard
- `user-prompt-submit.sh:72` critical 關鍵字含 `session|login|password`，「登入頁的文案」「session 逾時提示」也會被建議升到 critical（覆蓋率 100%）

### 4. 必測清單寫成「全部都要」
- `testing-standards/SKILL.md:40-49` 「必須測試的邊界情況」8 項，包含競態條件（第 6 項）和 10k 筆以上資料的效能（第 7 項）。這兩項對大多數函式不適用，但寫的是「必須」
- 同一份清單在 `tdd-guide.md:110-119` 又抄了一份（跨層重複）
- `tdd-guide.md:130-131` 要求「**所有**公開函式有單元測試、**所有** API 端點有整合測試」；`:8`「達到全面覆蓋」、`:43`「撰寫全面測試套件（單元、整合、E2E）」
- `testing-standards/SKILL.md:21-25` 三種「必要測試類型」，E2E 也列為必要，沒有寫依什麼條件

### 5. 每次派 agent 的必讀規範本身就很大
- `tdd-guide.md:10-16` 必讀清單在 Python 專案會讀到 plan-format（7.5KB）、testing-standards、python-testing（**19KB／816 行**）、python-patterns（17KB）、python-uv 等，加起來約 50KB 以上，換算超過 1.5 萬 token；`test-automation-engineer.md:10` 也讀 python-testing
- `python-testing` 大部分是 pytest 的通用教學（fixture、parametrize、mock），模型本來就會（違反 writing-extensions 的「模型是不是本來就會」判準）

### 6. E2E 的執行次數
- `e2e-validation-specialist.md:61` 每次本地跑 3-5 次檢查是否不穩定；`:91-96` 3 種瀏覽器 × 3 種視窗；`:24` 也會建 handoff 給 test-automation-engineer

## 合理的保護 vs 過度設計

| 項目 | 判斷 | 砍掉會失去什麼 |
|---|---|---|
| critical 模式要先寫測試再實作（RED-first） | **保留** | 金流／認證的回歸保護 |
| `/verify` 最後跑一次整套測試 | **保留** | 唯一能抓到跨模組回歸的地方 |
| 合併後強制 `/verify`（merge-gate） | **保留** | 平行開發時兩邊程式碼的互動沒人驗 |
| code-quality-specialist 審查 | **保留** | 安全與品質把關；但「缺少測試」不該自動接下一棒 |
| 新功能鏈無條件接 test-automation-engineer | **過度** | 幾乎沒有損失：tdd-guide 剛寫完測試。改成「有具體缺口才接」 |
| 每次 RED/GREEN 都跑整套＋coverage | **過度** | 沒有損失：整套最後在 /verify 會跑 |
| 8 項邊界全部必測 | **過度** | 改成「挑適用的」後，競態／效能只在相關程式碼才測 |
| standard 的 80% 是整個專案的數字 | **可討論** | 改成「這次改動的部分」會失去「順手補舊債」的壓力，但那本來就不是這個任務的範圍 |
| critical 100% 而且四個維度都算 | **可討論** | 改成「critical 模組的分支 100%」會失去對周邊樣板碼的覆蓋，但那些通常沒有風險 |
| E2E 跑 3-5 次、3×3 矩陣 | **過度**（本地） | 不穩定測試要到 CI 才會被發現 |

## 互相矛盾的地方

1. **standard 到底是不是預設**：`testing-standards/SKILL.md:15` 寫「`standard`（預設）」；`task-mode.md:19` 寫「預設不是 standard」；`tdd-guide.md:56` 寫「standard（或檔案不存在）」，但同一份檔案的 `:59` 又說「檔案不存在時不要逕自當 standard」；`verify.md:233` 也把「檔案不存在」當 standard
2. **覆蓋率數字被重述了好幾份**（`testing-standards:18` 明文禁止重述）：
   - `test-automation-engineer.md:64,66,79` 寫「預設 80%，金融/認證 100%」，完全不看任務模式
   - `python-testing/SKILL.md:43-44,647` 寫「Target 80%+／Critical 100%」，而且 `:20-27,640` 寫「Always follow TDD」，沒有 quick 豁免——但它自己的 description 說「覆蓋率門檻的唯一來源是 testing-standards」
   - `commands/tdd.md:157` 寫「關鍵程式碼目標 100% 覆蓋率」
3. **quick 模式到底派不派 tdd-guide**：`using-taskmaster/SKILL.md:29` 說 quick 只派「粗體那一棒」，新功能鏈的粗體正是 tdd-guide（`:35`）；但 `agent-orchestration.md:9`、`using-taskmaster:53`、`tdd-guide.md:3` 都說 quick 不派
4. **quick 要求寫測試，卻沒有地方會跑它**：`testing-standards:14` 要求 quick 至少寫 1 個 happy-path 測試，但 `verify.md:222` 的 quick profile 只跑建置＋型別檢查，這個測試永遠不會被執行
5. **E2E 必不必要**：`testing-standards:25` 列為「必要」，`tdd-guide.md:108` 寫「關鍵路徑」才要，`e2e.md:25` 寫「不要用 E2E 測每個邊界情況」

## 建議（依「省最多、風險最低」排序）

| # | 改哪個檔 | 怎麼改 | 預估省多少 | 風險 |
|---|---|---|---|---|
| 1 | `using-taskmaster/SKILL.md:35,41`；`code-quality-specialist.md:24-25,65` | 鏈改成 `… → code-quality-specialist →（只在回報具體測試缺口時）test-automation-engineer`。code-quality 只在「某條有風險的行為路徑完全沒有測試」時才建 handoff，不因為覆蓋率百分比就建 | 每個 standard 功能少派一個 opus agent，粗估整條鏈少 25-35% | 低 |
| 2 | `testing-standards/SKILL.md` 新增一節「執行測試」（唯一來源）；`tdd-guide.md:84,97`、`tdd.md:110,123`、`implementer-prompt.md:57` 改成指標 | RED/GREEN 只跑這次相關的測試檔；coverage 只在階段結束跑一次，而且只看這次改動的檔案；只回報「通過/失敗數＋失敗摘要」，不貼整份 coverage 表；整套測試只在 `/verify` 跑 | 測試輸出佔用的 context 粗估省 50-70% | 低（整套仍在 /verify 跑） |
| 3 | `testing-standards/SKILL.md:40-49`；`tdd-guide.md:110-119,130-131` | 「必須測試的邊界情況」改成「挑適用的」：1-5 項依函式性質挑，6（競態）、7（大量資料）只在有並行或批次處理時才測。tdd-guide 那份刪掉，改成指標。「所有公開函式」改成「有分支邏輯或錯誤路徑的公開行為」 | 每個函式的測試數粗估少 30-50% | 低～中 |
| 4 | 修正上面列的 5 處矛盾 | 刪掉重述的百分比改成指標；`testing-standards:15` 拿掉「（預設）」；`tdd-guide:56` 拿掉「或檔案不存在」；`using-taskmaster:29` 說清楚 quick 不派 tdd-guide | 直接省得不多，但能防止 agent 讀到 80% 就自己升級 | 低 |
| 5 | `python-testing/SKILL.md` | 從 816 行精簡到約 150 行，只留這個專案的約定（`uv run pytest`、conftest 放哪、非同步怎麼測、markers），刪掉通用的 pytest 教學與重述的覆蓋率 | Python 專案每次派 tdd-guide／test-automation 少讀約 4-5 千 token | 低（需另一輪 skill-curator） |
| 6 | `e2e-validation-specialist.md:61,91-96` | 3-5 次重跑只用在新寫或改過的 spec；跨瀏覽器矩陣交給 CI，本地只跑 chromium | E2E 執行次數少 60-80% | 低～中 |
| 7 | `task-mode.md:15,19`；`user-prompt-submit.sh:72` | **需要你決定**：quick 放寬成「≤2 檔、沒動對外介面或資料結構」；「判不準往上靠」只套用在 critical 的觸發詞；critical 關鍵字拿掉單獨的 `session`／`login` | 依專案而定，可能是最大的一項 | 中 |
| 8 | `testing-standards/SKILL.md:12-16` | **需要你決定**：standard 從「整個專案 80%」改成「plan 驗收條件列的行為都有測試＋改動檔的覆蓋率作參考」；critical 從「100% 四個維度」改成「critical 模組的分支 100%」 | 中～大 | 中 |
| 9 | `verify.md:222` | quick profile 加「只跑這次改到的測試檔」，讓 quick 要求的那 1 個測試真的有被執行（**會多花一點 token，是補漏洞不是省**） | 負值，很小 | 低；要等另一個 agent 改完 verify.md |

第 1、2 項加起來大概就是使用者感受到的「很耗 token」的主要來源，建議先做。第 7、8 項是政策決定，需要使用者拍板。

## 逐項裁決

| 對象 | 裁決 | 理由 |
|---|---|---|
| `testing-standards` | Improve | `:15` 寫「（預設）」與 task-mode 矛盾；`:40-49` 改成挑適用的；新增「執行測試」一節成為測試範圍與輸出格式的唯一來源 |
| `tdd-guide` | Improve | `:110-119` 與 testing-standards 重複，改成指標；`:56` 與自己的 `:59` 矛盾；`:84,97` 跑整套；`:8,43,130-131` 寫「全面」「所有」 |
| `test-automation-engineer` | Improve | `:64,66,79` 自己寫死百分比、不看任務模式；觸發條件要從「鏈裡的固定一棒」改成「有具體缺口才派」 |
| `code-quality-specialist` | Improve | `:24-25,65` 只要缺測試就建 handoff，沒有門檻，這就是自動補測連鎖的起點 |
| `python-testing` | Improve | 816 行大部分是模型本來就會的通用 pytest；`:20-27,41-48,640,647` 重述 80% 與「Always TDD」，跟自己的 description 矛盾 |
| `e2e-validation-specialist` | Improve | `:61` 和 `:91-96` 的本地執行量沒有條件限制 |
| `subagent-execution` | Keep | 每階段審查與修復迴圈有上限（`:158-164`），帳本可以續跑，問題出在它呼叫的測試指令沒限範圍；第 2 項改完它就會跟著受益，不用動它本身 |
| `e2e-testing` | Keep | 本次沒看到造成測試膨脹的內容，它是 Playwright 寫法的參考，不規定要測多少 |
| `task-mode` | NEEDS_CONTEXT | quick 的門檻要放多寬是政策決定，要使用者決定 |

## 驗證

- 接線檢查：沒有改任何接線（只寫了本報告）
- 行為驗證：**未驗證**。省多少都是依流程結構推估；要量測，得在有應用程式碼的專案裡用同一個 standard 任務跑改前/改後各一次，比較 subagent 數量和 token 數（CLAUDE.md「已知落差」提過模板 repo 跑不出正向題）
