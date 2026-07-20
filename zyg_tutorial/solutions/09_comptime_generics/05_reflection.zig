//! Reflection: @typeInfo, inline for over fields, @field — SOLUTION
//!
//! Concepts: @typeInfo(T).@"struct".fields (and std.meta.fields), iterating
//! struct fields with inline for, @field access by comptime string, writing
//! functions that work on ANY struct — the mechanism behind std.json.
//!
//! Run: zig test 05_reflection.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#typeInfo

const std = @import("std");

/// Sums every integer field of any struct, ignoring non-integer fields.
fn sumIntFields(value: anytype) i64 {
    var total: i64 = 0;
    inline for (std.meta.fields(@TypeOf(value))) |f| {
        if (@typeInfo(f.type) == .int) {
            total += @intCast(@field(value, f.name));
        }
    }
    return total;
}

/// Counts how many fields of struct T have exactly the type Needle.
fn countFieldsOfType(comptime T: type, comptime Needle: type) usize {
    var total: usize = 0;
    inline for (std.meta.fields(T)) |f| {
        if (f.type == Needle) total += 1;
    }
    return total;
}

/// Compares two values of the same type, field by field (a small
/// std.meta.eql — the real one also handles arrays, unions, optionals).
fn genericEql(a: anytype, b: @TypeOf(a)) bool {
    switch (@typeInfo(@TypeOf(a))) {
        .@"struct" => |info| {
            inline for (info.fields) |f| {
                if (!genericEql(@field(a, f.name), @field(b, f.name)))
                    return false;
            }
            return true;
        },
        else => return a == b,
    }
}

/// Adds 1 to every integer field of the struct behind the pointer, in place.
fn bumpIntFields(ptr: anytype) void {
    inline for (std.meta.fields(@TypeOf(ptr.*))) |f| {
        if (@typeInfo(f.type) == .int) {
            // @field on a struct pointer auto-derefs, and the result is an
            // assignable lvalue — reflection can write, not just read.
            @field(ptr, f.name) += 1;
        }
    }
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
