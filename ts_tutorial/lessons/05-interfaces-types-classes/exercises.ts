/**
 * Lesson 05 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 05` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * Then run it:  npx tsx lessons/05-interfaces-types-classes/exercises.ts
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// ---------------------------------------------------------------------------
// Exercise 1 — The interface is the contract; the object breaks it.
// `Track` is correct — don't touch it. Fix the object literal: one property
// has the wrong type (durations are stored in SECONDS, and 6:23 is 383 of
// them), and one required property is missing entirely (this track is not
// explicit).
// ---------------------------------------------------------------------------

interface Track {
  title: string
  durationSec: number
  explicit: boolean
}

const paranoid: Track = {
  title: "Paranoid Android",
  durationSec: "6:23",
}

check("duration is stored in seconds", paranoid.durationSec, 383)
check("explicit flag is present", paranoid.explicit, false)

// ---------------------------------------------------------------------------
// Exercise 2 — Don't copy fields; extend.
// A StudioAlbum is everything an Album is, PLUS a label. Whoever declared
// `StudioAlbum` forgot that. Fix the INTERFACE DECLARATION (one keyword!) —
// leave `Album`, the object literal, and `formatAlbum` alone.
// ---------------------------------------------------------------------------

interface Album {
  title: string
  artist: string
  year: number
}

function formatAlbum(album: Album): string {
  return `${album.artist} — ${album.title} (${album.year})`
}

interface StudioAlbum {
  label: string
}

const okComputer: StudioAlbum = {
  title: "OK Computer",
  artist: "Radiohead",
  year: 1997,
  label: "Parlophone",
}

type _e2 = Expect<Equal<StudioAlbum["year"], number>>

check(
  "a StudioAlbum is accepted anywhere an Album is",
  formatAlbum(okComputer),
  "Radiohead — OK Computer (1997)",
)

// ---------------------------------------------------------------------------
// Exercise 3 — Intersections combine type aliases.
// An AdminUser must be a User AND have Permissions. Fix ONLY the AdminUser
// alias, using `&`. Leave User, Permissions, and the object literal alone.
// ---------------------------------------------------------------------------

type User = {
  id: string
  displayName: string
}

type Permissions = {
  canBan: boolean
  canEditPosts: boolean
}

type AdminUser = User

const moderator: AdminUser = {
  id: "u_31",
  displayName: "dgonz",
  canBan: true,
  canEditPosts: false,
}

type _e3 = Expect<Equal<AdminUser, User & Permissions>>

check("moderator can ban", moderator.canBan, true)

// ---------------------------------------------------------------------------
// Exercise 4 — A conflicting intersection makes `never`.
// Two teams described the same track; gluing their types with `&` made
// SyncedTrack["id"] into `never` (hover it!) because string & number has no
// possible value. Server ids are strings like "t_9" — fix LocalTrack so the
// two sides AGREE. Don't touch ServerTrack, SyncedTrack, or the literal.
// ---------------------------------------------------------------------------

type ServerTrack = {
  id: string
  title: string
}

type LocalTrack = {
  id: number
  cachedAt: number
}

type SyncedTrack = ServerTrack & LocalTrack

const synced: SyncedTrack = {
  id: "t_9",
  title: "Nude",
  cachedAt: 1720000000,
}

type _e4 = Expect<Equal<SyncedTrack["id"], string>>

check("synced track keeps the server id", synced.id, "t_9")

// ---------------------------------------------------------------------------
// Exercise 5 — Class keywords are enforced, not decorative.
// Three problems, three fixes:
//   a. `tracks` is declared but never initialized — strict mode objects.
//      Give it an initializer (`= []`) right on the property.
//   b. The line below the constructor calls tries to RE-ID the playlist, but
//      `id` is readonly on purpose. It was MEANT to rename the playlist to
//      "Deep Focus" — assign to the right property instead.
//   c. The last check reaches into the private `tracks` field. Fix the
//      check's second argument to use the public `size()` method.
// The class's constructor uses parameter properties — that part is correct.
// ---------------------------------------------------------------------------

class Playlist {
  private tracks: string[]

  constructor(
    public readonly id: string,
    public name: string,
  ) {}

  add(track: string): void {
    this.tracks.push(track)
  }

  size(): number {
    return this.tracks.length
  }
}

const afternoon = new Playlist("pl-1", "Afternoon Focus")
afternoon.add("Weird Fishes")
afternoon.add("Pyramid Song")

afternoon.id = "pl-2"

// A class declares a type with the same name — no `interface Playlist` needed.
type _e5 = Expect<Equal<typeof afternoon, Playlist>>

check("playlist was renamed", afternoon.name, "Deep Focus")
check("playlist counts its tracks", afternoon.tracks.length, 2)

// ---------------------------------------------------------------------------
// Exercise 6 — `implements` is a promise; keep it.
// HttpError claims to implement WithStatus but never declares `status`, so
// the class errors AND `err.status` doesn't exist after narrowing. Fix the
// constructor using the parameter-property shorthand from exercise 5
// (status should be public and readonly). Don't touch WithStatus or
// describeError.
// ---------------------------------------------------------------------------

interface WithStatus {
  status: number
}

class HttpError extends Error implements WithStatus {
  constructor(message: string, status: number) {
    super(message)
  }
}

function describeError(err: Error): string {
  if (err instanceof HttpError) {
    // `instanceof` narrowed Error → HttpError (lesson 04's narrowing —
    // possible because classes, unlike interfaces, exist at runtime).
    type _e6 = Expect<Equal<typeof err, HttpError>>
    return `HTTP ${err.status} — ${err.message}`
  }
  return err.message
}

check(
  "http errors report their status",
  describeError(new HttpError("Not Found", 404)),
  "HTTP 404 — Not Found",
)
check("plain errors pass through", describeError(new Error("disk full")), "disk full")

// ---------------------------------------------------------------------------
summary()
export {}
