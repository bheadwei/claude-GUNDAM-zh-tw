# Package Manager 規則（Node.js 生態）

Node.js / 前端專案的 package manager（套件管理器）選擇由使用者決定，寫入專案設定檔後強制執行。本規則定義選擇、儲存、讀取、切換的全流程。

## 🚨 CRITICAL：執行任何 Node 指令前必檢

以下指令執行前，**必須**先讀取 `.claude/taskmaster-data/package-manager.json`：

- `npm install` / `bun install` / `pnpm install`
- `npm run <script>` / `bun run <script>` / `pnpm run <script>`
- `npm test` / `bun test` / `pnpm test`
- `npm audit` / `bun audit` / `pnpm audit`
- 任何操作 `package.json`、`node_modules/`、lockfile 的動作

### 分流

1. **檔案存在** → 讀取 `manager` 欄位，一律用該 PM 的指令語法（見下方對照表）
2. **檔案不存在** → 觸發 `/pm-choose` 指令詢問使用者，寫入後再繼續

**例外**：使用者在當次請求中**明確**指定 PM（例："用 pnpm 裝 react"）→ 尊重當次選擇，但提醒其與設定檔不符並詢問是否更新設定

---

## 設定檔格式

路徑：`.claude/taskmaster-data/package-manager.json`

```json
{
  "manager": "bun",
  "chosen_at": "2026-04-23",
  "lockfile": "bun.lock",
  "reason": "新專案，追求安裝速度"
}
```

欄位：
- `manager`：`"bun"` / `"pnpm"` / `"npm"`
- `chosen_at`：YYYY-MM-DD
- `lockfile`：對應 lock 檔名（`bun.lock` / `pnpm-lock.yaml` / `package-lock.json`）
- `reason`：選擇理由（自由文字，供日後回顧）

---

## 指令對照表

| 操作 | npm | pnpm | bun |
|---|---|---|---|
| 安裝全部依賴 | `npm install` | `pnpm install` | `bun install` |
| 新增套件 | `npm install <pkg>` | `pnpm add <pkg>` | `bun add <pkg>` |
| 新增 dev 套件 | `npm install -D <pkg>` | `pnpm add -D <pkg>` | `bun add -d <pkg>` |
| 移除套件 | `npm uninstall <pkg>` | `pnpm remove <pkg>` | `bun remove <pkg>` |
| 執行腳本 | `npm run <script>` | `pnpm <script>` | `bun run <script>` |
| 啟動開發 | `npm run dev` | `pnpm dev` | `bun dev` |
| 測試 | `npm test` | `pnpm test` | `bun test` |
| 全域安裝 | `npm install -g <pkg>` | `pnpm add -g <pkg>` | `bun add -g <pkg>` |
| 執行 CLI（臨時） | `npx <cli>` | `pnpm dlx <cli>` | `bunx <cli>` |
| 稽核漏洞 | `npm audit` | `pnpm audit` | `bun audit` |

---

## 安全閘門

### 偵測 lock 檔衝突

執行 `<pm> install` 前，若專案內出現**多個** lock 檔（例：同時有 `package-lock.json` 和 `bun.lock`），**停止**並提示使用者：

```
⚠️ 偵測到 lock 檔衝突：
  - package-lock.json（npm）
  - bun.lock（bun）

當前設定使用 bun。建議動作：
  1. 刪除 package-lock.json
  2. 刪除 node_modules/
  3. 重新執行 bun install

是否執行？(y/N)
```

### 偵測 PM 與設定不符

若專案有 `package-lock.json` 但設定檔指定 `bun`，提示：

```
⚠️ 此專案看起來是 npm 專案（存在 package-lock.json），
但設定檔指定使用 bun。

選項：
  1. 切換設定為 npm（保守，不動現有 lock）→ /pm-switch
  2. 清除 npm 痕跡改用 bun（會重算依賴版本）
  3. 忽略並繼續
```

### 原生模組 fallback

若 `bun install` 或 `pnpm install` 因原生模組失敗（如 `sharp`、`canvas`、`node-gyp` 編譯錯），可臨時用 `npm install <該套件>` 繞過，但**必須**：

1. 在設定檔 `reason` 欄位追加 TODO 備註
2. 在 commit message 說明原因
3. 不切換全域 PM

---

## 與其他規則的協作

- **Python uv 規則**（`development-workflow.md`）處理 Python；本規則處理 Node.js，兩者互不覆蓋
- **UI 風格規則**（`ui-design.md`）在建立前端專案時應確保本規則已執行
- **Pencil 設計規則**（`pencil-design-location.md`）不受本規則影響（不跑 Node 指令）

---

## 相關指令

- `/pm-choose` — 首次選擇或在未設定時觸發
- `/pm-switch` — 切換已設定的 PM（附遷移指引）
- `/task-init` — 專案初始化時若偵測到前端需求，會自動跳入 `/pm-choose`
