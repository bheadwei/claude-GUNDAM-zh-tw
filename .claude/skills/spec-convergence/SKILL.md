---
name: spec-convergence
description: Use when checking whether the codebase and WBS still match the original spec — after a milestone completes, before a PR, or when the user asks "還符合當初的需求嗎 / 規格有沒有跑掉 / CR 加了這麼多還對嗎". Compares docs/00_brief.md and the PRD against wbs.md, wbs-archive.md and completed plans, then reports gaps as proposed WBS rows. Never rewrites the PRD itself.
---

# 規格收斂（Spec Convergence）

`/verify` 驗的是「這個任務做完了嗎」——建置、型別、lint、測試、plan 的驗收標準。
它**不會**回頭問「整體還符合當初講好的東西嗎」。

這個落差在**客戶持續提 CR** 的情境下最會出事：每個 plan 都完成、每個 `/verify` 都綠，
但半年後的 codebase 已經和 PRD 是兩件事，而沒有任何一刻有人察覺。

**核心原則：報告落差，不自動改規格。** 方向判斷是人的事——
客戶 CR 常常是「PRD 該更新」而不是「程式該改」。

---

## 何時跑

| 時機 | 觸發者 | 深度 |
|---|---|---|
| **里程碑全部完成** | `/verify` 標完最後一個任務時提議 | 完整（A+B+C） |
| **開 PR 前** | `/verify pre-pr` | A+B（跳過 C，太慢） |
| 使用者問「還符合需求嗎」 | 自然語言喚起本 skill | 依使用者要的範圍 |
| 累積 ≥5 個 CR 之後 | `/task-add` 提醒 | A+B |

**不要每個任務都跑。** 單一任務很少會讓整份規格跑掉，每次都跑只會變成被忽略的噪音。

---

## 輸入

按優先序讀：

1. **`docs/00_brief.md`** —— `/task-init` 步驟 2.7 產出、**使用者逐段確認過**的需求 brief。
   最可靠的基準，而且它有 `non-goals` 與「仍未釐清」兩段是別處沒有的
2. **PRD** —— `docs/prd.md`（demo）／`docs/tech-spec.md`（mvp）／`docs/01_prd.md`（full）
3. **`wbs.md` ＋ `wbs-archive.md`** —— 打算做什麼、做完了什麼（歸檔的也要讀，否則會誤判成漏做）
4. **`plans/archive/*.md`** —— 實際怎麼做的（含 `files:`，指出動過哪些檔案）
5. 程式碼本身 —— 只在檢查 C 用

**brief 不存在時**（舊專案或沒跑 `/task-init`）：以 PRD 為唯一基準，並在報告開頭標明
「無 brief，non-goals 與未釐清項無法比對」——不要假裝有。

---

## 三個檢查

### A. 漏做 —— 規格有寫，WBS 沒有

逐一取 brief／PRD 的功能點，找 `wbs.md` 與 `wbs-archive.md` 有沒有對應任務。

沒有對應的，**分三類，不要混在一起報**：

| 類別 | 判斷依據 | 建議動作 |
|---|---|---|
| 真的漏了 | 規格有寫、WBS 沒有、也不在 non-goals | 提議加 WBS 行 |
| 當初決定不做 | 出現在 brief 的 non-goals | 無需動作（但若 PRD 還寫著它，提議修 PRD） |
| 規格本身模糊 | 出現在 brief 的「仍未釐清」 | 提議先釐清再決定 |

### B. 範圍蔓延 —— WBS 做了，規格沒提

**這一項是 CR 情境的主戰場。** 逐一取已完成任務（含歸檔），找 brief／PRD 有沒有提到。

沒有的，通常是 **CR 進來了但沒回寫 PRD**。這不是錯誤——CR 本來就會發生——
錯的是 PRD 沒跟上，導致：

- 新人讀 PRD 不知道系統實際做了什麼
- 下次收斂檢查又會把它報成蔓延（永久噪音）
- 驗收時沒有依據

**特別要標出來的兩種**：

- **做了 non-goals 裡的事** —— brief 明說不做卻做了。可能是 CR 覆蓋了原決定
  （那要更新 non-goals），也可能是範圍失控（那要停下來談）
- **改動集中在 PRD 沒描述的模組** —— 讀已歸檔 plan 的 `files:`，
  若某個目錄被大量改動但 PRD 完全沒提到它，那是結構性的落差

### C. 描述失真 —— 規格寫的與現況不同

最貴的一項，**只在里程碑收斂或使用者明確要求時做**。

委派 `documentation-specialist`（`subagent_type: "documentation-specialist"`）——
「文件與程式碼是否相符」正是它的職責，不要自己一個一個檔案讀。

抽樣比對 PRD 裡**具體可驗證**的敘述：

- 提到的 API 端點／路由 → 實際存在嗎？路徑與方法一致嗎？
- 提到的資料模型／欄位 → schema 或 migration 對得上嗎？
- 提到的頁面／流程 → 路由存在嗎？
- 提到的外部整合 → 程式碼裡真的接了嗎，還是還在 mock？

**不要**比對散文式的描述（「提供良好的使用者體驗」）——那無法驗證，比了只會產生假警報。

---

## 輸出

寫報告到 `.claude/context/docs/spec-convergence-{YYYY-MM-DD-HHMM}.md`，
格式遵循 `.claude/context/_REPORT_TEMPLATE.md`，內容：

```markdown
# 規格收斂檢查 — {日期}

基準：docs/00_brief.md（已確認）＋ docs/01_prd.md
範圍：里程碑 M2 完成後 ／ 檢查 A+B+C
{無 brief 時在此標明缺口}

## 摘要
漏做 N ・ 範圍蔓延 N ・ 描述失真 N ・ 已否決但做了 N

## A. 漏做
| 規格中的功能 | 出處 | 狀態判斷 | 建議 |
|---|---|---|---|

## B. 範圍蔓延
| 已完成任務 | 規格有提嗎 | 判斷 | 建議 |
|---|---|---|---|

## C. 描述失真
| PRD 敘述 | 實際 | 差異 |
|---|---|---|

## 不需要動作的
{列出來，讓人知道你檢查過而不是漏了}
```

然後用 `AskUserQuestion` 問**一題**（依實際落差裁剪選項，沒有落差就不問）：

```
收斂檢查找到 3 項落差。怎麼處理？
  [Recommended] 把「漏做」加進 WBS，「蔓延」的提議回寫 PRD
      漏做 → /task-add 追加任務；蔓延 → 列出該補進 PRD 的段落草稿供你確認
  只加 WBS，PRD 我自己更新
  先看完整報告再決定
```

**永遠不要自動改 PRD。** 產出草稿供確認可以，直接寫入不行——
「這個 CR 該進 PRD」還是「這個 CR 當初就不該做」是人的判斷。

---

## 反模式

- ❌ 每個任務都跑收斂（噪音，且單一任務很少讓整份規格跑掉）
- ❌ 自動改寫 PRD
- ❌ 比對散文式描述（「效能良好」）→ 假警報
- ❌ 沒讀 `wbs-archive.md` → 把已完成歸檔的任務誤報成「漏做」
- ❌ 沒有 brief 時假裝比對過 non-goals
- ❌ 檢查 C 自己一個一個檔案讀（委派 `documentation-specialist`）
- ❌ 把「範圍蔓延」當成錯誤來報 —— CR 本來就會發生，錯的是 PRD 沒跟上

## 相關

- `.claude/commands/verify.md` — 里程碑完成與 `pre-pr` 的觸發點
- `.claude/commands/task-add.md` — CR 追加入口
- `project-docs` skill — PRD／Tech Spec 的範本與章節結構
- `plan-format` skill — 已歸檔 plan 的 `files:` 欄
