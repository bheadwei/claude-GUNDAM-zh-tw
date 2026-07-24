# Design System Inspired by Clerk

## 1. Visual Theme & Atmosphere

Clerk's site is what happens when a design team obsesses over a single square inch — the button — until it becomes a small masterpiece of layered light. The overall canvas is a quiet, professional light gray (`#F7F7F8`), almost clinical in its restraint, with near-black text (`#131316`) that never quite hits pure ink. Against this deliberately unremarkable backdrop, Clerk spends its entire visual budget on component precision: buttons that look like they were extruded from glass and pressed plastic simultaneously, cards with soft multi-layer shadows that feel closer to physical material samples than flat CSS boxes. This is auth infrastructure sold through craftsmanship — the message is "we obsess over details this small, imagine how carefully we handle your users' credentials."

The typographic voice pairs Geist (for UI and body text) with Suisse (for display and editorial moments) — both are Swiss-grotesk-influenced sans families that read as clean, neutral, and confident without shouting. Headlines run large (64px), but restraint in letter-spacing and weight keeps them feeling engineered rather than decorative. The real personality lives in the grayscale text system itself: Clerk defines *two* distinct secondary grays (`#747686` primary-secondary and `#5E5F6E` a cooler variant) rather than one, giving designers a nuanced palette for hierarchy without ever reaching for color.

Color, when it appears, is a single confident violet (`#6C47FF`) — used exactly like Linear uses its indigo, but warmer, punchier, and slightly more saturated, reflecting Clerk's friendlier, more approachable developer-tool personality versus Linear's colder precision-engineering tone. The signature move, however, is structural, not chromatic: Clerk's buttons use **compound, multi-layer shadow recipes** — a hairline ring border simulated via box-shadow, an inset top highlight for glassy sheen, and an outer diffuse shadow for lift — creating buttons that feel tactile and premium in a way flat design never can.

**Key Characteristics:**
- Light, professional canvas: `#F7F7F8` background, `#131316` near-black text — clinical and calm
- Two-tier secondary gray system: `#747686` (primary-secondary) and `#5E5F6E` (cooler variant) for nuanced hierarchy
- Font pairing: **Geist** (UI/body) + **Suisse** (display/editorial) — both Swiss-grotesk lineage, calm and confident
- Single brand accent: `#6C47FF` (violet) — warmer and more saturated than typical developer-tool blues/indigos
- Signature "engineered button" shadow system: 0.5px ring border simulated via box-shadow + inset top highlight + soft outer diffuse shadow — the system's defining visual signature
- Secondary button carries an even more elaborate "glass white key" treatment: dual-layer diffuse shadow + 24px inset white highlight
- 4px base spacing grid — finer-grained than most competitors, enabling the micro-precision the shadows demand
- Radius scale runs generous: 6px (primary buttons) up to 12px (secondary buttons, cards) — soft, friendly, never sharp

## 2. Color Palette & Roles

### Background Surfaces
- **Page Background** (`#F7F7F8`): The default canvas across the entire site — a cool, clinical light gray, never pure white.
- **Card Surface** (`#FFFFFF`): Pure white for elevated cards and panels, creating deliberate contrast against the gray page background.
- **Secondary Button Surface** (`#F7F7F8`): Matches the page background exactly — secondary buttons are distinguished purely through shadow, not color fill.

### Text & Content
- **Primary Text** (`#131316`): Near-black with a faint cool cast — the default for headings and primary copy.
- **Secondary Text — Warm** (`#747686`): The primary secondary gray, used for body copy, descriptions, and de-emphasized UI labels.
- **Secondary Text — Cool** (`#5E5F6E`): A slightly cooler, darker gray variant used for metadata, captions, and content requiring marginally more contrast than the warm secondary.

### Brand & Accent
- **Clerk Violet** (`#6C47FF`): The single chromatic anchor — primary button backgrounds, links, active nav states, focus rings, brand marks.
- **Violet Hover** (`#7C5CFF`, inferred lighter tint): Used for hover/active states on violet elements.
- **Violet Tint** (`rgba(108,71,255,0.08)`): Extremely light violet wash for selected states and subtle highlighted backgrounds.

### Border & Divider
- **Ring Border** (`rgba(19,19,22,0.08)`): Simulated as a 0.5px box-shadow ring around buttons — Clerk's signature "hairline precision" edge, thinner and crisper than a standard CSS border.
- **Card Border** (`rgba(19,19,22,0.06)`): Even subtler border for card containers, relying primarily on shadow for definition rather than line weight.
- **Divider** (`rgba(19,19,22,0.10)`): Standard horizontal rule / section divider.

### Shadow Component Colors
- **Highlight White** (`rgba(255,255,255,0.5)` inset): Used inside both button types to simulate a glassy top-edge sheen.
- **Ambient Shadow** (`rgba(19,19,22,0.10)` to `rgba(19,19,22,0.20)`): The diffuse outer shadow layers that give buttons physical lift.

## 3. Typography Rules

### Font Family
- **UI / Body**: `Geist`, fallback: `-apple-system, BlinkMacSystemFont, Segoe UI, Helvetica Neue, Arial, sans-serif`
- **Display / Editorial**: `Suisse Int'l`, fallback: `Geist, -apple-system, sans-serif` — reserved for large hero headlines and marketing moments
- **Monospace**: `Geist Mono`, fallback: `ui-monospace, SFMono-Regular, Menlo, monospace`

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| Hero H1 | Suisse Int'l | 64px (4.00rem) | 500 | 1.05 | Homepage hero, top marketing statement |
| Section H2 | Suisse Int'l | 40px (2.50rem) | 500 | 1.10 | Section headers |
| Card H3 | Geist | 24px (1.50rem) | 600 | 1.25 | Card titles, feature headers |
| Subhead | Geist | 20px (1.25rem) | 500 | 1.35 | Sub-section intros |
| Body Large | Geist | 18px (1.13rem) | 400 | 1.60 | Intro paragraphs |
| Body | Geist | 16px (1.00rem) | 400 | 1.55 | Standard reading text |
| Body Medium | Geist | 16px (1.00rem) | 500 | 1.55 | Nav links, button labels |
| Small | Geist | 14px (0.88rem) | 400 | 1.50 | Form hints, secondary UI text |
| Caption | Geist | 13px (0.81rem) | 400 | 1.45 | Metadata, footnotes |
| Mono Body | Geist Mono | 14px (0.88rem) | 400 | 1.55 | Code snippets, API keys |

### Principles
- **Two-font role separation**: Suisse handles editorial impact (hero, section headers); Geist handles everything functional (body, UI, buttons). Never mix them within the same text block.
- **Weight discipline**: 400 (reading), 500 (emphasis, UI labels), 600 (strong emphasis, card titles) — Clerk rarely if ever uses 700 bold in body contexts.
- **Neutral tracking**: Unlike Linear's aggressive negative letter-spacing, Clerk keeps tracking close to default — the Swiss-grotesk letterforms are legible enough without compression tricks.
- **Two-gray hierarchy**: Use `#747686` for general secondary text, reserve `#5E5F6E` for moments needing slightly stronger contrast (e.g., form labels next to input values) — this nuance is easy to miss but core to Clerk's polish.

## 4. Component Stylings

### Buttons

**Primary Button (Signature)**
- Background: `#6C47FF`
- Text: `#FFFFFF`, Geist 16px weight 500
- Padding: 10px 20px
- Radius: 6px
- Shadow (compound recipe — replicate all layers):
  1. Ring: `0 0 0 0.5px rgba(19,19,22,0.08)` (crisp hairline border simulated as shadow, not CSS border)
  2. Inset top highlight: `inset 0 1px 0 rgba(255,255,255,0.16)` (glassy sheen at the top edge)
  3. Outer lift: `0 1px 3px rgba(19,19,22,0.20)`
- Hover: outer lift deepens to `0 2px 6px rgba(19,19,22,0.25)`, background lightens slightly
- Use: primary CTAs ("Get started", "Start building")

**Secondary Button ("Glass White Key")**
- Background: `#F7F7F8`
- Text: `#131316`, Geist 16px weight 500
- Padding: 10px 20px
- Radius: 12px (notably larger than primary — softer, friendlier silhouette)
- Shadow (compound recipe — this is Clerk's most elaborate signature detail):
  1. Ring: `0 0 0 0.5px rgba(19,19,22,0.06)`
  2. Diffuse layer 1: `0 1px 2px rgba(19,19,22,0.06)`
  3. Diffuse layer 2: `0 4px 10px rgba(19,19,22,0.08)`
  4. Inset white highlight: `inset 0 24px 24px -20px rgba(255,255,255,0.5)` (a large, soft top-inset highlight simulating light hitting a glossy plastic key — the most distinctive single shadow value in the whole system)
- Use: secondary CTAs ("Contact sales", "View docs")

**Ghost Button**
- Background: transparent
- Text: `#747686`, hover to `#131316`
- Padding: 8px 12px
- Radius: 8px
- Use: tertiary nav-adjacent actions

### Cards & Containers
- Background: `#FFFFFF`
- Border: `0.5px solid rgba(19,19,22,0.06)` (simulated as shadow ring where possible for crispness)
- Radius: 12px (standard), 16px (featured/large cards)
- Shadow: `0 1px 2px rgba(19,19,22,0.04), 0 4px 12px rgba(19,19,22,0.06)` — layered soft diffusion, never a single hard shadow
- Padding: 24–32px
- Hover (interactive cards): shadow deepens one step, subtle 2px lift via `transform: translateY(-2px)`

### Inputs & Forms

**Text Input**
- Background: `#FFFFFF`
- Text: `#131316`, Geist 16px
- Border: `1px solid rgba(19,19,22,0.10)`
- Radius: 8px
- Padding: 10px 14px
- Focus: border transitions to `#6C47FF`, focus ring `0 0 0 4px rgba(108,71,255,0.12)`

**Search Input**
- Background: `#F7F7F8`
- Text: `#131316`
- Radius: 8px
- Padding: 8px 12px (icon-aware left padding)

### Badges & Pills
- Background: `rgba(108,71,255,0.08)` (violet tint)
- Text: `#6C47FF`, Geist 13px weight 500
- Radius: 9999px (full pill)
- Padding: 4px 10px
- Use: plan tags, status indicators ("Beta", "New")

### Navigation
- Light sticky header on `#F7F7F8` or translucent white with backdrop blur
- Logo left-aligned
- Links: Geist 15px weight 500, `#747686` text, hover to `#131316`
- CTA: Primary violet button, right-aligned, full signature shadow recipe applied
- Mobile: hamburger collapse below 768px

### Image Treatment
- Product/dashboard screenshots shown inside rounded cards (16px radius) with the full layered card shadow — screenshots are never presented "bare," always framed as a component
- Auth widget previews (sign-in/sign-up forms) are the hero visual motif — rendered at high fidelity to showcase the product itself as the marketing asset

## 5. Layout Principles

### Spacing System
- Base unit: 4px
- Scale: 4px, 8px, 12px, 16px, 20px, 24px, 32px, 40px, 48px, 64px, 96px
- Primary rhythm: 8px/16px for component-internal spacing; 64px/96px for section separation
- The finer 4px base (vs. the more common 8px) supports the precision needed for compound shadow layering

### Grid & Container
- Max content width: ~1200px
- Hero: centered column with auth-widget visual (sign-in form) as the focal image, often floating with its own card shadow
- Feature sections: 2–3 column grids, 24–32px gutters
- Component showcase sections: side-by-side code snippet + live-rendered component, reinforcing "see it, ship it"

### Whitespace Philosophy
- **Calm gray as neutral ground**: The `#F7F7F8` background is intentionally unremarkable — it exists purely to let card shadows and violet accents read clearly against it.
- **Components as focal points**: Unlike text-heavy marketing sites, Clerk's whitespace is organized around showcasing UI components themselves — buttons, forms, cards — as the primary visual content, with generous padding (32px+) around each showcased component.
- **Section rhythm**: 80–96px vertical section padding, consistent with mid-size SaaS marketing conventions.

### Border Radius Scale
- Small (6px): Primary buttons — slightly tighter, more "clickable"
- Medium (8px): Inputs, ghost buttons, small badges
- Large (12px): Secondary buttons, standard cards
- XL (16px): Featured cards, screenshot frames
- Full Pill (9999px): Badges, status tags

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, `#F7F7F8` bg | Page background |
| Ring (Level 1) | `0 0 0 0.5px rgba(19,19,22,0.06–0.08)` | Hairline component edges |
| Surface (Level 2) | `0 1px 2px rgba(19,19,22,0.04), 0 4px 12px rgba(19,19,22,0.06)` | Cards, dropdowns |
| Primary Button (Signature) | Ring + inset top highlight + `0 1px 3px rgba(19,19,22,0.20)` | Primary CTA only |
| Secondary Button (Signature) | Ring + dual diffuse layers + `inset 0 24px 24px -20px rgba(255,255,255,0.5)` | Secondary CTA only — Clerk's most elaborate shadow |
| Elevated (Level 3) | `0 8px 24px rgba(19,19,22,0.12)` | Modals, popovers |

**Shadow Philosophy**: Clerk treats shadows as a compositional craft, not a utility. Every interactive surface — especially buttons — is built from *multiple stacked layers*: a crisp sub-pixel ring for edge definition, an inset highlight for simulated light reflection, and a soft outer diffuse layer for physical lift. This compound approach is what makes Clerk's buttons feel like manufactured objects (glass, plastic, metal) rather than flat rectangles. The secondary button's `inset 0 24px 24px -20px rgba(255,255,255,0.5)` is the system's most distinctive single value — a large negative-spread inset shadow that concentrates a soft white highlight along the top edge, mimicking how light catches the beveled top of a glossy plastic key. Always replicate the *full* layered recipe — a single flat `box-shadow` value will not read as "Clerk."

## 7. Do's and Don'ts

### Do
- Always build buttons with the full compound shadow recipe (ring + inset highlight + outer diffuse) — never approximate with one shadow layer
- Keep the page background at `#F7F7F8`, reserving pure white for card surfaces to create layered depth
- Use the two-tier gray system (`#747686` / `#5E5F6E`) deliberately — don't collapse them into one gray
- Pair Suisse (display) with Geist (everything else) — never use Suisse for body text or Geist for hero headlines
- Reserve `#6C47FF` violet strictly for CTAs, links, and active/focus states

### Don't
- Don't flatten buttons to a single `box-shadow` — the layered recipe is the entire point of the system
- Don't use pure black text — `#131316` prevents the harsh contrast of true black on light gray
- Don't apply sharp 0–4px radii — Clerk's silhouette is deliberately soft (6px minimum, 12px+ preferred)
- Don't introduce a second chromatic accent — violet is the only brand color in the system
- Don't skip the inset highlight layer — without it, buttons look flat and generic rather than "engineered"

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|-------------|
| Mobile | <640px | Single column, hero H1 drops to 36px, hamburger nav |
| Tablet | 640–1024px | Two-column feature/card grids begin |
| Desktop | 1024–1280px | Full grids, standard nav, auth-widget hero at full scale |
| Large Desktop | >1280px | Max-width container (1200px), generous margins |

### Touch Targets
- Buttons maintain 10px vertical padding, comfortable 44px+ total tap height
- Pill badges are display-only; interactive pills get minimum 32px height
- Form inputs use 10px padding minimum for touch-friendly tap targets

### Collapsing Strategy
- Hero H1: 64px → 44px → 36px across breakpoints
- Auth widget hero visual: scales down but retains full shadow fidelity even on mobile
- Card grids: 3-column → 2-column → single column
- Navigation: horizontal links + CTA → hamburger at 768px

## 9. Agent Prompt Guide

### Quick Color Reference
- Primary CTA: Clerk Violet (`#6C47FF`)
- Page Background: Cool Light Gray (`#F7F7F8`)
- Card Surface: White (`#FFFFFF`)
- Heading text: Near-Black (`#131316`)
- Secondary text (warm): `#747686`
- Secondary text (cool): `#5E5F6E`
- Violet tint (badges): `rgba(108,71,255,0.08)`

### Example Component Prompts
- "Create a hero section on `#F7F7F8` background. Headline in Suisse Int'l 64px weight 500, line-height 1.05, color `#131316`. Subtitle in Geist 18px weight 400, color `#747686`. Primary button: `#6C47FF` background, white text, 6px radius, shadow ring `0 0 0 0.5px rgba(19,19,22,0.08)` + inset top highlight `inset 0 1px 0 rgba(255,255,255,0.16)` + outer `0 1px 3px rgba(19,19,22,0.20)`."
- "Design a secondary 'glass key' button: `#F7F7F8` background, `#131316` text, 12px radius, ring `0 0 0 0.5px rgba(19,19,22,0.06)`, diffuse `0 1px 2px rgba(19,19,22,0.06), 0 4px 10px rgba(19,19,22,0.08)`, inset highlight `inset 0 24px 24px -20px rgba(255,255,255,0.5)`."
- "Build a card: white background, `0.5px solid rgba(19,19,22,0.06)` border, 12px radius, shadow `0 1px 2px rgba(19,19,22,0.04), 0 4px 12px rgba(19,19,22,0.06)`. Title Geist 24px weight 600 `#131316`. Body Geist 16px weight 400 `#747686`."
- "Create a violet pill badge: `rgba(108,71,255,0.08)` background, `#6C47FF` text, Geist 13px weight 500, 9999px radius, 4px 10px padding."

### Iteration Guide
1. Buttons are the system's centerpiece — always apply the full compound shadow (ring + inset highlight + outer diffuse), never a flat single-layer shadow
2. Suisse is for display/hero only; Geist handles all functional UI and body text — don't cross these roles
3. Distinguish the two secondary grays intentionally: `#747686` for general body/secondary, `#5E5F6E` for slightly higher-contrast metadata/labels
4. Radius runs soft throughout (6–16px) — never introduce sharp 0–4px corners
5. `#6C47FF` is the sole chromatic accent — keep everything else grayscale
6. Card and screenshot frames always carry layered (not single) shadow values for the characteristic "physical material" depth
