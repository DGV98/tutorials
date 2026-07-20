//! Solution 05: Error-handling patterns

const std = @import("std");

fn findScalar(haystack: []const u8, needle: u8) ?usize {
    return std.mem.indexOfScalar(u8, haystack, needle);
}

fn parseDigit(c: u8) error{NotADigit}!u8 {
    if (c < '0' or c > '9') return error.NotADigit;
    return c - '0';
}

fn strictIndexOf(s: []const u8, ch: u8) error{NotFound}!usize {
    // optional -> error: orelse's fallback can be any expression,
    // including an error value.
    return findScalar(s, ch) orelse error.NotFound;
}

fn digitOrNull(c: u8) ?u8 {
    // error -> optional: catch collapses every failure into null.
    // The reason is discarded — only do this when callers don't need it.
    return parseDigit(c) catch null;
}

fn describeDigit(c: u8) []const u8 {
    // if unwraps error unions like optionals, plus an error capture arm.
    // Both branches do real work, so neither try nor catch fits better.
    if (parseDigit(c)) |d| {
        return if (d % 2 == 0) "even digit" else "odd digit";
    } else |_| {
        return "not a digit";
    }
}

fn isRecoverable(err: anyerror) bool {
    // Errors are ordinary values: switch on them like enums. With anyerror
    // the compiler cannot know the full set, so an else arm is mandatory —
    // the price of erasing the concrete error set.
    return switch (err) {
        error.NotFound, error.NotADigit => true,
        else => false,
    };
}

fn firstDigitValue(s: []const u8) error{NoDigits}!u8 {
    for (s) |c| {
        // Not a digit? Skip it. catch composes with any control flow.
        const d = parseDigit(c) catch continue;
        return d;
    }
    return error.NoDigits;
}

test "strictIndexOf" {
    try std.testing.expectEqual(1, try strictIndexOf("zig", 'i'));
    try std.testing.expectEqual(0, try strictIndexOf("zig", 'z'));
    try std.testing.expectError(error.NotFound, strictIndexOf("zig", 'q'));
}

test "digitOrNull" {
    try std.testing.expectEqual(7, digitOrNull('7'));
    try std.testing.expectEqual(0, digitOrNull('0'));
    try std.testing.expectEqual(null, digitOrNull('x'));
    try std.testing.expectEqual(null, digitOrNull(' '));
}

test "describeDigit" {
    try std.testing.expectEqualStrings("even digit", describeDigit('4'));
    try std.testing.expectEqualStrings("odd digit", describeDigit('7'));
    try std.testing.expectEqualStrings("not a digit", describeDigit('x'));
}

test "isRecoverable" {
    try std.testing.expect(isRecoverable(error.NotFound));
    try std.testing.expect(isRecoverable(error.NotADigit));
    try std.testing.expect(!isRecoverable(error.OutOfMemory));
    try std.testing.expect(!isRecoverable(error.AccessDenied));
}

test "firstDigitValue" {
    try std.testing.expectEqual(3, try firstDigitValue("ab3c9"));
    try std.testing.expectEqual(7, try firstDigitValue("x7"));
    try std.testing.expectEqual(0, try firstDigitValue("0"));
    try std.testing.expectError(error.NoDigits, firstDigitValue("abc"));
    try std.testing.expectError(error.NoDigits, firstDigitValue(""));
}
