---
wbs_task: "none"
slug: "mp-op-type"
created: "2026-09-11"
updated: "2026-09-11"
status: "⏳ 未開始"
current_phase: 1
files:
  - ".claude/hooks/post-bash.sh"
---

# 實作計畫：`.merge-pending` 記下是哪一種合併操作

## 目標

`.merge-pending` 的每一列要能**看出是 merge、cherry-pick 還是 rebase**。

## 背景（為什麼要做）

三種操作被同一個 `case` 收進同一份清單，但它們合併後要驗的東西不同：

- `merge` —— 驗兩邊 plan 的驗收標準都還成立
- `cherry-pick` —— 驗被挑過來的那個 commit 在新脈絡下仍成立（它的前後文沒跟過來）
- `rebase` —— **整段歷史都被重寫**，每一個 commit 都是新的，風險最高

`/verify` 的合併關卡現在對三者一視同仁，因為清單上分不出來。要讓它能分流，
清單得先記下操作類型。

## 階段拆解

### 階段 1: 在寫入清單時標記操作類型 ⏳

- [ ] 從 `$CMD` 判定是 `merge`／`cherry-pick`／`rebase` 三者之一
- [ ] 寫進 `.merge-pending` 的列要帶上這個類型，讓 `/verify` 一眼分得出來
- [ ] `hooks.log` 的那行也要帶上，方便事後追
- **預估**：30min
- **驗收**：三種指令各跑一次，清單上三列的類型正確

## 驗收標準（整體）

- [ ] 階段 1 ✅
- [ ] `run-tests.sh` 全綠，且新案例做過負向測試
- [ ] 不動 `files:` 以外的任何檔案

## 邊界（本任務不做）

- **不改**閘門的擋／放行邏輯 —— 只改「記什麼進清單」
- **不改** `/verify` 本身的分流實作（那是下一個任務，本任務只提供它需要的資訊）
