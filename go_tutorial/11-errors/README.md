# 11. Errors

Go has no exceptions. Failure is a value — an ordinary return value
you receive, inspect, decorate, and pass along, using the same `if`
statements you use for everything else. Coming from languages with
`try`/`catch`, this feels verbose for about a day; then you notice
that every possible failure point in a Go program is visible right
where it happens, and that reading unfamiliar code no longer requires
guessing what might throw. This module covers the whole error
toolkit: making errors, the ubiquitous `if err != nil`, wrapping and
unwrapping chains of errors, and the escape hatch — `panic` — that
you will almost never use.

## What you'll learn

- `error` is just an interface — nothing magic, no special syntax
- The `if err != nil` idiom, early returns, and the happy path on the left margin
- Creating errors with `errors.New` and `fmt.Errorf`
- Wrapping with `%w`; matching through chains with `errors.Is` and `errors.As`
- Sentinel errors like `ErrNotFound` and why `==` is the wrong test
- Custom error types that carry structured data
- `panic` and `recover`, and why returned errors are the norm
- Error message style: lowercase, no punctuation, add context when wrapping

## error is just an interface

The entire error mechanism rests on one tiny interface, predeclared in
the language (no import needed):

```go
type error interface {
	Error() string
}
```

That's it. Anything with an `Error() string` method is an error. There
is no throw statement, no exception hierarchy, no stack unwinding.
When module 10 said small interfaces are the heart of Go, this is
exhibit A: the most-used interface in the language has one method.

Consequences worth internalizing:

- An `error` is a value like any other — store it in a struct, put it
  in a slice, return it from a function, compare it to `nil`.
- `nil` means success. A nil interface value has no method to call, so
  by convention "no error" is spelled `nil`.
- You can define your own error types by writing one method (you will,
  below).

## if err != nil and early returns

The dominant shape of Go code — you saw it foreshadowed in module 04's
multiple returns — is:

```go
n, err := strconv.Atoi(line)
if err != nil {
	return 0, fmt.Errorf("parse line: %w", err)
}
// use n — err is out of the picture from here down
```

Handle the failure immediately, `return` early, and keep going.
Because each failing branch exits, the success path runs straight down
the left margin with no nesting, and every failure is handled exactly
where it can occur. This is a deliberate style choice the whole
ecosystem shares:

```go
func loadGame(path string) (*Game, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("load game: %w", err)
	}
	cfg, err := parseConfig(data)
	if err != nil {
		return nil, fmt.Errorf("load game: %w", err)
	}
	return newGame(cfg), nil
}
```

Yes, you will type `if err != nil` thousands of times. It stops
registering as noise and starts registering as a checklist: every call
that can fail is visibly accounted for. The compiler helps — an
unused variable is a compile error, so you can't silently drop an
`err` you assigned with `:=`. (You *can* drop one with `_`; doing so
is a loud, greppable statement that you mean it.)

## Creating errors: errors.New and fmt.Errorf

Two constructors cover nearly everything:

```go
import (
	"errors"
	"fmt"
)

// Fixed message: errors.New.
errDivZero := errors.New("division by zero")

// Formatted message: fmt.Errorf (it's Sprintf that returns an error).
err := fmt.Errorf("row %d: expected %d fields, got %d", i, want, got)
```

Use `errors.New` when the message is a constant, `fmt.Errorf` when it
needs data. Both produce values whose `Error()` method returns the
message — nothing more. In particular, Go errors do **not**
automatically carry stack traces; the context you add while wrapping
(next section) plays that role, and reads better.

## Wrapping with %w, matching with errors.Is and errors.As

An error that bubbles up through three layers of calls is useless if
it still just says `open input.txt: no such file or directory` — which
of the twelve files you open was it? Each layer should add what it
knows. `fmt.Errorf` has a special verb for this, `%w` ("wrap"):

```go
data, err := os.ReadFile(path)
if err != nil {
	return fmt.Errorf("read puzzle input: %w", err)
}
```

`%w` formats like `%v`, but it also records the wrapped error inside
the new one, forming a chain:

```
read puzzle input: open input.txt: no such file or directory
└── *fs.PathError
    └── syscall.ENOENT
```

Two functions from the `errors` package walk that chain:

- **`errors.Is(err, target)`** reports whether `target` appears
  anywhere in `err`'s chain. It answers "*is* this failure
  fundamentally that known error?"

  ```go
  if errors.Is(err, fs.ErrNotExist) {
  	// the file is missing, however deeply that fact got wrapped
  }
  ```

- **`errors.As(err, &target)`** searches the chain for an error of
  `target`'s type, and if found, copies it into `target` so you can
  read its fields. It answers "is there a *typed* error in here with
  data I can use?"

  ```go
  var pathErr *fs.PathError
  if errors.As(err, &pathErr) {
  	fmt.Println("failed path:", pathErr.Path)
  }
  ```

Rule of thumb: `Is` for identity (sentinels), `As` for data (custom
types). Both replace the naive `err == target` and type assertions,
which see only the outermost layer and break the moment anyone adds a
wrap. Always compare errors with `errors.Is`, never `==`.

The choice between `%w` and `%v` when building an error is an API
decision: `%w` invites callers to inspect the cause; `%v` flattens it
to text and hides it. Default to `%w` unless the cause is an
implementation detail you may want to change later.

## Sentinel errors

A *sentinel* is an exported, package-level error value that callers
can test for by identity:

```go
var ErrNotFound = errors.New("not found")

func Lookup(m map[string]int, key string) (int, error) {
	v, ok := m[key]
	if !ok {
		return 0, fmt.Errorf("lookup %q: %w", key, ErrNotFound)
	}
	return v, nil
}
```

The stdlib is full of them: `io.EOF`, `fs.ErrNotExist`,
`strconv.ErrSyntax`, `sql.ErrNoRows`. The naming convention is a
variable (not a type) named `Err...`.

Note that `Lookup` doesn't return the bare sentinel — it wraps it with
the key, so the message is helpful *and* the identity survives:

```go
v, err := Lookup(inventory, "torch")
if errors.Is(err, ErrNotFound) {   // true even though err != ErrNotFound
	// take the "missing" branch
}
```

A sentinel is a contract: once exported, callers depend on it, and its
message and identity are frozen. Export one only when callers
genuinely need to distinguish that failure from others.

## Custom error types carrying data

When callers need more than identity — *which* field failed, *what*
the limit was — define a type. Any struct with an `Error() string`
method is an error:

```go
type ValidationError struct {
	Field  string
	Reason string
}

func (e *ValidationError) Error() string {
	return e.Field + ": " + e.Reason
}
```

Return it as a plain `error`, and let callers dig it out with
`errors.As`:

```go
err := ValidateUser("", 30)

var ve *ValidationError
if errors.As(err, &ve) {
	fmt.Println("bad field:", ve.Field) // structured data, no string parsing
}
```

Two conventions to copy:

- **Pointer receiver, pointer return.** With `func (e *ValidationError)
  Error()`, the error type is `*ValidationError`, so that is what
  `errors.As` must look for — hence `var ve *ValidationError`. Pointer
  receivers are the norm for error structs (module 09's receiver rules
  apply unchanged).
- **Declared return type `error`.** Functions return the interface, not
  the concrete type — see the typed-nil gotcha below for why this is
  more than style.

## panic and recover

`panic(v)` aborts the normal flow: the current function stops, its
deferred calls run, then its caller's defers run, and so on up the
stack until the program crashes with a stack trace — unless a deferred
function calls `recover()`, which stops the unwinding and returns the
value passed to `panic`.

```go
func DontPanic(f func()) (err error) {
	defer func() {
		if v := recover(); v != nil {
			err = fmt.Errorf("panic: %v", v)
		}
	}()
	f()
	return nil
}
```

Every piece of that shape is load-bearing:

- `recover` does something only when called **directly inside a
  deferred function** during a panic; anywhere else it returns `nil`.
- The result **must be a named return value** (`err error`). The
  `return` statement already ran or never will — assigning to `err`
  in the deferred closure is the only remaining way to set the result
  (module 04's defer rules, now earning their keep).
- `recover()` returns `any` — whatever value was passed to `panic` —
  so it gets formatted with `%v`, not treated as an error directly.

Now the important part: **why you'll almost never write this.** The
division of labor in Go is:

- **Errors** are for *expected* failures — bad input, missing files,
  a key not in the map. Things that are the environment's fault, that
  the caller can plausibly handle. They are part of a function's
  signature and its documented contract.
- **Panics** are for *programmer bugs* — index out of range, nil
  pointer dereference, impossible states. Things that shouldn't be
  handled but fixed. The runtime panics on your behalf for exactly
  these.

Don't use `panic` as a cross-function control-flow shortcut, and don't
use `recover` as a `catch`-all to keep a broken program limping along.
Legitimate `recover` sits at hard boundaries: a server that must not
let one request's bug kill the other thousand (`net/http` does this),
or a test harness running untrusted student code — which is precisely
the `DontPanic` exercise. Legitimate `panic` in application code is
essentially "this cannot happen, and if it does I want a loud crash
here rather than corrupt data later."

## Error message style

Error strings have firm conventions (enforced by reviewers and
linters across the ecosystem):

- **Lowercase, no trailing punctuation:** `"division by zero"`, not
  `"Division by zero."`. Messages get wrapped into larger messages —
  `parse config: division by zero` — and capitals or periods in the
  middle of that read as garbage. (Proper nouns keep their case:
  `"parsing JSON: ..."` is fine.)
- **Add context when wrapping, `"context: %w"`:** each layer prefixes
  what *it* was doing, colon, the cause. Chains read outermost-first,
  like a breadcrumb trail: `start server: load config: open app.conf:
  no such file`.
- **No `"error: "` prefix, no `"failed to"` stutter.** Every error is
  a failure; say what was being attempted (`"load config: %w"`), not
  that it failed.
- **Include the operative values**, ideally with `%q` for strings —
  `parse age "abc"` pinpoints the culprit; `parse age` sends you off
  logging.

## Gotchas & idioms

- **Compare with `errors.Is`, never `==`.** `err == io.EOF` breaks as
  soon as anything wraps the error. (Historical footnote: pre-1.13
  code did use `==`, and `io.EOF` specifically is still matched that
  way by convention inside the stdlib — but new code should use
  `errors.Is` throughout.)
- **`%w` only works in `fmt.Errorf`.** In `fmt.Sprintf` or a print
  function it's a mistake (`go vet` catches it). Multiple `%w` verbs
  in one `Errorf` are allowed (since Go 1.20) and wrap all of them.
- **The typed-nil trap.** Never declare an error variable with a
  concrete type on a success path:

  ```go
  func check(x int) error {
  	var ve *ValidationError // nil pointer... so far so good
  	if x < 0 {
  		ve = &ValidationError{Field: "x", Reason: "negative"}
  	}
  	return ve // BUG: non-nil error even when ve is nil!
  }
  ```

  A nil `*ValidationError` stuffed into an `error` interface is a
  non-nil interface (module 10: an interface is nil only when both its
  type and value are nil), so `check(5) != nil`. Fix: return literal
  `nil` on success, and only ever create the concrete value on failure
  paths.
- **`errors.As` needs a pointer to your error type.** For a pointer
  error type that means a pointer to a pointer at the call site:
  `var ve *ValidationError; errors.As(err, &ve)`. Passing `ve` without
  `&` compiles (the parameter type is `any`) but panics at run time;
  so does `var ve ValidationError` (no `*`) with `&ve`, because plain
  `ValidationError` doesn't implement `error` when the method has a
  pointer receiver. `go vet` catches both mistakes.
- **Handle or return, not both.** Logging an error *and* returning it
  means every layer logs it again. Each error should be dealt with
  exactly once: wrap-and-return on the way up, and act on it (log,
  retry, exit) at exactly one place, usually near `main`.
- **`recover` outside a deferred function is a no-op** that returns
  `nil`. It must be `defer func() { ... recover() ... }()` — even
  `defer recover()` directly doesn't stop a panic usefully.
- **Don't wrap reflexively at every layer.** Wrap when you add
  information (which file, which key, which stage). `return err`
  unchanged is fine for thin helpers that have nothing to add.
- **`errors.Join(errs...)`** combines multiple errors into one that
  `errors.Is`/`As` search through — handy for "validate everything and
  report all problems" instead of first-failure-wins.

## In Advent of Code

AoC inputs are trusted — your own puzzle input, on disk, correct by
construction — so AoC code is one of the few places where minimal
error handling is defensible: many people write a `must(err)` helper
that panics, and that's fine for a 60-line solution you run twice.
But you still *consume* errors constantly: `strconv.Atoi` on every
parsed number, `os.ReadFile` on the input (module 15), and `io.EOF`
sentinel checks when scanning. Knowing the `(value, error)` shape and
`errors.Is` cold means these are one-liners instead of speed bumps.
And the panic/recover story pays off on debugging day: when your
solution dies with `index out of range`, that panic is Go telling you
the exact line where your grid math went wrong — far better than a
silently wrong answer.

## Exercises

Implement the stubs in `errs.go`. The tests define the contracts
precisely; read them.

- **`SafeDivide(a, b float64) (float64, error)`** — division with an
  error instead of `+Inf` on a zero divisor. Message exactly
  `"division by zero"` — which constructor fits a fixed message?
- **`ParseAge(s string) (int, error)`** — `strconv.Atoi` plus rules.
  Wrap the strconv failure with `fmt.Errorf("parse age %q: %w", ...)`
  so the tests' `errors.Is(err, strconv.ErrSyntax)` still succeeds;
  reject negative ages with a plain (non-wrapping) formatted error.
- **`Lookup(m map[string]int, key string) (int, error)`** — the
  comma-ok map form (module 06) decides between value and error; wrap
  `ErrNotFound` with the quoted key. The test asserts you did *not*
  return the bare sentinel.
- **`(*ValidationError).Error() string`** — one line; mind the exact
  `"field: reason"` format.
- **`ValidateUser(name string, age int) error`** — first failure wins;
  return `&ValidationError{...}` (a pointer — the tests extract
  `*ValidationError` with `errors.As`) or literal `nil`.
- **`Chain(err error) error`** — two nested `fmt.Errorf("...: %w")`
  calls producing `"outer: inner: <msg>"`. The tests push a sentinel
  and a `*ValidationError` through it and expect `errors.Is` and
  `errors.As` to find them at the bottom. Don't decorate `nil`.
- **`DontPanic(f func()) (err error)`** — the recover pattern from the
  lesson, verbatim shape: deferred closure, `recover()`, assign
  `fmt.Errorf("panic: %v", v)` to the named result. The tests panic
  with a string, an int, an error, and a real out-of-range slice
  index.

## Check your work

Run the module's tests from the repo root:

```sh
go test ./11-errors/
```

Fresh stubs compile but fail every test; make them pass one exercise
at a time (`go test ./11-errors/ -run TestLookup` narrows the run).
When everything is green — or when you're stuck — compare your code
with `solution/`, which passes the byte-identical test file:

```sh
go test ./11-errors/solution/
```
