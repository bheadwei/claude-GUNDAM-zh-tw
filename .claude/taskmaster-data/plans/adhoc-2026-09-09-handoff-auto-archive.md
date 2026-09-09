---
wbs_task: "none"
slug: "handoff-auto-archive"
created: "2026-09-09"
updated: "2026-09-09"
status: "⏳ 未開始"
current_phase: 1
files:
  - ".claude/hooks/lib/handoff-archive.sh"
  - ".claude/hooks/post-agent-report.sh"
  - ".claude/hooks/pre-agent-gate.sh"
  - ".claude/settings.json"
  - ".claude/coordination/README.md"
  - ".claude/coordination/handoffs/_HANDOFF_TEMPLATE.md"
  - ".claude/hooks/tests/run-tests.sh"
---

# 實作計畫：handoff 自動歸檔 + 兩個 agent hook 的真 bug

## 目標

`status: completed` 的 handoff 自動搬到 `coordination/handoffs/archive/YYYY-MM/`，
`post-agent-report.sh` 的 pending 掃描只需要看平坦目錄裡「還沒完成」的那幾份。
審計軌跡不消失，只是換位置。

## 背景（為什麼要做）

`_HANDOFF_TEMPLATE.md` 末行寫「完成後不刪除，作為審計軌跡」，所以 completed 的檔案
永遠留在 `handoffs/`。三個後果：

1. `post-agent-report.sh:123` 每次 subagent 結束都 for-loop 掃整個目錄、對每個檔案
   `grep -m1 '^status:'`。做過 50 次交接後，每次 hook 都掃 50 檔才找到 0 個 pending
2. agent 要讀「屬於自己的 pending handoff」時得在一堆 completed 裡撈
3. status 改成 completed **完全靠自律** —— hook 只在注入訊息裡提醒一句

歸檔要做成 hook 而非文字規則：照 v5.6 的決策「自動化一律做成 hook，指令要人記得打」。

## 技術依賴 / 既有資產

- `.claude/hooks/lib/resolve-roots.sh` — `handoffs/` 屬**共享產物**，一律用 `MAIN_CLAUDE`
  （見 `worktree-orchestration` skill 的狀態隔離邊界表）
- `.claude/hooks/lib/merge-gate.sh` — 既有的 lib 拆法範例，照它的風格寫
- `.claude/hooks/post-agent-report.sh` 的 pending 掃描迴圈（第 122-148 行）

## 階段拆解

### 階段 1: `lib/handoff-archive.sh` ⏳

- [ ] 掃 `$MAIN_CLAUDE/coordination/handoffs/*.md`，跳過 `_HANDOFF_TEMPLATE.md`
- [ ] `status:` 含 `completed` 或 `cancelled` → 搬到 `archive/YYYY-MM/`
      （YYYY-MM 取自檔案 frontmatter 的 `date:`，抓不到才用 `mtime`）
- [ ] 目標已存在同名檔 → 加 `-2` 後綴，**絕不覆蓋**（審計軌跡不能被吃掉）
- [ ] 任何一步失敗都靜默跳過該檔（hook 不能因為歸檔失敗就中斷主流程）
- **預估**：40min
- **驗收**：手動建 3 個假 handoff（pending／completed／cancelled）跑一次，
  只有後兩個被搬走且內容一字不差

### 階段 2: 接進 `post-agent-report.sh` ⏳

- [ ] 在 pending 掃描**之前** source 並呼叫（先歸檔再掃，當次就受益）
- [ ] 尊重既有逃生門：`.suggest-mode` = off 時**不歸檔**（該檔已是文件化的總開關）
- [ ] `archive/` 子目錄不能被 pending 掃描的 `for f in "$HANDOFF_DIR"/*.md` 撈到
      （glob 不遞迴，確認即可）
- **預估**：20min
- **驗收**：`bash .claude/hooks/tests/run-tests.sh` 既有 190 案例全綠

### 階段 3: 文件與測試 ⏳

- [ ] `_HANDOFF_TEMPLATE.md` 末行「完成後不刪除」改成「完成後改 status，hook 會自動歸檔到
      `archive/YYYY-MM/`」
- [ ] `coordination/README.md` 補目錄結構與「查看待處理」的指令（archive 不在掃描範圍）
- [ ] `run-tests.sh` 加案例：completed 被搬、pending 留下、同名不覆蓋、`.suggest-mode=off` 不動
- **預估**：40min
- **驗收**：新案例全綠，且**做負向測試**（故意讓歸檔搬錯目錄，確認測試會紅）

### 階段 4: `post-agent-report.sh` 的 `AREA` 對應表補 `skill-curator` ⏳

第 49-59 行的對應表只涵蓋 11 個 agent。`skill-curator` 被歸為「會寫報告」那一類，
但沒有對應項 → **稽核永遠找不到它的報告**。這正是 CLAUDE.md「連帶檢查」明文警告的坑，
v5.6 加 agent 時漏了。

- [ ] 補 `skill-curator` 的 `AREA`（`decisions` —— 它的產出是擴充決策與盤點結果）
- [ ] 同時檢查 `conflict-resolver` 該不該有對應項：它的 `tools:` **沒有 `Write`**，
      機制上寫不了報告檔，所以**不該**加。確認後在該表留一行註解說明為什麼刻意不列
- **預估**：20min
- **驗收**：對應表涵蓋的 agent 集合與「會寫報告」那一類完全一致，且有測試釘住

### 階段 5: `pre-agent-gate.sh` 的誤報 ⏳

**症狀**：閒置超過 60 分鐘後的第一次委派**必被擋一次**。deny-once 讓它看起來
只是「擋一下就過」，所以放了很久沒被發現。第一輪壓力測試的受測 session 自己撞到並回報。

**根因**：`settings.json` 的 PreToolUse 把 `agent-monitor.sh` 排在 `pre-agent-gate.sh`
**前面**，於是 `agent_start` 先被寫進 `agent-activity.jsonl`，閘門再算 in-flight 時
**把它正在把關的這一次也算進去**。

- [ ] **優先做順序無關的修法**：閘門從 INPUT 取本次的 `tool_use_id`，算 in-flight 時排除它。
      這樣不管兩支 hook 誰先跑都正確
- [ ] 先確認 PreToolUse 的 INPUT 真的帶 `tool_use_id`（實測，不要假設）。
      **若沒有**，退回改 `settings.json` 的 hook 順序，並在兩支 hook 的檔頭都註明
      「順序有意義，不要調換」——否則下次有人重排又壞
- [ ] 不要用「in-flight ≥ 2 才擋」這種調門檻的方式繞過：那會讓真正的兩個並行漏掉第一次
- **預估**：45min
- **驗收**：新增測試涵蓋「只派一個 agent 時不擋」（這是現在會誤報的情境）與
  「真的有一個在跑時擋第二個」。**負向測試**：把修法還原確認新測試會紅

## 風險與緩解

| 風險 | 影響 | 緩解 |
|---|---|---|
| 歸檔搬檔失敗導致 hook 中斷 → 每次 agent 結束都出錯 | HIGH | 每個動作都 `|| true`，失敗靜默跳過 |
| 調 hook 順序修誤報 → 下次有人重排又壞 | MEDIUM | 優先做順序無關的修法；真要靠順序就在兩支檔頭都註明 |
| worktree 內執行時搬到 worktree 的 handoffs | MEDIUM | 強制走 `MAIN_CLAUDE`，不用 `WORK_CLAUDE` |
| 覆蓋掉同名歸檔檔案 → 審計軌跡消失 | HIGH | 目標存在就加後綴，絕不覆寫 |

## 驗收標準（整體）

- [ ] 五階段全 ✅
- [ ] `run-tests.sh` 全綠且新案例做過負向測試
- [ ] `bash scripts/check-counts.sh` 無新增問題（**約 50 秒，timeout 不要設太緊**）
- [ ] 不動 `files:` 以外的任何檔案

## 邊界（本任務不做）

- 不改 handoff 的 frontmatter 欄位定義
- 不動 `context/` 的報告歸檔（那是另一件事）
- 不碰 `scripts/check-counts.sh`
