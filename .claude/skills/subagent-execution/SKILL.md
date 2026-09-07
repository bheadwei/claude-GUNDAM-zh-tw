---
name: subagent-execution
description: Use when executing a multi-phase plan under standard/critical task mode — dispatches a fresh implementer subagent per plan phase with review and a bounded fix loop, and keeps a ledger that survives context compaction. Not for quick mode or single-phase work.
---

# 執行型委派（Subagent Execution）

把 plan 的**每一個階段**交給一個**全新的 implementer subagent** 去實作，每階段做完立刻
審查，審查有問題就進有上限的修復迴圈。主模型只做協調：派工、讀回報、裁決、記帳。

**核心原則：** 每階段一個新 subagent ＋ 階段審查 ＋ 有界修復迴圈 ＋ 全域最終審查。

**為什麼要派而不自己寫**：subagent 的 context 是你**親手構造**的，不會繼承你這條對話的
雜訊。你精準給它需要的東西，它就不會跑偏；而你的 context 留給協調工作，不會被實作細節
吃掉。這也是為什麼**絕不能叫它「延續我們剛才的討論」**——它看不到，也不該看到。

---

## 何時用

| 條件 | 用執行型委派？ |
|---|---|
| 任務模式 `standard`／`critical` **且** plan 有 ≥2 個階段 | ✅ 適用 |
| `quick` 模式 | ❌ 自己做完，補一個 happy-path 驗證 |
| 沒有 plan 檔 | ❌ 先 `/plan`；沒有階段拆解就沒有派工單位 |
| 單一階段、單檔小改 | ❌ 開 subagent 的開銷大於收益 |
| 探索性工作（還不知道要做什麼） | ❌ 先 `debug-investigator` 或 `architect` |

**這是選項不是強制。** 用 `AskUserQuestion` 問一題讓使用者決定：
逐階段派 implementer（context 乾淨、可平行審查、較慢較貴）vs 主模型直接照 plan 實作
（快、省，但長任務容易偏離 plan）。使用者沒表示過就問，問過就記在帳本裡別再問。

---

## 流程

```
準備：確認 plan 存在 → 建立/接續帳本 → 讀 context/learned/ 的相關坑 → 預檢 plan
   ▼
┌─ 對 plan 的每個階段 ─────────────────────────────────┐
│  1. 記錄派工前的 commit（BASE）                      │
│  2. 派 implementer subagent（見 implementer-prompt）  │
│  3. 讀回報狀態碼 → 分流                              │
│  4. 審查這個階段（規格合規 + 程式品質）              │
│  5. 有問題 → 修復迴圈（最多 5 輪，R≥4 升級模型）     │
│  6. 通過 → 帳本記完成、plan 階段標 ✅、current_phase++│
└──────────────────────────────────────────────────────┘
   ▼
全部階段完成 → 全域審查（整條 branch 的 diff）→ /verify
```

---

## 帳本（Ledger）

**位置**：`.claude/taskmaster-data/plans/<plan 檔同名>.progress.md`
（例：plan 是 `2.1-auth-middleware.md` → 帳本是 `2.1-auth-middleware.progress.md`）

**第一行必須是身分行**，否則你無法確認手上這本帳是不是這個 plan 的：

```markdown
# 執行帳本 — plan: .claude/taskmaster-data/plans/2.1-auth-middleware.md
```

開工前先檢查帳本是否存在：

- 身分行指向**同一個** plan → 這是續跑，讀完帳本接續，**不要從頭開始**
- 身分行指向**別的** plan → 這是別人的帳本，停下來問使用者，不要覆寫
- 不存在 → 建立，寫入身分行

**帳本是你的復原地圖。** context 被壓縮後，**相信帳本與 `git log`，不要相信你的記憶。**
帳本點名的 commit 在 git 裡是真的存在的，你腦中的印象不是。

### 帳本要記什麼

只記**決策與事實**，不記過程敘事。每筆一行，append-only：

```markdown
## 階段 1: 介面與型別
- 2026-09-07 10:12 派工 implementer（sonnet）｜BASE=a1b2c3d
- 2026-09-07 10:20 回報 DONE｜commit=e4f5g6h｜產出 src/types/auth.ts, tests/auth/types.test.ts
- 2026-09-07 10:23 審查通過（規格 ✅ 品質 ✅）
- 2026-09-07 10:23 階段完成 → plan 標 ✅，current_phase=2

## 階段 2: JWT 驗證核心
- 2026-09-07 10:25 派工 implementer（sonnet）｜BASE=e4f5g6h
- 2026-09-07 10:41 回報 DONE_WITH_CONCERNS｜「middleware.ts 已 320 行」
- 2026-09-07 10:42 Ruling: 不在本階段拆檔 — plan 階段 4 就要重整這支 — 若階段 4 取消則留下技術債
- 2026-09-07 10:48 審查 R1：驗簽失敗未回 401 而是 500（規格 ✗）
- 2026-09-07 10:55 修復 R1 完成｜commit=i7j8k9l｜審查通過
```

### 決策（Ruling）的格式

```
Ruling: <你決定了什麼> — <為什麼> — <如果錯了代價是什麼>
```

第三段不能省。它是使用者事後判斷「這個決定要不要推翻」的唯一依據。

---

## 派工

用 `Agent` 工具，`subagent_type: "general-purpose"`（implementer 是通用實作角色，
不是本模板 14 個專業 agent 中的任何一個），prompt 照 `implementer-prompt.md` 組裝。

**每次派工都要明確指定 `model`。** 讓它繼承你的模型是在燒錢——多數實作任務在 plan
寫清楚的前提下是機械性的。

| 任務性質 | 模型 |
|---|---|
| 機械實作（獨立函式、規格明確、1-2 檔） | `haiku` |
| 整合與判斷（跨檔協調、比對既有模式、除錯） | `sonnet` |
| 架構與設計取捨 | `opus` |
| 審查 | 與被審對象同級，複雜階段往上一級 |
| 修復迴圈第 4-5 輪 | **至少比前一輪高一級** |

**回合數比單價貴。** 掛鐘時間與 context 成本取決於「來回幾次」，不是每 token 多少錢。
一個便宜模型來回五次，比一個貴模型一次做對更貴。規格模糊時直接上一級。

### 同形狀的小任務可以合批

plan 裡連續幾個階段如果是同一種形狀的機械工作（例如「把這 5 個檔的 import 路徑改掉」），
合成一次派工，不要一階段一次。判準：合批後的驗收標準還能一次講清楚嗎？

---

## 讀回報：照狀態碼分流

implementer 會回 `STATUS: <碼>`（見各 agent 檔的「回報格式」）。

| 狀態碼 | 你要做的事 |
|---|---|
| `DONE` | 產生 diff（`git diff <BASE>..HEAD`，**不要用 `HEAD~1`**——多 commit 的階段會只看到最後一個）→ 進審查 |
| `DONE_WITH_CONCERNS` | 先讀疑慮。屬正確性或範圍 → 處理掉再審查；只是觀察 → 記進帳本，繼續 |
| `NEEDS_CONTEXT` | 補齊它說缺的，**重新派**。缺的是使用者意圖 → 去問使用者 |
| `BLOCKED` | 評估阻礙：計畫本身錯了就裁決並改計畫再派；環境問題就修環境；**絕不用同一個模型原樣重試** |
| 沒有狀態碼 | 當作沒交代完。自己驗證產出（跑測試、讀 diff）再決定 |

---

## 審查

每階段做完審兩件事，**分開審**：

1. **規格合規**：這個階段的「驗收」欄達成了嗎？做的是 plan 說的事嗎？有沒有多做？
2. **程式品質**：委派 `code-quality-specialist`（`subagent_type: "code-quality-specialist"`）

`critical` 模式額外加 `security-infrastructure-auditor`。
涉及 UI 關鍵流程加 `e2e-validation-specialist`。

審查者要拿到的是**這個階段的 diff**，不是整個 repo。給它 `git diff <BASE>..HEAD` 的輸出
或檔案清單，讓它聚焦。

---

## 修復迴圈（上限 5 輪）

| 輪次 | 做法 |
|---|---|
| R1-R3 | 把審查發現交回**同一個** implementer（重新派，帶上發現與原始階段規格） |
| R4-R5 | **換一個全新的 implementer**，模型至少升一級。前一個已經證明它看不到這個問題 |
| 第 5 輪仍未過 | 停下來回報使用者。列出：卡在哪、試過什麼、你的判斷 |

**審查發現與 plan 文字衝突時**：你裁決，記進帳本，然後帶著這個裁決重新派工。
不要讓 implementer 自己去猜該聽誰的。

---

## 裁決，不要停等

計畫跑起來之後**不等人**。衝突、模糊、plan 的缺陷、一個你本來想問「可不可以超過」的
上限——**你自己決定**。規格是最終權威，plan 是它的論證，兩者都沒答案的地方由你的判斷收尾。
每個決定照上面的格式記進帳本，然後繼續。

理由很簡單：**錯誤的裁決造成的是使用者看得見、也能撤銷的重工；停在一個問題上等回答，
花掉的是使用者一整天，而且什麼都沒買到。**

不要在階段之間問「要繼續嗎？」，也不要每階段給進度摘要。使用者叫你執行計畫就是要你執行完。

### 只有這四件事會讓你停下來

1. **不可逆或破壞性操作**（刪資料、改 production、`git push --force`、drop table）
2. **安全敏感行為**（動認證/金流邏輯、寫入秘密、開放對外端點）
3. **副作用超出本任務的檔案範圍**（plan 的 `files:` 之外）
4. **所有階段完成**

其他一切：裁決、記帳、繼續。

---

## 與既有機制的交互

| 機制 | 執行型委派要注意什麼 |
|---|---|
| **坑閘門**（`pre-tool-use.sh`） | implementer 會被擋一次並看到坑。這是預期行為，不要教它繞過。派工前你自己也先讀 `context/learned/` 相關紀錄，寫進 prompt |
| **任務模式閘門** | 派工前確認 `.current-task-mode` 已存在，否則 implementer 第一次寫檔就被擋，浪費一個回合 |
| **覆蓋率門檻** | 由 `testing-standards` skill 決定（standard 80%／critical 100%）。寫進 implementer 的驗收條件 |
| **plan 階段狀態** | 只有**你**改 plan 檔（`/tdd` 的權限）。不要讓 implementer 去改 plan——它會跟你搶 |
| **`files:` frontmatter** | 就是 implementer 的檔案授權範圍。它想動範圍外的檔案 → 那是 `BLOCKED`，由你裁決要不要擴大範圍並更新 plan |
| **handoff** | 階段審查產生的 handoff 照原機制走，`post-agent-report.sh` 會注入 |
| **報告稽核** | 審查用的專業 agent 要寫報告到 `context/<area>/`。非同步啟動的會被延後稽核並要求補寫 |

---

## 反模式

- ❌ 叫 subagent「接續我們剛才的討論」——它沒有你的 context，這句話等於沒給資訊
- ❌ 一個 subagent 跑完整個 plan——那只是把偏離 plan 的風險換個地方發生
- ❌ 用 `git diff HEAD~1` 當階段 diff——多 commit 的階段會漏掉前面全部
- ❌ 不指定 `model`，讓每個機械任務都繼承 opus
- ❌ 審查發現交給同一個模型無限重試（第 4 輪就該升級）
- ❌ 每階段之間停下來問使用者「要繼續嗎」
- ❌ 帳本只記「階段 1 完成」——沒記 commit 與 BASE 的帳本無法復原
- ❌ 讓 implementer 改 plan 檔或 WBS

## 相關

- `implementer-prompt.md` — 派工 prompt 骨架
- `reviewer-prompt.md` — 階段審查 prompt 骨架
- `plan-format` skill — plan 檔格式、`files:` 欄、狀態同步權限
- `testing-standards` skill — 覆蓋率門檻
- `.claude/rules/task-mode.md` — quick / standard / critical
- `.claude/context/learned/` — 派工前必讀的坑
