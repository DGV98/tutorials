# 16. Testing Go Code

You have been *running* tests since module 01 — every exercise in this
course is checked by one. Now you learn to write them. Go's answer to
testing is characteristically minimal: no framework, no assertion
library, no test runner to install. The `testing` package plus the
`go test` command *are* the framework, and one idiom — the table-driven
test — does most of the work. Because the tooling is built in, Go
programmers test far more reflexively than in most ecosystems, and for
AoC-style code that habit pays off the moment part 2 makes you refactor
part 1.

This module inverts the course: the functions are (mostly) already
written, and the exercise is the test file. One of the shipped
functions is deliberately buggy — your tests should be the thing that
finds it.

## What you'll learn

- Test files (`_test.go`), test functions (`TestXxx(t *testing.T)`)
- Running tests: `go test`, `-v`, `-run`, `-count=1` and test caching
- Table-driven tests with `t.Run` subtests — THE Go testing idiom
- `t.Errorf` vs `t.Fatalf`
- Test helpers and `t.Helper()`
- Benchmarks: `go test -bench`, `b.Loop()` (and the older `b.N`)
- Fuzzing basics: `go test -fuzz`
- Coverage: `go test -cover`
- What makes a test *good*: behavior, not implementation

## Test files and test functions

Tests live in the same directory as the code, in files whose names end
in `_test.go`. Those files are compiled only by `go test` — they are
never part of a normal build, so tests can import heavyweight helpers
without bloating your program.

A test is any exported-looking function of exactly this shape:

```go
func TestReverse(t *testing.T) { ... }
```

The name must start with `Test` followed by a character that is not a
lowercase letter — an uppercase letter in practice. Get it wrong and
there is no test: `testReverse` is silently ignored (a classic trap),
while `Testreverse` at least fails fast — `go test` runs a handful of
`vet` checks automatically, and one of them rejects lowercase-after-`Test`
names as malformed. The `*testing.T`
parameter is your handle for reporting failures. There are no asserts
and no exceptions: a test fails by *saying so* on `t`, usually after a
plain `if`:

```go
func TestReverse(t *testing.T) {
	got := Reverse("hello")
	if got != "olleh" {
		t.Errorf("Reverse(%q) = %q, want %q", "hello", got, "olleh")
	}
}
```

If the function returns without reporting anything, the test passes.
Go deliberately has no `assertEqual`: the language designers judged
that a plain `if` plus a good message is clearer than a DSL, and that
forcing you to write the message produces better failure output.

A test file declares a package. Everything in this course uses
*internal* tests — `package testkit` in the test file too — which can
see unexported identifiers. Declaring `package testkit_test` instead
(an *external* test, the only case where two packages may share a
directory) forces you to test only the public API. Both are common;
internal is the default choice for small packages.

## Running tests: go test and its flags

```sh
go test ./16-testing/            # this package
go test ./...                    # every package under the current dir
go test -v ./16-testing/         # -v: print every test and subtest, incl. skips
go test -run TestReverse ./16-testing/            # only matching tests
go test -run 'TestMostCommon/tie' -v ./16-testing/ # a single subtest
go test -count=1 ./16-testing/   # force a real run, ignore the cache
```

Two flags deserve explanation:

- **`-run` takes a regular expression**, not an exact name: `-run
  Reverse` matches `TestReverse` *and* `FuzzReverse`'s test-mode run —
  anchor with `-run 'TestReverse$'` when it matters. The pattern can
  descend into subtests with `/`: parent regex, slash, subtest regex.
  Spaces in subtest names become underscores in these paths.
- **`-count=1` defeats test caching.** `go test` caches a passing
  package result and replays it (you'll see `(cached)`) as long as the
  code and test files are unchanged. That's almost always what you
  want, but when a test depends on something the cache can't see — an
  input file you're editing, time, randomness you're chasing —
  `-count=1` forces re-execution. `-count=5` runs everything five
  times, handy for smoking out flaky, order-dependent tests.

## Table-driven tests — THE idiom

Testing one input per function call doesn't scale; you want a dozen
cases, and they differ only in data. Go's answer — you have seen it in
every module of this course — is a slice of anonymous structs and a
loop:

```go
func TestClamp(t *testing.T) {
	tests := []struct {
		name      string
		x, lo, hi int
		want      int
	}{
		{"below range", -5, 0, 10, 0},
		{"above range", 99, 0, 10, 10},
		{"inside range", 7, 0, 10, 7},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Clamp(tt.x, tt.lo, tt.hi); got != tt.want {
				t.Errorf("Clamp(%d, %d, %d) = %d, want %d",
					tt.x, tt.lo, tt.hi, got, tt.want)
			}
		})
	}
}
```

Why this shape is *the* idiom:

- **Adding a case is one line.** The activation energy for "hmm, what
  about the empty string?" is nearly zero — so the edge case actually
  gets added.
- **`t.Run` makes each row a subtest** with its own name
  (`TestClamp/below_range`), its own pass/fail, and its own line in
  `-v` output. One bad row doesn't stop the others, and you can re-run
  exactly one row with `-run`.
- **The table documents the contract.** A well-named table reads as a
  specification; that's why this course tells you to read the shipped
  tests when a doc comment feels ambiguous.

Conventions worth copying: call the loop variable `tt`, name the
fields `want`/`wantOK`, and write failure messages in the shape
`FuncName(input) = got, want want`. That message format matters — when
a test fails at 2am, `Clamp(-5, 0, 10) = -5, want 0` tells you
everything without opening the file.

For comparing results: `==` works for strings and numbers,
`slices.Equal` and `maps.Equal` for slices and maps of comparable
elements, and `reflect.DeepEqual` as the blunt instrument for nested
structures (module 06 used it for `[][]string`).

## t.Errorf vs t.Fatalf

Both mark the test failed; they differ in what happens next.

- `t.Errorf(format, args...)` — report and **keep going**. The test
  continues, so one run can report several independent mismatches.
- `t.Fatalf(format, args...)` — report and **stop this test now**
  (the current test function or subtest; the rest still run).

Rule of thumb: `Errorf` for "the answer is wrong", `Fatalf` for "there
is no point continuing" — setup failed, an error you can't proceed
past, or a nil you're about to dereference:

```go
f, err := os.Open("testdata/input.txt")
if err != nil {
	t.Fatalf("opening fixture: %v", err) // continuing would just panic
}
```

(`t.Errorf` = `t.Logf` + `t.Fail`; `t.Fatalf` = `t.Logf` +
`t.FailNow`. You'll meet the undecorated forms too — `t.Error`,
`t.Fatal` — which take a list of values instead of a format string.)
One footgun for later: `t.Fatalf` must be called from the goroutine
running the test, because it works by killing that goroutine. From a
goroutine you started yourself (modules 13–14), use `t.Errorf`.

## Test helpers and t.Helper()

When several tests share checking logic, factor it into a helper that
takes `*testing.T`. The one wrinkle: when a helper calls `t.Errorf`,
the failure is reported at the `Errorf` line *inside the helper* —
useless when ten call sites share it. `t.Helper()` fixes the blame:

```go
func checkMostCommon(t *testing.T, s string, wantR rune, wantN int) {
	t.Helper() // failures point at the caller, not this function
	r, n := MostCommon(s)
	if r != wantR || n != wantN {
		t.Errorf("MostCommon(%q) = (%q, %d), want (%q, %d)", s, r, n, wantR, wantN)
	}
}
```

`checked_test.go` in this module uses exactly this helper — read it.
Helpers are ordinary functions: not run as tests (no `Test` prefix),
free to take any arguments, free to call `Fatalf`. By convention
`*testing.T` is the first parameter.

## Benchmarks

Benchmarks share the file and the machinery, with a `Benchmark` prefix
and a `*testing.B`:

```go
func BenchmarkReverse(b *testing.B) {
	s := strings.Repeat("héllo wörld ", 50) // setup: not timed
	for b.Loop() {
		Reverse(s)
	}
}
```

`go test` ignores benchmarks; you opt in with:

```sh
go test -bench=. ./16-testing/                            # tests, then all benchmarks
go test -run '^$' -bench=Reverse -benchmem ./16-testing/  # benchmarks only
```

Benchmarks only run after the package's tests pass, so the classic
invocation pairs `-bench` with `-run '^$'` — a regex matching no test
name — to skip straight to the benchmarks.

Output like `BenchmarkReverse-8   240188   4983 ns/op` reads: on 8
CPUs, the loop body ran 240,188 times, averaging 4,983ns per
iteration. The framework chooses the iteration count itself, growing
it until the timing is statistically meaningful — that's what the loop
construct is for. `-benchmem` adds allocation counts per operation,
often the more actionable number.

`for b.Loop()` is the modern form (Go 1.24+). It excludes setup before
the loop from the timing, and it keeps the loop body's arguments and
results alive so the compiler can't discover that `Reverse(s)` is
unused and delete it — the classic way to benchmark nothing at 0.3
ns/op. In older code you will constantly see the original pattern:

```go
for i := 0; i < b.N; i++ { // pre-1.24 style; b.N chosen by the framework
	Reverse(s)
}
```

It still works, but needs manual care (`b.ResetTimer()` after setup,
sinks to defeat dead-code elimination). Write `b.Loop()`; recognize
`b.N`.

## Fuzzing

Table tests check inputs you thought of. A fuzz test states a
*property* that must hold for all inputs, and lets the toolchain
mutate inputs searching for a counterexample:

```go
func FuzzReverse(f *testing.F) {
	f.Add("héllo") // seed corpus: known-interesting starting points
	f.Fuzz(func(t *testing.T, s string) {
		if !utf8.ValidString(s) {
			t.Skip() // outside Reverse's contract
		}
		rev := Reverse(s)
		if !utf8.ValidString(rev) {
			t.Errorf("Reverse(%q) = %q, not valid UTF-8", s, rev)
		}
		if Reverse(rev) != s {
			t.Errorf("Reverse(Reverse(%q)) != original", s)
		}
	})
}
```

The trick is finding properties that don't require re-implementing the
function: round-trips (`Reverse(Reverse(s)) == s`), invariants (output
is valid UTF-8, output length matches input), comparison against a
slow-but-obvious implementation.

```sh
go test ./16-testing/                              # seeds only, as normal tests
go test -run FuzzReverse -fuzz=Reverse -fuzztime=10s ./16-testing/  # actually fuzz
```

Under plain `go test`, only the `f.Add` seeds run — fuzz targets
double as regular tests. With `-fuzz` (one target at a time), the
engine generates inputs indefinitely (bound it with `-fuzztime`).
Like `-bench`, `-fuzz` refuses to start while any test selected by
`-run` is failing, so while the rest of the package is red, scope the
pre-flight run down to the target itself with `-run FuzzReverse`.
When it finds a failing input it writes the input to
`testdata/fuzz/FuzzReverse/` and stops; that file re-runs on every
future plain `go test`, so a found bug stays found until you fix it.
Commit those files — they're free regression tests.

## Coverage

```sh
go test -cover ./16-testing/                     # percent of statements executed
go test -coverprofile=cover.out ./16-testing/    # write a profile...
go tool cover -html=cover.out                    # ...and browse it, line by line
```

The HTML view paints executed code green and unexecuted code red —
excellent for spotting the error branch or edge case no test reaches.
Treat the percentage as a flashlight, not a target: 100% coverage
proves every line *ran*, not that any result was *checked*. A test
with no `if` has perfect coverage and catches nothing.

## What makes a good test

- **Test behavior, not implementation.** Test what the doc comment
  promises — inputs to outputs — never *how* the function gets there.
  A test that breaks when you swap a correct algorithm for a faster
  correct one is worse than no test: it punishes refactoring, which is
  exactly when you need tests most. Corollary: don't test unexported
  helpers directly; test them through the exported behavior.
- **Failure messages say got and want.** `Clamp(-5, 0, 10) = -5, want 0`
  diagnoses itself. `t.Error("wrong answer")` sends you debugging.
- **Hunt edge cases.** Empty input, one element, boundaries, negative
  numbers, ties, non-ASCII strings. The bug in this module is only
  catchable by a test row someone bothered to add.
- **Independent and deterministic.** Each subtest builds its own data
  and must not depend on order — remember module 06: anything derived
  from map iteration order needs an explicit tie-break, or your test
  fails one run in five.
- **Test the contract's edges *as stated*.** If the doc comment says
  "never modifies xs", write the test that catches mutation — checking
  the return value can't see it.

## Gotchas & idioms

- **A misnamed test can silently not run.** `testReverse` — no error,
  no test: without the `Test` prefix it's just an unexported function.
  If a new test doesn't show up under `-v`, check the name. Names like
  `TestreverseString` are the friendlier failure mode: `go vet` flags
  a lowercase letter after `Test` as a malformed name, and `go test`
  runs that check for you, refusing to build the package.
- **`(cached)` means it didn't run.** Fine until you're testing
  something the cache can't hash. `-count=1` is the escape hatch.
- **`-run` is a regex.** `-run TestMedian` also runs
  `TestMedianDoesNotMutate`. Anchor: `-run 'TestMedian$'`.
- **Failing tests block `-bench` and `-fuzz`.** Both run the tests
  selected by `-run` first and stop if any fail. The escape hatches:
  `-run '^$'` for benchmarks, `-run FuzzReverse` when fuzzing.
- **Old code re-declares the loop variable** (`tt := tt`) before
  `t.Run`. Pre-1.22, closures captured one shared loop variable —
  disastrous with `t.Parallel()`. Since Go 1.22 each iteration gets a
  fresh variable, so the copy is obsolete; recognize it, don't write it.
- **Subtests can run in parallel**: call `t.Parallel()` first thing
  inside the `t.Run` closure. Rarely worth it for fast pure functions;
  very worth it for slow I/O-bound tests.
- **`testdata/` is magic.** The Go tool ignores any directory with
  that name, so test fixtures live there by convention (fuzzing
  already put its corpus in `testdata/fuzz/`).
- **Don't chase 100% coverage;** chase untested *behaviors*. The
  `-html` view is for finding forgotten branches, not for gaming a
  number.

## In Advent of Code

Every AoC puzzle hands you a worked example — "consider this input;
the answer is 31" — which is a test case, verbatim. The strongest AoC
habit this course can teach: before touching your real input, paste
the example into a table test and make it pass. When part 2 forces you
to restructure part 1 (it will), that test is what lets you refactor
fearlessly, and the part-1-example row keeps passing while you add the
part-2 row. Benchmarks earn their keep on the "your solution takes 40
minutes" days — `-benchmem` usually points at allocations in a hot
loop. And the discipline of edge-case rows (empty line at end of
input, single-element case, off-by-one at a boundary) maps one-to-one
onto the reasons AoC answers come back "too low".

## Exercises

**Part 1 — write the tests** (`practice_test.go`). The functions
`Clamp`, `Reverse`, and `Median` in `practice.go` are already
implemented; their doc comments are the contracts. `practice_test.go`
contains six named skeletons whose bodies are `t.Skip("write me")` —
replace each skip with a real body:

- **`TestClamp`** — a table-driven test: below/above/inside the range,
  and both boundaries exactly.
- **`TestReverse`** — a table-driven test. Choose inputs adversarially.
- **`TestMedian`** — a table: empty (comma-ok false), single value,
  odd length, even length, unsorted input.
- **`TestMedianDoesNotMutate`** — a behavior test: prove `Median`
  leaves its argument untouched (`slices.Clone` before,
  `slices.Equal` after).
- **`BenchmarkReverse`** — time `Reverse` on a few hundred bytes with
  `b.Loop()`.
- **`FuzzReverse`** — seeds via `f.Add`, then check round-trip and
  UTF-8 validity, skipping invalid-UTF-8 inputs.

**The bug hunt:** exactly one of the three functions violates its
contract. If all your tests pass on the first run, they're too polite
— reread the doc comments and think about what module 07 said a Go
string really is. (The fuzzer will also find it in about a second.)
Once a test catches it, **fix the function in `practice.go`** so the
whole module is green. `solution/practice.go` names the bug and shows
the fix if you want to check your diagnosis.

**Part 2 — the usual red-to-green loop** (`histogram.go`, checked by
the shipped `checked_test.go` — which is also your worked example of
the table style and of a `t.Helper()` helper):

- **`RuneHistogram(s string) map[rune]int`** — count each rune. Hint:
  `range` over a string yields runes (module 07); then it's the
  module-06 counting pattern.
- **`MostCommon(s string) (rune, int)`** — most frequent rune and its
  count; ties go to the smallest rune. Hint: build on
  `RuneHistogram`, and make the tie-break explicit — the map's
  iteration order won't do it for you.

## Check your work

From the repository root:

```sh
go test ./16-testing/             # checked tests fail until Part 2 is done
go test -v ./16-testing/          # also shows your Part 1 skips shrinking
go test -run 'TestClamp$' -v ./16-testing/       # focus one test
go test -run '^$' -bench=Reverse -benchmem ./16-testing/           # your benchmark
go test -run FuzzReverse -fuzz=Reverse -fuzztime=10s ./16-testing/  # fuzz (finds the bug!)
go test -cover ./16-testing/      # how much do your tests execute?
go test ./16-testing/solution/    # reference: everything green
```

You're done when `go test -v ./16-testing/` shows no failures *and no
skips*. Then compare with `solution/`: `solution/practice_test.go` is
a completed, idiomatic version of the test file you just wrote (the
one place in this course where the solution's tests differ from the
module's), and `solution/practice.go` has the bug fixed and explained.
`checked_test.go` is identical in both directories, as always.
