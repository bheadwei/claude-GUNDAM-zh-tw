---
wbs_task: "none"
slug: "agent-orchestration-upgrade"
created: "2026-06-08"
updated: "2026-06-08"
status: "✅ 完成"
current_phase: 5
---

# 實作計畫：Agent 協作精準化 + 任務分級自動化

## 目標

讓模板「協作零件接上電」：subagent 之間能依明確訊號**自動委派/交接**，且小任務不再被迫跑完整 TDD。完成後，使用者開發時：(1) 寫完功能會被主動提示啟動 quality/security/test 鏈；(2) 臨時小修改會被自動判為 quick 並跳過 TDD；(3) agent 交接（handoff）會在下一輪自動浮現給主模型，而非躺在資料夾無人理會。

## 背景診斷（為什麼要做）

現況是「**零件齊全但沒接電**」：

- `coordination/handoffs/`、`context/<area>/`、報告模板、task-mode 三檔制**全部存在**，但：
  - **問題 #1**：agent `description` 全是名詞定義無觸發條件 → 主模型不自動委派；handoff 是被動拉取、無人扣板機；hooks 全是被動 logger 從不注入提示。
  - **問題 #2**：`.current-task-mode` 只有 `/task-next` 會寫 → ad-hoc 工作落到預設 `standard` → 小任務也跑完整 TDD；自動分級啟發式只活在 `/task-next` 內。

## 技術依賴 / 既有資產

- 既有協作基礎設施（**重用，不重造**）：
  - `.claude/coordination/handoffs/_HANDOFF_TEMPLATE.md`（frontmatter: from/to/status/priority）
  - `.claude/coordination/README.md`（已定義 `grep -l "status: pending"` 查法 + 常見交接場景表）
  - `.claude/context/<area>/`（quality/security/testing/e2e/docs/deployment）+ `_REPORT_TEMPLATE.md`
- 既有規則：`task-mode.md`、`plan-persistence.md`、`testing.md`、`development-workflow.md`、`interactive-qa.md`
- 既有 hook 註冊點（`settings.json`）：UserPromptSubmit、PostToolUse(Agent)、PostToolUse(Write)、PreToolUse
- 限制：**hook 無法直接啟動 agent**；只能注入 context 讓主模型啟動 → 本計畫的「主動觸發」= hook 注入提示 + 主模型依 playbook 行動
- 限制：hooks 走 Git Bash + 重度依賴 `jq`（Windows 環境）

---

## 階段拆解

### 階段 1: Agent description 重寫（自動委派主槓桿）✅

對 `.claude/agents/*.md` 全部 14 個重寫 `description`，從「名詞定義」改為「**時機 + 觸發語**」。

- [x] 盤點 14 個 agent，分類主動觸發 vs 按需觸發
- [x] 主動類加入 `MUST BE USED` / `Use PROACTIVELY` + 具體觸發條件（code-quality/security/test-automation/build-error/e2e/documentation = 6 個）
- [x] 按需類補上「何時該叫它」與邊界說明（architect/planner/refactor/deployment/ui-builder/workflow-template/tdd-guide/general-purpose）
- [x] description 為單行、中英混寫可被主模型解析
- **預估**：45min ・ **實際**：已完成
- **驗收**：✅ 14 個 description 皆含觸發時機；6 個主動類含 PROACTIVELY/MUST BE USED；邊界保留（general-purpose=Fallback only、tdd-guide=quick 跳過、documentation↔workflow-template 互相界定）

### 階段 2: Handoff 主動化 + 協作契約標準化 ✅

把被動 handoff 變成主模型看得見的提示，並讓所有參與鏈的 agent 都遵守同一交接契約。

- [x] 升級 `.claude/hooks/post-agent-report.sh`：掃 handoffs/ 的 pending 交接，以 `hookSpecificOutput.additionalContext` JSON 注入主對話（沿用原報告稽核）
- [x] 注入精簡（[priority] from→to（檔名）：起因），尊重 `.suggest-mode`：off=不注入 / low=僅 high / medium·high=全部（上限 5）
- [x] 稽核 14 agent：quality/security/test/e2e 原已有契約
- [x] 補 `deployment-expert` 協作段落（它是 security 的交接目標卻缺「讀 handoff」）→ 5 個鏈上 agent 全到位
- [x] 用 claude-code-guide 查證 hook 注入 JSON 格式；建立 `.suggest-mode` 持久化慣例（更新 suggest-mode.md）
- [x] hook 實測：medium 正常注入合法 JSON、off 靜默、low 僅 high、completed 排除
- **預估**：1.5h ・ **實際**：已完成並通過功能測試
- **驗收**：✅ 模擬 PostToolUse(Agent) + 假 pending handoff → 輸出合法 JSON 含 additionalContext；5 個鏈上 agent 皆有協作段落

### 階段 3: 入口意圖路由 + 編排 playbook ✅

在入口處給主模型「路由訊號」與「劇本」，減少漏委派。

- [x] 升級 `user-prompt-submit.sh`：關鍵字路由（auth/金流/migration/deploy/refactor/build-error/ui）注入建議；順手修掉 `.content`→`.prompt` 既有 bug
- [x] 路由為建議性注入、斜線指令略過、尊重 `.suggest-mode`（off/low/medium 分流，高訊號穿透 low）
- [x] 新增 `.claude/rules/agent-orchestration.md`：9 種標準鏈 + 鏈推進機制 + 任務模式對照 + 反模式
- [x] 確認 rules 由 Claude Code 自動載入（無 CLAUDE.md，新 rule 自動生效，無需註冊）
- **預估**：1h ・ **實際**：已完成並通過 6 情境測試
- **驗收**：✅「實作登入 API」→ 注入 critical + security 建議；playbook 檔完整可被主模型引用

### 階段 4: Task-mode 預設翻轉為自動分級 ✅

從「預設 standard」改成「預設自動判級」，直擊小任務跑 TDD。

- [x] `task-mode.md` 新增「入口自動分級（主路徑必跑）」節：任何實作請求前若無 `.current-task-mode`，主模型必須判級+宣告+寫檔，**預設不再是 standard**
- [x] 啟發式改為「共用」（/task-next 與 入口自動分級），訊號不再綁 WBS
- [x] `tdd.md` 改為優先序：行內參數 `/tdd <mode>` > 設定檔 > 入口自動分級，明訂「不要逕自當 standard」
- [x] 設定檔節說明 ad-hoc 也寫入；升級可/降級不可規則維持
- **預估**：45min ・ **實際**：已完成
- **驗收**：✅ 規則明訂「改文案→宣告 quick 跳過 TDD」「金流→critical」；`/tdd quick` 可直接進 Fast Lane

### 階段 5: Rules 豁免條款 + 殘留清理 + 健檢 ✅

消除規則矛盾與技術債，讓地基乾淨。

- [x] `testing.md`：「測試驅動開發」標題改為「standard/critical 強制；quick 豁免」+ 明確豁免說明
- [x] `development-workflow.md`：先規劃/TDD 步驟標註 standard/critical，quick 跳過 1-2 直接實作+happy-path
- [x] `hook-utils.sh`：`check_required_files` 的 taskmaster.js 由「缺少即 error」降級為 optional debug（確認此 lib 未被任何 active hook 載入，session-start 的引用本就有 `[ -f ]` 守衛）
- [x] `session-start.sh` 加 jq 健檢：缺 jq 時提示安裝指令（agent 監控/handoff 注入依賴 jq）
- [x] 全域複查：8 個 hook 純 LF、無 BOM、bash -n 通過；rules 對齊無矛盾
- **預估**：45min ・ **實際**：已完成
- **驗收**：✅ TDD 強制已限縮；taskmaster.js 不再誤判失敗；缺 jq 會提示；hook 全綠

---

## 風險與緩解

| 風險 | 影響 | 緩解 |
|---|---|---|
| description 改太兇 → 什麼都委派（過度觸發） | MEDIUM | PROACTIVELY/MUST BE USED 只給少數真正該主動的；按需類保留邊界說明；改完人工通讀 |
| hook 注入格式錯 → 完全沒注入或報錯 | HIGH | 先用手動 echo 測 JSON 輸出符合 hook 協定；保持軟降級（jq 缺→exit 0） |
| 注入過於頻繁 → 對話雜訊 | MEDIUM | 尊重 `suggest-mode`（off/low 時減少或不注入）；注入內容精簡單行 |
| 翻轉預設讓既有專案行為突變 | MEDIUM | 主模型每次都「宣告判級」可被使用者當場否決；升級可、降級不可 |
| Windows/Git Bash 無 jq | MEDIUM | 階段 5 加健檢提示；所有 hook 維持 jq 缺失時軟降級 |

## 驗收標準（整體）

- [x] 所有階段狀態為 ✅
- [x] 問題 #1 可複現改善：agent 跑完後 handoff 會主動浮現（hook 實測）、入口路由提示啟動鏈、description 驅動自動委派
- [x] 問題 #2 可複現改善：入口自動分級讓小任務判 quick 並跳過 TDD；rules 已加 quick 豁免
- [x] 無規則矛盾、無死引用（8 hook 全綠、taskmaster.js 降級）
- [ ] 變更以 conventional commits 分階段提交（遵守 `git-workflow.md`）— **待使用者確認後提交**
