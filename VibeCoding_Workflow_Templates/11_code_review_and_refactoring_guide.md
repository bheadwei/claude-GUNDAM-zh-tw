# 程式碼審查與重構指南

> **版本:** v2.0 | **更新:** YYYY-MM-DD

---

## 1. 審查前檢查（提交者）

- [ ] 程式碼可編譯/建置無錯誤
- [ ] 所有測試通過（含新增測試）
- [ ] Linter / Formatter 已執行（Ruff/ESLint/Prettier）
- [ ] 符合專案 `.claude/rules/` 中的編碼規範
- [ ] 已完成自我審查（逐行看過 diff）
- [ ] PR 描述清楚說明「為什麼改」而非「改了什麼」

---

## 2. 審查重點清單（審查者）

### 正確性
- [ ] 邏輯是否正確？邊界條件是否處理？
- [ ] 錯誤路徑是否有適當處理？（不靜默吞噬）
- [ ] 並發安全嗎？（共享狀態、race condition）
- [ ] 資料驗證在系統邊界完成？

### 設計
- [ ] 符合架構分層？（domain 不依賴 infrastructure）
- [ ] 函式 < 50 行、類別 < 200 行？
- [ ] 有沒有不必要的抽象？（三次以上重複才抽取）
- [ ] 命名是否清晰表達意圖？

### 安全（每次都要看）
- [ ] 無硬編碼秘密（API key、密碼）
- [ ] 使用者輸入已驗證/清理
- [ ] SQL 使用參數化查詢
- [ ] 敏感資料不出現在 log 中

### 效能（有疑慮時看）
- [ ] 無 N+1 查詢
- [ ] 大列表有分頁
- [ ] 昂貴操作有快取策略
- [ ] 無不必要的同步阻塞

### 測試
- [ ] 新程式碼有對應測試
- [ ] 測試覆蓋正常路徑 + 邊界 + 錯誤路徑
- [ ] 測試是否脆弱？（不依賴時序、外部狀態）

---

## 3. 審查嚴重等級

| 等級 | 定義 | 範例 | 是否阻擋合併 |
| :--- | :--- | :--- | :--- |
| **Blocker** | 安全漏洞或資料遺失風險 | SQL injection、未加密密碼 | 必須修復 |
| **Major** | 明確的 bug 或設計缺陷 | Race condition、錯誤的商業邏輯 | 必須修復 |
| **Minor** | 改善項目，不影響功能 | 命名不佳、可讀性差 | 建議修復 |
| **Nit** | 個人偏好 | 空行數量、import 順序 | 不阻擋 |

---

## 4. 重構識別 — Code Smells

| Smell | 症狀 | 重構手法 |
| :--- | :--- | :--- |
| **Long Method** | 函式 > 50 行 | Extract Method |
| **Large Class** | 類別 > 200 行或 > 5 個職責 | Extract Class |
| **Long Parameter List** | 參數 > 4 個 | Introduce Parameter Object |
| **Duplicated Code** | 相同邏輯出現 3+ 次 | Extract Method / Module |
| **Feature Envy** | 方法大量存取另一個類別的資料 | Move Method |
| **Shotgun Surgery** | 一個改動需要改 5+ 個檔案 | 合併到同一模組 |
| **Primitive Obsession** | 到處用 string/int 表達業務概念 | Introduce Value Object |

---

## 5. PR 範本

```markdown
## 摘要
[一句話說明這個 PR 為什麼存在]

## 變更類型
- [ ] Bug 修復
- [ ] 新功能
- [ ] 重構（不改行為）
- [ ] 破壞性變更

## 關聯
- Issue: #[number]
- ADR: ADR-[number]（如有架構決策）

## 測試
- [ ] 單元測試通過
- [ ] 整合測試通過
- [ ] 手動驗證：[描述步驟]

## 截圖/錄影
[UI 變更附圖]
```

---

## 6. 合併流程

### 合併前
- [ ] CI 全綠（build + test + lint + security scan）
- [ ] 至少 1 位同儕 Approve
- [ ] Blocker / Major 全部解決
- [ ] Branch 已 rebase 到最新 main

### 合併後
- [ ] 部署到 Staging 驗證
- [ ] 監控 15 分鐘無異常（error rate、latency）
- [ ] 關閉相關 Issue
