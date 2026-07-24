# VibeCoding Workflow Templates（已搬遷）

> ⚠️ 本目錄的範本已於 2026-07-24 搬遷至 **`.claude/skills/project-docs/templates/`**，並升級為 v5.0。

## 為什麼搬？

- 範本現在是 `project-docs` skill 的自包含資源，複製 `.claude/` 即可帶著走
- `scripts/update-template -ClaudeOnly` 只同步 `.claude/`，範本放這裡才能被一併更新
- 單一事實來源，避免兩份漂移

## 新位置

```
.claude/skills/project-docs/
├── SKILL.md            # 使用說明（模式選擇、產出流程）
└── templates/          # 全部文件範本（含 INDEX.md）
```

## 入口指令（不變）

- `/docs-init` — 依 demo / mvp / full 模式產出專案文件
- `/task-init` — 專案初始化（會自動接 /docs-init）
- `/template-check` — 驗證專案文件是否符合範本規範
