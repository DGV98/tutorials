//! Exercise 01: Functions
//! Concepts: fn syntax, immutable parameters, return types, pub,
//!           early return, function pointers, comptime fn parameters
//! Run: zig test 01_functions.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Functions

const std = @import("std");

// A function in Zig: `fn name(param: Type, ...) ReturnType { ... }`.
// Two fully-worked examples — the tests below also use them as inputs:

fn double(x: i32) i32 {
    return x * 2;
}

fn addTen(x: i32) i32 {
    return x + 10;
}

// `pub` makes a function visible to other files that @import this one.
// Inside a single file it changes nothing — but a library's API is exactly
// its set of pub declarations, so get in the habit.

// TODO: return the mean of a and b. Integer division truncates; for signed
// integers you must be explicit about it: @divTrunc(a, b).
pub fn average(a: i32, b: i32) i32 {
    // Delete the two discards below once you actually use the parameters —
    // Zig makes unused parameters a compile error, so the stub needs them.
    _ = a;
    _ = b;
    return 0;
}

// Parameters are IMMUTABLE. Zig passes them as if by value (a copy — the
// compiler may pass big ones by reference behind the scenes, but you can
// never tell), and you cannot assign to them:
//
//     fn broken(n: u32) u32 {
//         n -= 1;            // error: cannot assign to constant
//     }
//
// The idiom: copy the parameter into a local `var` and mutate that.
//
// TODO: return how many decimal digits n has. countDigits(0) == 1,
// countDigits(7) == 1, countDigits(12345) == 5.
// Hint: `var x = n;` then repeatedly divide by 10.
fn countDigits(n: u32) u32 {
    _ = n; // delete when implemented
    return 0;
}

// `return` exits the function immediately. Early returns beat deeply nested
// if/else: handle the edge cases first, and the "main" path reads flat.
//
// TODO: clamp x into [lo, hi]: if x < lo return lo, if x > hi return hi,
// otherwise return x. Use early returns, not nested else branches.
fn clamp(x: i32, lo: i32, hi: i32) i32 {
    _ = x; // delete when implemented
    _ = lo;
    _ = hi;
    return 0;
}

// Functions are values too. `*const fn (i32) i32` is a pointer to any
// function taking an i32 and returning an i32. A function name coerces to
// this pointer type automatically, so callers just write applyTwice(double, 3).
//
// TODO: apply f to x, then apply f to that result: f(f(x)).
fn applyTwice(f: *const fn (i32) i32, x: i32) i32 {
    _ = f; // delete when implemented
    _ = x;
    return 0;
}

// Zig has no closures, so you can't build a new function at runtime that
// remembers f and g. The pragmatic "compose" takes the input right away.
//
// TODO: return g(f(x)) — f first, then g.
fn compose(f: *const fn (i32) i32, g: *const fn (i32) i32, x: i32) i32 {
    _ = f; // delete when implemented
    _ = g;
    _ = x;
    return 0;
}

// The other way to pass a function: a comptime parameter of function TYPE
// (`fn (i32) i32`, no `*const`). The function must be known at compile time,
// and the compiler stamps out a specialized copy per function — zero
// indirection. This is how std.sort takes its comparator.
//
// TODO: apply f to x, n times. n == 0 returns x unchanged.
fn applyN(comptime f: fn (i32) i32, x: i32, n: u32) i32 {
    _ = f; // delete when implemented
    _ = x;
    _ = n;
    return 0;
}

test "average" {
    try std.testing.expectEqual(5, average(4, 6));
    try std.testing.expectEqual(-5, average(-2, -8));
    try std.testing.expectEqual(3, average(3, 4)); // truncates toward zero
}

test "countDigits" {
    try std.testing.expectEqual(1, countDigits(0));
    try std.testing.expectEqual(1, countDigits(7));
    try std.testing.expectEqual(3, countDigits(100));
    try std.testing.expectEqual(5, countDigits(12345));
}

test "clamp" {
    try std.testing.expectEqual(5, clamp(5, 1, 10)); // inside: unchanged
    try std.testing.expectEqual(1, clamp(-3, 1, 10)); // below: lo
    try std.testing.expectEqual(10, clamp(99, 1, 10)); // above: hi
}

test "applyTwice" {
    try std.testing.expectEqual(12, applyTwice(double, 3));
    try std.testing.expectEqual(25, applyTwice(addTen, 5));
    // &double works too — the name alone already coerces to the pointer.
    try std.testing.expectEqual(8, applyTwice(&double, 2));
}

test "compose" {
    try std.testing.expectEqual(16, compose(double, addTen, 3)); // addTen(double(3))
    try std.testing.expectEqual(26, compose(addTen, double, 3)); // double(addTen(3))
}

test "applyN" {
    try std.testing.expectEqual(32, applyN(double, 1, 5));
    try std.testing.expectEqual(7, applyN(addTen, 7, 0));
    try std.testing.expectEqual(31, applyN(addTen, 1, 3));
}
