/**
 * Lesson 11 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import type { ReactNode, ComponentProps } from "react"

// Exercise 1 — a component's props are one object parameter, typed exactly
// like any lesson-02 object shape. The spec used label as a string and
// count as a number, so that's the type. Nothing React-specific happened.

type BadgeProps = {
  label: string
  count: number
}

function Badge({ label, count }: BadgeProps) {
  return (
    <span className="badge">
      {label}: {count}
    </span>
  )
}

type _e1 = Expect<Equal<Parameters<typeof Badge>[0], { label: string; count: number }>>

const badges = (
  <>
    <Badge label="inbox" count={3} />
    <Badge label="drafts" count={0} />
  </>
)

// Exercise 2 — `size?` makes the prop optional for CALLERS; the
// destructuring default `= 48` makes it a plain `number` INSIDE the body
// (the default erases undefined, which is what the assertion checks — a
// bare `size?: number` without the default would fail it). In old React
// you'd have reached for Avatar.defaultProps; React 19 ignores it on
// function components — and the type-checker still humors it, so it fails
// silently at runtime. The destructuring default is the whole story now.

type AvatarProps = {
  name: string
  size?: number
}

function Avatar({ name, size = 48 }: AvatarProps) {
  type _e2 = Expect<Equal<typeof size, number>>
  return <img alt={name} width={size} height={size} src={`/avatars/${name}.png`} />
}

const team = (
  <div>
    <Avatar name="david" />
    <Avatar name="ada" size={96} />
  </div>
)

// Exercise 3 — `children` is an ordinary prop that JSX nesting fills in.
// ReactNode is the right type: it's the union of everything React can
// render (elements, strings, numbers, null/undefined, iterables...).
// ReactElement would have rejected the plain text; string would have
// rejected the elements. `children?: ReactNode` would make nesting
// optional — required is the better default for a Card that's pointless
// when empty.

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

const stats = (
  <Card title="This week">
    <p>Weekly active users</p>
    <strong>1,204</strong>
  </Card>
)

// Exercise 4 — the component was right; the callers were wrong. Both fixes
// happen at the call site: "dangerous" isn't in the union (the error listed
// the three that are), and `size` doesn't exist on ButtonProps — the same
// excess property check from lesson 02, fired by JSX.

type ButtonProps = {
  variant: "primary" | "secondary" | "danger"
  label: string
}

function Button({ variant, label }: ButtonProps) {
  return <button className={`btn btn-${variant}`}>{label}</button>
}

const toolbar = (
  <div>
    <Button variant="primary" label="Save" />
    <Button variant="danger" label="Delete" />
    <Button variant="secondary" label="Cancel" />
  </div>
)

// Exercise 5 — the union has two branches keyed on the `dismissible`
// discriminant: the `true` branch carries a REQUIRED onDismiss; the
// absent/false branch has no handler at all. Now "dismissible but no
// handler" isn't a runtime bug — it's unrepresentable, which is why the
// line marked @ts-expect-error still (correctly) suppresses an error. The
// component keeps `props` whole: `props.dismissible &&` narrows to the
// first branch, so `props.onDismiss` is safe to read. (You could also
// write `{ message: string } & (union)` to avoid repeating `message`.)

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

const alerts = (
  <>
    <Alert message="Profile saved." />
    <Alert message="Session expiring soon." dismissible onDismiss={() => {}} />
  </>
)

// @ts-expect-error — dismissible with no handler must NOT compile
const brokenAlert = <Alert message="Unsaved changes." dismissible />

// Exercise 6 — ComponentProps<"button"> is every prop a native <button>
// accepts; the intersection bolts our own on top. In the signature we
// pluck OUR props off and collect the native remainder in `rest`, then
// spread it onto the element — so type="submit", disabled, onClick (and
// 200 friends) all pass straight through, fully typed.

type IconButtonProps = ComponentProps<"button"> & {
  icon: string
  label: string
}

function IconButton({ icon, label, ...rest }: IconButtonProps) {
  return (
    <button {...rest}>
      <span aria-hidden>{icon}</span> {label}
    </button>
  )
}

function handleDelete() {
  console.log("deleted")
}

const actions = (
  <div>
    <IconButton icon="save" label="Save" type="submit" />
    <IconButton icon="trash" label="Delete" disabled onClick={handleDelete} />
  </div>
)

// Exercise 7 — intersecting a NEW onChange doesn't replace the native one;
// it demands a function satisfying both signatures at once (string AND
// ChangeEvent), which no useful callback can. Omit the native key first,
// then add ours — now the spec's `value` is contextually typed as string.
// This Omit-then-extend move is the standard recipe whenever a wrapper
// reshapes a native prop.

type TextInputProps = Omit<ComponentProps<"input">, "onChange"> & {
  onChange: (value: string) => void
}

function TextInput({ onChange, ...rest }: TextInputProps) {
  return <input {...rest} onChange={(e) => onChange(e.target.value)} />
}

const search = (
  <TextInput
    placeholder="Search lessons"
    onChange={(value) => console.log(value.toUpperCase())}
  />
)

export {}
