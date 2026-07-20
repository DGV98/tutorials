//! Exercise 02: Error sets and error unions
//! Concepts: declaring error sets, returning errors, error union return
//!           types (`E!T`), inferred error sets (`!T`), merging with `||`
//! Run: zig test 02_error_sets.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Errors

const std = @import("std");

// Zig has no exceptions. An error is a VALUE — a member of an error set,
// which looks and acts a lot like an enum:

const MathError = error{DivisionByZero};
const ParseError = error{InvalidChar};

// `||` merges two error sets into one. A function that can fail in both
// ways returns the merged set:

const CalcError = MathError || ParseError;

// A return type of `MathError!i32` is an ERROR UNION: the function returns
// either an i32 or an error from MathError. The caller cannot silently
// ignore which one it got — the compiler forces them to deal with it.
// That is the whole error-handling story: no throw, no unwinding, just a
// return value with two cases.

// TODO: return a divided by b (@divTrunc — signed division must be explicit
// about rounding), or error.DivisionByZero if b is 0.
fn safeDivide(a: i32, b: i32) MathError!i32 {
    // This stub compiles but is wrong on purpose. Replace it.
    _ = a; // delete when implemented
    _ = b;
    return 0;
}

// TODO: convert an ASCII digit character to its numeric value:
// '0' -> 0 ... '9' -> 9. Anything else is error.InvalidChar.
// Hint: chars are just u8 numbers; '7' - '0' == 7.
fn parseDigit(c: u8) ParseError!u8 {
    _ = c; // delete when implemented
    return 0;
}

// A function using BOTH failable pieces returns the merged set. `try`
// (covered properly in the next exercise) unwraps a success value or
// returns the error to the caller — you'll want it three times here.
//
// TODO: parse both digit characters, then divide num by den.
// evalDigitDivision('8', '2') == 4.
fn evalDigitDivision(num: u8, den: u8) CalcError!i32 {
    _ = num; // delete when implemented
    _ = den;
    return 0;
}

// Writing `!u8` (nothing before the `!`) asks the compiler to INFER the
// error set from whatever the body can actually return. Handy while code
// is evolving; public APIs usually prefer explicit sets so the contract
// is visible. Note the error name below is invented on the spot — inferred
// sets pick up any `error.Whatever` you return.
//
// TODO: return n + 1, or error.Overflow if n is already 255 (the max u8).
fn checkedIncrement(n: u8) !u8 {
    _ = n; // delete when implemented
    return error.NotImplemented;
}

test "safeDivide divides" {
    try std.testing.expectEqual(5, try safeDivide(10, 2));
    try std.testing.expectEqual(3, try safeDivide(7, 2));
    try std.testing.expectEqual(-3, try safeDivide(-7, 2));
}

test "safeDivide rejects zero denominator" {
    // expectError asserts a call produced a SPECIFIC error value.
    try std.testing.expectError(error.DivisionByZero, safeDivide(1, 0));
}

test "parseDigit" {
    try std.testing.expectEqual(7, try parseDigit('7'));
    try std.testing.expectEqual(9, try parseDigit('9'));
    try std.testing.expectError(error.InvalidChar, parseDigit('x'));
    try std.testing.expectError(error.InvalidChar, parseDigit(' '));
}

test "evalDigitDivision happy path" {
    try std.testing.expectEqual(4, try evalDigitDivision('8', '2'));
    try std.testing.expectEqual(2, try evalDigitDivision('9', '4'));
}

test "evalDigitDivision propagates both kinds of failure" {
    try std.testing.expectError(error.InvalidChar, evalDigitDivision('x', '2'));
    try std.testing.expectError(error.InvalidChar, evalDigitDivision('8', '!'));
    try std.testing.expectError(error.DivisionByZero, evalDigitDivision('8', '0'));
}

test "checkedIncrement" {
    try std.testing.expectEqual(42, try checkedIncrement(41));
    try std.testing.expectError(error.Overflow, checkedIncrement(255));
}
