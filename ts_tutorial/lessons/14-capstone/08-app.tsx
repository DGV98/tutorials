/**
 * Capstone stage 08 — Ship it: the Next-shaped app.
 *
 * This file intentionally does not type-check. It is stage 8 of 8 of ONE
 * app — Heavy Rotation — and it is the victory lap: pages, layouts, route
 * handlers, and a server action, each banner naming the Next file it would
 * be. Work the stages in order (this one leans on 01, 03, 04, 05, and 06),
 * and within this file work top to bottom until `./check 14` reports no
 * errors mentioning `08-`.
 *
 * Type-check ONLY — nothing runs here. When this file goes quiet, walk the
 * whole finish line: `./check 14` fully green, then npx tsx on 01, 02,
 * and 04. That's the course.
 *
 * Never edit lines containing Expect<Equal<...>> — they are the assertions
 * you're satisfying. Never touch GIVEN-marked blocks or given/ files — they
 * are complete and correct.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import type { ReactNode } from "react"
import type { PageProps, RouteContext, ActionState } from "./given/next"
import { RAW_CATALOG_JSON, fakeFetchTrack } from "./given/raw-data"
import type { Track, Play } from "./01-domain"
import { seedPlays } from "./01-domain"
import { API_ROUTES } from "./03-tokens"
import { fetchDashboard, isTrack, parseCatalog, HttpError } from "./04-api"
import type { DashboardData } from "./04-api"
import type { SegmentOf, Serialized } from "./05-type-kit"
import { GenreBadge, List, TrackCard } from "./06-components"

// ---------------------------------------------------------------------------
// GIVEN — the router payoff. Complete and correct; DO NOT EDIT.
// Stage 05's SegmentOf does string surgery on the route itself:
// "/tracks/[id]" gives up "id", and Record turns that key into
// { id: string }. If this line (or _e1a) is red, stage 05 isn't done yet —
// the fix lives there, not here.
// ---------------------------------------------------------------------------

export type TrackParams = Record<SegmentOf<"/tracks/[id]">, string>

type _e1a = Expect<Equal<TrackParams, { id: string }>>

// ---------------------------------------------------------------------------
// Task 1 — await your params (lesson 13).
// This is app/tracks/[id]/page.tsx. In Next 15 `params` is a Promise, and
// you can't reach into a Promise with a dot — read the TS2339 as "you
// forgot to await". Fix the destructuring line ONLY; the JSX below it is
// GIVEN. (loadTrack lives under Task 6 — function declarations hoist.)
// ---------------------------------------------------------------------------

export async function TrackPage(props: PageProps<TrackParams>): Promise<ReactNode> {
  const { id } = props.params

  type _e1b = Expect<Equal<typeof id, string>>

  const track = await loadTrack(id)
  return (
    <article>
      <h1>{track.title}</h1>
      <p>
        {track.artist} — {track.album}
      </p>
    </article>
  )
}

// ---------------------------------------------------------------------------
// Task 2 — collapse the searchParams union (lessons 13 + 04).
// This is app/search/page.tsx. ?q=ts is a string, ?q=a&q=b is a string[],
// no ?q at all is undefined — `q` is honestly all three. Fix ONLY the
// `query` line with a typeof ternary that keeps the string case and folds
// the rest to "". Don't touch the await line.
// ---------------------------------------------------------------------------

export async function SearchPage(props: PageProps): Promise<ReactNode> {
  const { q } = await props.searchParams

  const query = q

  type _e2 = Expect<Equal<typeof query, string>>

  return <p>Results for “{query}”</p>
}

// ---------------------------------------------------------------------------
// Task 3 — layouts receive children (lessons 11 + 13).
// This is app/library/[section]/layout.tsx. The body renders
// {props.children}, but whoever wrote the props type forgot that every
// layout receives the content it wraps — `children`, typed ReactNode.
// Fix the PROPS TYPE only; the body is GIVEN and correct.
// ---------------------------------------------------------------------------

export async function LibraryLayout(props: {
  params: Promise<{ section: string }>
}): Promise<ReactNode> {
  const { section } = await props.params
  return (
    <section>
      <h2>Library / {section}</h2>
      {props.children}
    </section>
  )
}

// ---------------------------------------------------------------------------
// Task 4 — route handlers: Request in, Promise<Response> out (lesson 13).
// GET is app/api/tracks/route.ts, served at API_ROUTES.tracks. Three bugs:
//   - an async function cannot be annotated `: Response` — the error names
//     the fix;
//   - a handler returns a Response, not a bare array — wrap the catalog in
//     Response.json(...);
//   - `err` in a catch is unknown (lesson 10): narrow with
//     `if (err instanceof HttpError)` — stage 04's .status is your payoff —
//     and fall through to a 500 Response.json otherwise.
// DELETE is app/api/tracks/[id]/route.ts: context.params is a Promise —
// same story as Task 1. Await it, then destructure.
// ---------------------------------------------------------------------------

export async function GET(request: Request): Response {
  try {
    return parseCatalog(RAW_CATALOG_JSON)
  } catch (err) {
    return Response.json({ error: err.message }, { status: err.status })
  }
}

type _e4 = Expect<Equal<Awaited<ReturnType<typeof GET>>, Response>>

export async function DELETE(
  request: Request,
  context: RouteContext<{ id: string }>,
): Promise<Response> {
  const id = context.params.id
  return Response.json({ deleted: id })
}

// ---------------------------------------------------------------------------
// GIVEN — complete and correct: the slug a saved track files under.
// ---------------------------------------------------------------------------

function slugify(title: string): string {
  return title.toLowerCase().replace(/[^a-z0-9]+/g, "-")
}

// ---------------------------------------------------------------------------
// Task 5 — narrow FormData before you trust it (lessons 13 + 04).
// This is app/actions.ts. formData.get() returns FormDataEntryValue | null
// — missing fields are null, and a PRESENT field may still be a File.
// Guarding only against null leaves `string | File`, which slugify refuses.
// Make the guard `typeof title !== "string"` — ONE check that rejects null
// and File together — and keep each return matching its ActionState branch
// (ok:false carries error, ok:true carries message). The union is imported
// and untouchable.
// ---------------------------------------------------------------------------

export async function addTrackAction(formData: FormData): Promise<ActionState> {
  "use server"
  const title = formData.get("title")

  if (title === null) {
    return { ok: false, error: "Give the track a text title." }
  }

  type _e5 = Expect<Equal<typeof title, string>>

  return { ok: true, message: `Queued "${title}" as ${slugify(title)}.` }
}

// ---------------------------------------------------------------------------
// Task 6 — the fetch boundary, guarded with YOUR predicate (lesson 10).
// fakeFetchTrack resolves to unknown — as honest as a real res.json() —
// and unknown does not become Track by wishing. Insert the guard:
//   if (!isTrack(data)) throw new HttpError(502, "malformed track payload")
// Past it, `data` IS a Track and the return type-checks. No casts, no any —
// the predicate you built in stage 04 earns the type.
// ---------------------------------------------------------------------------

export async function loadTrack(id: string): Promise<Track> {
  const data: unknown = await fakeFetchTrack(id)
  return data
}

// ---------------------------------------------------------------------------
// Task 7 — annotate what the function DOES, not what you wish (lesson 09
// paying off). This is app/api/plays/route.ts. The GIVEN body tells the
// truth: JSON has no Date, so playedAt goes over the wire as a string. The
// hand-written `: Play` annotation is a lie the compiler catches at that
// exact property. Replace the ANNOTATION with Serialized<Play> — your
// stage-05 wire type, already imported. The body stays untouched.
// ---------------------------------------------------------------------------

// GIVEN body — do not edit; only the return annotation is wrong.
export function serializePlay(play: Play): Play {
  return { ...play, playedAt: play.playedAt.toISOString() }
}

type _e7 = Expect<
  Equal<Serialized<Play>, { trackId: string; playedAt: string; source: "library" | "playlist" | "radio" }>
>

// GIVEN — complete and correct: the one line the plays route's GET would
// hold. Once serializePlay stops lying, the mapped payload is
// Serialized<Play>[] — hover it and see.
const playsRoute = () => Response.json(seedPlays.map(serializePlay))
void playsRoute

// ---------------------------------------------------------------------------
// Task 8 — fix the broken usages of YOUR components (lessons 11 + 02).
// This is app/page.tsx. (In a real repo it would open with "use client" —
// it passes handlers down.) Two TrackCard usages are broken, and the union
// you built in stage 06 is what rejects them:
//   - the first says `playable` but forgot onPlay — unrepresentable, by
//     YOUR design: give it an onPlay handler;
//   - the second typo'd the prop as `onPlaay` — the excess-property shield,
//     firing in JSX. Fixing the name ALSO types the callback: trackId gets
//     its contextual string from the prop the type knows about.
// Fix the two CALL SITES only. The List and GenreBadge usages are GIVEN and
// already correct.
// ---------------------------------------------------------------------------

export function DashboardPage(props: { data: DashboardData }): ReactNode {
  const opener = props.data.topTracks[0]
  const closer = props.data.topTracks[1]
  return (
    <main>
      <header>
        <h1>Heavy Rotation</h1>
        {/* GIVEN — stage 03's route table typing a real href. */}
        <a href={API_ROUTES.tracks}>open the crate</a>
        <p>
          {props.data.user.handle} · {props.data.totalPlays} plays logged
        </p>
      </header>

      {/* GIVEN — the course's final hover lives here: cursor on `track`,
          press K. YOUR domain type, flowing through YOUR generic component,
          inside YOUR page — inferred at every hop, annotated at none. */}
      <List
        items={props.data.topTracks}
        renderItem={(track) => {
          type _s8 = Expect<Equal<typeof track, Track>>
          return (
            <>
              <GenreBadge genre={track.genre} size={12} />
              {track.title}
            </>
          )
        }}
      />

      <TrackCard track={opener} playable />
      <TrackCard track={closer} playable onPlaay={(trackId) => console.log(`up next ${trackId}`)} />
    </main>
  )
}

// ---------------------------------------------------------------------------
// GIVEN — THE SPEC, complete and correct: the dashboard rendered with the
// data your own API layer proved at the boundary. Stage 04 built the trust,
// stage 06 built the components, and this line spends both.
// ---------------------------------------------------------------------------

async function __spec() {
  return <DashboardPage data={await fetchDashboard()} />
}
void __spec

// ---------------------------------------------------------------------------
export {}
