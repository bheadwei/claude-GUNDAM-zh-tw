# 效能優化

## 模型選擇策略

| 模型 | 適用場景 |
| :--- | :--- |
| **Haiku 4.5** | 輕量 agent、高頻呼叫、worker agent |
| **Sonnet 5** | 主要開發、多 agent 編排、複雜編碼 |
| **Opus 4.8** | 架構決策、深度推理、研究分析 |
| **Fable 5**（Mythos 級） | 最高難度推理與長程自主任務（主 session 模型） |

> Agent frontmatter 一律用別名（`haiku` / `sonnet` / `opus`），自動解析到當下最新版本，模型改版時無需逐檔更新。

## Context Window 管理

避免在最後 20% context 中進行：
- 大規模重構
- 跨多檔案的功能實作
- 複雜互動除錯

低 context 敏感任務：
- 單檔案編輯
- 獨立工具函式
- 文檔更新
- 簡單 bug 修復

## 建置疑難排解

建置失敗時：
1. 使用 build-error-resolver agent
2. 分析錯誤訊息
3. 增量修復
4. 每次修復後驗證
