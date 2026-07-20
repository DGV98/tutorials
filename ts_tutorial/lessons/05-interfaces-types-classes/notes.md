# Lesson 05 — Interfaces, type aliases, and classes (where they matter)

**Why this matters for React:** every props type you'll write is a `type`
alias or an `interface` — choosing between them is the first style decision
in any React codebase. Intersections (`&`) say "these props, plus everything
a `<button>` accepts." Your components will be functions, but classes still
count: custom `Error` subclasses, and the library classes you'll `gd` into.

## Two ways to name an object shape

Lesson 02 named object shapes with `type` aliases. `interface` is the second
syntax for the same job:

```ts
type TrackT = { title: string; durationSec: number }
interface TrackI { title: string; durationSec: number }
```

For plain object shapes these are interchangeable — structural typing
(lesson 02) only cares that the properties line up.

## `extends`: building shapes on shapes

An interface can extend another, inheriting all its members:

```ts
interface Album { title: string; artist: string }

interface StudioAlbum extends Album {
  label: string
}
// StudioAlbum = { title, artist, label } — and since it has everything an
// Album has, any function accepting an Album accepts a StudioAlbum.
```

## Intersections: `&` on type aliases

Type aliases combine shapes with `&`, which means "both at once":

```ts
type User = { id: string; displayName: string }
type Permissions = { canBan: boolean }
type AdminUser = User & Permissions   // { id, displayName, canBan }
```

## Interface vs type — the honest comparison

Things only `type` can do (plus lessons 08–09's mapped/conditional types):

```ts
type Status = "idle" | "loading" | "error"   // unions
type Id = string                             // primitive aliases
type Point = [number, number]                // tuples
```

Things only `interface` does:

```ts
interface Flags { darkMode: boolean }
interface Flags { betaBanner: boolean }
// legal! The two declarations MERGE into one interface with both fields.
```

**Declaration merging** is how libraries let you augment their types (adding
a field to Express's `Request`, say) — powerful there, a silent surprise in
app code. Interfaces also give clearer errors: an incompatible `extends`
fails loudly at the declaration; a conflicting `&` doesn't (next section).

House guidance: **either is fine for object shapes — pick one per codebase
and be consistent.** React codebases commonly use `type` for props (prop
unions like `variant` push you toward `type` anyway). This course uses both.

## When intersections conflict: the `never` trap

`&` never errors at the declaration. When shapes disagree, the conflicting
member becomes `never` — a type with no possible values:

```ts
type A = { id: string }
type B = { id: number }
type Both = A & B   // compiles fine! But Both["id"] is string & number =
                    // never. No object can satisfy Both; assigning one errors.
```

Compare `interface C extends A { id: number }` — that errors immediately, at
the declaration, naming both types. That's the "clearer errors" point above.

## Classes in two minutes

TypeScript classes are JavaScript classes plus annotations and a few keywords:

```ts
class Playlist {
  private tracks: string[] = []      // property annotation + initializer

  constructor(
    public readonly id: string,      // "parameter properties": declare the
    public name: string,             // property AND assign it, in one place
  ) {}

  add(track: string): void {
    this.tracks.push(track)
  }
}
```

- **`private`** — only class-internal code may touch it. **`readonly`** — set
  once, never reassigned. Strict mode also insists every property gets
  initialized (in the declaration or the constructor).
- **Parameter properties** — `public readonly id: string` in the parameter
  list replaces the declare-then-`this.id = id` boilerplate.

## A class declares a type, too

`class Playlist` creates **two** things — the runtime constructor, and a
type named `Playlist` describing its instances:

```ts
const p = new Playlist("pl-1", "Focus")        // typeof p is Playlist
function describe(list: Playlist) { /* … */ }  // class name as a type
```

## `implements`, and `instanceof` narrowing

`implements` checks a class against an interface — it adds nothing, only
verifies the class keeps its promise:

```ts
interface WithStatus { status: number }

class HttpError extends Error implements WithStatus {
  constructor(message: string, public readonly status: number) {
    super(message)
  }
}
```

And because classes exist at runtime, they narrow — lesson 04's narrowing
with a new guard:

```ts
function report(err: Error) {
  if (err instanceof HttpError) err.status  // narrowed: Error → HttpError
}
```

You can't `instanceof` an interface or type alias — those are erased before
runtime. That asymmetry is most of why classes survive in modern TS.

## Do you even need classes in a React world?

Mostly, no. Components are functions; state and API data are plain objects
transformed by plain functions. Classes earn their place in two spots:

1. **Custom `Error` subclasses** — an `HttpError` whose `status` you
   `instanceof` out of a `catch` beats string matching, especially in
   Next.js route handlers and server actions.
2. **Library objects** — `URL`, `Date`, `Map`, `Response`, SDK clients:
   you consume these constantly, and now you can read their types.

If you're reaching for a class to *hold data*, plain objects win.

## Exercises

Open `exercises.ts` — broken on purpose. Fix every exercise, then run it:

```
./check 05
npx tsx lessons/05-interfaces-types-classes/exercises.ts
```

Stuck? `solution.ts` sits next door, with commentary.

## Key takeaways

- `interface` and `type` are interchangeable for object shapes — pick one per
  codebase; React codebases commonly use `type` for props.
- Only `type` does unions, primitives, tuples; only `interface` merges
  declarations (great for library augmentation, surprising in app code).
- `extends` errors loudly at the declaration; a conflicting `&` silently
  makes `never` members that only explode at the use site.
- A class name is also its instance type; `instanceof` narrows because
  classes exist at runtime — interfaces don't.
- In React code: plain objects + functions for data; classes for custom
  Errors and library objects. Generics (lesson 06) work with all of these.
