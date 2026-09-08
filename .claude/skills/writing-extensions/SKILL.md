---
name: writing-extensions
description: Use when adding or changing anything under .claude/ — deciding whether it should be a hook, rule, skill, command or agent, writing a skill description that actually gets recalled, and pressure-testing that the model really complies. Load before creating a new skill (including via /learn), before adding a rule, or when an existing rule/skill is being ignored.
---

# 擴充這個模板

要加東西到 `.claude/` 之前先讀本檔。它處理的是**選錯層**這個問題——
這個模板實際踩過四次，佔了歷次修補的大半。

---

## 第一個問題：該做成哪一層

五層不是設計選擇，是 **Claude Code 給的擴充點**。你沒有「用少一點層」的選項——
想要機器強制只能用 hook，想要常駐只能用 rules。所以問題永遠是「這件事該放哪一層」。

### 決策表

依序問，第一個「是」就決定了：

| 問 | 是 → 放這裡 | 為什麼 |
|---|---|---|
| **能不能在工具呼叫當下用程式判斷對錯？** | **Hook（PreToolUse）** | 唯一能回 `deny` 的地方。判斷得出來就別靠自律 |
| 需要在某個事件**當下**把資訊塞進對話？ | **Hook（其他事件的 `additionalContext`）** | SessionStart／UserPromptSubmit／PostToolUse 支援；**PreToolUse 不支援** |
| **任何**任務都適用，且不長？ | **Rule** | 常駐的成本是注意力稀釋，不只 token |
| 只在特定情境適用，需要時載入？ | **Skill** | 代價是「要被想起來」，所以 `description` 決定生死 |
| 使用者會主動叫它？ | **Command** | 它同時給了「開 Agent 工具」的授權（見下） |
| 需要獨立 context 與專屬流程去執行一件事？ | **Agent** | 它的價值是「不讓人跳步」，不是「比較聰明」 |

### 這個模板實際選錯的四次

| 原本 | 為什麼失效 | 改成 |
|---|---|---|
| `agent-orchestration.md` 寫「有專業 agent 就優先委派」（rule） | 軟規則對撞 Claude Code 內建的「非必要不開 Agent」就輸 | SessionStart 注入的 skill（`using-taskmaster`） |
| 坑的知識放 `context/learned/` 等人想起來 | 沒有任何機制在「要碰那個檔案」的當下提出來 | `pre-tool-use.sh` 的 deny 閘門 |
| 文件同步靠自律 | `documentation-specialist` 在任務完成路徑上沒有位置 | `post-write.sh` 偵測 + `/verify` 關卡 |
| agent 報告稽核只寫 log | 只寫 log 等於沒有牙齒 | `additionalContext` 注入 |

**共同點**：都是「該用 hook 卻用了文字」。**判準是「這件事有沒有一個機器判斷得出來的時機」**，
有就用 hook，別問「寫清楚一點會不會有用」——不會。

### Command 的隱藏價值

Claude Code 內建規則寫的是
*"Do not use the Agent tool unless the user, a CLAUDE.md file, **or a skill** asks for it"*。
**slash command 在 Claude Code 裡算 skill**，所以 command 內文提到 agent 就取得了授權；
自然語言沒有。這是為什麼 `/tdd` 派得動 `tdd-guide` 而「整理更新文件」派不動任何人。

---

## 第二個問題：同一份知識現在存在幾個地方

**答案是 1 → 沒問題。是 2 → 指定唯一來源，其他改成指標。**

多層架構的失敗模式不是層多，是**同一張表放兩處然後漂開**。實際發生過：
`rules/agent-orchestration.md` 的「標準鏈」與 `using-taskmaster` 的「路由表」曾是同一張表的兩份，
而兩者都常駐 context——付兩次錢還會不一致。

模板既有的處理方式（照抄即可）：

```markdown
**完整程序見 `worktree-orchestration` skill（唯一來源，勿在此重述）。**
```

`/verify` 對 WBS 歸檔、`task-next` 對 worktree、`agent-orchestration` 對路由表都用這個寫法。

---

## 寫 skill：`description` 決定它會不會被想起來

skill 的代價是「要被喚起才載入」，而喚起的唯一依據是 `description`。

**寫觸發條件，不寫內容摘要。**

| ❌ 內容摘要 | ✅ 觸發條件 |
|---|---|
| `PostgreSQL 索引與 RLS 知識` | `Use when 設計 schema、寫 SQL 或查詢變慢時` |
| `worktree 的完整說明` | `Use when running work in parallel across git worktrees…` |
| `測試覆蓋率標準` | `Use when writing or fixing tests, running /tdd, deciding coverage targets` |

三個要點：

- **開頭用 `Use when …`**，強迫自己寫情境而非內容
- **列出實際症狀與使用者會說的話**——`spec-convergence` 的 description 直接放了
  「還符合當初的需求嗎 / 規格有沒有跑掉」這種原話
- **需要硬一點的用 `MUST BE USED before …`**（`python-uv`、`node-package-manager`、
  `ui-style-compliance` 都是這樣，因為用錯工具的代價立即可見）

寫完**更新 `.claude/skills/INDEX.md`**，否則沒人知道它存在（`check-counts.sh` 會擋）。

### 常駐 vs 按需

目前只有 `using-taskmaster` 是常駐注入（由 `session-start.sh` 全文塞進 `additionalContext`）。
**要再加一個常駐之前，先問「它值得每個 session 都佔位嗎」**——常駐的真正成本是
稀釋其他規則的注意力。v5.3 把 rules 從 15 條砍到 6 條就是因為這個。

---

## 第三個問題：怎麼知道它真的生效

**這是這個模板目前最大的驗證盲區。** 163 個 hook 測試證明的是閘門邏輯正確，
**完全測不到「模型會不會照做」**。

hook 可以用 `run-tests.sh` 釘住。rule／skill／command 不行——它們是給模型讀的文字，
唯一的驗證方式是**看模型在有／沒有它的情況下行為差多少**。

### 壓力測試法

借自 superpowers 的 `writing-skills`（它把這套叫做 TDD for documentation）：

```
1. RED —— 先在「沒有這份擴充」的情況下，用真實開場 prompt 讓 agent 做那件事
          **記下它用的每一句藉口**，逐字記，不要概括
2. 寫    —— 針對那些藉口寫擴充（不是針對你想像中的藉口）
3. GREEN —— 同一個 prompt 再跑，確認行為變了
4. 重整 —— 找新的藉口，補進去，再驗
```

`using-taskmaster` 的 Red Flags 表就是這樣來的——那 11 條不是憑空想的，
是針對「模型會怎麼合理化不派 agent」寫的（「這只是個簡單問題」「我先看一下程式碼」
「這個我自己做比較快」）。**針對真實藉口寫的表，比針對想像寫的規則有效得多。**

### 可執行的雛形

`.claude/tests/skill-compliance/` 放真實開場 prompt，用 `run-compliance.sh` 跑批。
細節見該目錄的 README。**這一步不做，第 3 點就只是方法論。**

---

## 反模式

- ❌ 判斷得出來的事寫成文字規則（該用 hook）
- ❌ 同一張表放兩層
- ❌ `description` 寫內容摘要 → 永遠不會被載入
- ❌ 新增 rule 而不問「這真的每個任務都適用嗎」
- ❌ 新增 skill 卻沒更新 `INDEX.md`
- ❌ 針對「想像中的藉口」寫規則，而不是先跑 baseline 看真實藉口
- ❌ 加了擴充就當它生效，沒有任何驗證

## 相關

- `.claude/hooks/README.md` — 各 hook 事件支援什麼（哪些能 `additionalContext`）
- `.claude/skills/INDEX.md` — 現有 skill 與「不需要 Skill 的場景」
- `.claude/rules/agent-orchestration.md` — 五層的協作方式
- `.claude/tests/skill-compliance/README.md` — 壓力測試怎麼跑
- `scripts/check-counts.sh` — 新增後跑一次，它會列出所有沒同步的計數
- `CLAUDE.md` 的「改動時的連帶檢查」 — 每種新增各要同步哪些檔案
