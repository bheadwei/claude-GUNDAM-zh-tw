---
name: testing-standards
description: Use when writing or fixing tests, about to run a test command, deciding which cases or edge cases to test, checking a coverage target, or a test is failing — 「測試要寫到多少」「覆蓋率要幾 %」「跑一下測試」「這個要不要測」. 覆蓋率門檻與「測試怎麼跑、輸出怎麼回報」的唯一來源。先寫測試再實作的流程在 tdd-workflow skill；quick 模式不套用完整流程。
---

# 測試要求

## 覆蓋率門檻（依任務模式）

讀 `.claude/taskmaster-data/.current-task-mode`（不存在 → 先依 `rules/task-mode.md` 判級、宣告、寫入，**不要逕自當 standard**）：

| 模式 | 門檻 | 算哪些檔 |
|---|---|---|
| `quick` | **不檢查**，至少 1 個 happy-path 測試（由 `/verify quick` 執行） | — |
| `standard` | 行覆蓋率 80%，**而且** plan 驗收條件列的每一條行為都有對應測試 | 只算**這次改到的檔** |
| `critical` | **分支**覆蓋率 100% | 只算**關鍵模組**：判成 critical 的那段程式（金流、認證、權限判斷、核心商業邏輯） |

- **舊程式碼不拖累新任務**：專案整體覆蓋率不是這次任務的門檻。改到的檔以外的缺口，不在本任務範圍
- critical 只看分支覆蓋，不再四種指標（分支／函式／行／語句）都算。關鍵模組周邊的樣板與接線照 standard 算
- 覆蓋率是**輔助訊號**，不是目標。數字達標但驗收條件沒被測到 → 不算達標

> ⚠️ 這張表是覆蓋率門檻的**唯一來源**。其他檔案（agent、command、skill、hook 訊息）
> 一律寫「見 `testing-standards`」，**不要重述百分比**——重述的那份不會跟著改，
> 而且讀到「80%」的 agent 會自己把 quick 任務升級。

## 執行測試（唯一來源）

測試輸出是 context 最大的消耗來源之一。規則只有四條：

| 時機 | 跑什麼 | 不要做 |
|---|---|---|
| RED／GREEN 每一輪 | **只跑這次相關的測試檔**（新寫的、和被改到的模組對應的） | 跑整套 |
| 一個階段結束 | **跑一次** coverage，範圍限縮在這次改到的檔 | 每輪都跑 coverage、印整個專案的覆蓋率表 |
| 任務收尾 | 整套測試 | 自己跑——**那是 `/verify` 的事**，它一定會跑 |
| 任何時候 | 只回報結果摘要（見下） | 把整份測試輸出讀進 context |

### 只跑相關的測試檔

套件管理器與測試指令讀 `.claude/taskmaster-data/package-manager.json`／專案設定，**不要自選**。
常見寫法（旗標以專案實際版本的文件為準）：

| 測試框架 | 只跑指定檔 | 覆蓋率只看指定檔 |
|---|---|---|
| pytest（一律 `uv run`） | `uv run pytest tests/test_x.py -q` | `--cov=<被改的模組路徑> --cov-report=term` |
| vitest | `<pm> vitest run tests/x.test.ts` | `--coverage --coverage.include=<被改的檔>` |
| jest | `<pm> jest tests/x.test.ts` | `--coverage --collectCoverageFrom=<被改的檔>` |
| playwright | 見 `e2e-testing` skill | — |

「這次改到的檔」＝`git diff --name-only <階段起點>` 的結果，扣掉測試檔本身。

### 只回報摘要

回報給主模型（或寫進報告）的測試結果只需要：

```
測試：通過 12／失敗 1
失敗：tests/test_order.py::test_refund_over_limit — AssertionError: expected 400, got 500
覆蓋率（改到的檔）：src/order/refund.py 86%
```

- 用安靜模式跑（`-q`、`--reporter=dot`），失敗時只取失敗段落（`| tail -n 40` 或框架的摘要區）
- **不要**貼 `--cov-report=term-missing` 的全專案表；要看哪幾行沒覆蓋，只對單一檔案看
- 輸出被截掉時寧可重跑單一失敗測試看細節，也不要把整份讀進來

## 要寫哪些測試

**有分支或錯誤路徑的行為要測。** 不是「每個公開函式都要有單元測試」——
沒有分支的轉接函式、純設定、框架樣板，測它等於在測框架。

| 類型 | 什麼時候寫 |
|---|---|
| 單元測試 | 有判斷、計算、解析、權限邏輯的函式 |
| 整合測試 | 這次改到 API 端點、資料庫存取、外部服務接線時 |
| E2E | 只給**關鍵使用者流程**（登入、結帳、核心 CRUD），見 `e2e-testing` skill。不用 E2E 測邊界情況 |

依程式性質決定要多嚴格（先寫測試／實作後補／不寫單元測試）見 `tdd-workflow` skill。

### 邊界情況：挑適用的測

不是每個函式都要全測一遍。依這段程式真的會遇到的情況挑：

| 情況 | 什麼時候測 |
|---|---|
| null／undefined／空值輸入 | 輸入來自外部或型別允許空值時 |
| 空陣列／空字串 | 有迭代或字串處理時 |
| 無效型別 | 只在系統邊界（使用者輸入、外部 API）——型別系統已保證的不測 |
| 邊界值（最小／最大／剛好等於） | 有比較、範圍、分頁、金額時 |
| 錯誤路徑（網路失敗、DB 錯誤、逾時） | 有呼叫外部資源時 |
| 特殊字元（Unicode、emoji、SQL 字元） | 有文字處理、搜尋、組查詢時 |
| 競態條件 | **只在**這段程式有並行操作（同時寫同一筆、鎖、佇列） |
| 大量資料效能 | **只在**這段程式處理批次或大量資料 |

## 測試反模式（避免）

- 測試實作細節（內部狀態）而非行為
- 測試之間互相依賴（共享狀態）
- 斷言太少（通過但未驗證任何東西）
- 未 mock 外部依賴
- 為了拉高覆蓋率寫沒有實際斷言的測試
- 測語言或框架本身的行為（`typeof x === 'string'`）

## 測試失敗排除

1. 先只重跑那一個失敗的測試，看完整錯誤
2. 檢查測試隔離（單獨跑會過、一起跑會掛 → 共享狀態）
3. 驗證 mock 正確性
4. **修實作，不改測試**——測試本身真的錯了才改，而且要說明理由（見 `tdd-workflow`）
5. 跑起來行為不對、根因說不出來 → 委派 `debug-investigator`

## 相關

- `tdd-workflow` skill — 先寫測試再實作的流程、依程式性質決定強度
- `rules/task-mode.md` — 任務分級定義
- `plan-format` skill — plan 階段的「驗收」欄位是 RED 的推導來源
- `e2e-testing` skill — Playwright 端到端測試模式
- `python-testing` skill — pytest 的專案約定
