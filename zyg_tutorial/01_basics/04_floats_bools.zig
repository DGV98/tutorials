//! Exercise 04: Floats and bools
//!
//! Concepts: f32/f64, float literals, @floatFromInt / @intFromFloat,
//!           why == on floats bites (std.math.approxEqAbs),
//!           bool operators are `and` / `or` / `!` — not && / ||.
//!
//! Run: zig test 04_floats_bools.zig
//!
//! Reference: https://ziglang.org/documentation/0.16.0/#Floats

const std = @import("std");

// Zig has f16, f32, f64, f80, f128. Default to f64 unless you have a
// reason (GPU data, huge arrays). Untyped literals like `3.14` are
// `comptime_float` and coerce to whichever float type they're stored in.
// Note `9 / 5` is integer division (== 1); write `9.0 / 5.0` when you
// mean float math.

// TODO: convert Celsius to Fahrenheit:  F = C * 9/5 + 32
fn celsiusToFahrenheit(c: f64) f64 {
    _ = c; // remove this discard when you implement
    return 0; // wrong on purpose
}

// Mixing ints and floats never happens implicitly. To divide two i64s as
// floats you must convert each side explicitly:
//   const s: f64 = @floatFromInt(sum);
// Like @intCast, @floatFromInt has no type parameter — the destination
// type must be known from context, which is why the annotation `: f64`
// on the const matters.
//
// TODO: return sum / count as an f64 (count is never 0 in the tests).
fn average(sum: i64, count: i64) f64 {
    _ = sum; // remove these discards when you implement
    _ = count;
    return 0; // wrong on purpose
}

// Going the other way, @intFromFloat truncates toward zero: 3.99 -> 3,
// -3.99 -> -3. (If the float doesn't fit the int type, that's illegal
// behavior — Debug builds panic.)
//
// TODO: return the whole part of x, truncated toward zero.
fn wholePart(x: f64) i32 {
    _ = x; // remove this discard when you implement
    return 0; // wrong on purpose
}

// Floats are base-2: 0.1 has no exact representation, so 0.1 + 0.2 is
// 0.30000000000000004 and `0.1 + 0.2 == 0.3` is FALSE. Never test floats
// with == unless you know exactly why it's safe. Compare within a
// tolerance instead:
//   std.math.approxEqAbs(f64, a, b, tolerance)
//
// TODO: return true when a and b are within 1e-9 of each other.
fn nearlyEqual(a: f64, b: f64) bool {
    _ = a; // remove these discards when you implement
    _ = b;
    return false; // wrong on purpose
}

// Booleans: the operators are the KEYWORDS `and` and `or` (both
// short-circuit, like && and || in C), and negation is `!x`. Writing
// `a && b` is a compile error — the message even tells you to use `and`.
// There is no truthiness: `if (some_int)` doesn't compile; you write
// `if (some_int != 0)`.

// TODO: you may ride alone if you are at least 120 cm tall AND at least
// 8 years old.
fn canRideAlone(height_cm: u32, age: u8) bool {
    _ = height_cm; // remove these discards when you implement
    _ = age;
    return false; // wrong on purpose
}

// TODO: you need a jacket if it is raining OR colder than 10 degrees.
fn needsJacket(raining: bool, temp_c: i32) bool {
    _ = raining; // remove these discards when you implement
    _ = temp_c;
    return false; // wrong on purpose
}

// ── The spec ────────────────────────────────────────────────────────────

test "celsius to fahrenheit" {
    try std.testing.expect(std.math.approxEqAbs(f64, 212.0, celsiusToFahrenheit(100.0), 1e-9));
    try std.testing.expect(std.math.approxEqAbs(f64, -40.0, celsiusToFahrenheit(-40.0), 1e-9));
}

test "average of integers" {
    try std.testing.expect(std.math.approxEqAbs(f64, 3.5, average(7, 2), 1e-9));
    try std.testing.expect(std.math.approxEqAbs(f64, -2.5, average(-5, 2), 1e-9));
}

test "whole part truncates toward zero" {
    try std.testing.expectEqual(3, wholePart(3.99));
    try std.testing.expectEqual(-3, wholePart(-3.99));
}

test "nearlyEqual forgives float error but not real differences" {
    // The classic: exact equality fails...
    try std.testing.expect(0.1 + 0.2 != 0.3);
    // ...but approximate equality succeeds.
    try std.testing.expect(nearlyEqual(0.1 + 0.2, 0.3));
    try std.testing.expect(!nearlyEqual(1.0, 1.1));
}

test "canRideAlone needs both conditions" {
    try std.testing.expect(canRideAlone(140, 10));
    try std.testing.expect(!canRideAlone(140, 6));
    try std.testing.expect(!canRideAlone(90, 10));
}

test "needsJacket needs either condition" {
    try std.testing.expect(needsJacket(true, 20));
    try std.testing.expect(needsJacket(false, 5));
    try std.testing.expect(!needsJacket(false, 20));
}
