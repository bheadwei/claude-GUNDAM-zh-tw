# 模組規格與測試案例 - [模組名稱]

> **版本:** v5.0 | **更新:** 2026-07-24 | **狀態:** 草稿/開發中/已完成

**對應架構文件**: [連結至 05]
**對應 BDD Feature**: [連結至 03]
**對應 API 端點**: [連結至 06]

---

## 1. 模組概覽與職責邊界

| 項目 | 內容 |
| :--- | :--- |
| **模組名稱** | [例如：OrderService] |
| **所屬層級** | [Application / Domain / Infrastructure] |
| **核心職責** | [一句話描述，只做這件事] |
| **明確不做** | [列出容易被誤放進來的職責，寫明由哪個模組負責] |
| **依賴** | [列出依賴的其他模組/服務] |
| **被依賴** | [列出依賴此模組的上層] |

> **職責邊界原則**：一個模組只對一種變更理由負責（SRP）。若「核心職責」需要用「和」才能描述完，考慮拆分。

---

## 2. 對外介面（機讀合約）

| 介面類型 | 合約檔案 | 驗證方式 |
| :--- | :--- | :--- |
| HTTP API | [`openapi.yaml#/paths/...`](./06_api_design_specification.md) | Spectral lint + Schemathesis |
| 消費者合約 (CDC) | [`pacts/<consumer>-<provider>.json`](#3-consumer-driven-contract-testing) | Pact Broker `can-i-deploy` |
| 事件/訊息 | [`events/order.created.schema.json`](#) | JSON Schema 驗證 + 消費端契約測試 |

- 本模組的對外介面**以機讀合約檔為唯一真實來源**；本文件僅摘要用途，異動時先改合約檔、跑驗證，再回填本節連結。
- gRPC 模組另填：`proto` 檔路徑 + buf lint 結果連結。

---

## 3. Consumer-Driven Contract Testing

適用於本模組**作為 Provider**被其他服務消費、或**作為 Consumer**依賴其他服務時。

### 3.1 角色與流程

```
[Consumer] --定義期望--> Pact 檔 --發布--> [Pact Broker] --驗證--> [Provider CI]
```

1. Consumer 端寫測試描述「我期望呼叫 X 端點會得到 Y 格式回應」，產出 `.json` pact 檔
2. Pact 檔發布到 Pact Broker
3. Provider CI 拉取所有相關 pact 檔，針對本模組實際回應做重播驗證（provider verification）
4. `can-i-deploy` 檢查通過才允許部署（避免破壞性變更影響下游）

### 3.2 本模組的合約關係

| 角色 | 對方服務 | Pact 檔位置 | Broker 連結 |
| :--- | :--- | :--- | :--- |
| Provider | [FrontendApp] | `pacts/frontend-orderservice.json` | [連結] |
| Consumer | [PaymentService] | `pacts/orderservice-payment.json` | [連結] |

- **何時需要 CDC 而非純 E2E**：跨服務邊界、雙方各自獨立部署、又不想每次都跑重量級 E2E → 用 CDC 取代大部分整合驗證，E2E 只保留少量關鍵旅程。
- **CI 掛鉤**：Provider verification 失敗 = 阻擋合併；`can-i-deploy` 失敗 = 阻擋部署。

---

## 4. 效能與容量邊界

| 指標 | 目標值 | 測量方式 |
| :--- | :--- | :--- |
| 回應時間 (P95) | < [X]ms | [APM/Prometheus] |
| 吞吐量 | [X] req/s | 壓力測試 |
| 記憶體上限 | < [X]MB | 容器資源限制 |
| 最大並發 | [X] concurrent | 負載測試 |
| 資料量上限 | [X] 筆/[X]GB | 容量規劃 |

---

## 5. 函式規格

### 5.1 [函式名稱，例如：create_order]

**描述**: [功能說明]
**簽名**:

```python
async def create_order(
    user_id: str,
    items: list[OrderItem],
    payment_method: PaymentMethod,
) -> Order:
```

**契約式設計 (DbC)**:

| 類型 | 條件 |
| :--- | :--- |
| **前置條件** | 1. `user_id` 為已驗證的有效用戶 2. `items` 非空且每項數量 > 0 3. `payment_method` 為支援的付款方式 |
| **後置條件** | 1. 建立 Order 記錄於資料庫 2. 庫存已扣減 3. 回傳含 order_id 的 Order 物件 |
| **不變性** | 1. 訂單總金額 = Σ(item.price × item.quantity) 2. 訂單狀態初始為 `pending` |

**錯誤處理**:

| 錯誤情境 | 例外類型 | HTTP 狀態碼 | 回應訊息 |
| :--- | :--- | :--- | :--- |
| 用戶不存在 | `UserNotFoundError` | 404 | 找不到指定用戶 |
| 庫存不足 | `InsufficientStockError` | 409 | 商品 {item_name} 庫存不足 |
| 付款方式無效 | `InvalidPaymentError` | 400 | 不支援的付款方式 |

---

### 5.2 [下一個函式名稱]

_(複製上方結構)_

---

## 6. 測試分層模型選擇

> 依團隊型態與系統特性選一種為主，記錄理由；不同模組可用不同模型，但同模組內需一致。

| 模型 | 形狀 | 適用情境 | 本模組是否採用 |
| :--- | :--- | :--- | :--- |
| **Pyramid** | 大量單元 > 少量整合 > 極少 E2E | 教學/單體應用，邏輯集中在少數服務內 | ☐ |
| **Trophy** | 少量單元、大量整合、少量 E2E，頸部窄 | SaaS 應用、大量跨模組整合，重視實際整合正確性 | ☐ |
| **Diamond / Honeycomb** | 整合測試為主體，單元與 E2E 皆少 | 微服務、每個服務邏輯簡單但整合複雜 | ☐ |
| **Risk-based + Contract** | 依風險分級投入 + CDC 取代跨服務 E2E | 大型團隊、金融/醫療等高合規要求 | ☐ |

**本模組選用**：[模型名稱] — **理由**：[1-2 句]

### 6.1 測試案例

#### TC-001: 正常建立訂單

```python
async def test_create_order_success():
    # Arrange
    user = await create_test_user()
    items = [OrderItem(product_id="prod_1", quantity=2, price=Decimal("29.99"))]
    payment = PaymentMethod(type="credit_card", token="tok_test")

    # Act
    order = await order_service.create_order(user.id, items, payment)

    # Assert
    assert order.id is not None
    assert order.status == OrderStatus.PENDING
    assert order.total == Decimal("59.98")
    assert order.user_id == user.id
```

#### TC-002: 邊界情況 — 單一商品最小數量

```python
async def test_create_order_minimum_quantity():
    # Arrange
    user = await create_test_user()
    items = [OrderItem(product_id="prod_1", quantity=1, price=Decimal("0.01"))]

    # Act
    order = await order_service.create_order(user.id, items, valid_payment)

    # Assert
    assert order.total == Decimal("0.01")
```

#### TC-003: 無效輸入 — 空商品列表

```python
async def test_create_order_empty_items_raises():
    # Arrange
    user = await create_test_user()

    # Act & Assert
    with pytest.raises(ValidationError, match="items 不可為空"):
        await order_service.create_order(user.id, [], valid_payment)
```

#### TC-004: 業務規則 — 庫存不足

```python
async def test_create_order_insufficient_stock():
    # Arrange
    user = await create_test_user()
    items = [OrderItem(product_id="prod_1", quantity=9999)]

    # Act & Assert
    with pytest.raises(InsufficientStockError):
        await order_service.create_order(user.id, items, valid_payment)
```

#### TC-005: 並發安全 — 同時下單同一商品

```python
async def test_create_order_concurrent_stock_safety():
    # Arrange — 庫存只剩 1 件
    await set_stock("prod_1", quantity=1)
    user_a = await create_test_user()
    user_b = await create_test_user()
    items = [OrderItem(product_id="prod_1", quantity=1)]

    # Act — 同時下單
    results = await asyncio.gather(
        order_service.create_order(user_a.id, items, valid_payment),
        order_service.create_order(user_b.id, items, valid_payment),
        return_exceptions=True,
    )

    # Assert — 只有一個成功
    successes = [r for r in results if not isinstance(r, Exception)]
    failures = [r for r in results if isinstance(r, InsufficientStockError)]
    assert len(successes) == 1
    assert len(failures) == 1
```

---

## 7. 相容性與整合

| 整合對象 | 通訊方式 | 契約 | Mock / CDC 策略 |
| :--- | :--- | :--- | :--- |
| [PaymentService] | HTTP REST | `POST /v1/charges`（見 §2/§3） | Pact consumer stub（取代 httpx mock） |
| [InventoryService] | gRPC | `inventory.proto` | grpc-testing mock + proto contract lint |
| [NotificationService] | 事件佇列 | `order.created` event schema | in-memory queue + schema 驗證 |

---

## 8. 測試覆蓋率要求

| 類型 | 最低覆蓋率 | 重點 |
| :--- | :--- | :--- |
| 單元測試 | 80% | 業務邏輯、驗證規則 |
| Contract 測試 | 所有對外介面 100% | 每個消費端關係至少 1 組 pact |
| 整合測試 | 關鍵路徑 100% | DB 操作、外部 API 呼叫 |
| 邊界測試 | 所有已知邊界 | null/空/最大值/並發 |

---

## 9. 已知限制與技術債

| 項目 | 影響 | 追蹤 |
| :--- | :--- | :--- |
| [例：尚未支援批次建立] | [說明] | [Issue 連結] |
