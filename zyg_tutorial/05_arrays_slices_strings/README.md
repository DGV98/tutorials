# 05 — Arrays, Slices & Strings

This is the most Advent-of-Code-relevant module in the course. Every AoC
puzzle starts the same way: you get a wall of text, and you have to cut it
into pieces and turn the pieces into numbers. The tools for that are arrays,
slices, and a dozen functions from `std.mem` and `std.fmt`. Get fluent here
and half of every puzzle is already solved.

You'll learn:

- fixed-size arrays `[N]T` and why they copy on assignment
- slices `[]T` / `[]const T` — the type you actually pass around
- sentinel-terminated types like `[:0]const u8` and what string literals really are
- that Zig has no string type: strings are `[]const u8`, plain bytes
- the `std.mem` toolbox: search, compare, trim, count, replace
- `tokenizeScalar` vs `splitScalar` vs `splitSequence`, plus `parseInt`/`parseFloat`
- building strings with `bufPrint`, `allocPrint`, `join`, and `concat`

## Arrays: `[N]T`

An array's length is part of its type and known at compile time. `[4]u8` and
`[5]u8` are different, incompatible types.

```zig
const explicit = [4]u8{ 1, 2, 3, 4 };
const inferred = [_]u8{ 1, 2, 3, 4 };   // compiler counts for you
const repeated = [_]u8{ 0, 1 } ** 3;    // {0,1,0,1,0,1} — comptime repetition
const filled: [16]u8 = @splat(0);       // every element = 0
```

`arr.len` is a compile-time constant. Indexing with a constant that's out of
range is a *compile error*; indexing with a runtime variable is bounds-checked
and panics in Debug builds instead of corrupting memory.

The property that surprises people: **arrays are values**. Assigning one
copies every element. Passing one to a function copies it too.

```zig
var a = [_]i32{ 1, 2, 3 };
var b = a;      // full copy
b[0] = 99;      // a[0] is still 1
```

There is no `==` for arrays. Compare with `std.mem.eql(u8, &a, &b)` (or
`std.meta.eql(a, b)` for arbitrary types).

A 2D grid is just an array of arrays: `[height][width]u8`, indexed
`grid[row][col]`. You'll live in these during AoC's grid puzzles.

```zig
var grid: [3][4]u8 = @splat(@splat('.'));  // 3 rows of 4 dots
grid[1][2] = '#';
```

## Slices: `[]T`

A slice is a *fat pointer*: a pointer plus a length. It doesn't own or copy
anything — it's a view into memory that someone else (an array, an allocator)
owns. Unlike an array's, its length is a runtime value.

```zig
var arr = [_]i32{ 10, 20, 30, 40, 50 };
const all: []i32 = &arr;      // &array coerces to a slice
const mid = arr[1..4];        // elements 1,2,3 — start inclusive, end exclusive
const tail = arr[2..];        // to the end
```

Detail worth knowing: when both bounds are comptime-known, `arr[1..4]` is
actually a `*[3]i32` (pointer to array — length still in the type). It
coerces to `[]i32` wherever a slice is expected, so day to day you won't
notice, but it explains what `@TypeOf` shows you. Use a runtime index and you
get a real slice.

Slices come in two flavors:

- `[]const T` — read-only view. **Take this in function parameters** whenever
  you don't mutate; everything coerces to it (`[]T`, `&array`, literals).
- `[]T` — writable view. Writing through it writes into the underlying array:

```zig
fn doubleAll(xs: []i32) void {
    for (xs) |*x| x.* *= 2;
}
var nums = [_]i32{ 1, 2, 3 };
doubleAll(&nums);   // nums is now {2, 4, 6}
```

Passing slices is the default way to hand collections to functions. Arrays
copy; slices alias. If a function should work on any number of elements, its
parameter is a slice, full stop.

Out-of-range slicing (`xs[3..7]` when `xs.len == 5`) is a checked panic in
Debug/ReleaseSafe builds — you get a stack trace, not silent corruption.

## Sentinels and string literals

`[N:0]u8` is an array of N bytes with a *guaranteed* 0 byte after them (the
sentinel — not counted in `len`). Likewise `[:0]const u8` is a slice with a
guaranteed terminating 0. C interop needs these; most Zig code doesn't.

Now the punchline — the type of a string literal:

```zig
const lit = "zig";           // type: *const [3:0]u8
```

A pointer to a constant array of 3 bytes plus a null terminator. It coerces
to `[]const u8`, and that's the type you should think of as "string":

```zig
const s: []const u8 = "zig"; // the everyday string type
```

There is **no string type in Zig**. A string is a slice of bytes that you
promise yourself is text. `s.len` counts *bytes*, not characters:
`"héllo".len == 6` because `é` is two bytes in UTF-8. For ASCII puzzle input
(which is all of AoC) bytes and characters coincide, so this rarely bites —
but know it's bytes all the way down.

Character literals like `'a'` are just numbers (`u8` in context), so
arithmetic and comparison work: `'z' - 'a' == 25`, `c >= '0' and c <= '9'`.
`std.ascii` has the classifiers so you don't hand-roll them: `isDigit`,
`isAlphabetic`, `isWhitespace`, `toLower`, `toUpper`.

## The `std.mem` toolbox

Everything below works on any `[]const T`, but you'll use them on strings:

```zig
std.mem.eql(u8, a, b)                    // content equality
std.mem.startsWith(u8, s, "Card")        // bool
std.mem.endsWith(u8, s, ".txt")          // bool
std.mem.find(u8, haystack, needle)       // ?usize, first occurrence
std.mem.findScalar(u8, s, ':')           // ?usize, first single byte
std.mem.findLast(u8, haystack, needle)   // ?usize, last occurrence
std.mem.count(u8, haystack, needle)      // non-overlapping occurrences
std.mem.trim(u8, s, " \t\r\n")           // strip a set of bytes, both ends
std.mem.trimStart / std.mem.trimEnd      // one end only
std.mem.replace(u8, in, old, new, buf)   // into a buffer; see replacementSize
```

Naming note: 0.16 renamed the search family — `indexOf` → `find`,
`indexOfScalar` → `findScalar`, `lastIndexOf` → `findLast`,
`indexOfPos` → `findPos`. The old names still exist as deprecated aliases and
appear in most material online; write the new ones.

All searches return `?usize` — module 04's optionals immediately pay off:

```zig
const colon = std.mem.findScalar(u8, line, ':') orelse return error.BadLine;
const rest = line[colon + 1 ..];
```

## Splitting and parsing — the core AoC skill

Two iterators cut strings on a single-byte delimiter, and the difference
matters:

| input `"a,,b,"` with `','`  | yields                  |
| --------------------------- | ----------------------- |
| `std.mem.tokenizeScalar`    | `"a"`, `"b"`            |
| `std.mem.splitScalar`       | `"a"`, `""`, `"b"`, `""`|

**tokenize** treats runs of delimiters as one separator and never yields an
empty piece — right for whitespace-separated input. **split** cuts at every
delimiter and keeps empties — right for CSV-ish input where an empty field
means something. `std.mem.splitSequence(u8, s, " -> ")` splits on a
multi-byte separator.

```zig
var it = std.mem.tokenizeScalar(u8, "12  34 -5", ' ');
var sum: i64 = 0;
while (it.next()) |tok| {
    sum += try std.fmt.parseInt(i64, tok, 10);
}
```

`parseInt(i64, s, 10)` returns `error.InvalidCharacter` or `error.Overflow`
on bad input — that's why the `try`. Base 10 is explicit; pass `0` to
auto-detect `0x`/`0b` prefixes. `parseFloat(f64, s)` is the float twin.

The pieces the iterators yield are slices *into the original string* — no
copies are made, which is fast, but they're only valid as long as the
original buffer is.

Put together, the parse-a-line pattern that unlocks half of AoC:

```zig
// "x=3, y=-7"  →  Point{ .x = 3, .y = -7 }
var fields = std.mem.splitSequence(u8, line, ", ");
// each field: name '=' number — find the '=', slice, parseInt
```

You'll implement exactly this in exercise 05.

## Building strings

Four ways, in the order you should reach for them:

```zig
// 1. into a stack buffer — no allocation, error.NoSpaceLeft if too small
var buf: [64]u8 = undefined;
const s = try std.fmt.bufPrint(&buf, "{s}: {d}", .{ name, n });

// 2. allocate exactly the right amount — caller frees
const t = try std.fmt.allocPrint(alloc, "{s}: {d}", .{ name, n });
defer alloc.free(t);

// 3. glue many pieces
const j = try std.mem.join(alloc, ", ", &.{ "a", "b", "c" }); // "a, b, c"
const c = try std.mem.concat(alloc, u8, &.{ "foo", "bar" });  // "foobar"
```

`++` concatenates arrays too — but only at compile time. For runtime data
it's `concat`, `join`, or a format function.

## Gotchas

1. **Strings are bytes.** `.len` is a byte count; indexing gives you a byte.
   Fine for ASCII, wrong for multi-byte UTF-8 characters. (`std.unicode`
   exists when you truly need code points.)
2. **Arrays copy, slices alias.** `var b = a;` on an array duplicates it.
   A slice of `a` sees every later change to `a` — and mutating through a
   `[]T` slice mutates the original. Know which one you're holding.
3. **No `==` on arrays or slices.** On slices, `==` compares pointer+length
   identity, not contents — a classic bug. Content comparison is
   `std.mem.eql`. On arrays `==` doesn't even compile.
4. **Array length lives in the type; slice length lives in the value.**
   `[4]u8` can't be passed where `[5]u8` is expected. Functions over
   "any number of elements" must take a slice.
5. **Sentinel-terminated vs not.** `"abc"` is `*const [3:0]u8`, so string
   literals coerce to *both* `[]const u8` and `[:0]const u8`. A slice you
   built yourself has no sentinel and won't coerce to `[:0]const u8` — only
   C-interop APIs care, but the error message will make sense now.
6. **Split pieces borrow the input.** Slices from `tokenize`/`split`/`trim`
   point into the original buffer. If the buffer is freed or reused (say, a
   line-reading loop), the slices dangle. Copy (`alloc.dupe`) what you keep.
7. **tokenize vs split on empty pieces** — see the table above. Using
   `splitScalar` on `"a  b"` with `' '` gives you an empty string between
   the spaces, and your `parseInt` blows up with `error.InvalidCharacter`.

## Exercises

Work them in order, from inside this directory:

| file                    | practice                                                    |
| ----------------------- | ----------------------------------------------------------- |
| `01_arrays.zig`         | array init forms, value semantics, comparing, 2D grids      |
| `02_slices.zig`         | slicing, aliasing, mutation through `[]T`, `&arr` coercion  |
| `03_strings.zig`        | bytes, char literals, `std.ascii`, fixed-buffer building    |
| `04_mem_toolbox.zig`    | eql/find/trim/count/replace; palindromes; line cleanup      |
| `05_split_parse.zig`    | tokenize vs split, parseInt/parseFloat, line → struct       |
| `06_building_strings.zig` | bufPrint, allocPrint, join, concat, uppercasing           |

```sh
zig test 01_arrays.zig     # red → implement the TODOs → green
../check.sh 05             # run the whole module from the repo root
```

Reference answers live in `../solutions/05_arrays_slices_strings/` — struggle
first, peek second.
