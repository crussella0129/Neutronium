# Testing & Quality Gates — Deep Reference

Read this when writing tests, wiring up Vitest/Playwright, or verifying that
islands actually hydrate. The strategy has three layers, each catching what the
one below can't:

1. **Vitest** — pure logic and store behavior (fast, no DOM)
2. **Vitest + @solidjs/testing-library** — component behavior in jsdom
3. **Playwright** — real-browser truth: hydration, progressive enhancement,
   Action round-trips, layout stability

## Contents

- [Setup](#setup)
- [Layer 1: logic and stores](#layer-1-logic-and-stores)
- [Layer 2: component tests](#layer-2-component-tests)
- [Layer 3: Playwright E2E and hydration](#layer-3-playwright-e2e-and-hydration)
- [What to test where](#what-to-test-where)
- [The full gate sequence](#the-full-gate-sequence)

## Setup

Vitest must compile Solid JSX and resolve Solid's **browser** builds — the
default SSR condition resolution is the classic cause of "computations created
outside a `createRoot`" warnings and dead reactivity in tests:

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import solid from 'vite-plugin-solid';

export default defineConfig({
  plugins: [solid()],
  resolve: { conditions: ['development', 'browser'] },
  test: {
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'], // @testing-library/jest-dom matchers, cleanup
  },
});
```

If test-time reactivity behaves strangely, check this config against the
current `@solidjs/testing-library` README before debugging application code —
the failure mode is almost always resolution conditions, not your component.

Playwright runs against the built site, not the dev server, because hydration
behavior and bundling only fully match production in a build:

```ts
// playwright.config.ts (essentials)
export default defineConfig({
  webServer: { command: 'npm run build && npm run preview', port: 4321, reuseExistingServer: true },
  use: { baseURL: 'http://localhost:4321' },
});
```

## Layer 1: logic and stores

Shared stores (`src/stores/*.ts`) and reactive utilities get tested directly —
no rendering. Wrap in `createRoot` so computations have an owner and can be
disposed:

```ts
import { createRoot } from 'solid-js';
import { describe, it, expect } from 'vitest';

describe('cart store', () => {
  it('derives count from items', () => {
    createRoot((dispose) => {
      const { cartItems, setCartItems, cartCount } = createCartStore();
      expect(cartCount()).toBe(0);
      setCartItems([{ id: 'a', qty: 2 }, { id: 'b', qty: 1 }]);
      expect(cartCount()).toBe(3);
      dispose();
    });
  });
});
```

Note the pattern this forces on the store module: exporting a **factory**
(`createCartStore`) that the real `src/stores/cart.ts` instantiates once at
module level. The factory is testable in isolation; the singleton is what
islands import. Module-level singletons that can't be re-created are
untestable by construction — design them as factory + instance from the start.

## Layer 2: component tests

Use `@solidjs/testing-library` (never React Testing Library — same names,
incompatible internals). Test through the DOM the way a user would; never
reach into component internals for signals.

```tsx
import { render, screen, fireEvent } from '@solidjs/testing-library';
import { describe, it, expect } from 'vitest';
import Counter from '../src/components/Counter';

describe('<Counter />', () => {
  it('increments on click', async () => {
    render(() => <Counter initial={2} />);
    const button = screen.getByRole('button', { name: /count: 2/i });
    fireEvent.click(button);
    expect(await screen.findByRole('button', { name: /count: 3/i })).toBeInTheDocument();
  });
});
```

Conventions:

- `render` takes a **function** returning JSX (`() => <Counter />`), not an
  element — passing bare JSX evaluates it outside the reactive root.
- Query by **role and accessible name** first (`getByRole`, `getByLabelText`).
  If a component can't be selected by role, that's an accessibility finding,
  not a reason to add `data-testid`.
- Solid updates are synchronous but effect-scheduled — prefer `await
  screen.findBy...` over asserting immediately after `fireEvent` when updates
  flow through effects or resources.
- Mock Actions at the module boundary (`vi.mock('astro:actions', ...)`) to
  test island behavior on success, input error, and server error paths — all
  three, since the error branches are where UI quality lives (see
  design.md, "States").

## Layer 3: Playwright E2E and hydration

The questions only a real browser answers, each an explicit test:

**Did the island hydrate and become interactive?**

```ts
test('cart button hydrates and responds', async ({ page }) => {
  await page.goto('/products/anvil');
  const addButton = page.getByRole('button', { name: /add to cart/i });
  await expect(addButton).toBeVisible();
  await addButton.click(); // auto-waits for actionability, but assert the OUTCOME:
  await expect(page.getByRole('status')).toHaveText(/added/i);
});
```

The outcome assertion is the hydration test — a dead island still *looks*
clickable, so a test that only checks visibility passes against a broken page.

**Does the page work before/without JavaScript?** (the progressive-enhancement
gate — run key form flows in a no-JS context):

```ts
test('newsletter form works without JS', async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto('/newsletter');
  await page.getByLabel(/email/i).fill('ada@example.com');
  await page.getByRole('button', { name: /subscribe/i }).click();
  await expect(page.getByRole('status')).toHaveText(/subscribed/i); // server-rendered result
});
```

**Does hydration shift layout?**

```ts
test('hydration causes no layout shift', async ({ page }) => {
  await page.goto('/');
  const cls = await page.evaluate(() =>
    new Promise<number>((resolve) => {
      let total = 0;
      new PerformanceObserver((list) => {
        for (const e of list.getEntries() as any[]) if (!e.hadRecentInput) total += e.value;
      }).observe({ type: 'layout-shift', buffered: true });
      setTimeout(() => resolve(total), 3000);
    })
  );
  expect(cls).toBeLessThan(0.1);
});
```

**Do deferred islands load on their trigger?** For `client:visible`, scroll the
island into view and then assert interactivity — clicking before scrolling
should be part of no test's happy path.

Also make Playwright's accessibility snapshot part of key-page tests
(`@axe-core/playwright`) — it mechanically enforces the design reference's
floor (labels, roles, contrast) on every run.

## What to test where

| Concern | Layer |
| --- | --- |
| Store derivations, reactive utilities | 1 — `createRoot` unit tests |
| Component state, conditional rendering, event handling | 2 — testing-library |
| Action error/success UI branches | 2 — with `astro:actions` mocked |
| Island hydration, directive timing | 3 — Playwright only (jsdom cannot see this) |
| No-JS form fallback | 3 — `javaScriptEnabled: false` |
| Layout shift, focus order, axe checks | 3 |
| Action handler logic itself | 1 — call the handler as a function with test context |

Don't test: framework behavior (that `<For>` diffs, that signals update),
styling minutiae via snapshot dumps (they rot and assert nothing), or anything
through implementation details that a refactor would break without a behavior
change.

## The full gate sequence

Every task ends with all of these green, in this order (cheap → expensive):

```bash
bash scripts/audit.sh src/   # mechanical pattern audit (see SKILL.md)
astro check                  # types across .astro/.ts/.tsx incl. the island boundary
vitest run                   # layers 1–2
npx playwright test          # layer 3
```

A red gate is a stop, not a note. If a gate can't run in the current
environment (e.g., no browsers installed for Playwright), say so explicitly in
the final report rather than letting silence imply it passed.
