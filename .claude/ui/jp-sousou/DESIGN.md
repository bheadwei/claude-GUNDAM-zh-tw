# DESIGN.md — SOU・SOU（そうそう）

> SOU・SOU（https://www.sousou.co.jp/）公式オンラインショップのデザイン仕様書。
> 「日本の伝統と現代の融合」をコンセプトに、地下足袋・テキスタイル・和装を現代的なグラフィックで再解釈する京都発のテキスタイルブランド。
> 実サイトの computed style 実測（2026-05-07 取得）に基づく。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 和紙のような **オフホワイト `#f5f5f5`** をキャンバスに、**Noto Serif JP（明朝体）で本文も見出しもすべて組む** という非常に珍しい選択。アクセントの **マスタード `#c1a443`（金茶色）** が伝統的な染め色や茶室を想起させる、**現代的に再構築された和の編集デザイン**
- **密度**: 商品カードと本文がゆったり配置され、letter-spacing を **0.08em（本文）〜 0.2em（h2）** と極端に開いて組む。**呼吸の長い、ゆったりとした和的編集組**
- **キーワード**: Noto Serif JP、明朝体ボディ、letter-spacing 大、マスタード金茶 #c1a443、オフホワイト #f5f5f5、ピル CTA、和の現代化
- **特徴**:
  - **本文も見出しも `--heading-font-family / --text-font-family` の両方が `"Noto Serif JP"` 単一指定** — Web フォントを明朝で組む決断
  - 補助フォントとして `--font-gothic: "Noto Sans JP"` も定義されているが、UI は基本的に明朝が主役
  - **CSS Custom Properties が 311 個**定義されており、Shopify Plus + theme system の典型的な完成度
  - **letter-spacing が極端に広い** — h2 は **5.6px (0.2em)** / h2 36px は **7.2px (0.2em)** / h1 22px は 1.76px (0.08em) / 本文 14-16px は 1.12-1.28px (0.08em)
  - CTA は **3 系統の角丸**を使い分け：黒塗りボタン（`5px`）、ピル形ナビ（`40.81px ≈ full pill`）、丸角アウトライン（`19px / 25px`）
  - ブランド色 **`#c1a443`（マスタード/金茶）** は CSS Custom Property `--color-accent` として定義 — 染め物・茶室・畳の和的な warm tone
  - エラー色 `#de2a2a`、成功色 `#2e9e7b`、リンク色 `#4181f2`（青）等のセマンティック色も完備
  - キャンペーン強調色 `#a91717`（朱赤、深紅）— 伝統的な日本の禁色を意識
  - ダークモード非対応

---

## 2. Color Palette & Roles

> 実サイトの computed style 実測値および CSS Custom Properties（`--color-*`）。すべて hex 表記。

### Brand

- **Accent (Mustard Gold)** (`#c1a443`): メインアクセント色（`--color-accent`）。47 回出現、ブランド識別の最重要色。和の染め色「黄丹（おうたん）」を想起
- **Campaign Red** (`#a91717`): キャンペーンラベル「送料無料キャンペーン中」等の強調赤（深紅・朱に近い）

### Surface

- **Page Background** (`#f5f5f5`): ページ全体のオフホワイト（67 回出現、最頻）。和紙・生成りの色味
- **Section Alt** (`#e8e8e8`): 補助セクション背景
- **Surface White** (`#ffffff`): カード・モーダル等の純白面（`--bg-color-common`）
- **Footer Dark** (`#4b4b4b`): フッター・ダーク背景
- **CTA Black** (`#000000`): 「今日のブログを読む」黒塗りボタン（強い CTA）
- **Sub Header Dark** (`#222426`): ストックエリアのサブヘッダー（`--bg-color-stock-area-sub-header`、α 0.79）

### Text

- **Heading Color** (`#222222`): 見出し（`--heading-color: 34, 34, 34`）
- **Text Primary** (`#222222`): 本文（`--text-color: 34, 34, 34`）
- **Text Muted** (`#888888`): 補足・キャプション（`--color-subbed`）
- **Text on Search** (`#5c5c5c`): 検索欄テキスト（`--color-search`）
- **Search Placeholder** (`#929292`): 検索プレースホルダー（`--color-search-holder`）
- **Light Outline** (`#555555`): 「もっと見る」アウトラインボタンのテキスト

### Border

- **Border Default** (`#dedede`): 標準ボーダー（`--border-color: 222, 222, 222`）
- **Border Stronger** (`#a7a7a7`): 強めの境界（`--border-color-darker`）
- **Border Main** (`#dcdcdc`): メイン境界（`--color-main-border`）

### Semantic

- **Error / Danger** (`#de2a2a`): エラーテキスト・低在庫警告（`--error-color`）
- **Delete Border** (`#c72d3f`): 削除ボタンの境界線（`--delete-border-color`）
- **Delete Text** (`#e5354a`): 削除アクションのテキスト（`--delete-text-color`）
- **Success / In Stock** (`#2e9e7b`): 在庫あり・成功（`--success-color` / `--product-in-stock-text-color`）
- **Link / Reviews** (`#4181f2`): U-KOMI 等の外部リンク色

### Light BG / Pale

- **Pale Blue** (`#e1eaf2`): 補助 BG（`--color-bg-light`）
- **Payment** (`#d9d9d9`): 決済関連背景（`--color-payment`）

---

## 3. Typography Rules

### 3.1 和文フォント

SOU・SOU は **本文・見出しすべてを明朝体（Noto Serif JP）で統一**するという非常に珍しい選択をしている。

- **メイン（明朝）**: **Noto Serif JP（Google Fonts / 砧書体制作所）** — Web 配信される明朝体の代表格。SOU・SOU は本文・見出しの両方をこれで組む
- **補助（ゴシック）**: **Noto Sans JP**（`--font-gothic` として定義、UI フォーム等で限定使用）
- **フォールバック**: serif（システム明朝）

### 3.2 欧文フォント

- 専用欧文書体の指定なし。**Noto Serif JP の欧文グリフ**を使用

### 3.3 font-family 指定

実サイトの実測値（**body / 全見出し / a / p すべて同一**）:

```css
/* CSS Custom Properties */
--heading-font-family: "Noto Serif JP", "Noto Serif Japanese", serif;
--text-font-family: "Noto Serif JP", "Noto Serif Japanese", serif;
--font-gothic: "Noto Sans JP", sans-serif;

/* 実適用 */
font-family: "Noto Serif JP", "Noto Serif Japanese", serif;
```

**フォールバックの考え方**:
- **明朝統一が SOU・SOU の核**。Sans でフォールバックさせない（`serif` 終端で必ず明朝系）
- ゴシックを使うのはフォーム・小さな UI ラベルだけに限定
- AI で再現する場合は **Google Fonts の "Noto Serif JP"** を読み込み、フォールバックを `serif` で締める

### 3.4 文字サイズ・ウェイト階層

> 実測値（トップページ、2026-05-07 取得）

| Role | Size | Weight | Line Height | Letter Spacing | Color | 備考 |
|------|------|--------|-------------|----------------|-------|------|
| Hero h2 (Display) | **36px** | **400** | 54px (×1.5) | **7.2px (+0.2em)** | `#222222` | "SOU・SOU\nについて" |
| Section h2 | **28px** | **400** | 42px (×1.5) | **5.6px (+0.2em)** | `#222222` | "お知らせ" |
| Banner h2 (on dark) | 26.6px | 400 | 37.24px (×1.4) | 2.128px (+0.08em) | `#ffffff` | "夏の新作和装" |
| Lead p | 24px | 400 | 31.2px (×1.3) | 1.92px (+0.08em) | `#000000` | "5.15(金)まで" |
| Section h3 | 22px | 400 | 39.6px (×1.8) | 1.76px (+0.08em) | `#222222` | "衣類" |
| Banner h3 (on dark) | 22px | 400 | 38.13px (×1.73) | normal | `#ffffff` | "送料／関税 無料キャンペーン" |
| Page h1 | 22px | 400 | 17px (×0.77) | 1.76px (+0.08em) | `#222222` | "SOU・SOUのブログ"（極端なタイト lh） |
| Banner Logo a | 32px | 700 | 55.47px (×1.73) | normal | `#ffffff` | "SOU・SOU netshop" ヒーローロゴ |
| Body | 16px | 400 | 27.73px (×1.733) | normal | `#222222` | 本文段落（Noto Serif JP） |
| Banner Body p | 15px | 400 | 27px (×1.8) | 1.2px (+0.08em) | `#ffffff` | "日本の気候に寄り添った素材..." |
| Sub h3 | 15px | 400 | 22.5px (×1.5) | 1.2px (+0.08em) | `#222222` | "【お詫び】..." |
| Article p | 14px | 400 | 25.2px (×1.8) | 1.12px (+0.08em) | `#222222` | 記事本文 |
| Campaign Bold | 17px | **500** | 17px (×1.0) | 1.7px (+0.1em) | `#a91717` (赤) | "送料無料キャンペーン中" |
| Campaign Date | 17px | 500 | 17px (×1.0) | 1.7px (+0.1em) | `#222222` | "5.15 (金)まで" |
| Campaign Caption | 14px | 400 | 14px (×1.0) | 1.7px (+0.12em) | `#888888` | "¥5,000以上(海外は¥10,000以上)..." |
| Nav Pill Link | 16px | 400 | 16px (×1.0) | 1.28px (+0.08em) | `#222222` | "トップページ" / "新商品" |

### 3.5 行間・字間

- **本文の行間**: **1.733（≈ 1.7）**（27.73 / 16）— Noto Serif JP の可読性を保つ広めの行間
- **記事本文の行間**: **1.8**（25.2 / 14）— さらに広い
- **見出しの行間**: **1.5**（42 / 28, 54 / 36）
- **letter-spacing は SOU・SOU の最大の特徴 — 全要素で広く取る**:
  - 大型見出し（h2 28〜36px）: **+0.2em（5.6〜7.2px）** — 極端に広い
  - 中型見出し（h1 22px / h3 22px）: **+0.08em（1.76px）**
  - 本文（14〜16px）: **+0.08em（1.12〜1.28px）** または normal（場所により）
  - キャンペーン強調（17px 太字）: **+0.1em（1.7px）**

**ガイドライン**:
- **letter-spacing を必ず開く**（特に見出しは 0.08em 以上、大型見出しは 0.2em）— SOU・SOU の和的・編集的な「呼吸」の源
- 本文も基本的に 0.08em 開く（normal も場面により可）
- 行間は欧文寄りに少し緩めの 1.7〜1.8（明朝体の可読性確保）
- 大型見出しでは行間を 1.5、極端なタイトを使う場合は h1 のように 0.77 まで詰める例外もあり

### 3.6 禁則処理・改行ルール

```css
word-break: normal;
overflow-wrap: break-word;
line-break: strict;
```

- 商品名・カテゴリ名は短く、`<br>` を手動配置する例が多い（"SOU・SOU\nについて"）
- 中黒「・」（U+30FB）の前後で letter-spacing が見栄えよくスペースを作る

### 3.7 OpenType 機能

```css
font-feature-settings: normal;
```

- **palt は使用していない** — 明朝体の固定幅字形を活かしたいため、palt で詰めない
- letter-spacing で組み広げているため、palt と組み合わせると意図が崩れる
- **AI 再現時も palt は使わない**（letter-spacing のみで字間を制御）

### 3.8 縦書き

- 該当なし（横書きのみ）。ただし伝統的な和的トーンに合わせて、装飾としての縦書きラベルを部分的に使う余地あり

---

## 4. Component Stylings

### Buttons

SOU・SOU は **3 系統の角丸**を使い分けて意味を伝える。

**Primary CTA（"今日のブログを読む"）— 黒塗りボタン**
- Background: `#000000`
- Text: `#ffffff`
- Padding: `10px 30px`
- Border Radius: **`5px`**（軽い丸み）
- Font: 16px / weight 400 / "Noto Serif JP" / letter-spacing normal
- 強い CTA に使用

**Pill Nav（"トップページ" / "新商品"）— ピル形ナビゲーション**
- Background: `transparent`
- Text: `#222222`
- Border: `1px solid #dedede`（推奨）
- Padding: `15px 20px`
- Border Radius: **`40.81px`**（full pill）
- Font: 16px / weight 400 / line-height 1.0 / letter-spacing 1.28px (+0.08em)
- カテゴリ・ナビ用

**Rounded Outline（"全て見る"）— 大きめの丸角アウトライン**
- Background: `transparent`
- Text: `#222222`
- Border: `1px solid #dcdcdc`（推奨）
- Padding: `19px 20px`
- Border Radius: **`25px`**
- Font: 16px / weight 400 / letter-spacing normal

**Rounded Secondary（"もっと見る"）— 小さめの丸角アウトライン**
- Background: `#ffffff`
- Text: `#555555`
- Border: `1px solid #dedede`
- Padding: `10px 20px`
- Border Radius: **`19px`**
- Font: 14px / weight 400

**External Link CTA（"U-KOMIの詳細はこちら"）— 青塗り**
- Background: `#4181f2`
- Text: `#ffffff`
- Padding: `15px 35–40px`
- Border Radius: `5px`
- Font: 16px / weight 400

**Form Submit（"登録"）— グレー塗り**
- Background: `#888888`
- Text: `#ffffff`
- Padding: `0 5px`（高さは入力欄に追従）
- Border Radius: `3px`
- Font: 16px / weight 400

### Inputs

- Background: `#ffffff`
- Border: `1px solid #dedede`（`--border-color`）
- Border (focus): `1px solid #c1a443`（accent / 推奨）
- Border (error): `1px solid #de2a2a`
- Border Radius: `3〜5px`
- Padding: `8〜12px`
- Font: 13〜16px / weight 400 / "Noto Serif JP"（または UI 限定で Noto Sans JP）
- Color: `#000000` / placeholder `#929292`

### Search Input

- Background: `#ffffff`
- Color: `#5c5c5c`（`--color-search`）
- Placeholder: `#929292`
- Font: 14px / weight 400

### Cards / Product Tiles

- Background: `#ffffff`
- Border: なし or `1px solid #dedede`
- Border Radius: `0px`（写真の四角を尊重）
- Padding: 写真直下にメタ領域 12〜16px
- Shadow: なし（フラット）
- 構造: 商品写真 → 商品名（22px / "Noto Serif JP"）→ 価格（14px）
- ホバー: 写真 opacity 0.85 等

### Banner Section（"夏の新作和装"）

- Background: 写真または `#222426`（暗色）
- Heading 26.6〜36px / weight 400 / `#ffffff`
- Body 15px / weight 400 / line-height 1.8 / letter-spacing 1.2px
- 「全て見る」CTA は丸角 25px のアウトライン

### Header / Nav

- Background: `#ffffff`
- Color: `#222222`
- Padding: `16px 24px`
- Logo "SOU・SOU netshop" 中央、検索・カート右
- グローバルナビは下段にピル形（radius 40.81px）で配置

### Footer

- Background: `#4b4b4b` または `#f5f5f5`
- Color: `#ffffff` または `#222222`
- Padding: `48px 24px 24px`
- フッターリンク: 14〜16px / weight 400 / "Noto Serif JP"

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
| XXL | 80px | セクション間 |

### Container

- Max Width: 1280px（推奨）
- Padding (horizontal): mobile 16px / desktop 24〜32px

### Grid

- 商品グリッド: 2 カラム（mobile）→ 3 カラム（tablet）→ 4 カラム（desktop）
- Gutter: 16〜24px

### Border Radius Scale

SOU・SOU は **複数の角丸を意図的に使い分ける**:

| Token | Value | 用途 |
|-------|-------|------|
| Sharp | 0px | カード・写真・コンテンツ領域 |
| Soft | 3px | フォーム送信ボタン |
| Subtle | 5px | 黒塗り CTA・青塗り CTA |
| Rounded | 19px | 小さめのアウトラインボタン |
| Pill Soft | 25px | 「全て見る」等の中サイズアウトライン |
| Pill Full | 40.81px | カテゴリナビ（full pill） |
| Circle | 100% | カラースウォッチ・アイコン |

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | `none` | カード・写真・パネル（基本フラット） |
| 1 | `0 2px 8px rgba(34, 34, 34, 0.06)` | 薄いカード・ホバー（推奨） |
| 2 | `0 4px 16px rgba(34, 34, 34, 0.1)` | モーダル・ドロップダウン（推奨） |

- SOU・SOU は**影をほぼ使わない**和的フラット表現。明朝体のクリアさを邪魔しない
- カードは基本フラット、ホバー時のみ薄い影を出す

---

## 7. Do's and Don'ts

### Do（推奨）

- **本文・見出しすべてを `"Noto Serif JP"` で組む** — SOU・SOU の最大の identity
- **letter-spacing を必ず開く**:
  - 大型見出し（28〜36px）: **0.2em（5.6〜7.2px）**
  - 中型見出し（22px）: **0.08em（1.76px）**
  - 本文（14〜16px）: **0.08em（1.12〜1.28px）** または normal
- **アクセント色は `#c1a443`（マスタード/金茶）** を `--color-accent` として使用
- **ページ背景は `#f5f5f5`**（純白でなく和紙風オフホワイト）
- **3 種類の角丸を使い分ける**: 0px（コンテンツ）/ 5px（黒塗り CTA）/ 25–40px（ピル）/ 19px（サブ）
- **本文 line-height は 1.7〜1.8** — 明朝の可読性を確保
- キャンペーン強調は **`#a91717`（深紅）** で和の伝統色を意識
- 影は最小限、フラット原則
- ピル形ナビ（radius 40.81px）でカテゴリを表現

### Don't（禁止）

- 見出し・本文を sans-serif（Noto Sans JP 等）で組まない（明朝統一が崩れる）
- letter-spacing を normal だけで組まない（特に大型見出し）
- 純白 `#ffffff` をページ背景に使わない（オフホワイト `#f5f5f5` を厳守）
- 角丸を 1 種類だけに統一しない（意味によって使い分ける）
- palt を使わない（letter-spacing で字間を制御するため、組み合わせると崩れる）
- 強いシャドウやグラデーションを使わない
- カラフルなアクセントを多用しない（マスタード金茶 + 深紅 + ニュートラル基調を保つ）
- 行間を 1.5 未満にしない（明朝の可読性が落ちる、h1 の例外を除く）

---

## 8. Responsive Behavior

### Breakpoints

| Name | Width | 説明 |
|------|-------|------|
| Mobile | ≤ 768px | スマホ |
| Tablet | 769–1024px | タブレット |
| Desktop | > 1024px | デスクトップ |

### モバイル時の調整

- Hero h2: 36px → 24〜28px（letter-spacing 0.2em は維持）
- Section h2: 28px → 22〜24px
- Body: 16px 維持（縮小しない）
- ナビは drawer ハンバーガーへ切り替え
- 商品グリッド 4 → 2 → 1 カラム
- ピル CTA は左右パディングを `15px 20px` から `12px 16px` へ縮小

### タッチターゲット

- 最小 44×44px。ピルボタン（radius 40.81px）は padding `15px 20px` で十分なヒット領域

### ダークモード

- 該当なし。常時ライトモード

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Background: #f5f5f5（オフホワイト、和紙色）
Surface: #ffffff
Heading / Text: #222222
Text Muted: #888888
Search Text: #5c5c5c
Border: #dedede
Accent: #c1a443（マスタード/金茶、--color-accent）
Campaign Red: #a91717（深紅）
Error: #de2a2a / Success: #2e9e7b / Link: #4181f2

Font (本文・見出し共通): "Noto Serif JP", "Noto Serif Japanese", serif
Web Loader: <link href="https://fonts.googleapis.com/css2?family=Noto+Serif+JP:wght@400;500;700&display=swap" rel="stylesheet">
Gothic Alt (UI 限定): "Noto Sans JP", sans-serif

Hero h2 (Display): 36px / weight 400 / line-height 1.5 / letter-spacing 7.2px (+0.2em)
Section h2: 28px / weight 400 / line-height 1.5 / letter-spacing 5.6px (+0.2em)
Section h3: 22px / weight 400 / line-height 1.8 / letter-spacing 1.76px (+0.08em)
Lead: 24px / weight 400 / line-height 1.3 / letter-spacing 1.92px
Body: 16px / weight 400 / line-height 1.733 / letter-spacing normal or +0.08em
Article p: 14px / weight 400 / line-height 1.8 / letter-spacing 1.12px (+0.08em)
Campaign Bold: 17px / weight 500 / letter-spacing 1.7px / color #a91717

Border Radius: 0px (cards) / 5px (black CTA) / 19-25px (rounded outline) / 40.81px (pill nav)
Shadow: none（基本フラット、ホバー時のみ薄い影）
font-feature-settings: normal（palt 適用なし）
letter-spacing: 0.08em〜0.2em（必ず開く）
```

### プロンプト例

```
SOU・SOU のデザインに従って、商品一覧ページを作成してください。
- 背景: #f5f5f5（純白でなく和紙風オフホワイト）
- フォント: "Noto Serif JP", "Noto Serif Japanese", serif（本文・見出し共通の明朝統一）
  Google Fonts: Noto Serif JP weight 400 / 500 / 700 をロード
- letter-spacing を必ず開く:
  - h2 (28px): letter-spacing 5.6px（+0.2em）/ line-height 1.5
  - h2 (36px): letter-spacing 7.2px（+0.2em）/ line-height 1.5
  - h3 (22px): letter-spacing 1.76px（+0.08em）/ line-height 1.8
  - 本文 (16px): line-height 1.733 / letter-spacing normal or 1.28px (+0.08em)
  - 記事本文 (14px): line-height 1.8 / letter-spacing 1.12px
- カラーパレット:
  - 見出し・本文: #222222
  - 補足: #888888
  - アクセント: #c1a443（マスタード金茶）
  - キャンペーン強調: #a91717（深紅）
  - エラー: #de2a2a / 成功: #2e9e7b
  - 純白サーフェス: #ffffff
- 商品カード: 写真直置き、border-radius 0、影なし、商品名 22px / line-height 1.8 / letter-spacing 1.76px
- カテゴリナビ: ピル形（border-radius 40.81px）/ 透明背景 / #222 文字 / padding 15px 20px / letter-spacing 1.28px
- 強い CTA「カートに追加」: 黒塗り #000 / 白文字 / border-radius 5px / padding 10px 30px
- 「もっと見る」: 白塗り / #555 文字 / border 1px solid #dedede / border-radius 19px / padding 10px 20px
- 「全て見る」: 透明 / #222 文字 / border 1px solid #dcdcdc / border-radius 25px / padding 19px 20px
- 入力欄: border 1px solid #dedede / border-radius 3-5px / focus border #c1a443
- font-feature-settings: normal を維持（palt は使わない）
- 影は使わず、ホバー時のみ薄影 0 2px 8px rgba(34, 34, 34, 0.06)
```
