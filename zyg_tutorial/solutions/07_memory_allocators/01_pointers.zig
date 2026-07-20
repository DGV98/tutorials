//! Exercise 01: Pointers
//!
//! Concepts: single-item pointers (*T), address-of (&), dereference (.*),
//! const pointers (*const T), pointers to arrays (*[N]T) and their coercion
//! to slices, passing by pointer to mutate, a swap function.
//!
//! Run: zig test 01_pointers.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Pointers

const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

// A quick map of the syntax before you start:
//
//   var x: i32 = 5;
//   const p: *i32 = &x;      // & takes the address; p is a pointer to x
//   p.* = 6;                 // .* dereferences; x is now 6
//   const cp: *const i32 = &x; // read-only pointer: cp.* compiles, cp.* = 7 does not
//
// Two things Zig pointers do NOT do:
//   - They cannot be null. "Maybe a pointer" is spelled ?*T (module 04).
//   - Single-item pointers have no arithmetic. When you want "a pointer plus
//     a length", you want a slice ([]T) — that's the whole reason slices exist.

// This demo test already passes. Read it, run it, move on.
test "demo: address-of and dereference" {
    var x: i32 = 41;
    const p: *i32 = &x; // p holds the address of x
    p.* += 1; // write through the pointer
    try expectEqual(@as(i32, 42), x); // x itself changed

    const cp: *const i32 = &x; // *const T: read-only view
    try expectEqual(@as(i32, 42), cp.*); // reading is fine; writing won't compile
}

/// Add 10 to the integer that `x` points at.
///
/// Zig passes function arguments by value: `fn addTen(x: i32)` would receive
/// a copy and the caller would never see the change. To mutate the caller's
/// variable, take a pointer.
fn addTen(x: *i32) void {
    x.* += 10;
}

test "addTen mutates through a pointer" {
    var x: i32 = 5;
    addTen(&x);
    try expectEqual(@as(i32, 15), x);
}

/// Exchange the values behind `a` and `b`.
fn swap(a: *i32, b: *i32) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

test "swap exchanges two values" {
    var a: i32 = 1;
    var b: i32 = 99;
    swap(&a, &b);
    try expectEqual(@as(i32, 99), a);
    try expectEqual(@as(i32, 1), b);
}

/// Sum the elements of a 4-element array, received BY POINTER.
///
/// `*const [4]i32` is "pointer to an array of exactly 4 i32, read-only".
/// Passing `&arr` avoids copying the array. A pointer to an array coerces
/// to a slice — assign it to a `[]const i32` and iterate that.
fn sumArray(arr: *const [4]i32) i32 {
    const items: []const i32 = arr; // *const [4]i32 coerces to []const i32
    var total: i32 = 0;
    for (items) |x| total += x;
    return total;
}

test "sumArray reads through a const array pointer" {
    const arr = [4]i32{ 3, 7, 20, 12 };
    try expectEqual(@as(i32, 42), sumArray(&arr));
}

/// Fill the array behind `arr` so that arr[i] == i * i.
///
/// `*[5]u32` is a MUTABLE pointer to an array — writes go straight into the
/// caller's array. You can `for` over a pointer-to-array directly, and
/// capturing with `|*slot|` gives you a pointer to each element to write to.
fn fillSquares(arr: *[5]u32) void {
    for (arr, 0..) |*slot, i| {
        slot.* = @intCast(i * i);
    }
}

test "fillSquares writes through an array pointer" {
    var arr = [_]u32{ 9, 9, 9, 9, 9 };
    fillSquares(&arr);
    try expectEqualSlices(u32, &.{ 0, 1, 4, 9, 16 }, &arr);
}

// One more thing to internalize before the next exercise: every pointer above
// points at STACK memory that some caller owns, and it dies when that stack
// frame returns. Returning `&local` from a function is the classic dangling
// pointer bug (Zig catches many of these at compile time, not all). Heap
// allocation — memory whose lifetime YOU control — is the next exercise.
