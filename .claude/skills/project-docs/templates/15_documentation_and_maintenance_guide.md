# 文檔與維護指南 - [專案名稱]

> **版本:** v2.0 | **更新:** 2026-07-24

---

## 1. 文檔架構 — Diátaxis 四象限

文檔依「使用情境」分類，**不可混雜**：一份文件只服務一種目的。寫作前先問「讀者現在是想學、想做、想查、還是想懂？」

| 象限 | 讀者情境 | 目的 | 判斷準則 | 範例 |
| :--- | :--- | :--- | :--- | :--- |
| **Tutorials（教學）** | 我是新手，帶我從零走一遍 | 學習（learning-oriented） | 步驟式、有起點終點、可重現 | 「10 分鐘建立第一個 API」 |
| **How-to（操作指南）** | 我知道目標，告訴我怎麼做 | 完成任務（task-oriented） | 假設讀者已有基礎、聚焦單一任務 | 「如何設定 CI/CD」 |
| **Reference（參考）** | 我要查一個確切事實 | 資訊查詢（information-oriented） | 結構化、完整、不摻教學語氣 | API 規格、CLI 參數表 |
| **Explanation（說明）** | 我想理解「為什麼」 | 理解（understanding-oriented） | 討論脈絡、取捨、設計理由 | 架構決策脈絡、ADR |

**禁止混雜規則**：
- ❌ Tutorial 中插入「你也可以這樣做...（進階選項）」→ 應拆到 How-to
- ❌ Reference 文件夾雜「建議先做 X 再做 Y」的教學語氣 → 應拆到 Tutorial/How-to
- ❌ How-to 中長篇解釋設計理念 → 應連結到 Explanation，本文只留步驟

---

## 2. 目錄結構（docs-as-code）

文檔與程式碼同 repo、走同一套 PR 審查流程：

```
docs/
├── tutorials/           # Diátaxis: 學習
│   └── getting-started.md
├── how-to/              # Diátaxis: 任務
│   ├── deploy.md
│   └── configure-ci.md
├── reference/            # Diátaxis: 資訊查詢
│   ├── api/
│   │   ├── openapi.yaml
│   │   └── examples/
│   └── cli.md
├── explanation/          # Diátaxis: 理解
│   ├── architecture-overview.md
│   └── adr/
└── _meta/
    ├── owners.yaml       # 文件擁有者對照
    └── glossary.md       # 術語表（供 CI 術語檢查）
```

> 既有專案若沿用 `api/` `architecture/` `guides/` `developer/` 舊結構，遷移時優先建立映射表，不必一次搬遷；新文件一律依四象限落位。

---

## 3. 撰寫規範

- **簡潔明瞭**：直接切入重點，不堆砌形容詞
- **主動語態**：「設定伺服器」而非「伺服器應被設定」
- **包含範例**：可運行的真實範例，不用虛構佔位輸出
- **象限一致**：寫作前先確認本文屬於哪個象限，全文只服務該目的
- **版本控制**：所有變更走 PR，commit message 說明「為什麼改」

---

## 4. CI 文檔檢查

文檔 PR 應和程式碼一樣跑自動化檢查，未通過不可合併：

| 檢查項 | 工具範例 | 檢查內容 |
| :--- | :--- | :--- |
| **連結檢查** | `lychee` / `markdown-link-check` | 內部錨點與外部連結不失效 |
| **術語一致性** | 自訂 lint（比對 `_meta/glossary.md`） | 同一概念不使用多種名稱（如「使用者」vs「用戶」混用） |
| **範例可執行** | 對應語言的 doctest / CI job | 程式碼區塊實際跑過並通過，非手寫猜測輸出 |
| **格式檢查** | markdownlint / Vale | 標題階層、風格一致性 |

- [ ] 新增/修改文檔的 PR 必須通過上述 CI 才可合併
- [ ] Reference 類文檔（API/CLI）優先考慮「從程式碼/schema 自動產生」以避免漂移

---

## 5. 文檔擁有者 = 功能擁有者

- 每份文檔在 `_meta/owners.yaml` 標註擁有者，**預設為該功能的程式碼擁有者**，而非獨立文檔團隊
- 功能變更的 PR 若影響行為，**同一 PR** 需同步更新對應文檔（docs-as-code 的核心要求）
- 擁有者異動（如離職、轉調）時，於下一次每季稽核（見第 6 節）重新指派

```yaml
# _meta/owners.yaml 範例
docs/how-to/deploy.md: "@platform-team"
docs/reference/api/openapi.yaml: "@backend-team"
docs/explanation/architecture-overview.md: "@arch-lead"
```

---

## 6. 維護排程

### 每月
- [ ] 檢查外部連結有效性（CI 自動跑，人工複核失效項）
- [ ] 更新截圖和 UI 參考
- [ ] 更新版本號和日期

### 每季（全面稽核）
- [ ] 逐份文檔確認擁有者仍正確、內容仍準確
- [ ] 檢查是否有內容跨象限混雜（見第 1 節），需要則拆分
- [ ] 更新架構圖與 ADR 索引
- [ ] 分析文檔使用/搜尋指標，找出高流量但低評價的頁面優先修
- [ ] 標記過時文檔為 `[Deprecated]` 或直接歸檔刪除

---

## 7. README 模板

```markdown
# [專案名稱]

## 描述
[專案簡述]

## 安裝
[安裝指令]

## 使用方式
[基本使用範例，連結至 tutorials/getting-started.md]

## API 參考
[連結到 reference/api/]

## 貢獻
參見 [CONTRIBUTING.md](CONTRIBUTING.md)

## 授權
[授權名稱]
```

## 8. CHANGELOG 模板

```markdown
# 變更記錄

## [Unreleased]
### 新增
### 變更
### 修復

## [1.0.0] - YYYY-MM-DD
### 新增
- 初始版本
```

---

## 9. 最佳實踐

1. **隨開發同步撰寫**：功能 PR 與文檔更新同一個 PR，不事後補
2. **文檔也要 Review**：納入 Code Review 流程，套用 `11_code_review_and_refactoring_guide.md` 的留言規範
3. **象限先行**：下筆前先判斷屬於哪個 Diátaxis 象限，避免寫到一半失焦
4. **人人有責**：文檔擁有者制度不代表只有一人能改，而是「誰負責最終品質」
5. **持續改善**：每季稽核收集回饋，優化目錄結構與內容
