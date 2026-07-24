# 專案結構指南 - [專案名稱]

> **版本:** v5.0 | **更新:** 2026-07-24 | **狀態:** 草稿/已批准

---

## 設計原則

- **按功能/領域組織**：相關功能放一起（非按類型分散），子目錄以業務概念命名（`orders/`、`billing/`）而非技術層命名（`controllers/`、`models/` 全域打散）
- **明確職責**：每個目錄單一職責，看目錄名就知道放什麼
- **一致命名**：目錄 `kebab-case`、Python `snake_case.py`、測試 `test_` 開頭
- **配置外部化**：配置與程式碼分離，秘密不進版控
- **根目錄簡潔**：原始碼放 `src/`，根目錄只放專案級檔案

---

## Monorepo vs Polyrepo 決策

| 考量 | Monorepo | Polyrepo |
| :--- | :--- | :--- |
| **適用情境** | 多套件強耦合、需原子提交跨套件變更、共用大量內部套件 | 各服務獨立部署節奏、團隊邊界清楚、需嚴格存取權限隔離 |
| **依賴管理** | 統一 lockfile，版本一致易保證 | 各自 lockfile，需額外套件發布流程同步版本 |
| **CI/CD** | 需 affected-graph 工具（Turborepo/Nx/Bazel）避免全量重跑 | 各 repo 獨立 CI，天然隔離但重複設定 |
| **原子變更** | 支援（一次 PR 改多套件） | 不支援，需協調多個 PR + 版本相容 |
| **權限隔離** | 較弱（預設全員可見全部程式碼） | 天然隔離，可依 repo 分權 |
| **本專案選擇** | [Monorepo / Polyrepo] — **理由**：[1-2 句] | |

> 若選 Monorepo，需在下方「頂層結構」標明 workspace 工具（如 pnpm workspaces / Turborepo / Nx）；若選 Polyrepo，本文件描述單一 repo 的內部結構，另建 `docs/architecture/repo-map.md` 記錄跨 repo 關係。

---

## 頂層結構

```plaintext
[project-root]/
├── .github/              # CI/CD 工作流程
├── configs/              # 環境配置（不含秘密，見下方「設定與秘密擺放慣例」）
├── docs/                 # 專案文檔、ADR
├── scripts/              # 開發/運維腳本
├── src/[app_name]/       # 應用程式原始碼（monorepo 則為 packages/apps/*）
├── tests/                # 測試程式碼
├── .env.example           # 環境變數範本（不含真實值）
├── .gitignore
├── pyproject.toml        # (或 package.json / Cargo.toml)
└── README.md
```

**Monorepo 額外結構**（若適用）：

```plaintext
[project-root]/
├── apps/                 # 可獨立部署的應用（api、web、worker）
├── packages/             # 跨 app 共用套件（ui-kit、shared-types、eslint-config）
├── turbo.json            # 或 nx.json — affected-graph / task pipeline 設定
└── pnpm-workspace.yaml   # 或對應 workspace 宣告檔
```

---

## 原始碼結構（Clean Architecture，按領域切片）

```plaintext
src/[app_name]/
├── main.py                     # 入口點
├── core/                       # 跨功能共享 (config, security)
├── domains/                    # Domain Layer: 業務模型，依業務領域分目錄
│   └── [feature]/               # 例：orders/、billing/（非 models/ 全域堆放）
│       ├── entities.py         # 業務實體
│       ├── aggregates.py       # 聚合根
│       └── exceptions.py       # 領域例外
├── application/                # Application Layer: 應用邏輯
│   └── [feature]/
│       ├── use_cases.py        # 用例/服務
│       ├── dtos.py             # 資料傳輸物件
│       └── validators.py       # 輸入驗證
└── infrastructure/             # Infrastructure Layer: 外部實現
    ├── web/                    # Controllers/Routers
    └── persistence/            # ORM models, Repository 實現
```

> **依功能/領域組織原則**：新增功能時優先在既有 `[feature]/` 目錄內擴充，而非在 `core/` 或跨領域共用層堆放。當某段邏輯被 ≥ 2 個領域重複需要時，才升級為 `core/` 或獨立共用套件；避免「先共用、後界定」導致耦合。

---

## 測試結構

```plaintext
tests/
├── conftest.py               # 全局 fixtures
├── unit/                     # 單元測試
├── integration/              # 整合測試
├── contract/                 # Consumer-Driven Contract 測試（Pact 檔輸出/驗證）
└── features/                 # 功能測試 (對應 src 結構)
    └── [feature]/
        ├── test_router.py
        └── test_service.py
```

測試分層模型的選擇與各層覆蓋率要求，見 [`07_module_specification_and_tests.md` §6](./07_module_specification_and_tests.md#6-測試分層模型選擇)。

---

## 設定與秘密檔案擺放慣例

| 類型 | 存放位置 | 進版控？ |
| :--- | :--- | :--- |
| 非敏感預設設定 | `configs/*.yaml` / `configs/*.toml` | 是 |
| 環境變數範本 | `.env.example`（列出所有 key，值為空或範例） | 是 |
| 實際環境變數 | `.env`（本機）/ 部署平台的 Secret Manager（雲端） | **否**，加入 `.gitignore` |
| 秘密（API key、憑證、私鑰） | Secret Manager（Vault / AWS Secrets Manager / GCP Secret Manager）注入為環境變數 | **否**，絕不落地檔案進 repo |
| CI/CD 秘密 | GitHub Actions Secrets（或對應 CI 平台的加密變數） | **否** |

- 設定讀取順序：`configs/default.yaml` → 環境專屬覆蓋（`configs/production.yaml`）→ 環境變數（最高優先權）
- 詳細安全規範見 [`13_security_and_readiness_checklists.md`](./13_security_and_readiness_checklists.md)

---

## 前端專案的結構銜接

若本專案含前端應用，其內部結構（`app/pages/widgets/features/entities/shared` 等 Feature-Sliced Design 切片）**不在本文件重複定義**，改參照：

- [`12_frontend_architecture_specification.md`](./12_frontend_architecture_specification.md) — FSD 分層、Server/Client 邊界、Design Tokens
- [`17_frontend_information_architecture_template.md`](./17_frontend_information_architecture_template.md) — 頁面級資訊架構

Monorepo 情境下，前端通常落在 `apps/web/` 內，其內部再依 12 號文件的 FSD 規範細分；本文件只負責到 `apps/web/` 這一層。

---

## 文檔結構

```plaintext
docs/
├── adrs/                     # 架構決策記錄
├── design/                   # 設計文檔
└── images/                   # 文檔圖片
```

---

## 演進原則

- 本結構是起點，依專案發展調整
- 頂層結構的重大變更需 ADR 記錄
- Monorepo/Polyrepo 選擇一旦定案，變更需 ADR 記錄並評估遷移成本
- 一致性比嚴格遵守特定模式更重要
