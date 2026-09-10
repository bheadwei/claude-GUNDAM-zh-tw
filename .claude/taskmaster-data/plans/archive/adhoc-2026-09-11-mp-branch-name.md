---
wbs_task: "none"
slug: "mp-branch-name"
created: "2026-09-11"
updated: "2026-09-11"
archived: "2026-09-11"
status: "✅ 完成"
current_phase: 1
files:
  - ".claude/hooks/post-bash.sh"
  - ".claude/hooks/tests/run-tests.sh"
---

# 實作計畫：`.merge-pending` 記分支名，而不是整條指令

## 目標

`.merge-pending` 的每一列要能**看出是哪個分支合進來的**。

## 背景（為什麼要做）

`post-bash.sh:68` 現在是：

```sh
BR=$(printf '%s' "$CMD" | tr '\n' ' ' | cut -c1-100)
```

變數叫 `BR`（branch），存的卻是**整條 Bash 指令的前 100 個 byte**。兩個後果：

1. **看不出分支。** 平行開發合了 3 個分支時，`/verify` 要「比對每一個已合併任務的
   plan 驗收標準」，而它從清單上讀到的是三條長得幾乎一樣的 `cd ... && git merge --no-ff -q -m "..."`。
   那份清單唯一的用途就是分辨哪個分支，現在做不到。
2. **中文會變亂碼。** `cut -c1-100` 在 Git Bash 上按 **byte** 切，切在 UTF-8 字元中間。
   2026-09-11 實際重現：`... -m "merge: 宣告義務\xe7...`（末字被腰斬）。

## 階段拆解

### 階段 1: 從指令抽出 merge 的目標 ref ✅

- [x] 解析 `$CMD`，取 `git merge`／`cherry-pick`／`rebase` 後面第一個**非旗標**參數當作 ref
- [x] 抽不到時（例如 `git merge` 讀 `MERGE_HEAD` 續做、或指令形式沒見過）
      **fallback 回舊行為**，但改用 `cut -b` 之後補一道 UTF-8 修剪，確保不留半個字元
- [x] 記進 `.merge-pending` 的是 ref，不是整條指令
- **預估**：30min
- **驗收**：`git merge --no-ff -m "訊息" feat/x` 記下的是 `feat/x`；中文訊息不產生亂碼

## 驗收標準（整體）

- [x] 階段 1 ✅
- [x] `run-tests.sh` 全綠，且新案例做過負向測試
- [x] 不動 `files:` 以外的任何檔案

## 邊界（本任務不做）

- **不改**閘門的擋／放行邏輯 —— 只改「記什麼進清單」
- **不改** `.merge-pending` 以外的狀態檔

## 歸檔紀錄（2026-09-11）

這兩份 plan 的存在目的是**驗證 `conflict-resolver`**——整套平行開發機制裡唯一
從頭到尾沒被叫起來過的一塊（上一輪零衝突，它從未被觸發）。兩份的 `files:` 刻意
完全重疊，改 `post-bash.sh` 同一段但意圖不同，正解是保留雙方。

**結果：它解對了。** 組合成 `BR="[$MP_OP] $MP_REF"`，兩邊註解都留住，報告逐項
寫出「決定 + 依據哪份 plan 的哪一條」。

**它糾正了我的一個預設**：這次衝突不是 `files:` 漏列造成的。兩份的 `files:`
完全正確也完全重疊——照「無交集才可平行」，這兩個任務**當初就不該被判成可平行**。
真正漏列的是 `run-tests.sh`：兩份都把「測試全綠」寫進驗收卻沒列進 `files:`，
又都寫「不動 `files:` 以外的任何檔案」，於是**兩個 agent 都無權修自己弄壞的斷言**。
已補列。**寫 plan 時，凡是驗收標準會碰到的檔案都必須列進 `files:`。**
