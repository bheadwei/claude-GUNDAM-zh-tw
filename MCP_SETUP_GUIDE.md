# MCP Server 設定指南

> **版本:** v4.2 | **更新:** 2026-03-16

---

## 初始設定

```bash
# Windows
cp .mcp.json.windows.example .mcp.json

# Linux (Ubuntu / RHEL / CentOS)
cp .mcp.json.linux.example .mcp.json
```

然後編輯 `.mcp.json` 填入你的 API keys。

---

## 目前已啟用（6 個）

| Server | 用途 | API Key |
| :--- | :--- | :--- |
| brave-search | 網路搜尋 | BRAVE_API_KEY |
| context7 | 即時套件文檔查詢 | CONTEXT7_API_KEY |
| github | GitHub PR/Issue 操作 | GITHUB_PERSONAL_ACCESS_TOKEN |
| playwright | 瀏覽器自動化與 E2E | 不需要 |
| sequential-thinking | 鏈式推理 | 不需要 |
| memory | 跨 session 記憶 | 不需要 |

---

## 如何新增 MCP Server

### 步驟 1：編輯 `.mcp.json`

在 `mcpServers` 中加入新 server：

```json
{
  "mcpServers": {
    "existing-servers": "...",
    "new-server": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@package/name"],
      "env": {
        "API_KEY": "your-key-here"
      }
    }
  }
}
```

HTTP 類型（不需要安裝）：

```json
"cloudflare-docs": {
  "type": "http",
  "url": "https://docs.mcp.cloudflare.com/mcp"
}
```

### 步驟 2：啟用 Server

編輯 `.claude/settings.local.json`，在 `enabledMcpjsonServers` 加入名稱：

```json
"enabledMcpjsonServers": [
  "brave-search",
  "context7",
  "github",
  "playwright",
  "sequential-thinking",
  "memory",
  "new-server"
]
```

### 步驟 3：重啟 Claude Code

MCP 設定變更後需要重啟 session 才會生效。

---

## 推薦的 MCP Server

> 建議總數 < 10 個，避免佔用過多 context window。

### 開發工具

| Server | 用途 | 設定 |
| :--- | :--- | :--- |
| supabase | Supabase DB 操作 | `npx -y @supabase/mcp-server-supabase@latest --project-ref=REF` |
| magic | Magic UI 元件 | `npx -y @magicuidesign/mcp@latest` |
| token-optimizer | Token 壓縮 95%+ | `npx -y token-optimizer-mcp` |
| filesystem | 檔案系統操作 | `npx -y @modelcontextprotocol/server-filesystem /path` |

### 部署平台

| Server | 用途 | 設定 |
| :--- | :--- | :--- |
| vercel | Vercel 部署 | HTTP: `https://mcp.vercel.com` |
| railway | Railway 部署 | `npx -y @railway/mcp-server` |
| cloudflare-docs | Cloudflare 文檔 | HTTP: `https://docs.mcp.cloudflare.com/mcp` |

### 搜尋與研究

| Server | 用途 | 設定 |
| :--- | :--- | :--- |
| firecrawl | 網頁爬取 | `npx -y firecrawl-mcp` (需 FIRECRAWL_API_KEY) |
| exa-web-search | 進階搜尋 | `npx -y exa-mcp-server` (需 EXA_API_KEY) |

### AI 工具

| Server | 用途 | 設定 |
| :--- | :--- | :--- |
| fal-ai | AI 圖片/影片生成 | `npx -y fal-ai-mcp-server` (需 FAL_KEY) |

---

## API Key 取得方式

| Service | 取得網址 |
| :--- | :--- |
| Brave Search | https://api.search.brave.com/app/dashboard |
| Context7 | https://upstash.com/context7 |
| GitHub | https://github.com/settings/tokens |
| Firecrawl | https://firecrawl.dev |
| Exa | https://exa.ai |
| fal.ai | https://fal.ai |

---

## 注意事項

- `.mcp.json` 包含 API keys，**不要提交到公開 Git repo**
- 確認 `.gitignore` 已包含 `.mcp.json`
- 每個 MCP server 會佔用部分 context window，不要裝太多
- Windows: command 用 `"cmd"`, args 用 `["/c", "npx", "-y", "..."]`
- Linux: command 直接用 `"npx"`, args 用 `["-y", "..."]`
- 使用對應平台的 `.mcp.json.*.example` 即可，無需手動調整格式
