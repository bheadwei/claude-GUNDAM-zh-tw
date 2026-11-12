# 任務分級規則（Task Mode）

定義單一任務的執行強度，避免「小修改也被迫跑完整 plan → tdd → verify 流程」。

## 三檔任務模式

| 模式 | 適用條件 | 流程 |
|---|---|---|
| `quick` | ≤ 2 個檔，且**沒有**動到對外介面（API／路由／CLI）或資料結構（schema／migration） | 直接寫 → `/verify quick` |
| `standard` | 超過 2 個檔 ・ 動到對外介面 ・ 新增功能 ・ 重構 | `/plan`（依門檻，見 `plan-format` skill）→ `/tdd` → `/verify` |
| `critical` | 金流 ・ 認證／授權邏輯 ・ 安全 ・ migration ・ 核心商業邏輯 | `/plan`（必要）→ `/tdd` → `/verify pre-pr` → `/pr`（把關鏈不可跳過） |

覆蓋率門檻見 `testing-standards` skill（唯一來源，本檔不寫數字）。

## 審查節奏（唯一來源）

| 模式 | 每階段（`/tdd`，審該階段的 diff） | 最後一道 |
|---|---|---|
| `quick` | 不審 | 無 |
| `standard` | `code-quality-specialist` | 無額外審查 |
| `critical` | `code-quality-specialist` ＋ `security-infrastructure-auditor` | `/pr` 的把關鏈（不可跳過，見 `commands/pr.md` 步驟 2） |

不要再疊一層：每階段已審過，`/verify` 不另派審查；`/code-review` 是 Claude Code 內建 skill，
需要時手動跑，不是流程的固定一棒。

## 自動分級啟發式

- 觸及認證或授權**邏輯本身**、金流、安全、migration、核心商業邏輯 → **critical**
  （只是改登入頁的文案或樣式、session 逾時的提示文字，不算——要動到驗證、授權、token、密碼處理的程式）
- ≤ 2 個檔 **且** 沒動對外介面（API／路由／CLI）**且** 沒動資料結構（schema／migration） → **quick**
- 其他（超過 2 個檔、動到對外介面、新功能、重構） → **standard**

判不準時往上一級靠。**預設不是 standard —— 是「先判定、後宣告」。**

## 判級由 hook 強制（不靠自律）

寫程式碼檔前沒有 `.claude/taskmaster-data/.current-task-mode`（或超過 8 小時未更新）會被
`pre-tool-use.sh` 擋下，deny 訊息附判級表與寫入指令。**別等被擋才判**——先判定、宣告、寫入：

> 判定 **quick**（2 個檔、沒動 API 或 schema）→ 直接實作 + 1 個 happy-path 驗證，跳過 plan/TDD。

不攔：`.md`、`.json`、`.claude/**`、`docs/**`、依賴與建置產物；純問答、檢視、研究不需分級。
逃生門：`/suggest-mode off` 或 `TASKMODE_GATE=off`。
`/plan`、`/tdd`、`/verify` 依模式的行為差異寫在各自的指令檔。

## 例外與升級

執行中發現複雜度超過初始評估時：

- quick → standard：發現要動第 3 個檔、或碰到對外介面／資料結構，主動提示「升級到 standard，要先 `/plan` 嗎？」
- standard → critical：發現觸碰金流/認證，停止並提示升級

**降級不允許**（避免規避測試）。

## 相關

`testing-standards`（覆蓋率）・`plan-format`（plan 門檻）・`.claude/hooks/pre-tool-use.sh`（閘門）
