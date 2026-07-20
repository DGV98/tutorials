//! Solution 02: Error sets and error unions

const std = @import("std");

const MathError = error{DivisionByZero};
const ParseError = error{InvalidChar};
const CalcError = MathError || ParseError;

fn safeDivide(a: i32, b: i32) MathError!i32 {
    // An error is returned like any other value — no throw, no unwinding.
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}

fn parseDigit(c: u8) ParseError!u8 {
    if (c < '0' or c > '9') return error.InvalidChar;
    return c - '0';
}

fn evalDigitDivision(num: u8, den: u8) CalcError!i32 {
    // Each try unwraps a success or forwards the error to our caller.
    // ParseError and MathError both coerce into the merged CalcError.
    const n = try parseDigit(num);
    const d = try parseDigit(den);
    return try safeDivide(n, d);
}

fn checkedIncrement(n: u8) !u8 {
    // Inferred error set: the compiler sees exactly {Overflow} here.
    // The error name is invented on the spot — no declaration needed.
    if (n == 255) return error.Overflow;
    return n + 1;
}

test "safeDivide divides" {
    try std.testing.expectEqual(5, try safeDivide(10, 2));
    try std.testing.expectEqual(3, try safeDivide(7, 2));
    try std.testing.expectEqual(-3, try safeDivide(-7, 2));
}

test "safeDivide rejects zero denominator" {
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
