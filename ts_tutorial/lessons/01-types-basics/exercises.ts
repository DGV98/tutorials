/**
 * Lesson 01 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 01` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * Then run it:  npx tsx lessons/01-types-basics/exercises.ts
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// ---------------------------------------------------------------------------
// Exercise 1 — Fix the values, not the annotations.
// Each variable's annotation is correct; the values are wrong.
// ---------------------------------------------------------------------------

const username: string = "1019"
const loginCount: number = 14
const isActive: boolean = true

check("username is a string", typeof username, "string")
check("loginCount is a number", typeof loginCount, "number")
check("isActive is a boolean", typeof isActive, "boolean")

// ---------------------------------------------------------------------------
// Exercise 2 — Fix the annotations, not the values.
// These variables are declared first and assigned later — a case where
// annotations genuinely matter. But whoever wrote them lied about the types.
// The assigned values are correct; fix the annotations to match.
// ---------------------------------------------------------------------------

let sessionToken: string
let retryLimit: number

sessionToken = "abc-123"
retryLimit = 3

type _e2a = Expect<Equal<typeof sessionToken, string>>
type _e2b = Expect<Equal<typeof retryLimit, number>>

// ---------------------------------------------------------------------------
// Exercise 3 — Let inference work.
// Someone annotated everything here as `any`, throwing away all checking.
// Delete the annotations entirely and let TypeScript infer the types.
// ---------------------------------------------------------------------------

const appName = "inbox-zero"
let version: number = 2
const tags: string[] = ["email", "productivity"]

// Note the difference below: `version` is a `let`, so it infers the widened
// type number. `appName` is a `const`, so it infers the literal type
// "inbox-zero" — not string. Hover both and see.
type _e3a = Expect<Equal<typeof version, number>>
type _e3b = Expect<Equal<typeof tags, string[]>>
type _e3c = Expect<Equal<typeof appName, "inbox-zero">>

// ---------------------------------------------------------------------------
// Exercise 4 — Empty arrays need annotations.
// This queue must hold numbers only. But an empty `[]` says nothing, so
// TypeScript lets its type "evolve" with each push — hover pendingIds after
// the pushes and you'll see a string snuck in. Annotate the declaration as
// number[], then fix the push that violates it.
// ---------------------------------------------------------------------------

const pendingIds: number[] = []
pendingIds.push(101)
pendingIds.push(102)

type _e4 = Expect<Equal<typeof pendingIds, number[]>>
check("two ids are pending", pendingIds.length, 2)

// ---------------------------------------------------------------------------
// Exercise 5 — Read the error, fix the cause.
// The function is fine. The caller is wrong. Fix the CALL so the label reads
// "played 42 times" — and notice how the error message told you exactly
// this, in its backwards way: Type 'string' is not assignable to 'number'.
// ---------------------------------------------------------------------------

function formatPlayCount(count: number) {
  return `played ${count} times`
}

const label = formatPlayCount(42)

check("label is built from a number", label, "played 42 times")

// ---------------------------------------------------------------------------
summary()
export {}
