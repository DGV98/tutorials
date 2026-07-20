/**
 * Lesson 03 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// Exercise 1 — parameters always need annotations: there's no value to
// infer from at the declaration. The return type stays un-annotated on
// purpose — hover areaOfRect and you'll see `: number` inferred from the
// body. Annotating params + inferring returns is the everyday default.

function areaOfRect(width: number, height: number) {
  return width * height
}

const area = areaOfRect(6, 7)

type _e1 = Expect<Equal<typeof area, number>>
check("area of a 6x7 rectangle", area, 42)

// Exercise 2 — the `: string` annotation is a contract the body must honor,
// so the bad branch errored on its own return line — the exact spot the fix
// belongs. Without the annotation, the return type would have silently
// widened to `string | number` and the errors would have surfaced at every
// CALL site instead. That's why public helpers deserve return annotations.

function describeScore(score: number): string {
  if (score >= 90) return "excellent"
  if (score >= 50) return "passing"
  return `failed: ${score}`
}

check("a great score", describeScore(95), "excellent")
check("a decent score", describeScore(70), "passing")
check("a failing score", describeScore(20), "failed: 20")

// Exercise 3a — a default value does two jobs at once: it makes the
// parameter optional at call sites AND infers its type (hover punctuation:
// string). Writing `punctuation: string = "."` also works; the annotation
// is just redundant.

function greet(name: string, punctuation = ".") {
  return `Hello, ${name}${punctuation}`
}

const casual = greet("Ada")
const excited = greet("Ada", "!")

check("greet falls back to a period", casual, "Hello, Ada.")
check("greet accepts punctuation", excited, "Hello, Ada!")

// Exercise 3b — `middle?: string` means callers may omit it, and INSIDE the
// body its type is `string | undefined` (the assertion pins that). The
// ternary handles the undefined case — a preview of narrowing, lesson 04.
// Unlike 3a there's no fallback value here; omitting it changes behavior.

function fullName(first: string, last: string, middle?: string) {
  type _e3 = Expect<Equal<typeof middle, string | undefined>>
  return middle ? `${first} ${middle} ${last}` : `${first} ${last}`
}

check("no middle name", fullName("Grace", "Hopper"), "Grace Hopper")
check("with middle name", fullName("Grace", "Hopper", "Brewster"), "Grace Brewster Hopper")

// Exercise 4 — rest parameters gather arguments into a real array, so the
// annotation must be an array type: number[]. Note what we did NOT
// annotate: `acc` and `n`. reduce's declared type tells TypeScript what its
// callback receives, so contextual typing fills both in as number.

function sum(...values: number[]) {
  return values.reduce((acc, n) => acc + n, 0)
}

const total = sum(1, 2, 3, 4)

type _e4 = Expect<Equal<typeof total, number>>
check("sum of four numbers", total, 10)
check("sum of no numbers", sum(), 0)

// Exercise 5 — `(id: string) => void` is a function type expression: the
// shape of a whole function used as a type. Once the DECLARATION says what
// the callback receives, the arrow at the call site needs no annotations —
// `user` is contextually typed as string. Exactly how React props like
// `onSelect: (id: string) => void` work in lesson 11.

function forEachUser(ids: string[], callback: (id: string) => void) {
  for (const id of ids) {
    callback(id)
  }
}

const notified: string[] = []
forEachUser(["ada", "grace"], (user) => {
  type _e5 = Expect<Equal<typeof user, string>>
  notified.push(user.toUpperCase())
})

check("every user was notified", notified, ["ADA", "GRACE"])

// Exercise 6 — two directions of `void`, and they're different on purpose:
//   • ASSIGNING a function: `(m) => received.push(m)` returns number, but a
//     `=> void` context means "the return will be ignored", so it's allowed.
//     This is exactly why `onClick={() => savePromise()}` compiles in React.
//   • WRITING a body: emit returns nothing, so declaring `: number` was a
//     broken promise (TS: "must return a value"). Fire-and-forget = `: void`.

type Listener = (message: string) => void

const listeners: Listener[] = []

function addListener(listener: Listener): void {
  listeners.push(listener)
}

const received: string[] = []
addListener((message) => received.push(message))

function emit(message: string): void {
  for (const listener of listeners) {
    listener(message)
  }
}

const result = emit("deploy finished")

type _e6 = Expect<Equal<typeof result, void>>
check("the listener heard it", received, ["deploy finished"])

// Exercise 7 — `never` says "this function does not return AT ALL" (void
// says "returns, carrying nothing"). Two reasons the explicit annotation
// matters: function DECLARATIONS infer void here, not never — and control
// flow analysis only treats a call as path-ending when the callee is
// explicitly annotated `: never`. That's what lets parseBoolean's final
// line satisfy the `: boolean` contract: the end is provably unreachable.

function crash(message: string): never {
  throw new Error(message)
}

type _e7 = Expect<Equal<typeof crash, (message: string) => never>>

function parseBoolean(input: string): boolean {
  if (input === "true") return true
  if (input === "false") return false
  crash(`expected "true" or "false", got "${input}"`)
}

check("parses true", parseBoolean("true"), true)
check("parses false", parseBoolean("false"), false)

summary()
export {}
