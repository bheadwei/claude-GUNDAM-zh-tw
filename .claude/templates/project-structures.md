# 專案結構範本

> 此檔案是 `/task-init` 執行時的結構選項參考。
> **不會被自動載入到 session context**。

`/task-init` 會根據專案類型推薦其中一種結構。

---

## 1. 簡易型（CLI 工具、單檔腳本、學習專案）

```
project/
├── CLAUDE.md
├── src/
│   ├── main.[ext]
│   └── utils.[ext]
├── tests/
├── docs/
└── output/
```

**何時用**：
- 單一檔案或少於 5 個模組
- 個人工具、學習練習
- 不需要分層架構

---

## 2. 標準型（Web 服務、API、中型應用）

```
project/
├── CLAUDE.md
├── src/
│   ├── core/        # 核心邏輯
│   ├── utils/       # 工具函式
│   ├── models/      # 資料模型
│   ├── services/    # 服務層
│   └── api/         # API 端點
├── tests/
│   ├── unit/
│   └── integration/
├── docs/
├── configs/
└── scripts/
```

**何時用**：
- 後端服務、REST/GraphQL API
- 需要分層架構（controller / service / repository）
- 預期會有 10+ 個模組

---

## 3. AI/ML 型（模型訓練、資料處理）

```
project/
├── CLAUDE.md
├── src/
│   ├── core/
│   ├── models/
│   ├── training/
│   ├── inference/
│   └── evaluation/
├── data/
│   ├── raw/
│   └── processed/
├── notebooks/
├── experiments/
├── tests/
└── docs/
```

**何時用**：
- 機器學習 / 深度學習
- 需要實驗追蹤
- 含資料前處理 pipeline

---

## GitHub 設定（任何結構都適用）

`/task-init` 完成本地建立後會詢問：

```
GitHub 儲存庫設定：
1. 建立新的 GitHub repo
2. 連接現有 repo
3. 跳過（僅本地 Git）
```

選 1 或 2 後 `/task-init` 自動設定 remote 並推送初始 commit。

---

## 完成訊息範本

```
專案 "[PROJECT_NAME]" 初始化成功！

配置：
- CLAUDE.md 規則生效
- 7 條自動載入規則 (.claude/rules/)
- 13 個專業 Agent 就緒
- 17 個 Slash Command 可用
- Context 系統已啟用 (.claude/context/)
- GitHub: [啟用/未啟用]

下一步：
1. /task-next  取得第一個任務
2. /plan       規劃實作步驟
3. /tdd        開始開發
```
