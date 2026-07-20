# Lesson 02 — Object shapes, structural typing, and tuples

**Why this matters for React:** a component's props arrive as one object, and
you describe that object with the types in this lesson. Optional props are `?`
properties. "Never mutate state" is `readonly`. When you typo a prop name, the
error React throws at you is this lesson's excess-property check, word for
word. Even `useState` hands you a tuple. React's data model, minus the React.

## Describing an object

You can annotate a shape inline — `const ada: { name: string; age: number } =
{ … }` — but inline types can't be reused. Name the shape with a **`type` alias**:

```ts
type User = {
  name: string
  age: number
}

const ada: User = { name: "Ada", age: 36 }
```

An alias is *just a name*: `User` and the inline version are the identical
type. (`interface` also does this job; the differences wait for lesson 05.)

Two ways to break a shape, two different errors — learn to tell them apart:

```ts
const u1: User = { name: "Ada" }             // Property 'age' is missing …
const u2: User = { name: "Ada", age: "36" }  // 'string' is not assignable to 'number'
```

## Optional properties: `?`

A `?` after the property name means "may be absent":

```ts
type Profile = { username: string; displayName?: string }

const p1: Profile = { username: "ada" }   // fine — displayName may be absent
```

Here's the important half of the deal: an optional property **reads back as
`T | undefined`**. Hover `p1.displayName` — it's `string | undefined`, so code
that uses it must handle the missing case:
`p1.displayName ?? p1.username` hands you back a plain `string`.

Optional React props are declared exactly this way, and `string | undefined`
in an error message almost always traces back to a `?`. Lesson 04 brings the
full narrowing toolkit for the `undefined` half.

## `readonly` properties

`readonly` bans assignment after creation:

```ts
type Session = { readonly userId: number; page: string }

const session: Session = { userId: 42, page: "/home" }
session.page = "/settings"   // fine
session.userId = 99          // Cannot assign to 'userId' — read-only property
```

Like every type, `readonly` is erased at runtime — a compile-time promise,
not a lock. And it only restricts assignment *through that reference*;
building a **new** object is always allowed:

```ts
const next: Session = { ...session, userId: 99 }   // legal — new object
```

That spread-into-a-fresh-object move is precisely how React state updates
work (lesson 12); make it a reflex now.

## Structural typing: if it fits the shape, it fits

TypeScript compares **shapes, not names**. Nothing ever has to declare "I am
a `User`" — having the right properties is enough, extras included:

```ts
type HasName = { name: string }
const rex = { name: "Rex", legs: 4 }
const named: HasName = rex   // fine — rex has a name; `legs` is ignored
```

This is why any object with `label` and `onClick` can be passed where button
props are expected. Duck typing, but checked.

## Excess property checks: fresh literals get strict treatment

Now the twist. Do the same thing with an inline literal and it errors:

```ts
const named2: HasName = { name: "Rex", legs: 4 }
//     'legs' does not exist in type 'HasName' — same value, now an error!
```

When an object literal is written **fresh, right where the target
type is known**, TypeScript reasons: an extra property here can never be used
by anyone, so it's probably a typo — and flags it. An object passed via a
variable skips this check (as `rex` did above).

This is *exactly* the error for a typo'd React prop: write
`<Button colour="red" />` when the props say `color`, and you get this check —
usually with a helpful `Did you mean 'color'?` attached.

## Nested shapes

Object types nest: wherever a property's type goes, another object type can
go. Inline, or composed from named aliases — they're equivalent:

```ts
type Coordinates = { lat: number; lng: number }
type Venue = {
  name: string
  address: { city: string; coordinates: Coordinates }   // inline + named alias
}
```

Rule of thumb: name the pieces you'd reuse or talk about; inline the rest.

## Tuples: arrays with a fixed plan

`string[]` means "any number of strings". A **tuple** fixes the length *and*
gives each position its own type:

```ts
const entry: [string, number] = ["Ada", 36]
entry[0].toUpperCase()   // position 0 is a string — TS knows
entry[2]                 // error: no position 2
```

**The inference gotcha:** a bare array literal infers an *array*, never a
tuple — TypeScript assumes you might push and reorder:

```ts
const pair = ["Ada", 36]   // (string | number)[] — position info lost!
const [name, age] = pair   // both are string | number — not what you wanted
```

Annotate to keep the positions (lesson 07's `as const` is the other route).

Two refinements you'll meet in library types constantly:

```ts
type Rgb = readonly [red: number, green: number, blue: number]
```

- **Labels** (`red:`) are pure documentation — they change nothing about the
  type, but hovers and error messages become vastly more readable.
- **`readonly`** on a tuple bans `push`, `pop`, and assignment by index —
  the tuple you get is the tuple that stays.

Teaser: `const [count, setCount] = useState(0)` is a tuple return being
destructured — lesson 12 makes that precise.

## Exercises

Open `exercises.ts` — broken on purpose, as always. Fix it top to bottom,
then run it:

```
./check 02
npx tsx lessons/02-objects-and-tuples/exercises.ts
```

Stuck? `solution.ts` sits next door, with commentary. Next: lesson 03,
typing functions.

## Key takeaways

- A `type` alias names an object shape; the alias is the name, the shape is
  the type.
- `prop?: T` means "may be absent" — and reads back as `T | undefined`.
- `readonly` blocks reassignment through a reference; build a new object
  (spread!) instead of mutating.
- Structural typing: anything with the right shape fits, extras and all —
  *except* fresh object literals, which get the strict typo-catching check.
- Tuples fix length and per-position types; bare literals infer arrays, so
  annotate (or later, `as const`). Labels are free documentation.
