---
name: database-migrations
description: 資料庫 Migration 最佳實踐 — Schema 變更、資料遷移、Rollback 及 Zero-downtime 部署，涵蓋 PostgreSQL、MySQL 及常見 ORM（Prisma、Django、TypeORM 等）。
origin: ECC
---

# 資料庫 Migration 模式

正式環境安全、可逆的 Schema 變更。

## 啟動時機

- 建立或修改資料庫表
- 新增/移除欄位或索引
- 執行資料遷移（回填、轉換）
- 規劃 Zero-downtime Schema 變更
- 為新專案設定 Migration 工具

## 核心原則

1. **所有變更都是 Migration** — 絕不手動修改正式資料庫
2. **正式環境只有前進** — Rollback 使用新的前進 Migration
3. **Schema 和資料 Migration 分開** — 不在同一個 Migration 中混用 DDL 和 DML
4. **用正式規模的資料測試** — 100 筆能跑的 Migration，10M 筆可能鎖表
5. **部署後的 Migration 不可修改** — 建新的，不改舊的

## Migration 安全檢查清單

每次執行前確認：

- [ ] Migration 有 UP 和 DOWN（或明確標記為不可逆）
- [ ] 大表不會全表鎖定（使用 concurrent 操作）
- [ ] 新欄位有預設值或允許 NULL（不要直接加 NOT NULL）
- [ ] 索引用 CONCURRENTLY 建立（既有大表）
- [ ] 資料回填與 Schema 變更在不同 Migration
- [ ] 已在正式資料副本上測試
- [ ] Rollback 計畫已記錄

## PostgreSQL 模式

### 安全新增欄位

```sql
-- 正確：允許 NULL，不鎖表
ALTER TABLE users ADD COLUMN avatar_url TEXT;

-- 正確：帶預設值（Postgres 11+ 瞬間完成，不重寫）
ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;

-- 錯誤：NOT NULL 沒有預設值（需全表重寫）
ALTER TABLE users ADD COLUMN role TEXT NOT NULL;
```

### 不停機建索引

```sql
-- 錯誤：大表會阻塞寫入
CREATE INDEX idx_users_email ON users (email);

-- 正確：非阻塞，允許同時寫入
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);

-- 注意：CONCURRENTLY 不能在交易區塊內執行
```

### 重命名欄位（Zero-Downtime）

不要直接在正式環境重命名。使用 Expand-Contract 模式：

```sql
-- 步驟 1：新增欄位（migration 001）
ALTER TABLE users ADD COLUMN display_name TEXT;

-- 步驟 2：回填資料（migration 002，資料遷移）
UPDATE users SET display_name = username WHERE display_name IS NULL;

-- 步驟 3：更新應用程式碼，同時讀寫新舊欄位
-- 部署應用變更

-- 步驟 4：停止寫入舊欄位，移除（migration 003）
ALTER TABLE users DROP COLUMN username;
```

### 安全移除欄位

```sql
-- 步驟 1：移除應用程式碼中所有對此欄位的引用
-- 步驟 2：部署不含該欄位引用的應用
-- 步驟 3：在下一次 migration 中刪除欄位
ALTER TABLE orders DROP COLUMN legacy_status;
```

### 大量資料遷移

```sql
-- 錯誤：單一交易更新所有列（鎖表）
UPDATE users SET normalized_email = LOWER(email);

-- 正確：批次更新
DO $$
DECLARE
  batch_size INT := 10000;
  rows_updated INT;
BEGIN
  LOOP
    UPDATE users
    SET normalized_email = LOWER(email)
    WHERE id IN (
      SELECT id FROM users
      WHERE normalized_email IS NULL
      LIMIT batch_size
      FOR UPDATE SKIP LOCKED
    );
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    RAISE NOTICE 'Updated % rows', rows_updated;
    EXIT WHEN rows_updated = 0;
    COMMIT;
  END LOOP;
END $$;
```

## Django (Python)

### 工作流程

```bash
# 從 Model 變更產生 migration
python manage.py makemigrations

# 套用 migration
python manage.py migrate

# 查看 migration 狀態
python manage.py showmigrations

# 產生空 migration（自訂 SQL 用）
python manage.py makemigrations --empty app_name -n description
```

### 資料遷移

```python
from django.db import migrations

def backfill_display_names(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    batch_size = 5000
    users = User.objects.filter(display_name="")
    while users.exists():
        batch = list(users[:batch_size])
        for user in batch:
            user.display_name = user.username
        User.objects.bulk_update(batch, ["display_name"], batch_size=batch_size)

def reverse_backfill(apps, schema_editor):
    pass  # 資料遷移，不需反向

class Migration(migrations.Migration):
    dependencies = [("accounts", "0015_add_display_name")]
    operations = [
        migrations.RunPython(backfill_display_names, reverse_backfill),
    ]
```

### SeparateDatabaseAndState

從 Django Model 移除欄位但暫不刪除資料庫欄位：

```python
class Migration(migrations.Migration):
    operations = [
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.RemoveField(model_name="user", name="legacy_field"),
            ],
            database_operations=[],  # 先不動資料庫
        ),
    ]
```

## Prisma (TypeScript/Node.js)

### 工作流程

```bash
npx prisma migrate dev --name add_user_avatar    # 開發：產生並套用
npx prisma migrate deploy                        # 正式：套用待執行的 migration
npx prisma migrate reset                         # 開發：重設資料庫
npx prisma generate                              # 產生 client
```

### 自訂 SQL Migration

Prisma 無法表達的操作（concurrent index、資料回填）：

```bash
npx prisma migrate dev --create-only --name add_email_index
```

```sql
-- 手動編輯 migration.sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users (email);
```

## Zero-Downtime 策略

對關鍵正式環境變更，遵循 Expand-Contract 模式：

```
階段 1：EXPAND
  - 新增欄位/表（允許 NULL 或帶預設值）
  - 部署：應用同時寫入新舊欄位
  - 回填既有資料

階段 2：MIGRATE
  - 部署：應用從新欄位讀取，同時寫入新舊
  - 驗證資料一致性

階段 3：CONTRACT
  - 部署：應用只使用新欄位
  - 在獨立 migration 中移除舊欄位
```

## 反模式

| 反模式 | 為什麼會失敗 | 更好的做法 |
|:---|:---|:---|
| 手動改正式 DB | 無稽核軌跡、不可重複 | 一律使用 migration 檔 |
| 修改已部署的 migration | 導致環境間不一致 | 建立新的 migration |
| NOT NULL 沒預設值 | 鎖表、全表重寫 | 先 nullable → 回填 → 加約束 |
| 大表上直接建索引 | 阻塞寫入 | CREATE INDEX CONCURRENTLY |
| Schema + 資料同一個 migration | 難以 rollback、長交易 | 分開成兩個 migration |
| 先刪欄位再改程式 | 應用報錯 | 先改程式，下次部署再刪欄位 |
