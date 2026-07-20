//! Exercise 05: Split & parse — reference solution
//!
//! Run:  zig test 05_split_parse.zig
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.mem.tokenizeScalar

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn countTokens(s: []const u8, delim: u8) usize {
    var n: usize = 0;
    var it = std.mem.tokenizeScalar(u8, s, delim);
    while (it.next()) |_| n += 1;
    return n;
}

fn countFields(s: []const u8, delim: u8) usize {
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, s, delim);
    while (it.next()) |_| n += 1;
    return n;
}

fn sumLine(line: []const u8) !i64 {
    var sum: i64 = 0;
    var it = std.mem.tokenizeScalar(u8, line, ' ');
    while (it.next()) |tok| {
        sum += try std.fmt.parseInt(i64, tok, 10);
    }
    return sum;
}

fn parseArrow(s: []const u8) ![2]i64 {
    var it = std.mem.splitSequence(u8, s, " -> ");
    const a = it.next() orelse return error.BadFormat;
    const b = it.next() orelse return error.BadFormat;
    return .{
        try std.fmt.parseInt(i64, a, 10),
        try std.fmt.parseInt(i64, b, 10),
    };
}

fn mean(line: []const u8) !f64 {
    var sum: f64 = 0;
    var n: usize = 0;
    var it = std.mem.tokenizeScalar(u8, line, ' ');
    while (it.next()) |tok| {
        sum += try std.fmt.parseFloat(f64, tok);
        n += 1;
    }
    if (n == 0) return error.NoNumbers;
    return sum / @as(f64, @floatFromInt(n));
}

const Point = struct { x: i32, y: i32 };

// "x=3" -> 3. Shared by both fields of parsePoint.
fn parseField(field: []const u8) !i32 {
    const eq = std.mem.findScalar(u8, field, '=') orelse return error.BadFormat;
    return std.fmt.parseInt(i32, field[eq + 1 ..], 10);
}

fn parsePoint(line: []const u8) !Point {
    var fields = std.mem.splitSequence(u8, line, ", ");
    const xf = fields.next() orelse return error.BadFormat;
    const yf = fields.next() orelse return error.BadFormat;
    return .{
        .x = try parseField(xf),
        .y = try parseField(yf),
    };
}

test "tokenize vs split on the same input" {
    const csv = "a,,b,c,";
    try expectEqual(@as(usize, 3), countTokens(csv, ','));
    try expectEqual(@as(usize, 5), countFields(csv, ','));

    try expectEqual(@as(usize, 0), countTokens("", ','));
    try expectEqual(@as(usize, 1), countFields("", ','));

    try expectEqual(@as(usize, 2), countTokens("a   b", ' '));
    try expectEqual(@as(usize, 4), countFields("a   b", ' '));
}

test "sumLine" {
    try expectEqual(@as(i64, 12), try sumLine("10 -3 5"));
    try expectEqual(@as(i64, 0), try sumLine(""));
    try expectEqual(@as(i64, 6), try sumLine("  1  2   3 "));
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
