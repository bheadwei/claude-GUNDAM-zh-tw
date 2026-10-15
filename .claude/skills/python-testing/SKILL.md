---
name: python-testing
description: Use when writing, running or fixing pytest tests in a Python project — 「幫這個 FastAPI 端點寫測試」「pytest 跑不過」「conftest 要放哪」「async 函式怎麼測」「怎麼 mock 這個外部呼叫」. 只有這個專案的 pytest 約定（uv、目錄、設定、async、FastAPI、DB 隔離、patch 位置）；pytest 通用用法模型本來就會，不在這裡。覆蓋率門檻與「測試怎麼跑」見 testing-standards。
origin: ECC（2026-10-15 精簡：刪除通用 pytest 教學，只留專案約定）
---

# pytest 專案約定

pytest 的 fixture、parametrize、assert 寫法你本來就會，本檔不教。
這裡只寫**這個模板的專案會遇到、而且做錯了不會報錯**的約定。

- 覆蓋率門檻、每輪跑哪些測試、輸出怎麼回報 → `.claude/skills/testing-standards/SKILL.md`
- 先寫測試還是後補、怎麼從驗收條件推測試 → `.claude/skills/tdd-workflow/SKILL.md`

## 1. 一律透過 uv

```bash
uv add --dev pytest pytest-cov pytest-asyncio   # 測試依賴進 dev 群組
uv run pytest tests/unit/test_order.py -q       # 只跑相關的檔
```

- **不要**直接打 `pytest`、`python -m pytest`、`pip install pytest`——會跑到系統 Python 或錯的虛擬環境，
  測試結果是別的環境的。規則見 `python-uv` skill
- worktree 裡跑測試前確認 `.venv` 是這個 worktree 自己的（不是指回主 checkout 的 symlink），
  否則測到的是另一條線的程式碼。見 `context/learned/2026-09-17-worktree-isolation-stops-at-the-file-layer.md`

## 2. 目錄與 conftest

```
tests/
├── conftest.py          # 全專案共用：app、db session、client
├── unit/                # 不碰 I/O，毫秒級
│   └── test_<模組>.py
└── integration/         # 碰 DB、HTTP、檔案系統
    ├── conftest.py      # 只給整合測試的 fixture（例：真的 DB）
    └── test_<功能>.py
```

- 測試檔路徑對應被測模組：`src/app/order/refund.py` → `tests/unit/order/test_refund.py`。
  這樣 `testing-standards` 的「只跑相關的測試檔」才找得到對應的檔
- fixture 放在**用到它的最近一層** conftest，不要全部堆進根目錄那一份
- 不要從測試檔 import 另一個測試檔的 fixture——放進 conftest

## 3. 設定放 pyproject.toml

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["-ra", "--strict-markers"]
asyncio_mode = "auto"
markers = [
    "integration: 碰 DB／網路／檔案系統",
    "slow: 超過 1 秒",
]
```

- `--strict-markers`：打錯 marker 名稱會直接報錯，而不是靜默變成「沒有任何測試被選到」
- 不要另外建 `pytest.ini`——兩份設定並存時只有一份生效，而且不會告訴你是哪一份
- `addopts` **不要**放 `--cov`：那會讓每一次只跑單一檔案也去算整個專案的覆蓋率

## 4. 非同步程式

`asyncio_mode = "auto"` 之後，`async def test_...` 直接就是非同步測試，不用逐一加
`@pytest.mark.asyncio`。async fixture 也一樣直接寫 `async def`。

```python
async def test_fetch_user_returns_none_when_missing(repo):
    assert await repo.get_user(999) is None
```

- mock 非同步函式用 `AsyncMock`，不是 `Mock`——用錯時 `await` 會丟 `TypeError`，
  或更糟：測試通過但根本沒等到結果
- 不要在測試裡 `asyncio.run(...)`——event loop 由 pytest-asyncio 管

## 5. FastAPI 端點

```python
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app
from app.deps import get_db

@pytest.fixture
async def client(db_session):
    app.dependency_overrides[get_db] = lambda: db_session
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()

async def test_refund_over_limit_returns_400(client):
    r = await client.post("/orders/1/refund", json={"amount": 10_000})
    assert r.status_code == 400
    assert r.json()["error"] is not None
```

- 換依賴用 `app.dependency_overrides`，**不要** patch 路由模組裡的函式
- **一定要在 fixture 結尾 `clear()`**——`app` 是模組層級的單例，沒清掉的 override
  會漏到下一個測試，造成「單獨跑會過、一起跑會掛」
- 斷言回應的**信封格式**（`coding-style.md` 的 API 回應格式），不只斷言狀態碼

## 6. 資料庫隔離

每個測試在一個交易裡跑，結束時 rollback，不留資料給下一個測試：

```python
@pytest.fixture
def db_session(engine):
    with engine.connect() as conn:
        tx = conn.begin()
        session = Session(bind=conn)
        yield session
        session.close()
        tx.rollback()
```

- 不要靠測試執行順序（「先跑建立、再跑查詢」）——pytest 不保證順序，平行執行時一定壞
- 整合測試用的 DB 要和開發用的分開（環境變數指定），測試**絕不**連到開發或正式資料

## 7. patch 要 patch「被使用的地方」

```python
# app/service.py 裡寫的是：from app.client import fetch_rate
patch("app.service.fetch_rate")      # ✅ service 模組裡那個名字
patch("app.client.fetch_rate")       # ❌ service 早就 import 走了，這個 patch 沒作用
```

- 用 `autospec=True`：呼叫參數跟真的函式對不上時會直接報錯，而不是靜默通過
- 只 mock 系統邊界（外部 API、時間、亂數、檔案系統）。mock 自己專案的商業邏輯
  等於測 mock 本身

## 8. 常用的執行方式

完整規則見 `testing-standards` 的「執行測試」。pytest 常用的幾個：

| 目的 | 指令 |
|---|---|
| 只跑一個檔 | `uv run pytest tests/unit/test_x.py -q` |
| 只跑上次失敗的 | `uv run pytest --lf -q` |
| 第一個失敗就停 | `uv run pytest -x -q` |
| 跳過慢的 | `uv run pytest -m "not slow" -q` |
| 只看改到的模組的覆蓋率 | `uv run pytest tests/unit/order -q --cov=app.order.refund --cov-report=term` |

- 回報只寫「通過 N／失敗 M＋失敗的測試名與一行錯誤」
- **不要**在自動化流程裡用 `--cov-report=html` 或對整個套件 `--cov-report=term-missing`——
  前者產一堆檔案沒人看，後者把每個檔的未覆蓋行號全印進 context

## 反模式

- ❌ 測試裡出現 `time.sleep()` 等非同步結果——用 `AsyncMock` 或等條件成立
- ❌ fixture 改了模組層級的狀態（`app.dependency_overrides`、全域設定）卻不還原
- ❌ 斷言 `assert result`（只驗真值）——寫出期望的具體值
- ❌ 一個測試測好幾個行為，失敗時看不出是哪一個壞了
- ❌ 為了覆蓋率去測 `__repr__`、純資料類別、Pydantic model 的欄位定義

## 相關

- `.claude/skills/testing-standards/SKILL.md` — 覆蓋率門檻、執行測試、要測哪些邊界
- `.claude/skills/tdd-workflow/SKILL.md` — RED → GREEN → 重整
- `.claude/skills/python-uv/SKILL.md` — 套件與環境
- `.claude/skills/python-patterns/SKILL.md` — Python 寫法
