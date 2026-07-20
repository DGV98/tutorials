/**
 * Capstone stage 04 — solution with commentary.
 *
 * Import rule: solution files import ONLY sibling solution files
 * (./01-domain), ../given/*, and ../../../helpers/* — NEVER ../NN-*
 * exercise files.
 */
import type { Expect, Equal } from "../../../helpers/type-assertions"
import { check, summary } from "../../../helpers/test"

// Task 1 — Track, Play, and User are types: they're erased at compile time,
// and verbatimModuleSyntax (lesson 10's config tour) demands the import SAY
// so, because fast single-file transpilers like tsx strip exactly what the
// syntax marks. One keyword — `import type` — and all three TS1484 errors
// go quiet, and the emitted JavaScript never tries to load bindings that
// don't exist at runtime.

import type { Track, Play, User } from "./01-domain"

// GIVEN — the untrusted outside world: raw strings and unknowns, exactly as
// honest as a real fetch-and-parse. These are runtime VALUES, so they're
// imported the plain way.
import { RAW_CATALOG_JSON, RAW_PREFS_JSON, RAW_BAD_PREFS_JSON } from "../given/raw-data"

// Task 2 — JSON.parse hands back you-don't-know-what, and the honest
// `unknown` annotation makes the compiler enforce that (lesson 10). The
// guard chain narrows one clause at a time — object first, then not-null
// (typeof null === "object", the fossil), then the key exists, then the
// value is a number — and any failure bails into an HttpError before the
// next clause runs. Past the if, data.volume is a PROVEN number. The old
// lying cast would have compiled while "loud" sailed straight through;
// narrowing verifies, `as` merely silences. (HttpError is declared under
// Task 5 below — a function body may reference it freely, since nothing
// here runs until the whole module has loaded.)

export function readVolume(raw: string): number {
  const data: unknown = JSON.parse(raw)
  if (
    typeof data !== "object" ||
    data === null ||
    !("volume" in data) ||
    typeof data.volume !== "number"
  ) {
    throw new HttpError(400, "bad prefs payload")
  }
  return data.volume
}

// Task 3 — a type predicate is a promise the compiler TRUSTS, not one it
// verifies (lesson 10). The skeleton only proved durationSec existed — the
// compiler flagged the comparison on an unknown property, but it would have
// happily accepted a body that checked nothing else. So the fix is turtles
// all the way down: a typeof check for every string field Track promises,
// then the number, then the sanity check. The "malformed entry rejected"
// check in the harness below is the load-bearing backstop — it's the only
// thing that catches a lazy predicate, which is why this stage is runnable.
// One honest looseness, on purpose: typeof genre === "string" can't prove
// the Genre literal union (this boundary file deliberately doesn't import
// stage 03's tokens). The predicate's word is what the whole app runs on —
// keep its body honest.

export function isTrack(value: unknown): value is Track {
  return (
    typeof value === "object" &&
    value !== null &&
    "id" in value &&
    typeof value.id === "string" &&
    "title" in value &&
    typeof value.title === "string" &&
    "artist" in value &&
    typeof value.artist === "string" &&
    "album" in value &&
    typeof value.album === "string" &&
    "genre" in value &&
    typeof value.genre === "string" &&
    "durationSec" in value &&
    typeof value.durationSec === "number" &&
    value.durationSec > 0
  )
}

// Task 4 — two layers, one rule each (lesson 10). Array.isArray proves
// "this is an array at all" — a 502 if the server sent garbage — and then
// .filter(isTrack) proves each ELEMENT: passing the predicate by reference
// is what upgrades the filtered result to Track[]. Returning `data`
// directly was the TS2322 tripwire: unknown never assigns to Track[]
// without proof, and that refusal is the whole point of the annotation.

export function parseCatalog(json: string): Track[] {
  const data: unknown = JSON.parse(json)
  if (!Array.isArray(data)) {
    throw new HttpError(502, "catalog payload is not an array")
  }
  return data.filter(isTrack)
}

// GIVEN — complete and correct. Stage 08's route handlers narrow on this.
export interface WithStatus {
  status: number
}

// Task 5 — `implements WithStatus` is a check, not an inheritance: the
// class must actually HAVE a status property, and a plain constructor
// parameter is just a local variable that evaporates after super(message)
// runs. The parameter property `public readonly status: number` declares
// AND assigns in one stroke (lesson 05), which satisfies the interface and
// gives every `err instanceof HttpError` branch a real .status to read —
// instanceof narrowing works because the class, unlike the interface,
// exists at runtime.

export class HttpError extends Error implements WithStatus {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message)
  }
}

// Task 6 — the call site was right all along: a patch IS "any subset of
// Track". Partial<Track> makes every property optional, so { title:
// "Rename" } becomes a legal patch and the spread fills in the rest from
// the original. Lesson 08's rule: fix the PARAMETER where the contract is
// wrong — don't inflate every caller to a full Track.

export function applyPatch(track: Track, patch: Partial<Track>): Track {
  return { ...track, ...patch }
}

// Task 7 — Pick and Omit are duals (lesson 08). Pick<User, "email"> keeps
// ONLY the email — precisely the one field a public payload must never
// carry. Omit<User, "email"> says what was always meant: everything except
// the email. The given body never changed; the type finally matches it.
// Notice _e7: Omit carried `readonly id` and `displayName?` along —
// utility types preserve modifiers.

export type PublicUser = Omit<User, "email">

// GIVEN — complete and correct. The body was always right.
export function toPublicUser(user: User): PublicUser {
  return { id: user.id, handle: user.handle, displayName: user.displayName }
}

type _e7 = Expect<Equal<PublicUser, { readonly id: string; handle: string; displayName?: string }>>

// Task 8 — `{ [key: string]: number }` accepts ANY key and demands none:
// it can neither catch a typo'd source nor notice a missing one, which is
// how the radio tally silently vanished. Record<Play["source"], number> is
// DERIVED from the domain — if stage 01's Play ever gains a source, this
// table refuses to compile until it's counted. The counts mirror stage
// 01's seed log: one play each from the library, a playlist, and the
// radio. And OfflineSource subtracts from the same union with Exclude
// instead of hand-copying the survivors (lesson 08) — one source of truth,
// two derivations.

export const PLAYS_BY_SOURCE: Record<Play["source"], number> = {
  library: 1,
  playlist: 1,
  radio: 1,
}

type _e8a = Expect<Equal<keyof typeof PLAYS_BY_SOURCE, Play["source"]>>

export type OfflineSource = Exclude<Play["source"], "radio">

type _e8b = Expect<Equal<OfflineSource, "library" | "playlist">>

// GIVEN — complete and correct. No network: the dashboard assembles what
// this file has already proven. Stage 08 awaits it inside a page.
const sampleUser: User = { id: "u1", handle: "dgonz", email: "dgonz@example.com" }

export async function fetchDashboard(): Promise<{
  user: PublicUser
  topTracks: Track[]
  totalPlays: number
}> {
  const totalPlays =
    PLAYS_BY_SOURCE.library + PLAYS_BY_SOURCE.playlist + PLAYS_BY_SOURCE.radio
  return {
    user: toPublicUser(sampleUser),
    topTracks: parseCatalog(RAW_CATALOG_JSON),
    totalPlays,
  }
}

// Task 9 — ReturnType of an async function is the Promise, not the prize.
// Awaited unwraps it: Awaited<ReturnType<typeof fetchDashboard>> reads as
// "what one awaited call gives me" (lesson 08). Derived, never duplicated
// — when fetchDashboard grows a field, DashboardData follows for free,
// and stage 08's page props update themselves.

export type DashboardData = Awaited<ReturnType<typeof fetchDashboard>>

type _e9 = Expect<Equal<DashboardData, { user: PublicUser; topTracks: Track[]; totalPlays: number }>>

// ---------------------------------------------------------------------------
// GIVEN — the runtime harness. Complete and correct.
// The "malformed entry rejected" check is the trusted-predicate backstop:
// a lazy isTrack body type-checks fine and fails HERE. The compiler cannot
// save you at a boundary — this is where npx tsx earns its keep.
// ---------------------------------------------------------------------------

check("good prefs read the volume", readVolume(RAW_PREFS_JSON), 7)

let badPrefsOutcome = "no error thrown"
try {
  readVolume(RAW_BAD_PREFS_JSON)
} catch (err) {
  if (err instanceof HttpError) {
    badPrefsOutcome = `HttpError ${err.status}`
  }
}
check("bad prefs throw HttpError 400", badPrefsOutcome, "HttpError 400")

const catalog = parseCatalog(RAW_CATALOG_JSON)

type _e4 = Expect<Equal<typeof catalog, Track[]>>

check("malformed entry rejected — the predicate is trusted", catalog.length, 2)
check("the survivors are the real tracks", catalog.map((t) => t.id).join(","), "t10,t12")

const renamed = applyPatch(catalog[0], { title: "Rename" })

type _e6 = Expect<Equal<Parameters<typeof applyPatch>[1], Partial<Track>>>

check("patch applies the new title", renamed.title, "Rename")
check("patch leaves the original alone", catalog[0].title, "Everything In Its Right Place")

const publicUser = toPublicUser(sampleUser)
check("public user drops the email", "email" in publicUser, false)
check("public user keeps the handle", publicUser.handle, "dgonz")

const dashboard = await fetchDashboard()
check("dashboard serves the guarded catalog", dashboard.topTracks.length, 2)
check("dashboard tallies every source", dashboard.totalPlays, 3)

summary()
export {}
