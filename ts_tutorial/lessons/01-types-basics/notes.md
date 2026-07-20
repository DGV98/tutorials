# Lesson 01 — Types, inference, and the basic building blocks

**Why this matters for React:** every prop, every piece of state, every event
handler in a React + TypeScript codebase is built out of the primitives in
this lesson. When an error message says `Type 'string | undefined' is not
assignable to type 'string'`, this lesson is what lets you read that sentence.

## What TypeScript actually is

TypeScript is JavaScript plus a *static type system*. The types exist only
while you're editing and compiling — they are **erased** before the code runs.
Two consequences:

1. Types can never change what your program does at runtime. They only
   describe it.
2. The compiler (`tsc`) is a *checker*, not (for us) a build tool. This
   project never emits JS; we run files directly with `tsx` and use `tsc`
   purely to find mistakes.

## The workflow in nvim

Open this lesson's `exercises.ts`. Your LSP (vtsls) shows type errors as
diagnostics. Your loop is:

1. Read the exercise comment.
2. Fix the code until the diagnostics on that exercise disappear.
3. `./check 01` from the project root confirms the whole lesson is clean
   (or `./check 01 --watch` in a split terminal to re-check on save).

Two keybindings will teach you more than any book:

- **`K` (hover)** on any variable shows you the type TypeScript has inferred.
  Use it constantly — "what does the compiler think this is?" is the core
  skill.
- **`gd` (go to definition)** on any type jumps to where it's defined — even
  into React's own type definitions.

## Primitives and annotations

The basic types mirror JavaScript's values:

```ts
let name: string = "Ada"
let age: number = 36        // no int/float distinction — just number
let isAdmin: boolean = false
let nothing: null = null
let missing: undefined = undefined
```

The `: string` part is a **type annotation**. Once a variable has a type,
assigning anything else is an error:

```ts
let city: string = "Berlin"
city = 42
//   ^ Type 'number' is not assignable to type 'string'
```

## Inference: annotations are usually unnecessary

TypeScript infers types from values, so idiomatic TS annotates far less than
you'd expect:

```ts
let name = "Ada"      // inferred as string — hover it!
let age = 36          // inferred as number
```

Rule of thumb: **let inference do the work; annotate when inference can't
know** (empty arrays, function parameters, values that arrive later).

## `const` infers something narrower

```ts
let mood = "happy"     // type: string        (could be reassigned)
const greeting = "hi"  // type: "hi"          (can never be anything else)
```

`"hi"` is a **literal type** — a type with exactly one value. This looks like
trivia now, but literal types power most advanced React prop patterns
(`variant: "primary" | "secondary"` is literal types at work). Lesson 04
builds on this heavily.

## Arrays

```ts
const scores: number[] = [90, 82, 77]
const names: string[] = []          // annotation needed: empty array says nothing
const flags = [true, false]         // inferred as boolean[]
```

`string[]` means "array of strings, any length". (Fixed-length arrays —
tuples — come in lesson 02.)

## `any`: the off switch

A value of type `any` turns the checker off for everything it touches:

```ts
let data: any = JSON.parse('{"whatever": true}')
data.does.not.exist()   // compiles fine, explodes at runtime
```

`any` isn't a type, it's the absence of checking — and it spreads through
whatever it touches. You'll see it in error messages and legacy code. The
disciplined alternative, `unknown`, gets proper treatment in lesson 10; for
now the rule is simply: **don't write `any` in these lessons.**

## Reading error messages

TypeScript errors read backwards from how you might expect. In

```
Type 'number' is not assignable to type 'string'
```

the FIRST type is what you *provided*, the SECOND is what was *required*.
Train yourself to read it as: "you gave me a number where a string belongs."

## Exercises

Open `exercises.ts` — it has errors right now, on purpose. Fix them all,
then run the file to see the runtime checks pass:

```
./check 01
npx tsx lessons/01-types-basics/exercises.ts
```

Stuck? `solution.ts` sits next door, with commentary.

## Key takeaways

- Types are compile-time only; they're erased before the code runs.
- Prefer inference; annotate when TypeScript can't know.
- `const` on a primitive infers a literal type like `"hi"` — remember this.
- `error: X is not assignable to Y` = "you gave X where Y belongs".
- Hover (`K`) is how you ask TypeScript what it's thinking.
