# Zig 0.16 API Notes

This course targets **Zig 0.16.0** (installed at `~/.local/bin/zig`). Zig is
pre-1.0 and the standard library changed substantially in 0.15 and 0.16. Most
tutorials, blog posts, and LLM answers you find online target 0.11–0.14 and
**will not compile** on this toolchain. This file collects the current,
verified patterns so you can translate old examples on sight.

Every snippet below was compiled and run against Zig 0.16.0.

## The big picture

Two sweeping changes dominate:

1. **Containers are unmanaged.** `std.ArrayList` (and friends) no longer store
   an allocator. You pass the allocator to each method that allocates.
2. **`std.Io` interface.** All I/O (files, stdout, networking) goes through an
   explicit `Io` instance, exactly like allocators: the program's entry point
   obtains one and passes it down. `std.fs.cwd()`, `std.io.getStdOut()`, and
   the old reader/writer APIs are gone.

## Entry point: `main`

Plain `pub fn main() !void` still works. But 0.16 added a much nicer form —
the runtime hands you an allocator and an `Io`:

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;      // general-purpose allocator (leak-checked in Debug)
    const io = init.io;        // the Io instance
    const arena = init.arena.allocator(); // arena freed automatically at exit
    _ = gpa; _ = io; _ = arena;
}
```

`init.minimal.args` holds the command-line args (see below).

## Printing

```zig
// Quick debugging — goes to stderr, no setup:
std.debug.print("x = {d}\n", .{x});

// Proper stdout (buffered writer):
var buf: [1024]u8 = undefined;
var stdout_writer = std.Io.File.stdout().writer(io, &buf);
const stdout = &stdout_writer.interface; // *std.Io.Writer
try stdout.print("Hello, {s}! {d}\n", .{ "world", 42 });
try stdout.flush(); // don't forget — it's buffered
```

Common format specifiers: `{d}` decimal, `{s}` string, `{c}` char, `{x}` hex,
`{b}` binary, `{e}` scientific, `{any}` debug-print anything, `{t}` tag name of
an enum/error, `{}` default for the type.

## Command-line args

```zig
pub fn main(init: std.process.Init) !void {
    var args: std.process.Args.Iterator = .init(init.minimal.args);
    _ = args.next(); // argv[0], the program path
    while (args.next()) |arg| {
        std.debug.print("arg: {s}\n", .{arg});
    }
}
```

## Reading files

```zig
// Whole file into allocated buffer (note: Io.Dir, not fs; Io first, limit last):
const content = try std.Io.Dir.cwd().readFileAlloc(io, "input.txt", gpa, .limited(1 << 20));
defer gpa.free(content);

// Embed a file at compile time (no Io needed; path relative to the .zig file):
const data = @embedFile("input.txt");

// Line-by-line via a File.Reader:
var file = try std.Io.Dir.cwd().openFile(io, "input.txt", .{});
defer file.close(io);
var rbuf: [4096]u8 = undefined;
var file_reader = file.reader(io, &rbuf);
const r = &file_reader.interface; // *std.Io.Reader
while (r.takeDelimiterExclusive('\n')) |line| {
    // use line ([]u8, valid until next take)
} else |err| switch (err) {
    error.EndOfStream => {},
    else => |e| return e,
}
```

### Getting an `Io` inside a `test` block

Tests don't receive `std.process.Init`, so construct one:

```zig
test "needs io" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    _ = io;
}
```

## ArrayList (unmanaged since 0.15)

```zig
var list: std.ArrayList(i32) = .empty;   // NOT .init(alloc)
defer list.deinit(alloc);                 // alloc passed to methods
try list.append(alloc, 42);
try list.appendSlice(alloc, &.{ 1, 2, 3 });
const last = list.pop();                  // ?i32
for (list.items) |x| { _ = x; }
const owned = try list.toOwnedSlice(alloc); // list becomes empty
defer alloc.free(owned);
```

## HashMaps (still managed — they store the allocator)

```zig
var map = std.AutoHashMap(i32, u32).init(alloc);   // numbers/structs as keys
defer map.deinit();
var smap = std.StringHashMap(u32).init(alloc);     // []const u8 keys
defer smap.deinit();

try map.put(5, 100);
const v: ?u32 = map.get(5);
const gop = try map.getOrPut(5);       // gop.found_existing, gop.value_ptr
if (!gop.found_existing) gop.value_ptr.* = 0;
gop.value_ptr.* += 1;                  // classic frequency-counter pattern

var it = map.iterator();
while (it.next()) |entry| {
    _ = entry.key_ptr.*; _ = entry.value_ptr.*;
}
```

## PriorityQueue (unmanaged in 0.16)

```zig
const PQ = std.PriorityQueue(i32, void, struct {
    fn lessThan(_: void, a: i32, b: i32) std.math.Order {
        return std.math.order(a, b); // min-heap
    }
}.lessThan);
var pq: PQ = .empty;        // NOT .init(alloc, ctx)
defer pq.deinit(alloc);
try pq.push(alloc, 5);      // was add()
const smallest = pq.pop();  // ?i32, was remove()
```

## Allocators

```zig
var dbg: std.heap.DebugAllocator(.{}) = .init;  // was GeneralPurposeAllocator
defer _ = dbg.deinit();                          // reports leaks
const gpa = dbg.allocator();

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();                            // frees everything at once
const a = arena.allocator();

var fba_buf: [1024]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&fba_buf); // no heap at all

// In tests, always:
const alloc = std.testing.allocator;             // fails the test on leaks
```

## Strings & parsing (mostly unchanged)

```zig
std.mem.eql(u8, a, b);
std.mem.startsWith(u8, s, "pre");  std.mem.endsWith(u8, s, "post");
std.mem.find(u8, s, "needle");               // ?usize — indexOf* are deprecated aliases of find*
std.mem.trim(u8, s, " \t\r\n");              // trimLeft/trimRight are now trimStart/trimEnd
var it = std.mem.tokenizeScalar(u8, "a  b c", ' ');  // skips empty
var it2 = std.mem.splitScalar(u8, "1,,3", ',');      // keeps empty
const n = try std.fmt.parseInt(i64, "-42", 10);
const f = try std.fmt.parseFloat(f64, "3.14");
const s = try std.fmt.allocPrint(alloc, "{d}-{s}", .{ 7, "x" }); // caller frees
```

## Sorting

```zig
std.mem.sort(i32, slice, {}, comptime std.sort.asc(i32));
// custom key:
std.mem.sort(Person, people, {}, struct {
    fn lt(_: void, a: Person, b: Person) bool { return a.age < b.age; }
}.lt);
```

## Testing

```zig
const expect = std.testing.expect;
try expect(x > 0);
try std.testing.expectEqual(@as(i32, 42), result); // expected first, comptime-coerced
try std.testing.expectEqualStrings("abc", s);
try std.testing.expectEqualSlices(i32, &.{ 1, 2 }, xs);
try std.testing.expectError(error.Overflow, failingCall());
```

Run with `zig test file.zig`.

## Quick old → new cheat table

| Pre-0.15 (what old tutorials show)          | Zig 0.16 (this course)                                  |
| ------------------------------------------- | ------------------------------------------------------- |
| `std.fs.cwd()`                               | `std.Io.Dir.cwd()` (+ pass `io`)                        |
| `std.io.getStdOut().writer()`                | `std.Io.File.stdout().writer(io, &buf)` → `.interface`  |
| `ArrayList(T).init(alloc)` / `list.deinit()` | `: ArrayList(T) = .empty` / `list.deinit(alloc)`        |
| `list.append(x)`                             | `list.append(alloc, x)`                                 |
| `GeneralPurposeAllocator(.{}){}`             | `DebugAllocator(.{}) = .init`                           |
| `std.process.argsAlloc(alloc)`               | `std.process.Args.Iterator = .init(init.minimal.args)`  |
| `readUntilDelimiterOrEof(buf, '\n')`         | `reader.interface.takeDelimiterExclusive('\n')`         |
| `pq.add(x)` / `pq.remove()`                  | `pq.push(alloc, x)` / `pq.pop()`                        |
| `@typeInfo(T).Struct`                        | `@typeInfo(T).@"struct"` (lowercase, quoted)            |
| `std.time.Timer.start()`                     | `std.Io.Clock.awake.now(io)` + `Timestamp.durationTo`   |
| `std.mem.trimLeft` / `trimRight`             | `std.mem.trimStart` / `trimEnd`                         |
| `std.mem.indexOf*` family                    | `std.mem.find*` family (indexOf* work but deprecated)   |

One more gotcha class worth knowing: discards. Zig rejects unused locals AND
unused function parameters (`_ = x;` to discard), rejects discarding an
`anyerror` you haven't inspected ("error set is discarded"), and rejects a
"pointless discard" of something you already used elsewhere in the signature.
The exercises lean on these errors deliberately — read what the compiler says.
