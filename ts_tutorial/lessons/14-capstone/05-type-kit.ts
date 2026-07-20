/**
 * Capstone stage 05 — BOSS FIGHT: the type toolkit.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each task until `./check 14` shows zero errors mentioning `05-`. Never
 * edit lines containing Expect<Equal<...>> — they are the assertions
 * you're satisfying — and never edit GIVEN blocks.
 *
 * This stage is part of one app, and the stages are meant to be worked in
 * order — but this file imports NOTHING from the other stages. The arena
 * is soundproof: every error here is yours, and the entire React layer
 * ahead (stages 06–08) runs on what you build here.
 *
 * Type-level only: nothing to run. Replace each `unknown // ← replace`
 * with a real implementation and watch the suite under it go quiet, one
 * by one. Budget a full evening. If a stub fights you for more than
 * fifteen minutes, read solution/05-type-kit.ts, then re-do it from a
 * blank line — peeking is studying.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"

// ---------------------------------------------------------------------------
// GIVEN — local fixtures, complete and correct. DO NOT EDIT.
// The real domain lives in stage 01, but the boss arena is soundproof:
// these stand-ins are shaped like Heavy Rotation without importing it.
// ---------------------------------------------------------------------------

type LoginForm = { email: string; password: string }
type Song = { readonly id: string; title: string; likes: number }
type PlayRecord = { id: string; playedAt: Date; count: number }
type ToastAction =
  | { type: "show"; message: string }
  | { type: "hide" }
  | { type: "clear" }
type EditForm = { title: string; durationSec: number; explicit: boolean; tags: string[] }

// ---------------------------------------------------------------------------
// Task 1 — FieldErrors<T>: rename every key with a template literal.
// { email: string } should become { emailError?: string }. Loop over
// keyof T, remap with `as` to `${K & string}Error`, and make every value
// an OPTIONAL string — a clean form has NO error entries. Every move here
// is lesson 09 Ex8, minus Capitalize.
// ---------------------------------------------------------------------------

export type FieldErrors<T> = unknown // ← replace

type _e1a = Expect<Equal<FieldErrors<LoginForm>, { emailError?: string; passwordError?: string }>>
type _e1b = Expect<Equal<FieldErrors<{ title: string }>, { titleError?: string }>>

// ---------------------------------------------------------------------------
// Task 2 — Draft<T>: rebuild Partial + Mutable by hand.
// Strip `readonly` from every key AND add `?`, in one mapped type. Lesson
// 09 taught `-?`; `-readonly` is its mirror — see notes.md, "`-readonly` —
// the mirror of `-?`". Do NOT reach for Partial<T>; write the modifiers yourself.
// ---------------------------------------------------------------------------

export type Draft<T> = unknown // ← replace

type _e2 = Expect<Equal<Draft<Song>, { id?: string; title?: string; likes?: number }>>

// ---------------------------------------------------------------------------
// Task 3 — Serialized<T>: what JSON.stringify actually does.
// A conditional type in the VALUE position — see notes.md, "A conditional
// type in the mapped value position". Keep every key; any value that
// extends Date becomes string, every other value passes through. Dates
// never survive the wire.
// ---------------------------------------------------------------------------

export type Serialized<T> = unknown // ← replace

type _e3a = Expect<Equal<Serialized<PlayRecord>, { id: string; playedAt: string; count: number }>>
type _e3b = Expect<Equal<Serialized<{ at: Date; ok: boolean }>, { at: string; ok: boolean }>>

// ---------------------------------------------------------------------------
// Task 4 — ActionOfType<A, K>: rebuild Extract with distribution.
// A conditional over the naked parameter A runs once per union member
// (lesson 09 Ex4): keep the members whose `type` matches K, send the rest
// to never and let them vanish. _e4b passes a UNION for K — assignability
// handles it; no extra machinery needed.
// ---------------------------------------------------------------------------

export type ActionOfType<A, K> = unknown // ← replace

type _e4a = Expect<Equal<ActionOfType<ToastAction, "show">, { type: "show"; message: string }>>
type _e4b = Expect<
  Equal<ActionOfType<ToastAction, "hide" | "clear">, { type: "hide" } | { type: "clear" }>
>

// ---------------------------------------------------------------------------
// Task 5 — UnwrapData<T>: infer through a nested shape.
// Match "a Promise resolving to an object with a data property" in ONE
// pattern, and capture what data holds (lesson 09 Ex5 and Ex6, chained).
// Anything that doesn't match — wrong shape, or not a Promise at all —
// is never.
// ---------------------------------------------------------------------------

export type UnwrapData<T> = unknown // ← replace

type _e5a = Expect<Equal<UnwrapData<Promise<{ data: Song[] }>>, Song[]>>
type _e5b = Expect<Equal<UnwrapData<Promise<{ status: number }>>, never>>
type _e5c = Expect<Equal<UnwrapData<string>, never>>

// ---------------------------------------------------------------------------
// Task 6 — SegmentOf<Path>: infer inside a template literal.
// "/tracks/[id]" should yield "id"; a path with no [segment] yields
// never. The capture goes between the brackets — see notes.md, "`infer`
// inside a template literal". Stage 08 derives Next page
// params from route strings with exactly this move.
// ---------------------------------------------------------------------------

export type SegmentOf<Path> = unknown // ← replace

type _e6a = Expect<Equal<SegmentOf<"/tracks/[id]">, "id">>
type _e6b = Expect<Equal<SegmentOf<"/playlists/[playlistId]">, "playlistId">>
type _e6c = Expect<Equal<SegmentOf<"/library">, never>>

// ---------------------------------------------------------------------------
// Task 7 — ChangeHandlers<T>: lesson 09's peak, from memory.
// Every key K becomes `on${Capitalize<K & string>}Change`, holding a
// handler (value: T[K]) => void. Try it WITHOUT peeking at lesson 09
// first — this exact shape lights up real JSX in stage 06.
// ---------------------------------------------------------------------------

export type ChangeHandlers<T> = unknown // ← replace

type _e7 = Expect<
  Equal<
    ChangeHandlers<{ query: string; limit: number }>,
    { onQueryChange: (value: string) => void; onLimitChange: (value: number) => void }
  >
>

// ---------------------------------------------------------------------------
// Task 8 — FINAL BOSS — EditableHandlers<T>: filter keys while remapping.
// Same shape as Task 7, but ONLY keys whose value is string | number get
// a handler: put a conditional INSIDE the `as` clause, and remap the
// failures to never — a key named never is dropped entirely. See
// notes.md, "Key remapping to `never` — filtering keys". _e8b checks the
// surviving keys by name, not by eyeball.
// ---------------------------------------------------------------------------

export type EditableHandlers<T> = unknown // ← replace

type _e8a = Expect<
  Equal<
    EditableHandlers<EditForm>,
    { onTitleChange: (value: string) => void; onDurationSecChange: (value: number) => void }
  >
>
type _e8b = Expect<Equal<keyof EditableHandlers<EditForm>, "onTitleChange" | "onDurationSecChange">>

// ---------------------------------------------------------------------------
export {}
