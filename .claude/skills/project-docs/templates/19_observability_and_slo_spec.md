# 可觀測性與 SLO 規範 - [專案名稱]

> **版本:** v5.0 | **更新:** 2026-07-24 | **狀態:** 範本
> **依據:** Google SRE Workbook（SLO Document / Error Budget Policy）、OpenTelemetry Semantic Conventions

> 本文件定義服務的可靠性目標與可觀測性資料模型，與 14_deployment_and_operations_guide.md 的基礎設施監控互補（該文件管硬體/資源指標，本文件管使用者體驗指標與告警策略）。

---

## 1. 服務概述與使用者旅程

| 項目 | 內容 |
| :--- | :--- |
| 服務名稱 | [service-name] |
| 關鍵使用者旅程 | [例：登入 → 搜尋 → 下單] |
| 依賴服務 | [上游/下游服務清單] |
| 擁有者 | [團隊/負責人] |

---

## 2. SLI 定義（Service Level Indicator）

> 每個 SLI 需明確定義「good event」與「valid event」，並指出資料來源（避免主觀認定）。

| SLI 名稱 | 定義 | Good Event | Valid Event | 資料來源（OTel） |
| :--- | :--- | :--- | :--- | :--- |
| 可用性 | 成功請求比例 | HTTP 狀態碼 < 500 | 所有到達服務的請求 | `http.server.request.duration` metric |
| 延遲 | 快速回應比例 | P95 < [門檻]ms | 所有成功請求 | `http.server.request.duration` histogram |
| 正確性 | 資料正確返回比例 | [業務定義] | [業務定義] | [span attribute / log] |

---

## 3. SLO 目標（Service Level Objective）

| SLI | 目標 | 窗口 | 依據 |
| :--- | :--- | :--- | :--- |
| 可用性 | 99.9% | 滾動 30 天 | [使用者期望 / 合約 SLA 反推] |
| 延遲（P95） | < [門檻]ms | 滾動 30 天 | [歷史基線 + 使用者可感知門檻] |
| 正確性 | [目標]% | 滾動 30 天 | [業務容忍度] |

---

## 4. Error Budget 政策

> Error Budget = 1 − SLO。例：SLO 99.9% → 30 天預算 = 0.1%（約 43.2 分鐘不可用）。

| 規則 | 內容 |
| :--- | :--- |
| 計算方式 | `1 - SLO`，以滾動窗口消耗量追蹤 |
| 凍結規則 | 超過 4 週預算消耗 → 凍結非緊急發布，優先修復可靠性 |
| 強制 Postmortem 條件 | 單一事故消耗 > 20% 月度預算 → 強制撰寫 Postmortem（→ 詳見 14_deployment_and_operations_guide.md 第 9 節） |
| 例外 | [列出可豁免凍結的情境，例：安全修補] |
| 預算剩餘查詢 | [Dashboard 連結] |

---

## 5. 告警策略（Multi-Window Multi-Burn-Rate）

> 單一閾值告警易產生雜訊或漏報；採用長短窗組合，兩者同時成立才觸發，兼顧靈敏度與噪音控制。

| 窗口 | Burn Rate | 消耗預算 | 嚴重度 | 通知對象 |
| :--- | :--- | :--- | :--- | :--- |
| 1 小時 | 14.4x | 2%（月度） | Critical | Page on-call |
| 6 小時 | 6x | 5%（月度） | Warning | Page on-call（非深夜） |
| 3 天 | 1x | 10%（月度） | Warning | Slack / Ticket |

**告警規則範例：**
```
(short_window_burn_rate > 14.4 AND long_window_burn_rate > 14.4)  # 1h/6h 組合
  OR
(short_window_burn_rate > 6 AND long_window_burn_rate > 6)        # 6h/1d 組合
  OR
(short_window_burn_rate > 1 AND long_window_burn_rate > 1)        # 3d 組合
```

---

## 6. OpenTelemetry 資料模型

### Resource Attributes（服務識別）

| 屬性 | 說明 | 狀態 |
| :--- | :--- | :--- |
| `service.name` | 服務名稱 | stable |
| `service.version` | 服務版本 | stable |
| `deployment.environment.name` | 部署環境（prod/staging/dev） | stable |
| `[自訂屬性]` | [說明] | [stable/experimental] |

### 命名慣例

| 類型 | 慣例 | 範例 |
| :--- | :--- | :--- |
| Metric | `<domain>.<object>.<unit>` | `http.server.request.duration` |
| Span | `<動詞> <資源>` | `GET /orders/{id}` |
| Log | 結構化 JSON，含 `trace_id`/`span_id` 關聯 | `{"level":"error","trace_id":"..."}` |

> 新增自訂屬性/指標時標註 `stable`（可長期依賴）或 `experimental`（可能變動），避免下游誤用。

---

## 7. Dashboard 連結

| Dashboard | 用途 | 連結 |
| :--- | :--- | :--- |
| SLO 總覽 | 各 SLI 即時值與預算消耗 | [連結] |
| 服務健康 | 延遲/錯誤率/流量/飽和度（Four Golden Signals） | [連結] |
| Trace 查詢 | 分散式追蹤 | [連結] |

---

## 8. 每季審閱機制

| 項目 | 內容 |
| :--- | :--- |
| 審閱頻率 | 每季一次 |
| 審閱內容 | SLO 目標是否仍反映使用者期望、預算消耗趨勢、告警雜訊率、新增/淘汰的 SLI |
| 參與角色 | [SRE / Tech Lead / 產品負責人] |
| 輸出 | 更新本文件 + 若目標調整需知會相關團隊 |

---

## 9. 相關文件

| 文件 | 關聯 |
| :--- | :--- |
| 14_deployment_and_operations_guide.md | 基礎設施層監控指標、Runbook、DORA 指標 |
| 13_security_and_readiness_checklists.md | 安全事件日誌與告警覆蓋（A09 Logging and Monitoring Failures） |
| 20_threat_model_template.md | 若 SLO 事故涉及安全威脅，回溯對應威脅 ID |
