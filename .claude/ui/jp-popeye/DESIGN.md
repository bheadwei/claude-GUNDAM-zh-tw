# DESIGN.md — POPEYE Web

> POPEYE Web（https://popeyemagazine.jp/）のデザイン仕様書。
> 2026-05-08 取得の computed style と CSS Custom Properties に基づく。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: マガジンハウスの『POPEYE』Web 版。シティボーイ向けカルチャー誌の遊び心を Web に翻訳。**強烈なコバルトブルー (#343ec9) + 白 + シアン (#3affff)** の三色構成で、雑誌のような大胆な紙面密度をデジタルで再現
- **密度**: 高密度。カードを格子状に詰め、各カードに非対称の角丸 (`border-radius: 0px 5px 5px 0px` 等) を入れて誌面のような切り抜きカット感を出す
- **キーワード**: ポップ、若々しい、ブルー、レトロモダン、雑誌的、アシンメトリック
- **特徴**: テキストは原則 `#343ec9`（POPEYE Blue）の青文字。背景白に青文字、青背景に白文字を反転させながら使い、雑誌の見開きのようなコントラスト構造を作る。検索フォームや CTA には `border-radius: 24px`（pill）と `5px`（カード内）の 2 トークンのみを使用

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）— CSS Custom Properties 実測値

POPEYE Web は CSS Custom Properties で **9 つのブルー段階** とアクセントカラーを定義している。

- **Primary** (`#343ec9`): POPEYE Blue。テキスト、ボーダー、アクティブ面。サイトの主役色
- **Primary 2** (`#3b47e7`): やや明るい青
- **Primary 3** (`#4350ff`): さらに明るい青
- **Primary 4** (`#4b59ff`)
- **Primary 5** (`#5363ff`)
- **Primary 6** (`#5b6cff`)
- **Primary 7** (`#6275ff`)
- **Logo Color** (`#ff9000`): ロゴのオレンジ（Primary に対する強烈な補色アクセント）

### Calendar / Today モジュール

- **Calendar Primary** (`#3affff`): カレンダーの強調シアン（Primary の補色側）
- **Calendar Background** (`#002184`): 濃紺の暗いブルー (rgb 0, 33, 132)

### TODO リスト・ドロワー

- **TODO Title BG** (`#add8e6`): ライトブルー
- **TODO Accent** (`#0055ff`): ビビッドブルー
- **TODO BG** (`#f7f7f7`): ライトグレー背景
- **Drawer Primary** (`#343ec9`)
- **Drawer BG** (`#ffffff`)
- **Gathering Color** (`orange`): イベント告知用

### Neutral

- **Background** (`#ffffff`): ページ背景
- **Surface Subdued** (`#f5f5f5`): 一部のカード背景
- **Text Body**: 通常 `#343ec9`（白背景の場合）
- **Text Inverse**: `#ffffff`（青背景の場合）
- **Article Body** (`#000000`): 記事ページ本文のみ純黒（読み物として可読性優先）

### Border Radius トークン

- **Radius** (`24px`): pill / 大きな角丸
- **Radius Small** (`5px`): カード・タグの小さな角丸

---

## 3. Typography Rules

### 3.1 和文フォント

POPEYE は **DNP 秀英角ゴシック金 (Std)** を Adobe Fonts 経由で使用。雑誌『POPEYE』本誌の組版に近い表情を Web で再現する。

- **dnp-shuei-gothic-kin-std**: DNP 秀英角ゴシック金 Std（Adobe Fonts）
- システムフォールバック: なし（直接 sans-serif へ）

> Adobe Fonts のドメインライセンスのため、preview.html ではこのフォントが表示されない。雰囲気の近い代替として **Zen Kaku Gothic New** を使用する（DNP 秀英の流れを汲む字面）。

### 3.2 欧文フォント

- **DM Sans**: Google Fonts のジオメトリック・サンセリフ。POPEYE の英文表記（POPEYE / WEB / NO.949 等）を担当
- 和文フォント (秀英角ゴシック金) より先に置き、欧文部分は DM Sans で組む

### 3.3 font-family 指定

```css
/* メイン */
font-family: "DM Sans", dnp-shuei-gothic-kin-std, sans-serif;

/* 一部の system UI（検索ボタン等） */
font-family: Arial;
```

**フォールバックの考え方**:
- 欧文 (DM Sans) を最優先 → ブランド名・数字を確実に DM Sans で表示
- 和文は秀英角ゴシック金を直接呼び、システムフォントへのフォールバックを設けない（Adobe Fonts 前提）
- Adobe Fonts が読み込めない環境では sans-serif にフォールバック

### 3.4 文字サイズ・ウェイト階層

| Role | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|--------|-------------|----------------|------|
| Article Title (h1 ls02) | 43.2px | 400 | 1.0 (43.2px) | 0.0667em (2.88px) | 記事大見出し。字間広め |
| Marquee Headline | 20.16px | 400 | 1.5 (30.24px) | 0.0714em (1.44px) | 流れるテロップ |
| Card Title (h3 medium) | 20.16px | 400 | 1.5 (30.24px) | 0.025em (0.36px) | 「醤油、砂糖、お酒で...」 |
| Article Body (記事 p) | 17.28px | 400 | 1.5 (25.92px) | 0.025em | カレンダー本文 |
| Body (デフォルト) | 14.4px | 400 | 1.0 (14.4px) | 0.025em (0.36px) | サイト標準 |
| Card Body (h3 small) | 14.4px | 400 | 1.5 (21.6px) | 0.025em | カード見出し small |
| Tag Caption | 12.5px | 400 | 1.5 (18.75px) | 0.025em | 「フード」「ファッション」等のカテゴリタグ |
| Logo / Header | 14.4px | 400 | 0 | 0.025em | ヘッダーロゴ位置に表示される `POPEYE` 文字 |
| Input | 16px | 400 | 1.0 (16px) | normal | フォーム入力 |

**特徴**:
- POPEYE は **font-weight を 400 一本** で統一する（本文・見出し問わず）。太さで階層を作らず、サイズと色とレイアウトで階層を作る。これは雑誌の本誌組版の流儀
- ボディサイズは 14.4px と Web 標準 (16px) より小さめ。雑誌の細かな組版を再現

### 3.5 行間・字間

- **本文の行間**: `line-height: 1.5` を基本（21.6px / 14.4px）。雑誌的な詰めたリズム
- **見出しの行間**: `line-height: 1.0` も多用（h1, h5, header）。タイトルは 1 行で組み、行間で開く
- **本文の字間**: `letter-spacing: 0.36px`（≈0.025em）。微小な字間を全文に適用
- **大見出しの字間**: `letter-spacing: 2.88px`（h1 43.2px 時、≈0.0667em）。雑誌の大扉タイトル風に大きく開ける
- **マーキータイトル**: `letter-spacing: 1.44px`（20.16px 時、≈0.0714em）。流れるテロップでも字間を広めに

### 3.6 OpenType 機能

```css
font-feature-settings: "palt";
```

- POPEYE は **palt** を全テキスト要素に一律適用
- 雑誌組版の「字詰めの密度」を Web 上で再現する目的
- 数字も palt が効くため、価格・日付の半角数字が和文と均一の密度で組まれる

---

## 4. Component Stylings

### Buttons / CTA

**Primary CTA / 最新号バナー**（"最新号: NO.949 特集..."）

- Background: `#ffffff`
- Text: `#343ec9`
- Border: 1px solid `#343ec9`
- Border Radius: **24px**（pill）
- Padding: 14.4px 0
- Font: DM Sans + 秀英角ゴシック金
- Font Size: 14.4px
- Font Weight: 400
- Letter Spacing: 0.36px
- Footer 上の同 CTA は 反転（青背景・白文字・白ボーダー）

**Calendar Action**（"TODOリストを見る！"）

- Background: `#3affff`（シアン）
- Text: `#002184`（濃紺）
- Border: 1px solid `#3affff`
- Border Radius: 24px（pill）
- Padding: 0 28.8px
- Font Size: 14.4px

**Card Title with Asymmetric Corner**（カード見出し）

- Background: `#ffffff`
- Text: `#343ec9`
- Border: 1px solid `#343ec9`
- Border Radius: **`0px 5px 5px 0px`**（左上のみ角丸なし）または **`0px 5px 5px`**（右下も追加）
- Padding: 10.8px 14.4px
- 雑誌の切り抜きシール風の造形

**Town Talk Card**（曜日別カラム）

- Background: `#343ec9`
- Text: `#ffffff`
- Border Radius: 各カードで異なる角を採用
  - 月曜カード: `0px 24px 0px 0px`（右上だけ pill）
  - 日曜カード: `0px 0px 24px`（右下だけ pill）
  - 火・水・木・金・土: `0px`（フラット）
- カード群を並べると「曜日カードのまとまり」全体に大きな pill が描かれる構造

**Newsletter Submit**

- Background: `#343ec9`
- Text: `#ffffff`
- Border Radius: `0px 24px 24px 0px`（右側のみ pill）
- Input 側: `border-radius: 24px 0px 0px 24px`（左側のみ pill）
- 並ぶと完全な pill 形状になる

### Inputs

- Background: `#ffffff`
- Border: 1px solid `#343ec9`
- Border Radius: `24px 0px 0px 24px`（左側のみ pill。Submit と組み合わせる前提）
- Padding: 0 14.4px
- Font Size: 16px
- Font: DM Sans + 秀英角ゴシック金

フッター内の Newsletter は反転配色:
- Background: `#343ec9`
- Border: 1px solid `#ffffff`
- Text: `#ffffff`

### Cards / Tags

**Category Tag**（"フード" 等）

- Background: `#ffffff`
- Text: `#343ec9`
- Border Radius: `5px 5px 0px 0px`（上端のみ角丸。カード上部に貼り付ける）
- Padding: 7.2px 14.4px
- Font Size: 12.5px

**Search Submit**（虫眼鏡アイコンボタン）

- Background: `#343ec9`
- Border Radius: `0px 24px 24px 0px`
- Padding: 16.128px

---

## 5. Layout Principles

### Container

- 雑誌的な高密度グリッド
- カードは 2〜4 カラムで隙間なく敷き詰め
- 角丸は全体ではなく各カードの角単位で設定し、カード群を並べたときに全体で 1 つの大きなオブジェクトになるように設計

### Spacing Scale（実測ベース、`p-`, `m-` クラス命名）

CSS クラス命名から推定される spacing トークン:

| Token | Class | 推定値 |
|-------|-------|--------|
| 0_5 | `pt-0_5` | 7.2px (≈0.5rem) |
| 1 | `pt-1`, `pl-1` | 14.4px (≈1rem) |
| 2 | `pl-2`, `pt-2`, `mt-2` | 28.8px (≈2rem) |

### Border Radius Tokens

```css
--radius: 24px;        /* pill / 大きな角丸 */
--radius-small: 5px;   /* カード・タグの小角丸 */
```

この 2 トークンの組み合わせ + 「どの角に適用するか」のバリエーションで、すべての角丸表現が成立する。

---

## 6. Depth & Elevation

POPEYE はシャドウを **使わない**。フラットな色面と非対称角丸で誌面構造を作る。

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | none | 標準。ほぼ全要素 |

---

## 7. Do's and Don'ts

### Do（推奨）

- **テキストの基本色は `#343ec9`（POPEYE Blue）**。本文・見出し・リンク・ボーダーまで一律
- 反転コンテキストでは **白背景に青文字 / 青背景に白文字** で組み、雑誌の見開きのようなコントラストを作る
- font-weight は **400 一本** で統一。太さで階層を作らず、サイズ・色・レイアウトで階層を表現
- カードの角丸は **非対称（4 つの角を別々に設定）** で組む。雑誌の切り抜きカット感
- 字間は `letter-spacing: 0.025em` を全テキストに均一適用、大見出しのみ `0.067em` 以上に開ける
- font-feature-settings に `"palt"` を必ず指定する
- **CTA の角丸は 24px (pill) と 5px (small) の 2 値のみ**を使う
- カレンダー・TODO セクションだけは **シアン (#3affff)** と **濃紺 (#002184)** の特別配色を許容

### Don't（禁止）

- 黒文字 `#000000` を主役にしない（記事ページの本文以外は基本的に `#343ec9`）
- font-weight 700 や 600 を多用しない。POPEYE は 400 で統一する組版思想
- 影 (box-shadow) を入れない。POPEYE はフラット
- 角丸を全体に均一に適用しない。**「どの角を丸めるか」を意識的に設計**
- 黄色・赤などの強い暖色アクセントは使わない。アクセントは **オレンジ (#ff9000)** か **シアン (#3affff)** のみ
- 行間 1.8 以上で本文を組まない（雑誌的な密度が失われる）

---

## 8. Responsive Behavior

### Breakpoints（CSS class 命名から推測）

| Name | Width | 説明 |
|------|-------|------|
| Mobile | ≤ 767px | スマートフォン |
| Tablet | 768〜1024px | iPad |
| Desktop | > 1024px | デスクトップ |

CSS には `pl-2-tablet`, `textsize-articlebody-tablet`, `radius-small-bottom-left` のような **タブレット専用 utility クラス** が大量に定義されており、breakpoint ごとに細かく font-size と padding が切り替わる。

### モバイル時の調整

- カードグリッドは 1〜2 カラムに折り返し
- マーキー（流れるテロップ）はそのまま継続。スマホ幅でも続く
- TODO リスト等のオーバーレイは画面幅いっぱいに展開
- フォントサイズは PC 時の 80〜90% 程度に縮小

### タッチターゲット

- pill CTA は最小 44px の高さを確保（padding 14.4px × 2 + line-height 14.4px = 43.2px なので、実装ではプラス 1〜2px の余裕あり）

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Brand: POPEYE Web (マガジンハウス)
Primary Color: #343ec9 (POPEYE Blue)
Logo Accent: #ff9000 (orange)
Calendar Accent: #3affff (cyan)
Calendar BG: #002184 (dark navy)
Background: #ffffff
Text Body: #343ec9 (青文字が原則)
Text Inverse: #ffffff (青背景時)
Font: "DM Sans", dnp-shuei-gothic-kin-std, sans-serif
Body Size: 14.4px
Body Line Height: 1.5 (21.6px)
Letter Spacing: 0.36px (≈0.025em)
font-feature-settings: "palt"
Font Weight: 400 (一律)
Border Radius: 24px (pill) / 5px (small) のみ。非対称適用
CTA: 白bg + 青text + 1px 青border + radius 24px
Asymmetric Card: radius 0px 5px 5px 0px 等で雑誌切り抜き風
```

### プロンプト例

```
POPEYE のデザインシステムに従って、新しい連載コラムのカード一覧ページを作成してください。
- フォント: "DM Sans", dnp-shuei-gothic-kin-std, sans-serif
- font-feature-settings: "palt"
- font-weight は 400 一本（太字を使わない）
- 本文・見出し・リンクの color は #343ec9 (POPEYE Blue)
- 背景は #ffffff
- カード見出しは border 1px solid #343ec9 + border-radius: 0px 5px 5px 0px (左上のみフラット)
- カテゴリタグ「ファッション」は border-radius: 5px 5px 0px 0px でカード上部に貼り付け
- CTA「もっと読む」は #ffffff bg + #343ec9 text + border 1px solid #343ec9 + border-radius: 24px (pill)
- 字間 letter-spacing: 0.36px、line-height: 1.5
- 影は使用禁止
```

### 字詰め・組版の重要ポイント

1. **font-weight 400 で全階層を組む**: 雑誌組版の流儀。太さに頼らず、サイズ・色・配置で階層を作る
2. **`#343ec9` の徹底**: 青文字をデフォルトにして、世界観を保つ
3. **非対称角丸**: `border-radius: 0px 5px 5px 0px` のように 4 隅を別々に指定。雑誌の切り抜きカット感
4. **palt 全適用**: 雑誌的な字詰め密度を Web で再現
5. **2 値の角丸トークン**: 24px (pill) と 5px (small) のみ。それ以外の中間値は使わない
6. **シアン #3affff はカレンダー・TODO 限定**: ブランド全体の補色アクセントとして節度を持って使用

---

**取得日**: 2026-05-08
**出典**: https://popeyemagazine.jp/
**抽出方法**: Headless Chrome (Puppeteer) による computed style 実測 + CSS Custom Properties 抽出
