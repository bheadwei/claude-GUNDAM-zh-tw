---
name: testing-standards
description: 測試覆蓋率門檻（依 quick/standard/critical 任務模式分級）、必要測試類型、TDD 的 RED-GREEN-REFACTOR 流程與測試失敗排除。Use when writing or fixing tests, running /tdd, deciding coverage targets, or diagnosing failing tests. quick 模式的小任務不套用完整 TDD。
---

# 測試要求

## 覆蓋率門檻（依任務模式）

讀 `.claude/taskmaster-data/.current-task-mode`：

| 模式 | 覆蓋率門檻 | 行為 |
|---|---|---|
| `quick` | **不檢查** | 至少 1 個 happy path 測試 |
| `standard`（預設） | 80% | 一般功能/重構 |
| `critical` | 100% | 金流、認證、安全、核心邏輯 |

> ⚠️ 這張表是覆蓋率門檻的**唯一來源**。不要在其他地方重述「80% 適用所有程式碼」——
> quick 模式明確豁免。分級定義見 `rules/task-mode.md`。

## 必要測試類型

1. **單元測試** — 個別函式、工具、元件
2. **整合測試** — API 端點、資料庫操作
3. **E2E 測試** — 關鍵使用者流程（見 `e2e-testing` skill）

## 測試驅動開發（standard / critical 強制；quick 豁免）

> **任務模式豁免**：以下 test-first 流程僅在 `standard` / `critical` 模式強制。
> `quick` 模式允許「先實作 + 後補 happy-path 測試」，**不強制 RED-first、不檢查覆蓋率**。
> 不要對 quick 小任務硬套完整 TDD。

1. 先寫測試 (RED)
2. 執行測試 — 應該失敗
3. 寫最小實作 (GREEN)
4. 執行測試 — 應該通過
5. 重構 (IMPROVE)
6. 驗證覆蓋率（依上表門檻）

## 必須測試的邊界情況

1. Null / Undefined 輸入
2. 空陣列 / 空字串
3. 無效型別傳入
4. 邊界值（最小 / 最大）
5. 錯誤路徑（網路失敗、DB 錯誤）
6. 競態條件（並行操作）
7. 大量資料（10k+ 項目的效能）
8. 特殊字元（Unicode、emoji、SQL 字元）

## 測試反模式（避免）

- 測試實作細節（內部狀態）而非行為
- 測試之間互相依賴（共享狀態）
- 斷言太少（通過但未驗證任何東西）
- 未 mock 外部依賴
- 為了拉高覆蓋率寫沒有實際斷言的測試

## 測試失敗排除

1. 使用 `tdd-guide` agent
2. 檢查測試隔離
3. 驗證 mock 正確性
4. 修實作而非測試（除非測試本身有誤）

## 相關

- `rules/task-mode.md` — 任務分級定義
- `plan-format` skill — plan 階段的「驗收」欄位是 RED 的推導來源
- `e2e-testing` skill — Playwright 端到端測試模式
