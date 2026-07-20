//! Exercise 06: Building strings
//!
//! Concepts: std.fmt.bufPrint (format into a fixed buffer, no allocation),
//! std.fmt.allocPrint (allocate exactly enough), std.mem.join,
//! std.mem.concat, uppercasing into a new buffer, freeing what you allocate.
//!
//! Run:  zig test 06_building_strings.zig
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.fmt.bufPrint

const std = @import("std");
const Allocator = std.mem.Allocator;

// std.fmt.bufPrint(buf, fmt, args) formats into a buffer YOU provide and
// returns the slice it actually wrote. No allocator, nothing to free — but
// it returns error.NoSpaceLeft if the buffer is too small.
//
// TODO: format name and score as "<name>: <score>pts", e.g. "ada: 42pts".
// ({s} formats a string, {d} a number.)
fn scoreLine(buf: []u8, name: []const u8, score: u32) ![]u8 {
    _ = buf; // TODO: remove
    _ = name; // TODO: remove
    _ = score; // TODO: remove
    return error.NotImplemented;
}

// std.fmt.allocPrint(alloc, fmt, args) is bufPrint's heap twin: it measures,
// allocates exactly the right amount, and formats. The CALLER owns the
// result and must free it — every test below does `defer alloc.free(...)`,
// and std.testing.allocator fails the test if you leak.
//
// TODO: return "(x, y)", e.g. "(3, -7)".
fn pointString(alloc: Allocator, x: i32, y: i32) ![]u8 {
    _ = alloc; // TODO: remove
    _ = x; // TODO: remove
    _ = y; // TODO: remove
    return error.NotImplemented;
}

// TODO: join the parts with ", " between them. std.mem.join is one call.
fn commaList(alloc: Allocator, parts: []const []const u8) ![]u8 {
    _ = alloc; // TODO: remove
    _ = parts; // TODO: remove
    return error.NotImplemented;
}

// ++ concatenates arrays — but only at COMPTIME. For runtime strings use
// std.mem.concat(alloc, u8, &.{ a, b, c }).
//
// TODO: return prefix ++ body ++ suffix (conceptually), built at runtime.
fn wrap(alloc: Allocator, prefix: []const u8, body: []const u8, suffix: []const u8) ![]u8 {
    _ = alloc; // TODO: remove
    _ = prefix; // TODO: remove
    _ = body; // TODO: remove
    _ = suffix; // TODO: remove
    return error.NotImplemented;
}

// Transforming into a NEW buffer: allocate s.len bytes, then fill them.
// Either alloc.alloc(u8, s.len) + a loop with std.ascii.toUpper, or let
// std.ascii.allocUpperString do both steps. Try the manual way once.
//
// TODO: return a newly allocated uppercase copy of s.
fn shout(alloc: Allocator, s: []const u8) ![]u8 {
    _ = alloc; // TODO: remove
    _ = s; // TODO: remove
    return error.NotImplemented;
}

// Capstone — combine the tools: format a roll call like
//     "3 elves: alice, bob, carol"
// Plan: join the names first, allocPrint the final string, and don't leak
// the intermediate — `defer alloc.free(joined)` after the join.
//
// TODO: implement it.
fn rollCall(alloc: Allocator, names: []const []const u8) ![]u8 {
    _ = alloc; // TODO: remove
    _ = names; // TODO: remove
    return error.NotImplemented;
}

test "scoreLine" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("ada: 42pts", try scoreLine(&buf, "ada", 42));

    // A too-small buffer is an error, not a crash.
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
