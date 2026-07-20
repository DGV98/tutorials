/**
 * Lesson 01 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// Exercise 1 — the annotations promised string/number/boolean, so supply
// values of those types.

const username: string = "davidgonzalez"
const loginCount: number = 14
const isActive: boolean = true

check("username is a string", typeof username, "string")
check("loginCount is a number", typeof loginCount, "number")
check("isActive is a boolean", typeof isActive, "boolean")

// Exercise 2 — the values were right, the annotations lied. For
// declare-now-assign-later variables, the annotation is the contract.

let sessionToken: string
let retryLimit: number

sessionToken = "abc-123"
retryLimit = 3

type _e2a = Expect<Equal<typeof sessionToken, string>>
type _e2b = Expect<Equal<typeof retryLimit, number>>

// Exercise 3 — with the `any` annotations deleted, inference kicks in.
// `let version` widens to number (it could be reassigned); `const appName`
// infers the LITERAL type "inbox-zero" (it can never change).

const appName = "inbox-zero"
let version = 2
const tags = ["email", "productivity"]

type _e3a = Expect<Equal<typeof version, number>>
type _e3b = Expect<Equal<typeof tags, string[]>>
type _e3c = Expect<Equal<typeof appName, "inbox-zero">>

// Exercise 4 — a bare `[]` has no element type, so TypeScript lets it
// "evolve" — the string push silently widened it to (string | number)[].
// Annotating number[] pins the type, which then CATCHES the bad push.

const pendingIds: number[] = []
pendingIds.push(101)
pendingIds.push(102)

type _e4 = Expect<Equal<typeof pendingIds, number[]>>
check("two ids are pending", pendingIds.length, 2)

// Exercise 5 — the function required a number; the fix belongs at the call
// site. "Type 'string' is not assignable to type 'number'" = you gave a
// string where a number belongs.

function formatPlayCount(count: number) {
  return `played ${count} times`
}

const label = formatPlayCount(42)

check("label is built from a number", label, "played 42 times")

summary()
export {}
