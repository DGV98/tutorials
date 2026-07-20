//! Exercise 03: Strings are bytes
//!
//! Concepts: string literals are *const [N:0]u8 and coerce to []const u8,
//! there is no string type, iterating bytes, char literals are numbers,
//! std.ascii helpers (isDigit, toLower, ...), building a string into a
//! fixed buffer by hand.
//!
//! Run:  zig test 03_strings.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#String-Literals-and-Unicode-Code-Point-Literals

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// A string is a slice of bytes. Iterate it like any slice: for (s) |c| —
// each c is a u8. std.ascii.isDigit(c) is true for '0'...'9'.
//
// TODO: count how many bytes of s are ASCII digits.
fn countDigits(s: []const u8) usize {
    _ = s; // TODO: remove
    return 0;
}

// Char literals like 'a' are just numbers (here: u8). You can compare them,
// do arithmetic on them, and switch on them — switch even takes ranges:
//     switch (c) { 'a', 'e', 'i', 'o', 'u' => ..., else => ... }
//
// TODO: count lowercase vowels (a e i o u) in s.
fn countVowels(s: []const u8) usize {
    _ = s; // TODO: remove
    return 0;
}

// Case-insensitive equality: lengths must match, then compare byte by byte
// through std.ascii.toLower. (for (a, b) |x, y| walks two slices in step —
// but only after you've checked they're the same length.)
//
// TODO: implement it.
fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    _ = a; // TODO: remove
    _ = b; // TODO: remove
    return false;
}

// Building a string WITHOUT an allocator: write bytes into a caller-provided
// buffer, then return the part you used: buf[0..s.len].
//
// ROT13 rotates every letter 13 places ('a'->'n', 'n'->'a', 'Z'->'M');
// everything else passes through unchanged. Because chars are numbers,
// arithmetic does the work:  'a' + (c - 'a' + 13) % 26
//
// TODO: write the ROT13 of s into buf and return the written slice.
// Assume buf is big enough.
fn rot13(s: []const u8, buf: []u8) []const u8 {
    _ = s; // TODO: remove
    return buf[0..0];
}

test "a string literal is a pointer to a sentinel-terminated array" {
    const lit = "zig";
    // The concrete type: pointer to 3 constant bytes with a guaranteed 0
    // after them (the sentinel — not counted in len).
    try expect(@TypeOf(lit) == *const [3:0]u8);

    // It coerces freely to []const u8 — the everyday "string" type.
    const s: []const u8 = lit;

    // TODO: fix both expected values. (Remember: 'z' is just a u8.)
    try expectEqual(@as(usize, 0), s.len);
    try expectEqual(@as(u8, 0), s[0]);
}

test "length counts bytes, not characters" {
    // é is TWO bytes in UTF-8. There is no string type doing magic for you.
    const word = "héllo";
    // TODO: fix the expected length.
    try expectEqual(@as(usize, 5), word.len);
}

test "countDigits" {
    try expectEqual(@as(usize, 3), countDigits("a1b22c"));
    try expectEqual(@as(usize, 0), countDigits("no digits here"));
    try expectEqual(@as(usize, 4), countDigits("2026"));
}

test "countVowels" {
    try expectEqual(@as(usize, 5), countVowels("advent of code"));
    try expectEqual(@as(usize, 0), countVowels("zzz"));
}

test "eqlIgnoreCase" {
    try expect(eqlIgnoreCase("Zig", "zIG"));
    try expect(eqlIgnoreCase("", ""));
    try expect(!eqlIgnoreCase("Zig", "Zag"));
    try expect(!eqlIgnoreCase("Zig", "Zigg"));
}

test "rot13" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("Hello, World!", rot13("Uryyb, Jbeyq!", &buf));

    // Applying ROT13 twice gets you back where you started.
    var buf2: [64]u8 = undefined;
    const once = rot13("Attack at dawn 123", &buf);
    try std.testing.expectEqualStrings("Attack at dawn 123", rot13(once, &buf2));
}
