---
description: 選擇專案的 Node.js package manager（bun / pnpm / npm），寫入 .claude/taskmaster-data/package-manager.json
---

# Package Manager 選擇

## 功能

互動式選擇專案要使用的 Node.js 套件管理器，寫入設定檔供所有 Node 相關任務引用。

## 何時觸發

- 使用者主動執行 `/pm-choose`
- `/task-init` 偵測到前端需求時自動呼叫
- `.claude/rules/package-manager.md` 偵測到要執行 Node 指令但設定檔不存在時自動呼叫

---

## 執行流程

### 互動原則（CRITICAL）

**必須遵守 `.claude/rules/interactive-qa.md`**：

- 使用 `AskUserQuestion` 工具逐題詢問
- 在記憶中收集問答，結束後一次性 Write 到 `.claude/qa-history/YYYY-MM-DD-HHMMSS-pm-choose.md`

### 步驟 1：環境偵測（自動，不問使用者）

執行前先用 Glob / Read 檢查：

- [ ] 專案根目錄是否有 `package.json`？
- [ ] 是否已存在 lock 檔？（`package-lock.json` / `pnpm-lock.yaml` / `bun.lock` / `bun.lockb` / `yarn.lock`）
- [ ] 是否已存在 `.claude/taskmaster-data/package-manager.json`？若存在 → 提示使用者改用 `/pm-switch`

記錄偵測結果，作為步驟 2 的選項推薦依據。

### 步驟 2：主題詢問

用 `AskUserQuestion` 問一題：

**題目：** 這個專案要用哪個 package manager？

| 選項 | 說明 |
|------|------|
| **bun (Recommended)** | 最快的安裝與執行速度、內建 TypeScript 與 test runner、ESM-first。適合新專案與追求開發體驗者。注意：少數 C++ 原生模組可能需 workaround。 |
| **pnpm** | 硬連結節省磁碟、嚴格依賴隔離、monorepo 友善。注意：peer-dep 規則較嚴，老套件可能抱怨。 |
| **npm** | Node.js 官方內建、相容性最高、CI 平台預設。注意：安裝最慢、`node_modules` 最肥。 |

**推薦邏輯：**

- 若偵測到 `package-lock.json` 已存在 → **npm** 列第一並標 Recommended（尊重現況）
- 若偵測到 `pnpm-lock.yaml` → **pnpm** 列第一
- 若偵測到 `bun.lock` 或 `bun.lockb` → **bun** 列第一
- 若**都沒有** lock 檔（新專案）→ **bun** 列第一（模板預設推薦）

### 步驟 3：若有 lock 檔衝突 → 額外詢問

若使用者選擇的 PM **與現有 lock 檔不符**，追問一題：

**題目：** 偵測到現有 `<existing-lock>` 屬於 `<other-pm>`。要如何處理？

| 選項 | 說明 |
|------|------|
| **保留現有，改選對應 PM** | 取消當次選擇，改用 lock 檔對應的 PM |
| **遷移到新 PM (謹慎)** | 刪除舊 lock + `node_modules`，用新 PM 重裝。注意依賴版本可能微幅漂移 |
| **兩者並存 (不建議)** | 保留但由本規則追蹤，後續每次執行會警告 |

### 步驟 4：寫入設定檔

用 `Write` 建立 `.claude/taskmaster-data/package-manager.json`：

```json
{
  "manager": "<選擇>",
  "chosen_at": "<今天 YYYY-MM-DD>",
  "lockfile": "<對應 lock 檔名>",
  "reason": "<從使用者答案摘錄，若無則留空字串>"
}
```

若目錄 `.claude/taskmaster-data/` 不存在則先建立。

### 步驟 5：執行必要動作

依步驟 3 選擇：

- **保留現有** → 什麼都不做，提示「已採用 `<pm>`，可直接開始開發」
- **遷移到新 PM** → 提示使用者（**不自動執行**，需使用者確認）：
  ```
  下一步需要執行：
    rm -rf node_modules <舊-lock>
    <新pm> install
  
  是否現在執行？(y/N)
  ```
- **兩者並存** → 不動作，但提示未來每次執行相關指令都會再次警告

### 步驟 6：完成提示

```
✅ Package manager 已設定為 <pm>
   設定檔：.claude/taskmaster-data/package-manager.json

從現在起，所有 Node 指令將使用 <pm> 語法：
  - 安裝依賴：<pm install>
  - 啟動開發：<pm dev 指令>
  - 執行測試：<pm test 指令>

想切換？執行 /pm-switch
完整規則：.claude/rules/package-manager.md
```

---

## 使用方式

```
/pm-choose                  # 互動式選擇
```

## 注意事項

- 不接受指令參數，一律走互動流程（避免誤設）
- 若要切換已設定的 PM，使用 `/pm-switch`
- 設定檔路徑固定 `.claude/taskmaster-data/package-manager.json`，不可自訂
