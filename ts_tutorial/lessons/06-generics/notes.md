# Lesson 06 — Generics: code that keeps its types

**Why this matters for React:** `useState` is a generic function —
`useState<User | null>(null)` passes a *type argument*, the exact machinery
this lesson teaches. Once generics click, `Promise<T>`, `Array<T>`, and half
the signatures in a React codebase stop looking like magic.

## The problem generics solve

You want a function that returns the first element of *any* array. Lesson 03
taught you to type parameters and returns — so you try:

```ts
function firstItem(items: unknown[]): unknown { return items[0] }

const tag = firstItem(["urgent", "bug"])
// tag: unknown — it WAS a string, but the signature threw that away
```

It accepts everything but forgets everything, and one overload per type
(`(items: string[]): string`, then `number[]`...) doesn't scale. What you
want to say: "whatever element type the caller's array has comes back out."

## Generic functions: `<T>`

```ts
function firstItem<T>(items: T[]): T { return items[0] }
```

The `<T>` before the parentheses **declares a type parameter**, filled in
per call. Using the *same* `T` in the parameter (`T[]`) and the return (`T`)
is what links input to output:

```ts
const tag = firstItem(["urgent", "bug"])  // T = string → tag: string
const score = firstItem([98, 87, 91])     // T = number → score: number
```

## Inference: hover to see what T became

You almost never write the type argument yourself — TypeScript **infers** it
from the value arguments. In nvim, put the cursor on the call and hit `K`:

```
function firstItem<string>(items: string[]): string
```

That `<string>` is inference showing its work. "What did T become here?" is
the debugging question for every confusing generic error you'll ever hit.

## Explicit type arguments

Sometimes inference has nothing to look at, and you fill in `T` by hand:

```ts
const queue = firstItem([])          // T = never — an empty [] says nothing
const queue = firstItem<string>([])  // T = string, by decree
```

The other classic case is a **return-only generic** — `T` isn't in any
parameter:

```ts
function makeEmptyList<T>(): T[] { return [] }
const names = makeEmptyList<string>()  // nothing to infer from — must be explicit
```

This is the `useState` situation: `useState(0)` infers `number`, but
`useState<User | null>(null)` must be explicit — `null` alone infers `null`.

## Multiple type parameters

Declare as many as needed — the classic is `map`, with input and output
element types:

```ts
function mapItems<In, Out>(items: In[], transform: (item: In) => Out): Out[] {
  return items.map(transform)
}

const lengths = mapItems(["ok", "retry"], (s) => s.length)
// In = string, Out = number → lengths: number[]
```

## Constraints: `extends`

An unconstrained `T` could be *anything*, so inside the function you can do
almost nothing with it:

```ts
function describe<T>(value: T) {
  return value.name  // error: Property 'name' does not exist on type 'T'
}
```

TypeScript is right — `T` might be `number`. A **constraint** narrows what
callers may pass, which unlocks that shape inside the body:
`function describe<T extends { name: string }>(value: T)`.

Read it as "any T, as long as it *at least* has a string `name`". The win
over plain `value: { name: string }`: callers can pass richer objects, and
`T` remembers their **full** type.

## The lookup pattern (memorize this one)

The most useful constrained signature in TypeScript:

```ts
function getProp<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key]
}
```

- `keyof T` — the union of `T`'s property names (`"theme" | "fontSize"` below).
- `K extends keyof T` — the key must be one of those; typos become errors.
- `T[K]` — *indexed access*: "the type of that property".

```ts
const settings = { theme: "dark", fontSize: 14 }
getProp(settings, "theme")      // string
getProp(settings, "fontsize")   // error — not a key of settings
```

That's all you need today — lesson 07 goes deep on this whole family.

## Generic type aliases and interfaces

Types take parameters too — same angle brackets, same idea:

```ts
type ApiResponse<T> = { status: number; data: T }
type UserResponse = ApiResponse<{ id: string; name: string }>
```

Interfaces work identically: `interface PaginatedList<T> { items: T[] }`.
You've used these since lesson 01: `string[]` is sugar for `Array<string>`,
and every `async` function returns a `Promise<T>`.

## Default type parameters

Like default function parameters, a type parameter can have a fallback:

```ts
type PaginatedList<T = string> = { items: T[]; page: number }

type Tags = PaginatedList           // T defaults to string
type Scores = PaginatedList<number> // overridden
```

React's own type definitions lean on defaults heavily — you'll see them when
you `gd` into a hook in lesson 12, which also covers generic components.

## The mental model

**Generics are function parameters, one level up.**

| Runtime world | Type world |
|---|---|
| parameter `items` | type parameter `T` |
| argument `["a", "b"]` | type argument `<string>` |
| default `page = 1` | default `T = string` |
| runtime validation | constraint `T extends ...` |

A function abstracts over *values* it doesn't know yet; a generic abstracts
over *types*. Lesson 09 pushes this further — conditional types are `if`
statements over these same type parameters.

## Exercises

Open `exercises.ts` — broken on purpose, as always. Fix it top to bottom:

```
./check 06
npx tsx lessons/06-generics/exercises.ts
```

Stuck? `solution.ts` sits next door, with commentary.

## Key takeaways

- `<T>(items: T[]): T` links input to output; inference fills in `T` from
  the arguments — hover (`K`) to see what it chose.
- Explicit `<string>` when there's nothing to infer: empty inputs,
  return-only generics, `useState<User | null>(null)`.
- Constraints (`T extends { id: string }`) mean "at least this shape" — they
  unlock property access *and* keep the caller's full type.
- `<T, K extends keyof T>(obj: T, key: K): T[K]` — the lookup pattern.
- Types take parameters too: `ApiResponse<T>`, `PaginatedList<T = string>`.
- Generics are function parameters, one level up.
