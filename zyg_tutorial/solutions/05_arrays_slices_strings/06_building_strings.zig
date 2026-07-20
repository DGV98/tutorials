//! Exercise 06: Building strings — reference solution
//!
//! Run:  zig test 06_building_strings.zig
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.fmt.bufPrint

const std = @import("std");
const Allocator = std.mem.Allocator;

fn scoreLine(buf: []u8, name: []const u8, score: u32) ![]u8 {
    return std.fmt.bufPrint(buf, "{s}: {d}pts", .{ name, score });
}

fn pointString(alloc: Allocator, x: i32, y: i32) ![]u8 {
    return std.fmt.allocPrint(alloc, "({d}, {d})", .{ x, y });
}

fn commaList(alloc: Allocator, parts: []const []const u8) ![]u8 {
    return std.mem.join(alloc, ", ", parts);
}

fn wrap(alloc: Allocator, prefix: []const u8, body: []const u8, suffix: []const u8) ![]u8 {
    return std.mem.concat(alloc, u8, &.{ prefix, body, suffix });
}

fn shout(alloc: Allocator, s: []const u8) ![]u8 {
    // The manual version. std.ascii.allocUpperString(alloc, s) is the shortcut.
    const out = try alloc.alloc(u8, s.len);
    for (s, out) |c, *o| o.* = std.ascii.toUpper(c);
    return out;
}

fn rollCall(alloc: Allocator, names: []const []const u8) ![]u8 {
    const joined = try std.mem.join(alloc, ", ", names);
    defer alloc.free(joined); // intermediate — freed on every exit path
    return std.fmt.allocPrint(alloc, "{d} elves: {s}", .{ names.len, joined });
}

test "scoreLine" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("ada: 42pts", try scoreLine(&buf, "ada", 42));

    var tiny: [4]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, scoreLine(&tiny, "ada", 42));
}

test "pointString" {
    const alloc = std.testing.allocator;
    const s = try pointString(alloc, 3, -7);
    defer alloc.free(s);
    try std.testing.expectEqualStrings("(3, -7)", s);
}

test "commaList" {
    const alloc = std.testing.allocator;
    const s = try commaList(alloc, &.{ "gold", "silver", "bronze" });
    defer alloc.free(s);
    try std.testing.expectEqualStrings("gold, silver, bronze", s);

    const one = try commaList(alloc, &.{"solo"});
    defer alloc.free(one);
    try std.testing.expectEqualStrings("solo", one);
}

test "wrap" {
    const alloc = std.testing.allocator;
    const s = try wrap(alloc, "<<", "middle", ">>");
    defer alloc.free(s);
    try std.testing.expectEqualStrings("<<middle>>", s);
}

test "shout" {
    const alloc = std.testing.allocator;
    const s = try shout(alloc, "ship it!");
    defer alloc.free(s);
    try std.testing.expectEqualStrings("SHIP IT!", s);
}

test "rollCall" {
    const alloc = std.testing.allocator;
    const s = try rollCall(alloc, &.{ "alice", "bob", "carol" });
    defer alloc.free(s);
    try std.testing.expectEqualStrings("3 elves: alice, bob, carol", s);
}
