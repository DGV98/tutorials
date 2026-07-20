# Learn Go — from zero to Advent of Code

A self-paced, test-driven Go course designed to be worked through entirely in
your editor and terminal. No videos, no browser sandboxes: you read a lesson,
implement real functions in nvim, and `go test` tells you when you got it
right — the same loop you'll use writing real Go.

By the end you should be able to sit down with an Advent of Code puzzle and
solve it comfortably in Go: parse the input, pick the right data structures,
and write clean, idiomatic code.

## Prerequisites

- Go (already installed — check with `go version`)
- `gopls`, the Go language server, for nvim autocompletion/diagnostics:

  ```sh
  go install golang.org/x/tools/gopls@latest
  ```

  Make sure `~/go/bin` is on your `$PATH` so nvim can find it.

## How to work through a module

Each module is a folder. Inside you'll find:

| File            | What it is                                                      |
| --------------- | --------------------------------------------------------------- |
| `README.md`     | The lesson — read this first                                    |
| `*.go`          | Exercise stubs with doc comments telling you what to implement  |
| `*_test.go`     | The tests that check your work — read them, they're also specs  |
| `solution/`     | Complete reference solutions — peek when stuck, compare after   |

The loop:

1. `cd` into the module (or open it in nvim) and read `README.md`.
2. Open the exercise `.go` files and implement the `TODO`s.
3. Run the tests from the repo root or the module directory:

   ```sh
   go test ./01-hello/        # run one module's tests
   go test -run TestGreet ./01-hello/   # run a single test
   go test -v ./01-hello/     # verbose: see each test case
   ```

4. Red? Read the failure message — table-driven tests show you exactly which
   input broke. Green? Move on, or compare your code against `solution/`.

> **Note:** `go test ./...` from the root will fail until you've finished
> every module — the stubs are *supposed* to fail. To see all reference
> solutions pass: `go test ./.../solution/`.

## The modules

Work them in order — each builds on the previous.

**Foundations**
- [ ] `01-hello` — the toolchain, program anatomy, `fmt` and format verbs
- [ ] `02-values` — variables, types, zero values, conversions, constants & `iota`
- [ ] `03-control-flow` — `if`, every shape of `for`, `switch`
- [ ] `04-functions` — multiple returns, variadic, closures, `defer`, recursion

**Data structures (the AoC bread & butter)**
- [ ] `05-arrays-slices` — slices deeply: `append`, slicing, `copy`, 2D grids
- [ ] `06-maps` — lookups, counting, sets, comma-ok
- [ ] `07-strings` — `strings`, `strconv`, runes vs bytes, parsing text input

**Types & abstraction**
- [ ] `08-pointers` — what they are, when to use them, `nil`
- [ ] `09-structs-methods` — structs, methods, receivers, embedding
- [ ] `10-interfaces` — interfaces, type switches, `Stringer`, `any`
- [ ] `11-errors` — the `error` idiom, wrapping, `errors.Is/As`, `panic`/`recover`
- [ ] `12-generics` — type parameters and constraints

**Concurrency**
- [ ] `13-goroutines-channels` — goroutines, channels, `select`, `sync.WaitGroup`
- [ ] `14-concurrency-patterns` — worker pools, pipelines, mutexes, `context`

**Working like a Gopher**
- [ ] `15-stdlib-toolkit` — files & stdin, `bufio`, `time`, `regexp`, sorting, `slices`/`maps`
- [ ] `16-testing` — writing your own table tests, benchmarks, fuzzing

**Capstones**
- [ ] `17-aoc-capstone` — full Advent-of-Code-style puzzles, parts one and two
- [ ] `18-capstone-project` — build `puzzlerunner`, a real multi-package CLI
      that runs, times, and reports your puzzle solvers — and becomes your
      own harness for the next Advent of Code

Tick the boxes as you go (this file is yours now).

## nvim setup tips

- **LSP**: with `nvim-lspconfig`, `require("lspconfig").gopls.setup{}` is
  enough. If you use a distro (LazyVim, kickstart, NvChad), enable its Go
  extra/preset — it wires up `gopls` for you.
- **Format on save**: `gopls` formats via LSP, or use `gofmt`/`goimports`
  through conform.nvim / null-ls. Idiomatic Go is *always* gofmt-formatted —
  let the tool do it, never format by hand.
- **Run tests without leaving nvim**: `:!go test ./%:h/` runs the tests for
  the file you're editing, or set `makeprg=go\ test\ ./...` and use quickfix.
- **Jump to definition** (`gd` with LSP) into the standard library — reading
  stdlib source is one of the best ways to learn idiomatic Go.

## Useful references

- [A Tour of Go](https://go.dev/tour/) — the official interactive tour
- [Effective Go](https://go.dev/doc/effective_go) — the idiom bible
- [Go by Example](https://gobyexample.com/) — snippets for everything
- [Standard library docs](https://pkg.go.dev/std) — or `go doc strings.Split` in your terminal
- See `CHEATSHEET.md` in this repo for a one-page syntax reference
