# ADR-XXX: [簡短的決策標題]

> **版本:** v5.0 | **更新:** 2026-07-24 | **狀態:** MADR 4.0 格式
>
> 本文件依 [MADR 4.0.0](https://adr.github.io/madr/) 格式撰寫。小決策用 **bare 版**（第 A 節），重大/跨團隊決策用 **full 版**（第 B 節）。一個 ADR 一個檔案，檔名 `ADR-XXX-kebab-title.md`。

---

## A. Bare 版（最簡骨架 — 日常小決策用這版）

```markdown
---
status: proposed
date: YYYY-MM-DD
decision-makers: []
---
# <決策標題>

## Context and Problem Statement

[2-3 句描述背景與待解問題，可用問句收尾]

## Considered Options

* [選項 1]
* [選項 2]
* [選項 3]

## Decision Outcome

Chosen option: "[選項 X]", because [理由 — 通常是唯一符合限制條件，或優劣權衡後最佳者]。
```

---

## B. Full 版（完整骨架 — 重大/跨團隊決策用這版）

```markdown
---
status: proposed
date: YYYY-MM-DD
decision-makers: []
consulted: []
informed: []
---
# <決策標題>

## Context and Problem Statement

[描述背景脈絡與問題，盡量量化嚴重性；可用 2-3 句 + 1 個問句]

## Decision Drivers

* [驅動因素 1，例如效能需求、團隊熟悉度、成本上限]
* [驅動因素 2]
* [約束 1，例如既有基礎設施、合規要求]

## Considered Options

* [選項 1]
* [選項 2]
* [選項 3]

## Decision Outcome

Chosen option: "[選項 X]", because [理由摘要，說明相對其他選項的關鍵優勢]。

### Consequences

* Good, because [正面後果，盡量可衡量]
* Good, because [正面後果 2]
* Bad, because [負面後果 / 引入的技術債或風險]
* Neutral, because [中性影響，例如需要團隊學習新工具]

### Confirmation

[如何驗證此決策已被正確落實 — 例如：程式碼審查檢查清單項目 / 架構測試 (fitness function) / CI 檢查 / 特定 lint 規則]

## Pros and Cons of the Options

### [選項 1]

[選項 1-2 句描述，附範例或連結]

* Good, because [論點]
* Good, because [論點]
* Neutral, because [論點]
* Bad, because [論點]

### [選項 2]

[選項 1-2 句描述]

* Good, because [論點]
* Bad, because [論點]

### [選項 3]

[選項 1-2 句描述]

* Good, because [論點]
* Bad, because [論點]

## More Information

[補充資訊：相關 RFC、討論串連結、後續追蹤事項、`adr_tags`、`related: ADR-YYY` 等]
```

---

## Frontmatter 欄位說明

| 欄位 | 必填 | 說明 |
| :--- | :--- | :--- |
| `status` | 是 | `proposed` / `accepted` / `rejected` / `deprecated` / `superseded` / `under-review` |
| `date` | 是 | 決策制定日期（非建檔日期），YYYY-MM-DD |
| `decision-makers` | 建議 | 對此決策有最終拍板權的人/角色 |
| `consulted` | 選填 | 決策前被諮詢意見者（雙向溝通，RACI 之 C） |
| `informed` | 選填 | 決策後需被告知者（單向通知，RACI 之 I） |

---

## 撰寫指引

- **一個 ADR 只記一個決策**。決策範圍變了 → 開新 ADR 並在 `More Information` 互相 `related` 連結，不要塞進舊 ADR。
- **Considered Options 至少 2 個**（含「維持現狀」也算一個選項），否則無從比較。
- **Confirmation 是 4.0 新增的關鍵欄位**：沒有可驗證的落實方式，決策容易變成紙上文字。優先寫「自動化可檢查」的方式（CI/lint/架構測試），其次才是人工審查。
- **狀態變更時更新 frontmatter**，並在檔案結尾補一行變更記錄（見下方）。

## 狀態變更記錄（選填，狀態變動時追加）

| 日期 | 新狀態 | 異動人 | 備註 |
| :--- | :--- | :--- | :--- |
| YYYY-MM-DD | accepted | [姓名] | [原因或連結至討論] |
