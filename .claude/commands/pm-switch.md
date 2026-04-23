---
description: 切換已設定的 Node.js package manager，附遷移指引與安全檢查
---

# Package Manager 切換

## 功能

將專案既有的 package manager 切換到另一個（bun ↔ pnpm ↔ npm），並提供遷移步驟。

## 前提

`.claude/taskmaster-data/package-manager.json` **必須**已存在。若不存在 → 提示使用者改用 `/pm-choose`。

---

## 執行流程

### 步驟 1：讀取當前設定

Read `.claude/taskmaster-data/package-manager.json`，記錄當前 `manager`（稱為 `old_pm`）。

若檔案不存在：

```
❌ 尚未設定 package manager。
請先執行 /pm-choose 進行初次設定。
```

→ 停止執行。

### 步驟 2：詢問要切換到哪個

用 `AskUserQuestion` 問：

**題目：** 目前使用 **`<old_pm>`**，要切換到哪個 package manager？

選項排除 `old_pm`，只留其他兩個：

| 選項 | 說明 |
|------|------|
| **bun** | 速度最快、ESM-first、內建 TS/test。注意原生模組相容 |
| **pnpm** | 磁碟效率、嚴格依賴隔離、monorepo 友善 |
| **npm** | 官方內建、相容性最高、CI 平台預設 |

（`old_pm` 不出現在選項中）

### 步驟 3：遷移影響說明

切換後在回覆中**必須**列出以下影響清單供使用者確認：

```
⚠️ 切換 <old_pm> → <new_pm> 會有以下變動：

必要動作（使用者需自行執行，此指令不自動動檔案）：
  1. 刪除 node_modules/
  2. 刪除舊 lock 檔：<old_lock>
  3. 執行新 PM 安裝：<new_pm install>

可能影響：
  - 依賴版本微幅漂移（lock 檔重新計算）
  - 原生模組可能需重新編譯
  - CI/CD 設定需更新（setup-node → setup-bun / setup-pnpm）
  - Dockerfile base image 可能要改
  - 團隊成員下次 pull 後也需重做上述步驟

確認切換？(y/N)
```

### 步驟 4：使用者確認後執行

若確認 `y`：

1. **更新設定檔** — Write `.claude/taskmaster-data/package-manager.json`：

   ```json
   {
     "manager": "<new_pm>",
     "chosen_at": "<今天>",
     "lockfile": "<new_pm 對應 lock>",
     "reason": "從 <old_pm> 切換至 <new_pm>：<使用者原因>",
     "previous_manager": "<old_pm>"
   }
   ```

2. **提供可直接複製的指令**（不自動執行，由使用者確認後貼到 terminal）：

   ```bash
   rm -rf node_modules <old_lock>
   <new_pm> install
   ```

3. **提醒相關檔案需人工更新**：

   - `.github/workflows/*.yml`（若有）— `setup-node` 改 `setup-<new_pm>`
   - `Dockerfile`（若有）— base image 改 `oven/bun:1` / `node:20-alpine` + `pnpm` 安裝
   - `package.json` 的 `engines` 欄位（若有指定）
   - `README.md`（若有安裝說明）

### 步驟 5：完成提示

```
✅ Package manager 已切換為 <new_pm>

請在 terminal 執行上述指令完成實際遷移。
需要協助更新 CI/Dockerfile？告訴我相關檔案路徑。
```

---

## 使用方式

```
/pm-switch                  # 互動式切換
```

## 注意事項

- 本指令**不自動**刪除 `node_modules` 或 lock 檔（避免誤刪使用者進行中的工作）
- 設定檔中保留 `previous_manager` 欄位供回溯
- 切換過多次會污染 `reason` 欄位，必要時可手動清理設定檔
