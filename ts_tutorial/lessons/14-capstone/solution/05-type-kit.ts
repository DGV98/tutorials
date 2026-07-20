/** Capstone stage 05 — solution with commentary. */
import type { Expect, Equal } from "../../../helpers/type-assertions"

// GIVEN — local fixtures, identical in both worlds. The boss arena is
// soundproof: this stage imports nothing from the other stages, so these
// stand-ins are shaped like Heavy Rotation without depending on it. That
// isolation is the point — every error in this file is YOURS, and every
// type you build here gets imported by the React layer (stages 06–08).

type LoginForm = { email: string; password: string }
type Song = { readonly id: string; title: string; likes: number }
type PlayRecord = { id: string; playedAt: Date; count: number }
type ToastAction =
  | { type: "show"; message: string }
  | { type: "hide" }
  | { type: "clear" }
type EditForm = { title: string; durationSec: number; explicit: boolean; tags: string[] }

// Task 1 — the lesson 09 skeleton with one rename: the loop still walks
// keyof T, but `as` gives each key a new name built from a template
// literal. `K & string` is the trick from lesson 09 Ex8 — keys can be
// symbols, template literals can't hold those, and intersecting with
// string narrows K to what `${...}` accepts. The `?` matters too: a clean
// form has NO error entries, so every message is optional.

export type FieldErrors<T> = {
  [K in keyof T as `${K & string}Error`]?: string
}

type _e1a = Expect<Equal<FieldErrors<LoginForm>, { emailError?: string; passwordError?: string }>>
type _e1b = Expect<Equal<FieldErrors<{ title: string }>, { titleError?: string }>>

// Task 2 — lesson 09 Ex2 taught `-?` as "strip optionality"; `-readonly`
// is the same dial pointed at the other modifier. A draft is something
// you're still editing: nothing locked (readonly stripped), nothing
// required yet (everything optional). You just rebuilt Partial and a
// hand-rolled Mutable in one homomorphic mapped type — hover Draft<Song>
// and watch `readonly id` come unfrozen AND turn optional at once.

export type Draft<T> = {
  -readonly [K in keyof T]?: T[K]
}

type _e2 = Expect<Equal<Draft<Song>, { id?: string; title?: string; likes?: number }>>

// Task 3 — a conditional type in the VALUE position. The keys don't
// change; each value gets asked a question instead: `T[K] extends Date`
// picks out the properties that JSON.stringify will flatten to strings,
// and everything else passes through untouched. This is the honest type
// of a JSON round-trip — Date survives nowhere on the wire — and stage 08
// cashes it in when plays cross the API boundary.

export type Serialized<T> = {
  [K in keyof T]: T[K] extends Date ? string : T[K]
}

type _e3a = Expect<Equal<Serialized<PlayRecord>, { id: string; playedAt: string; count: number }>>
type _e3b = Expect<Equal<Serialized<{ at: Date; ok: boolean }>, { at: string; ok: boolean }>>

// Task 4 — A is a naked type parameter, so the conditional distributes:
// it runs once per member of the union (lesson 09 Ex4). Members whose
// `type` is assignable to K keep themselves; the rest map to never, and
// never vanishes from unions — which is exactly what "selecting" means.
// You just rebuilt Extract. Note _e4b: K can itself be a union, and plain
// assignability ("hide" fits "hide" | "clear") does the work — no extra
// machinery needed.

export type ActionOfType<A, K> = A extends { type: K } ? A : never

type _e4a = Expect<Equal<ActionOfType<ToastAction, "show">, { type: "show"; message: string }>>
type _e4b = Expect<
  Equal<ActionOfType<ToastAction, "hide" | "clear">, { type: "hide" } | { type: "clear" }>
>

// Task 5 — infer reaches through a nested shape in a single pattern. For
// the match to succeed T must be a Promise AND its resolved value must
// have a `data` property; D captures whatever that property holds. Both
// failure modes fall to never: a response with no data key (_e5b) and a
// non-promise (_e5c). This is lesson 09 Ex5 and Ex6 chained into one move.

export type UnwrapData<T> = T extends Promise<{ data: infer D }> ? D : never

type _e5a = Expect<Equal<UnwrapData<Promise<{ data: Song[] }>>, Song[]>>
type _e5b = Expect<Equal<UnwrapData<Promise<{ status: number }>>, never>>
type _e5c = Expect<Equal<UnwrapData<string>, never>>

// Task 6 — infer inside a template literal pattern. Read it left to
// right: some string, then "/[", then a capture, then "]". The compiler
// does the string surgery for you — "/tracks/[id]" matches with
// Param = "id", and a path with no dynamic segment simply doesn't match.
// That bracket syntax isn't invented: it's how Next names dynamic route
// segments, and stage 08 derives page params from route strings with
// exactly this type.

export type SegmentOf<Path> = Path extends `${string}/[${infer Param}]` ? Param : never

type _e6a = Expect<Equal<SegmentOf<"/tracks/[id]">, "id">>
type _e6b = Expect<Equal<SegmentOf<"/playlists/[playlistId]">, "playlistId">>
type _e6c = Expect<Equal<SegmentOf<"/library">, never>>

// Task 7 — lesson 09's capstone, rebuilt from memory: `as` renames each
// key with a template literal, Capitalize dresses it up, `K & string`
// keeps Capitalize fed, and the value is a fresh function type whose
// parameter is T[K] — indexed access keeping each handler honest about
// which property it updates. This is the React onSomethingChange
// convention derived instead of hand-written, and it's about to be real:
// stage 06's form props come from this family of types.

export type ChangeHandlers<T> = {
  [K in keyof T as `on${Capitalize<K & string>}Change`]: (value: T[K]) => void
}

type _e7 = Expect<
  Equal<
    ChangeHandlers<{ query: string; limit: number }>,
    { onQueryChange: (value: string) => void; onLimitChange: (value: number) => void }
  >
>

// Task 8 — the final boss: the conditional moves INSIDE the `as` clause.
// Each key is tested where its new name is decided — a value that passes
// `extends string | number` earns a handler name; one that fails remaps
// to never, and a key named never is dropped from the result entirely.
// Lesson 09's notes mentioned remap-to-never filtering in passing; here
// it earns its keep: a text form can edit strings and numbers, so
// EditForm's boolean and string[] members vanish (_e8b proves it at the
// key level, not just by eyeball). Stage 06's TrackForm runs on this.

export type EditableHandlers<T> = {
  [K in keyof T as T[K] extends string | number
    ? `on${Capitalize<K & string>}Change`
    : never]: (value: T[K]) => void
}

type _e8a = Expect<
  Equal<
    EditableHandlers<EditForm>,
    { onTitleChange: (value: string) => void; onDurationSecChange: (value: number) => void }
  >
>
type _e8b = Expect<Equal<keyof EditableHandlers<EditForm>, "onTitleChange" | "onDurationSecChange">>

export {}
