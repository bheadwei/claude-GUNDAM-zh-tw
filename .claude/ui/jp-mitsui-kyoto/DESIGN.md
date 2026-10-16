# DESIGN.md — HOTEL THE MITSUI KYOTO（ホテル ザ 三井 京都）

> このファイルはAIエージェントが正確な日本語UIを生成するためのデザイン仕様書です。
> セクションヘッダーは英語、値の説明は日本語で記述しています。
> 実測日: 2026-10-08 / 対象: `https://www.hotelthemitsui.com/ja/kyoto/`, `/ja/kyoto/about/`

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: **サイト全体が明朝体 1 本**。ゴシックはボタンのラベルにしか出てこない。色は濃い焦茶（`#190e0a`）と白の 2 色で、写真以外に彩度のあるものを置かない
- **密度**: 低い。`line-height: 1.8`、見出しは `1.5`、表組みでも 1.6。**余白でラグジュアリーを出す**
- **キーワード**: 本明朝、字間 .03em、palt なし、角丸 3px、影ゼロ

**このサイトの核心は4つある。**

1. **和文は Morisawa Fonts Web 配信の「本明朝 Pro Medium」（`MFW-RoHMinchoPro-Md`）1 書体。** 可視 75 要素（トップ）/ 91 要素（下層）。**見出しから表組みの数字まで全部これ**。ゴシックが出るのはボタンの 15 / 7 要素だけ
2. **`letter-spacing: .03em` を `body` に書いて全体へ継承させている。** computed は `0.48px` で、トップ 63 要素・下層 69 要素。**サイズが違っても 0.48px のまま**なので、`em` ではなく絶対値の継承
3. **`font-feature-settings` は 1 要素も使っていない**（実測 0 件）。**`palt` を使わない明朝のサイト**で、括弧や中黒の空きはそのまま残す。これが字間 `.03em` の浅さと釣り合っている
4. **影が 1 つも無い**（`boxShadow` 0 種）。`border-radius` は **`3px` が 13 要素**だけで、それ以外は角なし。**面と 1px の罫線だけで組む**

**CSS Custom Properties は 0 個**（トップ・下層とも `total: 0`）。設計トークンは存在しない。

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

| 役割 | 実装値 | 実測 |
|------|--------|------|
| **Brand Dark Brown** | **`#190e0a`** | **トップの `body` 背景・ヘッダーの予約ボタン（145×96px）・セクション見出し・ボタンの文字と枠線**。可視 18 要素の文字色（トップ）。**このサイトでほぼ唯一のブランド色** |
| **Hero Brown** | **`#1c0b06`** | **トップの `body` 背景**（`pageBackground.resolved` / 根拠 `body`）。`#190e0a` とは別値 |
| **Chip Tint** | **`rgba(25, 14, 10, .06)`** | ニュースのカテゴリチップの面（可視 5 要素） |
| **Overlay** | **`rgba(25, 14, 10, .9)`** | 予約パネルのオーバーレイ |

> **茶色が 2 つあるのは実装の実態。** `#190e0a`（UI）と `#1c0b06`（トップの `body`）は肉眼で区別できない。**新規実装では `#190e0a` に寄せてよい。**
>
> **`heroCover` が `true`（`span.TopKeyVisual__bg` が `#190e0a` で 1440×900 を覆う）。** トップの地色は焦茶だが、**下層ページの地色は白**（`/about/` の `resolved` = `rgb(255,255,255)`）。**トップの背景色をサイト全体の背景として写さないこと。**

### 宣言はあるが使われていない色

CSS には次の 2 色が書かれているが、**トップ・下層とも可視 0 要素**。

| 変数名なし（直書き） | 値 | 用途として書かれている場所 |
|---|---|---|
| オリーブ | `#536b2b` | `background: #536b2b` の CTA（280×80px）、`border: 1px solid #536b2b` のボタン |
| ゴールド | `#a4904c` | `color: #a4904c` の見出し |

> **この 2 色を「ブランドカラー」として採用しないこと。** 実測した 2 ページには 1 要素も出ていない。下層の特設ページ用に残っている定義と見られる。

### Neutral（ニュートラル）

- **Text Primary** (`#000000`): 本文・見出し。**可視 63 要素（トップ）/ 89 要素（下層）**。**このサイトは本文に純黒を使う**
- **Text on Dark** (`#ffffff`): 予約ボタン・ヘッダー帯（可視 7 / 4 要素）
- **Text Muted** (`#666666`): ニュースの日付（可視 4 要素）
- **Text Soft** (`#2d2d2d`): `お問い合わせ`
- **Surface Select** (`#363636`): 予約パネルの `select`（可視 11 要素）
- **Surface Card** (`#f1f1f1`): トップのカード面（可視 4 要素）
- **Header Band** (`#4f4f4f`): ヘッダー最上部の細い帯
- **Border Calendar** (`#cccccc`): 予約カレンダーの罫
- **Dot Inactive** (`#c4c4c4`): スライダーの非アクティブドット
- **UA Button** (`#efefef`): `Menu` `開閉` `閉じる` など**スタイルを当てていない `<button>`**。ブラウザ既定（`border: 2px outset`）がそのまま出ている

> **`#efefef` の `2px outset` ボタンはバグ。** 開閉トリガーに CSS を当て忘れている。**真似しないこと。**

### Semantic（意味的な色）

- **Sunday Red** (`#ff4d4d`): 予約カレンダーの日曜のみ
- それ以外の semantic パレットは持たない

---

## 3. Typography Rules

### 3.1 和文フォント

- **明朝体（既定・ほぼすべて）**: **本明朝 Pro Medium**（`MFW-RoHMinchoPro-Md` / リョービ・モリサワ、**Morisawa Fonts Web 配信**）
- **ゴシック体（ボタンのみ）**: **游ゴシック体**（OS フォント。Web フォントではない）
- 本文・見出し・表組み・ナビ・日付・価格まで**すべて明朝**

**配信は Morisawa Fonts Web（`morisawafonts.net`）。** Adobe Fonts でも TypeSquare でもない第 3 の経路。

```css
/* 実サイトの @font-face（抜粋。実際は unicode-range で 20 以上に分割されている） */
@font-face {
  font-family: mfw-rohminchopro-md;
  font-display: swap;
  font-weight: 1 1000;
  src: url(/f/01K94CGT.../9nox2q2mna.woff2) format("woff2");
  unicode-range: U+4e07, U+4e95, U+4eac, ...;   /* 漢字を使用頻度で分割 */
}
```

- **実測したフォントファイルの要求は 24 件**（うち `morisawafonts.net` が 22 件）。`unicode-range` で細かく分割されているため、**1 ページで 20 本以上の woff2 を読む**
- **`mfw-rohminchostd-bd`（本明朝 Std Bold）も宣言されているが、`document.fonts` で `unloaded`・可視 0 要素。** CSS に `font-family: MFW-RoHMinchoStd-Bd; font-weight: 700` の定義はあるが、実測した 2 ページでは使われていない
- **`@font-face` が `font-weight: 1 1000` を宣言している。** つまり **400 でも 700 でも同じファイルが返る**。トップの `h1.TopKeyVisual__head` は `font-weight: 700` と書かれているが、ファミリーが全域をカバーしているため**合成太字も起きない**。**太さを変えたいときは `font-weight` ではなくファミリー（`...Pro-Md` ↔ `...Std-Bd`）を切り替える**

### 3.2 欧文フォント

- **セリフ**: **VanDijckRoman**（セルフホスト / `cdn.fonts.net`）。**`loaded`**。`－EMBRACING JAPAN'S BEAUTY－` とコピーライトの **2 要素だけ**。`VanDijckItalic` も宣言されているが **`unloaded`**
- **サンセリフ**: **Roboto**（Google Fonts、400 / 500 `loaded`）。**`Close` ボタン 1 要素だけ**
- **等幅**: 使用しない

### 3.3 font-family 指定

```css
/* 本文・見出し・表組み（body に 1 回） */
font-family: MFW-RoHMinchoPro-Md, 游明朝体, "Yu Mincho", YuMincho,
             "ヒラギノ明朝 Pro", "Hiragino Mincho Pro", serif;

/* ボタン */
font-family: 游ゴシック体, YuGothic, "游ゴシック Medium", "Yu Gothic Medium", sans-serif;

/* 一部のボタン（CSS 上） */
font-family: "Noto Sans JP", 游ゴシック体, YuGothic, "游ゴシック Medium", "Yu Gothic Medium", sans-serif;

/* 英字見出し */
font-family: VanDijckRoman, serif;
```

**フォールバックの考え方 — 実サイトの 3 つの引っかかり**:

- **`"Yu Gotich"` というタイプミスがある**（`font-family: Roboto, Yu Gotich, sans-serif`）。`Gothic` の綴り違いで、**このファミリーは存在しないので常に飛ばされる**。**正しくは `"Yu Gothic"`**
- **Windows の游ゴシック問題に対して、Medium を Regular より後ろに置いている。** `游ゴシック体, YuGothic, "游ゴシック Medium", "Yu Gothic Medium"` の順だと、**Windows では 2 番目の `YuGothic`（Light 相当）が先に当たって細く出る**。**Medium を先に置くのが正しい**（`"游ゴシック Medium", "Yu Gothic Medium", 游ゴシック体, YuGothic`）
- **`"Noto Sans JP"` をスタック先頭に書いている箇所があるが、`@font-face` もフォント要求も無い。** OS に入っていなければ素通りする。**読み込むか、書かないかのどちらかにする**

### 3.4 文字サイズ・ウェイト階層

`html` / `body` とも **16px 固定**（1440 / 1200 / 834 / 375px の 4 幅すべて）。流体ルートもブレークポイント切替も無い。

| Role | Font | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|------|--------|-------------|----------------|------|
| **Hero Heading** | 本明朝 Pro Md | 32px | 700（実効 Medium） | 28.8px（継承） | 0.48px（継承） | トップのキービジュアル見出し |
| **Page Title** | 本明朝 Pro Md | 34px | 400 | **51px (1.50)** | 0.48px（継承） | 下層の `h1.head-1` |
| **Menu Head** | 本明朝 Pro Md | 34px | 400 | 51px (1.50) | 0.48px（継承） | 予約パネルの見出し（白） |
| **Section Heading ★** | 本明朝 Pro Md | **26px** | 400 | **39px (1.50)** | 0.48px（継承） | `h2`。可視 9 / 7 要素 |
| **English Lead** | **VanDijckRoman** | 22px | 400 | **1.40** | 0.48px（継承） | `－EMBRACING JAPAN'S BEAUTY－` |
| **Lead** | 本明朝 Pro Md | 19px | 400 | **1.60** | 0.48px（継承） | リード文・電話番号 |
| **Body ★** | 本明朝 Pro Md | **16px** | 400 | **28.8px (1.80)** | **0.48px = .03em** | **既定。可視 46 / 45 要素** |
| **Table Cell** | 本明朝 Pro Md | 16px | 400 | 25.6px (1.60) | 0.48px（継承） | 概要表の `td` |
| **Nav** | 本明朝 Pro Md | 16px | 400 | **16px (1.00)** | 0.48px（継承） | グローバルナビ |
| **Button** | **游ゴシック体** | 16px | **500** | 16px (1.00) | 0.48px（継承） | `.Button` |
| **Footer / Copyright** | VanDijckRoman | 14px | 400 | 1.60 | 0.48px（継承） | `© 2021 Mitsui Fudosan Resort Management` |
| **Caption** | 本明朝 Pro Md | 13px | 400 | 16px (1.23) | 0.48px（継承） | 料金の注記 |
| **Label ★** | 本明朝 Pro Md | **12px** | 400 | **21.6px (1.80)** | **0.24px = .02em** | 日付・パンくず・表の見出し。**可視 33 / 39 要素** |
| **Price** | 本明朝 Pro Md | 10px | 400 | 18px (1.80) | 0.48px（継承） | カレンダーの最安値 |

**ウェイトは 400 と 500 の 2 値だけ。** 500 は**ボタン（游ゴシック体）専用**で、明朝側は実質 400 一択。

### 3.5 行間・字間

- **本文の行間**: **`line-height: 1.8`（単位なし）** → 16px で 28.8px。各要素が自分のサイズで再計算する
- **見出しの行間**: **1.50**（26px → 39px、34px → 51px）
- **ナビ・ボタンの行間**: **1.00**（16px → 16px）
- **本文の字間**: **`letter-spacing: .03em` を `body` に 1 回**。computed `0.48px` が子へ**絶対値として降りる**（サイズが違っても 0.48px）
- **12px 系の字間**: 日付・パンくずなど 12px の要素だけ **`.02em`（0.24px）を自分で宣言**している
- 見出しによっては **`.04em`** を直接当てている（CSS 上。26px 見出しの一部）

**CSS に現れる `letter-spacing` の宣言値**: `.03em`（body）/ `.04em` / `.02em` / `.01em` / `0`。

**ガイドライン**:

- **`line-height` は単位なし、`letter-spacing` は `body` に `em` で 1 回。** 子要素で `.03em` を再宣言しない
- **明朝の本文に `line-height: 1.8` は必須。** 1.5 まで詰めると本明朝の縦画が重なって読めなくなる
- **12px 以下だけ字間を `.02em` に落としている**。小さい文字で `.03em` のままだと間延びする

### 3.6 禁則処理・改行ルール

```css
/* 実測：明示的な宣言なし（UA 既定） */
word-break: normal;
```

- 4 幅（1440 / 1200 / 834 / 375px）すべてで `body` の `word-break` は `normal`
- `overflow-wrap` / `line-break` / `word-break: auto-phrase` の宣言は無い
- 英字見出しだけ `text-align: justify` を当てている箇所がある（CSS 上）

**禁則対象**（ブラウザ既定に任せている）:
- 行頭禁止: `）」』】〕〉》、。，．・：；？！`
- 行末禁止: `（「『【〔〈《`

### 3.7 OpenType 機能

```css
/* 該当なし。font-feature-settings の宣言は 0 件 */
```

- **`palt` を 1 要素も使っていない**（`typography.fontFeatureSettings` が空）
- **これは意図的な選択として読む。** 明朝で `palt` を効かせると括弧や句読点が詰まりすぎてラグジュアリーの間が消える。**字間 `.03em` の浅さと「詰めない」がセットになっている**
- `"tnum"` `"kern"` `"halt"` も無し
- 代わりに **`-webkit-font-smoothing: antialiased` / `-moz-osx-font-smoothing: grayscale`** を `body` に当てている（明朝の細い画を潰さないため）

### 3.8 縦書き

```css
/* 該当なし */
```

**縦組みは使っていない**（`typography.verticalWriting` がトップ・下層とも 0 件）。京都のラグジュアリーホテルだが、縦組みに寄せずに横組みで通している。

---

## 4. Component Stylings

### Buttons

**Primary（ヘッダーの予約ボタン）**

- Background: `#190e0a`
- Text: `#ffffff`
- Font: **本明朝 Pro Md** / 16px / 400 / line-height 18.4px
- Size: **145 × 96px**（ヘッダー右端に 2 つ並ぶ）
- Border Radius: **`0px`**
- Shadow: none

**Secondary（`.Button -normal -light` — 本文中の既定ボタン）**

- Background: `transparent`
- Text: `#190e0a`
- Font: **游ゴシック体** / 16px / **500** / line-height 16px / letter-spacing 0.48px
- Border: **`1px solid #190e0a`**
- Padding: `13px 20px`
- Size: **180 × 44px**（幅固定）
- Border Radius: **`3px`**（サイト唯一の角丸）
- Shadow: none

> **ボタンだけゴシックになる。** 本文が全部明朝なので、**ボタンのラベルが明朝だと押せるように見えない**という判断と読める。**この切り替えを再現すること。**

**Chip（ニュースのカテゴリ）**

- Background: `rgba(25, 14, 10, .06)`
- Text: `#190e0a` / 本明朝 Pro Md / 12px / 400 / letter-spacing 0.48px
- Padding: `0 6px` / 高さ 22px / Border Radius `0px`

**未スタイルの `<button>`（バグ）**

`Menu` `開閉` `閉じる` はブラウザ既定のまま（`background: #efefef` / `border: 2px outset` / `padding: 1px 6px`）。**実装時は必ずリセットすること。**

### Inputs

- `select`（予約パネル）: Background `#363636` / Text `#ffffff` / Border Radius `0px` / 右に `/images/menu/select...` の矢印画像
- `input`: 独自のスタイルは実測できなかった（予約フォームは別ドメイン）
- 実装するなら **Border Radius `3px`**（ボタンに合わせる）、Border `1px solid #190e0a`

### Cards

- Background: `#f1f1f1`（トップのインデックスカード。可視 4 要素）
- Border: なし
- Border Radius: **`0px`**
- Shadow: **none**（サイト全体で影 0 種）
- 見出し: 本明朝 Pro Md / 26px / line-height 1.50 / color `#190e0a`

### Table（概要表）

- `th`: 本明朝 Pro Md / **12px** / 400 / line-height 21.6px / 幅 588px
- `td`: 本明朝 Pro Md / 16px / 400 / line-height 25.6px（1.60）/ 幅 588px
- 罫線・背景色なし。**サイズ差だけで見出しと値を分ける**

---

## 5. Layout Principles

### Spacing Scale

CSS Custom Properties が 0 個なので、スケールは暗黙。実測から確認できた `gap`:

| Token | Value | 用途 |
|-------|-------|------|
| S | 16px | 小要素間 |
| M | **24px** | **カード間（最多）** |
| M (row/col) | `0 26px` | 横並びの列間 |

- ボタンの内側: `13px 20px`
- 見出し下: `10px`（`h1.head-1`）

### Container

| 文脈 | Max Width | 実測 |
|------|-----------|------|
| **標準コンテナ** | **1240px** | トップ 3 / 下層 5 要素で最多 |
| **本文コンテナ** | **996px** | トップ 3 / 下層 2 要素 |
| ワイド | 1200px | `h1.head-1` の実幅 |
| 2 カラムの左 | 792px | — |
| 2 カラムの右（見出し） | **384px** | `h2.about__head` の固定幅 |

### Grid

- 概要ページは **384px（見出し）＋ 792px（本文）の 2 カラム**
- カードは 3 列 / `gap: 24px`

---

## 6. Depth & Elevation

**影が 1 つも無い。**

| Level | Shadow | 用途 | 実測 |
|-------|--------|------|------|
| 0 | `none` | **全要素** | トップ・下層とも `boxShadow` 0 種 |

- **`border-radius` は `3px` が 13 要素だけ**（ボタン）。ほかに `50%` が 5 要素（スライダーのドット）。**それ以外はすべて角なし**
- 奥行きは**面の明暗（`#ffffff` / `#f1f1f1` / `#190e0a`）とオーバーレイ（`rgba(25,14,10,.9)`）だけ**で作る
- **`box-shadow` を足さないこと。** 影を入れた瞬間にこのサイトの静けさが消える

---

## 7. Do's and Don'ts

### Do（推奨）

- **本文から表組みまで明朝 1 本で通す。** ゴシックを出すのは**ボタンのラベルだけ**
- **`letter-spacing: .03em` と `line-height: 1.8` は `body` に 1 回だけ書く**（子は継承）
- **12px 以下の文字だけ `letter-spacing: .02em` に落とす**
- **`border-radius` は `3px`（ボタン）以外 0。** `box-shadow` は使わない
- **`-webkit-font-smoothing: antialiased` を `body` に当てる**（明朝の細い画を保つため）
- 下層ページの地色は **白**。焦茶 `#190e0a` はトップのキービジュアルとボタン・見出しに限定する
- ボタンは **180 × 44px の固定サイズ**、`1px solid #190e0a`、背景透明

### Don't（禁止）

- **`font-feature-settings: "palt"` を足さない。** 実サイトは 0 件。明朝で詰めると間が消える
- **`line-height` を 1.5 以下にしない。** 本明朝は 1.8 前提で組まれている
- **子要素で `letter-spacing: .03em` を再宣言しない**（0.48px が絶対値で継承されている）
- **`font-weight: 700` に頼らない。** `@font-face` が `font-weight: 1 1000` を宣言しているので 400 と同じファイルが返り、合成太字も起きない。太くしたいなら `MFW-RoHMinchoStd-Bd` を**読み込んだうえで**ファミリーを切り替える
- **`"Yu Gotich"` をそのまま写さない。** 実サイトのタイプミス（正しくは `"Yu Gothic"`）
- **游ゴシックの Medium を Regular より後ろに置かない。** 実サイトは `游ゴシック体, YuGothic, "游ゴシック Medium", ...` の順で、**Windows で細く出る**。Medium を先頭側に移す
- **`"Noto Sans JP"` をスタック先頭に書いて読み込まない**をやらない。実サイトは `@font-face` もフォント要求も無い
- **`#536b2b`（オリーブ）/ `#a4904c`（ゴールド）をブランド色として使わない。** CSS にはあるが実測 2 ページで可視 0 要素
- **`<button>` をリセットせずに置かない。** 実サイトの `Menu` `開閉` `閉じる` はブラウザ既定（`2px outset` / `#efefef`）が出てしまっている
- **影を足さない。** サイト全体で 0 種

---

## 8. Responsive Behavior

### Breakpoints

| Name | Width | 実測 | 説明 |
|------|-------|------|------|
| **Mobile** | `max-width: 768px` | **522 回** | **主ブレークポイント。圧倒的多数** |
| Tablet | `max-width: 1024px` | 67 回 | — |
| Desktop | `min-width: 769px` | 41 回 | — |
| Container | `max-width: 1240px` | 14 回 | コンテナ幅の調整 |
| Wide | `min-width: 1025px` | 6 回 | — |
| Hover | `(hover: hover)` | 4 回 | タッチデバイスでホバーを無効化 |

> **`(min-width: 1025px) and (max-width: 768px)` のように成立しない組み合わせが 2 件ある**（常に false）。ビルド時のネスト崩れと見られる。**写さないこと。**

### 幅ごとの実測値（`body`）

| 幅 | html | body font-size | line-height | letter-spacing | word-break |
|----|------|----------------|-------------|----------------|------------|
| 1440px | 16px | 16px | 28.8px | 0.48px | normal |
| 1200px | 16px | 16px | 28.8px | 0.48px | normal |
| 834px | 16px | 16px | 28.8px | 0.48px | normal |
| 375px | 16px | 16px | 28.8px | 0.48px | normal |

> **`body` は 4 幅すべて同じ。** 流体ルートもブレークポイント切替も無い。縮むのは見出しとレイアウトだけで、**本文は 16px / 1.8 / .03em のまま**。

### タッチターゲット

- `.Button` は **180 × 44px**。**44px 基準ちょうど**
- ヘッダーの予約ボタンは 145 × 96px で十分
- グローバルナビのリンクは `line-height: 1.00` の 16px。**モバイルではハンバーガーに切り替わる**（`max-width: 768px` の 522 件がこれを担う）

### フォントサイズの調整

- 本文は縮小しない（16px 固定）
- 見出し（34px / 26px）は `max-width: 768px` のメディアクエリで個別に縮小

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Primary Color: #190e0a   (焦茶。ボタン・見出し・枠線)
Text Color:    #000000
Muted:         #666666
Surface:       #f1f1f1
Background:    #ffffff   (下層) / #190e0a (トップのキービジュアル)
Font (本文): MFW-RoHMinchoPro-Md, 游明朝体, "Yu Mincho", YuMincho, "ヒラギノ明朝 ProN", serif
Font (ボタン): "游ゴシック Medium", "Yu Gothic Medium", 游ゴシック体, YuGothic, sans-serif
Font (欧文):  VanDijckRoman, serif
Body Size: 16px (全幅で固定)
Font Weight: 400 (本文) / 500 (ボタン)
Line Height: 1.8 (本文) / 1.5 (見出し) / 1.0 (ナビ・ボタン)
Letter Spacing: .03em ← body に 1 回。12px 以下だけ .02em
font-feature-settings: なし（palt を足さない）
Border Radius: 3px (ボタンのみ) / 0 (それ以外)
Box Shadow: なし
Container: 1240px / 本文 996px
```

### プロンプト例

```
HOTEL THE MITSUI KYOTO のデザインシステムに従って、客室一覧ページを作成してください。

- body:
    color: #000000; background: #ffffff;
    font-family: MFW-RoHMinchoPro-Md, 游明朝体, "Yu Mincho", YuMincho, "ヒラギノ明朝 ProN", serif;
    font-size: 16px; font-weight: 400;
    line-height: 1.8;          /* 単位なし */
    letter-spacing: .03em;     /* 子へは 0.48px として継承される */
    -webkit-font-smoothing: antialiased;
  ※ font-feature-settings は書かない（実サイトは palt を 1 要素も使っていない）
- 見出し（h2）は 26px / line-height 1.5 / color #190e0a。font-weight は 400 のまま
- 日付・注記など 12px の要素だけ letter-spacing: .02em に落とす
- 本文は 384px（見出し）＋ 792px（本文）の 2 カラム、コンテナ 1240px
- ボタンだけゴシックにする:
    font-family: "游ゴシック Medium", "Yu Gothic Medium", 游ゴシック体, YuGothic, sans-serif;
    font-size: 16px; font-weight: 500; line-height: 1;
    color: #190e0a; background: transparent; border: 1px solid #190e0a;
    width: 180px; height: 44px; padding: 13px 20px; border-radius: 3px;
- カードは背景 #f1f1f1・角丸なし・影なし
- box-shadow はページ全体で 1 つも使わない
```
