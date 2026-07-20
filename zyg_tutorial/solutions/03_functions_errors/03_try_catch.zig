//! Solution 03: try and catch

const std = @import("std");

const DivideError = error{DivisionByZero};

fn divide(a: i32, b: i32) DivideError!i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}

fn parseAndDivide(num: []const u8, den: []const u8) !i32 {
    // The happy path reads straight through; each `try` is a marked exit.
    // Inferred error set: parseInt's {InvalidCharacter, Overflow}
    // merged with divide's {DivisionByZero}.
    const n = try std.fmt.parseInt(i32, num, 10);
    const d = try std.fmt.parseInt(i32, den, 10);
    return try divide(n, d);
}

fn divideOr(a: i32, b: i32, fallback: i32) i32 {
    // catch-with-default: stop the error here, substitute a value.
    return divide(a, b) catch fallback;
}

fn classify(num: []const u8, den: []const u8) []const u8 {
    // Capture the error and switch on it. No `else` arm: the switch is
    // provably exhaustive over parseAndDivide's inferred error set, so
    // growing that set later becomes a compile error here — the compiler
    // walks you to every classification site you need to update.
    _ = parseAndDivide(num, den) catch |err| return switch (err) {
        error.InvalidCharacter => "invalid character",
        error.Overflow => "overflow",
        error.DivisionByZero => "division by zero",
    };
    return "ok";
}

fn halveEven(n: i32) i32 {
    // Legitimate `catch unreachable`: the denominator is the constant 2,
    // so DivisionByZero is impossible by local reasoning. Anywhere the
    // error depends on inputs, this would be a bug waiting for its moment.
    return divide(n, 2) catch unreachable;
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
