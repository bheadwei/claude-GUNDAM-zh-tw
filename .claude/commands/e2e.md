---
description: 使用 Playwright 生成並執行端到端測試。建立測試旅程、執行測試、擷取截圖/影片/trace。
---

# E2E 指令

委派 **e2e-validation-specialist** agent 生成、維護與執行 Playwright 端到端測試。

## 知識分層（避免三份副本各自漂移）

| 需要什麼 | 去哪 |
|---|---|
| Playwright 模式與最佳實踐（POM、選擇器、等待、不穩定測試） | `e2e-testing` skill |
| 執行判斷、風險排序、報告與 handoff | `e2e-validation-specialist` agent |
| 入口與時機 | 本指令 |

**本檔不重述指令表與最佳實踐**——那些在 skill 裡，agent 啟動時會載入。

## 使用時機

- 關鍵使用者旅程變更後（登入、金流、CRUD、多步驟表單）
- 開 PR 前的把關鏈：code-quality → security → **e2e**
- 收到 `to: e2e-validation-specialist` 的 pending handoff（常見來源：`ui-builder`）

單元/整合測試用 `/tdd`，不要用 E2E 測每個邊界情況。

## 執行流程

1. 宣告一句「為何委派、預期產出」
2. 啟動 `e2e-validation-specialist`，交付：變更範圍、要驗證的使用者旅程
3. agent 會讀取 `e2e-testing` skill 取得模式、跑測試、寫報告到 `.claude/context/e2e/`
4. 若發現缺測流程 → agent 建 handoff 給 `test-automation-engineer`

## 搭配

```
/tdd            單元/整合測試（更快、更細粒度）
/e2e            使用者旅程端到端驗證（本指令）
/verify pre-pr  PR 前完整把關
/code-review    程式碼審查（Claude Code 內建）
```
