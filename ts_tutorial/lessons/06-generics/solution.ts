/**
 * Lesson 06 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// Exercise 1 — <T> declares a type parameter, and using the SAME T in the
// parameter (T[]) and the return (T) is what links input to output. Each
// call infers its own T — hover the two calls: firstItem<string> for the
// first, firstItem<number> for the second. One function, no info lost.

function firstItem<T>(items: T[]): T {
  return items[0]
}

const firstTag = firstItem(["urgent", "bug", "ui"])
const firstScore = firstItem([98, 87, 91])

type _e1a = Expect<Equal<typeof firstTag, string>>
type _e1b = Expect<Equal<typeof firstScore, number>>

check("firstTag keeps its string type", firstTag, "urgent")
check("firstScore keeps its number type", firstScore, 98)

// Exercise 2 — (a) an empty [] gives inference nothing to chew on, so T
// falls back to never; the explicit <string> decides it instead. (b) the
// explicit argument OVERRIDES inference entirely — write <number> and the
// string array becomes the error. <string> fixes it (so would deleting the
// type argument and letting inference read the array).

function lastOf<T>(items: T[]): T | undefined {
  return items[items.length - 1]
}

const lastQueued = lastOf<string>([])
const lastMeeting = lastOf<string>(["standup", "retro"])

type _e2a = Expect<Equal<typeof lastQueued, string | undefined>>
type _e2b = Expect<Equal<typeof lastMeeting, string | undefined>>

check("nothing queued yet", lastQueued, undefined)
check("last meeting of the day", lastMeeting, "retro")

// Exercise 3 — two type parameters, because there are two independent
// unknowns: what goes in and what comes out. `transform: (item: In) => Out`
// ties them together, so inference reads BOTH from the callback you pass.
// The `out` array inside must be Out[] too — the body works for any pair.

function mapItems<In, Out>(items: In[], transform: (item: In) => Out): Out[] {
  const out: Out[] = []
  for (const item of items) {
    out.push(transform(item))
  }
  return out
}

const shouts = mapItems(["ok", "go"], (s) => s.toUpperCase())
const lengths = mapItems(["ok", "error", "retry"], (s) => s.length)

type _e3a = Expect<Equal<typeof shouts, string[]>>
type _e3b = Expect<Equal<typeof lengths, number[]>>

check("strings map to strings", shouts, ["OK", "GO"])
check("strings map to numbers", lengths, [2, 5, 5])

// Exercise 4 — `T extends { id: string }` means "any T, as long as it at
// least has a string id" — which is exactly what the body needs to read
// item.id. Note what the assertion proves: T still remembers the FULL
// element type ({ id, name }), not just the { id } the constraint names.
// That's the win over typing the parameter as { id: string }[] directly.

function findById<T extends { id: string }>(items: T[], id: string): T | undefined {
  return items.find((item) => item.id === id)
}

const users = [
  { id: "u1", name: "Ada" },
  { id: "u2", name: "Grace" },
]
const ada = findById(users, "u1")

type _e4 = Expect<Equal<typeof ada, { id: string; name: string } | undefined>>

check("found Ada by id", ada?.name, "Ada")
check("missing id gives undefined", findById(users, "u9"), undefined)

// Exercise 5 — the lookup pattern, piece by piece: `keyof T` is the union
// of T's property names ("theme" | "fontSize" | "relativeNumbers"), so
// `K extends keyof T` forces the key to be real. `T[K]` (indexed access)
// is "the type of that property" — string for "theme", number for
// "fontSize". Lesson 07 dissects keyof and indexed access in depth.

function getProp<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key]
}

const editorConfig = { theme: "dark", fontSize: 14, relativeNumbers: true }

const theme = getProp(editorConfig, "theme")
const fontSize = getProp(editorConfig, "fontSize")

type _e5a = Expect<Equal<typeof theme, string>>
type _e5b = Expect<Equal<typeof fontSize, number>>

check("theme keeps its property type", theme, "dark")
check("fontSize keeps its property type", fontSize, 14)

// Exercise 6 — type aliases take parameters with the same angle brackets as
// functions. `data: T` is the placeholder; each annotation below fills it
// in with a different type argument. This shape (ApiResponse<T>) is
// everywhere in real API layers.

type ApiResponse<T> = {
  status: number
  data: T
}

const healthResponse: ApiResponse<string> = { status: 200, data: "ok" }
const userResponse: ApiResponse<{ id: string; name: string }> = {
  status: 200,
  data: { id: "u1", name: "Ada" },
}
const countResponse: ApiResponse<number> = { status: 200, data: 42 }

type _e6a = Expect<Equal<typeof userResponse.data, { id: string; name: string }>>
type _e6b = Expect<Equal<typeof countResponse.data, number>>

check("health endpoint data", healthResponse.data, "ok")
check("user endpoint data", userResponse.data.name, "Ada")
check("count endpoint data", countResponse.data, 42)

// Exercise 7 — `T = string` is a default type parameter: exactly like a
// default function parameter, one level up. A bare `PaginatedList` now
// means PaginatedList<string>, and `<number>` still overrides it. React's
// own type definitions lean on defaults heavily (see lesson 12).

type PaginatedList<T = string> = {
  items: T[]
  page: number
  totalPages: number
}

const tagPage: PaginatedList = {
  items: ["typescript", "react", "nextjs"],
  page: 1,
  totalPages: 4,
}

const scorePage: PaginatedList<number> = {
  items: [88, 92, 79],
  page: 2,
  totalPages: 3,
}

type _e7a = Expect<Equal<typeof tagPage.items, string[]>>
type _e7b = Expect<Equal<typeof scorePage.items, number[]>>

check("tag page holds strings", tagPage.items[0], "typescript")
check("score page holds numbers", scorePage.items.length, 3)

summary()
export {}
