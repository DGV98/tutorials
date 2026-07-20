# 07 — Memory & Allocators

Everything you've written so far lived on the stack: locals, arrays, structs
with sizes known at compile time, all freed automatically when their scope
ended. That runs out the moment a problem says "read an unknown number of
lines" — you need memory whose size is decided at runtime and whose lifetime
you control. That's the heap, and in Zig, the heap is something you operate
deliberately, not something that happens to you.

In this module you learn:

- pointers: `*T`, `&x`, `.*`, `*const T`, pointers to arrays and how they
  coerce to slices
- the `std.mem.Allocator` interface — an ordinary value you pass to any
  function that needs to allocate
- `alloc`/`free`, `create`/`destroy`, and the `defer` habit that keeps them
  paired
- `ArenaAllocator` and `FixedBufferAllocator`, and how to choose
- the caller-owns convention: who frees what, `dupe`, `toOwnedSlice`
- `errdefer` and proving your error paths leak-free with
  `std.testing.checkAllAllocationFailures`

## Pointers first

A pointer is an address plus a type. The syntax is small:

```zig
var x: i32 = 5;
const p: *i32 = &x;        // & takes the address of x
p.* = 6;                   // .* dereferences: x is now 6
const cp: *const i32 = &x; // *const T: you can read cp.*, writes won't compile
```

Zig passes arguments by value, so a function that should modify its caller's
variable takes a pointer:

```zig
fn addOne(n: *i32) void {
    n.* += 1;
}
```

Pointers to arrays get their own type, `*[N]T`, which remembers the length —
and coerces to a slice, which is how you actually use it:

```zig
var arr = [_]i32{ 1, 2, 3, 4 };
const ap: *[4]i32 = &arr;
const s: []i32 = ap;   // coercion: same memory, now with runtime length
```

That coercion is the missing piece of the slice story from module 05: a slice
*is* a pointer and a length traveling together. Two deliberate absences: Zig
pointers can't be null (that's `?*T`, module 04), and single-item pointers
have no arithmetic (want to walk memory? use a slice).

## The Allocator interface

Zig has no `new`, no garbage collector, and no global allocator hiding in the
runtime. Heap memory comes from a `std.mem.Allocator` — a plain value. Any
function that allocates takes one as a parameter:

```zig
fn readNames(alloc: std.mem.Allocator, ...) ![][]u8 { ... }
```

This buys you two things. Honesty: a signature tells you whether a function
touches the heap. Control: the *caller* decides the strategy — a test passes
the leak-checking allocator, a batch job passes an arena, an embedded target
passes a fixed buffer, and `readNames` doesn't change.

The core operations:

```zig
const buf = try alloc.alloc(u8, n);   // []u8: n bytes, uninitialized
defer alloc.free(buf);                // release — same allocator, exactly once

const p = try alloc.create(Point);    // *Point: one item, uninitialized
defer alloc.destroy(p);               // counterpart of create
```

Rules worth engraving:

- `alloc`/`free` for slices, `create`/`destroy` for single items. Don't cross
  the pairs.
- Allocation can fail: `error.OutOfMemory` is in every return type, hence the
  `try`.
- New memory is uninitialized. Debug builds fill it with `0xAA` so you notice.
  `@memset(buf, 0)` fills a slice; `p.* = .{ ... }` initializes a struct.
- Write the `defer alloc.free(...)` on the line after the allocation, before
  writing anything else. `defer` runs on every exit path — early returns and
  `try` failures included — so pairing them immediately means you can't
  forget a path.

## Which allocator?

| Allocator                  | What it is                              | Reach for it when                          |
| -------------------------- | --------------------------------------- | ------------------------------------------ |
| `std.testing.allocator`    | leak/double-free detector               | every test — non-negotiable in this course |
| `init.gpa` in `main`       | general-purpose, leak-checked in Debug  | default for real programs (module 10)      |
| `std.heap.ArenaAllocator`  | free everything at once                 | many allocations, one shared lifetime      |
| `std.heap.FixedBufferAllocator` | carves up a buffer you provide     | small, bounded work; no heap wanted        |
| `std.heap.page_allocator`  | raw pages from the OS                   | as a backing allocator; rarely directly    |

The arena deserves the spotlight, because it will carry most of your Advent
of Code solutions:

```zig
var arena = std.heap.ArenaAllocator.init(backing_alloc);
defer arena.deinit();              // ONE call frees every allocation below
const alloc = arena.allocator();

// allocate freely: parse lines, dupe strings, build tables...
// no individual frees. none. deinit reclaims it all.
```

When a whole pile of allocations dies at the same moment — parse input,
compute answer, exit — tracking individual frees is busywork with extra bugs.
The arena deletes the whole problem, including cleanup on error paths.

`FixedBufferAllocator` is the opposite trade: you hand it a buffer (usually a
stack array) and it never touches the heap. Deterministic, fast, and it
returns a very real `error.OutOfMemory` when the buffer is spent:

```zig
var buf: [256]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);
const alloc = fba.allocator();
```

The nesting idiom you'll use in every exercise from 03 on: an arena *on top
of* `std.testing.allocator`. The arena gets its blocks from the testing
allocator, so a forgotten `arena.deinit()` still fails the test.

## Ownership: who frees this?

C's memory bugs are mostly one question answered wrong: *who owns this
allocation?* Zig's answer is a convention the entire standard library
follows:

> A function that returns allocated memory transfers ownership to the caller.
> The caller frees it — with the same allocator — exactly once.

You'll see it as `alloc` parameters plus doc comments reading "caller owns
the returned slice". Two tools show up constantly:

```zig
const copy = try alloc.dupe(u8, input);      // allocate + copy in one call
```

`dupe` is how you keep a string that outlives its source — remember from
module 05 that a slice is a *view*, so storing a slice of a buffer that's
about to be reused or freed is a bug; dupe it instead. And for "I don't know
the size yet", the `ArrayList` preview (module 08 does it properly), in its
0.16 unmanaged form — the list stores no allocator, you pass it to each call:

```zig
var list: std.ArrayList(i32) = .empty;
defer list.deinit(alloc);
try list.append(alloc, 42);
const owned = try list.toOwnedSlice(alloc);  // buffer now belongs to the caller
```

## Failure in the middle: errdefer

The hard case: a function makes three allocations, and the second one fails.
`try` propagates the error — and the first allocation leaks, because the
caller never got a handle to it. `defer` alone can't fix this: on *success*
you don't want to free anything (the caller now owns it), on *failure* you
must free everything so far. That split is exactly what `errdefer` is for —
it runs only when the function exits with an error:

```zig
const p = try alloc.create(Person);
errdefer alloc.destroy(p);            // fires only on error below this line
p.name = try alloc.dupe(u8, name);
errdefer alloc.free(p.name);
p.email = try alloc.dupe(u8, email);  // fails? free name, destroy p, in that order
return p;                             // success? no errdefer runs
```

And because eyeballing error paths doesn't scale, the standard library ships
a harness that *forces* every allocation to fail, one at a time, and checks
nothing leaks: `std.testing.checkAllAllocationFailures`. Exercise 05 is built
around it.

## Gotchas

**Dangling pointers.** A pointer to a stack local is dead the moment the
function returns — `return &local;` hands back an address into a recycled
stack frame. The compiler catches the blatant cases; the sneaky ones are why
"who owns this and how long does it live" must be answerable for every
pointer you store. Returning heap memory (with ownership transferred) is the
fix.

**Use-after-free.** Free memory, keep a slice to it, read it later. The
allocator may have handed those bytes to someone else; you read garbage or
corrupt theirs. `std.testing.allocator` poisons freed memory so tests catch
it loudly.

**Double-free.** Two owners both "clean up" the same allocation. The usual
root cause is copying a slice around until two places think they own it.
One allocation, one owner, one free.

**Leaks.** The quiet one. Nothing crashes; your program just grows. This is
why every test in this module uses `std.testing.allocator` — a leaked
allocation fails the test and prints a stack trace pointing at the exact
`alloc` call. Treat that safety net as part of the assignment: once green,
delete a `free` and read the report so you recognize it later.

**Why so explicit?** Zig's position: allocation is a real cost and a real
failure point, so it must be visible at the call site. No hidden `malloc`, no
GC pauses, no operator that allocates behind your back. The price is that
*you* answer the ownership question; the payoff is that programs state their
memory behavior in their signatures, allocation failure is handleable like
any other error, and switching strategy (arena, fixed buffer, pool) is a
one-line change at the call site instead of a rewrite.

## Exercises

Work them in order; run each with `zig test <file>` until green.

1. `01_pointers.zig` — address-of, dereference, const pointers, array
   pointers coercing to slices, mutation through pointers, swap. No heap yet.
2. `02_alloc_free.zig` — `alloc`/`free`, `create`/`destroy`, `@memset`, the
   defer-right-after-alloc habit, and what a leak report looks like.
3. `03_arena_fba.zig` — build a pile of strings in an arena and free them
   with one `deinit`; format into a stack buffer with a
   `FixedBufferAllocator`; split text into lines that point into the source.
4. `04_ownership.zig` — caller-owns in practice: `dupe`, concatenation into
   a fresh allocation, and `toOwnedSlice` on an unmanaged `ArrayList`.
5. `05_errdefer_leaks.zig` — the boss fight: multi-step construction that
   cannot leak no matter which allocation fails, proven by
   `checkAllAllocationFailures`.

If a test fails with a leak trace instead of a wrong value, that *is* the
exercise: find the allocation in the trace and give it an owner.
