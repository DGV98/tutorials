# Module 08 — Collections: the AoC toolbox

You know how to get memory (module 07). This module is about what you put in
it: the four data structures that solve 90% of Advent of Code puzzles —
dynamic arrays, hash maps, sorted slices, and heaps. By the end you'll parse
unknown-length input, count things, group things, and pull the "best" thing
out of a pile, all without leaking a byte.

## What you'll learn

- `std.ArrayList`: the growable array, and the `toOwnedSlice` handoff
- `std.AutoHashMap` and `std.StringHashMap`: lookup tables, sets, counters
- `getOrPut`: find-or-insert in one hash lookup
- `std.mem.sort`, custom comparators, binary search, min/max
- `std.PriorityQueue`: min-heaps, max-heaps, and the top-k trick
- The ownership rules that keep `std.testing.allocator` from yelling at you

## One rule before anything else: who holds the allocator?

Zig 0.16 splits its containers into two camps, and you'll mix them in the
same program constantly:

| Container | Style | Create | Methods |
|---|---|---|---|
| `ArrayList` | unmanaged | `.empty` | take `alloc`: `append(alloc, x)` |
| `PriorityQueue` | unmanaged | `.empty` | take `alloc`: `push(alloc, x)` |
| `AutoHashMap` / `StringHashMap` | managed | `.init(alloc)` | no `alloc`: `put(k, v)` |

Unmanaged containers are just `{ items, capacity }` — no allocator field —
so every method that might grow them asks for one. Managed hash maps store
the allocator at init and never ask again. If the compiler complains about
an unexpected (or missing) allocator argument, you've mixed the camps up.

Old tutorials show `ArrayList(T).init(alloc)` and `pq.add(x)`. Those are
pre-0.15. Translate on sight.

## ArrayList

The default collection. When in doubt, it's an ArrayList.

```zig
var list: std.ArrayList(i64) = .empty;
defer list.deinit(alloc);

try list.append(alloc, 42);
try list.appendSlice(alloc, &.{ 1, 2, 3 });

list.items[0] = 7;          // .items is a plain []T — index, slice, iterate
for (list.items) |x| { ... }

const last = list.pop();    // ?i64 — null when empty, never a crash
```

The AoC parse loop — you don't know how many values are coming, so append,
then hand back an exact-size slice:

```zig
var list: std.ArrayList(i64) = .empty;
defer list.deinit(alloc);
var it = std.mem.tokenizeAny(u8, input, ", \n");
while (it.next()) |tok| {
    try list.append(alloc, try std.fmt.parseInt(i64, tok, 10));
}
const nums = try list.toOwnedSlice(alloc); // caller owns; list is empty again
```

Removal is a choice between two costs:

- `orderedRemove(i)` — shifts everything after `i` left. O(n), keeps order.
- `swapRemove(i)` — moves the *last* element into slot `i`. O(1), destroys
  order. AoC rarely cares about order; reach for this one first.

And for scratch lists inside a loop, `clearRetainingCapacity()` empties the
list but keeps the buffer, so the next iteration appends without allocating.

## Hash maps

`std.AutoHashMap(K, V)` hashes ints, enums, bools — and plain structs of
those, which means grid coordinates Just Work:

```zig
const Point = struct { x: i32, y: i32 };
var grid = std.AutoHashMap(Point, u8).init(alloc);
defer grid.deinit();

try grid.put(.{ .x = 3, .y = 7 }, '#');
const c: ?u8 = grid.get(.{ .x = 3, .y = 7 });
_ = grid.contains(.{ .x = 0, .y = 0 });   // bool
_ = grid.remove(.{ .x = 3, .y = 7 });     // bool: was it there?
_ = grid.count();                          // u32
```

A set is a map with `void` values — they occupy zero bytes:

```zig
var seen = std.AutoHashMap(Point, void).init(alloc);
try seen.put(p, {});          // insert (duplicates overwrite harmlessly)
if (seen.contains(p)) ...     // membership
```

Three ways to walk a map, none in any guaranteed order:

```zig
var it = map.iterator();               // entries: key_ptr + value_ptr
while (it.next()) |e| { _ = e.key_ptr.*; _ = e.value_ptr.*; }

var kit = map.keyIterator();           // just *K
var vit = map.valueIterator();         // just *V
```

For `[]const u8` keys, use `std.StringHashMap(V)` — AutoHashMap refuses
slices because it can't know whether you mean "same pointer" or "same
bytes". StringHashMap hashes the bytes.

### getOrPut: the one-lookup counter

The naive count is `get` then `put` — two hash lookups. `getOrPut` does it
in one, returning pointers into the map plus a flag telling you whether the
key was already there:

```zig
const gop = try counts.getOrPut(word);
if (!gop.found_existing) gop.value_ptr.* = 0; // value is UNINITIALIZED memory!
gop.value_ptr.* += 1;
```

That's the whole frequency counter. Memorize it — every "how many of each"
puzzle is these four lines.

## Sorting and searching slices

`std.mem.sort` mutates in place, allocates nothing:

```zig
std.mem.sort(i32, slice, {}, comptime std.sort.asc(i32));   // ascending
std.mem.sort(i32, slice, {}, comptime std.sort.desc(i32));  // descending
```

For structs, write a comparator — `fn (ctx, a, b) bool`, "does a come before
b". Multi-key sorts compare the primary key and fall back on ties:

```zig
std.mem.sort(Person, people, {}, struct {
    fn lessThan(_: void, a: Person, b: Person) bool {
        if (a.age != b.age) return a.age < b.age;
        return std.mem.lessThan(u8, a.name, b.name); // tie-break by name
    }
}.lessThan);
```

Once sorted, `std.sort.binarySearch` finds in O(log n). Its compare function
gets your context (typically the needle) and an item, and returns a
`std.math.Order`:

```zig
fn order(needle: i32, item: i32) std.math.Order {
    return std.math.order(needle, item);
}
const idx: ?usize = std.sort.binarySearch(i32, sorted, needle, order);
```

Not sorted? `std.mem.indexOfScalar(T, slice, value)` is the honest linear
scan. And if all you need is an extreme, skip sorting entirely:
`std.mem.min(T, slice)` / `std.mem.max(T, slice)` (they assert non-empty).
`std.mem.reverse(T, slice)` flips in place.

## PriorityQueue

A heap: pops the "best" element in O(log n) without keeping everything
sorted. You define "best" with a compare function returning
`std.math.Order` — `.lt` means "a pops before b":

```zig
fn minFirst(_: void, a: i64, b: i64) std.math.Order {
    return std.math.order(a, b);        // min-heap
    // std.math.order(b, a) would be a max-heap — same swap as desc sort
}
const MinQueue = std.PriorityQueue(i64, void, minFirst);

var pq: MinQueue = .empty;              // unmanaged, like ArrayList
defer pq.deinit(alloc);
try pq.push(alloc, 5);
const best = pq.peek();                 // ?i64, look don't take
const taken = pq.pop();                 // ?i64, null when empty
_ = pq.count();
```

The killer application is top-k: "sum of the 3 largest" without sorting a
million elements. Keep a *min*-heap capped at k — push everything, pop
whenever you exceed k. The smallest is always the one evicted, so the k
largest survive. O(n log k), k elements of memory.

## Gotchas

**Appending invalidates pointers.** `append` may reallocate the backing
buffer, at which point every pointer into `list.items` — including `.items`
slices you saved, and `&list.items[i]` — dangles. Same for `getOrPut`'s
`value_ptr` after the *next* map insertion. Grab pointers late, drop them
before the next append. This is the #1 collections segfault.

**Don't mutate a container while iterating it.** Inserting into or removing
from a hash map invalidates live iterators (and their key/value pointers).
Collect changes into an ArrayList, apply them after the loop.

**StringHashMap does NOT copy keys.** It stores your slice — pointer and
length. If the backing text is freed or reused (a line buffer!), every key
dangles. Either keep the source alive as long as the map, or
`alloc.dupe(u8, key)` on first insert and free the dupes on teardown.
Exercise 03 makes you do it properly.

**getOrPut's fresh value is uninitialized.** `found_existing == false` means
`value_ptr.*` is garbage until you write it. Writing `+= 1` before `= 0` is
undefined behavior that often "works" in Debug.

**`pop` returns an optional.** Both `ArrayList.pop()` and
`PriorityQueue.pop()` return `?T`. `while (list.pop()) |v|` drains cleanly;
unwrap with `orelse` instead of blind `.?`.

**Owned slices are yours to free.** `toOwnedSlice(alloc)` transfers
ownership: the list is empty afterward, and freeing the slice is now your
job. `std.testing.allocator` will report exactly what you forgot.

## Exercises

Work through them in order — the capstone assumes the rest.

| File | Topic |
|---|---|
| `01_arraylist.zig` | append/pop/remove/insert, toOwnedSlice, clearRetainingCapacity |
| `02_hashmap.zig` | AutoHashMap CRUD, three iterators, struct keys, void-value sets |
| `03_counter.zig` | StringHashMap + getOrPut frequency counter, key ownership |
| `04_sorting.zig` | asc/desc, struct comparators, binary search, min/max/reverse |
| `05_priorityqueue.zig` | min/max heaps via compareFn, top-k without a full sort |
| `06_anagram_groups.zig` | capstone: map of sorted-key to ArrayList, full ownership contract |

Each file compiles as-is but its tests fail. Replace the `// TODO:` stubs
(and delete the `_ = x;` discards as you go) until:

```sh
zig test 01_arraylist.zig     # from this directory
../check.sh 08                # or run the whole module
```

Every test uses `std.testing.allocator`, so a leak is a failure. If you get
"memory leaked" with a trace pointing at a `dupe` or `append`, that's not
noise — that's the exercise. Reference solutions live in
`solutions/08_collections/`, but wrestle with the ownership errors first;
that fight is the lesson.
