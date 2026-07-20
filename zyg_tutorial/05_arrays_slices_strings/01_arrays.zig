//! Exercise 01: Arrays
//!
//! Concepts: [N]T fixed-size arrays, initialization (explicit, [_] inference,
//! ** repetition, @splat), .len, indexing, value semantics (arrays copy on
//! assignment!), comparing arrays, 2D arrays.
//!
//! Run:  zig test 01_arrays.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Arrays

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// An array type is [N]T — the length N is part of the type, known at compile
// time. Arrays are passed BY VALUE: this function receives a copy of all
// eight elements. Iterate with `for (arr) |x|`.
//
// TODO: return the sum of every element.
fn sumArray(arr: [8]u16) u32 {
    _ = arr; // TODO: remove this line once you use `arr`
    return 0;
}

// Building an array: declare `var result: [6]u32 = undefined;` and fill it
// with a loop — `for (&result, 0..) |*slot, i|` gives you a pointer to each
// element plus its index. (Or compute it some other way; your call.)
//
// TODO: return the first 6 perfect squares: 0, 1, 4, 9, 16, 25.
fn squares() [6]u32 {
    return @splat(0); // TODO: replace — @splat fills every element with one value
}

// Arrays do NOT support ==. Compare contents with std.mem.eql, which takes
// slices — prefix each array with & to coerce it.
//
// TODO: return true when a and b hold the same bytes.
fn sameBytes(a: [4]u8, b: [4]u8) bool {
    _ = a; // TODO: remove
    _ = b; // TODO: remove
    return false;
}

// Function parameters are immutable in Zig. To return a modified version,
// copy the parameter into a var first:
//     var copy = arr;   // arrays are values — this duplicates all elements
//
// TODO: return a copy of `arr` whose first element is 99.
fn withFirst99(arr: [3]i32) [3]i32 {
    return arr; // TODO: copy to a var, modify the copy, return it
}

// A 2D array is an array of arrays: [3][3]i32 is 3 rows of 3 columns,
// indexed grid[row][col]. AoC grid puzzles live on these.
//
// TODO: return grid[0][0] + grid[1][1] + grid[2][2] (the main diagonal).
fn diagonalSum(grid: [3][3]i32) i32 {
    _ = grid; // TODO: remove
    return 0;
}

test "initialization shorthands" {
    // [_] asks the compiler to count the elements for you.
    const primes = [_]i32{ 2, 3, 5, 7, 11 };
    // ** repeats an array pattern at compile time.
    const ruler = [_]u8{ '-', '+' } ** 3; // "-+-+-+"
    // @splat fills every element with the same value.
    const blank: [9]u8 = @splat(' ');

    // TODO: replace the three 0s with the correct lengths.
    try expectEqual(@as(usize, 0), primes.len);
    try expectEqual(@as(usize, 0), ruler.len);
    try expectEqual(@as(usize, 0), blank.len);
}

test "sumArray" {
    const data = [8]u16{ 1, 2, 3, 4, 5, 6, 7, 8 };
    try expectEqual(@as(u32, 36), sumArray(data));
    try expectEqual(@as(u32, 800), sumArray(@splat(100)));
}

test "squares" {
    const s = squares();
    try std.testing.expectEqualSlices(u32, &.{ 0, 1, 4, 9, 16, 25 }, &s);
}

test "sameBytes" {
    const a = [4]u8{ 'z', 'i', 'g', '!' };
    const b = [_]u8{ 'z', 'i', 'g', '!' }; // same values, different init form
    const c = [4]u8{ 'z', 'a', 'g', '!' };
    try expect(sameBytes(a, b));
    try expect(!sameBytes(a, c));
}

test "arrays are values (copied on assignment)" {
    const original = [3]i32{ 1, 2, 3 };
    const changed = withFirst99(original);
    // The function worked on a copy — original is untouched.
    try expectEqual(@as(i32, 1), original[0]);
    try expectEqual(@as(i32, 99), changed[0]);
    try expectEqual(@as(i32, 3), changed[2]);
}

test "diagonalSum" {
    const grid = [3][3]i32{
        .{ 5, 1, 1 },
        .{ 1, 6, 1 },
        .{ 1, 1, 7 },
    };
    try expectEqual(@as(i32, 18), diagonalSum(grid));
}
