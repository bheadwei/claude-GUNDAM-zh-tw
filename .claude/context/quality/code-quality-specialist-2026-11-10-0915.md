---
agent: code-quality-specialist
date: 2026-11-10-0915
area: quality
target: git diff 9b84fc2..feb86d5（overview.sh、templates/overview/index.html、hooks/tests/run-tests.sh）
severity: medium
status: findings
---

# 專案圖解可讀性階段 3（選計畫）審查：PASS，1 MEDIUM、2 LOW

## TL;DR
規格每一點都有做到，也沒有多做。沒有 XSS（標題、檔名都經 `esc`，`esc` 會轉義引號，所以 `data-pf` 屬性也安全）。事件委派只綁一次，選取狀態在 plan 消失時會被正確清掉。
MEDIUM：「只選本次」和預設選取的結果不一致（current plan 已 ✅、或之後換了任務時）。沒有 CRITICAL／HIGH，不需要 handoff。

## 範圍
- **檢查目標**：commit 1902706（產生器＋測試）、feb86d5（畫面）
- **觸發原因**：plan adhoc-2026-11-09-overview-readability 階段 3 的階段審查
- **參考資料**：plan 階段 3 驗收條件；已裁決不改的兩項（預設選取含已 ✅ 的 current plan 但抽屜不列它；390px 選計畫鈕要橫滑）

## 發現

### 🔴 Critical / High
無

### 🟡 Medium
- `.claude/templates/overview/index.html:762-770`：「只選本次」不會回到預設選取。`setSel` 把 `PSEL` 設成「當下 `p.current` 的 file」，接著 `planSel` 只保留未完成的 plan。造成兩種狀況：
  1. current plan 已 ✅：預設（`PSEL === null`）會畫出它的虛線框，按「只選本次」後 `PSEL` 變成 `{}`，虛線框消失。使用者預期回到預設，結果反而清空了。這是已裁決項的連帶後果，裁決時可能沒有考慮到這個按鈕。
  2. 之後的輪詢換了 `.current-task`：按過「只選本次」後 `PSEL` 固定在舊的 file，不會跟著新的本次 plan 走。
  → 建議 `k === 'cur'` 時改成 `PSEL = null; planSel(D); map(D);`，跟預設走同一條路徑。改動只有一行，兩種狀況都會修好。

### 🟢 Low / Info
- `index.html:753-755`：所有未完成 plan 都消失時，程式會把 `#psel` 藏起來，但 `#pbtn` 的 `aria-expanded` 仍是 `true`。之後有新 plan 出現時，第一次點按鈕只會「關閉」，要點第二次才會打開。`header()` 的 nbtn／dbtn（第 802 行）本來就有同樣的寫法，屬於一致的既有模式，信心有、影響小。
- `run-tests.sh:3944`：stub 案例只驗 `plannedModules | type == "array"`。因為 stub 是用 `{…, plannedModules, …}` 原值複製，這個檢查足以抓到「欄位被漏掉」（漏掉時會變 null）。不過驗不到內容。要更嚴謹的話，可以比對 stub 前後同一份 plan 的值。非必要。

### 已確認無問題的重點
1. **規格合規**：`plannedModules` 進了 public（取代 `_fileMods`，`del` 清單也同步拿掉）。stub 第 4 級保留它。`modules[].planned` 照舊只看本次（shrink 第 0 級與 overview.md 仍在用，符合 plan 第 134 行）。抽屜只列 `!completed`，有燈號、標題、模組數，也有全選／只選本次／清除。預設選本次，以 file 為鍵，輪詢後保留。`planf`、`shown()`、`planDiff()`、側欄兩則提示、說明文字都改讀 `PM`，已經沒有殘留的 `m.planned` 讀取。`lamp()` 是從 `tocItem` 抽出來共用的，不算多做。
2. **XSS**：`esc(p.file)` 放在雙引號屬性裡，`esc` 會轉義 `"'<>&`。`esc(task + title)` 也有轉義。模組數是數字。
3. **選取狀態**：`PSEL` 每次都用目前的 open plans 重建（第 747、749 行），不存在或已完成的 file 會自然被剔除，不會出錯。新出現的 plan 在手動選過之後預設不選，沒選過時跟著 current 走。「清除」後 `PSEL = {}` 是 truthy，所以不會退回預設，行為正確。
4. **事件委派**：`#psel` 的 click／change 監聽器在頂層各綁一次，`innerHTML` 重建不會造成重複綁定。label 被點時會冒泡到 click handler，但 `closest('button[data-ps]')` 是 null，等於 no-op。
5. **jq 端**：沒有 `files:` 時是 `[]`（有測試）。`--actual` 強制入選的 plan 走同一個 `build_plan`，欄位一樣。stub 會保留。`globmod` 對不到模組的 glob 會被 `select(. != null)` 濾掉。
6. **測試**：兩份 plan 的案例同時驗了「各自的 plannedModules 值」和「`planned` 仍只看本次」，驗的是行為，不只是欄位存在。測完會 `rm` 1.7 的 plan，不會污染後面的案例。

## 建議的後續 Agent
無（沒有任何有風險的路徑完全沒測試；畫面 JS 在模板 repo 沒有測試基礎設施，不屬於 handoff 範圍）。

## 度量
- 檢查檔案數：3
- 通過：PASS | MEDIUM 1 | LOW 2
- index.html 大小 67021 bytes（≤ 80KB）
