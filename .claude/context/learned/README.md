# Learned — 踩過的坑與可重用 pattern

跨 session 的**累積式**知識，與 `../<area>/` 的 agent 執行報告不同：

| 目錄 | 內容 | 生命週期 |
|---|---|---|
| `../quality/`、`../security/` 等 | 單次執行的掃描/審查報告 | 滾動，只留最新 5 份 |
| **本目錄** | 教訓、根因、可重用做法 | **長期累積，不 GC** |

## 這個目錄有牙齒

`pre-tool-use.sh` 的**坑閘門**會在你（或任何 agent）要寫入某個檔案時，掃本目錄每份
紀錄的 `files:` glob。命中就**擋下該次寫入一次**，把 `symptom` / `root-cause` /
`guard` 直接貼進對話，讀完重試同一次編輯即通過（同一檔案一個 session 只擋一次）。

> 這是「同一個坑不該踩第二次」從自律變成機器保證的地方。
> **`files:` 寫錯或留空 = 這份紀錄永遠不會被觸發，等於沒寫。**

逃生門：環境變數 `PITFALL_GATE=off`（只關坑閘門）、或 `/suggest-mode off`（全關）。

## 格式（frontmatter 是契約，不是裝飾）

照 `_PITFALL_TEMPLATE.md`。`_` 開頭的檔案與 `README.md` 會被閘門跳過。

```yaml
---
date: 2026-08-19
title: 一句話講清楚這個坑
files:                          # 閘門比對用；相對專案根的 glob
  - "backend/mcp/*.py"
  - "src/api/**/*.ts"
symptom: 看到的現象（錯誤訊息、錯誤行為）
root-cause: 真正的原因，不是症狀複述
guard: 下次碰這些檔案該怎麼做才不會再踩
severity: high                  # high | medium | low
---
```

`files:` 也接受行內寫法 `files: ["a/*.ts", "b.py"]`。
glob 用 shell 樣式比對整條相對路徑（`*` 會跨 `/`，所以 `src/**/*.ts` 與
`src/*.ts` 實際效果相同——寧可寬一點，漏提醒比誤提醒糟）。

## 誰會寫進來

| 來源 | 時機 | 強制性 |
|---|---|---|
| `debug-investigator` | 找到根因後 | **必須**（見該 agent「結束後」第 2 條） |
| `/learn` | 手動擷取當前 session | 自願 |
| 你自己 | 任何時候踩到值得記的坑 | 自願 |

## 誰會讀

- **坑閘門**（機器，寫檔當下）—— 唯一有強制力的讀取者
- `debug-investigator` 開始調查前
- `using-taskmaster` skill 要求主模型動工前先看

## 什麼時候該升級成別的東西

| 情況 | 該放哪 |
|---|---|
| 坑能用 regex／測試表達 | **升級成機器保證**：加測試，或在 `pre-tool-use.sh` 加規則。文件留給判斷題 |
| pattern 通用到跨專案可重用 | 改寫成 skill（`.claude/skills/<name>/SKILL.md`）並更新 `skills/INDEX.md` |
| 技術決策（為什麼選 A 不選 B） | `../decisions/`（ADR），不放這裡 |

## 過期的紀錄

坑修掉了、或前提不再成立時，**改掉或刪掉那份檔案**——不要靠 `PITFALL_GATE=off`
繞過。留著過期的紀錄比沒有紀錄更糟：它會一直擋人，然後大家學會忽略它。
