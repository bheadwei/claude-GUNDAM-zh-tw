# Design System Inspired by Granola

## 1. Visual Theme & Atmosphere

Granola's website feels like an open notebook left on a sunlit desk — a warm, off-white canvas (`#F7F7F2`) that reads as *paper*, not *screen*. Where most AI products reach for cool blues and glassy gradients to signal "intelligence," Granola does the opposite: it borrows the visual vocabulary of independent magazines, Field Notes-style stationery, and hand-drawn marginalia. The brand's own 2026 identity refresh (by Ragged Edge) leaned deliberately into imperfection — a consciously rough, hand-drawn spiral mark for meetings, collage-like photography, and type running at unusual angles — to say "we're your trusty notebook, not your software."

The typographic centerpiece is **Quadrant**, a slightly mechanical slab serif used at an almost absurd scale — h1 headlines run at **110px**, dwarfing anything in a typical SaaS type scale. This isn't decorative excess; it's editorial confidence, the kind of oversized serif you'd see on the masthead of a magazine, not a dashboard. Quadrant has an editorial, masthead quality that immediately distinguishes Granola from generic AI-tool type systems built on Inter or system sans. Body text, by contrast, drops to a small, quiet **14px** set in **Melange** — a neutral but subtly characterful UI sans — creating a huge scale contrast between "the big idea" (headline) and "the fine print" (everything else), much like a handwritten note pinned under a bold magazine cutout.

Color-wise, the palette centers on **olive/matcha green** (`#5B6F00`) as the primary brand color, paired with a **soft mint-green** (`#DDEEDD`) for secondary surfaces and a brighter **accent green** (`#22C55E`) for links and interactive highlights. Everything sits on the warm paper background (`#F7F7F2`) or pure white (`#FFFFFF`), with near-black text (`#292929`) rather than pure black — consistent with the "ink on paper" metaphor. Buttons are **uniformly pill-shaped** (full radius) — there are no sharp-cornered buttons anywhere in the system — reinforcing the soft, organic, hand-finished feel that counterbalances Quadrant's editorial weight.

**Key Characteristics:**
- Warm paper background: `#F7F7F2` (primary) with `#FFFFFF` as a secondary lighter surface — never a cool/blue-tinted white
- Quadrant slab serif for display type, used at an oversized **110px** for h1 — editorial masthead energy
- Melange sans for body copy at a comparatively tiny **14px** — huge scale contrast between headline and body
- Primary brand color: olive/matcha green `#5B6F00` — warm, earthy, not a typical "tech" green
- Secondary soft mint `#DDEEDD` for gentle background tinting
- Accent green `#22C55E` reserved for links and small interactive highlights
- Near-black ink `#292929` for text — never pure `#000000`
- **All buttons are pills** (9999px radius) — no sharp corners anywhere in the button system
- 4px base spacing unit (tighter grain than most systems) with 12px standard component radius
- Hand-drawn, collage-like imagery and off-kilter type placement in marketing sections — imperfection as brand signal

## 2. Color Palette & Roles

### Background Surfaces
- **Paper Cream** (`#F7F7F2`): The primary, signature background — warm off-white that reads as paper/notebook stock. Used for the majority of page backgrounds.
- **Pure White** (`#FFFFFF`): Secondary surface — cards, modals, and elevated panels that need to sit visibly above the paper background.
- **Soft Mint Tint** (`#DDEEDD`): Gentle secondary surface color — used for subtle section backgrounds, secondary button fills, and quiet highlight blocks.
- **Button Cream** (`#FCFCF8`): A near-white, slightly warmer white used specifically as text color on dark-green primary buttons — not a background in its own right, but part of the button-color pairing.

### Text & Content
- **Primary Ink** (`#292929`): Near-black warm charcoal — the default text color for headlines and body copy. Deliberately not pure black, echoing ink-on-paper rather than pixels-on-glass.
- **Secondary Ink** (`rgba(41,41,41,0.7)`, inferred): Muted variant of primary ink for captions, timestamps, and de-emphasized copy.
- **Reversed Text** (`#FCFCF8`): Cream-white text used on dark-green button and badge fills.

### Brand & Accent
- **Olive Primary** (`#5B6F00`): The signature Granola brand color — matcha/olive green used for primary buttons, key brand marks, and the dominant chromatic note of the system.
- **Accent Green** (`#22C55E`): Brighter, more saturated green used for links, small interactive highlights, and hover accents — distinct from the muted olive primary.
- **Soft Mint** (`#DDEEDD`): Pale green companion used as a secondary surface/background tint, not as text or button color.

### Status Colors (inferred, consistent with the organic palette)
- **Success** (`#22C55E`): Reuses the accent green — completed recordings, saved notes, sync confirmations.
- **Warning** (`#B45309`, warm amber, inferred): Recording paused, sync delayed.
- **Error** (`#B91C1C`, muted brick red, inferred): Failed transcription, connection lost — kept warm/desaturated to stay in-family with the earthy palette, never a cold, clinical red.

### Border & Divider
- **Ink Border** (`#292929`): Solid dark border used on secondary/outline buttons — a deliberately strong, visible border rather than a whisper-thin one.
- **Paper Divider** (`rgba(41,41,41,0.12)`, inferred): Soft, low-contrast divider lines within cards and lists, keeping the paper metaphor intact (like a faint ruled line, not a hard rule).

### Overlay
- **Modal Backdrop** (`rgba(41,41,41,0.4)`): Warm charcoal overlay at moderate opacity — softer and warmer than a typical pure-black scrim, consistent with the ink-on-paper palette.

## 3. Typography Rules

### Font Family
- **Display**: `"Quadrant", "Georgia", "Times New Roman", serif` — a slightly mechanical slab serif, editorial and masthead-like, used exclusively for large display type
- **Body/UI**: `"Melange", -apple-system, "Segoe UI", Roboto, sans-serif` — neutral but characterful, used for all body copy, UI labels, and controls

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| Display H1 | Quadrant | 110px (6.88rem) | 400–500 | 0.95 (very tight) | Hero headline — the system's signature move, magazine-masthead scale |
| Display H2 | Quadrant | 64px (4.00rem) | 400–500 | 1.00 | Section headlines |
| Heading 1 | Quadrant | 40px (2.50rem) | 400–500 | 1.10 | Major page/section titles |
| Heading 2 | Quadrant | 28px (1.75rem) | 400–500 | 1.20 | Sub-section headers, card feature titles |
| Heading 3 | Melange | 20px (1.25rem) | 600 | 1.30 | Component/card headers (sans, not serif — a deliberate register shift for UI chrome) |
| Body Large | Melange | 16px (1.00rem) | 400 | 1.60 | Introductory copy, feature descriptions |
| Body | Melange | 14px (0.88rem) | 400 | 1.55 | Standard reading text — the system's default, notably small relative to the huge headlines |
| Body Medium | Melange | 14px (0.88rem) | 600 | 1.55 | Emphasized inline text, nav links |
| Small/Caption | Melange | 12px (0.75rem) | 400 | 1.45 | Metadata, timestamps, form helper text |
| Label | Melange | 12px (0.75rem) | 600 | 1.30 | Button labels, tag text |
| Micro | Melange | 11px (0.69rem) | 500 | 1.30 | Tiny badges, footnote-scale annotations |

### Principles
- **Extreme scale contrast is the identity**: 110px Quadrant headlines next to 14px Melange body isn't a mistake in the type scale — it's the entire point. The contrast mimics a magazine masthead sitting above dense column text.
- **Serif announces, sans serves**: Quadrant is reserved strictly for display/heading roles (H1/H2, and occasionally H1-scale card titles in marketing contexts); Melange handles everything functional — buttons, forms, metadata, body copy. Never mix the roles.
- **Tight line-height at display sizes**: 0.95–1.10 line-height at Quadrant sizes keeps oversized serif headlines from feeling loose or airy — they should feel set, deliberate, like a printed masthead.
- **Small body by default**: at 14px, Granola's body text is smaller than most SaaS systems (which default to 16px) — this is intentional, reinforcing the "fine print under a bold headline" notebook metaphor. Don't "fix" it to 16px.
- **No aggressive letter-spacing**: unlike geometric sans systems (Linear's Inter), Quadrant and Melange are both used at normal or very slightly tightened tracking — the character comes from the typeface choice itself, not spacing tricks.

## 4. Component Stylings

### Buttons

**Primary Button (Pill)**
- Background: `#5B6F00` (olive)
- Text: `#FCFCF8` (cream-white)
- Padding: 12px 24px
- Radius: 9999px (full pill — the only radius used for buttons)
- Border: none
- Hover: background lightens slightly to `#6E8600` or gains a subtle warm glow
- Use: Primary CTAs — "Try Granola", "Start for free", record/save actions

**Secondary Button (Outline Pill)**
- Background: `#F7F7F2` (paper) or `#FFFFFF`
- Text: `#292929`
- Padding: 12px 24px
- Radius: 9999px
- Border: `1px solid #292929` (deliberately strong, visible ink-colored border)
- Hover: background shifts to `#DDEEDD` (soft mint tint)
- Use: Secondary actions — "Learn more", "Watch demo", dismiss/cancel actions

**Ghost/Text Pill**
- Background: transparent
- Text: `#5B6F00`
- Padding: 8px 16px
- Radius: 9999px
- Hover: text color shifts to `#22C55E` (accent green), subtle underline
- Use: Tertiary nav links, inline text actions

**Icon Button**
- Background: `#DDEEDD`
- Text/Icon: `#292929`
- Radius: 50% (the one exception to "everything is a pill" — icon-only controls are circular, a pill's natural limit case)
- Size: 36px × 36px
- Use: Recording controls, note actions, toolbar icons

### Cards & Containers
- Background: `#FFFFFF` (elevated above the `#F7F7F2` paper background)
- Border: none by default, or `1px solid rgba(41,41,41,0.08)` when adjacent cards need separation
- Radius: 12px (the system's standard container radius)
- Shadow: soft, warm-toned `0 4px 16px rgba(41,41,41,0.06)`
- Padding: 20–24px
- Meeting-note cards often include a hand-drawn spiral-notebook motif in the corner as a brand signature

### Inputs & Forms

**Text Input**
- Background: `#FFFFFF`
- Border: `1px solid rgba(41,41,41,0.15)`
- Radius: 12px
- Padding: 12px 16px
- Text: `#292929`, placeholder `rgba(41,41,41,0.45)`
- Focus: border becomes `#5B6F00`, subtle focus ring `0 0 0 3px rgba(91,111,0,0.15)`

**Search / Command Input**
- Background: `#F7F7F2`
- Border: `1px solid rgba(41,41,41,0.12)`
- Radius: 9999px (pill, matching the button system)
- Padding: 10px 20px

### Tags & Badges

**Meeting Tag Pill**
- Background: `#DDEEDD`
- Text: `#5B6F00`
- Padding: 4px 12px
- Radius: 9999px
- Font: 12px Melange weight 600
- Use: Meeting categories, attendee count chips, calendar-source labels

**Highlight Badge**
- Background: `#5B6F00`
- Text: `#FCFCF8`
- Padding: 3px 10px
- Radius: 9999px
- Font: 11px Melange weight 600
- Use: "AI Summary", "New template" call-outs

### Navigation
- Paper-colored (`#F7F7F2`) or white sticky header, no hard border — instead a very soft `rgba(41,41,41,0.06)` bottom hairline
- Logo: hand-drawn spiral mark + Quadrant wordmark, left-aligned
- Nav links: Melange 14px weight 600, `#292929`, hover shifts to `#5B6F00`
- CTA: primary olive pill button, right-aligned
- Mobile: hamburger collapse, spiral mark remains visible

### Image & Illustration Treatment
- Collage-style photography: macro shots (seashells, textures), mixed with bold Quadrant type at unusual angles, occasionally bleeding off the edge of the section
- Hand-drawn line-art accents (spirals, underlines, arrows) layered over photography — the imperfection is a deliberate brand signal, not a bug
- Screenshots of the product UI shown in simple white or cream frames with 12px radius, minimal shadow

## 5. Layout Principles

### Spacing System
- Base unit: 4px
- Scale: 4px, 8px, 12px, 16px, 20px, 24px, 32px, 40px, 48px, 64px, 96px
- Tighter grain (4px base) than most SaaS systems reflects the "hand-set, notebook-grid" feel — fine adjustments matter, like ruled lines on a page
- Primary rhythm for marketing sections: 64px–96px vertical spacing (to give the 110px headlines room to breathe)

### Grid & Container
- Max content width: ~1140px for marketing pages
- Hero: centered, oversized Quadrant headline dominates the viewport, often with off-center or angled supporting imagery
- Feature sections: asymmetric 2-column layouts (large image + text block) more common than symmetric 3-column grids, reinforcing the editorial/magazine layout language rather than uniform SaaS grids
- App/dashboard views: single-column note list with a right-side detail panel

### Whitespace Philosophy
- **Paper needs margin**: the warm cream background is treated genuinely like paper — generous margins (64px+) frame content the way a magazine page frames a pull-quote.
- **Scale creates its own space**: the 110px headline doesn't need much surrounding decoration — its sheer size does the visual work, so supporting elements (body text, buttons) can sit close beneath it without feeling cramped.
- **Imperfection over grid rigidity**: unlike Linear's precise 8px grid, Granola's marketing layouts intentionally break grid alignment at points (rotated type, bleeding images) to preserve the hand-crafted, notebook-doodle feeling.

### Border Radius Scale
- Small (8px, rare): minor inline elements
- Standard (12px): cards, inputs, containers — the dominant radius across the entire system
- Full Pill (9999px): all buttons, tags, badges, search bars
- Circle (50%): icon buttons, avatars — the natural limiting case of "everything is round"

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, `#F7F7F2` paper bg | Page background |
| Card (Level 1) | `0 4px 16px rgba(41,41,41,0.06)` | Standard cards on paper background |
| Elevated Card (Level 2) | `0 8px 24px rgba(41,41,41,0.10)` | Featured cards, pricing tables |
| Dropdown/Popover (Level 3) | `0 12px 32px rgba(41,41,41,0.14)` | Menus, note-action popovers |
| Modal (Level 4) | `0 24px 48px rgba(41,41,41,0.18)` | Dialogs, onboarding flows |
| Button Hover Glow | `0 2px 8px rgba(91,111,0,0.20)` | Primary pill button hover state |

**Shadow Philosophy**: All shadows in this system use the warm charcoal ink color (`rgba(41,41,41, ...)`) rather than pure black, keeping elevation feeling soft and organic rather than harsh and mechanical — a light-mode complement to Hugging Face's "warm neutral shadow" approach, but pushed further toward warmth to match the paper metaphor. Elevation is used sparingly; most of the visual hierarchy comes from the paper/white surface contrast and generous whitespace rather than deep shadow stacks.

## 7. Do's and Don'ts

### Do
- Use Quadrant exclusively for display/heading roles — never for body copy or UI labels
- Keep body text at 14px Melange — resist "correcting" it to 16px, the smallness is intentional
- Make every button a full pill (9999px radius) — no exceptions for standard buttons
- Use the warm paper background (`#F7F7F2`) as the default, reserving pure white for elevated cards
- Reserve accent green (`#22C55E`) for links and small highlights — keep olive (`#5B6F00`) as the dominant brand fill
- Allow controlled imperfection in marketing layouts — slight rotation, bleeding images, hand-drawn accents
- Use warm charcoal ink (`#292929`) for text and shadows, never pure black

### Don't
- Don't use Quadrant at body-text sizes — it's a display-only serif, it will feel heavy and slow to read at small sizes
- Don't shrink the h1 scale contrast — 110px Quadrant next to 14px Melange is the brand signature, not an accident to normalize
- Don't introduce sharp-cornered (0–4px radius) buttons — the pill shape is non-negotiable across the button system
- Don't use cool blue-tinted whites — the background must read warm (`#F7F7F2`), not clinical
- Don't use pure black (`#000000`) for text or shadows — always the warm ink `#292929`
- Don't apply Linear-style aggressive negative letter-spacing — Quadrant and Melange both read best at normal tracking
- Don't over-polish marketing imagery into stock-photo perfection — the collage/hand-drawn roughness is deliberate brand equity

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|--------------|
| Mobile | <640px | Single column, Quadrant H1 drops to ~48px, stacked pill buttons |
| Tablet | 640–1024px | Two-column feature sections begin, H1 ~72px |
| Desktop | 1024–1280px | Full asymmetric layouts, H1 ~96–110px |
| Large Desktop | >1280px | Full 110px H1, generous margins, editorial imagery at full scale |

### Touch Targets
- Pill buttons maintain 44px+ minimum tap height on mobile
- Tag pills gain extra horizontal padding (14px) on touch devices
- Icon buttons (circular) sized at minimum 40px on mobile for comfortable tapping

### Collapsing Strategy
- Display H1: 110px → 72px → 48px across breakpoints, line-height loosens slightly (0.95 → 1.05 → 1.15) to stay legible at smaller sizes
- Asymmetric 2-column marketing sections stack to single column, image above or below text
- Navigation: horizontal links + CTA pill → hamburger menu at <640px, spiral logo mark always remains visible
- Note list + detail panel: side-by-side on desktop collapses to a single-pane, tap-to-drill-in pattern on mobile

## 9. Agent Prompt Guide

### Quick Color Reference
- Page background: Paper Cream (`#F7F7F2`)
- Card background: White (`#FFFFFF`)
- Primary text: Warm Ink (`#292929`)
- Primary brand/button: Olive (`#5B6F00`)
- Button text on olive: Cream (`#FCFCF8`)
- Accent/link: Bright Green (`#22C55E`)
- Secondary surface: Soft Mint (`#DDEEDD`)
- Border (outline button): `#292929`
- Shadow tint: `rgba(41,41,41, ...)`

### Example Component Prompts
- "Create a hero section on `#F7F7F2` background. Headline at 110px Quadrant serif, weight 400, line-height 0.95, color `#292929`. Subtitle at 16px Melange weight 400, line-height 1.60, color `rgba(41,41,41,0.7)`. Primary olive pill button (`#5B6F00` bg, `#FCFCF8` text, 9999px radius, 12px 24px padding) next to an outline pill button (`#F7F7F2` bg, `1px solid #292929` border, `#292929` text)."
- "Design a meeting-note card: white background, 12px radius, soft shadow `0 4px 16px rgba(41,41,41,0.06)`, 24px padding. Title at 20px Melange weight 600, color `#292929`. Below it, a mint-green tag pill (`#DDEEDD` bg, `#5B6F00` text, 9999px radius, 12px weight 600) showing the meeting category."
- "Build a search pill: `#F7F7F2` background, `1px solid rgba(41,41,41,0.12)` border, 9999px radius, 10px 20px padding, 14px Melange text in `#292929`."
- "Create navigation: paper-colored sticky header with a soft `rgba(41,41,41,0.06)` bottom hairline. Hand-drawn spiral logo mark + Quadrant wordmark left-aligned. Nav links 14px Melange weight 600 `#292929`. Right-aligned olive pill CTA button."
- "Design a section headline pairing: Quadrant H2 at 64px weight 400 color `#292929`, followed by 14px Melange body copy in the same color at 60% width, line-height 1.55 — emphasizing the huge type-scale contrast."

### Iteration Guide
1. Always pair Quadrant (display) with Melange (functional) — never let one typeface do the other's job
2. Preserve the extreme scale jump between H1 (110px) and body (14px) — this contrast IS the brand
3. Every button is a pill (9999px) — check radius before shipping any button component
4. Default background is warm paper `#F7F7F2`; use `#FFFFFF` only for surfaces that need to visibly lift off the page
5. Olive (`#5B6F00`) carries brand weight; accent green (`#22C55E`) is for links/small highlights only — don't swap their roles
6. Keep shadows warm-toned (`rgba(41,41,41,...)`) and soft — never a cold, hard black shadow
7. In marketing contexts, allow deliberate imperfection (slight rotation, bleeding images, hand-drawn accents) rather than forcing pixel-perfect grid alignment
</content>
