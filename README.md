# Neutronium - An Agent Agnostic Front End Skill
---
System Context: You are an expert Principal Systems Architect specializing in modern web performance, fine-grained reactivity, testing frameworks, and AI agent instruction design.

Task Objective:
Generate an exhaustive, enterprise-grade agent skill file named `neutronium.md` for an Astro + SolidJS + TypeScript project. This skill will serve as strict, comprehensive execution instructions for AI coding agents working in this codebase.

Context & Architectural Stack:
- Hosting & Scaffolding: Astro (zero-JS by default, static/SSR routing, Content Collections, Astro Actions)
- Client-Side Reactivity: SolidJS (compiled fine-grained reactivity, direct DOM manipulation, no Virtual DOM)
- Type System: TypeScript (strict mode, prop contracts across hydration boundaries)
- Styling: Astro scoped styles, Tailwind CSS/UnoCSS, CSS Modules
- Mutations: Astro Actions (`astro:actions`) for type-safe RPC server functions
- Testing: Vitest + @solidjs/testing-library for units/components, Playwright for E2E and hydration verification

Detailed Domain Guardrails & Rules to Include in the Skill:

1. FILE & ARCHITECTURAL SEPARATION
   - `.astro` files: Server-only context. Handle layouts, page routing, build-time/SSR data fetching, SEO tags, and static HTML. Zero client-side JS shipped by default.
   - `.tsx` files: Interactive SolidJS islands ONLY. Must be lean and focused on interactive state.
   - `.ts` files: Utilities, domain interfaces, Astro Actions schemas, and shared global reactive stores (using top-level Solid signals/stores).

2. HYDRATION DISCIPLINE
   - Never embed a SolidJS component (`.tsx`) into an `.astro` page without an explicit `client:*` directive, unless intentionally rendering static HTML on the server.
   - Prefer `client:visible` or `client:idle` for non-critical elements. Reserve `client:load` strictly for critical above-the-fold controls.

3. SOLIDJS REACTIVITY RULES (ANTI-REACT COMPLIANCE)
   - Banned Imports: Strictly prohibit imports from 'react' (`useState`, `useEffect`, `useRef`, `useMemo`, `useCallback`).
   - Prop Access: Never destructure `props` in function parameters or component bodies (e.g., `const { title } = props` is FORBIDDEN). Access properties exclusively via `props.title`.
   - Prop Defaults & Splitting: Enforce `mergeProps` for default values and `splitProps` for passing rest attributes down to DOM elements.
   - Signal Invocation: Signals are getter functions. Must be read by invoking them: `count()`, not `count`.
   - JSX Attributes: Use native `class` and `classList={{ active: isActive() }}`. Explicitly ban `className`.
   - Control Flow Components: Enforce Solid primitives (`<Show>`, `<For>`, `<Index>`, `<Switch>`, `<Match>`) over native JS `.map()` or ternary operators inside JSX.
   - Lifecycle Primitives: Enforce `onMount()` for component setup and `onCleanup()` for teardown/disposal. Do NOT return cleanup functions inside `createEffect`.
   - Complex State: Enforce `createStore` from 'solid-js/store' for nested objects and arrays, rather than deeply nested `createSignal` calls.

4. ASTRO TO SOLID DATA BOUNDARIES & ACTIONS
   - All props passed from `.astro` to `.tsx` across hydration boundaries MUST be JSON-serializable (primitives, plain arrays, plain objects).
   - Form Handling & Mutations: Enforce Astro Actions (`astro:actions`) for backend operations. SolidJS client islands must call actions directly (e.g., `await actions.updateProfile(data)`) with type-safe z.object validation schemas defined on the server side.
   - Progressive Enhancement: Static forms in `.astro` files must degrade gracefully using standard HTML POST actions, while SolidJS islands enhance them with optimistic client state.

5. STYLING CONVENTIONS
   - Astro Pages/Layouts: Use scoped `<style>` blocks in `.astro` files for static layout CSS.
   - Solid Components: Use Tailwind CSS utility classes paired with Solid's `classList` directive for dynamic state styling. If scoped component styles are needed, use CSS Modules (`.module.css`).
   - Banned Attributes: Never write `className` in `.tsx` files; it renders as a non-standard custom attribute in SolidJS.

6. CROSS-ISLAND SHARED STATE
   - Instruct the agent to create module-level signals/stores in shared `.ts` files (e.g., `src/stores/cart.ts`) to manage state across multiple independent Solid islands on the same page without external state managers.

7. TESTING & QUALITY ASSURANCE STRATEGY
   - Unit & Component Testing: Enforce Vitest with `@solidjs/testing-library` for isolated SolidJS component state, signals, and store testing.
   - Hydration & E2E Testing: Enforce Playwright for full-page user flows to verify that client islands successfully hydrate, become interactive without layout shifts, and correctly perform server actions.

8. QUALITY GATES & AUDIT CHECKLIST
   - Define a step-by-step verification checklist for the agent to self-audit generated code:
     1. Search for forbidden React hooks, `useEffect`, or `className` attributes.
     2. Check for destructured `props` in Solid components.
     3. Verify all Solid components embedded in `.astro` files have `client:*` directives.
     4. Check that Astro Action input schemas match client payload types.
     5. Ensure TypeScript compilation and test runs pass (`astro check`, `vitest run`, `playwright test`).

Output Format Instructions:
- Output as a complete markdown file starting with standard YAML frontmatter (`name: astro-solid-ts`, `description: ...`).
- Use explicit visual code blocks showing "❌ FORBIDDEN (React/Anti-Pattern)" vs "✅ MANDATORY (Solid/Astro Pattern)" for every key rule.
- Keep the language authoritative, unambiguous, and formatted for optimal LLM context parsing.

Generate the complete `astro-solid-ts.md` file content now.
