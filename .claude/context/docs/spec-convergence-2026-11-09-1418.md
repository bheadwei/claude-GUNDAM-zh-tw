---
agent: main
area: docs
target: feat/overview-from-code 本輪（56d93424..HEAD）
severity: low
status: findings
---

# 規格收斂檢查 — 2026-11-09

基準：**無 brief、無 PRD、無 WBS**（模板 repo 沒有 `docs/`）。改以本輪兩份 ad-hoc 計畫的「為什麼做」＋各階段驗收、frontmatter `files:`，與 ADR-2026-11-05-001～008、ADR-2026-11-06-001／002 為基準。non-goals 與未釐清項無法比對。
範圍：`/verify pre-pr`，檢查 A+B（跳過 C）。計畫：`adhoc-2026-11-05-overview-from-code`（階段 0–7）、`adhoc-2026-11-05-docs-system`（階段 1–6），外加 CI 修正（非計畫階段）。

## 摘要
漏做 0 ・ 範圍蔓延 4 群（9 檔，皆使用者要求的支線）・ 描述失真 未檢查 ・ 已否決但做了 0

## A. 漏做
| 規格中的功能 | 出處 | 狀態判斷 | 建議 |
|---|---|---|---|
| — | 兩份計畫所有 `### 階段` 標題皆 ✅；每階段都有審查報告與帳本「審查通過」紀錄 | 無漏做 | 無 |

已知未做、已明確記為技術債（不算漏做）：extkind 的 Go／Java／C# 與 scoped 套件無案例、inner 空殼無直接斷言、`overview.sh:57` 註解過期、check-counts NOTES 表頭只取第一個表、ov_const 只認單行、其他吞錯的 gitq、平台條件案例無機器檢查、index.html 接近 64KB、`user-prompt-submit` 架構文件維護動詞清單需隨用語擴充、`workshop/docs/03_command_cheatsheet.md:105` 仍列已刪 agent（workshop 依使用者規定不動）。

## B. 範圍蔓延
本輪改了 113 檔；扣掉過程產物（ADR、agent 報告、qa-history、learned、計畫檔本身）後，有 9 檔不在任一份計畫的 `files:`：

| 已完成的改動 | 計畫有提嗎 | 判斷 | 建議 |
|---|---|---|---|
| statusline 鋼彈 100 級＋外號台詞（`statusline.sh`、`STATUSLINE_GUIDE.md`；e71c57c、a592865） | 否 | 使用者要求的支線（`qa-history/2026-11-06-100000-statusline-gundam-levels.md`） | PR 說明列為獨立項 |
| 最低版本 bash 4、jq 1.7.1（`session-start.sh`、`writing-extensions` SKILL；1910215、eb53ab0、90cdb7f） | 部分（地圖 0 有 jq 1.6 CI，後改成要求 1.7.1） | 使用者決策（`qa-history/2026-11-06-110000-bash-min-version.md`） | PR 說明列為獨立項 |
| 模板測試不再複製／同步到專案（`copy-template.{sh,ps1}`、`update-template.sh`、`skill-curator.md`、`testing-standards` SKILL；69418f6） | 否 | 2026-11-05 支線 | PR 說明列為獨立項 |
| 收尾一致性修正（`update-template.{sh,ps1}` 結尾、spec-convergence 檢查 C 改派、plan-format status、post-write 字串；2b060e8） | 否（修的是本輪兩份計畫造成的不一致） | 屬本輪範圍的收尾 | 無 |

CI 修正（28d865c：run-tests.sh、learned 紀錄）依 `qa-history/2026-11-09-103000-ci-fix-placement.md` 併進本分支，檔案在計畫 `files:` 內，不列蔓延。

## C. 描述失真
pre-pr 跳過。

## 不需要動作的
- 過程產物 33 檔（`context/decisions/`、`context/planning/`、`context/learned/`、`qa-history/`、`plans/`）
- 兩份計畫 `files:` 合計 285 項（含 glob），本輪其餘 71 檔都落在範圍內
- 本輪無 PRD，不適用「PRD 情境變更」套回
