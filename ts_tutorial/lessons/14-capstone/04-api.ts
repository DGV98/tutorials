/**
 * Capstone stage 04 — The boundary: trust nothing that crosses it.
 *
 * This file intentionally does not type-check. It is stage 4 of 8 of ONE
 * app — Heavy Rotation — and stage 08 imports the guards you build here.
 * Work the stages in order (01 through 03 first), and within this file work
 * top to bottom until `./check 14` reports no errors mentioning `04-`.
 *
 * Then run it:  npx tsx lessons/14-capstone/04-api.ts
 * The runtime checks here are load-bearing — one of them catches a bug the
 * compiler cannot see.
 *
 * Never edit lines containing Expect<Equal<...>> — they are the assertions
 * you're satisfying. Never touch GIVEN-marked blocks — they are complete
 * and correct.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// ---------------------------------------------------------------------------
// Task 1 — say what's erased (lesson 10).
// Track, Play, and User are all TYPES — they vanish at compile time, and
// this project runs verbatimModuleSyntax, so the import below must say so.
// One keyword fixes all three errors. The raw-data import is GIVEN — those
// are runtime values, imported the plain way on purpose.
// ---------------------------------------------------------------------------

import { Track, Play, User } from "./01-domain"

// GIVEN — the untrusted outside world. Do not edit.
import { RAW_CATALOG_JSON, RAW_PREFS_JSON, RAW_BAD_PREFS_JSON } from "./given/raw-data"

// ---------------------------------------------------------------------------
// Task 2 — prove the payload (lesson 10).
// A previous dev "fixed" this with a lying cast; it has been removed — do
// NOT bring it back (no casts, no any). Write the guard chain: not an
// object, or null, or no "volume" key, or volume isn't a number → throw
// new HttpError(400, "bad prefs payload"). Then return data.volume, which
// by then is a proven number. (HttpError lives under Task 5 below — a
// function body may reference it before it's declared.)
// ---------------------------------------------------------------------------

export function readVolume(raw: string): number {
  const data: unknown = JSON.parse(raw)
  return data.volume
}

// ---------------------------------------------------------------------------
// Task 3 — the predicate is TRUSTED, not verified (lesson 10).
// The compiler only flags the durationSec comparison — but keep narrowing
// turtles-all-the-way-down: a typeof check for EVERY field Track promises
// (id/title/artist/album/genre are strings, durationSec a number), keeping
// the `> 0` sanity check. A lazy body type-checks fine and lies to the
// whole app; the "malformed entry rejected" check in the harness below is
// the backstop that catches it. On this task, npx tsx is the judge.
// ---------------------------------------------------------------------------

export function isTrack(value: unknown): value is Track {
  return (
    typeof value === "object" &&
    value !== null &&
    "durationSec" in value &&
    value.durationSec > 0
  )
}

// ---------------------------------------------------------------------------
// Task 4 — two-layer proof of an unknown array (lesson 10).
// You can't just return `data` — unknown is not Track[]. First prove it's
// an array at all: if (!Array.isArray(data)) throw new HttpError(502, ...).
// Then prove each element: return data.filter(isTrack) — passing your
// predicate by REFERENCE is what turns the elements into Tracks.
// ---------------------------------------------------------------------------

export function parseCatalog(json: string): Track[] {
  const data: unknown = JSON.parse(json)
  return data
}

// GIVEN — complete and correct. Stage 08's route handlers narrow on this.
export interface WithStatus {
  status: number
}

// ---------------------------------------------------------------------------
// Task 5 — a constructor param is not a property (lesson 05).
// `implements WithStatus` demands the class actually HAVE a status — but a
// plain parameter evaporates after super(message) runs. Convert it to the
// parameter property `public readonly status: number` (declares AND
// assigns in one stroke). The GIVEN try/catch in the harness reads
// err.status the moment it exists.
// ---------------------------------------------------------------------------

export class HttpError extends Error implements WithStatus {
  constructor(
    status: number,
    message: string,
  ) {
    super(message)
  }
}

// ---------------------------------------------------------------------------
// Task 6 — a patch is a SUBSET (lesson 08).
// The GIVEN call in the harness passes { title: "Rename" } — and it is
// right to. Fix the PARAMETER, not the caller: a patch should be
// Partial<Track>. The body already does the correct spread; leave it.
// ---------------------------------------------------------------------------

export function applyPatch(track: Track, patch: Track): Track {
  return { ...track, ...patch }
}

// ---------------------------------------------------------------------------
// Task 7 — Pick and Omit are duals (lesson 08).
// PublicUser is meant to be User WITHOUT the email — but Pick<User, "email">
// keeps ONLY the email, exactly backwards, and the GIVEN body refuses to
// compile against it. Swap Pick for Omit; touch nothing else.
// ---------------------------------------------------------------------------

export type PublicUser = Pick<User, "email">

// GIVEN — complete and correct. The body was always right.
export function toPublicUser(user: User): PublicUser {
  return { id: user.id, handle: user.handle, displayName: user.displayName }
}

type _e7 = Expect<Equal<PublicUser, { readonly id: string; handle: string; displayName?: string }>>

// ---------------------------------------------------------------------------
// Task 8 — derive the keys, don't index-signature them (lesson 08).
// `{ [key: string]: number }` accepts ANY key and demands none — useless as
// a tally, which is how the radio count silently vanished. Swap the
// annotation for Record<Play["source"], number>, then add the entry the
// compiler starts demanding (one radio play in stage 01's seed log).
// And OfflineSource has drifted: it must be every source EXCEPT "radio" —
// use Exclude on Play["source"] instead of hand-copying the survivors.
// ---------------------------------------------------------------------------

export const PLAYS_BY_SOURCE: { [key: string]: number } = {
  library: 1,
  playlist: 1,
}

type _e8a = Expect<Equal<keyof typeof PLAYS_BY_SOURCE, Play["source"]>>

export type OfflineSource = Play["source"]

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

// ---------------------------------------------------------------------------
// Task 9 — unwrap the Promise (lesson 08).
// ReturnType of an async function is Promise<...> — the assertion wants
// what an AWAITED call yields. Wrap the whole thing in Awaited.
// (fetchDashboard itself is GIVEN and correct.)
// ---------------------------------------------------------------------------

export type DashboardData = ReturnType<typeof fetchDashboard>

type _e9 = Expect<Equal<DashboardData, { user: PublicUser; topTracks: Track[]; totalPlays: number }>>

// ---------------------------------------------------------------------------
// GIVEN — the runtime harness. Complete and correct. Do not edit.
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
