# DESIGN.md — Toraya（とらや・株式会社虎屋）

> 株式会社 虎屋 公式サイト（https://www.toraya-group.co.jp/）のデザイン仕様書。
> 室町時代後期から続く老舗和菓子店。羊羹で知られ、皇室御用達の格式と現代的な和の美意識を併せ持つ。
> 実サイトの computed style 実測（2026-05-07 取得）に基づく。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 純白背景に**深紺 `#27455c`** をブランド色に据え、見出しに**モリサワ「本明朝シンキング」**、本文に游ゴシックを使う**和の伝統と現代タイポグラフィの融合**
- **密度**: 余白を広く取り、写真・和菓子イメージを大きく配置するメディア寄りのレイアウト。**情報密度は低め、視覚密度が中程度**
- **キーワード**: 純白背景、深紺アクセント、明朝見出し、游ゴシック本文、季節パステル、ピル CTA、角丸ゼロ
- **特徴**:
  - **見出しは明朝（Mincho）serif**: モリサワの `MFW-RoHMinSinkPro-Md`（本明朝シンキング Pro Medium）を h2 Lv1/Lv2 に適用 — 老舗感と現代的なシャープさを両立
  - **本文は游ゴシック**: `游ゴシック体, YuGothic, "游ゴシック Medium"` を最優先するモダンな日本語本文構成
  - **letter-spacing は normal**（詰めも開きも適用しない）
  - **font-feature-settings: normal**（palt を有効化していない）— 詰めない素朴な組
  - **CTA は白塗り＋ pill 形状**（border-radius 23px）。`2px solid #cccccc` のグレー枠 + 黒文字 14px / weight 700
  - **季節パステル色**: 桜ピンク `#eee0e9` / 抹茶緑 `#d6e2db` / 桃 `#e6d4de` / 若葉 `#c8d7cd` 等を商品カード背景に使用 — 和菓子の季節感を色で表現
  - **深紺 `#27455c`** はフッタの企業情報・グループ会社案内の面色として登場（プライマリ・サーフェス）
  - body line-height は 1.6（25.6 / 16）— 和文標準の中庸値
  - 角丸はすべて 0px（CTA ピルのみ大きな 23px）
  - ライトモード前提（ダーク切替なし）

---

## 2. Color Palette & Roles

> 実サイトの computed style 実測値。すべて hex 表記。
> Toraya は**深紺ベース** + **季節パステル**の二層構造で構成される。

### Brand

- **Primary Navy** (`#27455c`): 虎屋の伝統的なブランドカラー（rgb(39, 69, 92)）。フッタ・グループ会社案内の面色、最頻出のブランド色
- **Brand Black** (`#111111`): ロゴ・主要見出し・本文の基調色（rgb(17, 17, 17)）

### Surface（背景）

- **Page Background** (`#ffffff`): ページ全体の純白
- **Light Gray Surface** (`#f2f1f1`): 補助セクション背景
- **Footer Surface** (`#27445c`): フッタ深紺背景（白文字とともに）

### 季節パステル（Seasonal Accents）

季節商品のカード背景に登場する淡いトーン。和菓子の意匠と連動:

- **Sakura Pink** (`#eee0e9`): 桜・春の和菓子（rgb(238, 224, 233)）
- **Peach Pink** (`#e6d4de`): 桃の節句・春（rgb(230, 212, 222)）
- **Matcha Green** (`#d6e2db`): 抹茶・初夏（rgb(214, 226, 219)）
- **Wakaba Green** (`#c8d7cd`): 若葉・初夏（rgb(200, 215, 205)）

これらはすべて低彩度・高明度の**和の中間色**で、落ち着いた季節感を演出する。

### Text / Foreground

- **Text Primary** (`#111111`): 見出し・本文・ナビ
- **Text Muted** (`#777777`): 日付・キャプション（rgb(119, 119, 119)）
- **Text Inverse** (`#ffffff`): フッタ深紺背景上の白文字

### Border / Divider

- **CTA Border** (`#cccccc`): ピル CTA の 2px 枠
- **Subtle Divider** (`#e5e7eb`): デフォルトの薄い境界線（Tailwind 由来の標準値）

### Semantic（補完）

- 実 UI に表面化したエラー・成功色は確認できない（菓子小売の一覧 UI ではアラートが必要となる場面が少ない）
- アラートを追加する場合は赤 `#b53939` / 緑 `#3a7c4f` / 黄 `#c89f3a` を**深みのある和の彩度**で

---

## 3. Typography Rules

### 3.1 和文フォント

Toraya は **2 系統のフォント**を明確に使い分ける:

#### 見出し（h2 Lv1 / Lv2）— 明朝 serif

- **採用**: **`MFW-RoHMinSinkPro-Md`**（モリサワ「本明朝 シンキング Pro Medium」）
- **フォールバック**: `serif`
- **役割**: 老舗の格式と現代的なシャープさを表現する、和の Mincho

> Note: `MFW-RoHMinSinkPro-Md` はモリサワ Web フォントサービス（TypeSquare 等）由来のドメインライセンス。preview.html では Google Fonts の代替（**Shippori Mincho** や **Noto Serif JP Medium**）を使う。

#### 本文・ナビ・CTA — 游ゴシック sans

- **第1候補**: `游ゴシック体` / `YuGothic` / `"游ゴシック Medium"` / `"Yu Gothic Medium"`
- **第2候補**: `游ゴシック` / `"Yu Gothic"`
- **第3候補**: `"Hiragino Kaku Gothic ProN"` / `"Hiragino Sans"`
- **第4候補**: `Meiryo`
- **最終フォールバック**: `sans-serif`

### 3.2 欧文フォント

- 欧文専用フォントは未使用。和文チェーンの欧文グリフ（YuGothic / Hiragino）で対応
- 等幅・特殊書体: 該当なし

### 3.3 font-family 指定

実サイトの実測値:

```css
/* 本文・ナビ・CTA・p */
font-family: 游ゴシック体, YuGothic, "游ゴシック Medium", "Yu Gothic Medium",
  游ゴシック, "Hiragino Kaku Gothic ProN", "Hiragino Sans", Meiryo, sans-serif;

/* 見出し h2 Lv1 / Lv2（明朝） */
font-family: MFW-RoHMinSinkPro-Md, serif;
```

**フォールバックの考え方**:
- 本文は游ゴシックを最優先 — モダンで上品な日本語本文の標準構成
- 見出しは明朝で老舗感を担保 — 本明朝シンキング Pro Medium という、Morisawa の現代的な明朝体を採用
- AI で再現する場合:
  - 本文: `"Yu Gothic Medium", "Hiragino Sans", sans-serif` に簡略化
  - 見出し: `"Shippori Mincho", "Noto Serif JP", "Yu Mincho", "Hiragino Mincho ProN", serif` に置換可

### 3.4 文字サイズ・ウェイト階層

> 実測値（トップページ、2026-05-07 取得）

| Role | Family | Size | Weight | Line Height | Letter Spacing | Color | 備考 |
|------|--------|------|--------|-------------|----------------|-------|------|
| Heading Lv1 (h2) | **明朝** | **32px** | 400 | 48px (×1.5) | normal | `#111111` | "お知らせ" 等の最上位見出し |
| Heading Lv2 (h2) | **明朝** | 24px | 400 | 37.92px (×1.58) | normal | `#111111` | "季節のおすすめ" 等の節タイトル |
| Related Title (p) | 游ゴシック | 20px | 400 | 32px (×1.6) | normal | `#111111` | "菓子資料室 虎屋文庫" 等の関連リンク見出し |
| Body | 游ゴシック | 16px | 400 | 25.6px (×1.6) | normal | `#111111` | 段落・通常テキスト |
| Date / Caption | 游ゴシック | 16px | 400 | 25.6px (×1.6) | normal | `#777777` | "2026.04.16" 等の日付（mid-gray） |
| Footer Heading (明朝) | 明朝 | 16px | 400 | 25.6px (×1.6) | normal | `#ffffff` | "虎屋グループのご案内" 等 |
| Sub Body | 游ゴシック | 14px | 400 | 22.4px (×1.6) | normal | `#111111` | "メールマガジンのご案内" 説明文 |
| CTA Text | 游ゴシック | 14px | **700** | 22.4px (×1.6) | normal | `#111111` | "すべてのお知らせを読む" 等 |

### 3.5 行間・字間

- **本文の行間**: **1.6**（25.6 / 16）— 日本語本文の標準
- **見出し Lv1（明朝）の行間**: **1.5**（48 / 32）
- **見出し Lv2（明朝）の行間**: **1.58**（37.92 / 24）
- **letter-spacing**: **normal（0）** — 本文・見出し問わず詰めも開きも適用しない

**ガイドライン**:
- Toraya の本文は中〜長文（商品説明・お知らせ）が中心。**行間 1.6 を厳守**して読みやすさを担保
- 明朝見出しは line-height 1.5 で、和の縦長字面を活かす
- letter-spacing は normal を貫く — 明朝の字面メトリクスをそのまま信頼

### 3.6 禁則処理・改行ルール

```css
word-break: normal;
overflow-wrap: break-word;
line-break: strict;
```

- 商品名・お知らせタイトルは適度な長さで改行を意識
- 句読点は約物半角ではなく標準のまま使用（palt 無効）

### 3.7 OpenType 機能

```css
font-feature-settings: normal;
```

- **palt / kern を有効化していない** — 詰めず素朴な組が Toraya の選択
- 明朝見出しの「、」「。」「（）」は約物全角のまま広めに配置 — 老舗の格式と読みやすさを優先

### 3.8 縦書き

- 該当なし。横書きのみ
- 商品個別ページや読み物（虎屋文庫）では `writing-mode: vertical-rl` を使う場面もあり得るが、トップ UI は横書き統一

---

## 4. Component Stylings

### Buttons

Toraya の CTA は**白塗り pill + グレー枠**に統一されている。

**Primary CTA（"すべてのお知らせを読む" "とらやオンラインショップを見る" 等）**
- Background: `#ffffff`
- Text: `#111111`
- Border: `2px solid #cccccc`
- Padding: `0px 16px`（line-height 22.4px が高さを決める）
- Border Radius: **`23px`**（pill 形状）
- Font: 14px / weight 700 / line-height 1.6 / letter-spacing normal
- Hover: border `#111111` / background `#f2f1f1`（推奨）

**Secondary CTA（黒 pill）**
- Background: `#000000`
- Text: `#ffffff`
- Border: `1px solid #000000`
- Border Radius: 2px〜23px（場面による）
- Font: 13px / weight 600

### Inputs

実 UI に検索欄等は表面化していないが、Toraya トーンに合わせる場合:

- Background: `#ffffff`
- Border: `1px solid #cccccc`
- Border (focus): `1px solid #27455c`（ブランド深紺）
- Border Radius: `4px` または `0px`
- Padding: `12px 16px`
- Font: 16px / 游ゴシック / weight 400
- Color: `#111111`

### Cards / Article Cards

トップページの「お知らせ」「季節のおすすめ」カード:

- Background: `#ffffff` または季節パステル（`#eee0e9` `#d6e2db` 等）
- Border: なし（影もなし、面色だけで区切る）
- Border Radius: `0px`
- Padding: 16〜24px（推奨）
- Shadow: なし（フラット）
- 構造:
  - 商品/記事画像（正方形に近い 1:1 〜 4:5）
  - 日付（16px / `#777777`）
  - タイトル（16px〜20px / weight 400 / `#111111`）
  - 本文抜粋（必要に応じ 14〜16px / `#111111`）

### Header / Nav

- Background: `#ffffff`
- Color: `#111111`
- Logo "とらや" 中央 or 左寄せ
- ナビ項目: 16px / 游ゴシック / weight 400
- Padding: `16px 32px`

### Footer

- Background: `#27455c`（深紺）または `#000000`
- Color: `#ffffff`
- "虎屋グループのご案内" は明朝 16px で組む
- リンク列・コピーライトは游ゴシック 14px

---

## 5. Layout Principles

### Spacing Scale（推奨 8px グリッド）

| Token | Value | 用途 |
|-------|-------|------|
| XS | 4px | バッジ内余白 |
| S | 8px | リスト項目間 |
| M | 16px | カード内段落間 |
| L | 24px | カード間 |
| XL | 48px | セクション内余白 |
| XXL | 96px | セクション間 |

### Container

- Max Width: 1200px（推奨）
- Padding (horizontal): mobile 16px / desktop 32px

### Grid

- 商品/記事カード: 2 カラム（mobile）→ 3 カラム（tablet）→ 4 カラム（desktop）
- Gutter: 16〜24px
- 季節パステル背景のカードはギャップを狭めて 2 列並列もあり

### Border Radius Scale

| Token | Value | 用途 |
|-------|-------|------|
| Square | 0px | カード・タグ・画像 |
| Pill CTA | **23px** | プライマリボタン |
| Small | 2px | 補助ボタン・Cookie 設定等 |

- 原則 0px。**CTA だけ大きな pill (23px)** で柔らかさを出す

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | `none` | カード・写真・パネル（基本フラット） |
| 1 | `0 1px 0 0 #cccccc` | 罫線で代替（推奨） |

- Toraya は**影を使わない**。立体表現はゼロで、季節パステルの面色と明朝見出しが視覚階層を作る
- カード・モーダルすべてフラット
- ホバー演出は border-color / opacity の変化のみ

---

## 7. Do's and Don'ts

### Do（推奨）

- **背景は純白 `#ffffff`**、文字は `#111111`（純黒に近いがわずかに浮かせる）
- **見出しは明朝 serif**（`MFW-RoHMinSinkPro-Md` または代替の `Shippori Mincho` / `Noto Serif JP`）/ weight 400
- **本文は游ゴシック**（`"Yu Gothic Medium", "Hiragino Sans", sans-serif`）/ weight 400
- **見出し Lv1: 32px / line-height 1.5 / 明朝 / weight 400**
- **見出し Lv2: 24px / line-height 1.58 / 明朝 / weight 400**
- **本文: 16px / line-height 1.6 / weight 400 / letter-spacing normal**
- **CTA は白塗り + 2px solid #cccccc + border-radius 23px (pill)**, 14px / weight 700 / 黒文字
- **季節商品カード背景には和のパステル**（桜ピンク `#eee0e9` / 抹茶緑 `#d6e2db` 等）を使う
- **フッタは深紺 `#27455c` 面 + 白文字**でブランドを締める
- **letter-spacing は normal を貫く** — 詰めも開きも適用しない
- 日付・キャプションは `#777777`（mid-gray）に統一

### Don't（禁止）

- 純黒 `#000000` を本文に使わない（`#111111` のわずかに柔らかい黒を使う）
- 本文に明朝を使わない（明朝は h2 見出しのみ — 本文は游ゴシック）
- 見出しを weight 700 で組まない（明朝は weight 400 でも十分なコントラストが出る）
- letter-spacing を +0.04em 等で詰めない（normal が Toraya の組）
- font-feature-settings: "palt" を適用しない（normal が Toraya の選択）
- ボタンを直角矩形にしない（CTA は pill 23px）
- 鮮やかな原色（蛍光ピンク・電子青等）を使わない（季節パステルは低彩度）
- 影・elevation を使わない（フラット原則）

---

## 8. Responsive Behavior

### Breakpoints

| Name | Width | 説明 |
|------|-------|------|
| Mobile | ≤ 768px | スマホ |
| Tablet | 769–1024px | タブレット |
| Desktop | > 1024px | デスクトップ |

### モバイル時の調整

- Heading Lv1: 32px → 24px（明朝のメトリクスを崩さず縮小）
- Heading Lv2: 24px → 20px
- Body: 16px 維持（縮小しない）
- ナビは drawer ハンバーガーへ切り替え
- カードグリッド 4 → 2 → 1 カラム

### タッチターゲット

- 最小 44×44px。CTA pill は line-height 22.4px + padding 上下を含めて 44px 以上を確保

### ダークモード

- **対応なし**。ライトモード固定
- フッタの深紺面が「ダーク的役割」を担う

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Background: #ffffff（純白）
Text Primary: #111111（やや柔らかい黒）
Text Muted: #777777（日付・キャプション）
Brand Navy: #27455c（フッタ・グループ会社案内）
Surface Gray: #f2f1f1
Border: #cccccc（CTA pill 2px）

Seasonal Pastels:
  Sakura Pink: #eee0e9
  Peach Pink: #e6d4de
  Matcha Green: #d6e2db
  Wakaba Green: #c8d7cd

Heading Font (明朝): MFW-RoHMinSinkPro-Md, serif
Heading Web Fallback: "Shippori Mincho", "Noto Serif JP", "Yu Mincho", "Hiragino Mincho ProN", serif

Body Font (游ゴシック): 游ゴシック体, YuGothic, "游ゴシック Medium", "Yu Gothic Medium", 游ゴシック, "Hiragino Kaku Gothic ProN", "Hiragino Sans", Meiryo, sans-serif
Body Web Fallback (簡略): "Yu Gothic Medium", "Hiragino Sans", "Yu Gothic", sans-serif

Heading Lv1: 32px / 明朝 / weight 400 / line-height 1.5 / letter-spacing normal
Heading Lv2: 24px / 明朝 / weight 400 / line-height 1.58 / letter-spacing normal
Body: 16px / 游ゴシック / weight 400 / line-height 1.6 / letter-spacing normal
Date / Caption: 16px / 游ゴシック / weight 400 / color #777777
CTA Text: 14px / 游ゴシック / weight 700 / line-height 1.6

CTA Pill: white bg / 2px solid #cccccc / border-radius 23px / padding 0 16px / black text 14px / weight 700
font-feature-settings: normal（palt 適用なし）
Border Radius: 0px（CTA pill のみ 23px）
Shadow: none（フラット）
```

### プロンプト例

```
Toraya のデザインに従って、季節商品の一覧ページを作成してください。
- 背景: #ffffff（純白）
- 見出しフォント: "Shippori Mincho", "Noto Serif JP", "Yu Mincho", serif
- 本文フォント: "Yu Gothic Medium", "Hiragino Sans", "Yu Gothic", sans-serif
- font-feature-settings: normal（palt は適用しない）
- letter-spacing: normal（詰めない）
- ページタイトル "季節のおすすめ": 32px / 明朝 / weight 400 / line-height 1.5 / color #111111
- セクション小見出し: 24px / 明朝 / weight 400 / line-height 1.58 / color #111111
- 商品カード（春の和菓子）: 背景 #eee0e9（桜ピンク）/ border-radius 0 / padding 16-24px / 影なし
- 商品カード（夏の和菓子）: 背景 #d6e2db（抹茶緑）
- カード内日付: 游ゴシック 16px / color #777777 / "2026.04.16" 形式
- カード内タイトル: 游ゴシック 20px / weight 400 / color #111111
- 本文・説明: 游ゴシック 16px / weight 400 / line-height 1.6 / color #111111
- "もっと見る" CTA: 白塗り pill / border-radius 23px / 2px solid #cccccc / 黒文字 14px weight 700
- フッタ: 背景 #27455c（深紺）+ 白文字 / "虎屋グループのご案内" は明朝 16px
- 影・グラデーションは一切使わない
- 角丸はすべて 0px（CTA pill のみ 23px）
- 鮮やかな原色は使わず、季節パステルで色を入れる
```
