# Superpowers（`sp-*`）全系列繁體中文說明

本文件說明 `.claude/skills` 底下所有 **`sp-*`** skill 的用途、何時用、怎麼用（摘要）。來源為 [obra/superpowers](https://github.com/obra/superpowers)；**細節與步驟以各目錄內英文 `SKILL.md` 為準**。

**建議閱讀順序**：若第一次使用 Superpowers，先看 **`sp-using-superpowers`** → 依任務選 **`sp-brainstorming`** / **`sp-writing-plans`** → 實作與收尾見 **`sp-executing-plans`**、**`sp-verification-before-completion`**、**`sp-finishing-a-development-branch`**。

---

## 目錄（依工作流程）

| 目錄 | 一句話 |
|------|--------|
| [sp-using-superpowers](#sp-using-superpowers) | 開場規則：何時、如何載入 skill |
| [sp-brainstorming](#sp-brainstorming) | 寫程式前先釐清意圖與設計 |
| [sp-writing-plans](#sp-writing-plans) | 有規格後先寫多步驟實作計畫 |
| [sp-executing-plans](#sp-executing-plans) | 依計畫實作（含檢查點） |
| [sp-verification-before-completion](#sp-verification-before-completion) | 宣稱完成／送 PR 前先跑證據 |
| [sp-systematic-debugging](#sp-systematic-debugging) | 先除錯再亂改 |
| [sp-requesting-code-review](#sp-requesting-code-review) | 發起結構化 code review |
| [sp-receiving-code-review](#sp-receiving-code-review) | 消化 review 意見（先求證再改） |
| [sp-finishing-a-development-branch](#sp-finishing-a-development-branch) | 測試都過後：合併／PR／收尾選項 |
| [sp-dispatching-parallel-agents](#sp-dispatching-parallel-agents) | 多個獨立問題 → 平行子代理 |
| [sp-using-git-worktrees](#sp-using-git-worktrees) | 多分支用 worktree 隔離目錄 |
| [sp-writing-skills](#sp-writing-skills) | 撰寫／驗證 `SKILL.md` |

---

## `sp-using-superpowers`

### 用途

定義 **一進對話就要遵守** 的習慣：若任務可能適用某個 skill，**先透過 Skill 工具載入**（含澄清問題之前）；並說明與 `CLAUDE.md` / 使用者指示的優先順序。

### 何時用

幾乎每次開新對話、或子代理**未被**指派為「只執行單一任務」時（見該檔 `<SUBAGENT-STOP>`）。

### 怎麼用（摘要）

- 由助理在適用時 **invoke skill**，不要只靠預設系統提示。
- 使用者明確指示優先於 skill。

---

## `sp-brainstorming`

### 用途

在 **寫程式、加功能、改行為** 之前，用對話把 **意圖、需求、設計** 談清楚，減少做錯方向。

### 何時用

新增功能、建元件、改產品行為、任何「創作型」實作前。

### 怎麼用（摘要）

- 先探索「要做什麼、為誰、成功長什麼樣」，再進入實作或 `sp-writing-plans`。

---

## `sp-writing-plans`

### 用途

在 **動程式碼** 之前，把多步驟任務寫成 **可執行的實作計畫**（通常基於已有一份規格或共識）。

### 何時用

已有 spec／需求，且任務跨多檔、多步驟時。

### 怎麼用（摘要）

- 產出計畫後，另開情境或依檢查點執行 **`sp-executing-plans`**。

---

## `sp-executing-plans`

### 用途

手邊已有 **書面實作計畫** 時，在 **獨立工作節奏** 裡逐步做，並保留 **review 檢查點**（不要一股腦寫到底）。

### 何時用

計畫已寫好，準備開始實作或接續上一段實作時。

### 怎麼用（摘要）

- 需要與目前工作目錄隔離時，可搭配 **`sp-using-git-worktrees`**。

---

## `sp-verification-before-completion`

### 用途

在 **宣稱完成、修好、測試通過**，或 **commit／開 PR** 之前，必須先 **實際執行** 驗證指令並 **根據輸出** 說話（證據優於口頭）。

### 何時用

任務快結束、要下結論或要發 PR 前。

### 怎麼用（摘要）

- 禁止未跑指令就宣稱綠燈；與本 repo **`tdd-workflow`** 的「先驗證再交差」一致。

---

## `sp-systematic-debugging`

### 用途

遇到 bug、測試失敗、非預期行為時，**先系統化定位根因**，再提修正；避免直接猜測式改碼。

### 何時用

任何故障、紅燈、異常，在提出「修好了」之前。

### 怎麼用（摘要）

- 依 skill 內的階段（重現 → 假設 → 縮小範圍 → 驗證）；可與 **`sp-verification-before-completion`** 搭配。

---

## `sp-requesting-code-review`

### 用途

完成一大塊實作或重要功能時，**派生子代理／專用 reviewer**，在合併前做結構化審查；給 reviewer **精簡、與任務相關** 的上下文，而非整段聊天紀錄。

### 何時用

任務完成、重大功能、merge 前想降低漏網之魚時。

### 怎麼用（摘要）

- 見該 skill 內對 `code-reviewer` 的提示與範本（同目錄可能有 `code-reviewer.md`）。

---

## `sp-receiving-code-review`

### 用途

收到他人（或 reviewer）的 review 意見時：**先技術上求證**，再決定是否採納；避免為了「看起來配合」而盲改。

### 何時用

有 PR 評論、反饋看似模糊或與你的理解衝突時。

### 怎麼用（摘要）

- 對每条建議：是否成立、是否過度、是否有更好做法，再改碼。

---

## `sp-finishing-a-development-branch`

### 用途

實作完成且測試通過後，協助 **選擇收尾方式**：merge、開 PR、清理分支等結構化選項。

### 何時用

準備把分支上的工作接回主線或發 PR 時。

### 怎麼用（摘要）

- 依 skill 內選項與團隊流程決定下一步。

---

## `sp-dispatching-parallel-agents`

### 用途

把 **彼此獨立** 的工作交給多個子代理 **並行**，避免無關問題在同一對話裡排隊。

### 何時用

多個 **不同根因** 的失敗（多測試檔、多子系統）；每題不需另一題的完整上下文；**無** 共用可寫狀態或互踩檔案。

### 何時不要用

失敗彼此相關、需全系統情境、多代理會改同一區塊。

### 怎麼用（摘要）

1. 分域（依檔案／子系統）。  
2. 每個代理 **獨立提示**（範圍、路徑、完成定義）。  
3. 環境支援時並行 **`Task`**（見英文 `SKILL.md`）。  
4. 最後 **整合變更、跑全套測試**。

---

## `sp-using-git-worktrees`

### 用途

同一 repo **同時** 開多條分支：各分支一個工作目錄，**少切換 checkout**。

### 何時用

新功能要隔離、長計畫實作、或與目前目錄並行工作時。

### 目錄與安全（摘要）

- 優先使用既有 **`.worktrees`** 或 **`worktrees`**；或依 **`CLAUDE.md`**；否則問使用者。  
- 專案內目錄必須 **`git check-ignore`**，未 ignore 則先改 **`.gitignore`** 再建 worktree。  
- 建立方式見英文 `SKILL.md`（`git worktree add ...`）。

---

## `sp-writing-skills`

### 用途

**新增／修改／驗證** `SKILL.md`（與附檔）；以 **壓力情境 + 子代理** 驗證文件是否真能約束行為（類似對流程文件做 TDD）。

### 何時用

要寫新 skill、大修 skill、或上線前確認代理會遵守時。

### 何時不要用單獨一個 skill

一次性作法、只適用單一專案 → 寫 **`CLAUDE.md`**；可機械檢查的規則 → 優先 **lint／自動化**。

### 與 `tdd-workflow` 的關係

寫程式用 **`tdd-workflow`**；寫 skill 文件可對齊同樣 RED-GREEN-REFACTOR 心智（見英文 `SKILL.md`）。

---

## 與本 repo 其他 skill 的關係

| 本 repo skill | 與 `sp-*` |
|---------------|-----------|
| **tdd-workflow** | 與 **`sp-test-driven-development`**（未導入）重疊；寫程式以 **`tdd-workflow`** 為主。 |
| **security-review** / **owasp-web-security** | 與流程向 `sp-*` 正交；安全相關任務另載入。 |

---

## 快速對照（全表）

| 目錄 | 一句話 |
|------|--------|
| **sp-using-superpowers** | 先載入 skill、使用者優先 |
| **sp-brainstorming** | 寫碼前先談清楚需求與設計 |
| **sp-writing-plans** | 動手前先寫多步驟計畫 |
| **sp-executing-plans** | 依計畫實作 + 檢查點 |
| **sp-verification-before-completion** | 宣稱完成前先跑指令拿證據 |
| **sp-systematic-debugging** | 先除錯定位再修 |
| **sp-requesting-code-review** | 發起專注的 code review |
| **sp-receiving-code-review** | 理性消化 review |
| **sp-finishing-a-development-branch** | 分支收尾選項 |
| **sp-dispatching-parallel-agents** | 獨立問題多路並行 |
| **sp-using-git-worktrees** | worktree 隔離分支 |
| **sp-writing-skills** | 寫／驗證 skill 文件 |
