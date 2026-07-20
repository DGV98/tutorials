//! Exercise 04: Sorting and searching slices
//!
//! Concepts: std.mem.sort with std.sort.asc/desc, custom lessThan for
//! structs, std.sort.binarySearch, std.mem.indexOfScalar,
//! std.mem.min/max, std.mem.reverse.
//!
//! Run: zig test 04_sorting.zig
//!
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.sort
//!       https://ziglang.org/documentation/0.16.0/std/#std.mem.sort

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;

// Sorting mutates a slice in place and never allocates:
//
//     std.mem.sort(i32, slice, {}, comptime std.sort.asc(i32));
//
// The `{}` is a "context" value threaded through to your comparator —
// for simple sorts you don't need one, so you pass void. std.sort.asc/
// std.sort.desc build ready-made comparators for any numeric type.

pub const Person = struct {
    name: []const u8,
    age: u32,
};

/// Sort people by age ascending; break age ties by name ascending.
///
/// A comparator is any `fn (ctx, a, b) bool` returning "a comes before
/// b". For multi-key sorts: compare the primary key, fall back to the
/// secondary only on a tie. std.mem.lessThan(u8, a, b) gives you
/// lexicographic order for strings.
pub fn sortPeople(people: []Person) void {
    // TODO: std.mem.sort(Person, people, {}, <your comparator>).
    // Write the comparator as an in-place anonymous struct method:
    //     struct {
    //         fn lessThan(_: void, a: Person, b: Person) bool { ... }
    //     }.lessThan
    _ = people; // TODO: remove this discard once you use `people`.
}

/// Find `needle` in a SORTED slice in O(log n).
///
/// std.sort.binarySearch takes a context (pass the needle itself) and
/// a compare function `fn (ctx, item) std.math.Order` telling it
/// whether the target is .lt / .eq / .gt relative to `item`.
/// std.math.order(context, item) does exactly that for numbers.
pub fn indexOfSorted(haystack: []const i32, needle: i32) ?usize {
    // TODO: return std.sort.binarySearch(i32, haystack, needle, ...);
    // You'll need a small `fn (context: i32, item: i32) std.math.Order`
    // helper (file-level or anonymous struct, your choice).
    _ = haystack; // TODO: remove this discard once you use `haystack`.
    _ = needle; // TODO: remove this discard once you use `needle`.
    return null;
}

test "sort ascending and descending" {
    var xs = [_]i32{ 5, -1, 9, 2, 2 };

    // TODO: sort xs ascending with std.mem.sort + std.sort.asc.
    try expectEqualSlices(i32, &.{ -1, 2, 2, 5, 9 }, &xs);

    // TODO: now sort xs descending with std.sort.desc.
    try expectEqualSlices(i32, &.{ 9, 5, 2, 2, -1 }, &xs);
}

test "reverse flips a slice in place" {
    var xs = [_]i32{ 1, 2, 3, 4 };
    // TODO: flip xs with std.mem.reverse(i32, &xs).
    // (sort ascending + reverse == sort descending)
    try expectEqualSlices(i32, &.{ 4, 3, 2, 1 }, &xs);
}

test "sortPeople: by age, then by name" {
    var people = [_]Person{
        .{ .name = "carol", .age = 30 },
        .{ .name = "bob", .age = 25 },
        .{ .name = "alice", .age = 30 },
        .{ .name = "dave", .age = 25 },
    };

    sortPeople(&people);

    try expectEqualStrings("bob", people[0].name); // 25
    try expectEqualStrings("dave", people[1].name); // 25, d > b
    try expectEqualStrings("alice", people[2].name); // 30, a < c
    try expectEqualStrings("carol", people[3].name); // 30
}

test "binary search on a sorted slice" {
    const sorted = [_]i32{ 2, 4, 8, 16, 32, 64 };

    try expectEqual(3, indexOfSorted(&sorted, 16));
    try expectEqual(0, indexOfSorted(&sorted, 2));
    try expectEqual(null, indexOfSorted(&sorted, 5));

    // For UNSORTED data, linear search is the tool (provided, no TODO):
    const unsorted = [_]i32{ 8, 2, 64, 16 };
    try expectEqual(2, std.mem.indexOfScalar(i32, &unsorted, 64));
    try expectEqual(null, std.mem.indexOfScalar(i32, &unsorted, 5));
}

test "min and max without sorting" {
    const xs = [_]i32{ 3, 9, -2, 7 };
    _ = xs; // TODO: remove this discard once you use `xs`.
    // TODO: replace the zeros with std.mem.min(i32, &xs) and
    // std.mem.max(i32, &xs) — O(n) scans, no sort needed (both assert
    // the slice is non-empty).
    const lo: i32 = 0;
    const hi: i32 = 0;
    try expectEqual(-2, lo);
    try expectEqual(9, hi);
}
