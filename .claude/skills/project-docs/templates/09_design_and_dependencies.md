# 設計與依賴關係文件 - [專案名稱]

> **版本:** v5.0 | **更新:** 2026-07-24 | **狀態:** 草稿/已批准
>
> 本文件合併原「模組依賴分析」與「類別關係文件」，涵蓋架構分層、類別設計、依賴管理與模組邊界。介面契約如何在 CI 自動驗證 → 詳見 `07_module_specification_and_tests.md` 的 Contract Testing 章節。

---

## 1. 架構分層與依賴規則

### 分層依賴圖

```mermaid
graph TD
    A[介面層] --> B[應用層]
    B --> C[領域層]
    D[基礎設施層] -.->|實現介面| C
    D --> DB[(資料庫)]
    D --> ExtAPI[外部 API]
    D --> MQ[訊息佇列]
```

**規則**：介面層 → 應用層 → 領域層（單向）。基礎設施層實現領域層定義的介面，不被領域層直接依賴。

### 層級職責

| 層級 | 職責 | 程式碼路徑 | 允許依賴 |
| :--- | :--- | :--- | :--- |
| 介面層 | HTTP/gRPC 處理、序列化、認證 | `src/api/` | 應用層 |
| 應用層 | 編排業務流程、交易管理 | `src/services/` | 領域層 |
| 領域層 | 核心業務邏輯、實體、倉儲介面 | `src/domain/` | 無（最穩定，零外部依賴） |
| 基礎設施層 | DB 存取、外部通信、快取 | `src/infrastructure/` | 領域層介面（反向實現） |

### 依賴方向規則（依賴倒置，DIP 詳解）

> 核心：**依賴永遠指向抽象，抽象不依賴實現**。高層模組（領域/應用層）定義介面，低層模組（基礎設施）實現介面 — 依賴方向與「呼叫方向」相反，這就是「倒置」。

1. **領域層定義介面，不 import 具體實現**：例如 `OrderRepository`（interface）放在 `src/domain/`，`PostgresOrderRepository`（實現）放在 `src/infrastructure/`，由 DI 容器在啟動時綁定。
2. **依賴注入取代直接 import**：Service 建構子接收 `Repository` 介面型別，不 `new ConcretePostgresRepo()`。
3. **禁止「跳層依賴」**：介面層不得直接 import 基礎設施層（例如 controller 直接呼叫 ORM）。
4. **禁止循環依賴（ADP：無循環依賴原則）**：依賴關係須形成 DAG（有向無環圖）。

| 原則 | 要點 | 違反指標 |
| :--- | :--- | :--- |
| **依賴倒置 (DIP)** | 高層依賴抽象，不依賴低層實現 | import 直接指向 infrastructure |
| **無循環依賴 (ADP)** | 依賴關係形成 DAG | 雙向 import |
| **穩定依賴 (SDP)** | 依賴方向朝向更穩定的模組 | 領域層依賴應用層 |
| **介面隔離 (ISP)** | 依賴方只看到用得到的方法 | 一個介面塞進所有 CRUD，用戶端被迫實現無關方法 |

---

## 2. 核心類別/元件設計

### 類別圖

```mermaid
classDiagram
    direction LR

    class Repository {
        <<Interface>>
        +get_by_id(id: str): Entity
        +save(entity: Entity): void
        +delete(id: str): void
    }

    class ConcreteRepository {
        +get_by_id(id: str): Entity
        +save(entity: Entity): void
        +delete(id: str): void
    }

    class Service {
        -repository: Repository
        +get(id: str): Entity
        +create(data: CreateDTO): Entity
        +update(id: str, data: UpdateDTO): Entity
    }

    class Entity {
        -id: str
        -created_at: datetime
        -updated_at: datetime
        +validate(): bool
    }

    Service ..> Repository : "uses (DI)"
    Service ..> Entity : "creates/returns"
    ConcreteRepository ..|> Repository : "implements"
    ConcreteRepository ..> Entity : "persists"
```

### 元件職責表

| 元件 | 核心職責 | 協作者 | 所屬層 |
| :--- | :--- | :--- | :--- |
| `Service` | 業務流程編排 | Repository, Entity | Application |
| `Repository` (Interface) | 持久化契約定義 | Entity | Domain |
| `ConcreteRepository` | 具體 DB/API 實現 | Entity, ORM | Infrastructure |
| `Entity` | 領域模型、業務規則 | Value Objects | Domain |

### 關係類型速查

| 關係 | UML 符號 | 意義 | 範例 |
| :--- | :--- | :--- | :--- |
| 實現 | `..\|>` | 類別 implements 介面 | `PostgresRepo ..\|> Repository` |
| 組合 | `*--` | 生命週期強綁定（整體刪除部分也刪） | `Order *-- OrderItem` |
| 聚合 | `o--` | 生命週期獨立 | `Team o-- Member` |
| 依賴 | `..>` | 方法中使用（通常透過 DI） | `Service ..> Repository` |

---

## 3. 設計模式應用

| 模式 | 應用位置 | 解決的問題 |
| :--- | :--- | :--- |
| **Repository** | 資料存取層 | 業務邏輯與儲存細節解耦 |
| **依賴注入** | Service ← Repository | 降低耦合、提高可測試性 |
| **策略模式** | [具體場景] | [運行時切換演算法] |
| **觀察者/事件** | [具體場景] | [模組間非同步通信] |
| **工廠模式** | [具體場景] | [複雜物件建立邏輯集中] |

---

## 4. SOLID 原則檢核

| 原則 | 檢查項目 | 量化指標 | 狀態 |
| :--- | :--- | :--- | :--- |
| **S** 單一職責 | 每個類別只有一個變更原因 | 類別方法數 ≤ 10、行數 ≤ 200 | [ ] |
| **O** 開放封閉 | 新增功能不修改既有程式碼 | 擴展用繼承/組合，不改原類別 | [ ] |
| **L** 里氏替換 | 子類別可安全替換父類別 | 無需 isinstance 檢查 | [ ] |
| **I** 介面隔離 | 介面小而專一 | 每個介面方法數 ≤ 5 | [ ] |
| **D** 依賴反轉 | 高層依賴抽象 | 0 個 infrastructure import in domain | [ ] |

---

## 5. 模組邊界與 Fitness Function

> **模組邊界**：以第 1 節分層 + DDD 限界上下文（見 `05_architecture_and_design_document.md` 5.3 節）共同定義。邊界一旦劃定，跨邊界呼叫只能透過公開介面/事件，不得直接引用內部型別。

**Fitness Function（架構適應度函數）**：把架構規則寫成可自動執行的檢查，取代「Code Review 靠人眼抓依賴違規」。

| 規則 | 檢查方式 | 工具範例 | 執行時機 |
| :--- | :--- | :--- | :--- |
| 領域層零外部依賴 | 靜態依賴分析 | `import-linter` (Python) / `dependency-cruiser` (JS/TS) / ArchUnit (Java) | CI（每次 PR） |
| 無循環依賴 | 依賴圖分析 | `madge --circular` / `import-linter` | CI |
| 分層依賴方向 | 自訂分層規則 | ArchUnit / `dependency-cruiser` rules | CI |
| 介面契約未破壞 | Contract Testing | Pact / OpenAPI diff | CI（見 `07_module_specification_and_tests.md`） |
| 模組間耦合度 | 扇入/扇出量測 | 靜態分析工具內建指標 | 週期性（非阻斷） |

**建議**：新專案在 CI pipeline 早期就加入至少「領域層零外部依賴」與「無循環依賴」兩項 fitness function，違反即擋 PR；其餘視團隊成熟度逐步加入。

---

## 6. 關鍵依賴路徑

### 場景：[例如：使用者下單]

```
1. api.orders.create (介面層)
   → 接收 HTTP POST、驗證 token
2. order_service.create_order (應用層)
   → 編排：驗證 → 扣庫存 → 建訂單 → 發事件
3. Order.validate() (領域層)
   → 業務規則驗證
4. OrderRepository.save() (領域介面)
   → 呼叫持久化契約
5. PostgresOrderRepo.save() (基礎設施實現)
   → 實際 DB 操作
6. EventBus.publish("order.created") (基礎設施)
   → 非同步通知下游
```

---

## 7. 外部依賴管理

### 套件依賴

| 依賴 | 版本 | 用途 | 替代方案 | 風險等級 |
| :--- | :--- | :--- | :--- | :--- |
| [套件名] | [版本] | [用途] | [替代] | 低/中/高 |

### 外部服務依賴

| 服務 | 通訊方式 | SLA | 降級策略 |
| :--- | :--- | :--- | :--- |
| [服務名] | REST/gRPC/Event | [可用性] | [快取/佇列/fallback] |

### 依賴風險緩解

| 風險 | 偵測方式 | 緩解策略 |
| :--- | :--- | :--- |
| 循環依賴 | 靜態分析工具（madge/import-linter，見第 5 節 fitness function） | 提取共用模組 / 事件驅動解耦 |
| 不穩定外部依賴 | 健康檢查 + 斷路器 | 適配器模式封裝 + fallback |
| 過時套件 | Dependabot / Renovate | 自動 PR + CI 驗證 |

---

## 8. 介面契約與 Contract Testing

### 契約定義（本文件範圍）

| 方法 | 前置條件 | 後置條件 | 複雜度 |
| :--- | :--- | :--- | :--- |
| `get_by_id(id)` | id 非空字串 | 找到回傳物件；未找到拋 NotFoundException | O(1) |
| `save(entity)` | entity 已通過 validate() | 狀態已持久化、updated_at 已更新 | O(1) |
| `find_by(filters)` | filters 為有效查詢條件 | 回傳符合條件的列表（可能為空） | O(n) |

### 契約如何被驗證（銜接 07）

上表定義的是「程式碼層級」契約（前置/後置條件）；**跨服務**的契約（消費端期待的請求/回應格式）改用 Consumer-Driven Contract Testing，機讀合約與 CI 驗證流程 → 詳見 `07_module_specification_and_tests.md` 的「對外介面」與「測試策略」章節。

- 內部模組介面：本節表格 + 單元測試斷言前置/後置條件
- 跨服務介面：Pact（消費端定義合約）+ Pact Broker（供應端 CI 驗證）或 OpenAPI schema diff
- 兩者共同目標：介面變更時，**呼叫方在 CI 階段就發現不相容**，而非上線後才出事
