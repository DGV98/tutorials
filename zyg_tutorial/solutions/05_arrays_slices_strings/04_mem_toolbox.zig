//! Exercise 04: The std.mem toolbox — reference solution
//!
//! Run:  zig test 04_mem_toolbox.zig
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.mem

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn isPalindrome(s: []const u8) bool {
    if (s.len < 2) return true;
    var i: usize = 0;
    var j: usize = s.len - 1;
    while (i < j) : ({
        i += 1;
        j -= 1;
    }) {
        if (s[i] != s[j]) return false;
    }
    return true;
}

fn countOccurrences(haystack: []const u8, needle: []const u8) usize {
    // std.mem.count(u8, haystack, needle) gives the same answer; here's the
    // manual loop for when you need a variation of it.
    var n: usize = 0;
    var start: usize = 0;
    while (std.mem.findPos(u8, haystack, start, needle)) |i| {
        n += 1;
        start = i + needle.len; // skip past the hit -> non-overlapping
    }
    return n;
}

fn cleanLine(line: []const u8) []const u8 {
    const end = std.mem.findScalar(u8, line, '#') orelse line.len;
    return std.mem.trim(u8, line[0..end], " \t");
}

fn between(s: []const u8, open: u8, close: u8) ?[]const u8 {
    const start = std.mem.findScalar(u8, s, open) orelse return null;
    const end = std.mem.findScalarLast(u8, s, close) orelse return null;
    if (end <= start) return null;
    return s[start + 1 .. end];
}

fn replaceAll(input: []const u8, needle: []const u8, replacement: []const u8, buf: []u8) []const u8 {
    const size = std.mem.replacementSize(u8, input, needle, replacement);
    _ = std.mem.replace(u8, input, needle, replacement, buf);
    return buf[0..size];
}

test "toolbox tour" {
    const line = "  Card 42: 1 2 3  ";
    const t = std.mem.trim(u8, line, " ");
    try expect(std.mem.startsWith(u8, t, "Card"));
    try expect(std.mem.endsWith(u8, t, "3"));
    try expectEqual(@as(?usize, 7), std.mem.findScalar(u8, t, ':'));
    try expectEqual(@as(usize, 4), std.mem.count(u8, t, " "));
}

test "isPalindrome" {
    try expect(isPalindrome("racecar"));
    try expect(isPalindrome("abba"));
    try expect(isPalindrome(""));
    try expect(isPalindrome("x"));
    try expect(!isPalindrome("zig"));
    try expect(!isPalindrome("ab"));
}

test "countOccurrences" {
    try expectEqual(@as(usize, 3), countOccurrences("abababa", "ab"));
    try expectEqual(@as(usize, 2), countOccurrences("aaaa", "aa")); // non-overlapping!
    try expectEqual(@as(usize, 0), countOccurrences("zig", "cat"));
}

test "cleanLine" {
    try std.testing.expectEqualStrings("answer = 42", cleanLine("  answer = 42   # trust me"));
    try std.testing.expectEqualStrings("no comment", cleanLine("no comment \t"));
    try std.testing.expectEqualStrings("", cleanLine("# all comment"));
}

test "between" {
    const inner = between("pos=<3, 4>", '<', '>') orelse return error.TestExpectedSome;
    try std.testing.expectEqualStrings("3, 4", inner);
    const word = between("[hello]", '[', ']') orelse return error.TestExpectedSome;
    try std.testing.expectEqualStrings("hello", word);
    try expect(between("no brackets", '<', '>') == null);
    try expect(between(">backwards<", '<', '>') == null);
}

test "replaceAll" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings(
        "the cat sat on the cat",
        replaceAll("the dog sat on the dog", "dog", "cat", &buf),
    );
    try std.testing.expectEqualStrings(
        "north, north, east",
        replaceAll("N, N, east", "N", "north", &buf),
    );
}
