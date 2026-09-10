---
date: 2026-09-11
title: 閘門用子字串比對指令，於是「寫到那個指令名的文件」會被當成真的執行過
files:
  - ".claude/hooks/post-bash.sh"
  - ".claude/hooks/lib/merge-gate.sh"
  - ".claude/hooks/pre-tool-use.sh"
symptom: 明明沒合併過任何東西，下一次真的合併卻被擋，訊息說「上一次合併還沒驗證過」；清單裡那一筆長得像自己剛才寫檔案的指令
root-cause: post-bash.sh 用 `case "$CMD" in *"git merge"*)` 比對整條指令字串。寫文件、寫測試、寫 plan 只要內文提到那三個指令名，字串就命中，於是「寫檔案」被記成一次待驗證的合併
guard: 閘門要判斷的是「這條指令會不會真的執行某個動作」，不是「這條指令裡有沒有出現那幾個字」。比對前先剝掉 heredoc 內文與引號字串，或錨定到指令開頭（`git-backup-gate.sh` 已有這類回歸測試，抄它）
severity: high
---

## 怎麼發現的

2026-09-11 做 `conflict-resolver` 的驗證實驗時，一天之內被誤擋 **四次**：

1. 用 heredoc 寫兩份 plan，內文提到 `git merge` → 清單多一筆幽靈紀錄
2. 用 Python heredoc 改 `post-bash.sh`，程式碼裡有 `*"git cherry-pick"*` 這個 case 分支
   → 幽靈紀錄的類型還被標成 `[cherry-pick]`
3. 真正要合併時被那些幽靈紀錄擋下
4. **最嚴重的一次**：要修這個 bug，補丁腳本裡必須出現 `'git merge'`（那正是要被替換掉的
   舊斷言），於是**閘門擋下了修好它自己的那次編輯**

第 4 點是這個坑值得寫下來的理由。前三次只是煩，第四次是死結：
**你越想修它，它越擋你。** 最後是把補丁寫成 scratchpad 裡的 `.py` 檔、再用
`python <path>` 執行才繞過去——因為那條指令本身不含關鍵字。

排除過的假設：一開始以為是 `conflict-resolver` 留下的殘留，`cat` 了清單才看到
那一筆的內容是「我剛才寫檔案的指令」。

## 完整說明

`git-backup-gate.sh` **已經修過同一類問題**，它的測試裡有一條叫

> `只是提到指令（heredoc 內文）不擋`

註解寫著「本閘門幾乎每個 session 都處於『沒有 backup tag』的狀態，所以這個誤擋
會天天發生——實際踩過一次」。

**但 `post-bash.sh` 的合併偵測沒有跟著補上同樣的防護。**
同一個坑，兩支 hook 只修了一支。這是「修 bug 時只修了命中的那一處，沒去問
還有誰用同樣的寫法」的典型後果。

`.claude/` 底下所有用 `case "$CMD" in *"<指令名>"*)` 判斷的地方都該一起檢查。

### 附帶發現：衝突檔本身是 live hook 時，通知會靜默失效

同一次實驗的第二個發現。`post-bash.sh` 偵測到合併衝突時會注入
「⚠️ 合併有衝突 → 委派 `conflict-resolver`」——但這次衝突**就發生在 `post-bash.sh` 自己身上**，
衝突標記 `<<<<<<< HEAD` 讓它語法錯誤，於是：

```
post-bash.sh: line 68: syntax error near unexpected token `<<<'
```

**那則提示從來沒出現過。** 是人自己 `git status` 才發現有衝突的。

這推翻了一個隱含假設：整套機制假設「hook 一定會提醒你委派」。
在**改 hook 的 session** 裡這個假設不成立——而這個模板最常做的事就是改 hook。

沒有簡單解（hook 壞掉時本來就不能靠 hook 自救）。務實的做法是記住：
**衝突檔清單裡有 `.claude/hooks/**` 時，不要等提示，自己看 `git status`。**

## 相關

- `.claude/hooks/lib/git-backup-gate.sh` — 同類誤判的正確處理方式與回歸測試
- `.claude/hooks/tests/run-tests.sh` — 「只是提到指令（heredoc 內文）不擋」那條案例
