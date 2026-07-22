# Astro Islands, Actions & the Server Boundary — Deep Reference

Read this when deciding page architecture, hydration strategy, form handling, or
how data moves between server and client.

## Contents

- [The architecture in one picture](#the-architecture-in-one-picture)
- [Hydration directives, precisely](#hydration-directives-precisely)
- [The serialization boundary](#the-serialization-boundary)
- [Astro Actions](#astro-actions)
- [Progressive enhancement: the form pattern](#progressive-enhancement-the-form-pattern)
- [Content collections and data fetching](#content-collections-and-data-fetching)
- [Common failure modes](#common-failure-modes)

## The architecture in one picture

```
src/
├── pages/           .astro — routes; fetch data, compose layout + islands
├── layouts/         .astro — shells: <head>, SEO, nav, footer
├── components/
│   ├── *.astro      static presentational pieces (zero JS)
│   └── *.tsx        SolidJS islands (interactive ONLY)
├── actions/
│   └── index.ts     Astro Actions: all mutations, Zod-validated
├── stores/          *.ts — module-level Solid signals/stores shared across islands
├── content/         content collections (md/mdx/json + config)
└── styles/          global.css: design tokens, base styles
```

The page is a server-rendered static document with interactive holes punched in
it. Each hole (island) hydrates independently, on its own schedule. Everything
else is HTML and CSS that costs the user nothing.

## Hydration directives, precisely

A `.tsx` component in an `.astro` file with **no directive** is rendered to
static HTML on the server and never hydrated. This is a feature (free static
rendering) and a trap (interactive-looking components that silently do
nothing). Every time you place an island, make the decision explicitly:

| Directive | Loads JS | When | Cost profile |
| --- | --- | --- | --- |
| *(none)* | never | Static content that happens to be a Solid component | zero |
| `client:visible` | when scrolled into view | Below-fold interactivity: comment forms, carousels, "load more" | deferred, often never paid |
| `client:idle` | on `requestIdleCallback` | Above-fold but not instant-critical: theme toggles, secondary menus | after first paint |
| `client:load` | immediately | The user's first likely interaction: nav drawer, search box, add-to-cart | eager — budget it |
| `client:media="(max-width: 768px)"` | when the media query matches | Mobile-only drawers, viewport-conditional widgets | conditional |
| `client:only="solid-js"` | immediately, **no SSR** | Components that cannot run on the server (canvas, WebGL, browser-API-dependent) | no static fallback — you must reserve layout space yourself |

Rules of judgment:

- Default to no directive; escalate only with a reason.
- `client:load` needs justification in review — "it's interactive" is not one;
  "it's the first thing users touch" is.
- `client:only` requires an explicitly sized container (aspect-ratio, fixed
  height, or a skeleton) — otherwise the page reflows when it mounts, and
  layout shift is a defect.
- SSR runs the component function on the server: no `window`, no `document` at
  the top level of any island. DOM access belongs in `onMount`, which only runs
  client-side.

## The serialization boundary

Island props are serialized into the HTML payload and revived on the client.
What crosses cleanly: primitives, plain objects/arrays, `Date`, `Map`, `Set`,
`RegExp`. What cannot cross: **functions, class instances, symbols, JSX,
components**.

```astro
---
import BookingWidget from '../components/BookingWidget';
const rooms = await db.rooms.findAvailable(Astro.params.hotelId);
---
<!-- ❌ FORBIDDEN — function props and live class instances can't serialize -->
<BookingWidget rooms={rooms} onBook={handleBook} db={db} client:visible />

<!-- ✅ MANDATORY — plain data in; the island calls an Action to mutate -->
<BookingWidget
  rooms={rooms.map((r) => ({ id: r.id, name: r.name, rate: r.nightlyRate }))}
  client:visible
/>
```

Practices that keep the boundary honest:

- Define an explicit interface for every island's props in the island file;
  `astro check` then type-checks the `.astro` call sites against it.
- Map ORM/domain entities to plain DTOs at the boundary — never pass a raw
  database row shape into an island "because it works today."
- Big prop payloads are a smell: everything you pass is inlined into the HTML.
  If an island needs megabytes, it should fetch (via `createResource`) instead.
- "The island needs a callback" means the design is inverted: the island owns
  its behavior and calls Actions or writes shared stores; the server passes
  data, never behavior.

## Astro Actions

All mutations are Actions. The server defines the contract; clients — both
plain HTML forms and Solid islands — consume it with full type safety.

```ts
// src/actions/index.ts
import { defineAction, ActionError } from 'astro:actions';
import { z } from 'astro:schema';

export const server = {
  subscribe: defineAction({
    accept: 'form', // 'form' for FormData (progressive enhancement); 'json' for island-only RPC
    input: z.object({
      email: z.string().email(),
      plan: z.enum(['monthly', 'annual']),
    }),
    handler: async ({ email, plan }, context) => {
      const user = await getUser(context);
      if (!user) {
        throw new ActionError({ code: 'UNAUTHORIZED', message: 'Sign in to subscribe.' });
      }
      return await billing.subscribe(user.id, email, plan);
    },
  }),
};
```

Calling from a Solid island — the result is a discriminated pair, never a
thrown exception for expected failures:

```tsx
import { actions, isInputError } from 'astro:actions';

const { data, error } = await actions.subscribe(formData);
if (error) {
  if (isInputError(error)) {
    setFieldErrors(error.fields);        // { email?: string[], plan?: string[] } — typed
  } else {
    setFormError(error.message);         // ActionError with code + message
  }
} else {
  setConfirmation(data);                 // typed as the handler's return
}
```

- Schema lives on the server, once. Client payload types are *derived* from it —
  if they drift, `astro check` fails. Never hand-duplicate the shape.
- Use `ActionError` codes (`UNAUTHORIZED`, `NOT_FOUND`, `BAD_REQUEST`, ...) for
  expected failures; reserve thrown exceptions for genuine bugs.
- `accept: 'form'` whenever a no-JS fallback exists or could exist; `'json'`
  only for interactions that are meaningless without a client (drag reorder,
  optimistic toggles).

## Progressive enhancement: the form pattern

The canonical Neutronium form: works with JavaScript disabled, gets better with
it. Static shell in `.astro`, enhancement as an island.

```astro
---
// src/pages/newsletter.astro
import { actions } from 'astro:actions';
import NewsletterForm from '../components/NewsletterForm';
const result = Astro.getActionResult(actions.subscribe); // present after a no-JS POST round-trip
---
<NewsletterForm client:visible>
  <!-- This exact form is the no-JS fallback, slotted through the island -->
  <form method="POST" action={actions.subscribe}>
    <label for="email">Email</label>
    <input id="email" name="email" type="email" required />
    <button>Subscribe</button>
  </form>
</NewsletterForm>
{result && !result.error && <p role="status">Subscribed — check your inbox.</p>}
```

```tsx
// src/components/NewsletterForm.tsx — upgrades the same form in place
import { createSignal, Show, type ParentProps } from 'solid-js';
import { actions, isInputError } from 'astro:actions';

export default function NewsletterForm(props: ParentProps) {
  const [status, setStatus] = createSignal<'idle' | 'busy' | 'done'>('idle');
  const [errorMsg, setErrorMsg] = createSignal<string>();

  const onSubmit = async (e: SubmitEvent) => {
    e.preventDefault(); // JS present: take over from the native POST
    setStatus('busy');
    // e.target, not e.currentTarget: the listener sits on the wrapper div,
    // the slotted <form> is where the event fired
    const { error } = await actions.subscribe(new FormData(e.target as HTMLFormElement));
    if (error) {
      setErrorMsg(isInputError(error) ? error.fields.email?.[0] : error.message);
      setStatus('idle');
    } else {
      setStatus('done');
    }
  };

  return (
    <div onSubmit={onSubmit}>
      <Show when={status() !== 'done'} fallback={<p role="status">Subscribed — check your inbox.</p>}>
        {props.children}
        <Show when={errorMsg()}>{(msg) => <p role="alert">{msg()}</p>}</Show>
      </Show>
    </div>
  );
}
```

The test for this pattern: disable JavaScript, submit the form, confirm the
mutation happens and feedback renders. If that fails, the enhancement layer is
hiding a broken foundation.

## Content collections and data fetching

- Structured content (posts, docs, products-from-files) lives in content
  collections with a Zod schema in `src/content.config.ts` — typed frontmatter,
  build-time validation, `getCollection()`/`getEntry()` access.
- Page data fetching happens in `.astro` frontmatter (top-level `await` is
  fine). It runs at build time for static pages, per-request for SSR — write it
  to be correct for the page's actual output mode.
- The hierarchy for where data loading belongs, best first:
  1. `.astro` frontmatter, passed down as props (server knew it — costs zero JS)
  2. An Action call in response to a user interaction (mutation or on-demand read)
  3. `createResource` in an island (data is client-contextual: depends on
     viewport, live input, or browser state)

## Common failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Component renders but clicks do nothing | Missing `client:*` directive | Add the cheapest directive that fits |
| `window is not defined` during build | Browser API at island top level (SSR runs it) | Move into `onMount` / guard, or `client:only="solid-js"` as last resort |
| Island shows stale/frozen data | Props destructured, or server data captured once into a signal without need | Access via `props.*`; don't copy props into state unless the island owns divergent state |
| Page jumps when a widget appears | `client:only` or `Suspense` without reserved space | Sized skeleton/container matching final dimensions |
| Two islands disagree about shared state | Each created its own local signal | Move the state to `src/stores/*.ts` module scope |
| Users' data bleeding between requests | Module-level store read/written during SSR | Stores are client-only; server passes per-request data as props |
| "Works on my machine" form | Only the JS path was built | Build the native POST path first, enhance second, test with JS off |
