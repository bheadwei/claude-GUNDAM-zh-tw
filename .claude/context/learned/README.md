# Learned — 踩過的坑與可重用 pattern

跨 session 的**累積式**知識，與 `../<area>/` 的 agent 執行報告不同：

| 目錄 | 內容 | 生命週期 |
|---|---|---|
| `../quality/`、`../security/` 等 | 單次執行的掃描/審查報告 | 滾動，只留最新 5 份 |
| **本目錄** | 教訓、根因、可重用做法 | **長期累積，不 GC** |

## 誰會寫進來

- `debug-investigator` — 找到根因後寫報告（同時也是「這個坑長什麼樣」的紀錄）
- `/learn` — 手動擷取當前 session 的可重用 pattern

## 誰會讀

`debug-investigator` 開始調查前會先讀這裡——同一個坑不該踩第二次。

## 格式

自由格式，開頭寫明擷取日期與情境。若某個 pattern 通用到值得在多個專案重用，
改寫成 skill（`.claude/skills/<name>/SKILL.md`）並更新 `skills/INDEX.md`。

> 技術決策（為什麼選 A 不選 B）不放這裡，放 `../decisions/`（ADR）。
