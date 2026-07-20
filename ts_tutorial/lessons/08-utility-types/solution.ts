/**
 * Lesson 08 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"

type Role = "admin" | "editor" | "viewer"

type User = {
  id: number
  name: string
  email: string
  password: string
  role: Role
}

// Exercise 1 — Partial<User> makes every field optional: exactly the shape
// of a PATCH payload. The call sites were right all along; the parameter
// was over-demanding. Fixing the type where the *requirement* lives (not
// silencing the callers) is the recurring move in this lesson.

function updateUser(id: number, changes: Partial<User>) {
  // pretend: PATCH /api/users/:id with `changes` as the body
  return { ...changes, id }
}

updateUser(1, { name: "Ada King" })
updateUser(2, { email: "grace@example.com", role: "admin" })

// Exercise 2 — Pick names the slice ONCE, in terms of User. The hand copy
// had drifted ("passwrd"); a Pick can't drift — rename a field on User and
// this type follows automatically.

type LoginFormFields = Pick<User, "email" | "password">

type _e2 = Expect<Equal<LoginFormFields, { email: string; password: string }>>

// Exercise 3 — Pick keeps what you list; Omit drops what you list. For
// "everything except password", Omit is also the future-proof dual: add a
// new field to User and PublicUser gains it automatically, while a Pick
// would silently leave it behind.

type PublicUser = Omit<User, "password">

type _e3 = Expect<Equal<PublicUser, { id: number; name: string; email: string; role: Role }>>

// Exercise 4 — the index signature accepted ANY string key, so a missing
// role could never be caught. Record<Role, Permission[]> demands exactly
// the three Role keys — annotating it is what forced viewer to appear.

type Permission = "read" | "write" | "delete"

const rolePermissions: Record<Role, Permission[]> = {
  admin: ["read", "write", "delete"],
  editor: ["read", "write"],
  viewer: ["read"],
}

type _e4 = Expect<Equal<typeof rolePermissions, Record<Role, Permission[]>>>

// Exercise 5 — Exclude removes the members you name, Extract keeps only
// the members you name, NonNullable strips null/undefined. (SettledStatus
// could equally be Extract<Status, "success" | "error"> — Exclude/Extract
// are duals, like Omit/Pick; name the more stable list.)

type Status = "idle" | "loading" | "success" | "error" | null

type SettledStatus = Exclude<Status, "idle" | "loading" | null>
type _e5a = Expect<Equal<SettledStatus, "success" | "error">>

type KnownStatus = NonNullable<Status>
type _e5b = Expect<Equal<KnownStatus, "idle" | "loading" | "success" | "error">>

type BusyStatus = Extract<Status, "idle" | "loading">
type _e5c = Expect<Equal<BusyStatus, "idle" | "loading">>

// Exercise 6 — ReturnType/Parameters (with typeof, lesson 07) make the
// implementation the single source of truth. The drift the hand copies had
// accumulated — Date vs number, a forgotten second parameter — is exactly
// the class of bug this style makes impossible.

function buildSession(user: User, minutes: number) {
  return {
    user,
    token: `tok_${user.id}`,
    expiresAt: Date.now() + minutes * 60_000,
  }
}

type Session = ReturnType<typeof buildSession>
type _e6a = Expect<Equal<Session, { user: User; token: string; expiresAt: number }>>

type SessionArgs = Parameters<typeof buildSession>
type _e6b = Expect<Equal<SessionArgs, [user: User, minutes: number]>>

// Exercise 7 — ReturnType of an async function is Promise<...>; Awaited
// unwraps it. Awaited<ReturnType<typeof fn>> reads as "what one awaited
// call gives me" — the everyday way to type API data without writing a
// duplicate interface for it.

async function fetchProfile(id: number) {
  // pretend: const res = await fetch(`/api/users/${id}`)
  return { id, name: "Ada King", email: "ada@example.com", role: "admin" as Role }
}

type Profile = Awaited<ReturnType<typeof fetchProfile>>

type _e7 = Expect<Equal<Profile, { id: number; name: string; email: string; role: Role }>>

// Exercise 8 — (a) Required strips every `?`: the after-defaults shape is
// derived, never re-typed. (b) Readonly on the parameter turns "please
// don't mutate" into a compiler-enforced contract — it immediately flagged
// `settings.fontSize = 0`, deleted here. The types found a real bug.

type DraftSettings = {
  theme?: "light" | "dark"
  fontSize?: number
}

type ResolvedSettings = Required<DraftSettings>

type _e8a = Expect<Equal<ResolvedSettings, { theme: "light" | "dark"; fontSize: number }>>

function renderSettings(settings: Readonly<ResolvedSettings>) {
  return `${settings.theme} @ ${settings.fontSize}px`
}

type _e8b = Expect<Equal<Parameters<typeof renderSettings>[0], Readonly<ResolvedSettings>>>

export {}
