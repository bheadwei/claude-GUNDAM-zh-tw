# DESIGN.md — 界（星野リゾート KAI）

> このファイルはAIエージェントが正確な日本語UIを生成するためのデザイン仕様書です。
> セクションヘッダーは英語、値の説明は日本語で記述しています。
> 実測日: 2026-10-12 / 対象: `https://hoshinoresorts.com/ja/brands/kai/`, `/ja/hotels/kaikinugawa/`

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: **字を空ける旅館ブランド。** 明朝を縦に組み、文字そのものにグラデーションを流す。UI（予約・検索）はゴシックで事務的に、コンテンツは明朝でゆったりと、完全に二層に分かれている
- **密度**: 低い。1施設 = 写真1枚＋短い和文という単位を積む。情報は施設ページ側へ送る
- **キーワード**: 縦組み明朝、文字グラデーション、正の字空け、和文3書体、数字専用フォント

**このサイトの核心は5つある。**

1. **字間は「空ける」一方向。** 正の `letter-spacing` だけを使い、負の値は1つも無い。`1.6px`（22 要素）/ `1.8px`（9 要素）/ `2.4px`（5 要素）/ `5px`（縦組み見出し）/ `16.2px` / `18.225px`（ディスプレイ見出し）。**最大 18.225px = 0.1em を超える大きな字空け**がブランドの表情を作っている（既定は `normal` が 229 要素）
2. **縦組みが本物で、しかもデスクトップ限定。** `.my-kai-new__feature__title` が **Shippori Mincho 50px / line-height 1.5（75px）/ letter-spacing 5px（0.1em）/ `writing-mode: vertical-rl`** で 27 要素。**375px では `horizontal-tb` に切り替わり 35px / 3.5px（同じ 0.1em）になる**。画像ではなく CSS で組んでいる
3. **文字にグラデーションを流している。** `.my-kai-new__feature__h1` と `__title` が `linear-gradient(94.07deg, #334b5c 2.85%, #638fb6 70%)` を `background-clip: text` で文字に適用（6 要素）。**角度 94.07deg・停止位置 2.85% / 70%（h1 のみ 80%）をそのまま写す**
4. **和文を3書体で使い分ける。** UI = Noto Sans JP（507 要素）/ 本文・リード = **Shippori Mincho**（59 要素）/ カテゴリラベル = **Zen Kaku Gothic New**（47 要素）。さらに**数字だけ `HNumber`（自社配信の GFNumber）**に切り替える（4 要素、宿泊料金の表示専用）
5. **ブランドトップと施設ページで明朝が違う。** ブランドトップは **Shippori Mincho**、施設ページ（界 鬼怒川）は **Klee One**（29 要素 / 30px / letter-spacing 5.4px = 0.18em）。CSS 変数 `--theme-secondary-font-ja` は `"Klee One", serif` を指しており、**トップの Shippori Mincho はその変数を通さずハードコードされている**

**CSS Custom Properties は 124 個すべて自社**（プラットフォーム由来 0）。ただし後述のとおり**宣言と実装がずれている変数がある**。

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

| 役割 | 実装値 | 実測 |
|------|--------|------|
| **Reservation Cyan** | **`#00a0cb`**（`--color-primary` / `--color-button-reservation`） | 予約 CTA `空室検索` の面（可視 2 要素）。**星野リゾート共通の予約色**で、界 固有の色ではない |
| **Kai Gradient (text)** | **`linear-gradient(94.07deg, #334b5c 2.85%, #638fb6 70%)`** | **文字に流すグラデーション**（`background-clip: text`、6 要素）。`味わう` `感じる` `学ぶ` `触れる` `浸かる` と `界がもてなす 温泉文化体験`（こちらは終端 80%） |
| **Kai Navy** | **`#334b5c`** | グラデーションの始端。単色でも `日本旅会席` `ご当地部屋` `ご当地楽` の文字に使う（可視 5 要素） |
| **Kai Blue** | `#638fb6` | グラデーションの終端。単色使用なし |
| **Kai Tint** | **`#d4e4f2`** | 温泉文化体験セクションの淡い青の地（可視 2 要素） |
| **Facility Beige** | **`#f5efe9`**（`--theme-facility-foundation-background`） | **施設ページの地色**（3 要素）。ブランドトップでは使わない |

> **ブランドトップは白地＋青のグラデーション文字、施設ページはベージュ地。** ページ種別で地色が変わる。

### Semantic（意味的な色）

| 役割 | 変数 | 値 |
|------|------|-----|
| Strong / Error | `--color-text-strong` / `--strong-text-color` / `--color-control-error` | `#d50000` / `#cb0000` |
| Success | `--color-success` | `#00b391` |
| Warning | `--color-warn` | `#ffa000` |

**いずれもブランドトップ・施設ページともに可視 0 要素。** フォーム用に宣言されているだけ。

### Neutral（ニュートラル）

- **Text Base** (`#3c4043`, `--color-text-base`): 本文（施設ページで **76 要素**）
- **Text on Photo** (`#ffffff`): 写真の上（トップ 161 / 施設 117 要素で最多）
- **Text on Photo Dim** (`rgba(255, 255, 255, 0.5)`): 地域フィルタの区切り `|` とラベル（**82 要素**）
- **Text Sub** (`#555555`, `--color-text-sub`): カテゴリの説明文（5 要素）
- **Text Dark** (`#1a1a1a`, `--color-bg-invert` / `--ui-palette-grayscale-900`): ポータルヘッダー（6 要素）。**ナビの地色でもある**（`--main-navi-bg-color`）
- **Text Muted** (`#999999`, `--color-text-muted`) / **Link** (`#006a86`, `--color-text-link`): 宣言はあるが**可視 0 要素**
- **Button Plain** (`#e6e6e6`, `--color-button-plain`): 副次ボタンの面（トップ 3 / 施設 6 要素）
- **Disabled Gray** (`#cccccc`): ポータルナビの非選択（12 要素）
- **Surface** (`#f8f8f8`, `--color-plain`): カードの面
- **Scrim** (`rgba(0, 0, 0, 0.4)` / `rgba(0, 0, 0, 0.5)`): 施設ページで写真の上に敷く暗幕（4 / 12 要素）
- **Background** (`#ffffff`, `--color-bg-base`): ページ背景（`html` / `body` とも `rgb(255,255,255)`）

---

## 3. Typography Rules

### 3.1 和文フォント

| 用途 | 書体 | 実測 |
|------|------|------|
| **UI・ナビ・本文（既定）** | **Noto Sans JP**（`HEmoji` 経由のスタック） | トップ **507 要素** / 施設 267 要素 |
| **本文・リード（ブランドトップ）** | **Shippori Mincho** | トップ **59 要素**。`loaded` は weight **500 の1本だけ** |
| **本文・リード（施設ページ）** | **Klee One** | 施設 **29 要素**。トップでは可視 0 |
| **カテゴリラベル** | **Zen Kaku Gothic New** | トップ **47 要素**。`loaded` は weight 400 |
| **数字（料金表示）** | **HNumber**（= GFNumber、星野リゾート自社配信） | トップ 4 / 施設 5 要素 |

- **`HEmoji` は書体ではなく絵文字の受け皿。** `@font-face { font-family: HEmoji; src: local("Segoe UI Emoji"), local("Apple Color Emoji"), … ; unicode-range: U+A9, U+AE, U+200D, … }` という **`local()` のみ・`unicode-range` で ©®等に限定**した定義。本文スタックの先頭に置かれているが、**©® と絵文字しか拾わない**。`document.fonts` では永久に `unloaded` のままだが**これが正常**
- **`HNumber` は数字専用の自社ウェブフォント。** `assets-gf.hoshinoresorts.com/res/common/fonts/GFNumber/GFNumber-Regular.woff2` を配信。`local("GFNumber Regular")` を先に試し、無ければダウンロードする
- **フォント取得は 115 件**（Google Fonts の Shippori Mincho / Zen Kaku Gothic New の unicode-range サブセット＋GFNumber＋アイコンフォント）

### 3.2 欧文フォント

専用の欧文書体は**無い**。欧文は Noto Sans JP の欧文グリフで出る。
CSS 変数には `--font-sans-en: "Noto Sans"` / `--font-serif-en: "Noto Serif"` / `--theme-secondary-font-en: "Klee One", serif` が宣言されているが、**日本語ページでは可視 0 要素**。

### 3.3 font-family 指定

```css
/* 既定（UI・ナビ・本文） — --base-font / --theme-base-font */
font-family: HEmoji, "Noto Sans JP", sans-serif;

/* 数字（料金） — --number-font */
font-family: HNumber, HEmoji, "Noto Sans JP", sans-serif;

/* 明朝（ブランドトップの本文・縦組み見出し） */
font-family: "Shippori Mincho", serif;

/* 明朝（施設ページ） — --theme-secondary-font-ja */
font-family: "Klee One", serif;

/* カテゴリラベル */
font-family: "Zen Kaku Gothic New", sans-serif;
```

**多言語の出し分け**（CSS 変数に全言語分が宣言されている）:

```css
--font-sans-ja:    "Noto Sans JP";
--font-sans-ko:    "Noto Sans KR";
--font-sans-zh-tw: "Noto Sans TC";
--font-sans-zh-cn: "Noto Sans SC";
--font-serif-ja:   "Noto Serif JP";
--font-serif-ko:   "Noto Serif KR", "Dancing Script";
--font-serif-zh-tw:"Noto Serif TC";
--font-serif-zh-cn:"Noto Serif SC";
```

- **日本語ページでは `*-ja` 系しか読み込まれない。** 他言語の書体が `unloaded` なのは正常（宣言だけで未使用、ではなく**別言語用**）
- **`--theme-secondary-font-ko` と `-zh-*` は `"Noto Serif JP"` を指している**（韓国語・中国語に日本語の明朝を当てている）。意図的かどうかは不明だが、**実装の実態としてそうなっている**

### 3.4 文字サイズ・ウェイト階層

**`html` / `body` ともに `14px` 固定**（1440 / 1200 / 834 / 768 / 767 / 375px すべてで 14px）。`body` の line-height は `21px`（= 1.5）。
**`rem` は 1rem = 14px。16px ではない。**

| Role | Font | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|------|--------|-------------|----------------|------|
| Display (縦組み) | Shippori Mincho | **50px** | 400 | **1.5**（75px） | **5px**（0.1em） | `味わう` 等。`writing-mode: vertical-rl`。375px で 35px / 3.5px / 横組み |
| Display (h1) | Shippori Mincho | 32px 相当 | 400 | 1.2 | **18.225px** | `界がもてなす 温泉文化体験`。文字グラデーション |
| Section Title | Shippori Mincho | — | 400 | 1.25 | **16.2px** | `新施設のご紹介` |
| Facility Name | — | **25.85px** / 18.47px | 400 | 1.1 | normal | 施設名カード（流体。下記参照） |
| Lead (明朝) | Shippori Mincho | **18px** | 400 | **2.00** | **1.8px**（0.1em） | `温泉が湧く。そこに人が集い、…` 9 要素 |
| Sub Headline | Noto Sans JP | 16px | **700** | 1.14 | **1.6px**（0.1em） | `何につかる？`。**サイトで唯一の weight 700** |
| Card Title | — | 16px | 400 | 1.14 | **1.6px**（0.1em） | `彩りの渓流で\n伊達なひととき` 22 要素 |
| Category Label | Zen Kaku Gothic New | **12px** | 400 | 1.4 | **2.4px**（0.2em） | `その土地を、味わい尽くす。` 5 要素。**最も強い字空け率** |
| Body | HEmoji, Noto Sans JP | 14px | 400 | 1.5 | normal | 既定（63 要素） |
| Price (数字) | HNumber | 18px | 400 | 1.0 | normal | `17,000円〜` |
| UI Small | HEmoji, Noto Sans JP | **10px** | 400–500 | 1.5 | normal | `1泊1名` `当サイトが最もお得`。**最多サイズ（88 要素）** |
| Region Chip | Zen Kaku Gothic New | 10.37px / 14.52px | 400 | 1.0 | normal | 地域フィルタ（流体） |

- **weight は 400 が圧倒的**（トップ 230 / 施設 258 要素）。次が 500（37 / 25 要素）。**300 と 700 は各 1 要素ずつしか無い**
- `--font-weight-light: 300` / `--font-weight-regular: 400` / `--font-weight-medium: 500` の3つしか宣言されていない。**600 も 700 も設計に存在しない**（`何につかる？` の 700 は例外的な1要素）

### 3.5 行間・字間

- **`--line-height-*` トークンが5段**: `xs: 1` / `sm: 1.25` / `md: 1.5` / `lg: 1.71` / `xl: 1.8`
- **実測の最多は 1.10（118 要素）** — 施設名カードの2行組み。**トークンに無い値**で、カード側が独自に宣言している
- 次が 1.50（59 / 70 要素、`--line-height-md`）、1.00（61 / 56 要素、`--line-height-xs`）
- **明朝のリードだけ 2.00**（4 要素）。トークンの `xl: 1.8` より広い
- **`0.70` の比率が 6 要素**（`6月 開業` `2027年開業` の開業予定バッジ）。**font-size より行送りが小さい**ので、複数行になると重なる。**真似しない**
- **字間は正の値のみ。負の `letter-spacing` は 1 つも無い。** `em` 換算で見ると:

| 要素 | px | font-size | em |
|------|----|-----------|----|
| カテゴリラベル | 2.4px | 12px | **0.2em** |
| カードタイトル / サブ見出し | 1.6px | 16px | **0.1em** |
| 明朝リード | 1.8px | 18px | **0.1em** |
| 縦組み見出し | 5px | 50px | **0.1em** |
| 施設ページの明朝 | 5.4px | 30px | **0.18em** |

**0.1em が基準、ラベルだけ 0.2em。** サイズが違っても em が揃う＝**各要素が `em` で宣言している**（body からの px 継承ではない）。375px で縦組み見出しが 35px / 3.5px になるのも 0.1em のまま＝比例の証拠。

### 3.6 禁則処理・改行ルール

```css
/* 実サイトは body に word-break / overflow-wrap を指定していない（computed: normal） */
word-break: normal;
overflow-wrap: anywhere;   /* 推奨 */
line-break: strict;        /* 推奨 */
```

- `word-break: auto-phrase` は**使っていない**
- カードタイトルは HTML に実改行（`彩りの渓流で\n伊達なひととき`）を入れて折り返しを固定している。**自動折り返しに任せていない**

### 3.7 OpenType 機能

**`font-feature-settings` は 2 ページとも 0 件。`palt` を使っていない。**

このサイトは**詰めない**ので `palt` が要らない。字間は `letter-spacing` の正の値（0.1〜0.2em）だけで作っている。
**`palt` を足すと約物が詰まって、空けた字間とちぐはぐになる。**

### 3.8 縦書き

```css
.feature-title {
  writing-mode: vertical-rl;
  font-family: "Shippori Mincho", serif;
  font-size: 50px;
  line-height: 1.5;      /* 75px */
  letter-spacing: 0.1em; /* 5px */
}
@media (max-width: 767px) {
  .feature-title {
    writing-mode: horizontal-tb;   /* ★モバイルは横組みに戻す */
    font-size: 35px;               /* letter-spacing は 0.1em のまま 3.5px */
  }
}
```

- **27 要素が `vertical-rl`。外部ウィジェット由来ではなく、`my-kai-new__feature__*` という自社クラス**（実測で `textPreview` が `味わう` `感じる` `学ぶ` `触れる` `浸かる` であることを確認済み）
- **画像ではない。** CSS で組んでいるので文字は選択・検索できる
- **縦組みはデスクトップだけ。** 375px では横組みに切り替わる。モバイルでも縦に組むと1行が画面の高さを超える
- `text-orientation` は既定（`mixed`）のまま。数字を縦中横にする指定は無い

---

## 4. Component Stylings

### Buttons

**Reservation（予約 CTA）** — `空室検索`
- Background: `#00a0cb`（`--color-primary`）
- Text: `#ffffff` / 14px / weight **500** / line-height 1.143（16.002px）
- Border: `1px solid #00a0cb` / Border Radius: **`2px`**（`--button-radius`）
- Box Shadow: **`rgba(0, 0, 0, 0.3) 0 1px 1px 0`**（`--button-shadow`）

**Plain（副次ボタン）**
- Background: `#e6e6e6`（`--color-button-plain`）/ Text: `#1a1a1a` / 14px / 400
- Border: `1px solid #e6e6e6` / Border Radius: `2px`

**Outlined on Photo**（地域チップ）
- Background: `transparent` / Text: `#ffffff` / Zen Kaku Gothic New 10.37〜14.52px / 400
- Border: `1px solid #ffffff` / Border Radius: **`20px`**（ピル。21 要素）

**Glass**（施設数バッジ `全 10 施設`）
- Background: `rgba(255, 255, 255, 0.1)` / Text: `#ffffff` / 14px / Border Radius: `2px`

### Cards

- Background: `#ffffff` / `#f8f8f8`（`--color-plain`）/ 施設ページは `#f5efe9`
- Border Radius: **`2px`** が基準（トップ 20 / 施設 31 要素）。`--border-radius: 4px` という変数もあるが、**実装の中心は 2px**
- Shadow: `rgba(0, 0, 0, 0.3) 0 1px 1px 0`（施設 9 要素）/ `rgba(0, 0, 0, 0.3) 0 0 5px 0`（予約バー）

### Inputs

フォーム用の変数は揃っているが、**2 ページとも可視 0 要素**。実装する場合は宣言値に従う:

| 役割 | 変数 | 値 |
|------|------|-----|
| 面 | `--color-control-bg-color` | `#fafafa` |
| 面（フォーカス） | `--color-control-bg-focused-color` | `#f5fdff` |
| 枠 | `--color-control-border` | `#979797` |
| 無効 | `--color-control-disabled` / `--color-control-bg-disabled` | `#b1b1b1` / `#f6f1ea` |
| エラー | `--color-control-error` / `--color-control-bg-error` | `#cb0000` / `#fff5f5` |

---

## 5. Layout Principles

### Container

| 用途 | 幅 | 実測 |
|------|----|----|
| カード（施設） | **432px** | トップ 12 要素（最多） |
| 中カラム | **604px** | トップ 9 要素 |
| 全幅の上限 | **1920px** | トップ 3 / 施設 5 要素 |
| 本文 | 796px / 720px / 634px / 480px / 470px | — |
| ワイド | 1440px / 1200px / 1092px / 1024px | — |

### Gap

`display: grid` / `flex` の `gap` 実測: **40px**（3 要素・最多）/ 28px / 20px / 16px / 12px / 0px。
**40px と 20px の2つが主軸。**

### Spacing / Z-index

`--header-height: 72px`、`--viewport-offset-top: calc(72px + 0px)`、`--cover-height-wide: 578px`。
z-index は体系化されている: ドロワー 100 → ヘッダー 110 → ヘッダー内モーダル 115 → カバーモーダル 120 → その header/footer 130 → **ローディング 327670**。

---

## 6. Depth & Elevation

| Level | Shadow | 用途 | 実測 |
|-------|--------|------|------|
| 0 | `none` | 既定。**ほぼ全ての要素** | トップ 269 要素中 266 要素 |
| 1 | **`rgba(0, 0, 0, 0.3) 0 1px 1px 0`**（`--button-shadow`） | 予約ボタン・カード | トップ 2 / 施設 9 要素 |
| 2 | `rgba(0, 0, 0, 0.3) 0 0 5px 0` | 固定の予約バー | 1 要素 |

**影の alpha が `0.3` と濃いのに blur が `1px` と小さい**ので、見た目は「縁取り」に近い。`0 2px 8px rgba(0,0,0,0.1)` のような一般的な値に置き換えると別物になる。

---

## 7. Do's and Don'ts

### Do（推奨）

- **字間は正の値だけ使う。基準 `0.1em`、カテゴリラベルだけ `0.2em`**。`em` で各要素に宣言する
- 縦組みは `writing-mode: vertical-rl` ＋ Shippori Mincho 50px / line-height 1.5 / 0.1em。**767px 以下で `horizontal-tb` に戻す**
- 文字グラデーションは `linear-gradient(94.07deg, #334b5c 2.85%, #638fb6 70%)` ＋ `background-clip: text` をそのまま写す
- 和文は用途で3書体に分ける（UI = Noto Sans JP / 本文 = 明朝 / ラベル = Zen Kaku Gothic New）
- 料金などの数字は専用スタック（`HNumber, HEmoji, "Noto Sans JP", sans-serif`）に切り替える
- weight は **400 を既定、強調は 500** まで。`--font-weight-*` は 300 / 400 / 500 の3つしかない
- `border-radius` は `2px`（面）と `20px`（チップのピル）の2つに寄せる
- `rem` は **1rem = 14px** で換算する

### Don't（禁止）

- **`palt` を足さない。** このサイトは 0 件。詰めるのではなく空ける設計
- **負の `letter-spacing` を使わない。** 1 要素も無い
- **モバイルでも縦組みにしない。** 実サイトは 767px 以下で横組みに戻している
- **`--theme-secondary-font` を `"Klee One"` だと思って全ページに適用しない。** ブランドトップの明朝は **Shippori Mincho**（変数を経由していない）。施設ページが Klee One
- **`--color-text-muted` (#999999) / `--color-text-link` (#006a86) / `--color-success` / `--color-warn` を「使われている色」として扱わない。** 2 ページとも可視 0 要素
- **`line-height: 0.70` を真似しない**（開業予定バッジの 6 要素。複数行で文字が重なる）
- `html` の font-size を 16px にしない（全ての `rem` が 1.14 倍になる）
- 影の alpha を薄くしない（`0.3` / blur `1px` が実装値）

---

## 8. Responsive Behavior

### Breakpoints

CSS に出現するメディアクエリ（実測・出現数順）:

| Width | 出現数（トップ / 施設） |
|-------|------------------------|
| **`min-width: 768px`** | **583 / 643** |
| **`max-width: 767px`** | **117 / 130** |
| `max-width: 1023px` | 14 / 14 |
| `max-width: 320px` | 7 / 8 |
| `min-width: 1024px` | 3 / 3 |
| `max-width: 575px` | 2 / 2 |
| `max-width: 1366px` | — / 2 |

- **768px の1本がほぼ全て。** モバイルファースト（`min-width: 768px` で上書きする書き方）で、**デスクトップ側の宣言が 583 件、モバイル側が 117 件**
- **`html` / `body` の font-size は 14px でどの幅でも固定**（768px の前後 ±1px でも確認済み）。流体ルートの崖は無い
- **要素単位では流体がある**: 施設名カード 25.85px / 18.47px、地域チップ 10.37px / 14.52px のような端数は、`vw` ベースのサイズ指定によるもの。`html` が固定なので `rem` では追えない

### 縦組みの切り替え

**767px 以下で `writing-mode: vertical-rl` → `horizontal-tb`、font-size 50px → 35px。** `letter-spacing` は 0.1em のままなので 5px → 3.5px に比例する。**これがこのサイトで最も大きいレスポンシブの挙動。**

### タッチターゲット

- 予約 CTA（14px / radius 2px）、地域チップ（radius 20px）は padding で 44px を確保している
- **10px の UI テキスト（88 要素）とその周辺は 44px を下回る。** モバイルでは上下 padding を足す

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Reservation Cyan: #00a0cb   (--color-primary / 予約CTA)
Kai Navy:         #334b5c   (グラデ始端・単色文字)
Kai Blue:         #638fb6   (グラデ終端)
Text Gradient:    linear-gradient(94.07deg, #334b5c 2.85%, #638fb6 70%)  + background-clip: text
Kai Tint:         #d4e4f2
Facility Beige:   #f5efe9   (施設ページの地色)
Text Base:        #3c4043
Text Sub:         #555555
Text Dark:        #1a1a1a
On Photo:         #ffffff / rgba(255,255,255,0.5)
Button Plain:     #e6e6e6
Surface:          #f8f8f8
Background:       #ffffff

Font (UI):   HEmoji, "Noto Sans JP", sans-serif
Font (数字): HNumber, HEmoji, "Noto Sans JP", sans-serif
Font (明朝): "Shippori Mincho", serif   ← ブランドトップ
Font (明朝): "Klee One", serif          ← 施設ページ
Font (ラベル): "Zen Kaku Gothic New", sans-serif

html / body: 14px 固定（1rem = 14px）/ line-height 1.5
letter-spacing: normal 既定、空けるときは 0.1em（基準）/ 0.2em（カテゴリラベル）。負の値は使わない
font-weight: 400 既定 / 500 強調。600・700 は設計に無い
line-height tokens: 1 / 1.25 / 1.5 / 1.71 / 1.8（実測の最多は 1.10 = カード独自）
縦組み: writing-mode: vertical-rl / Shippori Mincho 50px / 1.5 / 0.1em → 767px 以下で横組み 35px
font-feature-settings: なし（palt 0 件）
Border Radius: 2px（面）/ 20px（チップ）
Shadow: rgba(0,0,0,0.3) 0 1px 1px 0
Container: 432px カード / 604px 中カラム / 1920px 全幅 / gap 40px・20px
Breakpoint: 768px（min-width 側に 583 件）
```

### プロンプト例

```
星野リゾート「界」のデザインシステムに従って、温泉旅館のブランドページを作成してください。
- html / body は font-size 14px 固定、line-height 1.5。rem は 1rem = 14px で換算する
- UI とナビは HEmoji, "Noto Sans JP", sans-serif
- 本文・リードは "Shippori Mincho", serif（18px / line-height 2.0 / letter-spacing 0.1em）
- カテゴリラベルは "Zen Kaku Gothic New", sans-serif（12px / letter-spacing 0.2em）
- 料金の数字だけ HNumber, HEmoji, "Noto Sans JP", sans-serif に切り替える
- letter-spacing は正の値のみ。基準 0.1em、カテゴリラベルだけ 0.2em。em で各要素に宣言する
- 負の letter-spacing と palt は使わない
- 特集見出しは writing-mode: vertical-rl / Shippori Mincho 50px / line-height 1.5 /
  letter-spacing 0.1em。767px 以下では horizontal-tb に戻して 35px にする
- その見出しには linear-gradient(94.07deg, #334b5c 2.85%, #638fb6 70%) を
  background-clip: text で文字に流す
- font-weight は 400 を既定、強調で 500。600 と 700 は使わない
- 予約 CTA は背景 #00a0cb / 白 / 14px / weight 500 / border-radius 2px /
  box-shadow rgba(0,0,0,0.3) 0 1px 1px 0
- 地域チップは透明背景 / 1px solid #ffffff / border-radius 20px
- 施設カードは 432px、中カラム 604px、gap は 40px
- ブレークポイントは 768px の1本（min-width 側に書く）
```
