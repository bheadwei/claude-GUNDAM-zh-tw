# skill-curator — 專案圖解 階段 2：架構文件格式與 WBS 模組欄（2026-11-04）

- 提案：`skill-curator-2026-11-04-visual-overview-proposal.md` 第 4 節階段 2、6.2、7、12
- 分支：`worktree-agent-a3c2a9da9933af61c`（從 `feat/visual-overview` 開出，HEAD 含 `ef56bed`）
- 只改文件與 `check-counts.sh`，沒有產生任何圖、沒動 hook

## 改了哪些檔

| 檔案 | 改了什麼 |
|---|---|
| `.claude/skills/project-docs/templates/05_architecture_and_design_document.md` | 5.1 範例的節點 id 改成小寫（`web` `gateway` `svc-a` `svc-b` `db` `cache`），subgraph 加 id（`g1`–`g3`），下面加一句「節點 id＝5.5 的 id」。5.5 表改成 `id\|模組\|路徑\|對應 BDD\|職責\|API 設計\|資料模型`，範例 6 列一一對應 5.1 的節點，並加三行說明：id 格式 `[a-z0-9-]+`、必須等於 5.1 節點 id、路徑寫 glob 用 `,` 分隔 |
| `.claude/templates/wbs.template.md` | 第 1 節兩張任務表在「任務」後加 `模組`；第 2 節加「模組」列（填 5.5 的 id、多個用 `,`、沒架構或跨全域填 `—`；欄位定義指向 05 範本）；第 5 節歸檔表加欄，「模組」原樣帶過去；重申舊節原樣保留、依表頭找欄位 |
| `.claude/commands/docs-init.md` | 路徑 A：說明 demo 沒有架構，模組欄一律 `—`，圖解只有任務圖。路徑 B：「2. 架構總覽」改成容器圖＋模組表，骨架下加一段指向 05 的 5.1／5.5（唯一來源），沒有內嵌表頭 |
| `.claude/commands/task-init.md` | 步驟 5：模組欄填架構文件 5.5 的 id，demo 一律 `—` |
| `.claude/commands/task-add.md` | 步驟 3 欄位表加「模組」：比對 5.5 的職責與路徑提出建議，對不到就 `—`，不自己發明 id；步驟 4 預覽加「模組（建議）」欄；「調整拆解」可改模組；寫回時填確認過的值 |
| `.claude/agents/architect.md` | tools 加 `Edit`（使用者決定 #4）；寫入邊界改寫成「`Write` 與 `Edit`，只能寫文件」，並說明 `Edit` 是為了不洗掉手改；角色加一條；新增「架構文件的容器圖與模組表（你負責）」節，指向 05 範本 |
| `.claude/agents/documentation-specialist.md` | 必讀加 `.claude/skills/project-docs/SKILL.md`；新增「架構文件的模組表（5.5）」節：①搬目錄時只同步「路徑」欄（不動 id 與切分，那是 architect 的範圍）②沒有架構文件時反推草稿、加 `<!-- overview: draft -->`、不寫 context 報告、回 `NEEDS_CONTEXT`、標記由主模型移除。description 補上這兩個觸發情境 |
| `.claude/scripts/check-counts.sh` | 新增 7 項檢查（見下） |

### 任務單沒列、但加欄後必須跟著改的地方

WBS 多一欄後，凡是會寫 WBS 列或依欄位讀歸檔的地方都要知道這一欄，否則寫出來的列少一格、後面欄位整排錯位（不會報錯）。
照 2026-10-27 加「負責」欄那次（`skill-curator-2026-10-27-1132-wbs-owner-column.md`）找到的寫入點逐一補上，每處只改一句：

| 檔案 | 改了什麼 |
|---|---|
| `.claude/commands/verify.md` | ad-hoc 補登那一行：模組欄填 `—` |
| `.claude/commands/task-status.md` | 歸檔：「模組」原樣帶過去、加欄前的舊節不回填；舊格式轉換：模組欄填 `—`，不猜 |
| `.claude/commands/time-log.md`、`task-add.md` 步驟 1 | 「加入負責欄之前的舊節少一欄」改成「加入負責欄、模組欄之前的舊節少欄」 |
| `.claude/skills/project-docs/templates/16_wbs_development_plan_template.md` | 職責分工表與任務列範例加模組欄，補一句填法 |

判定不用改：`post-write.sh` 的格子長度檢查用表頭欄名取值（「任務」欄豁免、`#` 永遠在第一欄），加欄不影響。

## check-counts 新增的檢查

| # | 檢查 | 對應提案驗收 |
|---|---|---|
| 1–2 | 05 範本 5.5 第一個表頭的儲存格含 `id`、`路徑` | 階段 2 第 1 項 |
| 3 | 05 範本 5.1 mermaid 的每個小寫節點 id 都在 5.5 的 id 欄（找不到任何節點也算失敗） | 第 2 項 |
| 4 | `wbs.template.md` 所有 `\| # \| 任務 \|` 表頭都含 `模組` | 第 3 項 |
| 5 | `wbs.template.md` 第 2 節有 `\| 模組 \|` 列 | 第 3 項 |
| 6 | `docs-init.md` 路徑 B 提到 `05_architecture_and_design_document.md` 與 `5.5` | 第 4 項 |
| 7 | `docs-init.md` 路徑 B 沒有 `\| id \|` 開頭的行（防第二份副本） | 第 4 項 |

「與 `overview.sh` 欄名常數一致」（第 5 項）等階段 3 腳本存在再加。

## 驗證

- **接線**：`check-counts.sh --tests 812` 檢查 706 項，全部一致（不帶 `--tests` 為 703 項）
- **檢查本身會擋**：把 5.5 表頭改名、5.1 多一個 `mq` 節點、WBS 歸檔表頭拿掉模組、第 2 節「模組」列改名、docs-init 路徑 B 塞一行 `| id | 模組 | 路徑 |`，跑出 6 項不一致、每項訊息都對；之後 `git checkout` 還原
- hook 沒動，不跑 `run-tests.sh`
- **行為未驗證**：第 7 項（用新範本實跑 `/task-init` mvp，看 `tech-spec.md` 有容器圖與模組表、WBS 每列有模組欄）在模板 repo 做不了——**待在應用專案實測**。`/task-add` 會不會照 5.5 建議模組也一樣沒驗
- mermaid 節點 id 帶連字號（`svc-a`）：查到的資料（mermaid issue 把 `A-node` 列為合法 id）顯示可以解析，但沒找到官方語法規格明寫，也沒實際渲染過

## 留給後面的事

- 架構文件在 full 模式的實際檔名仍沒有唯一答案（提案 R9、第 11 節）：agent 定義裡寫的是 `docs/*architecture*.md`，`docs-init` 路徑 C 的產出檔名對不到範本編號。本階段沒處理
- `.skill-impact`：本 worktree 沒有這個檔；主 checkout 那份是提案時就存在的 33 行舊累積，與本階段無關，沒有處理也沒有清除
- `agent-orchestration.md` 的 8＋1＋1＋4 名單不變：documentation-specialist 仍是終端節點、不寫報告（使用者決定 #6），architect 報告落點不變，`post-agent-report.sh` 的 `AREA` 表不用改
