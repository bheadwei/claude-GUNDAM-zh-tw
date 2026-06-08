# 測試要求

## 覆蓋率門檻（依任務模式）

讀 `.claude/taskmaster-data/.current-task-mode`：

| 模式 | 覆蓋率門檻 | 行為 |
|---|---|---|
| `quick` | 不檢查 | 至少 1 個 happy path 測試 |
| `standard`（預設） | 80% | 一般功能/重構 |
| `critical` | 100% | 金流、認證、安全、核心邏輯 |

詳見 `.claude/rules/task-mode.md`。

## 最低覆蓋率: 80%（standard 模式）

必要測試類型：
1. **單元測試** - 個別函式、工具、元件
2. **整合測試** - API 端點、資料庫操作
3. **E2E 測試** - 關鍵使用者流程

## 測試驅動開發（standard / critical 強制；quick 豁免）

> **任務模式豁免**：以下 test-first 流程僅在 `standard` / `critical` 模式強制。
> `quick` 模式（見 `task-mode.md`）允許「先實作 + 後補 happy-path 測試」，**不強制 RED-first、不檢查覆蓋率**。不要對 quick 小任務硬套完整 TDD。

1. 先寫測試 (RED)
2. 執行測試 - 應該失敗
3. 寫最小實作 (GREEN)
4. 執行測試 - 應該通過
5. 重構 (IMPROVE)
6. 驗證覆蓋率 (80%+)

## 測試失敗排除

1. 使用 tdd-guide agent
2. 檢查測試隔離
3. 驗證 mock 正確性
4. 修實作而非測試（除非測試有誤）
