# Pencil 設計稿落地規則（強制）

Pencil MCP 產出的 `.pen` 檔必須落地在專案根目錄的 `design/` 資料夾。本規則在呼叫 Pencil MCP 工具前強制執行，違反即為違規。

## 🚨 CRITICAL：呼叫 Pencil MCP 前必檢

### 規則 1：新增 `.pen` 檔一律指定 `design/` 路徑

❌ **禁止**使用 `"new"` 參數（會存到 Cursor/IDE 的預設位置，離開專案目錄）：

```
mcp__pencil__open_document("new")   // BAD
```

✅ **必須**傳入 `design/<name>.pen` 路徑：

```
mcp__pencil__open_document("design/login-page.pen")
mcp__pencil__open_document("design/components/button-kit.pen")
```

若該檔案不存在，Pencil 會在該路徑建立新檔；若已存在則開啟。

### 規則 2：確認 `design/` 目錄存在

呼叫 `open_document` 前，若 `design/` 或子目錄尚未建立，**先用 Bash/Write 建立**：

```bash
mkdir -p design
# 或子目錄
mkdir -p design/components
```

### 規則 3：命名規範

- 英數小寫 + 連字號（kebab-case）
- 描述性名稱：`login-page.pen`、`checkout-flow.pen`、`button-kit.pen`
- **禁止** `untitled.pen`、`new.pen`、`test.pen` 這種無意義命名
- 需要時徵詢使用者要叫什麼名字（透過 `AskUserQuestion`）

### 規則 4：子資料夾建議分類

```
design/
├── pages/          # 完整頁面
│   ├── login.pen
│   └── dashboard.pen
├── components/     # 元件庫
│   └── button-kit.pen
├── mobile/         # 行動版
└── web/            # 網頁版
```

無明確分類時可直接放 `design/` 根目錄。

## 使用者詢問「開個新設計稿」的標準流程

1. `AskUserQuestion` 問要叫什麼名字、放哪個子類（若不清楚）
2. 確認 `design/` 或目標子目錄存在（不存在則 `mkdir -p`）
3. 呼叫 `mcp__pencil__open_document("design/<name>.pen")`
4. 接著 `mcp__pencil__get_guidelines` 載入設計指南
5. 開始 `mcp__pencil__batch_design` 操作

## 例外

- 使用者**明確指定**絕對路徑（`C:/...` 或 `/mnt/...`）→ 尊重使用者意圖，不強制改到 `design/`
- 使用者**明確要求**放在其他資料夾 → 尊重，但提醒本規則預設是 `design/`
- 純讀取既有 `.pen` 檔做分析 → 不受本規則限制

## 為什麼重要

Pencil MCP 的 `open_document("new")` 會把檔案建立在 IDE 工作區以外的暫存位置，導致：
- 設計稿無法進 git 版控
- 團隊成員拿不到
- `/ui-page` 等後續指令找不到參考檔
- 與 `design/` 約定脫勾

一律走專案路徑才能確保設計稿是專案資產的一部分。
