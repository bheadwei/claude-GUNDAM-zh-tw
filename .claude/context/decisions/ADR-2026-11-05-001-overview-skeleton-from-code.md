---
status: 已採納
date: 2026-11-05
decision-makers: [使用者]
---

> **定案（2026-11-05，問答紀錄 `.claude/qa-history/2026-11-05-153000-overview-from-code-adr.md`）**
> - Q3 實測專案的結構：**Python 後端＋JS/TS 前端**，`backend/`、`frontend/` 分開。fixture 與掃描規則以
>   Python（`import`／`from … import`、FastAPI 路由）與 JS/TS（`import`／`require`、前端 fetch 呼叫）優先；C#／Java 規則照做但不是驗收主軸
> - Q5 寫程式碼檔時背景重掃、30 秒節流：**同意**
> - Q6 codegraph adapter 先不做，只保留 `edges[].source` 的位置：**同意**
> - 實作計畫：`.claude/taskmaster-data/plans/adhoc-2026-11-05-overview-from-code.md`

# ADR-2026-11-05-001: 專案地圖的骨架改以程式碼掃描為準，架構文件降為選配覆寫

## 背景

現行 `overview.sh` 的地圖骨架完全取自架構文件 5.5 模組表（要有 `id`、`路徑` 欄）與 5.1 mermaid。
使用者在真實專案 for-query 實測：文件放在 `docs/architecture/` 子資料夾，5.1 是 C4 系統情境圖（使用者／LDAP／MSSQL／Redis），
不是程式模組，結果整張圖全灰、對不到程式碼，WBS 沒有模組欄，30 多個任務都對不到模組。
使用者的核心觀點是：文件不一定反映現況，實際開發看的是 WBS 與 plan。
那麼地圖到底該畫「文件說的樣子」還是「程式碼現在的樣子」？

## 決策

地圖分三層取資料：**骨架**（有哪些模組、誰依賴誰）由新腳本 `overview-scan.sh` 機械式掃程式碼產生（0 token，
用 `git ls-files` 與 `git grep` 分析目錄、import、路由）；**進度**照舊取自 WBS／plan；架構文件 5.5 降為**選配覆寫**，
只用來沿用既有模組 id、名稱與分組。三方對不上的地方另外產出**落差報告**。

## 替代方案

| 方案 | 優點 | 否決理由 |
|---|---|---|
| 維持現狀（骨架取自 5.5／5.1） | 不用改；文件寫得好時名稱最準 | 文件格式不合或過期時整張圖失效；for-query 這種既有專案永遠用不了 |
| 接 codegraph（tree-sitter＋SQLite，MIT） | 依賴邊最準（真正的呼叫與 import 圖），支援 19 種以上語言 | 要 Node＋npm 安裝原生套件，金融客戶的遠端伺服器可能沒有 Node 或不能連外；要額外的 sqlite3 CLI 才讀得到資料庫。**保留成日後的選配資料來源**（schema 預留 `edges[].source`） |
| 整合 Floorplan（Claude Code plugin，MIT） | 掃描加 AI 白話命名，現成的畫面 | 每次更新都花使用者方案的 token；要 Node 18+ 與本機 server；跟 WBS／plan 的燈號完全沒有接合；在金融環境裝第三方 plugin 要另外過供應鏈審查。2026-11-04 已決定不整合，本次重新評估後維持 |
| 混合：自寫骨架，有裝 codegraph 就拿它補依賴邊 | 兩邊的好處都拿到 | 現在做是 YAGNI：沒有證據顯示 regex 掃描的準確度不夠。先把 adapter 的介面留好，等 C#／Java 專案實測不準再做 |

## 後果

**得到：**
- 文件格式不合的專案也有地圖；骨架反映 `git ls-files` 當下的檔案，不會過期
- 0 token、0 新依賴（bash、awk、jq、git 都是 hook 本來就需要的）
- 落差報告把「文件 vs 程式碼 vs WBS」的漂移變成看得到的清單

**犧牲：**
- regex 掃 import 只是近似。Python、TS／JS、Go 準度高；C#／Java 要靠 namespace 對照，會漏掉反射與 DI 組起來的依賴
- 自動切出來的模組名稱是目錄名，不如人寫的好讀。這一塊由 ADR-2026-11-05-002 的說明層補
- `overview.sh` 的職責變多，所以掃描拆成獨立的 `overview-scan.sh`，產物放快取檔
- 行為變更：架構文件帶 `<!-- overview: draft -->` 時，地圖**不再整個不畫**，只是不拿那份文件來覆寫。舊測試第 3-19 條的預期要改

**何時該重新考慮：**
- C#／Java 專案實測時，掃出來的依賴邊漏掉超過三成（拿人工確認過的依賴清單比對）→ 做 codegraph adapter
- 5,000 檔的 repo 在 Windows Git Bash 背景掃描超過 5 秒 → 改成增量掃描

## 確認方式

- [T] `run-tests.sh` 新增一節：用仿 for-query 結構的合成 fixture（C4 格式的 5.1、沒有模組欄的 WBS、中文路徑），驗證模組數、依賴邊、`modules[].source` 都符合預期
- [T] fixture 帶有效的 5.5 時，模組 id 和 5.5 完全相同（既有專案不退化）。既有 overview 測試除第 3-19 條外**原樣通過**
- [T] jq 1.6 相容：沿用 `run-tests.sh` 的保留字靜態掃描，再加一個 jq 1.6 的 CI job
- [M] 效能：在 Windows Git Bash 掃 2,000 檔與 5,000 檔的 repo，記錄行程數與秒數，寫進階段報告

## 相關

- 設計提案全文：`.claude/context/decisions/architect-2026-11-05-1500.md`
- 部分取代：`skill-curator-2026-11-04-visual-overview-proposal.md` 第 2 節（資料流）與 R5、R9（骨架來源與找架構文件）。
  理由：原本「md 是正本」的前提是文件會照模板格式維護，for-query 證實既有專案不成立
- 相關：ADR-2026-11-05-002（說明層）、ADR-2026-11-05-003（畫面品質基準）
- 部分修訂（2026-11-06）：ADR-2026-11-06-002 保留檔案層級的 import 並把第三方歸類（模組層的邊不變）
