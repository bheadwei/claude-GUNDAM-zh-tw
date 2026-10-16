# 階段 7：ui-builder 截圖驗收與「不准編事實」接線

## TL;DR

`ui-builder` 拿到 Playwright MCP 的 7 個工具，產出後依 `ui-style-compliance` 的斷點規則截圖、
查 console 錯誤與水平捲軸；沒有 MCP 時走 Playwright CLI 退路；兩條都不行就報「截圖未驗證」並回
`DONE_WITH_CONCERNS`。報告新增「截圖驗收」「開放問題」兩節。接線檢查全綠，**行為未驗證**。

## 範圍

- 只改 `.claude/agents/ui-builder.md`（計畫階段 7 的 `files:`）

## 裁決

| 項目 | 裁決 | 理由 |
|---|---|---|
| `ui-builder.md` | Improve | `tools:` 加 `mcp__playwright__browser_{navigate,resize,take_screenshot,console_messages,evaluate,wait_for,close}`；啟動前加第 4 步讀三份附屬檔（條件指向 1.3）；產出後加「反 AI 感對照」（指向 anti-ai.md「產出後」）與「截圖驗收」；紅旗的「2.6 ②」改指 anti-ai.md「文案與事實」 |

## 查證

- Claude Code sub-agents 文件（https://code.claude.com/docs/en/sub-agents）：
  「Subagents inherit the built-in tools and MCP tools available in the main conversation」；
  「Both fields accept MCP server-level patterns in addition to exact tool names: `mcp__<server>` or `mcp__<server>__*`」；
  「When nothing in the `tools` list resolves to a tool … Claude Code usually refuses to launch the subagent」
  → 列確切工具名可行；只要有一項解析得到就能啟動，所以 MCP 沒裝時 agent 照常啟動、只是少了這 7 個
- Playwright MCP README（microsoft/playwright-mcp main）：7 個工具名與參數；`filename` 相對路徑「resolved against the workspace root」；
  `--allow-unrestricted-file-access` 說明「navigation to file:// URLs is blocked」（預設）
- Playwright CLI 1.64.1 `screenshot --help`：`--viewport-size <size>`、`--full-page`
- 本機實測：390 寬、內含 1200px 元素的頁面，`--full-page` 圖寬 1200（PNG 檔頭讀出）；
  evaluate 片段回 `scrollWidth 1200 / overflow true`，console error 計到 1

## 疑慮

- 截圖目錄 `.claude/tmp/ui-screenshots/` 靠 agent 執行時寫一份 `*` 的 `.gitignore` 自我排除；
  CLAUDE.md 說 `.claude/.gitignore` 是版控邊界唯一來源，但這個分支沒有該檔，且不在 `files:` 內
- server 名稱不是 `playwright`（或用 plugin 安裝的 Playwright）時工具名不同，會靜默走退路
- 計畫的 5 項驗收需要階段 6 的範例專案，本輪未跑

## 度量

- check-counts：520 項全部一致
- 壓力測試：未跑（未驗證行為改變）
