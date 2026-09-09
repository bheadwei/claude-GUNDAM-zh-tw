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
| code-quality-specialist | test-automation-engineer | 發現需要補強測試 |
| test-automation-engineer | e2e-validation-specialist | 單元測試完成，需 E2E 驗證 |
| security-infrastructure-auditor | deployment-expert | 安全檢查完成 |
