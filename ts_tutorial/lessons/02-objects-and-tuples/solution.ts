/**
 * Lesson 02 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// Exercise 1 — the alias is a contract: every property present, every value
// the declared type. "387" and "no" were strings cosplaying as a number and
// a boolean; the annotation caught both.

type Track = {
  title: string
  durationSeconds: number
  explicit: boolean
}

const track: Track = {
  title: "Paranoid Android",
  durationSeconds: 387,
  explicit: false,
}

check("duration is a number", typeof track.durationSeconds, "number")
check("explicit is a boolean", typeof track.explicit, "boolean")

// Exercise 2 — `?` marks a property allowed-to-be-absent, which is why
// `fresh` is now legal. The flip side: the property reads back as
// `string | undefined`, so every USE must handle the missing case — that's
// what `??` does below. Declare less, get forced to check more: a good deal.

type Profile = {
  username: string
  displayName?: string
  avatarUrl?: string
}

const fresh: Profile = { username: "dgonzalez" }
const complete: Profile = {
  username: "ada",
  displayName: "Ada Lovelace",
  avatarUrl: "https://example.com/ada.png",
}

type _e2 = Expect<Equal<typeof fresh.avatarUrl, string | undefined>>

check("fresh profile falls back to username", fresh.displayName ?? fresh.username, "dgonzalez")
check("complete profile uses displayName", complete.displayName ?? complete.username, "Ada Lovelace")

// Exercise 3 — the fix is deleting `session.startedAt = "2026-07-10"`.
// readonly blocks assignment THROUGH this reference; it never blocks
// building a new object. If a "changed" session were genuinely needed:
//
//   const rebooted: Session = { ...session, startedAt: "2026-07-10" }
//
// Spread-into-a-fresh-object is exactly how React state updates work
// (lesson 12), so this reflex pays off later.

type Session = {
  readonly userId: number
  readonly startedAt: string
  page: string
}

const session: Session = { userId: 42, startedAt: "2026-07-09", page: "/home" }

session.page = "/settings"

check("page navigation is allowed", session.page, "/settings")
check("startedAt never changes", session.startedAt, "2026-07-09")

// Exercise 4 — fresh literals get the strict excess-property check: an
// unknown property there can never be read by anyone, so it's assumed to be
// a typo (TypeScript even suggested: did you mean 'tone'?). `fromCms` sails
// through WITH its extra `priority`, because via a variable, structural
// typing only requires the shape to INCLUDE what BadgeProps asks for.

type BadgeProps = {
  label: string
  tone?: string
}

function renderBadge(props: BadgeProps): string {
  return props.tone ? `[${props.label}:${props.tone}]` : `[${props.label}]`
}

const a = renderBadge({ label: "New", tone: "green" })

const fromCms = { label: "Sale", priority: 2 }
const b = renderBadge(fromCms)

check("typo fixed, tone applied", a, "[New:green]")
check("wider object accepted as-is", b, "[Sale]")

// Exercise 5 — object types nest: wherever a property's type goes, another
// object type can go. Inline nesting (below) and composing named aliases
// (e.g. a separate `type Coordinates`) produce the SAME type — name the
// pieces you'd reuse, inline the rest.

type ApiUser = {
  id: number
  email: string
  address: {
    city: string
    postcode: string
    coordinates: { lat: number; lng: number }
  }
}

const user: ApiUser = {
  id: 7,
  email: "ada@example.com",
  address: {
    city: "London",
    postcode: "EC1A",
    coordinates: { lat: 51.5, lng: -0.1 },
  },
}

type _e5a = Expect<Equal<typeof user.address.city, string>>
type _e5b = Expect<Equal<typeof user.address.coordinates.lat, number>>

check("city is one level down", user.address.city, "London")
check("lat is two levels down", user.address.coordinates.lat, 51.5)

// Exercise 6 — a bare array literal infers an ARRAY, (string | number)[]:
// TypeScript assumes you might push, pop, and reorder, so it won't guess
// tuple. The annotation pins the length and per-position types, and
// destructuring then recovers `string` and `number` individually.
// (Lesson 07's `as const` is the other route to tuple inference.)

const row: [string, number] = ["Paranoid Android", 387]

type _e6a = Expect<Equal<typeof row, [string, number]>>

const [songTitle, playCount] = row

type _e6b = Expect<Equal<typeof songTitle, string>>
type _e6c = Expect<Equal<typeof playCount, number>>

check("position 0 is the title", songTitle, "Paranoid Android")
check("position 1 is the count", playCount, 387)

// Exercise 7 — two features doing their jobs: per-position types caught the
// string in the blue channel, and readonly turned the in-place mutation into
// "Cannot assign to '0' because it is a read-only property". The mutating
// line is deleted; `lighter` was already the right move — read the parts,
// build a NEW tuple. (The labels red/green/blue are documentation only:
// hover `brand[0]` and you'll see them in the tooltip.)

type Rgb = readonly [red: number, green: number, blue: number]

const brand: Rgb = [59, 130, 246]

const lighter: Rgb = [brand[0] + 9, brand[1] + 9, brand[2] + 9]

check("brand color is untouched", brand, [59, 130, 246])
check("lighter is a new tuple", lighter, [68, 139, 255])

summary()
export {}
