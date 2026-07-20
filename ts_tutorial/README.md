# TypeScript, from zero to advanced — in nvim

A hands-on course you work through entirely in your editor. There are no
videos and no quizzes: each lesson is a set of files whose **type errors are
the exercise**. You read the notes, open the exercise file, and fix code
until the compiler goes quiet. That feedback loop — red squiggle, hover,
think, fix — is exactly how you'll work in real React and Next.js codebases,
so the course trains the skill directly.

## Goal

By the end you should be able to:

- read any TypeScript error message and know what it's telling you,
- write React components with precisely-typed props, state, events, and hooks
  without guessing,
- understand what Next.js's generated types (page props, route handlers,
  server actions) are actually doing.

## How a lesson works

Every lesson folder has three files:

| File | What it is |
|---|---|
| `notes.md` | The teaching. Read it first (or side-by-side in a split). |
| `exercises.ts(x)` | Broken on purpose. Fix it until the checker is silent. |
| `solution.ts(x)` | The answers, with commentary. No shame in peeking. |

The exercise files use type-level assertions that look like this:

```ts
type _check = Expect<Equal<typeof result, string[]>>
```

That line errors until `result` is exactly `string[]`. Fix the code above
the assertion — never the assertion itself.

## Commands

```sh
./check 03            # type-check lesson 03 (exercises + solution)
./check 03 --watch    # re-check on every save — keep in a split terminal
./check               # type-check the whole course (your progress meter)
npx tsx lessons/01-types-basics/exercises.ts   # actually run a file
```

A lesson is done when `./check NN` reports zero errors.

## The nvim workflow

Your LSP (vtsls) does the heavy lifting — open nvim **from this directory**
so it picks up `tsconfig.json` and the local TypeScript. The three habits
that matter:

- **`K` (hover)** — ask TypeScript what type it thinks something has. This is
  the single most important habit in the course; hover *everything*.
- **`gd` (go to definition)** — works on types too, including into
  `@types/react` itself. Reading library types is an advanced-TS superpower
  and it's one keystroke away.
- **Diagnostics** — the exercise list *is* the diagnostics list. `]d` / `[d`
  jump between them; `<leader>`-your-diagnostic-float shows the full message
  when the virtual text truncates.

If the LSP shows stale errors after you fix something across files,
`:LspRestart` clears it up.

## Curriculum

**Part 1 — Foundations**

| # | Lesson | You learn |
|---|---|---|
| 01 | `01-types-basics` | primitives, inference, annotations, literal types, `any` |
| 02 | `02-objects-and-tuples` | object shapes, optional/readonly, structural typing, tuples |
| 03 | `03-functions` | typing params/returns/callbacks, `void`, `never` |
| 04 | `04-unions-and-narrowing` | unions, narrowing, discriminated unions, exhaustiveness |
| 05 | `05-interfaces-types-classes` | interface vs type, intersections, classes where they matter |

**Part 2 — The type system for real**

| # | Lesson | You learn |
|---|---|---|
| 06 | `06-generics` | generic functions/types, inference, constraints |
| 07 | `07-deriving-types` | `typeof`, `keyof`, indexed access, `as const`, `satisfies` |
| 08 | `08-utility-types` | `Partial`, `Pick`, `Omit`, `Record`, `ReturnType`, `Awaited`… |
| 09 | `09-mapped-conditional-types` | mapped types, conditional types, `infer`, template literals |
| 10 | `10-boundaries-and-config` | `unknown` at API boundaries, type guards, casts, tsconfig |

**Part 3 — React & Next.js (the payoff)**

| # | Lesson | You learn |
|---|---|---|
| 11 | `11-react-props` | props, `children`, union props, wrapping native elements |
| 12 | `12-react-state-events-hooks` | `useState`/`useRef`/`useReducer`, events, custom hooks, generic components |
| 13 | `13-nextjs-patterns` | page props, route handlers, server actions, typing `fetch` |

**Part 4 — The capstone**

| # | Lesson | You learn |
|---|---|---|
| 14 | `14-capstone` | **Heavy Rotation**: one real app, front to back — everything, composed |

Do them in order — later exercises lean on earlier concepts on purpose.
Expect Part 1 to feel quick and lesson 09 to feel like a workout; that's the
intended difficulty curve.

The capstone breaks the one-lesson-one-file mold: instead of a single
`exercises` file it is eight numbered stage files (`01-domain.ts` …
`08-app.tsx`) that build one music-listening dashboard, with solved
versions in `solution/`. Its `notes.md` explains the layout — read it
first.

## Rules of engagement

1. **Hover before you Google.** Most questions are answered by `K`.
2. **Read the error twice.** `Type 'X' is not assignable to type 'Y'` means
   "you gave X where Y belongs" — first type is yours, second is required.
3. **Don't use `any`.** If you're stuck enough to reach for it, that's the
   lesson working — check the solution file instead.
4. **Peeking is studying.** Reading `solution.ts` and then re-doing the
   exercise from scratch is a legitimate and effective way to learn.

## After the course

- Do a handful of [type-challenges](https://github.com/type-challenges/type-challenges)
  (start with "easy" — after lesson 09 they'll feel familiar).
- Start a real Next.js app (`npx create-next-app@latest --typescript`) and
  build something small; wire up a form with a server action and type the
  whole flow.
- When a library's types confuse you, `gd` into them. You now speak the
  language they're written in.
