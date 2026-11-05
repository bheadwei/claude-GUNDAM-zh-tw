# overview-scan 效能實測（2026-11-05）

**結論：5,000 檔整條掃描約 1.0 秒、6 個行程，低於門檻（≤ 3 秒、≤ 12 個行程）→ 照原設計，不需要把增量掃描提前到階段 1。**

## 環境與方法

- Windows 11、Git Bash（gawk）、git 2.x、`LC_ALL=C` 給 awk
- 測試資料：`gen-large.sh 2000|5000`（60 個目錄、`.py` 與 `.ts` 各半、每檔 3 行，其中 1 行是 import）
- 每組量 3 次、取最小值；輸出一律導到 `/dev/null`
- **量測時有另一條線在本機跑**（文件與 check-counts 工作），數字偏保守；2k 的 `git ls-files` 比 5k 慢就是這個干擾造成的
- 掃描樣式（Python 與 TS 的聯集）：`^[[:space:]]*(from|import)[[:space:]]|require\(|import\(`，限定 `*.py *.ts *.tsx`

## 結果（最小值，毫秒）

| 步驟 | 2,000 檔 | 5,000 檔 |
|---|---|---|
| `git -c core.quotepath=off ls-files -z` | 446 | 310 |
| `git -c core.quotepath=off grep -z -n -I -E '<樣式>'` | 360 | 551 |
| 上一行 `\| tr '\0' '\t' \| awk -F'\t'` 解析一趟（含 grep 本身） | 577 | 694 |
| 整條：`rev-parse HEAD` ＋ `ls-files -z \| awk` ＋ `grep \| tr \| awk` | 917 | 1,040 |

## 行程數（依設計逐一列出）

整條量測是 6 個行程：

1. `git rev-parse HEAD`
2. `git ls-files -z`
3. `awk`（檔案清單 → 目錄統計）
4. `git grep -z -n -I -E`
5. `tr '\0' '\t'`（awk 不直接以 `\0` 切欄，gawk 與 mawk 行為不同）
6. `awk`（import 行 → 邊）

實作時還會多的行程（沒有納入計時，成本是各一個行程）：工作區改動清單的 `git status --porcelain -z`（快取 key）、算 key 的 `cksum`、`mktemp`、`mv`（暫存檔換名）。合計 10 個，仍在 ≤ 12 之內。

## 判讀與限制

- 5,000 檔 1.0 秒，離 3 秒的門檻有 3 倍餘裕；行程數 6～10，離 12 有餘裕
- 本次每個檔只有 3 行。真實專案的檔案平均幾百行，`git grep` 要讀的位元組多很多，這一步會比表上的數字慢；3 倍餘裕就是為此留的。階段 1 做完 `overview-scan.sh` 後，應該拿一個真實專案再量一次整條
- 同一個 `HEAD` 與工作區改動清單重複掃描時，快取 key 命中就不重掃，所以重複觸發的成本是 `rev-parse` ＋ `status` 兩個行程
- 本次沒有量 20,000 檔（`OVERVIEW_SCAN_MAX_FILES` 的預設上限）：超過上限時只做目錄層級、不掃邊，所以不需要 `git grep`
