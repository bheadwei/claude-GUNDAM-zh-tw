# Design System Inspired by Hugging Face

## 1. Visual Theme & Atmosphere

Hugging Face's website reads like an open-source community bulletin board that happens to be beautifully organized: a nearly-white canvas (`#FFFFFF`) carrying dense grids of models, datasets, and Spaces, each rendered as a compact card or list row. The tone is unmistakably *friendly engineering* — the visual language of a lab notebook shared in public, not a polished enterprise SaaS. Where Linear treats darkness as its native medium, Hugging Face treats **density with warmth** as its native medium: hundreds of tag pills, avatar chips, and download counters coexist on one screen without feeling like clutter, because the underlying grayscale system is disciplined and the brand's signature yellow (`#FFD21E`) is deployed sparingly — as an identity cue, not a background wash.

The typography system runs on **Source Sans Pro**, a humanist sans that reads as approachable and slightly less corporate than Inter or Helvetica. Headlines sit at a moderate 60px (nowhere near Linear's 72px aggression) with regular weight and no exotic letter-spacing — the type system is quiet on purpose, so the yellow logo mark and the 🤗 emoji-as-brand-character can do the emotional work. Body copy runs at a comfortable 18px, favoring legibility over drama. This is design for scanning: researchers skimming thousands of model cards need clarity, not spectacle.

The color system is almost entirely achromatic — near-black slate text (`#101828`, `#141C2E`) on white, with a full ladder of mid-grays for secondary content and borders — punctuated by two chromatic notes: the brand yellow (`#FFD21E`) for logo/highlight moments, and a warmer amber (`#FF9D00`) that appears in badges and hover accents. Crucially, buttons do **not** default to yellow — the primary button is a **low-key light-gray pill** (`#E5E7EB`), and the true high-emphasis action uses an inverted **near-black pill** (`#0B0F19`) with a soft shadow. This inversion (gray-first, black-for-emphasis, yellow-for-brand-only) is the single most distinctive trait of the system and must not be flattened into "yellow buttons everywhere."

**Key Characteristics:**
- Light-mode-native: pure white page background (`#FFFFFF`), no dark mode default
- Source Sans Pro throughout — humanist, community-friendly, unshowy
- Brand yellow `#FFD21E` reserved for logo, emoji-brand moments, and rare highlight badges — never as a UI background workhorse
- Secondary amber `#FF9D00` for warm accents, hover glows, "trending" badges
- Primary button is **light gray** (`#E5E7EB`), not yellow — a deliberately understated default action
- Secondary/emphasis button is **near-black pill** (`#0B0F19`) with white text and a pronounced soft shadow — the true "look at me" affordance
- Dense list/grid layouts: tag pills, model cards, avatar stacks, download/like counters packed tightly but legibly
- 8px base spacing unit, 8px standard radius — friendly rounded corners, never sharp, never pill-everything
- Inputs use inset shadows on light-gray borders for a "recessed paper" feel

## 2. Color Palette & Roles

### Background Surfaces
- **Page White** (`#FFFFFF`): The default canvas — nearly every page, card, and panel starts here.
- **Soft Gray Surface** (`#F9FAFB`): Subtle section backgrounds, alternating list rows, code block backgrounds.
- **Card Border Gray** (`#E5E7EB`): The workhorse gray — used as both a border color and the default button fill.
- **Inset Panel** (`#F3F4F6`): Slightly deeper gray for nested containers, filter sidebars.

### Text & Content
- **Primary Text** (`#101828`): Near-black deep slate — headlines, primary body copy, model names.
- **Secondary Text** (`#141C2E`): A hair warmer/deeper variant used interchangeably with primary for dense UI labels.
- **Tertiary Text** (`#6A7282`): Muted slate-gray for links, metadata, secondary descriptions.
- **Quaternary Text** (`#9CA3AF`): Faint gray for placeholders, disabled states, timestamps.

### Brand & Accent
- **Brand Yellow** (`#FFD21E`): The Hugging Face identity color — logo, 🤗 emoji moments, "new" badges, rare highlight underlines. Used as a *point*, never a *field*.
- **Warm Amber** (`#FF9D00`): Secondary brand warmth — hover states on yellow elements, trending/popular badges, gradient companion to `#FFD21E`.
- **Black Emphasis** (`#0B0F19`): Inverted near-black used for the highest-emphasis button and key CTAs — the system's true "primary" action color despite not being chromatic.

### Status Colors (inferred, community-platform conventions)
- **Success Green** (`#16A34A`): Model "verified"/"safe" badges, successful task states.
- **Warning Amber** (`#D97706`): Deprecation notices, gated-model warnings.
- **Error Red** (`#DC2626`): Failed inference, broken Space status dots.

### Border & Divider
- **Standard Border** (`#E5E7EB`): Card outlines, table dividers, input borders — the single most reused hex in the system.
- **Subtle Divider** (`#F3F4F6`): Barely-there separators between list rows.
- **Focus Ring** (`rgba(255,210,30,0.35)`): Soft yellow halo on keyboard focus — one of the few places yellow appears at scale, and only as a translucent ring.

### Overlay
- **Modal Backdrop** (`rgba(16,24,40,0.5)`): Medium-weight dark overlay for dialogs, using the primary text color at reduced opacity rather than pure black.

## 3. Typography Rules

### Font Family
- **Primary**: `"Source Sans Pro", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif`
- **Monospace**: `"IBM Plex Mono", ui-monospace, "SF Mono", Consolas, monospace` — for model IDs, code snippets, file paths, hashes
- **Emoji/Brand**: The 🤗 emoji is treated as a first-class brand glyph and appears inline with headings and buttons — not decorative, structural.

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| Hero H1 | Source Sans Pro | 60px (3.75rem) | 600 | 1.10 | Landing page headline only |
| H2 | Source Sans Pro | 36px (2.25rem) | 600 | 1.20 | Section headers |
| H3 | Source Sans Pro | 28px (1.75rem) | 600 | 1.25 | Sub-section, model card group headers |
| H4 | Source Sans Pro | 22px (1.38rem) | 600 | 1.30 | Card titles, panel headers |
| Body Large | Source Sans Pro | 18px (1.13rem) | 400 | 1.60 | Intro paragraphs, feature descriptions |
| Body | Source Sans Pro | 16px (1.00rem) | 400 | 1.50 | Standard reading text |
| Body Medium | Source Sans Pro | 16px (1.00rem) | 600 | 1.50 | Emphasized inline text, nav links |
| Small | Source Sans Pro | 14px (0.88rem) | 400 | 1.50 | Card descriptions, list rows |
| Caption | Source Sans Pro | 13px (0.81rem) | 400 | 1.40 | Metadata: downloads, likes, updated-at |
| Label | Source Sans Pro | 12px (0.75rem) | 600 | 1.30 | Tag pill text, badge labels |
| Micro | Source Sans Pro | 11px (0.69rem) | 500 | 1.30 | Tiny counters, superscript badges |
| Mono Body | IBM Plex Mono | 14px (0.88rem) | 400 | 1.50 | Code snippets, config blocks |
| Mono Label | IBM Plex Mono | 12px (0.75rem) | 400 | 1.40 | Model repo IDs, commit hashes |

### Principles
- **No exotic letter-spacing**: unlike Linear's aggressive tracking, Hugging Face keeps letter-spacing at `normal` throughout — the humanist sans doesn't need compression to feel premium.
- **Weight ladder is short**: primarily 400 (read) and 600 (emphasize) — no 500, no 700 outside of rare hero moments. This restraint keeps dense pages calm.
- **Legibility over drama**: at 18px body-large, line-height 1.60 ensures long research-paper-adjacent copy stays readable at scanning speed.
- **Monospace signals data, not decoration**: IBM Plex Mono appears exclusively for machine-readable strings (model IDs, hashes) so users instantly know "this is copyable/exact."

## 4. Component Stylings

### Buttons

**Primary Button (Default — Light Gray)**
- Background: `#E5E7EB`
- Text: `#101828`
- Padding: 10px 16px
- Radius: 8px
- Border: none
- Hover: background darkens to `#D1D5DB`
- Use: Most in-context actions — "Follow", "Star", "Duplicate" — the *default* button, deliberately low-key

**Secondary/Emphasis Button (Inverted Black Pill)**
- Background: `#0B0F19`
- Text: `#FFFFFF`
- Padding: 12px 24px
- Radius: 9999px (full pill)
- Shadow: `0 4px 14px rgba(11,15,25,0.25)` (pronounced soft shadow)
- Hover: background lightens slightly to `#1F2430`, shadow deepens
- Use: The true high-emphasis CTA — "Sign Up", "Deploy on Spaces", hero-section actions

**Ghost/Text Button**
- Background: transparent
- Text: `#6A7282`
- Padding: 8px 12px
- Radius: 8px
- Hover: text darkens to `#101828`, background tints `#F9FAFB`
- Use: Tertiary nav actions, "Learn more" links

**Icon Button**
- Background: `#F3F4F6`
- Text: `#101828`
- Radius: 50%
- Size: 32px × 32px
- Border: `1px solid #E5E7EB`
- Use: Copy-to-clipboard, share, bookmark toggles

### Cards & Containers
- Background: `#FFFFFF`
- Border: `1px solid #E5E7EB`
- Radius: 8px
- Shadow: none by default (borders do the elevation work); hover adds `0 2px 8px rgba(16,24,40,0.06)`
- Padding: 16–20px
- Model/Dataset cards: title (H4) + tag pill row + metadata caption row (downloads, likes, updated) — a strict three-zone layout repeated thousands of times per page

### Inputs & Forms

**Text Input**
- Background: `#FFFFFF`
- Border: `1px solid #E5E7EB`
- Radius: 8px
- Padding: 10px 12px
- Shadow: `inset 0 1px 2px rgba(16,24,40,0.05)` (subtle recessed "paper" feel)
- Focus: border becomes `#101828`, focus ring `0 0 0 3px rgba(255,210,30,0.35)` (the rare large-scale yellow moment)

**Search Bar**
- Background: `#F9FAFB`
- Border: `1px solid #E5E7EB`
- Radius: 8px (search-specific instances may use 9999px pill for the global top-nav search)
- Padding: 10px 16px 10px 40px (icon-aware left padding)
- Text: `#101828`, placeholder `#9CA3AF`

### Tags & Pills

**Tag Pill (Category/Task Label)**
- Background: `#F3F4F6`
- Text: `#374151`
- Padding: 4px 10px
- Radius: 9999px
- Border: `1px solid #E5E7EB`
- Font: 12px weight 500
- Use: Task tags ("text-generation", "image-classification"), library tags, license tags — the single most repeated component on the site

**Brand Highlight Badge**
- Background: `#FFD21E`
- Text: `#0B0F19`
- Padding: 2px 8px
- Radius: 6px
- Font: 11px weight 700
- Use: "NEW", "Trending", editorial highlight badges — this is where yellow gets to be a *field* instead of a point, but only at tiny badge scale

**Avatar Stack**
- Circular avatars, 24px diameter, `-8px` overlap, `2px solid #FFFFFF` ring between avatars
- Use: Contributor lists, organization member previews

### Navigation
- Sticky white header, `1px solid #E5E7EB` bottom border, no shadow
- Logo: 🤗 mark + wordmark, left-aligned
- Center: global search bar (pill-shaped, `#F9FAFB` background)
- Right: nav links (Body Medium, `#101828`) + primary gray button ("Sign Up") + black pill button ("Log In" or "Deploy")
- Mobile: hamburger collapse below 768px

## 5. Layout Principles

### Spacing System
- Base unit: 8px
- Scale: 4px, 8px, 12px, 16px, 20px, 24px, 32px, 40px, 48px, 64px
- Dense grids (model cards) use tighter 12–16px gutters; marketing sections use 48–64px vertical rhythm

### Grid & Container
- Max content width: ~1280px for marketing, full-bleed with sidebar for app/dashboard views
- Model/dataset browse pages: responsive card grid, 3–4 columns desktop, 1 column mobile
- List views (search results): single-column dense rows, each row ~80–96px tall with avatar + title + tags + metadata

### Whitespace Philosophy
- **Density is the feature, not the bug**: unlike marketing-first sites with generous whitespace, Hugging Face's core product pages are intentionally dense — researchers need to scan hundreds of items quickly.
- **Marketing pages breathe more**: landing/about pages use 64px+ section spacing and more generous padding, contrasting with the dense app views.
- **Borders substitute for whitespace**: with `#E5E7EB` borders doing most of the separation work, cards can sit closer together than a shadow-only system would allow.

### Border Radius Scale
- Small (6px): highlight badges, inline chips
- Standard (8px): buttons (default), cards, inputs — the dominant radius in the system
- Full Pill (9999px): emphasis buttons, tag pills, search bars
- Circle (50%): avatars, icon buttons

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, `1px solid #E5E7EB` border only | Cards, default state |
| Hover (Level 1) | `0 2px 8px rgba(16,24,40,0.06)` | Card hover, list row hover |
| Button Emphasis (Level 2) | `0 4px 14px rgba(11,15,25,0.25)` | Black pill CTA |
| Dropdown/Popover (Level 3) | `0 8px 24px rgba(16,24,40,0.12)` | Menus, tooltips, autocomplete |
| Modal (Level 4) | `0 20px 40px rgba(16,24,40,0.18)` | Dialogs, model-download modals |
| Inset (Input) | `inset 0 1px 2px rgba(16,24,40,0.05)` | Text inputs, textareas |

**Shadow Philosophy**: Elevation in this system is achieved primarily through **borders**, not shadows — a light-mode inverse of Linear's border-as-shadow technique. Shadows are reserved for genuinely floating elements (modals, the black CTA button, dropdowns) and are always warm-neutral (`rgba(16,24,40,...)`, the primary text color at low opacity) rather than pure black, keeping the whole system feeling soft rather than harsh.

## 7. Do's and Don'ts

### Do
- Keep the primary/default button **light gray** (`#E5E7EB`) — resist the urge to make everything yellow
- Reserve `#FFD21E` for logo, small badges, and focus rings — a *point* of color, not a field
- Use the inverted black pill (`#0B0F19`) for genuine high-emphasis CTAs only
- Lean on `#E5E7EB` borders for structure before reaching for shadows
- Keep type weights to 400/600 — avoid introducing 500 or 700 outside hero moments
- Use IBM Plex Mono exclusively for machine-readable strings (IDs, hashes, code)
- Allow dense grids on product/browse pages — whitespace is for marketing pages, not search results

### Don't
- Don't default buttons to yellow — the actual system inverts this expectation on purpose
- Don't use pure black (`#000000`) — text and emphasis elements use warm near-blacks (`#101828`, `#0B0F19`)
- Don't apply aggressive negative letter-spacing — Source Sans Pro stays at normal tracking
- Don't stack more than two chromatic accents (`#FFD21E`, `#FF9D00`) — everything else is grayscale
- Don't use heavy drop shadows on cards by default — borders carry the structure
- Don't cram marketing/hero sections as densely as product list pages — they need different rhythm

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|--------------|
| Mobile | <640px | Single-column cards, hamburger nav, stacked search |
| Tablet | 640–1024px | 2-column card grid, condensed nav links |
| Desktop | 1024–1280px | 3-column card grid, full nav |
| Large Desktop | >1280px | 4-column card grid, generous margins |

### Touch Targets
- Buttons maintain 40px+ minimum tap height on mobile
- Tag pills gain extra horizontal padding (12px) on touch devices
- Avatar stacks collapse to a single "+N" badge on narrow viewports

### Collapsing Strategy
- Hero H1: 60px → 40px → 32px across breakpoints
- Card grid: 4 → 3 → 2 → 1 columns
- Navigation: horizontal links + search → hamburger + collapsed search icon at <640px
- Metadata rows (downloads/likes/updated) truncate to icon-only on mobile

## 9. Agent Prompt Guide

### Quick Color Reference
- Page background: White (`#FFFFFF`)
- Primary text: Deep Slate (`#101828`)
- Secondary text: Muted Slate (`#6A7282`)
- Default button: Light Gray (`#E5E7EB`) with dark text
- Emphasis button: Near-Black Pill (`#0B0F19`) with white text
- Brand accent: Yellow (`#FFD21E`) — badges/logo only
- Secondary accent: Amber (`#FF9D00`)
- Border: `#E5E7EB`
- Focus ring: `rgba(255,210,30,0.35)`

### Example Component Prompts
- "Create a model card: white background, `1px solid #E5E7EB` border, 8px radius, 16px padding. Title at 22px Source Sans Pro weight 600, color `#101828`. Below it, a row of tag pills (`#F3F4F6` background, `#374151` text, 9999px radius, 12px weight 500). Bottom row: caption-size (13px) metadata in `#6A7282` showing downloads and likes."
- "Design a hero CTA row: light-gray default button (`#E5E7EB` bg, `#101828` text, 8px radius, 10px 16px padding) next to a black pill emphasis button (`#0B0F19` bg, white text, 9999px radius, 12px 24px padding, shadow `0 4px 14px rgba(11,15,25,0.25)`)."
- "Build a search input: `#F9FAFB` background, `1px solid #E5E7EB` border, 8px radius, 10px 16px padding with left icon space, inset shadow `inset 0 1px 2px rgba(16,24,40,0.05)`."
- "Create a sticky navigation: white background, `1px solid #E5E7EB` bottom border. Center search pill, right-aligned nav links at 16px weight 600 color `#101828`, plus gray default button and black pill CTA."
- "Design a 'NEW' highlight badge: `#FFD21E` background, `#0B0F19` text, 6px radius, 2px 8px padding, 11px weight 700 — the only place yellow fills a solid area."

### Iteration Guide
1. Default to light-gray buttons; escalate to the black pill only for the single most important action on a screen
2. Treat `#FFD21E` as a spot color — logo, tiny badges, focus rings — never a large fill
3. Keep letter-spacing normal everywhere; Source Sans Pro doesn't need tracking tricks
4. Use `#E5E7EB` borders as the primary structural tool before adding shadows
5. Reserve IBM Plex Mono for anything a user might copy-paste (IDs, hashes, commands)
6. Product/browse pages can be dense (12–16px gutters); marketing pages need more air (48–64px sections)
7. Keep the weight ladder to 400/600 — resist adding 500 or 700 for "just a bit more emphasis"
</content>
