//! Exercise 05: Error-handling patterns
//! Concepts: optional -> error (`orelse return error.X`), error -> optional
//!           (`catch null`), `if (result) |v| ... else |err|`, anyerror,
//!           choosing between errors and optionals
//! Run: zig test 05_error_patterns.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Error-Union-Type

const std = @import("std");

// A 60-second optionals primer (module 04 goes deep): `?usize` holds either
// a usize or `null`. `opt orelse fallback` unwraps it, substituting the
// fallback when it's null. Errors and optionals are Zig's two "maybe"
// types, and real code constantly converts between them:
//
//   optional -> use when absence is a NORMAL outcome ("not in the map").
//   error    -> use when absence means a caller did something wrong, or
//               when there are MULTIPLE failure reasons to distinguish.
//
// Given, already working:

fn findScalar(haystack: []const u8, needle: u8) ?usize {
    return std.mem.indexOfScalar(u8, haystack, needle);
}

fn parseDigit(c: u8) error{NotADigit}!u8 {
    if (c < '0' or c > '9') return error.NotADigit;
    return c - '0';
}

// Pattern 1: optional -> error. The `orelse` fallback can be ANY expression
// — including `return error.X` — so lifting an optional into an error union
// is one line: `return maybeThing() orelse error.NotFound;`
//
// TODO: like findScalar, but absence is an error. One line via orelse.
fn strictIndexOf(s: []const u8, ch: u8) error{NotFound}!usize {
    _ = s; // delete when implemented
    _ = ch;
    return 0;
}

// Pattern 2: error -> optional. Going the other way, `catch` erases WHY it
// failed: `failable() catch null` collapses every error into "no value".
// Do this at boundaries where the caller genuinely doesn't care about the
// reason — and nowhere else, because the reason is gone for good.
//
// TODO: like parseDigit, but non-digits yield null. One line via catch.
fn digitOrNull(c: u8) ?u8 {
    _ = c; // delete when implemented
    return 0;
}

// Pattern 3: branch on an error union without try/catch. `if` can unwrap
// error unions just like optionals, with a second branch capturing the
// error:
//
//     if (failable()) |value| {
//         ... use value ...
//     } else |err| {
//         ... use err ...
//     }
//
// Use it when both outcomes lead to real work (not just propagation).
//
// TODO: return "even digit", "odd digit", or "not a digit" using exactly
// this if/else form on parseDigit(c).
fn describeDigit(c: u8) []const u8 {
    _ = c; // delete when implemented
    return "";
}

// `anyerror` is the superset of every error set in the whole program. A
// value of any error set coerces INTO anyerror; you need it when errors
// from unrelated subsystems funnel through one spot (loggers, retry loops).
// The cost: the compiler can no longer check your switch is exhaustive, so
// you're back to needing an `else` arm. Prefer concrete sets at API
// boundaries; anyerror is for plumbing.
//
// TODO: report whether retrying might help. error.NotFound and
// error.NotADigit are recoverable (true) — the input can be fixed and
// retried. Everything else (OutOfMemory, AccessDenied, ...) is not (false).
// (Fun fact: you can't `_ = err;` an error value — even DISCARDING an
// error is something Zig makes you say precisely. Hence the scaffold.)
fn isRecoverable(err: anyerror) bool {
    return switch (err) {
        // TODO: which error values deserve `=> true`?
        else => false,
    };
}

// Capstone: `catch` composes with control flow. Inside a loop,
// `parseDigit(c) catch continue` means "not parseable? next character".
// This skip-the-junk shape is everywhere in input-parsing code.
//
// TODO: return the numeric value of the FIRST digit character in s, or
// error.NoDigits if there is none. Loop + parseDigit + catch continue.
fn firstDigitValue(s: []const u8) error{NoDigits}!u8 {
    _ = s; // delete when implemented
    return 0;
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
