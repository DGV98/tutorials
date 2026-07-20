/**
 * Lesson 13 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 13` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * This lesson is type-check only — there is nothing to run. In a real
 * Next.js app each exercise would live in its own file (app/blog/[slug]/
 * page.tsx, app/api/health/route.ts, ...). The Next-shaped types are
 * hand-rolled below; we import NOTHING from "next".
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import type { ReactNode } from "react"

// ---------------------------------------------------------------------------
// Shared hand-rolled types — given and correct, used by exercises 1 and 2.
// DO NOT EDIT. This is (a simplified version of) what Next generates for
// every page. Note that both props are Promises — the Next 15 shape.
// ---------------------------------------------------------------------------

type SearchParams = Record<string, string | string[] | undefined>

type PageProps<Params = Record<string, never>> = {
  params: Promise<Params>
  searchParams: Promise<SearchParams>
}

// ---------------------------------------------------------------------------
// Exercise 1 — await your params.
// This is app/blog/[slug]/page.tsx. `params` is a Promise — you can't reach
// into it with a dot; await it first (destructuring the result is idiomatic).
// Fix the function body only; PageProps above is correct.
// ---------------------------------------------------------------------------

export default async function BlogPostPage({
  params,
}: PageProps<{ slug: string }>) {
  const slug = params.slug

  type _e1 = Expect<Equal<typeof slug, string>>

  return <article>Reading: {slug}</article>
}

// ---------------------------------------------------------------------------
// Exercise 2 — searchParams is a union; narrow it (lesson 04).
// For /search?q=ts, `q` is a string — but ?q=a&q=b makes it string[], and no
// ?q at all makes it undefined. Fix ONLY the `query` line so it's a plain
// string (collapse the array/missing cases to "" — a typeof check does it).
// Don't touch the await line.
// ---------------------------------------------------------------------------

export async function SearchResultsPage({ searchParams }: PageProps) {
  const { q } = await searchParams

  const query = q

  type _e2 = Expect<Equal<typeof query, string>>

  return <p>Results for: {query.toUpperCase()}</p>
}

// ---------------------------------------------------------------------------
// Exercise 3 — layouts receive children.
// This is app/team/[team]/layout.tsx. Whoever wrote TeamLayoutProps forgot
// that every layout receives the wrapped content as `children` (lesson 11:
// it's a prop like any other, typed ReactNode). Fix the TYPE; the component
// itself is correct.
// ---------------------------------------------------------------------------

type TeamLayoutProps = {
  params: Promise<{ team: string }>
}

export async function TeamLayout({ children, params }: TeamLayoutProps) {
  const { team } = await params

  type _e3 = Expect<Equal<typeof children, ReactNode>>

  return (
    <section>
      <h1>Team {team}</h1>
      {children}
    </section>
  )
}

// ---------------------------------------------------------------------------
// Exercise 4 — route handlers: Request in, Promise<Response> out.
// Two handlers, two bugs:
//   GET (app/api/health/route.ts) — an async function cannot be annotated
//     to return a bare Response; read the error, it names the fix. Then make
//     the body actually produce a Response (Response.json is the one-liner).
//   DELETE (app/api/episodes/[id]/route.ts) — the dynamic segment arrives
//     in context.params… which is a Promise. Same story as exercise 1.
// Don't touch EpisodeRouteContext.
// ---------------------------------------------------------------------------

export async function GET(request: Request): Response {
  return { status: "ok", uptime: 42 }
}

type EpisodeRouteContext = {
  params: Promise<{ id: string }>
}

export async function DELETE(
  request: Request,
  context: EpisodeRouteContext,
): Promise<Response> {
  const { id } = context.params

  type _e4 = Expect<Equal<typeof id, string>>

  return Response.json({ deleted: id })
}

// ---------------------------------------------------------------------------
// Exercise 5 — server actions: narrow FormData before you trust it.
// formData.get("title") returns FormDataEntryValue | null — the field may be
// missing (null), and when present it may be a File instead of a string.
// Fix the if-condition so it ALSO rejects non-strings (lesson 04: typeof),
// making the length check and savePost both type-check. Don't touch
// ActionState, savePost, or createPost's signature.
// ---------------------------------------------------------------------------

type ActionState = { ok: true } | { ok: false; error: string }

const savedTitles: string[] = []
async function savePost(title: string): Promise<void> {
  savedTitles.push(title)
}

export async function createPost(formData: FormData): Promise<ActionState> {
  "use server"
  const title = formData.get("title")

  if (title.length < 3) {
    return { ok: false, error: "Title must be at least 3 characters." }
  }

  type _e5 = Expect<Equal<typeof title, string>>

  await savePost(title)
  return { ok: true }
}

// ---------------------------------------------------------------------------
// Exercise 6 — the fetch boundary: unknown in, validated Post out.
// res.json() returns `any`, so we pin it to `unknown` immediately — the
// lesson 10 discipline. Now the compiler refuses to let unvalidated data
// escape. Use the given, correct `isPost` predicate to prove the payload is
// a Post before the log and the return (throw an Error when it isn't).
// Don't touch Post, isPost, the `: unknown` annotation, or the return type.
// ---------------------------------------------------------------------------

type Post = {
  id: number
  title: string
  tags: string[]
}

function isPost(value: unknown): value is Post {
  if (typeof value !== "object" || value === null) return false
  const candidate = value as Record<string, unknown>
  return (
    typeof candidate.id === "number" &&
    typeof candidate.title === "string" &&
    Array.isArray(candidate.tags) &&
    candidate.tags.every((tag: unknown) => typeof tag === "string")
  )
}

export async function fetchPost(id: number): Promise<Post> {
  const res = await fetch(`https://api.example.com/posts/${id}`)
  const data: unknown = await res.json()

  console.log("fetched:", data.title)
  return data
}

type _e6 = Expect<Equal<Awaited<ReturnType<typeof fetchPost>>, Post>>

// ---------------------------------------------------------------------------
// Exercise 7 — derive, don't duplicate (lesson 08 payoff).
// UnreadBadge wants the RESOLVED data of getDashboard, but ReturnType of an
// async function is the Promise. Unwrap it. Fix ONLY the DashboardData line.
// ---------------------------------------------------------------------------

async function getDashboard() {
  return { user: { name: "David" }, unreadCount: 3 }
}

type DashboardData = ReturnType<typeof getDashboard>

type _e7 = Expect<
  Equal<DashboardData, { user: { name: string }; unreadCount: number }>
>

export function UnreadBadge({ data }: { data: DashboardData }) {
  return <strong>{data.unreadCount} unread</strong>
}

// ---------------------------------------------------------------------------
export {}
