# Skills 取材池索引（94 個）

> 此目錄為**備份取材池**，不參與模板執行。需啟用某項時複製到 `.claude/skills/`。
> ★ = 已啟用於 `.claude/skills/`（主模板精選 8 個）

## 1. 通用工程 / 編碼標準（13）

| Skill | 一句話用途 |
| :--- | :--- |
| ★ **api-design** | REST API 設計（命名、狀態碼、分頁、版本） |
| ★ **coding-standards** | TypeScript / JavaScript / React / Node.js 通用標準 |
| ★ **deployment-patterns** | CI/CD、Docker、健康檢查、回滾策略 |
| ★ **docker-patterns** | Docker / Compose 開發、安全、網路、卷 |
| ★ **e2e-testing** | Playwright E2E、POM、artifacts、flaky 處理 |
| ★ **security-review** | 認證、輸入處理、秘密、API 端點安全清單 |
| ★ **tdd-workflow** | TDD 完整流程，80%+ 覆蓋率 |
| ★ **deep-research** | firecrawl + exa 多源研究與引註 |
| backend-patterns | Node.js / Express / Next.js API 路由架構 |
| frontend-patterns | React / Next.js / 狀態管理 / 效能 |
| database-migrations | PostgreSQL/MySQL/Prisma/Drizzle 遷移與零停機 |
| security-scan | 用 AgentShield 掃 .claude/ 設定漏洞 |
| content-hash-cache-pattern | SHA-256 內容雜湊快取，路徑無關 |

## 2. AI / Agent 工作流（23）

| Skill | 一句話用途 |
| :--- | :--- |
| agent-harness-construction | 設計 agent action space / tool / observation |
| agentic-engineering | eval-first 執行、分解、cost-aware 路由 |
| ai-first-engineering | AI 大量產出程式碼的團隊作業模型 |
| autonomous-loops | 自主 Claude Code 迴圈架構（從 pipeline 到 RFC DAG） |
| blueprint | （描述跨行）專案藍圖規劃 |
| configure-ecc | Everything Claude Code 互動式安裝器 |
| continuous-agent-loop | 含 quality gate / eval / 復原的連續 agent loop |
| continuous-learning | 從 session 自動萃取可重用 skill |
| continuous-learning-v2 | v2.1：instinct 系統 + 專案隔離 |
| cost-aware-llm-pipeline | LLM API 成本優化、模型路由、預算追蹤 |
| dmux-workflows | 用 dmux（tmux for AI agents）做多 agent 平行 |
| enterprise-agent-ops | 長壽 agent workload 的觀測 / 安全 / 生命週期 |
| eval-harness | Claude Code session 的 eval-driven development |
| iterative-retrieval | 漸進式 context 取回（解 subagent context 問題） |
| nanoclaw-repl | 操作 / 擴充 NanoClaw v2 REPL |
| plankton-code-quality | hook 上的寫入時 lint / format / Claude 修復 |
| prompt-optimizer | （描述跨行）prompt 優化 |
| ralphinho-rfc-pipeline | RFC 驅動的多 agent DAG + quality gate + merge queue |
| regex-vs-llm-structured-text | 結構化文字解析的決策框架（先 regex 再 LLM） |
| search-first | 寫 code 前先搜尋既有工具 / 套件 / 模式 |
| skill-stocktake | 審計 Claude skills / commands 品質 |
| strategic-compact | 在邏輯節點手動 compact 而非自動 |
| verification-loop | Claude Code session 的全面驗證系統 |

## 3. 語言 / 框架

### C++（2）
| Skill | 一句話用途 |
| :--- | :--- |
| cpp-coding-standards | C++ Core Guidelines |
| cpp-testing | GoogleTest / CTest / 覆蓋率 / sanitizer |

### Java / Spring Boot（6）
| Skill | 一句話用途 |
| :--- | :--- |
| java-coding-standards | Spring Boot 服務命名、不可變、Optional、stream |
| springboot-patterns | Spring Boot 架構、REST、分層、快取、async |
| springboot-security | authn/authz / CSRF / 標頭 / rate limit |
| springboot-tdd | JUnit 5 / Mockito / MockMvc / Testcontainers |
| springboot-verification | build / 靜態分析 / 測試 / 安全掃描 |
| jpa-patterns | JPA / Hibernate / 關聯 / 查詢優化 / 池化 |

### Python（2）
| Skill | 一句話用途 |
| :--- | :--- |
| python-patterns | PEP 8 / 型別 / Pythonic 慣用 |
| python-testing | pytest / TDD / fixture / mock / coverage |

### Go（2）
| Skill | 一句話用途 |
| :--- | :--- |
| golang-patterns | 慣用 Go 模式 |
| golang-testing | table-driven / subtests / fuzz / coverage |

### Perl（3）
| Skill | 一句話用途 |
| :--- | :--- |
| perl-patterns | Perl 5.36+ 現代慣用 |
| perl-security | taint mode / DBI / web 安全 / perlcritic |
| perl-testing | Test2::V0 / prove / Devel::Cover |

### Kotlin（5）
| Skill | 一句話用途 |
| :--- | :--- |
| kotlin-patterns | 慣用 Kotlin（coroutines / null safety / DSL） |
| kotlin-coroutines-flows | 結構化並行 / Flow operator / StateFlow / 測試 |
| kotlin-exposed-patterns | Exposed ORM / DSL / DAO / Flyway |
| kotlin-ktor-patterns | Ktor server / 路由 DSL / Koin / WebSocket |
| kotlin-testing | Kotest / MockK / coroutine 測試 / Kover |

### Django（4）
| Skill | 一句話用途 |
| :--- | :--- |
| django-patterns | DRF / ORM / 快取 / signal / middleware |
| django-security | authn / CSRF / SQLi / XSS / 部署 |
| django-tdd | pytest-django / factory_boy / DRF API 測試 |
| django-verification | 遷移 / lint / 測試 / 安全掃描 |

### Swift / iOS（6）
| Skill | 一句話用途 |
| :--- | :--- |
| swift-actor-persistence | Swift actor 做執行緒安全持久化 |
| swift-concurrency-6-2 | Swift 6.2 Approachable Concurrency |
| swift-protocol-di-testing | protocol-based DI / Swift Testing |
| swiftui-patterns | @Observable / 組合 / 導航 / 效能 |
| foundation-models-on-device | iOS 26 Apple FoundationModels（@Generable） |
| liquid-glass-design | iOS 26 Liquid Glass 設計系統 |

### Android / KMP（2）
| Skill | 一句話用途 |
| :--- | :--- |
| android-clean-architecture | Clean Architecture / 模組 / UseCase / Repository |
| compose-multiplatform-patterns | Compose Multiplatform / KMP UI |

### Database（2）
| Skill | 一句話用途 |
| :--- | :--- |
| clickhouse-io | ClickHouse 查詢優化、分析工作負載 |
| postgres-patterns | PostgreSQL 查詢 / schema / 索引（Supabase） |

## 4. API / MCP 整合（6）

| Skill | 一句話用途 |
| :--- | :--- |
| claude-api | Anthropic Messages API / streaming / tool use / Agent SDK |
| exa-search | Exa MCP 神經搜尋 |
| fal-ai-media | fal.ai MCP 圖 / 影 / 音生成 |
| nutrient-document-processing | Nutrient DWS 文件處理（OCR / 簽署 / 填表） |
| videodb | VideoDB 影片資料庫 |
| x-api | X / Twitter API 發文、threads、搜尋 |

## 5. 內容 / 寫作 / 商業（9）

| Skill | 一句話用途 |
| :--- | :--- |
| article-writing | 文章 / 教學 / newsletter，保持品牌語氣 |
| content-engine | X / LinkedIn / TikTok / YouTube 平台原生內容 |
| crosspost | 多平台分發（X / LinkedIn / Threads / Bluesky） |
| frontend-slides | HTML 動畫簡報（含 PPT 轉換） |
| investor-materials | pitch deck / one-pager / 財務模型 |
| investor-outreach | 冷信 / 暖介紹 / follow-up |
| market-research | 市場調研 / 競品分析 / 投資人盡調 |
| video-editing | AI 輔助影片剪輯（FFmpeg / Remotion / fal.ai） |
| visa-doc-translate | 簽證文件翻譯 + 雙語 PDF |

## 6. 產業垂直（8）

供應鏈 / 貿易 / 製造領域，多為內部專案範本：

| Skill | 領域 |
| :--- | :--- |
| carrier-relationship-management | 物流承運商管理 |
| customs-trade-compliance | 海關貿易合規 |
| energy-procurement | 能源採購 |
| inventory-demand-planning | 庫存需求規劃 |
| logistics-exception-management | 物流異常管理 |
| production-scheduling | 生產排程 |
| quality-nonconformance | 品質不符合處理 |
| returns-reverse-logistics | 退貨逆物流 |

## 7. 範本（1）

| Skill | 一句話用途 |
| :--- | :--- |
| project-guidelines-example | 真實生產應用的專案 skill 範例樣板 |

---

## 取材建議（依專案類型）

| 專案類型 | 建議追加 |
| :--- | :--- |
| Python / Django | python-patterns, python-testing, django-* |
| Go 服務 | golang-patterns, golang-testing, postgres-patterns |
| Spring Boot | java-coding-standards, springboot-*, jpa-patterns |
| Kotlin / Android | kotlin-*, android-clean-architecture |
| iOS | swift-*, swiftui-patterns |
| 多 agent 自動化 | autonomous-loops, ralphinho-rfc-pipeline, eval-harness |
| 含資料庫 | database-migrations, postgres-patterns |
| 內容創作 | content-engine, article-writing, crosspost |
