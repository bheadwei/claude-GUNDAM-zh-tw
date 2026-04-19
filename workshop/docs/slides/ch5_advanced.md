# Chapter 5 — 進階技巧與收尾

> 投影片文字稿 | 預估時長：10 min

---

## Slide 1: 章節目標

```
Chapter 5: 進階技巧
━━━━━━━━━━━━━━━━━━

 開胃菜 — 讓你知道模板還能做什麼
 每個主題 1-2 分鐘，點到為止
```

---

## Slide 2: /save-session — 下次接著做

```
⚡ 操作：輸入 /save-session

保存當前會話狀態的快照：
• 已完成的任務
• 進行中的工作
• 遇到的問題
• 下次該從哪裡繼續

存檔位置: .claude/sessions/YYYY-MM-DD-*.md

┌──────────────────────────────────────┐
│  下次開新對話時：                      │
│                                      │
│  "請讀取上次的 session 檔案，         │
│   接續之前的進度繼續開發"              │
│                                      │
│  → AI 讀完就知道上下文                │
└──────────────────────────────────────┘
```

**講師口述：** 每次下班前 `/save-session`，隔天開新對話就能無縫接續。不用再重新解釋「我做到哪了」。

---

## Slide 3: /hub-delegate — 點名 Agent

```
平常 Agent 是自動分配的
但你也可以手動指定：

⚡ 操作：/hub-delegate

  "請 security-infrastructure-auditor
   檢查這個專案的安全性"

  → 直接啟動安全稽核 Agent (Opus)
  → 產出 OWASP Top 10 檢查報告

適用場景：
• 你知道該用哪個 Agent
• 需要特定專業的深度分析
• 自動路由沒有觸發你想要的 Agent
```

**講師口述：** 大部分時候你不需要手動選 Agent，但如果你知道要什麼，可以直接點名。

---

## Slide 4: /learn — 把經驗變知識

```
⚡ 操作：/learn

分析當前 session 中的模式，萃取可複用知識：

  "這次開發 FastAPI + SQLModel 的組合，
   有一個好用的 database session 管理模式，
   值得存下來。"

  → 存到 .claude/skills/learned/
  → 下次遇到類似專案自動套用

等於教 AI 學會你的開發偏好
```

**講師口述：** 每次做完專案，花 1 分鐘讓 AI 萃取學到的東西。下次遇到類似情境，它就會自動用上。

---

## Slide 5: 擴充 — 94+ 備用技能

```
.claude/custom-rule&skill/skills/
├── python-patterns/         ← Python 最佳實踐
├── python-testing/          ← pytest 進階
├── django-patterns/         ← Django 開發
├── golang-patterns/         ← Go 開發
├── typescript/              ← TS 開發
├── docker-patterns/         ← Docker
├── security-review/         ← 安全審查
├── ... 共 94+ 個技能包

使用方式：
  把資料夾複製到 .claude/skills/ 即可啟用

例：cp custom-rule&skill/skills/python-patterns/ .claude/skills/
```

**講師口述：** 模板內建 94 個以上的技能包，涵蓋各種語言和框架。需要什麼就複製過去，即裝即用。

---

## Slide 6: 完整流程回顧

```
今天我們走過的路：

  Ch1  認識模板     了解 5 大機制、13 個 Agent
        │
  Ch2  /task-init   專案初始化、產出 CLAUDE.md + WBS
        │
  Ch3  開發循環 x3
        │  /task-next → /plan → /tdd → /review-code → commit
        │  後端 API (FastAPI)
        │  前端 UI (React)
        │  Bug 修復 (/build-fix)
        │
  Ch4  品質驗證
        │  /verify → /e2e → /check-quality → /time-log
        │
  Ch5  進階技巧
           /save-session, /hub-delegate, /learn

  ─────────────────────────────────────
  用了 ~60 min 完成一個有測試、有文檔、有品質門的全端應用
```

---

## Slide 7: 課後作業

```
📝 三個等級，選一個挑戰：

初級 ─ 記帳本 App
  用模板跑 /task-init → /task-next → /tdd
  練習完整循環

中級 ─ TaskFlow 加「到期日」欄位
  練習 SQLModel migration + 前端更新
  體驗修改既有功能的流程

進階 ─ TaskFlow 加 JWT 認證
  FastAPI Security + JWT
  體驗 security-auditor agent
```

---

## Slide 8: 推薦探索路徑

```
想深入的方向             去哪裡看
──────────────────────────────────
Agent 機制              .claude/agents/ (13 個定義檔)
自訂規則                .claude/rules/ (修改或新增)
擴充技能                custom-rule&skill/skills/ (94+)
完整文件流程            /project-docs + 16 個模板
建 MCP Server          mcp-builder skill
模板運作原理            .claude/guides/MECHANISMS.md
```

---

## Slide 9: Q&A

```
┌─────────────────────────────────────────┐
│                                         │
│              Q & A                      │
│                                         │
│    問任何關於模板、工作流、               │
│    Claude Code 的問題                    │
│                                         │
│                                         │
│    模板 repo:                           │
│    [公司內部 Git 位址]                   │
│                                         │
│    速查卡:                              │
│    workshop/docs/03_command_cheatsheet   │
│                                         │
└─────────────────────────────────────────┘
```

**講師口述：** 感謝大家。速查卡放在 workshop/docs 裡，可以列印出來貼在螢幕旁邊。有問題隨時在內部頻道問。
