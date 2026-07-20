/**
 * Capstone stage 01 — solution with commentary.
 *
 * Import rule: solution files import ONLY sibling solution files
 * (./01-domain), ../given/*, and ../../../helpers/* — NEVER ../NN-*
 * exercise files.
 */
import type { Expect, Equal } from "../../../helpers/type-assertions"
import { check, summary } from "../../../helpers/test"

// Task 1 — `: any` didn't just permit bad values, it threw away the literal
// type that const inference hands you for free (lesson 01). Delete the
// annotation and APP_NAME is "heavy-rotation" — not string, not any.
// defaultSource widened to string only because `let` promises reassignment;
// the fix is the declaration keyword, not an annotation.

export const APP_NAME = "heavy-rotation"
const defaultSource = "library"

type _e1a = Expect<Equal<typeof APP_NAME, "heavy-rotation">>
type _e1b = Expect<Equal<typeof defaultSource, "library">>

// Task 2 — the seed data was right; the TYPE was lying (lesson 01's "fix
// the annotations, not the values", scaled up to lesson 02 shapes).
// Durations are stored in seconds, so durationSec is a number, and only
// two tracks carry the explicit flag, so it's `explicit?:` — optional
// properties are how a type says "present sometimes, and that's fine".
// genre stays as the spelled-out union: stage 03 derives this exact union
// from a const array and cross-checks it against Track["genre"].

export type Track = {
  readonly id: string
  title: string
  artist: string
  album: string
  genre: "rock" | "electronic" | "hip-hop" | "jazz" | "ambient"
  durationSec: number
  explicit?: boolean
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
// GIVEN — the play log and the listener. Complete and correct.
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

// Task 3 — three small repairs, all lesson 02:
// (1) pl-2 legitimately has no description, so the property is optional —
//     fix the type to match the real data, not the other way around.
// (2) The line that reassigned seedPlaylists[0].id is simply GONE. `readonly`
//     means the compiler forbids that assignment forever — deleting the
//     mutation is the fix, exactly like lesson 02's session exercise.
// (3) renamePlaylist spelled the property `nmae`. Because the return value
//     is a FRESH object literal checked against Playlist, the excess-property
//     check caught the typo at the exact line it happened — the same shield
//     that will catch typo'd props in your JSX later. Note the body copies
//     with spread and never mutates; the runtime check below proves it.

export type Playlist = {
  readonly id: string
  name: string
  description?: string
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

export function renamePlaylist(playlist: Playlist, name: string): Playlist {
  return { ...playlist, name }
}

// GIVEN — complete and correct.
export function describePlaylist(p: Playlist): string {
  const base = `${p.name} · ${p.trackIds.length} tracks`
  return p.description ? `${base} — ${p.description}` : base
}

type _e3 = Expect<Equal<Playlist["description"], string | undefined>>

// Task 4 — the evolving-array footgun, deliberately re-armed (lesson 01).
// A bare `[]` has no element type, so each push quietly widened it — the
// 42 turned the queue into (string | number)[]. Annotating the DECLARATION
// as string[] pins the type, and the annotation then catches the bad push,
// which becomes a real track id.

const pendingTrackIds: string[] = []
pendingTrackIds.push("t3")
pendingTrackIds.push("t4")

type _e4 = Expect<Equal<typeof pendingTrackIds, string[]>>

// Task 5 — number[] says "any amount of numbers, reorder at will", which is
// not what [minutes, seconds] means at all. The labeled readonly tuple says
// exactly two positions, each with a name (hover a destructuring and the
// labels show up), and no mutation ever — which is why the sneaky
// `openerParts[0] = 99` line lit up the moment the type was fixed. It's
// deleted, not patched: lesson 02's rule is that readonly data gets replaced
// (a new tuple), never edited in place.

export type TimeParts = readonly [minutes: number, seconds: number]

// GIVEN — complete and correct.
export function toTimeParts(totalSec: number): TimeParts {
  return [Math.floor(totalSec / 60), totalSec % 60]
}

// GIVEN — complete and correct.
export function formatDuration(parts: TimeParts): string {
  const [minutes, seconds] = parts
  return `${minutes}:${String(seconds).padStart(2, "0")}`
}

const openerParts = toTimeParts(seedTracks[0].durationSec)
const [openerMinutes] = openerParts

type _e5 = Expect<Equal<TimeParts, readonly [number, number]>>
type _e5b = Expect<Equal<typeof openerMinutes, number>>

// Task 6 — the typo'd prop, caught at the call site (lesson 02). A fresh
// object literal is checked strictly against Playlist, so `descripton`
// produced "Did you mean to write 'description'?" — the error even named
// the fix. The function was always fine; the CALL was wrong.

const focusLabel = describePlaylist({
  id: "pl-9",
  name: "Focus",
  trackIds: [],
  description: "deep work",
})

// Task 7 — one keyword each (lesson 05).
// `extends Release` makes AlbumRelease inherit title and year instead of
// hand-copying them — the deluxe literal compiled the moment the interface
// admitted what it really is. And Curator = User & Permissions glues two
// type aliases into one shape with an intersection, so the curator literal's
// canEditPlaylists stops being an excess property and starts being required.

// GIVEN — complete and correct.
export interface Release {
  title: string
  year: number
}

export interface AlbumRelease extends Release {
  trackIds: string[]
}

// GIVEN — the data was always right.
const deluxe: AlbumRelease = {
  title: "In Rainbows",
  year: 2007,
  trackIds: ["t1"],
}

// GIVEN — complete and correct.
export type Permissions = { canEditPlaylists: boolean }

export type Curator = User & Permissions

// GIVEN — the data was always right.
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
