# Git 工作流

## Commit Message 格式

```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

## Pull Request 流程

1. 分析完整 commit 歷史（不只最新 commit）
2. 使用 `git diff [base-branch]...HEAD` 查看所有變更
3. 撰寫全面 PR 摘要
4. 包含測試計畫
5. 新分支用 `-u` flag push
