/**
 * Capstone stage 07 — State, events, and hooks: wiring the player.
 *
 * This file intentionally does not type-check. It is stage 7 of 8 of ONE
 * app — Heavy Rotation — and it wires stage 02's player into React. Work
 * the stages in order (01 and 02 before this one), and within this file
 * work top to bottom until `./check 14` reports no errors mentioning `07-`.
 *
 * Type-check ONLY: hooks need a rendering React behind them, so there is
 * nothing to run here. The compiler going quiet is the finish line.
 *
 * Never edit lines containing Expect<Equal<...>> — they are the assertions
 * you're satisfying. Never touch GIVEN-marked blocks — they are complete
 * and correct.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { useReducer, useRef, useState } from "react"
import type {
  ChangeEvent,
  Dispatch,
  FormEvent,
  ReactNode,
  Ref,
  SetStateAction,
} from "react"
import type { Track } from "./01-domain"
import { seedTracks } from "./01-domain"
import { playerReducer } from "./02-player"
import type { PlayerAction, PlayerState } from "./02-player"

// ---------------------------------------------------------------------------
// Task 1 — Tell useState the whole story (lesson 12).
// The now-playing slot starts empty, and useState(null) infers a state
// type of `null` — a state that can NEVER hold a track, which is why the
// GIVEN playOpener helper errors. Pass the generic explicitly:
// useState<Track | null>(null). Fix the useState CALL only.
// ---------------------------------------------------------------------------
// Task 2 — Return a pair, not an array (lessons 07 + 12).
// The hook means to return [value, setter], but the bare return widens to
// an ARRAY of the union, so the ReturnType assertion below the hook stays
// red even after Task 1. One `as const` on the return line pins the tuple.
// ---------------------------------------------------------------------------

export function useNowPlaying() {
  const [nowPlaying, setNowPlaying] = useState(null)

  // GIVEN — complete and correct: the helper the dashboard taps to spin
  // up the opener. It compiles once the state can actually hold a Track.
  const playOpener = () => setNowPlaying(seedTracks[0])

  type _e1 = Expect<Equal<typeof nowPlaying, Track | null>>

  void playOpener // the hook keeps it private; the type story is the point

  return [nowPlaying, setNowPlaying]
}

type _e2 = Expect<
  Equal<
    ReturnType<typeof useNowPlaying>,
    readonly [Track | null, Dispatch<SetStateAction<Track | null>>]
  >
>

// ---------------------------------------------------------------------------
// GIVEN — the player hook. Complete and correct. DO NOT EDIT.
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

// ---------------------------------------------------------------------------
// Task 4 — Declare the ref prop (lesson 12; React 19: forwardRef is dead).
// SearchBox's GIVEN body forwards props.ref to its <input>, and PlayerBar's
// GIVEN JSX passes ref={inputRef} — both light up because SearchBoxProps
// never declared a `ref` prop. In React 19, ref is a REGULAR prop: add
// `ref?: Ref<HTMLInputElement>` (Ref is already imported; keep it
// optional). Fix the PROPS TYPE only — do NOT touch SearchBox's body or
// PlayerBar's JSX.
// (Tasks 3, 5, and 6 live inside PlayerBar, just below — the component had
// to exist before PlayerBar could render it.)
// ---------------------------------------------------------------------------

export type SearchBoxProps = {
  onSearch: (query: string) => void
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
// PlayerBar — the transport strip. Hosts Tasks 3, 5, and 6; work them in
// order, each has its own comment below.
// ---------------------------------------------------------------------------

export function PlayerBar(): ReactNode {
  const { state, dispatch } = usePlayer()
  const [query, setQuery] = useState("")

  // Task 3 — React 19's useRef ALWAYS takes an argument (lesson 12).
  //   - inputRef points at a DOM node that doesn't exist until render, so
  //     its initial value is null: useRef<HTMLInputElement>(null). A DOM
  //     ref's .current can then be null — make jumpToSearch survive that
  //     with ?. .
  //   - renderCount is a plain mutable box — call it as useRef(0) and let
  //     inference pick the type. Leave `renderCount.current += 1` alone.
  const inputRef = useRef<HTMLInputElement>()
  const renderCount = useRef<number>()
  renderCount.current += 1

  const jumpToSearch = () => inputRef.current.focus()

  type _e3 = Expect<Equal<typeof inputRef.current, HTMLInputElement | null>>

  // GIVEN — complete and correct: search the crate, play the first hit.
  // A dispatch call done RIGHT, for contrast with the two Task 5 repairs.
  const playFirstMatch = (q: string) => {
    const hit = seedTracks.find((t) => t.title.toLowerCase().includes(q.toLowerCase()))
    if (hit) dispatch({ type: "play", track: hit })
  }

  // Task 5 — Fix the dispatch CALLS (lesson 12, powered by lesson 04).
  // dispatch is typed by stage 02's PlayerAction union — imported and
  // untouchable, exactly as designed. One call typo'd its action type
  // (the error lists all four valid spellings), the other matched "seek"
  // but forgot its positionSec payload (pause at 30, seek to 90). Fix the
  // CALLS; the union and the reducer stay exactly as they are.
  const pauseAtThirty = () => dispatch({ type: "paws", positionSec: 30 })
  const seekToChorus = () => dispatch({ type: "seek" })

  type _e5 = Expect<Equal<typeof dispatch, Dispatch<PlayerAction>>>

  // Task 6 — Annotate the extracted handlers (lesson 12).
  // Inline handlers borrow their `e` type from the JSX attribute; these
  // three stand alone, so each `e` is implicitly any. You need
  // ChangeEvent<HTMLInputElement> (it reads e.target.value),
  // FormEvent<HTMLFormElement> (it calls e.preventDefault()), and
  // MouseEvent<HTMLButtonElement> (it calls e.currentTarget.blur()).
  // Careful with the third: MouseEvent is NOT in the type-only import list
  // at the top, so the DOM global resolves instead and the compiler says
  // "MouseEvent is not generic" — that error is pointing you at the IMPORT
  // line. Add MouseEvent to the type-only import from "react".
  function handleQueryChange(e) {
    setQuery(e.target.value)
  }

  function handleSubmit(e) {
    e.preventDefault()
    jumpToSearch()
  }

  function handleStopClick(e) {
    // React types currentTarget as EventTarget & T — the element you
    // registered the handler on, still wearing its EventTarget hat.
    type _e6 = Expect<Equal<typeof e.currentTarget, EventTarget & HTMLButtonElement>>
    e.currentTarget.blur()
    dispatch({ type: "stop" })
  }

  // GIVEN — the JSX. Complete and correct; Task 4's fix is what makes the
  // ref attribute on <SearchBox> legal. Do not edit.
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
