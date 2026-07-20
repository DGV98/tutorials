//! Exercise 03: try and catch
//! Concepts: `try` to propagate, `catch` with a default value,
//!           `catch |err| switch (err)`, why `catch unreachable` is a smell
//! Run: zig test 03_try_catch.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#try

const std = @import("std");

// Given, already working — the failable building block for this file:

const DivideError = error{DivisionByZero};

fn divide(a: i32, b: i32) DivideError!i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}

// `try f()` means: unwrap the success value, or return the error to MY
// caller right now. It is sugar for `f() catch |err| return err`. Chains of
// failable calls read almost like the happy path, but every point where an
// error can exit is still marked — grep for `try` and you see them all.
//
// std.fmt.parseInt(i32, s, 10) returns error.InvalidCharacter or
// error.Overflow on bad input. Note the inferred `!i32` below: this
// function's error set is parseInt's errors merged with divide's,
// and the compiler works that out for you.
//
// TODO: parse both strings as i32 (base 10), divide num by den, return the
// result. Every failure just propagates — this function is 3 lines and
// contains the word `try` three times.
fn parseAndDivide(num: []const u8, den: []const u8) !i32 {
    _ = num; // delete when implemented
    _ = den;
    return error.NotImplemented;
}

// `catch` is how you STOP an error instead of passing it up. The simplest
// form supplies a default value:  const x = failable() catch 0;
//
// TODO: return a divided by b, or `fallback` if the division fails.
// No if statement — one line with catch.
fn divideOr(a: i32, b: i32, fallback: i32) i32 {
    _ = a; // delete when implemented
    _ = b;
    _ = fallback;
    return 0;
}

// To react differently per error, capture it and switch:
//
//     failable() catch |err| switch (err) {
//         error.A => ...,
//         error.B => ...,
//     };
//
// The switch must be exhaustive over the function's error set — add a case
// to the set and the compiler points at every switch you forgot to update.
// That is the payoff of error sets being types, not conventions.
//
// TODO: call parseAndDivide and classify the outcome as one of exactly:
//   "ok", "invalid character", "overflow", "division by zero"
// If your parseAndDivide error set is right, the switch needs no else.
fn classify(num: []const u8, den: []const u8) []const u8 {
    _ = num; // delete when implemented
    _ = den;
    return "";
}

// `catch unreachable` means: "if this errors, crash in safe builds and be
// undefined behavior in ReleaseFast". It is only defensible when you can
// PROVE from local logic that the error cannot happen — and it is a smell
// anywhere near input, I/O, or allocation, because "can't happen" has a
// way of becoming "happened in production". Prefer try; reach for
// `catch unreachable` about as often as you write `undefined`.
//
// Here it is legitimate: dividing by the constant 2 cannot hit
// DivisionByZero, and the type system just can't see that.
//
// TODO: return divide(n, 2), unwrapped with catch unreachable.
fn halveEven(n: i32) i32 {
    _ = n; // delete when implemented
    return 0;
}

test "parseAndDivide happy path" {
    try std.testing.expectEqual(42, try parseAndDivide("84", "2"));
    try std.testing.expectEqual(-4, try parseAndDivide("-12", "3"));
}

test "parseAndDivide propagates every failure" {
    try std.testing.expectError(error.InvalidCharacter, parseAndDivide("4x", "2"));
    try std.testing.expectError(error.InvalidCharacter, parseAndDivide("4", ""));
    try std.testing.expectError(error.Overflow, parseAndDivide("99999999999", "1"));
    try std.testing.expectError(error.DivisionByZero, parseAndDivide("84", "0"));
}

test "divideOr" {
    try std.testing.expectEqual(5, divideOr(10, 2, -1));
    try std.testing.expectEqual(-1, divideOr(10, 0, -1));
    try std.testing.expectEqual(99, divideOr(3, 0, 99));
}

test "classify" {
    try std.testing.expectEqualStrings("ok", classify("84", "2"));
    try std.testing.expectEqualStrings("invalid character", classify("4x", "2"));
    try std.testing.expectEqualStrings("overflow", classify("99999999999", "1"));
    try std.testing.expectEqualStrings("division by zero", classify("6", "0"));
}

test "halveEven" {
    try std.testing.expectEqual(4, halveEven(8));
    try std.testing.expectEqual(-3, halveEven(-6));
}
