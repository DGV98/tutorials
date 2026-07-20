# 06 — Structs, Enums, and Tagged Unions

This is the module where you stop consuming types and start designing them.
Structs bundle data ("all of these"), enums name a fixed set of choices, and
tagged unions — Zig's sum type — carry a different payload per choice ("one
of these"). Combined with `switch`, they cover most of what interfaces and
class hierarchies do in OOP languages, with everything checked at compile
time.

## What you'll learn

- Defining structs, field defaults, init literals, anonymous `.{ ... }` literals
- Value (copy) semantics and `@This()`
- Methods: `self: Self` vs `self: *Self`, namespace ("static") functions, chaining
- Enums: methods, explicit integer tags, `@intFromEnum`/`@enumFromInt`,
  non-exhaustive enums, `std.meta.stringToEnum`, enum literals
- Tagged unions: `union(enum)`, switch payload captures `|v|` and `|*v|`,
  void variants
- Capstone: a `Shape` union with `area`/`perimeter`/`scale`/`describe`

## Structs

A struct is a type. Declaring one is an expression, which is why you assign
it to a `const`:

```zig
const Point = struct {
    x: f64,
    y: f64,
};
```

Instantiate with an init literal. When the context already knows the type,
drop the name and write an *anonymous struct literal*:

```zig
const a = Point{ .x = 1, .y = 2 };  // type spelled out
const b: Point = .{ .x = 1, .y = 2 }; // coerces to Point
```

That second form is everywhere in Zig: function arguments, return values,
nested fields. `.{}` is not special syntax for "empty options" — it's an
anonymous literal coercing to whatever the parameter type is.

### Field defaults

Fields may declare defaults. Fields without defaults must be set explicitly
— forgetting one is a compile error, which makes structs self-documenting
about what's required:

```zig
const Config = struct {
    width: u32 = 80,
    height: u32 = 24,
    title: []const u8, // no default: required
};

const cfg: Config = .{ .title = "report" }; // width/height defaulted
```

### Structs are values

Assignment copies. Passing to a function copies. Returning copies. There is
no hidden reference semantics:

```zig
var copy = original; // independent copy
copy.x = 99;         // original.x unchanged
```

If you want two names for one struct, take a pointer explicitly: `const p =
&original;`. This bites people coming from Python/Java/JS, and it shows up
again in loops: `for (items) |item|` gives you copies; `for (items) |*item|`
gives you pointers you can mutate through.

### @This()

Inside a struct, `@This()` is the struct's own type. The convention:

```zig
const Temperature = struct {
    celsius: f64,

    const Self = @This();

    fn fromFahrenheit(f: f64) Self { ... }
};
```

For a named top-level struct `Self` is mere convenience, but the pattern
matters once types are anonymous or generic (module 09), so build the habit
now.

## Methods

Zig has no method construct. A "method" is a function declared inside the
type whose first parameter is the type:

```zig
const Rectangle = struct {
    width: f64,
    height: f64,

    const Self = @This();

    fn init(width: f64, height: f64) Self {      // no self: "static"
        return .{ .width = width, .height = height };
    }

    fn area(self: Self) f64 {                    // reads a copy
        return self.width * self.height;
    }

    fn scale(self: *Self, factor: f64) void {    // mutates through pointer
        self.width *= factor;
        self.height *= factor;
    }
};
```

`r.area()` is sugar for `Rectangle.area(r)` — nothing more. Functions
without a `self` parameter are called on the type itself:
`Rectangle.init(3, 4)`. That's Zig's constructor: a plain function named
`init` by convention.

### `self: Self` vs `self: *Self`

The single most important decision per method:

- `self: Self` — the method gets a copy. Parameters are immutable in Zig, so
  you physically cannot mutate anything. Use for reads.
- `self: *Self` — the method can write through the pointer. Calling
  `r.scale(2)` on a `var r` automatically takes `&r`.

Two compile errors enforce honesty here. Mutating through `self: Self` fails
with "cannot assign to constant". Calling a `*Self` method on a `const`
value fails with "expected type `*Rectangle`, found `*const Rectangle`". If
you hit either, the fix is in the signature or the binding, not in casting.

### Chaining

A mutating method that returns `*Self` lets calls chain:

```zig
fn add(self: *Self, x: f64) *Self {
    self.value += x;
    return self;
}

_ = c.add(2).mul(10).sub(5); // discard the final pointer
```

## Enums

```zig
const Direction = enum { north, east, south, west };
```

Enums are namespaces too — methods work exactly as on structs. When the
expected type is known you can write the *enum literal* `.north` instead of
`Direction.north`; you've been doing this all course with `.{}` and error
values.

### Switching exhaustively

A switch over an enum must handle every value. Prefer listing them all over
an `else`: when you later add a value, every switch without `else` becomes a
compile error pointing at exactly the code that needs thought. `else` trades
that safety away for brevity — spend it deliberately.

```zig
fn opposite(self: Direction) Direction {
    return switch (self) {
        .north => .south,
        .south => .north,
        .east => .west,
        .west => .east,
    };
}
```

### Integer tags

Every enum is backed by an integer. Pin the representation and values when
they matter (protocols, file formats, C interop):

```zig
const HttpStatus = enum(u16) {
    ok = 200,
    not_found = 404,
};

@intFromEnum(HttpStatus.ok)        // 200, type u16
@as(HttpStatus, @enumFromInt(404)) // .not_found
```

`@enumFromInt` of a value with no corresponding name is illegal behavior —
a panic in safe builds, and a compile error if the value is comptime-known.
Which leads to:

### Non-exhaustive enums

A trailing `_` field says "values without names are still valid":

```zig
const Opcode = enum(u8) {
    halt = 0x00,
    push = 0x01,
    _,
};
```

Now `@enumFromInt` accepts any `u8` — exactly what you want when decoding
bytes you don't control. In a switch, the `_ =>` prong matches all unnamed
values, while still forcing you to handle every named one (unlike `else`,
which would also swallow named values you forgot).

### Names as strings

`@tagName(.north)` returns `"north"`; `std.meta.stringToEnum(Direction,
"north")` goes the other way, returning `?Direction`. In format strings,
`{t}` prints the tag name. Free serialization in both directions.

## Tagged unions

A union holds one of its fields at a time. A *tagged* union — `union(enum)`
— also tracks which one, and that tag is what makes it safe and switchable:

```zig
const Value = union(enum) {
    int: i64,
    float: f64,
    text: []const u8,
    nil, // void variant: tag only, no payload

    fn truthy(self: @This()) bool {
        return switch (self) {
            .nil => false,
            .int => |i| i != 0,       // |i| captures the payload
            .float => |f| f != 0,
            .text => |s| s.len != 0,
        };
    }
};

const v = Value{ .int = 42 };
const nothing: Value = .nil;  // void variants init like enum literals
```

The capture `|i|` is the payload by value, typed per branch. Reading a field
directly (`v.int`) works but is illegal behavior if that's not the active
variant — safe builds panic. Switch, or compare the tag first: `v == .int`
compares a tagged union against an enum literal by tag.

### Mutating payloads: `|*v|`

To modify the payload in place, switch on the dereferenced pointer and take
a pointer capture:

```zig
fn double(v: *Value) void {
    switch (v.*) {
        .int => |*i| i.* *= 2,   // i is a pointer into the union
        .float => |*f| f.* *= 2,
        else => {},
    }
}
```

Assigning a new variant re-tags the whole thing: `v.* = .{ .float = 1.5 }`.

### This is Zig's answer to interfaces

An OOP interface is an *open* set: anyone anywhere can add an
implementation, and no one can enumerate them all. A tagged union is a
*closed* set: all variants in one place, every operation an exhaustive
switch. For most programs — ASTs, JSON values, events, shapes, instructions
— the closed set is what you actually have, and the compiler verifies every
operation handles every case. (Zig can do open, vtable-style dispatch too —
`std.mem.Allocator` is one — but that's a module 11 topic.)

## Gotchas

- **Struct field order in memory is not guaranteed.** The compiler may
  reorder fields to minimize padding. Only `extern struct` and
  `packed struct` (module 11) promise a layout — never memcpy a plain
  struct onto bytes from outside.
- **`.{ ... }` needs a destination type.** "Unable to infer" errors mean the
  context doesn't name a type — annotate the variable or spell out
  `Point{ ... }`.
- **You can't take a mutable method call on a temporary.**
  `Rectangle.init(2, 3).scale(2)` fails: the temporary isn't addressable as
  `*Rectangle`. Bind it to a `var` first.
- **Copies in loops.** `for (shapes) |s| s.scale(2)` doesn't compile (can't
  take `&s` of a capture as mutable)? Use `for (shapes) |*s| s.scale(2);`.
  The by-value capture is a copy — even where it compiles, mutations vanish.
- **Wrong-field union access panics at runtime**, not compile time. The
  compile-time guarantee comes from `switch`, so prefer switching over
  direct field access when the variant isn't locally obvious.
- **`==` works on enums and tags, not on structs.** Comparing two structs
  with `==` is a compile error; compare field-by-field or with
  `std.meta.eql`. A tagged union `==` an enum literal compares tags only —
  payloads are not compared.
- **Enum methods vs values.** Inside `enum { north, ... }`, declarations
  (`const`, `fn`) and value fields can mix; a stray comma after a method or
  a missing one after the last value is a common parse error.

## Exercises

Work them in order; run each with `zig test <file>` until green.

1. `01_structs.zig` — define and instantiate structs, defaults, anonymous
   literals, nesting, copy semantics, `@This()`.
2. `02_methods.zig` — `init` pattern, `self: Self` vs `self: *Self`, dot-call
   sugar, method chaining on a `Calculator`.
3. `03_enums.zig` — `Direction` with methods, HTTP status codes as explicit
   tags, a non-exhaustive `Opcode`, `stringToEnum` and `@tagName`.
4. `04_tagged_unions.zig` — a dynamic `Value` type: tag checks, truthiness,
   numeric coercion, in-place mutation via `|*v|`.
5. `05_shapes.zig` — capstone: `Shape = union(enum)` with `area`,
   `perimeter`, in-place `scale`, `describe` via `std.fmt.bufPrint`, and
   `totalArea` over a `[]const Shape`.
