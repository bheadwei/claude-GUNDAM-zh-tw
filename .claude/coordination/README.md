# Coordination 協調機制

管理 Subagent 之間的任務交接。與 `../context/` 系統搭配使用。

## 目錄結構

```
coordination/
├── handoffs/     # Agent 間任務交接記錄
└── conflicts/    # 衝突解決與決策記錄
```

## 使用方式

- **建立交接**: 複製 `handoffs/_HANDOFF_TEMPLATE.md`，命名為 `<from>-to-<to>-<YYYY-MM-DD-HHMM>.md`
- **查看待處理**: `grep -l "status: pending" .claude/coordination/handoffs/*.md`
- **記錄衝突**: 在 `conflicts/` 建立 `conflict-<YYYY-MM-DD-HHMM>-<簡述>.md`

## 常見交接場景

| 從 | 到 | 觸發 |
|:---|:---|:---|
| code-quality-specialist | test-automation-engineer | 發現需要補強測試 |
| test-automation-engineer | e2e-validation-specialist | 單元測試完成，需 E2E 驗證 |
| security-infrastructure-auditor | deployment-expert | 安全檢查完成 |
