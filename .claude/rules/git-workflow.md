# Git 工作流

## Commit Message 格式

```
<type>(<optional scope>): <subject>

<WHY — 背景與動機>

<WHAT — 關鍵變更摘要>

<IMPACT — 影響範圍與破壞性變更>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

## Commit Message 品質標準（開源協作）

### Subject（第一行）
- 說明做了什麼，限 72 字元
- 用祈使句：「add」而非「added」或「adds」

### Body（必要，空一行後）

**WHY（為什麼）**— 第一段永遠回答動機：
- 解決什麼問題？現狀有什麼痛點？
- 什麼事件觸發了這次變更？
- 若不做會怎樣？

**WHAT（做了什麼）**— 第二段說明關鍵決策：
- 選了方案 A 而非 B 的原因
- 重要取捨（tradeoff）
- 不是 diff 的重複，是 diff 無法表達的上下文

**IMPACT（影響）**— 第三段列出波及範圍：
- 哪些模組/功能受影響
- 破壞性變更（breaking changes）須明確標記
- 後續需要的動作（如 migration）

### 鐵律
- 想像一個**從沒看過這個 repo 的人**讀你的 commit message
- 一個 commit 做一件事 — 大型變更拆成多個邏輯 commit
- 每個 commit 可獨立 review、獨立 revert
- 禁止「fix」「update」「misc」等無意義 subject

## 分支策略

### 保護分支
- `main`/`master` 禁止直接 commit — 所有變更透過 PR 合入
- 發現在保護分支上時，**立即停止**並詢問使用者

### 命名慣例

格式：`<type>/<short-description>`

範例：
- `feat/user-auth`
- `fix/market-data-cache`
- `refactor/api-response-format`
- `chore/update-dependencies`

### 分支生命週期

```
main ──┬── feat/xxx ──── PR ──→ main
       ├── fix/yyy  ──── PR ──→ main
       └── refactor/zzz ─ PR ──→ main
```

- 一個分支做一件事 — 與 commit 原則一致
- 分支壽命越短越好 — 長壽命分支 = merge conflict
- 完成後載入 sunnydata-branch-lifecycle skill 收尾

### 禁止

- 禁止 `git stash` 作為工作流替代品（stash 只用於臨時中斷）
- 禁止在功能分支混做不相關任務
- 禁止 force push 到共享分支（除非明確請求且確認影響）

## Pull Request 流程

1. 分析完整 commit 歷史（不只最新 commit）
2. 使用 `git diff [base-branch]...HEAD` 查看所有變更
3. PR 標題：簡述 WHAT（< 70 字元）
4. PR Body 結構：
   - **Background** — 為什麼要做這個 PR（連結 issue/討論）
   - **Changes** — 核心變更摘要（不是 file list）
   - **Impact** — 破壞性變更、migration 步驟
   - **Test Plan** — 如何驗證
5. 新分支用 `-u` flag push
6. 每個 PR 的 commit 歷史應該乾淨可讀 — 必要時 squash 或 rebase

## 版本管理

- 使用語義化版本（MAJOR.MINOR.PATCH）
- 重要版本建立 git tag
- 維護 CHANGELOG.md（依 Keep a Changelog 格式）
