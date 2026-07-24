---
description: 驗證專案是否符合指定的 VibeCoding 工作流模板規範。
---

# 模板合規檢查

## 選擇模板: $ARGUMENTS

範本來源：`.claude/skills/project-docs/templates/`

## 可用模板

### 階段 0: 流程
1. **workflow-manual** → `01_workflow_manual.md`

### 階段 1: 規劃 (02-03)
2. **project-brief** → `02_project_brief_and_prd.md`
3. **bdd** → `03_behavior_driven_development_guide.md`

### 階段 2: 架構設計 (04-06)
4. **adr** → `04_architecture_decision_record_template.md`
5. **architecture** → `05_architecture_and_design_document.md`
6. **api** → `06_api_design_specification.md`

### 階段 3: 詳細設計 (07-09, 18)
7. **tests** → `07_module_specification_and_tests.md`
8. **structure** → `08_project_structure_guide.md`
9. **design** → `09_design_and_dependencies.md`
10. **data-model** → `18_data_model_and_migration_spec.md`

### 階段 4: 開發品質 (11-12, 17)
11. **code-review** → `11_code_review_and_refactoring_guide.md`
12. **frontend-arch** → `12_frontend_architecture_specification.md`
13. **frontend-ia** → `17_frontend_information_architecture_template.md`

### 階段 5: 安全部署 (13-14, 19-20)
14. **security** → `13_security_and_readiness_checklists.md`
15. **threat-model** → `20_threat_model_template.md`
16. **deployment** → `14_deployment_and_operations_guide.md`
17. **observability** → `19_observability_and_slo_spec.md`

### 階段 6: 維護管理 (15-16)
18. **documentation** → `15_documentation_and_maintenance_guide.md`
19. **wbs** → `16_wbs_development_plan_template.md`

### 階段 7: AI 功能 (21)
20. **ai-llm** → `21_ai_llm_integration_spec.md`

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
/template-check security       # 檢查安全合規
/template-check architecture   # 檢查架構合規
/template-check api            # 檢查 API 合規
```
