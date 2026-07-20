/**
 * Lesson 12 — solution with commentary.
 *
 * Type-check only — hooks need a rendering React, so nothing here runs.
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

// Exercise 1 — useState is a generic function; it infers the state type
// from the initial value.
// (a) `useState(0)` infers number — hover it: the tuple is
//     [number, Dispatch<SetStateAction<number>>]. With the old "0", the
//     functional update's `c` was a string and `c * 2` blew up.

function ClickCounter() {
  const [count, setCount] = useState(0)

  // SetStateAction<number> = number | ((prev: number) => number), which is
  // why both plain values and these callbacks are accepted — and why `c`
  // needs no annotation.
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

// (b) `useState(null)` inferred `null` — a state that could never hold a
// User, so setUser({...}) was rejected. When the initial value doesn't
// tell the whole story, pass the generic explicitly. THE day-one fix.

function CurrentUser() {
  const [user, setUser] = useState<User | null>(null)

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

// Exercise 2 — React 19's useRef always takes an argument.
// DOM flavor: useRef<HTMLInputElement>(null) — the node doesn't exist until
// render, so .current is HTMLInputElement | null and needs `?.` at each use.
// Box flavor: useRef(0) — plain inference, .current is a mutable number.

function NameField() {
  const inputRef = useRef<HTMLInputElement>(null)
  const focusCount = useRef(0)

  const focusInput = () => {
    focusCount.current += 1
    inputRef.current?.focus() // optional chaining survives the null
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

// Exercise 3 — in React 19, ref is a regular prop: declare it like any
// other lesson-11 prop and you're done. No forwardRef (it's deprecated),
// no wrapper, no ceremony. Ref<HTMLInputElement> accepts both ref objects
// and callback refs; optional because most callers won't pass one.

type SearchInputProps = {
  placeholder: string
  ref?: Ref<HTMLInputElement>
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

// Exercise 4 — the discriminated union (lesson 04) makes dispatch
// spell-checked: "decrament" was rejected because it matches no member's
// `type`, and { type: "increment" } was rejected because that member
// requires a `by` payload. The reducer itself narrows per `case` exactly
// like every switch you wrote in lesson 04.

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
      <button onClick={() => dispatch({ type: "increment", by: 1 })}>+1</button>
      <button onClick={() => dispatch({ type: "decrement", by: 1 })}>-1</button>
      <button onClick={() => dispatch({ type: "reset" })}>reset</button>
    </div>
  )
}

// Exercise 5 — extracted handlers lose contextual inference, so `e` must be
// annotated. The types name the EVENT and the ELEMENT it's attached to:
//   onChange on <input>  → ChangeEvent<HTMLInputElement>  (e.target.value)
//   onSubmit on <form>   → FormEvent<HTMLFormElement>     (e.preventDefault)
//   onClick  on <button> → MouseEvent<HTMLButtonElement>  (e.currentTarget)
// When in doubt: write the handler inline, hover `e`, then extract.

function SignupForm() {
  const [email, setEmail] = useState("")

  function handleEmailChange(e: ChangeEvent<HTMLInputElement>) {
    setEmail(e.target.value)
  }

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
  }

  function handleClear(e: MouseEvent<HTMLButtonElement>) {
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

// Exercise 6 — `as const` (lesson 07) turns the widened array
// (boolean | (() => void))[] into the tuple readonly [boolean, () => void],
// so destructuring gives each position its own type — exactly what useState
// itself does. (An explicit return annotation would work too; `as const`
// is the idiom.)

function useToggle(initial: boolean) {
  const [on, setOn] = useState(initial)
  const toggle = () => setOn((v) => !v)
  return [on, toggle] as const
}

type _e6a = Expect<
  Equal<ReturnType<typeof useToggle>, readonly [boolean, () => void]>
>

function MuteButton() {
  const [muted, toggleMuted] = useToggle(false)

  type _e6b = Expect<Equal<typeof muted, boolean>>

  return <button onClick={toggleMuted}>{muted ? "muted" : "sound on"}</button>
}

// Exercise 7 — one type parameter ties items to renderItem, and the call
// site fills it in: items={tracks} fixes T = Track, so renderItem's `track`
// is fully typed with zero annotations. useState's trick, applied to your
// own component. (A `function` declaration dodges the `<T,>` trailing-comma
// hack generic arrow functions need in .tsx files.)

type ListProps<T> = {
  items: T[]
  renderItem: (item: T) => ReactNode
}

function List<T>({ items, renderItem }: ListProps<T>) {
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

export {}
