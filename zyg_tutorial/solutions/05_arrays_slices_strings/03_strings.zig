//! Exercise 03: Strings are bytes — reference solution
//!
//! Run:  zig test 03_strings.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#String-Literals-and-Unicode-Code-Point-Literals

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn countDigits(s: []const u8) usize {
    var n: usize = 0;
    for (s) |c| {
        if (std.ascii.isDigit(c)) n += 1;
    }
    return n;
}

fn countVowels(s: []const u8) usize {
    var n: usize = 0;
    for (s) |c| {
        switch (c) {
            'a', 'e', 'i', 'o', 'u' => n += 1,
            else => {},
        }
    }
    return n;
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (std.ascii.toLower(x) != std.ascii.toLower(y)) return false;
    }
    return true;
}

fn rot13(s: []const u8, buf: []u8) []const u8 {
    for (s, 0..) |c, i| {
        buf[i] = switch (c) {
            'a'...'z' => 'a' + (c - 'a' + 13) % 26,
            'A'...'Z' => 'A' + (c - 'A' + 13) % 26,
            else => c,
        };
    }
    return buf[0..s.len];
}

test "a string literal is a pointer to a sentinel-terminated array" {
    const lit = "zig";
    try expect(@TypeOf(lit) == *const [3:0]u8);

    const s: []const u8 = lit;
    try expectEqual(@as(usize, 3), s.len);
    try expectEqual(@as(u8, 'z'), s[0]);
}

test "length counts bytes, not characters" {
    const word = "héllo";
    try expectEqual(@as(usize, 6), word.len);
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

    var buf2: [64]u8 = undefined;
    const once = rot13("Attack at dawn 123", &buf);
    try std.testing.expectEqualStrings("Attack at dawn 123", rot13(once, &buf2));
}
