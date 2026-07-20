/**
 * Lesson 10 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 10` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * Then run it:  npx tsx lessons/10-boundaries-and-config/exercises.ts
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// ---------------------------------------------------------------------------
// Exercise 1 — `unknown` means "prove it first".
// This value came through JSON.parse, so it was honestly annotated `unknown`
// — and now the math below refuses to compile. Good. Add a typeof check that
// throws on bad data, so everything after it is proven to be a number.
// (No casts. No any.)
// ---------------------------------------------------------------------------

const stored: unknown = JSON.parse("21")

const doubled = stored * 2

type _e1 = Expect<Equal<typeof doubled, number>>
check("doubled the stored number", doubled, 42)

// ---------------------------------------------------------------------------
// Exercise 2 — `in` needs an object first.
// The `in` operator refuses to run on `unknown`: it only works on values
// already known to be objects. Extend the condition so it first proves
// articleRaw is an object — and remember the fossil: typeof null === "object",
// so you need a null check too.
// ---------------------------------------------------------------------------

const articleRaw: unknown = JSON.parse('{"id":7,"title":"Ship it","draft":false}')

let title = "untitled"
if ("title" in articleRaw && typeof articleRaw.title === "string") {
  title = articleRaw.title
}

type _e2 = Expect<Equal<typeof title, string>>
check("title was extracted from the payload", title, "Ship it")

// ---------------------------------------------------------------------------
// Exercise 3 — from boolean to type predicate.
// isUser already performs all the right runtime checks, but its return type
// `boolean` teaches the compiler nothing — so the guard below doesn't narrow
// and both lines inside the if are errors. Change the return type to a type
// predicate. Remember the responsibility that comes with it: from then on,
// the compiler trusts this body blindly.
// ---------------------------------------------------------------------------

type User = { id: number; name: string }

function isUser(x: unknown): boolean {
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

// ---------------------------------------------------------------------------
// Exercise 4 — the lying cast.
// The payload is {"count": 8} — count is a NUMBER. A hurried teammate
// silenced the compiler with `as`, but cast it to the wrong shape, and `as`
// verifies nothing — so the wrong type flowed downstream until the assertion
// caught it. Delete the cast: annotate the parse result as unknown and
// narrow it for real (object check, `in`, typeof — or reuse the pattern
// from exercise 3).
// ---------------------------------------------------------------------------

const countPayload = JSON.parse('{"count":8}') as { count: string }

const nextCount = countPayload.count + 1

type _e4 = Expect<Equal<typeof nextCount, number>>
check("counted up from a real number", nextCount, 9)

// ---------------------------------------------------------------------------
// Exercise 5 — possibly undefined, and the `!` trap.
// Map.get returns string | undefined — thank strictNullChecks for the
// warning. The tempting fix is the non-null assertion (accent!): it compiles,
// then crashes at runtime because "accent" was never set, and the runtime
// check below would expose you. Handle the miss honestly instead: fall back
// to "teal" with `??`.
// ---------------------------------------------------------------------------

const prefs = new Map<string, string>([["theme", "dark"]])

const accent = prefs.get("accent")
const accentUpper = accent.toUpperCase()

type _e5 = Expect<Equal<typeof accentUpper, string>>
check("missing accent falls back to teal", accentUpper, "TEAL")

// ---------------------------------------------------------------------------
// Exercise 6 — an array crosses the boundary.
// Two layers to prove here. First guard with Array.isArray (throw if it
// fails) — then hover idsRaw: you got any[], the ELEMENTS are still
// unverified, and the assertion below refuses any. Keep only genuine numbers
// with a filter whose callback is a type predicate:
//   .filter((x): x is number => ...)
// ---------------------------------------------------------------------------

const idsRaw: unknown = JSON.parse("[3, 1, 4, 1, 5]")

const total = idsRaw.reduce((sum, n) => sum + n, 0)

type _e6 = Expect<Equal<typeof total, number>>
check("the ids sum to 14", total, 14)

// ---------------------------------------------------------------------------
// Exercise 7 — your tsconfig speaks.
// verbatimModuleSyntax is ON in this project's tsconfig.json, so anything
// that is only a type must be imported with `import type`. NotEqual is a
// type, but this import claims it's a value — read the error; it names the
// flag. Fix the import statement.
// ---------------------------------------------------------------------------

import { NotEqual } from "../../helpers/type-assertions"

type _e7 = Expect<NotEqual<string, number>>

// ---------------------------------------------------------------------------
summary()
export {}
