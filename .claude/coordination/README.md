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

## 哪些 agent 實作了接力（唯一來源）

2026-11-12 從 `rules/agent-orchestration.md` 搬來：這是給維護 hook 的人看的；執行期由
`post-agent-report.sh` 的 `AREA` 表稽核報告、注入 pending handoff，主模型照提示做即可。
**改這份名單時同步 `post-agent-report.sh` 的 `AREA` 對應表**，否則稽核找不到報告。

**會寫報告 + 建 handoff（8）**：architect、code-quality-specialist、
security-infrastructure-auditor（程式問題由主模型修完才建給 code-quality 的 handoff）、
e2e-validation-specialist、deployment-expert、ui-builder、debug-investigator、skill-curator

**報告與 handoff 寫在回應裡、由主模型落檔（1）**：refactor-cleaner——它固定跑在 worktree
（frontmatter `isolation: worktree`），對主 checkout 的寫入會被 Claude Code 擋下。
主模型把回應裡的兩份全文寫到主 checkout，再啟動 code-quality-specialist

**寫報告、下一棒由主模型接（1）**：planner——計畫寫好後由主模型跑 `/tdd`。
實作者不是專屬 agent（主模型自己照 `tdd-workflow` skill 做，或派 `general-purpose`
implementer，見 `subagent-execution`），所以沒有 handoff 對象

**終端節點，不建 handoff（3）**：build-error-resolver（單點修完即止）、
documentation-specialist、test-automation-engineer（只補被點名的缺口，補完鏈結束）

8＋1＋1＋3＝13，第 14 個 `conflict-resolver` **刻意不在名單裡**：它的 tools 沒有 Write，
機制上寫不了報告檔（只在回應裡回 STATUS 碼），列進去會讓稽核每次解衝突都發假警報
（見 `post-agent-report.sh` 的註解）。**不要把它「補」回來。**
