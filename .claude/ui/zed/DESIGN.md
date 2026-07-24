# Design System Inspired by Zed

## 1. Visual Theme & Atmosphere

Zed's marketing site reads like a well-machined tool laid out on a workbench: a warm paper-gray canvas (`#F5F5F3`) that feels closer to matte industrial stock than digital white, punctuated by a single, unapologetic engineering blue (`#1348DC`). Where most developer-tool sites retreat into dark-mode near-black, Zed does the opposite — it builds its entire identity in daylight, on a surface that has the tactile warmth of a printed spec sheet rather than the cold glow of a screen. This is a deliberate statement: Zed is a GPU-accelerated, Rust-native editor obsessed with raw performance, and its visual language borrows the confidence of precision engineering rather than the theatrics of "developer aesthetic" dark themes.

The typography system is a three-font division of labor that mirrors the editor's own architecture. Body copy runs on "writer," Zed's in-house humanist sans, chosen for long-form legibility. Headlines break convention entirely by switching to **IBM Plex Serif** — a deliberate, almost literary choice that signals craftsmanship and intent rather than generic tech-startup sans-serif hype. Code and technical labels use "zedMono," the same monospace family that ships inside the editor itself, creating a direct visual through-line between the marketing site and the product. This heading-in-serif / body-in-sans / code-in-mono split is Zed's most distinctive typographic signature: it reads as "we built the tool, we didn't just market it."

The color system is almost monastic — a warm off-white background, near-black text (`#242529`), and exactly one chromatic accent (`#1348DC`) used with total discipline for CTAs, links, and interactive states. Where the accent needs a lighter companion, Zed reaches for a soft sky blue (`#8EC5FF`) rather than diluting the primary hue. Radius is kept deliberately tight (4px, sometimes 0px) — nothing rounds into softness. And the primary button carries Zed's signature detail: an **inset bottom shadow** that mimics the depression of a real, physical key being pressed — a tactile metaphor entirely appropriate for a text editor whose entire value proposition is "the keys respond instantly."

**Key Characteristics:**
- Light-mode-native, paper-warm canvas: `#F5F5F3` background (not pure white — has a faint warm-gray cast)
- Single engineering-blue accent: `#1348DC`, with `#8EC5FF` as its light companion — no secondary chromatic colors
- Three-font system: "writer" (body sans), **IBM Plex Serif** (headings — the signature move), "zedMono" (code/technical)
- Sharp, restrained radius scale: 4px standard, 0px on secondary buttons and inputs — nothing rounds into softness
- Primary button carries a physical "pressed key" shadow: `inset 0 -2px 0 rgb(5,55,148), 0 1px 3px rgb(230,239,254)`
- Text hierarchy stays achromatic and calm: `#242529` primary, `#494E58` for links/secondary
- 8px base spacing grid — an engineer's grid, not a designer's
- Overall tone: matte, tactile, unpretentious — performance communicated through precision, not decoration

## 2. Color Palette & Roles

### Background Surfaces
- **Paper Gray** (`#F5F5F3`): The primary canvas for the entire site. A warm, matte off-white — never pure white — that evokes printed technical documentation rather than a glossy screen.
- **Secondary Button Surface** (`#FDFDFC`): A near-white surface reserved for secondary buttons, one shade lighter than the page background for subtle contrast.
- **Card Surface** (`#FFFFFF`): Pure white used sparingly for elevated content blocks and code panels, where maximum contrast against body text is needed.

### Text & Content
- **Primary Text** (`#242529`): Near-black with a soft charcoal cast — never pure `#000000`. Used for body copy and default UI text.
- **Link / Secondary Text** (`#494E58`): A muted slate gray for links, captions, and de-emphasized copy — legible but clearly secondary.
- **Tertiary Text** (`rgba(36,37,41,0.6)`): Faded charcoal for metadata, timestamps, and placeholder text.

### Brand & Accent
- **Engineering Blue** (`#1348DC`): The single chromatic anchor of the entire system — primary button backgrounds, active links, focus states, brand marks. Used with total discipline; never decorative.
- **Sky Blue** (`#8EC5FF`): The accent's light companion — used for hover highlights, secondary accents, and subtle background tints behind code or feature callouts.
- **Deep Blue Shadow** (`rgb(5,55,148)`): The darkened variant of the brand blue, used exclusively in the primary button's inset shadow for the "pressed key" effect.

### Border & Divider
- **Hairline Border** (`rgba(36,37,41,0.12)`): Default border for cards, dividers, and input outlines on the paper-gray canvas.
- **Button Border (Secondary)** (`rgba(36,37,41,0.16)`): Slightly more visible border for secondary/outline buttons.
- **Focus Ring** (`#1348DC` at 40% opacity): Keyboard-focus outline on interactive elements.

### Dark Mode (companion, for in-app/editor contexts)
- **Editor Background** (`#1E1E20`): Zed's own dark theme canvas, referenced when the marketing site needs to preview or embed the editor.
- **Editor Text** (`#F5F5F3`): Inverted — the light paper tone becomes the dark-mode foreground.
- **Editor Accent** (`#4C82FF`): A slightly brightened blue for legibility against dark backgrounds.

## 3. Typography Rules

### Font Family
- **Body**: `"writer"` (Zed's in-house humanist sans), fallback: `-apple-system, BlinkMacSystemFont, Segoe UI, Helvetica Neue, Arial, sans-serif`
- **Heading**: `"IBM Plex Serif"`, fallback: `Georgia, Cambria, Times New Roman, serif` — reserved exclusively for headlines; never used for body or UI chrome
- **Monospace**: `"zedMono"`, fallback: `ui-monospace, SFMono-Regular, Menlo, Consolas, monospace`

### Hierarchy

| Role | Font | Size | Weight | Line Height | Notes |
|------|------|------|--------|-------------|-------|
| Hero H1 | IBM Plex Serif | 48px (3.00rem) | 500 | 1.15 | Homepage hero, top-level marketing statements |
| Section H2 | IBM Plex Serif | 25.6px (1.60rem) | 500 | 1.25 | Section headers, feature titles |
| Card H3 | IBM Plex Serif | 20px (1.25rem) | 500 | 1.30 | Card headers, sub-feature titles |
| Body Large | writer | 18px (1.13rem) | 400 | 1.60 | Intro paragraphs, feature descriptions |
| Body | writer | 16px (1.00rem) | 400 | 1.55 | Standard reading text |
| Body Medium | writer | 16px (1.00rem) | 500 | 1.55 | Nav links, labels, button text |
| Small | writer | 14px (0.88rem) | 400 | 1.50 | Secondary copy, form hints |
| Caption | writer | 13px (0.81rem) | 400 | 1.45 | Metadata, timestamps, footnotes |
| Mono Body | zedMono | 14px (0.88rem) | 400 | 1.55 | Code blocks, terminal output |
| Mono Label | zedMono | 12px (0.75rem) | 500 | 1.40 | Keybinding tags, technical badges |

### Principles
- **Serif headlines are non-negotiable**: Every H1/H2/H3 uses IBM Plex Serif. This single decision is what separates Zed's marketing site from every other dark-mode developer tool — it reads as crafted, not templated.
- **Body stays humanist and quiet**: "writer" is used at moderate weights (400/500 only) — no heavy display weights in body copy, keeping the serif headlines as the sole dramatic element.
- **Code is code**: zedMono appears only for genuinely technical content (code samples, keybindings, terminal snippets) — never decoratively.
- **No negative letter-spacing games**: Unlike geometric-sans systems, Zed's serif headlines use default/neutral tracking — the drama comes from the typeface choice itself, not spacing manipulation.

## 4. Component Stylings

### Buttons

**Primary Button**
- Background: `#1348DC`
- Text: `#FFFFFF`, "writer" 16px weight 500
- Padding: 10px 20px
- Radius: 4px
- Shadow: `inset 0 -2px 0 rgb(5,55,148), 0 1px 3px rgb(230,239,254)` — the signature "pressed physical key" effect; the inset bottom shadow simulates a beveled key edge, and the soft light-blue drop shadow lifts it off the page
- Hover: shadow compresses slightly (`inset 0 -1px 0`), simulating the key being pressed further down
- Use: primary CTAs ("Download Zed", "Get started")

**Secondary Button**
- Background: `#FDFDFC`
- Text: `#1348DC`, "writer" 16px weight 500
- Padding: 10px 20px
- Radius: 0px (sharp, intentionally flat — contrasts with primary's 4px + depth)
- Border: `1px solid rgba(36,37,41,0.16)`
- Use: secondary actions, "Read the docs", "View on GitHub"

**Ghost / Text Button**
- Background: transparent
- Text: `#494E58`, underline on hover transitioning to `#1348DC`
- Padding: 4px 2px
- Use: inline links, nav items

### Cards & Containers
- Background: `#FFFFFF` on the `#F5F5F3` page canvas (subtle contrast lift)
- Border: `1px solid rgba(36,37,41,0.12)`
- Radius: 4px (matches button radius — system-wide consistency)
- Shadow: `0 1px 3px rgba(36,37,41,0.06)` — extremely restrained, almost imperceptible
- Padding: 24px
- Use: feature cards, changelog entries, testimonial blocks

### Inputs & Forms

**Text Input**
- Background: transparent
- Text: `#242529`, "writer" 16px
- Border: `1px solid rgba(36,37,41,0.16)`
- Radius: 0px (matches secondary button — the "form factor" family shares flat edges)
- Padding: 10px 12px
- Focus: border transitions to `#1348DC`, 2px focus ring at 40% opacity

**Search / Command Input**
- Background: `#FDFDFC`
- Text: `#242529`
- Radius: 4px
- Padding: 8px 12px
- Icon-aware left padding for search glyph

### Badges & Keybinding Tags
- Background: `#FDFDFC`
- Text: `#494E58`, zedMono 12px weight 500
- Border: `1px solid rgba(36,37,41,0.12)`
- Radius: 4px
- Padding: 2px 6px
- Use: keyboard shortcut display (`⌘K`), version tags, platform badges

### Navigation
- Light sticky header on `#F5F5F3` (matches page background — near-invisible seam, relying on a hairline bottom border)
- Bottom border: `1px solid rgba(36,37,41,0.08)`
- Logo left-aligned, wordmark in "writer" medium weight
- Links: "writer" 15px weight 500, `#494E58` text, hover to `#242529`
- CTA: Primary button (blue, pressed-key shadow) right-aligned
- Mobile: hamburger collapse below 768px

### Image Treatment
- Editor screenshots shown with hairline border (`1px solid rgba(36,37,41,0.12)`) and 4px radius — matches the system-wide sharp-corner discipline
- No heavy drop shadows on screenshots — a thin border does the separation work, consistent with the paper-flat aesthetic
- Syntax-highlighted code samples rendered in zedMono directly inline with marketing copy, reinforcing "this is the real editor, not a mockup"

## 5. Layout Principles

### Spacing System
- Base unit: 8px
- Scale: 4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px, 96px
- Primary rhythm: 16px / 24px / 32px for component-internal spacing; 64px / 96px for section separation

### Grid & Container
- Max content width: ~1120px
- Hero: centered single column, generous top padding (96px+), editor screenshot below the fold breaking the grid width for impact
- Feature sections: 2–3 column grids with consistent 24px gutters
- Full-bleed code/terminal demo sections occasionally break container width to feel "workshop-like"

### Whitespace Philosophy
- **Paper as canvas**: Unlike dark-mode systems where blackness is the void, Zed's whitespace is literal — a warm, matte paper tone that invites reading rather than immersion.
- **Restraint over drama**: Sections are separated by generous but not excessive vertical padding (64–96px), avoiding Linear-style theatrical darkness; the calm is achieved through color discipline, not scale.
- **Serif headlines anchor each section**: Because IBM Plex Serif headlines carry visual weight on their own, surrounding whitespace can stay moderate rather than extreme — the typeface does the work.

### Border Radius Scale
- Flat (0px): Secondary buttons, text inputs — the "engineered/precise" family
- Standard (4px): Primary buttons, cards, screenshots, badges — the default radius for nearly everything
- No large/pill radii anywhere in the system — Zed never uses radius above 4px; this is a hard constraint

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow, `#F5F5F3` bg | Page background |
| Surface (Level 1) | `0 1px 3px rgba(36,37,41,0.06)` | Cards, panels |
| Pressed Key (Signature) | `inset 0 -2px 0 rgb(5,55,148), 0 1px 3px rgb(230,239,254)` | Primary button only — Zed's unique tactile signature |
| Pressed Key (Active) | `inset 0 -1px 0 rgb(5,55,148)` | Primary button `:active` state — key travels further down |
| Elevated (Level 2) | `0 4px 12px rgba(36,37,41,0.10)` | Dropdowns, tooltips |

**Shadow Philosophy**: Zed inverts the typical "shadow = floating above the page" convention for its primary button. Instead of lifting the button up, the inset dark-blue shadow at the bottom pushes it *down* — visually depressing it like a real mechanical keycap. This is deliberate physicality in a product whose entire pitch is "keys respond the instant you press them." Every other element in the system stays nearly flat (shadows under 4px blur, low opacity) — the pressed-key button is the one moment of dimensional drama, making it stand out precisely because everything else is calm.

## 7. Do's and Don'ts

### Do
- Use IBM Plex Serif for every heading level — this is Zed's single most identity-defining typographic choice
- Keep the page background warm paper-gray (`#F5F5F3`), never pure white
- Reserve `#1348DC` for the single chromatic accent — CTAs, links, focus states only
- Apply the inset pressed-key shadow only to the primary button — it loses meaning if overused
- Keep radius at 4px or 0px everywhere — no exceptions, no pill shapes
- Use zedMono only for genuinely technical/code content

### Don't
- Don't switch headings to a sans-serif font — the serif/sans split is structural to the brand
- Don't introduce a second chromatic accent color — the system is intentionally monochromatic-plus-one
- Don't round corners beyond 4px — pill buttons or large-radius cards break the engineered aesthetic
- Don't apply heavy drop shadows generally — the pressed-key shadow is meaningful specifically because it's the exception
- Don't use pure black (`#000000`) or pure white (`#FFFFFF`) as primary text/background — always the warm-tinted variants

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|-------------|
| Mobile | <640px | Single column, hero H1 drops to 32px, hamburger nav |
| Tablet | 640–1024px | Two-column feature grids begin |
| Desktop | 1024–1280px | Full three-column grids, standard nav |
| Large Desktop | >1280px | Max-width container (1120px) centers with generous margins |

### Touch Targets
- Buttons maintain 10px vertical padding minimum for comfortable tap area
- Nav links spaced with adequate horizontal gaps for touch
- Keybinding badges are display-only, not interactive, so no touch constraint applies

### Collapsing Strategy
- Hero H1: 48px → 36px → 32px across breakpoints
- Editor screenshots: scale down proportionally, maintain hairline border
- Navigation: horizontal links → hamburger at 768px
- Feature grids: 3-column → 2-column → single column

## 9. Agent Prompt Guide

### Quick Color Reference
- Primary CTA: Engineering Blue (`#1348DC`)
- Page Background: Paper Gray (`#F5F5F3`)
- Card Surface: White (`#FFFFFF`)
- Heading text: Charcoal (`#242529`)
- Body text: Charcoal (`#242529`) at 400 weight
- Link/Secondary text: Slate (`#494E58`)
- Accent companion: Sky Blue (`#8EC5FF`)
- Border: `rgba(36,37,41,0.12)`

### Example Component Prompts
- "Create a hero section on `#F5F5F3` background. Headline in IBM Plex Serif 48px weight 500, line-height 1.15, color `#242529`. Subtitle in 'writer' 18px weight 400, color `#494E58`. Primary button: `#1348DC` background, white text, 4px radius, shadow `inset 0 -2px 0 rgb(5,55,148), 0 1px 3px rgb(230,239,254)`."
- "Design a feature card: white background, `1px solid rgba(36,37,41,0.12)` border, 4px radius, 24px padding. Title in IBM Plex Serif 20px weight 500, `#242529`. Body in 'writer' 16px weight 400, `#494E58`."
- "Build a secondary button: `#FDFDFC` background, `#1348DC` text, 0px radius, `1px solid rgba(36,37,41,0.16)` border, 10px 20px padding."
- "Create a keybinding badge: `#FDFDFC` background, zedMono 12px weight 500, `#494E58` text, 4px radius, `1px solid rgba(36,37,41,0.12)` border, 2px 6px padding."

### Iteration Guide
1. Always set headings to IBM Plex Serif — never substitute a sans-serif for H1–H3
2. The primary button's inset pressed-key shadow is the system's signature detail — replicate it exactly, don't approximate with a generic drop shadow
3. Keep radius binary: 4px (default) or 0px (flat/precise elements) — never introduce 8px, 12px, or pill radii
4. `#1348DC` is the only chromatic color permitted outside of grayscale — treat it as scarce
5. Background stays warm paper-gray, never cold white or pure black
6. zedMono is reserved for code/technical content only
7. When previewing dark-mode/editor contexts, switch to `#1E1E20` background with `#4C82FF` accent — never mix the light marketing palette with the dark editor palette in the same view
8. Favor flat, matte finishes throughout — Zed's aesthetic is closer to a well-kept workshop than a glossy product page, so avoid gradients, glass effects, or heavy blur
9. When in doubt about a new component, ask "would this exist on a well-organized workbench?" — if the answer requires gloss, heavy color, or ornamentation, it likely doesn't belong in Zed's system
10. Treat every added element as a cost: performance-obsessed branding means the UI itself should feel light and instantaneous, never bloated with decorative weight
