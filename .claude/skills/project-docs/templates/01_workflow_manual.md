# 產品開發流程使用說明書

> **版本:** v5.0 | **更新:** 2026-07-24 | **狀態:** 活躍

---

## 1. 使用原則

- **以文檔為契約**: 所有決策以文檔為單一事實來源 (SSOT)
- **小步快跑**: 優先小批量交付，保留 ADR 以利回溯
- **風險前置**: 用審查 Gate 降低重大偏差風險
- **模式可升級**: demo → mvp → full 隨專案成熟度升級（不支援降級，避免文件不一致）
- **文件先行**: WBS 從文件反推，避免任務發散

**角色縮寫 (RACI):** PM / TL / ARCH / DEV / QA / SRE / SEC / OPS

---

## 2. 模式選擇（三檔）

| 條件 | demo | mvp | full |
| :--- | :---: | :---: | :---: |
| 快速驗證、個人實驗、< 1 天 | ✅ | | |
| 內部工具、小型產品、< 1 週 | | ✅ | |
| 正式產品、跨團隊、> 1 週 | | | ✅ |
| 涉及金流/法遵/隱私 | | | ✅ |
| 高可用與規模化 | | | ✅ |
| 跨 3+ 團隊協作 | | | ✅ |

**產出文件對照**：

| 模式 | 文件 | 存放 | 觸發指令 |
|---|---|---|---|
| demo | 精簡 PRD（1 份） | `docs/prd.md` | `/docs-init --demo` |
| mvp | Tech Spec（合併 02+05+06+08） | `docs/tech-spec.md` | `/docs-init --mvp` |
| full | VibeCoding 完整文件集（16 份必備 + 條件式 18-21） | `docs/01_prd.md`、`02_bdd.md`… | `/docs-init --full` |

**條件式文件（18-21，依專案特性納入）**：

| 編號 | 文件 | 納入條件 |
|---|---|---|
| 18 | 資料模型與 Migration 規範 | 有資料庫 / schema 會演進 |
| 19 | 可觀測性與 SLO | 會上線並持續維運 |
| 20 | 威脅模型（STRIDE） | full 建議；觸及認證/金流/個資**必產** |
| 21 | AI/LLM 整合規範 | 專案含 LLM/AI 功能 |

**升級路徑**：`demo → /docs-init --mvp` 或 `mvp → /docs-init --full`，保留既有文件並補足。

**升級觸發**: 觸及敏感資料、DAU > 10k / TPS > 100、引入新服務/多團隊、轉為核心營收

---

## 3. 模式 A: 完整流程

```mermaid
graph LR
  A0[Kickoff] --> A1[PRD] --> A2[架構設計] --> A3[模組/API] --> A4[開發驗證] --> A5[品質Gate] --> A6[上線]
```

| 階段 | 目標 | 產出 | Gate |
| :--- | :--- | :--- | :--- |
| A0 啟動 | 對齊目標、邊界、風險 | 啟動簡報、里程碑 | 利益相關者共識 |
| A1 PRD | 定義問題、受眾、範圍、KPI | `02_prd.md` | PRD 簽核、KPI 可量測 |
| A2 架構 | 系統邊界、技術選型、NFR | `05_architecture.md` + `04_adr.md`（MADR 4.0） | ADR 齊備、Quality Scenario 可驗證 |
| A3 詳細設計 | 可實作規格與契約 | `07_module.md` + `06_api.md` + `08_structure.md` +（`18_data_model.md`） | 契約穩定（OpenAPI/Pact）、測試策略完整 |
| A4 開發 | 增量交付 | 程式碼、測試、建置產物 | 測試綠燈、覆蓋率達標 |
| A5 品質 | 消除高風險弱點 | `13_security.md` +（`20_threat_model.md`） | 高/中風險已整改、威脅緩解已驗證 |
| A6 上線 | 可靠性、可觀測性就緒 | Go/No-Go 簽核 +（`19_slo.md`） | SLO/Burn-rate 告警就緒、回滾演練通過 |
| A7 AI（選） | AI 功能安全上線 | `21_ai_llm.md` | Eval 門檻通過、Guardrails 就緒、成本告警設定 |

**跨階段**: 變更需更新 ADR 與相依文檔；重大變更需重過 Gate。

---

## 4. 模式 B: MVP 快速迭代

```mermaid
graph LR
  B0[Tech Spec] --> B1[Iter 1] --> B2[Iter 2] --> Bn[Iter n] --> BL[Light Launch]
```

### B0 Sprint 0: Tech Spec
一份輕量文件合併 PRD/SA/SDD/API 最小集合：
- 問題/目標用戶/成功指標 (最多 3 條)
- 高層設計 + 1 張元件圖
- 必要 API 契約 (僅核心端點)
- 1-2 張資料表 Schema
- 風險與手動替代方案

### B1-Bn 迭代循環
- 每次交付: 可運行版本 + 指標驗證 + 回顧
- 最低限度: 安全檢查 (Secrets/認證/輸入驗證) + 可觀測性 (日誌/健康檢查)

### MVP 上線 Gate
- [ ] 有最小可運營 Runbook
- [ ] 資料備份已啟用
- [ ] 風險與債務列入後續 Backlog

---

## 5. 文檔產出對照

| 階段 | 完整流程 | MVP |
| :--- | :--- | :--- |
| 規劃 | `02_prd.md` | Tech Spec PRD 區塊 |
| 架構 | `05_architecture.md` + `04_adr.md` | Tech Spec SA/ADR 區塊 |
| 規格 | `07_module.md` + `06_api.md` | Tech Spec SDD/API 區塊 |
| 品質 | `13_security.md` | 簡化安全檢查 |
| 結構 | `08_structure.md` | Tech Spec 結構區塊 |

---

## 6. Gate 度量 (通用)

- **準入**: 輸入文檔完整、角色對齊、風險已登記
- **準出**: 產出完成度 >= 90%、審查簽核、指標可驗證
- **共同度量**: 需求穩定度、缺陷密度、Lead Time / Cycle Time、SLO 達成率、MTTR

---

## 7. 附錄: 檢查清單

- **PRD**: 問題陳述、非目標、量化 KPI?
- **架構**: 權衡與 ADR? NFR 可測?
- **設計**: 資料模型/索引、API 契約、錯誤處理、可觀測性?
- **安全**: Secrets 管理、認證授權、輸入驗證、依賴風險?
- **上線**: 備份、監控、告警、回滾方案與演練?
