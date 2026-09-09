---
wbs_task: "none"
slug: "grader-agent-drift"
created: "2026-09-09"
updated: "2026-09-09"
status: "⏳ 未開始"
current_phase: 1
files:
  - ".claude/tests/skill-compliance/run-compliance.sh"
  - ".claude/tests/skill-compliance/README.md"
  - ".claude/tests/skill-compliance/prompts/09-schema-change.txt"
  - "scripts/check-counts.sh"
---

# 實作計畫：壓力測試 harness 的三個缺口

## 目標

`run-compliance.sh` 的 code grader 硬編碼 14 個 agent 名稱，`.claude/agents/` 現在有 16 個。
`skill-curator` 與 `conflict-resolver` 被正確點名時 grader 會印「（無）」——**判讀會被誤導成
「模型沒委派」**。改成從 `.claude/agents/` 動態取名單，並讓 `check-counts.sh` 擋住下次漂移。

## 背景（為什麼要做）

v5.6 新增兩個 agent（`skill-curator`、`conflict-resolver`）時，`run-compliance.sh:113`
那條 `grep -oE 'planner|architect|...'` 沒跟著同步。這是同一類問題的第三次：
硬編碼的清單與實際檔案漂開，而且**沒有東西會抓到**。

`check-counts.sh` 已經有 313 項檢查、專門處理這類漂移，但沒涵蓋這條。

順帶補一份 prompt：現有 8 份沒有測到 `database-migrations` 這個 MUST BE USED 的 skill，
而它是最容易在「使用者沒說 migration 這個詞」時漏掉的一個。

## 技術依賴 / 既有資產

- `scripts/check-counts.sh` 既有的「接線路徑存在」「孤兒 skill」「`tools:` 含 Skill」
  三組檢查 —— 照同一風格加，錯誤訊息要指名檔案並給修法
- `.claude/tests/skill-compliance/README.md` 的「每份 prompt 在測什麼」表格
- 反過擬合原則：**新 prompt 絕對不能含 skill 名稱或關鍵字**（README 明列的反模式）

## 階段拆解

### 階段 1: grader 名單改動態 ⏳

- [ ] `run-compliance.sh` 的 agent 名單從 `ls .claude/agents/*.md` 的 basename 產生，
      用 `|` 串成 alternation（`claude.md` 這類非本模板的 agent 也一併納入無妨）
- [ ] 名單為空時 fallback 成不匹配（不能變成 `grep -oE ''` 匹配所有行）
- **預估**：30min
- **驗收**：`bash run-compliance.sh -h` 正常；用一份含 `conflict-resolver` 字樣的假 `.out`
  驗證 grader 抓得到（可暫時 stub 掉 `claude` 呼叫，**不要真的跑對話**）

### 階段 2: `check-counts.sh` 擋下次漂移 ⏳

- [ ] 新增檢查：`.claude/agents/` 的每個 agent 名稱，都要能被 grader 的名單來源涵蓋
      （動態化之後這條退化成「grader 沒有殘留硬編碼名單」的靜態檢查）
- [ ] 錯誤訊息指名 `run-compliance.sh` 與修法
- **預估**：25min
- **驗收**：**負向測試** —— 故意把硬編碼名單塞回去，確認 `check-counts.sh` 會抓到並非零退出

### 階段 3: 補第 9 份 prompt ⏳

- [ ] `prompts/09-schema-change.txt`：用自然語氣描述要對一張大表加欄位，
      **不得出現** migration／schema 遷移／`database-migrations` 等關鍵字
- [ ] README 的表格補第 9 列（期望行為、測的是什麼），並標明它是正向題
- **預估**：25min
- **驗收**：README 表格列數與 `prompts/` 檔數一致

### 階段 4: `run-compliance.sh` 要防護工作區 ⏳

**2026-09-09 第一輪實跑抓到的**：測試會讓受測 session **真的改檔案**。那一輪動了
`README.md` 與 5 份 workshop 文件。腳本對此完全沒有防護，README 也沒警告。
工作區本來就髒的話，跑完根本分不出哪些是測試改的。

- [ ] 跑之前檢查 `git status --porcelain`，非空就印警告並要求確認
      （**不要硬性 exit** —— 逃生門用環境變數或 `--allow-dirty` 旗標）
- [ ] 跑完後把 `git status --porcelain` 的結果寫進 `_判讀.md`，
      並在終端印一句「以下檔案被受測 session 改動，逐一決定留或還原」
- **預估**：30min
- **驗收**：髒工作區時會警告、乾淨時不囉嗦；跑完的清單與 `git status` 一致

### 階段 5: README 記錄兩個 harness 限制 ⏳

第一輪實跑才看得到的，不記下來下次會重新發現：

- [ ] **受測者讀得到考卷**：prompt 04／05 都主動指出「你這句話一字不差地存在
      `prompts/0X-*.txt`」，05 還說它刻意不去讀 README 的評分標準「免得照答案演」。
      這次它誠實，但題庫、期望行為表、歷史結果全在受測 session 的讀取範圍內，
      下次照答案演我們分不出來。**寫進 README 的「評分反模式」那節**，
      並註明目前無解、要真正隔離得把題庫移出受測目錄
- [ ] **`-p` 非互動模式拿不到權限提示** → 受測 session 寫不了 `.claude/**`、
      也跑不了 Bash 腳本。第一輪有 5 筆改動被擋、`check-counts.sh` 跑不起來。
      凡是期望行為涉及這兩類動作的題目，在 `-p` 下都測不完整
- [ ] **正向題在模板 repo 內測不到東西**：8 份有 5 份的目標物（`src/`、API、schema）
      在模板 repo 不存在，受測 session 只能正確地回「給我專案路徑」。
      這批 prompt 必須在有應用程式碼的專案裡跑，README 要明講
- **預估**：30min
- **驗收**：三條都在 README 有對應段落，且寫的是「怎麼辦」不只是「有這個問題」

## 風險與緩解

| 風險 | 影響 | 緩解 |
|---|---|---|
| 動態名單在 `agents/` 為空時變成匹配全部 | MEDIUM | 空名單時明確 fallback 成不可能匹配的樣式 |
| 新 prompt 含關鍵字 → 自己餵答案 | HIGH | 寫完 grep 一遍確認無 skill 名稱 |
| 階段 1 驗收時真的跑起對話 → 燒 token | MEDIUM | 用假 `.out` 驗 grader，不呼叫 `claude` |

## 驗收標準（整體）

- [ ] 五階段全 ✅
- [ ] `bash scripts/check-counts.sh` 全綠，且階段 2 的檢查做過負向測試
- [ ] 新 prompt 不含任何 skill 名稱或觸發關鍵字
- [ ] 不動 `files:` 以外的任何檔案

## 邊界（本任務不做）

- **不要執行** `run-compliance.sh` 的真實對話。第一輪已於 2026-09-09 13:03 跑完，
  結果在 `results/20260909-130333/`（含 `_判讀.md`）。再跑一輪要主模型決定，不是你的範圍
- 不動 `.claude/hooks/`（另一個平行任務在改）
- 不改 `using-taskmaster` 的 Red Flags 表（那要有真實判讀結果才動）
