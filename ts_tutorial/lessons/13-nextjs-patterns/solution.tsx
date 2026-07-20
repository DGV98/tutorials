/**
 * Lesson 13 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import type { ReactNode } from "react"

// Shared hand-rolled types — unchanged. In a real project these come from
// Next's generated types; the shape is the same.

type SearchParams = Record<string, string | string[] | undefined>

type PageProps<Params = Record<string, never>> = {
  params: Promise<Params>
  searchParams: Promise<SearchParams>
}

// Exercise 1 — `params` is a Promise (the Next 15 shape), so the fix is one
// `await`. "Property 'slug' does not exist on type 'Promise<{ slug: string }>'"
// is the compiler telling you exactly this — the most common error in
// freshly-upgraded Next codebases.

export default async function BlogPostPage({
  params,
}: PageProps<{ slug: string }>) {
  const { slug } = await params

  type _e1 = Expect<Equal<typeof slug, string>>

  return <article>Reading: {slug}</article>
}

// Exercise 2 — `q` is string | string[] | undefined, the URL's honest truth.
// A typeof check (lesson 04) keeps the string case and collapses the other
// two to "". Both errors — "possibly 'undefined'" and "toUpperCase does not
// exist on type 'string[]'" — vanish with the one narrowing.

export async function SearchResultsPage({ searchParams }: PageProps) {
  const { q } = await searchParams

  const query = typeof q === "string" ? q : ""

  type _e2 = Expect<Equal<typeof query, string>>

  return <p>Results for: {query.toUpperCase()}</p>
}

// Exercise 3 — every layout receives the content it wraps as `children`,
// typed ReactNode (lesson 11). Once the prop exists in the type, the
// destructure and the {children} in the JSX both check out.

type TeamLayoutProps = {
  children: ReactNode
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

// Exercise 4 — GET: an async function ALWAYS returns a Promise, so the
// annotation must be Promise<Response> (the original error said exactly
// that). Response.json() turns the plain object into a real Response.
// DELETE: context.params is a Promise, same fix as exercise 1.

export async function GET(request: Request): Promise<Response> {
  return Response.json({ status: "ok", uptime: 42 })
}

type EpisodeRouteContext = {
  params: Promise<{ id: string }>
}

export async function DELETE(
  request: Request,
  context: EpisodeRouteContext,
): Promise<Response> {
  const { id } = await context.params

  type _e4 = Expect<Equal<typeof id, string>>

  return Response.json({ deleted: id })
}

// Exercise 5 — formData.get() is FormDataEntryValue | null: possibly missing,
// possibly a File. `typeof title !== "string"` rejects both bad cases in one
// stroke (lesson 04), so after the early return, title is plain string — the
// assertion proves it and savePost accepts it. Note the return values already
// matched ActionState's two branches; only the guard was missing.

type ActionState = { ok: true } | { ok: false; error: string }

const savedTitles: string[] = []
async function savePost(title: string): Promise<void> {
  savedTitles.push(title)
}

export async function createPost(formData: FormData): Promise<ActionState> {
  "use server"
  const title = formData.get("title")

  if (typeof title !== "string" || title.length < 3) {
    return { ok: false, error: "Title must be at least 3 characters." }
  }

  type _e5 = Expect<Equal<typeof title, string>>

  await savePost(title)
  return { ok: true }
}

// Exercise 6 — the boundary discipline from lesson 10, applied for real:
// res.json() is `any`, pinned to `unknown` at the door; the isPost predicate
// is the runtime gatekeeper. After the throw-guard, `data` is narrowed to
// Post, so the log and the return both check. Nothing unvalidated escapes.

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

  if (!isPost(data)) {
    throw new Error("Malformed payload from /posts")
  }

  console.log("fetched:", data.title)
  return data
}

type _e6 = Expect<Equal<Awaited<ReturnType<typeof fetchPost>>, Post>>

// Exercise 7 — ReturnType of an async function is the Promise; Awaited
// (lesson 08) unwraps it. Derive-don't-duplicate: if getDashboard grows a
// field tomorrow, DashboardData and UnreadBadge update themselves.

async function getDashboard() {
  return { user: { name: "David" }, unreadCount: 3 }
}

type DashboardData = Awaited<ReturnType<typeof getDashboard>>

type _e7 = Expect<
  Equal<DashboardData, { user: { name: string }; unreadCount: number }>
>

export function UnreadBadge({ data }: { data: DashboardData }) {
  return <strong>{data.unreadCount} unread</strong>
}

// ---------------------------------------------------------------------------
export {}
