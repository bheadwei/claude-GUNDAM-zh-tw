# skill-curator：測試瘦身、tdd-guide 退役、白話 output style、兩個 hook 修正（2026-10-15 16:30）

依據：`skill-curator-2026-10-15-1439-testing.md`（同日盤點）＋ 使用者拍板的 19 項決定。未 commit。

## 結論

1. 測試不再被兩個 agent 各測一次：`test-automation-engineer` 只在「有風險的路徑完全沒有測試」時才接。
2. 測試怎麼跑有了唯一來源（`testing-standards` 的「執行測試」）：每輪只跑相關測試檔，coverage 階段結束跑一次且只看改到的檔，回報只寫摘要。
3. 覆蓋率只算這次改到的檔；critical 只看關鍵模組的分支覆蓋。
4. `tdd-guide` 刪除，TDD 流程改由新 skill `tdd-workflow` 承載，實作者是主模型或 `general-purpose` implementer。
5. 新增 `plain-language` output style；依官方文件同時設 `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0`。
6. 修正合併紀錄把 shell 片段記成分支名的問題；subagent 回報不再觸發關鍵字路由。

## 逐項裁決

| 對象 | 裁決 | 理由 |
|---|---|---|
| `tdd-guide` agent | Retire（使用者拍板） | 缺陷：與 test-automation-engineer 在新功能鏈上重複測同一批程式；`:66` 叫自己用沒有的 `AskUserQuestion`；自己改 plan 檔與「只有主模型改 plan」衝突。現由 `tdd-workflow` skill（流程）＋主模型或 `general-purpose` implementer（執行者）覆蓋 |
| `tdd-workflow` skill（新） | Keep | 帶的是模型不會憑空產出的東西：依程式性質決定嚴格度的表、驗收條件→測試的對應規則、「改測試必須寫理由」。接線：`debug-investigator`、`implementer-prompt.md`、`/tdd` |
| `testing-standards` | Improve | 新增「執行測試」節（唯一來源）；門檻表改成只算改到的檔；拿掉「（預設）」；8 項邊界改成挑適用的；TDD 流程搬去 `tdd-workflow` |
| `python-testing` | Improve | 816 → 160 行，只留 uv、目錄、pyproject、async、FastAPI override 要清、DB rollback、patch 位置；刪除通用 pytest 教學與重述的 80%／Always TDD |
| `test-automation-engineer` | Improve | 描述拿掉 `PROACTIVELY`，改成有具體缺口才派；刪除寫死的 80%／100% |
| `code-quality-specialist` | Improve | 「缺少測試」不再自動 HIGH；只在有風險路徑完全沒測試時建 handoff |
| `e2e-validation-specialist` | Improve | 本地只跑 chromium；重跑 3-5 遍只用在新寫或改過的 spec |
| `planner` | Improve | 不再建實作 handoff；驗收欄要寫成能變成測試的句子；檔案已存在改回報 `NEEDS_CONTEXT`（它沒有 `AskUserQuestion`） |
| `plan-format` | Improve | 新增「驗收欄怎麼寫」；範例驗收改成可測句子；明定所有 subagent 不得改 plan |
| `skill-curator`（本 agent 定義） | 未改 | `:176` 也叫自己用 `AskUserQuestion`（反推 DESIGN.md 時），同一類衝突，但不在本次 19 項內，列入疑慮 |

## 驗證

- 接線：`check-counts.sh --tests 375` 共 316 項，5 項不一致，全部在根目錄 `README.md`（不在寫入範圍，交主模型）
- hook 測試：375 通過、0 失敗（原 364，新增 11）
- 行為：**未驗證行為改變**。`using-taskmaster` 路由表與關鍵字路由都改了，需要在有應用程式碼的專案跑 compliance
