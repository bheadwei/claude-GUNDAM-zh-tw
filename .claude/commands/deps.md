---
description: 依賴維護：掃漏洞與過期套件、依風險分批升級、每批測試後才 commit。破壞性升級一次一個並先讀遷移指南。
---

# 依賴維護

`security-infrastructure-auditor` 會**掃出**漏洞，但沒有人負責**修**。這是那個缺口的入口。

## 步驟 1：辨識生態（自動）

| 線索 | 稽核指令 | 過期查詢 |
|---|---|---|
| `package-manager.json` 存在 | 依設定的 PM（見 `node-package-manager` skill） | `<pm> outdated` |
| `pyproject.toml` / `uv.lock` | `uv pip audit`（或 `pip-audit`） | `uv pip list --outdated` |
| `go.mod` | `govulncheck ./...` | `go list -u -m all` |
| `Cargo.toml` | `cargo audit` | `cargo outdated` |

**Node 專案務必先讀 `package-manager.json`**，不可自選 PM（見 `node-package-manager` skill）。

## 步驟 2：分類成批次

把結果分成四批，**優先序固定**：

| 批次 | 內容 | 風險 | 處理方式 |
|---|---|---|---|
| 🔴 **安全** | 有 CVE / advisory 的套件 | 不升更危險 | **最優先**，即使是 major 也要升 |
| 🟢 **patch** | `1.2.3 → 1.2.9` | 低 | 可整批一起升 |
| 🟡 **minor** | `1.2.x → 1.5.x` | 中 | 可整批，但要跑完整測試 |
| ⚠️ **major** | `1.x → 2.x` | 破壞性 | **一次一個**，見步驟 4 |

呈現分類結果並用 `AskUserQuestion` 問要處理哪幾批（`multiSelect: true`，
安全批預設勾選且標 Recommended）。

## 步驟 3：分批升級迴圈（安全／patch／minor）

**每一批**都走完整循環，不可跳步：

1. **建立基準** — 先跑一次完整測試，確認當前是綠燈。**紅燈就停**（否則分不清是誰弄壞的）
2. **升級這一批**
3. **重跑測試 + 建置**
4. **綠燈** → 用描述性訊息 commit（`chore(deps): 升級 X 套件安全更新`）
5. **紅燈** → 回復這批（`git checkout -- <lockfile> package.json` 後重裝），
   把該套件移出本批、單獨處理，繼續下一批
6. 建置壞掉且非套件本身問題 → 委派 `build-error-resolver`

> 這個「一批一測一 commit」的紀律跟 `refactor-cleaner` 相同：出事時能精準回復。

## 步驟 4：Major（破壞性）升級

**一次只做一個**。每個都要：

1. **讀遷移指南** — 用 `context7` MCP 查該套件的最新文檔與 breaking changes；
   沒有 MCP 就找 CHANGELOG / release notes
2. **評估影響** — `grep` 出專案裡用到的 API，逐一對照是否受影響
3. **判斷規模**：
   - 影響 < 3 處且改法明確 → 直接做，走步驟 3 的循環
   - 影響大或改法不確定 → **提議 `/task-add` 加成一個任務**，走 `/plan` → `/tdd`
     （這本來就是跨檔、≥1h 的工作，不該塞在依賴維護裡順手做）
4. 升級後**手動驗證**關鍵流程，不能只靠測試

## 步驟 5：收尾

1. 若有安全更新落地 → 委派 `security-infrastructure-auditor` 複驗，確認漏洞真的消失
2. 若 CI/Dockerfile 有釘版本 → 提示需同步更新
3. 摘要回報：

```
依賴維護結果
──────────────────────────────
🔴 安全:  3 個已升級（CVE-2026-xxxx 等）
🟢 patch: 12 個已升級
🟡 minor: 5 個已升級・1 個回復（測試失敗：<套件>）
⚠️ major: 2 個待處理 → 已加入 WBS 任務 5.1、5.2
──────────────────────────────
測試: 通過   建置: 通過   commit: 4 筆
```

## 何時跑

- **定期**：每月一次，或每個里程碑結束時
- **被動**：`security-infrastructure-auditor` 報告有漏洞時
- **不要**在功能開發到一半跑——會混淆「是我改壞的還是升級弄壞的」

## 使用方式

```
/deps                # 完整流程（掃描 → 分類 → 選批次 → 升級）
/deps --audit-only   # 只掃描分類，不動任何東西
```

## 相關

- `node-package-manager` skill — Node 指令語法與 lock 檔規則
- `python-uv` skill — Python 一律 uv
- `security-infrastructure-auditor` — 漏洞掃描與複驗
- `build-error-resolver` — 升級後建置壞掉時
- `/task-add` — major 升級規模太大時，轉成正式任務
