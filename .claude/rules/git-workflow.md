# Git 工作流

## Commit Message 格式

```
<type>(<optional scope>): <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

## 分支命名慣例

格式：`<type>/<short-description>`

範例：
- `feat/user-auth`
- `fix/market-data-cache`
- `refactor/api-response-format`

詳細分支生命週期管理請載入 sunnydata-branch-lifecycle skill。

## Pull Request 流程

1. 分析完整 commit 歷史（不只最新 commit）
2. 使用 `git diff [base-branch]...HEAD` 查看所有變更
3. 撰寫全面 PR 摘要
4. 包含測試計畫
5. 新分支用 `-u` flag push

## 版本管理

- 使用語義化版本（MAJOR.MINOR.PATCH）
- 重要版本建立 git tag
- 維護 CHANGELOG.md（依 Keep a Changelog 格式）
