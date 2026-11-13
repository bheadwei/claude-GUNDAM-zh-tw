---
agent: code-quality-specialist
date: 2026-11-12
scope: "專案地圖改版 階段 4（git diff 3342b90..c4404e5）"
status: PASS
---

# 階段 4 審查：本機伺服器與 /task-status 開頁

（審查者未寫報告檔，由主模型依其回覆落檔。只讀程式，沒跑測試。）

結論：PASS。CRITICAL 0、HIGH 0、MEDIUM 3、LOW 5。並發、閒置結束、--stop、平台分支、退路都有案例，不建 handoff。

## 已確認正確
- 鎖：`mkdir .serve.lock`、拿鎖後再讀 `.serve`（overview-serve.sh:92-95）、EXIT trap 釋放
- 閒置結束刪 `.serve` 不會刪到新伺服器的檔（overview-serve.py:156-162 比對 token 與 pid）
- `/dev/tcp` 用 `read -t 3`；背景行程三個串流都改道，呼叫端不會等
- 開瀏覽器失敗不影響 exit code，stdout 最後一行永遠是網址或 file://
- implementer 自述四項差異皆可接受

## 發現
- [MEDIUM-1] run-tests.sh:5462-5465：主機有真的 `python3.13` 時會先被選到，「用 python3.12」案例失敗
- [MEDIUM-2] run-tests.sh:5406-5408：macOS `netstat -an` 格式為 `127.0.0.1.8765`，「只聽 127.0.0.1」案例必失敗；ss／netstat 都沒有時退成只看 .serve（恆真）
- [MEDIUM-3] overview-serve.sh:85-91：鎖內沒有持有者 pid，被 kill -9 後下次要等約 10 秒；持鎖者慢於 10 秒會被偷鎖、起第二個伺服器
- [LOW-1] overview-serve.sh:109 起新伺服器前先刪 .serve，overview-serve.py:131 的沿用 token 是死碼；ADR「重起後舊書籤仍能用」不成立
- [LOW-2] overview-serve.sh:97、:110：`OVERVIEW_SERVE_PYTHON` 路徑含空格會被拆字，錯誤訊息誤導
- [LOW-3] overview-serve.sh:126：開瀏覽器同步呼叫無逾時，前景瀏覽器會卡住 /task-status
- [LOW-4] overview-serve.py:53：非 ASCII 路徑使 `hmac.compare_digest` 拋 TypeError
- [LOW-5] task-status.md:29-33 仍要求 --print-path，與 overview-serve.sh 自印 file:// 重複；README／WORKFLOW「每 3 秒」與階段 3 的 2 秒不一致（建議階段 7 一併核對）

## 未驗證
macOS bash 3.2 的 /dev/tcp、Git Bash 背景行程存活（ADR 第 5 節手動驗收）

STATUS: DONE_WITH_CONCERNS
