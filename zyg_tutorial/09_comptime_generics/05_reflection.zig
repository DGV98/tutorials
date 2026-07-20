//! Reflection: @typeInfo, inline for over fields, @field
//!
//! Concepts: @typeInfo(T).@"struct".fields (and std.meta.fields), iterating
//! struct fields with inline for, @field access by comptime string, writing
//! functions that work on ANY struct — the mechanism behind std.json.
//!
//! Run: zig test 05_reflection.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#typeInfo

const std = @import("std");

// @typeInfo(T) returns a std.builtin.Type: a tagged union describing T.
// In 0.16 the variant names are lowercase, and ones that collide with
// keywords are quoted: .int, .float, .pointer, .@"struct", .@"enum",
// .@"union", .@"fn". (Pre-0.15 code you find online says .Int, .Struct —
// translate on sight.)
//
// For a struct, @typeInfo(T).@"struct".fields is a comptime slice of field
// descriptions — each has .name ([:0]const u8), .type, default value,
// alignment. std.meta.fields(T) is the ergonomic shortcut.
//
// The third piece is @field(value, "name"): field access where the field
// name is a comptime STRING. `@field(p, "x")` is exactly `p.x` — but the
// string can come from a fields() entry inside an inline for.
//
// fields() + inline for + @field is how std.json serializes any struct you
// hand it, how std.fmt prints {any}, and how std.meta.eql compares values.
// No codegen step, no runtime reflection tables — the loop unrolls at
// compile time into straight-line field accesses.

/// Sums every integer field of any struct, ignoring non-integer fields.
/// sumIntFields(.{ .x = 3, .y = 4, .name = "p" }) == 7
fn sumIntFields(value: anytype) i64 {
    // TODO:
    //   inline for (std.meta.fields(@TypeOf(value))) |f| { ... }
    //   - keep only fields where @typeInfo(f.type) == .int
    //     (a tagged union compares == against an enum literal)
    //   - add @field(value, f.name) to a running total; @intCast it to fit
    //     the i64 accumulator.
    _ = value; // remove this discard once you use value
    return 0;
}

/// Counts how many fields of struct T have exactly the type Needle.
/// Types are comptime values, so f.type == Needle just works.
fn countFieldsOfType(comptime T: type, comptime Needle: type) usize {
    // TODO: inline for over the fields, count matches.
    _ = T; // remove this discard once you use T
    _ = Needle; // remove this discard once you use Needle
    return 0;
}

/// Compares two values of the same type, field by field:
///   - structs: every field equal (recurse — nested structs should work)
///   - everything else: plain ==
/// This is a small std.meta.eql. Keep it simple: no slices/unions/arrays in
/// the tests. (Real std.meta.eql special-cases pointers, arrays, optionals —
/// slices don't even support ==; it compares them by pointer identity.)
fn genericEql(a: anytype, b: @TypeOf(a)) bool {
    // TODO: switch (@typeInfo(@TypeOf(a))) — for .@"struct", inline for the
    // fields and recurse on each pair via @field; if any differs return
    // false. For the else branch, return a == b.
    // (No discard needed for `a`: the @TypeOf(a) in the signature already
    // counts as a use. `b` still needs one.)
    _ = b; // remove this discard once you use b
    return true;
}

/// Adds 1 to every integer field of the struct behind the pointer, in place.
/// Reflection can WRITE too: @field(ptr, f.name) is an assignable lvalue
/// (pointers to structs auto-deref on field access, @field included).
fn bumpIntFields(ptr: anytype) void {
    // TODO: fields of @TypeOf(ptr.*), inline for, += 1 on the int ones.
    _ = ptr; // remove this discard once you use ptr
}

const Point = struct { x: i32, y: i32 };
const Mixed = struct {
    id: u32,
    score: i16,
    ratio: f32,
    name: []const u8,
    alive: bool,
};
const Nested = struct { pos: Point, hp: u8 };

test "sumIntFields adds only the integer fields" {
    try std.testing.expectEqual(@as(i64, 7), sumIntFields(Point{ .x = 3, .y = 4 }));
    try std.testing.expectEqual(@as(i64, 90), sumIntFields(Mixed{
        .id = 100,
        .score = -10,
        .ratio = 3.14,
        .name = "ignored",
        .alive = true,
    }));
}

test "countFieldsOfType" {
    try std.testing.expectEqual(@as(usize, 2), countFieldsOfType(Point, i32));
    try std.testing.expectEqual(@as(usize, 0), countFieldsOfType(Point, u32));
    try std.testing.expectEqual(@as(usize, 1), countFieldsOfType(Mixed, f32));
    try std.testing.expectEqual(@as(usize, 1), countFieldsOfType(Mixed, []const u8));
}

test "genericEql compares field by field, recursively" {
    const a = Nested{ .pos = .{ .x = 1, .y = 2 }, .hp = 100 };
    const b = Nested{ .pos = .{ .x = 1, .y = 2 }, .hp = 100 };
    const c = Nested{ .pos = .{ .x = 1, .y = 9 }, .hp = 100 };
    try std.testing.expect(genericEql(a, b));
    try std.testing.expect(!genericEql(a, c)); // differs deep in .pos.y
    try std.testing.expect(!genericEql(a, Nested{ .pos = .{ .x = 1, .y = 2 }, .hp = 99 }));
    // Non-struct types take the plain == path:
    try std.testing.expect(genericEql(@as(i32, 5), 5));
    try std.testing.expect(!genericEql(@as(f64, 1.0), 2.0));
}

test "bumpIntFields mutates through reflection" {
    var p = Point{ .x = 10, .y = -1 };
    bumpIntFields(&p);
    try std.testing.expectEqual(@as(i32, 11), p.x);
    try std.testing.expectEqual(@as(i32, 0), p.y);

    var m = Mixed{ .id = 1, .score = 2, .ratio = 0.5, .name = "n", .alive = false };
    bumpIntFields(&m);
    try std.testing.expectEqual(@as(u32, 2), m.id);
    try std.testing.expectEqual(@as(i16, 3), m.score);
    try std.testing.expectEqual(@as(f32, 0.5), m.ratio); // untouched
    try std.testing.expectEqualStrings("n", m.name); // untouched
}
