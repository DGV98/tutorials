/**
 * Capstone stage 03 — Design tokens and routes: derived, never duplicated.
 *
 * This file intentionally does not type-check. It is stage 3 of 8 of ONE
 * app — Heavy Rotation — and stages 06 and 08 import the tokens you fix
 * here. Work the stages in order (01 and 02 first), and within this file
 * work top to bottom until `./check 14` reports no errors mentioning `03-`.
 *
 * No `npx tsx` step this time: this stage lives entirely at the type
 * level (lesson 08's rule). When the checker goes quiet, you're done.
 *
 * Never edit lines containing Expect<Equal<...>> — they are the assertions
 * you're satisfying. Never touch GIVEN-marked lines — they are complete
 * and correct.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import type { Track } from "./01-domain"

// ---------------------------------------------------------------------------
// Task 1 — Two words unlock everything (lesson 07).
// Hover GENRES: it's string[], so five specific genres have melted into
// "any strings, any amount" — and every derivation below is built on this
// array. Add `as const` (two words, nothing else) and hover again.
// ---------------------------------------------------------------------------

export const GENRES = ["rock", "electronic", "hip-hop", "jazz", "ambient"]

type _e1 = Expect<Equal<typeof GENRES, readonly ["rock", "electronic", "hip-hop", "jazz", "ambient"]>>

// ---------------------------------------------------------------------------
// Task 2 — Delete the hand-written union; derive it (lesson 07).
// This union was copied by hand and has ALREADY drifted (spot the typo).
// Don't patch the typo — DELETE the whole right-hand side and derive it
// from GENRES with the (typeof X)[number] idiom. _e2b then proves your
// derivation matches Track["genre"] from stage 01: one source of truth,
// cross-checked against the domain.
// ---------------------------------------------------------------------------

export type Genre = "rock" | "electronc" | "hip-hop" | "jazz" | "ambient"

type _e2a = Expect<Equal<Genre, "rock" | "electronic" | "hip-hop" | "jazz" | "ambient">>
type _e2b = Expect<Equal<Genre, Track["genre"]>>

// ---------------------------------------------------------------------------
// Task 3 — as const satisfies: narrow AND checked (lessons 07 + 08).
// The `: Record<string, string>` annotation caught the number below (one
// tone isn't a string — fix it to "#e74c3c") but it also WIDENED the type:
// keys collapse to string, values to string, and BadgeTone is useless.
// Replace the annotation with `as const satisfies Record<Genre, string>` —
// then add whatever entry the compiler demands (ambient is "#10b981").
// The BadgeTone line is GIVEN — the derivation is right; don't touch it.
// ---------------------------------------------------------------------------

export const BADGE_TONES: Record<string, string> = {
  rock: 0xe74c3c,
  electronic: "#3b82f6",
  "hip-hop": "#f59e0b",
  jazz: "#8b5cf6",
}

// GIVEN — do not touch: the derivation was always right.
export type BadgeTone = (typeof BADGE_TONES)[Genre]

type _e3 = Expect<Equal<BadgeTone, "#e74c3c" | "#3b82f6" | "#f59e0b" | "#8b5cf6" | "#10b981">>

// ---------------------------------------------------------------------------
// Task 4 — The annotation is hiding a drifted key (lessons 07 + 08).
// Same disease as Task 3: `: Record<string, string>` collapses keyof to
// string, so SortField tells you nothing — and something in this object
// has quietly drifted. Swap the annotation for
// `as const satisfies Record<string, string>`, then fix whatever the
// assertions flag. _e4b is lesson 08's Extract cross-check: every sort
// field must really be a key of Track. The SortField line is GIVEN.
// ---------------------------------------------------------------------------

export const SORT_LABELS: Record<string, string> = {
  title: "Title",
  artist: "Artist",
  durationSecs: "Length",
}

// GIVEN — do not touch: the derivation was always right.
export type SortField = keyof typeof SORT_LABELS

type _e4a = Expect<Equal<SortField, "title" | "artist" | "durationSec">>
type _e4b = Expect<Equal<Extract<SortField, keyof Track>, SortField>>

// ---------------------------------------------------------------------------
// Task 5 — satisfies with a RULE, not just a type (lesson 08, one step on).
// A bare object literal widens every route to string, so ApiRoute — which
// stage 08 wires into real route handlers — is useless. Append
// `as const satisfies Record<string, `/api/${string}`>` to the object:
// the template literal spells the rule every value must match, and the
// compiler will point straight at the one route that breaks it — fix that
// value too. The ApiRoute line is GIVEN.
// ---------------------------------------------------------------------------

export const API_ROUTES = {
  tracks: "/api/tracks",
  plays: "api/plays",
  search: "/api/search",
}

// GIVEN — do not touch: the derivation was always right.
export type ApiRoute = (typeof API_ROUTES)[keyof typeof API_ROUTES]

type _e5 = Expect<Equal<ApiRoute, "/api/tracks" | "/api/plays" | "/api/search">>

export {}
