# Design System Inspired by shadcn/ui

## 1. Visual Theme & Atmosphere

shadcn/ui is not a brand identity in the conventional sense — it is a design *token architecture* that has become the de facto "default" aesthetic of the modern web-app era. The visual character is deliberately neutral: a zinc-gray achromatic scale (`zinc-50` through `zinc-950`) does nearly all of the work, with near-black primary actions (`#000000` / `#0A0A0A`) rather than a saturated brand hue. There is no signature color because the entire point of the system is to be a foundation other products theme on top of — the "default" theme is the honest, undecorated version of the system, not a placeholder.

What makes shadcn/ui distinctive is not any single color or shape but its **CSS-variable semantic token layer**: every surface and text color is expressed as a paired role (`--background` / `--foreground`, `--card` / `--card-foreground`, `--primary` / `--primary-foreground`, `--muted` / `--muted-foreground`) rather than a hardcoded value. This "role, not literal" approach is what lets an entire application re-skin instantly by swapping a `.dark` class or a handful of CSS custom properties — it is a system built for *composability*, not for a fixed visual signature.

Typography runs on **Geist** — Vercel's geometric-humanist sans — used as the sole typeface across headings and body, paired with radius values in the 8-18px range that read as "confidently rounded but not playful." Components (buttons, cards, inputs) are copy-pasted primitives built on Radix UI, styled with Tailwind utility classes, so the aesthetic is inseparable from its implementation: every shadow, border, and radius exists as a token that a developer can override without fighting a packaged component library. The overall impression is "engineered neutrality" — a blank, well-proportioned canvas that looks intentional even before a single brand decision is layered on top.

**Key Characteristics:**
- Achromatic default palette: zinc gray scale, near-black primary action (`#18181B` / `#000000`) — no signature chromatic accent
- Semantic CSS variable pairs for every color role: `--background`/`--foreground`, `--card`/`--card-foreground`, `--primary`/`--primary-foreground`, `--muted`/`--muted-foreground`, `--border`, `--ring`
- Geist as the sole typeface — geometric-humanist, highly legible at UI sizes
- Radius as a single root variable (`--radius: 0.625rem` ≈ 10px) that cascades to `sm`/`md`/`lg`/`xl` derived values — change one variable, reshape the whole system
- Dark mode via a `.dark` class toggle that swaps the same variable names to inverted zinc values — no separate component logic needed
- Built on Radix UI primitives for accessibility-correct behavior, styled entirely with Tailwind utility classes
- Minimal, almost invisible shadows (`shadow-xs`) — borders and subtle background steps carry most of the depth signaling
- The system is meant to be copied into a codebase and owned, not installed as an opaque dependency — "not a component library, a collection of reusable components"

## 2. Color Palette & Roles

> All colors are expressed as CSS custom properties (`oklch` in shadcn's current default, with hex/HSL equivalents noted for direct implementation). Each token has a light-mode and dark-mode value.

### Background Surfaces
- **`--background`** (`#FFFFFF` light / `#0A0A0A` dark): The page canvas — pure white in light mode, near-black zinc-950 in dark mode.
- **`--card`** (`#FFFFFF` light / `#18181B` dark, zinc-900): Card and panel surfaces — identical to background in light mode (differentiated by border only), one step lighter than background in dark mode.
- **`--popover`** (`#FFFFFF` light / `#18181B` dark): Dropdowns, popovers, tooltips — mirrors `--card`.
- **`--muted`** (`#F4F4F5` light, zinc-100 / `#27272A` dark, zinc-800): Subdued backgrounds for secondary panels, disabled states, code blocks.
- **`--secondary`** (`#F4F4F5` light / `#27272A` dark): Secondary surface/button background, same value as `--muted` by default but semantically distinct.
- **`--accent`** (`#F4F4F5` light / `#27272A` dark): Hover/active state background for menu items and subtle interactive surfaces.

### Text & Content
- **`--foreground`** (`#0A0A0A` light, zinc-950 / `#FAFAFA` dark, zinc-50): Primary text color — near-black on light, near-white on dark.
- **`--card-foreground`** (`#0A0A0A` / `#FAFAFA`): Text on card surfaces, mirrors `--foreground`.
- **`--muted-foreground`** (`#71717A` light, zinc-500 / `#A1A1AA` dark, zinc-400): Secondary/de-emphasized text — captions, placeholders, helper text.
- **`--primary-foreground`** (`#FAFAFA` light / `#18181B` dark): Text/icon color that sits on top of `--primary` (inverted relationship — light text on dark primary, dark text on light primary).

### Brand & Accent
- **`--primary`** (`#18181B` light, zinc-900 / `#FAFAFA` dark, zinc-50): The system's default "brand" color — near-black in light mode, near-white in dark mode (an intentional inversion, not a fixed hue). This is what a themed product typically overrides with its actual brand color.
- **`--ring`** (`#A1A1AA` light, zinc-400 / `#71717A` dark, zinc-500): Focus ring color — neutral gray by default, commonly overridden to match `--primary` in themed variants.

### Status Colors
- **`--destructive`** (`#EF4444` light, red-500 / `#7F1D1D` dark, red-900 base with adjusted lightness): Error states, destructive action buttons, validation messages.
- **`--destructive-foreground`** (`#FAFAFA`): Text on destructive-colored surfaces.
- Success/warning are **not** part of the default token set — consuming projects typically extend the palette with `--success` / `--warning` following the same paired-token convention.

### Border & Divider
- **`--border`** (`#E4E4E7` light, zinc-200 / `#27272A` dark, zinc-800): Default border for cards, inputs, dividers, table rules.
- **`--input`** (`#E4E4E7` light / `#27272A` dark): Border color specifically for form input outlines — same value as `--border` by default, kept semantically distinct for override flexibility.

## 3. Typography Rules

### Font Family
- **Primary**: `Geist`, with fallback stack: `ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif`
- **Monospace**: `"Geist Mono", ui-monospace, "SF Mono", Menlo, monospace`

### Hierarchy

| Role | Font | Size | Weight | Line Height | Tailwind Class | Notes |
|------|------|------|--------|-------------|-----------------|-------|
| Heading 1 | Geist | 48px (3.00rem) | 700 | 1.10 | `text-5xl font-bold` | Page/marketing titles |
| Heading 2 | Geist | 36px (2.25rem) | 700 | 1.15 | `text-4xl font-bold` | Section headings |
| Heading 3 | Geist | 24px (1.50rem) | 600 | 1.25 | `text-2xl font-semibold` | Card headers, dialog titles |
| Heading 4 | Geist | 20px (1.25rem) | 600 | 1.30 | `text-xl font-semibold` | Sub-section titles |
| Body Large | Geist | 18px (1.13rem) | 400 | 1.55 | `text-lg` | Lead paragraphs, feature descriptions |
| Body | Geist | 16px (1.00rem) | 400 | 1.50 | `text-base` | Default body/UI text |
| Body Medium | Geist | 14px (0.88rem) | 500 | 1.45 | `text-sm font-medium` | Form labels, nav items, button text |
| Small | Geist | 14px (0.88rem) | 400 | 1.45 | `text-sm` | Secondary UI text, table cells |
| Caption | Geist | 12px (0.75rem) | 400 | 1.40 | `text-xs` | Metadata, helper text, badges |
| Mono Body | Geist Mono | 14px (0.88rem) | 400 | 1.50 | `font-mono text-sm` | Code blocks, CLI output |

### Principles
- **Utility-driven sizing**: Type scale maps directly to Tailwind's default scale (`text-xs` through `text-5xl`) — the system doesn't invent custom sizes, it composes existing utility tokens for maximum portability.
- **font-medium (500) as UI-text default**: Interactive text (buttons, labels, nav) defaults to weight 500, keeping body copy at 400 — a two-weight system for most interfaces, with 600-700 reserved for headings.
- **`tracking-tight` on large headings**: Headings ≥24px commonly apply Tailwind's `tracking-tight` for a slightly compressed, confident feel without going as aggressive as display-type-obsessed systems.
- **Antialiasing and OS-native rendering**: Geist is designed to render crisply at small UI sizes (12-14px), which is why the system comfortably uses 14px as its dominant interactive-text size rather than defaulting everything to 16px.

## 4. Component Stylings

### Buttons

**Primary (Default) Button**
- Background: `var(--primary)` → `#18181B` light / `#FAFAFA` dark
- Text: `var(--primary-foreground)` → `#FAFAFA` light / `#18181B` dark
- Padding: `px-4 py-2` (16px 8px), height 36px (`h-9`)
- Radius: `var(--radius)` ≈ 10px (`rounded-md`, computed as `--radius - 2px`)
- Shadow: `shadow-xs` (`0 1px 2px rgba(0,0,0,0.05)`)
- Hover: background at 90% opacity (`hover:bg-primary/90`)
- Use: Primary form submissions, main CTAs

**Secondary Button**
- Background: `var(--secondary)` → `#F4F4F5` light / `#27272A` dark
- Text: `var(--secondary-foreground)` → `#18181B` / `#FAFAFA`
- Padding: `px-4 py-2`, height 36px
- Radius: `rounded-md` (~8px)
- Shadow: `shadow-xs`
- Use: Secondary actions alongside a primary button

**Outline Button**
- Background: `var(--background)`, transparent-adjacent
- Text: `var(--foreground)`
- Border: `1px solid var(--border)`
- Padding: `px-4 py-2`, height 36px
- Radius: `rounded-md`
- Hover: background shifts to `var(--accent)`
- Use: Tertiary/cancel actions, toolbar buttons

**Ghost Button**
- Background: transparent
- Text: `var(--foreground)`
- Padding: `px-4 py-2`, height 36px
- Radius: `rounded-md`
- Hover: background `var(--accent)`, no border
- Use: Low-emphasis inline actions, icon-adjacent labels

**Destructive Button**
- Background: `var(--destructive)` → `#EF4444`
- Text: `#FAFAFA`
- Padding: `px-4 py-2`
- Radius: `rounded-md`
- Use: Delete/irreversible actions

**Icon Button**
- Background: matches parent variant (ghost/outline/primary)
- Size: `size-9` (36x36px) square
- Radius: `rounded-md`
- Use: Toolbar icons, close buttons

### Cards & Containers
- Background: `var(--card)` (identical to `--background` in light mode)
- Text: `var(--card-foreground)`
- Border: `1px solid var(--border)`
- Radius: `var(--radius)` at `xl` derivation ≈ 14px (`rounded-xl`)
- Shadow: `shadow-sm` (`0 1px 3px rgba(0,0,0,0.06)`)
- Internal padding: `p-6` (24px), with `gap-6` between header/content/footer sections
- Structure: strict `Card` / `CardHeader` / `CardTitle` / `CardDescription` / `CardContent` / `CardFooter` composition pattern

### Inputs & Forms

**Text Input**
- Background: `var(--background)` (transparent in dark mode, uses `input/30` overlay)
- Text: `var(--foreground)`
- Border: `1px solid var(--input)`
- Padding: `px-3 py-1` (12px 4px), height 36px (`h-9`)
- Radius: `rounded-md` (~8px)
- Focus: `ring-[3px] ring-ring/50` — a soft 3px focus ring using the `--ring` token, plus border color shifts to `--ring`
- Placeholder: `var(--muted-foreground)`
- Invalid state: border/ring shift to `var(--destructive)` at reduced opacity

**Select / Combobox**
- Background: `var(--background)`
- Border: `1px solid var(--input)`
- Radius: `rounded-md`
- Height: 36px, matches Text Input for form-row alignment
- Dropdown panel: `var(--popover)` background, `1px solid var(--border)`, `rounded-md`, `shadow-md`

### Badges & Pills
**Default Badge**
- Background: `var(--primary)`
- Text: `var(--primary-foreground)`
- Padding: `px-2 py-0.5`
- Radius: `rounded-md` (~6px, not fully pill — badges stay rectangular-rounded, not `9999px`)
- Font: 12px weight 500

**Secondary/Outline Badge**
- Background: `var(--secondary)` or transparent
- Border (outline variant): `1px solid var(--border)`
- Text: `var(--foreground)` or `var(--secondary-foreground)`
- Radius: `rounded-md`

### Navigation
- `--sidebar` token group (`--sidebar-background`, `--sidebar-foreground`, `--sidebar-primary`, `--sidebar-accent`, `--sidebar-border`) provides a dedicated theme layer for app sidebars, independent from the main content tokens
- Sidebar background typically `var(--muted)` or a very slightly offset gray from `--background`
- Active nav item: `var(--sidebar-accent)` background, `var(--sidebar-accent-foreground)` text
- Top nav: `var(--background)` with `border-b var(--border)`, height typically 56-64px

### Table
- Header row: `var(--muted)` background, `var(--muted-foreground)` text, 12-14px weight 500
- Row border: `1px solid var(--border)` (bottom only, no vertical rules)
- Row hover: `var(--muted)` at reduced opacity
- Cell padding: `px-4 py-2` (16px 8px)

## 5. Layout Principles

### Spacing System
- Base unit: 4px (Tailwind's default spacing scale: `1` = 4px)
- Scale: `1` (4px), `2` (8px), `3` (12px), `4` (16px), `6` (24px), `8` (32px), `12` (48px), `16` (64px)
- Component-internal spacing standardizes on `gap-2` (8px) and `gap-4` (16px)
- Card/section padding standardizes on `p-6` (24px)

### Grid & Container
- Max content width: application-dependent — shadcn/ui does not prescribe a marketing-page container width; typical app shells use `max-w-7xl` (~1280px) for dashboards
- Form layouts: single-column stacked fields with `space-y-4` (16px vertical gap) as the convention
- Dashboard layouts: fixed sidebar (240-280px) + fluid main content area is the dominant pattern in shadcn-based admin templates

### Whitespace Philosophy
- **Density over decoration**: As a system built for application UI (not marketing sites), shadcn/ui favors moderate density — 36px control height, 24px card padding — rather than the oversized whitespace of marketing-first systems.
- **Token consistency over visual flourish**: Whitespace rhythm comes from consistently reusing `p-6`/`gap-4`/`space-y-4` across components, not from bespoke per-section spacing decisions.
- **Composable, not opinionated on macro-layout**: The system defines component-level spacing precisely but deliberately leaves page-level layout (grid, container widths) to the consuming application.

### Border Radius Scale
- Root variable: `--radius: 0.625rem` (10px) — every other radius derives from this single value
- `--radius-sm`: `calc(var(--radius) - 4px)` ≈ 6px — small elements, badges
- `--radius-md`: `calc(var(--radius) - 2px)` ≈ 8px — buttons, inputs, default components
- `--radius-lg`: `var(--radius)` = 10px — standard cards, dialogs
- `--radius-xl`: `calc(var(--radius) + 4px)` ≈ 14px — larger cards, feature panels
- Popular custom presets across the ecosystem: 10px, 14px, and 18px are the three most common `--radius` root overrides for "default", "rounder", and "roundest" theme variants

## 6. Depth & Elevation

| Level | Token | Treatment | Use |
|-------|-------|-----------|-----|
| Flat (Level 0) | none | No shadow, `var(--background)` | Page canvas |
| Whisper (Level 1) | `shadow-xs` | `0 1px 2px rgba(0,0,0,0.05)` | Buttons, inputs resting state |
| Subtle (Level 2) | `shadow-sm` | `0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)` | Cards |
| Elevated (Level 3) | `shadow-md` | `0 4px 6px rgba(0,0,0,0.07), 0 2px 4px rgba(0,0,0,0.05)` | Dropdowns, popovers |
| High (Level 4) | `shadow-lg` | `0 10px 15px rgba(0,0,0,0.08), 0 4px 6px rgba(0,0,0,0.05)` | Dialogs, sheets |
| Overlay (Level 5) | `shadow-xl` | `0 20px 25px rgba(0,0,0,0.10), 0 8px 10px rgba(0,0,0,0.05)` | Command palette, alert dialogs |

**Shadow Philosophy**: shadcn/ui treats shadow as a Tailwind-native utility scale (`shadow-xs` through `shadow-xl`) applied consistently by elevation tier rather than bespoke per-component values — this keeps the depth system portable across light and dark themes without needing separate shadow definitions for each mode. In dark mode, shadows are largely superseded by border contrast (`var(--border)` against `var(--background)`) since dark-on-dark shadows read poorly; elevation is instead communicated by the `--card`/`--popover` background stepping one level lighter than `--background`.

## 7. Do's and Don'ts

### Do
- Always reference semantic CSS variables (`var(--primary)`, `var(--muted-foreground)`) — never hardcode a hex value in component code
- Keep `--primary` as the single root override point for "brand color" — theming should require changing tokens, not rewriting components
- Use the `--radius` root variable to control the entire system's roundness — override once, cascade everywhere
- Pair every background token with its matching foreground token (`--card`/`--card-foreground`, etc.) to guarantee contrast in both light and dark mode
- Build components on Radix UI primitives for correct accessibility (focus trap, ARIA roles, keyboard nav) before applying Tailwind styling
- Keep badges rectangular-rounded (`rounded-md`, ~6-8px) rather than full pill — pill shape is not part of shadcn's default badge language

### Don't
- Don't hardcode colors like `bg-[#18181B]` — always use the token (`bg-primary`) so dark mode and custom themes work automatically
- Don't invent one-off spacing values outside the Tailwind scale (`p-6`, `gap-4`) — consistency across components depends on reusing the shared scale
- Don't apply heavy, colorful shadows — the system's shadow scale is neutral gray at low opacity across all elevation tiers
- Don't skip the `-foreground` pairing when introducing a new custom token — every background needs a corresponding readable text color
- Don't override component internals directly if a token-level change achieves the same result — token changes propagate consistently, ad-hoc overrides don't
- Don't assume the default zinc/black theme is "the brand" — it is intentionally the neutral starting point for further theming

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|--------------|
| Mobile | <640px (`sm`) | Single column, sidebar collapses to a sheet/drawer overlay |
| Tablet | 640–1024px (`md`/`lg`) | Two-column forms/grids begin, sidebar may auto-collapse to icons |
| Desktop | 1024–1280px (`xl`) | Full sidebar + content layout, standard dashboard grids |
| Large Desktop | >1280px (`2xl`) | Content area gains max-width constraint; extra space becomes margin |

### Touch Targets
- Default control height (`h-9`, 36px) meets minimum touch target guidance when combined with adequate spacing between adjacent controls
- Icon buttons standardize on `size-9` (36x36px) for consistent tap area across the component set
- Mobile-specific components (`Drawer`, `Sheet`) replace `Popover`/`DropdownMenu` on small viewports for easier touch interaction

### Collapsing Strategy
- Sidebar: fixed 240-280px → icon-only rail → off-canvas `Sheet` drawer as viewport narrows
- Data tables: horizontal scroll container on mobile rather than column hiding, preserving all data access
- Dialog → Drawer: many shadcn-based apps swap `Dialog` for `Drawer` (bottom sheet) below the `md` breakpoint for better mobile ergonomics
- Multi-column forms: `grid-cols-2` → `grid-cols-1` stacking below `sm`

## 9. Agent Prompt Guide

### Quick Color Reference
- Background: `var(--background)` → `#FFFFFF` light / `#0A0A0A` dark
- Foreground (text): `var(--foreground)` → `#0A0A0A` light / `#FAFAFA` dark
- Primary: `var(--primary)` → `#18181B` light / `#FAFAFA` dark
- Muted text: `var(--muted-foreground)` → `#71717A` light / `#A1A1AA` dark
- Border: `var(--border)` → `#E4E4E7` light / `#27272A` dark
- Destructive: `var(--destructive)` → `#EF4444`
- Focus ring: `var(--ring)` → `#A1A1AA` light / `#71717A` dark

### Example Component Prompts
- "Create a primary button: `bg-primary text-primary-foreground`, `h-9 px-4 py-2`, `rounded-md`, `shadow-xs`, hover `bg-primary/90`, Geist 14px weight 500."
- "Design a card: `bg-card text-card-foreground`, `1px solid border-border`, `rounded-xl`, `shadow-sm`, `p-6` with `gap-6` between header/content/footer."
- "Build a text input: `bg-background`, `1px solid border-input`, `rounded-md`, `h-9 px-3`, focus `ring-[3px] ring-ring/50`, placeholder `text-muted-foreground`."
- "Create a sidebar: `bg-sidebar text-sidebar-foreground`, 260px width, active item `bg-sidebar-accent text-sidebar-accent-foreground`, `border-r border-sidebar-border`."
- "Design a badge: `bg-secondary text-secondary-foreground`, `rounded-md`, `px-2 py-0.5`, 12px Geist weight 500 — not pill-shaped."

### Iteration Guide
1. Never hardcode a color — every value should trace back to a `--variable` token, both for portability and for automatic dark-mode correctness
2. Set `--radius: 0.625rem` (10px) as the root, then let `sm`/`md`/`lg`/`xl` derive automatically via `calc()` — don't hand-tune each component's radius independently
3. Default component height is 36px (`h-9`) for buttons and inputs — keep this consistent across a form row for visual alignment
4. Use Geist at 14px weight 500 as the default interactive-text style (buttons, labels, nav); reserve 16px/400 for reading-focused body copy
5. Dark mode is a `.dark` class swap on the root element — design every component against both the light and dark variable values before considering it complete
6. Shadows stay neutral-gray and low-opacity across all elevation tiers (`shadow-xs` → `shadow-xl`) — never introduce colored shadows
7. Badges and small tags stay `rounded-md` (6-8px), not full pill — reserve `rounded-full` for avatars and status dots only
