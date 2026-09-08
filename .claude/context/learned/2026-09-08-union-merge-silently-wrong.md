---
date: 2026-09-08
title: merge=union 對「相鄰行各自被改」會靜默產出重複且矛盾的內容
files:
  - ".gitattributes"
symptom: 兩個分支各自把 wbs.md 裡相鄰的兩列標成 ✅，掛了 `merge=union` 之後合併「成功」、沒有任何衝突標記，但結果是四列、兩份重複、狀態互相矛盾。
root-cause: union 保留的是「兩個版本的整個 diff hunk」，不是「各留自己改的那一行」。相鄰的行會落在同一個 hunk 裡，所以兩邊的整段都被留下。官方文件的警語是「lines from both sides depend on each other」會出錯——實際門檻比字面低得多，**單純相鄰就足以壞掉**。
guard: union 只能用在**純附加**的檔案（新內容都加在檔尾、從不修改既有行，例如 CHANGELOG）。凡是「既有列會被就地修改」的追蹤檔（wbs.md、plans/INDEX.md、任何帶狀態欄的表格）一律不要掛 union。真正的解法是讓那個檔案**只有一個寫入者**，不要想在合併時補救。
severity: high
---

> **注意：坑閘門不會貼出這一篇。** `pre-tool-use.sh` 只對程式碼副檔名生效，
> `.gitattributes` 不在清單裡。這裡留的是紀錄；實際的防護是 `.gitattributes`
> 檔案本身那段註解（動它的人一定會看到）。

## 怎麼發現的

差點為了「兩個 agent 各自標自己那列 ✅ 會衝突」開一個 merge-resolver agent。
使用者問「網路上沒有相關參考嗎」，查了才發現 git 內建 `union` driver 就在做這件事——
看起來是「選錯層」的漂亮修正（不需要 AI，一行 `.gitattributes` 就好）。

**但沒有直接採用，先在沙箱實測。** 建 repo → 兩個分支各標一列 → 合併：

```
| 1.1 | A | ✅ |     ← feat-a 標的
| 1.2 | B | ⏳ |
| 1.1 | A | ⏳ |     ← feat-b 那份的舊狀態
| 1.2 | B | ✅ |     ← feat-b 標的
```

`grep -c '<<<<<<<'` = 0。**完全沒有衝突標記。**

## 完整說明

這個失敗模式比「合併失敗」嚴重得多，因為它**看起來成功**。合併回報 `Auto-merging wbs.md`
就過去了，WBS 從此帶著矛盾的狀態，而沒有任何訊號。

三層教訓：

1. **官方文件的警語要當下限而不是上限。** 文件說「互相依賴的行」會出錯，
   實際上「相鄰」就夠了——因為 hunk 的粒度不是行。
2. **「找到現成的原生機制」不等於「可以直接用」。** 查到 union 的那一刻很像
   正解（git 原生、零 AI、確定性），但確定性不代表結果正確。
3. **衝突的正解通常在源頭而不在合併。** wbs.md 會衝突是因為 N 個 worktree
   各改它一次。讓它只有一個寫入者（合併完在主 checkout 更新一次）就沒有衝突可解。

## 相關

- `.gitattributes` —— 為什麼這裡沒有 union（含實測結果）
- `.claude/commands/verify.md` —— worktree 內跳過「標記與歸檔」
- `.claude/skills/worktree-orchestration/SKILL.md` —— 合併回 main 那節
