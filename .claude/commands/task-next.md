---
description: 從 WBS 取得下一個任務建議，分析優先級和依賴關係。
---

# 下個任務建議

## 功能

分析 WBS 任務清單，考慮依賴關係和優先級，建議最適合的下一個任務。

## 資料來源

**必須** 從 `.claude/taskmaster-data/wbs.md` 讀取 WBS 資料。

如果檔案不存在，提示使用者先執行 `/task-init` 初始化專案。

## 待辦清空時（不要只說「沒有任務了」）

若 WBS 中**沒有任何 `⏳ 待處理` 或 `🔄 進行中`** 的任務，先顯示完成摘要，
再用 `AskUserQuestion` 問（遵守 `interactive-qa.md`）：

```
🎉 WBS 所有任務已完成（共 N 個，累計 Xh）

接下來？
```

- **新增功能到 WBS**（Recommended）→ 走 `/task-add` 流程
- **查看完整進度** → `/task-status`
- **收尾這個專案** → 提示 `/verify pre-pr` 與 `/save-session`

> 這是「原本計劃做完了但還想加東西」的主要入口——不要讓使用者卡在空 backlog。

若有 `🚫 阻塞` 任務但無可執行任務，改為列出阻塞原因並詢問要不要解除阻塞。

## 分析內容

1. **依賴檢查** -- 前置任務是否完成
2. **優先級排序** -- 關鍵路徑、阻塞因素
3. **複雜度評估** -- 預估時間和難度
4. **Agent 建議** -- 建議搭配的專業 Agent

## 輸出格式

先顯示任務資訊（含 plan 狀態檢查）：

```
下個任務建議:

  任務: [任務名稱]
  描述: [簡述]
  優先級: [高/中/低]
  預估: [時間]
  依賴: [前置任務（已完成）]
  建議 Agent: [agent-name]
  計畫狀態: [依下方規則填入]
```

### 計畫狀態檢查規則

**必須**檢查 `.claude/taskmaster-data/plans/<id>-*.md` 是否存在：

- **找到計畫檔** → 讀取其 frontmatter，顯示：
  ```
  計畫狀態: 🔄 進行中（階段 2/4） — plans/2.1-auth-middleware.md
  建議下一步: /tdd  （自動接續階段 2）
  ```
- **無計畫檔** 且任務預估 ≥ 1h 或 跨 ≥ 2 檔案 → 顯示：
  ```
  計畫狀態: ⚪ 尚無計畫
  建議下一步: /plan [任務ID]  （建立實作藍圖）
  ```
- **無計畫檔** 但任務簡單（< 1h 且單檔案） → 顯示：
  ```
  計畫狀態: ⚪ 尚無計畫（任務簡單，可直接進入）
  建議下一步: /tdd  （ad-hoc TDD）
  ```

然後**必須使用 `AskUserQuestion`** 詢問使用者動作（遵守 `.claude/rules/interactive-qa.md`）：

- 「開始此任務」— 會依 plan 狀態導向對應下一步
- 「跳過，看下一個」
- 「查看詳細資訊」
- 「查看完整任務清單」
- **（僅當偵測到可平行任務時才出現）** 「🔀 平行開發這 N 個任務（worktree 隔離）」— 見下方「平行任務偵測」

### 平行任務偵測（可選，不強制）

> 目標：能平行的任務讓使用者**可以選擇**同時開發，但**預設不強制**——不選就是現在的單任務循序流程。

在顯示上面的動作選項**之前**，先算一次「可平行集合」：

1. **算 ready set**：WBS 中 `狀態 = ⏳ 待處理` 且**所有「依賴」任務皆為 ✅ 完成**的任務。
2. **取得每個 ready 任務的檔案範圍**：讀 `.claude/taskmaster-data/plans/<id>-*.md` 的 `files:` frontmatter。
   - **沒有 plan 檔，或 plan 沒寫 `files:` → 視為「範圍未知」，排除於平行候選**（保守，避免衝突）。
3. **判斷互不衝突**：兩任務的 `files:` glob **無交集** 即可平行。挑出一組彼此都不衝突的任務（≥ 2 個才有意義）。
4. **只有當「可平行集合 ≥ 2」時**，才在上面的 `AskUserQuestion` 加入「🔀 平行開發這 N 個任務」選項；並在選項說明列出是哪幾個任務（例：`2.2 / 2.3 / 3.1`）。

若候選任務缺 plan，**提示**使用者：「任務 2.3 尚無 plan/files，無法判斷是否可平行；可先 `/plan 2.3` 後再試」——但不阻擋單任務流程。

### 平行開發編排（使用者選了「平行開發」才執行）

採 **git worktree 隔離**，每個任務獨立分支、互不踩檔，完成後依序合併：

1. **前置檢查**：工作目錄需乾淨（`git status` 無未提交變更）；否則提示先提交/暫存。
2. **為每個並行任務建立 worktree**：
   ```bash
   git worktree add ".claude/worktrees/<task-id>" -b "task/<task-id>-<slug>"
   ```
3. **並行開發**：每個任務在自己的 worktree 內走既有鏈（`/tdd` → `/verify`）。可用 `Agent` 工具並 `isolation: "worktree"` 委派，或逐一進入各 worktree 開發。每個任務各自寫 `.current-task` / plan 階段狀態（互不干擾）。
4. **合併回主分支**（逐一、依序，降低衝突）：
   ```bash
   git -C "<主repo>" merge --no-ff "task/<task-id>-<slug>"
   ```
   - 合併前該任務需 `/verify` 通過。
   - 若仍出現合併衝突（代表 `files:` 估算有漏）→ 停下、人工解、並提醒補正該 plan 的 `files:`。
5. **清理**：
   ```bash
   git worktree remove ".claude/worktrees/<task-id>"
   ```
6. **更新 WBS**：每個完成的任務標 `✅ 完成`。

> 規範細節與反模式見 `.claude/rules/agent-orchestration.md`「安全平行（worktree 編排）」。

### 選擇任務模式（quick / standard / critical）

使用者選「開始此任務」後，**必須再用 `AskUserQuestion` 問一次任務模式**（規範見 `.claude/rules/task-mode.md`）：

依該規則的「自動分級啟發式」算出**預設值**並標 `(Recommended)`：

- `quick` — 直接寫，跳過 plan/TDD，僅 `/verify quick`（適合 < 30min 單檔修改）
- `standard` — 走 plan → tdd → verify 完整流程（適合 1-4h 新功能/重構）
- `critical` — standard + 100% 覆蓋 + review-code（金流/認證/安全）

使用者選定後，將模式字串寫入 `.claude/taskmaster-data/.current-task-mode`。

### 架構決策分流（條件式，非每次都問）

**只在任務描述觸及以下情況時多問一題**，其餘直接進入實作：

- 新子系統 / 新模組
- 技術選型（選框架、選資料庫、選第三方服務）
- 跨模組的架構調整
- 資料模型設計

命中時用 `AskUserQuestion` 問：

> 這個任務涉及技術選型／架構設計。要先讓 `architect` 出設計提案嗎？

- **要**（Recommended）— 委派 `architect`。它會把「為什麼選 A 不選 B」自動寫成 ADR 到
  `.claude/context/decisions/`，並建 handoff 交棒 `planner`。下次遇到同一個決策不用重新爭論
- **不用，直接開始** — 跳過，照選定的任務模式進入 plan / tdd

> **為什麼是條件式**：ADR 的價值在「決策當下記錄理由」，事後補寫的品質差很多。
> 但每次都問會變成噪音，所以只在真的有決策要做時才問。判斷標準見上方四項。

## 問答記錄

遵守 `.claude/rules/interactive-qa.md`：

- 流程結束後**一次性** `Write` 到 `.claude/qa-history/YYYY-MM-DD-HHMMSS-task-next.md`
- 記錄：建議任務、使用者選擇、時間戳
- 不要每題都寫（省 token）

## 使用方式

```
/task-next              # 取得建議
/task-next --detailed   # 含詳細分析
```

## 狀態同步

當使用者選擇開始任務時：
1. 讀取 `.claude/taskmaster-data/wbs.md`
2. 將選中的任務狀態更新為 `🔄 進行中`
3. 更新「最後更新」日期
4. 寫回檔案
5. **時間追蹤**：將任務編號寫入 `.claude/taskmaster-data/.current-task`（例如 `2.1`）
6. **任務模式**：將選定的模式（`quick`/`standard`/`critical`）寫入 `.claude/taskmaster-data/.current-task-mode`

當任務完成（透過 `/verify` 或使用者確認）時：
1. 將任務狀態更新為 `✅ 完成`
2. 寫回檔案
3. **時間追蹤**：清除 `.claude/taskmaster-data/.current-task`
4. **自動推薦下一個任務**：用 `AskUserQuestion` 詢問使用者：
   - 「繼續下一個任務」(Recommended) — 自動執行 `/task-next` 流程
   - 「查看目前進度」 — 顯示 WBS 狀態摘要
   - 「結束，稍後再繼續」 — 停止，不再推薦

## 搭配使用

```
/task-next        取得任務（自動更新 wbs.md + .current-task + 檢查 plan 狀態）
/plan <id>        規劃實作步驟（寫入 plans/<id>-<slug>.md，WBS 加連結）
/tdd              自動載入 plan 並按階段 TDD 推進，完成階段同步 plan 狀態
/verify           驗證覆蓋率與驗收 → 自動標 WBS 任務為 ✅
/task-next        取得下一個
```

**相關規範：** `plan-format` skill
