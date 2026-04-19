# 開發工作流

## Python 套件管理（CRITICAL）

Python 專案一律使用 `uv` 管理套件與虛擬環境：
- 初始化：`uv init` → `uv venv --python 3.12`
- 安裝套件：`uv add <package>`
- 執行程式：`uv run <command>`
- **禁止**使用 `pip install`、`pip3`、`poetry`
- 虛擬環境放專案目錄下（`.venv`）
- 每次新增/移除套件後，同步產出 `requirements.txt`：`uv pip compile pyproject.toml -o requirements.txt`

## 功能實作流程

### 0. 研究與重用（任何新實作前必做）
- 先搜 GitHub 找現有實作和模式
- 再查官方文檔確認 API 行為
- 搜套件庫（npm/PyPI/crates.io）找現成方案
- 優先採用經驗證的方案而非全新撰寫

### 1. 先規劃
- 使用 planner agent 建立實作計畫
- 識別依賴和風險
- 拆解為階段

### 2. TDD 方法
- 使用 tdd-guide agent
- 先寫測試 (RED)
- 實作讓測試通過 (GREEN)
- 重構 (IMPROVE)
- 驗證 80%+ 覆蓋率

### 3. 程式碼審查
- 寫完程式碼後立即使用 code-quality-specialist agent
- 處理 CRITICAL 和 HIGH 問題

### 4. 提交
- 詳細 commit message
- 遵循 conventional commits 格式
