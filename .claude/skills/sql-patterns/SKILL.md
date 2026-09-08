---
name: sql-patterns
description: 關聯式資料庫的通用設計與查詢原則，加上 PostgreSQL／SQL Server／SQLite 的**跨引擎差異對照**（線上加索引、加欄位、UPSERT、分頁語法、型態選用）。Use when 要寫或調效能 SQL、選索引、設計資料表、查詢變慢、或要把某個引擎的作法搬到另一個引擎。**MUST BE USED before 把任何 SQL 寫法從一個引擎照搬到另一個引擎** —— 語法看起來通用但線上行為差很多。PostgreSQL 深入內容見 `postgres-patterns`（唯一來源）；文件型資料庫見 `nosql-patterns`。
---

# SQL 模式（跨引擎）

本檔管**通用原則**與**引擎差異**。單一引擎的深入速查不在這裡：

| 引擎 | 深入內容 |
|---|---|
| PostgreSQL | `.claude/skills/postgres-patterns/SKILL.md`（唯一來源，勿在此重述） |
| SQL Server / SQLite | 本檔的對照表 + 下方各節 |
| MongoDB／Firestore | `.claude/skills/nosql-patterns/SKILL.md` |

Schema 變更的**流程**（zero-downtime、expand/contract、回滾）見
`.claude/skills/database-migrations/SKILL.md`。本檔只講「寫成什麼樣」。

## 啟動時機

- 設計資料表、選索引、決定型態
- 查詢變慢要調效能
- **把某個引擎的 SQL 搬到另一個引擎**（最容易出事的情境）
- Code review 看到可疑的查詢寫法

---

## 跨引擎差異對照（最容易踩雷的五件事）

| 動作 | PostgreSQL | SQL Server | SQLite |
|---|---|---|---|
| **線上加索引**（不鎖表） | `CREATE INDEX CONCURRENTLY`（不能在交易內） | `WITH (ONLINE = ON)`，**版本／版次相關，動手前先確認你的版本支援** | **沒有**。建索引會鎖住寫入；大表要挑離峰 |
| **加 NOT NULL 欄位** | 帶常數 `DEFAULT` 時為 metadata-only（11+）；否則要 expand/contract | 帶常數 `DEFAULT` 時多為 metadata-only（2012+） | **必須**同時給非 NULL `DEFAULT`，否則直接失敗 |
| **改欄位型別／加約束** | `ALTER COLUMN TYPE`（可能重寫整表） | `ALTER COLUMN`（可能重寫整表） | **不支援**。要走「建新表 → 複製 → 改名」的重建流程 |
| **UPSERT** | `INSERT ... ON CONFLICT DO UPDATE` | `MERGE`（有已知並發race，高並發下改用 `INSERT ... WHERE NOT EXISTS` 加適當隔離級別） | `INSERT ... ON CONFLICT DO UPDATE`（3.24+） |
| **分頁** | `LIMIT n OFFSET m` | `OFFSET m ROWS FETCH NEXT n ROWS ONLY`（需 `ORDER BY`） | `LIMIT n OFFSET m` |

> **這張表就是本 skill 存在的理由。** 「加個欄位」在三個引擎是三種風險等級：
> PG／MSSQL 帶 default 可能是瞬間完成，SQLite 可能要重建整張表。

### 型態選用差異

| | PostgreSQL | SQL Server | SQLite |
|---|---|---|---|
| 字串 | `text`（不必怕，沒有效能懲罰） | **`NVARCHAR`**，不要用 `VARCHAR`（非 Unicode 會吃掉中文） | `TEXT`（動態型別，宣告只是 affinity） |
| 時間 | `timestamptz`（**永遠帶時區**） | **`DATETIME2`**，不要用 `DATETIME`（精度與範圍都較差） | 無時間型別 → 存 ISO-8601 字串或 Unix epoch，**全專案統一一種** |
| 布林 | `boolean` | `BIT` | `INTEGER` 0/1 |
| JSON | `jsonb`（可索引） | `NVARCHAR` + `JSON_VALUE`（**不能直接索引，要建 computed column**） | `TEXT` + JSON 函式 |

### SQLite 專屬注意

- **單一 writer**：寫入是序列化的。務必開 WAL（`PRAGMA journal_mode=WAL`）讓讀寫並行，
  並設 `PRAGMA busy_timeout`，否則高並發下拿到 `SQLITE_BUSY`
- **動態型別**：`age INTEGER` 塞得進字串。約束要靠 `CHECK` 或應用層，別假設引擎會擋
- **外鍵預設關閉**：每個連線都要 `PRAGMA foreign_keys=ON`

### SQL Server 專屬注意

- **每張表只有一個 clustered index**，它決定實體排列順序 —— 選錯代價比一般索引大得多
- 預設隔離級別用鎖，讀會擋寫。考慮開 `READ_COMMITTED_SNAPSHOT`
- 預存程序開頭寫 `SET NOCOUNT ON`

---

## 通用原則（三個引擎都適用）

### 索引

- **高選擇性欄位才值得建**。`status` 只有 3 種值時，單獨索引幾乎沒用
- **複合索引看最左前綴**：`(a, b, c)` 能服務 `WHERE a`、`WHERE a AND b`，
  **不能**服務 `WHERE b`
- 索引不是免費的：每個索引都讓寫入變慢、佔空間。**先量再加**
- 外鍵欄位通常要索引（很多引擎不會自動建）

### 破壞索引的寫法

```sql
-- ❌ 對欄位套函式 → 索引失效
WHERE LOWER(email) = 'a@b.com'
WHERE DATE(created_at) = '2026-09-08'

-- ✅ 改成範圍條件，或建對應的函式／computed 索引
WHERE email = 'a@b.com'                 -- 存入時就正規化
WHERE created_at >= '2026-09-08' AND created_at < '2026-09-09'
```

### 查詢反模式

| 反模式 | 問題 | 改法 |
|---|---|---|
| **N+1 查詢** | 迴圈裡查單筆，1000 筆資料 = 1001 次往返 | 一次 `WHERE id IN (...)`，或 join |
| **大位移 `OFFSET`** | `OFFSET 100000` 要掃過並丟掉十萬列，愈後面愈慢 | **keyset 分頁**：`WHERE id > :last_id ORDER BY id LIMIT n` |
| **`SELECT *`** | 傳無用欄位、破壞覆蓋索引、schema 一改就壞 | 明列欄位 |
| **在交易裡呼叫外部 API** | 鎖被持有到網路往返結束 | 交易只包資料庫操作 |
| **用 `COUNT(*)` 做存在判斷** | 掃全表 | `EXISTS`／`LIMIT 1` |

### 交易與連線

- **交易要短**。長交易在任何引擎都會擋住別人
- 一律**參數化查詢**，永不字串拼接（見 `.claude/rules/security.md`）
- Serverless／每請求一個連線的架構要走 **connection pooler**，
  否則連線數會先爆掉（PG 尤其明顯）

---

## 反模式

- ❌ 把 PG 的 `CREATE INDEX CONCURRENTLY` 照抄到 MSSQL 或 SQLite（前者語法不同、後者沒有）
- ❌ SQL Server 用 `VARCHAR` 存中文
- ❌ SQLite 假設 `ALTER TABLE` 能改型別
- ❌ 在 `WHERE` 對欄位套函式後抱怨索引沒用
- ❌ 用 `OFFSET` 做無限滾動
- ❌ 沒量測就先加一堆索引

## 相關

- `postgres-patterns` — PostgreSQL 深入（唯一來源）
- `nosql-patterns` — 文件型資料庫
- `database-migrations` — schema 變更的流程與回滾
- `.claude/rules/security.md` — SQL 注入防護
