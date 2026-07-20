# Lesson 03 — Functions: parameters, returns, callbacks, `void`, and `never`

**Why this matters for React:** a React app is functions all the way down —
components are functions, and half the props you'll ever type are callbacks:
`onClick`, `onChange`, `onSelect`. Their types are function type expressions
like `(e: MouseEvent) => void`, and that `void` follows a special rule that
explains why `onClick={() => savePromise()}` compiles even though the arrow
returns a Promise. Lessons 11–12 stand on this lesson.

## Parameters must be annotated

Lesson 01's rule was "let inference do the work" — but inference needs a
value to look at, and a parameter *has no value yet*: nobody has called the
function. So under strict mode (specifically `noImplicitAny`), un-annotated
parameters are an error:

```ts
function repeat(text, times) {
  //            ^ Parameter 'text' implicitly has an 'any' type.
  return text.repeat(times)
}
function repeat(text: string, times: number) { /* ✓ */ }
```

This is the annotation you'll write most often, by far. The habit: **every
parameter of a function declaration gets a type.** (Inline callbacks are the
one exception — see contextual typing below.)

## Return types: inferred, but sometimes worth writing

TypeScript infers the return type from the `return` statements — hover the
function name and it's right there:

```ts
function add(a: number, b: number) {
  return a + b     // hover add: (a: number, b: number) => number
}
```

Inference is fine for local helpers. An annotation earns its keep at
**public API boundaries** (a contract the compiler holds the body to) and
for **catching mistakes at the source**: without it, a wrong return just
*widens* the inferred type and the errors erupt at every call site. With
it, the error lands on the guilty line itself:

```ts
function describeScore(score: number): string {
  if (score >= 90) return "excellent"
  return score
  //     ^ Type 'number' is not assignable to type 'string' — HERE,
  //       not at twelve call sites across the codebase
}
```

## Optional and default parameters

```ts
function greet(name: string, punctuation?: string) {
  // inside, punctuation is  string | undefined  — hover it!
  return `Hello, ${name}${punctuation ?? "."}`
}
function greet2(name: string, punctuation = ".") {
  // a default makes the param optional AND infers its type; inside
  // the body it's plain string, never undefined
  return `Hello, ${name}${punctuation}`
}
```

Three rules: optional parameters come **after** required ones; `?` means
`T | undefined` inside the body (handling that union is lesson 04's whole
topic); a default value makes a param optional *without* the `undefined`.
Same `?` you met on object properties in lesson 02, new position.

## Rest parameters

```ts
function sum(...values: number[]) {
  return values.reduce((acc, n) => acc + n, 0)
}
sum(1, 2, 3)      // any number of arguments — including none: sum()
```

A rest parameter gathers the remaining arguments into a real array, so its
annotation must be an array type (or a tuple, from lesson 02).

## Function type expressions

A whole function has a type too, written almost like an arrow function:

```ts
type IdCallback = (id: string) => void

function forEachUser(ids: string[], callback: IdCallback) {
  for (const id of ids) callback(id)
}
```

The parameter *name* in the type (`id`) is documentation only — only
position and type matter for compatibility. This shape is exactly what
React prop types look like: `onSelect: (id: string) => void` as a property
in a props object (lesson 02's shapes + these types = lesson 11).

## Contextual typing — why callbacks need no annotations

The "annotate every parameter" rule has one big exception:

```ts
const names = ["ada", "grace", "barbara"]
const upper = names.map((name) => name.toUpperCase())
//                       ^ no annotation, yet: string. Hover it!
```

`map` on a `string[]` *declares* that its callback receives a `string`, so
TypeScript flows that type into `name` from the outside in. That's
**contextual typing**: a function expression sitting where a known function
type is expected gets its parameter types for free — it's why
`onChange={(e) => ...}` in React needs no annotation on `e`. (How `map`
declares that expectation generically is lesson 06.)

## `void` — and its famous quirk

`void` is the return type of functions that return nothing usable —
`function logEvent(name: string): void { console.log(name) }`.

Now the quirk. In a function **type**, `=> void` does *not* mean "must
return nothing" — it means "**whatever this returns will be ignored**":

```ts
type OnClick = () => void
const handler: OnClick = () => fetch("/api/save")   // Promise — ALLOWED
```

This is deliberate: without it, `numbers.forEach((n) => results.push(n))`
would error, since `push` returns a number. Same story in React:
`onClick={() => savePromise()}` compiles because onClick's `=> void` shrugs
at the Promise. The catch: through a `void` type the return value is
*unusable* — and writing `: void` on your **own** function body is stricter
(`return someValue` inside it is an error).

## `never` — functions that do not return, period

```ts
function crash(message: string): never {
  throw new Error(message)
}
```

Keep the two "nothing" types straight: **`void` returns, carrying nothing;
`never` never returns at all** (it throws, or loops forever). Write `never`
explicitly, for two reasons: a function *declaration* that only throws
still infers `void` — a lie — and control flow analysis only treats a call
as ending the code path when the callee is explicitly annotated `: never`.
With the annotation, code after `crash(...)` is provably unreachable, so a
`: boolean` function can end on a `crash(...)` line without a final
`return`. `never` returns in lesson 04 with a bigger role: it's the type of
"no union members left", which powers exhaustiveness checking.

## Exercises

Open `exercises.ts` — seven exercises, all broken on purpose. Fix them,
then run the file:

```
./check 03
npx tsx lessons/03-functions/exercises.ts
```

Stuck? `solution.ts` sits next door, with commentary.

## Key takeaways

- Parameters always need annotations — there's no value to infer from.
- Returns are inferred; annotate them at API boundaries and to catch bugs
  at the source instead of at call sites.
- `?` makes a param optional and `undefined` possible inside; a default
  value makes it optional without the `undefined`.
- Rest params (`...values: number[]`) are always array types.
- `(id: string) => void` is a function type expression — the shape of every
  callback prop in React. Inline callbacks skip annotations thanks to
  contextual typing.
- A `=> void` function type IGNORES return values, it doesn't forbid them.
- `void` = returns nothing; `never` = never returns. Annotate `never`
  explicitly — inference won't do it for declarations.
