# skill-curator 報告：階段 9 hook（2026-10-16）

計畫：`.claude/taskmaster-data/plans/adhoc-2026-10-16-frontend-style-library.md` 階段 9

## 改了什麼

| 檔案 | 變更 |
|---|---|
| `.claude/hooks/user-prompt-submit.sh` | D10：`ui`／`css` 前後不能是英文字母；加 `網站|官網|landing|形象頁|一頁式|首頁|版型|配色|字型` |
| `.claude/hooks/lib/ui-lint.sh` | 新增。寫死色碼、motion 等級不符、AI 痕跡 P0（C6／C1／K1） |
| `.claude/hooks/post-write.sh` | 呼叫 ui-lint；與文件影響提醒同時命中時合併成一則 JSON（`finish_with`） |
| `.claude/hooks/session-start.sh` | 「是不是模板 repo」＝`scripts/sync-ui-sources.sh` 存在；設計走向提醒改成只在模板 repo 出現（決定 3）、「2.6 節」改指 `anti-ai.md`；新增上游同步 90 天提醒 |
| `.claude/hooks/README.md` | 結構樹加 `lib/ui-lint.sh`；功能表補 session-start、user-prompt-submit、post-write ③ |
| `.claude/hooks/tests/run-tests.sh` | 新增 D10、ui-lint、模板 repo 判斷三組案例（含真的跑 `copy-template.sh` 的反向測試與對照組） |
| `.claude/ui/_licenses/avoid-ai-design.txt` | MIT 原文（commit `2b7c718`） |
| `.claude/tests/skill-compliance/prompts/10-landing-page.txt` | 「幫我做一個咖啡店的形象網站」 |

## avoid-ai-design 掃描器評估（給階段 11 的 ADR）

上游 `scripts/detect.mjs`（v0.4.0）實作了約 40 條規則（目錄 `ai-tells-catalog.md` 有 67 條，其餘本來就需要看截圖），其中 P0 六條：

| ID | 規則 | 裁決 | 理由 |
|---|---|---|---|
| C6 | 漸層填色的標題字 | 收 | `bg-clip-text`＋`text-transparent`／`background-clip: text`＋透明字色，字面比對就準 |
| C1 | 紫／靛藍漸層 | 收 Tailwind 那半 | class 名字面比對準；CSS 那半要把色碼轉 HSL 判色相，bash 做不準 |
| K1 | 沒改過的 shadcn 主題 | 收 | `--primary` 的四種預設值是字面字串，最準 |
| T1 | Inter 當主字型 | 不收 | 風格庫 69 份有 26 份的 DESIGN.md 本身就指定 Inter，照風格寫反而被叫 |
| L1 | 膠囊徽章＋置中 hero | 不收 | 要看 `<h1>` 前 900 字的結構和 CSS 規則對應，grep 會亂叫 |
| L2 | 三張圖示卡 | 不收 | 同上，要解析 CSS 規則找出圖示 chip 的 class |

計畫舉的例子「全大寫 eyebrow 配 →」（上游 SD4／CP3）、「cream＋terracotta」（SD1）在上游都是 **P1**，照決定 2「只挑 P0」不收。
上游的豁免語法（`avoid-ai-design-ignore: <ID>`、`avoid-ai-design-ignore-file`）照搬，規則 ID 沿用。

## 判斷「是不是模板 repo」

用 `scripts/sync-ui-sources.sh` 存在與否（計畫指定）。四份 copy／update 腳本都排除它。
測試除了沙箱的正反案例，還真的跑一次 `copy-template.sh` 建新專案、開 session 驗證兩種提醒都不出現，
並在同一個新專案補上那支腳本當對照組，證明反向測試不是空跑。

## PostToolUseFailure

ui-lint 只接 PostToolUse。寫檔失敗時磁碟內容沒變、沒有新東西可檢查，所以刻意不接；理由寫在 `ui-lint.sh` 開頭與 post-write.sh 該節。

## 壓力測試第 10 題（2026-10-16 13:07，單輪）

在 `copy-template.sh` 建出來的範例專案（scratchpad，無 git、無 `src/`）跑 `run-compliance.sh 10`。
受測 session 沒有直接開工，而是：判 standard、說要等資料後委派 ui-builder、
引用「不准自己編這些事實，所以整頁會變成一堆 `【待提供】`」、推薦先跑 `/ui-style`「看三個方向的預覽」，另列「貼網址抽風格」。
這些內容只存在於 `ui-style-compliance`／`ui-builder.md`／`/ui-style`，所以判定**行為符合**。
限制：單輪（pass@3 未跑）；`-p` 看不到工具呼叫，「載入了 skill」是從輸出內容推斷；
prompt 含「網站」，關鍵字路由和 description 分不出是哪條召喚的。結果目錄在 scratchpad，不會留下。

## 驗證

- `bash .claude/hooks/tests/run-tests.sh`：479 通過、0 失敗
- `bash scripts/check-counts.sh`：520 項全部一致；`--tests 479` 時只剩三處文件的測試數（WORKFLOW、tests/README、根 README 目錄樹，目前寫 410）不一致，依指示留給主模型

## 沒改、要主模型處理的

- 測試數（根 `README.md`、`CLAUDE.md`、`guides/WORKFLOW.md`、`hooks/tests/README.md`、`writing-extensions`）
- `.claude/tests/skill-compliance/README.md` 的 prompt 表沒有第 10 題（不在本階段 `files:`）
- `.claude/agents/skill-curator.md` 第 152、199 行仍寫「跨風格通用 → `ui-style-compliance` 的 2.6 節」，跟 session-start 的新指向不一致（不在本階段 `files:`）
