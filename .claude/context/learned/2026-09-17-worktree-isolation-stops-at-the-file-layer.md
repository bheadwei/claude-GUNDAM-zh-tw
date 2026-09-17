---
date: 2026-09-17
title: worktree 的隔離只到檔案層——symlink 環境目錄會讓 agent 靜默執行到另一條線的程式碼
files:
  - ".claude/settings.json"
  - ".claude/skills/worktree-orchestration/SKILL.md"
  - ".claude/hooks/pre-agent-gate.sh"
symptom: 兩條 worktree 平行開發，檔案完全不重疊、git 也看不出異常。但 worktree 裡不帶 `PYTHONPATH` 執行時 `router.__file__` 指向**主 checkout**；該 worktree 的 agent 跑測試，測到的是另一條線的程式碼。對方當時正在做突變測試（刻意把程式碼改壞），所以這邊的測試結果整批是錯的——**沒有任何錯誤訊息，測試還是綠的/紅的，只是測錯了東西**
root-cause: `settings.json` 的 `worktree.symlinkDirectories` 預設含 `.venv`，所以 worktree 的 `backend/.venv` 是**指回主 checkout 的 symlink**。那個 venv 裡 editable install 的 `.pth` 記的是主 checkout 的絕對路徑（`uv` workspace 成員預設就是 editable）。worktree 的隔離是**檔案層**的——它保證你寫不到別人的檔案，但保證不了你 import 到自己的檔案。同一個病也在 `.next`／`dist`／`build`（建置產物是「這份 source 的輸出」）與 workspace 形態的 `node_modules`（`node_modules/<pkg>` 是指回 repo source 的 symlink）
guard: 要 symlink 一個目錄之前問：**它的內容只由 lockfile 決定，還是會記錄來源路徑？** 純快取／純下載產物可以；任何記路徑的東西（editable `.pth`、workspace package 連結、從 schema 產生的 client）與**建置產物**都不行。本模板的預設已改成 `symlinkDirectories: []`——空的永遠不會算錯，只會多花磁碟與安裝時間。中招的修法：`test -L <路徑> && unlink <路徑>` 再重建，**絕不用 `rm -rf <路徑>/`**（帶斜線會沿著 symlink 刪掉主 checkout 那一份）
severity: high
---

> **注意：坑閘門不會貼出這一篇。** `pre-tool-use.sh` 對 `.claude/*` 直接放行，
> 所以 `files:` 在這裡是**索引用**。這個坑的實際防線是**設定預設值**
> （`symlinkDirectories: []`）加上 `worktree-orchestration` skill 的判準表——
> 沒有閘門，理由見下方「為什麼不做成閘門」。

## 怎麼發現的

實際專案用 worktree 平行開發兩條線，檔案範圍完全隔離——這正是
`worktree-orchestration` 一路在推薦的做法，前一課（讀撞寫）的結論也是
「要平行只能靠 worktree 隔離」。所以現場看起來完全合規。

異常是從測試結果對不上開始的。查下去才發現不帶 `PYTHONPATH` 時
`router.__file__` 指向主 checkout，也就是說**這個 worktree 從一開始就沒有
在測自己的程式碼**。更糟的時間點：對方那條線當時正在做突變測試，
主 checkout 的程式碼是被刻意改壞的。

排除掉的假設：不是 git 出錯（`git status`、`git log` 在兩邊都正常）、
不是 `.worktreeinclude` 帶錯檔案（帶的是 `.env`／`.mcp.json`，跟 import 無關）、
不是 agent 寫錯目錄（它寫的檔案確實落在 worktree 裡）。

## 為什麼這一類特別難發現

前兩類衝突至少會**留下痕跡**：寫撞寫會讓某份工作消失、讀撞寫會讓報告出現
假 failed 或莫名被刪的檔案，查起來有東西可看。

這一類**什麼痕跡都沒有**。檔案在正確的地方、git 是乾淨的、測試有跑完、
結論有輸出。錯的只有「那個結論是關於哪份程式碼的」，而這件事不會出現在
任何一行輸出裡。

而且它挑的時機最壞：**合併前的全量驗證也是在 worktree 裡跑的**。
最需要結果正確的那一次，正好是被污染的那一次。

## 修法

**1. 設定預設值改掉**（`.claude/settings.json`）

```
"symlinkDirectories": ["node_modules", ".venv", ".next", "dist", "build"]   ← 舊
"symlinkDirectories": []                                                    ← 新
```

判準是**不對稱的**：空的預設值**不可能造成錯誤結果**，只會多花磁碟與安裝時間
（可見、可回復）；非空的預設值在某些專案形態下會造成靜默的錯誤結果。
模板不知道目標專案是不是 monorepo、用不用 editable install，所以不該替它做這個假設。
要開的人自己照 skill 的判準表開。

**2. 判準寫進 skill**（`worktree-orchestration` 的 `symlinkDirectories` 節，唯一來源）

可以 symlink 的是**純快取／純下載產物**；不能的是**任何會記錄來源路徑的東西**
與**建置產物**。含偵測與修法（`test -L` → `unlink` → `uv sync --all-packages`），
以及兩個容易做錯的細節：`rm -rf` 帶斜線會刪到主 checkout；只跑 `uv sync`
會把 workspace 成員修剪掉。

**3. `pre-agent-gate.sh` 檔頭的假設修正**

原本寫「帶了 isolation → 有自己的 checkout，**改不到別人**，直接放行」。
那句只在檔案層成立，補上執行層的例外並指向 skill。

### 為什麼不做成閘門

這是本模板少數「判斷得出時機卻刻意不做成 hook」的例子，理由要寫清楚免得下一個人
照 `writing-extensions` 的決策表第一列直接動手：

- **派工當下沒有東西可檢查**——worktree 還沒建，venv 也還不存在。
- 唯一能檢查的時機是 worktree 建好之後，而那時要判斷「這個 symlink 危不危險」
  得知道專案用不用 editable install、是不是 workspace，閘門問不出來。
- **誤擋的代價很高**：被擋的正是「帶 `isolation` 的派工」，那是我們花了三課
  在推廣的做法。把它變成要解釋的事，等於把人推回單 checkout 平行。

所以這一格交給**設定預設值**（機器層，永遠生效、零判斷）加**skill 判準**
（要主動開的人自己讀）。預設值其實比閘門更硬——它不需要被想起來。

## 可以帶走的通則

**「隔離」要問到底是哪一層的隔離。** 檔案層隔離不等於執行層隔離；
任何一條指回共用位置的路徑（symlink、絕對路徑、快取鍵、環境變數、資料庫連線）
都能在檔案層完好無損的情況下，把兩條線接回同一份東西。

配套的一條：**替別人選預設值時，比較兩種錯法的可見度，不是比較機率。**
「多花 484MB」跟「靜默測到別人的程式碼」不是同一個量級的錯，
即使後者比較少見。

## 相關

- `.claude/skills/worktree-orchestration/SKILL.md` — `symlinkDirectories` 判準與修法（唯一來源）
- `.claude/settings.json` — `worktree.symlinkDirectories`（預設 `[]`）
- `.claude/hooks/pre-agent-gate.sh` — 檔頭「帶了 isolation 就放行」那段的例外說明
- `2026-09-16-concurrent-read-write-not-file-overlap.md` — **第二類**衝突（讀撞寫）。
  那一課的結論是「要平行只能靠 worktree 隔離」，本課補的正是那個結論的前提條件：
  **隔離要真的隔離到執行層才算數**。兩課的強制者不同（那課是 `pre-agent-gate.sh`
  的攔截訊息，這課是設定預設值），觸發時機也不同（派工當下 vs 建 worktree 時），
  所以分成兩篇而不是併成一篇
