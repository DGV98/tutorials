/**
 * Lesson 11 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 11` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * New for the React lessons: there is nothing to run. Components describe
 * UI, and UI needs a browser — the type-checker is the whole game here.
 * Each exercise ends with a JSX block labelled THE SPEC: real usages of the
 * component, showing exactly how it's meant to be called. Fix the component
 * so its spec compiles. Never edit a spec block unless the exercise says
 * the usage is the broken part.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
// verbatimModuleSyntax is on, so type-only imports from React must use
// `import type`. Both of these get used in the exercises below.
import type { ReactNode, ComponentProps } from "react"

// ---------------------------------------------------------------------------
// Exercise 1 — Props are just an object shape (lesson 02, wearing JSX).
// Badge's parameter has no type, so its destructured fields are implicit
// `any`. Declare a BadgeProps type and annotate the parameter. The spec
// tells you exactly which props exist and what their types are; the
// assertion (using lesson 08's Parameters) keeps you honest.
// ---------------------------------------------------------------------------

function Badge({ label, count }) {
  return (
    <span className="badge">
      {label}: {count}
    </span>
  )
}

type _e1 = Expect<Equal<Parameters<typeof Badge>[0], { label: string; count: number }>>

// THE SPEC — do not edit:
const badges = (
  <>
    <Badge label="inbox" count={3} />
    <Badge label="drafts" count={0} />
  </>
)

// ---------------------------------------------------------------------------
// Exercise 2 — Optional props, React 19 style.
// The spec calls Avatar with and without `size`, but the type demands it
// every time. Make `size` optional with a destructuring default of 48.
// (In old React you'd bolt on `Avatar.defaultProps` — React 19 ignores
// that on function components; the destructuring default IS the API.)
// The assertion inside the component proves the default erases `undefined`
// from the type: a bare `size?: number` with no default won't satisfy it.
// ---------------------------------------------------------------------------

type AvatarProps = {
  name: string
  size: number
}

function Avatar({ name, size }: AvatarProps) {
  type _e2 = Expect<Equal<typeof size, number>>
  return <img alt={name} width={size} height={size} src={`/avatars/${name}.png`} />
}

// THE SPEC — do not edit:
const team = (
  <div>
    <Avatar name="david" />
    <Avatar name="ada" size={96} />
  </div>
)

// ---------------------------------------------------------------------------
// Exercise 3 — `children` is just a prop.
// Card is meant to render a titled box around whatever you nest inside its
// tags — but its props never declare `children`, so nesting anything is an
// error. Declare `children` with the right type (hover ReactNode; `gd` into
// it to see everything it accepts) and render it inside the section.
// ---------------------------------------------------------------------------

type CardProps = {
  title: string
}

function Card({ title }: CardProps) {
  return (
    <section className="card">
      <h2>{title}</h2>
    </section>
  )
}

// THE SPEC — do not edit:
const stats = (
  <Card title="This week">
    <p>Weekly active users</p>
    <strong>1,204</strong>
  </Card>
)

// ---------------------------------------------------------------------------
// Exercise 4 — Literal unions at the call site. FIX THE USAGE, not the
// component. Button is correct: `variant` only accepts the three strings in
// its union (lesson 04 paying off). One caller typo'd the variant, another
// passed a prop that doesn't exist — a textbook excess property error
// (lesson 02). Read each error carefully; the first even lists every valid
// option.
// ---------------------------------------------------------------------------

type ButtonProps = {
  variant: "primary" | "secondary" | "danger"
  label: string
}

function Button({ variant, label }: ButtonProps) {
  return <button className={`btn btn-${variant}`}>{label}</button>
}

// THE USAGE — broken this time; fix it here:
const toolbar = (
  <div>
    <Button variant="primary" label="Save" />
    <Button variant="dangerous" label="Delete" />
    <Button variant="secondary" label="Cancel" size="lg" />
  </div>
)

// ---------------------------------------------------------------------------
// Exercise 5 — Discriminated union props (lesson 04's biggest payoff).
// Alert's type has a design bug: `dismissible` and `onDismiss` are both
// required, so a plain non-dismissible alert can't be written at all.
// Rewrite AlertProps as a two-branch union:
//   { message; dismissible: true; onDismiss: () => void }  — handler REQUIRED
//   { message; dismissible?: false }                       — no handler exists
// Keep the component taking `props` whole and narrowing (destructuring the
// signature would fail — onDismiss doesn't exist on every branch). The
// usage marked @ts-expect-error at the bottom must STAY an error:
// dismissible without a handler is exactly the bug your union makes
// unrepresentable.
// ---------------------------------------------------------------------------

type AlertProps = {
  message: string
  dismissible: boolean
  onDismiss: () => void
}

function Alert(props: AlertProps) {
  return (
    <div role="alert">
      <p>{props.message}</p>
      {props.dismissible && <button onClick={props.onDismiss}>Dismiss</button>}
    </div>
  )
}

// THE SPEC — do not edit:
const alerts = (
  <>
    <Alert message="Profile saved." />
    <Alert message="Session expiring soon." dismissible onDismiss={() => {}} />
  </>
)

// @ts-expect-error — dismissible with no handler must NOT compile
const brokenAlert = <Alert message="Unsaved changes." dismissible />

// ---------------------------------------------------------------------------
// Exercise 6 — Wrapping a native element.
// IconButton should behave like a real <button>: every native button prop
// (type, disabled, onClick, ...) plus its own `icon` and `label`. Extend
// ComponentProps<"button"> with an intersection, collect the native props
// with ...rest in the destructuring, and spread them onto the <button>.
// ---------------------------------------------------------------------------

type IconButtonProps = {
  icon: string
  label: string
}

function IconButton({ icon, label }: IconButtonProps) {
  return (
    <button>
      <span aria-hidden>{icon}</span> {label}
    </button>
  )
}

function handleDelete() {
  console.log("deleted")
}

// THE SPEC — do not edit:
const actions = (
  <div>
    <IconButton icon="save" label="Save" type="submit" />
    <IconButton icon="trash" label="Delete" disabled onClick={handleDelete} />
  </div>
)

// ---------------------------------------------------------------------------
// Exercise 7 — Omit before you override (lesson 08 paying off).
// TextInput wraps <input> but wants a friendlier onChange that hands you
// the string directly. Intersecting ComponentProps<"input"> with a NEW
// onChange doesn't replace the native one — the intersection demands one
// function satisfying BOTH signatures, which is why the spec's callback
// refuses to compile. Omit the native "onChange" first, THEN add your own.
// ---------------------------------------------------------------------------

type TextInputProps = ComponentProps<"input"> & {
  onChange: (value: string) => void
}

function TextInput({ onChange, ...rest }: TextInputProps) {
  return <input {...rest} onChange={(e) => onChange(e.target.value)} />
}

// THE SPEC — do not edit:
const search = (
  <TextInput
    placeholder="Search lessons"
    onChange={(value) => console.log(value.toUpperCase())}
  />
)

// ---------------------------------------------------------------------------
export {}
