# 文件範本索引

> 6 份文件對 5 份範本。各份文件回答什麼、不寫什麼、demo／mvp／full 先產哪幾份，見 `../SKILL.md`（唯一來源）。

---

## 模板清單（5 份，另有 UI 鏈 2 份）

| 範本 | 產出 | 什麼時候有 |
| :--- | :--- | :--- |
| [project-brief-and-prd.md](./project-brief-and-prd.md) | 上半 `docs/00_brief.md`、下半 `docs/prd.md` | brief 一定有；PRD 在 mvp／full，demo 等第一條情境出現才建 |
| [architecture-decision-record.md](./architecture-decision-record.md) | `docs/decisions/ADR-*.md` | 做決策時 |
| [architecture-and-design.md](./architecture-and-design.md) | `docs/architecture.md` | mvp／full |
| [deployment-and-operations.md](./deployment-and-operations.md) | `docs/runbook.md` | 選配：會上線並持續維運時 |
| [threat-model.md](./threat-model.md) | `docs/threat-model.md` | 條件式：critical 任務碰到認證、金流、個資時必產 |

WBS 與 plan 沒有範本檔：WBS 版面在 `.claude/templates/wbs.template.md`，plan 格式在 `plan-format` skill。

## UI 鏈（不算文件體系）

| 範本 | 產出 |
| :--- | :--- |
| [frontend-architecture.md](./frontend-architecture.md) | `docs/frontend-architecture.md`（`/ui-site` 產） |
| [frontend-information-architecture.md](./frontend-information-architecture.md) | `docs/frontend-information-architecture.md`（`/ui-site` 產，`ui-lint.sh` 讀） |

---

## 版本記錄

| 版本 | 日期 | 變更 |
| :--- | :--- | :--- |
| v6.1 | 2026-11-17 | 範本與 UI 鏈產出檔名去掉數字前綴（`02_project_brief_and_prd.md` → `project-brief-and-prd.md` 等；`docs/12_*`、`docs/17_*` → `docs/frontend-architecture.md`、`docs/frontend-information-architecture.md`）；下方舊紀錄的編號指當時的檔名 |
| v6.0 | 2026-11-06 | 收斂成 5 份（ADR-2026-11-05-004）：改寫 02（brief＋PRD）、05（第 4 節自動段、第 5 節資料流）、14（runbook）；淘汰 01、03、06、07、08、09、11、13、15、16、18、19、21 |
| v5.0 | 2026-07-24 | 搬遷至 `.claude/skills/project-docs/templates/`（skill 自包含）；全數升級至 2026 業界標準 |
| v4.0 | 2026-04-13 | 擴展 02 PRD、擴展 07 模組規格、合併 09+10 為設計與依賴、強化 11 程式碼審查 |
| v3.0 | 2026-03-16 | 全面精簡優化，統一繁中 |
| v2.0 | 2025-10-03 | 重新組織序號，新增 INDEX |
