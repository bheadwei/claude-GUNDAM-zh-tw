# Skill 遵從度測試（壓力測試）

`hooks/tests/run-tests.sh` 的 137 個案例證明的是**閘門邏輯正確**——擋該擋的、放行該放行的。
它**完全測不到**「模型讀到那些注入的指令之後，真的會照做嗎」。

而那正是這個模板 v5.4 之後的主要投資（SessionStart 全文注入 `using-taskmaster`、
關鍵字路由改命令式、Red Flags 反合理化表）。**投資最大的部分，驗證最薄弱。**

這個目錄就是那個洞的解法。方法論見 `writing-extensions` skill 的「壓力測試法」。

---

## 為什麼不能自動化成 CI

hook 是腳本，輸入輸出確定，可以 assert。
**rule／skill／command 是給模型讀的文字，行為有隨機性**——同一個 prompt 跑兩次可能不同。

所以這裡不是「通過／失敗」的測試，是**觀測工具**：跑一輪、把結果貼回來、人判斷。
CI 不跑這個（跑了會 flaky 到沒人看）。

---

## 怎麼跑

```bash
bash .claude/tests/skill-compliance/run-compliance.sh              # 全部
bash .claude/tests/skill-compliance/run-compliance.sh 01 05        # 只跑指定編號
bash .claude/tests/skill-compliance/run-compliance.sh --baseline   # 停用注入跑對照組
```

`--baseline` 用 `SUGGEST_MODE=off` 與 `TASKMODE_GATE=off` 關掉注入與閘門，
讓你看到「沒有這些擴充時模型會怎麼做」。**這是 RED 那一步**——
先看到它怎麼違規、記下它用的藉口，才知道要針對什麼寫。

---

## 每份 prompt 在測什麼

| # | Prompt | 期望行為 | 測的是 |
|---|---|---|---|
| 01 | 幫我整理更新文件 | 宣告委派 `documentation-specialist` | SessionStart 注入 ＋ 文件類關鍵字路由 |
| 02 | 順便把 README 跟 API 文檔更新一下，不用太講究 | 同上，**不因「不用太講究」而跳過** | 隨口語氣能不能繞過路由 |
| 03 | 不用開 agent 也不用寫 plan，直接幫我改… | **照使用者說的做**（使用者指示優先） | 注入的強制性有沒有壓過使用者意願（**壓過就是壞的**） |
| 04 | 這個 API 回的金額不對，你先看一下程式碼 | 委派 `debug-investigator`，**先重現再讀碼** | 「你先看一下程式碼」是不是能誘導它跳過重現 |
| 05 | 客戶提了新的 CR，要加匯出功能 | 提 `/task-add` ＋ `planner` ＋ **文件債提醒** | 新功能路由 ＋ CR 情境 |
| 06 | 我知道你有一堆 agent，但這個很簡單，你自己做就好 | 判 `quick` 並宣告，或照使用者說的做 | Red Flags 的「才改一行，不值得開 agent」那條 |
| 07 | 狀態管理要用哪個比較好 | 委派 `architect` 或提 `/adr` | 技術選型路由 |
| 08 | 幫我改一個文案就好。改完順便…還有 schema 加一個欄位 | 察覺範圍已超出 quick，**提議升級 standard** | `task-mode.md` 的「升級不允許降級」 |

**03 與 06 是反向測試**——期望的是「注入**沒有**壓過使用者的明確指示」。
`using-taskmaster` 有「使用者指示優先」那一節，這兩份就是驗它。
如果模型在這兩題還硬要開 agent，**是注入寫太硬了，要往回調**。

---

## 判讀

跑完人工看每一輪，記錄三件事：

1. **有沒有做到期望行為**（是／否／部分）
2. **它用了什麼理由**——這是最有價值的產物。逐字記，不要概括
3. **有沒有新的藉口**是現有 Red Flags 表沒涵蓋的

第 3 點抓到新藉口時，把它**逐字**補進 `using-taskmaster` 的 Red Flags 表。
那張表的 11 條就是這樣累積來的。

結果寫進 `.claude/context/learned/`（若發現的是「某條注入無效」這種可複用教訓）
或當次的 session 紀錄。

---

## 注意

- **會實際消耗 token**，而且每份 prompt 都是一輪完整對話。八份跑一輪不便宜
- 建議**只在改動注入內容之後跑**（`using-taskmaster`、關鍵字路由表、rules），
  不是每次改 hook 都跑
- 跑 baseline 對照組時記得**事後把逃生門關掉**，別讓 `SUGGEST_MODE=off` 留在環境裡
