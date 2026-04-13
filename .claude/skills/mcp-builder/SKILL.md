---
name: mcp-builder
description: MCP Server 開發指南。使用 Python (FastMCP) 或 TypeScript (MCP SDK) 建立高品質的 MCP Server，讓 LLM 能透過工具與外部服務互動。適用於需要串接外部 API 或服務時。
license: Complete terms in LICENSE.txt
---

# MCP Server 開發指南

## 概述

建立高品質的 MCP (Model Context Protocol) Server，讓 LLM 能有效地與外部服務互動。MCP Server 提供工具讓 LLM 存取外部服務和 API。品質的衡量標準是：LLM 使用提供的工具完成實際任務的效果。

---

# 流程

## 高階工作流程

建立高品質 MCP Server 分為四個階段：

### 階段 1：深度研究與規劃

#### 1.1 理解 Agent 導向設計原則

實作前先理解如何為 AI Agent 設計工具：

**為工作流程設計，而非只是 API 端點：**
- 不要單純包裝既有 API — 要建立經過思考的、高影響力的工作流程工具
- 合併相關操作（例如 `schedule_event` 同時檢查可用性並建立事件）
- 聚焦在能完成完整任務的工具，而非個別 API 呼叫

**為有限的 Context 優化：**
- Agent 的 context window 有限 — 每個 token 都要有價值
- 回傳高訊號資訊，而非完整資料傾倒
- 提供「精簡」vs「詳細」回應格式選項
- 預設使用人類可讀的識別符（名稱優於 ID）

**設計可行動的錯誤訊息：**
- 錯誤訊息應引導 Agent 走向正確的使用模式
- 建議具體的下一步：「試試 filter='active_only' 來減少結果」
- 讓錯誤具有教育性，而不只是診斷性

**遵循自然的任務劃分：**
- 工具名稱應反映人類思考任務的方式
- 用一致的前綴分組相關工具，便於發現

**使用評估驅動開發：**
- 盡早建立實際的評估場景
- 讓 Agent 回饋驅動工具改進

#### 1.3 研究 MCP 協議文檔

使用 WebFetch 載入：`https://modelcontextprotocol.io/llms-full.txt`

此文件包含完整的 MCP 規格和指南。

#### 1.4 研究框架文檔

載入並閱讀以下參考資料：

- **MCP 最佳實踐**：[查看最佳實踐](./reference/mcp_best_practices.md)

**Python 實作：**
- **Python SDK 文檔**：WebFetch 載入 `https://raw.githubusercontent.com/modelcontextprotocol/python-sdk/main/README.md`
- [Python 實作指南](./reference/python_mcp_server.md)

**Node/TypeScript 實作：**
- **TypeScript SDK 文檔**：WebFetch 載入 `https://raw.githubusercontent.com/modelcontextprotocol/typescript-sdk/main/README.md`
- [TypeScript 實作指南](./reference/node_mcp_server.md)

#### 1.5 徹底研究 API 文檔

要整合某個服務，閱讀**所有**可用的 API 文檔：
- 官方 API 參考文檔
- 認證和授權需求
- Rate Limiting 和分頁模式
- 錯誤回應和狀態碼
- 可用端點及參數
- 資料模型和 Schema

#### 1.6 建立完整的實作計畫

基於研究結果，建立詳細計畫：

**工具選擇：**
- 列出最有價值的端點/操作
- 優先實作最常見和最重要的使用案例
- 考慮哪些工具可搭配完成複雜工作流程

**共用工具和輔助函式：**
- 識別常見的 API 請求模式
- 規劃分頁輔助函式
- 設計過濾和格式化工具
- 規劃錯誤處理策略

**輸入/輸出設計：**
- 定義輸入驗證模型（Python 用 Pydantic，TypeScript 用 Zod）
- 設計一致的回應格式（JSON 或 Markdown），可設定詳細程度
- 規劃大規模使用（數千使用者/資源）
- 實作字元限制和截斷策略（例如 25,000 tokens）

---

### 階段 2：實作

#### 2.1 建立專案結構

**Python：**
- 建立單一 `.py` 檔或依複雜度組織為模組（見 [Python 指南](./reference/python_mcp_server.md)）
- 使用 MCP Python SDK 註冊工具
- 用 Pydantic 模型驗證輸入

**Node/TypeScript：**
- 建立適當的專案結構（見 [TypeScript 指南](./reference/node_mcp_server.md)）
- 設定 `package.json` 和 `tsconfig.json`
- 使用 MCP TypeScript SDK
- 用 Zod schema 驗證輸入

#### 2.2 先實作核心基礎設施

先建立共用工具再實作個別工具：
- API 請求輔助函式
- 錯誤處理工具
- 回應格式化函式（JSON 和 Markdown）
- 分頁輔助函式
- 認證/Token 管理

#### 2.3 系統性地實作工具

每個工具：

**定義輸入 Schema：**
- 使用 Pydantic (Python) 或 Zod (TypeScript) 驗證
- 包含適當的約束（最小/最大長度、regex、範圍）
- 提供清晰描述和範例

**撰寫完整文件說明：**
- 一行摘要說明工具功能
- 參數類型與範例
- 回傳型態 Schema
- 使用範例（何時用、何時不用）
- 錯誤處理文檔

**實作工具邏輯：**
- 使用共用工具避免重複程式碼
- 所有 I/O 使用 async/await
- 實作適當的錯誤處理
- 支援多種回應格式
- 遵守分頁參數和字元限制

**新增工具 Annotations：**
- `readOnlyHint`: true（唯讀操作）
- `destructiveHint`: false（非破壞性操作）
- `idempotentHint`: true（重複呼叫結果相同）
- `openWorldHint`: true（與外部系統互動）

---

### 階段 3：審查與精煉

#### 3.1 程式碼品質審查

檢查：
- **DRY 原則**：工具間無重複程式碼
- **可組合性**：共用邏輯已抽取為函式
- **一致性**：類似操作回傳類似格式
- **錯誤處理**：所有外部呼叫都有錯誤處理
- **型別安全**：完整的型別覆蓋
- **文件**：每個工具都有完整說明

#### 3.2 測試與建置

**重要**：MCP Server 是長時間執行的程序，透過 stdio 或 HTTP 等待請求。直接執行（如 `python server.py`）會導致程序永久等待。

**安全的測試方式：**
- 使用評估工具（見階段 4）— 推薦方式
- 在 tmux 中執行 server
- 用 timeout 測試：`timeout 5s python server.py`

---

### 階段 4：建立評估

#### 4.1 理解評估目的

評估測試 LLM 能否有效使用你的 MCP Server 回答實際的複雜問題。

#### 4.2 建立 10 個評估問題

1. **工具檢視**：列出可用工具並理解其功能
2. **內容探索**：使用唯讀操作探索可用資料
3. **問題生成**：建立 10 個複雜、實際的問題
4. **答案驗證**：自己解答每個問題以驗證答案

#### 4.3 評估要求

每個問題必須：
- **獨立**：不依賴其他問題
- **唯讀**：只需非破壞性操作
- **複雜**：需要多次工具呼叫和深度探索
- **實際**：基於真實使用案例
- **可驗證**：有明確的、可比對的答案
- **穩定**：答案不會隨時間改變

---

# 參考資料

## 文檔庫

開發過程中按需載入：

### 核心 MCP 文檔（優先載入）
- **MCP 協議**：`https://modelcontextprotocol.io/llms-full.txt`
- [MCP 最佳實踐](./reference/mcp_best_practices.md) — 命名慣例、回應格式、分頁、安全等

### SDK 文檔（階段 1/2 時載入）
- **Python SDK**：`https://raw.githubusercontent.com/modelcontextprotocol/python-sdk/main/README.md`
- **TypeScript SDK**：`https://raw.githubusercontent.com/modelcontextprotocol/typescript-sdk/main/README.md`

### 語言特定實作指南（階段 2 時載入）
- [Python 實作指南](./reference/python_mcp_server.md) — Server 初始化、Pydantic 模型、`@mcp.tool` 工具註冊
- [TypeScript 實作指南](./reference/node_mcp_server.md) — 專案結構、Zod Schema、`server.registerTool` 工具註冊

### 評估指南（階段 4 時載入）
- [評估指南](./reference/evaluation.md) — 問題建立、答案驗證、XML 格式規格
