/**
 * Capstone stage 07 — solution with commentary.
 *
 * Import rule: solution files import ONLY sibling solution files
 * (./01-domain), ../given/*, and ../../../helpers/* — NEVER ../NN-*
 * exercise files.
 *
 * Type-check only — hooks need a rendering React behind them, so nothing
 * here runs.
 */
import type { Expect, Equal } from "../../../helpers/type-assertions"
import { useReducer, useRef, useState } from "react"
import type {
  ChangeEvent,
  Dispatch,
  FormEvent,
  MouseEvent,
  ReactNode,
  Ref,
  SetStateAction,
} from "react"
import type { Track } from "./01-domain"
import { seedTracks } from "./01-domain"
import { playerReducer } from "./02-player"
import type { PlayerAction, PlayerState } from "./02-player"

// Task 1 — useState(null) inferred a state type of `null` (lesson 12): a
// now-playing slot that could never hold a track, which is why the GIVEN
// playOpener helper's setNowPlaying(seedTracks[0]) call was rejected. When
// the initial value doesn't tell the whole story, pass the generic
// explicitly — useState<Track | null>(null) — and both halves of the story
// (empty now, a Track later) live in the type.
//
// Task 2 — `return [nowPlaying, setNowPlaying]` widened to a plain ARRAY
// of the union (lesson 07's widening rule, fixed exactly like lesson 12's
// useToggle), so every destructured piece at a call site would have been
// value-or-setter soup. `as const` pins the pair: value first, setter
// second, readonly, forever. The assertion below checks the hook WITHOUT
// calling it — ReturnType, from lesson 08 — because hooks only run inside
// components.

export function useNowPlaying() {
  const [nowPlaying, setNowPlaying] = useState<Track | null>(null)

  // GIVEN — complete and correct: the helper the dashboard taps to spin
  // up the opener. It compiles precisely because the state can hold a
  // Track now.
  const playOpener = () => setNowPlaying(seedTracks[0])

  type _e1 = Expect<Equal<typeof nowPlaying, Track | null>>

  void playOpener // the hook keeps it private; the type story is the point

  return [nowPlaying, setNowPlaying] as const
}

type _e2 = Expect<
  Equal<
    ReturnType<typeof useNowPlaying>,
    readonly [Track | null, Dispatch<SetStateAction<Track | null>>]
  >
>

// ---------------------------------------------------------------------------
// GIVEN — the player hook. Complete and correct.
// Stage 02's reducer meets React: useReducer takes YOUR playerReducer plus
// an initial state, and the whole state machine comes along for the ride —
// hover `state` and `dispatch` in PlayerBar and see PlayerState and
// Dispatch<PlayerAction>. The exhaustive switch you proved in stage 02 is
// now the type safety of every dispatch call below.
// ---------------------------------------------------------------------------

export function usePlayer(): { state: PlayerState; dispatch: Dispatch<PlayerAction> } {
  const [state, dispatch] = useReducer(playerReducer, { status: "stopped" })
  return { state, dispatch }
}

// Task 4 — in React 19, ref is a regular prop (lesson 12; forwardRef is
// dead). SearchBox's body always forwarded props.ref to its <input>, and
// PlayerBar always passed one — the only thing missing was the props type
// ADMITTING it. One optional property fixes both ends at once:
// Ref<HTMLInputElement> accepts ref objects and callback refs alike, and
// it's optional because most callers won't pass one. Notice there was
// nothing to change in either component — declaring the prop was the
// whole fix, which is the entire point of the React 19 design.

export type SearchBoxProps = {
  onSearch: (query: string) => void
  ref?: Ref<HTMLInputElement>
}

// GIVEN — complete and correct.
export function SearchBox(props: SearchBoxProps): ReactNode {
  return (
    <input
      type="search"
      placeholder="Search the crate…"
      ref={props.ref}
      onChange={(e) => props.onSearch(e.target.value)}
    />
  )
}

// ---------------------------------------------------------------------------
// PlayerBar — the transport strip. Hosts Tasks 3, 5, and 6.
// ---------------------------------------------------------------------------

export function PlayerBar(): ReactNode {
  const { state, dispatch } = usePlayer()
  const [query, setQuery] = useState("")

  // Task 3 — React 19's useRef ALWAYS takes an argument (lesson 12).
  // DOM flavor: the <input> doesn't exist until render, so the honest
  // starting value is null — useRef<HTMLInputElement>(null) — and .current
  // stays HTMLInputElement | null forever, which is why jumpToSearch
  // reaches through it with ?. instead of pretending. Box flavor:
  // useRef(0) — plain inference from the initial value, a mutable number
  // renderCount bumps on every render without re-rendering anything.
  const inputRef = useRef<HTMLInputElement>(null)
  const renderCount = useRef(0)
  renderCount.current += 1

  const jumpToSearch = () => inputRef.current?.focus()

  type _e3 = Expect<Equal<typeof inputRef.current, HTMLInputElement | null>>

  // GIVEN — complete and correct: search the crate, play the first hit.
  // A dispatch call done RIGHT, for contrast with the two Task 5 repairs.
  const playFirstMatch = (q: string) => {
    const hit = seedTracks.find((t) => t.title.toLowerCase().includes(q.toLowerCase()))
    if (hit) dispatch({ type: "play", track: hit })
  }

  // Task 5 — dispatch is typed by stage 02's PlayerAction union, so every
  // call site is spell-checked (lesson 12 Ex4, powered by lesson 04's
  // discriminated unions). "paws" matched no member's `type` — the error
  // listed all four spellings — and { type: "seek" } matched the member
  // but arrived without its positionSec payload. The union was untouchable
  // by design: your reducer is the contract, so the CALLS had to change.
  const pauseAtThirty = () => dispatch({ type: "pause", positionSec: 30 })
  const seekToChorus = () => dispatch({ type: "seek", positionSec: 90 })

  type _e5 = Expect<Equal<typeof dispatch, Dispatch<PlayerAction>>>

  // Task 6 — extracted handlers get no inference (lesson 12). Inline
  // handlers borrow their `e` type from the JSX attribute; these three
  // stand alone, so each parameter needed its annotation: ChangeEvent for
  // the input, FormEvent for the form, MouseEvent for the button. The
  // trap: MouseEvent wasn't in the type-only import list, so annotating
  // resolved the DOM GLOBAL MouseEvent instead — "MouseEvent is not
  // generic" — and the real fix was on the IMPORT line, not the handler.
  // React's synthetic events shadow DOM names on purpose; when one
  // misbehaves, check the imports first.
  function handleQueryChange(e: ChangeEvent<HTMLInputElement>) {
    setQuery(e.target.value)
  }

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    jumpToSearch()
  }

  function handleStopClick(e: MouseEvent<HTMLButtonElement>) {
    // React types currentTarget as EventTarget & T — the element you
    // registered the handler on, still wearing its EventTarget hat.
    type _e6 = Expect<Equal<typeof e.currentTarget, EventTarget & HTMLButtonElement>>
    e.currentTarget.blur()
    dispatch({ type: "stop" })
  }

  // GIVEN — the JSX. Complete and correct; Task 4's fix is what makes the
  // ref attribute on <SearchBox> legal.
  return (
    <form onSubmit={handleSubmit}>
      <SearchBox onSearch={playFirstMatch} ref={inputRef} />
      <input value={query} onChange={handleQueryChange} placeholder="Filter the queue…" />
      <p>
        {state.status === "stopped"
          ? "nothing playing"
          : `${state.status}: ${state.track.title} (render #${renderCount.current})`}
      </p>
      <button type="button" onClick={pauseAtThirty}>
        pause at 0:30
      </button>
      <button type="button" onClick={seekToChorus}>
        seek to 1:30
      </button>
      <button type="button" onClick={handleStopClick}>
        stop
      </button>
      <button type="submit">jump to search</button>
    </form>
  )
}

// ---------------------------------------------------------------------------
export {}
