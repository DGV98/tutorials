/**
 * Capstone stage 06 — The component library.
 *
 * This file intentionally does not type-check. It is stage 6 of 8 of ONE
 * app — Heavy Rotation — and stage 08 renders the components you fix here.
 * Work the stages in order (05 especially: the types you built in the boss
 * fight light up real JSX below), and within this file work top to bottom
 * until `./check 14` reports no errors mentioning `06-`.
 *
 * No `npx tsx` step: components describe UI, and UI needs a browser — the
 * type-checker is the whole game here (lesson 11's rule). Each component
 * ends with a JSX block labelled THE SPEC: real usages, showing exactly
 * how it's meant to be called. Fix the component so its spec compiles —
 * never edit a spec block unless the task says the USAGE is the broken
 * part.
 *
 * Never edit lines containing Expect<Equal<...>> or @ts-expect-error —
 * they are the assertions you're satisfying. Never touch GIVEN-marked
 * blocks — they are complete and correct.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import type { ReactNode, ComponentProps } from "react"
import type { Track } from "./01-domain"
import { seedTracks } from "./01-domain"
import type { Genre } from "./03-tokens"
import { BADGE_TONES } from "./03-tokens"
import type { Draft, EditableHandlers } from "./05-type-kit"

// ---------------------------------------------------------------------------
// Task 1 — Optional props, React 19 style (lesson 11).
// GenreBadge demands size and children on EVERY usage, so the spec's bare
// `<GenreBadge genre="jazz" />` refuses to compile. Make both optional:
// `size?: number` with a destructuring default of 16 (the default erases
// undefined INSIDE the body — _e1 checks exactly that; a bare `size?`
// with no default won't satisfy it), and `children?: ReactNode`. Fix the
// TYPE and the destructuring only — the body is already right.
// ---------------------------------------------------------------------------

export type GenreBadgeProps = {
  genre: Genre
  size: number
  children: ReactNode
}

export function GenreBadge({ genre, size, children }: GenreBadgeProps) {
  type _e1 = Expect<Equal<typeof size, number>>
  return (
    <span className="genre-badge" style={{ color: BADGE_TONES[genre], fontSize: size }}>
      {children ?? genre}
    </span>
  )
}

// THE SPEC — do not edit:
const badgeSpec = (
  <>
    <GenreBadge genre="jazz" />
    <GenreBadge genre="ambient" size={12} />
    <GenreBadge genre="hip-hop">hip-hop / rap</GenreBadge>
  </>
)

// ---------------------------------------------------------------------------
// Task 2 — THE USAGE is broken this time; fix it HERE (lessons 11 + 04 + 02).
// GenreBadge is correct once Task 1 is done — these two CALLERS are not.
// One passed a genre that isn't in the union (read the error: it lists
// your options — that's stage 03's derived Genre doing its job in JSX),
// and one typo'd a prop name (lesson 02's excess-property shield, fired
// by JSX). Fix the call sites; touch nothing else.
// ---------------------------------------------------------------------------

// THE USAGE — broken this time; fix it here:
const crateFilters = (
  <div className="crate-filters">
    <GenreBadge genre="metall" size={12} />
    <GenreBadge genre="rock" siize={10} />
  </div>
)

// ---------------------------------------------------------------------------
// Task 3 — Make the impossible card unrepresentable (lessons 11 + 04).
// TrackCardProps is flat optional soup, so "playable but no handler"
// type-checks — and the body's props.onPlay call is 'possibly undefined'
// because the compiler can't connect two independent optional props.
// Rebuild the type as `{ track: Track } &` a two-branch union:
//   { playable: true; onPlay: (trackId: string) => void }  — handler REQUIRED
//   { playable?: false }                                   — no handler exists
// Keep the component taking `props` WHOLE and narrowing on props.playable
// (destructuring the signature would kill the narrowing) — the body is
// GIVEN and already does this. The @ts-expect-error line under the spec
// must STAY an error after your fix: that bug becomes unrepresentable.
// ---------------------------------------------------------------------------

export type TrackCardProps = {
  track: Track
  playable?: boolean
  onPlay?: (trackId: string) => void
}

// GIVEN — do not touch the body: narrowing on props.playable is the point.
export function TrackCard(props: TrackCardProps) {
  return (
    <article className="track-card">
      <strong>{props.track.title}</strong>
      <span> — {props.track.artist}</span>
      {props.playable && (
        <button onClick={() => props.onPlay(props.track.id)}>play</button>
      )}
    </article>
  )
}

// THE SPEC — do not edit:
const deckSpec = (
  <>
    <TrackCard track={seedTracks[0]} />
    <TrackCard
      track={seedTracks[4]}
      playable
      onPlay={(id) => {
        type _s3 = Expect<Equal<typeof id, string>>
        console.log(`playing ${id}`)
      }}
    />
  </>
)

// @ts-expect-error — playable without onPlay must NOT compile
const silentCard = <TrackCard track={seedTracks[2]} playable />

// ---------------------------------------------------------------------------
// Task 4 — Omit before you override (lessons 11 + 08).
// SearchInput wraps <input> but wants a friendlier onChange that hands you
// the string directly. Intersecting ComponentProps<"input"> with a NEW
// onChange doesn't replace the native one — the intersection demands one
// callback satisfying BOTH signatures (string AND ChangeEvent), which is
// why the spec's `value.toUpperCase()` refuses to compile. Omit the
// native "onChange" first, THEN add your own. Fix the TYPE only — the
// body is GIVEN.
// ---------------------------------------------------------------------------

export type SearchInputProps = ComponentProps<"input"> & {
  onChange: (value: string) => void
}

// GIVEN — do not touch: pluck our onChange off, spread the native rest
// through, translate the event to a string at the edge.
export function SearchInput({ onChange, ...rest }: SearchInputProps) {
  return <input {...rest} onChange={(e) => onChange(e.target.value)} />
}

type _e4 = Expect<Equal<Parameters<SearchInputProps["onChange"]>[0], string>>

// THE SPEC — do not edit:
const searchSpec = (
  <SearchInput
    placeholder="Search the crate"
    onChange={(value) => console.log(value.toUpperCase())}
  />
)

// ---------------------------------------------------------------------------
// Task 5 — A generic component (lessons 12 + 06).
// Whoever wrote List reached for `unknown`, so inside the spec's
// renderItem every track is a mystery. Make List generic with the
// function-declaration form — one type parameter tying `items` to
// `renderItem`:
//   function List<T>(props: { items: T[]; renderItem: (item: T) => ReactNode })
// The CALL SITE fills T in by inference (useState's trick from lesson 06,
// now in your own component). Do NOT touch the spec.
// ---------------------------------------------------------------------------

export function List(props: { items: unknown[]; renderItem: (item: unknown) => ReactNode }) {
  return (
    <ul className="list">
      {props.items.map((item, i) => (
        <li key={i}>{props.renderItem(item)}</li>
      ))}
    </ul>
  )
}

// THE SPEC — do not edit (hover `track` after the fix: your domain type
// flows through your generic):
const crateSpec = (
  <List
    items={seedTracks}
    renderItem={(track) => {
      type _s5 = Expect<Equal<typeof track, Track>>
      return <em>{track.title}</em>
    }}
  />
)

// ---------------------------------------------------------------------------
// Task 6 — The boss fight pays off (capstone stage 05 + lessons 09 + 08).
// Both types below were written BY HAND, and both have drifted: a draft
// should be all-optional and mutable (this one is required and locked to
// nothing), onDurationSecChange takes a string, and onArtistChange is
// missing entirely. Don't patch them — DERIVE them from the domain with
// YOUR stage-05 types (already imported above):
//   TrackDraft     = Draft<Pick<Track, "title" | "artist" | "durationSec">>
//   TrackFormProps = { draft: TrackDraft } &
//                    EditableHandlers<Pick<Track, "title" | "artist" | "durationSec">>
// Then hover the spec's three callbacks: their value params contextually
// type themselves (string, string, number) — nobody writes those
// signatures by hand ever again. The body is GIVEN; fix the two TYPES.
// ---------------------------------------------------------------------------

export type TrackDraft = {
  title: string
  artist: string
  durationSec: number
}

export type TrackFormProps = {
  draft: TrackDraft
  onTitleChange: (value: string) => void
  onDurationSecChange: (value: string) => void
}

// GIVEN — do not touch the body: each input reads its draft field (with a
// fallback — drafts are all-optional) and reports edits through the
// matching handler, the number field converting at the edge.
export function TrackForm(props: TrackFormProps) {
  return (
    <form className="track-form">
      <input
        value={props.draft.title ?? ""}
        onChange={(e) => props.onTitleChange(e.target.value)}
      />
      <input
        value={props.draft.artist ?? ""}
        onChange={(e) => props.onArtistChange(e.target.value)}
      />
      <input
        type="number"
        value={props.draft.durationSec ?? 0}
        onChange={(e) => props.onDurationSecChange(Number(e.target.value))}
      />
    </form>
  )
}

type _e6a = Expect<Equal<TrackDraft, { title?: string; artist?: string; durationSec?: number }>>
type _e6b = Expect<Equal<TrackFormProps["onDurationSecChange"], (value: number) => void>>

// THE SPEC — do not edit:
const editorSpec = (
  <TrackForm
    draft={{ title: "Pyramid Song" }}
    onTitleChange={(value) => {
      type _s6a = Expect<Equal<typeof value, string>>
    }}
    onArtistChange={(value) => {
      type _s6b = Expect<Equal<typeof value, string>>
    }}
    onDurationSecChange={(value) => {
      type _s6c = Expect<Equal<typeof value, number>>
    }}
  />
)

export {}
