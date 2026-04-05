# Skills 索引

目前保留 **產品開發常用** 的 skill（精選 8 項 + 安全 + Superpowers + **shadcn/ui**）。已移除 Trail of Bits 全包；與 `tdd-workflow` 重複的 `sp-test-driven-development` 維持不導入。

## 精選（核心流程）

| Skill                         | 用途                               | 觸發時機                  |
| :---------------------------- | :--------------------------------- | :------------------------ |
| **tdd-workflow**        | TDD 完整流程（Red-Green-Refactor） | 寫新功能、修 bug、重構    |
| **api-design**          | REST API 設計最佳實踐              | 設計 API 端點             |
| **security-review**     | 安全審查流程                       | commit 前、安全敏感程式碼 |
| **e2e-testing**         | Playwright E2E 測試模式            | 測試關鍵使用者流程        |
| **coding-standards**    | 通用編碼標準                       | 所有開發工作              |
| **deep-research**       | 深度研究技巧                       | 複雜問題調查              |
| **deployment-patterns** | 部署模式（Blue-Green, Canary）     | 部署規劃                  |
| **docker-patterns**     | Docker 最佳實踐                    | 容器化專案                |

## shadcn/ui

| Skill | 用途 | 使用說明 |
| :--- | :--- | :--- |
| **shadcn-ui** | 官方 shadcn/ui CLI、元件規則、`components.json` 與 registry | 見 **[shadcn-ui/USAGE-zh-TW.md](./shadcn-ui/USAGE-zh-TW.md)**；規則全文見同目錄 **`SKILL.md`** |

**前置**：在目標前端專案執行 `npx shadcn@latest init`（或 `pnpm dlx` / `bunx`），產生 `components.json` 後再請 AI 協助加元件或改 UI。

## 安全（OWASP + 框架參考）

| Skill                                    | 用途                                                                                  |
| :--------------------------------------- | :------------------------------------------------------------------------------------ |
| **owasp-web-security**             | OWASP Top 10（2021）分類與官方連結，與 `security-review` 搭配                       |
| **security-best-practices-openai** | Python / JS / Go 等安全參考（[openai/skills](https://github.com/openai/skills) curated） |

## Superpowers

來源：[obra/superpowers](https://github.com/obra/superpowers)。與 `tdd-workflow` 重複的 **`sp-test-driven-development`** 未導入。

**繁體中文怎麼用（平行代理／worktree／寫 skill）**：見 **[SUPERPOWERS-EXTRAS-USAGE-zh-TW.md](./SUPERPOWERS-EXTRAS-USAGE-zh-TW.md)**。

| Skill                                       | 用途                  |
| :------------------------------------------ | :-------------------- |
| **sp-using-superpowers**              | 如何載入與遵循 skills |
| **sp-brainstorming**                  | 需求／設計前探索      |
| **sp-writing-plans**                  | 撰寫執行計畫          |
| **sp-executing-plans**                | 依計畫實作與檢查點    |
| **sp-verification-before-completion** | 完成前驗證            |
| **sp-systematic-debugging**           | 結構化除錯            |
| **sp-requesting-code-review**         | 發起 code review      |
| **sp-receiving-code-review**          | 處理 review 回饋      |
| **sp-finishing-a-development-branch** | 分支收尾與合併前選項  |
| **sp-dispatching-parallel-agents**    | 多個獨立任務 → 平行子代理 |
| **sp-using-git-worktrees**            | 用 `git worktree` 隔離分支／目錄 |
| **sp-writing-skills**                 | 撰寫／驗證 `SKILL.md`（流程文件 TDD） |

## 擴充方式

更多 skill 可從 everything-claude 複製，或自 [obra/superpowers](https://github.com/obra/superpowers)、[trailofbits/skills](https://github.com/trailofbits/skills)、[shadcn-ui/ui `skills/shadcn`](https://github.com/shadcn-ui/ui/tree/main/skills/shadcn) 等再挑選後放入 `.claude/skills/<name>/`。

```bash
cp -r /path/to/skill-folder .claude/skills/
```

### 可選擴充（依專案）

| 情境               | 建議來源                              |
| :----------------- | :------------------------------------ |
| 合約／深度安全審計 | `trailofbits/skills` 依 plugin 挑選 |
