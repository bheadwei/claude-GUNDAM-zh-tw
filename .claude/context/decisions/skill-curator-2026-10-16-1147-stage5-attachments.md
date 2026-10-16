# 階段 5：ui-style-compliance 三份附屬檔

- 日期：2026-10-16　執行者：skill-curator（worktree `worktree-agent-a46e842908cfdfe71`）
- 工作單：`.claude/taskmaster-data/plans/adhoc-2026-10-16-frontend-style-library.md` 階段 5

## 產出

| 檔案 | 裁決 | 內容 |
|---|---|---|
| `.claude/skills/ui-style-compliance/anti-ai.md` | 新增 | 原 2.5、2.6①②⑤⑥ 搬入並改寫；整合 frontend-design 五種樣式（第 1 種放最前）與 avoid-ai-design 的 P0／P1／P2、「有品味的預設」字型；產出前／產出後兩節；第 1 種樣式的數值判準、日本老店明朝體判準、5 份風格的實查對照表、使用者選了它們／看預覽選時的處理 |
| `.claude/skills/ui-style-compliance/motion.md` | 新增 | 給使用者看的 L1／L2／L3 選項（感覺＋像什麼＋適合誰＋代價，無函式庫名）、每級允許技術與效能預算、reduced-motion 降級、motion tokens、瀏覽器支援度（MDN，附日期）、函式庫速查、常見坑 |
| `.claude/skills/ui-style-compliance/fonts-cjk.md` | 新增 | 10 個 Google Fonts 繁中字型（含查證日期、字重、子集）、8 組中英搭配（標出 anti-ai 點名者）、載入（`display=swap`、`text=`、自動切片實測）、系統字型堆疊、排版參數、jp 日文字型→繁中對照表 |
| `.claude/skills/ui-style-compliance/SKILL.md` | Improve（354→320 行） | 新 1.3「載入附屬檔」（原 1.3 改 1.4，並加三行確認項）；2.5 改指標；2.6 改成保留舊編號的索引＋③動畫底線（L1 唯一來源）；2.1 加 motion token 一句；自檢加「anti-ai 產出後清單」「事實沒有編造」「動畫等級」三項 |

## 查證（全部 2026-10-16）

- 瀏覽器支援度：`mdn/browser-compat-data`（MDN 頁面的資料來源）。scroll-driven：Chrome 115、Safari 26、Firefox 159（當天是 beta，排定 10-27 發布）→ 舊 SKILL.md 寫的 Firefox 132+、Safari 18+ 兩個都錯；同頁 View Transitions Chrome 111／Firefox 144／Safari 18；跨頁 Chrome 126／Safari 18.2／Firefox 無
- 字型：`https://fonts.google.com/metadata/fonts`。8 個候選全部存在；另找到 Chiron GoRound TC、LXGW WenKai Mono TC、Bpmf 注音版。Iansui、Huninn、Cactus 只有 400；Chiron Sung HK 子集是 chinese-hongkong
- 函式庫：Lenis README（ScrollTrigger 同步寫法屬實；預設尊重 reduced-motion）、ShaderGradient README（**有 Vue 3 套件，gmap 寫「只能 React」不完整**）、Motion README（Framer Motion 已改名，也支援純 JS）、GSAP README（全部外掛免費可商用，授權是自家 no-charge license）、Vanta repo 最後 push 2024-03
- 上游：frontend-design commit `41bbe19`（Apache-2.0）、avoid-ai-design commit `2b7c718`（MIT, ungspirit）。只改寫、未整段複製

## 發現與疑慮

1. **派工前提有一處不成立**：「claude、perplexity、zed、granola 本身就是米白＋襯線＋陶土」——實際打開 DESIGN.md，只有 `claude` 三項全中；`granola` 中 2（米白、襯線，強調色是橄欖綠）；`zed` 中 1（襯線）；`perplexity` 中 0（全站無襯線、深青強調、底色接近純白）。CATALOG 的描述偏印象。anti-ai.md 依實查結果寫
2. 既有指標仍寫「2.6 節」：`skill-curator.md` 151、199 行，`session-start.sh` 189 行，`ui-builder.md` 143 行。2.6 保留為索引所以沒有斷，但之後改到這些檔的階段（7、9、10）可以直接寫 `anti-ai.md`
3. motion.md 第 1 節的選項表和推薦規則是**唯一來源**；階段 6 寫 `/ui-style` 動畫題時應指向它，不要另抄

## 驗證

- 接線：check-counts 520 項全部一致
- 行為：**未驗證行為改變**。模板 repo 沒有前端程式碼，compliance 正向題測不到（CLAUDE.md 已知落差）；應在階段 9／11 的範例專案裡驗
