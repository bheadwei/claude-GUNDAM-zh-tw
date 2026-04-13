# dev-project-kit

專案開發工具包 Plugin，提供 4 個專業 Skills。

## 包含的 Skills

| Skill | 用途 |
|:---|:---|
| `project-docs` | 依據 VibeCoding 範本撰寫 PRD、架構、API 等 17 種文件 |
| `deep-research` | 使用 firecrawl + exa MCP 進行多源深度研究 |
| `e2e-testing` | Playwright E2E 測試模式（POM、CI/CD、flaky test） |
| `cost-aware-llm-pipeline` | LLM API 成本優化（模型路由、預算追蹤、Prompt 快取） |

## 使用方式

### 方式 1：本地測試

```bash
claude --plugin-dir .claude/plugins/dev-project-kit
```

### 方式 2：在其他專案安裝

```bash
# 複製 plugin 目錄到目標專案
cp -r .claude/plugins/dev-project-kit /path/to/project/.claude/plugins/

# 或用 --plugin-dir 指向此模板的 plugin
claude --plugin-dir /path/to/template/.claude/plugins/dev-project-kit
```

### 方式 3：透過 Marketplace 分享

將此 plugin push 到 GitHub repo，建立 marketplace.json，其他人可用：
```bash
/plugin marketplace add your-github-org/claude-plugins
/plugin install dev-project-kit@your-marketplace
```

## Skill 呼叫方式

安裝為 plugin 後，skill 會加上命名空間前綴：

```
/dev-project-kit:project-docs
/dev-project-kit:deep-research
/dev-project-kit:e2e-testing
/dev-project-kit:cost-aware-llm-pipeline
```
