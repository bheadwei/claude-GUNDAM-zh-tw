# 任務分級規則（Task Mode）

定義單一任務的執行強度，避免「小修改也被迫跑完整 plan → tdd → verify 流程」。

## 三檔任務模式

| 模式 | 適用條件 | 流程 | 覆蓋率 |
|---|---|---|---|
| `quick` | < 30min ・ 單檔 ・ 文案/樣式/小 bug ・ 設定調整 | 直接寫 → `/verify quick` | 不檢查 |
| `standard` | 1-4h ・ 跨檔 ・ 新增功能 ・ 重構 | `/plan` → `/tdd` → `/verify` | 80% |
| `critical` | 金流 ・ 認證 ・ 安全 ・ migration ・ 核心商業邏輯 | `/plan`（必要）→ `/tdd` → `/code-review` → `/verify pre-pr` | 100% |

## 自動分級啟發式

- 單檔 **且** < 30min **且** 屬「文案/樣式/設定/小 bug」 → **quick**
- 觸及「auth/認證/payment/金流/billing/security/安全/migration/遷移/核心商業邏輯」 → **critical**
- 其他（跨檔、新功能、重構） → **standard**

判不準時往上一級靠。**預設不是 standard —— 是「先判定、後宣告」。**

## 判級由 hook 強制（不靠自律）

`pre-tool-use.sh` 在你要寫入程式碼檔時檢查 `.claude/taskmaster-data/.current-task-mode`：

- **不存在** → 擋下該次寫入，要求你先判級、宣告理由、寫入模式檔，再重試
- **超過 8 小時未更新** → 自動清除並重新要求判級（`TASKMODE_TTL_HOURS` 可調）

宣告格式（一句話，讓使用者能當場否決）：

> 判定 **quick**（單檔、<30min、樣式調整）→ 直接實作 + 1 個 happy-path 驗證，跳過 plan/TDD。

寫入：`echo standard > .claude/taskmaster-data/.current-task-mode`

**不受閘門攔截的寫入**：`.md`、`.json`、`.claude/**`、`docs/**`、依賴與建置產物。
純問答、檢視、研究不需分級。

### 逃生門

| 方式 | 效果 |
|---|---|
| `/suggest-mode off` | 完全關閉閘門（連同其他建議注入） |
| `TASKMODE_GATE=off` | 環境變數，單次或整個 session 關閉 |

## 設定檔

`.claude/taskmaster-data/.current-task-mode`，純文字單值 `quick` / `standard` / `critical`。

寫入時機：`/task-next` 選定任務時、hook 觸發判級時、`/tdd <mode>` 行內參數覆寫時。
清除時機：`/verify` 完成任務時，或 hook 的 TTL 過期（後者是機器保證，前者是自律）。

## 各指令如何讀取

| 指令 | 行為差異 |
|---|---|
| `/plan` | quick 跳過；standard 依門檻（跨 ≥2 檔 或 ≥1h）；critical 一律需要 |
| `/tdd` | quick 走 Fast Lane（不強制 test-first、不檢查覆蓋率）；standard 標準流程；critical 加 `/code-review` |
| `/verify` | quick → `verify quick`；standard → `verify full`；critical → `verify pre-pr` |

覆蓋率門檻的唯一來源是 `testing-standards` skill，不在其他地方重述。

## 例外與升級

執行中發現複雜度超過初始評估時：

- quick → standard：發現要動多檔，主動提示「升級到 standard，要先 `/plan` 嗎？」
- standard → critical：發現觸碰金流/認證，停止並提示升級

**降級不允許**（避免規避測試）。

## 相關

- `testing-standards` skill — 覆蓋率門檻
- `plan-format` skill — Plan 啟動門檻與格式
- `.claude/hooks/pre-tool-use.sh` — 閘門實作
