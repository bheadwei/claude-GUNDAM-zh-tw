---
agent: skill-curator
area: decisions
target: 文件計畫收尾的 4 處不一致 + description 喚起檢查
date: 2026-11-09
severity: info
status: fixed
---

# skill-curator — 文件計畫收尾（2026-11-09）

## TL;DR

修掉 `adhoc-2026-11-05-docs-system` 「發現與決策」記下的 4 處範圍外不一致；`check-counts.sh` 補一項 plan status 檢查涵蓋範例區塊外；
`docs-init`、`deployment-expert` 的 description 補觸發條件。行為改變未驗證。

## 裁決

| 對象 | 裁決 | 理由 |
|---|---|---|
| `spec-convergence` 檢查 C | Improve | 原本派 `documentation-specialist` 比對 PRD 情境；文件階段 5 後它的 description 寫明不寫 PRD、原則是「以程式碼為準改文件」，和本 skill「只報告落差、PRD 或程式誰改由使用者決定」相衝。改派 `general-purpose` 只讀比對、回傳表格，報告與提問留主模型。反模式那行同步 |
| `update-template.{sh,ps1}` 結尾 | Update | 「沒有架構文件時會多印提示請 documentation-specialist 反推」已不成立：`task-status.md:44` 明寫沒有架構文件時不印提示，`overview.sh` 只對草稿標記發 notice。兩份改成「地圖從程式碼掃出…要補文件跑 `/docs-init`」 |
| `plan-format` WBS 移除規則 | Improve | `status: "⚠️ WBS 已移除"` 違反同檔四值規則。改標 `🚫 阻塞` ＋「發現與決策」一行；阻塞是因為 `/tdd`（`tdd.md:68`）只撿 `⏳ 未開始`，而 `overview.sh` 的阻塞狀態取自 WBS 列，任務不在 WBS 就不會被計入 |
| `check-counts.sh` plan status 檢查 | Improve | 原檢查只看 plan-format 範例區塊（`wbs_task:` 到 code fence），上面那句在區塊外所以沒抓到。新增一項：plan-format、`commands/`、`agents/`、`templates/` 裡 emoji 開頭的 `status: "…"` 只准四值（ASCII 開頭的如 `status: "ok"` 是程式碼範例，排除）。以舊版 plan-format 實測會報錯 |
| `post-write.sh` WBS 提醒 | Update | 「選型理由 → `context/decisions/` 或 ADR」與 ADR-2026-11-05-004（新專案 ADR 在 `docs/decisions/`）不符；改成 `wbs.template.md:134` 同一寫法。`run-tests.sh` 沒有斷言這句（`:1032` 只是輸入資料含「選型理由」字樣），不需改預期 |
| `documentation-specialist` description | Keep | 仍是 `Use PROACTIVELY 在…` 觸發式，有 `.doc-impact` 這個機器時機，邊界寫明不寫 PRD／ADR；沒有 codemap、workflow-template-manager |
| `deployment-expert` description | Improve | 本體新增「維護 runbook」節，但 description 沒有 runbook；「寫 runbook 的告警／事故處理」這類請求在路由表沒有對應列（第 44 列只管跟程式碼對不上的事實），只能靠 description 命中。補一句 runbook 觸發 |
| `commands/docs-init.md` description | Improve | 原為內容摘要（「產出專案文件初稿，依 demo/mvp/full…」），且沒提階段 6 新增的舊專案盤點入口。改成 `Use when …` ＋使用者原話，保留模式說明 |
| `skills/INDEX.md` | Keep | `project-docs` 兩列與 `spec-convergence` 列仍正確；無過時字 |

## 驗證

- 接線：`check-counts.sh` 719 項全部一致（原 718，多出的是新增的 plan status 檢查）
- hook：`run-tests.sh "擴充維護提醒"`（WBS 提醒所在節）35 過／0 敗，未跑整套
- 行為：**未驗證行為改變**（沒有跑 `run-compliance.sh`）
