---
description: 專案初始化，建立 WBS 任務清單、分析複雜度、選擇開發模式。
---

# 專案初始化

## 功能

分析專案需求，建立工作分解結構 (WBS)，配置開發策略。

## 初始化流程

### 互動原則（CRITICAL）

**必須遵守 `.claude/rules/interactive-qa.md`**：

- 使用 `AskUserQuestion` 工具，一次一題逐題詢問
- **在記憶中收集所有問答**，全部結束後再**一次性**用 `Write` 寫入 `.claude/qa-history/YYYY-MM-DD-HHMMSS-task-init.md`
- 若 `.claude/qa-history/` 不存在則先建立
- 問題順序：先基礎資訊 → 再需求澄清 → 最後確認設定
- 依使用者答案動態調整後續問題內容

### 步驟 1: 基礎資訊收集（逐題詢問）

依序用 `AskUserQuestion` 問以下題目，**每次呼叫只問 1 題**：

1. **專案名稱** — 預設選項：沿用目錄名稱 / 自訂
2. **專案簡述** — 一句話描述用途（通常用 Other 自填）
3. **主要語言** — 選項：Python / TypeScript / Go / Java（依專案線索排序，最可能的放第一個並標 Recommended）
4. **GitHub 設定** — 選項：新建 repo / 連接現有 / 跳過

### 步驟 2: 需求澄清（逐題詢問）

同樣用 `AskUserQuestion` 逐題問，依步驟 1 答案調整問題內容：

1. **核心問題** — 解決什麼問題？
2. **核心功能** — 最重要的 3-5 個功能？（可 multiSelect 或 Other 自填）
3. **技術約束** — 偏好框架 / 部署環境 / 特殊限制
4. **規模需求** — 預期用戶量與效能目標
5. **時程資源** — 時間線與資源限制

### 步驟 3: 確認設定

```
專案結構：[簡易/標準/AI-ML]
建議密度：[high/medium/low]
複雜度：[依分析結果]
開發模式：[完整流程/MVP]

確認？(y/N)
```

### 步驟 4: 自動執行

1. **建立專案結構** — 參考 `.claude/templates/project-structures.md`，依步驟 3 選擇的類型套用
2. **生成 CLAUDE.md** — 參考 `.claude/templates/CLAUDE-md.template.md`，**只填入專案獨有資訊**（不重複 rules 內容）
3. 載入相關 VibeCoding 模板
4. 建立 WBS 任務清單
5. 初始化 Git + GitHub（如選擇）
6. 配置 Agent 協調策略
7. **刪除根目錄的 `CLAUDE_TEMPLATE.md`**（已完成初始化任務）

### 步驟 5: 持久化 WBS（關鍵步驟）

**必須** 將 WBS 寫入檔案以跨 session 保存：

1. 建立目錄 `.claude/taskmaster-data/`（若不存在）
2. 將完整 WBS 寫入 `.claude/taskmaster-data/wbs.md`，格式如下：

```markdown
# WBS - [專案名稱]

**建立日期:** YYYY-MM-DD
**最後更新:** YYYY-MM-DD
**開發模式:** [完整流程/MVP]
**專案描述:** [簡述]

---

## 任務清單

| # | 任務 | 狀態 | 優先級 | 依賴 | 預估 | 備註 |
|---|------|------|--------|------|------|------|
| 1.1 | 專案初始化 | ✅ 完成 | 高 | - | 0.5h | 自動完成 |
| 1.2 | 需求分析 | ✅ 完成 | 高 | - | 1h | 自動完成 |
| 2.1 | 架構設計 | ⏳ 待處理 | 高 | 1.2 | 2h | |
| ... | ... | ... | ... | ... | ... | |

### 狀態說明
- ✅ 完成
- 🔄 進行中
- ⏳ 待處理
- 🚫 阻塞
- ⏭️ 跳過

---

## 里程碑

| 里程碑 | 目標日期 | 包含任務 | 狀態 |
|--------|----------|----------|------|
| M1: MVP | YYYY-MM-DD | 1.x, 2.x | 進行中 |

---

## 風險與阻塞

| 風險 | 影響 | 緩解策略 |
|------|------|----------|
```

3. 同時建立 `.claude/taskmaster-data/project.json`：

```json
{
  "name": "[專案名稱]",
  "created": "YYYY-MM-DD",
  "mode": "[完整流程/MVP]",
  "language": "[主要語言]",
  "wbsFile": ".claude/taskmaster-data/wbs.md"
}
```

## 使用方式

```
/task-init                  # 互動式初始化
/task-init my-project       # 指定專案名稱
```

## 初始化完成後

```
專案初始化成功！
WBS 已儲存至 .claude/taskmaster-data/wbs.md

下一步:
  /task-next    取得第一個任務
  /plan         規劃實作步驟
  /task-status  查看 WBS 狀態
```
