# Design System Inspired by Neon

## 1. Visual Theme & Atmosphere

Neon's site is a high-end server room after midnight — a pure black void (`#000000`, not near-black, actually black) where the only sign of life is a single electric green (`#34D59A`) glowing like a status LED. This is the most extreme monochrome-plus-one system in the developer-tool space: no grays of nuance, no secondary chromatic accent, just true black, true white, and one relentless green. The effect is closer to a terminal window scaled up to fill an entire browser than a conventional marketing site — which is exactly the point, since Neon sells serverless Postgres to an audience that lives in terminals.

Typography leans into scale as the primary expressive device. Everything runs on Inter, but at sizes far larger than typical SaaS marketing sites — 72px hero headlines, 48px section headers, and even body copy set at a generous 24px. Where Zed and Railway use serif headlines for editorial gravitas, Neon achieves impact purely through raw size and weight against the black void — there is no ornamentation, only scale and contrast. This typographic bigness paired with total color restraint creates a distinct feeling: less "designed," more "broadcast" — like text on a jumbotron or a terminal boot sequence blown up to billboard proportions.

The signature structural tension in the system is the contrast between **pill-shaped buttons** (maximum radius, fully rounded) and **sharp 4px-radius containers** everywhere else. Nothing else in the interface rounds beyond 4px — cards, code blocks, input fields all stay close to rectangular — except buttons, which go fully pill. This deliberate mismatch makes every CTA visually pop as "the interactive thing" purely through shape language, without needing extra color or decoration. The other unmistakable signature is Neon's use of an actual terminal command (`$ npx neon init`) as a primary call-to-action — the CTA doesn't say "Get Started," it shows you the exact command you'll type, collapsing the gap between marketing promise and product reality to zero.

**Key Characteristics:**
- True black canvas: `#000000` (not `#0a0a0a` or near-black — genuinely pure black) with pure white (`#FFFFFF`) as the only neutral counterpoint
- Single chromatic accent: electric green `#34D59A`, with `#39A57D` as a slightly muted companion for links/secondary accents — no other hue appears anywhere
- Inter at unusually large scale throughout: 72px H1, 48px H2, 24px body — bigness is the primary design device, not ornamentation
- Signature shape tension: fully pill-radius buttons (`9999px`) against sharp 4px-radius everything-else (cards, inputs, code blocks)
- CTA-as-terminal-command: `$ npx neon init` rendered as a monospace, clickable/copyable command block used as a primary call-to-action
- 8px base spacing grid
- Depth achieved through layered near-black surfaces (not pure black at every level) rather than drop shadows — shadows are nearly absent from the system
- Overall tone: terminal culture elevated to billboard scale — maximal restraint, maximal size

## 2. Color Palette & Roles

### Background Surfaces
- **True Black** (`#000000`): The deepest, most literal background — page canvas, hero sections. Genuinely pure black, not a near-black approximation.
- **Elevated Surface 1** (`#0A0A0A`): The first, barely-perceptible step up from true black — used for cards and panels that need minimal separation.
- **Elevated Surface 2** (`#141414`): A slightly more visible dark gray for nested/secondary surfaces, code blocks, and hover states.
- **Border Surface** (`#1F1F1F`): The lightest of the near-black grays, used as a solid border/divider color where a hairline needs to actually register against true black.

### Text & Content
- **Primary Text** (`#FFFFFF`): Pure white — used without hesitation for headlines and primary content, in deliberate contrast to systems (like Linear) that soften to off-white. Neon wants maximum stark contrast.
- **Secondary Text** (`rgba(255,255,255,0.64)`): Muted white for body copy and descriptions.
- **Tertiary Text** (`rgba(255,255,255,0.40)`): Faded white for metadata, timestamps, placeholder text.

### Brand & Accent
- **Electric Green** (`#34D59A`): The system's single chromatic anchor — primary button backgrounds (on light/white pill buttons, used as text or icon color; see Buttons section), active states, terminal cursor blink, data visualization highlights, glow effects.
- **Muted Green** (`#39A57D`): A calmer companion used for links and secondary accents where the full-intensity electric green would be too loud (e.g., inline text links within body copy).
- **Green Glow** (`rgba(52,213,154,0.16)`): Soft radial glow used behind hero graphics and around focused/active elements — Neon's equivalent of Railway's purple bloom, but sharper and more electric in character.

### Border & Divider
- **Hairline Border** (`#1F1F1F`): Default solid border for cards, code blocks, and dividers — since `rgba(255,255,255,x)` borders would need very low opacity to avoid glowing against true black, Neon favors solid dark grays for definition instead.
- **Focus Border** (`#34D59A`): Full-intensity green border for focused inputs and active states.

## 3. Typography Rules

### Font Family
- **Primary**: `Inter`, fallback: `-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif` — used for everything: headlines, body, UI chrome
- **Monospace**: `"Berkeley Mono"` or `ui-monospace`, fallback: `SFMono-Regular, Menlo, Consolas, monospace` — used for the signature terminal-command CTA, code samples, and SQL/connection-string examples

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| Hero H1 | Inter | 72px (4.50rem) | 500 | 1.05 (tight) | Homepage hero — maximal scale, the system's signature move |
| Section H2 | Inter | 48px (3.00rem) | 500 | 1.10 | Section headers |
| Card H3 | Inter | 28px (1.75rem) | 500 | 1.25 | Card titles, feature headers |
| Body Large | Inter | 24px (1.50rem) | 400 | 1.50 | Standard body copy — notably larger than most systems' "body large" |
| Body | Inter | 18px (1.13rem) | 400 | 1.55 | Secondary reading text, smaller sections |
| Body Medium | Inter | 16px (1.00rem) | 500 | 1.50 | Nav links, button labels |
| Small | Inter | 14px (0.88rem) | 400 | 1.50 | Form hints, secondary UI text |
| Caption | Inter | 13px (0.81rem) | 400 | 1.45 | Metadata, timestamps |
| Mono CTA | Berkeley Mono | 16px (1.00rem) | 400 | 1.50 | `$ npx neon init` style command CTAs |
| Mono Body | Berkeley Mono | 14px (0.88rem) | 400 | 1.55 | Code blocks, SQL/connection strings |

### Principles
- **Scale is the message**: Neon achieves visual impact through sheer type size (72px H1, 24px body) rather than color, ornamentation, or serif drama — this is the single most important principle to replicate.
- **One weight family**: Inter is used almost exclusively at 400 (body) and 500 (headings, emphasis) — Neon doesn't reach for 600/700 bold; scale does the work weight would otherwise do.
- **Tight leading at display sizes**: Line-height compresses to 1.05–1.10 at hero/section sizes, keeping large type feeling dense and confident rather than sprawling.
- **Terminal commands are typographically sacred**: Any `$ npx ...` or SQL snippet renders in monospace, verbatim, often as a clickable/copyable CTA block rather than plain code styling.

## 4. Component Stylings

### Buttons

**Primary Pill Button**
- Background: `#34D59A`
- Text: `#000000`, Inter 16px weight 500
- Padding: 12px 24px
- Radius: 9999px (full pill — the system's signature shape)
- Shadow: none, or an extremely subtle `0 0 20px rgba(52,213,154,0.16)` glow on hover only
- Hover: background lightens slightly to `#4EE0AC`, glow intensifies
- Use: primary CTAs ("Start Free", "Sign Up")

**Secondary Pill Button**
- Background: `#FFFFFF`
- Text: `#000000`, Inter 16px weight 500
- Padding: 12px 24px
- Radius: 9999px
- Border: none (pure white fill provides sufficient contrast against black)
- Use: secondary CTAs ("Contact Us", "Book a Demo")

**Terminal Command CTA (Signature)**
- Background: `#0A0A0A`
- Text: `$` prompt in `rgba(255,255,255,0.4)`, command in `#34D59A`, Berkeley Mono 16px weight 400
- Padding: 12px 20px
- Radius: 4px (sharp — intentionally breaks from the pill family to read as "code," not "button")
- Border: `1px solid #1F1F1F`
- Icon: copy-to-clipboard icon right-aligned, `rgba(255,255,255,0.4)`
- Use: `$ npx neon init` — the platform's most distinctive CTA, converting the actual product command into the marketing action itself

**Ghost Button**
- Background: transparent
- Text: `rgba(255,255,255,0.64)`, hover to `#FFFFFF`
- Padding: 8px 12px
- Use: nav-adjacent tertiary actions

### Cards & Containers
- Background: `#0A0A0A`
- Border: `1px solid #1F1F1F`
- Radius: 4px (sharp — matches the terminal-CTA radius, reinforcing "everything except buttons stays rectangular")
- Shadow: none — depth communicated purely through the background-layer step (`#000` → `#0A0A0A` → `#141414`), not shadow
- Padding: 24–32px
- Hover (interactive cards): border brightens to `#34D59A` at reduced opacity, e.g., `rgba(52,213,154,0.3)`

### Inputs & Forms

**Text Input**
- Background: `#0A0A0A`
- Text: `#FFFFFF`, Inter 16px
- Border: `1px solid #1F1F1F`
- Radius: 4px
- Padding: 10px 14px
- Focus: border transitions to `#34D59A`, focus ring `0 0 0 3px rgba(52,213,154,0.16)`

**Connection String / SQL Input**
- Background: `#141414`
- Text: Berkeley Mono 14px, `#34D59A` for keywords/highlighted tokens, `#FFFFFF` for plain values
- Border: `1px solid #1F1F1F`
- Radius: 4px
- Use: database connection string display, SQL query examples

### Badges & Pills
- Background: `rgba(52,213,154,0.12)`
- Text: `#34D59A`, Inter 13px weight 500
- Radius: 9999px
- Padding: 3px 10px
- Use: "Beta", version tags, feature flags — note badges also use pill radius, aligning with the button family rather than the card/sharp family

### Navigation
- Black sticky header on `#000000`, bottom border `1px solid #1F1F1F`
- Logo left-aligned
- Links: Inter 15px weight 500, `rgba(255,255,255,0.64)` text, hover to `#FFFFFF`
- CTA: Primary green pill button, right-aligned
- Mobile: hamburger collapse below 768px

### Image Treatment
- Product screenshots and data-flow diagrams shown with sharp 4px-radius frames and `1px solid #1F1F1F` border — no glow, no heavy shadow, letting the true-black background do the isolation work
- Data visualizations (branching diagrams, scale-to-zero graphs) use `#34D59A` as the sole line/highlight color against black, terminal-plot style

## 5. Layout Principles

### Spacing System
- Base unit: 8px
- Scale: 8px, 16px, 24px, 32px, 48px, 64px, 96px, 128px
- Primary rhythm: 16px/24px component-internal; 96px+ section separation — Neon's sections breathe even more than most dark-mode systems, proportional to its oversized type

### Grid & Container
- Max content width: ~1200px
- Hero: centered single column, headline dominant at 72px, terminal-command CTA directly beneath as the primary action
- Feature sections: 2-column grids more common than 3-column, giving each feature more room given the larger body type size
- Symmetrical, centered compositions are the default — Neon avoids asymmetric magazine-style layouts in favor of centered stacks

### Whitespace Philosophy
- **True black as absence**: Unlike Linear's "near-black as native medium" or Railway's "colored night sky," Neon's black is genuinely empty — the void is total, and content reads as isolated points of light within it.
- **Size replaces density**: Because type runs so large (72px/48px/24px), sections need proportionally more whitespace just to contain the type comfortably — this isn't decorative restraint, it's structural necessity.
- **Centered symmetry**: Headlines, CTAs, and feature intros are consistently center-aligned, reinforcing the "broadcast/terminal boot screen" feeling rather than an editorial magazine layout.

### Border Radius Scale
- Sharp (4px): Cards, inputs, code blocks, terminal-CTA — the default for nearly all non-button surfaces
- Full Pill (9999px): Buttons and badges only — the deliberate exception that makes CTAs pop through shape alone

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, `#000000` bg | Page background — true void |
| Surface (Level 1) | `#0A0A0A` bg + `1px solid #1F1F1F` border | Cards, terminal-CTA, panels |
| Nested Surface (Level 2) | `#141414` bg | Code blocks, connection-string inputs, nested content |
| Glow (Signature) | `0 0 20px rgba(52,213,154,0.16)` | Primary button hover, focused inputs — the only "shadow" concept in the system |
| Elevated (Level 3) | `#141414` bg + `1px solid #34D59A` at 30% opacity | Dropdowns, active/selected states |

**Shadow Philosophy**: Neon almost entirely rejects conventional drop shadows — on true black, dark shadows are invisible and light shadows would look like mistakes. Instead, depth is communicated through **discrete background-layer steps** (`#000000` → `#0A0A0A` → `#141414`), each one a clearly perceptible jump in luminance rather than a soft gradient. The only shadow-like effect in the system is the green glow (`rgba(52,213,154,0.16)`), reserved exclusively for moments of interactivity or focus — hover states, active inputs — functioning more like a status LED illuminating than a physical shadow implying elevation.

## 7. Do's and Don'ts

### Do
- Keep the background genuinely `#000000` — don't soften to `#0a0a0a` or similar near-blacks; the starkness is intentional
- Use Inter at unusually large sizes for headlines and even body text (72px/48px/24px) — scale is the primary design device
- Apply pill radius (`9999px`) exclusively to buttons and badges; keep everything else at 4px sharp
- Render terminal commands (`$ npx neon init`) as first-class CTA components in monospace, not styled as generic buttons
- Reserve `#34D59A` for the single chromatic accent — CTAs, links, focus states, data highlights only

### Don't
- Don't soften true black into a near-black gray — Neon's void is meant to be absolute
- Don't apply drop shadows for elevation — use discrete background-layer steps (`#000` → `#0A0A0A` → `#141414`) instead
- Don't round cards, inputs, or code blocks beyond 4px — pill radius is reserved exclusively for buttons/badges
- Don't introduce a second chromatic accent — green is the only hue in the entire system
- Don't undersize body text to conventional 16px defaults — Neon's larger-than-usual body scale (18–24px) is part of its visual identity

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|--------------|
| Mobile | <640px | Single column, hero H1 drops to 40px, hamburger nav |
| Tablet | 640–1024px | Two-column feature grids begin |
| Desktop | 1024–1280px | Full grids, standard nav, hero at full 72px scale |
| Large Desktop | >1280px | Max-width container (1200px), generous margins |

### Touch Targets
- Pill buttons maintain 12px vertical padding, generous 44px+ total tap height
- Terminal-CTA blocks include a dedicated copy-icon tap target (minimum 32px) separate from the text itself
- Badges are display-only; interactive pill variants get 32px minimum height

### Collapsing Strategy
- Hero H1: 72px → 48px → 40px across breakpoints
- Body Large: 24px → 20px → 18px on smaller viewports (still notably larger than typical body text even at mobile size)
- Terminal-CTA: retains monospace styling and full border at all sizes, may wrap command text on narrow viewports
- Navigation: horizontal links + CTA → hamburger at 768px

## 9. Agent Prompt Guide

### Quick Color Reference
- Primary CTA: Electric Green (`#34D59A`)
- Page Background: True Black (`#000000`)
- Card Surface: `#0A0A0A`
- Nested Surface: `#141414`
- Heading/Body text: Pure White (`#FFFFFF`)
- Secondary text: `rgba(255,255,255,0.64)`
- Border: `#1F1F1F`
- Muted accent/links: `#39A57D`

### Example Component Prompts
- "Create a hero section on `#000000` background. Headline in Inter 72px weight 500, line-height 1.05, color `#FFFFFF`. Subtitle in Inter 24px weight 400, color `rgba(255,255,255,0.64)`. Primary pill button: `#34D59A` background, black text, 9999px radius, 12px 24px padding. Below it, a terminal-CTA block: `#0A0A0A` background, `1px solid #1F1F1F` border, 4px radius, `$ npx neon init` in Berkeley Mono 16px, `$` in muted white and command in `#34D59A`."
- "Design a card on true black: `#0A0A0A` background, `1px solid #1F1F1F` border, 4px radius, 24px padding — no shadow. Title Inter 28px weight 500 `#FFFFFF`. Body Inter 18px weight 400 `rgba(255,255,255,0.64)`."
- "Build a green pill badge: `rgba(52,213,154,0.12)` background, `#34D59A` text, Inter 13px weight 500, 9999px radius, 3px 10px padding."
- "Create navigation: black sticky header on `#000000`, bottom border `1px solid #1F1F1F`. Inter 15px weight 500 links in `rgba(255,255,255,0.64)`, hover `#FFFFFF`. Green pill CTA button right-aligned."

### Iteration Guide
1. Background must be literal `#000000` — never approximate with near-black grays
2. Type scale is oversized by convention: 72px H1, 48px H2, 24px body — don't default to typical 16px body text
3. Radius is binary: 4px for everything except buttons/badges, which are always full pill (`9999px`)
4. Depth comes from discrete background-layer steps (`#000` → `#0A0A0A` → `#141414`), not shadows — the only shadow-equivalent is the green glow on hover/focus
5. `#34D59A` is the sole chromatic color — everything else is black, white, or grayscale-on-black
6. Wherever a real CLI/SQL command exists, prefer rendering it as a monospace terminal-CTA block over a generic styled button
7. Favor centered, symmetrical compositions over asymmetric editorial layouts — Neon reads as a broadcast/terminal experience, not a magazine
8. When space allows, let body copy run at its full 24px/18px scale rather than defaulting down to 16px — the oversized type is core to Neon's identity, not an accessibility fallback
9. When a new surface needs to feel "alive," reach for the green glow rather than motion or gradient — Neon's energy comes from a single restrained light source, not animation
10. Resist the temptation to add a second accent color for variety — Neon's discipline (one hue, true black, pure white) is the feature, not a limitation to work around
