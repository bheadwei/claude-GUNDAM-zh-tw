---
agent: code-quality-specialist
date: 2026-11-12
scope: "專案地圖改版 階段 2（git diff 9858cea..888c31f，worktree-agent-a8ccf5dd35e53a26e）"
status: PASS
---

# 階段 2 審查：大包 plan 聚焦

（審查者在 worktree 內寫不進主 checkout，由主模型依其回覆落檔。）

結論：PASS。CRITICAL 0、HIGH 0、MEDIUM 1、LOW 4。沒有測試缺口，不建 handoff。

## implementer 疑慮判斷
1. 檔案明細用 `fdet` 不沿用 `xtra`：合理；`dk()` key `plan|source|file|done`／`|extra`／`|files`，`|extra` 與階段 1 相同、無碰撞。
2. 「計畫內部件才列檔案」：舊程式本就 `p.planned ? partFiles(...)`，只是 4 檔改 2 檔（規格要求），不越界。
3. 沒 node 整段略過：見 LOW-4。

## 特別檢查
- 共同路徑（index.html:947–955）：根目錄檔、無 `/` 不產生前綴；`cnt*10 >= len*6` 含等號；只算兩層以上目錄。
- XSS：新增拼接都有 `esc()`；未 esc 的 `ph.n` 是 `tonumber` 數字。
- 深色模式：新樣式只用既有 `light-dark()` token；無 :root 外 hex。
- 撞名：`.steps` `.later` `.prefix` `.donegrp` `.fdet` `.stepl` 無衝突。大小 72375 bytes。

## 發現
- [MEDIUM-1] index.html:942-945 `taskIds` 只看首尾，`21.2,21.5,21.9` 會顯示成 `21.2–21.9`。修法：同主編號且連續才壓縮，補非連續測試。
- [LOW-1] index.html:994 `nfile` 把 rollup 一筆（一個目錄）算成一個檔，明細數字少算。
- [LOW-2] index.html:1011-1013 沒有改動時仍畫出「檔案明細 0 個」。
- [LOW-3] index.html:963 聚焦取前兩個未完成階段；跳著做時 wip 階段會落到「之後」、不標為「現在」。
- [LOW-4] run-tests.sh:3555-3567、plan-fns.js：缺恰好 60%、根目錄檔、非連續編號案例；沒 node 時無任何輸出。

STATUS: DONE
