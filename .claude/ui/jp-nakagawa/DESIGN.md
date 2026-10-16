# DESIGN.md — 中川政七商店 / Nakagawa Masashichi Shoten

> 中川政七商店公式サイト（https://www.nakagawa-masashichi.jp/）のデザイン仕様書。
> 1716 年（享保元年）創業、奈良の老舗工芸品ブランド。「日本の工芸を元気にする！」をビジョンに掲げ、生活雑貨を中心にロングライフな暮らし道具を扱う。
> 実サイトの computed style に基づいて記述。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 老舗工芸店らしい、和の余白・静謐・端正。装飾を排し、余白と書体差で品格を出す
- **密度**: 中程度。1 商品 1 商品をていねいに見せる工芸カタログ的な構成。情報密度よりも呼吸の取れたレイアウト
- **キーワード**: 端正、和モダン、工芸、Yu Gothic、明朝、奈良、ロングライフ
- **特徴**: 本文はすべて **游ゴシック体**（YuGothic）。商品見出しに **Noto Serif Japanese（明朝）** を混在させ、和の佇まいを強調。h2 はあえて **Light（300）の Noto Sans JP 28px** を採用し、モダンで控えめな見出しを作る。色相は徹底的に抑えられ、ほぼグレースケール

---

## 2. Color Palette & Roles

### Primary（ブランドカラー — 抑制された無彩色運用）

- **Sumi Black** (`#000000`): 本文・見出しの主役。純黒を使う
- **Charcoal Dark** (`#222222`): 補助テキスト・濃い面色
- **Ink Gray** (`#333333`): 強アクセント帯（黒地ナビ等）。「店舗情報」エリアで使用
- **Mid Gray** (`#444444`): セカンダリ濃グレー
- **Sub Gray** (`#777777`): 補足テキスト（商品の補助情報）

### Surface（面色 — 和紙のような温度感）

- **Background** (`#ffffff`): ページ背景
- **Surface Gray** (`#f5f5f5`): 最頻出の面色（出現 14 回）。「11,000 円以上で送料・代引き手数料無料」帯やセクション背景に多用
- **Surface Section** (`#f1f1f1`): 「店舗を探す」エリア背景
- **Surface Pale** (`#eeeeee`): 「お知らせ」エリア背景
- **Surface Footer** (`#ededed`): フッター背景
- **Surface Tag** (`#dcdcdc`): カテゴリラベル（「中川政七商店について」「採用情報はこちら」等）
- **Surface Veil** (`rgba(255, 255, 255, 0.8)`): カテゴリラベル「衣」「食」「住」用半透明白
- **Surface Overlay** (`rgba(0, 0, 0, 0.6)`): 画像上のテキスト読みやすさ用半透明黒

### Text

- **Text Primary** (`#000000`): 本文・見出し（純黒）
- **Text Body** (`#111111`): ヘッダー帯テキスト（純黒に近い）
- **Text Sub** (`#333333`): 中位補足
- **Text Muted** (`#777777`): 商品サブ情報・キャプション

> **Note**: 中川政七商店の UI には**色相が存在しない**（数百年続く老舗としての信頼と工芸品の主役性を、無彩色で表現）。アクセント色は使わず、書体（明朝 / ゴシック）と Light ウェイトの差で階層を作る。

---

## 3. Typography Rules

### 3.1 和文フォント

**ゴシック体（本文・UI 全般）**:
- 游ゴシック体 / YuGothic（macOS / Windows 10+）
- "Yu Gothic M" / "游ゴシック Medium" / "Yu Gothic Medium"（Medium ウェイト指定）
- ヒラギノ角ゴ ProN W3 / Hiragino Kaku Gothic ProN W3
- ヒラギノ角ゴ ProN / Pro
- メイリオ / Meiryo（Windows）
- Osaka（旧 macOS）
- ＭＳ Ｐゴシック / MS PGothic（Windows レガシー）

**明朝体（商品見出し・特集タイトル等）**:
- Noto Serif Japanese（Web フォント、最優先）
- ヒラギノ明朝 ProN / Hiragino Mincho ProN
- 游明朝体 / YuMincho / 游明朝 / Yu Mincho
- ＭＳ Ｐ明朝 / MS PMincho（Windows レガシー）

**Web フォント（特定見出し）**:
- Noto Sans JP（h2 / 大見出し用、Light 300 を多用）

### 3.2 欧文フォント

中川政七商店は和文フォント内蔵の欧文グリフをそのまま使用。独立した欧文フォント指定はほぼ無し。

### 3.3 font-family 指定

```css
/* 本文・UI 全般 */
font-family:
  游ゴシック体, YuGothic, "Yu Gothic M", "游ゴシック Medium",
  "Yu Gothic Medium", "ヒラギノ角ゴ ProN W3", "Hiragino Kaku Gothic ProN W3",
  HiraKakuProN-W3, "ヒラギノ角ゴ ProN", "Hiragino Kaku Gothic ProN",
  "ヒラギノ角ゴ Pro", "Hiragino Kaku Gothic Pro",
  メイリオ, Meiryo, Osaka, "ＭＳ Ｐゴシック", "MS PGothic", sans-serif;

/* 商品見出し・特集（明朝） */
font-family:
  "Noto Serif Japanese", "ヒラギノ明朝 ProN", "Hiragino Mincho ProN",
  游明朝体, YuMincho, 游明朝, "Yu Mincho",
  "ＭＳ Ｐ明朝", "MS PMincho", serif;

/* h2 大見出し（Light Sans） */
font-family: "Noto Sans JP", sans-serif;
font-weight: 300;
```

**フォールバックの考え方**:
- 本文は **游ゴシック体を最優先**（老舗らしいオーソドックスさ。Noto Sans JP ではなく Yu Gothic を選ぶのが特徴）
- 「Yu Gothic M」「游ゴシック Medium」を含めることで Windows でもウェイトが正しく表示される（W3 ではなく Medium にマッピング）
- ヒラギノは **ProN（JIS2004 字形）** を採用
- 商品見出し・特集タイトルでは明朝体に切り替えて、和の趣・工芸の格を演出

### 3.4 文字サイズ・ウェイト階層

| Role | Font | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|------|--------|-------------|----------------|------|
| H2 Display | Noto Sans JP | 28px | 300 | 33.6px (1.2) | normal | 「OUR PRODUCTS」等のメジャー見出し（Light） |
| H2 Section | Noto Sans JP | 18px | 300 | 21.6px (1.2) | normal | 中位セクション見出し（Light） |
| H2 Compact | Noto Sans JP | 16px | 700 | 19.2px (1.2) | normal | 小見出し |
| H3 Mincho | Noto Serif Japanese | 15px | 700 | 24px (1.6) | normal | 商品名見出し（明朝） |
| H3 Card | 游ゴシック体 | 30px | 400 | 30px (1.0) | normal | カード上の大型見出し |
| Body | 游ゴシック体 | 16px | 400 | 24px (1.5) | normal | サイト全般の本文 |
| Body Strong | 游ゴシック体 | 14px | 700 | 21px (1.5) | normal | ヘッダー・強調本文 |
| Body Sub | 游ゴシック体 | 15px | 400 | 22.5px (1.5) | normal | 商品説明本文 |
| Caption | 游ゴシック体 | 13px | 400 | 20.8px (1.6) | normal | 補足キャプション (`color: #777`) |
| Nav Link | 游ゴシック体 | 13px | 700 | 19.5px (1.5) | 1.04px (≈0.08em) | グローバルナビリンク（字間あり） |
| Tag | 游ゴシック体 | 15px | 700 | 22.5px (1.5) | 2px (≈0.13em) | カテゴリタグ「衣 / 食 / 住」（広い字間） |

### 3.5 行間・字間

- **本文の行間**: **1.5**。日本語サイトとしては標準的な値
- **見出しの行間**: 1.0–1.6。見出しは詰めて、明朝見出しは緩めの 1.6 でゆとり
- **字間 (letter-spacing)**:
  - 本文・段落: `normal`（基本はベタ組み）
  - **ナビリンク**: `letter-spacing: 1.04px`（13px に対して **約 0.08em**。和文ナビでは特徴的に広めに開ける）
  - **カテゴリタグ「衣 / 食 / 住」**: `letter-spacing: 2px`（15px に対して **約 0.13em**。1 文字の和字を堂々と見せる）
- **本文の字間**: ベタ組み（normal）

**ガイドライン**:
- 本文は 16px / line-height 1.5 / letter-spacing normal がベース
- ナビ・タグ等の **短い和字ラベル**は 0.08–0.13em の字間で間延び感を出し、和の余白を演出する
- 商品見出しは明朝に切り替えて、line-height 1.6 でゆったりと組む

### 3.6 禁則処理・改行ルール

```css
overflow-wrap: break-word;
word-break: normal;
line-break: strict;
```

- 商品名（例: 「奈良晒のふきん」「花ふきん」）は意味の切れ目で折り返す
- 価格・型番は折り返さない

### 3.7 OpenType 機能

```css
font-feature-settings: normal;
```

- **palt は使わない**（ベタ組みを基本とする）
- カーニング `kern` も明示指定なし
- 工芸品らしい端正な組版を維持

### 3.8 縦書き

- 該当なし（横書き運用）。ただし商品撮影や特集グラフィックでは縦書きラベルを併用する場合あり

---

## 4. Component Stylings

### Buttons

**Primary CTA（ナビ・主要リンク）**
- Background: `#dcdcdc`（淡グレー）
- Text: `#000000`
- Padding: `0 24px`
- Border Radius: `0px`（角張り）
- Font Size: 13px / Weight 700 / line-height 1.5 / letter-spacing 1.04px
- 例: 「中川政七商店について」「採用情報はこちら」

**Inverse CTA（ヘッダー強調）**
- Background: `#333333`
- Text: `#ffffff`
- Padding: `0 24px`
- Border Radius: `0px`
- Font Size: 13px / Weight 700
- 例: 「店舗情報」

**Pill Button（特集 / インタラクション）**
- Background: `#ffffff`
- Text: `#000000`
- Border: 1px solid `#dddddd`
- Border Radius: `999px`（pill）
- Font Size: 14px / Weight 400
- 補助 CTA でのみ使用（基本は角張り）

**Ghost / Plain Link**
- Background: `transparent`
- Text: `#111111`
- Border: なし
- Padding: `5.6px 0` 〜 `6.3px 0px 6.3px 4px`

### Inputs

- Background: `#ffffff`
- Border: 1px solid `#dddddd`
- Border Radius: `0px`
- Padding: `8px 12px`
- Font Size: 14px / Weight 400 / line-height 1.5

### Cards

- Background: `#ffffff`
- Border: なし or 1px solid `#dddddd`（控えめ）
- Border Radius: `0px`（カードに角丸を使わない）
- Padding: `0`（画像 + キャプションを密に組む）
- Shadow: なし（フラット）

### Tags / Category Labels

- 「衣 / 食 / 住」等の和字 1 文字タグ: 15px Bold / letter-spacing 2px / bg `rgba(255,255,255,0.8)` / 角張り
- カテゴリリンクタグ: bg `#dcdcdc` / text `#000` / 13px Bold / radius 0 / padding `0 24px`

---

## 5. Layout Principles

### Spacing Scale

| Token | Value | 用途 |
|-------|-------|------|
| XS | 4px | アイコンとラベルの間 |
| S | 8px | カード内の細かい間 |
| M | 16px | カードキャプション間隔 |
| L | 24px | セクション内ブロック間 |
| XL | 40px | セクション間 |
| XXL | 80–100px | フッター上下余白等のメジャー余白 |

### Container

- Max Width: 約 1280px（実測ベース）
- Padding (horizontal): 16〜40px
- ヘッダー高さ: 136px（カスタムプロパティ `--header-height: 136px`）
- フッター上下: padding `80px 0 100px`（ゆとりを確保）

### Grid

- 商品サムネ: 4 カラム（PC）/ 2 カラム（SP）
- カテゴリブロック: 3 カラム（衣 / 食 / 住）
- ガッターは 16–24px。情報密度より呼吸を優先する

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | none | ほぼ全要素（フラット運用が原則） |
| 1 | `0 1px 3px rgba(0, 0, 0, 0.06)` | スティッキーヘッダー / ドロワー時のみ |

> 中川政七商店は box-shadow をほぼ使わない。階層は色面（`#fff` / `#f5f5f5` / `#eeeeee` / `#dcdcdc` / `#333`）の差で表現する。

---

## 7. Do's and Don'ts

### Do（推奨）

- 本文は `游ゴシック体, YuGothic, "Yu Gothic M", "游ゴシック Medium", "Yu Gothic Medium", "ヒラギノ角ゴ ProN W3", ...` の長いチェーンで指定する（macOS / Windows 両対応）
- 商品見出し・特集タイトルでは **明朝体（Noto Serif Japanese / ヒラギノ明朝 ProN）** に切り替えて、工芸の格を演出する
- メジャー見出し（h2 28px）は **Noto Sans JP の Light 300** を使う（あえて細く繊細に）
- 配色は `#000` / `#111` / `#222` / `#333` / `#444` / `#777` / `#dcdcdc` / `#eeeeee` / `#f1f1f1` / `#f5f5f5` / `#ededed` のグレースケールに絞る（色相を持たない）
- ナビリンクは `letter-spacing: 1.04px (≈0.08em)`、和字 1 文字タグは `letter-spacing: 2px (≈0.13em)` で組む
- 本文は 16px / line-height 1.5 / letter-spacing normal がベース
- ヒラギノは **ProN（JIS2004 字形）** を指定する
- カード・CTA・入力欄は基本 `border-radius: 0px`（角張り）。pill は補助 CTA のみ
- フラットなレイアウト（box-shadow 不使用）で、階層は面色の差で作る

### Don't（禁止）

- カラフルな色（赤・青・緑等）を使わない（中川政七商店は色相を持たない）
- ヒラギノ Pro ではなく **ProN** を指定（中川政七商店は ProN）
- 大きな box-shadow / drop-shadow を使わない（フラット原則）
- 本文の line-height を 1.3 以下にしない（呼吸を奪うとブランド観に反する）
- `palt` などの字詰め機能を本文に使わない（ベタ組み原則）
- 純黒以外のテキスト色（青系・茶系等）をブランド色として使わない
- 角丸を多用しない（pill は限定使用）

---

## 8. Responsive Behavior

### Breakpoints

| Name | Width | 説明 |
|------|-------|------|
| Mobile | ≤ 767px | モバイル（1〜2 カラム） |
| Tablet | 768–1023px | 2〜3 カラム |
| Desktop | ≥ 1024px | 3〜4 カラム |

### タッチターゲット

- 最小サイズ: 44px × 44px

### フォントサイズの調整

- モバイル本文は 14–16px を維持
- h2 28px はモバイルで 22–24px に縮小（Light 300 を保つ）

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Primary Black: #000000 (本文・見出し)
Sub Text: #333333 / #777777
Background: #ffffff
Surface Gray: #f5f5f5 (最頻出の面色)
Surface Section: #eeeeee / #f1f1f1
Surface Footer: #ededed
Tag BG: #dcdcdc
Header Inverse BG: #333333 (text white)
Font (Body): 游ゴシック体, YuGothic, "Yu Gothic M", "游ゴシック Medium", "Yu Gothic Medium", "ヒラギノ角ゴ ProN W3", "Hiragino Kaku Gothic ProN W3", メイリオ, sans-serif
Font (Display H2): "Noto Sans JP", sans-serif (Light 300)
Font (Mincho 商品見出し): "Noto Serif Japanese", "ヒラギノ明朝 ProN", "Hiragino Mincho ProN", 游明朝体, serif
Body Size: 16px / Weight 400 / line-height 1.5 / letter-spacing normal
Display H2: 28px / Weight 300 / line-height 1.2 (Noto Sans JP Light)
Mincho Heading: 15px / Weight 700 / line-height 1.6
Nav Link: 13px / Weight 700 / letter-spacing 1.04px (≈0.08em)
Tag (1 char): 15px / Weight 700 / letter-spacing 2px (≈0.13em)
Border Radius: 0px (基本) / 999px (補助 pill のみ)
Shadow: なし
font-feature-settings: normal (palt 不使用)
```

### プロンプト例

```
中川政七商店のデザインシステムに従って、工芸品紹介ページを作成してください。
- 背景: #ffffff、テキスト: #000000（純黒、サブは #333 / #777）
- 本文フォント: 游ゴシック体, YuGothic, "Yu Gothic M", "游ゴシック Medium", "Yu Gothic Medium", "ヒラギノ角ゴ ProN W3", "Hiragino Kaku Gothic ProN W3", メイリオ, sans-serif
- メジャー見出し（h2）は "Noto Sans JP", sans-serif の Light 300 / 28px / line-height 1.2
- 商品名・特集タイトルは "Noto Serif Japanese", "ヒラギノ明朝 ProN", 游明朝体, serif（明朝体）の 15px Bold / line-height 1.6
- 本文は 16px / line-height 1.5 / letter-spacing normal（ベタ組み）
- グローバルナビリンクは 13px Bold / letter-spacing 1.04px (≈0.08em) で字間を開ける
- カテゴリタグ「衣 / 食 / 住」は 15px Bold / letter-spacing 2px (≈0.13em) / bg rgba(255,255,255,0.8)
- カード・CTA・入力欄は border-radius: 0px（角張り）
- 配色は #000 / #111 / #333 / #444 / #777 / #dcdcdc / #eeeeee / #f1f1f1 / #f5f5f5 / #ededed のグレースケールのみ
- カラフルな色は使わない（色相を持たないブランド）
- 「店舗情報」CTA は bg #333333 / text #ffffff / radius 0 / padding 0 24px
- 「中川政七商店について」CTA は bg #dcdcdc / text #000 / radius 0 / padding 0 24px
- box-shadow は使わず、面色の差（#fff / #f5f5f5 / #eeeeee / #dcdcdc / #333）で階層を作る
- ヒラギノは ProN（JIS2004 字形）を指定
```
