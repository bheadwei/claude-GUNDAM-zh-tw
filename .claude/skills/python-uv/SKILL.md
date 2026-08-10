---
name: python-uv
description: Python 專案一律用 uv 管理套件與虛擬環境，禁止 pip/pip3/poetry。含初始化、安裝、執行與 requirements.txt 同步流程。MUST BE USED before running any Python package or environment command (install/add/venv/run), before creating a Python project scaffold, or when touching pyproject.toml / requirements.txt / .venv.
---

# Python 套件管理（uv）

## 🚨 CRITICAL

Python 專案一律使用 `uv` 管理套件與虛擬環境。**禁止**使用 `pip install`、`pip3`、`poetry`。

## 標準流程

```bash
uv init                                          # 初始化 pyproject.toml
uv venv --python 3.12                            # 建立 .venv（放專案目錄下）
uv add <package>                                 # 安裝套件
uv add --dev <package>                           # 安裝開發依賴
uv remove <package>                              # 移除套件
uv run <command>                                 # 在虛擬環境中執行
uv pip compile pyproject.toml -o requirements.txt   # 同步產出 requirements.txt
```

## 規則

- 虛擬環境放**專案目錄下**（`.venv`），不用全域環境
- 每次新增/移除套件後，**同步產出** `requirements.txt`
- 執行任何 Python 程式一律走 `uv run`，不直接呼叫系統 python
- `.venv/` 必須在 `.gitignore` 內

## 專案初始化順序

1. `uv init` → 產生 `pyproject.toml`
2. `uv venv --python 3.12` → 建立 `.venv`
3. `uv add` 安裝基礎依賴
4. `uv pip compile pyproject.toml -o requirements.txt`

## 常見誤用

| ❌ 錯誤 | ✅ 正確 |
|---|---|
| `pip install fastapi` | `uv add fastapi` |
| `python -m venv .venv` | `uv venv --python 3.12` |
| `python main.py` | `uv run python main.py` |
| `pytest` | `uv run pytest` |
| `poetry add` | `uv add` |
