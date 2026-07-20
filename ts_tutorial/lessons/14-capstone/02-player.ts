/**
 * Capstone stage 02 — The player state machine: functions, unions, generics.
 *
 * This file intentionally does not type-check. It is stage 2 of 8 of ONE
 * app — Heavy Rotation — and it builds the player that stage 07 wires into
 * React. Work the stages in order (01 before this one), and within this
 * file work top to bottom until `./check 14` reports no errors mentioning
 * `02-`.
 *
 * Then run it:  npx tsx lessons/14-capstone/02-player.ts
 *
 * Never edit lines containing Expect<Equal<...>> — they are the assertions
 * you're satisfying. Never touch GIVEN-marked blocks — they are complete
 * and correct.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"
import type { Track, Play } from "./01-domain"
import { seedTracks } from "./01-domain"

// ---------------------------------------------------------------------------
// GIVEN — the player's vocabulary. Complete and correct. DO NOT EDIT:
// stage 07 imports these exact unions to drive useReducer, so every shape
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

// ---------------------------------------------------------------------------
// Task 1 — Annotate the parameters (lesson 03).
// Both params are implicit any — there's no value to infer from at a
// declaration. Annotate `track` as Track. For `prefix`, don't just
// annotate: give it a DEFAULT of "♪ " so the bare announceTrack call in
// the harness below compiles. Hover prefix after the fix and see `string`.
// Leave the return type inferred.
// ---------------------------------------------------------------------------

export function announceTrack(track, prefix) {
  return `${prefix}${track.title}`
}

type _e1 = Expect<Equal<typeof announceTrack, (track: Track, prefix?: string) => string>>

// ---------------------------------------------------------------------------
// Task 2 — Honor the contract, then dodge the zero trap (lessons 03 + 04).
// The `: string` annotation is a promise the last return breaks — fix the
// BODY with a template literal (`${...}s in`); do NOT loosen the contract.
// Then run `npx tsx` on this file: the "position zero is real data" check
// fails, because `!positionSec` swallows 0 and the very start of a track
// is real data. Compare against null EXPLICITLY.
// ---------------------------------------------------------------------------

export function describePosition(positionSec: number | null): string {
  if (!positionSec) return "not playing"
  return positionSec
}

// ---------------------------------------------------------------------------
// Task 3 — Annotate the rest parameter (lesson 03).
// A rest parameter gathers its arguments into a real array, so its
// annotation must be an ARRAY type — right now it's an implicit any[].
// Annotate it; every call below already passes bare strings.
// ---------------------------------------------------------------------------

export function makeQueue(...trackIds) {
  return [...trackIds]
}

type _e3 = Expect<Equal<typeof makeQueue, (...trackIds: string[]) => string[]>>

// ---------------------------------------------------------------------------
// Task 4 — void: one thing to SEE, one thing to FIX (lesson 03).
// SEE (in the GIVEN block): the second pushed listener RETURNS a string,
// yet `=> void` accepts it — in a function TYPE, void means "any return
// value will be ignored". That line is legal; do NOT change it.
// FIX: emitPlay claims to return a number but returns nothing. It's
// fire-and-forget — fix its return ANNOTATION.
// ---------------------------------------------------------------------------

export type PlayListener = (play: Play) => void

// GIVEN — complete and correct. The second listener returns a string and
// still satisfies `=> void` — the quirk to SEE, not a bug to fix.
export const playListeners: PlayListener[] = []

const recentTrackIds: string[] = []
playListeners.push((play) => {
  recentTrackIds.push(play.trackId)
})
playListeners.push((play) => play.trackId)

export function emitPlay(play: Play): number {
  for (const listener of playListeners) {
    listener(play)
  }
}

type _e4 = Expect<Equal<typeof emitPlay, (play: Play) => void>>

// ---------------------------------------------------------------------------
// Task 5 — Annotate `never` and watch the cascade collapse (lesson 03).
// assertNever only ever throws, but an un-annotated function DECLARATION
// infers `void` — a lie that breaks TWO places: the assertion below, and
// the reducer's default branch further down (void is not a PlayerState).
// Add ONE return annotation here; both errors disappear.
// ---------------------------------------------------------------------------

export function assertNever(value: never) {
  throw new Error(`Unhandled action: ${JSON.stringify(value)}`)
}

type _e5 = Expect<Equal<typeof assertNever, (value: never) => never>>

// ---------------------------------------------------------------------------
// Task 6 — The compiler's to-do list (lesson 04).
// The signature and the play/pause/stop cases are GIVEN and correct. Even
// after Task 5, the default branch still errors: `action` there is
// { type: "seek"; ... }, not never — the switch forgot a case. Add it:
// seeking while stopped is a no-op (return state); otherwise spread the
// state and overwrite positionSec. Do NOT edit the default branch — it is
// the exhaustiveness guard doing its job.
// ---------------------------------------------------------------------------

export function playerReducer(state: PlayerState, action: PlayerAction): PlayerState {
  switch (action.type) {
    case "play":
      return { status: "playing", track: action.track, positionSec: 0 }
    case "pause":
      return state.status === "playing"
        ? { status: "paused", track: state.track, positionSec: action.positionSec }
        : state
    case "stop":
      return { status: "stopped" }
    default:
      return assertNever(action)
  }
}

// ---------------------------------------------------------------------------
// Task 7 — Explicit type arguments (lesson 06).
// lastOf is GIVEN and already correctly generic — the problem is the CALL.
// An empty array literal gives inference nothing to look at, so T falls to
// `never`. Pass the type argument explicitly at the call site: the empty
// queue WOULD hold Tracks. Don't touch the function or the second call.
// ---------------------------------------------------------------------------

// GIVEN — complete and correct.
export function lastOf<T>(items: T[]): T | undefined {
  return items[items.length - 1]
}

const nothingPlaying = lastOf([])
const lastSeeded = lastOf(seedTracks)

type _e7 = Expect<Equal<typeof nothingPlaying, Track | undefined>>

// ---------------------------------------------------------------------------
// Task 8 — The canonical lookup pattern (lesson 06).
// pluck returns unknown for every property, so the plucked durations lose
// their number-ness. Rewrite the SIGNATURE using the lookup shape —
// <T, K extends keyof T>(items: T[], key: K): T[K][] — the body is already
// correct. Don't touch the call sites.
// ---------------------------------------------------------------------------

export function pluck(items: Record<string, unknown>[], key: string): unknown[] {
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
