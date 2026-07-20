/**
 * Lesson 10 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// Exercise 1 — `unknown` blocks everything until you narrow. The typeof
// check + throw is the whole pattern: past that line, bad data cannot
// reach the math, so TypeScript lets the math through. Note the fix is a
// RUNTIME check — a cast would have compiled too, but proven nothing.

const stored: unknown = JSON.parse("21")

if (typeof stored !== "number") {
  throw new Error("expected a number in storage")
}
const doubled = stored * 2

type _e1 = Expect<Equal<typeof doubled, number>>
check("doubled the stored number", doubled, 42)

// Exercise 2 — `in` only runs on values already proven to be objects, so
// the object check comes first in the && chain (narrowing flows left to
// right). The `!== null` matters because typeof null === "object". After
// `"title" in articleRaw`, the property EXISTS but is typed unknown — the
// final typeof narrows it to string. Turtles all the way down.

const articleRaw: unknown = JSON.parse('{"id":7,"title":"Ship it","draft":false}')

let title = "untitled"
if (
  typeof articleRaw === "object" &&
  articleRaw !== null &&
  "title" in articleRaw &&
  typeof articleRaw.title === "string"
) {
  title = articleRaw.title
}

type _e2 = Expect<Equal<typeof title, string>>
check("title was extracted from the payload", title, "Ship it")

// Exercise 3 — the only change is the return type: boolean → `x is User`.
// Same runtime behavior, but now the compiler LEARNS from a true result and
// narrows `candidate` to User inside the if. The body is trusted, not
// verified — if it checked less than User's shape, downstream code would be
// typed as User while holding something else. Keep predicate bodies honest.

type User = { id: number; name: string }

function isUser(x: unknown): x is User {
  return (
    typeof x === "object" &&
    x !== null &&
    "id" in x &&
    typeof x.id === "number" &&
    "name" in x &&
    typeof x.name === "string"
  )
}

const candidate: unknown = JSON.parse('{"id":1,"name":"Ada"}')

if (isUser(candidate)) {
  type _e3 = Expect<Equal<typeof candidate, User>>
  check("the guarded user's name is usable", candidate.name, "Ada")
}

// Exercise 4 — the cast is deleted, replaced by unknown + a real guard.
// The early-throw style reads well at boundaries: each || clause narrows
// for the next one, and after the if, countPayload.count is a proven
// number. The lying cast compiled fine — that's the point: `as` silences,
// narrowing verifies.

const countPayload: unknown = JSON.parse('{"count":8}')

if (
  typeof countPayload !== "object" ||
  countPayload === null ||
  !("count" in countPayload) ||
  typeof countPayload.count !== "number"
) {
  throw new Error("malformed count payload")
}
const nextCount = countPayload.count + 1

type _e4 = Expect<Equal<typeof nextCount, number>>
check("counted up from a real number", nextCount, 9)

// Exercise 5 — `??` handles the miss and keeps the type honest:
// (string | undefined) ?? string = string. The non-null assertion would
// have satisfied the compiler too — and thrown "cannot read properties of
// undefined" at runtime, because "accent" genuinely isn't in the Map.
// strictNullChecks flagged a real bug here; don't gag it.

const prefs = new Map<string, string>([["theme", "dark"]])

const accent = prefs.get("accent")
const accentUpper = (accent ?? "teal").toUpperCase()

type _e5 = Expect<Equal<typeof accentUpper, string>>
check("missing accent falls back to teal", accentUpper, "TEAL")

// Exercise 6 — two proofs. Array.isArray gets unknown → any[] (hover it!),
// which is only HALF a proof: the elements are still unchecked, and the
// Equal assertion refuses any. The filter's type-predicate callback
// (`x is number`) is exercise 3 in miniature — it proves each element, so
// ids is number[] and reduce produces a real number.

const idsRaw: unknown = JSON.parse("[3, 1, 4, 1, 5]")

if (!Array.isArray(idsRaw)) {
  throw new Error("expected an array of ids")
}
const ids = idsRaw.filter((x): x is number => typeof x === "number")
const total = ids.reduce((sum, n) => sum + n, 0)

type _e6 = Expect<Equal<typeof total, number>>
check("the ids sum to 14", total, 14)

// Exercise 7 — `import type` is the fix. verbatimModuleSyntax makes the
// syntax itself declare what's erasable, so single-file transpilers (tsx,
// Next's swc) can strip types without reading other files. (In real code
// this import would live at the top of the file; it stays here to mirror
// the exercise.)

import type { NotEqual } from "../../helpers/type-assertions"

type _e7 = Expect<NotEqual<string, number>>

summary()
export {}
