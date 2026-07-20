/**
 * Lesson 09 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 09` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * This lesson is type-level only — there is nothing to run. Replace each
 * `unknown // ← replace` with a real implementation and watch the
 * assertions under it go quiet, one by one.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"

// ---------------------------------------------------------------------------
// Exercise 1 — Your first mapped type.
// Nullable<T> keeps every key of T but allows null in every value — the
// shape of a half-filled form draft. Loop over keyof T; the new value type
// for each K is T[K] | null.
// ---------------------------------------------------------------------------

type Nullable<T> = unknown // ← replace

type _e1a = Expect<
  Equal<Nullable<{ name: string; age: number }>, { name: string | null; age: number | null }>
>
type _e1b = Expect<Equal<Nullable<{ tags: string[] }>, { tags: string[] | null }>>

// ---------------------------------------------------------------------------
// Exercise 2 — Mapping modifiers: rebuild three of lesson 08's utilities.
// MyPartial adds `?` to every property, MyRequired strips it with `-?`, and
// MyReadonly adds `readonly`. Yes — the real Partial/Required/Readonly are
// exactly these one-liners (`gd` into Partial and compare when you're done).
// ---------------------------------------------------------------------------

type MyPartial<T> = unknown // ← replace
type MyRequired<T> = unknown // ← replace
type MyReadonly<T> = unknown // ← replace

type Draft = {
  title: string
  body?: string
  readonly id: number
}

type _e2a = Expect<Equal<MyPartial<Draft>, Partial<Draft>>>
type _e2b = Expect<Equal<MyRequired<Draft>, Required<Draft>>>
type _e2c = Expect<Equal<MyReadonly<Draft>, Readonly<Draft>>>
type _e2d = Expect<Equal<MyPartial<{ a: number }>, { a?: number }>>

// ---------------------------------------------------------------------------
// Exercise 3 — Map over a literal union: rebuild Record.
// The union after `in` doesn't have to come from keyof — map over K itself,
// giving every key in it the value type V.
// ---------------------------------------------------------------------------

type MyRecord<K extends PropertyKey, V> = unknown // ← replace

type _e3a = Expect<Equal<MyRecord<"dev" | "prod", string>, Record<"dev" | "prod", string>>>
type _e3b = Expect<Equal<MyRecord<"on" | "off", boolean>, { on: boolean; off: boolean }>>

// ---------------------------------------------------------------------------
// Exercise 4 — Conditional types and distribution.
// 4a: rebuild Exclude<T, U>. A conditional over a naked type parameter runs
//     once per union member; returning `never` for a member deletes it.
// 4b: AllStrings<T> should answer "is the WHOLE of T a string?" — but as
//     written it distributes, so a mixed union answers `boolean`. Turn
//     distribution off with the [T] extends [U] tuple trick.
// ---------------------------------------------------------------------------

type MyExclude<T, U> = unknown // ← replace

type _e4a = Expect<Equal<MyExclude<"a" | "b" | "c", "a">, "b" | "c">>
type _e4b = Expect<Equal<MyExclude<string | number | boolean, boolean>, string | number>>

type AllStrings<T> = T extends string ? true : false // ← fix me

type _e4c = Expect<Equal<AllStrings<"a" | "b">, true>>
type _e4d = Expect<Equal<AllStrings<"a" | 1>, false>>

// ---------------------------------------------------------------------------
// Exercise 5 — `infer`: capture a piece of a matched shape.
// 5a: ElementOf<T> unwraps an array type to its element type (never if T
//     isn't an array).
// 5b: MyReturnType<F> captures what a function returns (never if F isn't a
//     function). To match "any function" without `any`, write the parameters
//     as (...args: never[]) — the notes explain why that works.
// ---------------------------------------------------------------------------

type ElementOf<T> = unknown // ← replace
type MyReturnType<F> = unknown // ← replace

declare function loadUser(id: number): { name: string; admin: boolean }

type _e5a = Expect<Equal<ElementOf<string[]>, string>>
type _e5b = Expect<Equal<ElementOf<{ id: number }[]>, { id: number }>>
type _e5c = Expect<Equal<ElementOf<number>, never>>
type _e5d = Expect<Equal<MyReturnType<() => Date>, Date>>
type _e5e = Expect<Equal<MyReturnType<typeof loadUser>, { name: string; admin: boolean }>>

// ---------------------------------------------------------------------------
// Exercise 6 — MyAwaited: unwrap ONE level of Promise.
// If T is a Promise, produce what it resolves to; anything else passes
// through unchanged (that's what the false branch is for).
// ---------------------------------------------------------------------------

type MyAwaited<T> = unknown // ← replace

type _e6a = Expect<Equal<MyAwaited<Promise<string>>, string>>
type _e6b = Expect<Equal<MyAwaited<Promise<number[]>>, number[]>>
type _e6c = Expect<Equal<MyAwaited<boolean>, boolean>>
// One level only — the real Awaited from lesson 08 keeps unwrapping:
type _e6d = Expect<Equal<MyAwaited<Promise<Promise<string>>>, Promise<string>>>

// ---------------------------------------------------------------------------
// Exercise 7 — Template literal types.
// 7a: ButtonClass is every "size-tone" combination. One template literal
//     with two union placeholders builds the whole cross product.
// 7b: EventName<T> turns "click" into "onClick" — Capitalize<T> inside a
//     template literal. Distribution over unions comes for free.
// ---------------------------------------------------------------------------

type Size = "sm" | "md" | "lg"
type Tone = "primary" | "danger"

type ButtonClass = unknown // ← replace

type _e7a = Expect<
  Equal<
    ButtonClass,
    | "sm-primary" | "sm-danger"
    | "md-primary" | "md-danger"
    | "lg-primary" | "lg-danger"
  >
>

type EventName<T extends string> = unknown // ← replace

type _e7b = Expect<Equal<EventName<"click">, "onClick">>
type _e7c = Expect<Equal<EventName<"click" | "focus">, "onClick" | "onFocus">>

// ---------------------------------------------------------------------------
// Exercise 8 — Capstone: derive an event-handler map from a state shape.
// ChangeHandlers<T> maps every key K of T to a handler named
// on<CapitalizedK>Change that receives that property's own type:
//   { count: number }  →  { onCountChange: (value: number) => void }
// You'll need a mapped type, key remapping with `as`, a template literal,
// Capitalize, indexed access, and the `K & string` trick from the notes —
// everything this lesson taught, in one type.
// ---------------------------------------------------------------------------

type ChangeHandlers<T> = unknown // ← replace

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

// ---------------------------------------------------------------------------
export {}
