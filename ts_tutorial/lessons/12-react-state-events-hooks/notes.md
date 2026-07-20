# Lesson 12 — State, events, and hooks

**Why this matters for React:** lesson 11 typed what goes *into* a component;
this lesson types what happens *inside* one — state, refs, reducers, events.
Every day-one question ("why is my state stuck as `null`?", "what type is
`e`?") is answered by a concept you already own: generics (lesson 06),
discriminated unions (lesson 04), `as const` (lesson 07).

## `useState` is a generic function

You wrote generic functions in lesson 06. `useState` is one — its type
parameter is the state type, inferred from the initial value. Hover the
call (`K`) and read what comes back:

```tsx
const [query, setQuery] = useState("")
//    hover: [string, Dispatch<SetStateAction<string>>]
```

A **tuple** (lesson 02): current value, then setter. `SetStateAction<S>` is
just `S | ((prevState: S) => S)` — so the setter takes a plain value *or* a
**functional update**, whose parameter needs no annotation:

```tsx
setQuery("jazz")            // plain value
setQuery((q) => q + "!")    // functional update — q inferred as string
```

## State that starts empty — THE question

The most common day-one mistake in React TypeScript:

```tsx
const [user, setUser] = useState(null)
setUser({ id: 1, name: "Ada" })
// ^ not assignable to parameter of type 'SetStateAction<null>'
```

Inference did its job: initial value `null` → state type `null`, which can
never hold a `User`. When the initial value can't tell the whole story:

```tsx
const [user, setUser] = useState<User | null>(null)
```

Now `user` is `User | null`, and every use forces the "what if nobody's
logged in?" check — narrowing (lesson 04) does the rest.

## `useRef` — two flavors, one rule (React 19)

In React 19 `useRef` **requires an argument** — `useRef()` is a type error.
The two flavors differ only in what that argument is:

```tsx
const inputRef = useRef<HTMLInputElement>(null) // DOM ref — starts null
const renders = useRef(0)                       // mutable box — RefObject<number>

inputRef.current?.focus()  // .current is HTMLInputElement | null — survive it
```

A DOM ref starts `null` because the node doesn't exist until render. The box
flavor is plain inference — read and write `.current` freely; no re-render.

## `ref` is just a prop now

React 19 retired `forwardRef` — don't learn it, don't write it. A component
that wants to hand out a DOM node declares `ref` like any other lesson-11
prop (`Ref` is type-only: `import type { Ref } from "react"`):

```tsx
type SearchInputProps = {
  placeholder: string
  ref?: Ref<HTMLInputElement>
}

function SearchInput({ placeholder, ref }: SearchInputProps) {
  return <input type="search" placeholder={placeholder} ref={ref} />
}
```

The parent passes its `useRef<HTMLInputElement>(null)` ref as a normal
attribute. No wrapper, no second type parameter, no ceremony.

## `useReducer` — lesson 04's payoff

Model actions as a **discriminated union** and the reducer narrows on
`action.type` exactly like every `switch` you wrote in lesson 04:

```tsx
type CounterAction =
  | { type: "increment"; by: number }
  | { type: "decrement"; by: number }
  | { type: "reset" }

function counterReducer(count: number, action: CounterAction): number {
  switch (action.type) {
    case "increment": return count + action.by
    case "decrement": return count - action.by
    case "reset":     return 0
  }
}

const [count, dispatch] = useReducer(counterReducer, 0)
```

The payoff lands at the **dispatch site**: a typo'd `type` or a missing
payload is a compile error. Your whole state machine is spell-checked.

## Typed events — the hover trick

Inline handlers get `e` inferred for free; the moment you extract one to a
named function, inference is gone and `e` is implicitly `any` (a strict-mode
error). The trick: **write it inline first, hover `e`, extract with that type**:

```tsx
<input onChange={(e) => {}} />   // hover e: ChangeEvent<HTMLInputElement>
```

The ones you'll use constantly — all type-only imports from `"react"`:

```tsx
function handleChange(e: ChangeEvent<HTMLInputElement>) { /* e.target.value */ }
function handleSubmit(e: FormEvent<HTMLFormElement>)    { e.preventDefault() }
function handleClick(e: MouseEvent<HTMLButtonElement>)  { /* e.currentTarget */ }
```

(Recent `@types/react` may show `SubmitEvent<HTMLFormElement>` when you hover
an inline `onSubmit` — a refinement of `FormEvent`; either spelling checks.)

Careful: without the import, `MouseEvent` still resolves — to the DOM global
from `lib.dom`, a different type that won't assign. Check the import first.

## Custom hooks — return tuples with `as const`

A custom hook is just a function that calls hooks, so everything from lesson
06 applies. The one trap is returning a pair:

```tsx
function useToggle(initial: boolean) {
  const [on, setOn] = useState(initial)
  const toggle = () => setOn((v) => !v)
  return [on, toggle] as const   // readonly [boolean, () => void]
}
```

Without `as const` (lesson 07) the return widens to the array
`(boolean | (() => void))[]`, and destructuring hands every position that
whole union; with it, a real tuple, like `useState`'s own. (An explicit
return annotation works too — `as const` is the idiom.)

## Generic components — `useState`'s trick, for you

A type parameter on a component ties props to each other, and the **call
site** fills it in by inference — the same move `useState` pulls:

```tsx
type ListProps<T> = {
  items: T[]
  renderItem: (item: T) => ReactNode
}

function List<T>({ items, renderItem }: ListProps<T>) {
  return <ul>{items.map((item, i) => <li key={i}>{renderItem(item)}</li>)}</ul>
}

<List items={tracks} renderItem={(track) => track.title} />
// T inferred as Track — inside renderItem, track is fully typed
```

Prefer `function` declarations for generic components: in a `.tsx` file a
generic *arrow* function needs an ugly trailing comma (`<T,>`) so the
compiler knows `<T>` isn't a JSX tag.

## Exercises

Open `exercises.tsx`. This lesson is **type-check only** — hooks need a
rendering React, so nothing runs; the compiler going quiet is the finish
line. Hooks can only be *called* inside components or other hooks, so the
assertions sit inside component bodies (or use `ReturnType`, lesson-08 style).

```
./check 12
```

Stuck? `solution.tsx` sits next door, with commentary.

## Key takeaways

- `useState` is a generic function: state type inferred from the initial
  value, returned as a tuple — hover the call and read it.
- State that starts empty needs the generic: `useState<User | null>(null)`.
- React 19's `useRef` always takes an argument: `null` for DOM refs (then
  `.current` is nullable — `?.` it), a real value for mutable boxes.
- `ref` is a regular prop (`ref?: Ref<HTMLInputElement>`); `forwardRef` is
  deprecated — don't reach for it.
- A discriminated-union `Action` makes every `dispatch` spell-checked.
- Extracted handlers need event types — write inline, hover `e`, extract.
- Custom hooks returning pairs want `as const`; generic components let the
  call site infer, just like `useState`.

Next up — lesson 13, the finale: these patterns inside Next.js (page props,
route handlers, server actions, typed `fetch`).
