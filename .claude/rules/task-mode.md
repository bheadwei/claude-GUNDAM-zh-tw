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

由 `/task-next` 在使用者選定任務後寫入；`/verify` 完成任務後同步清除（連同 `.current-task`）。

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

## 自動分級啟發式（給 `/task-next` 用）

呈現任務時依以下訊號**預設**模式，再讓使用者調整：

- WBS 預估時間 < 30min **且** 描述含「修文案/調樣式/改設定/小 bug」 → **quick**
- WBS 任務名含「auth/payment/billing/security/migration」 → **critical**
- 其他 → **standard**

使用者透過 `AskUserQuestion` 可手動覆寫此預設。

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
