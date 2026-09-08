# Design System Inspired by Semrush

## 1. Visual Theme & Atmosphere

Semrush is a digital-marketing intelligence platform, and its product design system — published publicly as **Intergalactic** — is built around one premise that separates it from almost every other SaaS design language: **the screen's job is to fit as much decision-grade data as possible into one viewport.** A marketer opening a Domain Overview or Position Tracking report expects to see dozens of KPIs, a keyword table hundreds of rows deep, a trend chart, a competitor comparison, and several layers of filters — all without scrolling to hunt for them. Where Linear, Apple, or Notion treat whitespace as the primary expressive tool, Semrush treats **information adjacency** as the primary tool: the number, the delta, the sparkline, and the filter that produced them all sit within a few pixels of each other, because comparison is the actual task.

The consequence is a system built on a **4px base denominator** (`scale-indent: 4px`) rather than the usual 8px. Every spacing decision is available at half the granularity of a typical system, which is exactly what a dense dashboard needs: table cells at 12px padding, compact cells at 8px, control heights at 20/28/40px. Type starts at **10px** and the workhorse body/table size is **14px**, with 12px carrying labels, axis ticks, and metric captions. Radii stay tight (2–6px for nearly everything) so that dozens of adjacent surfaces don't visually bloat into each other.

Chromatically it is a **neutral gray canvas with an orange-and-blue division of labor**. Pure white (`#ffffff`) is the data surface; a cool near-white (`#f4f5f9`) is the chrome and table-header surface; the gray ladder runs nine steps to a near-black ink (`#191b23`). On top of that neutral base, **Semrush Orange (`#ff642d`)** is reserved almost exclusively for brand-level commitment — the primary "start/upgrade" control and the brand mark — while **blue (`#008ff8` for controls, `#006dca` for links and text)** carries all ordinary interactive weight: buttons, links, selected rows, focus rings. This split is the system's most important rule: orange means *this is the one action that matters*, blue means *this is interactive*. Because orange is rationed, it survives being placed on a screen with forty other elements. A deep dusty violet (`#382E5E` header, `#421983` advertising-product accent) marks the global app chrome and the paid-media product family, giving the shell a darker frame around the bright data surface.

Typography pairs **Factor A** (the Semrush brand display face, used for marketing headlines and the logotype) with **Inter** as the documented base font of the product UI. Inter here is a deliberate, documented choice rather than a default: at 10–14px in a table of a thousand cells, its tall x-height and tabular figures are doing measurable work.

**Key Characteristics:**
- **Density is the first principle** — one screen is expected to carry many KPIs, a deep table, a chart, and multi-level filters simultaneously
- **4px base unit** (not 8px) — half-step granularity exists specifically to make dense layouts tunable
- Type scale bottoms out at **10px**, with **14px as the body/table default** and **12px** for labels, axis ticks, and metric captions
- **Orange (`#ff642d`) is rationed to brand-primary actions**; **blue (`#008ff8` / `#006dca`) carries all ordinary interactivity** — the two never compete
- Nine-step cool gray ladder (`#f4f5f9` → `#191b23`) does all structural separation; white is the data surface, `#f4f5f9` is chrome
- Tight radii — 2px charts, 4px addons, 6px for controls/cards/poppers; only tags and switches go full-pill (24px)
- **Table is the hero component**, not an afterthought: 12px cell padding, 8px compact mode, top-aligned content, sticky header, and six semantic row states (selected / unread / new / critical / warning / accordion)
- A **24-color ordered chart palette** starting `#2bb3ff → #59ddaa → #ff642d → #f67cf2` — long enough for real competitor/keyword comparisons without recycling hues
- Dusty violet app shell (`#382E5E` header, `#E7E8F2`/`#E2DDFF` sidebar states) frames the bright white data surface
- Control heights come in three fixed steps: **20px (S) / 28px (M) / 40px (L)** — M is the dashboard default, and it is small on purpose
- Feather-light shadows (`0 0 1px` + `0 1px 2px` at 12–16% ink) — with this many adjacent surfaces, heavy elevation would turn the page to mush

## 2. Color Palette & Roles

### Background Surfaces
- **Data White** (`#ffffff`, `gray.white`): The primary interface background — every table, card, and chart canvas. Reserved for content, never for chrome.
- **Chrome Wash** (`#f4f5f9`, `gray.50`): Table header cells, page chrome, secondary/inset surfaces, unread-row tint, hover state of white surfaces. The most-used non-white surface in the system.
- **Active Wash** (`#e0e1e9`, `gray.100`): Active/pressed state of neutral surfaces, hovered table cells, hovered header cells, skeleton fill (at 80% opacity), chart grid lines.
- **Pressed Wash** (`#c4c7cf`, `gray.200`): Active state of secondary surfaces; also the chart X-axis line color.
- **Selected Blue** (`#e9f7ff`, `blue.50`): Selected table row/cell — deliberately a tint, not a border, so selection survives in a grid where every cell already has neighbors. Hover of a selected row goes `#c4e5fe` (`blue.100`).
- **Semantic Row Tints**: new `#dbfee8` (`green.50`), critical `#fff0f7` (`red.50`), warning `#fff3d9` (`orange.50`), highlight `#fdf7c8` (`yellow.50`). Row-level status is communicated by full-cell tint because a 12px-padded row has no room for a dedicated status column.
- **App Header** (`#382E5E`, `violet.dusty.700`): The global top bar — a deep dusty violet that frames the white data surface. Its internal dividers are `rgba(255,255,255,0.15)`.
- **Sidebar Nav States**: hover `#E7E8F2` (`violet.dusty.50`), active `#E2DDFF` (`violet.dusty.100`).

### Text & Content
- **Primary Text** (`#191b23`, `gray.800`): Near-black with a cool cast — all metric values, table cell data, headings. The darkest ink in the system.
- **Secondary Text** (`#6c6e79`, `gray.500`): Column headers, labels, hints, chart axis labels, metric captions. Carries roughly half the words on a dense dashboard.
- **Placeholder / Tertiary** (`#8a8e9b`, `gray.400`): Input placeholders, disabled text, the chart "total amount" series.
- **Large Secondary** (`#a9abb6`, `gray.300`): De-emphasized text at large sizes (big muted numbers, empty-state figures), secondary icons, and the table's accent border.
- **Link** (`#006dca`, `blue.500`): All text links. Hover/active darkens to `#044792` (`blue.600`); visited goes `#8649e1` (`violet.500`).
- **Advertising Text** (`#421983`, `violet.700`): Text belonging to the paid-media/advertising product family — a product-line signal, not decoration.
- **Inverted Text** (`#ffffff`, with `rgba(255,255,255,0.8)` for secondary): For the violet header and dark/colored fills.

### Brand & Accent
- **Semrush Orange** (`#ff642d`, `orange.400`): The brand color and the fill of the **brand-primary control only** — "Start free trial", "Upgrade plan", "Create project". Hover `#c33909` (`orange.500`), active `#8b1500` (`orange.600`). Also the third color of the chart palette and the "warning" semantic.
- **Control Blue** (`#008ff8`, `blue.400`): The fill of the ordinary primary control — "Apply filters", "Export", "Add keyword", "Run audit". Hover `#006dca` (`blue.500`), active `#044792` (`blue.600`). **This, not orange, is the default button color.**
- **Advertising Violet** (`#5925ab` / `#421983` / `#8649e1`, `violet.600/700/500`): Primary control fill on advertising-product surfaces.
- **Dusty Violet Shell** (`#382E5E`, `#4D407E`, `#6D619F`, `#9083C5`): App header background; active sidebar text `#4D407E`, normal sidebar text `#6D619F`, normal sidebar icon `#9083C5`.

### Status & Semantic
- **Success** (`#009f81`, `green.400` for icons/fills; `#007c65`, `green.500` for text): Positive deltas, healthy site-audit scores, progress-bar fill.
- **Critical** (`#ff4953`, `red.400` for icons/fills; `#d1002f`, `red.500` for text): Errors, negative deltas, broken links.
- **Warning** (`#ff642d`, `orange.400` for icons; `#c33909`, `orange.500` for active borders): Notices, stale data, quota approaching. Note the deliberate overlap with brand orange — keep warning usage to icons and row tints so it never reads as a CTA.
- **Info** (`#008ff8` / `#006dca`): Informational banners, tooltips, neutral notices.
- **Subtle Banner Fills**: info `#e9f7ff`, success `#dbfee8`, critical `#fff0f7`, warning `#fff3d9`, highlight `#fdf7c8`, advertising `#f9f2ff` — the 50-step of each ramp, used for full-width in-page notices that must not steal attention from the data.
- **Disabled**: `opacity: 0.3` applied to the element, not a separate gray token.

### Data Visualization Palette (ordered — use in sequence)
The system ships a **24-color ordered palette** so that a competitor chart with 12 series never has to invent colors. First eight, in order:

| # | Token | Hex |
|---|-------|-----|
| 1 | `blue.300` | `#2bb3ff` |
| 2 | `green.200` | `#59ddaa` |
| 3 | `orange.400` | `#ff642d` |
| 4 | `pink.300` | `#f67cf2` |
| 5 | `yellow.200` | `#fdc23c` |
| 6 | `violet.400` | `#ab6cfe` |
| 7 | `red.300` | `#ff8786` |
| 8 | `salad.200` | `#9bd85d` |

It continues `blue.400 #008ff8`, `green.300 #00c192`, `orange.200 #ffb26e`, `pink.400 #e14adf`, `yellow.300 #ef9800`, `violet.200 #dcb8ff`, `red.400 #ff4953`, `salad.300 #66c030`, then the remaining 200/400 steps of each family. **Always allocate from index 1 upward** — the order is tuned for adjacent-hue distinguishability, so picking arbitrarily breaks it.

Reserved non-series colors: **total/aggregate** `#8a8e9b` (`gray.400`), **other/missing data** `#c4c7cf` (`gray.200`), **null** `#e0e1e9` (`gray.100`).

Chart chrome: grid line `#e0e1e9`, X-axis `#c4c7cf`, hover accent line `#a9abb6`, axis label text `#6c6e79`, bar base track `#e0e1e9`, bar hover `rgba(196,199,207,0.3)`, highlighted period `rgba(196,199,207,0.2)`, and a `#ffffff` border on dots and segments so overlapping series stay readable.

### Border & Divider
- **Primary Border** (`#c4c7cf`, `gray.200`): Inputs, cards, standard dividers.
- **Secondary Border** (`#e0e1e9`, `gray.100`): Internal table rules, subtle separators — the hairline that does most of the grid work.
- **Table Accent Border** (`#a9abb6`, `gray.300`): Group/section boundaries inside a table (a pinned totals row, a column group) — deliberately darker than the row rules so hierarchy survives at 12px padding.
- **Active/Semantic Borders**: info-active `#006dca`, success-active `#007c65`, critical-active `#d1002f`, warning-active `#c33909`; their resting counterparts are the 200-step (`#8ecdff`, `#59ddaa`, `#ffaeb5`, `#ffb26e`).

### Overlay
- **Modal Backdrop** (`rgba(25,27,35,0.7)`): Primary overlay — heavy, because a dense page behind a modal needs decisive suppression.
- **Light Overlay** (`rgba(25,27,35,0.4)`): Secondary overlay for lighter dismissible layers.
- **Locked-Content Veil** (`rgba(255,255,255,0.85)` over `#f4f5f9`): Gates data behind a plan limit — a genuinely Semrush-specific pattern, since much of the product is metered.

## 3. Typography Rules

### Font Family
- **Display / Marketing**: `"Factor A", "Factor A Variable", Inter, -apple-system, "Segoe UI", Roboto, sans-serif` — the brand display face, for marketing headlines and the logotype
- **Product UI / Body**: `Inter, -apple-system, "Segoe UI", Roboto, Ubuntu, sans-serif` — the documented base font of the design system; pair with `font-variant-numeric: tabular-nums` for all metric and table figures
- **Monospace**: `ui-monospace, "SF Mono", Menlo, Consolas, monospace` — URLs, regex filters, API keys, raw SERP snippets

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| H1 | Inter | 48px (fs-800) | 600 | 117% | Report page title — rare in-app, common on marketing |
| H2 | Inter | 36px (fs-700) | 600 | 110% | Major section header |
| H3 | Inter | 32px (fs-600) | 600 | 125% | Sub-section; also the size for hero KPI values |
| H4 | Inter | 24px (fs-500) | 600 | 117% | Card/panel title; standard KPI value size |
| H5 | Inter | 20px (fs-400) | 600 | 120% | Widget title, modal header |
| H6 | Inter | 16px (fs-300) | **700** | 150% | Smallest heading — the only heading at bold |
| Subtitle | Inter | 20px (fs-400) | 400 | 120% | Regular-weight large text under a heading |
| Body Large | Inter | 16px (fs-300) | 400 | 150% | Onboarding, empty states, marketing body |
| **Body / Table Cell** | Inter | **14px (fs-200)** | 400 | 142% | **The default size for the entire product** |
| Body Medium | Inter | 14px (fs-200) | 500 | 142% | Emphasized cells, nav items, active labels |
| Label / Caption | Inter | 12px (fs-100) | 400–500 | 133% | Column headers, metric captions, filter chips, timestamps |
| Chart Axis Label | Inter | 12px (fs-100) | 700 | — | Axis ticks — bold at 12px so they read against grid lines |
| Micro | Inter | 10px (fs-50) | 500 | 133% | Counter badges, superscript deltas, legend micro-labels — the density floor |

### Principles
- **14px is the product's voice, 16px is the marketing voice.** Do not "upgrade" in-app body text to 16px for comfort; the dashboard's value depends on rows per screen. 16px appears in-app only for onboarding and empty states.
- **12px is a first-class working size** for column headers, captions, and axis labels — and at 12px, weight (500/700) does the emphasis work that size can't.
- **Weight ladder 400 / 500 / 600 / 700**: 400 reads, 500 emphasizes within a dense row, 600 heads sections, 700 is reserved for H6 and chart axis labels. Never stack 600 on a 14px table cell — use 500.
- **Line-heights are percentage-based and tighten as size grows** (150% at 16px → 142% at 14px → 110% at 36px). Large headings compress; small dense text keeps enough leading to stay scannable.
- **Tabular figures are mandatory** for any column of numbers, deltas, or percentages. A KPI grid where digits shift width column-to-column is the fastest way to make this style look wrong.
- **No decorative letter-spacing.** Positive tracking on 12px uppercase column headers is acceptable; negative tracking on display type is not part of the system.
- Cap a page at **four heading levels** (H1–H4) — a dashboard needing six has an information-architecture problem, not a typography problem.

## 4. Component Stylings

### Buttons

Three fixed heights, driven by the 4px unit: **S = 20px**, **M = 28px**, **L = 40px**. **M (28px) is the dashboard default** — toolbar actions, filter triggers, table row actions. L is for page-level and marketing CTAs. Radius is always **6px** (`control-rounded`).

**Brand Primary (orange)**
- Background: `#ff642d` → hover `#c33909` → active `#8b1500`
- Text: `#ffffff`
- Padding: 6px 16px (M), 10px 20px (L)
- Radius: 6px
- Use: **One per screen, maximum.** "Start free trial", "Upgrade plan", "Create project".

**Primary (blue) — the default**
- Background: `#008ff8` → hover `#006dca` → active `#044792`
- Text: `#ffffff`
- Padding/Radius: as above
- Use: The ordinary confirming action — "Apply", "Export", "Add keywords", "Run audit". Reach for this before orange.

**Secondary**
- Background: `rgba(138,142,155,0.1)` → hover `rgba(138,142,155,0.2)` → active `rgba(138,142,155,0.3)`
- Text: `#191b23`
- Radius: 6px
- Use: The workhorse of a dense toolbar. Because the fill is a translucent neutral, ten of them in a row don't create ten hard boxes. An info variant swaps in `rgba(0,143,248,0.1/0.2/0.3)` with `#006dca` text.

**Tertiary / Ghost**
- Background: transparent → hover `rgba(138,142,155,0.2)` → active `rgba(138,142,155,0.3)`
- Text: `#191b23` (neutral) or `#006dca` (link-lookalike)
- Use: Inline table-row actions, icon buttons, anything that must not add a visible box to an already-busy row.

**Critical / Success variants**: swap the primary fill for `#ff4953` / `#009f81` with the same hover/active darkening pattern.

**Disabled**: `opacity: 0.3` on the whole control — never a separate gray fill.

### Cards & Containers
- Background: `#ffffff`; secondary/inset containers `#f4f5f9`
- Border: `1px solid #c4c7cf` **or** the card shadow — not both. In a grid of eight KPI cards, prefer the shadow and drop the border, so eight adjacent 1px lines don't form a visual mesh.
- Radius: **6px** (`surface-rounded`); modals 12px
- Shadow: `0 0 1px rgba(25,27,35,0.16), 0 1px 2px rgba(25,27,35,0.12)`; hover `3px 3px 30px rgba(25,27,35,0.15)`
- Padding: 12–16px for in-dashboard cards, 24px for standalone panels. **12px is normal here** — a KPI card is a number, a caption, and a sparkline, not an essay.

### KPI / Metric Card (the signature dense component)
- Structure, top to bottom: **12px caption** (`#6c6e79`, often with an info icon) → **24–32px value** (weight 600, `#191b23`, tabular figures) → **12px delta** (`#007c65` up / `#d1002f` down, with an arrow glyph) → optional inline sparkline
- Card size target: **~160–200px wide, ~96–120px tall** — small enough that 5–8 fit in one row at desktop width
- The delta sits on the **line immediately below the value with no separator** — the comparison is the point
- Never center-align the value; left-align so a row of cards forms a scannable column of numbers
- Grid: `repeat(auto-fit, minmax(160px, 1fr))` with an **8px or 12px gap** — cards sit close together on purpose

### Inputs & Forms

**Text Input**
- Height: 28px (M) default, 40px (L) for standalone forms, 20px (S) inside table cells and toolbars
- Background: `#ffffff`
- Border: `1px solid #c4c7cf`; hover `#a9abb6`; focus adds `0 0 0 3px rgba(0,143,248,0.5)`
- Radius: 6px
- Padding: 4px 8px (S/M), 8px 12px (L)
- Text `#191b23`, placeholder `#8a8e9b`
- Invalid: border `#d1002f`, focus ring `rgba(255,73,83,0.5)`; valid: border and ring from the green ramp

**Filter Trigger / Multi-level Filter Bar (the other signature component)**
- A dense horizontal bar of 28px triggers, each `rgba(138,142,155,0.1)` background, 6px radius, 12px weight-500 label, chevron icon in `#8a8e9b`
- An **applied** filter switches to `rgba(0,143,248,0.1)` background with a `#006dca` label and a dismiss "×" — applied vs. available must be distinguishable at a glance, because there are often six to ten of them
- Filters **wrap to a second and third row rather than collapsing into a "More filters" menu** — visible filter state is part of the data's provenance
- An "Advanced filters" popover (6px radius, `0 1px 12px rgba(25,27,35,0.15)`) holds the condition builder: field select + operator select + value input, 8px gaps, one row per condition

**Dropdown / Select Menu**
- Item background `#ffffff`, hover `#f4f5f9`, selected `rgba(196,229,254,0.7)`, selected+hover `#c4e5fe`
- Popover radius 6px, shadow `0 1px 12px rgba(25,27,35,0.15)`
- Item height 28–32px with 14px text — dropdowns here are often 20+ items long (country, device, database), so item height stays tight

### Tags & Badges
- **Tag (pill)**: radius **24px** (`tag-rounded`), 12px weight-500 text, 2px 8px padding. Backgrounds are pre-flattened opaque values so they can sit over table row tints without compositing artifacts: gray `#ECEDF0`/text `#6c6e79`, blue `#D0EEFF`/`#006dca`, green `#CFF1EA`/`#007c65`, orange `#FFDDD2`/`#c33909`, red `#FFCEDC`/`#d1002f`, violet `#F4E3FF`/`#8649e1`, yellow `#FEE6D1`/`#a75800`. Hover/active use the slightly deeper variants (`#E3E4E9`, `#B7E4FF`, `#B7EAE0`, `#FFCCBB`, `#FFB6CA`, `#EFD5FF`, `#FEDAB9`).
- **Secondary Tag**: `#ffffff` background, `1px solid #c4c7cf`, hover `#f4f5f9` — for user-removable filter chips.
- **Badge**: radius 6px (`badge-rounded`), 10–12px weight-500 — "NEW", "BETA", plan-tier markers.
- **Counter**: radius 12px (`counter-rounded`), 10px text — row counts, notification counts.
- **Score Pill** (SEO-specific): a 12px weight-600 numeric pill whose background comes from the semantic ramp by threshold (Authority Score, Keyword Difficulty) — green `#CFF1EA` / yellow `#FEE6D1` / red `#FFCEDC`, text in the matching 500-step.

### Navigation
- **Global header**: `#382E5E` background, full-width, ~48–56px tall; white logotype (Factor A); white nav labels; internal dividers `rgba(255,255,255,0.15)`; the brand-orange CTA sits at the right edge — the one place orange appears in the chrome
- **Left sidebar**: `#ffffff` or `#f4f5f9` background, ~220–260px wide, collapsible to an icon rail. Items: 14px weight-500, text `#6D619F`, icon `#9083C5`; hover background `#E7E8F2`; active background `#E2DDFF` with text and icon at `#4D407E`
- The sidebar is **grouped by product** (SEO / Advertising / Social / Content) with 12px uppercase weight-500 group labels in `#6c6e79` — the app carries dozens of tools, so the grouping is load-bearing
- **In-report tabs**: 14px weight-500, `#6c6e79` inactive / `#191b23` active with a `2px` `#006dca` (or `#ff642d`) underline; the tab bar sits directly above the table with an 8px gap
- **Breadcrumb**: 12px, `#006dca` links with `#8a8e9b` separators — needed because report depth routinely reaches four levels

### Table / Grid Treatment (the hero component)
- **Cell padding: 12px** (`spacing-3x`) on header and body cells alike; **compact mode reduces horizontal padding to 8px** (`spacing-2x`) — use compact above roughly eight columns
- **Content is top-aligned**, not vertically centered — so a cell containing two stacked lines (keyword + URL, or value + delta) doesn't shift its neighbors' baselines
- **Header row**: `#f4f5f9` background, 12px weight-500 `#6c6e79` labels, hover/active `#e0e1e9`. A secondary (borderless) table variant uses a `#ffffff` header instead
- **Sticky header** on long tables; **sticky first column** for the entity name (keyword / domain / URL)
- **Sorting**: sortable columns reveal a sort icon on hover; an already-sorted column shows its direction icon persistently. If a header cell contains only non-interactive text and icons, **the whole cell is the sort target**
- **Row rules**: `1px solid #e0e1e9` horizontal only — no vertical cell borders in the default table. Use the darker `#a9abb6` accent border only for column-group or totals-row boundaries
- **Row states** (background tint, not border): hover `#e0e1e9`, selected `#e9f7ff` (hover `#c4e5fe`), unread `#f4f5f9`, new `#dbfee8`, critical `#fff0f7`, warning `#fff3d9`, nested-accordion `#f4f5f9`
- **Numeric columns are right-aligned with tabular figures**; text columns left-aligned; a delta or trend indicator lives inside the same cell as its value, never in a separate column
- **Table toolbar**: row count + applied filter chips + column-config trigger + export button, all at 28px height in a single row above the header

### Charts
- Radius on bars and segments: **2px** (`chart-rounded`) — barely rounded, so bar-to-bar gaps stay legible at 20+ bars
- Grid: horizontal lines only, `#e0e1e9`; X-axis `#c4c7cf`; axis labels 12px weight-700 `#6c6e79`
- Series colors come from the ordered palette **in sequence**; dots and stacked segments get a `1px #ffffff` border so overlaps read
- Hover: a vertical accent line `#a9abb6` plus a tooltip (white, 6px radius, `0 1px 12px rgba(25,27,35,0.15)`) listing **every** series at that X — not just the hovered one, because cross-series comparison is the task
- Legend sits **above** the chart as a row of 12px items, not to the side — horizontal space belongs to the data
- **Charts are paired with their numbers, not substituted for them**: a trend chart here almost always has a KPI row above it and a data table below it, on the same screen

### Progress & Feedback
- **Progress bar**: 4–8px tall, radius 6px, fill `#009f81`, track `#e0e1e9`
- **Skeleton**: `rgba(224,225,233,0.8)` blocks at the final content's exact dimensions — with this much on screen, layout shift on load is very visible
- **Tooltip**: default `#ffffff` at 6px radius with the popper shadow; warning `#ffd7df`; inverted `#191b23` with white text
- **Locked/metered content**: `rgba(255,255,255,0.85)` veil over `#f4f5f9` with a centered upgrade prompt — the plan-gating pattern

## 5. Layout Principles

### Spacing System
- **Base unit: 4px** (`scale-indent`) — half the usual 8px, and this is the system's defining structural decision
- Scale: **2px (0.5x), 4px (1x), 8px (2x), 12px (3x), 16px (4x), 20px (5x), 24px (6x), 32px (8x), 40px (10x), 56px (14x), 80px (20x), 96px (24x), 120px (30x)**
- Control heights are spacing multiples: **20px (5x) / 28px (7x) / 40px (10x)**
- **In-dashboard defaults**: 8px between related controls, 12px card and cell padding, 16px between cards, 24px between report sections. The 40px+ steps exist for marketing pages, not dashboards
- Never introduce an off-scale value to "give it room" — reach for the next step down instead and let density work

### Grid & Container
- **Full-bleed dashboard layout**: fixed sidebar (220–260px, collapsible to an icon rail) + fluid main region. No max-width on the data region — a wide monitor should show more columns, which is the entire point
- **Marketing/content pages**: ~1200px max content width
- **KPI band**: `repeat(auto-fit, minmax(160px, 1fr))` with 8–12px gaps — typically 5–8 cards per row at desktop
- **Report page vertical order**: breadcrumb → title + scope selector → filter bar (may wrap 2–3 rows) → KPI band → chart → data table. This sequence is the style's structural signature
- **Two-pane detail**: a table on the left with a persistent detail/preview panel on the right (SERP preview, backlink detail) rather than a modal — a modal hides the list you're comparing against

### Whitespace Philosophy
- **Density is the product, not a compromise.** The question is never "does this need more breathing room" but "can a marketer answer their question without scrolling or clicking". Whitespace is a budget spent on separating *sections*, not on padding individual elements.
- **Luminance does the separating.** With gaps this small, the `#ffffff` → `#f4f5f9` → `#e0e1e9` ladder — not spatial gutters — keeps the sidebar, toolbar, header row, and cells distinct.
- **Adjacency is meaning.** Value and delta, chart and table, filter and result: putting these within 8–12px of each other is a semantic statement that they should be read together. Pulling them apart for aesthetic balance destroys information.
- **Vertical space is the scarce resource.** Spend it on rows. This is why cell content is top-aligned, why line-heights tighten, and why the filter bar wraps rather than growing taller controls.
- **Marketing pages are the explicit exception** and run a different rhythm: 56–120px section spacing, 16px body, Factor A display headlines. The two modes should not be blended on one page.

### Border Radius Scale
- **2px** (`rounded-extra-small`): chart bars and segments
- **4px** (`rounded-small`): input addons, small attached elements
- **6px** (`rounded-medium`): the dominant radius — buttons, inputs, cards, poppers, dropdowns, badges, progress bars
- **12px** (`rounded-large`): modals, counters
- **24px** (`rounded-extra-large`): tags and switches only (reads as full-pill at tag heights)
- Avatars/favicons: circle at 16–24px — domain favicons appear in nearly every table row

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow; `1px solid #e0e1e9` or `#c4c7cf` | Table rows, inline surfaces, the data canvas |
| Card (Level 1) | `0 0 1px rgba(25,27,35,0.16), 0 1px 2px rgba(25,27,35,0.12)` | KPI cards, widgets, panels |
| Card Hover (Level 1h) | `3px 3px 30px rgba(25,27,35,0.15)` | Hovered/clickable card |
| Popper (Level 2) | `0 1px 12px rgba(25,27,35,0.15)` | Dropdowns, filter popovers, tooltips, column config |
| Modal (Level 3) | `0 3px 8px rgba(25,27,35,0.2)` over an `rgba(25,27,35,0.7)` backdrop | Dialogs, confirmations |
| Drag (Level 4) | `0 0 1px rgba(25,27,35,0.16), 0 12px 40px rgba(25,27,35,0.16)` | Dragged widget or column while reordering |
| Focus Ring | `0 0 0 3px rgba(0,143,248,0.5)` | Keyboard focus (valid → green ramp, invalid → red ramp, on-dark → `rgba(255,255,255,0.7)`) |

Layer order (`z-index`): overlay 500, popper 700, dropdown 750, tooltip 800, modal 900, notice bubble 999.

**Shadow Philosophy**: shadows are tinted with the system's own ink (`rgba(25,27,35,…)`) and kept **deliberately feather-light at Level 1** — a two-part `0 0 1px` + `0 1px 2px` at 12–16% opacity. This is a direct consequence of density: on a screen with thirty adjacent surfaces, a conventional `0 4px 12px` card shadow would produce a muddy gray haze across the whole page. Real separation is done by the gray luminance ladder and 1px rules; shadow is used only to say "this element floats above the page" (poppers, modals, drags). The one dramatic shadow in the system — the 30px card-hover glow — exists to make a clickable card unmistakable in a grid of eight.

## 7. Do's and Don'ts

### Do
- **Fit more on the screen.** When in doubt, choose the arrangement that answers more questions per viewport — that is this style's entire reason to exist
- Use **14px** for in-app body and table text, and **12px** for column headers, captions, and axis labels
- Reserve **orange `#ff642d` for a single brand-primary action per screen**; use **blue `#008ff8`** for every other primary button
- Keep table cell padding at **12px** (8px horizontal in compact mode) and **top-align cell content**
- Apply **tabular figures** to every numeric column, KPI value, and delta
- Allocate chart series from the **ordered palette starting at index 1**
- Place the **value and its delta on adjacent lines inside the same card or cell**
- Let the **filter bar wrap to multiple rows** so applied filter state stays visible
- Use the **gray luminance ladder** (`#ffffff` / `#f4f5f9` / `#e0e1e9`) for zone separation instead of larger gaps
- Keep radii at **6px** for controls, cards, and poppers, and **2px** for chart bars
- Use **row background tints** for status (selected / new / critical / warning) rather than adding a status column
- Choose a **persistent side detail panel** over a modal when the user is comparing list items

### Don't
- **Don't add whitespace to "let it breathe."** Increasing table row height, card padding, or section gaps trades away the thing this style exists for. If a screen feels overwhelming, improve grouping, alignment, and luminance separation — don't spread it out
- **Don't bump in-app body text to 16px.** 16px is the marketing and empty-state size only
- **Don't use orange for ordinary buttons.** Two orange buttons on one screen means neither is the brand action, and the whole ration system collapses
- **Don't put both a 1px border and a card shadow on every card** — in a grid of eight, pick one
- **Don't apply heavy shadows** (`0 4px 12px` and up) to cards or table rows; Level 1 here is intentionally near-invisible
- **Don't center-align KPI values or numeric columns** — left-align captions and values, right-align numeric table columns, so digits form scannable vertical stacks
- **Don't vertically center table cell content**, or two-line cells will knock their neighbors' baselines out of alignment
- **Don't draw vertical cell borders** in the default table; horizontal `#e0e1e9` rules plus a `#f4f5f9` header are sufficient
- **Don't pick chart colors ad hoc or reuse a hue within one chart** — the 24-color order exists precisely to avoid this
- **Don't collapse the filter bar into a single "Filters" button.** Hidden filter state makes the numbers unattributable
- **Don't cap the data region with a max-width.** Extra viewport width must become extra columns
- **Don't put 600 weight on 14px table cells** — use 500 for in-row emphasis
- **Don't set an off-scale spacing value** (10px, 14px, 18px); the 4px scale already gives you half-steps
- **Don't use the dusty violet header color as a content or accent color** — it belongs to the app shell

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|--------------|
| Extra Small | ≥320px | Single column. KPI cards stack 2-up. Table becomes a card-per-row list showing 3–4 key metrics with a "view all metrics" expand. Sidebar → bottom sheet |
| Small | ≥768px | KPI cards 3–4 up. Table returns as a horizontally scrollable grid with a sticky first column. Sidebar → collapsed icon rail |
| Medium | ≥1200px | Full dashboard: expanded sidebar + KPI band 5–6 up + chart + full table. The design target |
| Large | ≥1920px | Sidebar expanded, KPI band 7–8 up, table reveals additional columns before scrolling — extra width becomes extra data, never extra margin |

### Touch Targets
- The 28px (M) control is a **pointer-only** size. On touch, promote controls to **40px (L)** and table rows to a **44px minimum** effective tap height
- Icon-only table row actions grow from 20–24px to 40px, and hover-revealed actions become persistently visible (there is no hover on touch)
- Filter triggers become 40px with 8px gaps; sort and column-config controls move into an explicit toolbar sheet

### Collapsing Strategy
- **Sidebar**: expanded (≥1200px) → icon rail (≥768px) → bottom sheet / hamburger (<768px)
- **KPI band**: 8 → 6 → 4 → 2 per row; the card `minmax` floor stays 160px, so cards reflow rather than shrink
- **Table**: full grid → horizontal scroll with sticky first column → card-per-row with progressive disclosure. Column priority (entity name, primary metric, delta) is declared per table, not inferred
- **Filter bar**: multi-row wrap → horizontally scrollable chip strip → a filter sheet whose trigger shows the applied-filter count
- **Chart**: full width with all series → reduced tick density → top-N series with the remainder folded into "Other" (`#c4c7cf`)
- **Marketing headings**: 48px → 36px → 28px

### Motion
- Durations come from tokens: **100ms** (switch), **200ms** (control, popper, modal, accordion), **300ms** (medium), **400/500ms** (slow). Everything interactive lands in the 100–200ms band, because a dense UI with 300ms+ transitions feels sludgy
- Table row hover, cell state changes, and sort re-ordering should be near-instant (100ms or none); transitions belong to elements that actually enter and leave — poppers, modals, accordions

## 9. Agent Prompt Guide

### Quick Color Reference
- Data surface: White (`#ffffff`)
- Chrome / table header: Chrome Wash (`#f4f5f9`)
- Row hover / grid lines: (`#e0e1e9`)
- Primary text: Cool Near-Black (`#191b23`)
- Secondary text / column headers: (`#6c6e79`)
- Placeholder: (`#8a8e9b`)
- Brand action (max 1 per screen): Semrush Orange (`#ff642d`), hover `#c33909`
- Default primary action: Control Blue (`#008ff8`), hover `#006dca`
- Link: (`#006dca`)
- Selected row: (`#e9f7ff`)
- Success / Critical: (`#009f81`) / (`#ff4953`); text variants (`#007c65`) / (`#d1002f`)
- Border: primary (`#c4c7cf`), row rule (`#e0e1e9`), table accent (`#a9abb6`)
- App header: Dusty Violet (`#382E5E`); sidebar active `#E2DDFF` with `#4D407E` text
- Chart series 1–4: (`#2bb3ff`), (`#59ddaa`), (`#ff642d`), (`#f67cf2`)
- Focus ring: `0 0 0 3px rgba(0,143,248,0.5)`

### Example Component Prompts
- "Build a KPI band: `repeat(auto-fit, minmax(160px, 1fr))` grid, 12px gap, 6 cards. Each card: white background, 6px radius, `0 0 1px rgba(25,27,35,0.16), 0 1px 2px rgba(25,27,35,0.12)` shadow, 12px padding, no border. Inside, left-aligned: 12px Inter weight 500 `#6c6e79` caption, then 24px Inter weight 600 `#191b23` value with `font-variant-numeric: tabular-nums`, then a 12px delta line in `#007c65` (up) or `#d1002f` (down)."
- "Create a data table: white cells, header row `#f4f5f9` with 12px Inter weight 500 `#6c6e79` labels, sticky header, sticky first column, 12px cell padding, top-aligned content, horizontal `1px solid #e0e1e9` row rules and no vertical borders, 14px Inter weight 400 `#191b23` cell text, numeric columns right-aligned with tabular figures, row hover `#e0e1e9`, selected row `#e9f7ff`."
- "Design a filter bar: a wrapping flex row of 28px-tall triggers with 8px gaps. Available filter: `rgba(138,142,155,0.1)` background, 6px radius, 12px weight-500 `#191b23` label, `#8a8e9b` chevron. Applied filter: `rgba(0,143,248,0.1)` background, `#006dca` label, dismiss × icon. Let it wrap to a second row instead of collapsing into a menu."
- "Create a button set at 28px height and 6px radius: brand primary `#ff642d` with white text (hover `#c33909`), primary `#008ff8` with white text (hover `#006dca`), secondary `rgba(138,142,155,0.1)` with `#191b23` text (hover `rgba(138,142,155,0.2)`), tertiary transparent with `#191b23` text (hover `rgba(138,142,155,0.2)`). Focus: `0 0 0 3px rgba(0,143,248,0.5)`."
- "Build a report page shell: `#382E5E` global header ~52px with a white Factor A logotype and one orange CTA at the right; 240px white left sidebar with 14px weight-500 `#6D619F` items, hover `#E7E8F2`, active `#E2DDFF` + `#4D407E`; main region full-bleed with no max-width, containing breadcrumb → 24px title → wrapping filter bar → KPI band → chart → data table, 24px between sections and 16px between cards."
- "Design a trend chart: horizontal grid lines `#e0e1e9`, X-axis `#c4c7cf`, 12px Inter weight-700 `#6c6e79` axis labels, series in order `#2bb3ff`, `#59ddaa`, `#ff642d`, dots with a 1px `#ffffff` border, 2px bar radius, legend as a 12px row above the plot, hover showing an `#a9abb6` vertical line and a white 6px-radius tooltip listing all series at that X."
- "Create a tag row: 24px-radius pills, 12px Inter weight 500, 2px 8px padding — blue `#D0EEFF`/`#006dca`, green `#CFF1EA`/`#007c65`, orange `#FFDDD2`/`#c33909`, gray `#ECEDF0`/`#6c6e79`."

### Iteration Guide
1. **Density check first**: count the KPIs, rows, and filters visible without scrolling. If a comparable Semrush report would show more, the layout is too loose — tighten padding and row height before anything else
2. **Orange audit**: exactly zero or one orange element per screen; any additional orange button becomes `#008ff8`
3. **Type audit**: in-app body and table text at 14px, labels/captions/axis at 12px. Any 16px inside a dashboard region is suspect
4. **Numbers audit**: every numeric column, KPI value, and delta uses tabular figures; numeric table columns right-aligned, KPI values left-aligned
5. **Table audit**: 12px cell padding, top-aligned content, `#f4f5f9` header, horizontal-only `#e0e1e9` rules, sticky header and first column, status shown as a row tint
6. **Spacing audit**: every value is a 4px multiple, and in-dashboard gaps stay in the 8 / 12 / 16 / 24 band — 32px+ belongs to marketing pages
7. **Elevation audit**: cards use the feather-light Level 1 shadow *or* a 1px border, not both; nothing heavier than Level 1 outside poppers, modals, and drags
8. **Chart audit**: series allocated from the ordered palette starting at 1, no repeated hue, 2px bar radius, legend above the plot, tooltip listing all series
9. **Filter audit**: applied filters visibly distinct from available ones, and the bar wraps rather than hiding state
10. **Width audit**: the data region has no max-width, and widening the viewport reveals more columns rather than more margin
