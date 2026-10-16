# skill-curator 報告：階段 10 匯入品牌與 CATALOG 非科技業分類（2026-10-16）

計畫：`.claude/taskmaster-data/plans/adhoc-2026-10-16-frontend-style-library.md` 階段 10（使用者決定 4、6、8）

## 做了什麼

| 項目 | 結果 |
|---|---|
| VoltAgent `--apply` | 50 份換成上游 `3b605329`（全部是 google-alpha 新格式）；`claude` 本地有改，未動 |
| 匯入 35 份 | VoltAgent 7（starbucks、nike、wired、theverge、aljazeera、mastercard、oura）、jp 15、omd 13，全用 `sync-ui-sources.sh --import`（`--upstream-dir` 指向預先用 `gh api .../tarball` 抓好的同一個 commit，jp tarball 326MB，不想下載 15 次） |
| 授權 | `_licenses/jp-awesome-design-md-jp.txt`（jp@45cd605e）、`_licenses/omd-oh-my-design.txt`（omd@973cabc4），`gh api contents/LICENSE` 原文；`_sources.json` 登記 `license_file`、jp／omd `last_synced` = 2026-10-16 |
| CATALOG | 數字 69→104；開頭加「參考風格、商標屬原公司」；哲學分類新增「和風靜謐」「編輯刊物感」「在地零售與生活」三組，mastercard／omd-cathay 進企業專業、omd-farfetch 進奢華精品、oura 進溫暖擬物；品牌類型加「非科技業」六類；semrush 標「（依官方設計系統抽取）」；順手補 clay 漏在品牌類型索引外 |
| `/ui-style` | 2A-2a 哲學 8→11、2A-2b 產業 8→14 |
| `skill-curator.md` | 拿掉寫死的 69，改成「上百個／每一份」，實際數字指向 check-counts |
| `sync-ui-sources.test.sh` | 10 個失敗全是測試把 repo 現況當前提（jp last_synced 是 null、starbucks／jp-ippodo 不存在、jp 沒授權檔）。改成：jp last_synced 比對前後值、新增情境改用 zz-newbrand／jp:testtea、沙箱刪 jp 授權檔再測提醒。不在階段 10 files 內 |

## 裁決（逐項）

- **AI 痕跡加註：Update**。候選報告寫在 anti-ai.md 之前（它自己說要再對一次），這次用 anti-ai.md「例外」節的三元素判準重算：
  - 保留加註：oura（高，三個都中）、mastercard（中，`#F3F0EE` 米白＋接近陶土的橘）、wired（中，表 1 第 3 種）、theverge（中，表 1 第 2 種）、omd-ft（中，紙色＋襯線；`#FFF1E5` 的 B 只有 E5，嚴格說不到米白門檻）
  - **降為不加註**：jp-onibuscoffee（`#F8F6F4`，R 只比 B 高 4，無襯線）、jp-sousou（`#F5F5F5` 中性灰＋明朝，明朝不算）、omd-pixnet（白底＋宋體，宋體比照明朝不算）、omd-bloomandwild（白底，米色只在局部區塊）
- **omd-muji、omd-pinkoi 的 SOURCE.json `language`：Update** ja→en。內文是英文，只因字型名含假名被 `detect_language` 判成 ja。腳本的判斷法是階段 8 的事，未改

## 混搭實測（ui-style-compliance 1.2 節的標題對照表）

對 104 份全部跑：照表找 color／typography 段落，新格式另讀 YAML `colors:`／`typography:`。104 份全部抽得到（段落非空、色碼 ≥2、有字型），67 新格式、37 舊格式。抽樣：

| codename | 格式 | color 段落行／YAML 行／色碼數 | typography 段落行／YAML 行 |
|---|---|---|---|
| airbnb | 新 | 34／24／19 | 37／110 |
| stripe | 新 | 31／21／19 | 36／106 |
| oura | 新 | 30／29／25 | 34／85 |
| omd-icook | 新 | 22／14／13 | 22／40 |
| omd-ft | 新 | 57／27／40 | 23／27 |
| claude | 舊 | 36／—／19 | 36／— |
| starbucks | 舊 | 50／—／16 | 53／— |
| jp-ippodo | 舊 | 39／—／13 | 99／— |
| jp-kai-ryokan | 舊 | 40／—／18 | 141／— |

## 未驗證

- 沒有跑「範例專案 /ui-style 看預覽選、咖啡店至少一個方向對應新 codename」那條驗收：模板 repo 沒有範例專案，且這要互動
- `@google/design.md lint`：`--apply` 時有跑但輸出被過濾掉，事後抽 2 份沒輸出錯誤，沒有逐份確認

## 待處理（不在本階段 files 內）

- 根目錄 `README.md` 第 95、171 行「69 種」→ 104（使用者指示不改，留給階段 11 或主模型）
- `anti-ai.md`「已知會撞到的風格」表可補 mastercard（中兩個）
- `detect_language` 對「英文內文＋日文字型名」誤判
