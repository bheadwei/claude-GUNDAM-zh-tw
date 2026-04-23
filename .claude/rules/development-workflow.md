# 開發工作流

## Python 套件管理（CRITICAL）

Python 專案一律使用 `uv` 管理套件與虛擬環境：
- 初始化：`uv init` → `uv venv --python 3.12`
- 安裝套件：`uv add <package>`
- 執行程式：`uv run <command>`
- **禁止**使用 `pip install`、`pip3`、`poetry`
- 虛擬環境放專案目錄下（`.venv`）
- 每次新增/移除套件後，同步產出 `requirements.txt`：`uv pip compile pyproject.toml -o requirements.txt`

## Node.js / 前端套件管理（CRITICAL）

Node.js 專案的 package manager（`bun` / `pnpm` / `npm`）由使用者在專案層決定，**不由 Claude 自選**。

- **完整規則**：`.claude/rules/package-manager.md`
- **設定檔**：`.claude/taskmaster-data/package-manager.json`
- **選擇 / 切換指令**：`/pm-choose`、`/pm-switch`

**強制行為**：

- 執行 `install` / `run` / `test` 等 Node 相關指令前，**必須**讀取設定檔
- 設定檔不存在 → 觸發 `/pm-choose` 詢問使用者
- 設定檔存在 → 一律套用該 PM 的指令語法（對照表見 `package-manager.md`）
- **禁止**在未確認設定的情況下自行選擇 PM

**模板預設推薦**：新專案優先 `bun`（速度與 DX 最佳），但**必須透過 `/pm-choose` 讓使用者確認**，不可略過。

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
