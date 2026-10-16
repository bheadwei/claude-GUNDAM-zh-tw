# DESIGN.md — BRUTUS（ブルータス）

> マガジンハウス『BRUTUS』Web 版（https://brutus.jp/）のデザイン仕様書。
> 1980 年創刊、男性向けカルチャー総合誌の Web 版。WordPress ベース、雑誌的タイポグラフィの典型例。
> 実サイトの computed style 実測（2026-05-07 取得）に基づく。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 純白背景 `#ffffff` × 漆黒文字 `#101010` のシャープなコントラスト。**和文「FOT-筑紫ゴシック Pro」+ 欧文「Futura PT」の二系統混植**で、雑誌特有の知的でモダンな印象を作る
- **密度**: コンテンツ密度は高め。特集記事のサムネイルと文字情報を碁盤目状に並べる、**雑誌グリッド型レイアウト**
- **キーワード**: 筑紫ゴシック B/E/H の重厚な見出し、Futura PT の幾何学的欧文、特集ごとのカテゴリカラー、純白基調 + 漆黒テキスト、palt 不使用、letter-spacing normal、line-height 1.5
- **特徴**:
  - **2 系統フォント運用** — 和文には「FOT-筑紫ゴシック Pro」を Bold(B) / Extra Bold(E) / Heavy(H) で使い分け、欧文には「futura-pt」を 400/600 で使用
  - **筑紫ゴシック Heavy (Pro H)** を見出しに使い、雑誌特有の**重厚感ある見出し組**を実現。一般的な丸ゴシック系（ヒラギノ・游ゴシック）とは異なる、フォントワークス独特のクセ
  - **palt は使わない** — 字間調整は letter-spacing normal が基本。WordPress のデフォルト組版に近い
  - **line-height は 1.5（27px / 18px）** — note の 2.0 と比べてかなりタイトな雑誌的行送り
  - **本文 18px** — 雑誌記事として読み込ませる十分なサイズ
  - **WordPress のプリセットを大量に保持** — 124 個もの `--wp--preset--*` 変数。実際の運用色は限定的
  - **特集ごとのカテゴリカラー** — `#577590`（青灰）/ `#00c6ac`（ターコイズ）/ `#5fb7ff`（水色）/ `#ab9a86`（ベージュ）/ `#275ba1`（紺）/ `#b87333`（銅）/ `#e63946`（赤）など、特集ジャンルごとに彩りある面色を切り替える
  - **暗色帯セクション**は `#191919`（ほぼ黒）で組み、白文字 + Futura で英字タイトルを大きく出す
  - **小さい英字キャプション**は Futura PT の `600 weight` 13px で、和文の上に「WATCHES／時計」のように対訳を載せる雑誌定番レイアウト
  - **Adobe Fonts (futura-pt) と FOT (筑紫ゴシック)** の組み合わせは商用ライセンスの範囲内でしか再現不可。preview.html では Google Fonts の Futura 代替と Noto Sans JP を使用

---

## 2. Color Palette & Roles

> 実サイトの computed style 実測値。すべて hex 表記。

### Brand

- **Brutus Ink** (`#101010`): 本文の基本色（rgb(16, 16, 16)）。純黒ではなく、わずかに浮いた漆黒
- **Brutus Charcoal** (`#191919`): 暗色帯セクションの背景（rgb(25, 25, 25)）。ヘッダー・特集タイトル帯
- **Page White** (`#ffffff`): ページ背景の純白

### Surface（背景）

- **Page Background** (`#ffffff`): 純白
- **Section Light** (`#eaeaea`): セクション間の薄いグレー区切り（rgb(234, 234, 234)）
- **Magazine Beige** (`#e2dfd7`): 「RECOMMEND ／ 注目のコンテンツ」などの上品なベージュ系の背景（rgb(226, 223, 215)）
- **Soft Cream** (`#f4f3ef`): 「WHAT'S NEW ／ 新着記事」のクリーム系背景（rgb(244, 243, 239)）
- **Footer Slate** (`#394045`): フッター帯（rgb(57, 64, 69)）
- **Dark Charcoal** (`#212729`): 言語切替メニュー（rgb(33, 39, 41)）
- **Footer Ink** (`#2e2e2e`): 「配信停止」等の控えめなフッター帯（rgb(46, 46, 46)）

### Text / Foreground

- **Text Primary** (`#101010`): 本文・基本見出し
- **Text Inverse** (`#ffffff`): 暗色帯上のテキスト
- **Text Magazine** (`#191919`): カテゴリ見出し等の濃い黒
- **Text Muted** (`#939393`): 補助テキスト

### Category Colors（特集カテゴリ別の面色）

これが BRUTUS の最大の特徴。**特集ジャンルごとに彩り豊かな面色を切り替える**：

- **Slate Blue** (`#577590`): 主力カテゴリ（出現頻度トップ）
- **Turquoise** (`#00c6ac`): カルチャー・アート系
- **Sky Blue** (`#5fb7ff`): ライフスタイル系
- **Magazine Beige** (`#ab9a86`): クラフト・伝統工芸
- **Deep Navy** (`#275ba1`): ビジネス・旅
- **Copper** (`#b87333`): フード・ドリンク
- **Tomato Red** (`#e63946`): 限定特集・速報
- **Charcoal** (`#191919`): "WATCHES／時計" のような時計・ジュエリー系の重厚カテゴリ
- **Sand** (`#bda295`): 二次的カテゴリ

### Border / Divider

- 罫線は基本的に出さず、面色の切り替えで分節する
- どうしても必要な場合は `1px solid #eaeaea`

### Accent / Semantic

- **エラー・成功・警告色は標準を持たない** — 雑誌コンテンツが主体のため UI 系セマンティック色は希薄
- 補完する場合は Tomato Red `#e63946` をエラー、Turquoise `#00c6ac` を成功として運用可能

---

## 3. Typography Rules

### 3.1 和文フォント

BRUTUS は **Fontworks の「FOT-筑紫ゴシック Pro」を 3 ウェイト Web フォントとして配信**している。雑誌組版の本格的な書体選択。

- **FOT-筑紫ゴシック Pro B**（Bold）: 本文・ナビ・リンク
- **FOT-筑紫ゴシック Pro E**（Extra Bold）: 中見出し・小見出し（h3 / h4）
- **FOT-筑紫ゴシック Pro H**（Heavy）: 大見出し（h2 / 特集タイトル）
- **フォールバック**: `sans-serif`（明示的な和文フォント名は **置かない**）

### 3.2 欧文フォント

欧文は完全に**別系統**で運用：

- **futura-pt**（Adobe Fonts）: 日付・カテゴリラベル・英字タイトル
- **ウェイト**: 400（Regular）/ 600（Demi Bold）
- **フォールバック**: `sans-serif`

### 3.3 font-family 指定

実サイトの実測値。**用途別に和文・欧文が完全に分かれる**点が BRUTUS の特徴：

```css
/* 和文・本文（h1, body, a, button のデフォルト） */
font-family: "FOT-筑紫ゴシック Pro B", sans-serif;

/* 和文・中見出し（h3, h4, 強調 p） */
font-family: "FOT-筑紫ゴシック Pro E", sans-serif;

/* 和文・大見出し（h2, 特集タイトル） */
font-family: "FOT-筑紫ゴシック Pro H", sans-serif;

/* 欧文・日付/カテゴリ/英字タイトル */
font-family: futura-pt, sans-serif;
```

**注意**: 和文要素のフォールバックに「ヒラギノ」「游ゴシック」を含めない。**WebFont 未読込時は OS の sans-serif にそのまま落とす**思い切った設計。`@font-face` の読み込みを最優先する。

### 3.4 font-size

実測のサイズスケール（PC 1440px ビュー）：

| 用途 | サイズ | フォント | 用例 |
|------|--------|----------|------|
| H2（特集大見出し） | `24px` | 筑紫ゴシック H / w800 | "WATCHES" |
| H4（記事見出し） | `19px` | 筑紫ゴシック E / w700 | 強調された見出し |
| H4（小見出し） | `16px` | 筑紫ゴシック E / w700 | 一般的な小見出し |
| Body / Lead | `18px` | 筑紫ゴシック B / w400 | 本文・記事 |
| 英字大タイトル | `19px` | futura-pt / w800 | カテゴリ和文の上の英字 |
| Nav / リンク | `14px` | futura-pt / w400 | 欧文ナビ |
| H3 / 小見出し | `14px` | 筑紫ゴシック E / w700 | カードタイトル |
| キャプション | `13px` | futura-pt / w600 | 日付・タグ |
| 注釈 / メタ | `12px` | 筑紫ゴシック B / w400 | 細かいメタ情報 |

### 3.5 line-height

実測値（比率に換算）：

- **Body 18px**: `1.50`（27px / 18px）— 雑誌的なタイトな行送り
- **H2 24px**: `1.50`（36px / 24px）
- **H3 14px**: `1.43`（20px / 14px）
- **強調 p 19px**: `1.47`（27.93px / 19px）
- **Body 14px (小)**: `1.50`（21px / 14px）
- **Caption 12px**: `1.0`（12px / 12px）— キャプションは詰める

### 3.6 letter-spacing

**基本は `normal`**（letter-spacing 指定なし）。WordPress デフォルト組版を踏襲し、和文も欧文も自然な字送りに任せる。

- 全要素ほぼ `normal`
- 大きい英字タイトル（Futura）にだけ気持ち広げる程度

### 3.7 font-feature-settings

**palt は使わない**（実測で確認）。**約物の余分な空きをそのまま残す**雑誌的組版。Mazda や PARCO の `palt: ON` とは対照的。

### 3.8 ウェイト戦略

和文は3ウェイト、欧文は2ウェイトで運用：

| 用途 | フォント | ウェイト |
|------|----------|----------|
| 本文 | FOT-筑紫ゴシック Pro B | `400` |
| 中見出し | FOT-筑紫ゴシック Pro E | `700` |
| 大見出し | FOT-筑紫ゴシック Pro H | `800` |
| 欧文ラベル | futura-pt | `400` / `600` |

**注意**: 和文の Bold (Pro B) は **font-weight 400** で運用される。これは Pro B 自体がすでに Bold 寄りの太さを持っているため。CSS の `font-weight` ではなく、**ファミリ名の B/E/H で太さが決まる**。

---

## 4. Component Stylings

### 4.1 ボタン（記事リンク）

```css
font-family: "FOT-筑紫ゴシック Pro B", sans-serif;
font-size: 18px;
font-weight: 400;
line-height: 27px;
color: #101010;
background-color: transparent;
border: none;
text-decoration: none;
```

- ボタンらしい矩形枠は持たず、**テキストリンク主体**
- 必要な場合は親要素のカード全体をクリッカブルにする

### 4.2 暗色 CTA（暗色帯上の白文字）

```css
font-family: "FOT-筑紫ゴシック Pro B", sans-serif;
font-size: 18px;
font-weight: 400;
color: #ffffff;
background-color: #191919;
padding: 16px 24px;
```

- 漆黒帯 `#191919` の中で白文字
- 雑誌のキャプション風

### 4.3 カテゴリラベル（バッジ）

```css
/* 暗色帯の中の英字カテゴリ */
font-family: futura-pt, sans-serif;
font-size: 14px;
font-weight: 600;
color: #ffffff;
background: #577590; /* カテゴリ別 */
padding: 4px 12px;
letter-spacing: 0.04em;
text-transform: uppercase;
```

- 特集ジャンルに応じて bg を切り替える（Section 2 のカテゴリカラー参照）
- text-transform は uppercase が基本
- Futura PT で英字を組む

### 4.4 カード（記事サムネイル）

- 写真（4:3 または 16:9）+ タイトル + 日付・カテゴリ
- 影なし、罫線なし、**画像と文字情報の縦配置のみ**
- 周囲の余白だけで区切る
- カードタイトル: 筑紫ゴシック E、14〜16px、weight 700

### 4.5 雑誌セクションヘッダー（英字＋和文）

```html
<div class="section-header">
  <span class="en">WHAT'S NEW</span>
  <span class="ja">新着記事</span>
</div>
```

```css
.section-header .en {
  font-family: futura-pt, sans-serif;
  font-size: 19px; font-weight: 800;
  color: #191919;
  text-transform: uppercase;
}
.section-header .ja {
  font-family: "FOT-筑紫ゴシック Pro H", sans-serif;
  font-size: 24px; font-weight: 800;
  color: #191919;
  margin-left: 12px;
}
```

これが BRUTUS のシグネチャ。**英字大文字（Futura）+ 和文重厚見出し（筑紫 H）**を並べる雑誌定番。

### 4.6 フォーム

- フォームは検索ボックス・メール購読程度。専用デザインは控えめ
- 入力欄: `1px solid #eaeaea` 矩形、`border-radius: 0`
- 送信ボタン: 漆黒帯 `#191919` + 白文字

---

## 5. Layout Principles

- **コンテナ最大幅**: 1280〜1440px（雑誌的な広めのワイド）
- **グリッド**: 12 カラム。記事サムネイルは 3〜4 カラム配置が基本
- **セクション間余白**: 中庸（48〜80px）
- **背景色を切り替えてセクションを区切る** — `#ffffff` / `#eaeaea` / `#e2dfd7` / `#f4f3ef` を交互に
- 見出しは**左揃え**が基本
- 画像は 4:3 または 16:9。記事サムネイルは 4:3 が主流
- **特集カテゴリページでは大胆にカテゴリカラーで全幅塗り**することがある

---

## 6. Depth & Elevation

- **影は使わない**（box-shadow は基本 none）
- カードや UI 要素のレベル差は **面色の違い**で表現
- 暗色帯セクション `#191919` は強い視覚的アクセントとして機能
- ホバー状態は背景色 / 透明度の微変化で表現

---

## 7. Do's and Don'ts

### ✅ Do
- **FOT-筑紫ゴシック Pro B/E/H と futura-pt を併用**する
- 和文要素のフォールバックは `sans-serif` のみ — ヒラギノ・游ゴシックを置かない
- **palt は使わない** — letter-spacing normal が基本
- 本文 line-height は **1.5** に設定（雑誌的なタイト感）
- 大見出しは英字（Futura）+ 和文（筑紫 H）の対訳組み
- 特集ごとに **カテゴリカラーで彩りを変える**
- 漆黒帯 `#191919` を強いアクセントとして使う

### ❌ Don't
- ヒラギノ角ゴシック / 游ゴシック / メイリオで代用しない（デザインの大事な部分が失われる）
- letter-spacing を本文に与えない（雑誌の自然な字送りを保つ）
- line-height を 1.7 以上に広げない（雑誌密度を保つ）
- カードに角丸・影を付けない
- 単一の単色アクセントで全特集を統一しない（カテゴリ色の多様性を失う）

---

## 8. Responsive Behavior

- **PC 1440px** をベース幅とする
- **タブレット（〜1024px）**: 4 カラム → 2 カラム、本文 16〜17px
- **モバイル（〜768px）**: 1 カラム、本文 15〜16px、H2 18〜20px
- letter-spacing は normal を維持
- 特集カテゴリカラーはモバイルでも保つ

---

## 9. Agent Prompt Guide

> AI エージェントに BRUTUS 風 UI を生成させる際のプロンプト。

```
Generate a Japanese magazine-style UI in the BRUTUS visual style.

Visual:
- Pure white background (#ffffff) with sharp ink text (#101010)
- Magazine grid layout with section-color background switches
- letter-spacing: normal globally (NO palt, NO custom kerning)
- line-height: 1.5 for body (tight, magazine-like)
- Strong charcoal accent bands (#191919) with white text + Futura uppercase

Typography:
- Japanese: "FOT-筑紫ゴシック Pro B" (body), "Pro E" (subheadings), "Pro H" (large headings)
- English: futura-pt (Adobe Fonts), weights 400 / 600 / 800
- Body: 18px / line-height 1.5 / letter-spacing normal / weight 400
- H2: 24px / weight 800 / Pro H
- H4: 16px / weight 700 / Pro E
- Captions: 13px / Futura PT / weight 600

Components:
- Cards: image + title + date, no shadow, no border, no radius
- Section headers: English uppercase (Futura PT 800) + Japanese (Pro H 800) side-by-side
- Category badges: Futura PT 600 / 14px on category-colored bg

Color Strategy (category palette):
- Slate Blue #577590 (primary)
- Turquoise #00c6ac (culture)
- Sky Blue #5fb7ff (lifestyle)
- Magazine Beige #ab9a86 (craft)
- Deep Navy #275ba1 (business/travel)
- Copper #b87333 (food)
- Tomato Red #e63946 (special)
- Charcoal #191919 (watches/jewelry)

Avoid:
- Hiragino / Yu Gothic in font fallback (use sans-serif only)
- palt (no Japanese kerning adjustment)
- line-height 2.0 (too loose for magazine density)
- Single brand color (preserve category color diversity)
- Box shadows or rounded corners on cards
```
