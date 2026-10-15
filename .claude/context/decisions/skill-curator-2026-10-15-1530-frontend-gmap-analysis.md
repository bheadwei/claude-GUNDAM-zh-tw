# skill-curator 分析：用 gmap-landing-page 優化模板前端流程

日期：2026-10-15　模式：**只分析，未改任何檔案**（.skill-impact 未清除，因為這輪沒處理它）

來源：`D:\wei\sunny_課程\landingpage_design_demo\.claude\skills\gmap-landing-page\SKILL.md`（目錄裡只有這一個檔，沒有 references 或素材檔）

## 前置檢查
- check-counts：313 項全部一致（基準）
- 沒有 `to: skill-curator` 的 handoff
- 分析過程中查證的事實：GSAP 3.15 README 寫明全部 bonus plugin（含 SplitText）免費、可商用；
  Firefox 的 scroll-driven animations 到 2026 年中的穩定版**仍需要 flag**（查到的是第三方資料，寫進 skill 前要用 MDN／caniuse 再確認一次）

## 模板目前的缺陷（不管 gmap 也該處理）
| # | 缺陷 | 證據 | 裁決 |
|---|---|---|---|
| D1 | 合規自檢清單有三份而且已經不一致 | 自檢清單在 skill 有 14 項、ui-builder 10 項、ui-page 7 項；**真正在寫程式碼的 ui-builder 那份沒有反 AI slop、文案、動畫、a11y 這幾項** | Merge into ui-style-compliance 階段 3（ui-builder 第 127-147 行、ui-page 第 183-198 行改成指向它） |
| D2 | 混搭模式的 `animation` 覆蓋項等於沒作用 | 69 份 DESIGN.md 中有 66 份沒有 Motion 段落；/ui-style 路徑 B 只問 4 個面向，json 範例也沒有 animation 欄位 | Improve：改成頂層欄位 `motion: L1/L2/L3` |
| D3 | 混搭模式用的段落名對不上實際標題 | skill/CATALOG 寫 `Spacing / Grid / Section Rhythm`、`Buttons / Cards / Inputs`；69 份檔案實際的標題是 `Layout Principles`（67 份）、`Component Stylings`（69 份） | Improve：把 1.2 表與 CATALOG Metadata 表改成實際標題 |
| D4 | 規則自相矛盾 | Fallback 寫「深色模式：必須支援」，2.5 卻禁止「沒人要求的深色模式」；自檢項目又強制做雙版本 | Improve |
| D5 | 「動畫一律 150-300ms」沒寫適用範圍 | 這條拿去套捲動連動的動畫不成立 | Improve：限定只管 UI 微互動 |
| D6 | 瀏覽器支援度的資訊可能過期 | 2.6④ 寫 Firefox 132+、Safari 18+；查到的是 Firefox 仍需 flag、Safari 26 才支援 | Update（MDN／caniuse 確認後再改） |
| D7 | 斷點在三個地方寫法不一樣 | skill 寫 390/768/1024/1440、ui-builder 寫 640/1024、gmap 寫 390/768/1440 | 跟 D1 一起收斂 |
| D8 | ui-builder 等於在鼓勵編內容 | 紅旗寫「不要 Lorem ipsum，改用有意義的示意文案」 | Improve：改成「沒有的事實留 `【待提供：…】`」 |
| D9 | 「斷點都看過」這項自檢沒辦法驗證 | ui-builder 拿不到 playwright（工具列沒有它，流程也沒有截圖步驟） | Improve（agent） |
| D10 | 前端關鍵字規則誤觸發也會漏接 | `has 'ui'` 用子字串比對，所以 quick、build、guide 都會命中；「網站」「landing」「形象頁」卻都不在規則裡 | Improve（hook，改完要跑 run-tests） |

## 從 gmap 搬過來的項目與落點
| 項目 | 層級 | 落點 |
|---|---|---|
| 動畫分三級 L1/L2/L3（每級允許的技術、效能預算、reduced-motion 時怎麼降級）＋ 函式庫速查與常見坑 | skill 的附屬檔 | 新增 `.claude/skills/ui-style-compliance/motion.md`，2.6③④ 改成指向它 |
| 怎麼問使用者「動畫要多少」 | command | 在 `/ui-style` 加一步，答案寫進 ui-style.json 的 `motion`；`/ui-page` 原本那題改成「沿用專案設定／這頁另外調」 |
| 不准編事實，查不到的留空位 | skill | 併進 2.6② |
| 退件格式「哪個狀態→看到什麼→像什麼」＋ 白話回饋對應到技術調整 | command＋skill 附屬檔 | `/ui-page` 每做完一段的驗收迴圈 |
| 一段一段截圖驗收（390／1440，動畫段落另截 3 個捲動位置） | agent | ui-builder 的「產出後必跑」 |
| 「幫我提三個方向」入口 | command | `/ui-style` 步驟 1 新增選項；每個方向都要對應到 CATALOG 裡的品牌 |
| 繁中字型搭配、`display=swap` | skill 附屬檔 | `ui-style-compliance/fonts-cjk.md` |
| 動畫參數集中成 CONFIG／motion tokens | skill | 併進 2.1 的 token 概念 |

## 不搬進模板的
Google 地圖資料抓取與評論萃取、`/mnt/user-data/outputs` 與 SendUserMessage（這些屬於 claude.ai 雲端環境）、
「概念提案」標記、LocalBusiness JSON-LD、預設做成單一 index.html 走 CDN、Netlify Drop、Artifact 不公開的規定。
gmap 整包也不搬：它是特定領域用的，又依賴雲端工具，搬進來就得維護它。

## 該用 hook 的（照決策表第一題判斷）
- 前端檔案（tokens 檔以外）出現 hex 色碼 → 目前完全靠 ui-builder 自己 grep 檢查
- `motion: L1` 的專案卻 import 了 gsap/lenis
這兩件都能在 PostToolUse 當下用程式判斷，比寫文字規則可靠。

## 要使用者決定的
1. 要不要新增非科技業的風格，例如餐飲、在地品牌、編輯感（目前 69 個風格全是科技／SaaS 品牌）
2. 先做 D1-D10，還是動畫分級跟 D1-D10 一起做
3. AskUserQuestion 支不支援 `preview` 欄位要先實測，「提三個方向」的呈現方式取決於它

## 驗證
接線：check-counts 313 項一致（這是基準，因為沒改任何東西）
行為：未驗證。這一輪沒有建立或修改任何擴充
