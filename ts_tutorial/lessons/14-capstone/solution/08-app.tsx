/**
 * Capstone stage 08 — solution with commentary.
 *
 * Import rule: solution files import ONLY sibling solution files
 * (./01-domain), ../given/*, and ../../../helpers/* — NEVER ../NN-*
 * exercise files.
 */
import type { Expect, Equal } from "../../../helpers/type-assertions"
import type { ReactNode } from "react"
import type { PageProps, RouteContext, ActionState } from "../given/next"
import { RAW_CATALOG_JSON, fakeFetchTrack } from "../given/raw-data"
import type { Track, Play } from "./01-domain"
import { seedPlays } from "./01-domain"
import { API_ROUTES } from "./03-tokens"
import { fetchDashboard, isTrack, parseCatalog, HttpError } from "./04-api"
import type { DashboardData } from "./04-api"
import type { SegmentOf, Serialized } from "./05-type-kit"
import { GenreBadge, List, TrackCard } from "./06-components"

// ---------------------------------------------------------------------------
// GIVEN — the router payoff, complete and correct. Stage 05's SegmentOf
// does string surgery on the route itself: "/tracks/[id]" gives up "id",
// and Record turns that key into { id: string }. The params type is DERIVED
// from the path — rename the segment and the type follows. This is what
// Next's generated types do for real routes; you just built the machinery.
// ---------------------------------------------------------------------------

export type TrackParams = Record<SegmentOf<"/tracks/[id]">, string>

type _e1a = Expect<Equal<TrackParams, { id: string }>>

// Task 1 — app/tracks/[id]/page.tsx. In Next 15, `params` is a Promise
// (lesson 13), and you can't reach into a Promise with a dot. The TS2339
// wasn't really about the property — it was about the await you skipped:
// one `await props.params` and the destructured id is a plain string,
// which _e1b pins down. (loadTrack lives under Task 6 below — function
// declarations hoist, so the page may call it freely.)

export async function TrackPage(props: PageProps<TrackParams>): Promise<ReactNode> {
  const { id } = await props.params

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

// Task 2 — app/search/page.tsx. ?q=ts arrives as a string, ?q=a&q=b as a
// string[], and no ?q at all as undefined — searchParams tells the URL's
// honest truth, and the union survives until YOU collapse it. One typeof
// ternary (lesson 04's narrowing, lesson 13's idiom) keeps the string case
// and folds the other two into "" — which is all a search box needs.

export async function SearchPage(props: PageProps): Promise<ReactNode> {
  const { q } = await props.searchParams

  const query = typeof q === "string" ? q : ""

  type _e2 = Expect<Equal<typeof query, string>>

  return <p>Results for “{query}”</p>
}

// Task 3 — app/library/[section]/layout.tsx. Every layout receives the
// content it wraps as `children` — a prop like any other, typed ReactNode
// (lessons 11 and 13). The body was always right; the props type just
// hadn't admitted what the body renders. Fix the type, and {props.children}
// goes quiet.

export async function LibraryLayout(props: {
  children: ReactNode
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

// Task 4 — app/api/tracks/route.ts (GET, served at API_ROUTES.tracks) and
// app/api/tracks/[id]/route.ts (DELETE). Three repairs in GET:
//   - an async function ALWAYS returns a Promise, so the annotation is
//     Promise<Response> — the TS1064 named the fix verbatim (lesson 13);
//   - a route handler hands back a Response, not a bare array —
//     Response.json(...) is the one-liner that wraps the guarded catalog;
//   - `err` in a catch is unknown (lesson 10), and `instanceof HttpError`
//     is the narrowing that unlocks .status — stage 04's parameter
//     property paying off exactly where boundaries fail. Anything that
//     isn't ours falls through to a 500.
// DELETE had Task 1's bug in route-handler clothes: context.params is a
// Promise — await it, then destructure.

export async function GET(request: Request): Promise<Response> {
  try {
    return Response.json(parseCatalog(RAW_CATALOG_JSON))
  } catch (err) {
    if (err instanceof HttpError) {
      return Response.json({ error: err.message }, { status: err.status })
    }
    return Response.json({ error: "unexpected failure" }, { status: 500 })
  }
}

type _e4 = Expect<Equal<Awaited<ReturnType<typeof GET>>, Response>>

export async function DELETE(
  request: Request,
  context: RouteContext<{ id: string }>,
): Promise<Response> {
  const { id } = await context.params
  return Response.json({ deleted: id })
}

// ---------------------------------------------------------------------------
// GIVEN — complete and correct: the slug a saved track files under.
// ---------------------------------------------------------------------------

function slugify(title: string): string {
  return title.toLowerCase().replace(/[^a-z0-9]+/g, "-")
}

// Task 5 — app/actions.ts. formData.get() returns FormDataEntryValue | null:
// the field may be missing (null), and a PRESENT field may still be a File —
// forms upload those too. Guarding only against null left `string | File`,
// which is why slugify refused the argument. `typeof title !== "string"`
// rejects null and File in ONE guard (lesson 04: typeof keeps exactly the
// primitive), and each return matches its ActionState branch — ok:false
// carries error, ok:true carries message. The discriminated union from
// given/next.ts is lesson 04 working the form boundary.

export async function addTrackAction(formData: FormData): Promise<ActionState> {
  "use server"
  const title = formData.get("title")

  if (typeof title !== "string") {
    return { ok: false, error: "Give the track a text title." }
  }

  type _e5 = Expect<Equal<typeof title, string>>

  return { ok: true, message: `Queued "${title}" as ${slugify(title)}.` }
}

// Task 6 — the fetch boundary, guarded with YOUR predicate (lessons 10 and
// 13). fakeFetchTrack resolves to unknown — exactly as honest as a real
// res.json() — and unknown does not become Track by wishing. isTrack is
// stage 04's proof, and the throw is the only exit for payloads that fail
// it: past the guard, `data` IS a Track, and the return finally type-checks.
// Note what did NOT happen here: no cast, no any. The predicate earns the
// type — and stage 04's runtime harness is what keeps the predicate honest.

export async function loadTrack(id: string): Promise<Track> {
  const data: unknown = await fakeFetchTrack(id)
  if (!isTrack(data)) {
    throw new HttpError(502, "malformed track payload")
  }
  return data
}

// Task 7 — app/api/plays/route.ts. The body always told the truth: it
// spreads the play and stringifies playedAt, because JSON has no Date —
// what goes over the wire comes back a string. The old `: Play` annotation
// was a lie, and the compiler caught it at the exact property (string is
// not Date). Serialized<Play> — stage 05's conditional-in-value-position
// mapped type — is that JSON.stringify truth written down once and reused:
// the honest wire type. Annotate what the function DOES, not what you wish
// it did.

// GIVEN — the body was always right. Only the return annotation changed.
export function serializePlay(play: Play): Serialized<Play> {
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

// Task 8 — app/page.tsx. (In a real repo this component would open with
// "use client" — it passes onPlay handlers down. Lesson 13 never made the
// directive load-bearing, so here it stays a comment.) Both broken usages
// died against YOUR stage-06 union: `playable` without onPlay is
// unrepresentable by design — that was Task 3 of stage 06 doing its job —
// and `onPlaay` is lesson 02's excess-property shield firing inside JSX.
// Both fixes happen at the call site; the component library was already
// right. Notice the typo fix ALSO fixed the callback's parameter: a prop
// the type knows about gives its function a contextual type, so trackId
// is a string with nobody annotating it.

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

      <TrackCard track={opener} playable onPlay={(trackId) => console.log(`spinning ${trackId}`)} />
      <TrackCard track={closer} playable onPlay={(trackId) => console.log(`up next ${trackId}`)} />
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
