# SolidJS Reactivity — Deep Reference

Read this before writing any non-trivial `.tsx`. It assumes you've internalized
the core model from SKILL.md: **a component function runs once per instance;
reactivity lives in tracked scopes, not re-renders.**

## Contents

- [Signals, memos, effects](#signals-memos-effects)
- [Props: the three tools](#props-the-three-tools)
- [Control flow components](#control-flow-components)
- [Stores for nested state](#stores-for-nested-state)
- [Async: createResource, Suspense, ErrorBoundary](#async-createresource-suspense-errorboundary)
- [Lifecycle and refs](#lifecycle-and-refs)
- [Events](#events)
- [Escape hatches: batch, untrack, on](#escape-hatches-batch-untrack-on)
- [Context](#context)

## Signals, memos, effects

```tsx
import { createSignal, createMemo, createEffect, onCleanup } from 'solid-js';

const [count, setCount] = createSignal(0);

// Read by CALLING. `count` alone is a function object, not a value.
console.log(count());        // 0
setCount(5);                 // set directly
setCount((prev) => prev + 1); // or functionally

// Setting a signal to a function value requires the functional form,
// otherwise Solid treats it as an updater:
setHandler(() => myCallback);
```

**Derived values**: a plain function closure over signals is already reactive
when called inside JSX or a tracked scope. Reach for `createMemo` only when the
computation is expensive or read from multiple places:

```tsx
const double = () => count() * 2;                    // fine for cheap derivations
const filtered = createMemo(() =>                    // memo: computed once per change
  items().filter((i) => i.name.includes(query()))
);
```

**Effects** auto-track every signal read synchronously inside them. There are no
dependency arrays, and this is the source of the single nastiest silent bug:

```tsx
// ❌ FORBIDDEN — React habit. The return value is NOT a cleanup function.
// Solid passes it to the next run as an accumulator value. The listener leaks.
createEffect(() => {
  window.addEventListener('resize', onResize);
  return () => window.removeEventListener('resize', onResize);
});

// ✅ MANDATORY — onCleanup registers disposal with the owning scope.
createEffect(() => {
  const handler = makeHandler(mode()); // tracked: re-runs when mode changes
  window.addEventListener('resize', handler);
  onCleanup(() => window.removeEventListener('resize', handler));
});
```

Also note what *doesn't* need an effect. Deriving state from other state is a
memo or plain function, never an effect that writes a second signal:

```tsx
// ❌ Effect-writes-signal for derivation (React's useEffect+setState habit)
createEffect(() => setFullName(`${first()} ${last()}`));

// ✅ Derivation is just a function
const fullName = () => `${first()} ${last()}`;
```

Effects are for **synchronizing with the outside world** (DOM APIs, analytics,
subscriptions) — not for computing values.

## Props: the three tools

Props are a proxy of compiled getters. Property access is what subscribes; the
moment you destructure, you've read the value once at setup and disconnected
from all future updates.

```tsx
// ❌ FORBIDDEN — both forms freeze values at mount time
function Card({ title, tone }: CardProps) { ... }
function Card(props: CardProps) {
  const { title } = props;
  ...
}

// ✅ MANDATORY — access through the proxy, every time
function Card(props: CardProps) {
  return <h2>{props.title}</h2>;
}
```

For defaults, use `mergeProps`; for forwarding rest attributes to a DOM element,
use `splitProps`. Both preserve reactivity; object spread does not.

```tsx
import { mergeProps, splitProps, type ComponentProps } from 'solid-js';

interface ButtonProps extends ComponentProps<'button'> {
  tone?: 'primary' | 'ghost';
  label: string;
}

function Button(rawProps: ButtonProps) {
  const props = mergeProps({ tone: 'primary' as const }, rawProps);
  const [local, rest] = splitProps(props, ['tone', 'label']);
  return (
    <button classList={{ ghost: local.tone === 'ghost' }} {...rest}>
      {local.label}
    </button>
  );
}
```

`children` is also a getter — calling `props.children` multiple times can
re-create DOM. If you need to inspect or reuse children, resolve them once with
the `children` helper:

```tsx
import { children } from 'solid-js';
const resolved = children(() => props.children);
```

## Control flow components

JSX expressions in Solid compile to fine-grained bindings, but `.map()` and
inline ternaries recreate their output wholesale. The control-flow components
exist to preserve DOM nodes and evaluate branches lazily.

```tsx
import { Show, For, Index, Switch, Match } from 'solid-js';

// ❌ Recreates every <li> whenever items changes
<ul>{items().map((item) => <li>{item.name}</li>)}</ul>

// ✅ Diffs by reference, moves existing nodes
<ul>
  <For each={items()}>{(item, i) => <li>{i() + 1}. {item.name}</li>}</For>
</ul>
```

**`<For>` vs `<Index>`** — a genuinely confusing pair; the rule of thumb:

- `<For>`: lists of **objects** keyed by reference. Callback gets
  `(item, index)` where `item` is the plain value and `index` is a **signal**
  (`i()`).
- `<Index>`: lists of **primitives** or fixed-position slots (form fields).
  Callback gets `(item, index)` where `item` is a **signal** (`item()`) and
  `index` is a plain number — the inverse of `<For>`.

**Branching:**

```tsx
// ❌ Allowed only for trivial inline values, never for element branches
<div>{loggedIn() ? <Dashboard /> : <Login />}</div>

// ✅ Lazy, memoized, and supports the keyed/callback form
<Show when={user()} fallback={<Login />}>
  {(u) => <Dashboard user={u()} />}
</Show>

<Switch fallback={<NotFound />}>
  <Match when={route() === 'home'}><Home /></Match>
  <Match when={route() === 'about'}><About /></Match>
</Switch>
```

The callback form of `<Show when={...}>` narrows the type — `u` is a non-null
accessor — which is why it beats `user() && <Dashboard user={user()!} />`.

## Stores for nested state

Reach for `createStore` the moment state is a nested object or an array of
objects. A store proxies property access at every depth, so updates re-render
only the exact leaves that changed.

```tsx
import { createStore, produce, reconcile } from 'solid-js/store';

const [state, setState] = createStore({
  filter: 'all' as Filter,
  todos: [] as Todo[],
});

// Path syntax: surgical updates, no spread pyramids
setState('filter', 'active');
setState('todos', (t) => t.id === id, 'done', (d) => !d);
setState('todos', (todos) => [...todos, newTodo]);

// produce: imperative mutation for multi-step updates (Immer-style)
setState(produce((s) => {
  s.todos.push(newTodo);
  s.filter = 'all';
}));

// reconcile: replace with diffing when new data arrives wholesale (e.g. from
// the server) — keeps referential stability so <For> doesn't rebuild the list
setState('todos', reconcile(freshTodos));
```

Rules that follow from the proxy design:

- Never mutate the store object directly (`state.todos.push(...)` ❌) — always
  go through the setter.
- Don't destructure store values you want to stay reactive (same reason as
  props).
- One `createStore` with a well-typed shape beats five `createSignal`s that
  always change together.

## Async: createResource, Suspense, ErrorBoundary

For client-side async that genuinely belongs in an island (remember: if the
server already had the data, pass it as props instead):

```tsx
import { createResource, Suspense, ErrorBoundary, Show } from 'solid-js';

function SearchResults(props: { initialQuery: string }) {
  const [query, setQuery] = createSignal(props.initialQuery);
  const [results] = createResource(query, fetchResults); // refetches when query changes

  return (
    <ErrorBoundary fallback={(err, reset) => <ResultsError error={err} retry={reset} />}>
      <Suspense fallback={<ResultsSkeleton />}>
        <Show when={results()} keyed>
          {(r) => <ResultsList items={r} />}
        </Show>
      </Suspense>
    </ErrorBoundary>
  );
}
```

- The first argument is the reactive **source**; when it changes, the fetcher
  re-runs. Return `false`/`null`/`undefined` from the source to pause fetching.
- `results.loading` and `results.error` are reactive; `results.latest` keeps the
  previous value during refetch — use it to avoid skeleton flashes on
  subsequent loads.
- Always pair with a **sized** fallback (skeleton matching final dimensions),
  never a bare spinner that causes layout shift.

## Lifecycle and refs

```tsx
import { onMount, onCleanup } from 'solid-js';

function Chart(props: { points: Point[] }) {
  let canvas!: HTMLCanvasElement; // definite assignment: ref is set before onMount

  onMount(() => {
    const chart = createChartIn(canvas, props.points);
    onCleanup(() => chart.destroy());
  });

  return <canvas ref={canvas} class="h-64 w-full" />;
}
```

- `onMount` runs once after the component's DOM is attached — the place for
  DOM-dependent setup (measuring, third-party libs, focus management).
- `onCleanup` is scope-based disposal: valid inside components, effects, and
  memos. It is the *only* cleanup mechanism — never a returned function.
- A ref is a plain variable (or a callback `ref={(el) => ...}`). There is no
  `useRef`, and no `.current`. For mutable non-reactive values, a plain `let`
  in the component body is correct and stable, because the body runs once.

## Events

```tsx
<button onClick={handleClick}>          // delegated (Solid attaches one document-level listener)
<input onInput={(e) => setQuery(e.currentTarget.value)} />  // per-keystroke
<input onChange={commitValue} />        // NATIVE change: fires on blur/commit, not per keystroke
<div on:custom-event={handler} />       // native, non-delegated listener — needed for custom events
```

The `onChange` row deserves emphasis: React remaps `onChange` to input events;
Solid does not. Using `onChange` for live-typing state means the UI updates only
on blur — a bug that looks like "state is lagging."

Handlers are plain functions and stable by construction (the component body runs
once), so there is no `useCallback` and no memoization ceremony.

## Escape hatches: batch, untrack, on

```tsx
import { batch, untrack, on, createEffect } from 'solid-js';

// batch: multiple writes, one downstream update pass
batch(() => {
  setFirst('Ada');
  setLast('Lovelace');
});

// untrack: read a signal inside a tracked scope WITHOUT subscribing to it
createEffect(() => {
  log(`query changed to ${query()} at page ${untrack(page)}`);
});

// on: explicit dependencies + defer (skip the initial run — the closest thing
// to "effect that only fires on change")
createEffect(on(query, (q) => trackSearch(q), { defer: true }));
```

Use these when you need them and not before — they are precision tools, not
defaults. If you find yourself sprinkling `untrack` everywhere, the reactive
graph is probably shaped wrong.

## Context

Solid has `createContext`/`useContext` with an API close to React's — this one
instinct is safe. The Solid-specific detail: pass reactive values (signals,
stores, or getters), not snapshots, so consumers stay live:

```tsx
import { createContext, useContext, type ParentProps } from 'solid-js';

const ThemeContext = createContext<{ theme: () => Theme; setTheme: (t: Theme) => void }>();

export function ThemeProvider(props: ParentProps) {
  const [theme, setTheme] = createSignal<Theme>('light');
  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {props.children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
  return ctx;
}
```

One island = one context tree. Context does **not** cross island boundaries —
for state shared between separate islands on a page, use module-level stores
(see SKILL.md, "Shared state across islands").
