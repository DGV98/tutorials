//! Exercise 05: Split & parse — the AoC survival kit
//!
//! Concepts: tokenizeScalar vs splitScalar (they treat empty pieces
//! differently!), splitSequence, std.fmt.parseInt / parseFloat, and the
//! parse-a-line-into-a-struct pattern.
//!
//! Run:  zig test 05_split_parse.zig
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.mem.tokenizeScalar

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// The two line-cutters, side by side:
//
//   std.mem.tokenizeScalar(u8, s, d) — treats runs of d as ONE separator and
//                                      NEVER yields an empty piece.
//   std.mem.splitScalar(u8, s, d)    — cuts at EVERY d and KEEPS empties.
//
// Rule of thumb: tokenize for whitespace-separated input, split for CSV-ish
// input where an empty field carries meaning. Both return an iterator you
// drive with `while (it.next()) |piece| { ... }` — each piece is a slice
// INTO the original string (no copies).

// TODO: count the pieces tokenizeScalar yields for s.
fn countTokens(s: []const u8, delim: u8) usize {
    _ = s; // TODO: remove
    _ = delim; // TODO: remove
    return 99;
}

// TODO: count the pieces splitScalar yields for s.
fn countFields(s: []const u8, delim: u8) usize {
    _ = s; // TODO: remove
    _ = delim; // TODO: remove
    return 99;
}

// The bread-and-butter AoC line: whitespace-separated integers.
// std.fmt.parseInt(i64, token, 10) -> error.InvalidCharacter / .Overflow on
// bad input, hence the ! in our return type — `try` inside the loop and the
// error bubbles out.
//
// TODO: tokenize on ' ' and return the sum of the numbers.
fn sumLine(line: []const u8) !i64 {
    _ = line; // TODO: remove
    return error.NotImplemented;
}

// splitSequence cuts on a MULTI-byte separator.
//
// TODO: parse "3 -> 9" (separator " -> ") into [2]i64{ 3, 9 }.
fn parseArrow(s: []const u8) ![2]i64 {
    _ = s; // TODO: remove
    return error.NotImplemented;
}

// parseFloat is the float twin of parseInt.
//
// TODO: return the mean of whitespace-separated floats:
// "1.0 2.0 6.0" -> 3.0. Return error.NoNumbers for a line with no tokens.
fn mean(line: []const u8) !f64 {
    _ = line; // TODO: remove
    return error.NotImplemented;
}

const Point = struct { x: i32, y: i32 };

// The pattern that unlocks half of Advent of Code: line -> struct.
//
//   "x=3, y=-7"  ->  Point{ .x = 3, .y = -7 }
//
// One plan: splitSequence on ", " to get the fields; in each field,
// findScalar the '=' (return error.BadFormat if missing), slice out what's
// after it, parseInt. Field order is fixed: x first, y second.
//
// TODO: implement it.
fn parsePoint(line: []const u8) !Point {
    _ = line; // TODO: remove
    return error.NotImplemented;
}

test "tokenize vs split on the same input" {
    const csv = "a,,b,c,";
    // tokenize skips the empties: "a", "b", "c"
    try expectEqual(@as(usize, 3), countTokens(csv, ','));
    // split keeps them: "a", "", "b", "c", ""
    try expectEqual(@as(usize, 5), countFields(csv, ','));

    // They even disagree about the empty string:
    try expectEqual(@as(usize, 0), countTokens("", ','));
    try expectEqual(@as(usize, 1), countFields("", ','));

    // Runs of delimiters: tokenize collapses, split does not.
    try expectEqual(@as(usize, 2), countTokens("a   b", ' '));
    try expectEqual(@as(usize, 4), countFields("a   b", ' '));
}

test "sumLine" {
    try expectEqual(@as(i64, 12), try sumLine("10 -3 5"));
    try expectEqual(@as(i64, 0), try sumLine(""));
    // Extra spaces are fine — that's why we tokenize, not split.
    try expectEqual(@as(i64, 6), try sumLine("  1  2   3 "));
    // Garbage propagates as an error.
    try std.testing.expectError(error.InvalidCharacter, sumLine("1 x 2"));
}

test "parseArrow" {
    try expectEqual([2]i64{ 3, 9 }, try parseArrow("3 -> 9"));
    try expectEqual([2]i64{ -40, 1000 }, try parseArrow("-40 -> 1000"));
}

test "mean" {
    try expectEqual(@as(f64, 3.0), try mean("1.0 2.0 6.0"));
    try expectEqual(@as(f64, 2.5), try mean("2.5"));
    try std.testing.expectError(error.NoNumbers, mean("   "));
}

test "parsePoint" {
    try expectEqual(Point{ .x = 3, .y = -7 }, try parsePoint("x=3, y=-7"));
    try expectEqual(Point{ .x = 0, .y = 42 }, try parsePoint("x=0, y=42"));
    try std.testing.expectError(error.BadFormat, parsePoint("x3, y=7"));
}
