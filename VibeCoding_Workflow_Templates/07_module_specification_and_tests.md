# 模組規格與測試案例 - [模組名稱]

> **版本:** v1.0 | **更新:** YYYY-MM-DD | **狀態:** 草稿/開發中/已完成

**對應架構文件**: [連結至 05]
**對應 BDD Feature**: [連結至 03]
**對應 API 端點**: [連結至 06]

---

## 1. 模組概覽

| 項目 | 內容 |
| :--- | :--- |
| **模組名稱** | [例如：OrderService] |
| **所屬層級** | [Application / Domain / Infrastructure] |
| **核心職責** | [一句話描述] |
| **依賴** | [列出依賴的其他模組/服務] |
| **被依賴** | [列出依賴此模組的上層] |

---

## 2. 效能與容量邊界

| 指標 | 目標值 | 測量方式 |
| :--- | :--- | :--- |
| 回應時間 (P95) | < [X]ms | [APM/Prometheus] |
| 吞吐量 | [X] req/s | 壓力測試 |
| 記憶體上限 | < [X]MB | 容器資源限制 |
| 最大並發 | [X] concurrent | 負載測試 |
| 資料量上限 | [X] 筆/[X]GB | 容量規劃 |

---

## 3. 函式規格

### 3.1 [函式名稱，例如：create_order]

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

### 3.2 [下一個函式名稱]

_(複製上方結構)_

---

## 4. 測試案例

### 4.1 create_order 測試

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

## 5. 相容性與整合

| 整合對象 | 通訊方式 | 契約 | Mock 策略 |
| :--- | :--- | :--- | :--- |
| [PaymentService] | HTTP REST | `POST /v1/charges` | pytest-httpx fixture |
| [InventoryService] | gRPC | `inventory.proto` | grpc-testing mock |
| [NotificationService] | 事件佇列 | `order.created` event | in-memory queue |

---

## 6. 測試覆蓋率要求

| 類型 | 最低覆蓋率 | 重點 |
| :--- | :--- | :--- |
| 單元測試 | 80% | 業務邏輯、驗證規則 |
| 整合測試 | 關鍵路徑 100% | DB 操作、外部 API 呼叫 |
| 邊界測試 | 所有已知邊界 | null/空/最大值/並發 |
