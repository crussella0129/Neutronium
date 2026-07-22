# The Beauty Bar — Visual Design Reference

Read this before building or restyling any visible UI. Correct code that looks
generic is unfinished work. This file exists because generated interfaces have a
recognizable, forgettable sameness — and the way out is not talent, it's
discipline: tokens, scales, states, and a few deliberate choices applied
consistently.

## Contents

- [Process: decide before you build](#process-decide-before-you-build)
- [Design tokens](#design-tokens)
- [Typography](#typography)
- [Spacing and layout](#spacing-and-layout)
- [Color](#color)
- [Depth: borders, radii, shadows](#depth-borders-radii-shadows)
- [Motion](#motion)
- [States: where quality actually lives](#states-where-quality-actually-lives)
- [Accessibility is the floor](#accessibility-is-the-floor)
- [The anti-slop checklist](#the-anti-slop-checklist)

## Process: decide before you build

1. **Find the existing system first.** If the project has tokens, a type scale,
   or established components — match them exactly. Consistency with the
   codebase beats every preference in this file. This file governs when you're
   establishing the look or the existing one is silent.
2. **Pick a personality.** Two or three adjectives, written down before the
   first component: *calm and precise*, *warm and editorial*, *dense and
   technical*. Every later choice (typeface, radius, motion speed, color
   temperature) either serves those adjectives or is wrong. A UI with no
   personality decision is how you get the default-Tailwind look.
3. **Tokens before components.** Define the scales below in
   `src/styles/global.css` first. A component written before tokens exist will
   invent its own values, and entropy compounds from there.

## Design tokens

All visual values flow through CSS custom properties on `:root`, mapped into
Tailwind (v4 `@theme`, or the v3 config equivalent). Components consume tokens;
they never invent values.

```css
/* src/styles/global.css — the shape, with placeholder values to replace */
:root {
  /* color: semantic, not raw palette names */
  --color-bg: oklch(98% 0.005 95);
  --color-surface: oklch(96% 0.007 95);
  --color-text: oklch(22% 0.015 95);
  --color-text-muted: oklch(45% 0.015 95);
  --color-accent: oklch(55% 0.15 250);
  --color-accent-contrast: oklch(98% 0.01 250);
  --color-border: oklch(88% 0.01 95);
  --color-danger: oklch(55% 0.19 25);

  /* type scale: one ratio, fluid at the top end */
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.25rem;
  --text-xl: clamp(1.5rem, 1.2rem + 1.2vw, 2rem);
  --text-2xl: clamp(2rem, 1.5rem + 2vw, 3rem);

  /* spacing: 4px base — use the scale, never arbitrary values */
  /* radii + shadows + motion */
  --radius-sm: 0.375rem;
  --radius-md: 0.625rem;
  --shadow-raised: 0 1px 2px oklch(20% 0.02 95 / 0.06), 0 4px 12px oklch(20% 0.02 95 / 0.08);
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --duration-fast: 150ms;
  --duration-base: 250ms;
}

:root[data-theme='dark'] {
  --color-bg: oklch(18% 0.01 95);
  --color-surface: oklch(23% 0.012 95);
  --color-text: oklch(93% 0.008 95);
  /* ... every semantic token gets a dark value; components never change */
}
```

The load-bearing ideas:

- **Semantic names** (`--color-surface`, not `--gray-100`) so dark mode is a
  token swap, never a per-component override. If a component contains
  `dark:bg-...` overrides for basic surfaces, the token layer has failed.
- **A raw hex value or arbitrary `p-[13px]` in a component is a defect.** If a
  value matters enough to use, it matters enough to name.

## Typography

Typography does more for perceived quality than any other single system. The
rules:

- **Body**: ≥ `1rem` (16px), line-height 1.5–1.7. Never below 14px for
  anything users must read.
- **Measure**: 45–75 characters per line (`max-width: 65ch` on prose). Full-
  width paragraphs on desktop are the most common generated-UI tell.
- **Scale**: one ratio (1.2–1.333), five to six steps, nothing off-scale.
  Headings get line-height 1.1–1.3 and slightly negative letter-spacing
  (−0.01em to −0.025em) at display sizes.
- **Faces**: maximum two families (one is usually right; add a display or mono
  face only with a reason). The system stack is a legitimate choice; a
  characterless webfont is not an upgrade over it.
- **Details that read as craft**: `font-variant-numeric: tabular-nums` in
  tables and stat displays; real quotes and dashes in copy; uppercase labels
  get `letter-spacing: 0.05em` and a smaller size, never bold shouting.
- **Alignment**: left-align text. Center only short display lines (a hero
  heading, an empty-state message). Never center paragraphs; never justify.

## Spacing and layout

- **One scale, 4px base** (4/8/12/16/24/32/48/64/96...). Every margin, padding,
  and gap comes from it.
- **Proximity is grouping.** Space between sections must be visibly larger
  than space within them — a label sits near its field (4–8px), far from the
  previous field (24–32px). When everything is 16px apart, structure dissolves.
- **Be generous at the macro level.** Section padding of 64–96px on desktop is
  normal, not wasteful; whitespace is the cheapest way to look considered.
  Density belongs *inside* components (tables, lists), not between them.
- **Alignment is non-negotiable.** Pick edges and stick to them; a single
  misaligned element reads as a bug. Use CSS grid for page scaffolding,
  flexbox for rows — and `gap`, never margin-chains between siblings.
- **Vary the rhythm.** If every section is a centered heading over a 3-column
  card grid, the page reads as templated. Alternate: full-bleed, split
  two-column, inset prose, asymmetric. At most one card grid per page.

## Color

- **Build in OKLCH.** Perceptually uniform lightness makes palettes coherent
  and contrast predictable; vary lightness/chroma along one hue for a family.
- **Neutrals are tinted, not gray.** Push 0.005–0.02 chroma of the accent hue
  (or its complement) into backgrounds and text colors. Pure `#fff`/`#000`/gray
  UIs feel unfinished; tinted neutrals are the single cheapest "designed" cue.
- **One accent.** It marks primary actions and key highlights — which means it
  must be rare. If the accent is everywhere, nothing is primary. Support it
  with neutrals and, at most, semantic colors (danger/success/warning).
- **Contrast is a hard gate**: 4.5:1 for body text, 3:1 for large text and UI
  boundaries. Muted text (`--color-text-muted`) must still clear 4.5:1 —
  "muted" means lower contrast than body text, not inaccessible.
- **Dark mode is its own design, done in tokens.** Not inverted light mode:
  background lifts off pure black (18–22% lightness), surfaces get *lighter*
  as they rise (shadows are nearly invisible on dark — elevation reads through
  lightness instead), saturated colors get desaturated slightly, and contrast
  ratios get re-checked, not assumed.

## Depth: borders, radii, shadows

- **Pick one primary depth language** — hairline borders (technical, dense) or
  soft shadows (friendly, airy) — and use the other sparingly. Both maxed on
  every card is noise.
- **Radius is identity**: sharp (0–4px) reads technical/editorial, mid
  (6–10px) reads product-neutral, large (14px+) reads friendly/consumer. Pick
  the scale from the personality and apply it consistently. Nested rounding:
  inner radius = outer radius − gap, or the corners visibly fight.
- **Shadows are layered and quiet**: two layers (tight ambient + soft drop),
  low opacity (5–10%), tinted toward the background hue — never a single
  heavy gray `box-shadow: 0 4px 6px rgba(0,0,0,.3)`. Elevation must mean
  something: overlays > dropdowns > raised cards > flat page. Decorative
  shadows on static content are clutter.

## Motion

- **Purpose, not decoration.** Motion explains origin and causality: the menu
  grows from the button that opened it, the toast slides from the edge it
  lives on, the deleted row collapses. If an animation explains nothing,
  delete it.
- **Timing**: 120–200ms micro-interactions (hover, press, toggle), 200–350ms
  spatial transitions (overlays, accordions, page elements). Enter ease-out;
  exit ease-in and slightly faster — leaving should feel lighter than
  arriving. Nothing over 400ms except deliberate hero moments.
- **Compositor properties only** (`transform`, `opacity`) for anything that
  moves per-frame. Animating layout properties (width/height/top/margin)
  causes reflow jank; for expand/collapse use `grid-template-rows: 0fr → 1fr`
  or measured transforms.
- **`prefers-reduced-motion` is mandatory**, not optional polish:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

- Solid pairing: drive animation state with signals + `classList`, and use
  `<Transition>` from `solid-transition-group` when elements enter/exit the
  DOM. Never let hydration itself animate content into place — the static HTML
  is already there; animating it on load is layout shift by another name.

## States: where quality actually lives

The difference between generated-looking and designed-looking UI is rarely the
happy path — it's everything else. Every interactive element ships with **all**
of these, styled deliberately:

| State | Requirement |
| --- | --- |
| Hover | Visible but quiet — background/border shift, not a color carnival. Pointer devices only (`@media (hover: hover)`) |
| Focus-visible | A designed ring: `outline: 2px solid var(--color-accent); outline-offset: 2px`. Never `outline: none` without a replacement — that's a WCAG failure, not a style choice |
| Active/pressed | Immediate feedback (≤100ms): slight scale-down or darkening |
| Disabled | Reduced contrast + `cursor: not-allowed`; still legible, and disabled state must never be the only validation feedback |
| Loading | Skeletons **sized to the final content** for structure; inline spinners only for small in-place actions (button label swap). A full-page spinner is a design failure |
| Empty | Designed, not blank: one line of explanation + the action that fills it. The empty state is most users' first impression |
| Error | Human language ("We couldn't save your changes"), placed at the point of failure, with a retry path. Field errors inline next to the field, `role="alert"`, never only a toast |

Interactive targets: minimum 44×44px touch target (pad small icons to it).
Forms: every input has a visible `<label>` (placeholder is not a label), errors
appear on blur or submit — never while the user is still typing their first
attempt.

## Accessibility is the floor

Not a checklist after the fact — constraints that shape the build:

- **Semantic HTML first.** `<button>` for actions, `<a>` for navigation,
  `<nav>/<main>/<header>` landmarks, one `<h1>`, heading levels without gaps.
  ARIA only where semantics genuinely can't express it — role-stuffed divs are
  worse than plain HTML.
- **Keyboard completeness.** Everything clickable is tabbable and
  Enter/Space-operable; focus order follows visual order; overlays trap focus
  and restore it on close; a skip link precedes heavy navigation.
- **Announce dynamic changes**: `role="status"` for confirmations,
  `role="alert"` for errors — Solid islands that mutate the page silently are
  invisible to screen readers.
- **Images**: real alt text for content, empty `alt=""` for decoration.
- Contrast rules are in [Color](#color); they're gates, not goals.

## The anti-slop checklist

Before calling any UI finished, verify none of these are present. Each one is a
tell of ungoverned generation:

- [ ] Framework-default accent (unconsidered `#3b82f6` blue) — chosen by
      omission rather than decision
- [ ] Pure-gray neutrals everywhere (`#f9fafb`/`#6b7280`/`#111827` with zero tint)
- [ ] Every surface is a card with `rounded-lg shadow-md p-6`
- [ ] The centered-heading + subtitle + 3-column-icon-card-grid rhythm, twice
- [ ] Emoji standing in for an icon system
- [ ] Gradient text or glassmorphism without a personality that calls for it
- [ ] Full-width paragraphs; centered body text
- [ ] Values off the token scales (`p-[13px]`, `#4a7dc9`, `duration-[230ms]`)
- [ ] `outline: none` / `focus:outline-none` without a visible replacement
- [ ] Spinner-only loading pages; blank empty states; toast-only errors
- [ ] Dark mode as naive inversion, or `dark:` overrides scattered through
      components instead of the token layer
- [ ] Animation on page load for content that was already server-rendered

If the design brief is silent and choices feel arbitrary: quiet neutrals with
one committed accent, a 1.25 type ratio, mid radii, hairline borders over
shadows, fast subtle motion. Restraint executed consistently beats boldness
executed unevenly — and when in doubt, remove decoration rather than add it.
