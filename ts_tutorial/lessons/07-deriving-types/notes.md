# Lesson 07 — Deriving types: `typeof`, `keyof`, indexed access, `as const`, `satisfies`

**Why this matters for React:** real React apps are full of config objects —
a theme, a routes table, a map of button variants to class names. The
professional move is to write that object **once** and *derive* the types
from it: `variant: keyof typeof BUTTON_VARIANTS`. Add one entry to the
object and every component's props update themselves. This lesson is that
toolbox, and it's the biggest "oh, THAT'S how libraries do it" moment in
the course.

## One source of truth

The cardinal sin this lesson cures: maintaining a value AND a type that
describe the same thing.

```ts
const STATUSES = ["draft", "published", "archived"]        // the value
type Status = "draft" | "published"                        // the type — DRIFTED
```

Someone added `"archived"` to the array and forgot the type. The compiler
can't help, because nothing connects them. The fix is never "be more
careful" — it's to write the value once and **derive** the type from it,
with the tools below.

## `typeof` — the type-level one

You met `typeof` in lesson 01 as a *runtime* operator that returns a string.
TypeScript reuses the keyword in *type position* to mean something much more
powerful: "the type TypeScript inferred for this value".

```ts
const user = { name: "Ada", loggedIn: true }

const kind = typeof user   // runtime: the string "object"
type User = typeof user    // type-level: { name: string; loggedIn: boolean }
```

Same keyword, different world. Position decides which one you get: in an
expression it's the runtime operator; after `type X =` or a `:` it's the
type query. Hover `User` — the whole shape, never typed by hand.

## `keyof` — a union of an object type's keys

```ts
type User = { name: string; loggedIn: boolean }
type UserKey = keyof User   // "name" | "loggedIn"
```

`keyof` produces a **union of literal types** (lesson 01's literal types,
scaled up). You already brushed against it in lesson 06's constraints —
`<T, K extends keyof T>` is what made `get(obj, key)` safe. Combined with
`typeof`, it reads keys straight off a value:

```ts
const httpConfig = { baseUrl: "https://api.dev", retries: 3 }
type ConfigKey = keyof typeof httpConfig   // "baseUrl" | "retries"
```

Read it inside-out: `typeof` gets the object type, `keyof` gets its keys.

## Indexed access — `T["key"]`, `T[keyof T]`, `T[number]`

Types have a bracket syntax too. It looks like property access, but the
thing inside the brackets is a **type**:

```ts
type Config = { baseUrl: string; retries: number }

type Retries = Config["retries"]      // number  — one property's type
type Value   = Config[keyof Config]   // string | number — ALL values, as a union
```

Indexing with a union indexes with every member and unions the results —
that's why `T[keyof T]` gives you "the union of all the value types".
Arrays and tuples index with `number` — `Names[number]` on `type Names =
string[]` is just `string` ("the element type"). Boring there, but on a
tuple of literals `T[number]` is a union machine — which is where
`as const` comes in.

## `as const` — freeze it, and infer the narrowest type

Lesson 01 showed `const greeting = "hi"` inferring the literal `"hi"`. But
object properties and array elements still widen, because they're mutable:

```ts
const COLORS = ["red", "green", "blue"]            // string[]      (widened)
const FROZEN = ["red", "green", "blue"] as const   // readonly ["red", "green", "blue"]
```

`as const` tells TypeScript: this value will never be mutated, so infer the
narrowest possible type — literal types, all the way down (it's deep), and
`readonly` everywhere. Now `T[number]` pays off:

```ts
type Color = (typeof FROZEN)[number]   // "red" | "green" | "blue"
```

That `(typeof ARRAY)[number]` pattern — const array in, union out — is one
you will write constantly. (The parentheses aren't strictly required, but
they make the pattern much easier to read.) The same trick derives a union
from a const object's **values**:

```ts
const LABELS = { draft: "Draft", published: "Published" } as const

type Status = keyof typeof LABELS                    // "draft" | "published"
type Label  = (typeof LABELS)[keyof typeof LABELS]   // "Draft" | "Published"
```

## `satisfies` — validate without widening

Suppose ROUTES must be an object of strings. Your three options:

```ts
// 1. Annotation: validates, but WIDENS. TypeScript now believes the type IS
//    Record<string, string> — the actual keys are forgotten.
const routes1: Record<string, string> = { home: "/", about: "/about" }
type K1 = keyof typeof routes1   // string — the keys are gone

// 2. `as const` alone: narrows beautifully, but VALIDATES NOTHING.
const routes2 = { home: "/", about: 42 } as const   // the 42 compiles fine

// 3. `satisfies`: checks the value against the type, then KEEPS the
//    inferred type. Validation without amnesia.
const routes3 = { home: "/", about: "/about" } satisfies Record<string, string>
type K3 = keyof typeof routes3   // "home" | "about"
```

(`Record<string, string>` is a built-in meaning "object with string keys and
string values" — lesson 08 tours the whole utility-type toolbox.)

And they compose. For "literal values, deeply readonly, AND checked":

```ts
const THEME = {
  primary: "#4f46e5",
  danger: "#ef4444",
} as const satisfies Record<string, string>
```

Now a typo like `danger: 0xef4444` errors on the spot, and
`(typeof THEME)[keyof typeof THEME]` is still `"#4f46e5" | "#ef4444"`.

## The React payoff

```ts
const BUTTON_VARIANTS = {
  primary:   "bg-indigo-600 text-white",
  secondary: "bg-gray-200 text-gray-900",
  danger:    "bg-red-600 text-white",
} as const satisfies Record<string, string>

type ButtonProps = {
  variant: keyof typeof BUTTON_VARIANTS   // "primary" | "secondary" | "danger"
  label: string
}
```

Add a `ghost` variant to the object and `variant="ghost"` starts compiling
everywhere; misspell `varient="primry"` and the compiler catches both. One
edit, zero drift. Lesson 09 goes further — mapped types transform these
derived unions into whole new object types.

## Exercises

Open `exercises.ts` — every exercise is a value/type pair that has drifted.
Replace hand-written types with derived ones until the checker is silent:

```
./check 07
npx tsx lessons/07-deriving-types/exercises.ts
```

Stuck? `solution.ts` sits next door, with commentary.

## Key takeaways

- Never maintain a type and a value that can drift — write the value once,
  derive the type.
- `typeof` in type position asks "what type did you infer for this value?" —
  same keyword as runtime `typeof`, entirely different world.
- `keyof T` = union of keys; `T["key"]` = one value type; `T[keyof T]` =
  union of all value types; `T[number]` = an array/tuple's element type.
- `as const` = deep readonly + narrowest literal inference. It's what makes
  `(typeof COLORS)[number]` produce a union instead of `string`.
- Annotation validates but widens; `as const` narrows but validates nothing;
  `satisfies` validates AND keeps the narrow inferred type. Combine them:
  `as const satisfies Record<string, ...>`.
