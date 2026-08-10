---
name: plan-format
description: 實作計畫（plan）的檔案格式、命名、儲存位置、與 WBS 的職責分工、狀態同步規則，以及 files: frontmatter（平行開發衝突判斷的依據）。Use when running /plan, /tdd, /verify, or /task-next; when creating or updating any file under taskmaster-data/plans/; or when deciding whether a task needs a plan at all.
---

# 計畫持久化規則（Plan Persistence）

規範 `/plan` 產出的實作藍圖如何儲存、與 WBS 的職責分工、以及 `/tdd` 如何接續執行。

## 核心原則

**WBS 是 What，Plan 是 How。** 兩者職責不重疊。

| 欄位 | 唯一來源 | 說明 |
|---|---|---|
| 任務狀態（⏳/🔄/✅） | **WBS** | `/task-next` 更新進行中，`/verify` 或使用者確認後標完成 |
| 優先級、依賴任務、總預估 | **WBS** | 專案 backlog 視角 |
| 階段拆解、風險、驗收標準、實作細節 | **Plan 檔** | 單任務實作藍圖 |
| 單階段狀態（⏳/🔄/✅） | **Plan 檔** | `/tdd` 每完成一階段更新 |

Plan 檔**不重複** WBS 已有欄位。

---

## 檔案位置與命名

```
.claude/taskmaster-data/
├── wbs.md
├── project.json
└── plans/
    ├── INDEX.md
    ├── 2.1-auth-middleware.md          ← 對應 WBS 任務 2.1
    ├── 3.2-oauth-flow.md
    └── adhoc-2026-04-20-fix-login.md   ← 無 WBS 對應的臨時計畫
```

- **有 WBS 對應**：`<task-id>-<kebab-slug>.md`（slug 取自任務標題，英數小寫 + 連字號，20 字元內）
- **無 WBS 對應（ad-hoc）**：`adhoc-YYYY-MM-DD-<kebab-slug>.md`

### INDEX.md

`plans/INDEX.md` 列出所有計畫檔，供快速瀏覽：

```markdown
# Plans Index

| ID | 標題 | WBS 任務 | 狀態 | 最後更新 |
|---|---|---|---|---|
| 2.1 | Auth Middleware | 2.1 | 🔄 階段 2/4 | 2026-04-20 |
| 3.2 | OAuth Flow | 3.2 | ⏳ 未開始 | 2026-04-20 |
| adhoc-2026-04-20 | Fix Login Bug | - | ✅ 完成 | 2026-04-20 |
```

`/plan` 建立計畫時自動更新 INDEX.md，`/tdd` 更新階段狀態時同步。

---

## 計畫檔格式

```markdown
---
wbs_task: "2.1"              # WBS 任務編號，ad-hoc 填 "none"
slug: "auth-middleware"
created: "2026-04-20"
updated: "2026-04-20"
status: "🔄 進行中"           # ⏳ 未開始 / 🔄 進行中 / ✅ 完成
current_phase: 2              # 目前在第幾階段
files:                       # 本任務會「新增/修改」的檔案範圍
  - "src/lib/auth/middleware.ts"
  - "src/types/auth.ts"
  - "tests/auth/**"
---

# 實作計畫：Auth Middleware

## 目標

2-3 句摘要，描述完成後使用者看到什麼變化。

## WBS 連結

- 任務：2.1 建立 auth middleware
- WBS 依賴：1.3（DB schema）✅ 已完成
- 總預估：4h（WBS）

## 技術依賴

Plan 獨有的技術層面依賴，非 WBS 的任務依賴：

- 使用 `jose` 套件處理 JWT
- 需要 Redis（存 token blacklist）
- 參考現有 `src/lib/auth/session.ts` 的模式

## 階段拆解

### 階段 1: 介面與型別 ⏳

- [ ] 定義 `AuthMiddleware` interface（`src/types/auth.ts`）
- [ ] 定義 `TokenPayload` schema（Zod）
- [ ] 撰寫介面層測試（空實作即可）
- **預估**：30min
- **驗收**：`tsc --noEmit` 通過，測試 RED

### 階段 2: JWT 驗證核心 🔄

- [ ] 實作 `verifyToken()`（`src/lib/auth/middleware.ts`）
- [ ] 處理過期、簽章錯誤、格式錯誤
- [ ] 整合測試（mock Redis）
- **預估**：1.5h
- **驗收**：所有測試 GREEN，覆蓋率達當前任務模式門檻

### 階段 3-4: 整合 / 打磨

（同上結構：步驟 checklist + 預估 + 驗收）

## 風險與緩解

| 風險 | 影響 | 緩解 |
|---|---|---|
| Redis 連線失敗導致所有請求失敗 | HIGH | circuit breaker + graceful degradation |
| Token refresh 競態 | MEDIUM | 原子操作 + 短 TTL |

## 驗收標準（整體）

- [ ] 所有階段狀態為 ✅
- [ ] 測試覆蓋率達門檻（見 `testing-standards` skill）
- [ ] `/code-review` 無 CRITICAL/HIGH 問題
- [ ] 已更新 WBS 任務為 ✅
```

### `files:` 欄位（平行開發的依據）

列出本任務會新增/修改的檔案或 glob。`/task-next` 用它來判斷哪些「依賴已滿足」的任務
**彼此檔案範圍不重疊**，進而提供「平行開發」選項。

- 寫**會被寫入/編輯**的檔案即可（讀取的共用檔不必列）
- 不確定範圍時**寧可多列**（多列只會讓系統更保守、少誤判可平行）
- **沒有 plan 檔或沒寫 `files:` 的任務 → 一律視為「範圍未知，不可自動平行」**

---

## 狀態同步規則

### 誰可以寫入計畫檔？

| 指令 | 權限 | 時機 |
|---|---|---|
| `/plan` | 建立、覆寫整份 | 初次規劃或使用者要求重寫 |
| `/tdd` | 只改階段狀態、current_phase、updated | 每完成一階段 |
| `/verify` | 只標記整體 status=✅ 並歸檔 | 所有階段完成且驗證通過 |
| 使用者手動 | 任何時候 | 但會被 `/tdd` 下次讀取時覆寫階段狀態 |

### 與 WBS 的雙向同步

- **Plan 建立時** → WBS 對應任務的「備註」欄加上 `[計畫](plans/2.1-xxx.md)` 連結
- **Plan 所有階段完成時** → 提示執行 `/verify`，通過後 WBS 對應任務標 ✅
- **WBS 任務被跳過/刪除時** → Plan 檔保留但標記 `status: "⚠️ WBS 已移除"`

### Ad-hoc 計畫

- 建立時不寫入 WBS
- **完成驗收後 `/verify` 會主動問要不要補登 WBS**（不是靠使用者自己記得）
- 歸檔到 `plans/archive/` 後保留，供日後查閱

> 不補登會讓 WBS 逐漸偏離實際做過的事，`/task-status` 與 `/time-log` 的統計失真。

---

## 「Plan 好像跟 WBS 很像？」

會有這個感覺，通常是因為**新增功能時跳過了 WBS**：直接開 plan，那一行從沒被建立，
於是 plan 成了唯一紀錄、被迫兼差當 backlog。

正確做法是先補那一行：

```
想加功能  →  /task-add   （追加 WBS 行：自動拆解、接編號、算依賴）
          →  /plan <id>  （只在達門檻時才產：跨 ≥2 檔 / ≥1h / critical）
```

`/task-next` 在 WBS 待辦清空時、`/verify` 在 ad-hoc plan 完成時，都會主動提起 `/task-add`。

---

## 何時不該用 `/plan`

- 單檔案、< 30 分鐘的修改 — 直接做，不需要計畫
- 已在 WBS 且極簡單的任務（例：更新一個常數）
- 探索性實驗、還不確定方向 — 先用 `AskUserQuestion` 討論

**`/plan` 門檻**：跨 ≥ 2 檔案、預估 ≥ 1h、或有非 trivial 風險。
`critical` 模式一律需要 plan（見 `rules/task-mode.md`）。
