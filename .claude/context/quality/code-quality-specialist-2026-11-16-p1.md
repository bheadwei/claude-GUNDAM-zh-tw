---
agent: code-quality-specialist
date: 2026-11-16-1200
area: quality
target: feat/overview-stable-url-p1（7d5ecbd..433a672）
severity: high
status: findings
---

# 專案圖解網址固定 階段 1：安全與正確性通過，測試案例數兩平台不一致（HIGH）

## TL;DR
- 安全面無 CRITICAL；`.serve-keep` 寫入原子且 0600。
- HIGH 1 項：「權限 644 換 token」整組在 Windows 略過，沒補 else，案例數兩平台差 3，踩 learned 2026-11-09 的坑。
- `overview-serve` 一節 107 通過 0 失敗。

## 發現

### HIGH
- `.claude/hooks/tests/run-tests.sh:6018-6028` — `case uname` 在 MINGW/MSYS/CYGWIN 分支是空的，Windows 少 3 個案例（`權限 644 → 換新 token`、`照常起、exit 0`、`權限回到 600`）。learned 的 guard 要求「平台條件案例的 else 分支補同樣數量的 ok『（…略過）』」。`check-counts.sh --tests N` 以 Ubuntu 為準，Windows 實跑數字會對不上。此前例 `:5828` 與 `sv_perm` 用的是「值替換」，計數一致，這一組是整組跳過。
  修法：Windows 分支補 3 個 `ok "…（Windows 無 POSIX 權限，略過）"`，文字對應上面 3 個案例。

### MEDIUM
- ADR-2026-11-12-003 第 42 行仍寫「每次新起都換新 token，舊網址隨之失效」，只靠檔頭一行說明取代。新 ADR 已寫明取代範圍，足夠不誤導；建議把第 42 行尾端加「（已被 ADR-2026-11-16-001 取代）」，讀者不用回頭看檔頭。「犧牲」第 3 點（分頁超過 30 分鐘伺服器結束）本身仍成立，不必改。
- `overview-serve.sh` 的 `--rotate`：`stop_server` 若 `.shutdown` 20 次輪詢後伺服器仍活著，仍會刪 `.serve-keep` 然後走 `running` 分支印出舊 token 網址，舊 token 沒有失效。這需要伺服器關不掉才會發生，機率低，但 rotate 的目的就是讓舊網址失效。建議 rotate 在 stop 後若仍 `running` 就 fallback 報錯。
- 整套案例數文件（WORKFLOW:476/483、README、tests/README）本階段沒更新，新增約 28 個案例。依「整套留到本輪最後」處理即可，記得收尾時用 `--tests N` 對。

### LOW
- `bind()` 把 preferred 插在前面，若 preferred 落在 base..base+19 內會重試同一 port 一次，無害。

## 逐項確認（交辦重點）
1. 安全：
   - `write_serve` 用 `os.open(tmp, ..., 0o600)` 加 `os.replace`，同目錄原子；`os.umask(0o077)` 在更前面設好；暫存檔名帶 pid（`.serve-keep.<pid>.tmp`，點開頭同樣被服務層拒絕）。
   - 同時起兩個由 `.serve.lock` 擋，keep 競態在其保護內。
   - `TOKEN_RE` 錨定、長度 20–64、字元集合受限，`token_urlsafe(16)` 為 22 字元，符合。
   - 權限檢查為 `st_mode & 0o077`，非 nt 才做，符合 ADR。
   - `GET /.serve-keep`、`/<token>/.serve-keep` 皆 404 有測。
   - bind 一律 `127.0.0.1`，preferred 只限 1024–65535。
   - 舊 token 失效：rotate 測試涵蓋 404，見上方 MEDIUM 的例外。
2. 正確性：bind 回退、壞 JSON、短 token、閒置後 keep 還在、port 被佔更新 keep 皆有案例且通過；`bool` 不當 port 處理正確。`keep` 路徑 symlink 屬同使用者目錄，不報。
3. 測試：ADR「確認方式」5 條都有對應案例，唯一問題是上面的 HIGH。
4. ADR：替代方案 3 個（每次換、固定、固定加 N 天換）、威脅模型三點齊全。

## 結論
WARNING：1 個 HIGH（Windows 案例數）合併前修。

## 交接
無（測試補齊屬實作者範圍，非「完全沒有測試」）。
