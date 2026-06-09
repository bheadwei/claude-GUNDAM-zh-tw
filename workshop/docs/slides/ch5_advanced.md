# Chapter 5 — 進階技巧與收尾

> 投影片文字稿 | 預估時長：8 min

---

## Slide 1: 章節目標

```
Chapter 5: 進階技巧
━━━━━━━━━━━━━━━━━━

 開胃菜 — 讓你知道模板還能做什麼
 每個主題 1-2 分鐘，點到為止
```

---

## Slide 2: /suggest-mode — 調整建議密度

```
⚡ 操作：/suggest-mode <模式>

模板會在關鍵節點主動建議該叫哪個 Agent。
密度可依你的熟練度調整：

┌──────────┬────────────────────────────┐
│ high     │ 每步都建議  → 新手、學習中   │
│ medium   │ 關鍵點建議  → 日常（預設）   │
│ low      │ 只在有風險時 → 熟練開發者    │
│ off      │ 完全不建議  → 心流 / 快速原型│
└──────────┴────────────────────────────┘

  /suggest-mode high    今天教學建議開這個
  /suggest-mode off     自己很清楚要做什麼時
```

**講師口述：** 如果你是新手，開 `high`，模板會一路提醒你「現在該審查了」「該補安全檢查了」。等你熟了，調 `low` 或 `off`，讓它別吵你。這就是人機協作的節奏控制。

---

## Slide 3: /hub-delegate — 點名 Agent

```
平常 Agent 是自動分配的
但你也可以手動指定：

⚡ 操作：/hub-delegate

  "請 security-infrastructure-auditor
   檢查這個專案的 API Key 處理是否安全"

  → 直接啟動安全稽核 Agent (Opus)
  → 產出 OWASP Top 10 + 秘密偵測報告

適用場景：
• 你知道該用哪個 Agent
• 需要特定專業的深度分析
• 自動路由沒有觸發你想要的 Agent
```

**講師口述：** 大部分時候你不需要手動選 Agent，但如果你知道要什麼，可以直接點名。像我們的 chatbot 有 API Key，正式上線前就該點名安全稽核 agent 跑一遍。

---

## Slide 4: /save-session + /learn — 知識沉澱

```
⚡ /save-session — 下次接著做

  保存當前會話快照（已完成、進行中、下一步）
  存到 .claude/sessions/YYYY-MM-DD-*.md

  下次開新對話：
  "讀取上次的 session，接續開發"
  → AI 讀完就知道上下文

⚡ /learn — 把經驗變知識

  萃取這次 session 的可複用模式，例如：
  "Gemini 串流 + FastAPI SSE 的封裝模式"
  → 存成 skill，下次類似專案自動套用
```

**講師口述：** 下班前 `/save-session`，隔天無縫接續。做完專案花 1 分鐘 `/learn`，把學到的東西沉澱成模板的知識——等於教 AI 學會你的開發偏好。

---

## Slide 5: 擴充 — 94+ 備用技能

```
.claude/custom-rule&skill/skills/
├── python-patterns/         ← Python 最佳實踐
├── python-testing/          ← pytest 進階
├── fastapi-patterns/        ← FastAPI 開發
├── cost-aware-llm/          ← LLM 成本優化
├── mcp-builder/             ← 做 MCP server
├── security-review/         ← 安全審查
├── ... 共 94+ 個技能包

使用方式：
  把資料夾複製到 .claude/skills/ 即可啟用

例：cp -r custom-rule&skill/skills/fastapi-patterns/ \
        .claude/skills/
```

**講師口述：** 模板內建 94 個以上的技能包，涵蓋各種語言和框架。需要什麼就複製過去，即裝即用。`custom-rule&skill/` 是備份池，不會自動執行，是給你取材的。

---

## Slide 6: 完整流程回顧

```
今天我們走過的路：

  Ch1  認識模板     .claude 6 大觀念、14 個 Agent、編排劇本
        │
  Ch2  /task-init   專案初始化、產出 CLAUDE.md + WBS
        │
  Ch3  開發循環 x3
        │  /task-next → /plan → /tdd → /review-code → commit
        │  後端串流 API (FastAPI + Gemini SSE)
        │  前端聊天 UI (原生單頁，逐字串流)
        │  換人設 + 修 Bug (/build-fix)
        │
  Ch4  品質驗證
        │  /verify → /e2e → /agent-log → /check-quality → /time-log
        │
  Ch5  進階技巧
           /suggest-mode, /hub-delegate, /save-session, /learn

  ─────────────────────────────────────
  用了 ~60 min 做出一個會串流、能多輪對話、
  有測試、有品質門的 AI 聊天機器人
```

---

## Slide 7: 課後作業

```
📝 三個等級，選一個挑戰：

初級 ─ 翻譯小幫手 chatbot
  用模板跑 /task-init → /task-next → /tdd
  練習完整循環（換個 system prompt 就是新產品）

中級 ─ GeminiChat 加「對話持久化 + 多角色」
  存 SQLite + 預設多個角色切換
  體驗修改既有功能的流程

進階 ─ GeminiChat 進化
  選一個：
  • RAG：讀一份 PDF 後針對內容問答
  • MCP：用 mcp-builder 把它包成一個 MCP tool
  體驗 LLM 應用的進階模式
```

---

## Slide 8: 推薦探索路徑

```
想深入的方向             去哪裡看
──────────────────────────────────
Agent 機制              .claude/agents/ (14 個定義檔)
Agent 編排              .claude/rules/agent-orchestration.md
自訂規則                .claude/rules/ (15 條，可改可加)
擴充技能                custom-rule&skill/skills/ (94+)
LLM 成本優化            cost-aware-llm-pipeline skill
完整文件流程            /docs-init --full + 16 個模板
建 MCP Server          mcp-builder skill
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

**講師口述：** 感謝大家。速查卡放在 workshop/docs 裡，可以列印出來貼在螢幕旁邊。今天做的 GeminiChat 整套流程都在 SOP 文件裡，回去照著跑一遍就熟了。有問題隨時在內部頻道問。
