---
status: 已接受
date: 2026-11-06
decision-makers: [使用者]
---

# ADR-2026-11-06-002: 專案地圖可點模組「展開」看內部檔案與 import 關係；檔案層級的邊由 `overview-scan.sh` 保留、`overview.sh` 依上限寫進 data.js；框外依賴分成其他模組／資料庫／外部套件三類

## 背景

地圖（ADR-2026-11-05-001）只畫到模組層：一個模組是一張卡、模組間一條線。使用者要看「一個模組裡面現在長什麼樣」——
哪些檔案、誰 import 誰、對外碰了哪些模組、資料庫、套件——而且要永遠是最新的，所以只能從程式碼掃。
地圖計畫階段 1 的 `overview-scan.sh` 本來就要逐檔解析 import 行再彙總成模組邊（實測 5,000 檔整條約 1.0 秒、6 個行程，
`overview-scan-bench-2026-11-05.md`），檔案層級的邊是現成的中間結果，但提案 3.1 第 6 步把它彙總後丟掉、第三方 import 也直接丟掉。
使用者知道這張圖畫的是程式結構、不是業務順序；業務順序由架構文件的資料流節負責（ADR-2026-11-06-001）。
檔案層級的資料要不要進 data.js、大專案怎麼設上限、外部依賴怎麼歸類、畫面怎麼審？

## 決策

### 1. 資料：掃描保留全部，data.js 只放有上限的一份

| 層 | 放什麼 | 上限 |
|---|---|---|
| `overview-scan.sh` → `skeleton.json` | 每條 import／http 的檔案層級紀錄 `fileEdges[]`：`{from: 路徑, to: 路徑或 null, ext: "db:<名>"／"pkg:<名>" 或 null, source: "import"／"http"}`。**同一趟 awk 多輸出一種行，不加行程** | 不設（快取檔、模型不讀）；`scan.truncated` 時沒有邊，同現行 |
| `overview.sh` → data.js | 每個模組一份 `inner`（見下）＋頂層 `flows` | 每模組節點 ≤ 60、模組內邊 ≤ 200、框外目標 ≤ 15 |

模組層的邊（`edges[]`）與階段 1 的驗收**完全不變**：第三方套件照舊不產生模組邊（`import React` → 沒有模組邊）。

**data.js 新增欄位（schema 仍是 2，只加欄位；畫面遇到沒有這些欄位就顯示「沒有內部資料」）**——這是畫面階段可以平行開工的合約，欄位名在本 ADR 定死：

```js
modules[].inner = {
  root: "backend/app/orders",          // 節點路徑相對於它（模組多個路徑時取共同前綴）
  nodes: ["api.py", "service.py", "repo/"],   // 檔案；結尾 "/" 表示整個子目錄併成一個節點
  folded: 12,                          // 併進「其他 N 檔」的檔數，0 表示沒有
  edges: [[0, 1, 3]],                  // 模組內：[from 索引, to 索引, import 次數]
  out: [[1, "m:payments", 2, "import"], [2, "db:sqlalchemy", 4, "import"], [0, "pkg:httpx", 1, "import"]],
  outMore: 0                           // 超過上限沒列出的框外目標數
}                                      // 掃描截斷、或被大小上限丟掉時為 null
modules[].flows = [0, 2]               // 指向頂層 flows 的索引；沒有時 []
flows = [{ title: "orders 結帳 — 正常結帳（ORD-01、ORD-02）", line: 120,
           participants: ["web", "orders", "inventory", "pay", "mq"], modules: ["orders", "inventory"] }]
```

**上限與摺疊**（常數放 `overview.sh`，可用環境變數覆寫）：

1. 模組檔案數 ≤ `OVERVIEW_INNER_MAX_NODES`（60）→ 每個檔一個節點
2. 超過 → 模組根下一層的子目錄各併成一個節點（`repo/`），根目錄的檔照舊
3. 仍超過 → 依進出邊數保留前 59 個，其餘計入 `folded`（畫面畫一個「其他 N 檔」）；碰到被併檔案的模組內邊丟掉
4. 模組內邊依次數保留前 `OVERVIEW_INNER_MAX_EDGES`（200）條；框外目標依「其他模組 → 資料庫 → 外部套件」、同類依次數，保留前 `OVERVIEW_INNER_MAX_OUT`（15）個，其餘計入 `outMore`
5. 測試目錄照現行只計數，不進 `inner`

最壞情況估算：40 個模組 × 約 4.7KB ≈ 190KB，加上現有內容仍在 data.js 的 `OVERVIEW_MAX_BYTES`（預設 512KB）內。
`shrink_data` 多兩級：**最先**丟「不是本次 plan 預計會動、也沒有本次改動」的模組的 `inner`；現有四級都丟完仍超過，**最後**丟全部 `inner`。被丟的模組畫面顯示「資料量超過上限，未保留內部細節（調高 `OVERVIEW_MAX_BYTES`）」。

不採「每個模組另寫一個 `overview/inner/<id>.js`、點開才載入」：多檔要各自原子寫入、審閱 artifact 要內嵌、SSH 使用者要整個目錄下載，而上限已把大小壓在可接受範圍（見「何時該重新考慮」）。

### 2. 框外依賴怎麼歸類（在 `overview-scan.sh` 解析 import 時決定）

判斷順序，先符合者為準：

| 順序 | 條件 | 歸類 | 畫面 |
|---|---|---|---|
| 1 | import 解析得到 repo 內另一個模組的檔；或 X6 的前端 fetch 對到後端路由 | `m:<模組 id>`（`source` 照實寫 `import`／`http`） | 框外「其他模組」欄，虛線 |
| 2 | 套件名在資料庫清單 `SCAN_DB_PKGS`（＋`project.json` 的 `overview.scan.dbPackages`） | `db:<套件名>` | 框外「資料庫」欄，虛線 |
| 3 | 套件名在標準庫清單 `SCAN_STD_PY`／`SCAN_STD_JS`，或屬 Go 標準庫、`java.`／`javax.`／`kotlin.`、`System.`（不在 db 清單者） | 丟掉 | — |
| 4 | 其他解析不到 repo 內的 import | `pkg:<套件名>` | 框外「外部套件」欄，虛線 |

- 套件名：Python 取第一段（`from sqlalchemy.orm import` → `sqlalchemy`）；TS／JS 取第一段，scoped 取兩段（`@prisma/client`），去掉 `node:` 前綴；Go 取 module 路徑前三段；Java／C# 取前兩段
- `SCAN_DB_PKGS` 起始清單（資料庫驅動、ORM、快取、搜尋引擎）：Python `sqlalchemy psycopg psycopg2 asyncpg pymysql pyodbc pymssql sqlite3 pymongo motor redis elasticsearch oracledb cx_Oracle`；JS `pg mysql2 mssql mongodb mongoose redis ioredis @prisma/client typeorm sequelize knex drizzle-orm better-sqlite3`；Go／Java／C# 各放常見的 2–4 個（`database/sql`、`java.sql`、`System.Data.SqlClient`、`Microsoft.Data.SqlClient`、`Npgsql`、`Microsoft.EntityFrameworkCore`、`StackExchange.Redis`）
- 標準庫清單只列常用的約 50 個（`os sys re json typing pathlib datetime logging collections asyncio …`／`fs path os url crypto http https stream events util child_process …`），**不追求完整**：沒列到的標準庫會顯示成外部套件，但被框外上限與「依次數排序」壓在後面
- **不讀 `package.json`、`pyproject.toml` 判斷「宣告過的依賴」**：Python 的 import 名與套件名常不同（`cv2`／`opencv-python`、`PIL`／`Pillow`、`yaml`／`PyYAML`），用宣告比對會把 OCR 這類服務最重要的依賴漏掉

### 3. 資料流連結（`flows`）

`overview.sh` 讀架構文件時，找 `^## [0-9]+\. 資料流` 一節（節名常數 `OVERVIEW_FLOW_SECTION="資料流"`，不綁節號），
節內每個 `###` 是一條流程，只解析其後 mermaid 區塊裡的 `participant`／`actor` 宣告行取 id（ADR-2026-11-06-001 的參與者規則）：

- id 等於模組 id → 該模組；等於分組 id → 該分組全部模組
- 一條流程**沒有任何**參與者對得到模組 → 一則 notice「資料流「<標題>」對不到任何模組（模組改名？）」；部分對不到是正常的（外部系統、佇列）
- 沒有架構文件、或沒有資料流節 → `flows: []`，不出 notice
- `sequenceDiagram` 區塊不參與 5.1 容器圖的挑選（現行只挑 `graph`／`flowchart`，加測試鎖住）
- 架構文件自動段（第 5 節）**不放檔案層級**：自動段給客戶看模組全貌，檔案層級只在地圖

### 4. 畫面：點進模組，不在全圖原地展開

- 右側欄（點模組時）多兩樣：「展開內部」按鈕、「參與的資料流」清單（標題＋`docs/architecture.md` 第 N 行，連到該檔）
- 展開＝畫布切換成該模組的內部圖，頁首麵包屑「全圖 › <模組名>」，`Esc` 或點「全圖」返回；平移、縮放、小地圖沿用
- 內部圖：模組框內是檔案節點，依 import 方向分層由左到右排（環狀依賴略過回邊）；框外右側分「其他模組／資料庫／外部套件」三欄，虛線連過去；`folded`、`outMore` 各畫成一個「其他 N 個」節點
- 本次改動（git diff）碰到的檔，節點帶既有的改動標記；點檔案節點，右側欄列出它 import 誰、被誰 import
- 不在全圖原地展開：原地展開要重排整張圖、卡片位置會跳，違反 ADR-003「互動模型不變」
- 品質照 ADR-003 的 Q1–Q14；`qa-check.js` 的六項在內部圖也要全為 0／false
- **`index.html` 上限從 50KB 調成 64KB**（`check-counts.sh` 的 51200 → 65536、頁首註解同步）：階段 3 預估 40–45KB，展開約再加 7–9KB；64KB 仍在 ADR-003 原訂的 80KB 內（X9 當時選 50KB 是因為 45KB 放得下，不是使用者的限制）

### 5. 開發時先給使用者預覽（比照地圖計畫階段 3）

畫面完成後、合併前，主模型用 shop-clean 的 data.js 手補展示資料——一個 5 個檔的小模組、一個超過 60 個檔而摺疊成子目錄＋「其他 N 檔」的模組、
框外三類各至少一個、`outMore` > 0、兩條資料流——內嵌進 worktree 裡 `index.html` 的複本發成 artifact → `AskUserQuestion`：確認（Recommended）／要改（直接輸入要改的地方）。
選「要改」→ 回 ui-builder 修完再發一次。問答一次寫入 `.claude/qa-history/<時間>-overview-expand-review.md`。**沒有「確認」不合併。**

### 6. 硬限制照舊

不新增 hook；腳本只改 `overview-scan.sh`（地圖計畫唯一新腳本）與 `overview.sh`；jq 最低 1.7.1（地圖計畫 X12）；
中文路徑、gawk／mawk、Windows 行程成本的既有限制全部適用；背景重掃照現行節流，不因展開資料多一次觸發。

## 替代方案

| 方案 | 優點 | 否決理由 |
|---|---|---|
| 不做展開（只有模組層） | 不用改 | 使用者要看模組內部現況；做法 1 的文件只畫業務順序，看不到程式結構 |
| data.js 放完整檔案層級（不設上限） | 最完整 | 5,000 檔約 1MB 以上，超過 512KB 上限，畫面也排不開 |
| 每模組一個 `inner/<id>.js`，點開才載 | data.js 小 | 多檔原子寫入、審閱 artifact 要內嵌、SSH 要整目錄下載；上限已把大小壓住 |
| 外部套件用 `package.json`／`pyproject.toml` 的宣告比對 | 標準庫自然被排除 | Python import 名≠套件名，`cv2`、`PIL`、`yaml` 這類關鍵依賴會被漏掉；還要多讀檔、多解析兩種格式 |
| 外部依賴只分「模組／外部」兩類 | 規則最少 | 使用者明確要看到資料庫；資料庫是跨服務資料流的關鍵節點 |
| 全圖原地展開模組 | 不用切畫面 | 要重排整張圖、卡片會跳；超過 ADR-003 的互動模型 |
| 接 codegraph 取呼叫圖 | 函式層級、最準 | ADR-001 已否決（要 Node、原生套件）；檔案層級的 import 已夠回答「模組內長什麼樣」 |
| 頁面上限維持 50KB，展開放另一支 `expand.js` | 不動 check-counts | 多一個要複製、要內嵌進 artifact 的檔；80KB 的 ADR-003 上限內調到 64KB 較單純 |

## 後果

**得到：**
- 點模組就看得到內部檔案、import 關係、對外碰了哪些模組／資料庫／套件，永遠跟程式碼一致，0 token
- 點模組也看得到它參與哪些資料流，連到架構文件那一節
- 掃描不多行程；data.js 的大小有上限，超過時有固定的丟棄順序

**犧牲：**
- 檔案層級仍是 regex 近似，看不到反射、DI、動態 import；Java／C# 準度較低（同 ADR-001）
- 標準庫清單不完整，少數標準庫會顯示成外部套件
- 大模組被摺疊成子目錄後，看不到子目錄內部的檔
- `overview.sh` 再多一個出口（`inner`、`flows`）；`index.html` 變大到約 50–55KB

**何時該重新考慮：**
- 實測專案的 data.js 常因 `inner` 觸發 shrink → 改成每模組一個 `inner/<id>.js` 點開才載
- 使用者常抱怨某類套件被誤歸類 → 擴充清單，或改讓 `project.json` 覆寫整份標準庫清單
- 摺疊後的子目錄節點常被點來看 → 允許在內部圖裡再展開子目錄（一層）

## 確認方式

- [T] `backend/app/orders/api.py` 寫 `from app.orders.service import x` 與 `from sqlalchemy.orm import Session` 與 `import httpx` 與 `import os` → `orders` 的 `inner.edges` 有 api→service；`out` 含 `db:sqlalchemy`、`pkg:httpx`，不含 `os`
- [T] 前端 `import x from '@/stores/cart'`（另一模組）→ 該檔的 `out` 含 `m:stores`、`source:"import"`；X6 的 fetch 對到後端路由 → `m:<後端模組>`、`source:"http"`
- [T] 模組有 61 個檔、分在 3 個子目錄 → `nodes` 含 3 個以 `/` 結尾的節點；`gen-large.sh 5000` → 每個模組 `nodes` ≤ 60、`edges` ≤ 200、`out` ≤ 15，`skeleton.json` 的 `fileEdges` 數 ≥ data.js 各模組 `edges`＋`out` 的總和
- [T] `import React from 'react'` → 模組層 `edges[]` 不變（階段 1 驗收照過），只有 `inner.out` 多 `pkg:react`
- [T] `OVERVIEW_SCAN_MAX_FILES=10` → 所有 `inner` 為 null
- [T] `OVERVIEW_MAX_BYTES` 設小 → 先丟非本次相關模組的 `inner`；再小 → 全部 `inner` 為 null、其他欄位照既有四級處理
- [T] 架構文件的資料流節有一條流程宣告 `participant orders`、`participant pay` → `flows[0].modules` 為 `["orders"]`、`orders` 的 `flows` 含 0；流程的參與者全部對不到模組 → 一則 notice；`sequenceDiagram` 不被挑成容器圖
- [T] `gen-large.sh 5000`：`overview-scan.sh` 的行程數與加入本功能前相同；`overview.sh` 整條在 Windows 多花 ≤ 1 秒
- [C] `check-counts.sh`：`index.html` ≤ 65536 bytes
- [M] 審閱 artifact 看得到：麵包屑、框內分層的檔案、框外三欄虛線、「其他 N 檔」與「其他 N 個」節點、改動標記、右側欄的資料流清單；使用者選「確認」後才合併
- [M] shop-clean 與 messy-fullstack × 390／1440 × 淺／深，在內部圖跑 `qa-check.js` 六項全為 0／false

## 相關

- 審閱頁（主模型產）：`https://claude.ai/artifact/RskXDQm9VJ6eMGF3AEVpga`
- 設計提案：`.claude/context/decisions/architect-2026-11-06-1100.md`
- 部分修訂：ADR-2026-11-05-001（提案 3.1 第 6 步「第三方 import 丟掉」→ 模組層照舊丟、檔案層級保留並歸類）、ADR-2026-11-05-003 的頁面上限（地圖計畫 X9 的 50KB → 64KB，仍在本 ADR-003 的 80KB 內）
- 相關：ADR-2026-11-06-001（資料流節的參與者規則）、ADR-2026-11-05-007（自動段不放檔案層級）、ADR-2026-11-05-002（說明層不變，檔案節點沒有 LLM 說明）
- 依據：`.claude/context/decisions/overview-scan-bench-2026-11-05.md`（掃描行程與秒數）、`.claude/scripts/overview.sh` 的 `MAX_BYTES`（512KB）與 `shrink_data`
- 實作：地圖計畫 `.claude/taskmaster-data/plans/adhoc-2026-11-05-overview-from-code.md`（新增兩個階段，見 handoff）
