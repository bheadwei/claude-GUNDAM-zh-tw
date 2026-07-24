# Design System Inspired by Railway

## 1. Visual Theme & Atmosphere

Railway's site feels like standing on a rooftop at 2am looking out over a city of servers — a deep purple-black void (`#13111C`) lit not by cold blues but by warm, saturated violet (`#BF93EC`) glowing like distant neon signage. Where most infra/deploy platforms lean into sterile blue-gray "enterprise cloud" visuals, Railway goes theatrical: the darkness has depth and color temperature, built from layered purples rather than flat black, evoking a night sky with just enough atmosphere to feel inhabited rather than empty. This is deployment infrastructure sold as an experience, not a spec sheet — the emotional register is "shipping code should feel like this," not "here is our uptime SLA."

The typographic system pairs Inter for body and UI text with **IBM Plex Serif** for headlines — the same serif-headline move Zed makes, but deployed for entirely different emotional effect. Where Zed's serif reads as "engineered craftsmanship" against warm paper, Railway's serif reads as "editorial confidence" against a dramatic night sky — closer to a magazine cover than a spec sheet. Headlines run large (54px) and are given room to breathe against the dark canvas, with the serif's higher contrast strokes creating a striking silhouette against the purple-black background that a geometric sans could never achieve.

Color depth is Railway's real technical achievement: rather than one flat purple, the system layers four distinct violet/purple tones — a near-black purple background (`#13111C`), a dark plum for secondary surfaces (`#291839`), a mid-tone accent purple for buttons and borders (`#553F83`), and a bright, saturated lavender (`#BF93EC`) reserved for highlights and glow effects. This creates genuine tonal depth rather than a single hue applied at different opacities — closer to how a real night sky has multiple bands of color from horizon to zenith.

**Key Characteristics:**
- Dark-mode-native, purple-black canvas: `#13111C` background — not neutral black, but color-temperature-warm black with a violet undertone
- Four-tier purple depth system: `#13111C` (deepest bg) → `#291839` (secondary surface) → `#553F83` (mid accent/buttons) → `#BF93EC` (bright highlight/glow)
- Headline font: **IBM Plex Serif** — editorial, magazine-cover confidence against the dark night-sky backdrop
- Body/UI font: Inter — clean, neutral counterpoint to the serif drama
- Generous headline scale: 54px H1, 36px H2 — large enough to dominate the dark canvas
- 4px base spacing grid; radius runs 6–8px — soft enough to feel modern, not sharp
- Border treatment on buttons: visible `#36353E` border even on filled buttons, adding definition against the dark background
- Overall tone: atmospheric, nocturnal, editorial — deployment infrastructure with a night-sky soul

## 2. Color Palette & Roles

### Background Surfaces
- **Void Purple** (`#13111C`): The deepest background — page canvas, hero sections. A near-black with a distinct violet undertone, distinguishing it from neutral or blue-tinted darks.
- **Secondary Surface** (`#291839`): Dark plum used for cards, panels, and secondary button backgrounds — one perceptible step up from the void.
- **Elevated Surface** (`rgba(191,147,236,0.06)`): A faint violet-tinted wash for hover states and subtly elevated interactive elements.

### Text & Content
- **Primary Text** (`#F7F8F8`): Near-white for headlines and primary content — warm enough not to feel clinical against the purple backdrop.
- **Secondary Text** (`#BF93EC` at reduced opacity, or `#A9A6B8`): Muted lavender-gray for body copy and descriptions — ties back to the accent hue even when de-emphasized.
- **Tertiary Text** (`#6E6B7D`): Muted purple-gray for metadata, captions, timestamps.

### Brand & Accent
- **Bright Lavender** (`#BF93EC`): The system's signature glow color — used for highlights, active states, glowing text effects, and accent borders. This is Railway's "neon at night" color.
- **Mid Accent Purple** (`#553F83`): Primary button background and structural accent — a saturated but darker purple than the lavender highlight, providing the main interactive color without competing with the glow accent.
- **Deep Plum** (`#291839`): Secondary surfaces and secondary button backgrounds.

### Border & Divider
- **Button Border** (`#36353E`): A neutral dark gray-purple border applied even to filled primary buttons — Railway's signature "defined edge in the dark" treatment, preventing buttons from blurring into the void background.
- **Card Border** (`rgba(191,147,236,0.12)`): Subtle violet-tinted border for cards and panels.
- **Divider** (`rgba(247,248,248,0.08)`): Standard hairline divider on dark surfaces.

### Status / Utility
- **Success Green** (`#4ADE80`): Deployment success indicators, "live" status dots.
- **Warning Amber** (`#FBBF24`): Build warnings, pending states.
- **Error Red** (`#F87171`): Failed deployments, critical alerts.

## 3. Typography Rules

### Font Family
- **Heading**: `"IBM Plex Serif"`, fallback: `Georgia, Cambria, Times New Roman, serif` — used for all headline levels (H1–H2), never for body or UI chrome
- **Body / UI**: `Inter`, fallback: `-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif`
- **Monospace**: `"JetBrains Mono"` or `ui-monospace`, fallback: `SFMono-Regular, Menlo, Consolas, monospace` — used for logs, build output, CLI commands

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| Hero H1 | IBM Plex Serif | 54px (3.38rem) | 500 | 1.10 | Homepage hero, top marketing statement |
| Section H2 | IBM Plex Serif | 36px (2.25rem) | 500 | 1.15 | Section headers |
| Card H3 | Inter | 22px (1.38rem) | 600 | 1.30 | Card titles, feature headers — intentionally switches to Inter at this level |
| Body Large | Inter | 20px (1.25rem) | 400 | 1.55 | Intro paragraphs, hero subtitles |
| Body | Inter | 16px (1.00rem) | 400 | 1.55 | Standard reading text |
| Body Medium | Inter | 16px (1.00rem) | 500 | 1.55 | Nav links, labels |
| Small | Inter | 14px (0.88rem) | 400 | 1.50 | Secondary UI text, form hints |
| Caption | Inter | 13px (0.81rem) | 400 | 1.45 | Metadata, timestamps |
| Mono Body | JetBrains Mono | 14px (0.88rem) | 400 | 1.55 | Build logs, deploy output |
| Mono Label | JetBrains Mono | 12px (0.75rem) | 500 | 1.40 | CLI snippets, env var tags |

### Principles
- **Serif is reserved for H1/H2 only**: Below the section-header level, everything switches to Inter — this keeps the editorial drama concentrated at the top of the visual hierarchy rather than diluted throughout.
- **Large type against dark space**: Headline sizes (54px/36px) are generous specifically because they need to command attention against the atmospheric dark background — smaller serif type would lose the "magazine cover" effect.
- **Body stays functional**: Inter at 400/500/600 weights only — no attempt to make body copy dramatic; the drama is exclusively a headline-level device.
- **Mono for anything real**: Build logs, deployment output, and CLI examples always render in monospace — reinforcing the platform's technical credibility beneath the atmospheric marketing surface.

## 4. Component Stylings

### Buttons

**Primary Button**
- Background: `#553F83`
- Text: `#F7F8F8`, Inter 16px weight 500
- Padding: 10px 20px
- Radius: 8px
- Border: `1px solid #36353E` — the signature "defined edge in the dark" detail; even a filled button needs a visible border to stay crisp against `#13111C`
- Shadow: `0 2px 8px rgba(85,63,131,0.30)` — soft purple glow beneath, reinforcing the "light source in the dark" feel
- Hover: background lightens toward `#6B4F9E`, border brightens to `rgba(191,147,236,0.4)`
- Use: primary CTAs ("Deploy now", "Start a project")

**Secondary Button**
- Background: `#13111C` (matches void — effectively transparent against page)
- Text: `#F7F8F8`, Inter 16px weight 500
- Padding: 10px 20px
- Radius: 6px
- Border: `1px solid rgba(191,147,236,0.24)`
- Use: secondary actions ("View docs", "Read changelog")

**Ghost Button**
- Background: transparent
- Text: `#BF93EC`
- Padding: 8px 12px
- Use: inline links, nav items, tertiary actions

### Cards & Containers
- Background: `#291839`
- Border: `1px solid rgba(191,147,236,0.12)`
- Radius: 8px (standard), 12px (featured panels)
- Shadow: `0 4px 16px rgba(0,0,0,0.4)` — deep, soft shadow appropriate for dark-on-dark elevation
- Padding: 24px
- Hover (interactive cards): border brightens to `rgba(191,147,236,0.24)`, subtle glow shadow appears: `0 0 24px rgba(191,147,236,0.08)`

### Inputs & Forms

**Text Input**
- Background: `rgba(255,255,255,0.03)`
- Text: `#F7F8F8`, Inter 16px
- Border: `1px solid rgba(191,147,236,0.16)`
- Radius: 6px
- Padding: 10px 14px
- Focus: border transitions to `#BF93EC`, focus ring `0 0 0 3px rgba(191,147,236,0.16)`

**Env Var / Config Input**
- Background: `#13111C`
- Text: JetBrains Mono 14px, `#F7F8F8`
- Border: `1px solid #36353E`
- Radius: 6px
- Use: environment variable editors, CLI-style config fields

### Badges & Status Pills
- Background: matching status color at 12% opacity (e.g., `rgba(74,222,128,0.12)` for success)
- Text: full-opacity status color (e.g., `#4ADE80`)
- Radius: 9999px (pill)
- Padding: 3px 10px
- Font: Inter 12px weight 500
- Use: deployment status ("Live", "Building", "Failed")

### Navigation
- Dark sticky header on `#13111C`, subtle bottom border `1px solid rgba(191,147,236,0.08)`
- Logo left-aligned, wordmark in Inter medium
- Links: Inter 14px weight 500, `#A9A6B8` text, hover to `#F7F8F8`
- CTA: Primary button (purple, bordered) right-aligned
- Mobile: hamburger collapse below 768px

### Image Treatment
- Dashboard/deploy screenshots framed with `1px solid rgba(191,147,236,0.16)` border and soft ambient purple glow shadow behind them
- Architecture diagrams and service graphs rendered with glowing connection lines in `#BF93EC` against the dark canvas — visually reinforcing "network of services" as a literal starfield metaphor

## 5. Layout Principles

### Spacing System
- Base unit: 4px
- Scale: 4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px, 96px
- Primary rhythm: 16px/24px component-internal; 64px/96px section separation

### Grid & Container
- Max content width: ~1180px
- Hero: centered column, serif headline dominant, product/architecture visualization floating beneath with glow effects
- Feature sections: 2–3 column grids, 24px gutters
- Service/architecture diagrams often break container width for full-bleed dramatic effect

### Whitespace Philosophy
- **Night sky as canvas**: Like Linear, darkness is the native medium here — but Railway's darkness has color temperature (violet undertone) rather than being achromatic, giving it atmosphere rather than void.
- **Glow as spacing punctuation**: Empty space around interactive/accent elements often carries a soft radial glow (`box-shadow` blur), making whitespace feel inhabited by ambient light rather than simply empty.
- **Editorial section breaks**: 80–96px vertical padding between sections, each anchored by a serif headline that reads like a magazine section title.

### Border Radius Scale
- Small (6px): Secondary buttons, inputs
- Standard (8px): Primary buttons, cards
- Large (12px): Featured panels, diagram containers
- Full Pill (9999px): Status badges

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, `#13111C` bg | Page background |
| Surface (Level 1) | `#291839` bg + `1px solid rgba(191,147,236,0.12)` border | Cards, panels |
| Bordered Button | `1px solid #36353E` + `0 2px 8px rgba(85,63,131,0.30)` | Primary button — signature defined-edge + glow |
| Glow Hover (Level 2) | `0 0 24px rgba(191,147,236,0.08)` | Interactive card/button hover — ambient light bloom |
| Elevated (Level 3) | `0 4px 16px rgba(0,0,0,0.4)` | Dropdowns, modals |
| Deep Modal (Level 4) | `0 8px 32px rgba(0,0,0,0.5)` + backdrop blur | Dialogs, command palettes |

**Shadow Philosophy**: Railway's elevation model combines two techniques rarely seen together: deep, soft black shadows for structural lift (appropriate for a dark canvas, where black-on-black shadows still register through blur and spread), and *colored glow* shadows (`rgba(191,147,236, …)`) for anything meant to feel alive or interactive. The border-on-filled-button technique (`1px solid #36353E`) is the system's quiet signature — a subtle but crucial detail that keeps buttons from visually dissolving into the surrounding void, since a pure fill-and-shadow approach would lack definition against near-black backgrounds of similar value.

## 7. Do's and Don'ts

### Do
- Keep the page background purple-tinted black (`#13111C`), not neutral or blue-black — the violet undertone is the atmosphere
- Use IBM Plex Serif for H1/H2 only, switching to Inter at H3 and below
- Apply a visible border (`#36353E` or `rgba(191,147,236,0.12–0.24)`) to every button and card — nothing should float undefined in the dark
- Reserve `#BF93EC` for glow/highlight moments — active states, hover blooms, diagram connection lines
- Use the four-tier purple depth system deliberately: void → secondary surface → mid accent → bright highlight

### Don't
- Don't flatten the purple system to a single hue at varying opacity — the four distinct tones create the night-sky depth
- Don't use a geometric sans for headlines — the serif is what elevates this from generic "dark mode SaaS" to editorial/atmospheric
- Don't omit borders on filled buttons — without `#36353E`, buttons lose definition against the dark background
- Don't apply glow effects everywhere — reserve the lavender glow for genuinely interactive/highlighted moments, or it loses its "signal" value
- Don't use pure black (`#000000`) — the void must retain its violet undertone

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|-------------|
| Mobile | <640px | Single column, hero H1 drops to 34px, hamburger nav |
| Tablet | 640–1024px | Two-column grids begin |
| Desktop | 1024–1280px | Full three-column grids, standard nav |
| Large Desktop | >1280px | Max-width container (1180px), generous margins |

### Touch Targets
- Buttons maintain 10px vertical padding for comfortable tap height
- Status badges are display-only; interactive versions get 32px minimum height
- Nav links spaced with adequate gaps for touch accuracy

### Collapsing Strategy
- Hero H1: 54px → 40px → 34px across breakpoints
- Architecture diagrams: simplify connection density on mobile, retain glow styling
- Feature grids: 3-column → 2-column → single column
- Navigation: horizontal links + CTA → hamburger at 768px

## 9. Agent Prompt Guide

### Quick Color Reference
- Primary CTA: Mid Accent Purple (`#553F83`)
- Page Background: Void Purple (`#13111C`)
- Secondary Surface: Deep Plum (`#291839`)
- Highlight/Glow: Bright Lavender (`#BF93EC`)
- Heading text: Near-White (`#F7F8F8`)
- Body text: Muted Lavender-Gray (`#A9A6B8`)
- Button border: `#36353E`

### Example Component Prompts
- "Create a hero section on `#13111C` background. Headline in IBM Plex Serif 54px weight 500, line-height 1.10, color `#F7F8F8`. Subtitle in Inter 20px weight 400, color `#A9A6B8`. Primary button: `#553F83` background, white text, 8px radius, `1px solid #36353E` border, shadow `0 2px 8px rgba(85,63,131,0.30)`."
- "Design a card on dark purple background: `#291839` background, `1px solid rgba(191,147,236,0.12)` border, 8px radius, shadow `0 4px 16px rgba(0,0,0,0.4)`. Title Inter 22px weight 600 `#F7F8F8`. Body Inter 16px weight 400 `#A9A6B8`."
- "Build a status pill: `rgba(74,222,128,0.12)` background, `#4ADE80` text, Inter 12px weight 500, 9999px radius, 3px 10px padding."
- "Create navigation: dark sticky header on `#13111C`, bottom border `1px solid rgba(191,147,236,0.08)`. Inter 14px weight 500 links in `#A9A6B8`, hover `#F7F8F8`. Bordered purple CTA button right-aligned."

### Iteration Guide
1. Serif headlines (IBM Plex Serif) apply only to H1/H2 — everything else is Inter
2. Every button and card needs a visible border — dark-on-dark surfaces lose definition without one
3. Use the four-tier purple system with intention: `#13111C` deepest → `#291839` surface → `#553F83` interactive → `#BF93EC` glow/highlight — never substitute one for another
4. Glow shadows (`rgba(191,147,236, …)`) signal interactivity/emphasis — apply sparingly
5. Keep body/UI text in Inter at 400/500/600 weights — reserve dramatic scale for the serif headlines only
6. JetBrains Mono (or equivalent) for all logs, CLI snippets, and env-var/config content
7. Status colors (`#4ADE80` success, `#FBBF24` warning, `#F87171` error) are the only exceptions to the purple-dominant palette — reserve them strictly for deployment-state indicators, never for decorative accents
8. When composing architecture/service diagrams, treat connection lines and node glows as the primary opportunity to deploy the bright lavender accent at scale — this is where the "night sky of services" metaphor becomes literal
9. Think of every screen as a nighttime skyline: a dark base, a handful of glowing points of interest, and generous negative space between them — resist the urge to fill the canvas
10. When translating from a light-mode reference design, invert to the void palette first, then reintroduce the lavender/purple system rather than reusing generic dark-mode grays
