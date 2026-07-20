/**
 * Capstone stage 02 — solution with commentary.
 *
 * Import rule: solution files import ONLY sibling solution files
 * (./01-domain), ../given/*, and ../../../helpers/* — NEVER ../NN-*
 * exercise files.
 */
import type { Expect, Equal } from "../../../helpers/type-assertions"
import { check, summary } from "../../../helpers/test"
import type { Track, Play } from "./01-domain"
import { seedTracks } from "./01-domain"

// ---------------------------------------------------------------------------
// GIVEN — the player's vocabulary. Complete and correct.
// Stage 07 imports these exact unions to drive useReducer, so every shape
// here is a contract with your future React code.
// ---------------------------------------------------------------------------

export type PlayerState =
  | { status: "stopped" }
  | { status: "playing"; track: Track; positionSec: number }
  | { status: "paused"; track: Track; positionSec: number }

export type PlayerAction =
  | { type: "play"; track: Track }
  | { type: "pause"; positionSec: number }
  | { type: "seek"; positionSec: number }
  | { type: "stop" }

// Task 1 — parameters can't be inferred (lesson 03): nothing has called
// the function yet, so `track` and `prefix` were implicit any. `track`
// takes a plain annotation; `prefix` gets a DEFAULT instead, and `= "♪ "`
// does two jobs at once: it makes the parameter optional at call sites
// (the bare announceTrack(seedTracks[0]) call in the harness compiles
// again) and infers its type — hover prefix and see `string`. The return
// type stays inferred on purpose; the assertion pins the whole signature.

export function announceTrack(track: Track, prefix = "♪ ") {
  return `${prefix}${track.title}`
}

type _e1 = Expect<Equal<typeof announceTrack, (track: Track, prefix?: string) => string>>

// Task 2 — two bugs in one function, and the compiler only ever saw one.
// The `: string` annotation is a contract (lesson 03), so `return
// positionSec` errored exactly where the fix belongs — wrap the number in
// a template literal; never loosen the contract to string | number. The
// OTHER bug type-checked fine: `if (!positionSec)` swallows 0, and the
// zero-second mark of a track is real data (lesson 04's trap). Only the
// runtime check caught it — which is why we compare against null
// EXPLICITLY.

export function describePosition(positionSec: number | null): string {
  if (positionSec === null) return "not playing"
  return `${positionSec}s in`
}

// Task 3 — a rest parameter gathers its arguments into a real array, so
// its annotation must be an ARRAY type (lesson 03): string[], not string.
// The calls were always fine; only the declaration was missing its type.

export function makeQueue(...trackIds: string[]) {
  return [...trackIds]
}

type _e3 = Expect<Equal<typeof makeQueue, (...trackIds: string[]) => string[]>>

// Task 4 — one thing to SEE, one thing to FIX (lesson 03's void rule).
// SEE (the GIVEN block below): the second pushed listener has an
// expression body, so it RETURNS a string — yet PlayListener's `=> void`
// accepts it. In a function TYPE, void means "any return value will be
// ignored", which is what lets terse arrows live in listener arrays.
// FIX: emitPlay claimed `: number` but returns nothing. It's fire-and-
// forget, and the honest annotation for fire-and-forget is `: void`.

export type PlayListener = (play: Play) => void

// GIVEN — complete and correct. The second listener returns a string and
// still satisfies `=> void` — the quirk to SEE, not a bug to fix.
export const playListeners: PlayListener[] = []

const recentTrackIds: string[] = []
playListeners.push((play) => {
  recentTrackIds.push(play.trackId)
})
playListeners.push((play) => play.trackId)

export function emitPlay(play: Play): void {
  for (const listener of playListeners) {
    listener(play)
  }
}

type _e4 = Expect<Equal<typeof emitPlay, (play: Play) => void>>

// Task 5 — assertNever only ever throws, but a function DECLARATION with
// no annotation infers `void`, not `never` (lesson 03: "returns, carrying
// nothing" is a lie here — it never returns at all). One `: never`
// annotation cleared two errors at once: the assertion on assertNever's
// own type, and the reducer's default branch below, where a void result
// could not be handed back as PlayerState. Annotate the truth once and
// the whole cascade collapses.

export function assertNever(value: never): never {
  throw new Error(`Unhandled action: ${JSON.stringify(value)}`)
}

type _e5 = Expect<Equal<typeof assertNever, (value: never) => never>>

// Task 6 — the exhaustiveness guard did its job (lesson 04). With "seek"
// missing, `action` in the default branch was still { type: "seek";
// positionSec: number } — not never — and the error message literally
// named the case we forgot. Seeking while stopped is a no-op (no track,
// no needle to move); otherwise we narrow on state.status, spread the
// current state, and overwrite positionSec. Stage 07 hands this exact
// reducer to useReducer — the compiler's to-do list becomes your
// state machine's completeness proof.

export function playerReducer(state: PlayerState, action: PlayerAction): PlayerState {
  switch (action.type) {
    case "play":
      return { status: "playing", track: action.track, positionSec: 0 }
    case "pause":
      return state.status === "playing"
        ? { status: "paused", track: state.track, positionSec: action.positionSec }
        : state
    case "seek":
      return state.status === "stopped" ? state : { ...state, positionSec: action.positionSec }
    case "stop":
      return { status: "stopped" }
    default:
      return assertNever(action)
  }
}

// Task 7 — lastOf was always correct; the CALL had nothing to infer from
// (lesson 06). An empty array literal gives inference zero elements to
// look at, so T fell to `never`. Passing the type argument explicitly —
// lastOf<Track>([]) — tells the compiler what the queue WOULD hold. The
// second call below needs no help: seedTracks carries its element type.

// GIVEN — complete and correct.
export function lastOf<T>(items: T[]): T | undefined {
  return items[items.length - 1]
}

const nothingPlaying = lastOf<Track>([])
const lastSeeded = lastOf(seedTracks)

type _e7 = Expect<Equal<typeof nothingPlaying, Track | undefined>>

// Task 8 — the canonical lookup pattern (lesson 06). Record<string,
// unknown> flattened every property to unknown, so the plucked durations
// lost their number-ness on the way out. <T, K extends keyof T> ties the
// two parameters together: K must be a real key of T, and the return type
// T[K][] is the exact type living at that key. The body never changed —
// only the signature learned to tell the truth about it.

export function pluck<T, K extends keyof T>(items: T[], key: K): T[K][] {
  return items.map((item) => item[key])
}

const durations = pluck(seedTracks, "durationSec")

type _e8 = Expect<Equal<typeof durations, number[]>>

// ---------------------------------------------------------------------------
check("announce the opener", announceTrack(seedTracks[0]), "♪ Weird Fishes/Arpeggi")
check("a custom prefix still works", announceTrack(seedTracks[2], "now spinning: "), "now spinning: So What")
check("null means nothing is playing", describePosition(null), "not playing")
check("position zero is real data", describePosition(0), "0s in")
check("mid-track position reads naturally", describePosition(42), "42s in")
check("the queue gathers every id", makeQueue("t1", "t4", "t2"), ["t1", "t4", "t2"])
check("an empty queue is fine too", makeQueue(), [])

emitPlay({ trackId: "t2", playedAt: new Date("2026-07-10T08:12:00Z"), source: "playlist" })
check("listeners heard the play", recentTrackIds, ["t2"])

const playing = playerReducer({ status: "stopped" }, { type: "play", track: seedTracks[0] })
check("play starts from the top", playing.status === "playing" ? playing.positionSec : -1, 0)
const paused = playerReducer(playing, { type: "pause", positionSec: 45 })
check("pause remembers the position", paused.status === "paused" ? paused.positionSec : -1, 45)
const sought = playerReducer(paused, { type: "seek", positionSec: 120 })
check("seek moves the needle", sought.status === "paused" ? sought.positionSec : -1, 120)
check("seeking while stopped is a no-op", playerReducer({ status: "stopped" }, { type: "seek", positionSec: 10 }).status, "stopped")
check("stop clears the deck", playerReducer(sought, { type: "stop" }).status, "stopped")

check("an empty crate has no last track", nothingPlaying, undefined)
check("the last seeded track", lastSeeded?.title, "Alright")
check("plucked durations keep their type", durations, [318, 244, 562, 264, 219])
summary()
export {}
