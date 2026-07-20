# 09. Structs & Methods

So far you've juggled loose values: ints, strings, slices, maps. Real programs — and real Advent of Code solutions — need to bundle related data together and hang behavior off it. A `Point` with a `Manhattan` method beats a pair of bare ints and a free function every time you re-read your own code at 6am on December 12th. Structs are Go's only record type, and methods are how Go attaches behavior to *any* named type. There are no classes, no inheritance, no constructors in the language itself — just a few small mechanisms that compose surprisingly far.

## What you'll learn

- Defining struct types and writing struct literals (and why you should name the fields)
- Zero-value structs and the "make the zero value useful" idiom
- Value semantics: assigning a struct copies it
- Comparing structs with `==`
- Methods: value receivers vs pointer receivers, and the one rule of thumb
- Constructor functions (`NewThing`) — when and why
- Embedding: composition, method promotion, and shadowing
- Anonymous structs, especially in table-driven tests

## Defining structs and writing literals

A struct is a typed collection of named fields:

```go
type Point struct {
	X, Y int // fields of the same type can share a line
}

type Claim struct {
	ID            int
	Left, Top     int
	Width, Height int
}
```

You create values with *struct literals*. Always prefer the **field-name form**:

```go
c := Claim{ID: 17, Left: 3, Top: 2, Width: 5, Height: 4}
```

The positional form `Claim{17, 3, 2, 5, 4}` also compiles, but it breaks (or worse, silently reorders your data) the moment someone inserts a field. Field names are self-documenting and let you omit fields, which then get their zero values:

```go
p := Point{X: 5} // Y is 0
```

The community exception: tiny, universally-known structs whose field order will never change — `image.Point{2, 3}` is fine, and so is our `Point{2, 3}`. When in doubt, name the fields. `go vet` will flag positional literals for structs from *other* packages.

Exported field names (capitalized) are visible outside the package; lowercase fields are private to it — the same rule as functions, applied per field.

## Zero-value structs

`var c Claim` gives you a struct with every field set to its own zero value: ints are 0, strings are `""`, slices and maps are `nil`. There is no "uninitialized" state and no null structs.

Good Go types exploit this: **make the zero value useful**. `var b strings.Builder` and `var c Counter` (one of your exercises) work immediately, with no setup call. `bytes.Buffer` and `sync.Mutex` in the standard library are designed the same way. When the zero value *can't* be made useful — typically because a field is a map that needs `make` — that's your cue to write a constructor (below).

## Structs are values — assignment copies

Like ints, structs are copied on assignment and when passed to functions:

```go
a := Point{X: 1, Y: 2}
b := a       // b is a COPY
b.X = 99
fmt.Println(a.X) // 1 — a is untouched
```

Coming from Java or Python this is the big mental shift: there is no implicit reference. If you want two names for one struct, use a pointer (`p := &a`), exactly as in module 08. Also remember the module 05/06 subtlety: copying a struct copies its fields *shallowly* — a copied slice or map field still shares the same backing data.

## Comparing structs

Structs are comparable with `==` if all their fields are comparable — and the comparison is field-by-field:

```go
Point{1, 2} == Point{1, 2} // true
```

This is why `Point` works as a **map key**: `map[Point]rune` is the standard AoC grid, and it works because Points compare by value. A struct containing a slice, map, or function field is *not* comparable; using `==` on it won't even compile.

## Methods and receivers

A method is a function with a *receiver* parameter, written before the name:

```go
func (p Point) Manhattan(q Point) int {
	return abs(p.X-q.X) + abs(p.Y-q.Y)
}

d := p.Manhattan(q)
```

The receiver is just a parameter with special call syntax — Go has no hidden `this`. You can define methods on any named type declared in your package (not just structs): `type Grid map[Point]rune` can have methods too.

## Value receiver vs pointer receiver

The receiver can be a value or a pointer, and the difference is exactly the module 08 story:

```go
func (c Counter) broken()    { c.n++ } // mutates a copy; caller sees nothing
func (c *Counter) Increment() { c.n++ } // mutates the caller's Counter
```

The **one rule of thumb**:

> Use a pointer receiver if the method must mutate the receiver, or if the struct is large enough that copying it is wasteful. Then **be consistent: if any method of a type needs a pointer receiver, give them all pointer receivers.**

Consistency isn't just style — a type whose *methods* are split across value and pointer receivers behaves confusingly with interfaces (module 10) and is harder to reason about. The `Counter` exercise deliberately mixes receivers so you can watch both behave, but its doc comment tells you what real code would do.

Two conveniences the compiler gives you:

```go
var c Counter
c.Increment()   // shorthand for (&c).Increment() — Go takes the address for you
p := &c
fmt.Println(p.Value()) // shorthand for (*p).Value()
```

So at the call site you almost never care which kind of receiver a method has. The one trap: you can't call a pointer-receiver method on a value that has no address, like a struct just returned from a function or a map element — `m[k].Increment()` won't compile if `m` is a `map[string]Counter`.

## Constructor functions

Go has no constructors. The convention is a plain function named `New` (if the package has one main type) or `NewTypeName`:

```go
func NewInventory() *Inventory {
	return &Inventory{items: make(map[string]int)}
}
```

Write one **only when the zero value isn't usable** — here, because the internal map must be `make`d — or when construction needs validation or computation. If the zero value works, skip the constructor; forcing callers through `NewCounter()` for a struct that's just `{0}` is noise. Constructors for pointer-receiver types conventionally return `*T`, so methods can be called on the result directly.

Note that unexported fields like `items` are invisible outside the package — the constructor plus methods form the type's entire public API. That's Go's encapsulation story.

## Embedding: composition, not inheritance

Placing a type name in a struct *without a field name* embeds it:

```go
type Animal struct{ Name string }

func (a Animal) Describe() string { return a.Name + " is an animal" }

type Dog struct {
	Animal // embedded — no field name
	Breed  string
}
```

The embedded type's fields and methods are **promoted**: `d.Name` and `d.Describe()` just work, forwarding to the inner `Animal`. But this is composition, not inheritance:

- `Dog` is not an `Animal`; you can't pass a `Dog` where an `Animal` is expected.
- If `Dog` defines its own `Speak`, it **shadows** the promoted one — there's no `super`, but the original is still there explicitly: `d.Animal.Speak()`.
- No polymorphic dispatch: if `Animal.Describe` called `a.Speak()` internally, it would always get `Animal.Speak`, never `Dog.Speak`, even when called through a `Dog`. Promotion is mechanical forwarding, nothing more. (Go's answer to polymorphism is interfaces — next module.)

The field is named after the type: `Dog{Animal: Animal{Name: "Rex"}, Breed: "corgi"}`.

## Anonymous structs (in tests)

You can declare a struct type inline, without naming it. The canonical use is table-driven tests, where a named type for the rows would be ceremony:

```go
tests := []struct {
	name string
	p, q Point
	want int
}{
	{"diagonal", Point{X: 1, Y: 2}, Point{X: 4, Y: 6}, 7},
}
```

Every `_test.go` file in this module (and this whole course) does this — read them, they're part of the lesson. Anonymous structs are also handy for one-off grouped values inside a function, or as ad-hoc JSON decode targets in real-world code.

## Gotchas & idioms

- **Positional literals are fragile.** `Point{2, 3}` is fine; anything bigger, name the fields.
- **Pointer-receiver mutation is the #1 beginner bug.** If your mutating method "does nothing", check the receiver: `func (c Counter)` silently edits a copy.
- **Mixed receivers on one type** are legal but frowned upon; pick pointer for the whole type once any method needs it.
- **You can't assign to fields of a struct stored in a map**: `m["a"].n++` won't compile for `map[string]Counter`. Store pointers (`map[string]*Counter`) or read-modify-write the whole struct.
- **Comparable means map-key-able.** Structs of comparable fields work as map keys; add one slice field and both `==` and map keying stop compiling.
- **Embedding is not subtyping.** No `super`, no virtual dispatch; shadowed methods are reached via `d.Inner.Method()`.
- **Zero-value comparison as an "is this unset?" test**: `p == Point{}` compares against the zero value (parenthesize the literal in `if` conditions: `if p == (Point{})`).
- **Method values exist**: `f := c.Increment` captures the receiver; handy with the function-values material from module 04.

## In Advent of Code

Structs are where AoC solutions stop being spaghetti. A `Point{X, Y int}` used as a `map[Point]rune` key is *the* way to store 2D grids (sparse or dense), and `Manhattan` distance is asked for almost verbatim most years (2018 day 6, 2021 day 5 neighborhoods, every pathfinding heuristic). Puzzle entities — claims, instructions, bots, ranges — parse naturally into structs, and methods like `Rect.Contains` or `Overlaps` turn part 2 from a rewrite into a one-liner. Constructor functions matter the moment your solution type wraps a map or slice you build while parsing the input.

## Exercises

Implement the `// TODO` stubs in this directory. Struct definitions are already in place; you write the methods (and one constructor).

- **`Point.Manhattan(q Point) int`** (`geometry.go`) — the taxicab distance `|Δx| + |Δy|`. There's no integer `abs` in the stdlib (`math.Abs` is float64-only); write a two-line helper.
- **`Rect.Area() int`, `Rect.Perimeter() int`, `Rect.Contains(p Point) bool`** (`geometry.go`) — an axis-aligned rectangle with `Min`/`Max` corner Points. `Contains` is inclusive on all edges; note how naturally the nested fields read (`r.Max.X`).
- **`Counter.Increment()` / `Counter.Value() int`** (`counter.go`) — one line each, but the *receivers* are the exercise: `Increment` must use a pointer receiver or the tests will prove your counter never counts. `TestCounterCopy` also pins down copy semantics.
- **`NewInventory() *Inventory`, `Inventory.Add/Remove/Total`** (`inventory.go`) — a constructor that `make`s the internal `map[string]int`, then three pointer-receiver methods. Mind the contracts in the doc comments: `Add` ignores `qty <= 0`; `Remove` is all-or-nothing and reports success; deleting a key that hits zero keeps the map tidy.
- **`Animal.Speak`, `Animal.Describe`, `Dog.Speak`** (`animal.go`) — embedding in action. Implement `Describe` on `Animal` only and watch `Dog` get it by promotion; implement `Speak` on both and watch `Dog`'s shadow the promoted one. Exact output strings are in the doc comments.

## Check your work

```sh
go test ./09-structs-methods/
```

Run it from the repo root; add `-v` to see every subtest. Out of the box the package compiles but the tests fail — that's your worklist. When everything is green (or you're stuck), compare your code with the reference implementations in `solution/`, which pass the identical tests:

```sh
go test ./09-structs-methods/solution/
```
