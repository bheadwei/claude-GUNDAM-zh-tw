# 任務分級規則（Task Mode）

定義單一任務的執行強度，避免「小修改也被迫跑完整 plan → tdd → verify 流程」。

## 三檔任務模式

| 模式 | 適用條件 | 流程 | 覆蓋率門檻 |
|---|---|---|---|
| `quick` | < 30min ・ 單檔案 ・ 文案/樣式/小 bug ・ 設定調整 | 直接寫 → `/verify quick` | 不強制 |
| `standard` | 1-4h ・ 跨檔 ・ 新增功能 ・ 重構 | `/plan` → `/tdd` → `/verify` | 80% |
| `critical` | 金流 ・ 認證 ・ 安全 ・ 核心商業邏輯 | `/plan` → `/tdd` → `/review-code` → `/verify pre-pr` | 100% |

## 設定檔

路徑：`.claude/taskmaster-data/.current-task-mode`

格式：純文字，僅一個值 `quick` / `standard` / `critical`。

寫入時機：`/task-next` 選定任務後寫入；**入口自動分級**（見下節）對 ad-hoc 任務也寫入；`/tdd <mode>` 行內參數可覆寫；`/verify` 完成任務後同步清除（連同 `.current-task`）。

## 入口自動分級（主路徑必跑，無需 /task-next）

**問題**：`.current-task-mode` 過去只有 `/task-next` 會寫 → 臨時/ad-hoc 任務落到無檔狀態、被當成 standard 跑完整 TDD，**小任務也被迫走重流程**。

**修正**：**任何實作型請求開始前**，若 `.current-task-mode` 不存在，主模型**必須**：

1. 用下方「自動分級啟發式」即時判定模式
2. **明確宣告**判定與理由（一句話），例如：
   > 判定 **quick**（單檔、<30min、樣式調整）→ 直接實作 + 1 個 happy-path 驗證，跳過 plan/TDD。
3. 將判定值寫入 `.current-task-mode`（ad-hoc 也寫，不必經 `/task-next`）
4. 使用者可當場一句話否決/調整（如「這要 standard」）

**預設不再是 standard**——改為「先判定、後宣告」。判不準時偏保守往上一級，但 quick 該快就快。

> **何謂「實作型請求」**：需要寫/改程式碼或設定的請求。純問答、檢視、研究不需分級。

## 流程指令的快慢車道

### `/tdd` 行為差異

讀 `.current-task-mode`：

- **quick** → 跳過 plan 偵測；不強制先寫測試（允許「實作 + 補測試」）；不強制覆蓋率
- **standard**（預設） → 現行流程：載入 plan、RED → GREEN → REFACTOR、80% 覆蓋
- **critical** → standard + 100% 覆蓋 + 強制 `/review-code` 才算階段完成

### `/verify` 行為差異

讀 `.current-task-mode`，自動套對應 profile（使用者帶 `$ARGUMENTS` 仍優先）：

- **quick** → `verify quick`（僅 build + types）
- **standard** → `verify full`（六步驟全跑）
- **critical** → `verify pre-pr`（full + 安全掃描）

### `/plan` 啟動門檻

- **quick** → 不需要 plan，跳過
- **standard** → 跨 ≥ 2 檔 或 ≥ 1h 才需要（同 `plan-persistence.md` 既有規則）
- **critical** → 一律需要 plan

## 自動分級啟發式（共用：`/task-next` 與 入口自動分級）

依以下訊號判定**預設**模式，再讓使用者調整：

- 單檔範圍 **且** 預估 < 30min **且** 屬「文案/樣式/設定/小 bug」 → **quick**
- 觸及「auth/認證/payment/金流/billing/security/安全/migration/遷移/核心商業邏輯」 → **critical**
- 其他（跨檔、新功能、重構） → **standard**

`/task-next` 透過 `AskUserQuestion` 讓使用者覆寫；入口自動分級則以「宣告 + 等使用者一句話否決」方式覆寫。

## 例外與升級

執行中發現實際複雜度超過初始評估時：

- quick → standard：發現要動多檔，主動提示「升級到 standard，要先 `/plan` 嗎？」
- standard → critical：發現觸碰金流/認證，停止並提示升級

降級不允許（避免規避測試）。

## 為什麼這樣設計

- **承襲 `/docs-init` 的 demo/mvp/full 三檔哲學** — 文件能分級，任務也能
- **保留 plan-persistence.md 既有門檻** — 不重新發明，只是包裝成更明確的模式
- **使用者一次選擇，後續指令自動讀取** — 不必每個指令都重問

## 相關檔案

- `.claude/commands/task-next.md` — 詢問與寫入模式
- `.claude/commands/tdd.md` — 讀取並調整 TDD 強度
- `.claude/commands/verify.md` — 讀取並選 profile
- `.claude/rules/testing.md` — 覆蓋率門檻
- `.claude/rules/plan-persistence.md` — Plan 啟動門檻
