---
description: 以測試驅動方式執行實作，會自動載入當前任務的 plan 檔並接續執行。
---

# TDD 指令

照 **`tdd-workflow` skill** 執行測試驅動開發，並**自動載入當前任務（WBS 或 ad-hoc）的 plan 檔**（若存在）按階段推進。

**先載入 `tdd-workflow` skill**——依程式性質決定多嚴格、從驗收條件推出測試、
GREEN 過不了修實作不改測試，都在那裡（唯一來源，本檔不重述）。

實作者有兩種，由下方「選執行方式」決定：

- **主模型自己做**（單一階段，或使用者選直接實作）
- **逐階段派 `general-purpose` implementer**（多階段 standard／critical），照 `subagent-execution` skill

本模板沒有專屬的 TDD agent——不要派 `tdd-guide`，它已退役。

**相關規範：** `tdd-workflow` skill、`testing-standards` skill（覆蓋率門檻、測試怎麼跑）、
`plan-format` skill、`subagent-execution` skill、`.claude/rules/task-mode.md`

## 任務模式分流（最先檢查）

決定模式的優先序：

1. **行內參數** `/tdd quick|standard|critical` → 以此為準，並寫入 `.current-task-mode`（覆寫）
2. 否則讀 `.claude/taskmaster-data/.current-task-mode`
3. 仍無 → 依 `task-mode.md`「自動分級啟發式」即時判定、**宣告理由**後寫入（**不要逕自當 standard**）

判定後：

- **`quick`** → Fast Lane（見下方）
- **`standard`** → 下方流程
- **`critical`** → 下方流程，判成 critical 的那段程式一律先寫測試

### Fast Lane（quick 模式）

1. 跳過 plan 偵測，不派任何 agent
2. 直接實作，完成後補至少 1 個 happy-path 測試
3. 不檢查覆蓋率
4. 完成後提示 `/verify`（會自動跑 quick profile，只跑改到的測試檔）

## 執行前流程

### 1. 偵測當前任務與計畫

1. 讀 `.claude/taskmaster-data/.current-task`，取得當前值——WBS 任務 ID（例 `2.1`）
   或 ad-hoc plan 的檔名主幹（例 `adhoc-2026-10-20-fix-login`）
2. 在 `.claude/taskmaster-data/plans/` 中尋找 `<值>.md` 或 `<值>-*.md`（不含 `archive/`）
3. 若找到且 frontmatter `current_phase` 為 `0`（還沒開始）→ **不問**，直接從階段 1 開始
4. 若找到且已有進度 → 顯示計畫摘要，用 `AskUserQuestion` 問：

   ```
   偵測到計畫：2.1-auth-middleware.md
     狀態：🔄 進行中（階段 2/4）
     下一階段：階段 2 - JWT 驗證核心

   動作？
     [Recommended] 接續執行階段 2
     從階段 1 重新開始
     忽略計畫，自由 TDD
   ```

5. 若**找不到計畫**：
   - `critical` → **不問**，停下來要求先跑 `/plan <id>`（`critical` 一律要 plan）
   - `standard` 且達 `plan-format` skill「何時不該用 /plan」的門檻（唯一來源）→
     用 `AskUserQuestion` 問要先 `/plan <id>`（Recommended）還是直接開始
6. 若**無當前任務**（`.current-task` 不存在）→ 先找 `plans/` 裡 `status: "⏳ 未開始"` 的 plan
   （`/plan` 只寫計畫、不開工，所以剛規劃完的任務會在這裡）：
   - 有 → 用 `AskUserQuestion` 列出讓使用者選要開始哪一份（最近建立的放第一個並標 Recommended），
     另附「不用 plan，直接做」選項。選定後照下方「開工時標進行中」做，再回到第 3 點
   - 沒有，或選了「直接做」→ `critical` 同第 5 點，要求先 `/plan --adhoc`；
     其他模式先用一兩句話寫下「做完時哪些行為成立」當驗收條件

**開工時標進行中**（從階段 1 開始實作的那一刻，只做一次；接續既有進度時略過）：

- **WBS 任務** → 照 `/task-next` 的「狀態同步」節做（唯一來源，勿在此重述），
  第 6 步的模式取 plan frontmatter 的 `mode:`；已是 `🔄 進行中` 且 `.current-task` 已是這個 id 就略過
- **ad-hoc** → 把 plan 檔名主幹（例 `adhoc-2026-10-20-fix-login`）寫進 `.claude/taskmaster-data/.current-task`
- 兩者都把 plan frontmatter 的 `status` 改成 `"🔄 進行中"`

沒有這一步，`/verify` 不會比對這份 plan 的驗收標準，模式檔過期時 hook 也無從由 plan 還原。

### 2. 選執行方式（僅當 plan 有 ≥2 階段 且模式為 `standard`／`critical`）

先檢查帳本 `plans/<plan 同名>.progress.md`：**已存在且身分行指向同一個 plan
→ 這是續跑，直接沿用上次選的方式，不要再問。**

否則用 `AskUserQuestion` 問一題：

```
這個計畫有 4 個階段，要怎麼執行？
  [Recommended] 逐階段派 implementer subagent
    每階段一個全新 subagent 實作 + 階段審查 + 有界修復迴圈，
    過程記進帳本（context 被壓縮也能續跑）。慢一些、貴一些，
    但長任務不會偏離 plan。
  我直接照 plan 實作
    由主模型照 tdd-workflow 逐階段做。快、省，
    但階段多時容易累積偏離。
```

- 選第一個 → **載入 `subagent-execution` skill**，照它的流程走。派工單（`implementer-prompt.md`）
  已要求 implementer 讀 `tdd-workflow`
- 選第二個 → 主模型照下方「每階段」自己做

把選擇記進帳本第一段，避免下次重複問。

## 每階段（主模型直接實作時）

```
讀驗收條件 → 決定嚴格度 → RED → GREEN → 重整 → 階段 coverage → 更新 plan → 審查
```

1. 讀 plan 該階段的「驗收」欄，照 `tdd-workflow` 決定這段程式要多嚴格、推出測試
2. RED → GREEN → 重整：**每輪只跑相關的測試檔**；階段結束跑一次 coverage，只看改到的檔
   （指令與回報格式見 `testing-standards` 的「執行測試」）
3. 更新 plan 階段狀態（**只有主模型能改 plan 檔**，規則見 `plan-format` 的「誰可以寫入計畫檔」）：
   - 該階段標 ✅，更新 frontmatter 的 `current_phase`、`updated`
   - 最後一個階段 → `status: "✅ 完成"`，提示使用者執行 `/verify`
   - 同步更新 `plans/INDEX.md`
4. standard／critical → 委派 `code-quality-specialist` 審這個階段的 diff
   （`git diff <階段起點>..HEAD`，不是整個 repo）。誰審、critical 加誰見
   `rules/task-mode.md` 的「審查節奏」（唯一來源）

整套測試不在這裡跑——那是 `/verify` 的事。

## 使用時機

- 實作新功能、新增函式或元件
- 修復根因已確認的 bug（先寫重現 bug 的測試）。根因還說不出來 → 先派 `debug-investigator`
- 重構現有程式碼
- 建構關鍵商業邏輯

## 與其他指令的搭配

```
/plan             規劃並寫入 plans/<id>-<slug>.md
/tdd              自動載入當前 plan，按階段推進
/build-fix        建置錯誤修復
/code-review      程式碼審查（Claude Code 內建，需要時手動跑，不是流程固定一棒）
/verify           整套測試與整體驗收標準 → 標 WBS 為 ✅
```
