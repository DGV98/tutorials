# Lesson 10 — Boundaries: `unknown`, type guards, casts, and your tsconfig

**Why this matters for React:** every piece of data your app receives from
outside — a `fetch` response, a route param, `localStorage`, a form field —
arrives with no type at all. In lesson 13 you'll type real Next.js data
fetching, and every one of those calls crosses the boundary this lesson is
about. Apps that skip this discipline get production crashes TypeScript
"should have caught" — it couldn't, because someone lied to it at the edge.

## The boundary mental model

TypeScript proves things about code it can *see*. Inside your program, every
value's type traces back through assignments and returns the compiler has
checked — that's why you can refactor fearlessly. But data from **outside**
your program — `fetch` bodies, `JSON.parse`, `localStorage`, form input,
environment variables — is a *claim*, not a proof. The compiler was not there
when the server built that JSON.

So there are two worlds:

- **Inside:** types are proven. Trust them completely.
- **The boundary:** data must be *checked at runtime* before its type can be
  trusted.

Everything in this lesson is about crossing that line honestly.

## `JSON.parse` returns `any` — the landmine

Lesson 01 called `any` "the off switch". For historical reasons, `JSON.parse`
is typed to return `any`, which means every parse silently plants one:

```ts
const user = JSON.parse(body)   // type: any — checking is OFF from here on
user.naem.toUpperCase()         // typo compiles fine, explodes at runtime
```

The discipline: the moment outside data enters, annotate it `unknown`.

```ts
const user: unknown = JSON.parse(body)
user.naem                       // error: 'user' is of type 'unknown' — caught!
```

One character of honesty (`: unknown`) turns the checking back on.

## `unknown`: the honest twin of `any`

Both mean "this could be anything". The difference is what you're allowed to
do next:

| | `any` | `unknown` |
|---|---|---|
| assign anything *to* it | yes | yes |
| use it without checking | yes (danger) | **no** (compile error) |

With `unknown` you can do almost nothing: no property access, no calls, no
math. You can pass it around, compare it with `===`, and — the whole point —
**narrow** it.

## Narrowing `unknown`: lesson 04's tools, aimed outward

You already know narrowing from lesson 04; the same moves work on `unknown`:

```ts
function describe(x: unknown): string | number {
  if (typeof x === "string") return x.toUpperCase()   // x: string here
  if (Array.isArray(x)) return x.length               // x: any[] here (!)
  if (typeof x === "object" && x !== null && "id" in x) {
    return String(x.id)                               // x.id exists — as unknown
  }
  return "no idea"
}
```

Three gotchas, all of which the exercises will make you feel:

1. **`typeof null === "object"`** — a JavaScript fossil. Always pair the
   object check with `x !== null`.
2. **`in` refuses to run on `unknown`.** Prove it's an object first; *then*
   `"id" in x` narrows, and `x.id` comes out typed `unknown` — keep narrowing
   (`typeof x.id === "number"`). Turtles all the way down.
3. **`Array.isArray` narrows `unknown` to `any[]`** — the *elements* are
   still unverified. Check them too, e.g.
   `x.filter((el): el is number => typeof el === "number")`.

## Type predicates: teaching the compiler your checks

Boundary checks get long, and you want to reuse them. A **type predicate**
turns a boolean function into something the compiler learns from — the return
type `x is User` instead of `boolean`:

```ts
type User = { id: number; name: string }

function isUser(x: unknown): x is User {
  return (
    typeof x === "object" && x !== null &&
    "id" in x && typeof x.id === "number" &&
    "name" in x && typeof x.name === "string"
  )
}

if (isUser(data)) {
  data.name   // data is User in here — fully typed, no casts
}
```

Power **and** responsibility: TypeScript does *not* verify that the body
actually proves the claim. This compiles and lies:

```ts
function isUser(x: unknown): x is User {
  return typeof x === "object" && x !== null   // any object "is" a User?!
}
```

A wrong predicate is worse than no predicate — everything downstream trusts
it. Write the body as if the compiler were watching, because it isn't.

## Assertion functions, briefly

A sibling you'll meet in the wild: instead of returning a boolean, **throw**
on bad data, and the rest of the scope is narrowed — no `if` needed:

```ts
function assertUser(x: unknown): asserts x is User {
  if (!isUser(x)) throw new Error("not a User")
}

assertUser(data)
data.name        // User from this line down
```

Same trust rules apply. Recognize the `asserts` keyword; you'll see it in
API layers and test helpers.

## `as` — casting, honestly

`value as T` tells the compiler "trust me, it's a T". It **silences; it never
verifies** — nothing happens at runtime. It has legitimate uses, when you
genuinely know more than the compiler can:

```ts
const el = document.getElementById("email") as HTMLInputElement
```

You wrote that HTML; the compiler didn't. Fine. The danger is that `as` looks
like a fix but is only a gag order — the lie in this lesson's exercise 4
compiles beautifully and corrupts every type downstream.

TypeScript at least refuses casts between unrelated types — which is why the
**double cast** `x as unknown as T` is a smell: it launders anything into
anything. In application code it almost always marks a bug being hidden.

Safer habits, in order of preference:

1. Narrow instead (guards, predicates) — proves it at runtime.
2. `satisfies` (lesson 07) — checks a value against a type *without* changing it.
3. If you must cast, do it once, at the boundary, with a comment saying why
   you know better.

## The non-null assertion `!`

`expr!` strips `null | undefined` from a type — a cast in a trench coat:

```ts
const port = process.env.PORT!   // compiles; crashes later if PORT is unset
```

`strictNullChecks` (below) is the flag protecting you here; `!` switches it
off for one expression. Prefer `??` with a fallback, a real check, or an
early throw. Exercise 5 sets the trap.

## The industrial version: runtime validators

Hand-written guards don't scale to a 40-endpoint API. Libraries like **zod**
flip the workflow: define a schema once, get *both* the runtime validation
and the static type (`z.infer<typeof schema>`) from one source of truth.
Under the hood it's exactly the predicates you're writing in this lesson —
generated, composed, with good error messages. Nothing to install here; when
you see `schema.parse(await res.json())` in a Next.js codebase, you'll know
precisely what it's doing and why.

## Your `tsconfig.json`, decoded

You've been living under these flags for nine lessons. Open the root
`tsconfig.json` in a split and match these up:

- **`strict: true`** — an umbrella that switches on the whole strict family.
  The two load-bearing ones:
  - **`strictNullChecks`** — `null`/`undefined` are tracked in types. This is
    why `Map.get` returns `string | undefined` and why exercise 5 errors.
    Without it, half this course's safety evaporates.
  - **`noImplicitAny`** — anything the compiler can't infer must be
    annotated; silent `any` is banned.
- **`noEmit: true`** — `tsc` checks and never writes JavaScript. We run files
  with `tsx` instead. Next.js works the same way: the bundler compiles, `tsc`
  only checks. Types in, no build artifacts out.
- **`verbatimModuleSyntax: true`** — imports of *types* must say
  `import type`. Why: fast single-file transpilers (esbuild/swc — what `tsx`
  and Next use) erase types without reading other files, so the syntax itself
  must declare what's erasable. This is why every exercise file starts with
  `import type { Expect, Equal }`. Exercise 7 shows the error you get
  otherwise.
- **`types: ["node"]`** — TypeScript 7 doesn't auto-load every installed
  `@types` package; we opt into Node's globals (`process`, etc.) explicitly.
- **`jsx: "react-jsx"`** — the modern JSX transform; no `import React`
  needed just to write JSX. Dormant until lesson 11.
- **`moduleResolution: "bundler"`** — resolve imports the way Vite/Next
  bundlers do (extensionless relative imports, package `exports` maps).
- **`skipLibCheck: true`** — don't type-check the `.d.ts` files inside
  `node_modules`. Faster, and it stops other libraries' internal squabbles
  from failing *your* build. Your own code is still fully checked.
- The rest (`target`, `module`, `lib`, `esModuleInterop`) collectively say
  "modern JavaScript, ES2022 + DOM APIs available".

## Exercises

Open `exercises.ts` — it has errors right now, on purpose. Fix them all,
then run the file to see the runtime checks pass:

```
./check 10
npx tsx lessons/10-boundaries-and-config/exercises.ts
```

Stuck? `solution.ts` sits next door, with commentary.

## Key takeaways

- Inside your program, types are proven; data from outside is a **claim** —
  check it at runtime before trusting it.
- `JSON.parse` returns `any`. Annotate the result `: unknown` immediately.
- `unknown` allows nothing until you narrow: `typeof`, `Array.isArray`, `in`
  (object + `!== null` check first).
- A type predicate (`x is User`) makes guards reusable — and its body is
  *trusted*, so a wrong one lies to the compiler.
- `as` silences, never verifies; `as unknown as X` is a red flag; `!` is a
  tiny cast — prefer `??` or a real check.
- `strict` (especially `strictNullChecks` and `noImplicitAny`) is what's been
  protecting you all course; `verbatimModuleSyntax` is why `import type`.
- zod-style validators are the industrial version of your hand-written
  guards. Every `fetch` in lesson 13 crosses this boundary.
