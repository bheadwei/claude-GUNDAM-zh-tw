# shop-clean 參考資料（使用者滿意的「範例電商」）

來源：使用者提供的 artifact 預覽（現行 `index.html` ＋內嵌 data.js），2026-11-05 由主模型抄出。
用途：`make-fixture.sh shop-clean` 照這份重建輸入（架構文件 5.1／5.5、WBS、改動檔），
讓現行 overview.sh 產出等價的 data.js。也是階段 3「不退步」的視覺基準。

## 群組（5.1 subgraph）

| id | label |
|---|---|
| g1 | 用戶端 |
| g2 | 服務層 |
| g3 | 資料層 |

## 模組（5.5 模組表）

| id | 模組 | 群組 | 形狀 | 路徑 | 職責 | pos (col,row) |
|---|---|---|---|---|---|---|
| web | Web App | g1 | box | `src/web/**` | 前端 | 0,0 |
| gateway | API Gateway | g2 | box | `src/gateway/**` | 路由、認證、限流 | 1,0 |
| svc-a | 服務 A | g2 | box | `src/services/a/**` | 訂單 | 2,0 |
| svc-b | 服務 B | g2 | box | `src/services/b/**` | 會員 | 2,1 |
| db | 資料庫 | g3 | db（`[( )]`） | `migrations/**`, `src/db/**` | 持久化 | 3,0 |
| cache | 快取 | g3 | db（`[( )]`） | `src/cache/**` | 快取 | 3,1 |

## 邊（5.1 mermaid）

web → gateway、gateway → svc-a、gateway → svc-b、svc-a → db、svc-b → cache（皆無標籤）

## WBS（里程碑「M1 基礎」）

| # | 任務 | 模組 | 狀態 |
|---|---|---|---|
| 1.1 | 建 gateway | gateway | ✅ |
| 1.2 | 前端購物車 | web | 🔄（本次任務，`.current-task` = 1.2） |
| 1.3 | 訂單服務 | svc-a | ✅ |
| 1.4 | 訂單退款 | svc-a | ✅ |
| 1.5 | 會員點數 | svc-b | 🚫 阻塞 |
| 1.6 | 資料庫 | db | ✅ |
| 1.7 | CI | （無） | ⏳ |

預期燈號：web wip、gateway done、svc-a done、svc-b issue、db done、cache todo；unmappedTasks = [1.7]

## 本次改動（相對 main 分岔點）

| 檔案 | 模組 | 新檔 | +/− |
|---|---|---|---|
| src/services/a/create.ts | svc-a | 是 | +1 |
| src/web/Cart.tsx | web | 是 | +2 |
| src/web/a.ts | web | 否 | +1 / −0 |

注意：計畫寫「每個模組 2–5 個程式檔（Python＋TS）」，上表只有改動檔；其餘基礎檔由產生器補，
但不能讓改動清單多出上表以外的檔（先 commit 基礎檔，再造上表三個改動）。
