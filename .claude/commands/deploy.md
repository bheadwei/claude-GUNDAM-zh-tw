---
description: 部署入口指令。先跑安全把關（security-infrastructure-auditor）再委派 deployment-expert 執行部署/CI-CD/IaC，依目標環境調整嚴格度。
---

# 部署

部署是「PR 前把關 → 上線」鏈的最後一棒。本指令是 `deployment-expert` agent 的入口，並依 `agent-orchestration.md` 的部署鏈強制先過安全閘門。

## 流程

### 步驟 0：確認部署目標（必跑）

若使用者未在 `$ARGUMENTS` 指明環境，用 `AskUserQuestion` 問**一題**（遵守 `interactive-qa.md`）：

- 問題：「要部署到哪個環境？」
- 選項：`staging（預備）`、`production（正式）`、`preview / 其他`（可直接輸入名稱）
- 其餘部署細節（平台、是否零停機）由 agent 視專案推斷或在執行中追問。

`production` 視為 **critical**：安全閘門不可略過、需零停機策略與回滾計畫。

### 步驟 1：安全閘門（部署前強制）

啟動 `security-infrastructure-auditor`，掃描本次要上線的變更：
- 硬編碼秘密、`.env` / 金鑰外洩
- 認證/授權、輸入驗證、注入風險
- 相依套件與基礎設施設定（Dockerfile、IaC、CI secrets）

> 發現 CRITICAL/HIGH → **停止部署**，先修復（auditor 會建立 handoff 給 `code-quality-specialist` 或 `deployment-expert`）。production 必須零 CRITICAL/HIGH 才繼續。

### 步驟 2：委派 deployment-expert

宣告一句「為何委派、預期產出」後啟動 `deployment-expert`，交付：
- 目標環境（步驟 0）
- 安全掃描結論（步驟 1）
- 待上線範圍（`git diff <base>...HEAD`）

agent 會處理：建置/容器化、CI/CD pipeline、IaC、零停機發布策略、上線後監控；並讀取 `.claude/coordination/handoffs/` 中 `to: deployment-expert` 的 pending 交接作為工作清單。

### 步驟 3：收尾

- 確認 agent 已寫報告到 `.claude/context/deployment/`
- 將處理完的 handoff 標記 `completed`
- 向使用者回報：部署目標、安全結論、執行結果、回滾方式

## 何時用

- 要把功能上線（staging / production）
- 建立或調整 CI/CD、容器、K8s、IaC
- 規劃零停機發布或上線監控

## 相關

- `.claude/agents/deployment-expert.md` — 實際執行者
- `.claude/agents/security-infrastructure-auditor.md` — 部署前安全把關
- `.claude/rules/agent-orchestration.md` — 部署鏈：security → deployment
- `.claude/rules/security.md` — Commit/上線前安全清單
