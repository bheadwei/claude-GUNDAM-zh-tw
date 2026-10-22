# Coordination 協調機制

管理 Subagent 之間的任務交接。與 `../context/` 系統搭配使用。

## 目錄結構

```
coordination/
├── handoffs/              # Agent 間任務交接記錄（平坦層＝還沒結案的）
│   ├── archive/YYYY-MM/   # 已 completed / cancelled，由 hook 自動搬入
│   └── _HANDOFF_TEMPLATE.md
└── conflicts/             # 衝突解決與決策記錄
```

**平坦層只放未結案的交接。** `status:` 一旦改成 `completed` 或 `cancelled`，
`post-agent-report.sh` 會在下一次 subagent 結束時把該檔移進 `archive/YYYY-MM/`
（月份取自 frontmatter 的 `date:`）。檔案內容不變、同名只加 `-2` 後綴，不覆蓋也不刪除。

所以歸檔不需要任何人動手——**你要做的只是改 `status:`**。
（不想讓它自動搬：`/suggest-mode off`，該開關同時關掉這個 hook 的全部動作。）

## 使用方式

- **建立交接**: 複製 `handoffs/_HANDOFF_TEMPLATE.md`，命名為 `<from>-to-<to>-<YYYY-MM-DD-HHMM>.md`
- **查看待處理**: `grep -l "status: pending" .claude/coordination/handoffs/*.md`
  （glob 不遞迴，所以 `archive/` 不會被撈到——hook 的 pending 掃描同理）
- **查歷史交接**: `grep -rl "<agent 名>" .claude/coordination/handoffs/archive/`
  或直接看 `archive/2026-09/` 這樣的月份目錄
- **記錄衝突**: 複製 `conflicts/_CONFLICT_TEMPLATE.md`，命名為 `conflict-<YYYY-MM-DD-HHMM>-<簡述>.md`

## 常見交接場景

| 從 | 到 | 觸發 |
|:---|:---|:---|
| architect | planner | ADR 定案，需落地為實作計畫 |
| code-quality-specialist | test-automation-engineer | 某條有風險的路徑完全沒有測試 |
| refactor-cleaner | code-quality-specialist | 清理完成，確認無回歸、無孤兒引用（refactor-cleaner 在 worktree 寫不到主 checkout，由**主模型落檔**） |
| ui-builder | e2e-validation-specialist | 關鍵使用者流程需 E2E 驗證 |
| debug-investigator | code-quality-specialist ／ security-infrastructure-auditor | 修復後複查；critical（金流／認證）的 bug 另交 security |
| security-infrastructure-auditor | code-quality-specialist | **主模型修完**安全問題後重驗 |
| security-infrastructure-auditor | deployment-expert | 部署設定有問題 |

`test-automation-engineer` 是終端節點，補完測試不再往下交接。完整分類見
`.claude/rules/agent-orchestration.md` 的「哪些 agent 實作了接力」（唯一來源）。
