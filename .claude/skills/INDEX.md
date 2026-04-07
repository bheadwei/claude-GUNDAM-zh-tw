# Skills 索引

已安裝 8 個精選 skill，涵蓋核心開發流程。

## 已安裝

| Skill | 用途 | 觸發時機 |
| :--- | :--- | :--- |
| **tdd-workflow** | TDD 完整流程（Red-Green-Refactor） | 寫新功能、修 bug、重構 |
| **api-design** | REST API 設計最佳實踐 | 設計 API 端點 |
| **security-review** | 安全審查流程 | commit 前、安全敏感程式碼 |
| **e2e-testing** | Playwright E2E 測試模式 | 測試關鍵使用者流程 |
| **coding-standards** | 通用編碼標準 | 所有開發工作 |
| **deep-research** | 深度研究技巧 | 複雜問題調查 |
| **deployment-patterns** | 部署模式（Blue-Green, Canary） | 部署規劃 |
| **docker-patterns** | Docker 最佳實踐 | 容器化專案 |

## 擴充方式

更多 skill 可從備份取材池複製（共 94 個，見
[`.claude/custom-rule&skill/skills/INDEX.md`](../custom-rule&skill/skills/INDEX.md)）：

```bash
# 複製特定 skill
cp -r .claude/custom-rule&skill/skills/[skill-name] .claude/skills/
```

### 推薦擴充

| Skill | 適用場景 |
| :--- | :--- |
| python-patterns | Python 專案 |
| golang-patterns | Go 專案 |
| springboot-patterns | Java/Spring Boot 專案 |
| frontend-patterns | React/Vue 前端專案 |
| postgres-patterns | PostgreSQL 專案 |
| database-migrations | 資料庫遷移 |
