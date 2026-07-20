/**
 * Lesson 08 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 08` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * No `npx tsx` step this time: this lesson lives entirely at the type
 * level. When the checker goes quiet, you're done.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"

// The model every exercise derives from. Do not modify it.

type Role = "admin" | "editor" | "viewer"

type User = {
  id: number
  name: string
  email: string
  password: string
  role: Role
}

// ---------------------------------------------------------------------------
// Exercise 1 — Update payloads are Partial.
// updateUser applies a patch: callers send ONLY the fields that changed.
// But the parameter demands a full User, so both (perfectly good) call
// sites error. Fix the parameter's type with one utility — do not touch
// the calls.
// ---------------------------------------------------------------------------

function updateUser(id: number, changes: User) {
  // pretend: PATCH /api/users/:id with `changes` as the body
  return { ...changes, id }
}

updateUser(1, { name: "Ada King" })
updateUser(2, { email: "grace@example.com", role: "admin" })

// ---------------------------------------------------------------------------
// Exercise 2 — Pick a form's slice.
// The login form needs exactly User's email and password fields. Someone
// copied them by hand — and the copy has drifted (spot the typo). Replace
// the whole hand-written type with a Pick from User, so it can never
// drift again.
// ---------------------------------------------------------------------------

type LoginFormFields = {
  email: string
  passwrd: string
}

type _e2 = Expect<Equal<LoginFormFields, { email: string; password: string }>>

// ---------------------------------------------------------------------------
// Exercise 3 — Wrong tool: Pick where Omit belongs.
// PublicUser is what the API sends to the browser: everything EXCEPT the
// password. Someone reached for Pick and got it exactly backwards — right
// now this type is ONLY the password. Swap in the right utility.
// ---------------------------------------------------------------------------

type PublicUser = Pick<User, "password">

type _e3 = Expect<Equal<PublicUser, { id: number; name: string; email: string; role: Role }>>

// ---------------------------------------------------------------------------
// Exercise 4 — Record beats an index signature when you know the keys.
// The permissions table must cover EVERY role — but the index signature
// accepts any string key, so nobody noticed "viewer" is missing. Change
// the annotation to a Record keyed by Role, then add the entry the
// compiler demands (viewer can only "read").
// ---------------------------------------------------------------------------

type Permission = "read" | "write" | "delete"

const rolePermissions: { [role: string]: Permission[] } = {
  admin: ["read", "write", "delete"],
  editor: ["read", "write"],
}

type _e4 = Expect<Equal<typeof rolePermissions, Record<Role, Permission[]>>>

// ---------------------------------------------------------------------------
// Exercise 5 — Filter unions: Exclude, Extract, NonNullable.
// Status is the source of truth. Each derived type below is currently a
// lazy alias of the WHOLE union. Replace each right-hand `Status` with
// the correct union-filtering utility — do not hand-write the unions.
// ---------------------------------------------------------------------------

type Status = "idle" | "loading" | "success" | "error" | null

// (a) only the two "finished" states — remove the rest
type SettledStatus = Status
type _e5a = Expect<Equal<SettledStatus, "success" | "error">>

// (b) everything except null
type KnownStatus = Status
type _e5b = Expect<Equal<KnownStatus, "idle" | "loading" | "success" | "error">>

// (c) keep only the members that appear in "idle" | "loading"
type BusyStatus = Status
type _e5c = Expect<Equal<BusyStatus, "idle" | "loading">>

// ---------------------------------------------------------------------------
// Exercise 6 — The function is the source of truth.
// Session and SessionArgs were copied from buildSession by hand, and both
// have drifted (a Date that's really a number; a parameter added later).
// Derive them with ReturnType and Parameters (plus typeof, lesson 07) so
// they can never drift again. Do not edit the function.
// ---------------------------------------------------------------------------

function buildSession(user: User, minutes: number) {
  return {
    user,
    token: `tok_${user.id}`,
    expiresAt: Date.now() + minutes * 60_000,
  }
}

type Session = { user: User; token: string; expiresAt: Date }
type _e6a = Expect<Equal<Session, { user: User; token: string; expiresAt: number }>>

type SessionArgs = [User]
type _e6b = Expect<Equal<SessionArgs, [user: User, minutes: number]>>

// ---------------------------------------------------------------------------
// Exercise 7 — What does this API call resolve to?
// fetchProfile is async, so ReturnType alone gives a Promise<...> — hover
// Profile and look. You want what an `await` would hand you: wrap the
// ReturnType in one more utility.
// ---------------------------------------------------------------------------

async function fetchProfile(id: number) {
  // pretend: const res = await fetch(`/api/users/${id}`)
  return { id, name: "Ada King", email: "ada@example.com", role: "admin" as Role }
}

type Profile = ReturnType<typeof fetchProfile>

type _e7 = Expect<Equal<Profile, { id: number; name: string; email: string; role: Role }>>

// ---------------------------------------------------------------------------
// Exercise 8 — Required and Readonly.
// (a) DraftSettings is what callers may pass; ResolvedSettings is the shape
//     AFTER defaults are applied, so every field is guaranteed present.
//     Derive it from DraftSettings — don't re-type the fields.
// (b) renderSettings must not modify what it's given. Make its parameter
//     Readonly<ResolvedSettings> — the compiler will then point straight at
//     a sneaky mutation. Delete that line; it was a bug.
// ---------------------------------------------------------------------------

type DraftSettings = {
  theme?: "light" | "dark"
  fontSize?: number
}

type ResolvedSettings = DraftSettings

type _e8a = Expect<Equal<ResolvedSettings, { theme: "light" | "dark"; fontSize: number }>>

function renderSettings(settings: ResolvedSettings) {
  settings.fontSize = 0 // <- the bug part (b) exists to catch
  return `${settings.theme} @ ${settings.fontSize}px`
}

type _e8b = Expect<Equal<Parameters<typeof renderSettings>[0], Readonly<ResolvedSettings>>>

// ---------------------------------------------------------------------------
export {}
