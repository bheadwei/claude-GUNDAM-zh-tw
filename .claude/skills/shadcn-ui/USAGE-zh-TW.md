# shadcn/ui Skill — 使用說明（繁體中文）

本目錄為 [shadcn/ui 官方](https://github.com/shadcn-ui/ui) 提供的 **Agent Skill**（`skills/shadcn`），協助在專案中**正確使用 CLI、元件組合、樣式與表單規則**。完整規則以 **`SKILL.md`** 與同目錄下的 `rules/`、`cli.md` 為準。

---

## 1. 這個 skill 做什麼？

- 在對話中處理 **shadcn/ui、component registry、`components.json`、preset** 相關工作時，讓助理依官方約定產生程式與指令（含 **Tailwind 語意色、表單 Field 結構、CLI 用法** 等）。
- Skill 內建會建議執行 **`shadcn info --json`** 以讀取目前專案設定與已安裝元件（需專案已初始化，見下節）。

---

## 2. 專案要先準備什麼？

| 項目 | 說明 |
|------|------|
| **前端專案** | 通常為 Next.js、Vite + React 等（依 [官方文件](https://ui.shadcn.com/docs) 支援的框架）。 |
| **初始化 shadcn** | 在專案根目錄執行 `npx shadcn@latest init`（或 `pnpm dlx` / `bunx`，與你的套件管理一致）。成功後會產生 **`components.json`**。 |
| **套件管理器** | 之後所有 CLI 範例請改為與專案一致：例如 `pnpm dlx shadcn@latest`、`bunx --bun shadcn@latest`。 |

沒有 `components.json` 時，助理無法依 skill 取得「目前專案上下文」；請先完成 **init** 再請 AI 協助加元件或改 UI。

---

## 3. 在 Cursor / Claude 裡怎麼「用」這個 skill？

1. **Skill 已放在** `.claude/skills/shadcn-ui/`，只要你的環境會載入 `.claude/skills` 底下的技能，處理 shadcn 相關任務時就會套用（與官方 `description` 觸發條件一致）。
2. **說清楚情境**，例如：「用 shadcn 加一個含表單的登入頁」「幫我 `add` dialog 元件」「依 `components.json` 用 registry 補 calendar」。
3. 助理應依 **`SKILL.md`** 使用 **專案對應的 CLI**（`npx` / `pnpm dlx` / `bunx`），並參考 `rules/*.md` 的 Incorrect/Correct 範例。

> 官方 skill 標註 `user-invocable: false`，代表以**任務自動觸發**為主，不需要你手動輸入固定咒語；只要任務與 shadcn/ui 相關即可。

---

## 4. 常用 CLI（請替換成你的套件管理指令）

```bash
# 專案資訊（JSON，給 AI / skill 對齊設定）
npx shadcn@latest info --json

# 搜尋可安裝元件
npx shadcn@latest search

# 安裝元件（範例）
npx shadcn@latest add button

# 某元件文件與範例連結
npx shadcn@latest docs button
```

更多子指令與參數見同目錄 **`cli.md`** 與 [官方 CLI 文件](https://ui.shadcn.com/docs/cli)。

---

## 5. 與本 repo 其他 skill 的關係

- **`coding-standards`**：通用 TS/React 風格。
- **`security-review` / `owasp-web-security`**：表單、API、XSS 等安全相關時與 shadcn 並行考量。
- **`tdd-workflow`**：若為元件寫測試時使用。

---

## 6. 更新這個 skill

官方更新時可重新從上游複製：

```bash
# 僅示例：請在專案根目錄外自行 clone sparse 後覆蓋 .claude/skills/shadcn-ui
# 來源：https://github.com/shadcn-ui/ui/tree/main/skills/shadcn
```

---

## 7. 參考連結

- [shadcn/ui 文件](https://ui.shadcn.com/docs)
- [Skills 說明（官方）](https://ui.shadcn.com/docs/skills)
- 本目錄 **`SKILL.md`**（英文，權威規則）
