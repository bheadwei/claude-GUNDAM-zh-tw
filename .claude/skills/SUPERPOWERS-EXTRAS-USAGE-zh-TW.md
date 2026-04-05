# Superpowers 進階：平行代理／Git Worktree／撰寫 Skill（繁體中文）

以下三個 skill 來自 [obra/superpowers](https://github.com/obra/superpowers)，與精簡版日常工作流 **可並存**；需要時在任務描述中點名情境即可觸發（並請助理依各目錄 **`SKILL.md`** 執行）。完整規則以英文 **`SKILL.md`** 為準。

---

## 1. `sp-dispatching-parallel-agents`（平行代理）

### 用途

把 **彼此獨立** 的工作交給多個子代理並行處理，避免同一個對話上下文塞滿、也避免無關問題排隊調查。

### 何時用

- 多個 **不同根因** 的失敗（例如多個測試檔、不同子系統各自壞）。
- 每個問題 **不需** 讀另一個問題的完整上下文就能修。
- **沒有** 共用可寫狀態／不會互相踩檔案（否則改為循序或單一代理）。

### 何時不要用

- 失敗彼此相關（修一個可能連帶修好其他的）。
- 需要先掌握 **全系統** 狀態才能判斷。
- 多代理會同時改同一區塊或依賴同一資源。

### 怎麼用（實務）

1. **先分域**：依測試檔、子系統或 bug 類型分組，一組一個代理。
2. **給獨立提示**：每個代理只拿 **該範圍** 的說明、檔案路徑、成功條件；不要複製整段對話紀錄。
3. **在 Cursor／Claude Code**：對應 **`Task`**（或你環境裡的「子代理／parallel task」）並行送出多個任務（見官方 skill 中的 `Task(...)` 範例）。
4. **回來整合**：各代理回報後，由你或主對話 **合併變更、跑全套測試**，確認沒有衝突。

目錄：`.claude/skills/sp-dispatching-parallel-agents/SKILL.md`

---

## 2. `sp-using-git-worktrees`（Git Worktree）

### 用途

在同一個 repo 上 **同時** 開多條分支工作（例如一邊修 hotfix、一邊開功能），**不必** 反覆 `git checkout` 切換目錄；每個 worktree 是獨立工作目錄、共用同一個 object store。

### 何時用

- 新功能／實作計畫需要與 **目前工作目錄隔離**。
- 要在 **不動目前分支** 的情況下開新分支試作。
- 執行 `sp-executing-plans` 這類「長計畫」前，想先落在獨立目錄。

### 目錄放哪（優先順序）

Skill 內建順序（簡化）：

1. 若已有 **`.worktrees`** 或 **`worktrees`** 目錄 → 優先用（`.worktrees` 優先）。
2. 若 **`CLAUDE.md`** 寫了 worktree 目錄偏好 → 照文件。
3. 都沒有 → 問使用者要用 **專案內**（例如 `.worktrees/`）還是 **全域**（例如 `~/.config/superpowers/worktrees/<專案名>/`）。

### 安全檢查（專案內目錄必做）

在專案內建立 worktree 前，必須確認該目錄 **已被 gitignore**，避免把 worktree 內容誤提交：

```bash
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

若 **沒** 被 ignore → 應先補 **`.gitignore`** 並提交，再建立 worktree。

### 建立範例（概念）

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
git worktree add .worktrees/feat-foo -b feat/foo
cd .worktrees/feat-foo
```

實際路徑與分支命名以 **`SKILL.md`** 的步驟為準。

目錄：`.claude/skills/sp-using-git-worktrees/SKILL.md`

---

## 3. `sp-writing-skills`（撰寫 Skill）

### 用途

**新增／修改／驗證** 給 AI 用的 **Skill 文件**（主要是 `SKILL.md`）。官方把這套方法比喻成 **對「流程文件」做 TDD**：先設計壓力情境（子代理是否遵守），再寫文件、再驗證。

### 何時用

- 你要在 repo 或個人目錄裡 **建立新 skill**、或 **大修既有 skill**。
- 要確認 skill **上線前** 代理真的會照做（而非只寫漂亮文字）。

### 核心觀念（極短）

| 概念 | 對應 |
|------|------|
| 測試 | 用子代理跑 **壓力情境**（沒有 skill 時應失敗／違規） |
| 程式 | **`SKILL.md`**（與必要時的附檔） |
| 綠燈 | 載入 skill 後代理 **遵守** 規則 |

### 本專案 skill 放哪

- 專案內：**`.claude/skills/<skill-name>/SKILL.md`**（與本 repo 現有結構一致）。
- 個人全域：Claude Code 常見為 `~/.claude/skills`（以你安裝說明為準）。

### 何時「不要」單獨做一個 skill

- 一次性解法、只適用單一專案慣例 → 較適合寫進 **`CLAUDE.md`** / **`AGENTS.md`**。
- 已有官方文件、機械可檢查的規則 → 優先 **自動化／lint**，不必再堆長文。

### 與 `tdd-workflow` 的關係

官方 skill 說明建議先熟悉 **TDD 循環**；本 repo 的 **`tdd-workflow`** 可與「寫 skill 時的 RED-GREEN-REFACTOR」心智模型對齊。若只寫程式、不寫 skill，用 **`tdd-workflow`** 即可。

目錄：`.claude/skills/sp-writing-skills/SKILL.md`（內含 frontmatter 規範、`SKILL.md` 結構、檔案拆分建議等）

---

## 快速對照

| 前綴目錄 | 一句話 |
|----------|--------|
| **sp-dispatching-parallel-agents** | 多個 **獨立** 問題 → 多代理 **並行**，最後再整合 |
| **sp-using-git-worktrees** | 多分支 **實體目錄隔離** → `git worktree`，並注意 **gitignore** |
| **sp-writing-skills** | 寫／改 **`SKILL.md`**，用 **情境驗證** 代理是否遵守 |
