---
name: postgres-patterns
description: PostgreSQL 資料庫模式 — 查詢優化、Schema 設計、索引策略及安全性（RLS）。基於 Supabase 最佳實踐。
origin: ECC
---

# PostgreSQL 模式速查

PostgreSQL 最佳實踐速查表。

## 啟動時機

- 撰寫 SQL 查詢或 Migration
- 設計資料庫 Schema
- 排查慢查詢
- 實作 Row Level Security
- 設定 Connection Pooling

## 速查表

### 索引類型對照

| 查詢模式 | 索引類型 | 範例 |
|:---|:---|:---|
| `WHERE col = value` | B-tree (預設) | `CREATE INDEX idx ON t (col)` |
| `WHERE col > value` | B-tree | `CREATE INDEX idx ON t (col)` |
| `WHERE a = x AND b > y` | Composite | `CREATE INDEX idx ON t (a, b)` |
| `WHERE jsonb @> '{}'` | GIN | `CREATE INDEX idx ON t USING gin (col)` |
| `WHERE tsv @@ query` | GIN | `CREATE INDEX idx ON t USING gin (col)` |
| 時序範圍查詢 | BRIN | `CREATE INDEX idx ON t USING brin (col)` |

### 資料型態對照

| 用途 | 正確型態 | 避免使用 |
|:---|:---|:---|
| ID | `bigint` | `int`、random UUID |
| 字串 | `text` | `varchar(255)` |
| 時間戳 | `timestamptz` | `timestamp` |
| 金額 | `numeric(10,2)` | `float` |
| 旗標 | `boolean` | `varchar`、`int` |

### 常用模式

**複合索引順序：**
```sql
-- 等值欄位放前面，範圍欄位放後面
CREATE INDEX idx ON orders (status, created_at);
-- 適用：WHERE status = 'pending' AND created_at > '2024-01-01'
```

**覆蓋索引：**
```sql
CREATE INDEX idx ON users (email) INCLUDE (name, created_at);
-- 免去 table lookup，直接從索引取 email, name, created_at
```

**部分索引：**
```sql
CREATE INDEX idx ON users (email) WHERE deleted_at IS NULL;
-- 更小的索引，只包含未刪除的使用者
```

**RLS 政策（優化寫法）：**
```sql
CREATE POLICY policy ON orders
  USING ((SELECT auth.uid()) = user_id);  -- 用 SELECT 包起來！
```

**UPSERT：**
```sql
INSERT INTO settings (user_id, key, value)
VALUES (123, 'theme', 'dark')
ON CONFLICT (user_id, key)
DO UPDATE SET value = EXCLUDED.value;
```

**游標分頁：**
```sql
SELECT * FROM products WHERE id > $last_id ORDER BY id LIMIT 20;
-- O(1) 效能，OFFSET 分頁則是 O(n)
```

**佇列處理：**
```sql
UPDATE jobs SET status = 'processing'
WHERE id = (
  SELECT id FROM jobs WHERE status = 'pending'
  ORDER BY created_at LIMIT 1
  FOR UPDATE SKIP LOCKED
) RETURNING *;
```

### 反模式偵測

```sql
-- 找出沒有索引的外鍵
SELECT conrelid::regclass, a.attname
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid AND a.attnum = ANY(i.indkey)
  );

-- 找出慢查詢
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC;

-- 檢查表膨脹
SELECT relname, n_dead_tup, last_vacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

### 設定範本

```sql
-- 連線限制（依 RAM 調整）
ALTER SYSTEM SET max_connections = 100;
ALTER SYSTEM SET work_mem = '8MB';

-- 逾時設定
ALTER SYSTEM SET idle_in_transaction_session_timeout = '30s';
ALTER SYSTEM SET statement_timeout = '30s';

-- 監控
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 安全預設
REVOKE ALL ON SCHEMA public FROM public;

SELECT pg_reload_conf();
```
