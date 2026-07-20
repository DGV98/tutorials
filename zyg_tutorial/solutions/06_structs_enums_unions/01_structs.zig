//! 01 — Structs (solution)
//!
//! Concepts: defining structs, field defaults, init literals `.{ .x = 1 }`,
//! anonymous struct literals, nested structs, value (copy) semantics, @This().
//!
//! Run: zig test 01_structs.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#struct

const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const Point = struct {
    x: f64,
    y: f64,
};

fn makePoint(x: f64, y: f64) Point {
    return .{ .x = x, .y = y };
}

test "init literals" {
    const p = makePoint(3, -4);
    try expectEqual(@as(f64, 3), p.x);
    try expectEqual(@as(f64, -4), p.y);

    const q: Point = .{ .x = 1, .y = 1 };
    try expectEqual(@as(f64, 1), q.x);
}

const Config = struct {
    width: u32 = 80,
    height: u32 = 24,
    title: []const u8 = "untitled",
};

test "field defaults" {
    const c = Config{};
    try expectEqual(@as(u32, 80), c.width);
    try expectEqual(@as(u32, 24), c.height);
    try expectEqualStrings("untitled", c.title);

    const tall: Config = .{ .height = 50 };
    try expectEqual(@as(u32, 80), tall.width);
    try expectEqual(@as(u32, 50), tall.height);
}

fn midpoint(a: Point, b: Point) Point {
    return .{ .x = (a.x + b.x) / 2, .y = (a.y + b.y) / 2 };
}

test "midpoint" {
    const m = midpoint(.{ .x = 0, .y = 0 }, .{ .x = 10, .y = 4 });
    try expectEqual(@as(f64, 5), m.x);
    try expectEqual(@as(f64, 2), m.y);
}

const Line = struct {
    from: Point,
    to: Point,
};

fn lineLength(line: Line) f64 {
    return std.math.hypot(line.to.x - line.from.x, line.to.y - line.from.y);
}

test "nested structs" {
    const l: Line = .{
        .from = .{ .x = 1, .y = 2 },
        .to = .{ .x = 4, .y = 6 },
    };
    try expectEqual(@as(f64, 5), lineLength(l)); // 3-4-5 triangle
}

test "structs are values (copies)" {
    const original = Point{ .x = 1, .y = 2 };
    var copy = original;
    copy.x = 99;

    // Mutating `copy` did not touch `original` — they are separate values.
    try expectEqual(@as(f64, 1), original.x);
    try expectEqual(@as(f64, 99), copy.x);
}

const Temperature = struct {
    celsius: f64,

    const Self = @This();

    fn fromFahrenheit(f: f64) Self {
        return .{ .celsius = (f - 32) * 5 / 9 };
    }
};

test "@This and namespaced constructor" {
    const boiling = Temperature.fromFahrenheit(212);
    try expectEqual(@as(f64, 100), boiling.celsius);
    const freezing = Temperature.fromFahrenheit(32);
    try expectEqual(@as(f64, 0), freezing.celsius);
}
