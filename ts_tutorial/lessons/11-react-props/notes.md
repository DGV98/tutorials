# Lesson 11 — React props: components are just functions

**Why this matters for React:** it doesn't "matter for React" anymore — it
IS React. Part 3 starts here: ten lessons ago you were fixing
string-vs-number mixups, and now you're typing real components. And here's
the payoff the course has been promising all along: there is almost nothing
new to learn today. A component is a function (lesson 03). Its props are one
object parameter (lesson 02). A `variant` prop is a literal union (lessons
01 and 04). Impossible prop combinations get banished with a discriminated
union (lesson 04), and wrapping a native `<button>` is `Omit` plus an
intersection (lesson 08). React didn't bring a new type system — your type
system just got a rendering engine.

## A component is a function; props are its (only) parameter

A React function component takes ONE argument — the props object — and
returns JSX. So typing a component is typing an object parameter, exactly
like lesson 02:

```tsx
type BadgeProps = {
  label: string
  count: number
}

function Badge({ label, count }: BadgeProps) {
  return <span className="badge">{label}: {count}</span>
}
```

And every JSX usage is a type-checked function call:

```tsx
<Badge label="inbox" count={3} />            // ok
<Badge label="inbox" count="3" />            // error: string where number belongs
<Badge label="inbox" />                      // error: count is missing
<Badge label="inbox" count={3} clr="red" />  // error: 'clr' does not exist
```

That last one deserves a beat: JSX attributes form a fresh object literal,
so lesson 02's excess property checks fire at every call site. A typo'd
prop name IS an excess property error — hover the squiggle and you can
already parse every word of it.

## Why `type Props` + a plain function (and not `React.FC`)

Older codebases write `const Badge: React.FC<BadgeProps> = (props) => ...`.
It still works, but this course — like the current React docs — writes a
plain function with a typed parameter:

- the return type is inferred, so there's nothing extra to annotate,
- function declarations hoist and read better in diffs,
- generic components (lesson 12) are awkward to express through `React.FC`,
- historically `React.FC` silently added `children` to every component;
  that's fixed in modern `@types/react`, but the habit died with it.

`React.FC` isn't wrong — it's machinery that buys nothing here.

## Optional props: `?` plus a destructuring default

```tsx
type AvatarProps = {
  name: string
  size?: number     // callers may omit it — lesson 02's `?`
}

function Avatar({ name, size = 48 }: AvatarProps) {
  // hover size: it's `number` — the default erased `undefined`
  return <img alt={name} width={size} height={size} src={`/avatars/${name}.png`} />
}
```

Inside the body `size` is plain `number`; at the call site it's optional.
One mechanism, both sides typed honestly.

If you ever read pre-2024 React: `Avatar.defaultProps = { ... }` is dead —
React 19 ignores it on function components entirely. Worse, the
type-checker still humors `defaultProps` for legacy reasons, so nothing
warns you while React silently ignores it at runtime. The destructuring
default IS the API now.

## `children` is just a prop

Nesting JSX between a component's tags passes it as the `children` prop —
no magic, just a prop with a conventional name:

```tsx
import type { ReactNode } from "react"

type CardProps = {
  title: string
  children: ReactNode
}

function Card({ title, children }: CardProps) {
  return (
    <section className="card">
      <h2>{title}</h2>
      {children}
    </section>
  )
}

const usage = (
  <Card title="This week">
    <p>Numbers are up.</p>
  </Card>
)
```

Two things to do in your editor right now:

- **Hover `ReactNode`** — it's a union of everything React can render:
  elements, strings, numbers, bigints, booleans, `null`, `undefined`,
  iterables of more ReactNodes — and, new in React 19, Promises of all of
  the above.
- **`gd` into it** — you land inside `@types/react` itself. After lessons
  06–09, the definitions in there are readable to you. That was the plan.

For `children` you almost always want `ReactNode` (anything renderable) —
not `ReactElement` (elements only; rejects plain strings) and not `string`
(rejects elements).

Note the import: this project has `verbatimModuleSyntax` on, so type-only
imports must be written `import type { ReactNode } from "react"`.

## Literal-union props

Lesson 01 promised that literal types would power React prop patterns.
Here's the payoff:

```tsx
type ButtonProps = {
  variant: "primary" | "secondary" | "danger"
  label: string
}
```

Now `<Button variant="dangerous" label="Delete" />` is a compile error that
names every valid option. You get autocomplete too — type `variant="` inside
the JSX and let the editor list the union.

## Discriminated unions: invalid prop combos become unrepresentable

Some props only make sense together. A dismissible alert needs an
`onDismiss` handler; a non-dismissible one must not have one. Making both
optional allows nonsense. Lesson 04's discriminated unions make the
nonsense impossible to write:

```tsx
type AlertProps =
  | { message: string; dismissible: true; onDismiss: () => void }
  | { message: string; dismissible?: false }

function Alert(props: AlertProps) {
  return (
    <div role="alert">
      <p>{props.message}</p>
      {props.dismissible && <button onClick={props.onDismiss}>Dismiss</button>}
    </div>
  )
}
```

Two details worth noticing:

- The component takes `props` whole and narrows on `props.dismissible` —
  destructuring in the signature would fail, because `onDismiss` doesn't
  exist on every branch. Narrow first; lesson 04 rules apply unchanged.
- In JSX, a bare boolean attribute means `true`: `<Alert ... dismissible />`
  passes the literal `true`, selecting the first branch — which then
  REQUIRES `onDismiss`. Forgetting the handler is now a compile error.

## Wrapping native elements: `ComponentProps`

Real design-system components wrap native elements. Your `IconButton`
should accept everything a real `<button>` does — `type`, `disabled`,
`onClick`, all of it — without you listing 200 attributes by hand:

```tsx
import type { ComponentProps } from "react"

type IconButtonProps = ComponentProps<"button"> & {
  icon: string
}

function IconButton({ icon, ...rest }: IconButtonProps) {
  return (
    <button {...rest}>
      <span aria-hidden>{icon}</span>
    </button>
  )
}
```

Three moving parts:

1. `ComponentProps<"button">` — every prop a native `<button>` accepts.
2. `& { icon: string }` — an intersection adds your own props (lesson 05).
3. `{ icon, ...rest }` then `<button {...rest}>` — pluck YOUR props off,
   spread the native remainder onto the element.

When your prop REPLACES a native one, a plain intersection backfires: the
native `onChange` and yours collide, demanding one function that satisfies
both signatures. `Omit` the native prop first (lesson 08), THEN add yours:

```tsx
type TextInputProps = Omit<ComponentProps<"input">, "onChange"> & {
  onChange: (value: string) => void
}
```

(`ComponentProps` also works on your own components —
`ComponentProps<typeof Card>` recovers `CardProps`. Handy when a library
doesn't export its props type.)

## Exercises

Open `exercises.tsx` — note the extension: JSX lives in `.tsx` files. Then:

```
./check 11
```

That's the only command this time. There's nothing to `npx tsx` — components
describe UI, and UI needs a browser to render. That's not a limitation, it's
the lesson: in real React work the type-checker is what catches a broken
call site before your users do, and this lesson is played entirely against
the checker. The red squiggles in the JSX are the exercise.

Each exercise ends with a JSX block labelled THE SPEC — real usages of the
component. The spec is the source of truth: fix the component's types until
its spec compiles. Never edit a spec block (or an `Expect<Equal<...>>` line)
unless the exercise explicitly says the usage is the broken part.

Stuck? `solution.tsx` sits next door, with commentary.

## Key takeaways

- A component is a function; props are its single object parameter —
  `type Props = {...}`, then destructure. No `React.FC` required.
- Every JSX call site is type-checked like a function call; a typo'd prop
  is lesson 02's excess property error wearing angle brackets.
- Optional prop = `?` in the type + a destructuring default in the
  signature. React 19 ignores `defaultProps` on function components.
- `children: ReactNode` — nesting between tags is just passing a prop.
- Literal-union props buy you both errors and autocomplete at call sites.
- Props that must travel together belong in a discriminated union — invalid
  combinations become unrepresentable; narrow `props` inside the component.
- Wrap native elements with `ComponentProps<"tag"> & {...}`; `Omit` first
  when overriding a native prop; spread `...rest` onto the element.
- Next, lesson 12: state, events, refs, and hooks — the interactive half of
  React's type story.
