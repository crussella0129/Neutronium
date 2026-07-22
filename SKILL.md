---
name: neutronium
description: >-
  Execution rules and a visual-quality bar for all front-end work in an Astro +
  SolidJS + TypeScript codebase. Use this skill for ANY task that touches the UI
  or front-end files — creating or editing pages and components (.astro, .tsx),
  styles, forms, search/filter features, toggles, client state, animations, or
  front-end tests — even when the request never names the frameworks ("add a
  page", "wire up this form", "make it look better"). Also trigger on front-end
  symptoms: an element that renders but does nothing when clicked, layout shift
  while loading, janky motion, build/SSR errors like "window is not defined", or
  state that falls out of sync between components on a page. Always use it when
  refactoring or reviewing front-end code, especially anything written with React
  idioms (useState/useEffect, destructured props, className). Not for backend
  APIs, CI/tooling config, or React/Vue/Next codebases.
license: GPL-3.0
---

# Neutronium — Astro + SolidJS + TypeScript

The point of this stack is to ship **zero JavaScript by default** and hydrate only
the islands that genuinely need interactivity, with SolidJS providing fine-grained
reactivity (no virtual DOM, no re-renders) inside those islands. Every rule below
exists to protect one of two things: that performance model, or the visual quality
of what users see. Both are requirements. Fast and ugly fails. Beautiful and
bloated fails.

## Warning: your React instincts are wrong here

Training data is saturated with React. Solid's JSX looks like React's, so the pull
toward React idioms is strong — and in Solid most of them **compile without errors
and silently don't work**. The single mental-model correction that prevents almost
all of them:

> **A Solid component function runs exactly once per instance.** There are no
> re-renders. Reactivity lives in compiled JSX expressions and tracked scopes
> (`createEffect`, `createMemo`), not in re-executing your function.

Consequences, as a quick-reference table — the left column is what your instincts
will produce, the right column is what this codebase requires:

| ❌ React habit | ✅ Solid pattern | Why the habit fails here |
| --- | --- | --- |
| `useState`, `useEffect`, `useRef`, `useMemo`, `useCallback` | `createSignal`, `createEffect`, `ref`/plain variables, `createMemo`, plain functions | React hooks don't exist; any `from 'react'` import is a build break or a second framework in the bundle |
| `const { title } = props` | `props.title`, `splitProps`, `mergeProps` | Props are compiled reactive getters; destructuring reads once at setup and freezes the value forever |
| `count` as a value | `count()` | Signals are getter functions; `if (count)` is always truthy and `count + 1` is `NaN` — the value only exists by invoking it |
| `className=`, `htmlFor=` | `class=`, `classList={{ active: active() }}`, `for=` | Solid uses native attribute names; `className` becomes a meaningless custom attribute |
| `{items.map(item => ...)}` in JSX | `<For each={items()}>` / `<Index each={items()}>` | `.map` recreates every DOM node on every change; `<For>` diffs by reference and moves nodes |
| `cond ? <A/> : <B/>` for branches in JSX | `<Show when={cond()} fallback={<B/>}>` / `<Switch>`/`<Match>` | Control-flow components evaluate lazily and preserve DOM; ternaries are allowed only for trivial text/attribute values |
| `return () => cleanup()` from an effect | `onCleanup(() => ...)` inside the effect (or `onMount`) | Solid passes an effect's return value to its *next run* as an accumulator — a returned cleanup function is silently ignored |
| `useEffect(fn, [dep])` dependency arrays | just read the signals inside `createEffect` | Solid auto-tracks whatever you read; there are no dependency arrays to get wrong |
| `key={item.id}` | nothing (`<For>` keys by reference) | `key` is not a Solid concept |
| `onChange` for per-keystroke input state | `onInput` | Solid's `onChange` is the *native* change event (fires on blur/commit), not React's remapped one |
| Deeply nested `createSignal` per field | `createStore` from `solid-js/store` | Stores give path-level granularity for nested objects/arrays; signal-per-field turns into unmaintainable plumbing |

Full patterns with worked examples (stores, resources, context, refs, events,
`batch`/`untrack`/`on`): read [references/solid-reactivity.md](references/solid-reactivity.md)
before writing any non-trivial `.tsx`.

## Where code lives

| File type | Role | Hard boundaries |
| --- | --- | --- |
| `.astro` | Server-only: routing, layouts, SEO/meta, build-time & SSR data fetching, static HTML, scoped `<style>` | Ships zero JS by default. No client state. Fetch data here, not in islands, whenever the server already knows it |
| `.tsx` | Interactive SolidJS islands **only** | Lean, focused on interaction. If a component has no state, no handlers, and no lifecycle — it should be `.astro`, not a static `.tsx` |
| `.ts` | Domain types, utilities, Astro Actions definitions, shared cross-island stores (`src/stores/*.ts`) | No JSX. Module-level stores are client-side state only — never read them during SSR for per-request data (the server shares module state across requests) |

The strongest architectural instinct to maintain: **start static, add islands
reluctantly.** Every `.tsx` island is a cost (bundle, hydration, complexity) that
must buy real interactivity.

## Hydration discipline

A Solid component placed in an `.astro` file renders as **static HTML with no
interactivity** unless it has a `client:*` directive. This fails silently — the
page looks right and does nothing. Choose directives from cheapest to most
expensive, and always justify anything above `client:visible`:

| Directive | Use for |
| --- | --- |
| *(none)* | Anything that doesn't need to be interactive — the default answer |
| `client:visible` | Interactive elements below the fold (comments, carousels, footers) |
| `client:idle` | Above-the-fold interactivity that isn't needed in the first instant |
| `client:load` | Only critical, immediately-needed controls (nav toggle, cart button, search input) |
| `client:media="..."` | Interactivity that only exists at certain viewports |
| `client:only="solid-js"` | Components that cannot render on the server. Skips SSR entirely — reserve a correctly-sized placeholder or you will cause layout shift |

## Data across the island boundary

Props passed from `.astro` to a hydrated island are serialized into the HTML.
Functions, class instances, and components **cannot cross**. Keep island props to
JSON-shaped data (primitives, plain objects/arrays; Astro can also serialize
`Date`, `Map`, `Set`, `RegExp`) and type them with explicit interfaces so
`astro check` guards the boundary:

```astro
---
import ProductCard from '../components/ProductCard';
const product = await getProduct(Astro.params.id); // fetch on the server
---
<ProductCard product={{ id: product.id, name: product.name, price: product.price }} client:visible />
```

Islands never re-fetch what the server already had — pass it down.

## Mutations: Astro Actions only

All client→server mutations go through Astro Actions (`astro:actions`) with Zod
input schemas defined server-side. No hand-rolled `fetch('/api/...')` endpoints
for mutations; Actions give you end-to-end types, validation, and structured
errors for free.

```ts
// src/actions/index.ts
import { defineAction } from 'astro:actions';
import { z } from 'astro:schema';

export const server = {
  addToCart: defineAction({
    accept: 'form',
    input: z.object({ productId: z.string(), qty: z.number().int().positive() }),
    handler: async ({ productId, qty }, ctx) => { /* ... */ },
  }),
};
```

Forms follow **progressive enhancement**: a plain `<form method="POST">` in
`.astro` that works with JavaScript disabled, which a Solid island then upgrades
with optimistic state and inline validation. If the form only works with JS
enabled, it's wrong. Worked pattern (including `isInputError` handling and
optimistic UI): [references/astro-islands.md](references/astro-islands.md).

## Shared state across islands

Islands on a page are independent component trees, but they share module
instances. Cross-island state is module-level signals/stores in `src/stores/`:

```ts
// src/stores/cart.ts
import { createSignal } from 'solid-js';
export const [cartItems, setCartItems] = createSignal<CartItem[]>([]);
export const cartCount = () => cartItems().reduce((n, i) => n + i.qty, 0);
```

No external state-management library. Two caveats: this state resets on full-page
navigation (persist to `sessionStorage` or lean on view transitions if that
matters), and — repeated because it's a real footgun — module state on the server
is shared across all requests, so stores are for client-side state only.

## Styling

- **`.astro` files**: scoped `<style>` blocks for static layout CSS.
- **`.tsx` islands**: Tailwind utilities, with `classList` for state-driven
  classes. CSS Modules (`.module.css`) when a component needs styles utilities
  can't express cleanly.
- **All styling flows through design tokens** (CSS custom properties mapped into
  Tailwind). A raw hex color or arbitrary pixel value in a component is a defect
  — if the value matters, it belongs in the token layer.

## The beauty bar

"Works" is half the job. Before building any UI, read
[references/design.md](references/design.md) — it defines the visual standard.
The five commitments, inline, because they're cheap to hold in mind:

1. **Tokens before components.** Establish (or find) the project's type scale,
   spacing scale, color tokens, radii, shadows, and motion durations first.
   Consistency is what reads as "designed".
2. **Typography and spacing carry the design.** Body text ≥ 1rem at line-height
   ~1.6, measure 45–75ch, one deliberate type scale. Space between sections
   visibly larger than space within them.
3. **Every state is designed.** Hover, focus-visible, active, disabled, loading,
   empty, and error states — an unstyled focus ring or a spinner-only page means
   the work isn't finished.
4. **Motion is communication.** 120–350ms, ease-out on enter, `transform`/
   `opacity` only, always honoring `prefers-reduced-motion`.
5. **No generic slop.** Unconsidered framework-default blue, uniform card grids
   with `shadow-md rounded-lg`, emoji as icons, centered-heading-plus-three-cards
   rhythm on every section — these are the tells of ungoverned generation. Make
   choices; vary rhythm; let one accent color work.

Accessibility is part of the bar, not a separate concern: semantic HTML first,
real `<button>`s, labeled inputs, keyboard operability, WCAG AA contrast.

## Verification — run before declaring any task done

1. **Mechanical audit** — run the bundled script; it greps for the always-wrong
   patterns (React imports/hooks, `className`, destructured props, missing signal
   calls it can detect):

   ```bash
   bash scripts/audit.sh src/
   ```

   (Script lives in this skill's directory; pass the project's source dir.)

2. **Judgment audit** — things grep can't see:
   - Every Solid component embedded in `.astro` that needs interactivity has a
     `client:*` directive — and the cheapest one that works.
   - No island fetches data the server page already had.
   - Island props are serializable and typed.
   - Action input schemas match what the client actually sends.
   - Forms degrade gracefully without JS.
   - New UI passes the beauty bar: tokens used, states designed, motion respectful.

3. **Gates** — all must pass:

   ```bash
   astro check      # type-checks .astro and the island boundary
   vitest run       # unit + component tests
   playwright test  # E2E + hydration verification
   ```

Testing patterns — component tests with `@solidjs/testing-library`, testing
signals/stores in isolation, Playwright hydration checks:
[references/testing.md](references/testing.md).

## Reference index

Read these lazily, when the task touches their domain:

| File | Read when |
| --- | --- |
| [references/solid-reactivity.md](references/solid-reactivity.md) | Writing or reviewing any non-trivial `.tsx` — stores, resources, context, refs, effects, control flow |
| [references/astro-islands.md](references/astro-islands.md) | Page architecture, hydration decisions, Actions, forms, cross-boundary data |
| [references/design.md](references/design.md) | Building or restyling any visible UI |
| [references/testing.md](references/testing.md) | Writing tests, setting up Vitest/Playwright, verifying hydration |
