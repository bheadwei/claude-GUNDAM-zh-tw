#!/bin/bash
# make-fixture.sh — 專案圖解的測試資料產生器
#
# 用法：make-fixture.sh <shop-clean|messy-fullstack> <目標目錄>
#   只把檔案寫進目標目錄，不 git init、不 commit，由呼叫端決定。
#   shop-clean 另有環境變數 MAKE_FIXTURE_CHANGES=1：只補「本次改動」那三個檔
#   （先 commit 基礎檔、再帶這個變數跑一次，改動清單才會恰好是那三個）。
#
#   shop-clean      範例電商：5.1／5.5 都有效，WBS 每個任務都標了模組
#   messy-fullstack 髒資料：Python 後端＋TS 前端、C4 架構圖、沒有 5.5、WBS 沒有模組欄、32 個任務
#
# 只用通用電商／查詢系統詞彙，不含任何實測專案的名稱或程式碼。

usage() {
    printf '用法：%s <shop-clean|messy-fullstack> <目標目錄>\n' "${0##*/}" >&2
    exit 2
}

[ $# -eq 2 ] || usage
case "$1" in shop-clean|messy-fullstack) ;; *) usage ;; esac
mkdir -p "$2" || exit 1
DEST=$(cd "$2" && pwd) || exit 1
TD="$DEST/.claude/taskmaster-data"

put() { mkdir -p "$(dirname "$1")" && cat > "$1"; }

shop_changes() {
    printf 'export const create = (id: string) => id\n' | put "$DEST/src/services/a/create.ts"
    printf 'export const Cart = () => null\nexport default Cart\n' | put "$DEST/src/web/Cart.tsx"
    printf 'export const a = 1\nexport const b = 2\n' | put "$DEST/src/web/a.ts"
}

shop_clean() {
    if [ -n "${MAKE_FIXTURE_CHANGES:-}" ]; then shop_changes; return; fi
    printf '{"name":"範例電商","mode":"mvp"}\n' | put "$TD/project.json"
    printf '1.2\n' | put "$TD/.current-task"

    put "$DEST/docs/05_architecture.md" <<'MD'
# 範例電商架構

### 5.1 容器圖

```mermaid
graph TD
    subgraph g1["用戶端"]
        web[Web App]
    end
    subgraph g2["服務層"]
        gateway[API Gateway]
        svc-a[服務 A]
        svc-b[服務 B]
    end
    subgraph g3["資料層"]
        db[(資料庫)]
        cache[(快取)]
    end
    web --> gateway
    gateway --> svc-a
    gateway --> svc-b
    svc-a --> db
    svc-b --> cache
```

### 5.5 MVP 範圍與模組清單

| id | 模組 | 路徑 | 職責 |
|---|---|---|---|
| web | Web App | `src/web/**` | 前端 |
| gateway | API Gateway | `src/gateway/**` | 路由、認證、限流 |
| svc-a | 服務 A | `src/services/a/**` | 訂單 |
| svc-b | 服務 B | `src/services/b/**` | 會員 |
| db | 資料庫 | `migrations/**`, `src/db/**` | 持久化 |
| cache | 快取 | `src/cache/**` | 快取 |
MD

    put "$TD/wbs.md" <<'MD'
# WBS — 範例電商

## M1 基礎

| # | 任務 | 模組 | 狀態 | 優先 |
|---|---|---|---|---|
| 1.1 | 建 gateway | gateway | ✅ 11-01 | 高 |
| 1.2 | 前端購物車 | web | 🔄 進行中 | 高 |
| 1.3 | 訂單服務 | svc-a | ✅ 11-02 | 高 |
| 1.4 | 訂單退款 | svc-a | ✅ 11-03 | 中 |
| 1.5 | 會員點數 | svc-b | 🚫 阻塞 | 中 |
| 1.6 | 資料庫 | db | ✅ 11-01 | 高 |
| 1.7 | CI | web | ⏳ 待處理 | 低 |
MD

    printf 'export const boot = () => 1\n' | put "$DEST/src/web/index.ts"
    printf 'export const App = () => null\n' | put "$DEST/src/web/App.tsx"
    printf 'export const a = 1\n' | put "$DEST/src/web/a.ts"
    printf 'from src.gateway.auth import check\n\ndef route(path):\n    return check(path)\n' | put "$DEST/src/gateway/router.py"
    printf 'def check(path):\n    return True\n' | put "$DEST/src/gateway/auth.py"
    printf 'export const limit = 100\n' | put "$DEST/src/gateway/limit.ts"
    printf 'from src.db.session import connect\n\ndef orders():\n    return connect()\n' | put "$DEST/src/services/a/orders.py"
    printf 'class Order:\n    id = 0\n' | put "$DEST/src/services/a/models.py"
    printf 'from src.cache.client import get\n\ndef members():\n    return get("members")\n' | put "$DEST/src/services/b/members.py"
    printf 'def points(member):\n    return 0\n' | put "$DEST/src/services/b/points.py"
    printf 'def upgrade():\n    return "create table orders"\n' | put "$DEST/migrations/001_init.py"
    printf 'def connect():\n    return None\n' | put "$DEST/src/db/session.py"
    printf 'export const dbUrl = "sqlite://"\n' | put "$DEST/src/db/config.ts"
    printf 'def get(key):\n    return None\n' | put "$DEST/src/cache/client.py"
    printf 'export const key = (n: string) => `shop:${n}`\n' | put "$DEST/src/cache/keys.ts"
}

messy_py() {
    { printf '%b' "$2"; printf '%b' "$3"; } | put "$DEST/backend/app/$1"
}

messy_router() {
    local file="$1" prefix="$2" svc="$3" fn="$4"
    messy_py "$file" "from fastapi import APIRouter\nfrom app.services.$svc import $fn\nfrom .deps import current_user\n\n" \
"router = APIRouter(prefix=\"$prefix\")\n\n@router.get(\"/\")\ndef list_all(user=current_user):\n    return $fn()\n\n@router.get(\"/{item_id}\")\ndef get_one(item_id: int):\n    return $fn()\n\n@router.post(\"/\")\ndef create(payload: dict):\n    return $fn()\n"
}

messy_ts() {
    { printf '%b' "$2"; printf '%b' "$3"; } | put "$DEST/frontend/src/$1"
}

messy_fullstack() {
    local zh="報表匯出與排程作業"
    printf '{"name":"查詢系統","mode":"mvp","overview":{"architectureDoc":"docs/architecture/01_system_architecture.md"}}\n' | put "$TD/project.json"

    printf '[project]\nname = "query-backend"\nversion = "0.1.0"\nrequires-python = ">=3.11"\ndependencies = ["fastapi", "sqlalchemy"]\n' | put "$DEST/backend/pyproject.toml"
    printf '{"name":"query-frontend","version":"0.1.0","dependencies":{"react":"^18.0.0"}}\n' | put "$DEST/frontend/package.json"

    printf '' | put "$DEST/backend/app/api/__init__.py"
    messy_py api/deps.py "from app.core.security import verify_token\n\n" "def current_user():\n    return verify_token(None)\n"
    messy_router api/users.py /api/users user_service list_users
    messy_router api/reports.py /api/reports report_service list_reports
    messy_router api/auth.py /api/auth ldap_service authenticate
    messy_py services/user_service.py "from app.models.user import User\nfrom app.core.db import session\n\n" "def list_users():\n    return session().query(User).all()\n"
    messy_py services/report_service.py "from app.models.report import Report\nfrom app.core.db import session\nfrom . import user_service\n\n" "def list_reports():\n    user_service.list_users()\n    return session().query(Report).all()\n"
    messy_py services/ldap_service.py "from app.core.config import settings\n\n" "def authenticate():\n    return settings.ldap_url\n"
    messy_py models/user.py "from app.core.db import Base\n\n" "class User(Base):\n    id = 0\n"
    messy_py models/report.py "from app.core.db import Base\n\n" "class Report(Base):\n    id = 0\n"
    messy_py core/config.py "" "class settings:\n    ldap_url = \"ldap://example.invalid\"\n    db_url = \"mssql://example.invalid\"\n    redis_url = \"redis://example.invalid\"\n"
    messy_py core/db.py "from .config import settings\n\n" "Base = object\n\ndef session():\n    return settings.db_url\n"
    messy_py core/security.py "from .config import settings\n\n" "def verify_token(token):\n    return settings.ldap_url\n"
    messy_py "$zh/export.py" "from app.services.report_service import list_reports\n\n" "def export_csv():\n    return list_reports()\n"
    messy_py "$zh/schedule.py" "from .export import export_csv\n\n" "def run_daily():\n    return export_csv()\n"
    messy_py utils/helpers.py "" "def slug(text):\n    return text.lower()\n"

    printf 'def test_users():\n    assert True\n' | put "$DEST/backend/tests/test_users.py"
    printf 'def test_reports():\n    assert True\n' | put "$DEST/backend/tests/test_reports.py"

    messy_ts api/client.ts "" "export async function http(url: string) {\n  const res = await fetch(url)\n  return res.json()\n}\n"
    messy_ts api/users.ts "import { http } from './client'\n\n" "export const listUsers = () => http('/api/users')\nexport const loadMe = () => fetch('/api/auth/me')\n"
    messy_ts api/reports.ts "import { http } from './client'\n\n" "export const listReports = () => http('/api/reports')\nexport const createReport = (body: unknown) => fetch('/api/reports', { method: 'POST', body: JSON.stringify(body) })\n"
    messy_ts stores/auth.ts "import { loadMe } from '@/api/users'\n\n" "export const useAuth = () => loadMe()\n"
    messy_ts stores/report.ts "import { listReports } from '@/api/reports'\n\n" "export const useReports = () => listReports()\n"
    messy_ts components/Table.tsx "" "export const Table = () => null\n"
    messy_ts components/Header.tsx "import { useAuth } from '@/stores/auth'\n\n" "export const Header = () => useAuth()\n"
    messy_ts components/Chart.tsx "import { Table } from './Table'\n\n" "export const Chart = () => Table()\n"
    messy_ts pages/Login.tsx "import { useAuth } from '@/stores/auth'\nimport { Header } from '../components/Header'\n\n" "export const Login = () => [useAuth(), Header()]\n"
    messy_ts pages/Dashboard.tsx "import { Chart } from '../components/Chart'\nimport { useReports } from '@/stores/report'\n\n" "export const Dashboard = () => [Chart(), useReports()]\n"
    messy_ts pages/Reports.tsx "import { Table } from '@/components/Table'\nimport { createReport } from '@/api/reports'\n\n" "export const Reports = () => [Table(), createReport({})]\n"
    messy_ts __tests__/users.test.ts "import { listUsers } from '../api/users'\n\n" "test('users', () => { listUsers() })\n"
    messy_ts __tests__/reports.test.ts "import { listReports } from '../api/reports'\n\n" "test('reports', () => { listReports() })\n"

    put "$DEST/docs/architecture/01_system_architecture.md" <<'MD'
# 查詢系統：系統架構

## 系統情境

```mermaid
C4Context
    title 系統情境圖
    Person(user, "使用者", "查詢並匯出報表<br/>內部員工")
    System(app, "查詢系統", "報表查詢 &amp; 匯出<br/>排程作業")
    System_Ext(ldap, "LDAP", "身分驗證")
    SystemDb_Ext(mssql, "MSSQL", "主要資料庫")
    SystemDb_Ext(redis, "Redis", "快取 &amp; 工作佇列")
    Rel(user, app, "使用", "HTTPS")
    Rel(app, ldap, "驗證", "LDAP")
    Rel(app, mssql, "讀寫", "SQL")
    Rel(app, redis, "快取", "TCP")
```

## 技術選型

後端 FastAPI、前端 React，資料庫 MSSQL。
MD

    put "$TD/wbs.md" <<'MD'
# WBS — 查詢系統

## M1 基礎

| # | 任務 | 狀態 | 優先 |
|---|---|---|---|
| 1.1 | 專案骨架 | ✅ 10-20 | 高 |
| 1.2 | 設定與資料庫連線 | ✅ 10-21 | 高 |
| 1.3 | LDAP 登入 | ✅ 10-22 | 高 |
| 1.4 | 使用者模型 | ✅ 10-22 | 高 |
| 1.5 | 使用者 API | ✅ 10-23 | 高 |
| 1.6 | 前端框架與路由 | ✅ 10-24 | 高 |
| 1.7 | 前端 API client | ✅ 10-24 | 中 |
| 1.8 | 登入頁 | ✅ 10-25 | 高 |

## M2 查詢

| # | 任務 | 狀態 | 優先 |
|---|---|---|---|
| 2.1 | 報表模型 | ✅ 10-28 | 高 |
| 2.2 | 報表服務 | ✅ 10-29 | 高 |
| 2.3 | 報表 API | ✅ 10-30 | 高 |
| 2.4 | 報表列表頁 | ✅ 10-31 | 高 |
| 2.5 | 共用表格元件 | ✅ 11-01 | 中 |
| 2.6 | 圖表元件 | ✅ 11-01 | 中 |
| 2.7 | 儀表板頁 | 🔄 進行中 | 高 |
| 2.8 | 查詢條件儲存 | ⏳ 待處理 | 中 |

## M3 匯出與排程

| # | 任務 | 狀態 | 優先 |
|---|---|---|---|
| 3.1 | CSV 匯出 | ✅ 11-02 | 高 |
| 3.2 | 排程作業 | ✅ 11-03 | 中 |
| 3.3 | 匯出權限檢查 | 🔄 進行中 | 高 |
| 3.4 | 快取查詢結果 | ⏳ 待處理 | 中 |
| 3.5 | 匯出紀錄 | ⏳ 待處理 | 低 |
| 3.6 | 排程失敗通知 | 🚫 阻塞 | 中 |
| 3.7 | Header 與登入狀態 | ✅ 11-03 | 中 |
| 3.8 | 錯誤頁 | ⏳ 待處理 | 低 |

## M4 收尾

| # | 任務 | 狀態 | 優先 |
|---|---|---|---|
| 4.1 | 後端單元測試 | ✅ 11-04 | 中 |
| 4.2 | 前端單元測試 | 🔄 進行中 | 中 |
| 4.3 | 部署腳本 | ⏳ 待處理 | 中 |
| 4.4 | 操作手冊 | ⏳ 待處理 | 低 |
| 4.5 | 效能調校 | ⏳ 待處理 | 低 |
| 4.6 | 驗收測試 | ⏳ 待處理 | 高 |
| 4.7 | 上線檢查 | ⏳ 待處理 | 高 |
| 4.8 | 交接文件 | ⏳ 待處理 | 低 |
MD

    local -a with_files=(
        "1.1|backend/pyproject.toml|frontend/package.json" "1.2|backend/app/core/**" "1.3|backend/app/services/ldap_service.py|backend/app/api/auth.py"
        "1.4|backend/app/models/user.py" "1.5|backend/app/api/users.py|backend/app/services/user_service.py" "1.6|frontend/src/pages/Login.tsx"
        "1.7|frontend/src/api/client.ts|frontend/src/api/users.ts" "1.8|frontend/src/pages/Login.tsx|frontend/src/stores/auth.ts"
        "2.1|backend/app/models/report.py" "2.2|backend/app/services/report_service.py" "2.3|backend/app/api/reports.py"
        "2.4|frontend/src/pages/Reports.tsx|frontend/src/api/reports.ts" "2.5|frontend/src/components/Table.tsx" "2.6|frontend/src/components/Chart.tsx"
        "2.7|frontend/src/pages/Dashboard.tsx|frontend/src/stores/report.ts" "3.1|backend/app/$zh/export.py"
        "3.2|backend/app/$zh/schedule.py" "3.3|backend/app/api/deps.py|backend/app/core/security.py"
        "3.7|frontend/src/components/Header.tsx" "4.1|backend/tests/**" "4.2|frontend/src/__tests__/**"
        "2.8|frontend/src/stores/report.ts" "3.4|backend/app/core/db.py" "3.5|backend/app/models/report.py"
    )
    local -a diff_only=(3.6 3.8 4.3 4.4)
    local rec id rest f
    local -a fs
    for rec in "${with_files[@]}"; do
        id=${rec%%|*}; rest=${rec#*|}
        IFS='|' read -r -a fs <<< "$rest"
        {
            printf -- '---\nwbs_task: "%s"\nstatus: "⏳ 未開始"\nmode: "standard"\nfiles:\n' "$id"
            for f in "${fs[@]}"; do printf '  - "%s"\n' "$f"; done
            printf -- '---\n\n# 實作計畫：任務 %s\n\n### 階段 1: 實作 ⏳\n\n- [ ] 完成任務\n' "$id"
        } | put "$TD/plans/$id-task.md"
    done
    for id in "${diff_only[@]}"; do
        printf -- '---\nwbs_task: "%s"\nstatus: "⏳ 未開始"\nmode: "standard"\n---\n\n# 實作計畫：任務 %s\n\n### 階段 1: 實作 ⏳\n\n- [ ] 完成任務\n' "$id" "$id" \
            | put "$TD/plans/$id-task.md"
    done
}

case "$1" in
    shop-clean) shop_clean ;;
    messy-fullstack) messy_fullstack ;;
esac
