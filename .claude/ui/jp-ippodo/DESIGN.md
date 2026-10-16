# DESIGN.md — 一保堂茶舗（IPPODO）

> 一保堂茶舗（https://www.ippodo-tea.co.jp/）のデザイン仕様書。
> Puppeteer による computed style 実測値（2026-05-21 取得）に基づく。
> 享保二年（1717）創業の京都の老舗茶舗。抹茶・玉露・煎茶・番茶・ほうじ茶など
> 日本茶を幅広く取り扱い、Shopify ベースのオンラインストアを運営する。
> サイトデザインは「京の老舗の静かな品格」を、游明朝の見出しと
> 源ノ角ゴシック Light の極めて広い字間・行間で表現する。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 京都の老舗が持つ品格と静けさを、明朝体の見出し・Light ウェイトの本文・たっぷりの余白で表現。コマースサイトでありながら、茶室のような間（ま）を感じさせるデザイン
- **密度**: 極めて低い。本文の line-height 2.0、letter-spacing 0.1em と、日本語 Web サイトとしても突出して広い行間・字間で「空気を含んだ」組版を実現。商品を急いで売る印象を一切与えない
- **キーワード**: 京の品格、間（ま）、茶室の静けさ、明朝×ゴシックの二層構造、Brown Accent
- **特徴的なデザイン判断**:
  - **游明朝 Pr6（Adobe Fonts）の見出し** × **源ノ角ゴシック Light（Adobe Fonts）の本文** という二書体二層構造。見出しの書的な品格と、本文の現代的な読みやすさを両立
  - **本文 weight 300（Light）** は日本語サイトとして非常に珍しい。通常の 400 / 500 より繊細で、お茶の軽やかさ・透明感を字面で表現
  - **letter-spacing 0.1em（本文）** は一般的な日本語サイト（0〜0.05em）の 2〜5 倍。一文字一文字に間を置く、書道や茶道の「余白」の思想
  - **見出しの letter-spacing 最大 0.5em** は極端な値。文字がほぼ等間隔に並び、看板・暖簾の文字配置に近い
  - **ブランドアクセントは `#93806f`（茶色）**。典型的なブルーやグリーンではなく、お茶の色そのものをブランドカラーに据える
  - **Pill CTA に明朝体** を使用。サンセリフで「押させる」のではなく、明朝体で「誘う」デザイン
  - ページ全体がフラット。影・グラデーション・角丸をほとんど使わず、色面と文字だけで構成
  - CSS Custom Properties は Shopify Dawn テーマベース。`--color-base-accent-1: 147, 128, 111`（`#93806f`）がブランドトークン

---

## 2. Color Palette & Roles

> 実サイトの computed style 実測値。すべて hex 表記。

### Brand

- **Brown Accent** (`#93806f`): ブランドアクセント。ニュースレター「登録」ボタンの枠・文字、検索入力欄の枠、小キャプションの文字色。CSS 変数 `--color-base-accent-1: 147, 128, 111`。お茶の焙じ色を想起させる温かみのある茶色
- **Dark Accent** (`#3a3a3a`): 見出し・テキストの主色。CSS 変数 `--color-base-accent-2: 58, 58, 58` / `--color-base-text: 58, 58, 58`

### Text

- **Text Primary** (`#3a3a3a`): 見出し、ナビゲーション、重要テキスト。純黒ではなくソフトブラック
- **Text Body** (`#4e4e4e`): 本文テキスト。`#3a3a3a` よりさらに薄く、Light ウェイトとの組み合わせで柔らかい印象
- **Text Caption** (`#93806f`): キャプション、タグラベル。ブランドの茶色をそのまま使用
- **Footer Text** (`rgba(58, 58, 58, 0.75)`): フッターの補足テキスト。`#3a3a3a` の 75% 不透明度

### Surface

- **Background** (`#ffffff`): ページ背景。CSS 変数 `--color-base-background-1: 255, 255, 255`
- **Background Alt** (`#f5f6f7`): セクション交互背景。34 回出現（最多の面色）
- **Background Alt 2** (`#f3f3f3`): CSS 変数 `--color-base-background-2: 243, 243, 243`
- **Tag Surface** (`#f4efef`): タグピル「#\_冷たいお茶」等の背景。ほんのりピンクがかったウォームグレー
- **Yellow Section** (`#f9f971`): 「お茶の暮らしイロイロ」セクション背景。鮮やかなイエロー。特集・コラム系の目を引く面色
- **Pink-beige Section** (`#fcf7f7`): 「食卓ノート」セクション背景。桜色に近い極薄ピンク

### Border

- **Border Default** (`#cdcfd4`): メール入力欄等の標準ボーダー
- **Border Accent** (`#93806f`): 検索入力欄・「登録」ボタンのボーダー。ブランド茶色

### Semantic（実測未確認・推奨値）

実サイトには明確なエラー／成功色は表面化していない。老舗ブランドのトーンに合わせた推奨補完値:

- **Danger**: `#c53d3d`（彩度を抑えた朱赤）
- **Success**: `#4e7a5e`（渋い抹茶グリーン）
- **Warning**: `#c49a3c`（金茶）

---

## 3. Typography Rules

> 一保堂のタイポグラフィは明朝×ゴシックの二層構造が核心。
> 見出しの游明朝が「格」を、本文の源ノ角ゴシック Light が「読みやすさ」を担う。
> 共通して letter-spacing が極めて広く、京都の老舗らしい「間」を作っている。

### 3.1 和文フォント

- **ゴシック体（本文）**: **source-han-sans-japanese（源ノ角ゴシック）** — Adobe Fonts。weight 300（Light）を基本に、ナビキャプションで 500（Medium）、一部タグで 700（Bold）を使用
- **明朝体（見出し）**: **yu-mincho-pr6（游明朝 Pr6）** — Adobe Fonts。weight 400（Regular）のみ。Pr6 は JIS X 0213 対応の拡張版で、旧字体・異体字を含む

### 3.2 欧文フォント

- **サンセリフ**: Helvetica, Arial — 一部 h2 見出しで使用（22px / weight 500 / letter-spacing 0.17em）。欧文コンテンツ向けの補助書体
- **源ノ角ゴシックの欧文グリフ**: 本文の欧文部分は source-han-sans-japanese が持つ欧文グリフがそのまま表示される

### 3.3 font-family 指定

```css
/* 本文（源ノ角ゴシック Light） */
font-family: source-han-sans-japanese, sans-serif;

/* 見出し（游明朝 Pr6） */
font-family: yu-mincho-pr6, serif;

/* 一部見出し（欧文系） */
font-family: Helvetica, Arial, sans-serif;
```

**フォールバックの考え方**:
- Adobe Fonts（TypeKit）経由の Web フォントを最優先。未契約環境では即座に generic family へフォールバック
- 実測の CSS にはシステムフォントの長いフォールバックチェーンが含まれていない（Shopify テーマの設計上、Web フォントに依存）
- フォールバック強化が必要な場合は `"Hiragino Sans", "Noto Sans JP", "Yu Gothic", Meiryo, sans-serif`（ゴシック）/ `"Hiragino Mincho ProN", "Yu Mincho", YuMincho, serif`（明朝）を追加

> **代替フォント注記**: source-han-sans-japanese / yu-mincho-pr6 はいずれも Adobe Fonts のドメインライセンス。プレビューや社外資料では以下で代替:
> - source-han-sans-japanese → **Noto Sans JP**（weight 300 / 500。同じ源ノ角ゴシック系譜で字形がほぼ同一）
> - yu-mincho-pr6 → **Shippori Mincho**（Google Fonts。游明朝に近い端正な明朝体）

### 3.4 文字サイズ・ウェイト階層

> 実測値（トップページ、2026-05-21 取得）

| Role | Font | Size | Weight | Line Height | Letter Spacing | Color | 備考 |
|------|------|------|--------|-------------|----------------|-------|------|
| Display H2 | yu-mincho-pr6 | 30px | 400 | 60px (×2.0) | 0.5em | `#3a3a3a` | セクション大見出し。看板のような字配り |
| Section H2 | yu-mincho-pr6 | 24px | 400 | 48px (×2.0) | 0.08em | `#3a3a3a` | 標準の見出し |
| Section H2 (Latin) | Helvetica, Arial | 22px | 500 | 44px (×2.0) | 0.17em | `#3a3a3a` | 欧文見出し |
| Section H3 | yu-mincho-pr6 | 24px | 400 | 48px (×2.0) | 0.08em | `#3a3a3a` | 小見出し |
| Body | source-han-sans-japanese | 16px | **300** | 32px (×**2.0**) | **0.1em** | `#4e4e4e` | 本文。極めて広い字間・行間 |
| Nav Caption | source-han-sans-japanese | 14px | 500 | — | 0.18em | `#3a3a3a` | ナビゲーション項目 |
| Pill CTA | yu-mincho-pr6 | 16px | 400 | 58px | 0.08em | `#4e4e4e` | 「さらに見る」等のピル型 CTA |
| Tag Label | source-han-sans-japanese | 12px | 500 | — | 0.1em | `#4e4e4e` | タグピル「#\_冷たいお茶」 |
| Small Caption | source-han-sans-japanese | 10–11px | 300–700 | — | — | `#93806f` | 極小キャプション・日付等 |

### 3.5 行間・字間

**行間 (line-height)** — 実測:
- **本文 (16px)**: `2.0`（32px / 16px）— 日本語サイトの中でもかなり広い。note の記事本文と同等
- **見出し (24–30px)**: `2.0`（48–60px）— 見出しも本文と同じ `2.0` を維持する統一感
- **Pill CTA**: `line-height: 58px`（固定値指定でボタン高さを確保）

**字間 (letter-spacing)** — 実測:
- **本文**: `0.1em`（1.6px / 16px）— 一般的な日本語サイト（0〜0.05em）の 2〜5 倍
- **見出し（明朝・大）**: `0.5em` — 一文字ごとに大きな間。看板・暖簾風
- **見出し（明朝・標準）**: `0.08em`
- **見出し（欧文）**: `0.17em`
- **ナビキャプション**: `0.18em`
- **タグラベル**: `0.1em`

**ガイドライン**:
- 一保堂の「間」は **line-height 2.0 + letter-spacing 0.1em** の組み合わせで生まれる。この両方を維持しないと「茶室的な静けさ」が失われる
- 見出しの letter-spacing は 0.08em〜0.5em と幅が広い。大きな見出しほど字間を広げ、看板的な存在感を出す
- weight 300 は文字が細く、小サイズ（12px 以下）では可読性が落ちる。キャプションでは 500〜700 に上げる

### 3.6 禁則処理・改行ルール

```css
/* 推奨設定 */
word-break: normal;
overflow-wrap: break-word;
line-break: strict;
```

- 広い letter-spacing のため改行位置の不自然さが目立ちやすい。見出しの改行位置は `<br>` での手動制御を推奨

### 3.7 OpenType 機能

```css
font-feature-settings: normal;
```

- **palt は未使用**。letter-spacing 0.1em が全角文字にも等しくかかるため、palt で詰めると設計意図に反する
- 游明朝 Pr6 は JIS2004 字形・異体字のアクセスに OpenType 機能を活用できるが、実サイトでは `normal` のまま

### 3.8 縦書き

- 該当なし。横書きのみ

---

## 4. Component Stylings

### Buttons

**Pill CTA（明朝体ピル）** — 「さらに見る」
- Background: `transparent`
- Text: `#4e4e4e`
- Border: `1px solid #4e4e4e`
- Padding: ボタン高さは `line-height: 58px` で確保
- Border Radius: `60px`（完全ピル）
- Font: yu-mincho-pr6, 16px, weight 400, letter-spacing 0.08em
- 特徴: **明朝体でボタンを組む**珍しい設計。押し付けがましさを排し「誘い」の佇まい

**Newsletter Submit（登録ボタン）**
- Background: `transparent`
- Text: `#93806f`
- Border: `1px solid #93806f`
- Padding: `0px 16px`
- Border Radius: `4px`
- Font: source-han-sans-japanese, 14px, weight 500

**Newsletter Icon Button（送信アイコン）**
- Background: `#93806f`
- Text: `#ffffff`
- Border Radius: `0px`（角丸なし）
- 用途: メール送信の矢印アイコンボタン

**Tag Pill** — 「#\_冷たいお茶」等
- Background: `#f4efef`
- Text: `#4e4e4e`
- Padding: `4px 12px`
- Border Radius: `16px`
- Font: source-han-sans-japanese, 12px, weight 500, letter-spacing 0.1em
- Border: none

### Inputs

**Search Input**
- Background: `#ffffff`
- Border: `1px solid #93806f`（ブランド茶色）
- Border Radius: `16px`（丸みのある検索窓）
- Padding: `0px 12px 0px 32px`（左に検索アイコン分のスペース）
- Font Size: `10px`
- Height: line-height で確保

**Email Input（ニュースレター）**
- Background: `#ffffff`
- Border: `1px solid #cdcfd4`
- Border Radius: `4px`
- Padding: `0px 16px`
- Font Size: `16px`
- Height: `50px`（line-height: 50px）

### Cards

- Background: `#ffffff`
- Border: なし（影やボーダーに頼らない。面色の切り替えとタイポグラフィで区分）
- Border Radius: `0px`（Shopify テーマの `--buttons-radius: 0px` が基本。角丸は付けない）
- Shadow: なし

### Header / Navigation

- Background: `#ffffff`
- Position: sticky / fixed
- ナビキャプション: source-han-sans-japanese, 14px, weight 500, letter-spacing 0.18em, color `#3a3a3a`

### Footer

- Background: `#ffffff` または `#f5f6f7`
- Text: `rgba(58, 58, 58, 0.75)`
- フッターリンク: 14px, weight 300

---

## 5. Layout Principles

### Spacing Scale（推奨 8px グリッド）

| Token | Value | 用途 |
|-------|-------|------|
| XS | 4px | タグピル内の縦余白 |
| S | 8px | タグ間ギャップ |
| M | 16px | カード内の余白、ボタン横余白 |
| L | 32px | セクション内の見出しと本文 |
| XL | 64px | セクション間の縦余白 |
| XXL | 120px | ヒーロー上下のゆとり |

### Container

- Max Width: `1200px`（CSS 変数 `--page-width: 120rem`。1rem = 10px として 1200px）
- Padding (horizontal): mobile `16px` / desktop `40px`

### Grid

- 商品グリッド: 2〜4 カラム（レスポンシブ）
- コンテンツ幅: 記事・テキストブロックは 800px 程度
- Gutter: 24〜32px

### Border Radius Scale

| Token | Value | 用途 |
|-------|-------|------|
| None | 0px | カード・メインボタン・入力欄（`--buttons-radius` / `--inputs-radius`） |
| Small | 4px | ニュースレター入力・登録ボタン（`--badge-corner-radius: 4.0rem`） |
| Medium | 16px | 検索窓・タグピル |
| Pill | 60px | 「さらに見る」CTA |

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | `none` | ほぼ全要素。フラットデザインが基本 |
| 1 | `0 2px 8px rgba(0, 0, 0, 0.06)` | ホバー時の浮き上がり（推奨） |
| 2 | `0 8px 24px rgba(0, 0, 0, 0.08)` | ドロップダウン・検索候補（推奨） |

- 一保堂のサイトは**影を一切使わない**フラットデザイン
- 階層の表現は **面色の切り替え**（白 → `#f5f6f7` → `#f4efef` → `#f9f971`）で行う
- 影を追加する場合は **極めて控えめ**（`rgba(0, 0, 0, 0.06)` 以下）にし、茶室的な静けさを壊さない

---

## 7. Do's and Don'ts

### Do（推奨）

- 見出しには **游明朝（yu-mincho-pr6）weight 400** を使い、ボールドにしない。明朝体の細い横画が品格を作る
- 本文は **源ノ角ゴシック weight 300（Light）** を維持する。400 に上げると一保堂の軽やかさが失われる
- **letter-spacing 0.1em** を本文の基本とし、見出しでは 0.08em〜0.5em の範囲で調整する
- **line-height 2.0** を本文・見出し共通で維持し、ページ全体に統一感のある「間」を作る
- ブランドアクセントは **`#93806f`（茶色）** を使う。入力欄のボーダー、キャプション、ニュースレターの CTA に
- CTA は **明朝体のピル（border 1px solid, radius 60px）** で「誘い」のトーンを保つ
- セクション背景は **白と `#f5f6f7`（ライトグレー）の交互配置** を基本とし、特集には `#f9f971`（イエロー）や `#fcf7f7`（ピンクベージュ）を使う
- タグピルは **`#f4efef` 背景 + radius 16px** で柔らかい印象に

### Don't（禁止）

- 本文の letter-spacing を **0.05em 以下にしない**。一保堂の「間」は 0.1em が最低ライン
- 本文のウェイトを **400 以上にしない**（weight 300 が設計の核心）
- 見出しに **ゴシック体を使わない**。見出しは明朝体（游明朝）が鉄則
- CTA に **塗りつぶしボタン**を使わない（ニュースレターのアイコンボタンを除く）。透明背景＋ボーダーが一保堂のトーン
- **純黒 `#000000`** をテキストに使わない。一保堂は `#3a3a3a`（見出し）/ `#4e4e4e`（本文）のソフトブラック
- **強い影**（`box-shadow` の不透明度 0.1 以上）を使わない。フラットデザインを壊す
- **ビビッドなアクセントカラー**（ブルー、レッド、グリーン）を多用しない。`#f9f971`（イエロー）は例外的に使えるが、あくまで特集セクション限定
- ブランドの `#93806f` を **CTA の塗り背景**に使わない（`#ff4500` 等のサードパーティウィジェットの色はブランド色ではない）

---

## 8. Responsive Behavior

### Breakpoints

| Name | Width | 説明 |
|------|-------|------|
| Mobile | ≤ 749px | モバイルレイアウト |
| Tablet | 750–989px | タブレットレイアウト |
| Desktop | ≥ 990px | デスクトップレイアウト |

### モバイル時の調整

- 見出し: 30px → 22〜24px。letter-spacing は 0.08em に統一（0.5em は PC の大見出し専用）
- 本文サイズ: 16px を維持。line-height 2.0 / letter-spacing 0.1em も維持
- 商品グリッド: 4 カラム → 2 カラム
- ナビゲーション: ハンバーガー展開

### タッチターゲット

- Pill CTA: 高さ 58px（十分なタッチ領域）
- タグピル: 高さ 28px 程度（タッチには小さめ。padding 調整を推奨）
- 検索窓: 高さ 36px 程度

### ダークモード

- 該当なし（実測時点で未対応）

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Brand Accent (Brown): #93806f
Text Primary (Heading): #3a3a3a
Text Body: #4e4e4e
Background: #ffffff
Background Alt: #f5f6f7
Tag Surface: #f4efef
Yellow Section: #f9f971
Pink-beige Section: #fcf7f7
Border Default: #cdcfd4
Border Accent: #93806f

Heading Font: yu-mincho-pr6, serif
Body Font: source-han-sans-japanese, sans-serif
（代替: Shippori Mincho / Noto Sans JP）

Body: 16px / weight 300 / line-height 2.0 / letter-spacing 0.1em / color #4e4e4e
Heading (Display): 30px / weight 400 / line-height 2.0 / letter-spacing 0.5em / color #3a3a3a
Heading (Standard): 24px / weight 400 / line-height 2.0 / letter-spacing 0.08em / color #3a3a3a
Nav Caption: 14px / weight 500 / letter-spacing 0.18em
Tag: 12px / weight 500 / letter-spacing 0.1em

Pill CTA: transparent bg / border 1px solid #4e4e4e / radius 60px / 明朝体
Tag Pill: bg #f4efef / radius 16px / ゴシック体
Newsletter: border 1px solid #93806f / radius 4px

Border Radius: 0px（カード）/ 4px（入力欄）/ 16px（検索・タグ）/ 60px（CTA ピル）
Shadow: 基本 none。階層は面色の切り替えで表現
palt: 未使用（font-feature-settings: normal）
```

### プロンプト例

```
一保堂茶舗のデザインに従って、お茶の商品一覧セクションを作成してください。
- 見出しフォント: yu-mincho-pr6, serif（代替: Shippori Mincho）
- 本文フォント: source-han-sans-japanese, sans-serif（代替: Noto Sans JP）
- セクション見出し: 24-30px / weight 400 / line-height 2.0 / letter-spacing 0.08-0.5em / color #3a3a3a
- 本文: 16px / weight 300 / line-height 2.0 / letter-spacing 0.1em / color #4e4e4e
- キャプション: 10-11px / weight 300-700 / color #93806f
- Pill CTA「さらに見る」: 透明背景 / 文字 #4e4e4e / border 1px solid #4e4e4e / radius 60px / 游明朝 16px weight 400 / letter-spacing 0.08em
- タグピル: 背景 #f4efef / 文字 #4e4e4e / radius 16px / 源ノ角ゴシック 12px weight 500 / letter-spacing 0.1em
- カード: 背景白、ボーダー・影なし。radius 0px
- セクション背景: 白 #ffffff と #f5f6f7 の交互。特集は #f9f971 や #fcf7f7
- ブランドアクセント #93806f は入力欄ボーダーとキャプション色に使用
- 見出しにゴシック体を使わない。CTA に塗りつぶしボタンを使わない
- letter-spacing 0.1em と line-height 2.0 を本文で必ず維持する
- 影は一切使わない。面色の切り替えで階層を表現する
```
