---
status: 已採納
date: 2026-11-05
decision-makers: [使用者]
---

> **定案（2026-11-05，問答紀錄 `.claude/qa-history/2026-11-05-153000-overview-from-code-adr.md`）**
> - Q1 同意方式：**可以**——按需產生，每次由 `/task-status` 用 AskUserQuestion 問，永遠不自動執行；
>   `project.json` 設 `overview.notes: off` 可整個關閉說明層
> - Q2 `module-notes.md`：**進 git**
> - 實作計畫：`.claude/taskmaster-data/plans/archive/adhoc-2026-11-05-overview-from-code.md`（階段 4）

# ADR-2026-11-05-002: 模組白話說明由 documentation-specialist 按需產生、存檔快取，品質由腳本驗證

## 背景

骨架改成掃程式碼之後（ADR-2026-11-05-001），模組名稱只剩目錄名（`svc`、`core`），使用者看不出每一塊在做什麼。
白話說明只能靠 LLM 讀程式碼產生（Floorplan 也是這樣做），但這有成本：要花 token，程式碼也會送到模型。
使用者的客戶是金融業。使用者原本想用 skill 來保證這一層的品質，
但 skill 只是文字，要被想起來才會載入，而且載入了也擋不住格式錯誤。

## 決策

說明存成 **`.claude/taskmaster-data/module-notes.md`**（人可讀的表格，進 git），流程分四段，各放在該放的層：

| 職責 | 層 | 做法 |
|---|---|---|
| 寫說明 | **Agent**：documentation-specialist（既有，不新增 agent） | 需要獨立 context 讀大量程式碼 |
| 寫作標準（rubric） | **agent 定義明寫路徑的附屬檔**：`.claude/skills/project-docs/module-notes.md` | 寫的人固定是同一個 agent，直接在定義裡寫路徑，不靠 description 被想起來。**不新增獨立 skill** |
| 保證品質 | **Script**：`overview.sh --check-notes` 做機械式驗證，加上 **Hook**：`post-write.sh` 在寫入 notes 的當下把違規項目注入對話 | 判斷得出對錯的事交給機器 |
| 何時更新 | **Command**：`/task-status` 偵測到「沒有說明或說明已過期」時，用 AskUserQuestion 問使用者 | 絕不自動花 token |

過期的判定：notes 檔頭記一個 `based_on: <commit>`。腳本跑一次 `git diff --name-only <commit>`，
改過的檔落在哪些模組，那些模組就標「可能過期」。

## 替代方案

| 方案 | 優點 | 否決理由 |
|---|---|---|
| 不做說明層（只顯示目錄名） | 0 token、程式碼不送模型 | 使用者看不懂地圖，等於沒有解決問題 |
| 獨立新 skill `module-notes`，靠 description 喚起 | 符合使用者最初的想法 | 寫的人固定是 documentation-specialist，指定路徑比靠 description 被想起來可靠；而且 skill 擋不住格式錯誤，真正的保證來自腳本驗證 |
| 每次重產都自動呼叫 LLM（Floorplan 模式） | 說明永遠是新的 | 每次都花 token；背景的 hook 開不了模型；金融客戶需要明確同意 |
| 存在 `overview/`（不進 git） | 不會弄髒工作區 | 寫一次要花幾十到上百 k token，換台機器或換個同事就要重寫。notes 只由 agent 前景寫入，不會被 hook 背景改，所以沒有「弄髒工作區」的問題 |

## 後果

**得到：** 地圖上每個模組都有一句白話說明；只有過期的模組要重寫，token 花在刀口上；
格式、長度、引用的檔案是否存在、有沒有機密字樣，都由機器檢查。

**犧牲：** 第一次寫說明約要 100k–180k 輸入 token（30 個模組）。程式碼片段會經由 Claude Code 送到 Anthropic，
這跟平常開發用的是同一個通道，不經第三方，但仍要使用者明確同意。
說明的「內容對不對」腳本驗不出來，只能靠 rubric 加上人工抽查。

**何時該重新考慮：** 使用者回報說明經常不準；或客戶政策禁止把程式碼送進模型（這時把說明層關掉，
`project.json` 設 `overview.notes: off`，地圖照樣能用）。

## 確認方式

- [T] `overview.sh --check-notes` 能抓到：超過長度、引用的檔案不在該模組裡、出現 IP／連線字串／`password=`／Email、id 不存在於骨架
- [T] `post-write.sh` 收到寫入 `module-notes.md` 的 payload、而且內容有違規時，`additionalContext` 列出違規項目；沒有違規時 stdout 為空
- [T] `based_on` 之後改過某模組的檔 → data.js 裡那個模組的 `description.stale` 是 `true`
- [M] 在仿 for-query 的 fixture 上實跑一次 documentation-specialist，人工抽查 5 個模組的說明是否正確

## 相關

- 設計提案：`.claude/context/decisions/architect-2026-11-05-1500.md` 第 5 節
- 相關：ADR-2026-11-05-001
