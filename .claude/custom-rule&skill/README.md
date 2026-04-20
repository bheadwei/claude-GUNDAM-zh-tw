# custom-rule&skill — 取材備份池

> **此目錄不參與模板執行**，是 rules / skills 的完整備份倉庫，供未來挑選新功能加入主模板時使用。

## 角色定位

| 目錄 | 是否生效 | 用途 |
| :--- | :--- | :--- |
| `.claude/rules/` | ✅ 生效 | 主模板實際載入的規則（精簡版） |
| `.claude/skills/` | ✅ 生效 | 主模板精選 8 個 skill |
| `.claude/custom-rule&skill/rules/` | ❌ 備份 | 8 種語言的完整規則集 |
| `.claude/custom-rule&skill/skills/` | ❌ 備份 | 94 個 skill 的完整池 |

## 取材流程

1. 在 [`skills/INDEX.md`](skills/INDEX.md) 找到想啟用的 skill
2. 整個目錄複製到 `.claude/skills/`：
   ```bash
   cp -r .claude/custom-rule&skill/skills/python-patterns .claude/skills/
   ```
3. 更新 `.claude/skills/INDEX.md` 的「已安裝」清單
4. 規則類同理：從 `custom-rule&skill/rules/<lang>/` 複製到 `.claude/rules/`

## 為什麼分開放？

- **主模板要輕**：規則太多會稀釋 Claude 的注意力，每多 1KB rules 都吃 context
- **備份要全**：保留所有可能用到的素材，避免日後重新蒐集
- **明確邊界**：執行用 vs 取材用，不會互相污染

## 取材後務必檢查

搬運 skill 到 `.claude/skills/` 後，**檢查並更新這些容易過時的內容**：

- [ ] 寫死的 Claude 模型 ID（`claude-opus-4-7`、`claude-sonnet-4-6`、`claude-haiku-4-5-20251001`）
- [ ] API 定價表（參考 Anthropic 官網最新值）
- [ ] SDK 版本號、npm/PyPI 套件版本
- [ ] 套件管理指令（Python 一律用 `uv add`，非 `pip install`）
- [ ] 參考連結是否仍有效
