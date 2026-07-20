/**
 * Lesson 12 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 12` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * Type-check ONLY: hooks need a rendering React behind them, so there is
 * nothing to run here. The compiler going quiet is the finish line.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
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

// ---------------------------------------------------------------------------
// Exercise 1 — useState infers from the initial value.
// Two components, two classic mistakes. Fix only the useState CALLS.
//   (a) ClickCounter: the state is numeric, but the initial value isn't.
//       Hover the useState call before and after — watch the tuple change.
//   (b) CurrentUser: the state starts empty, and useState(null) infers a
//       state type of `null` — a state that can never hold a User. Pass the
//       generic explicitly so the type tells the whole story: User | null.
// ---------------------------------------------------------------------------

function ClickCounter() {
  const [count, setCount] = useState("0")

  // Functional updates: the callback parameter is typed by the state type.
  const increment = () => setCount((c) => c + 1)
  const double = () => setCount((c) => c * 2)

  type _e1a = Expect<Equal<typeof count, number>>
  type _e1b = Expect<Equal<typeof setCount, Dispatch<SetStateAction<number>>>>

  return (
    <button onClick={increment} onDoubleClick={double}>
      {count}
    </button>
  )
}

type User = { id: number; name: string }

function CurrentUser() {
  const [user, setUser] = useState(null)

  const logIn = () => setUser({ id: 1, name: "Ada Lovelace" })
  const logOut = () => setUser(null)

  type _e1c = Expect<Equal<typeof user, User | null>>

  return (
    <div>
      <p>{user ? user.name : "signed out"}</p>
      <button onClick={user ? logOut : logIn}>toggle session</button>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Exercise 2 — useRef in React 19 ALWAYS takes an argument.
// Three bugs, don't touch the assertions or the JSX:
//   - inputRef points at a DOM node that doesn't exist until render, so its
//     initial value is null: useRef<HTMLInputElement>(null).
//   - focusCount is a plain mutable box — give it a real starting value and
//     let inference pick the type: useRef(0).
//   - a DOM ref's .current can be null; make focusInput survive that.
// ---------------------------------------------------------------------------

function NameField() {
  const inputRef = useRef<HTMLInputElement>()
  const focusCount = useRef<number>()

  const focusInput = () => {
    focusCount.current += 1
    inputRef.current.focus()
  }

  type _e2a = Expect<Equal<typeof inputRef.current, HTMLInputElement | null>>
  type _e2b = Expect<Equal<typeof focusCount.current, number>>

  return (
    <div>
      <input ref={inputRef} placeholder="name" />
      <button onClick={focusInput}>focus the field</button>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Exercise 3 — in React 19, `ref` is a regular prop. No forwardRef.
// SearchBar wants to focus the <input> living inside SearchInput, so it
// passes its ref down — but SearchInputProps never declared a `ref` prop.
// Declare it (Ref<HTMLInputElement> is already imported; make it optional).
// Fix the props type ONLY — both components are already correct.
// ---------------------------------------------------------------------------

type SearchInputProps = {
  placeholder: string
}

function SearchInput({ placeholder, ref }: SearchInputProps) {
  return <input type="search" placeholder={placeholder} ref={ref} />
}

function SearchBar() {
  const inputRef = useRef<HTMLInputElement>(null)

  return (
    <div>
      <SearchInput placeholder="Search tracks…" ref={inputRef} />
      <button onClick={() => inputRef.current?.focus()}>jump to search</button>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Exercise 4 — useReducer + a discriminated union: lesson 04's payoff.
// The Action type and the reducer are correct — do NOT touch them. The
// component's dispatch calls are wrong: one forgot its payload, another
// typo'd its action type. The union catches both at the dispatch site;
// fix the calls.
// ---------------------------------------------------------------------------

type CounterAction =
  | { type: "increment"; by: number }
  | { type: "decrement"; by: number }
  | { type: "reset" }

function counterReducer(count: number, action: CounterAction): number {
  switch (action.type) {
    case "increment":
      return count + action.by
    case "decrement":
      return count - action.by
    case "reset":
      return 0
  }
}

function Counter() {
  const [count, dispatch] = useReducer(counterReducer, 0)

  type _e4 = Expect<Equal<typeof count, number>>

  return (
    <div>
      <output>{count}</output>
      <button onClick={() => dispatch({ type: "increment" })}>+1</button>
      <button onClick={() => dispatch({ type: "decrament", by: 1 })}>-1</button>
      <button onClick={() => dispatch({ type: "reset" })}>reset</button>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Exercise 5 — typed event handlers.
// Inline handlers get their `e` inferred; extracted ones don't — you
// annotate. The types you need are ChangeEvent<HTMLInputElement>,
// FormEvent<HTMLFormElement>, MouseEvent<HTMLButtonElement> (all already
// imported, type-only, from "react").
//   - handleEmailChange and handleClear: `e` is implicitly any. Not sure
//     which type fits? Write the handler inline in the JSX and hover `e`.
//   - handleSubmit: annotated with the WRONG event — it sits on a <form>.
// Fix the handler signatures; leave the JSX alone.
// ---------------------------------------------------------------------------

function SignupForm() {
  const [email, setEmail] = useState("")

  function handleEmailChange(e) {
    setEmail(e.target.value)
  }

  function handleSubmit(e: MouseEvent<HTMLButtonElement>) {
    e.preventDefault()
  }

  function handleClear(e) {
    e.currentTarget.blur()
    setEmail("")
  }

  type _e5 = Expect<Equal<typeof email, string>>

  return (
    <form onSubmit={handleSubmit}>
      <input type="email" value={email} onChange={handleEmailChange} />
      <button type="button" onClick={handleClear}>
        clear
      </button>
      <button type="submit">sign up</button>
    </form>
  )
}

// ---------------------------------------------------------------------------
// Exercise 6 — a custom hook returning a tuple: lesson 07's payoff.
// useToggle means to return a PAIR — value first, toggler second — but a
// bare `return [on, toggle]` infers the ARRAY (boolean | (() => void))[],
// so every destructured piece is that whole union. One `as const` on the
// return fixes the hook. Don't touch MuteButton or the assertions.
// ---------------------------------------------------------------------------

function useToggle(initial: boolean) {
  const [on, setOn] = useState(initial)
  const toggle = () => setOn((v) => !v)
  return [on, toggle]
}

// Asserting on a hook WITHOUT calling it: ReturnType, from lesson 08.
type _e6a = Expect<
  Equal<ReturnType<typeof useToggle>, readonly [boolean, () => void]>
>

function MuteButton() {
  const [muted, toggleMuted] = useToggle(false)

  type _e6b = Expect<Equal<typeof muted, boolean>>

  return <button onClick={toggleMuted}>{muted ? "muted" : "sound on"}</button>
}

// ---------------------------------------------------------------------------
// Exercise 7 — a generic component. This is useState's trick (lesson 06)
// applied to your own code: one type parameter ties `items` to `renderItem`,
// and the CALL SITE fills it in by inference. Whoever wrote List reached
// for `unknown` instead, so inside renderItem every track is a mystery.
// Make ListProps and List generic over the item type; do NOT touch Playlist.
// ---------------------------------------------------------------------------

type ListProps = {
  items: unknown[]
  renderItem: (item: unknown) => ReactNode
}

function List({ items, renderItem }: ListProps) {
  return (
    <ul>
      {items.map((item, i) => (
        <li key={i}>{renderItem(item)}</li>
      ))}
    </ul>
  )
}

type Track = { id: number; title: string }

function Playlist() {
  const [tracks] = useState<Track[]>([
    { id: 1, title: "So What" },
    { id: 2, title: "Blue in Green" },
  ])

  return (
    <List
      items={tracks}
      renderItem={(track) => {
        type _e7 = Expect<Equal<typeof track, Track>>
        return <em>{track.title}</em>
      }}
    />
  )
}

// ---------------------------------------------------------------------------
export {}
