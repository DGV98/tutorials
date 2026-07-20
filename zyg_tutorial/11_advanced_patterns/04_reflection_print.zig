//! 04 — Comptime Reflection
//!
//! Concepts: @typeInfo, inline for over struct fields, @field access by
//!           name, comptime branching on field types, generic equality
//!
//! Run: zig test 04_reflection_print.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#typeInfo

const std = @import("std");
const testing = std.testing;

// ---------------------------------------------------------------------------
// @typeInfo(T) returns a std.builtin.Type — a tagged union describing T.
// For a struct, `@typeInfo(T).@"struct".fields` is a comptime slice of
// field descriptors (.name, .type, ...). Loop over it with `inline for`
// (the loop is unrolled at compile time, so each iteration can use
// comptime-only values), and read a field by name with @field(value, name).
//
// Note the 0.16 spelling: variant names are lowercase and need @"..."
// quoting where they collide with keywords: .@"struct", .@"enum", .int,
// .float, .pointer, .bool.
// ---------------------------------------------------------------------------

/// Format any struct as `a=1, b=hello, c=true` into `buf`.
/// []const u8 fields print as text; everything else uses {any}.
///
/// Plan: make a fixed writer over buf (`var w: std.Io.Writer = .fixed(buf);`),
/// then `inline for (fields, 0..) |field, i|`:
///   - write ", " before every field but the first
///   - grab the value with @field(value, field.name)
///   - if `comptime isStringType(field.type)`, print with "{s}={s}",
///     otherwise with "{s}={any}"
/// Return w.buffered() — the slice of buf written so far.
fn debugString(value: anytype, buf: []u8) ![]const u8 {
    // TODO: implement as described above.
    _ = value; // TODO: remove this line when you use `value`
    return buf[0..0]; // TODO: return w.buffered() instead
}

/// Provided: is this field type printable as text?
fn isStringType(comptime T: type) bool {
    return T == []const u8 or T == []u8;
}

/// Field-by-field equality for any struct type.
/// (std.meta.eql does exactly this, recursively — this shows the machinery.)
///
/// Plan: inline for over the fields; if std.meta.eql on any pair of
/// @field values says false, return false. Note that returning early from
/// an inline for is fine — it just stops unrolling.
fn structsEqual(a: anytype, b: @TypeOf(a)) bool {
    // TODO: implement. (No discard needed for `a` — it already counts as
    // used because it appears in b's type.)
    _ = b; // TODO: remove this line when you use `b`
    return false;
}

/// Sum every integer field of a struct, ignoring non-integer fields.
///
/// Plan: inline for over the fields, switch on @typeInfo(field.type):
/// on `.int`, add @intCast(@field(value, field.name)) to the total;
/// `else => {}` skips floats, bools, slices, ...
fn sumIntFields(value: anytype) i64 {
    // TODO: implement.
    _ = value; // TODO: remove this line when you use `value`
    return 0;
}

const Point3 = struct { x: i32, y: i32, z: i32 };
const Reindeer = struct { name: []const u8, speed: u32, flying: bool };

test "debugString on a plain struct" {
    var buf: [128]u8 = undefined;
    const s = try debugString(Point3{ .x = 1, .y = -2, .z = 3 }, &buf);
    try testing.expectEqualStrings("x=1, y=-2, z=3", s);
}

test "debugString prints string fields as text" {
    var buf: [128]u8 = undefined;
    const comet: Reindeer = .{ .name = "Comet", .speed = 14, .flying = true };
    const s = try debugString(comet, &buf);
    try testing.expectEqualStrings("name=Comet, speed=14, flying=true", s);
}

test "debugString works for ANY struct — that is the point" {
    var buf: [128]u8 = undefined;
    const Config = struct { verbose: bool, retries: u8 };
    const s = try debugString(Config{ .verbose = false, .retries = 3 }, &buf);
    try testing.expectEqualStrings("verbose=false, retries=3", s);
}

test "structsEqual" {
    const a: Point3 = .{ .x = 1, .y = 2, .z = 3 };
    const b: Point3 = .{ .x = 1, .y = 2, .z = 3 };
    const c: Point3 = .{ .x = 1, .y = 2, .z = 4 };
    try testing.expect(structsEqual(a, b));
    try testing.expect(!structsEqual(a, c));
}

test "structsEqual spots a single differing field" {
    // Note: std.meta.eql compares slice fields by pointer + length, not
    // content. Here both names are the same literal, so only speed differs.
    const a: Reindeer = .{ .name = "Dasher", .speed = 10, .flying = false };
    const b: Reindeer = .{ .name = "Dasher", .speed = 11, .flying = false };
    try testing.expect(!structsEqual(a, b));
}

test "sumIntFields skips non-integer fields" {
    const Mixed = struct { a: u8, b: i32, ratio: f32, on: bool };
    const m: Mixed = .{ .a = 5, .b = -2, .ratio = 3.14, .on = true };
    try testing.expectEqual(@as(i64, 3), sumIntFields(m));
}
