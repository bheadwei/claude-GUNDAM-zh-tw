---
description: 分析當前 session 並擷取值得保存的可重用模式作為知識。
---

# 學習指令

分析當前 session 並擷取任何值得保存為技能的模式。

## 觸發時機

在 session 中解決非平凡問題的任何時刻執行 `/learn`。

## 擷取目標

尋找以下內容：

### 1. 錯誤解決模式
- 發生了什麼錯誤？
- 根因是什麼？
- 什麼修復了它？
- 這對類似錯誤是否可重用？

### 2. 除錯技巧
- 不明顯的除錯步驟
- 有效的工具組合
- 診斷模式

### 3. 變通方案
- 套件的特殊行為
- API 限制
- 版本特定的修復

### 4. 專案特定模式
- 發現的程式碼庫慣例
- 做出的架構決策
- 整合模式

## 輸出格式（兩種，先問使用者選哪個）

> **重要**：舊版把檔案寫到 `.claude/skills/learned/[名稱].md`，
> 那**不是合法的 skill 格式**（skill 必須是 `skills/<name>/SKILL.md` 且帶 frontmatter），
> 因此永遠不會被索引或載入，實質只是筆記卻佔著 skills 命名空間。已修正為下列兩種。

用 `AskUserQuestion` 問一題：這個發現要成為**可載入的 skill**（跨專案通用的技巧），
還是**坑紀錄**（這個專案特有、會在特定檔案重演的雷）？

### 選項 A：真 skill（模式夠通用、未來會想自動觸發）

建立 `.claude/skills/<kebab-name>/SKILL.md`：

```markdown
---
name: <kebab-name>
description: <一句話說明內容>。Use when <明確的觸發條件——寫成情境導向，不是內容摘要>。
---

# [描述性模式名稱]

**擷取日期:** [日期]

## 問題
[此模式解決什麼問題 - 要具體]

## 解決方案
[模式/技巧/變通方案]

## 範例
[適用時附上程式碼範例]
```

寫完後**更新 `.claude/skills/INDEX.md`** 加一行，否則沒人知道它存在。

### 選項 B：坑紀錄（這個專案踩過的雷、會在特定檔案重演）

建立 `.claude/context/learned/[kebab-name].md`，**照 `_PITFALL_TEMPLATE.md` 的 frontmatter**：

```yaml
---
date: <今天>
title: 一句話講清楚這個坑
files:                    # 這個坑會在哪些檔案重演（glob，相對專案根）
  - "backend/mcp/*.py"
symptom: 看到的現象
root-cause: 真正的原因，不是症狀複述
guard: 下次碰這些檔案該怎麼做才不會再踩
severity: high | medium | low
---
```

**`files:` 不是裝飾**——`pre-tool-use.sh` 的坑閘門靠它比對：下次任何人或 agent 要寫入
命中的檔案，會被擋一次並看到這份紀錄。留空或寫錯 = 永遠不會被觸發，等於沒寫。

寫完後檢查一件事：**這個坑能不能用 regex 或測試表達？** 能的話優先升級成機器保證
（加測試，或在 `pre-tool-use.sh` 加規則），文件留給判斷題。

## 流程

1. 審查 session 中可擷取的模式
2. 識別最有價值/可重用的洞察
3. 用 `AskUserQuestion` 問要 skill 還是筆記
4. 撰寫草稿並請使用者確認後再儲存
5. 若為 skill，同步更新 `skills/INDEX.md`

## 注意事項

- **寫入前檢查敏感資料** —— `context/learned/` 與 `skills/` 都進版控，git 歷史刪不掉。
  坑紀錄最容易夾帶的是「重現用的資料樣本」與「錯誤訊息裡的連線字串」：
  寫**形狀**不寫**內容**（「TTL 單位用秒但 API 期望毫秒」可以，貼整條連線字串不行）。
  完整清單見 `.claude/commands/save-session.md` 的「敏感資料檢查」
- 不擷取瑣碎修復（打字錯誤、簡單語法錯誤）
- 不擷取一次性問題（特定 API 中斷等）
- 專注於能在未來 session 節省時間的模式
- 保持聚焦 -- 一個模式一個檔案
- **skill 的 `description` 決定它會不會被想起來**——寫觸發條件，不要寫內容摘要。
  「PostgreSQL 索引知識」是壞的；「Use when 設計 schema 或查詢變慢時」是好的
