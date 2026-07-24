# Design System Inspired by OpenAI

## 1. Visual Theme & Atmosphere

OpenAI's site is an exercise in radical restraint: an almost entirely achromatic system — pure white canvas, true black text, and nothing else structural — that reads less like a tech company's marketing page and more like a research institution's letterhead. Where most AI competitors reach for a signature brand hue, OpenAI deliberately withholds one; color is treated as a scarce resource, appearing only as a single warm accent (`#FF9A3C`) on links and rare highlight moments, with a cooler blue (`#005CC5`) as a secondary/technical accent. The effect is a page that feels like an "empty vessel" — content and product screenshots supply the color, the chrome itself stays neutral.

The entire interface runs on one custom typeface, **OpenAI Sans** — a geometric grotesk purpose-built in 2025 with ABC Dinamo and Studio Dumbar, designed to balance technological precision with human warmth. Its defining trait is the perfectly circular 'O', echoed throughout the brand system, and softened terminals that keep the geometry from feeling cold. Because there is no secondary typeface competing for attention, hierarchy is built almost entirely through size, weight, and — most distinctively — through OpenAI's near-universal adoption of the fully-rounded pill shape (`9999px` / `40px` radius) for every button, input, and many containers. Nothing in the system has a sharp corner; the pill is to OpenAI what the indigo accent is to Linear — the one unmistakable signature.

Spacing is generous to the point of austerity: OpenAI's pages favor large empty margins, oversized headline type, and short line lengths, giving each statement room to breathe like a manifesto rather than a feature list. Motion and decoration are minimal — the personality comes entirely from typographic confidence and geometric consistency, not from color or ornament.

**Key Characteristics:**
- Near-monochrome canvas: pure white (`#FFFFFF`) background, true black (`#000000`) text — color is the exception, not the rule
- Single custom typeface throughout: **OpenAI Sans** (geometric grotesk, circular 'O', 5 weights + italics)
- Warm accent used sparingly for links/highlights: `#FF9A3C`; cooler secondary accent `#005CC5` for technical/code contexts
- Universal pill geometry: primary buttons at 40px radius, secondary buttons and inputs at full `9999px` pill
- Primary button = black fill / white text; secondary button = transparent with black outline — the entire button system is a black/white pair
- Extremely light shadow use — near-flat, near-shadowless elevation (`rgba(0,0,0,0.02–0.05)`)
- 4px base spacing unit with generous multi-hundred-pixel section padding on marketing pages
- Body copy runs compact (14px base) while headline type runs oversized — a wide contrast range with almost no midpoint
- Minimal iconography, minimal decoration — confidence expressed through typographic scale and negative space alone

## 2. Color Palette & Roles

### Background Surfaces
- **Pure White** (`#FFFFFF`): The default and near-universal background — page canvas, cards, panels, navigation.
- **Off-White Panel** (`#F7F7F8`): The only alternate light surface, used sparingly to differentiate a section (e.g. a highlighted callout block) from the pure-white canvas around it.
- **True Black** (`#000000`): Used as a background exclusively for high-contrast marketing moments (dark hero sections, primary buttons) — not a general "dark mode" surface, but a deliberate reversal.

### Text & Content
- **Primary Text** (`#000000`): True black — the default for headlines and body copy. OpenAI does not soften this toward gray; contrast is meant to be stark.
- **Secondary Text** (`#6E6E80`): Muted gray for captions, metadata, de-emphasized UI labels.
- **Tertiary Text** (`#8E8EA0`): The lightest text tone — placeholder text, disabled states.
- **Inverted Text** (`#FFFFFF`): White text used on the rare black-background sections and on primary black buttons.

### Brand & Accent
- **Warm Accent** (`#FF9A3C`): The primary — and almost only — chromatic color in the system. Used for links, highlighted terms, and small brand moments.
- **Technical Blue** (`#005CC5`): Secondary accent reserved for code/technical contexts, developer-platform links, and syntax highlighting accents.
- **Accent Hover** (`#E67E22`): Slightly deepened warm accent for hover/active link states.

### Status Colors
- **Success** (`#1A7F37`): Confirmation states, successful API calls — used minimally, mostly in developer-console contexts.
- **Warning** (`#B36B00`): Rate-limit banners, usage warnings.
- **Error** (`#D1242F`): Form validation errors, failed requests.

### Border & Divider
- **Border Default** (`#E5E5E5`): Standard 1px border for cards, input outlines, table rules.
- **Border Subtle** (`rgba(0,0,0,0.06)`): The lightest divider — used for internal card separations.
- **Border on Dark** (`rgba(255,255,255,0.15)`): Border treatment for the rare black-background sections.

### Overlay
- **Overlay Primary** (`rgba(0,0,0,0.5)`): Standard modal/dialog backdrop.

## 3. Typography Rules

### Font Family
- **Primary**: `OpenAI Sans`, with fallback stack: `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif`
- **Monospace**: `"OpenAI Sans Mono", ui-monospace, "SF Mono", Menlo, monospace` (developer docs, code blocks)
- **Weights available**: Light (300), Regular (400), Medium (500), Semibold (600), Bold (700) — each with a matching italic

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| Display XL | OpenAI Sans | 80px (5.00rem) | 500 | 1.02 | Flagship hero statements ("Introducing...") |
| Display | OpenAI Sans | 56px (3.50rem) | 500 | 1.05 | Section-level hero headlines |
| Heading 1 | OpenAI Sans | 40px (2.50rem) | 500 | 1.10 | Page titles |
| Heading 2 | OpenAI Sans | 28px (1.75rem) | 500 | 1.20 | Section headings |
| Heading 3 | OpenAI Sans | 20px (1.25rem) | 600 | 1.30 | Card titles, feature labels |
| Body Large | OpenAI Sans | 18px (1.13rem) | 400 | 1.50 | Introductory/lead paragraphs |
| Body | OpenAI Sans | 14px (0.88rem) | 400 | 1.50 | Standard UI and reading text — notably compact for the base size |
| Body Medium | OpenAI Sans | 14px (0.88rem) | 500 | 1.50 | Emphasized labels, active nav items |
| Small | OpenAI Sans | 13px (0.81rem) | 400 | 1.45 | Secondary text, form helper text |
| Caption | OpenAI Sans | 12px (0.75rem) | 400 | 1.40 | Metadata, timestamps, legal text |
| Button Label | OpenAI Sans | 15px (0.94rem) | 500 | 1.00 | All button text |
| Mono Body | OpenAI Sans Mono | 14px (0.88rem) | 400 | 1.60 | Code blocks, API examples |

### Principles
- **Bimodal scale, minimal midpoint**: The type scale jumps from an oversized 80px display straight down to a compact 14px body — there is deliberately little "medium" text; hierarchy is stark rather than gradual.
- **Weight 500 as the workhorse**: Headlines and emphasis default to Medium (500) rather than Bold (700) — Bold is reserved for truly rare emphasis, keeping the overall tone calm and confident rather than shouting.
- **The circular 'O'**: OpenAI Sans's defining structural trait — a perfectly round bowl on 'O', 'o', 'e', 'c' — reinforcing the brand mark's geometry at the type level.
- **No aggressive letter-spacing tricks**: Unlike geometric-compression systems, OpenAI Sans is set at normal or very slightly tight tracking — its personality comes from the letterforms themselves, not from spacing manipulation.

## 4. Component Stylings

### Buttons

**Primary Button (Pill)**
- Background: `#000000`
- Text: `#FFFFFF`
- Padding: 12px 24px
- Radius: 40px
- Shadow: none
- Hover: background lightens to `#1A1A1A`, no elevation change
- Use: Primary CTAs ("Try ChatGPT", "Get started")

**Secondary Button (Outline Pill)**
- Background: transparent
- Text: `#000000`
- Border: `1px solid #000000`
- Padding: 12px 24px
- Radius: 9999px
- Shadow: extremely subtle `rgba(0,0,0,0.02)` to `rgba(0,0,0,0.05)`
- Hover: background fills to `rgba(0,0,0,0.04)`
- Use: Secondary CTAs ("Learn more", "View docs")

**Text / Ghost Button**
- Background: transparent
- Text: `#FF9A3C` or `#000000`
- Padding: 4px 0
- Radius: none — underline appears on hover instead
- Use: Inline links styled as actions

**Icon Button**
- Background: transparent
- Radius: 50%
- Size: 36px hit area
- Hover: `rgba(0,0,0,0.05)` background fill
- Use: Navigation utility icons, close/menu toggles

### Cards & Containers
- Background: `#FFFFFF` on `#FFFFFF` or `#F7F7F8` — cards are differentiated almost entirely by border, not by background shift
- Border: `1px solid #E5E5E5`
- Radius: 20px (standard feature cards), 12px (compact/utility cards)
- Shadow: none by default; on hover a barely perceptible `0px 4px 12px rgba(0,0,0,0.04)` may appear
- The near-absence of shadow keeps the page feeling flat and paper-like, consistent with the black/white restraint

### Inputs & Forms

**Pill Input (Signature Component)**
- Background: transparent or `#FFFFFF`
- Border: `1px solid #E5E5E5`, focus `1px solid #000000`
- Padding: 12px 20px
- Radius: 9999px (full pill)
- Placeholder: `#8E8EA0`
- Use: Email capture, chat/prompt inputs, search fields

**Standard Form Field**
- Background: `#FFFFFF`
- Border: `1px solid #E5E5E5`
- Padding: 10px 14px
- Radius: 8px
- Focus: border `#000000`, no colored glow — the system avoids colored focus rings in favor of stark black outlines

### Badges & Pills
- Background: `#F7F7F8`
- Text: `#000000`
- Padding: 4px 12px
- Radius: 9999px
- Font: 12px weight 500
- Use: Model tags ("GPT-5"), category labels, status chips

### Navigation
- White sticky header, `1px solid #E5E5E5` bottom border
- Logo (circular 'O' mark) left-aligned
- Links: OpenAI Sans 14px weight 400, `#000000` text, no color change on hover — underline or subtle background pill instead
- CTA: black pill button right-aligned
- Mobile: collapses to hamburger with full-screen overlay menu

### Image / Product Treatment
- Product screenshots and diagrams are given enormous whitespace margins — images rarely touch the edges of their container
- Illustrations use flat, minimal geometric shapes echoing the circular brand mark
- No heavy borders or shadows on imagery — images sit directly on the white canvas

## 5. Layout Principles

### Spacing System
- Base unit: 4px
- Scale: 4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px, 96px, 128px
- Marketing sections use extreme vertical rhythm — 96px–128px between major sections is common
- Primary rhythm: 8px/16px for component-internal spacing; 48px+ for section-level spacing

### Grid & Container
- Max content width: ~1200px, but text blocks are frequently constrained much narrower (~640-720px) for readability
- Hero sections: centered single column, oversized headline, minimal supporting copy
- Feature sections: 2–3 column grids with large gutters (32px+)
- Full-width white sections predominate; the rare full-width black section is reserved for maximum-impact statements

### Whitespace Philosophy
- **The page as an empty vessel**: OpenAI's design philosophy is explicit about restraint — space is not filler, it is the primary design material. Content earns its presence through isolation.
- **Short line lengths at large sizes**: Headlines often break at 3-5 words per line, reinforcing the manifesto-like tone.
- **No visual clutter**: Icons, decorative elements, and secondary information are minimized aggressively — if it doesn't communicate the core idea, it is removed.

### Border Radius Scale
- Standard (8px): Form fields, small utility containers
- Card (12–20px): Feature cards, panels
- Circle (50%): Icon buttons, avatars, the brand mark itself
- Full Pill (40px / 9999px): All primary/secondary buttons and text inputs — this is the system's dominant radius signature

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, `#FFFFFF` bg | Page background — the default state for nearly everything |
| Whisper (Level 1) | `rgba(0,0,0,0.02) 0px 1px 2px` | Secondary button resting state |
| Subtle (Level 2) | `rgba(0,0,0,0.05) 0px 2px 4px` | Card hover, dropdown resting |
| Elevated (Level 3) | `rgba(0,0,0,0.08) 0px 8px 24px` | Dropdown menus, tooltips |
| Modal (Level 4) | `rgba(0,0,0,0.12) 0px 16px 48px` | Dialogs, command palettes |

**Shadow Philosophy**: OpenAI's elevation system is the lightest of any major design system — shadows exist mostly as a formality rather than a visible design element. Depth is instead communicated through borders (`1px solid #E5E5E5`) and the rare, deliberate use of a solid black background to signal "this section is different." The near-total absence of shadow reinforces the flat, paper-like, editorial character of the whole system.

## 7. Do's and Don'ts

### Do
- Keep the canvas pure white (`#FFFFFF`) and text true black (`#000000`) — the contrast is meant to be stark, not softened
- Use OpenAI Sans for absolutely everything — headlines, body, buttons, code — there is no secondary typeface
- Apply the full-pill shape (`9999px` / 40px radius) to every button and text input without exception
- Reserve the warm accent (`#FF9A3C`) strictly for links and rare highlight words — never for backgrounds or large surfaces
- Give headline text generous negative space — short line lengths, large margins
- Keep shadows nearly invisible; let borders and whitespace do the separating

### Don't
- Don't introduce a saturated brand color as a dominant UI hue — OpenAI's restraint is the point
- Don't use square or slightly-rounded (4-8px) corners on buttons or primary inputs — the pill is non-negotiable for these components
- Don't mix in a second typeface for "variety" — consistency across headline/body/code is core to the system's calm authority
- Don't add heavy drop shadows or colored glows — elevation should be nearly imperceptible
- Don't crowd sections — err toward more whitespace, not less, especially around hero headlines
- Don't use bold (700) as the default heading weight — medium (500) is the system's true workhorse

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|--------------|
| Mobile | <640px | Single column, hamburger nav, headline sizes drop by ~40% |
| Tablet | 640–1024px | Two-column feature grids begin, nav remains collapsed |
| Desktop | 1024–1440px | Full horizontal nav, 2–3 column grids, standard headline sizes |
| Large Desktop | >1440px | Content max-width caps at ~1200px; extra space becomes margin |

### Touch Targets
- Pill buttons maintain 44px+ minimum height on mobile for comfortable tapping
- Icon buttons keep a 36-44px hit area regardless of visual icon size
- Form inputs increase padding slightly on mobile to ease thumb interaction

### Collapsing Strategy
- Hero: 80px → 48px → 32px display text as viewport narrows
- Navigation: horizontal links + CTA → hamburger with full-screen overlay at 1024px
- Feature grids: 3-column → 2-column → single column stacked
- Section vertical spacing: 128px → 64px → 40px on mobile

## 9. Agent Prompt Guide

### Quick Color Reference
- Page Background: Pure White (`#FFFFFF`)
- Primary Text: True Black (`#000000`)
- Secondary Text: `#6E6E80`
- Accent (links): `#FF9A3C`
- Secondary Accent: `#005CC5`
- Border: `#E5E5E5`
- Primary Button: Black fill / white text
- Secondary Button: Transparent / black outline

### Example Component Prompts
- "Create a hero section on `#FFFFFF` background. Headline at 56px OpenAI Sans weight 500, line-height 1.05, color `#000000`, max-width 640px, centered. Subtitle at 18px weight 400, color `#6E6E80`. Primary black pill button (40px radius, 12px 24px padding) and outline pill secondary button (`1px solid #000000`, 9999px radius)."
- "Design a feature card: `#FFFFFF` background, `1px solid #E5E5E5` border, 20px radius, no shadow. Title at 20px OpenAI Sans weight 600, `#000000`. Body at 14px weight 400, `#6E6E80`."
- "Build a pill input: transparent background, `1px solid #E5E5E5` border (focus: `1px solid #000000`), 9999px radius, 12px 20px padding, placeholder `#8E8EA0`."
- "Create navigation: white sticky header, `1px solid #E5E5E5` bottom border. OpenAI Sans 14px weight 400 links, `#000000` text. Black pill CTA button right-aligned."
- "Design a badge/tag: `#F7F7F8` background, `#000000` text, 9999px radius, 4px 12px padding, 12px OpenAI Sans weight 500."

### Iteration Guide
1. Default every button and text input to a full pill shape — 40px radius for primary buttons, 9999px for secondary/inputs
2. Text stays true black (`#000000`) on pure white (`#FFFFFF`) — do not soften into gray for "readability," the contrast is intentional
3. Use weight 500 as the default emphasis weight; reserve 700 (bold) for truly exceptional cases
4. The warm accent (`#FF9A3C`) appears only on links/highlighted terms — never as a background or large fill
5. Keep shadows nearly invisible (`rgba(0,0,0,0.02–0.08)` range) — borders carry the separation work instead
6. Favor oversized whitespace over density — when in doubt, add more margin, not more content
7. OpenAI Sans is the only typeface; use its system-ui fallback stack when the font file isn't loaded
