# MCP Server 推薦清單

> 建議同時啟用 < 10 個，避免佔用過多 context window。

## 已安裝（在 .mcp.json，共 6 個）

| Server | 用途 | 需要 API Key |
| :--- | :--- | :--- |
| **brave-search** | 網路搜尋 | BRAVE_API_KEY |
| **context7** | 即時文檔查詢 | CONTEXT7_API_KEY |
| **github** | GitHub PR/Issue/Repo 操作 | GITHUB_PERSONAL_ACCESS_TOKEN |
| **playwright** | 瀏覽器自動化與測試 | 否 |
| **sequential-thinking** | 鏈式推理 | 否 |
| **memory** | 跨 session 記憶 | 否 |

### 部署與基礎設施

| Server | 用途 | 安裝方式 |
| :--- | :--- | :--- |
| **vercel** | Vercel 部署 | HTTP: `https://mcp.vercel.com` |
| **railway** | Railway 部署 | `npx -y @railway/mcp-server` |
| **supabase** | Supabase 資料庫 | `npx -y @supabase/mcp-server-supabase@latest` |
| **cloudflare-docs** | Cloudflare 文檔 | HTTP: `https://docs.mcp.cloudflare.com/mcp` |

### 研究與搜尋

| Server | 用途 | 安裝方式 |
| :--- | :--- | :--- |
| **firecrawl** | 網頁爬取 | `npx -y firecrawl-mcp` (需 API Key) |
| **exa-web-search** | 進階網路搜尋 | `npx -y exa-mcp-server` (需 API Key) |

### 特殊工具

| Server | 用途 | 安裝方式 |
| :--- | :--- | :--- |
| **magic** | Magic UI 元件 | `npx -y @magicuidesign/mcp@latest` |
| **fal-ai** | AI 圖片/影片生成 | `npx -y fal-ai-mcp-server` (需 API Key) |
| **token-optimizer** | Token 壓縮 (95%+) | `npx -y token-optimizer-mcp` |

## 如何新增

在 `.mcp.json` 的 `mcpServers` 中加入設定：

```json
"server-name": {
  "command": "cmd",
  "args": ["/c", "npx", "-y", "@package/name"],
  "env": {
    "API_KEY": "your-key-here"
  }
}
```

HTTP 類型的 server：

```json
"server-name": {
  "type": "http",
  "url": "https://example.com/mcp"
}
```

然後在 `settings.local.json` 的 `enabledMcpjsonServers` 加入 server 名稱。
