---
description: 建立 Pull Request。分析完整 commit 歷史與 diff、可選先跑把關鏈、產出含測試計畫的 PR 內容，確認後 push 並開 PR。
---

# 建立 Pull Request

`git-workflow.md` 早就定義了 PR 流程，本指令是它的執行入口。

## 前置檢查（自動，失敗就停）

| 檢查 | 不通過時 |
|---|---|
| 不在預設分支（main/master） | 提示先開分支：`git checkout -b <type>/<slug>`，停止 |
| 有 commit 領先 base | 沒有變更 → 提示無事可做，停止 |
| 工作目錄乾淨 | 有未提交變更 → 問「先 commit / 暫存 / 取消」 |
| `gh` 可用（`gh auth status`） | 不可用 → 改為只 push 並給出手動開 PR 的網址 |
| 有 remote | 無 remote → 提示先設定，停止 |

## 步驟 1：分析完整變更（**不是只看最新 commit**）

```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@.*/@@' || echo main)
git log --oneline "$BASE"..HEAD          # 完整 commit 歷史
git diff "$BASE"...HEAD --stat           # 三個點：只看本分支引入的變更
git diff "$BASE"...HEAD                  # 實際內容
```

> **務必用三個點 `...`**。兩個點會把 base 分支的新 commit 也算進來，導致摘要包含別人的變更。

從中歸納：真正的意圖是什麼（不是逐 commit 複述）、影響範圍、有沒有破壞性變更。

## 步驟 2：把關（用 `AskUserQuestion` 問一題）

> **題目：** 開 PR 前要先跑檢查嗎？

- **跑 `/verify pre-pr`**（Recommended）— 建置/型別/lint/測試/安全掃描
- **跑完整把關鏈** — code-quality-specialist → security-infrastructure-auditor →
  e2e-validation-specialist（見 `agent-orchestration.md` 的「PR 前把關」）
- **跳過，直接開** — 適合文件變更或已經驗過

任務模式為 `critical` 時，**把關鏈不可跳過**——直接執行，不問。

檢查失敗 → 停下回報，不要帶著紅燈開 PR。

## 步驟 3：草擬 PR 內容

用 `AskUserQuestion` 呈現草稿並確認（可選「就這樣」/「我要改標題」/「補充說明」/「取消」）。

**標題**：conventional commits 格式，一行講完做了什麼
`feat(auth): 支援 OAuth 登入`

**內容骨架**：

```markdown
## 摘要

<2-4 句：為什麼要做、做了什麼。針對整個分支，不是逐 commit 流水帳>

## 變更內容

- <依主題分組，不是依檔案列>
- <破壞性變更用 ⚠️ 標出，並寫明遷移方式>

## 測試計畫

- [ ] <具體怎麼驗證，含指令>
- [ ] `/verify pre-pr` 通過
- [ ] <手動驗證步驟，如果有 UI 變更>

## 相關

- WBS 任務：<id>（若有）
- 計畫：`plans/<id>-<slug>.md`（若有）
- 關聯 issue：Closes #<n>（若有）
```

**內容來源**：優先從 WBS 任務描述與 plan 檔的「目標／驗收標準」取材，
那些本來就寫好了，不要重新編一套說法。

## 步驟 4：推送並建立

```bash
git push -u origin "$(git branch --show-current)"     # 新分支必須 -u
gh pr create --base "$BASE" --title "<標題>" --body "<內容>"
```

草稿 PR 加 `--draft`。指定審查者加 `--reviewer <user>`。

## 步驟 5：回報

給出 PR 網址，並提示：

- 有 CI 的話用 `gh pr checks --watch` 追蹤
- `/deploy` 走部署（合併後）

## 使用方式

```
/pr              # 互動式建立
```

不接受參數——標題與內容由分析結果產生並讓你確認，比背參數快。

## 注意

- **PR 內容的署名**：預設附上 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`。
  不想要就在確認那一步說一聲，之後都不加。
- **不要 `--force` push** 到已有審查意見的 PR，除非你明確要求
- 已存在 PR 的分支再跑本指令 → 改為顯示現有 PR 並問要不要更新內容

## 相關

- `.claude/rules/git-workflow.md` — commit 與 PR 規範
- `.claude/rules/agent-orchestration.md` — PR 前把關鏈
- `/verify pre-pr` — 完整檢查含安全掃描
