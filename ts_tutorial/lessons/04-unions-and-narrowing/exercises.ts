/**
 * Lesson 04 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 04` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * Then run it:  npx tsx lessons/04-unions-and-narrowing/exercises.ts
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// ---------------------------------------------------------------------------
// Exercise 1 — Prove which branch you hold.
// `id` might be a string OR a number, so `.toUpperCase()` is not allowed
// until you narrow. Use a `typeof` check: uppercase strings, and turn
// numbers into `#${id}`. Don't change the parameter's type.
// ---------------------------------------------------------------------------

function describeId(id: string | number): string {
  return id.toUpperCase()
}

check("string ids are uppercased", describeId("abc"), "ABC")
check("number ids get a hash", describeId(42), "#42")

// ---------------------------------------------------------------------------
// Exercise 2 — Literal unions, the React variant pattern.
// Two call sites are broken. Fix the typo in the first. For the second,
// `chosen` was declared so that it widens to `string` — change the
// DECLARATION so it keeps its literal type (lesson 01 says how; don't add
// an annotation, and don't touch the assertion).
// ---------------------------------------------------------------------------

type ButtonVariant = "primary" | "secondary" | "danger"

function buttonClass(variant: ButtonVariant): string {
  return `btn-${variant}`
}

const saveClass = buttonClass("primry")

let chosen = "secondary"
const cancelClass = buttonClass(chosen)

type _e2 = Expect<Equal<typeof chosen, "secondary">>
check("save button class", saveClass, "btn-primary")
check("cancel button class", cancelClass, "btn-secondary")

// ---------------------------------------------------------------------------
// Exercise 3 — Narrow out null. Carefully.
// The function doesn't compile: `count` is possibly null. Narrow the null
// away — but mind the trap: `if (!count)` type-checks AND makes the tests
// fail, because 0 is falsy and a count of zero is real data. Compare
// against null explicitly.
// ---------------------------------------------------------------------------

function formatCount(count: number | null): string {
  return `${count.toFixed(0)} items`
}

check("null means no data", formatCount(null), "no data")
check("zero is real data", formatCount(0), "0 items")
check("normal counts format", formatCount(12), "12 items")

// ---------------------------------------------------------------------------
// Exercise 4 — Narrow object shapes with `in`.
// `.name` is fine unnarrowed — it exists on BOTH shapes. `.email` is not.
// Use `"email" in contact` to branch: email contacts render as
// `Name <email>`, phone contacts as `Name (phone)`.
// ---------------------------------------------------------------------------

type EmailContact = { name: string; email: string }
type PhoneContact = { name: string; phone: string }

function contactLine(contact: EmailContact | PhoneContact): string {
  return `${contact.name} <${contact.email}>`
}

check("email contact", contactLine({ name: "Ada", email: "ada@lovelace.dev" }), "Ada <ada@lovelace.dev>")
check("phone contact", contactLine({ name: "Grace", phone: "555-0101" }), "Grace (555-0101)")

// ---------------------------------------------------------------------------
// Exercise 5 — Narrow class instances with `instanceof`.
// A failure might arrive as an Error object or a plain string. `typeof`
// can't tell classes apart (both are just "object"... and "string" only
// catches one branch) — use `instanceof Error` to extract `.message`, and
// pass plain strings through unchanged.
// ---------------------------------------------------------------------------

function errorText(failure: Error | string): string {
  return failure.message
}

check("Error instances expose .message", errorText(new Error("boom")), "boom")
check("plain strings pass through", errorText("wires crossed"), "wires crossed")

// ---------------------------------------------------------------------------
// Exercise 6 — The fetch state machine.
// The last return assumes success, but idle is still possible there, and
// idle has no `data`. Handle idle first (return "nothing yet") so control
// flow leaves only success at the last return. Don't touch the loading or
// error branches, or the assertion.
// (Try `npx tsx` on this file before fixing — it CRASHES right here at
// runtime. This type error is a real bug, caught before running.)
// ---------------------------------------------------------------------------

type FetchState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: string[] }
  | { status: "error"; message: string }

function renderResults(state: FetchState): string {
  if (state.status === "loading") return "spinner"
  if (state.status === "error") {
    // The discriminant check narrowed the WHOLE object — see for yourself:
    type _e6 = Expect<Equal<typeof state, { status: "error"; message: string }>>
    return `error: ${state.message}`
  }
  return `${state.data.length} results`
}

check("idle state", renderResults({ status: "idle" }), "nothing yet")
check("loading state", renderResults({ status: "loading" }), "spinner")
check("success state", renderResults({ status: "success", data: ["a", "b"] }), "2 results")
check("error state", renderResults({ status: "error", message: "offline" }), "error: offline")

// ---------------------------------------------------------------------------
// Exercise 7 — Exhaustiveness: the compiler's to-do list.
// This reducer-style switch (preview of lesson 12) forgot the "reset"
// action, so `action` is NOT `never` in the default block. Add the missing
// case (reset returns `action.to`). Do NOT edit the default block — it is
// the exhaustiveness guard doing its job.
// ---------------------------------------------------------------------------

type CounterAction =
  | { type: "increment" }
  | { type: "decrement" }
  | { type: "reset"; to: number }

function nextCount(current: number, action: CounterAction): number {
  switch (action.type) {
    case "increment":
      return current + 1
    case "decrement":
      return current - 1
    default: {
      const unhandled: never = action
      return unhandled
    }
  }
}

check("increment", nextCount(4, { type: "increment" }), 5)
check("decrement", nextCount(4, { type: "decrement" }), 3)
check("reset jumps to the target", nextCount(4, { type: "reset", to: 0 }), 0)

// ---------------------------------------------------------------------------
summary()
export {}
