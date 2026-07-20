/**
 * Capstone stage 01 — The Crate: model the music library.
 *
 * This file intentionally does not type-check. It is stage 1 of 8 of ONE
 * app — Heavy Rotation — and every later stage imports what you fix here.
 * Work the stages in order (this one first), and within this file work top
 * to bottom until `./check 14` reports no errors mentioning `01-`.
 *
 * Then run it:  npx tsx lessons/14-capstone/01-domain.ts
 *
 * Never edit lines containing Expect<Equal<...>> — they are the assertions
 * you're satisfying. Never touch GIVEN-marked blocks — they are complete
 * and correct.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// ---------------------------------------------------------------------------
// Task 1 — Let inference work (lesson 01).
// Someone annotated APP_NAME as `any`, throwing away the literal type that
// const inference gives for free — DELETE the annotation, add nothing.
// And defaultSource widens to string because `let` promises reassignment:
// fix the DECLARATION (one keyword), not with an annotation. Hover both
// after each fix and watch the types tighten.
// ---------------------------------------------------------------------------

export const APP_NAME: any = "heavy-rotation"
let defaultSource = "library"

type _e1a = Expect<Equal<typeof APP_NAME, "heavy-rotation">>
type _e1b = Expect<Equal<typeof defaultSource, "library">>

// ---------------------------------------------------------------------------
// Task 2 — Fix the type, not the values (lessons 01 + 02).
// The five seed tracks below are copied straight from the crate — the DATA
// is right and UNTOUCHABLE. Whoever wrote Track stored durationSec as a
// string and made `explicit` required (only two tracks even carry the
// flag). Fix the TYPE: durationSec is a number, explicit is optional.
// The genre line is GIVEN — stage 03 derives that union; leave it alone.
// ---------------------------------------------------------------------------

export type Track = {
  readonly id: string
  title: string
  artist: string
  album: string
  genre: "rock" | "electronic" | "hip-hop" | "jazz" | "ambient"
  durationSec: string
  explicit: boolean
}

export const seedTracks: Track[] = [
  {
    id: "t1",
    title: "Weird Fishes/Arpeggi",
    artist: "Radiohead",
    album: "In Rainbows",
    genre: "rock",
    durationSec: 318,
  },
  {
    id: "t2",
    title: "Midnight City",
    artist: "M83",
    album: "Hurry Up, We're Dreaming",
    genre: "electronic",
    durationSec: 244,
    explicit: false,
  },
  {
    id: "t3",
    title: "So What",
    artist: "Miles Davis",
    album: "Kind of Blue",
    genre: "jazz",
    durationSec: 562,
  },
  {
    id: "t4",
    title: "An Ending (Ascent)",
    artist: "Brian Eno",
    album: "Apollo",
    genre: "ambient",
    durationSec: 264,
  },
  {
    id: "t5",
    title: "Alright",
    artist: "Kendrick Lamar",
    album: "To Pimp a Butterfly",
    genre: "hip-hop",
    durationSec: 219,
    explicit: true,
  },
]

type _e2 = Expect<Equal<Track, { readonly id: string; title: string; artist: string; album: string; genre: "rock" | "electronic" | "hip-hop" | "jazz" | "ambient"; durationSec: number; explicit?: boolean }>>

// ---------------------------------------------------------------------------
// GIVEN — the play log and the listener. Complete and correct; DO NOT EDIT.
// Stage 02 emits plays, stage 04 counts them, stage 08 puts them on the
// wire; stage 04 also builds PublicUser out of User.
// ---------------------------------------------------------------------------

export type Play = {
  trackId: string
  playedAt: Date
  source: "library" | "playlist" | "radio"
}

export const seedPlays: Play[] = [
  { trackId: "t1", playedAt: new Date("2026-07-08T21:04:00Z"), source: "library" },
  { trackId: "t2", playedAt: new Date("2026-07-09T07:30:00Z"), source: "playlist" },
  { trackId: "t4", playedAt: new Date("2026-07-09T23:45:00Z"), source: "radio" },
]

export type User = {
  readonly id: string
  handle: string
  email: string
  displayName?: string
}

const sampleUser: User = { id: "u1", handle: "dgonz", email: "dgonz@example.com" }

// ---------------------------------------------------------------------------
// Task 3 — Optional, readonly, and a typo in a fresh literal (lesson 02).
// Three fixes, in order: (1) pl-2 has no description and that's FINE —
// make the property optional in the TYPE (don't touch the data);
// (2) DELETE the line that reassigns seedPlaylists[0].id — ids are
// readonly forever; (3) renamePlaylist spells a property `nmae`, and the
// excess-property check on its fresh return literal caught it — fix the
// BODY. The runtime check below proves rename copies instead of mutating.
// ---------------------------------------------------------------------------

export type Playlist = {
  readonly id: string
  name: string
  description: string
  trackIds: string[]
}

export const seedPlaylists: Playlist[] = [
  {
    id: "pl-1",
    name: "Deep Focus",
    description: "Long-form concentration fuel",
    trackIds: ["t1", "t4"],
  },
  { id: "pl-2", name: "Morning Run", trackIds: ["t2", "t5"] },
]

seedPlaylists[0].id = "pl-99"

export function renamePlaylist(playlist: Playlist, name: string): Playlist {
  return { ...playlist, nmae: name }
}

// GIVEN — complete and correct; DO NOT EDIT.
export function describePlaylist(p: Playlist): string {
  const base = `${p.name} · ${p.trackIds.length} tracks`
  return p.description ? `${base} — ${p.description}` : base
}

type _e3 = Expect<Equal<Playlist["description"], string | undefined>>

// ---------------------------------------------------------------------------
// Task 4 — Empty arrays need annotations (lesson 01's footgun, re-armed).
// A bare `[]` has no element type, so it "evolves" with every push — hover
// pendingTrackIds after the pushes and a number has snuck into the queue.
// Annotate the DECLARATION as string[], then fix the push the annotation
// flags (queue "t4" instead).
// ---------------------------------------------------------------------------

const pendingTrackIds = []
pendingTrackIds.push("t3")
pendingTrackIds.push(42)

type _e4 = Expect<Equal<typeof pendingTrackIds, string[]>>

// ---------------------------------------------------------------------------
// Task 5 — Tuple, not array (lesson 02).
// TimeParts means [minutes, seconds]: exactly two positions, each with a
// meaning, never mutated. number[] says none of that. Rewrite the TYPE as
// a labeled readonly tuple — readonly [minutes: number, seconds: number].
// The fix makes the sneaky "adjustment" line below light up: DELETE it,
// readonly data gets replaced, never edited. toTimeParts and
// formatDuration are GIVEN — leave them alone.
// ---------------------------------------------------------------------------

export type TimeParts = number[]

// GIVEN — complete and correct; DO NOT EDIT.
export function toTimeParts(totalSec: number): TimeParts {
  return [Math.floor(totalSec / 60), totalSec % 60]
}

// GIVEN — complete and correct; DO NOT EDIT.
export function formatDuration(parts: TimeParts): string {
  const [minutes, seconds] = parts
  return `${minutes}:${String(seconds).padStart(2, "0")}`
}

const openerParts = toTimeParts(seedTracks[0].durationSec)
const [openerMinutes] = openerParts

openerParts[0] = 99

type _e5 = Expect<Equal<TimeParts, readonly [number, number]>>
type _e5b = Expect<Equal<typeof openerMinutes, number>>

// ---------------------------------------------------------------------------
// Task 6 — The typo'd prop, caught at the call site (lesson 02).
// describePlaylist is GIVEN and correct. The fresh object literal in this
// call misspells one property — read the error, it literally suggests the
// fix. Repair the CALL SITE; nothing else changes.
// ---------------------------------------------------------------------------

const focusLabel = describePlaylist({
  id: "pl-9",
  name: "Focus",
  trackIds: [],
  descripton: "deep work",
})

// ---------------------------------------------------------------------------
// Task 7 — One keyword each (lesson 05).
// (1) An AlbumRelease is everything a Release is PLUS trackIds — the
// interface forgot to say so. Fix the DECLARATION (one keyword!); leave
// Release and the deluxe literal alone.
// (2) A Curator is a User AND Permissions. Fix ONLY the Curator alias,
// using `&` — the curator literal was right all along.
// ---------------------------------------------------------------------------

// GIVEN — complete and correct; DO NOT EDIT.
export interface Release {
  title: string
  year: number
}

export interface AlbumRelease {
  trackIds: string[]
}

// GIVEN — the data is right; DO NOT EDIT.
const deluxe: AlbumRelease = {
  title: "In Rainbows",
  year: 2007,
  trackIds: ["t1"],
}

// GIVEN — complete and correct; DO NOT EDIT.
export type Permissions = { canEditPlaylists: boolean }

export type Curator = User

// GIVEN — the data is right; DO NOT EDIT.
const curator: Curator = {
  id: "u2",
  handle: "mixmaster",
  email: "mm@example.com",
  canEditPlaylists: true,
}

type _e7a = Expect<Equal<AlbumRelease["year"], number>>
type _e7b = Expect<Equal<Curator["canEditPlaylists"], boolean>>

// ---------------------------------------------------------------------------
check("the default source is the library", defaultSource, "library")
check("five tracks in the crate", seedTracks.length, 5)
check("three plays in the log", seedPlays.length, 3)
check("sample user answers to dgonz", sampleUser.displayName ?? sampleUser.handle, "dgonz")
const renamed = renamePlaylist(seedPlaylists[0], "Laser Focus")
check("rename returns the new name", renamed.name, "Laser Focus")
check("rename does not mutate the original", seedPlaylists[0].name, "Deep Focus")
check("two tracks are queued", pendingTrackIds.length, 2)
check("the opener runs 5:18", formatDuration(openerParts), "5:18")
check("single-digit seconds get padded", formatDuration([3, 5]), "3:05")
check("call-site typo fixed, description shows", focusLabel, "Focus · 0 tracks — deep work")
check("pl-2 reads fine without a description", describePlaylist(seedPlaylists[1]), "Morning Run · 2 tracks")
check("deluxe release inherits title and year", `${deluxe.title} (${deluxe.year})`, "In Rainbows (2007)")
check("curators can edit playlists", curator.canEditPlaylists, true)
summary()
export {}
