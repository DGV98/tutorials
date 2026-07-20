/**
 * Capstone stage 06 — solution with commentary.
 *
 * Import rule: solution files import ONLY sibling solution files
 * (./01-domain), ../given/*, and ../../../helpers/* — NEVER ../NN-*
 * exercise files.
 */
import type { Expect, Equal } from "../../../helpers/type-assertions"
import type { ReactNode, ComponentProps } from "react"
import type { Track } from "./01-domain"
import { seedTracks } from "./01-domain"
import type { Genre } from "./03-tokens"
import { BADGE_TONES } from "./03-tokens"
import type { Draft, EditableHandlers } from "./05-type-kit"

// Task 1 — optional props, React 19 style (lesson 11). The spec calls
// GenreBadge three ways — bare, with a size, with children — so the type
// has to admit all three. `size?` makes the prop optional for CALLERS; the
// destructuring default `= 16` makes it a plain `number` INSIDE the body
// (the default erases undefined, which is exactly what _e1 checks — a bare
// `size?: number` with no default would fail it). children gets the same
// treatment: `children?: ReactNode`, because a badge with no children
// falls back to printing its genre. No defaultProps, no React.FC — the
// props type and the destructuring ARE the whole API.

export type GenreBadgeProps = {
  genre: Genre
  size?: number
  children?: ReactNode
}

export function GenreBadge({ genre, size = 16, children }: GenreBadgeProps) {
  type _e1 = Expect<Equal<typeof size, number>>
  return (
    <span className="genre-badge" style={{ color: BADGE_TONES[genre], fontSize: size }}>
      {children ?? genre}
    </span>
  )
}

// THE SPEC — all three call shapes compile now:
const badgeSpec = (
  <>
    <GenreBadge genre="jazz" />
    <GenreBadge genre="ambient" size={12} />
    <GenreBadge genre="hip-hop">hip-hop / rap</GenreBadge>
  </>
)

// Task 2 — the component was right; the CALLERS were wrong, and both fixes
// happen at the call site (lesson 11 Ex4's lesson, now with your own
// union). "metall" isn't a Genre — the error listed the five that are,
// because Genre is stage 03's derived union doing its job in JSX. And
// `siize` doesn't exist on GenreBadgeProps: the same excess-property
// shield from lesson 02, fired by JSX. Typos die at the call site, not in
// production.

// THE USAGE — fixed at the call sites:
const crateFilters = (
  <div className="crate-filters">
    <GenreBadge genre="electronic" size={12} />
    <GenreBadge genre="rock" size={10} />
  </div>
)

// Task 3 — the flat optional-soup props made "playable but no handler"
// representable, which is why the body's props.onPlay call was 'possibly
// undefined' — the compiler was pointing at a real design bug, not a
// missing `!`. The union fixes the DESIGN: the `playable: true` branch
// carries a REQUIRED onPlay, the absent/false branch has no handler at
// all. `{ track: Track } & (branch | branch)` keeps the shared prop
// written once (lesson 11 Ex5's closing hint). And the component keeps
// `props` WHOLE: `props.playable &&` narrows to the true branch, so
// props.onPlay is safe — destructuring at the signature would have torn
// the discriminant away from the handler and killed the narrowing.
// The spec's @ts-expect-error line still suppresses a real error:
// playable-without-a-handler is now unrepresentable, which was the point.

export type TrackCardProps = { track: Track } & (
  | { playable: true; onPlay: (trackId: string) => void }
  | { playable?: false }
)

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

// THE SPEC — a plain card, and a playable one whose handler is fully typed:
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

// Task 4 — Omit before you override (lesson 11 Ex7, now on your own
// search box). Intersecting a NEW onChange doesn't replace the native one;
// it demands one function satisfying BOTH signatures (string AND
// ChangeEvent), which no useful callback can. Omit the native "onChange"
// first, THEN add ours — now the spec's `value` is contextually typed as
// plain string, and _e4 pins the parameter type down with lesson 08's
// Parameters so nobody re-introduces the collision.

export type SearchInputProps = Omit<ComponentProps<"input">, "onChange"> & {
  onChange: (value: string) => void
}

// GIVEN — the body was always right: pluck our onChange off, spread the
// native remainder through, translate the event to a string at the edge.
export function SearchInput({ onChange, ...rest }: SearchInputProps) {
  return <input {...rest} onChange={(e) => onChange(e.target.value)} />
}

type _e4 = Expect<Equal<Parameters<SearchInputProps["onChange"]>[0], string>>

// THE SPEC — a friendly string-first callback, native props still welcome:
const searchSpec = (
  <SearchInput
    placeholder="Search the crate"
    onChange={(value) => console.log(value.toUpperCase())}
  />
)

// Task 5 — a generic component via a plain function declaration (lesson 12
// Ex7's move, kept because it's the one form that stays out of JSX's way).
// One type parameter ties `items` to `renderItem`: pass Track[] and the
// callback's item IS a Track — the call site fills T in by inference, the
// same trick useState plays (lesson 06). `unknown` was the honest
// placeholder while nobody knew the element type; the generic is the
// honest answer now that the CALLER knows.

export function List<T>(props: { items: T[]; renderItem: (item: T) => ReactNode }) {
  return (
    <ul className="list">
      {props.items.map((item, i) => (
        <li key={i}>{props.renderItem(item)}</li>
      ))}
    </ul>
  )
}

// THE SPEC — hover `track`: your domain type flowed through your generic:
const crateSpec = (
  <List
    items={seedTracks}
    renderItem={(track) => {
      type _s5 = Expect<Equal<typeof track, Track>>
      return <em>{track.title}</em>
    }}
  />
)

// Task 6 — the boss fight pays off. The hand-copied TrackDraft had already
// drifted (required + mutable is the opposite of a draft), and the
// hand-written props type drifted twice more: onDurationSecChange took a
// string, and onArtistChange didn't exist at all. That's what hand-copying
// buys you. Derive both instead:
//   Draft<Pick<Track, ...>>            — stage 05's -readonly + ? mapped
//                                        type: everything unlocked,
//                                        everything optional;
//   EditableHandlers<Pick<Track, ...>> — stage 05's remap-to-never
//                                        filter: every string/number field
//                                        earns an onXxxChange handler whose
//                                        value parameter is T[K] itself.
// Because the handlers are DERIVED, the spec's three callbacks contextually
// type their value params (string, string, number) with nobody writing
// those signatures by hand — the types you built in the soundproof arena
// of stage 05 are now lighting up real JSX. Rename a Track field tomorrow
// and this form's props follow automatically.

export type TrackDraft = Draft<Pick<Track, "title" | "artist" | "durationSec">>

export type TrackFormProps = { draft: TrackDraft } & EditableHandlers<
  Pick<Track, "title" | "artist" | "durationSec">
>

// GIVEN — the body was always right: each input reads its draft field
// (with a fallback, since drafts are all-optional) and reports edits
// through the matching handler — the number field converting at the edge.
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

// THE SPEC — a partial draft is legal, and each handler knows its type:
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
