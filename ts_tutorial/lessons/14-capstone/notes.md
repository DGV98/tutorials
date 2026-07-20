# Capstone — Heavy Rotation

**Why this matters for React:** for thirteen lessons this paragraph pointed
at some future payoff — a component you'd type later, a Next.js pattern
waiting at the end. Not this time. There is no motivating example, because
this IS the app. **Heavy Rotation** is a music-listening tracker — a typed
domain, a player state machine, design tokens, a validated API boundary, a
mapped-type toolkit, a component library, hooks, and a Next-shaped app
layer — and you build all of it. Thirteen lessons of fixing other people's
broken files end here: the last file you fix is your own.

## The repo map

Eight numbered stage files, one per sitting-or-so, each standing in for a
place in a real Next.js repo:

| Stage file | In a real Next repo | What it is |
|---|---|---|
| `01-domain.ts` | `lib/domain.ts` | `Track`, `Play`, `Playlist` — the nouns |
| `02-player.ts` | `lib/player.ts` | the player reducer and its action union |
| `03-tokens.ts` | `lib/tokens.ts` | genres, badge colors, sort labels, API routes — derived, never duplicated |
| `04-api.ts` | `lib/api.ts` | the boundary: guards, predicates, `HttpError` |
| `05-type-kit.ts` | `types/kit.ts` | your utility-type toolkit (the boss fight) |
| `06-components.tsx` | `components/*.tsx` | `GenreBadge`, `TrackCard`, `SearchInput`, `List`, `TrackForm` |
| `07-hooks.tsx` | `hooks/*.tsx` | `useNowPlaying`, `usePlayer`, the wired-up `PlayerBar` |
| `08-app.tsx` | `app/**` | pages, layouts, route handlers, a server action |

And the import graph — who feeds whom:

```
01-domain ──┬──> 02-player ──────────> 07-hooks
            ├──> 03-tokens ──┬──> 06-components ──> 08-app
            ├──> 04-api ─────┼─────────────────────> 08-app
            └──> (types + seed data into 06, 07, 08 as well)

05-type-kit  (imports NOTHING — soundproof) ──> 06-components, 08-app
given/*.ts   (complete, untouchable)        ──> 04-api, 08-app
```

Every finished layer becomes the imported foundation of the next. By stage
08 you are wiring **your** types into **your** components inside **your**
pages — which is exactly the job you're graduating into.

## How to work

**One stage per sitting, strictly top to bottom.** The stages import each
other in order, so working out of order means fighting errors whose causes
live in files you haven't opened yet.

`./check 14` type-checks the **whole directory** — all eight stages at
once. That means on day one it prints errors from every unstarted stage:
expect roughly **136 errors**. That listing is your
todo list, not noise. Watch it shrink stage by stage; that's your progress
meter.

The per-stage loop is the one you know: open the stage file in nvim, let
vtsls light it up, and work the diagnostics — `]d` / `[d` to jump, `K` to
hover, `gd` to chase a type home. When you want a CLI view of just your
current stage, filter:

```sh
./check 14 2>&1 | grep '04-'    # only stage 04's errors
```

**A stage is done when `./check 14` shows zero errors mentioning its
number** — and, for the runnable stages, when `npx tsx` on it prints all
checks passing:

```sh
npx tsx lessons/14-capstone/01-domain.ts    # stages 01, 02, 04 also run
```

Two warnings worth pinning:

- A few assertions in stages 06 and 08 stay red **until stage 05 is
  solved** — they consume the types you build there. The error names the
  imported type; that's your cue that the fix lives upstream, and the
  work-in-order rule has you covered.
- If the LSP shows stale errors after a fix in another file,
  `:LspRestart`. Cross-file type flow is exactly where vtsls caches go
  stale.

## The effort map

Slow progress on some stages is by design, not a sign you're failing:

| Stage | Budget | Feel |
|---|---|---|
| 01–03 | one sitting each | warmup ramping to moderate |
| 04 | a full evening | hard — the boundary demands rigor |
| 05 | a full evening | **the boss fight** — the header says so |
| 06–07 | one sitting each | hard, but riding momentum from 05 |
| 08 | one sitting | the victory lap — deliberately a step down |

And lesson 09's license is hereby restated for the whole capstone: if a
task fights you for more than fifteen minutes, read the matching file in
`solution/`, then re-do it from scratch. **Peeking is studying.**

## New moves taught here

Four constructs go one step beyond the course inventory. Everything else
in the capstone you have already done at least once; these four you meet
here first — so learn them here, then spend them in the exercises.

### `-readonly` — the mirror of `-?`

Lesson 09 taught the modifier syntax: `-?` strips optional. The same minus
works on `readonly`:

```ts
type Locked = { readonly apiKey: string; readonly retries: number }

type Unlock<T> = { -readonly [K in keyof T]: T[K] }

type Editable = Unlock<Locked>
// { apiKey: string; retries: number } — readonly gone from every key
```

There is no built-in "Mutable" utility; when you need one, this is how you
write it. The exercise version combines `-readonly` with `?` in a single
mapped type — two modifiers, one loop.

### A conditional type in the mapped *value* position

Lesson 09's mapped types transformed every value the same way
(`T[K] | null` for all keys). But `T[K]` is just a type, so it can sit in
a conditional — meaning each value gets its own `if`:

```ts
type Wire<T> = {
  [K in keyof T]: T[K] extends bigint ? string : T[K]
}

type Stats = { totalPlays: bigint; label: string }
type WireStats = Wire<Stats>
// { totalPlays: string; label: string } — only the bigint changed
```

Read it per key: does *this* value type match? Rewrite it. Otherwise pass
it through untouched. The exercise applies the same move to the type
JSON.stringify actually inflicts on your data — `Date` survives nowhere.

### `infer` inside a template literal

Lesson 09 used `infer` to capture pieces of arrays, functions, and
Promises. Template literal types are also matchable shapes, and `infer`
works inside them — with `${string}` as a wildcard for "anything here":

```ts
type FileExtension<Path> = Path extends `${string}.${infer Ext}`
  ? Ext
  : never

type A = FileExtension<"cover.png">   // "png"
type B = FileExtension<"README">      // never — no dot, no match
```

TypeScript pattern-matches the string type against the template and hands
you the captured piece. The exercise aims this at something you have seen
in every Next.js tutorial: extracting the dynamic segment from a route
path.

### Key remapping to `never` — filtering keys

Lesson 09's notes dropped this as a bonus fact: remapping a key to `never`
**deletes it**. Put a conditional inside the `as` clause and you can
filter an object's keys by their value types:

```ts
type Methods<T> = {
  [K in keyof T as T[K] extends (...args: never[]) => unknown ? K : never]: T[K]
}

type Player = { title: string; play: () => void; stop: () => void }
type PlayerMethods = Methods<Player>
// { play: () => void; stop: () => void } — title filtered out
```

Trace one key: `title` is `string`, not a function, so it remaps to
`never` and vanishes; `play` matches, so it keeps its own name `K`. The
exercise version filters *and* renames in the same `as` clause — the last
stub in the boss fight, and the hardest line in the capstone.

## The stages

**01 — The Crate** (lessons 01, 02, 05). Model the music library: fix a
sabotaged `Track` type, an evolving-`any` array, a `number[]` that should
be a labeled readonly tuple, an excess-property typo, and two one-keyword
fixes (`extends`, `&`). Warmup pace — but everything downstream imports
these types, so the whole app stands on this file.

**02 — The player state machine** (lessons 03, 04, 06). Annotate
parameters under `noImplicitAny`, fix a body instead of loosening its
contract, dodge the `!positionSec` zero-trap at runtime, and complete a
discriminated-union reducer whose exhaustiveness is proven by a single
`: never` annotation. The generic `pluck` rebuild is lesson 06's canonical
lookup pattern. Payoff: stage 07 feeds this exact reducer to `useReducer`.

**03 — Tokens and routes** (lessons 07, 08). Type-level only — nothing to
run, silence is the finish line. `as const`, the `(typeof X)[number]`
derivation replacing a drifted hand-written union, and the
annotation-widens / `as const`-narrows / `satisfies`-audits triangle three
times over — including a template-literal-constrained
``satisfies Record<string, `/api/${string}`>`` that catches a malformed
route. Payoff: `Genre` is cross-checked against `Track["genre"]` (one
source of truth), `BADGE_TONES` styles stage 06's `GenreBadge`, and
`API_ROUTES` resurfaces in stage 08.

**04 — The boundary** (lessons 10, 08, 05, 13). Budget a full evening.
Everything crossing into the app arrives as `unknown` and earns its type:
a narrowing chain for `readVolume`, a turtles-all-the-way-down `isTrack`
predicate, `Array.isArray` + `.filter(predicate)`, and an `HttpError`
class with a parameter property. One check here is **runtime-gated on
purpose**: a lazy predicate body type-checks fine but lets a malformed
catalog entry through — predicates are trusted, not verified, and the
`npx tsx` backstop is load-bearing (lesson 10's deepest point). Payoff:
stage 08 catches your `HttpError` with `instanceof` and guards its fetch
with your `isTrack`.

**05 — The type kit: BOSS FIGHT** (lessons 09, 06, 08). The header says
so. This file imports **nothing** from the other stages — the arena is
soundproof, so every error on screen is yours. Eight `unknown // ← replace`
stubs, easiest first, each with its `Expect` suite right below: lesson
09's greatest hits rebuilt from memory, plus all four new moves from the
section above. Budget a full evening and hover every intermediate. The
entire React layer ahead runs on what you build here.

**06 — The component library** (lessons 11, 12, 08, 02). Props types with
defaults and optional `children`, a `TrackCard` whose
`playable`/`onPlay` pairing becomes a discriminated union kept whole for
narrowing, `Omit`-before-override on `ComponentProps<"input">`, and a
generic `List` via function declaration. Then the boss fight pays off:
`TrackForm` derives its draft and handler props from *your* `Draft` and
`EditableHandlers`, and the spec's callbacks contextually type themselves
in real JSX.

**07 — Hooks** (lessons 12, 04). Wire the player: `useState<Track | null>`
for nullable state, both `useRef` flavors under React 19 (the argument is
required now), `ref` as a regular prop — no `forwardRef` — and
`useReducer` running your stage-02 reducer, with broken `dispatch` calls
erroring against the untouchable action union. Three extracted handlers
need event annotations, and one of them springs lesson 12's
`MouseEvent` import trap: the DOM global shadows React's type until you
fix the `import type` line.

**08 — Ship it** (lessons 13, 10, 04, 11). The victory lap. Each banner
names the Next file it would be: await Promise-typed `params`, collapse a
`searchParams` union with one ternary, give a layout its
`children: ReactNode`, return `Promise<Response>` from route handlers,
narrow `FormData` in a server action with a single `typeof` guard, and
guard a fake fetch with your own predicate. `serializePlay`'s lying
`: Play` annotation gets replaced with `Serialized<Play>` — the honest
wire truth from your kit. Finish the two broken usages of your own
`TrackCard` and the course finish line is a fully green `./check 14`.

## The rules

1. **Never edit `Expect<Equal<...>>` lines** — same as always. That goes
   for `@ts-expect-error` spec guards too: they are assertions that an
   error *should* be there.
2. **No `any`. No casts.** (`as const` is allowed — it's narrowing, not
   lying.) If you're reaching for either, that's the capstone working;
   read the solution instead.
3. **`given/` files and `GIVEN`-marked blocks are untouchable.** They are
   complete and correct; if an error seems to point at one, the real fix
   is in your code nearby.
4. **Solutions live in `solution/`** — one solved file per stage, with
   commentary. They import only each other, never your exercise files, so
   peeking can't spoil your progress.
5. **Work the stages in order.** The import graph is the syllabus.

## Commands

```sh
./check 14                                   # type-check the whole capstone
./check 14 --watch                           # re-check on save — keep in a split
./check 14 2>&1 | grep '05-'                 # only the stage you're on
npx tsx lessons/14-capstone/01-domain.ts     # run a runnable stage (01, 02, 04)
npx tsx lessons/14-capstone/02-player.ts
npx tsx lessons/14-capstone/04-api.ts
./check solutions                            # the solved world, always green
```

## You built this

When stage 08 goes green, do one last thing before you close the editor.
Find the spec block where `DashboardPage` renders your `List`, put your
cursor on the `track` parameter inside `renderItem`, and press `K`.

That's **your** domain type, flowing through **your** generic component,
inside **your** page — inferred, not annotated, correct at every hop. In
lesson 01 that hover showed you a red squiggle you couldn't read. Now it
shows you an app you can.

## Key takeaways

- A real TypeScript app is layers: domain → state → tokens → boundary →
  type kit → components → hooks → app. Types flow **up** the import graph,
  and errors point **down** it — when a red line names an imported type,
  the fix lives upstream.
- `./check 14` on day one prints every unstarted stage's errors. A big
  error count is a todo list, not a verdict.
- `-readonly` strips `readonly`; a conditional in the mapped value
  position rewrites values selectively; `infer` pattern-matches inside
  template literals; remapping a key to `never` deletes it. Those four
  plus lesson 09 are the whole dialect `@types/react` is written in.
- Type predicates are trusted, not verified — sometimes only a runtime
  check can catch a lazy guard. That's why stages 01, 02, and 04 run.
- Derive, don't duplicate: every hand-written type the capstone makes you
  delete (`Genre`, `TrackDraft`, `DashboardData`, `Serialized<Play>`) was
  a copy that had already drifted from its source.

## After the capstone

`npx create-next-app@latest --typescript` and build something real. You
have now hand-rolled the domain, the boundary, the components, the hooks,
and the app shell — the only new thing in a real Next project is that the
types you built by hand in `given/next.ts` are generated for you. Wire a
form to a server action, type the whole flow, and when a library's types
confuse you, `gd` into them.

Red squiggle, hover, think, fix. Go build something.
