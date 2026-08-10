# Hooks 回歸測試

```bash
bash .claude/hooks/tests/run-tests.sh
```

56 個案例，全數通過才算綠燈（失敗時 exit 1，可直接掛 CI）。
**Windows Git Bash 上約需 1.5 分鐘**——大量 `bash` + `jq` 子行程，process spawn 是主要成本。

## 為什麼這套測試存在

`pre-tool-use.sh` 是模板裡唯一的硬閘門。它壞掉有兩種方式，**兩種都很難用肉眼發現**：

| 失效模式 | 症狀 | 後果 |
|---|---|---|
| 誤擋 | 所有程式碼寫入被 deny | 很吵，會馬上發現 |
| **靜默失效** | 該擋沒擋，一切看起來正常 | **不會發現** |

第二種正是這個模板的歷史教訓：`.current-task-mode` 該清沒清，導致入口自動分級
永久不觸發，壞了很久都沒人察覺。測試就是為了讓靜默失效變成紅燈。

## 涵蓋範圍

| 區塊 | 案例數 | 重點 |
|---|---|---|
| 任務模式閘門（無模式檔） | 11 | 程式碼檔擋、文件/設定/`.claude`/`docs`/依賴放行、deny 訊息含判級指引 |
| 有模式檔 | 7 | 有效放行、空檔視同無、TTL 未過期不清除、**過期必須清除（解互鎖）**、TTL 可調 |
| 逃生門 | 3 | `.suggest-mode=off`、`TASKMODE_GATE=off`、`low` 仍會攔 |
| 裸 `cd` 偵測 | 6 | 裸 cd 擋；`&&`、`;`、subshell、非 cd 指令放行 |
| handoff 注入 | 9 | pending 注入含 from/to/優先級/起因；completed 不注入；suggest-mode 分級過濾；範本檔不誤判 |
| 意圖路由 | 8 | auth→critical、UI/npm/測試→提示載入對應 skill、斜線指令不路由 |
| 全體 hooks | 12 | 語法可解析、空 payload 不爆炸 |

## 隔離保證

所有測試在 `mktemp -d` 沙箱內執行，`CLAUDE_PROJECT_DIR` 指向沙箱。
**絕不觸碰真實的 `.claude/taskmaster-data/` 或 `coordination/handoffs/`**，
跑測試不會清掉你當前的任務模式或交接檔。結束時 `trap` 自動清理沙箱。

## 改了 hook 之後

1. 跑一次 `run-tests.sh`，確認全綠
2. **加測試**——新分支要有對應案例，否則下一個人改它時沒有保護

## 驗證測試本身有效（突變測試）

一套在壞掉的程式上也會過的測試沒有價值。改動測試框架後，用突變確認它還抓得到：

```bash
cp .claude/hooks/pre-tool-use.sh /tmp/bak

# 突變 1：拿掉 TTL 清除 → 應有 2 個案例失敗
sed -i 's|rm -f "$MODE_FILE" 2>/dev/null|:|' .claude/hooks/pre-tool-use.sh
bash .claude/hooks/tests/run-tests.sh   # 期望 exit 1

# 突變 2：閘門永遠放行 → 應有多個案例失敗
cp /tmp/bak .claude/hooks/pre-tool-use.sh
sed -i '/模式已存在 → 放行/{n;s|.*|exit 0|}' .claude/hooks/pre-tool-use.sh
bash .claude/hooks/tests/run-tests.sh   # 期望 exit 1

git checkout -- .claude/hooks/pre-tool-use.sh   # 還原（比 cp 可靠）
```

> 還原務必用 `git checkout --`，不要只依賴 `cp` 備份——
> 若中途逾時或中斷，備份還原那一步可能根本沒執行到。

## 加新案例

`run-tests.sh` 內建的斷言：

```bash
expect_decision "案例名稱" deny  "$(run pre-tool-use.sh "$(w /p/src/a.ts)")"
expect_contains "案例名稱" "子字串" "$(run user-prompt-submit.sh "$(p '使用者輸入')")"
expect_empty    "案例名稱" "$(run post-agent-report.sh '{}')"
```

payload 產生器：`w <路徑>`（Write）、`e <路徑>`（Edit）、`b <指令>`（Bash）、`p <文字>`（prompt）。
每個區塊開頭記得 `reset` 清乾淨沙箱狀態。
