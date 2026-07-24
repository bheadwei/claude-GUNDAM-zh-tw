# BDD 行為驅動情境指南

> **版本:** v2.0 | **更新:** YYYY-MM-DD | **狀態:** 草稿/審核中/已批准

> 撰寫指引：本檔為**骨架範本**。先做 Example Mapping 對齊三方認知，再依 BRIEF 原則寫 Gherkin；每節保留精簡指引，不做長篇論述。

---

## 1. Example Mapping（撰寫 Scenario 前必做）

> 目的：PO、Dev、QA 三方在動手寫 Gherkin 前，用四色卡片對齊「這個功能到底要做什麼」，避免寫到一半才發現理解不一致。建議 25 分鐘 timebox。

| 卡片顏色 | 代表 | 內容 |
| :--- | :--- | :--- |
| 🟨 黃卡 | Story | 對應 PRD 的 Epic/User Story 標題 |
| 🟦 藍卡 | Rule | 該 Story 下的業務規則（一條規則 = 一張卡） |
| 🟩 綠卡 | Example | 每條 Rule 的具體例子（含真實資料） |
| 🟥 紅卡 | Question | 對齊過程中發現的未決問題，不阻塞、先記錄 |

### 1.1 Mapping 範本

```
🟨 Story: [功能名稱]

  🟦 Rule: [業務規則 1]
    🟩 Example: [具體例子 1]
    🟩 Example: [具體例子 2]

  🟦 Rule: [業務規則 2]
    🟩 Example: [具體例子 1]

  🟥 Question: [未決問題] → 負責人：[誰] / 截止：[何時]
```

### 1.2 何時完成，可以進入寫 Gherkin

- [ ] 每條 Rule 至少有 1 個綠卡 Example
- [ ] 紅卡數量收斂（多張紅卡代表 Story 尚未成熟，不急著寫測試）
- [ ] PO/Dev/QA 三方對範圍無異議

---

## 2. BRIEF 原則（寫 Scenario 的品質準則）

> 撰寫指引：每寫完一個 Scenario，對照以下五項自我檢查。

| 原則 | 說明 |
| :--- | :--- |
| **B**usiness language | 用業務語言而非技術術語（`使用者登入失敗` 而非 `HTTP 401`） |
| **R**eal data | 用真實/貼近真實的資料，避免 `foo`/`bar`/`test1` |
| **I**ntention-revealing | 一看就懂「為什麼」，而非只描述「怎麼做」 |
| **E**ssential | 只保留驗證該 Rule 必要的步驟，砍掉多餘鋪陳 |
| **F**ocused | 一個 Scenario 只驗證一件事，不疊加多條 Rule |

---

## 3. Gherkin 語法速查

| 關鍵字 | 用途 |
| :--- | :--- |
| `Feature` | 高層次功能，對應 PRD 中的 Epic |
| `Rule` | 對應 Example Mapping 藍卡，一條業務規則 |
| `Example` (別名 `Scenario`) | 對應綠卡，具體業務場景/測試案例 |
| `Given` | 初始狀態 (Arrange) |
| `When` | 使用者操作/業務事件 (Act) |
| `Then` | 預期結果 (Assert) |
| `And/But` | 連接多個步驟 |
| `Background` | 所有 Rule/Example 共用的前置步驟 |
| `Scenario Outline` + `Examples` | 參數化多組資料測試 |

---

## 4. 範本：以 `Rule:`/`Example:` 分組

**檔案名稱**: `[feature_name].feature`

```gherkin
Feature: [功能名稱]
  # 對應 PRD: [Link]
  # 對應 Example Mapping: [Link 或日期]

  Background:
    Given [共用前置條件]

  Rule: [業務規則 1，來自藍卡]

    @happy-path @smoke-test
    Example: [正常流程描述，來自綠卡]
      Given [前置狀態，用真實資料]
      When [業務事件，非 UI 操作]
      Then [預期結果]

    @sad-path
    Example: [異常流程描述]
      Given [前置狀態]
      When [錯誤事件]
      Then [錯誤處理結果]

  Rule: [業務規則 2]

    @edge-case
    Scenario Outline: [邊界情況描述]
      Given [前置狀態 "<field>"]
      When [業務事件 "<value>"]
      Then [預期結果 "<message>"]

      Examples:
        | field | value | message |
        | ...   | ...   | ...     |
```

---

## 5. 最佳實踐

1. **一個 Example 只測一條 Rule**——對應 BRIEF 的 Focused
2. **使用陳述式** — `Then I should be redirected to...`（非 `Then the system redirects...`）
3. **禁止 UI click-by-click 腳本** — 見第 6 節，一律描述業務意圖而非操作細節
4. **從使用者角度編寫** — 非技術人員也能讀懂，用業務語言（BRIEF 的 Business language）
5. **先 Example Mapping、後寫 Gherkin** — 未完成第 1 節對齊前不動手寫 `.feature`

---

## 6. 禁止事項：UI Click-by-Click 腳本

> 撰寫指引：Gherkin 描述「業務意圖」，不是「操作紀錄」。以下對照表為強制規範，非建議。

| ❌ 禁止（技術/UI 細節） | ✅ 應改為（業務意圖） |
| :--- | :--- |
| `When I click the green "Submit" button` | `When 使用者送出訂單` |
| `When I fill in "#email-input" with "a@b.com"` | `Given 使用者已輸入有效 Email` |
| `Then the modal with id "success-dialog" appears` | `Then 使用者應看到訂單成立確認` |
| `When I navigate to "/checkout?step=2"` | `When 使用者進入結帳流程` |

**原因**：UI 結構（按鈕顏色、CSS selector、路由參數）屬實作細節，變動頻繁；Gherkin 一旦綁定 UI 細節，會導致：
- 前端重構就要重寫大量 Scenario（維護成本失控）
- 業務規則被 UI 操作噪音淹沒，PO/QA 難以閱讀審核
- 無法作為跨層測試（單元/整合/E2E）共用的需求來源

UI 層級的操作驗證交給 E2E 測試框架的 step definition 實作細節去處理，**不寫進 `.feature` 檔本身**。

---

## 7. Gherkin 作為 AI 協作的結構化需求輸入

> 撰寫指引：本節說明為何本模板要求比傳統 BDD 更嚴格的 Focused/Essential——因為 `.feature` 檔會被直接餵給 AI 代理（如 tdd-guide agent）作為程式化需求來源。

- **結構化輸入**：`Rule:`/`Example:` 分組讓 AI 能將一條業務規則對應到一組測試案例，減少「AI 自行腦補範圍」的風險
- **語意明確 > 語法正確**：AI 會逐字解析 Given/When/Then，模糊或帶 UI 細節的描述會讓 AI 產出錯誤的實作假設
- **允收標準的單一事實來源**：`02_project_brief_and_prd.md` 第 7 節的允收標準應可直接映射為本檔的 `Example:`，供 `/tdd` 流程讀取後生成測試骨架
- **紅卡（Question）不可省略**：未解問題若被 AI 誤當作已確認需求，會產出錯誤功能；寫入 `.feature` 前必須清空或明確標記為 `@pending-clarification`

---

## 8. 交叉引用

- 需求來源：`02_project_brief_and_prd.md` 第 3、5、7 節
- 測試策略對應：`06_module_specification_and_test_plan.md`（若存在，見專案 skill 目錄）
- Example Mapping 紀錄建議存放：`docs/example-mapping/<feature>.md`
