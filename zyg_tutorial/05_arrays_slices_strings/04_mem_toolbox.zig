//! Exercise 04: The std.mem toolbox
//!
//! Concepts: std.mem.eql, find/findScalar/findLast (the functions old docs
//! call indexOf/indexOfScalar/lastIndexOf), startsWith/endsWith,
//! trim/trimStart/trimEnd, count, replace + replacementSize.
//!
//! Run:  zig test 04_mem_toolbox.zig
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.mem

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// Naming note: Zig 0.16 renamed the search family. indexOf -> find,
// indexOfScalar -> findScalar, lastIndexOf -> findLast, indexOfPos ->
// findPos. The old names survive as deprecated aliases (you'll see them all
// over the internet); write the new ones. All of them return ?usize.

// TODO: true if s reads the same forwards and backwards ("abba", "racecar").
// Classic two-index walk: one from the front, one from the back, compare as
// they close in. The empty string is a palindrome.
fn isPalindrome(s: []const u8) bool {
    _ = s; // TODO: remove
    return false;
}

// TODO: count non-overlapping occurrences of needle inside haystack.
// Two routes: loop with std.mem.findPos(u8, haystack, start, needle)
// yourself, advancing start past each hit — or just use std.mem.count.
// (Do try the manual loop once; AoC often needs a variation of it.)
fn countOccurrences(haystack: []const u8, needle: []const u8) usize {
    _ = haystack; // TODO: remove
    _ = needle; // TODO: remove
    return 0;
}

// Puzzle input lines carry junk. Given something like
//     "  answer = 42   # trust me"
// return just "answer = 42":
//   1. if there's a '#', keep only what's before it   (std.mem.findScalar)
//   2. trim spaces and tabs from both ends            (std.mem.trim)
//
// TODO: implement it.
fn cleanLine(line: []const u8) []const u8 {
    return line; // TODO
}

// TODO: return the text between the FIRST `open` byte and the LAST `close`
// byte, or null when either is missing or they're in the wrong order.
//     between("pos=<3, 4>", '<', '>')  ->  "3, 4"
// std.mem.findScalar and std.mem.findScalarLast do the searching; you do
// the slicing. `orelse return null` keeps it tidy.
fn between(s: []const u8, open: u8, close: u8) ?[]const u8 {
    _ = s; // TODO: remove
    _ = open; // TODO: remove
    _ = close; // TODO: remove
    return null;
}

// Fixed-buffer find-and-replace. std.mem.replacementSize tells you exactly
// how many bytes the result will need; std.mem.replace writes the result
// into your buffer and returns the number of replacements it made.
//
// TODO: replace every needle with replacement, write into buf, and return
// the slice of buf holding the result. Assume buf is big enough.
fn replaceAll(input: []const u8, needle: []const u8, replacement: []const u8, buf: []u8) []const u8 {
    _ = needle; // TODO: remove
    _ = replacement; // TODO: remove
    _ = buf; // TODO: remove
    return input;
}

test "toolbox tour" {
    const line = "  Card 42: 1 2 3  ";
    const t = std.mem.trim(u8, line, " ");
    try expect(std.mem.startsWith(u8, t, "Card"));
    try expect(std.mem.endsWith(u8, t, "3"));

    // findScalar returns ?usize — the index of the first match.
    // TODO: fix the expected index of ':' inside `t`.
    try expectEqual(@as(?usize, 0), std.mem.findScalar(u8, t, ':'));

    // TODO: how many spaces does `t` contain?
    try expectEqual(@as(usize, 0), std.mem.count(u8, t, " "));
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
    // replacement longer than the needle — replacementSize earns its keep
    try std.testing.expectEqualStrings(
        "north, north, east",
        replaceAll("N, N, east", "N", "north", &buf),
    );
}
