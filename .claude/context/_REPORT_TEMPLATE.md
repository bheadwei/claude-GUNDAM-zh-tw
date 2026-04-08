---
agent: <agent-name>
date: <YYYY-MM-DD-HHMM>
area: <quality|security|testing|e2e|deployment|docs|decisions>
target: <檔案路徑或範圍>
severity: <info|low|medium|high|critical>
status: <findings|resolved|partial|blocked>
---

# <一行摘要>

## TL;DR
<最多 3 行重點，提供給其他 agent 快速判斷是否要讀全文>

## 範圍
- **檢查目標**: <具體 file/dir/feature>
- **觸發原因**: <為什麼這次跑 agent>
- **參考資料**: <讀了哪些先前報告（若有）>

## 發現

### 🔴 Critical / High
- `<file>:<line>` — <問題> → <建議動作>

### 🟡 Medium
- `<file>:<line>` — <問題>

### 🟢 Low / Info
- <次要觀察>

## 建議的後續 Agent
<若需要交接，列出建議的下一個 agent，並建立 coordination/handoffs/ 檔>
- **<agent-name>** — <為什麼需要他>

## 度量
- 檢查檔案數: N
- 通過: N | 警告: N | 失敗: N
- （可選）覆蓋率/分數: N%

---

> 報告檔保留規則：每個 area 只保留最新 5 份，超過自動歸檔到 `_archive/`
> 詳見 `.claude/scripts/context-gc.sh`
