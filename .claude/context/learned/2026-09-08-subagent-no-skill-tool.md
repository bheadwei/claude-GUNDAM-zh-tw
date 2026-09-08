---
date: 2026-09-08
title: subagent 拿不到 Skill 工具——寫進限縮的 tools: 會被靜默丟掉
files:
  - ".claude/agents/*.md"
symptom: agent 定義的 `tools:` 裡寫了 `"Skill"`，agent 跑起來實際可用工具清單裡沒有它，也沒有任何錯誤或警告。agent 也收不到 available-skills 清單，所以無法靠 description 自己判斷要載入什麼。
root-cause: 限縮的 `tools:` 白名單不認 `Skill` 這個名字，未知項被靜默忽略而非報錯。只有 `tools` 為 `*`（或未限縮）的 agent 才拿得到 `Skill` 工具與 skill 清單。
guard: agent 要用到某個 skill 的內容時，在它的定義開頭寫「**必讀規範：** `.claude/skills/<name>/SKILL.md`」——**完整路徑**，讓它用 `Read` 直接讀。不要寫成 `` `<name>` skill ``（agent 得自己猜檔案在哪），也不要試圖把 `"Skill"` 加進 `tools:`。`check-counts.sh` 會擋下含 `"Skill"` 的 `tools:`，並驗證引用的路徑存在。
severity: high
---

> **注意：坑閘門不會貼出這一篇。** `pre-tool-use.sh` 對 `.claude/*` 直接放行
> （避免自鎖），且只對程式碼副檔名生效（`.md` 不在清單裡）。所以上面的 `files:`
> 是給人看的範圍標記，不是觸發條件。
>
> 這個坑的機器保證在 **`scripts/check-counts.sh`**（拒絕 `tools:` 含 `"Skill"`）
> 與 **`post-write.sh` 的擴充維護提醒**（改到 `.claude/agents/` 時提醒一次）。
>
> 由此暴露的機制落差：**`context/learned/` 完全不覆蓋模板自身的擴充**。
> 關於 `.claude/` 的教訓寫進來只是紀錄，不會有人被擋下來看到。

## 怎麼發現的

兩次實測，缺一個都會得到錯誤結論：

1. **`general-purpose`（`tools: *`）** → 可以呼叫 `Skill(skill="python-uv")`，
   回傳 `Launching skill: python-uv`，skill 全文在**下一個回合**以注入訊息送達
   （不是在工具結果裡，所以呼叫後必須讓回合推進才拿得到內容）。
   它也收到約 100 項的 available-skills 清單。
2. **`documentation-specialist`**，把 `"Skill"` 加進它的
   `tools: ["Read","Write","Edit","Bash","Grep","Glob","Skill"]` → agent 回報
   實際工具只有 `Read/Write/Edit/Bash/Grep/Glob`，**沒有 `Skill`**，
   也沒收到任何 skill 清單。

只做第 1 個測試會誤以為「subagent 可以用 Skill」，然後把它加進 14 個 agent
的 `tools:`，做出看起來完全正確、實際一個字都不會載入的東西 —— 而且沒有任何訊號。

## 完整說明

這件事的後果比「少一個工具」大得多，因為它決定了**整個 skill 層對 agent 的可達性**：

- 只有 `description` 進**主模型**的 context，skill 本體要被喚起才載入
- subagent 連 description 清單都拿不到，所以它**沒有任何自主喚起路徑**
- agent 取得 skill 內容的唯一途徑是**它自己的定義給一個可 `Read` 的路徑**

發現這件事之前，14 個 agent 只有 4 個接了線，其餘的專業知識完全沒有召喚路徑。
例如 `e2e-validation-specialist` 從來讀不到 `e2e-testing` skill 那 278 行的
POM／flaky test／trace 知識，每次都自己重新想怎麼寫 Playwright。

順帶暴露的第二層問題：沒接線的 agent 定義裡**寫死了錯的指令**。
`build-error-resolver` 原本寫著
`rm -rf node_modules package-lock.json && npm install`——
在 pnpm/bun 專案會毀掉可重現的安裝。

## 相關

- 決策紀錄：`.claude/context/decisions/`（本次盤點報告）
- 接線檢查：`scripts/check-counts.sh`（引用的 skill 路徑必須存在；
  每個 skill 要嘛被 agent 引用、要嘛在 `MAIN_MODEL_ONLY` 白名單裡）
- 維護者：`.claude/agents/skill-curator.md` 的「你必須知道的機制事實」
