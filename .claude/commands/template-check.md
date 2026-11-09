---
description: 驗證專案文件是否符合 project-docs 範本（brief、PRD、架構文件、ADR、runbook、威脅模型）的節與「不寫什麼」。
---

# 模板合規檢查

## 選擇模板: $ARGUMENTS

範本來源：`.claude/skills/project-docs/templates/`；各份文件的路徑與分工見 `.claude/skills/project-docs/SKILL.md`。

## 可用模板

| 參數 | 範本 | 檢查的文件 |
|---|---|---|
| **brief** | `02_project_brief_and_prd.md`（上半） | `docs/00_brief.md` |
| **prd** | `02_project_brief_and_prd.md`（下半） | `docs/prd.md` |
| **adr** | `04_architecture_decision_record_template.md` | `docs/decisions/ADR-*.md` |
| **architecture** | `05_architecture_and_design_document.md` | `docs/architecture.md` |
| **runbook** | `14_deployment_and_operations_guide.md` | `docs/runbook.md` |
| **threat-model** | `20_threat_model_template.md` | `docs/threat-model.md` |
| **frontend-arch** | `12_frontend_architecture_specification.md`（UI 鏈） | `docs/12_*.md` |
| **frontend-ia** | `17_frontend_information_architecture_template.md`（UI 鏈） | `docs/17_*.md` |

比對三件事：範本的節有沒有缺、範本「不寫什麼」表列的內容有沒有被寫進來、
架構文件第 4 節的 `overview:generated` 標記是否成對（標記之間由專案地圖產生，不檢查內容）。

## 合規分析

針對選定的模板檢查專案合規性：

```
模板: $ARGUMENTS
合規分析:

  符合: [項目列表]
  需改善: [項目列表]
  缺失: [項目列表]

  整體合規: [X]%

建議:
  [Y] 啟動對應 Agent 改善
  [R] 產生詳細報告
  [C] 交叉檢查其他模板
  [N] 稍後處理
```

## 使用方式

```
/template-check prd            # 檢查 PRD 的用語表與情境格式
/template-check architecture   # 檢查架構文件的節與自動段標記
/template-check threat-model   # 檢查威脅模型
```
