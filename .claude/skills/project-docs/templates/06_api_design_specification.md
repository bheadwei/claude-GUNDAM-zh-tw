# API 設計規範 - [API/服務名稱]

> **版本:** v5.0 | **更新:** 2026-07-24 | **狀態:** 草稿/已發布 | **OpenAPI 定義:** [連結至 openapi.yaml，OpenAPI 3.1]

**Style Guide 參照**: [Zalando RESTful API Guidelines](https://opensource.zalando.com/restful-api-guidelines/) / [Google AIP](https://google.aip.dev/)（擇一為主，記錄於此）

---

## 1. 設計約定

| 項目 | 規範 |
| :--- | :--- |
| **風格** | RESTful（或 [gRPC/GraphQL]，說明選型理由） |
| **OpenAPI 版本** | 3.1（對齊 JSON Schema 2020-12） |
| **Base URL** | Production: `https://api.example.com/v1` / Staging: `https://staging-api.example.com/v1` |
| **格式** | `application/json` (UTF-8)；錯誤回應用 `application/problem+json` |
| **資源路徑** | 小寫、連字符、複數 (e.g., `/user-profiles`)，巢狀深度 ≤ 2 層 |
| **欄位命名** | `snake_case` |
| **日期格式** | ISO 8601 UTC (e.g., `2023-10-27T10:00:00Z`) |
| **認證** | OAuth 2.0 / OIDC，Bearer Token in `Authorization` header |

---

## 2. 版本策略

- **策略**：URI path 版本化（`/v1/...`），從第一版就版本化，不留「無版號」端點。
- **棄用流程**（Deprecation → Sunset）：
  1. 新版上線後，舊版回應加 `Deprecation: true` header（或 `Deprecation: <date>`，RFC 8594 之前身）
  2. 同時加 `Sunset: <HTTP-date>`（[RFC 8594](https://www.rfc-editor.org/rfc/rfc8594)）標示停用日期
  3. `Link: <https://api.example.com/v2/resources>; rel="successor-version"` 指向新版
  4. 停用前至少提前 [N] 個月通知（Changelog + Email + Header 三管齊下）
- **Breaking change 判定**：新增欄位/端點非 breaking；移除欄位、改變型別、改變必填狀態、改變語意皆視為 breaking，需開新版本。

---

## 3. 通用行為

### 3.1 分頁（Cursor-based，強制用於可能 > 1 萬筆的集合）

```
GET /resources?limit=25&cursor=eyJpZCI6MTIzfQ
```

**回應信封**：

```json
{
  "data": [ /* Resource[] */ ],
  "pagination": {
    "next_cursor": "eyJpZCI6MTQ4fQ",
    "has_more": true,
    "limit": 25
  }
}
```

- `limit`：預設 25，最大 100
- `next_cursor`：`null` 代表無下一頁
- 禁止 offset-based 分頁用於大集合（效能與一致性問題）；小型固定集合可用 `page`/`page_size`，但需在此註記例外

### 3.2 排序與過濾

- 排序：`sort_by=field`（升序）/ `sort_by=-field`（降序）
- 過濾：欄位名直接作為參數，運算子用方括號：`/users?status=active&created_at[gte]=2023-01-01`

### 3.3 冪等性

- 所有非 GET 的變更性請求（尤其 `POST` 建立資源）**必須**支援 `Idempotency-Key` header
- 伺服器對同一 key 在 [24] 小時內回傳相同結果（含相同狀態碼與 body），不重複執行副作用
- Key 衝突但請求體不同 → `409 Conflict` + Problem Details

---

## 4. 錯誤處理 — RFC 9457 Problem Details

**Content-Type**: `application/problem+json`

```json
{
  "type": "https://api.example.com/errors/parameter-missing",
  "title": "缺少必要參數",
  "status": 400,
  "detail": "缺少必要參數 email",
  "instance": "/v1/users",
  "request_id": "req_xxx",
  "errors": [
    { "param": "email", "code": "missing" }
  ]
}
```

| 欄位 | 必填 | 說明 |
| :--- | :--- | :--- |
| `type` | 是 | 指向錯誤說明文件的 URI（無文件時用 `about:blank`） |
| `title` | 是 | 人類可讀的簡短摘要（同 `type` 應固定不變） |
| `status` | 是 | 對應的 HTTP 狀態碼 |
| `detail` | 否 | 針對此次請求的詳細說明 |
| `instance` | 否 | 觸發錯誤的請求路徑 |
| `errors[]` | 否 | 擴充欄位：多欄位驗證錯誤明細（自訂） |
| `request_id` | 否 | 擴充欄位：追蹤用請求 ID |

### 標準錯誤碼表（`type` slug 對照）

| `type` slug | HTTP | 描述 |
| :--- | :--- | :--- |
| `resource-not-found` | 404 | 資源不存在 |
| `parameter-invalid` | 400 | 參數格式無效 |
| `parameter-missing` | 400 | 缺少必要參數 |
| `authentication-failed` | 401 | 認證失敗 |
| `permission-denied` | 403 | 無權限 |
| `idempotency-key-conflict` | 409 | 同 key 但請求體不同 |
| `rate-limit-exceeded` | 429 | 超出速率限制 |
| `internal-server-error` | 500 | 伺服器錯誤 |

---

## 5. 速率限制

- 超限回應：`429 Too Many Requests` + Problem Details body
- **必含 headers**：

| Header | 說明 |
| :--- | :--- |
| `Retry-After` | 建議重試等待秒數 |
| `X-RateLimit-Limit` | 該時間窗口的總配額 |
| `X-RateLimit-Remaining` | 剩餘可用次數 |
| `X-RateLimit-Reset` | 配額重置時間（Unix timestamp 或秒數） |

- 限制維度：依 [API Key / User ID / IP]，寫明各方案配額（e.g., Free 60 req/min、Pro 600 req/min）

---

## 6. 安全性

- **TLS**：強制 HTTPS (TLS 1.2+)
- **安全 Headers**：`Strict-Transport-Security`、`Content-Security-Policy`、`X-Content-Type-Options: nosniff`
- **輸入驗證**：所有請求體/查詢參數以 JSON Schema（OpenAPI 3.1）驗證，拒絕未定義欄位或明確標註 `additionalProperties`
- **OWASP API Security Top 10**：逐項確認緩解措施（BOLA、Broken Auth、資源濫用等），詳見 `13_security_and_readiness_checklists.md`

---

## 7. API 端點定義

### 資源: [資源名稱]

**路徑:** `/resources`

#### `POST /resources` - 建立

- **授權**: `resources.write`
- **請求 Header**: `Idempotency-Key`（必填）
- **請求體**: `ResourceCreate`
- **回應**: `201 Created` -> `Resource`
- **錯誤**: `400 parameter-missing` / `409 idempotency-key-conflict`

#### `GET /resources/{id}` - 取得

- **授權**: `resources.read`
- **回應**: `200 OK` -> `Resource`
- **錯誤**: `404 resource-not-found`

#### `GET /resources` - 列表

- **授權**: `resources.read`
- **參數**: `limit`, `cursor`, `sort_by`, `status`
- **回應**: `200 OK` -> `{ data: Resource[], pagination: { next_cursor, has_more, limit } }`

#### `PATCH /resources/{id}` - 更新

- **授權**: `resources.write`
- **請求體**: `ResourceUpdate` (JSON Merge Patch，部分更新)
- **回應**: `200 OK` -> `Resource`

#### `DELETE /resources/{id}` - 刪除

- **授權**: `resources.write`
- **回應**: `204 No Content`

---

## 8. 資料模型（對齊 OpenAPI 3.1 / JSON Schema 2020-12）

### `Resource`

```json
{
  "id": "string (res_...)",
  "object": "resource",
  "name": "string",
  "status": "active | inactive",
  "created_at": "string (ISO 8601)",
  "updated_at": "string (ISO 8601)"
}
```

### `ResourceCreate`

```json
{
  "name": "string (required)",
  "status": "string (optional, default: active)"
}
```

> Schema 的**唯一機讀真實來源**是 `openapi.yaml`；本節僅供人類快速閱讀，異動時以 OpenAPI 檔為準並跑 schema lint（如 Spectral）。

---

## 9. 棄用流程 Checklist

- [ ] 新版本發布並穩定運行 ≥ [N] 週
- [ ] 舊版加上 `Deprecation` + `Sunset` + `Link` headers
- [ ] Changelog / Email / Developer Portal 三管道通知
- [ ] 監控舊版流量，確認消費者遷移進度
- [ ] Sunset 日期到達後回應 `410 Gone` + Problem Details
