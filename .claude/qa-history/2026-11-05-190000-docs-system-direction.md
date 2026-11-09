# 文件體系方向定案（接續 2026-11-05-docs-system-session）

日期：2026-11-05

## 討論（對話中定案，非選項題）

**使用者訴求**：開發流程（SDD＋TDD）不變；文件要收斂、要精、要能隨時反映專案狀態；專案地圖要像 artifact 5XL57YXU6AMcPTgJ2actpi 那樣有燈號、可互動看出這次做了什麼。

**定案內容**：
- 文件 6 份：brief、PRD、架構文件、WBS、plan、ADR
- PRD 功能段用中文 Given／When／Then 情境（BDD 併入，不另開文件），加用語表；DDD 只取用語表與模組邊界
- 借 OpenSpec 概念：plan 寫這次 ADDED／MODIFIED／REMOVED 哪些 PRD 情境，`/verify` 由模型套回 PRD；不裝 OpenSpec CLI、不做 `specs/`、`spec-merge.sh`、`docs-lint.sh`，不加 hook
- 架構文件保留（客戶需要）：人寫段＋自動產生段（模組表、mermaid，和地圖同一份掃描資料）
- 專案地圖只有一張，不另做開發地圖
- hook 不再增加；hook 減法盤點另議（實測 Windows 上 Bash 工具呼叫的 hook 約 3.5～4 秒）

## Q1 專案地圖要不要加「plan 預計會動」這一層？

- 選項：加 (Recommended)／不加
- 答案：**加**
- 內容：讀 plan 的 `files:`，虛線框標出預計會動的模組，與 git diff 的實際改動對照；右側欄顯示「plan 第 N／M 階段」

## Q2 architect 改寫後留下的 5 件待決事項

- 內容：①架構文件自動段只在 `/verify`、`/task-status` 更新，背景重掃不寫檔 ②ADR 統一放 `docs/decisions/` ③plan 狀態沿用四個 emoji、禁止附註 ④documentation-specialist 不再產 codemap ⑤workflow-template-manager 退場（從 3 個 hook 檔刪名字，不新增 hook）
- 選項：全部照建議 (Recommended)／逐題看／先看 ADR 全文
- 第一次回答（追問）：「既有文件有必要留嗎？還是封存起來比較建議？」→ 回覆照 ADR-008：可併入與過期的搬 `docs/archive/`，交付物留原處，永不刪除
- 答案：**全部照建議**

## Q3 「plan 階段可平行」要不要併進這次的 plan 格式改動（ADR-006）？

- 起因：使用者指出 plan 的階段不會自動判斷平行，要特別說才會判斷。原因：`/task-next` 要求候選任務已有 plan 與 `files:`（通常還沒寫）；`/tdd` 只問執行方式、階段一律循序，plan 階段沒有依賴欄
- 修法：每階段加「依賴」欄；planner 標可平行階段；`/tdd` 多「用 worktree 同時跑」選項；`/task-next` 沒 plan 時用 WBS 模組欄粗估。只改 md
- 選項：併進這次 (Recommended)／之後另外做
- 答案：**併進這次**

## Q4 check-counts.sh 的 5.1／5.5 檢查（第 302–346、375 行）怎麼處理？

- 選項：刪掉 (Recommended)／改成檢查自動段標記
- 答案：**刪掉**（overview.sh 讀舊專案 5.5 的程式照留）

## Q5 WBS「模組」欄的模組代號從哪裡取？

- 選項：改讀自動段 (Recommended)／直接讀掃描結果
- 答案：**依建議**：優先讀架構文件自動段的模組表，舊專案退回 5.5，都沒有填 `—`
- 使用者追問「模組名稱是什麼」→ 說明：是程式區塊代號（地圖上的框，如 `web`、`svc-a`），不是 WBS 任務號碼

## 結論

委派 architect 依上述方向改寫 ADR-004～008 與設計提案（不動已 commit 的 ADR-001～003），更新給 planner 的交接；之後再派 planner。
