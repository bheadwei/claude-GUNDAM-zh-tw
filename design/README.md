# design/

專案的 Pencil 設計稿資料夾。所有 `.pen` 檔都應落地在這裡。

## 規則

- **新增** `.pen` 檔一律放本目錄
- 命名：`<頁面或元件>.pen`，英數小寫 + 連字號
  - 例：`login-page.pen`、`dashboard.pen`、`button-kit.pen`
- 子資料夾可依模組分類：`design/mobile/`、`design/web/`、`design/components/`
- 與前端程式碼的對應關係寫在檔名或檔案內註解，方便日後 `/ui-page` 取用

## 相關工具

- Pencil MCP：`.pen` 檔編輯（視覺設計稿）
- `/ui-site` `/ui-page`：把定稿的設計轉成前端程式碼
- `.claude/rules/pencil-design-location.md`：本資料夾的強制規則
