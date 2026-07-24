# Design System Inspired by Attio

## 1. Visual Theme & Atmosphere

Attio's website and product present as the visual antithesis of a legacy enterprise CRM: instead of blue-and-gray corporate chrome, it commits to a **precision, near-achromatic grayscale system** — pure white canvas (`#FFFFFF`), a single near-black accent (`#202124`), and a meticulously graded ladder of mid-grays for everything in between. The overall impression is one of **data-density engineered for calm** — this is a product built to display thousands of rows of company, people, and deal records at once, and the design system's entire job is to make that density feel controlled rather than overwhelming. Where Linear achieves precision through darkness and Granola achieves warmth through paper tones, Attio achieves precision through **restraint**: almost no chromatic color anywhere in the core UI, so that when a status dot or a data-visualization accent does appear, it reads instantly as meaningful signal rather than decoration.

Typography runs on **Inter** for UI text and **InterDisplay** for large headings — the same type family split into two optical sizes, a technique built specifically so that big marketing headlines (up to 80px) and tiny dense table cells (down to 12px) both render optimally at their respective scales without needing separate typefaces. This is a deliberately un-flashy choice: Attio isn't trying to have a "personality font" the way Granola's Quadrant or Linear's tuned Inter does — it's optimizing purely for legibility at extreme size range, because the product's core surface is a spreadsheet-like record table where every pixel of x-height matters.

The color system's only real chromatic move is reserving the near-black (`#202124`) as the "ink" of the interface — used for primary buttons, primary text emphasis, and the strongest borders — while the rest of the palette is a careful five-step gray scale (`#2E3238` → `#6F7988` → `#A4ADBA` → `#B5BDC9` → `#CAD0D9` → `#D3D8DF`) that lets the UI express hierarchy through **luminance steps alone**, not hue. This is CRM-as-spreadsheet aesthetics: dense tables, small type, tight row heights, and a grayscale system disciplined enough that data itself — not chrome — is always the visual focus.

**Key Characteristics:**
- Pure white background (`#FFFFFF`) — no tinted or warm-toned canvas, a clinical, precise white
- Near-black accent `#202124` as the system's only strong chromatic move — used for primary buttons and top-level emphasis
- Five-step neutral gray scale (`#2E3238`, `#6F7988`, `#A4ADBA`, `#B5BDC9`, `#CAD0D9`, `#D3D8DF`) carries almost all hierarchy — no blue/teal/brand-hue substitute
- Inter for UI (body/labels), InterDisplay for large headings — one family, two optical masters
- Body/table text as small as **12px** — high information density is a first-class design goal, not a compromise
- H1 at 80px, H2 at 40px — a steep but controlled display scale (2:1 ratio), unlike Granola's extreme 110px-vs-14px jump
- Primary button: near-black (`#202124`) background, light gray text (`#F3F4F6`), 10px radius, with a visible mid-gray border (`#505967`)
- Secondary button: white background, `#CAD0D9` border, 10px radius — quiet, table-adjacent affordance
- Base spacing unit 8px, standard radius 8–10px — comfortable but not soft; corners are rounded enough to feel modern, not so round they feel casual
- Table/grid aesthetics dominate: 1px hairline borders, high-contrast column headers, alternating-row legibility over decorative styling

## 2. Color Palette & Roles

### Background Surfaces
- **Page White** (`#FFFFFF`): The single background color for nearly the entire product and marketing site — no gray-tinted page background, keeping maximum contrast available for data.
- **Table Row Alt** (`#F9FAFB`, inferred from the neutral ladder): Very subtle alternating-row tint for dense tables, kept close enough to white that it doesn't compete with cell content.
- **Panel Gray** (`#F4F5F7`, inferred): Light gray background used to separate navigation/sidebar chrome from the primary record workspace.

### Text & Content
- **Primary Text** (`#2E3238`): Near-black charcoal — the default text color for headings and primary body copy. Slightly softer than pure black, but still reads as high-contrast "ink."
- **Secondary Text** (`#6F7988`): Mid-gray for secondary labels, field descriptions, less critical copy.
- **Tertiary Text** (`#A4ADBA`): Lighter gray for placeholders, disabled text, low-priority metadata.
- **Quaternary Text** (`#B5BDC9`): The lightest readable gray — used sparingly for the most de-emphasized labels (e.g. empty-state hints).

### Brand & Accent
- **Ink Black** (`#202124`): The system's near-black accent — primary button fills, key brand marks, the strongest possible emphasis color in an otherwise achromatic system. Functions the way a single brand hue would in a typical SaaS palette, except it's achromatic.
- **Button Text on Ink** (`#F3F4F6`): The light gray (not pure white) used as text on `#202124` buttons — keeps contrast high without the harshness of pure white-on-black.
- **Button Border** (`#505967`): Mid-dark gray border used specifically to frame the primary black button, adding definition without introducing hue.

### Status & Data Colors (product-context, inferred to remain in-family)
- **Success** (`#16A34A`, muted green): Deal-won states, positive record indicators — used only as small dots/badges, never large fills.
- **Warning** (`#D97706`, muted amber): Overdue tasks, stale records.
- **Error** (`#DC2626`, muted red): Failed sync, validation errors.
- **Data Category Accents** (soft blue/purple/teal swatches, inferred): Used exclusively for user-assignable tags and pipeline-stage color-coding — the *only* place saturated hue is allowed to proliferate, because it's user data, not UI chrome.

### Border & Divider
- **Standard Border** (`#D3D8DF`): The default border color — input outlines, secondary button borders, card edges.
- **Table Border** (`#CAD0D9`): Slightly more visible border used for table cell dividers and header underlines, where high-density grids need clearer separation than a card needs.
- **Strong Border** (`#505967`): Reserved for framing the primary black button and other high-emphasis elements.

### Overlay
- **Modal Backdrop** (`rgba(32,33,36,0.4)`): Near-black overlay at moderate opacity, using the ink-black accent color rather than pure black, staying tonally consistent with the rest of the system.

## 3. Typography Rules

### Font Family
- **Display**: `InterDisplay, Inter, -apple-system, "Segoe UI", Roboto, sans-serif` — optical size optimized for large headings
- **UI/Body**: `Inter, -apple-system, "Segoe UI", Roboto, sans-serif` — optical size optimized for small, dense text
- **Monospace**: `ui-monospace, "SF Mono", "Roboto Mono", Consolas, monospace` — for record IDs, API fields, formula/filter syntax

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| Hero H1 | InterDisplay | 80px (5.00rem) | 600 | 1.05 | Marketing hero headline |
| H2 | InterDisplay | 40px (2.50rem) | 600 | 1.15 | Section headers |
| H3 | InterDisplay | 28px (1.75rem) | 600 | 1.20 | Sub-section titles, feature headers |
| H4 | Inter | 20px (1.25rem) | 600 | 1.30 | Card/panel titles, modal headers |
| Body Large | Inter | 16px (1.00rem) | 400 | 1.55 | Marketing intro copy, onboarding text |
| Body | Inter | 14px (0.88rem) | 400 | 1.50 | Standard app UI text, form labels |
| Body Medium | Inter | 14px (0.88rem) | 600 | 1.50 | Emphasized labels, nav items |
| Table Cell | Inter | 13px (0.81rem) | 400 | 1.40 | Standard record-table cell content |
| Small/Caption | Inter | 12px (0.75rem) | 400 | 1.35 | Table headers, metadata, timestamps — the system's density floor |
| Label | Inter | 12px (0.75rem) | 500 | 1.30 | Field labels, filter chips |
| Micro | Inter | 11px (0.69rem) | 500 | 1.30 | Tiny badges, count indicators |
| Mono | ui-monospace | 12px (0.75rem) | 400 | 1.40 | Record IDs, formula syntax |

### Principles
- **Two optical masters, one voice**: InterDisplay handles 20px+ headings, standard Inter handles everything at 20px and below — the split exists purely for legibility at extreme sizes, not for visual variety, so the two should always feel like "the same font."
- **12px is a first-class size, not an afterthought**: unlike marketing-led systems that treat small text as a compromise, Attio's table-cell and caption sizes (12–13px) are core to the product experience — tight line-height (1.35–1.40) keeps dense grids scannable without wasted vertical space.
- **Weight ladder: 400 (read) / 500 (label) / 600 (announce)**: no 700-bold in the core system — 600 is the maximum emphasis weight, keeping even headlines from feeling shouty.
- **Controlled 2:1 display ratio**: H1 (80px) to H2 (40px) is exactly halved, and H2 to H3 is a gentler step — the display scale is systematic and predictable, reflecting the same engineering precision as the data grid itself.
- **No aggressive letter-spacing**: Inter/InterDisplay are used at normal or very slightly tightened tracking at display sizes — the precision comes from the grid and grayscale discipline, not typographic special effects.

## 4. Component Stylings

### Buttons

**Primary Button**
- Background: `#202124` (ink black)
- Text: `#F3F4F6` (light gray, not pure white)
- Padding: 10px 18px
- Radius: 10px
- Border: `1px solid #505967`
- Hover: background lightens slightly to `#33353A`
- Use: Primary CTAs — "Get started", "Create record", "Save"

**Secondary Button**
- Background: `#FFFFFF`
- Text: `#2E3238`
- Padding: 10px 18px
- Radius: 10px
- Border: `1px solid #CAD0D9`
- Hover: border darkens to `#A4ADBA`, background tints `#F9FAFB`
- Use: Secondary actions — "Cancel", "Filter", table toolbar actions

**Ghost/Text Button**
- Background: transparent
- Text: `#6F7988`
- Padding: 6px 10px
- Radius: 8px
- Hover: text darkens to `#2E3238`, background tints `#F4F5F7`
- Use: Inline row actions, tertiary nav links

**Icon Button**
- Background: transparent, `#F4F5F7` on hover
- Text/Icon: `#6F7988`, darkens to `#2E3238` on hover
- Radius: 8px
- Size: 28px × 28px (compact, fitting the dense UI)
- Use: Table row actions (edit, delete, expand), toolbar icons

### Cards & Containers
- Background: `#FFFFFF`
- Border: `1px solid #D3D8DF`
- Radius: 10px
- Shadow: none by default; hover/elevated state adds `0 2px 6px rgba(32,33,36,0.06)`
- Padding: 16–20px
- Marketing feature cards use slightly larger radius (12px) and more padding (24px) to distinguish from dense in-app cards

### Inputs & Forms

**Text Input**
- Background: `#FFFFFF`
- Border: `1px solid #D3D8DF`
- Radius: 10px
- Padding: 8px 12px
- Text: `#2E3238`, placeholder `#A4ADBA`
- Focus: border becomes `#202124`, focus ring `0 0 0 3px rgba(32,33,36,0.08)`

**Table Cell (Editable)**
- Background: transparent, `#F9FAFB` on hover, `#FFFFFF` with `1px solid #202124` ring when active/editing
- Border: `1px solid #CAD0D9` (cell divider, right + bottom only, forming the grid)
- Padding: 6px 10px
- Font: 13px Inter weight 400
- Row height: 36px (compact) — this tight vertical rhythm is central to the "spreadsheet-as-CRM" feel

**Filter Chip / Dropdown Trigger**
- Background: `#F4F5F7`
- Text: `#2E3238`
- Padding: 6px 10px
- Radius: 8px
- Border: `1px solid #D3D8DF`
- Font: 12px weight 500
- Use: Column filters, view/sort controls above the table

### Tags & Badges

**Status Dot**
- Size: 8px circle
- Colors: success `#16A34A`, warning `#D97706`, error `#DC2626`, neutral `#A4ADBA`
- Use: Record status, sync state — the primary place a saturated color is allowed in the core UI

**Data Tag Pill**
- Background: user-assignable soft hue (e.g. `#DBEAFE` blue-tint, `#F3E8FF` purple-tint) — the *only* zone where multiple chromatic colors coexist, since these represent user-created categories/pipeline stages
- Text: darker matching hue tone
- Padding: 3px 10px
- Radius: 6px
- Font: 12px weight 500
- Use: Pipeline stage labels, deal tags, company categories

**Count Badge**
- Background: `#F4F5F7`
- Text: `#6F7988`
- Padding: 2px 7px
- Radius: 9999px
- Font: 11px weight 500
- Use: Record counts, unread indicators, table row counts

### Navigation
- Sticky white header on marketing pages, `1px solid #D3D8DF` bottom border
- In-app: left sidebar (`#F4F5F7` background) + top toolbar (`#FFFFFF`) — a two-zone navigation model, distinct from a single top bar
- Sidebar items: Inter 14px weight 500, `#6F7988`, active state gets `#2E3238` text + `#FFFFFF` pill background with subtle border
- CTA (marketing): primary black button, right-aligned
- Table toolbar: filter chips + view switcher + primary black "New record" button, all left-to-right in a single dense row

### Table/Grid Treatment (Attio's signature surface)
- 1px hairline borders (`#CAD0D9`) on all cell boundaries — no zebra striping by default, relying on hairlines for row/column separation
- Column headers: `#F4F5F7` background, 12px weight 500 text in `#6F7988`, uppercase optional, sticky on scroll
- Row height: 36px default (compact mode), 44px (comfortable mode) — user-toggleable density, itself a design-system-level feature
- Selected row: `#F4F5F7` background with `2px solid #202124` left-edge indicator bar

## 5. Layout Principles

### Spacing System
- Base unit: 8px
- Scale: 4px, 8px, 12px, 16px, 20px, 24px, 32px, 40px, 48px, 64px
- Table-specific micro scale: 6px, 10px — tighter increments for cell padding where every pixel of row height matters
- Marketing sections use the standard 8px rhythm at 48–64px; in-app density drops to 8–16px between elements

### Grid & Container
- Max content width: ~1200px for marketing pages
- In-app: full-bleed layout with fixed sidebar (240–280px) + fluid main content area that hosts the record table
- Table view: horizontally scrollable grid with sticky first column (record name) and sticky header row
- Marketing feature sections: 2–3 column grids, often showcasing actual product screenshots of the dense table UI as the hero visual (the density itself is marketed as a feature)

### Whitespace Philosophy
- **Density is the value proposition, not a constraint**: unlike consumer-facing products that maximize whitespace, Attio's core surface is meant to show as much structured data as possible per screen — whitespace is spent deliberately (around the table, in modals) rather than liberally throughout.
- **Grayscale substitutes for spatial separation**: where a chromatic system might use color to separate zones, Attio uses luminance steps (`#FFFFFF` → `#F9FAFB` → `#F4F5F7`) so that dense adjacent regions (sidebar, toolbar, table) stay visually distinct without needing large gutters.
- **Marketing pages get more air**: hero and feature sections on the marketing site use generous 64px+ vertical spacing, a conscious contrast to the tight in-app table density — the two "modes" of the product (sell vs. use) have distinct spatial rhythms.

### Border Radius Scale
- Small (6px): data tag pills, filter chips
- Standard (8px): icon buttons, small containers, dropdown triggers
- Comfortable (10px): buttons, inputs, cards — the dominant radius in the system
- Panel (12px): marketing feature cards, larger modals
- Full Pill (9999px): count badges only
- Circle: avatars (initials-based, common in CRM contexts for contact/company records)

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, `1px solid #D3D8DF` border only | Cards, table cells, default state |
| Hover (Level 1) | `0 2px 6px rgba(32,33,36,0.06)` | Card hover, row hover |
| Dropdown (Level 2) | `0 6px 16px rgba(32,33,36,0.10)` | Filter menus, column config popovers |
| Modal (Level 3) | `0 16px 32px rgba(32,33,36,0.16)` | Record detail modals, create-record dialogs |
| Focus Ring | `0 0 0 3px rgba(32,33,36,0.08)` | Keyboard focus on inputs and active table cells |

**Shadow Philosophy**: Like Hugging Face and Granola, elevation shadows use the system's own ink color (`rgba(32,33,36,...)`) rather than pure black, but at notably lower opacity than either — Attio's shadows are the most restrained of the three, reflecting a product where the table grid itself (borders + luminance steps) does almost all of the structural work, and shadows are reserved strictly for genuinely floating layers (dropdowns, modals).

## 7. Do's and Don'ts

### Do
- Keep the palette achromatic outside of status dots and user-assigned data tags — grayscale carries hierarchy, not hue
- Use `#202124` sparingly as the system's single strong accent — primary buttons and top-level emphasis only
- Design tables with hairline borders (`#CAD0D9`) and luminance-step headers (`#F4F5F7`) rather than zebra striping by default
- Treat 12–13px as legitimate, well-supported UI sizes — optimize line-height and padding for density, don't default everything to 16px
- Use InterDisplay only at 20px and above; drop to standard Inter below that threshold
- Keep button/input radius in the 8–10px range — rounded enough to feel current, not so round it reads as casual/consumer
- Reserve saturated chromatic tag colors exclusively for user-generated categories (pipeline stages, custom tags)

### Don't
- Don't introduce a blue/teal "brand color" for chrome — the system's only strong color is achromatic near-black
- Don't use pure black (`#000000`) — always the softer `#202124` / `#2E3238` ink tones
- Don't inflate table row height or cell padding "for breathing room" — compact 36px rows are a deliberate density feature, not a limitation to fix
- Don't apply oversized display type the way Granola does — Attio's 80px H1 is already the system's ceiling; don't push past it
- Don't add heavy shadows to table cells or standard cards — hairline borders plus luminance-step backgrounds are the correct tool
- Don't mix more than the sanctioned weight ladder (400/500/600) — no 700 bold in core UI
- Don't let user-tag colors bleed into system chrome — data-category hues stay confined to tags/pipeline labels only

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|--------------|
| Mobile | <640px | Marketing: single column, H1 drops to ~40px. In-app: sidebar collapses, table becomes horizontally scrollable card-list |
| Tablet | 640–1024px | Sidebar becomes collapsible/overlay, table view remains scrollable |
| Desktop | 1024–1440px | Full sidebar + table layout, standard column widths |
| Large Desktop | >1440px | Table gains additional visible columns before requiring horizontal scroll |

### Touch Targets
- Buttons maintain 40px+ minimum tap height on mobile despite 10px desktop padding defaults
- Table rows on mobile shift to 44px+ effective tap height (comfortable density mode auto-enabled on touch)
- Icon buttons expand from 28px to 36px minimum on touch devices

### Collapsing Strategy
- Marketing H1: 80px → 56px → 40px across breakpoints
- Sidebar: persistent (desktop) → collapsible drawer (tablet) → bottom nav or hamburger (mobile)
- Table: full multi-column grid (desktop) → horizontally scrollable with sticky first column (tablet) → card-per-record stacked list (mobile), trading table density for readability at small viewports
- Toolbar filter chips wrap to a second row rather than truncating on narrower viewports

## 9. Agent Prompt Guide

### Quick Color Reference
- Page background: White (`#FFFFFF`)
- Primary text: Near-black Charcoal (`#2E3238`)
- Secondary text: Mid Gray (`#6F7988`)
- Primary button: Ink Black (`#202124`) with `#F3F4F6` text, `#505967` border
- Secondary button: White with `#CAD0D9` border
- Table border: `#CAD0D9`
- Standard border: `#D3D8DF`
- Sidebar/panel background: `#F4F5F7`
- Status dots: success `#16A34A`, warning `#D97706`, error `#DC2626`

### Example Component Prompts
- "Create a primary button: `#202124` background, `#F3F4F6` text, `1px solid #505967` border, 10px radius, 10px 18px padding, 14px Inter weight 600."
- "Design a data table: white background, `1px solid #CAD0D9` cell borders, `#F4F5F7` header row with 12px weight 500 `#6F7988` labels, 36px row height, 13px Inter weight 400 cell text in `#2E3238`, hover row background `#F9FAFB`."
- "Build a secondary button: white background, `1px solid #CAD0D9` border, `#2E3238` text, 10px radius, 10px 18px padding, hover border `#A4ADBA`."
- "Create an in-app layout: fixed 260px sidebar on `#F4F5F7` background with 14px weight 500 nav items in `#6F7988` (active item `#2E3238` text on white pill), main content area white with a dense record table."
- "Design a hero section: white background, InterDisplay headline at 80px weight 600, line-height 1.05, color `#2E3238`. Subtitle 16px Inter weight 400, color `#6F7988`. Primary ink-black button and white secondary button side by side."

### Iteration Guide
1. Default every UI surface to grayscale first — only reach for chromatic color for status dots or user-generated tag data
2. Use InterDisplay above 20px, standard Inter at and below 20px — treat the switch as a hard rule, not a suggestion
3. For any table/grid component, default to 36px compact rows with hairline `#CAD0D9` borders before considering zebra striping or heavier shadows
4. Keep the weight ladder to 400/500/600 — never introduce 700 bold in core product UI
5. Primary button is always `#202124` with `#F3F4F6` text and a `#505967` border — don't substitute pure black or pure white
6. Respect the 8–10px radius band for buttons/inputs/cards; only count badges get full-pill radius
7. Shadows stay low-opacity and ink-tinted (`rgba(32,33,36,...)`) — reserve them for dropdowns and modals, not standard cards or table cells
</content>
