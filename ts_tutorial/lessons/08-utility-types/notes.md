# Lesson 08 — Utility types: the type system's standard library

**Why this matters for React:** production React code rarely writes a type
twice — it *derives* the second one from the first. The edit-form payload is
`Partial<User>`. The API response is `Omit<User, "password">`. The props of a
custom button are `Omit<ComponentProps<"button">, "onClick">` — the single
most common pattern for wrapping native elements, and the backbone of lesson
11. This lesson is the toolbox those one-liners come from.

## A toolbox, not new machinery

Utility types are ordinary **generic types** — the exact thing you built in
lesson 06 — that happen to ship with TypeScript itself. `Partial<User>` is a
type-level function call: `Partial` is the function, `User` is the argument.

They aren't compiler magic, either. Every one is written in plain TypeScript
inside the compiler's own `lib.*.d.ts` files. In nvim, rest your cursor on
`Partial` and press `K` to see its definition, or `gd` to jump into it:

```ts
type Partial<T> = { [P in keyof T]?: T[P] }
```

That `[P in keyof T]` is a **mapped type** — built on the `keyof` you met in
lesson 07 — and it's lesson 09's headline feature. You don't need to read it
fluently yet: in lesson 09 you'll build `Partial`, `Pick`, and `ReturnType`
from scratch yourself. Today is vocabulary — knowing which tool does what,
so tomorrow's machinery has a purpose.

One running model for the whole lesson (object shapes: lesson 02):

```ts
type Role = "admin" | "editor" | "viewer"

type User = {
  id: number
  name: string
  email: string
  password: string
  role: Role
}
```

## Reshape objects — `Partial`, `Required`, `Readonly`, `Pick`, `Omit`

These five take an object type and hand back a modified copy:

| Utility | Effect |
|---|---|
| `Partial<T>` | every property becomes optional |
| `Required<T>` | every property becomes required (strips `?`) |
| `Readonly<T>` | every property becomes `readonly` |
| `Pick<T, K>` | keep only the properties named in `K` |
| `Omit<T, K>` | drop the properties named in `K`, keep the rest |

```ts
type UserPatch = Partial<User>
// { id?: number; name?: string; ... }   — the shape of an update payload

type PublicUser = Omit<User, "password">
// everything except password — what the API is allowed to send

type LoginForm = Pick<User, "email" | "password">
// just the slice one form needs
```

Two things to notice:

- `Pick` and `Omit` are duals: name the slice you keep, or the slice you
  drop — whichever list is shorter and *more stable*. An API response should
  `Omit` the secrets (new safe fields flow through automatically); a form
  should `Pick` its fields (new model fields don't silently leak in).
- These produce **new types**. `Partial<User>` no more changes `User` than
  `name.toUpperCase()` changes `name`.

## Build objects — `Record<K, V>`

`Record<K, V>` builds an object type with keys `K` and values `V`:

```ts
type Permission = "read" | "write" | "delete"

const rolePermissions: Record<Role, Permission[]> = {
  admin: ["read", "write", "delete"],
  editor: ["read", "write"],
  viewer: ["read"],
}
```

Compare an index signature (lesson 02): `{ [role: string]: Permission[] }`
accepts *any* string key — it can't catch a misspelled `"editer"`, and it
can't notice you forgot `viewer` entirely. `Record<Role, Permission[]>`
catches both, because its keys are the literal union `Role`: every member
must be present, and nothing else is allowed. Rule of thumb: **index
signature when the keys are genuinely open-ended, `Record` with a union
when you know them.** (`Record<string, V>` also exists and behaves like the
index signature — handy shorthand, no exhaustiveness.)

## Filter unions — `Exclude`, `Extract`, `NonNullable`

Where the reshape tools work on object *properties*, these work on union
*members* (unions and narrowing: lesson 04):

```ts
type Status = "idle" | "loading" | "success" | "error" | null

type Settled = Exclude<Status, "idle" | "loading" | null> // "success" | "error"
type Busy    = Extract<Status, "idle" | "loading">        // "idle" | "loading"
type Known   = NonNullable<Status>                        // everything but null/undefined
```

`Exclude` removes the members you name, `Extract` keeps only the members you
name, and `NonNullable<T>` is just `Exclude<T, null | undefined>` with a
better name.

## Extract from functions — `ReturnType`, `Parameters`

Lesson 07's theme was *derive types from values instead of duplicating
them*. These two extend that to functions, teaming up with `typeof`:

```ts
function buildSession(user: User, minutes: number) {
  return { user, token: "tok_1", expiresAt: Date.now() + minutes * 60_000 }
}

type Session = ReturnType<typeof buildSession>
// { user: User; token: string; expiresAt: number }

type SessionArgs = Parameters<typeof buildSession>
// [user: User, minutes: number] — a tuple, lesson 02
```

The implementation is the source of truth; the types follow it. When someone
adds a field to the returned object, `Session` updates itself — a
hand-written copy would silently drift out of date.

## Unwrap async — `Awaited`

`ReturnType` on an `async` function gives you a `Promise<...>` — accurate,
but rarely what you wanted. `Awaited<T>` unwraps it:

```ts
async function fetchProfile(id: number) {
  const res = await fetch(`/api/users/${id}`)
  return (await res.json()) as Omit<User, "password">
}

type FetchReturn = ReturnType<typeof fetchProfile>
// Promise<Omit<User, "password">>

type Profile = Awaited<ReturnType<typeof fetchProfile>>
// Omit<User, "password">  — what one awaited call actually gives you
```

That last line is the **"what does this API call resolve to?"** pattern.
You'll write it constantly in Next.js: the data type comes straight from the
fetching function, no duplicate interface anywhere. (`Awaited` even unwraps
nested promises — `Awaited<Promise<Promise<number>>>` is `number`.)

## The combos you'll actually write

The utilities compose — with each other and with lesson 07's `typeof`:

| Need | Write |
|---|---|
| update/PATCH payload | `Partial<User>` |
| API response without secrets | `Omit<User, "password">` |
| one form's slice of a model | `Pick<User, "email">` (add keys with a union) |
| lookup table with exhaustive keys | `Record<Role, Permission[]>` |
| what an async call resolves to | `Awaited<ReturnType<typeof fetchProfile>>` |
| wrapped `<button>`, minus a prop you own | `Omit<ComponentProps<"button">, "onClick">` |

That last row is the React payoff: "my component accepts everything a real
`<button>` does, except I control `onClick`". Lesson 11 builds on it for
real.

## Exercises

Open `exercises.ts`. This lesson lives **entirely at the type level** — no
`npx tsx` step this time, because there is nothing meaningful to run. The
compiler going quiet *is* the passing test:

```
./check 08
```

Every exercise is driven by `Expect<Equal<...>>` assertions, or by call
sites that error until you fix the type above them. As always: fix the code,
never the assertions. Hover (`K`) the intermediate types constantly — "what
did this utility actually produce?" is the whole game.

## Key takeaways

- Utility types are plain generic types that ship with TypeScript — `gd`
  into them today; lesson 09 teaches you to write them yourself.
- Reshape objects: `Partial`, `Required`, `Readonly`, `Pick`, `Omit` —
  `Pick`/`Omit` are duals; keep whichever list is shorter and more stable.
- Build objects: `Record<UnionOfKeys, V>` gives exhaustive, typo-proof keys;
  index signatures are for genuinely open-ended keys.
- Filter unions: `Exclude` (remove), `Extract` (keep), `NonNullable`.
- Derive from functions: `ReturnType<typeof fn>`, `Parameters<typeof fn>`,
  and `Awaited<ReturnType<typeof fn>>` for async — the code is the source
  of truth, so the types can't drift.
