# Neutronium

**An agent-agnostic skill for building beautiful, fast front ends with Astro + SolidJS + TypeScript.**

Neutronium is a set of execution instructions for AI coding agents — Claude
Code, Cursor, Copilot, Codex, or anything that can read a markdown file. Drop
it into a project and any agent working on the front end inherits two things
most generated UI lacks:

1. **Correctness in a stack that punishes React instincts.** Solid's JSX looks
   like React's, so agents steeped in React training data reflexively write
   code that compiles and silently doesn't work — destructured props that
   freeze, effect cleanups that never run, `.map()` calls that rebuild the DOM.
   Neutronium names each trap, explains *why* it fails, and gives the correct
   pattern.
2. **A real visual-quality bar.** "It renders" is not "it's designed."
   Neutronium defines a design process (tokens → personality → components), the
   craft rules (typography, spacing, color, motion, states), and an anti-slop
   checklist that catches the generic-generated-UI look before it ships.

## What's inside

```
SKILL.md                          The core skill: mental model, hard rules,
                                  hydration discipline, verification workflow
references/
├── solid-reactivity.md           SolidJS deep dive: signals, stores, resources,
│                                 control flow, refs, events, context
├── astro-islands.md              Islands architecture: hydration directives,
│                                 the serialization boundary, Astro Actions,
│                                 progressive-enhancement forms
├── design.md                     The beauty bar: tokens, typography, color,
│                                 motion, states, accessibility, anti-slop
└── testing.md                    Vitest + @solidjs/testing-library + Playwright:
                                  what to test where, hydration verification
scripts/
└── audit.sh                      Mechanical audit: greps for always-wrong
                                  patterns (React imports, className,
                                  destructured props, ...) — exits nonzero
```

The structure is deliberate: `SKILL.md` is small enough to sit in an agent's
context permanently, and it tells the agent when to pull in each reference.
Agents read the deep dives lazily, only when the task touches that domain.

## Installation

Neutronium follows the [Agent Skills](https://agentskills.io) format
(`SKILL.md` with YAML frontmatter), which most agent harnesses either read
natively or can be pointed at.

**Claude Code** — clone into the skills directory (project-local or global):

```bash
git clone https://github.com/crussella0129/Neutronium .claude/skills/neutronium   # project
git clone https://github.com/crussella0129/Neutronium ~/.claude/skills/neutronium # global
```

**Any AGENTS.md-convention agent** (Codex, Jules, Amp, ...) — vendor the repo
and point at it:

```bash
git clone https://github.com/crussella0129/Neutronium vendor/neutronium
echo "For all front-end work, follow vendor/neutronium/SKILL.md and the reference files it links." >> AGENTS.md
```

**Cursor** — add a rule in `.cursor/rules/neutronium.mdc` that applies to
`*.astro`, `*.tsx`, and front-end `*.ts` files and instructs: *"Follow
vendor/neutronium/SKILL.md; read its linked references when the task touches
their domain."*

**GitHub Copilot** — add the same pointer line to
`.github/copilot-instructions.md`.

**Anything else** — paste `SKILL.md` into the system prompt or context. It's
self-contained; the references add depth but the core rules stand alone.

## The stack it governs

| Layer | Choice | Why |
| --- | --- | --- |
| Framework | [Astro](https://astro.build) | Zero JS by default; islands hydrate only what's interactive |
| Reactivity | [SolidJS](https://solidjs.com) | Fine-grained, compiled, no virtual DOM, no re-renders |
| Types | TypeScript (strict) | Contracts across the server/island serialization boundary |
| Styling | Design tokens + Tailwind / scoped styles / CSS Modules | Consistency is what reads as "designed" |
| Mutations | Astro Actions | End-to-end typed RPC with Zod validation, progressive enhancement built in |
| Testing | Vitest + @solidjs/testing-library + Playwright | Logic → components → real-browser hydration truth |

## Philosophy

Ship almost no JavaScript. Hydrate reluctantly. Let the server do what the
server already knows. Inside islands, embrace Solid's run-once component model
instead of fighting it with React habits. Treat visual quality — typography,
spacing, states, motion, accessibility — as a requirement with the same weight
as type-checking. Verify mechanically what can be verified mechanically
(`scripts/audit.sh`), and reserve judgment for what can't.

Fast and ugly fails. Beautiful and bloated fails. Neutronium exists to make
agents ship neither.

## License

[GPL-3.0](LICENSE)
