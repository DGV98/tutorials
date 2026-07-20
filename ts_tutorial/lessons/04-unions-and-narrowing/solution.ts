/**
 * Lesson 04 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// Exercise 1 — before the check, `id` is string | number and only common
// members are usable. `typeof id === "string"` proves the branch; after the
// early return, control flow leaves only number — no `else` needed.

function describeId(id: string | number): string {
  if (typeof id === "string") {
    return id.toUpperCase()
  }
  return `#${id}` // id: number here — hover it
}

check("string ids are uppercased", describeId("abc"), "ABC")
check("number ids get a hash", describeId(42), "#42")

// Exercise 2 — "primry" isn't one of the three literals, so the typo was a
// compile error (this is why variant props are literal unions). And `let`
// widened chosen to `string`; `const` keeps the literal type "secondary",
// which is assignable to ButtonVariant AND satisfies the assertion.

type ButtonVariant = "primary" | "secondary" | "danger"

function buttonClass(variant: ButtonVariant): string {
  return `btn-${variant}`
}

const saveClass = buttonClass("primary")

const chosen = "secondary"
const cancelClass = buttonClass(chosen)

type _e2 = Expect<Equal<typeof chosen, "secondary">>
check("save button class", saveClass, "btn-primary")
check("cancel button class", cancelClass, "btn-secondary")

// Exercise 3 — `count === null` narrows precisely: only null takes the
// early return, so 0 flows through to the format line. The tempting
// `if (!count)` also type-checks — but it swallows 0 and the "zero is real
// data" runtime check catches it. Types can't see every bug; tests still
// matter.

function formatCount(count: number | null): string {
  if (count === null) return "no data"
  return `${count.toFixed(0)} items` // count: number — null is gone
}

check("null means no data", formatCount(null), "no data")
check("zero is real data", formatCount(0), "0 items")
check("normal counts format", formatCount(12), "12 items")

// Exercise 4 — `.name` never needed narrowing (it's on both shapes).
// `"email" in contact` narrows to EmailContact in the branch, and — by
// elimination — PhoneContact after it.

type EmailContact = { name: string; email: string }
type PhoneContact = { name: string; phone: string }

function contactLine(contact: EmailContact | PhoneContact): string {
  if ("email" in contact) {
    return `${contact.name} <${contact.email}>`
  }
  return `${contact.name} (${contact.phone})`
}

check("email contact", contactLine({ name: "Ada", email: "ada@lovelace.dev" }), "Ada <ada@lovelace.dev>")
check("phone contact", contactLine({ name: "Grace", phone: "555-0101" }), "Grace (555-0101)")

// Exercise 5 — `instanceof` narrows by prototype chain, which is what you
// need for class instances like Error. (Narrowing the OTHER branch with
// `typeof failure === "string"` would also have worked — by elimination.)

function errorText(failure: Error | string): string {
  if (failure instanceof Error) {
    return failure.message
  }
  return failure // failure: string here
}

check("Error instances expose .message", errorText(new Error("boom")), "boom")
check("plain strings pass through", errorText("wires crossed"), "wires crossed")

// Exercise 6 — each discriminant check eliminates one union member, so
// after handling loading, error, AND idle, control flow has proved the
// last return only ever sees success — `.data` is safe with no cast and
// no `if` around it.

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
  if (state.status === "idle") return "nothing yet"
  return `${state.data.length} results` // state: the success member only
}

check("idle state", renderResults({ status: "idle" }), "nothing yet")
check("loading state", renderResults({ status: "loading" }), "spinner")
check("success state", renderResults({ status: "success", data: ["a", "b"] }), "2 results")
check("error state", renderResults({ status: "error", message: "offline" }), "error: offline")

// Exercise 7 — with "reset" handled, every member of CounterAction is
// eliminated by a case, so `action` really is `never` in the default and
// the guard compiles. Add a fourth action tomorrow and this default errors
// again — exactly where the code must change. Lesson 12 builds useReducer
// on this pattern.

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
    case "reset":
      return action.to // narrowed: only "reset" carries `to`
    default: {
      const unhandled: never = action
      return unhandled
    }
  }
}

check("increment", nextCount(4, { type: "increment" }), 5)
check("decrement", nextCount(4, { type: "decrement" }), 3)
check("reset jumps to the target", nextCount(4, { type: "reset", to: 0 }), 0)

summary()
export {}
