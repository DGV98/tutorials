//! Exercise 03: Integers
//!
//! Concepts: integer types (u8/i32/u64/usize), hex/binary/underscore
//!           literals, overflow is illegal, wrapping +% and saturating +|,
//!           @intCast, @divTrunc vs @divFloor, @mod vs @rem.
//!
//! Run: zig test 03_integers.zig
//!
//! Reference: https://ziglang.org/documentation/0.16.0/#Integers

const std = @import("std");

// Zig's integer types spell out signedness and bit width: u8, i32, u64,
// even u3 or i128. `usize` is the pointer-sized unsigned type (64-bit
// here) — you'll meet it constantly as the type of array indexes and
// lengths. Untyped literals like `42` are `comptime_int`: arbitrary
// precision at compile time, coerced to a real type when stored.
//
// Literal forms — all three of these are the same number:
//   240   ==   0xF0   ==   0b1111_0000
// Underscores are ignored; use them to group digits: 1_000_000.

// TODO: return the mask that keeps the upper 4 bits of a byte.
// Write it as a binary literal (0b....) so the shape of the mask is
// visible at a glance — that's the point of binary literals.
fn upperNibbleMask() u8 {
    return 0; // wrong on purpose
}

// Plain `+` on a u8 holding 255 does NOT wrap to 0 like it would in C.
// Overflow is illegal behavior: in Debug builds the program panics with
// "integer overflow". When wrap-around is what you MEAN, say so with the
// wrapping operators: +%, -%, *%.
//
// TODO: increment a byte counter so that 255 wraps to 0.
fn wrappingIncrement(counter: u8) u8 {
    _ = counter; // remove this discard when you implement
    return 1; // wrong on purpose
}

// Saturating operators (+|, -|, *|) clamp at the type's bounds instead of
// wrapping: 200 +| 100 on a u8 is 255. Good for meters, volumes, health
// bars — anything where "pin at max" beats "wrap to tiny".
//
// TODO: add two bytes, clamping at 255.
fn clampedAdd(a: u8, b: u8) u8 {
    _ = a; // remove these discards when you implement
    _ = b;
    return 0; // wrong on purpose
}

// Zig never converts integers implicitly when information could be lost.
// A u32 does not silently become a u8 — you must write @intCast(x), which
// says "I guarantee the value fits". If it doesn't fit, that's illegal
// behavior (Debug builds panic). Note there's no type argument: @intCast
// infers the destination from where the result goes — here, the return
// type.
//
// TODO: narrow a u32 (guaranteed by the caller to be <= 255) to a u8.
fn narrowToU8(x: u32) u8 {
    _ = x; // remove this discard when you implement
    return 1; // wrong on purpose
}

// Division. For signed integers, `a / b` does not even compile:
//   error: division with 'i32' and 'i32': signed integers must use
//          @divTrunc, @divFloor, or @divExact
// C truncates toward zero and Python floors — Zig refuses to guess for
// you. -7/2 is -3 truncated (chop the fraction) but -4 floored (round
// toward negative infinity).

// TODO: divide, rounding toward zero (the C behavior).
fn divTowardZero(a: i32, b: i32) i32 {
    _ = a; // remove these discards when you implement
    _ = b;
    return 0; // wrong on purpose
}

// TODO: divide, rounding toward negative infinity (the Python behavior).
fn divToNegInf(a: i32, b: i32) i32 {
    _ = a; // remove these discards when you implement
    _ = b;
    return 0; // wrong on purpose
}

// Same split for remainders: `%` on signed ints doesn't compile either.
// @rem takes the sign of the NUMERATOR: @rem(-7, 2) == -1.
// @mod takes the sign of the DENOMINATOR: @mod(-7, 2) == 1.
// @mod is what you want for "wrap this index into range" — it never goes
// negative when the length is positive.

// TODO: wrap `index` into [0, len) so that -1 means "last element".
fn wrapAround(index: i32, len: i32) i32 {
    _ = index; // remove these discards when you implement
    _ = len;
    return 0; // wrong on purpose
}

// TODO: the C-style remainder (sign follows the numerator).
fn remainder(a: i32, b: i32) i32 {
    _ = a; // remove these discards when you implement
    _ = b;
    return 0; // wrong on purpose
}

// ── The spec ────────────────────────────────────────────────────────────

test "upper nibble mask" {
    try std.testing.expectEqual(0xF0, upperNibbleMask());
}

test "wrapping increment" {
    try std.testing.expectEqual(0, wrappingIncrement(255));
    try std.testing.expectEqual(42, wrappingIncrement(41));
}

test "saturating add" {
    try std.testing.expectEqual(255, clampedAdd(200, 100));
    try std.testing.expectEqual(3, clampedAdd(1, 2));
}

test "narrowing cast" {
    try std.testing.expectEqual(200, narrowToU8(200));
    try std.testing.expectEqual(0, narrowToU8(0));
}

test "the two divisions disagree on negatives" {
    try std.testing.expectEqual(-3, divTowardZero(-7, 2));
    try std.testing.expectEqual(-4, divToNegInf(-7, 2));
    // ... and agree on positives:
    try std.testing.expectEqual(3, divTowardZero(7, 2));
    try std.testing.expectEqual(3, divToNegInf(7, 2));
}

test "mod wraps indexes, rem follows the numerator" {
    try std.testing.expectEqual(4, wrapAround(-1, 5));
    try std.testing.expectEqual(2, wrapAround(7, 5));
    try std.testing.expectEqual(-1, remainder(-7, 2));
    try std.testing.expectEqual(1, remainder(7, 2));
}
