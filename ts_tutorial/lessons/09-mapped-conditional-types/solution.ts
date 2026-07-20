/**
 * Lesson 09 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"

// Exercise 1 — the mapped-type skeleton is always the same: loop over
// keyof T, look up each value with T[K], and say what the new value type
// is. Here the tweak is "| null" on the value.

type Nullable<T> = {
  [K in keyof T]: T[K] | null
}

type _e1a = Expect<
  Equal<Nullable<{ name: string; age: number }>, { name: string | null; age: number | null }>
>
type _e1b = Expect<Equal<Nullable<{ tags: string[] }>, { tags: string[] | null }>>

// Exercise 2 — this time the value type stays T[K]; only the modifiers
// change. Bare `?`/`readonly` means +, and `-?` strips optionality. These
// compare Equal to the built-ins because they ARE the built-ins: `gd` into
// Partial and you'll find this exact mapped type. Note _e2b: MyRequired
// keeps `readonly id` intact — mapping over keyof T preserves existing
// modifiers unless you explicitly remove them.

type MyPartial<T> = {
  [K in keyof T]?: T[K]
}

type MyRequired<T> = {
  [K in keyof T]-?: T[K]
}

type MyReadonly<T> = {
  readonly [K in keyof T]: T[K]
}

type Draft = {
  title: string
  body?: string
  readonly id: number
}

type _e2a = Expect<Equal<MyPartial<Draft>, Partial<Draft>>>
type _e2b = Expect<Equal<MyRequired<Draft>, Required<Draft>>>
type _e2c = Expect<Equal<MyReadonly<Draft>, Readonly<Draft>>>
type _e2d = Expect<Equal<MyPartial<{ a: number }>, { a?: number }>>

// Exercise 3 — the union after `in` is K itself, not keyof anything. Each
// member of K becomes a key; every key gets value type V. PropertyKey in
// the constraint is why Record rejects things that can't be object keys.

type MyRecord<K extends PropertyKey, V> = {
  [P in K]: V
}

type _e3a = Expect<Equal<MyRecord<"dev" | "prod", string>, Record<"dev" | "prod", string>>>
type _e3b = Expect<Equal<MyRecord<"on" | "off", boolean>, { on: boolean; off: boolean }>>

// Exercise 4a — T is naked, so the conditional runs once per union member.
// Members matching U map to never, and never vanishes from unions — which
// is exactly what "excluding" means. (In _e4b, boolean itself splits into
// true | false during distribution; both match and both vanish.)

type MyExclude<T, U> = T extends U ? never : T

type _e4a = Expect<Equal<MyExclude<"a" | "b" | "c", "a">, "b" | "c">>
type _e4b = Expect<Equal<MyExclude<string | number | boolean, boolean>, string | number>>

// Exercise 4b — wrapping both sides in a one-element tuple means the
// checked type is [T], which is not naked — so no distribution, and the
// union "a" | 1 is tested as a single unit against [string]: false.

type AllStrings<T> = [T] extends [string] ? true : false

type _e4c = Expect<Equal<AllStrings<"a" | "b">, true>>
type _e4d = Expect<Equal<AllStrings<"a" | 1>, false>>

// Exercise 5a — the pattern (infer E)[] both asks "is T an array?" and
// captures the element type when the answer is yes.

type ElementOf<T> = T extends (infer E)[] ? E : never

// Exercise 5b — same move against a function shape. `(...args: never[])`
// matches ANY function because parameters check contravariantly and never
// is assignable to every parameter type — the no-`any` way to say "some
// function, I don't care about its parameters".

type MyReturnType<F> = F extends (...args: never[]) => infer R ? R : never

declare function loadUser(id: number): { name: string; admin: boolean }

type _e5a = Expect<Equal<ElementOf<string[]>, string>>
type _e5b = Expect<Equal<ElementOf<{ id: number }[]>, { id: number }>>
type _e5c = Expect<Equal<ElementOf<number>, never>>
type _e5d = Expect<Equal<MyReturnType<() => Date>, Date>>
type _e5e = Expect<Equal<MyReturnType<typeof loadUser>, { name: string; admin: boolean }>>

// Exercise 6 — the false branch is T, not never: a non-promise "awaits" to
// itself, which mirrors how `await 42` just gives you 42. And because the
// pattern only matches once, Promise<Promise<string>> unwraps a single
// level (_e6d) — the real Awaited recurses to finish the job.

type MyAwaited<T> = T extends Promise<infer V> ? V : T

type _e6a = Expect<Equal<MyAwaited<Promise<string>>, string>>
type _e6b = Expect<Equal<MyAwaited<Promise<number[]>>, number[]>>
type _e6c = Expect<Equal<MyAwaited<boolean>, boolean>>
type _e6d = Expect<Equal<MyAwaited<Promise<Promise<string>>>, Promise<string>>>

// Exercise 7a — each ${...} placeholder holding a union multiplies the
// result: 3 sizes × 2 tones = 6 literal strings. You wrote no union
// members by hand; the compiler did the combinatorics.

type Size = "sm" | "md" | "lg"
type Tone = "primary" | "danger"

type ButtonClass = `${Size}-${Tone}`

type _e7a = Expect<
  Equal<
    ButtonClass,
    | "sm-primary" | "sm-danger"
    | "md-primary" | "md-danger"
    | "lg-primary" | "lg-danger"
  >
>

// Exercise 7b — Capitalize is one of the four intrinsic string helpers,
// and template literals distribute over unions on their own, so the
// "click" | "focus" case needs no extra work.

type EventName<T extends string> = `on${Capitalize<T>}`

type _e7b = Expect<Equal<EventName<"click">, "onClick">>
type _e7c = Expect<Equal<EventName<"click" | "focus">, "onClick" | "onFocus">>

// Exercise 8 — the whole lesson in one type. The loop walks keyof T; `as`
// renames each key with a template literal; K & string narrows the key to
// what Capitalize accepts; and the value is a fresh function type whose
// parameter is T[K] — indexed access keeping each handler honest about
// which property it updates. This is precisely the shape of React's
// onSomethingChange prop conventions, derived instead of hand-written.

type ChangeHandlers<T> = {
  [K in keyof T as `on${Capitalize<K & string>}Change`]: (value: T[K]) => void
}

type PlayerState = {
  track: string
  volume: number
  muted: boolean
}

type _e8a = Expect<
  Equal<
    ChangeHandlers<PlayerState>,
    {
      onTrackChange: (value: string) => void
      onVolumeChange: (value: number) => void
      onMutedChange: (value: boolean) => void
    }
  >
>
type _e8b = Expect<
  Equal<ChangeHandlers<{ user: string | null }>, { onUserChange: (value: string | null) => void }>
>

export {}
