/**
 * Capstone stage 03 — solution with commentary.
 *
 * Import rule: solution files import ONLY sibling solution files
 * (./01-domain), ../given/*, and ../../../helpers/* — NEVER ../NN-*
 * exercise files.
 */
import type { Expect, Equal } from "../../../helpers/type-assertions"
import type { Track } from "./01-domain"

// Task 1 — `as const` is the whole fix (lesson 07). Without it the array
// infers string[]: five specific genres melt into "any strings, any amount".
// With it, GENRES is the readonly tuple of exactly those five literals —
// which is what makes every derivation below possible.

export const GENRES = ["rock", "electronic", "hip-hop", "jazz", "ambient"] as const

type _e1 = Expect<Equal<typeof GENRES, readonly ["rock", "electronic", "hip-hop", "jazz", "ambient"]>>

// Task 2 — the hand-written union had already drifted ("electronc"), which
// is the argument for never writing it by hand again. Indexing a tuple by
// `number` unions every element (lesson 07), so the derivation below IS the
// five genres, kept in sync by the compiler. And _e2b is the capstone's
// single-source cross-check: the same union stage 01 spelled out on
// Track["genre"], now provably identical. Add a genre to GENRES tomorrow
// and this line tells you exactly where the domain needs to catch up.

export type Genre = (typeof GENRES)[number]

type _e2a = Expect<Equal<Genre, "rock" | "electronic" | "hip-hop" | "jazz" | "ambient">>
type _e2b = Expect<Equal<Genre, Track["genre"]>>

// Task 3 — the annotation-vs-satisfies triangle (lessons 07 + 08), applied
// to real design tokens. The old `: Record<string, string>` annotation did
// catch the number 0xe74c3c — but it also REPLACED the inferred type, so
// the keys collapsed to string and the values to string, and nobody noticed
// "ambient" was missing. `as const satisfies Record<Genre, string>` does
// all three jobs at once: `as const` keeps every hex literal, `satisfies`
// audits without widening, and keying the Record by Genre makes a missing
// genre a compile error. The moment the annotation moved, the compiler
// demanded the ambient entry — that's Record exhaustiveness working for you.

export const BADGE_TONES = {
  rock: "#e74c3c",
  electronic: "#3b82f6",
  "hip-hop": "#f59e0b",
  jazz: "#8b5cf6",
  ambient: "#10b981",
} as const satisfies Record<Genre, string>

// GIVEN — the derivation was always right; the object needed to earn it.
export type BadgeTone = (typeof BADGE_TONES)[Genre]

type _e3 = Expect<Equal<BadgeTone, "#e74c3c" | "#3b82f6" | "#f59e0b" | "#8b5cf6" | "#10b981">>

// Task 4 — same move, and the assertions did the detective work. Under the
// old annotation, `keyof typeof SORT_LABELS` was just string — so the typo'd
// key `durationSecs` hid in plain sight. After the swap to
// `as const satisfies Record<string, string>`, keyof finally names the real
// keys and BOTH assertions point at the drift: _e4a because the union has
// the wrong member, _e4b because Extract against keyof Track (lesson 08's
// cross-check) drops "durationSecs" — you can't sort tracks by a field
// Track doesn't have. One deleted "s" and the checker goes quiet.

export const SORT_LABELS = {
  title: "Title",
  artist: "Artist",
  durationSec: "Length",
} as const satisfies Record<string, string>

// GIVEN — the derivation was always right.
export type SortField = keyof typeof SORT_LABELS

type _e4a = Expect<Equal<SortField, "title" | "artist" | "durationSec">>
type _e4b = Expect<Equal<Extract<SortField, keyof Track>, SortField>>

// Task 5 — satisfies with a template-literal type as the audit. A bare
// object literal widens every route to string, so ApiRoute was useless —
// and "api/plays" (no leading slash) sailed through. Record<string,
// `/api/${string}`> spells the RULE every value must match, and the moment
// `as const satisfies` landed, the compiler pointed at the one entry that
// broke it. Stage 08 imports API_ROUTES for its route handlers; the
// leading-slash bug dies here instead of in production.

export const API_ROUTES = {
  tracks: "/api/tracks",
  plays: "/api/plays",
  search: "/api/search",
} as const satisfies Record<string, `/api/${string}`>

// GIVEN — the derivation was always right.
export type ApiRoute = (typeof API_ROUTES)[keyof typeof API_ROUTES]

type _e5 = Expect<Equal<ApiRoute, "/api/tracks" | "/api/plays" | "/api/search">>

export {}
