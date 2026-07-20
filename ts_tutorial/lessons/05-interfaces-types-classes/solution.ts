/**
 * Lesson 05 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// Exercise 1 — an interface is a contract for a shape. The literal owed a
// number for durationSec (you gave a string where a number belongs) and was
// missing `explicit` entirely — missing required properties are errors too.

interface Track {
  title: string
  durationSec: number
  explicit: boolean
}

const paranoid: Track = {
  title: "Paranoid Android",
  durationSec: 383,
  explicit: false,
}

check("duration is stored in seconds", paranoid.durationSec, 383)
check("explicit flag is present", paranoid.explicit, false)

// Exercise 2 — `extends Album` folds all of Album's members into
// StudioAlbum. That fixed everything at once: the "excess" properties in the
// literal became expected, StudioAlbum["year"] came into existence, and —
// structural typing — formatAlbum now accepts a StudioAlbum, because it has
// everything an Album has.

interface Album {
  title: string
  artist: string
  year: number
}

function formatAlbum(album: Album): string {
  return `${album.artist} — ${album.title} (${album.year})`
}

interface StudioAlbum extends Album {
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

// Exercise 3 — `&` is how TYPE ALIASES combine shapes (extends is interface
// syntax). `User & Permissions` means "both at once": all four properties
// required. This is exercise 2's idea with the other keyword — same shape
// either way, which is the point of the interface-vs-type comparison.

type User = {
  id: string
  displayName: string
}

type Permissions = {
  canBan: boolean
  canEditPosts: boolean
}

type AdminUser = User & Permissions

const moderator: AdminUser = {
  id: "u_31",
  displayName: "dgonz",
  canBan: true,
  canEditPosts: false,
}

type _e3 = Expect<Equal<AdminUser, User & Permissions>>

check("moderator can ban", moderator.canBan, true)

// Exercise 4 — string & number has no possible value, so the broken
// intersection quietly made id: never, and NOTHING could be assigned to it.
// The fix belongs at the source of the disagreement: make LocalTrack's id a
// string so the intersection reduces to string & string = string. (Had these
// been interfaces, `extends` would have flagged the conflict at the
// declaration instead of waiting for a use site.)

type ServerTrack = {
  id: string
  title: string
}

type LocalTrack = {
  id: string
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

// Exercise 5 —
//  a. Strict mode demands every property be initialized; `= []` on the
//     declaration is the idiomatic fix for collections.
//  b. `readonly id` means set-once-in-the-constructor. The rename belongs on
//     the mutable `name` property.
//  c. `private tracks` is invisible outside the class — the public size()
//     method IS the API. Note the constructor's parameter properties:
//     `public readonly id: string` declares AND assigns in one stroke.

class Playlist {
  private tracks: string[] = []

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

afternoon.name = "Deep Focus"

// The class declaration produced this type for free — `typeof afternoon` is
// Playlist, and Playlist works anywhere a type annotation does.
type _e5 = Expect<Equal<typeof afternoon, Playlist>>

check("playlist was renamed", afternoon.name, "Deep Focus")
check("playlist counts its tracks", afternoon.size(), 2)

// Exercise 6 — `public readonly status: number` in the parameter list both
// declares the property and assigns it, which satisfies `implements
// WithStatus` (a check, not an inheritance) AND gives the narrowed `err`
// a real `.status`. This custom-Error-plus-instanceof pattern is the main
// reason you'll write classes in React/Next.js server code.

interface WithStatus {
  status: number
}

class HttpError extends Error implements WithStatus {
  constructor(
    message: string,
    public readonly status: number,
  ) {
    super(message)
  }
}

function describeError(err: Error): string {
  if (err instanceof HttpError) {
    // Inside this branch err is HttpError, not Error — instanceof narrowing
    // works because the class exists at runtime (interfaces are erased).
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

summary()
export {}
