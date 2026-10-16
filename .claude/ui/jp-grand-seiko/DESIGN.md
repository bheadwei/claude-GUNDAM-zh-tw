# DESIGN.md — グランドセイコー (Grand Seiko)

> グランドセイコー（https://www.grand-seiko.com/jp-ja）のデザイン仕様書。
> 2026-05-08 取得の computed style と CSS Custom Properties に基づく。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 1960年に誕生した日本の高級時計ブランドらしく、明朝体だけで構成された伝統と品格の世界。色は **深いネイビー #000040** を主軸に、白と淡いグレーで構成。すべての要素が控えめで、時計そのものの美しさを邪魔しない
- **密度**: 写真は大判で、テキストは少なく、余白は豊かに。letter-spacing 0.7px の微小な字間が全文に適用され、上品な間合いを保つ
- **キーワード**: 高級時計、ヘリテージ、明朝、深ネイビー、矩形 CTA、漆黒紺、伝承、スプリングドライブ
- **特徴**: フォントは **DNP 秀英明朝 Pr6**（dnp-shuei-mincho-pr6）と **Adobe Text Pro** の和文・欧文セリフのみ。ボタンはすべて **border-radius: 0px** の矩形（直線で潔く）。CTA は深ネイビー `#000040` の塗りつぶしか、ネイビー枠線のアウトライン。font-weight はほぼすべて 400（細身で品位を保つ）

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

グランドセイコーは独自の **深いネイビー #000040** をブランドの基軸色とする。黒に限りなく近いが、わずかに青みを残すのが特徴で、漆や夜空を思わせる日本的な色味。

- **GS Navy** (`#000040`): ロゴ、Primary CTA、強いリンク（rgb 0, 0, 64）
- **Deep Navy Border** (`#000027`): CTA の枠線（rgb 0, 0, 39）— `#000040` より一段濃い
- **Slate Navy** (`#27455c`): セクションアクセント（rgb 39, 69, 92）
- **Cookie Navy** (`#213662`): クッキー設定パネル等の補助ネイビー（rgb 33, 54, 98）

### Neutral

- **Text Primary** (`#000000`): メガメニュー内テキスト
- **Text Heading**: `#000040` または `#212121`（rgb 33, 33, 33）
- **Text Secondary** (`#757575`): 非選択タブ
- **Surface** (`#ffffff`): 標準背景
- **Surface Subtle** (`#f6f6f6`): メガメニュー背景・セクション地（rgb 246, 246, 246）
- **Surface Muted** (`#dbdbdb`): 区切り線・薄面（rgb 219, 219, 219）
- **Surface Cooler** (`#ececf1`): ニュートラル系セクション（rgb 236, 236, 241）
- **Newsletter Surface** (`#eeeeee`): 公式ニュースレター枠
- **Hover Layer** (`rgba(255, 255, 255, 0.075)`): 反転背景上のホバー

### Accent

- **Filter Blue** (`#3860be`): フィルターアイコン等の僅かなアクセント（rgb 56, 96, 190）
- 強い装飾色は使わず、ネイビー一色のグラデーションで品位を作る

---

## 3. Typography Rules

### 3.1 和文フォント

グランドセイコーは **DNP 秀英明朝 Pr6**（Adobe Fonts 経由の dnp-shuei-mincho-pr6）を全要素に採用。本文・見出し・ボタン・ナビ、すべて明朝体で統一する。

- **DNP 秀英明朝 Pr6**: dnp-shuei-mincho-pr6（Adobe Fonts）
- **Times New Roman / serif**: フォールバック

### 3.2 欧文フォント

- **Adobe Text Pro**: 一部のメガメニュー・グローバルフッターなどで補助的に使用される欧文セリフ
- **Times New Roman / Georgia / serif**: フォールバック

### 3.3 font-family 指定

```css
/* メイン（本文・大半の見出し・ボタン・ナビ） */
font-family: dnp-shuei-mincho-pr6, "Times New Roman", serif;

/* 一部のメガメニュー・国別ナビ */
font-family: adobe-text-pro, "Times New Roman", Georgia, serif;
```

**フォールバックの考え方**:
- Adobe Fonts の DNP 秀英明朝 Pr6 が読み込めなかった場合は Times New Roman に直接フォールバック
- 日本語環境では OS の明朝（ヒラギノ明朝、游明朝）が最終的にレンダリングされる
- 和文ゴシック（游ゴシック、Hiragino Sans）は **使用しない**

### 3.4 文字サイズ・ウェイト階層

| Role | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|--------|-------------|----------------|------|
| Page Title (h1) | 40px | 400 | 1.5 (60px) | 0.7px | "スプリングドライブ" 等。Hero 見出し |
| Hero Title (h2) | 52px | 400 | 1.2 (62.4px) | 0.7px | "THE NATURE OF TIME" |
| Section Title (h2) | 32px | 400 | 1.5 (48px) | 0.7px | "44GS" 等 |
| Mega Menu Title (h2) | 24px | 400 | 1.5 (36px) | 0.7px | "コレクション" |
| Footer Heading (h2) | 16px | 400 | 1.5 (24px) | 0.7px | "コレクション" 列見出し |
| Card Title (h3) | 24px | 400 | 1.5 (36px) | 0.7px | "SBGX363" 等のリファレンス |
| News Title (h3) | 14px | 400 | 1.5 (21px) | 0.7px | お知らせ見出し |
| Sub Heading (h4) | 14〜16px | 400 | 1.5 | 0.7px | "マスターピースコレクション" |
| Lead (p) | 20px | 400 | 1.85 (37px) | 0.7px | "ヘリテージコレクション" 紹介 |
| Body | 14px | 400 | 1.85 (25.9px) | 0.7px | 本文。`body` の基準 |
| Card Caption | 14px | 400 | 1.85 (25.9px) | 0.7px | "SBGA443" 等 |
| Sub Caption | 12.25px | 400 | 1.5 (18.375px) | 0.7px | "グランドセイコーについて" |
| Promo Caption | 12px | 400 | 1.5 (18px) | 0.7px | "時代を超えて心を動かす…" |
| Country/Footer | 12px | 400 | 1.85 (22.2px) | 0.7px | "Country/Area" 等の補助テキスト |

### 3.5 行間・字間

- **本文の行間**: `line-height: 1.85`（25.9px / 14px）。明朝体で長文を読ませるための余裕ある縦リズム
- **見出しの行間**: 1.5 を基本に、巨大なヒーロー（52px）のみ 1.2 と詰める
- **本文の字間**: `letter-spacing: 0.7px`（≈0.05em）。**ほぼすべての要素**にこの値が適用される。明朝の縦線を緻密に並べたときの息苦しさを和らげる、グランドセイコー固有の組版設定
- **特殊な字間**: ボタン内テキストや一部のヘッダー要素は `letter-spacing: normal` に戻す

### 3.6 OpenType 機能

- 抽出データ上で明示的な `font-feature-settings` 指定はなし（normal）
- Adobe Fonts の DNP 秀英明朝 Pr6 が持つカーニング・約物処理（Pr6 の文字セット）に依存
- **`palt` は使用しない**: 明朝の本来の字面を尊重し、字詰めではなく `letter-spacing: 0.7px` の均等な空きで間合いを作る

### 3.7 改行・禁則

- 本文ブロックでは `word-break` を強制しない
- 商品名（"SBGA443" のようなリファレンス番号）は半角英数で1単語として扱い、改行を避ける
- 長い和文タイトル（"スプリングドライブ"等）はキーワード単位での改行を許容

---

## 4. Component Stylings

### Buttons

**Primary CTA（GS Navy）**（"探す" "時計を探す" の主要動作）

- Background: `#000040`
- Text: `#ffffff`
- Border: 1px solid `#000027`（背景より一段濃いネイビー）
- Border Radius: **0px**（完全な矩形。グランドセイコーの潔さ）
- Padding: 12px 16px〜40px（横幅は文字数で可変）
- Font Family: `dnp-shuei-mincho-pr6, "Times New Roman", serif`
- Font Size: 14〜16px
- Font Weight: 400（太字にしない）
- Line Height: 1.0〜1.5
- Letter Spacing: normal

**Outline CTA（ネイビー枠線）**（補助動作）

- Background: transparent (`rgba(0, 0, 0, 0)`)
- Text: `#000040`
- Border: 1px solid `#000040`
- Border Radius: **0px**
- Padding: 12px 40px
- Font Size: 14px

**Mega Menu Tab CTA**（"マスターピースコレクション" 等のメニュー大項目）

- Background: `#f6f6f6`
- Text: `#000000`
- Border: none
- Border Radius: 0px（コーナーのみ `4px 4px 0 0` のタブもあり）
- Padding: 32px 24px（広い縦余白）
- Font Size: 14px

**Tab Selected (Mega Menu)**

- Color: `#000040`（GS Navy）
- Border Radius: `4px 4px 0px 0px`（タブのコーナー）

**Tab Unselected**

- Color: `#757575`（ミュート）
- Border Radius: `4px 4px 0px 0px`

### Inputs

実測の input 要素から:

- Font Family: `dnp-shuei-mincho-pr6, "Times New Roman", serif`
- Font Size: 12〜16px
- Border: 1px solid（淡いグレー想定）
- Border Radius: 0px（矩形）
- Background: `#ffffff`
- Padding: 多くは検索バー・フッター登録欄

### Cards

- Background: `#ffffff` または `#f6f6f6`
- Border Radius: 0px（矩形のみ）
- Shadow: なし（フラット）
- 大判の時計写真 + リファレンス番号（h3）+ コレクション名（caption）の構成

### Section Backgrounds

- Hero: `#ffffff` または時計の単色背景写真
- Mega Menu: `#f6f6f6` のフラット
- Newsletter: `#eeeeee`
- Cookie/Privacy Panel: `#213662`（深ネイビー）

---

## 5. Layout Principles

### Container

- Header (`l-globalHeader-wrapper`) は max-width 全幅で固定
- Main (`l-mainContent-wrapper`) は中央寄せの大判コンテナ
- Footer (`l-globalFooter-wrapper`) も max-width 全幅、中で 4〜5 列のリンク群

### Spacing Scale（実測ベース）

| Token | Value | 用途 |
|-------|-------|------|
| XS | 8px | タブ縦 padding |
| S | 12px | CTA 縦 padding |
| M | 16px | CTA 横 padding 最小 |
| L | 24px | メガメニュー横 padding |
| XL | 32px | メガメニュー縦 padding |
| XXL | 40px | Outline CTA 横 padding |

### Grid

- ヒーローは 1 カラム全幅（時計の大判ビジュアル）
- 商品グリッドは 3〜4 カラム（コレクション一覧）
- フッターは 5 カラム前後（カテゴリ別リンク群）

---

## 6. Depth & Elevation

グランドセイコーはシャドウを基本使わない。明朝のセリフと細い枠線で空間を作る。`#dbdbdb` の境界線が elevation の役割を担う。

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | none | 標準。すべての要素 |
| 1 | `1px solid #dbdbdb` border | カード・セクションの区切り |
| Modal | `rgba(255, 255, 255, 0.075)` overlay | 反転背景上のホバー |
| Cookie | bg `#213662` の濃いネイビーパネル | プライバシー設定モーダル |

---

## 7. Do's and Don'ts

### Do（推奨）

- 本文・見出しすべてに **`color: #000040` または #000000`**（漆ネイビーまたは黒）を使う
- フォントは **DNP 秀英明朝 Pr6** で統一する。和文ゴシックは使わない
- 全要素に **`letter-spacing: 0.7px`** を適用する。明朝の息苦しさを開放するグランドセイコー固有の処方
- 本文の `line-height: 1.85` を必ず確保
- ボタンは **`border-radius: 0px`** の矩形のみ。pill や角丸は使わない
- Primary CTA は **`#000040`** の濃ネイビー塗りつぶし + **`#000027`** の枠線
- Outline CTA はネイビー文字 + ネイビー 1px 枠線
- font-weight は **400** を基本にする。太字にしない

### Don't（禁止）

- ゴシック体（游ゴシック・Hiragino Sans 等）を使わない
- ボタンを pill (radius: 50%) にしない
- 角丸（border-radius 4px 以上）を CTA に使わない
- 鮮やかな色（赤・緑・オレンジ）を多用しない。ネイビーと白の世界を保つ
- 本文を太字（700）にしない。明朝の細さが品格を作る
- ドロップシャドウや派手な装飾を入れない
- letter-spacing を 0 にしない。明朝が窮屈に見える
- 純黒 `#000000` の代わりに、本文以外では `#000040` の漆ネイビーを優先する

---

## 8. Responsive Behavior

### Breakpoints（想定）

| Name | Width | 説明 |
|------|-------|------|
| Mobile | ≤ 767px | スマートフォン |
| Tablet | 768〜1024px | iPad |
| Desktop | > 1024px | デスクトップ |

### モバイル時の調整

- ヒーロー h2 52px → 32px 程度
- ヘッダーは drawermenu 化（実際にクラス `l-drawermenu-collections-actions` が存在）
- 商品グリッドは 1〜2 カラムに折り返す
- Outline CTA の padding 12px 40px → 12px 24px

### タッチターゲット

- Primary CTA は最小 40px 高（12+12+16 = 40px）を確保
- メガメニュー項目は padding 32px 24px と十分広い

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Brand: グランドセイコー (Grand Seiko)
Primary Color: #000040 (GS Navy)
Border Color: #000027 (Deep Navy Border)
Text Primary: #000000 / #000040
Surface: #ffffff
Surface Subtle: #f6f6f6
Surface Muted: #dbdbdb
Newsletter Surface: #eeeeee
Body Font: dnp-shuei-mincho-pr6, "Times New Roman", serif
Mega Menu Font: adobe-text-pro, "Times New Roman", Georgia, serif
Body Size: 14px / 400 / line-height 1.85
Letter Spacing: 0.7px (全要素均一)
Heading Weight: 400 (太字禁止)
CTA Border Radius: 0px (矩形のみ)
CTA Padding: 12px 16px〜40px
palt: 使用しない
```

### プロンプト例

```
グランドセイコーのデザインシステムに従って、新作時計の紹介ページを作成してください。
- フォント: dnp-shuei-mincho-pr6, "Times New Roman", serif
- 本文 color は #000000、line-height: 1.85、letter-spacing: 0.7px
- font-weight は全て 400（太字にしない）
- ヒーローは時計の大判写真 + h2「THE NATURE OF TIME」52px / 400
- リード（p 20px）でコレクションを紹介
- Primary CTA「コレクションを見る」は #000040 bg + #ffffff text + 1px solid #000027 + radius 0px + padding 12px 40px
- Outline CTA「動画を見る」は transparent bg + #000040 text + 1px solid #000040 + radius 0px
- セクション背景は #ffffff と #f6f6f6 を交互に
- 装飾は最小限。ネイビーと白だけで構成する
```

### 字詰め・組版の重要ポイント

1. **letter-spacing: 0.7px を全要素に**: グランドセイコーの組版の核心。明朝の窮屈さを開放する
2. **明朝で全部組む**: 見出しもボタンもナビも、すべて DNP 秀英明朝 Pr6
3. **font-weight 400 縛り**: 太字を一切使わない。細さが品格を作る
4. **CTA は border-radius 0px**: pill ではなく矩形。グランドセイコーの潔さの象徴
5. **#000040 の漆ネイビー**: 純黒ではない、わずかに青みのあるネイビーがブランドカラー
6. **palt なし、letter-spacing 0.7px**: 字詰めではなく均等な空きで間合いを作る

---

**取得日**: 2026-05-08
**出典**: https://www.grand-seiko.com/jp-ja, https://www.grand-seiko.com/jp-ja/about
**抽出方法**: Headless Chrome (Puppeteer) による computed style 実測 + CSS Custom Properties 抽出
