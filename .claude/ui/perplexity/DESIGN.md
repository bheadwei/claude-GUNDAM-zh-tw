# Design System Inspired by Perplexity

## 1. Visual Theme & Atmosphere

Perplexity's product is a knowledge instrument disguised as a search box — the visual language reads like a well-bound reference book rather than a typical tech dashboard. The canvas is a warm, paper-like off-white (`#FCFCF9`), never clinical pure white, evoking the cream stock of a printed page. Against this paper ground, a single deep teal — True Turquoise (`#016A71` / brand variant `#20808D`) — carries almost all of the interface's chromatic weight, appearing on links, active states, focus rings, and the brand mark. Everything else recedes into warm near-black ink (`#091717` / `#27251E`) for text and soft sage-teal (`#8EBEC3`) for secondary accents.

The typography leans on Perplexity's proprietary `pplxSans`, a humanist grotesque with slightly rounded terminals that feels more "editorial" than "SaaS." Sizes stay conservative (base 16px) and weight contrast does the heavy lifting instead of color — the interface trusts hierarchy through scale and ink density, the way a book trusts typography over decoration. Buttons and inputs are markedly rounded: secondary actions default to full pill shape (`9999px`), giving every interactive control a soft, tactile, almost stationery-like quality — think library card catalog meets modern research tool.

The overall feeling is "quiet authority": a workspace built for reading and synthesis, where the UI gets out of the way of the answer. Dark mode inverts this palette into a near-black ink well (`#100E12`) with the same teal accent surviving as a glowing thread — Perplexity is one of the few AI products where the light mode, not the dark mode, is the primary/default identity.

**Key Characteristics:**
- Paper-warm canvas: `#FCFCF9` light background — never pure white, always a hint of cream
- Single chromatic accent: True Turquoise `#016A71` (UI accent) / `#20808D` (brand mark) — used sparingly and with intent
- Proprietary `pplxSans` typeface, humanist grotesque, system-ui fallback stack
- Warm off-black ink for text: `#091717` (near-black) and `#27251E` (warm brown-black on pill labels)
- Full-pill secondary buttons (`9999px` radius) — a soft, book-like tactility
- 4px base spacing unit, 8px default border radius on cards/containers
- Dark mode inverts to `#100E12` off-black, teal accent persists as the sole warm/cool contrast
- Sage-teal secondary accent `#8EBEC3` for subtle highlights, backgrounds, and supporting UI
- Content-first, chrome-minimal: the answer/text column is the hero, navigation recedes

## 2. Color Palette & Roles

### Background Surfaces
- **Paper White** (`#FCFCF9`): Primary page background in light mode — warm off-white with a barely-perceptible cream cast, the "paper" the whole system sits on.
- **Card Surface** (`#FFFFFF` / `#F7F6F1`): Slightly lifted surfaces — cards, dropdowns, modals — either pure white or a warmer cream depending on elevation.
- **Offblack** (`#091717`): Deep near-black ink used as the darkest surface anchor and as the dominant text color.
- **Dark Mode Canvas** (`#100E12`): Primary background in dark mode — a warm, near-black charcoal, not a cold blue-black.
- **Dark Surface Elevated** (`#1B1A1E`): Cards and panels in dark mode, one step lighter than the canvas.

### Text & Content
- **Primary Text** (`#000000` / `#091717`): Default reading text — true black on paper white for maximum legibility, echoing print typography.
- **Warm Secondary Text** (`#27251E`): Warm brown-black used on pill buttons and secondary labels — softer than pure black.
- **Muted Text** (`#5B5A54`): De-emphasized text — captions, metadata, timestamps.
- **Dark Mode Text** (`#F7F6F1`): Primary text on dark backgrounds — warm off-white, not pure white.

### Brand & Accent
- **True Turquoise (UI Accent)** (`#016A71`): The primary interactive color — links, focus states, active navigation, selected pills, CTA text.
- **Brand Turquoise (Mark)** (`#20808D`): Slightly lighter teal used in the logo/wordmark and larger brand moments.
- **Sage Teal** (`#8EBEC3`): Secondary accent — subtle backgrounds, hover tints, supporting chart/status color.
- **Link Blue** (`#1A73E8`): Reserved specifically for hyperlinks/citations within answer text — distinct from the UI accent to keep "sources" visually separable from "actions."

### Status Colors
- **Success Teal** (`#016A71` at reduced opacity): Reuses the brand accent for success states rather than introducing green — keeps the palette disciplined.
- **Warning Amber** (`#B36B00`): Used sparingly for rate-limit or caution banners.
- **Error Red** (`#C0392B`): Reserved strictly for destructive/error states.

### Border & Divider
- **Border Default** (`#E7E5DE`): Warm light gray border — cards, input outlines, table dividers.
- **Border Subtle** (`rgba(9,23,23,0.08)`): Semi-transparent ink border for the lightest separations.
- **Border Dark Mode** (`rgba(247,246,241,0.10)`): Equivalent subtle border on dark surfaces.

### Overlay
- **Overlay Light** (`rgba(9,23,23,0.4)`): Modal/dialog backdrop in light mode — warm-tinted dark scrim.
- **Overlay Dark** (`rgba(0,0,0,0.6)`): Modal backdrop in dark mode.

## 3. Typography Rules

### Font Family
- **Primary**: `pplxSans`, with fallback stack: `system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif`
- **Monospace**: `"pplxMono", ui-monospace, "SF Mono", Menlo, monospace` (for code/citations formatting)
- **Base size**: 16px — Perplexity keeps body text at a comfortable reading size, never dropping below 14px for primary content.

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| Display | pplxSans | 56px (3.5rem) | 600 | 1.10 | Marketing hero headlines |
| Heading 1 | pplxSans | 36px (2.25rem) | 600 | 1.20 | Page titles |
| Heading 2 | pplxSans | 28px (1.75rem) | 600 | 1.25 | Section titles |
| Heading 3 | pplxSans | 22px (1.375rem) | 600 | 1.30 | Card headers, answer sub-sections |
| Answer Body | pplxSans | 17px (1.06rem) | 400 | 1.65 | The core "answer" reading column — generous line-height for long-form synthesis |
| Body | pplxSans | 16px (1.00rem) | 400 | 1.55 | Standard UI text |
| Body Medium | pplxSans | 16px (1.00rem) | 500 | 1.55 | Emphasized labels, active nav |
| Small | pplxSans | 14px (0.88rem) | 400 | 1.50 | Secondary text, form labels |
| Caption | pplxSans | 13px (0.81rem) | 400 | 1.45 | Timestamps, citation numbers, metadata |
| Micro | pplxSans | 12px (0.75rem) | 500 | 1.40 | Pill labels, badges |
| Link | pplxSans | inherit | 400–500 | inherit | Color `#1A73E8`, underline on hover only |

### Principles
- **Reading-first sizing**: The core answer column never drops below 16-17px body text — this is a reading product, not a dense dashboard.
- **Weight over color for hierarchy**: Headings use 600, body uses 400, emphasis uses 500 — color is reserved for the teal accent, not for creating text hierarchy.
- **Generous line-height on long-form content**: Answer body text runs 1.65 line-height to keep multi-paragraph AI responses scannable and book-like.
- **No display-size letter-spacing tricks**: Unlike geometric-obsessed systems, pplxSans is used at normal tracking throughout — the personality comes from warmth of color, not typographic compression.

## 4. Component Stylings

### Buttons

**Primary Button**
- Background: `#016A71` (True Turquoise)
- Text: `#FCFCF9` (paper white)
- Padding: 10px 20px
- Radius: 9999px (full pill)
- Hover: background darkens to `#014F54`
- Use: Primary CTAs ("Ask", "Sign up", "Try Pro")

**Secondary Button (Pill)**
- Background: transparent
- Text: `#27251E` (warm ink)
- Border: `1px solid #E7E5DE`
- Padding: 8px 16px
- Radius: 9999px (full pill — the signature shape)
- Hover: background tints to `rgba(1,106,113,0.06)`
- Use: Secondary actions, filter toggles, source-type selectors

**Ghost / Text Button**
- Background: transparent
- Text: `#016A71`
- Padding: 6px 10px
- Radius: 6px
- Use: Inline actions within answer text, "Copy", "Share"

**Icon Button**
- Background: transparent or `rgba(9,23,23,0.04)`
- Radius: 50% (circle)
- Size: 32px–40px square hit area
- Hover: background `rgba(9,23,23,0.06)`
- Use: Toolbar icons, thumbs up/down, regenerate

### Cards & Containers
- Background: `#FFFFFF` on the `#FCFCF9` page canvas — a subtle luminance step, not a shadow-driven separation
- Border: `1px solid #E7E5DE`
- Radius: 8px (standard cards), 16px (feature/marketing cards)
- Shadow: `0px 1px 2px rgba(9,23,23,0.04)` — extremely light, paper never "floats" aggressively
- Hover: border darkens slightly to `#D6D3C9`, no dramatic elevation change

### Inputs & Forms

**Search / Ask Bar (Signature Component)**
- Background: `#FFFFFF`
- Border: `1px solid #E7E5DE`, focus state `1px solid #016A71`
- Padding: 16px 20px
- Radius: 24px (large pill/rounded-rect — the anchor of the entire product)
- Shadow: `0px 2px 8px rgba(9,23,23,0.06)` on focus
- Placeholder text: `#5B5A54`

**Standard Input**
- Background: `#FFFFFF`
- Border: `1px solid #E7E5DE`
- Padding: 10px 14px
- Radius: 8px
- Focus: border `#016A71`, subtle glow `0 0 0 3px rgba(1,106,113,0.12)`

### Badges & Pills
- Background: `rgba(1,106,113,0.08)` (tinted teal)
- Text: `#016A71`
- Padding: 4px 10px
- Radius: 9999px
- Font: 12px weight 500
- Use: Source-type tags, citation counters, "Pro" badges

### Navigation
- Fixed dark-ink left rail (`#091717`, ~256px wide on desktop) housing the wordmark, product icons, and a teal-tinted "Sign In" pill anchored at the bottom
- Icons: monochrome, brighten to teal `#016A71` on active/hover
- Top-level product switches (Search / Discover / Spaces) rendered as pill tabs
- Mobile: rail collapses to a bottom tab bar or hamburger

### Citation & Source Treatment
- Inline citation markers: small superscript numbered pills, teal background `rgba(1,106,113,0.10)`, teal text
- Source cards: compact horizontal cards with favicon, domain name (`#5B5A54`), and title (`#091717`) — radius 8px, border `#E7E5DE`

## 5. Layout Principles

### Spacing System
- Base unit: 4px
- Scale: 4px, 8px, 12px, 16px, 20px, 24px, 32px, 40px, 48px, 64px
- Primary rhythm: 8px and 16px multiples for component-internal spacing; 32px/48px for section rhythm

### Grid & Container
- Answer column max-width: ~680–720px — deliberately narrow, optimized for reading, not full-bleed
- Marketing max content width: ~1200px
- Left rail (fixed) + main content column layout on desktop app views
- Feature grids: 2–3 columns on marketing pages

### Whitespace Philosophy
- **Paper margins, not dashboard density**: The reading column behaves like a printed page — generous side margins, comfortable line length (~65-75 characters).
- **Chrome recedes, content leads**: Navigation and toolbars are deliberately understated in scale and color so the answer text carries the visual weight.
- **Breathing room around the ask bar**: The search/ask input always has generous vertical padding around it, reinforcing its role as the product's anchor.

### Border Radius Scale
- Small (6px): Ghost buttons, inline chips
- Standard (8px): Cards, inputs, badges base
- Comfortable (16px): Feature cards, larger containers
- Ask Bar (24px): The signature large input shape
- Full Pill (9999px): Secondary buttons, tags, filter pills

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, `#FCFCF9` bg | Page canvas |
| Card (Level 1) | `0px 1px 2px rgba(9,23,23,0.04)` | Standard cards, source cards |
| Ask Bar Focus (Level 2) | `0px 2px 8px rgba(9,23,23,0.06)` | Focused search input |
| Dropdown (Level 3) | `0px 4px 16px rgba(9,23,23,0.10)` | Menus, popovers |
| Modal (Level 4) | `0px 8px 32px rgba(9,23,23,0.16)` | Dialogs, share sheets |

**Shadow Philosophy**: Elevation stays deliberately restrained — shadows are warm-tinted (using the ink color `#091717` rather than pure black) and low-opacity, echoing how a piece of paper casts a soft shadow rather than a UI panel "floating." The teal accent never appears in shadows — depth is achieved entirely through neutral warm-gray shadow layering plus border contrast.

## 7. Do's and Don'ts

### Do
- Keep the canvas warm off-white (`#FCFCF9`), never switch to stark pure white for the page background
- Reserve True Turquoise (`#016A71`) for interactive/brand moments only — links, active states, primary CTAs
- Use full-pill (`9999px`) radius for secondary buttons and tags — it's the system's signature shape
- Keep the answer/reading column narrow (~680-720px) with generous line-height (1.6+)
- Use warm ink tones (`#091717`, `#27251E`) instead of pure black for text where softness is desired
- Let pplxSans (or its system-ui fallback) run at comfortable, book-like sizes — 16-17px minimum for body

### Don't
- Don't introduce a second saturated accent color — teal is the only chromatic identity
- Don't use cold pure white backgrounds — always warm the canvas slightly toward cream
- Don't make the ask bar small or understated — it is the product's hero element and should read as generously sized (24px radius, ample padding)
- Don't use sharp/square corners on secondary buttons — the pill shape is load-bearing for brand recognition
- Don't over-shadow cards — keep elevation subtle and paper-like, never heavy drop shadows
- Don't mix the citation link blue (`#1A73E8`) with the UI accent teal — they serve different semantic roles

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|--------------|
| Mobile | <640px | Left rail collapses to bottom tab bar; ask bar becomes full-width sticky |
| Tablet | 640–1024px | Rail narrows to icon-only; single-column answer view |
| Desktop | 1024–1440px | Full rail with labels; answer column centered at max-width |
| Large Desktop | >1440px | Answer column stays capped at ~720px; extra space becomes margin, not new columns |

### Touch Targets
- Icon buttons maintain minimum 40x40px hit area
- Pill buttons keep 8-10px vertical padding for comfortable tapping
- Ask bar height increases slightly on mobile for easier thumb typing

### Collapsing Strategy
- Left rail (256px) → icon rail (64px) → bottom tab bar as viewport narrows
- Source cards: horizontal row → vertical stack on mobile
- Marketing feature grids: 3-column → 2-column → single column

## 9. Agent Prompt Guide

### Quick Color Reference
- Page Background: Paper White (`#FCFCF9`)
- Primary Accent: True Turquoise (`#016A71`)
- Brand Mark Teal: `#20808D`
- Primary Text: Offblack (`#091717`)
- Secondary Text: `#5B5A54`
- Border: `#E7E5DE`
- Dark Mode Background: `#100E12`
- Dark Mode Text: `#F7F6F1`
- Citation Link Color: `#1A73E8`

### Example Component Prompts
- "Create an ask bar: `#FFFFFF` background, `1px solid #E7E5DE` border (focus: `1px solid #016A71`), 24px radius, 16px 20px padding, placeholder text `#5B5A54` in pplxSans 16px."
- "Design a source card: `#FFFFFF` background, `1px solid #E7E5DE` border, 8px radius, favicon + domain (`#5B5A54` 13px) + title (`#091717` 15px weight 500)."
- "Build a secondary pill button: transparent background, `#27251E` text, `1px solid #E7E5DE` border, 9999px radius, 8px 16px padding, pplxSans 14px weight 500."
- "Create a left navigation rail: `#091717` background, 256px width, monochrome icons that brighten to `#016A71` on active state, teal-tinted 'Sign In' pill anchored bottom."
- "Design an inline citation marker: superscript pill, `rgba(1,106,113,0.10)` background, `#016A71` text, 12px, 9999px radius."

### Iteration Guide
1. Always warm the canvas — `#FCFCF9`, not `#FFFFFF` — for any full-page background
2. True Turquoise (`#016A71`) is the only chromatic accent; everything else stays neutral warm-gray/ink
3. Default to full-pill (`9999px`) for secondary buttons and tags unless the component is a large primary input (use 24px for the ask bar specifically)
4. Keep body/answer text at 16-17px with 1.6+ line-height — this is a reading product first
5. Use pplxSans with a `system-ui` fallback stack for anything not explicitly branded
6. Reserve `#1A73E8` link-blue strictly for citation/source hyperlinks, never for UI chrome actions
7. Dark mode: invert to `#100E12` canvas / `#F7F6F1` text, keep True Turquoise unchanged as the accent
