# Lesson 13 — Next.js patterns: pages, actions, and the fetch boundary

**Why this matters for React:** this is the payoff the README promised. A
fresh Next.js project hands you typed page props, route handlers, and server
actions — and to most people those generated types read like magic. They are
not. They are Promises, unions, narrowing, `unknown`, and utility types:
exactly the twelve lessons you just finished. `next` is deliberately not
installed in this repo, so nothing here imports from `"next"` — **we're
rebuilding Next's types by hand so that when the real ones appear in your
project, you can read them.**

## The App Router in one paragraph

In modern Next.js (App Router, Next 15+), your app is a folder tree:
`app/blog/[slug]/page.tsx` is a page, `layout.tsx` wraps the pages below it,
`app/api/health/route.ts` is an HTTP endpoint, and a function marked
`"use server"` is a server action a form can call directly. Each is just a
TypeScript function with a specific shape — the shapes are the whole lesson.

## Pages: async components whose params are a Promise

A page is a server component: an `async` function that receives props and
returns JSX. Here is the hand-rolled version of what Next generates for
`app/blog/[slug]/page.tsx`:

```tsx
type PageProps = {
  params: Promise<{ slug: string }>
  searchParams: Promise<Record<string, string | string[] | undefined>>
}

export default async function BlogPostPage({ params }: PageProps) {
  const { slug } = await params
  return <article>Reading: {slug}</article>
}
```

The surprise: **`params` is a `Promise`**. Since Next 15, route info arrives
asynchronously so pages can start streaming before everything resolves.
Forget the `await` and you get:

```
Property 'slug' does not exist on type 'Promise<{ slug: string }>'
```

Read that the lesson 01 way and it's perfectly clear: you tried to reach
into a Promise with a dot. It's the single most common error in
freshly-upgraded Next codebases.

## searchParams: a union you must narrow

Look at the `searchParams` value type: `string | string[] | undefined`.
That's the URL's honest truth — `/search?q=ts` gives a `string`,
`/search?q=a&q=b` gives a `string[]`, and no `?q` at all gives `undefined`.
Using a search param is a lesson 04 narrowing job:

```tsx
const { q } = await searchParams
const query = typeof q === "string" ? q : ""   // now: string
```

Hover `q`, hover `query` — watch the union collapse.

## Layouts: children plus params

A layout wraps every page beneath it, so on top of its own awaited `params`
it receives the wrapped content as `children` — typed `ReactNode`, exactly
as in lesson 11:

```tsx
import type { ReactNode } from "react"

type LayoutProps = {
  children: ReactNode
  params: Promise<{ team: string }>
}
```

## Route handlers: Request in, Promise<Response> out

An HTTP endpoint (`app/api/.../route.ts`) exports functions named after
methods — `GET`, `POST`, `DELETE`. Their types need nothing from Next at
all: they use the **web-standard** `Request` and `Response` that live in the
DOM lib you've had all along.

```ts
export async function GET(request: Request): Promise<Response> {
  return Response.json({ status: "ok" })
}
```

The return type is `Promise<Response>`, not `Response` — an `async` function
always returns a Promise, and annotating otherwise gets you a compiler error
that says so in plain words (you'll meet it in the exercises).
`Response.json(...)` builds a JSON response in one line.

Dynamic segments arrive as a second parameter — and yes, its `params` is a
Promise again:

```ts
type RouteContext = { params: Promise<{ id: string }> }

export async function DELETE(request: Request, context: RouteContext) {
  const { id } = await context.params
  return Response.json({ deleted: id })
}
```

## Server actions: FormData in, discriminated union out

A server action is an async function a `<form>` submits to. It receives a
`FormData`, and here TypeScript quietly saves you from a real bug:

```ts
const title = formData.get("title")
//    ^? FormDataEntryValue | null
```

`null` because the field may not exist; `FormDataEntryValue` is
`string | File` because file inputs use the same API. Using it as a string
without checking is the mistake lessons 04 and 10 trained you to catch —
narrow first:

```ts
if (typeof title !== "string" || title.length < 3) {
  return { ok: false, error: "Title must be at least 3 characters." }
}
// title: string from here on
```

And the return value? Make it a discriminated union (lesson 04's favorite
shape):

```ts
type ActionState = { ok: true } | { ok: false; error: string }
```

That's exactly the shape you'd hand to React's `useActionState` on the
client: check `ok`, and `error` appears or disappears accordingly.

## Typing fetch: the boundary discipline, for real

`fetch` returns a typed `Response`, but `res.json()` returns `any` — the
compiler cannot know what a server sent. This is the API boundary from
lesson 10, and the discipline applies verbatim:

1. Pin the payload the moment it enters: `const data: unknown = await
   res.json()`. Never let the `any` breathe.
2. Validate with a type predicate (`value is Post`).
3. Only then use it.

```ts
async function fetchPost(id: number): Promise<Post> {
  const res = await fetch(`/api/posts/${id}`)
  const data: unknown = await res.json()
  if (!isPost(data)) throw new Error("Malformed payload")
  return data   // narrowed to Post
}
```

One last trick ties in lesson 08: components downstream shouldn't re-declare
what a data function returns — they should **derive** it:

```ts
type PostData = Awaited<ReturnType<typeof fetchPost>>   // = Post
```

Change the fetcher, and every consumer's type updates itself.

## Exercises

Open `exercises.tsx` — seven exercises, all broken on purpose. This lesson
is type-check only, so there's nothing to run:

```
./check 13
```

Stuck? `solution.tsx` sits next door, with commentary.

## Key takeaways

- In Next 15+, `params` and `searchParams` are **Promises** — await them.
  "Property 'x' does not exist on type 'Promise<...>'" means you forgot.
- `searchParams` values are `string | string[] | undefined`; narrow before
  use (lesson 04).
- Layouts take `children: ReactNode` plus their own awaited `params`
  (lesson 11).
- Route handlers are plain web-standard functions:
  `(request: Request) => Promise<Response>`; `Response.json` builds bodies.
- `formData.get(...)` is `FormDataEntryValue | null` — narrow it, and return
  a discriminated union as your action state.
- `res.json()` is `any`: pin to `unknown`, validate with a predicate, then
  use (lesson 10). Derive downstream types with
  `Awaited<ReturnType<...>>` (lesson 08).

## The end of the lessons — not the course

That's all thirteen lessons — but before the diploma there's a final boss.
The capstone in `lessons/14-capstone/` is **Heavy Rotation**, a
music-listening tracker you build across eight stages: the typed domain,
a player reducer, derived design tokens, a validated API boundary, a
utility-type toolkit, components, hooks, and a Next-shaped app layer.
Everything from lessons 01–13 gets used in anger there. Read its
`notes.md`, then start with `01-domain.ts`.

Worth doing alongside or after it:

- **Do some [type-challenges](https://github.com/type-challenges/type-challenges).**
  Start with "easy"; after lesson 09 they'll feel like puzzles, not walls.
- **`gd` into library types when they confuse you.** That was the promise of
  lesson 01, and it's now true: you speak the language they're written in.

Red squiggle, hover, think, fix. See you in the capstone.
