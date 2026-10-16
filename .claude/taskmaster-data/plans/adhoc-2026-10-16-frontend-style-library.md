---
wbs_task: "none"
slug: "frontend-style-library"
created: "2026-10-16"
updated: "2026-10-16"
status: "⏳ 未開始"
current_phase: 0
mode: "standard"
files:
  # 階段 1：順手修的小問題
  - ".claude/commands/verify.md"
  - ".claude/hooks/lib/cmd-segments.sh"
  - ".claude/hooks/post-bash.sh"
  - ".claude/hooks/post-agent-report.sh"
  - ".claude/hooks/tests/run-tests.sh"
  # 階段 2：授權與來源 metadata
  - ".claude/ui/_licenses/**"
  - ".claude/ui/_sources.json"
  - ".claude/ui/*/SOURCE.json"
  - "scripts/check-counts.sh"
  # 階段 3：品牌候選調查（只寫調查報告）
  - ".claude/context/decisions/**"
  # 階段 4、5：ui-style-compliance 收斂與附屬檔
  - ".claude/skills/ui-style-compliance/SKILL.md"
  - ".claude/skills/ui-style-compliance/anti-ai.md"
  - ".claude/skills/ui-style-compliance/motion.md"
  - ".claude/skills/ui-style-compliance/fonts-cjk.md"
  - ".claude/agents/skill-curator.md"
  - ".claude/agents/ui-builder.md"
  - ".claude/commands/ui-page.md"
  - ".claude/ui/CATALOG.md"
  # 階段 6：指令
  - ".claude/commands/ui-style.md"
  - ".claude/commands/ui-site.md"
  # 階段 8：同步腳本
  - "scripts/sync-ui-sources.sh"
  - "scripts/sync-ui-sources.test.sh"
  - "scripts/copy-template.sh"
  - "scripts/copy-template.ps1"
  - "scripts/update-template.sh"
  - "scripts/update-template.ps1"
  # 階段 9：hook
  - ".claude/hooks/user-prompt-submit.sh"
  - ".claude/hooks/post-write.sh"
  - ".claude/hooks/lib/ui-lint.sh"
  - ".claude/hooks/session-start.sh"
  - ".claude/hooks/README.md"
  - ".claude/tests/skill-compliance/prompts/**"
  # 階段 10：匯入
  - ".claude/ui/jp-*/**"
  - ".claude/ui/omd-*/**"
  - ".claude/ui/<VoltAgent 新增的 codename>/**"
  - "README.md"
  - ".claude/README.md"
  # 階段 11：整合
  - "CLAUDE.md"
  - ".claude/context/decisions/FIXED-LOG.md"
---

# 實作計畫：前端定調、動畫分級、反 AI 感與多來源風格庫

## 目標

做完之後，使用者跑 `/ui-style` 會多三條路可走：看三個方向的預覽挑一個、用 Claude Design 定調、
貼喜歡的網站網址抽風格。同一題流程裡也會問一次「動畫要多少」（L1／L2／L3）。
`ui-builder` 寫程式前後都會對照同一份反 AI 感清單；查不到的事實一律留 `【待提供：…】`，不再自己編；
產出後在 390 與 1440 兩種寬度截圖自查。風格庫補上授權檔和來源紀錄，有一支只預覽、
不覆蓋本地修改的同步腳本，並新增日本與台灣的非科技業品牌。

## WBS 連結

- ad-hoc，沒有 WBS 任務。完成後 `/verify` 會問要不要用 `/task-add` 補登
- 分支：`feat/frontend-style-library`（已開）
- 總預估：約 27h。**比 standard 一般的 1～4h 大很多**，建議分三批合併（見「實作順序」）

## 依據

- `.claude/context/decisions/skill-curator-2026-10-15-1530-frontend-gmap-analysis.md`（下稱「比對報告」，D1～D10）
- `.claude/context/decisions/skill-curator-2026-10-15-1510-ui-sources.md`（下稱「來源報告」）
- `D:\wei\sunny_課程\landingpage_design_demo\.claude\skills\gmap-landing-page\SKILL.md`（下稱 gmap）

## 技術依賴與已知事實

- **AskUserQuestion 的 `preview` 欄位**：使用者已確認 Claude Code 支援（只能用在單選題）
- **Claude Design**：Anthropic Labs 的 research preview，入口 claude.ai/design；Claude Code 端的 `/design`、`/design-sync`
  需要 v2.1.265 以上。官方沒有交接包格式的說明 → 轉寫時**以實際收到的內容為準**
- **firecrawl MCP**：`.mcp.json.*.example` 已經有了；用 `firecrawl_scrape` 的 `branding` 與 `screenshot` 格式。
  參數要先查 firecrawl 文件確認，不要憑記憶寫
- **Playwright MCP**：`.mcp.json.*.example` 已經有了。ui-builder 目前的 `tools:` 沒有它
- **context7**：動畫函式庫的 API 細節交給它查，`motion.md` 不寫版本號
- **上游**：VoltAgent/awesome-design-md（MIT，格式正在改成 Google DESIGN.md 規格）、kzhrknt/awesome-design-md-jp（MIT，舊版 9 節格式）、
  kwakseongjae/oh-my-design（MIT，omd-v3 格式）。用 `gh api` 抓
- **參考做法**：commit `d4e6f78`（2026-07-24，用 firecrawl 從實際網站抽出 10 份）。階段 6 動工前先 `git show d4e6f78 --stat`，再讀其中一份（例如 `.claude/ui/attio/DESIGN.md`）
- **授權**：VoltAgent／jp／omd／avoid-ai-design 都是 MIT，要附原文；Anthropic frontend-design 是 Apache-2.0。
  後者只改寫重點並附出處，**不整段複製**（整段複製就要附 NOTICE）

## 落層判斷（依 `writing-extensions` 決策表）

| 項目 | 層 | 理由 |
|---|---|---|
| 寫死色碼、L1 卻 import 動畫庫 | Hook（PostToolUse，`post-write.sh` → `lib/ui-lint.sh`） | 寫檔當下程式判斷得出來。現在只靠 ui-builder 自己 grep |
| `ui` 子字串誤觸發、網站／landing／形象頁漏接 | Hook（`user-prompt-submit.sh`） | 本來就是關鍵字路由 |
| 風格庫超過 90 天沒同步 | Hook（`session-start.sh` 既有的 ② 提醒） | 有明確的時間點；擴充既有提醒，不另外開一個 |
| quick 模式的 debug-investigator 報告假警報 | Hook（`post-agent-report.sh`） | 稽核本身判斷錯了，要改稽核，不是去要求 agent 多寫報告 |
| 反 AI 感、動畫分級、繁中字型 | Skill 附屬檔（`ui-style-compliance/*.md`） | 只有寫前端時才需要。L2／L3 才讀 `motion.md` |
| 三條定調路徑、動畫問題、退件迴圈 | Command（`/ui-style`、`/ui-page`） | 使用者主動叫的流程 |
| 截圖驗收、不准編事實 | Agent（`ui-builder`） | 它負責產出，「不讓人跳步」是它存在的理由 |
| 同步腳本 | `scripts/`，只給模板維護者用 | 不進新專案 |

---

## 階段拆解

### 階段 1：順手修的 3 個 hook／指令小問題（G1、G2、G4） ⏳

> G3（skill-curator 要求它沒有的 AskUserQuestion）放到階段 4，因為那一階段本來就要改 `skill-curator.md`。

- [ ] **G1**：`/verify` 的「0a. 合併驗證關卡」搬出「任務完成銜接」（那一節前提是有 `.current-task`），
      改成獨立一節「合併驗證（不論有沒有進行中任務）」。沒有任務時只做 0a 的第 2、3 步（收斂檢查、通過就刪清單）；
      第 1 步「比對每個已合併任務的 plan」改成有 plan 才做（`.claude/commands/verify.md`）
- [ ] **G2 先重現**：從 `.claude/logs/hooks.log` 找出寫進 `[merge] 結束碼非` 的那筆紀錄，和當時的 commit 指令。
      **先寫一條會失敗的測試**，用一模一樣的指令形狀（`git commit -m "$(cat <<'EOF' … EOF)"`，內文含「衝突的 merge 結束碼非 0」）
- [ ] **G2 修正**（`.claude/hooks/lib/cmd-segments.sh`）：切段前先拿掉 heredoc 內文（`<<[-]?['"]?WORD['"]?` 到單獨一行的 `WORD`）。
      子指令比對只看 `git` 後面第一個非選項字（跳過 `-C <路徑>`、`-c <k=v>`、`--no-pager`），不再看整段任何位置。
      `git-backup-gate.sh` 和 `post-bash.sh` 共用這支，**只改這一份**
- [ ] **G4**（`.claude/hooks/post-agent-report.sh`）：`debug-investigator` 啟動當下，如果 `$WORK_CLAUDE/taskmaster-data/.current-task-mode` 是 `quick`，
      就不記報告期望（`AREA=""`），並在 log 寫一行 `SKIP: debug-investigator quick 模式不寫報告`
- [ ] 在 `run-tests.sh` 加對應測試
- **預估**：2h
- **files**：`.claude/commands/verify.md`、`.claude/hooks/lib/cmd-segments.sh`、`.claude/hooks/post-bash.sh`（只在必要時改）、`.claude/hooks/post-agent-report.sh`、`.claude/hooks/tests/run-tests.sh`
- **驗收**：
  - commit 指令用 heredoc 帶訊息、內文含「衝突的 merge 結束碼非 0」→ 執行後 `.merge-pending` 不存在或是空的
  - 同一形狀但內文含 `git reset --hard` → `git-backup-gate` 不擋
  - `git merge feature/x` → `.merge-pending` 有一行 `[merge] feature/x`（既有測試繼續通過）
  - `git -C /some/path merge feature/x` → `.merge-pending` 有一行 `[merge] feature/x`
  - `.current-task-mode` 是 `quick` 時同步派 `debug-investigator`、而且沒寫報告 → `context-reports.log` **沒有** `WARN: debug-investigator`，有 `SKIP:` 那一行
  - 同樣情境但模式是 `standard` → 仍寫 `WARN: debug-investigator completed but no report`
  - 非同步派 `debug-investigator`、模式是 `quick` → `.report-expectations.jsonl` 沒有新增 `debug-investigator` 那一列
  - （人工）沒有 `.current-task`、`.merge-pending` 有一筆、驗證 PASS → 跑 `/verify` 後清單被刪掉；驗證 FAIL → 清單保留
  - `bash .claude/hooks/tests/run-tests.sh` 全部通過
- **注意**：寫測試時如果內文提到 `git merge`，可能被**還沒修好的閘門**擋下（`context/learned/2026-09-11-gate-blocks-its-own-fix.md` 那一次一樣）。
  被擋就單次加 `MERGE_GATE=off`，不要繞路改測試內容

### 階段 2：授權檔、來源 metadata、CATALOG 檢查修正（F 的一部分） ⏳

- [ ] 建 `.claude/ui/_licenses/voltagent-awesome-design-md.txt`（上游 LICENSE 原文，`gh api` 抓，不要手打）
- [ ] 建 `.claude/ui/_sources.json`：每個來源一筆 `{id, repo, ref, path_pattern, license, license_file, format, prefix, last_synced}`。
      先登記 `voltagent`、`jp`、`omd`、`self-extracted` 四筆；jp／omd 的 `last_synced` 先填 `null`
- [ ] 為現有 69 個風格目錄各寫一份 `SOURCE.json`，欄位照來源報告 5.2，**再加 `imported_sha256`**
      （匯入當下 DESIGN.md 的 sha256；有沒有本地修改由腳本比對 hash 算出來，不信任手填的旗標）
  - 58 份 VoltAgent：找出上游在該目錄 `imported_at`（用 git log 查本地第一次 commit 的日期）**當天或之前**最近的 commit，
    比對 hash。相同就填 `upstream_commit` 和 `locally_modified: false`；不同就填 `locally_modified: true`、`local_changes: "與 <commit> 不一致，原因未記錄"`
  - `semrush`：`upstream_status: "removed"`，本地保留（標示方式待使用者確認，見文末決定 4）
  - 10 份自己抽的：`source: "self-extracted"`、`upstream_repo: null`、`extraction_method: "firecrawl"`、`imported_at: "2026-07-24"`
- [ ] 修 `scripts/check-counts.sh` 的 UI 檢查：`_` 開頭的目錄**連 DESIGN.md 都不檢查**（現在 `_licenses/` 會被報「缺 DESIGN.md」）。
      另外加兩項：非 `_` 的風格目錄要有 `SOURCE.json`；DESIGN.md 要找得到「配色」和「字型」兩個段落，新舊標題都算
      （別名清單照階段 4 的對照表，在 check-counts 的註解寫明「唯一來源是 `ui-style-compliance` 1.2 節」）
- **預估**：2.5h
- **files**：`.claude/ui/_licenses/**`、`.claude/ui/_sources.json`、`.claude/ui/*/SOURCE.json`、`scripts/check-counts.sh`
- **驗收**：
  - `bash scripts/check-counts.sh` → 0 個 ✗，而且**不會**出現「UI 風格缺 DESIGN.md：_licenses」
  - 暫時刪掉 `.claude/ui/apple/SOURCE.json` 後跑 check-counts → 出現一行 ✗ 指出 apple 缺 SOURCE.json（驗完還原）
  - 暫時把某份 DESIGN.md 的 `## 2. Color Palette & Roles` 改成 `## Palette` → check-counts 報那份找不到配色段落（驗完還原）
  - `jq -e . .claude/ui/*/SOURCE.json` 全部可以解析；`jq -r .source` 的值只會是 `voltagent`／`self-extracted`
  - `semrush/SOURCE.json` 的 `upstream_status` 是 `removed`
  - `.claude/ui/_licenses/voltagent-awesome-design-md.txt` 第一行含 `MIT License`，內文含 `Copyright (c) 2026 VoltAgent`

### 階段 3：匯入品牌候選清單（只調查，**做完停下來給使用者挑**） ⏳

- [ ] VoltAgent 新增的 26 份：每份記下格式（舊 9 節／google-alpha）、產業、繁中一句話；**標出推薦的 6～10 份**
      （來源報告建議 starbucks、wired、theverge、aljazeera、mastercard、oura、nike、shopify）
- [ ] jp：從非科技類挑 20～25 份候選（茶舖、咖啡、和菓子、工藝、雜誌、精品、旅館），每份查
      Colors 節有幾個色、有沒有實測日期、字型是什麼；**推薦 10～15 份**
- [ ] omd：從台灣品牌和非科技國際品牌挑 20～25 份候選，**先確認 Colors 節夠用**（誠品只有電商區塊色票，這種要標出來）；**推薦 10～15 份**
- [ ] 「溫暖手作」類只列實際網站的品牌（例如一保堂、中川政七商店、pinkoi），**不列**通用的 cafe／terracotta 風格
- [ ] 每份候選都標出它會不會撞到 `anti-ai.md` 點名的 AI 痕跡（米白底＋襯線＋陶土色）。會撞的不是不能收，但要標出來
- [ ] 寫成一份報告 `.claude/context/decisions/skill-curator-<時間>-ui-import-candidates.md`（由 skill-curator 寫，主模型拿去問使用者）
- **預估**：2h
- **files**：`.claude/context/decisions/**`（只新增一份報告）
- **驗收**：
  - 報告有三張表（voltagent／jp／omd），每列都有：codename（含前綴）、產業、繁中一句話、格式、Colors 節色數、AI 痕跡風險、推薦（是／否）
  - jp 和 omd 推薦數各在 10～15 之間
  - 沒有任何一列是科技／SaaS 類，除非在備註寫了理由
  - **主模型用 AskUserQuestion（multiSelect）讓使用者挑，挑完才可以開始階段 10**

### 階段 4：`ui-style-compliance` 收斂與修正（E：D1、D3、D4、D5、D7、D8；G3） ⏳

- [ ] **D1／D7**：合規自檢清單只留 `SKILL.md` 階段 3 那一份（唯一來源）。`ui-builder.md` 第 127～147 行、`ui-page.md` 第 183～198 行改成一句指標
      「自檢清單見 `ui-style-compliance` 階段 3（唯一來源，勿在此重述）」。斷點統一寫法：
      **必截圖 390、1440；768、1024 只檢查沒有水平捲軸；CSS 斷點照 DESIGN.md 或框架預設**。ui-builder 原則 4 的 640／1024 改成指向這一條
- [ ] **D3**：1.2 節 mixed 對照表改成同時認新舊標題（比對時忽略前面的編號，例如 `## 2. `）：

  | overrides | 認這些標題（任一） |
  |---|---|
  | `color` | `Color Palette & Roles`、`Colors` |
  | `typography` | `Typography Rules`、`Typography` |
  | `components` | `Component Stylings`、`Components` |
  | `layout` | `Layout Principles`、`Layout` |

  拿掉 `animation` 列（動畫改成頂層的 `motion`，見階段 6）。主風格找不到某個段落時要**明說**「<codename> 沒有 <段落>，沿用主風格」，不能默默略過。
  `CATALOG.md` 的「Metadata 欄位」表和 `skill-curator.md` 第 166～168 行的標題清單同步改（這兩處目前寫的都是不存在的標題）
- [ ] **D4**：深色模式只在 DESIGN.md 有定義、或使用者要求時才做。Fallback 的「必須支援」改成「token 用語意命名，之後要加深色模式不必改元件」；自檢項目跟著改
- [ ] **D5**：「150～300ms」只限 UI 微互動（hover、focus、展開收合），並註明捲動連動的動畫不受這條限制（細節在 `motion.md`）
- [ ] **D8**：2.6② 加一條「不准編事實」：價格、營業時間、電話、得獎、年份、評論、客戶名，查不到就留 `【待提供：<項目>】`，並列進回報的「開放問題」。
      `ui-builder.md` 紅旗第一條改成「編造事實（價格、評論、數據、客戶名）來填版面」
- [ ] **G3**：`skill-curator.md` 約第 176 行「用 `AskUserQuestion` 問三題」改成「回 `NEEDS_CONTEXT`，列出三題和建議的預設答案，由主模型問」。
      `ui-style.md` 路徑 E 的對應句子在階段 6 一起改
- [ ] `skill-curator.md` 第 139、152、157 行的「68」改成實際數字
- **預估**：2h
- **files**：`.claude/skills/ui-style-compliance/SKILL.md`、`.claude/agents/ui-builder.md`、`.claude/commands/ui-page.md`（只動自檢段落）、`.claude/ui/CATALOG.md`（只動 Metadata 表）、`.claude/agents/skill-curator.md`
- **驗收**：
  - `grep -c '^- \[x\]' .claude/agents/ui-builder.md .claude/commands/ui-page.md` → 兩檔都是 0
  - `grep -n '640px' .claude/agents/ui-builder.md` → 沒有結果
  - `grep -n 'Spacing / Grid / Section Rhythm\|Buttons / Cards / Inputs' .claude/skills/ui-style-compliance/SKILL.md .claude/ui/CATALOG.md .claude/agents/skill-curator.md` → 沒有結果
  - `grep -n '必須支援' .claude/skills/ui-style-compliance/SKILL.md` → 沒有結果
  - `grep -n 'AskUserQuestion' .claude/agents/skill-curator.md` → 只剩「回 NEEDS_CONTEXT 由主模型問」的語境，沒有「用 AskUserQuestion 問」的指示
  - `grep -n '有意義的示意文案' .claude/agents/ui-builder.md` → 沒有結果；`grep -n '【待提供' .claude/skills/ui-style-compliance/SKILL.md` → 至少 1 行
  - 照新對照表，用 `airbnb`（舊 9 節）和一份 google-alpha 格式的檔案各抽一次 color 段落 → 兩份都抽得到非空內容（用 `awk` 實測，貼在 PR 說明）
  - `bash scripts/check-counts.sh` → 0 個 ✗

### 階段 5：三份附屬檔（C 反 AI 感、B 動畫、D 繁中字型） ⏳

- [ ] **`anti-ai.md`**（新增）：把 SKILL.md 的 2.5 和 2.6 ①②⑤⑥ 搬過來（SKILL.md 改成指標），再整合兩個來源：
  - Anthropic frontend-design 的 5 種集群，**第 1 種寫在最前面**：米白底（約 #F4F1EA）＋高對比襯線標題＋陶土色強調（約 #D97757）
  - avoid-ai-design 的 P0／P1 項目，以及「有品味的預設」名單（cream＋terracotta、Space Grotesk、Geist、Instrument Serif、Fraunces）
  - 分成「產出前（挑方向、挑字型時）」和「產出後（自檢時）」兩張表
  - 例外規則：選定的 DESIGN.md 明確要求的不算違規（`claude`、`perplexity`、`zed`、`granola` 這幾份**本身就是**米白、襯線路線，要寫明）
  - 檔尾附出處：兩個上游的網址、授權、抓取日期。只改寫，不整段複製
- [ ] **`motion.md`**（新增）：L1／L2／L3 各自允許的技術、效能預算、`prefers-reduced-motion` 時怎麼降級、
      動畫參數集中成 CONFIG／motion tokens（併進 2.1 的 token 概念）、函式庫速查與常見坑（例如 Lenis 搭 ScrollTrigger 要同步捲動事件）。
      SKILL.md 2.6③④ 改成指標。**只在 `motion` 是 L2／L3 時才讀**（SKILL.md 寫明）
- [ ] **D6**：`motion.md` 裡的瀏覽器支援度（scroll-driven animations、View Transitions）**先查 MDN 或 caniuse 再寫**，每一條附來源網址和查證日期。
      不寫 API 細節和版本號，寫「用 context7 查當前版本」
- [ ] **`fonts-cjk.md`**（新增）：繁中字型清單（候選：Noto Sans TC、Noto Serif TC、LXGW WenKai TC、Iansui、Huninn、Chiron Sung HK、Chiron Hei HK、Cactus Classical Serif），
      **每一個都到 fonts.google.com 查證有沒有**，附查證日期；查不到的就刪掉。另外寫：
      中英搭配建議（每組附氣質描述，並標出哪些屬於 anti-ai.md 點名的「有品味的預設」）、`display=swap` 與 `text=` 子集、
      系統字型堆疊（PingFang TC、Microsoft JhengHei）、行距字距與 `line-break: strict`、
      **jp 風格的日文字型要換成什麼繁中字型**的對照表（這張表在這裡寫一次，jp 的 DESIGN.md 一份都不改）
- [ ] SKILL.md 階段 1 加「載入附屬檔」規則：`anti-ai.md` 一律讀；`motion.md` 只在 L2／L3 讀；`fonts-cjk.md` 在專案語言含繁中時讀
- [ ] 階段 3 自檢清單加兩項：「已逐項對照 anti-ai.md 產出後清單」「事實欄位沒有編造，缺的都標了【待提供】」
- **預估**：3h
- **files**：`.claude/skills/ui-style-compliance/SKILL.md`、`anti-ai.md`、`motion.md`、`fonts-cjk.md`
- **驗收**：
  - `grep -n '#F4F1EA\|陶土' .claude/skills/ui-style-compliance/anti-ai.md` → 至少 1 行，而且出現在第一張表
  - `anti-ai.md` 有「產出前」和「產出後」兩個段落標題；檔尾有兩個上游網址和授權名稱
  - `grep -nE '[0-9]+\.[0-9]+\.[0-9]+|v[0-9]+' .claude/skills/ui-style-compliance/motion.md` → 沒有函式庫版本號
  - `motion.md` 每一條瀏覽器支援度的敘述都附 `developer.mozilla.org` 或 `caniuse.com` 網址和日期
  - `fonts-cjk.md` 的字型表每一列都有「查證日期」欄，而且有值
  - SKILL.md 的行數比改之前少（2.5、2.6 搬出去了）；`grep -n 'anti-ai.md\|motion.md\|fonts-cjk.md' SKILL.md` 三個檔名都找得到
  - 使用者在 `/ui-style` 看到的動畫選項文字裡**沒有**任何函式庫名（這條在階段 6 驗）

### 階段 6：`/ui-style` 三條新路徑、動畫分級問題；`/ui-page`、`/ui-site` 配合（A、B、D 的退件格式） ⏳

- [ ] **入口題**改成：**看預覽選（Recommended）**／單一風格／混搭／用 Claude Design 定調／貼網址抽風格／從現有程式碼反推／瀏覽目錄。
      選項超過 4 個時拆成兩層（AskUserQuestion 一題最多 4 個選項）：第一層「讓我推薦（看預覽選）／我自己挑（單一、混搭、目錄）／我有參考來源（Claude Design、網址、現有程式碼）」
- [ ] **網站類型題**（新）：先讀 `docs/17_*`、`docs/00_brief.md`、`ui-style.json` 推斷，推斷不出來才問。
      選項和 `/ui-site` Q1 一致，另外加「品牌形象頁／在地店家」。寫進 `ui-style.json` 的 `site_type`；`/ui-site` Q1 有值就預先帶入
- [ ] **路徑：看預覽選**：主模型依專案提 3 個方向，每個方向的 `preview` 有：方向名、一句話概念、4～5 個 hex 色票、
      至少 3 行的 ASCII 版面示意、對應的 CATALOG codename（單一，或主風格加覆蓋）。
      **對應的 codename 必須存在於 `.claude/ui/`**；提方向前先讀 `anti-ai.md` 的「產出前」表，避開被點名的組合，除非專案本身就是那個路線。
      選定後照 codename 寫成 `mode: single` 或 `mixed`
- [ ] **路徑：Claude Design**：先跑 `claude --version`，低於 2.1.265 就說明要升級並退回入口題。
      夠新的話，一步一步帶使用者：開 claude.ai/design → 從 codebase、品牌素材或既有網站建設計系統（並提醒：沒有設計系統時，官方說產出「可用但通用」）→
      看畫面微調 → Export → Hand off to Claude Code → 收下交接內容。**交接包格式查不到官方說明，轉寫時以實際收到的內容為準**，
      對應不上的欄位留 `【待確認】`。寫成 `_project/DESIGN.md`，`notes` 記 `source: claude-design`
- [ ] **路徑：貼網址**：使用者直接輸入 1～3 個網址 → 每個網址用 `firecrawl_scrape` 取 `branding`＋`screenshot` →
      把截圖給使用者看，問「是不是這個感覺」（是／不是，換一個網址／這個不要）→
      多個網址時，逐項問配色、字型、元件、版面各取哪一個 → 寫成 `_project/DESIGN.md`。
      **只取風格**（色票、字型、圓角、陰影、間距），不搬 logo、圖片、文案；檔頭記來源網址與抽取日期，信心分級照路徑 E。
      **抽不到時的退路**依序：沒裝 firecrawl 或回傳沒有 branding → Playwright MCP 用 `getComputedStyle` 讀 body、h1、button、a →
      都不行就請使用者上傳截圖，色票標「目測，低信心」
- [ ] **共用「轉寫成 `_project/DESIGN.md`」一節**：段落標題用階段 4 對照表的新格式標題；E／Claude Design／網址三條路徑都指向這一節（唯一來源）。
      已經有 `_project/DESIGN.md` 時先問「覆蓋／取消」
- [ ] **路徑 E 修正（配合 G3）**：skill-curator 回 `NEEDS_CONTEXT` 帶三題 → 主模型逐題問 → 再派一次 skill-curator 把答案補進去
- [ ] **動畫題**（每條路徑都問，在確認題之前）：L1 安靜／L2 有節奏／L3 沉浸。每個選項的描述寫「感覺＋像什麼＋適合誰＋代價」，**不出現函式庫名**。
      依 `site_type` 推薦：管理後台、文件站推薦 L1，**而且不提供 L3**；品牌形象頁／在地店家／作品集推薦 L2；其他推薦 L1
- [ ] **`ui-style.json`**：`version` 改成 `"1.1"`；加頂層 `motion`、`site_type`、`source`（`catalog`／`preview`／`claude-design`／`url`／`code-scan`）；
      `overrides` 拿掉 `animation`。**相容舊檔**：沒有 `motion` 就當作 L1 並提示可以重跑；有 `overrides.animation` 就忽略並提示一次
- [ ] **2A-2a、2A-2b 的分類清單**：先保留現有的，非科技業分類等階段 10 匯入後再加（避免列出還不存在的 codename）
- [ ] **`/ui-page`**：2.1 第 3 題「動畫程度」改成「沿用專案設定（L?）／這一頁另外調」，選另外調時再問 L1／L2／L3（同樣依 `site_type` 限制）；
      頁面層的等級寫進 IA snippet 的「動畫等級」
- [ ] **`/ui-page` 驗收迴圈**（新增 4.5）：改成一段一段派 ui-builder（先做 hero）。每段回來後給使用者看 390／1440 截圖，問「這段可以嗎？」（可以／要修改，直接輸入）。
      使用者的回饋先改寫成退件格式「**哪個狀態 → 看到什麼 → 像什麼**」再交給 ui-builder；附一張白話回饋對照表
      （例：「太擠」→ 區塊間距加一級 spacing token；「太素」→ 加大標題字重對比；「很 AI」→ 逐項對照 anti-ai.md；「太花」→ 動畫降一級；「看不清楚」→ 檢查對比度是否 ≥ 4.5:1）
- [ ] **`/ui-site`**：Q1 加「品牌形象頁／在地店家」；`ui-style.json` 有 `site_type` 時預先帶入
- **預估**：3.5h
- **files**：`.claude/commands/ui-style.md`、`.claude/commands/ui-page.md`、`.claude/commands/ui-site.md`
- **驗收**（在**有前端程式碼的範例專案**裡實跑，模板 repo 本身測不到。用 `bash scripts/copy-template.sh <臨時目錄>` 建一個，放一頁靜態 HTML）：
  - 跑 `/ui-style` → 第一題的第一個選項是「讓我推薦（看預覽選）(Recommended)」
  - 走「看預覽選」→ 方向題有 3 個選項，每個 `preview` 都含 ≥4 個 `#RRGGBB`、≥3 行 ASCII、一個 `.claude/ui/<codename>/DESIGN.md` 存在的 codename
  - `site_type` 是管理後台時 → 動畫題只有 L1、L2 兩個選項，L1 標 (Recommended)
  - 動畫題的選項和描述用 `grep -iE 'gsap|lenis|framer|three|vanta|motion\.dev'` 檢查 → 沒有結果
  - 走完任一路徑 → `ui-style.json` 有 `"version": "1.1"`、`motion`、`site_type`、`source`，`overrides` 沒有 `animation`
  - 拿一份舊格式 `ui-style.json`（沒有 `motion`、有 `overrides.animation`）跑 `/ui-page` → 當作 L1 處理，而且提示一次
  - 走「貼網址」、給一個公開網站 → 先出現截圖確認題，確認後才寫 `_project/DESIGN.md`；檔案裡有來源網址、日期和信心分級，沒有 logo 或圖片網址
  - 在沒有 firecrawl 的環境走「貼網址」→ 改用 Playwright 退路，或請使用者上傳截圖，不會直接失敗
  - `claude --version` 低於 2.1.265 時走「Claude Design」→ 顯示升級說明並回到入口題（可以用改寫版本字串的方式模擬）
  - `/ui-page /` 在使用者回「太擠」之後 → 交給 ui-builder 的 prompt 裡有「狀態 → 看到什麼 → 像什麼」三段

### 階段 7：`ui-builder` 產出流程（D：截圖驗收、不准編事實） ⏳

- [ ] `tools:` 加 Playwright MCP 的工具（`browser_navigate`、`browser_resize`、`browser_take_screenshot`、`browser_console_messages`、`browser_evaluate`；確切名稱先查 Playwright MCP 文件）。
      沿用 context7 那句寫法：「專案沒裝時工具不會出現」
- [ ] 「啟動前必跑」加：讀 `anti-ai.md`；`motion` 是 L2／L3 時讀 `motion.md`；語言含繁中時讀 `fonts-cjk.md`
- [ ] 「產出後必跑」加截圖驗收：390、1440 各截一張並用 Read 自己看；有動畫的段落另外在 3 個捲動位置截圖；
      讀 console 錯誤；`browser_evaluate` 檢查 `document.documentElement.scrollWidth > clientWidth`（390、768、1024、1440 四種寬度）。
      需要 dev server 時用專案的 dev 指令啟動，**啟動不了或沒有 Playwright 時，報告寫「截圖未驗證」並回 `DONE_WITH_CONCERNS`**，不能當作通過
- [ ] 報告加「開放問題」節：列出所有 `【待提供：…】`
- **預估**：1.5h
- **files**：`.claude/agents/ui-builder.md`
- **驗收**：
  - 範例專案（階段 6 那個）跑 `/ui-page /` → `.claude/context/quality/ui-builder-*.md` 有 390 和 1440 兩張截圖的路徑，以及「console 錯誤：N」「水平捲軸：無／有（寬度）」
  - 故意在頁面放一個 `width: 1200px` 的元素 → 報告的水平捲軸列標出 390
  - 移除 `.mcp.json` 的 playwright 後再跑 → 回 `STATUS: DONE_WITH_CONCERNS`，報告寫「截圖未驗證」
  - 頁面需要價格但沒提供 → 產出的頁面有 `【待提供：價格】`，報告的「開放問題」列出它
  - `bash scripts/check-counts.sh` → 0 個 ✗

### 階段 8：同步腳本 `scripts/sync-ui-sources.sh`（F） ⏳

- [ ] **只有 `.sh` 版，不做 `.ps1`**。理由：CLAUDE.md 要求「兩份要一致」的只有 copy／update 這種會**發佈到使用者專案**的腳本；
      維護者工具的前例是 `check-counts.sh`（只有 sh），而且本模板的 hook 本來就需要 bash
- [ ] 介面：
  - `bash scripts/sync-ui-sources.sh`：只預覽，列出四種清單（上游有更新／上游新增／上游已刪除／本地已修改）。**不寫任何檔**
  - `--source <id>`：只看一個來源
  - `--apply`：只更新「上游有更新」**而且**本地 hash 等於 `imported_sha256` 的項目；上游刪除的只改 `SOURCE.json` 的 `upstream_status`，不刪本地檔；
    更新 `_sources.json` 的 `last_synced`。**永遠不加新項目、不覆蓋本地修改**
  - `--import <source>:<upstream-id>`：明確匯入一份，寫 `.claude/ui/<prefix><id>/DESIGN.md`＋`SOURCE.json`，最後提醒「去 CATALOG.md 加兩處，check-counts 會擋」
  - `--upstream-dir <路徑>`：用本機目錄代替 `gh api`（給測試用）
- [ ] 抓取：`gh api` 固定在某個 commit；下載到 `mktemp -d`（repo 外面），不在專案目錄裡解開。沒有 `gh` → exit 2 並說明
- [ ] google-alpha 格式的檔案，有 `npx` 才跑 `npx @google/design.md lint`，沒有就印「略過 lint」
- [ ] 測試 `scripts/sync-ui-sources.test.sh`：用 `--upstream-dir` 建假的上游，不連網
- [ ] **排除在新專案之外**：`copy-template.sh` 的 `EXCLUDES` 和 `copy-template.ps1` 的 `$excludeFiles` 加 `sync-ui-sources*`；
      `update-template.sh` 的 `sync_dir` 會 mirror 整個 `scripts/`，rsync 要加 `--exclude`，**`cp -a` 的退路**要在複製完後刪掉這兩支；
      `update-template.ps1` 同步改。四份要一致
- **預估**：3h
- **files**：`scripts/sync-ui-sources.sh`、`scripts/sync-ui-sources.test.sh`、`scripts/copy-template.sh`、`scripts/copy-template.ps1`、`scripts/update-template.sh`、`scripts/update-template.ps1`
- **驗收**（全部用 `--upstream-dir` 假上游跑，寫進 `sync-ui-sources.test.sh`）：
  - 假上游改了 `apple/DESIGN.md`、本地沒動 → 預覽列在「上游有更新」，`git status` 沒有任何變動
  - 同樣情境加 `--apply` → 本地 `apple/DESIGN.md` 變成上游內容，`SOURCE.json` 的 `upstream_commit` 和 `imported_sha256` 跟著更新
  - 本地 `stripe/DESIGN.md` 被手改過、上游也改了，加 `--apply` → 本地檔一個 byte 都沒變，列在「本地已修改」並印出 diff
  - 假上游多了 `starbucks` → 預覽列在「上游新增」；加 `--apply` 後 `.claude/ui/starbucks/` **不存在**
  - 假上游少了 `semrush` → `--apply` 後 `semrush/DESIGN.md` 還在，`SOURCE.json` 的 `upstream_status` 是 `removed`
  - `--import jp:ippodo` → `.claude/ui/jp-ippodo/DESIGN.md` 和 `SOURCE.json` 存在；接著跑 check-counts 出現 ✗「未列入 CATALOG.md：jp-ippodo」
  - PATH 裡沒有 `gh`、也沒給 `--upstream-dir` → exit 2，訊息含「需要 gh」
  - `bash scripts/copy-template.sh <臨時目錄>` → 臨時目錄沒有 `scripts/sync-ui-sources*`，**但有** `.claude/ui/_licenses/`
  - `bash scripts/update-template.sh <臨時目錄>` → 同上；在沒有 rsync 的情況（`PATH` 拿掉 rsync）也一樣
  - `copy-template.ps1`、`update-template.ps1` 用 PowerShell 跑一次 → 結果和 sh 版相同

### 階段 9：hook（E 的 D10 和兩個 PostToolUse 提醒、C 的掃描器評估、F 的 90 天提醒） ⏳

- [ ] **D10**（`user-prompt-submit.sh` 第 147 行）：`ui` 改成前後不能是英文字母（`(^|[^a-z])ui([^a-z]|$)`），並加入
      `網站|官網|landing|形象頁|一頁式|首頁|版型|配色|字型`。`css` 同樣處理
- [ ] **`lib/ui-lint.sh`**（新增，由 `post-write.sh` 呼叫，**不新增 settings.json 的接線**）：
  - 寫入的檔案副檔名是 `tsx|jsx|vue|svelte|html|css|scss`、不在 `.claude/**`／`docs/**`、檔名不含 `tokens|theme|tailwind.config` →
    抓 `#[0-9a-fA-F]{3,8}`，但排除 CSS 自訂屬性的宣告行（`--xxx: #...`）→ 用 `additionalContext` 提醒（不擋）
  - 讀 `ui-style.json` 的 `motion`：L1 卻出現 `gsap|lenis|locomotive|framer-motion|from ['"]motion|three|vanta` 的 import；
    L2 卻出現 `three|vanta` → 提醒。沒有 `ui-style.json` 就不檢查
  - 逃生門 `UI_LINT=off`
- [ ] **avoid-ai-design 掃描器評估**：讀它的 `scripts/detect.mjs`，把 67 條分成「bash 用 grep 判斷得準」和「需要解析才判斷得準」兩類。
      **預設做法**：只把準確度高的幾條 P0（例如紫藍漸層、全大寫 eyebrow 配 `→`、cream＋terracotta 的 hex 組合）用 bash 改寫進 `ui-lint.sh`，
      不引入 Node 依賴，也不整支放進模板。改寫到的規則要在 `.claude/ui/_licenses/` 附 MIT 原文，並在註解寫出處。
      評估結果（採用哪幾條、為什麼其他的不採用）寫進階段 11 的 ADR 提議
- [ ] **90 天同步提醒**（`session-start.sh` 既有的 ②）：加一個條件，**只有 `$MAIN_ROOT/scripts/sync-ui-sources.sh` 存在時**
      （這支腳本已經排除在新專案之外，所以等於「這裡是模板 repo」）才讀 `_sources.json` 每個來源的 `last_synced`；
      任何一個是 `null` 或超過 90 天就提醒「跑 `bash scripts/sync-ui-sources.sh` 預覽」。
      既有的「設計走向」提醒要不要也限定只在模板 repo 出現，見文末決定 3
- [ ] `hooks/README.md` 的檔案結構樹和功能表加 `lib/ui-lint.sh`
- [ ] 改了注入內容（關鍵字路由）→ 在 `.claude/tests/skill-compliance/prompts/` 加一題 `10-landing-page.txt`
      （例如「幫我做一個咖啡店的形象網站」，題目不提 skill 名），**在範例專案裡**跑 `run-compliance.sh`
- **預估**：3h
- **files**：`.claude/hooks/user-prompt-submit.sh`、`.claude/hooks/post-write.sh`、`.claude/hooks/lib/ui-lint.sh`、`.claude/hooks/session-start.sh`、`.claude/hooks/tests/run-tests.sh`、`.claude/hooks/README.md`、`.claude/ui/_licenses/**`、`.claude/tests/skill-compliance/prompts/**`
- **驗收**：
  - 輸入「quick fix 一下 build 腳本」「看一下 guide」→ 注入內容**沒有** `ui-style-compliance`
  - 輸入「幫我做一個 landing page」「做餐廳的官網」「UI 調整一下」「這個形象頁」→ 注入內容有 `ui-style-compliance`
  - 寫 `src/components/Hero.tsx`，內容含 `color: '#1D1D1F'` → `post-write.sh` 輸出的 `additionalContext` 提到寫死色碼和行號
  - 寫 `src/styles/tokens.css`，內容含 `--color-primary: #1D1D1F;` → 不提醒
  - 寫 `src/app.css`，內容只有 `:root { --c: #fff; }` → 不提醒
  - `ui-style.json` 是 `"motion": "L1"`，寫入含 `import gsap from 'gsap'` 的檔 → 提醒 motion 等級不符；改成 L2 → 不提醒
  - `ui-style.json` 不存在時寫入同一個檔 → 只做色碼檢查，不做 motion 檢查
  - `UI_LINT=off` → 兩種提醒都沒有
  - 沙箱有 `scripts/sync-ui-sources.sh`、`_sources.json` 的 `last_synced` 是 100 天前 → SessionStart 輸出含 `sync-ui-sources.sh`
  - 同一個沙箱但沒有 `scripts/sync-ui-sources.sh` → SessionStart 輸出**不含** `sync-ui-sources.sh`
  - `last_synced` 是 10 天前 → 不提醒
  - `bash .claude/hooks/tests/run-tests.sh` 全部通過；`bash scripts/check-counts.sh` → 0 個 ✗
  - `run-compliance.sh` 跑第 10 題 → 受測 session 有載入 `ui-style-compliance`（判讀寫進結果目錄的 `_判讀.md`）

### 階段 10：匯入使用者挑選的品牌、CATALOG 非科技業分類（F） ⏳

> **前提：階段 3 的清單已經由使用者挑過。** 沒挑不能開始。

- [ ] 用 `bash scripts/sync-ui-sources.sh --import <source>:<id>` 一份一份匯入（VoltAgent 用原名；jp 加 `jp-`；omd 加 `omd-`）
- [ ] 建 `.claude/ui/_licenses/` 的 jp、omd LICENSE 原文；`_sources.json` 填 `last_synced`
- [ ] 匯入後用階段 4 的對照表抽每一份的 color／typography，**抽不到的就不收**（或回報使用者）
- [ ] CATALOG.md：
  - 加非科技業分類：**餐飲咖啡／茶**、**在地工藝與生活選物**、**雜誌編輯感**、**精品與旅館**（實際命名依挑選結果調整）。每一份寫繁中一句話；jp 的另外標「日文原檔，字型對照見 fonts-cjk.md」
  - 「按品牌類型」也加對應產業
  - semrush 照決定 4 的方式標示
  - 開頭加一段說明：風格庫是「參考風格」，不是冒用品牌；商標屬原公司
  - 數字「69 種」更新
- [ ] `/ui-style` 的 2A-2a 哲學清單、2A-2b 產業清單加上新分類（**改 `ui-style.md`**）
- [ ] README.md 兩處「69 種」、`skill-curator.md` 的數字更新
- **預估**：4.5h（約 30～35 份）
- **files**：`.claude/ui/<新 codename>/**`、`.claude/ui/_licenses/**`、`.claude/ui/_sources.json`、`.claude/ui/CATALOG.md`、`.claude/commands/ui-style.md`、`.claude/agents/skill-curator.md`、`README.md`、`.claude/README.md`
- **驗收**：
  - `bash scripts/check-counts.sh` → 0 個 ✗（每個新目錄都有 DESIGN.md、SOURCE.json、在 CATALOG 兩處都有，配色、字型段落都找得到）
  - `ls .claude/ui/_licenses/` → 至少 `voltagent`、`jp`、`omd` 三份
  - 每個 `jp-*`、`omd-*` 目錄的 `SOURCE.json` 的 `source` 分別是 `jp`、`omd`，`license` 是 `MIT`
  - `bash scripts/sync-ui-sources.sh`（預覽）→ 剛匯入的項目**不會**出現在「本地已修改」
  - `grep -c '^- \*\*jp-' .claude/ui/CATALOG.md` 等於 `ls -d .claude/ui/jp-*/ | wc -l`（omd 同理）
  - CATALOG 的非科技業分類裡，沒有任何一份是 bergside cafe／terracotta 這類通用風格
  - 在範例專案跑 `/ui-style` →「看預覽選」推薦咖啡店時，3 個方向裡至少 1 個對應到新匯入的非科技業 codename

### 階段 11：整合驗收與文件 ⏳

- [ ] CLAUDE.md「改動時的連帶檢查」加一條：新增 `.claude/ui/` 風格 → 要有 `SOURCE.json`、CATALOG 兩處、上游新的話 `_sources.json` 和 `_licenses/`
- [ ] 檢查 `.claude/.gitignore`：這次沒有新增執行時狀態檔（最後同步日期記在進版控的 `_sources.json`）。如果實作過程有新增，就補上
- [ ] 如果 G1、G2 的落差有記在 CLAUDE.md 或 learned，搬進 `FIXED-LOG.md`
- [ ] 全套驗證：`bash .claude/hooks/tests/run-tests.sh`（約 10 分鐘）、`bash scripts/check-counts.sh`、`bash scripts/sync-ui-sources.test.sh`
- [ ] 範例專案從頭走一次：`/ui-style`（看預覽選）→ `/ui-site` → `/ui-page /`，包含一輪「太擠」的回饋
- [ ] 提議 `/adr`：記錄「掃描器用 bash 改寫部分規則，不引入 Node 版 detect.mjs」，以及「mixed 對照表認新舊標題，不把上游正規化成舊格式」兩個決定
- **預估**：2h
- **files**：`CLAUDE.md`、`.claude/context/decisions/FIXED-LOG.md`、`.claude/.gitignore`（只在需要時）
- **驗收**：
  - 三套腳本都是 0 失敗
  - 範例專案走完後：`ui-style.json` 有 `motion`；`_project/` 或選定的 codename 存在；ui-builder 報告有兩張截圖、`【待提供】` 清單；
    `src/` 底下 tokens 檔以外 `grep -rE '#[0-9a-fA-F]{3,8}'` 沒有結果
  - `git diff main --stat` 沒有 `workshop/` 底下的檔案

---

## 實作順序與平行

```
批次一（可以平行，最多 4 條 worktree）
  階段 1 小修 hook ─────────┐
  階段 2 授權與 metadata ───┼──→ 階段 8 同步腳本 ──┐
  階段 3 品牌候選（調查）───┼──→【停：使用者挑選】─┼──→ 階段 10 匯入
  階段 4 compliance 收斂 ───┘                       │
批次二                                               │
  階段 5 三份附屬檔（等 4）                          │
  階段 6 指令（等 5） ∥ 階段 7 ui-builder（等 5）    │
批次三                                               │
  階段 9 hook（等 1、6、8）──────────────────────────┘
  階段 10 匯入（等 3 的挑選結果、6、8）
  階段 11 整合（等全部）
```

| 階段 | 可以和誰平行 | 不能平行的原因 |
|---|---|---|
| 1 | 2、3、4 | 和 9 共用 `run-tests.sh` → 9 要等 1 |
| 2 | 1、3、4 | 8 要用它定好的 `SOURCE.json`／`_sources.json` 欄位 |
| 3 | 全部（只新增一份報告） | — |
| 4 | 1、2、3 | 5 要改同一份 `SKILL.md` |
| 5 | 8 | 6、7 要引用它的檔名和內容 |
| 6 | 7、8 | 10 也改 `ui-style.md`；9 需要 `motion` 的 schema |
| 7 | 6、8 | 4 也改 `ui-builder.md` → 要等 4 |
| 8 | 4、5、6、7 | 9 的提醒用它在不在來判斷是不是模板 repo |
| 9 | 10 | 和 1 共用 `run-tests.sh`；和 10 共用 `_licenses/`（只新增不同檔，衝突機率低但仍算重疊）→ **保守起見循序** |
| 10 | — | 改 `ui-style.md`、`skill-curator.md`、`CATALOG.md`，和 4、6 重疊 |

平行前提：
- `plans/` 在 `.git/info/exclude` 裡，**要先 `git add -f` 這份 plan 並 commit**，worktree 才看得到它（INDEX.md 的 09-09 註記）
- `code-quality-specialist` 這類會讀整個 repo 的審查者不要在平行期間跑，等合併後再跑
- 每合一條就 `/verify`（`.merge-pending` 閘門會擋）。階段 1 修好 G1、G2 之前，合併後的清單可能要手動確認

建議分三個 PR：批次一（1～4）、批次二（5～8）、批次三（9～11）。每一批單獨就能用：
批次一合進去後授權缺口就補上了；批次二合進去後三條定調路徑就能用；批次三才是 hook 和新品牌。

## 風險與緩解

| 風險 | 影響 | 緩解 |
|---|---|---|
| 同步腳本覆蓋本地修改 | HIGH | 用 hash 比對 `imported_sha256`，不信任手填旗標；`--apply` 只動 hash 相符的；預設只預覽；測試要涵蓋「本地改過＋上游也改」 |
| 上游換成新格式，mixed 模式抽不到內容而且不報錯 | HIGH | 階段 4 對照表認新舊標題；階段 2 讓 check-counts 檢查每份都抽得到配色、字型；抽不到要明說 |
| `_licenses/` 被 check-counts 當成缺 DESIGN.md 的風格 | MEDIUM | 階段 2 改成 `_` 開頭整個跳過 |
| 同步腳本被 update-template 帶進使用者專案（`scripts/` 是整個 mirror） | MEDIUM | 階段 8 四份 copy／update 腳本都排除，包含 `cp -a` 退路；驗收兩種都測 |
| 90 天提醒在新專案出現 | MEDIUM | 以「同步腳本存在」為條件，而腳本已經排除在新專案之外；驗收有反向測試 |
| firecrawl 抽不到（沒裝、被擋、branding 是空的） | MEDIUM | 退路：Playwright `getComputedStyle` → 使用者上傳截圖（標低信心）。不會直接失敗 |
| 抽網址時搬到 logo、圖片、文案 | MEDIUM | 只寫色票、字型、圓角、陰影、間距；驗收檢查 `_project/DESIGN.md` 沒有圖片網址 |
| Claude Design 是 research preview，入口、指令、交接格式都可能改 | MEDIUM | 標成選用；寫版本檢查；轉寫以實際收到的內容為準；文件寫查證日期 |
| 「看預覽選」推出的方向正好是 AI 痕跡（米白＋襯線＋陶土；CATALOG 的 `claude`、`perplexity`、`zed`、`granola` 本身就是） | MEDIUM | 提方向前先讀 `anti-ai.md` 的「產出前」表；例外規則寫明 |
| 「溫暖手作」把 AI 感帶進風格庫 | MEDIUM | 只收實際網站的品牌，階段 3 每份都標 AI 痕跡風險 |
| 授權：jp／omd 每份都聲明不擁有品牌識別；Apache-2.0 整段複製要附 NOTICE | MEDIUM | `_licenses/` 放原文；CATALOG 開頭寫「參考風格不是冒用品牌」；frontend-design 只改寫 |
| G2 修 cmd-segments 時，測試內文被還沒修好的閘門擋下 | LOW | 單次 `MERGE_GATE=off`；測試先寫、先看它失敗 |
| 範例專案才能驗正向流程（模板 repo 沒有 `src/`） | MEDIUM | 階段 6、7、9、11 都寫明「在 copy-template 出來的臨時專案裡跑」 |
| ui-builder 截圖需要 dev server，有些專案啟動不了 | LOW | 啟動不了就回 `DONE_WITH_CONCERNS` 並寫「截圖未驗證」，不能當作通過 |
| 範圍大（約 27h），中途 context 壓縮 | MEDIUM | 分三批 PR；每階段結束 commit；用執行帳本 `*.progress.md` |

## 驗收標準（整體）

- [ ] 所有階段狀態為 ✅
- [ ] `bash .claude/hooks/tests/run-tests.sh` 全部通過
- [ ] `bash scripts/check-counts.sh` 0 個 ✗
- [ ] `bash scripts/sync-ui-sources.test.sh` 全部通過
- [ ] 範例專案從 `/ui-style` 走到 `/ui-page` 的完整流程通過（階段 11）
- [ ] `run-compliance.sh` 第 10 題的判讀寫好了
- [ ] 沒有改到 `workshop/`
- [ ] `/code-review` 沒有 CRITICAL／HIGH

## 使用者決定（2026-10-16）

1. 同步腳本放 `scripts/sync-ui-sources.sh`，四份 copy／update 腳本加排除
2. avoid-ai-design 掃描器：只挑高準確度的 P0 規則以 bash 改寫進 `ui-lint.sh`，不引入 Node，附 MIT 原文
3. 既有「設計走向 90 天」提醒也改成只在模板 repo 出現
4. `semrush`：本地保留。階段 2 查證它從未在上游（依 Semrush 官方設計系統 Intergalactic 抽取），使用者改決定：CATALOG 標「（依官方設計系統抽取）」，SOURCE.json 上游欄位皆為 null
5. 第一批（階段 1～4）以 4 條 worktree 平行執行
6. 階段 10 匯入清單：`skill-curator-2026-10-16-1034-brand-candidates.md`「給使用者挑選用的精簡清單」推薦的 35 份全收（VoltAgent 7、jp 15、omd 13），含 AI 痕跡標中／高者（作對照組，由 anti-ai.md 在提方向時避開或標註）
7. 階段 6 一併處理：`ui-site.md` 約第 194 行「產 tokens 一律做深色模式」與階段 4 的 D4 新規則矛盾（階段 4 回報）
