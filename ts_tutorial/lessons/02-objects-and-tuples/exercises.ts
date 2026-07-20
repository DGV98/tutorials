/**
 * Lesson 02 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 02` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * Then run it:  npx tsx lessons/02-objects-and-tuples/exercises.ts
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// ---------------------------------------------------------------------------
// Exercise 1 — Match the shape.
// The Track alias is the contract, and it's correct. The object literal
// breaks it twice. Fix the VALUES, not the type.
// ---------------------------------------------------------------------------

type Track = {
  title: string
  durationSeconds: number
  explicit: boolean
}

const track: Track = {
  title: "Paranoid Android",
  durationSeconds: "387",
  explicit: "no",
}

check("duration is a number", typeof track.durationSeconds, "number")
check("explicit is a boolean", typeof track.explicit, "boolean")

// ---------------------------------------------------------------------------
// Exercise 2 — Make the optional fields optional.
// Every profile has a username; displayName and avatarUrl only exist once
// the user fills them in. BOTH objects below are valid profiles — fix the
// TYPE by adding `?` where it belongs. Don't touch the objects.
// ---------------------------------------------------------------------------

type Profile = {
  username: string
  displayName: string
  avatarUrl: string
}

const fresh: Profile = { username: "dgonzalez" }
const complete: Profile = {
  username: "ada",
  displayName: "Ada Lovelace",
  avatarUrl: "https://example.com/ada.png",
}

// Optional properties read back as `T | undefined` — code that uses them
// must handle the missing case, which the `??` below does.
type _e2 = Expect<Equal<typeof fresh.avatarUrl, string | undefined>>

check("fresh profile falls back to username", fresh.displayName ?? fresh.username, "dgonzalez")
check("complete profile uses displayName", complete.displayName ?? complete.username, "Ada Lovelace")

// ---------------------------------------------------------------------------
// Exercise 3 — Respect readonly.
// userId and startedAt identify this session forever, so they're readonly —
// the type is correct. Updating `page` is fine and should stay. Delete the
// line that "refreshes" startedAt; it was never allowed to.
// ---------------------------------------------------------------------------

type Session = {
  readonly userId: number
  readonly startedAt: string
  page: string
}

const session: Session = { userId: 42, startedAt: "2026-07-09", page: "/home" }

session.page = "/settings"
session.startedAt = "2026-07-10"

check("page navigation is allowed", session.page, "/settings")
check("startedAt never changes", session.startedAt, "2026-07-09")

// ---------------------------------------------------------------------------
// Exercise 4 — The typo'd prop.
// Call A passes a FRESH object literal, so TypeScript checks it strictly and
// catches the misspelled property — the exact error a typo'd React prop
// gives you. Fix the typo at the call site.
// Call B already compiles: `fromCms` arrives via a variable, and structural
// typing only asks "does it have a label?". Its extra property is fine —
// leave call B exactly as it is.
// ---------------------------------------------------------------------------

type BadgeProps = {
  label: string
  tone?: string
}

function renderBadge(props: BadgeProps): string {
  return props.tone ? `[${props.label}:${props.tone}]` : `[${props.label}]`
}

const a = renderBadge({ label: "New", tonee: "green" })

const fromCms = { label: "Sale", priority: 2 }
const b = renderBadge(fromCms)

check("typo fixed, tone applied", a, "[New:green]")
check("wider object accepted as-is", b, "[Sale]")

// ---------------------------------------------------------------------------
// Exercise 5 — Nest the type to match the data.
// The object below is copied verbatim from a real API response — the DATA is
// right. Whoever wrote ApiUser flattened `address` into a string. Fix the
// TYPE so it describes the real nested shape (an object inside an object).
// ---------------------------------------------------------------------------

type ApiUser = {
  id: number
  email: string
  address: string
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

// ---------------------------------------------------------------------------
// Exercise 6 — Tuple, not array.
// A row from a CSV import: position 0 is the title, position 1 is the play
// count. Hover `row`: a bare literal infers (string | number)[] — an array
// that has forgotten which position holds what, so destructuring gives every
// piece the type string | number. Annotate `row` as a tuple.
// ---------------------------------------------------------------------------

const row = ["Paranoid Android", 387]

type _e6a = Expect<Equal<typeof row, [string, number]>>

const [songTitle, playCount] = row

type _e6b = Expect<Equal<typeof songTitle, string>>
type _e6c = Expect<Equal<typeof playCount, number>>

check("position 0 is the title", songTitle, "Paranoid Android")
check("position 1 is the count", playCount, 387)

// ---------------------------------------------------------------------------
// Exercise 7 — Readonly tuples stay put.
// Rgb is a labeled readonly tuple: exactly three numbers, no mutation ever.
// Two bugs here: the blue channel is a string, and someone tried to lighten
// the color in place. Fix the bad channel; DELETE the mutating line —
// `lighter` below already builds the new color the right way, as a new tuple.
// ---------------------------------------------------------------------------

type Rgb = readonly [red: number, green: number, blue: number]

const brand: Rgb = [59, 130, "246"]

brand[0] = 89

const lighter: Rgb = [brand[0] + 9, brand[1] + 9, brand[2] + 9]

check("brand color is untouched", brand, [59, 130, 246])
check("lighter is a new tuple", lighter, [68, 139, 255])

// ---------------------------------------------------------------------------
summary()
export {}
