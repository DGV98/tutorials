# 01. Hello, Go

Go was designed for exactly the kind of programming Advent of Code demands:
read some input, transform it, print an answer — fast, with a standard
library that covers almost everything and a toolchain so uniform that every
Go project on Earth builds and tests the same way. This first module gets
you fluent with that toolchain and with `fmt`, the package you will use in
literally every program you write from here on. The formatting verbs you
drill here (`%d`, `%q`, `%8.2f`, ...) are the same mini-language you'll use
to debug slices, dump grids, and print puzzle answers.

## How this course works

Every module in this repo follows the same loop. Learn it once here and it
carries you through all eighteen modules:

1. **Read the module's `README.md`** (this file) — it is the lesson.
2. **Open the exercise file** — here, `01-hello/hello.go`. Each exported
   function has a doc comment stating its exact contract and a body that
   currently just returns a zero value (`""` for strings) below a
   `// TODO: implement` marker. The package compiles as-is; it just gives
   wrong answers.
3. **Run the tests** from the repository root:

   ```sh
   go test ./01-hello/
   ```

4. **Read the failure**, fix your code, run again. Right now, with the
   stubs untouched, you'll see failures like this:

   ```
   --- FAIL: TestGreet (0.00s)
       --- FAIL: TestGreet/simple_name (0.00s)
           hello_test.go:23: Greet("Gopher") = "", want "Hello, Gopher! Welcome to Go."
   ...
   FAIL
   FAIL	gotutorial/01-hello	0.001s
   ```

   Every failure message has the shape `Func(input) = got, want want` —
   the test told you the input, what your code returned, and what it
   should have returned. That's the whole game: make `got` equal `want`.
5. **Compare with `solution/`** when you're done (or truly stuck). Each
   module has a `solution/` subdirectory containing idiomatic reference
   implementations and the *same* tests, so `go test ./01-hello/solution/`
   always passes.

One heads-up: the test files use a few Go features you haven't been taught
yet (structs, slices, `for ... range` loops — they arrive in modules 03–09).
You don't need to understand the test plumbing yet. Read the tables of
inputs and expected outputs, and the failure messages.

## What you'll learn

- The `go` command: `run`, `build`, `test`, `fmt`, `vet`, `doc`
- The anatomy of a `.go` file: package clause, imports, `func main`
- How packages relate to the module defined in `go.mod`
- `fmt.Println`, `fmt.Printf`, `fmt.Sprintf` and the difference between them
- The essential verbs: `%v` `%d` `%s` `%f` `%q` `%T` `%x`
- Width and padding: `%5d`, `%-10s`, `%8.2f`

## The Go toolchain

Go ships as a single `go` binary with subcommands. There is no separate
build system to choose, no formatter debate, no linter to configure — the
toolchain is the same for every project. Run all of these from the
repository root.

**`go run`** compiles and runs a `main` package in one step (nothing is
left on disk). This module ships a tiny demo program; try it:

```sh
$ go run ./01-hello/demo
Hello, Go!
Gopher
50
...
```

**`go build`** compiles packages. For a `main` package it drops an
executable in the current directory; for library packages it just
type-checks and reports errors. The idiom `go build ./...` means "build
everything from here down" (`./...` is a package wildcard you'll use with
almost every subcommand):

```sh
$ go build ./...          # silence means success
$ go build ./01-hello/demo
$ ./demo                  # a real, dependency-free binary
Hello, Go!
```

**`go test`** finds files ending in `_test.go`, runs the `TestXxx`
functions inside them, and prints `ok` or the failures. Flags you'll use
constantly:

```sh
go test ./01-hello/                 # this module's tests
go test ./...                       # every test in the repo
go test ./01-hello/ -v              # list every subtest, pass or fail
go test ./01-hello/ -run TestGreet  # only tests matching a name
```

**`go fmt`** (a wrapper over the `gofmt` tool) rewrites your files into
*the* canonical Go style — tabs, brace placement, alignment, everything.
There are no style options. This sounds authoritarian and is genuinely one
of Go's best features: all Go code everywhere looks the same, so you never
spend a code review arguing about it.

```sh
go fmt ./01-hello/    # prints the names of any files it had to fix
```

**`go vet`** catches mistakes that *compile* but are almost certainly bugs.
Its killer feature for this module: it type-checks your `Printf`/`Sprintf`
verbs against the arguments:

```go
fmt.Printf("%d\n", "not a number")
```

```sh
$ go vet .
main.go:6:14: fmt.Printf format %d has arg "not a number" of wrong type string
```

Get in the habit now: `go vet ./...` before you consider anything done.

**`go doc`** shows the documentation for any package or symbol, straight
from the doc comments in the source — no browser needed:

```sh
$ go doc fmt.Sprintf
package fmt // import "fmt"

func Sprintf(format string, a ...any) string
    Sprintf formats according to a format specifier and returns the resulting
    string.
```

Try `go doc fmt` for the whole package — its verb reference table is the
single most useful page of Go documentation.

## Anatomy of a .go file

Here is the smallest complete Go program (this is essentially
`01-hello/demo/main.go`):

```go
package main

import "fmt"

func main() {
	fmt.Println("Hello, Go!")
}
```

Three parts, always in this order:

1. **The package clause** — the first statement of every `.go` file, no
   exceptions. All files in one directory must declare the *same* package;
   a directory *is* a package. The name `main` is magic: a `main` package
   with a `func main()` builds to an executable. Any other name
   (like this module's `package hello`) is a library that other packages
   import.
2. **Imports** — every package you use must be imported, and Go *refuses
   to compile* if you import something you don't use (more under Gotchas).
   Multiple imports use a parenthesized block:

   ```go
   import (
   	"fmt"
   	"strings"
   )
   ```

3. **Declarations** — functions, types, constants, variables. `func main()`
   takes no arguments and returns nothing; it's the entry point.

Notice what's *absent*: no semicolons (the compiler inserts them at line
ends, which is also why the opening `{` must sit on the same line as
`func`), and no class wrapping everything — functions live directly at
package level.

Two conventions that are load-bearing in Go, not just taste:

- **Capitalization is visibility.** `Greet` (capital G) is *exported* —
  usable from other packages, and reachable by the tests. `greet` would be
  private to the package. There is no `public`/`private` keyword; the
  first letter *is* the keyword.
- **Doc comments.** A comment directly above a declaration, starting with
  the declared name ("Greet returns ..."), is documentation — it's what
  `go doc` prints. The exercise stubs' doc comments are their contracts.

## Packages and the module (go.mod)

At the root of this repo sits `go.mod`:

```
module gotutorial

go 1.26
```

A **module** is the unit of versioning and dependency management: this
whole repo. A **package** is the unit of compilation and import: one
directory. The import path of a package is simply

```
module path + "/" + directory path
```

so the package in `01-hello/` has import path `gotutorial/01-hello`, and
the solution is `gotutorial/01-hello/solution`. Note the directory name
(`01-hello`, `solution`) and the package name (`hello` in both cases) are
different things — the import path is how you *find* a package, the
package name is what you *type* to use it (`hello.Greet(...)`). By
convention they usually match; here the numbered directory names serve the
course ordering instead.

You will not need to touch `go.mod` in this course: we use only the
standard library, which needs no entries there. When you eventually add a
third-party dependency in your own projects, `go get` records it in
`go.mod` and the checksums in `go.sum` — that's the whole story.

## The fmt package

`fmt` (pronounced "fumt" by approximately no one and "format" by everyone)
handles formatted I/O. Three functions cover 95% of usage:

```go
fmt.Println("scores:", 3, 7)         // spaces between args, newline at end
fmt.Printf("%s scored %d\n", n, s)   // format string with verbs, NO auto-newline
s := fmt.Sprintf("%s: %d", name, x)  // like Printf, but RETURNS the string
```

- **`Println`** — quick and dirty: prints each argument in its default
  format, separated by spaces, followed by a newline. Perfect for
  debugging.
- **`Printf`** — a format string containing *verbs* (the `%` things), then
  one argument per verb. It does **not** append a newline; end your format
  string with `\n` or your output runs together.
- **`Sprintf`** — identical formatting, but returns the `string` instead
  of printing it. **Every exercise in this module returns strings, so
  `Sprintf` is your tool.** This is a deliberate lesson in Go design:
  functions that *return* strings are testable and reusable; printing is
  something `main` does at the edge of the program.

### The essential verbs

| Verb | Meaning                                | Example input   | Output       |
|------|----------------------------------------|-----------------|--------------|
| `%v` | default format for *any* value         | `3.5`, `"hi"`   | `3.5`, `hi`  |
| `%d` | integer, base 10                       | `42`            | `42`         |
| `%s` | string (uninterpreted)                 | `"Gopher"`      | `Gopher`     |
| `%f` | float, decimal, 6 digits by default    | `0.98765`       | `0.987650`   |
| `%q` | double-quoted, Go-escaped string       | `say "hi"`      | `"say \"hi\""` |
| `%T` | the Go *type* of the value             | `0.98765`       | `float64`    |
| `%x` | hexadecimal (lowercase)                | `255`           | `ff`         |
| `%%` | a literal percent sign                 | —               | `%`          |

`%v` is the safe default when you don't care about presentation — it works
on every type, including the structs, slices, and maps you'll meet later.
`%q` looks redundant next to `%s` until the first time trailing whitespace
or an embedded tab makes two "identical" strings compare unequal; `%q`
makes the invisible visible. `%T` answers "what type IS this thing?"
during debugging.

### Width, precision, and alignment

Between the `%` and the verb you can specify a minimum **width**, and for
floats a **precision** after a dot:

```go
fmt.Printf("[%5d]\n", 50)      // [   50]      width 5, right-aligned (default)
fmt.Printf("[%-10s]\n", "Go")  // [Go        ] '-' flag = left-aligned
fmt.Printf("[%8.2f]\n", 3.5)   // [    3.50]   width 8, 2 decimals
fmt.Printf("[%.2f]\n", 123.456) // [123.46]    precision only — note: ROUNDED
fmt.Printf("[%05d]\n", 42)     // [00042]      '0' flag = pad with zeros
```

Widths are *minimums*: a value too big for its field just takes more room,
it is never truncated. Line up several `Printf` calls with the same widths
and you get an aligned table — exactly what the `FormatScore` and
`TableRow` exercises drill.

## Gotchas & idioms

- **Unused imports and unused local variables are compile errors**, not
  warnings. This shocks everyone at first ("I'm just experimenting!") but
  keeps real codebases free of dead cruft. While debugging, the idiom
  `_ = someVar` silences the error temporarily.
- **`Printf` does not add a newline.** If your output looks glued
  together, you forgot `\n`. `Println` adds one (and spaces between
  arguments); `Printf` gives you exact control and therefore no favors.
- **Too few/too many arguments doesn't crash** — it produces output like
  `%!d(MISSING)` or `%!(EXTRA string=x)` at runtime. `go vet` catches
  these mistakes before they run; use it.
- **Don't fight `gofmt`.** Tabs for indentation, brace on the same line —
  run `go fmt ./...` and move on. Formatting-consistent code is a Go
  cultural cornerstone.
- **Capitalization is API.** Renaming `greet` to `Greet` isn't cosmetic;
  it changes what other packages (and the course tests) can see.
- **`+` vs `Sprintf`:** for gluing two strings, `"Hello, " + name` is
  perfectly idiomatic and faster. Reach for `Sprintf` the moment
  non-strings, widths, or more than a couple of pieces are involved.
- **`%v` everywhere is a smell in *final* output.** It's ideal for
  debugging, but for user-facing formatting pick the precise verb — it
  documents intent and lets `go vet` check types.

## In Advent of Code

Every AoC solution ends with printing an answer, and `fmt` is how. Beyond
that: `Sprintf` builds map keys from coordinates (`fmt.Sprintf("%d,%d", x, y)`
is a classic trick before you learn struct keys), `%q` is the fastest way
to discover that your puzzle input has a trailing newline or `\r\n` line
endings (the classic "why doesn't my parse work" bug), width verbs make
debug dumps of grids and intermediate tables readable, and `%T` sorts out
type confusion when a calculation mysteriously misbehaves. The
edit-test-iterate loop you're practicing here is exactly the AoC rhythm:
run, read the diff between got and want, fix, repeat.

## Exercises

Open `01-hello/hello.go` and implement, in order (each doc comment there
is the precise contract; the tests in `hello_test.go` enforce it):

1. **`Greet(name string) string`** — return exactly
   `Hello, <name>! Welcome to Go.` One `Sprintf` with one `%s` (or simple
   concatenation — your choice).
2. **`FormatScore(name string, score int) string`** — the name
   left-aligned in a 10-wide field, a `|`, the score right-aligned in a
   5-wide field. Hint: one format string, two verbs; remember which side
   the `-` flag goes on and that right-alignment is the default.
3. **`QuoteWords(first, second, third string) string`** — the three words
   quoted and comma-separated: `"go", "is", "fun"`. Hint: `%q` does *all*
   the quoting and escaping; do not add quote characters yourself.
4. **`Banner(text string) string`** — `*** <text> ***`. Trivial on
   purpose: it's a `Sprintf`-vs-concatenation judgment call. (A banner
   whose border matches the text length needs `strings.Repeat` — that
   satisfaction arrives in module 07.)
5. **`TableRow(day string, stars int, seconds float64) string`** — three
   `|`-separated aligned columns: `%-8s`, then a 4-wide integer, then an
   8-wide float with exactly two decimals. Hint: width and precision
   combine as `width.precision` before the `f`.

All five are single-expression solutions. If you find yourself writing a
loop or an `if`, re-read the verb table.

## Check your work

From the repository root:

```sh
go test ./01-hello/            # run this module's tests
go test ./01-hello/ -v         # see every subtest by name
go test ./01-hello/ -run TestBanner   # focus on one exercise
go vet ./01-hello/             # catch verb/argument mismatches
```

You're done when `go test ./01-hello/` prints
`ok  gotutorial/01-hello`. Then read `solution/hello.go` and compare it
against what you wrote — the solutions are the idiomatic reference, and
`go test ./01-hello/solution/` shows the same tests passing against them.
