---
name: tdd-workflow
description: Use when about to write implementation code in standard/critical mode — running /tdd, executing a plan phase, acting as an implementer subagent, fixing a bug whose root cause is known, or when the user says 「開始做這個階段」「照 plan 實作」「把這個功能寫出來」「接著做下一階段」「修掉這個 bug」. Decides how test-first to be from what the code is (logic / glue / UI / spike), derives the RED tests from the plan's 驗收 lines, and forbids editing a test to make GREEN pass. Not for quick mode — there you implement and add one happy-path test.
---

# TDD 流程

規格驅動（SDD）＋測試驅動（TDD）：**規格寫出驗收條件 → 驗收條件變成測試 → 測試逼出實作。**
誰來做都一樣——主模型自己做，或 `general-purpose` implementer 照 `subagent-execution` 做。

**測試怎麼跑、輸出怎麼回報、覆蓋率門檻**：見 `.claude/skills/testing-standards/SKILL.md`
的「執行測試」與「覆蓋率門檻」（唯一來源，本檔不重述）。

---

## 1. 先決定這段程式要多嚴格

不是所有程式碼都值得先寫測試。**依程式的性質決定**，不是依心情：

| 程式性質 | 做法 | 為什麼 |
|---|---|---|
| **商業邏輯、計算、解析、權限判斷** | **嚴格先寫測試**（RED → GREEN → 重整） | 錯了不會報錯，只會算錯。測試是唯一的防線 |
| **API 接線、設定、膠水程式** | 先實作，**實作後補整合測試** | 單元測試只會在測 mock；真正會壞的是接起來之後 |
| **UI 畫面** | 截圖驗收 ＋ 關鍵流程 E2E，**不寫單元測試** | 單元測試測不到「看起來對不對」；樣式見 `ui-style-compliance` |
| **探索性試做**（還不知道做不做得到） | **先不寫測試**。方向確定後**重寫**並補測試 | 為會被丟掉的程式寫測試是浪費；但試做的程式碼不能直接留下來當正式版 |

一個階段常常混著兩三種。分開處理：計算的部分先寫測試，接線的部分做完補整合測試。

**探索性試做的界線**：試做完要明講「這是試做，接下來重寫」，不能悄悄把它變成正式實作。
critical 模式不允許跳過測試——判成 critical 的那段程式，一律走第一列。

## 2. 測試從規格推出來

RED 的測試來自 plan 該階段的 **「驗收」** 欄：

- **驗收寫幾條，就至少測幾條**——每一條對應一個（或一組）測試，測試名稱看得出對應哪一條
- **再加上這段程式真正有的錯誤路徑**（外部呼叫失敗、輸入不合法、權限不足）。
  挑法見 `testing-standards` 的「邊界情況：挑適用的測」
- **不多測**：驗收沒寫、程式也沒有的情境，不要自己發明

驗收條件寫得太模糊、變不成測試（例：「功能正常」「體驗良好」）→ **不要自己猜**。
主模型：先補 plan（`/plan <id>` 或直接修驗收欄）再做。
implementer subagent：回報 `NEEDS_CONTEXT`，寫出哪一條無法變成測試、你建議怎麼改寫。

沒有 plan（ad-hoc）時，先用一兩句話寫下「做完時哪些行為成立」，那就是你的驗收條件。

## 3. RED → GREEN → 重整

```
RED     寫一個描述預期行為的測試 → 只跑這個測試檔 → 確認它失敗，而且是「因為功能還沒做」而失敗
GREEN   寫最少的實作讓它通過 → 只跑相關的測試檔 → 通過
重整    消除重複、改善命名、拆過長的函式 → 再跑一次相關測試，仍是綠的
```

- **RED 要看失敗原因**。失敗訊息是 import 錯誤、語法錯誤、fixture 壞掉，那不是 RED，是測試本身壞了
- 一次一條驗收條件，不要一口氣寫十個測試再一口氣實作
- 階段結束時跑一次 coverage（範圍與門檻見 `testing-standards`）

### GREEN 過不了：修實作，不改測試

測試是規格的翻譯。GREEN 過不了代表**實作不符規格**，該改的是實作。

真的要改測試，只有兩種正當理由，而且**必須寫出來**（commit 訊息或回報的「疑慮」欄）：

1. 測試本身寫錯了（斷言的值算錯、測錯了對象）——寫出「原本測什麼、為什麼錯、改成什麼」
2. 規格（驗收條件）改了——寫出是哪一條改了、誰決定的

「測試太嚴格」「這個情況應該不會發生」不是理由。改測試讓它通過，等於把規格改掉而沒人知道。

同一個測試連續修三輪還是紅的 → 停下來。很可能是規格本身有問題或根因不在你以為的地方：
主模型 → 委派 `debug-investigator`；implementer → 回報 `BLOCKED`，附上試過什麼。

## 4. 階段完成之後

| 誰在做 | 做什麼 |
|---|---|
| **主模型**（`/tdd` 直接實作） | 更新 plan 的階段狀態（規則見 `plan-format` skill）→ standard/critical 委派 `code-quality-specialist` 審這個階段的 diff |
| **implementer subagent** | **不要碰 plan 檔、WBS、`.claude/taskmaster-data/`**。照派工單的回報格式交回，由主模型更新狀態與安排審查 |

subagent 沒有 `AskUserQuestion`。需要使用者決定的事，一律寫進回報（`NEEDS_CONTEXT`），由主模型去問。

## 反模式

- ❌ 先把整個階段寫完，最後補一批測試再宣稱「TDD」
- ❌ 為了讓 GREEN 通過改斷言、加 `skip`、放寬比對條件，而且沒寫理由
- ❌ 每一輪都跑整套測試加 coverage
- ❌ 為 UI 畫面寫一堆 snapshot 單元測試，卻沒有截圖驗收
- ❌ 試做的程式碼沒重寫就直接當正式版留下來
- ❌ 驗收條件寫「功能正常」，然後自己決定什麼叫正常

## 相關

- `.claude/skills/testing-standards/SKILL.md` — 覆蓋率門檻、執行測試、該測哪些邊界
- `.claude/skills/plan-format/SKILL.md` — 驗收欄的寫法、誰能改 plan 檔
- `.claude/skills/subagent-execution/SKILL.md` — 多階段計畫逐階段派 implementer
- `.claude/commands/tdd.md` — 使用者的入口
- `.claude/rules/task-mode.md` — quick／standard／critical
