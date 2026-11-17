---
agent: code-quality-specialist
date: 2026-11-17-1600
area: quality
target: project-docs 範本去數字前綴、scripts/update-template.{sh,ps1} 舊檔名自動改名
severity: high
status: resolved
---

# 範本去數字前綴＋update-template 自動改名：1 HIGH、3 MEDIUM 已修

## TL;DR
ps1 在 PowerShell 5.1 + ErrorActionPreference=Stop 下，`ls-files --error-unmatch` 寫 stderr 會終止整支腳本（HIGH）。
另有 git mv 失敗處理不一致、sh 連結替換誤報、ps1 丟 BOM（MEDIUM）。全部由主模型修正；舊檔名引用無漏換，copy-template 不需同步。
（agent 依派工指示只回報未落檔，本檔由主模型依回報補寫）

## 範圍
- **檢查目標**: main 上未 commit 的 diff
- **觸發原因**: standard 模式的階段審查
- **參考資料**: 無

## 發現

### 🔴 Critical / High
- `scripts/update-template.ps1` — 用 `--error-unmatch` 判斷是否進 git，5.1 下 stderr 變終止例外 → 改看 `ls-files` 輸出是否為空（已修）

### 🟡 Medium
- `scripts/update-template.{sh,ps1}` — git mv 失敗時 sh 中止整支、ps1 照樣記為已改名 → 兩邊都改成印警告並跳過該檔（已修）
- `scripts/update-template.sh` — grep 比對兩個舊名但 sed 只換實際改名的，會對內容沒變的檔印「更新連結」 → 改成 sed 後 cmp，有變才寫回與印出；加測試釘住（已修）
- `scripts/update-template.ps1` — 寫回時丟 BOM → 偵測原檔 BOM 照樣寫回（已修）

### 🟢 Low / Info
- `.claude/scripts/overview.sh` 跳過 frontend 的註解理由過時 → 已改寫
- sh／ps1 的改名對照表各一份，已標「要一致」，2 筆可接受
- ps1 無法在本機（無 pwsh）實測

## 建議的後續 Agent
無

## 度量
- 檢查檔案數: 約 25
- 通過: — | 警告: 4 | 失敗: 0
