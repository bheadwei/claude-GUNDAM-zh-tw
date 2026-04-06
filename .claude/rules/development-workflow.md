# 開發工作流

## 功能實作流程

### 0. 研究與重用（任何新實作前必做）
- 先搜 GitHub 找現有實作和模式
- 再查官方文檔確認 API 行為
- 搜套件庫（npm/PyPI/crates.io）找現成方案
- 優先採用經驗證的方案而非全新撰寫

### 1. 先規劃
- 載入 sunnydata-design skill
- 探索意圖與需求 → 撰寫實作計畫 → 依檢查點執行

### 2. TDD 方法
- 遵循 TDD 流程（詳見 testing.md）

### 3. 程式碼審查
- 寫完程式碼後載入 sunnydata-code-review skill
- 處理 CRITICAL 和 HIGH 問題

### 4. 提交
- 詳細 commit message
- 遵循 conventional commits 格式
