# Lesson 04 — Unions, narrowing, and discriminated unions

**Why this matters for React:** every data fetch in every React app is in
exactly one of a few states — idle, loading, success, error — and the single
most useful typing pattern in React is modelling that as a *union* so the
compiler forces you to handle every state before touching the data. Variant
props (`variant: "primary" | "secondary"`) are unions too. Nothing else in
this course will show up in your React code as often as this lesson.

## Union types: this OR that

A union type says a value is one of several types:

```ts
function describeId(id: string | number) { ... }
```

Inside the function, `id` might be *either* — so TypeScript only lets you use
members that exist on **every** branch of the union:

```ts
id.toString()     // fine: exists on string AND number
id.toUpperCase()  // error: Property 'toUpperCase' does not exist on
                  //        type 'string | number'
```

This is the union bargain: you get flexibility at the call site, and in
exchange you must *prove* which branch you're holding before using
branch-specific members. That proof is called **narrowing**.

## Literal unions: the React variant pattern

Lesson 01 introduced literal types (`const greeting = "hi"` has type `"hi"`).
A union of literals is how you type "one of these exact values":

```ts
type ButtonVariant = "primary" | "secondary" | "danger"

function buttonClass(variant: ButtonVariant) {
  return `btn-${variant}`
}

buttonClass("primary")  // ✓
buttonClass("primry")   // error — typos become compile errors
```

This is *exactly* how React component props like `variant`, `size`, and
`align` are typed. One gotcha from lesson 01 comes back to bite here:

```ts
let chosen = "primary"      // let widens: type is string
buttonClass(chosen)         // error! string isn't a ButtonVariant
const picked = "primary"    // const keeps the literal: type is "primary"
buttonClass(picked)         // ✓
```

## Narrowing: teaching the compiler what you know

Narrowing is any check that eliminates union branches. TypeScript understands
ordinary JavaScript:

```ts
// typeof — for primitives
if (typeof id === "string") { id.toUpperCase() }   // id: string here

// equality — great for null/undefined and literals
if (name === null) { return "anonymous" }           // name: string after

// the `in` operator — for object shapes
if ("email" in contact) { contact.email }           // narrows by property

// instanceof — for class instances (typeof only sees primitives)
if (err instanceof Error) { err.message }
```

**Truthiness works too — but carries a trap.** `if (value)` eliminates
`null` and `undefined`, but it *also* treats `""` and `0` as false:

```ts
function formatCount(count: number | null) {
  if (!count) return "no data"   // ← 0 lands here too. Bug!
  return `${count} items`
}
```

A count of zero is real data. When falsy values are valid, compare
explicitly: `if (count === null)`.

## Control-flow analysis

TypeScript tracks narrowing through your program's control flow — if/else
branches, early returns, even assignments. The same variable can have
different types on different lines:

```ts
function head(items: string[] | null): string {
  if (items === null) return "(empty)"
  // the early return eliminated null — from here down:
  return items[0] ?? "(empty)"   // items: string[]
}
```

Hover (`K`) the same variable above and below a check and watch the type
change. This is the compiler reading your code the way you do.

## `null` and `undefined` under strict mode

This project has `strict` on, which includes `strictNullChecks`: `null` and
`undefined` are **not** assignable to other types. A `string | null` must be
narrowed before use — which is precisely what makes unions honest:

```ts
function shout(name: string | null) {
  name.toUpperCase()            // error: 'name' is possibly 'null'
  if (name !== null) {
    name.toUpperCase()          // ✓
  }
  const safe = name ?? "guest"  // ?? provides a default; safe: string
}
```

Optional things (`function f(x?: number)`, optional props in lesson 02)
are just `T | undefined` unions — same rules, same narrowing.

## Discriminated unions: the state machine pattern

Object unions get their superpower from a shared **literal** field — the
*discriminant*. Here is the fetch state machine you will write in every
React app:

```ts
type FetchState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: string[] }
  | { status: "error"; message: string }
```

Checking the discriminant narrows the **whole object**:

```ts
function render(state: FetchState) {
  if (state.status === "success") {
    return state.data.join(", ")   // data exists — compiler agrees
  }
  return "..."                     // here, data does NOT exist. Also correct!
}
```

Compare with the tempting-but-wrong flat shape
`{ loading: boolean; data?: string[]; error?: string }` — that type happily
represents nonsense like "loading AND errored with data". The union makes
impossible states *unrepresentable*. Lesson 12 uses exactly this shape for
`useReducer` actions.

## Exhaustiveness: `switch` + `never`

Lesson 03 introduced `never`, the type with no values. It powers a pattern
that turns "I forgot a case" into a compile error:

```ts
function label(state: FetchState): string {
  switch (state.status) {
    case "idle":    return "—"
    case "loading": return "…"
    case "success": return `${state.data.length} rows`
    case "error":   return state.message
    default: {
      const unhandled: never = state   // all cases handled → state is never
      return unhandled
    }
  }
}
```

Every handled case is eliminated, so in `default` the type of `state` is
`never` and the assignment compiles. Now add a `{ status: "refreshing" }`
variant to `FetchState`: the `default` block errors — *at the exact line
where code must change*. That is exhaustiveness checking: the compiler
maintains your to-do list when types evolve.

(Lesson 10 extends today's toolkit with `unknown` and *type predicates* —
functions you write that narrow for you at API boundaries.)

## Exercises

Open `exercises.ts` — every exercise currently has at least one type error.
Fix them all, then run the file to watch the runtime checks pass:

```
./check 04
npx tsx lessons/04-unions-and-narrowing/exercises.ts
```

Stuck? `solution.ts` sits next door, with commentary.

## Key takeaways

- `A | B` means "one of these" — only members common to *all* branches are
  usable until you narrow.
- Literal unions (`"primary" | "secondary"`) are how React variant props
  work; remember `let` widens literals to `string`.
- Narrow with `typeof`, `===`, `in`, and `instanceof` — plain JavaScript
  the compiler can follow.
- Truthiness narrowing swallows `""` and `0`; compare against `null`
  explicitly when falsy values are legitimate.
- Discriminated unions (shared literal `status`/`kind` field) make
  impossible states unrepresentable — THE pattern for fetch state and
  reducer actions.
- A `never`-typed `default` makes a `switch` exhaustive: new variants
  produce errors exactly where code must change.
