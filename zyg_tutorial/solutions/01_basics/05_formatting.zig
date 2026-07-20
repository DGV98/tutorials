//! Exercise 05: Formatting with std.fmt — SOLUTION
//!
//! Run: zig test 05_formatting.zig

const std = @import("std");

fn scoreLine(buf: []u8, name: []const u8, score: u32) ![]u8 {
    // bufPrint returns the sub-slice of buf it wrote, or NoSpaceLeft.
    // Returning its result directly propagates both.
    return std.fmt.bufPrint(buf, "{s}: {d}", .{ name, score });
}

fn ticketNumber(buf: []u8, n: u32) ![]u8 {
    // fill '0', right-aligned, minimum width 4.
    return std.fmt.bufPrint(buf, "{d:0>4}", .{n});
}

fn hexColor(buf: []u8, r: u8, g: u8, b: u8) ![]u8 {
    return std.fmt.bufPrint(buf, "#{x:0>2}{x:0>2}{x:0>2}", .{ r, g, b });
}

fn bits(buf: []u8, byte: u8) ![]u8 {
    return std.fmt.bufPrint(buf, "{b:0>8}", .{byte});
}

fn gradeLine(buf: []u8, letter: u8) ![]u8 {
    // {c} treats the u8 as a character; {d} would print 65 for 'A'.
    return std.fmt.bufPrint(buf, "grade: {c}", .{letter});
}

fn describeItems(buf: []u8, xs: []const i32) ![]u8 {
    return std.fmt.bufPrint(buf, "items: {any}", .{xs});
}

fn keyValue(alloc: std.mem.Allocator, key: []const u8, value: i64) ![]u8 {
    // allocPrint measures first, allocates exactly, then formats.
    // Ownership transfers to the caller — the tests free it.
    return std.fmt.allocPrint(alloc, "{s}={d}", .{ key, value });
}

test "scoreLine formats name and score" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("ada: 95", try scoreLine(&buf, "ada", 95));
}

test "scoreLine propagates NoSpaceLeft" {
    var tiny: [2]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, scoreLine(&tiny, "ada", 95));
}

test "ticketNumber zero-pads to 4 digits" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("0042", try ticketNumber(&buf, 42));
    try std.testing.expectEqualStrings("12345", try ticketNumber(&buf, 12345));
}

test "hexColor formats each channel as two hex digits" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("#ff8000", try hexColor(&buf, 255, 128, 0));
    try std.testing.expectEqualStrings("#000000", try hexColor(&buf, 0, 0, 0));
}

test "bits shows all eight binary digits" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("00000101", try bits(&buf, 5));
    try std.testing.expectEqualStrings("11111111", try bits(&buf, 255));
}

test "gradeLine prints the byte as a character" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("grade: A", try gradeLine(&buf, 'A'));
}

test "describeItems debug-prints a slice" {
    var buf: [64]u8 = undefined;
    const xs = [_]i32{ 1, 2, 3 };
    try std.testing.expectEqualStrings("items: { 1, 2, 3 }", try describeItems(&buf, &xs));
}

test "keyValue allocates exactly what it needs" {
    const s = try keyValue(std.testing.allocator, "retries", -1);
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("retries=-1", s);
}
