# Bash 工作目錄（CWD）規則

## 核心原則

**Bash tool 的 CWD 會跨呼叫持續存在。** 一旦 `cd` 進子目錄卻沒切回來，後續所有相對路徑命令都會從錯的地方找檔案，導致 hook、script、工具鏈的連鎖失敗。

## 規則

### 禁止 ❌

```bash
cd subdir
pwd          # 這輪看起來沒事
```

下一次 Bash 呼叫仍在 `subdir` — 主動汙染後續執行環境。

### 允許 ✅

#### 做法 1：使用絕對路徑（優先）

```bash
ls "$CLAUDE_PROJECT_DIR/.claude/hooks/"
cat /absolute/path/to/file.txt
```

#### 做法 2：Subshell（括號）隔離 cd

```bash
(cd subdir && npm test)
```

括號建立子 shell，`cd` 只影響子 shell，主 session CWD 不變。

#### 做法 3：用 `&&` 鏈式一次執行

```bash
cd subdir && npm test && cd -
```

`cd -` 切回上一個目錄。但若中間命令失敗就回不去，**不如用 subshell**。

## 例外

使用者明確要求「切換到 X 目錄並在那裡作業」時，可連續在該目錄操作。完成後仍應**顯式用絕對路徑**回到專案根，或提醒使用者 CWD 已移動。

## 為什麼重要

- **Hooks 使用絕對路徑觸發**（`$CLAUDE_PROJECT_DIR/.claude/hooks/xxx.sh`），內部有 cd 防衛，但依賴 `PROJECT_ROOT` 計算的操作仍會受影響
- **Build / test 工具**（pytest、jest、cargo）常從 CWD 尋找設定檔
- **Git 操作**在錯誤的子目錄內只會作用到該子 repo（若是 submodule）

## 除錯

若遇到「檔案不存在」但檔案明明在，第一步先：

```bash
pwd
```

確認 CWD 在預期位置。不在就用絕對路徑重跑。
