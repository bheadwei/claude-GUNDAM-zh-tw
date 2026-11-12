# Agent 編排

路由表、宣告格式、Red Flags、狀態碼分流、handoff 接力的**唯一來源是 `using-taskmaster` skill**
（`session-start.sh` 每個 session 全文注入）。本檔只留注入沒涵蓋、而且每次派工都成立的幾條。

1. 都不適配時才退回 Claude Code 內建的 `general-purpose`（本模板不自訂它：同名會 shadow 掉內建版）
2. **委派看任務模式**：`quick` 不拉 planner、不走完整 TDD；`standard`／`critical` 才走完整鏈

## 反模式

- ❌ 有專業 agent 卻全用 general-purpose；留下 pending handoff 卻無人接手
- ❌ 一次委派一長串 agent 卻不在每棒後檢視產出
- ❌ 同時平行啟動會互改同一批檔案的 agent

## 平行

**循序是預設、平行是選項。** plan 的 `files:` 無交集只是必要條件：會讀或跑整個 repo 的 agent
（審查、測試、E2E、重構）要平行**只能用 worktree 隔離**。`pre-agent-gate.sh` 會擋；並行 2–4 個。
判準、例外與完整程序見 `worktree-orchestration` skill（唯一來源）。

誰會建 handoff、為什麼 `conflict-resolver` 不在稽核名單：見 `.claude/coordination/README.md`。
