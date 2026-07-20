# Lesson 09 — Mapped types, conditional types, `infer`, and template literals

**Why this matters for React:** this is the machinery *underneath* React's
types. Lesson 08's `Partial`, `ReturnType`, and `Awaited` are not compiler
magic — each is a one-liner in the constructs below, and so is half of
`@types/react`: `ComponentProps` extracts prop types with `infer`; handler
props follow the `on${EventName}` shape template literal types describe.
After this lesson, `gd` into a library's types stops being scary.

Fair warning: this is the workout lesson the README promised, the hardest
in the course. But nothing here is magic — it's all assembled from
**generics** (lesson 06) and **`keyof` + indexed access** (lesson 07).
One section at a time; each builds on the last.

## Mapped types: a loop over keys

A mapped type builds a new object type by looping over the keys of an
existing one:

```ts
type Flags = { darkMode: boolean; beta: boolean }

type Nullable<T> = {
  [K in keyof T]: T[K] | null
}

type DraftFlags = Nullable<Flags>
// { darkMode: boolean | null; beta: boolean | null }
```

Read `[K in keyof T]` as `for (const K of keyof T)`: on each pass, `K` is
one key (`"darkMode"`, then `"beta"`) and `T[K]` — indexed access from
lesson 07 — is that key's value type. The identity map
`{ [K in keyof T]: T[K] }` just clones `T`; every mapped type tweaks one
thing in that clone: the value (above), the modifiers (next), or the key
itself (`as`, later).

## Mapping modifiers: `?` and `readonly`

Inside a mapped type you can add or remove the two property modifiers.
`+` adds, `-` removes, and a bare modifier means `+`:

```ts
type MyPartial<T> = { [K in keyof T]?: T[K] }           // add ? (same as +?)
type MyRequired<T> = { [K in keyof T]-?: T[K] }         // strip ?
type MyReadonly<T> = { readonly [K in keyof T]: T[K] }  // add readonly
```

Now the reveal: **these ARE lesson 08's `Partial`, `Required`, and
`Readonly`** — near character-for-character (`gd` on `Partial` and compare).
One nicety for free: mapping over `keyof T` preserves each property's
existing modifiers unless you explicitly change them, so `Partial` never
accidentally strips a `readonly`. (Docs call this *homomorphic*; the word
just means "maps over `keyof T`, keeps modifiers".)

## Mapping over a literal union

The union after `in` doesn't have to come from `keyof` — any union of keys
works:

```ts
type Env = "dev" | "staging" | "prod"

type UrlMap = { [E in Env]: string }
// { dev: string; staging: string; prod: string }
```

Generalize both parts and you've rebuilt another lesson 08 utility:

```ts
type MyRecord<K extends PropertyKey, V> = { [P in K]: V }
```

(`PropertyKey` is a built-in alias for `string | number | symbol`.)

## Conditional types: `if` for types

`T extends U ? X : Y` asks "is `T` assignable to `U`?" and picks a branch —
lesson 06's constraint `extends`, wearing JavaScript's ternary syntax:

```ts
type IsString<T> = T extends string ? true : false

type A = IsString<"hello">   // true   (IsString<42> would be false)
```

## Distribution: conditionals run once per union member

The behavior that makes conditionals powerful *and* surprising: when the
checked type is a **naked type parameter** (plain `T`, not `T[]` or `[T]`)
instantiated with a union, it runs once per member and unions the results:

```ts
type MyExclude<T, U> = T extends U ? never : T

type Metal = MyExclude<"gold" | "silver" | "copper", "gold" | "silver">
// "copper"
```

Trace it: `"gold"` matches → `never`; `"silver"` → `never`; `"copper"`
survives. And `never` — the empty type from lesson 03 — simply vanishes from
a union. Result: `"copper"`. That's lesson 08's `Exclude`, in one line.

Distribution isn't always what you want — sometimes the question is about
the union *as one unit*. Wrapping both sides in a one-element tuple turns
distribution off, because `[T]` isn't naked:

```ts
type Loose<T> = T extends string ? true : false
type Huh = Loose<"a" | 1>      // boolean — i.e. true | false. Not helpful!

type Strict<T> = [T] extends [string] ? true : false
type Better = Strict<"a" | 1>  // false — tested as one unit
```

## `infer`: capture part of a matched shape

`infer` upgrades `extends` from a yes/no question to destructuring: "if `T`
matches this shape, *name* the missing piece so I can use it."

```ts
type ElementOf<T> = T extends (infer E)[] ? E : never

type S = ElementOf<string[]>   // string  (ElementOf<number> would be never)
```

The same move against a function type rebuilds `ReturnType`:

```ts
type MyReturnType<F> = F extends (...args: never[]) => infer R ? R : never
```

(Why `never[]`? The built-in writes `(...args: any) => infer R`, but this
course bans `any`; parameters check contravariantly and `never` is
assignable to everything, so `(...args: never[]) =>` matches any function.)

And against `Promise`, one level of lesson 08's `Awaited`:

```ts
type MyAwaited<T> = T extends Promise<infer V> ? V : T
```

The `: T` branch lets non-promises pass through untouched; the real
`Awaited` recurses so nested promises unwrap all the way down.

## Template literal types

Backtick syntax works in type position, and union placeholders expand to
every combination:

```ts
type Size = "sm" | "md" | "lg"
type Tone = "primary" | "danger"
type ButtonClass = `${Size}-${Tone}`
// "sm-primary" | "sm-danger" | "md-primary" | ... | "lg-danger"  (all six)
```

Three sizes × two tones = a six-member union, for free. TypeScript also
ships four intrinsic string helpers — `Uppercase`, `Lowercase`,
`Capitalize`, `Uncapitalize` — and `` `on${Capitalize<"click">}` `` is
`"onClick"`: the exact shape of React's event props.

## Key remapping: `as` renames keys mid-loop

The final piece: `as` renames each key mid-loop, template literal in hand.

```ts
type Getters<T> = {
  [K in keyof T as `get${Capitalize<K & string>}`]: () => T[K]
}

type User = { name: string; age: number }
type UserGetters = Getters<User>
// { getName: () => string; getAge: () => number }
```

`K & string` is needed because `keyof T` can include `number | symbol`
while `Capitalize` only accepts strings — the intersection keeps the string
keys and satisfies the checker. Bonus fact: remapping a key to `never`
*deletes* it — that's how `Omit` can be one mapped type; try it after the
course.

## Exercises

This lesson is type-level only: nothing to run, no runtime checks. Open
`exercises.ts` and replace each `unknown // ← replace` with a real
implementation — the `Expect<Equal<...>>` lines are your test suite, and
the compiler going quiet is the pass condition:

```
./check 09
```

Build each type in small steps and hover the intermediates (`K` on
everything). If an exercise fights you for more than fifteen minutes, read
the solution, then re-do it from a blank line — peeking is studying.

## Key takeaways

- A mapped type is a loop over keys: `{ [K in keyof T]: ...T[K]... }`.
- `+`/`-` on `?` and `readonly` add/strip modifiers — `Partial`, `Required`,
  and `Readonly` are exactly these three one-liners.
- `[P in SomeUnion]` maps over key unions not from `keyof` — that's `Record`.
- `T extends U ? X : Y` is a type-level `if`. Over a naked type parameter it
  **distributes** per union member; `[T] extends [U]` turns that off.
- `infer` captures part of a matched shape — it powers `ReturnType`/`Awaited`.
- Template literal types cross-product string unions; with `as` +
  `Capitalize` they remap keys (the `on${Key}Change` handler pattern).
- This is the dialect library types are written in. The "easy" tier of
  type-challenges (see the README's after-course list) is your gym now.
