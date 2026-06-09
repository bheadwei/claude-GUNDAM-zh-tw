# Chapter 4 — 品質驗證與可觀測性

> 投影片文字稿 | 預估時長：10 min

---

## Slide 1: 章節目標

```
Chapter 4: 品質驗證與可觀測性
━━━━━━━━━━━━━━━━━━━━━━━━━

 寫完程式碼不代表完成。
 通過品質門才算完成。

 /verify        → 全面驗證
 /e2e           → 端到端測試（自動對話）
 /agent-log     → 看 subagent 軌跡與交接
 /check-quality → 品質評估
 /time-log      → 時間報表
```

---

## Slide 2: /verify — 三道品質門

```
⚡ 操作：輸入 /verify

┌──────────────────────────────────────┐
│  🔍 全面驗證                          │
│                                      │
│  Gate 1: 型別檢查                    │
│    mypy --strict           ✅        │
│                                      │
│  Gate 2: 測試                        │
│    pytest     → 9/9 passed  ✅       │
│    coverage   → 86%         ✅ (>80%) │
│    （Gemini 全程 mock，不打真 API）   │
│                                      │
│  Gate 3: Lint                        │
│    ruff       → 0 errors    ✅       │
│                                      │
│  結果: ✅ 全部通過                    │
└──────────────────────────────────────┘
```

**講師口述：** `/verify` 一次跑完三道門：型別、測試、lint。任何一道沒過都會告訴你哪裡有問題。這就是你提交 PR 前的最後檢查。

> 💡 `/verify` 會依任務模式自動降階/升階：quick 模式只跑型別 + 建置、critical 模式會加跑安全掃描。手動帶 `/verify full` 仍可強制跑完整流程。

---

## Slide 3: /e2e — Playwright 自動操作瀏覽器

```
⚡ 操作：輸入 /e2e

e2e-validation-specialist agent 會：

1. 啟動 Playwright 瀏覽器
2. 自動執行使用者流程：

   打開聊天頁
     → 看到空的對話視窗
   輸入「你好」並送出
     → AI 開始串流回覆
   等待串流完成
     → 對話氣泡出現完整回覆
   再追問一句
     → 驗證多輪 context 生效
   清除對話
     → 回到空白視窗

3. 產出截圖 + 測試報告
```

**講師口述：**（等 Playwright 跑完）看到了嗎？瀏覽器自己在打字、送出、等 AI 回覆。這不是 mock，是真的開瀏覽器操作整個對話流程。這就是端到端測試。

---

## Slide 4: /agent-log — 看剛剛哪些 Agent 跑過

```
⚡ 操作：輸入 /agent-log

┌──────────────────────────────────────┐
│  🔭 Subagent 活動軌跡                 │
│                                      │
│  agent              次數   最後動作   │
│  ─────────────────  ────  ─────────  │
│  planner            2     規劃串流端點│
│  tdd-guide          2     RED→GREEN   │
│  code-quality       2     抓到 1 CRIT │
│  build-resolver     1     修 import   │
│  e2e-specialist     1     對話測試通過│
│                                      │
│  📋 Handoffs:                        │
│  [completed] tdd→code-quality        │
│  [pending]   code-quality→test-auto  │
│                                      │
│  報告：.claude/context/ 下 5 份       │
└──────────────────────────────────────┘
```

**講師口述：** 這是模板的可觀測性。`/agent-log` 把剛剛跑過的所有 subagent 攤開——誰做了幾次、留下什麼報告、把工作交接給了誰。呼應 Ch1 講的編排劇本：agent 之間靠 handoff 接力，這裡看得一清二楚。注意還有一個 pending 的交接，提示我們可能該補測試。

---

## Slide 5: /check-quality + /time-log

```
⚡ /check-quality — 全面品質報告

┌──────────────────────────────────────┐
│  📊 品質評估                          │
│  程式碼品質  8/10   測試覆蓋率  86%   │
│  安全性  ✅ Key 已保護  技術債  低    │
│                                      │
│  建議：                              │
│  • 加 rate limiting（→ critical 任務）│
│  • 串流錯誤時前端可加重試             │
│  適合交付：deployment-expert / doc    │
└──────────────────────────────────────┘

⚡ /time-log — 自動時間追蹤

┌──────────────────────────────────────┐
│  ⏱️  開發時間報表                     │
│  2.2 串流端點        8 min            │
│  3.2 前端串流顯示    8 min            │
│  2.4 換人設+修Bug    4 min            │
│  ────────────────────────            │
│  合計              ~20 min            │
│  → 你沒手動記過時間，Hook 自動追蹤    │
└──────────────────────────────────────┘
```

**講師口述：** `/check-quality` 不只打分，還告訴你接下來該找哪個 Agent。最後 `/time-log`——我們從頭到尾沒記過時間，但 Hook 在背後自動追蹤。用數據收尾：我們大約 20 分鐘，做出一個能真聊天的 AI 產品。

---

## Slide 6: Chapter 4 小結

```
✅ 品質驗證 + 可觀測性五件套

  /verify        三道品質門（型別 + 測試 + lint）
  /e2e           真實瀏覽器自動對話測試
  /agent-log     subagent 軌跡與 handoff 交接
  /check-quality 綜合評估 + Agent 路由推薦
  /time-log      自動時間追蹤報表

關鍵觀念：
  「寫完 ≠ 完成，通過品質門才算完成」
  「模板會自己觀測自己」

接下來：進階技巧 + Q&A →
```
