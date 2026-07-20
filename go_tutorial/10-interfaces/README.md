# 10. Interfaces

Interfaces are Go's entire answer to polymorphism. There is no
inheritance, no class hierarchies, no generics-based traits — just
this one mechanism: a named set of method signatures, satisfied by
any type that happens to have those methods. If you internalize one
module of this course, make it this one; interfaces are how the
standard library is designed (`io.Reader` is arguably the most
important type in Go), how `fmt` prints your types, and how you write
functions that don't care what concrete data they're handed.

## What you'll learn

- Implicit satisfaction: there is no `implements` keyword
- Why tiny interfaces (`io.Reader`, `fmt.Stringer`) are the idiom
- Defining your own interfaces, and "accept interfaces, return structs"
- `fmt.Stringer` and how `fmt` discovers it at runtime
- Type assertions: `v, ok := x.(T)`
- Type switches
- `any` (the empty interface) and why to use it sparingly
- The nil-interface-vs-nil-pointer gotcha
- Sorting anything with `slices.SortFunc`

## Interfaces are satisfied implicitly

An interface type lists method signatures and nothing else:

```go
type Shape interface {
	Area() float64
}
```

Any type with an `Area() float64` method *is* a `Shape`. You never
declare the relationship:

```go
type Circle struct{ Radius float64 }

func (c Circle) Area() float64 { return math.Pi * c.Radius * c.Radius }

var s Shape = Circle{Radius: 2} // just works
```

Coming from Java/C#/TypeScript this feels like duck typing, but it is
checked entirely at **compile time** — assign a type without the right
methods to a `Shape` variable and the build fails with a message
telling you exactly which method is missing. It's structural typing,
not dynamic typing.

Implicitness is not just syntax savings. It means a type can satisfy
interfaces defined in packages that didn't exist when the type was
written — your `Circle` satisfies any one-method `interface { Area()
float64 }` anyone ever defines, with zero coordination. This is why Go
code decouples so cleanly.

Because satisfaction is implicit, it's occasionally useful to assert
it explicitly. The idiom is a blank-identifier variable:

```go
var _ Shape = Circle{} // compile-time check, costs nothing at runtime
```

If `Circle` ever stops satisfying `Shape`, this line breaks the build
right here instead of at some distant use site.

## Small interfaces are the idiom

The most-used interfaces in the standard library have one method:

```go
type Reader interface { Read(p []byte) (n int, err error) }   // io
type Writer interface { Write(p []byte) (n int, err error) }  // io
type Stringer interface { String() string }                   // fmt
```

Rob Pike's line is "the bigger the interface, the weaker the
abstraction." A one-method interface is satisfied by hundreds of
types (files, network connections, buffers, string readers,
compressors all satisfy `io.Reader`), so a function accepting it works
with all of them. A ten-method interface is satisfied by almost
nothing, so it abstracts almost nothing. When you design an interface,
list the methods the *caller actually needs* — usually one or two —
and stop.

## Defining and accepting interfaces

The Go proverb is **accept interfaces, return structs**:

```go
// Accepts an interface: works for Circle, Square, and every Shape
// that will ever be written. Can only call what Shape promises.
func TotalArea(shapes []Shape) float64

// Returns a concrete type: callers get the full API, all fields and
// methods, and can decide for themselves which interface to view it as.
func NewCircle(r float64) Circle
```

Accepting an interface makes your function maximally reusable and
maximally honest — the signature says exactly what it needs.
Returning a concrete type keeps you from hiding useful functionality
behind an artificially narrow window.

A related habit that surprises people from nominal-typing languages:
in Go, interfaces are usually defined by the **consumer**, next to the
function that accepts them — not by the implementor. `Circle` doesn't
need to know `Shape` exists. Don't create an interface until some
function actually needs to accept multiple types; a package that
exports `Thing` and `ThingInterface` side by side is a code smell in
Go.

## fmt.Stringer: how fmt prints your types

`fmt.Stringer` is the interface behind "toString":

```go
type Stringer interface {
	String() string
}
```

When `fmt.Println`, `%v`, or `%s` receives a value, it checks — at
runtime, using a type assertion like the ones below — whether the
value satisfies `Stringer`, and if so calls `String` instead of the
default `{field1 field2}` rendering:

```go
type Temperature float64

func (t Temperature) String() string {
	return fmt.Sprintf("%.1f°C", float64(t))
}

fmt.Println(Temperature(21.3)) // 21.3°C, not 21.3
```

Note the `float64(t)` conversion. Formatting `t` itself with `%v` or
`%s` inside `String` would make `fmt` call `String` again — infinite
recursion (`go vet` catches the obvious cases). Convert to the
underlying type first.

## Type assertions

An interface value tells you what a thing can *do*. Sometimes you need
to know what it *is*. A type assertion extracts the dynamic value:

```go
var s Shape = Circle{Radius: 2}

c := s.(Circle)      // c is a Circle; PANICS if s isn't one
c, ok := s.(Circle)  // ok == false if s isn't a Circle; no panic
```

Use the two-result comma-ok form almost always — the same shape as
map lookups from module 06. The one-result form is a claim that you
*know* the type, and a panic when you're wrong.

You can also assert to another **interface** type, asking "does this
value additionally have these methods?":

```go
if st, ok := s.(fmt.Stringer); ok {
	fmt.Println(st.String())
}
```

This is exactly what `fmt` does internally, and it's a common pattern
for optional behaviors throughout the standard library.

## Type switches

When there are several types to check, a type switch beats a chain of
assertions:

```go
switch x := v.(type) {
case nil:
	fmt.Println("nil interface")
case int:
	fmt.Println("int:", x+1) // x is an int here
case string:
	fmt.Println("string:", len(x)) // x is a string here
case fmt.Stringer:
	fmt.Println("stringer:", x.String()) // x is a fmt.Stringer here
default:
	fmt.Printf("unexpected %T\n", x) // %T prints the dynamic type
}
```

The magic is that `x` has a different static type in each case — no
casting after the match. Cases are tried top to bottom and the first
match wins, so put concrete types before interface cases. `case nil`
matches an interface holding nothing at all.

## any — the empty interface

`any` is an alias for `interface{}`, the interface with no methods.
Every type has at least zero methods, so every value satisfies it:

```go
var v any = 42
v = "now a string"
v = []float64{1, 2}
```

That flexibility comes at the price of the type system: you can do
*nothing* with an `any` except assert or switch your way back to a
concrete type — every mistake becomes a runtime failure instead of a
compile error. Legitimate uses are genuinely heterogeneous data
(`fmt`'s own arguments are `...any`, JSON decoding produces
`map[string]any`). If you're reaching for `any` because several types
share behavior, define a small interface instead; if it's because the
element type varies per call site, that's generics (module 12). An
`any` in an API is usually a design that gave up too early.

## The nil-interface-vs-nil-pointer gotcha

An interface value is a pair under the hood: **(dynamic type, dynamic
value)**. It equals `nil` only when *both* halves are empty. Store a
nil pointer in it and the type half is filled in — the interface is
no longer nil:

```go
var p *Circle       // nil pointer
var s Shape = p     // s holds (type: *Circle, value: nil)

fmt.Println(p == nil) // true
fmt.Println(s == nil) // false!
```

Calling `s.Area()` here would find the method (the type is known) and
then explode on the nil receiver inside it. The comparison surprising
you is the real trap: code like `if result != nil` passes even though
there's no usable value inside. You'll meet the infamous version of
this in module 11 — returning a typed nil as an `error` makes every
`err != nil` check fire. The rule: a function returning an interface
should return a literal `nil`, never a nil concrete pointer dressed up
as the interface.

## Sorting with slices.SortFunc

Module 05 sorted `[]int` with `slices.Sort`, which needs a naturally
ordered element type. For everything else there's `slices.SortFunc`,
which takes a comparison function returning negative / zero / positive
(the `strcmp` convention):

```go
slices.SortFunc(shapes, func(a, b Shape) int {
	return cmp.Compare(a.Area(), b.Area()) // ascending by area
})
```

`cmp.Compare(a, b)` (package `cmp`) returns -1, 0, or 1 for any
ordered type — use it instead of hand-writing the if/else ladder, and
definitely instead of the classic `int(a - b)` trick, which overflows.
Swap the arguments (`cmp.Compare(b.Area(), a.Area())`) to sort
descending. `slices.SortFunc` is not stable; if equal elements must
keep their order, use `slices.SortStableFunc`. These functions are
generic — you'll learn to *write* generics in module 12, but calling
them needs nothing new.

## Gotchas & idioms

- **Method sets.** If a method has a pointer receiver (`func (c
  *Counter) Inc()`), only `*Counter` satisfies interfaces containing
  it — a bare `Counter` value does not, and the compiler will say so.
  Value receivers work through both. This is the module-08/09 material
  paying rent; when "does not implement" errors surprise you, check
  receivers first.
- **`var _ Shape = Circle{}`** — free compile-time proof of
  satisfaction; put it next to the type when the relationship matters.
- **Comma-ok everywhere.** `x.(T)` panics; `v, ok := x.(T)` doesn't.
  Reserve the panicking form for impossibilities.
- **Don't format the receiver in `String`.** `fmt.Sprintf("%v", t)`
  inside `t.String()` recurses forever; convert to the underlying type
  first.
- **Interfaces are comparable, carefully.** `==` on two interface
  values compares (type, value) pairs — handy, but it panics at
  runtime if the dynamic type is incomparable (e.g. a slice).
- **Keep interfaces at the point of use.** Define them where they're
  consumed, only when a second implementation actually exists or is
  imminent.

## In Advent of Code

Interfaces earn their keep in AoC the moment a puzzle has *kinds* of
things: a virtual machine with different instruction types, a grid of
creatures with different behaviors, a packet structure that's either a
literal or an operator (2021 day 16 is exactly a `Describe`-style type
switch). `fmt.Stringer` is quietly one of the best debugging tools in
the game — give your `Grid` or `State` type a `String` method and
`fmt.Println(state)` prints a readable picture instead of a wall of
struct syntax. And `slices.SortFunc` is an every-other-day tool:
"order the hands by poker strength", "sort bricks by lowest z" are
one comparison function away. Type switches on `any` also appear
whenever input is genuinely heterogeneous — nested lists of ints and
lists (2022 day 13) parse naturally into `[]any`, and `SumNumeric` is
a warm-up for walking such data.

## Exercises

Work through `shapes.go`, `stringer.go`, and `typeswitch.go` in that
order — later shape exercises call `Area`, so implement it first.

- **`Circle.Area() float64` / `Square.Area() float64`** — πr² and
  side². `math.Pi` has the π you need. With these two methods written,
  `Circle` and `Square` satisfy `Shape` automatically — no other
  declaration exists to write.
- **`TotalArea(shapes []Shape) float64`** — sum of all areas. The
  body only gets to use what `Shape` promises; note that the tests
  sneak in a shape type defined inside the test file, which your code
  handles without knowing it exists.
- **`Temperature.String() string`** — one decimal place plus `"°C"`,
  so `Temperature(-40)` prints as `-40.0°C`. Format the *converted*
  value: `float64(t)`. The tests verify both direct calls and that
  `fmt` picks the method up via `%v`.
- **`Describe(v any) string`** — one type switch, eight cases; the doc
  comment in `typeswitch.go` pins down every output format. Remember
  `case nil`, keep the `fmt.Stringer` case below the concrete ones,
  and let `default` handle strangers with `%T`.
- **`SumNumeric(vals []any) float64`** — sum the `int`s and
  `float64`s, skip everything else silently. A type switch with two
  cases and no default is the cleanest shape.
- **`SortByArea(shapes []Shape)`** — in-place ascending sort:
  `slices.SortFunc` plus `cmp.Compare` on the two areas. Three lines.
- **`FilterShapes(shapes []Shape, keep func(Shape) bool) []Shape`** —
  closures (module 04) meet interfaces: return the shapes the
  predicate approves, in order, without touching the input. The tests
  pass predicates that assert on concrete type (`s.(Circle)`) and that
  call `Area` — your implementation just calls `keep`.

## Check your work

Run the module's tests from the repo root:

```sh
go test ./10-interfaces/
```

Fresh stubs compile but fail every test; make them pass one exercise
at a time (`go test ./10-interfaces/ -run TestDescribe` narrows the
run). When everything is green — or when you're stuck — compare your
code with `solution/`, which passes the byte-identical test files:

```sh
go test ./10-interfaces/solution/
```
