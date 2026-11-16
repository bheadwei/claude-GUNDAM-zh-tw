---
status: 已接受
date: 2026-11-16
decision-makers: [使用者]
consulted: [planner]
informed: []
---

# ADR-2026-11-16-001: 專案圖解的網址 token 永久固定，外洩時手動 `--rotate`

取代 ADR-2026-11-12-003 第 1 節「每次新起都換新 token」一條，以及該 ADR「犧牲」第 3 點的前提。其餘決策照舊。

## 背景

ADR-003 讓每次新起伺服器都換新 token。實際使用上，伺服器閒置 30 分鐘就結束，分頁切走再回來時網址已經失效，
使用者得重跑 `/task-status` 取得新網址、舊書籤與舊分頁全部作廢。
網址要固定到同一個專案重起也一樣（token 與 port 都不變），這條取捨要重看。

## 決策驅動因素

* 書籤與舊分頁在伺服器重起後仍能用（頁面會自己接回，見同 plan 階段 2）
* 不降低 ADR-003 擋同機其他使用者與 DNS rebinding 的能力
* 外洩時使用者要有明確的補救動作

## 決策

選擇 **token 與 port 存進 `overview/.serve-keep`，重起時沿用；外洩時跑 `overview-serve.sh --rotate` 換新**，
因為它只改「誰決定 token」這一點，其餘防護完全不動。

- `.serve-keep`：單行 JSON `{"token","port"}`，0600，與 `.serve` 同在 `overview/`（`MAIN_CLAUDE` 側，不進 git）。閒置結束與 `--stop` 都**不刪**它
- 沿用條件：token 符合 `^[A-Za-z0-9_-]{20,64}$`，且（POSIX）檔案沒有 group／other 權限位元。不符 → 產新 token（`secrets.token_urlsafe(16)`）
- 權限不是 600 視為可能外洩，自動換新 token 並把檔案寫回 600
- port：bind 時先試 `.serve-keep` 的 port（限 1024–65535），失敗再從 `OVERVIEW_SERVE_PORT_BASE` 起試 20 個；實際 bind 到的 port 寫回 `.serve-keep`
- `--rotate`：在跑就先走 `.shutdown`，刪 `.serve-keep`，再照新起流程（會開瀏覽器）
- `.serve-keep` 是點開頭，`_serve_file` 本來就拒絕，GET 任何路徑都是 404

### 威脅模型重看

| 威脅 | 結論 |
|---|---|
| 同機其他使用者 | 成立：`.serve-keep`、`.serve` 皆 0600，讀不到；port 看得到但沒有 token 只拿到 404 |
| DNS rebinding／本機惡意網頁 | 成立：token 128 bit（`token_urlsafe(16)`），固定不會讓它變得可猜 |
| **網址外洩（新增風險）** | 瀏覽器歷史、螢幕分享、終端機捲動紀錄、對話 transcript 裡的網址，外洩後一直有效；舊做法重起即失效。對策：`--rotate`；`.serve-keep` 權限不對自動換 |

## 替代方案

| 方案 | 優點 | 缺點 | 否決理由 |
|---|---|---|---|
| 每次換（現狀） | 外洩的網址最多活到伺服器結束 | 書籤、舊分頁每次閒置結束後都失效，要重跑指令 | 使用者每天碰到的痛點比外洩風險大 |
| 固定 | 書籤可用、分頁自動接回 | 外洩後一直有效，要使用者主動 rotate | **採用**；圖解只含路徑與任務名，綁 127.0.0.1，外洩面小 |
| 固定但 N 天自動換 | 外洩有壽命上限 | 仍會讓書籤過幾天作廢；要記時間戳與換發邏輯；N 沒有依據 | 多一套機制換來的保護有限，手動 `--rotate` 已夠 |

## 後果

**得到：** 網址同一個專案重起也不變，可加書籤。

**犧牲：** 網址外洩後不會自己失效，要使用者想到才 `--rotate`。

**何時該重新考慮：** 圖解開始含更敏感內容（金鑰、客戶資料）、或要支援非 127.0.0.1 的綁定時，改回每次換或加壽命。

## 確認方式

- [T] 起、`--stop`、再起 → 兩次網址相同；閒置結束後再起 → 相同，且 `.serve-keep` 還在
- [T] 沿用 port 被佔 → 從起始 port 找空的，token 不變，`.serve-keep` 的 port 更新
- [T] `.serve-keep` 644／壞 JSON／token 太短 → 換新 token 照常起，權限回 600
- [T] `--rotate` → token 不同、舊網址 404、瀏覽器開 1 次
- [T] GET `/.serve-keep`、`/<token>/.serve-keep` → 404

## 相關

- 取代：ADR-2026-11-12-003 第 1 節 token 一條
- 計畫：`.claude/taskmaster-data/plans/adhoc-2026-11-16-overview-stable-url.md` 階段 1
