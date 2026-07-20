//! 05 — Shapes (capstone, solution)
//!
//! Concepts: everything in this module together — structs as payloads, a
//! tagged union with methods, exhaustive switches with |v| and |*v|
//! captures, formatting into a buffer with std.fmt.bufPrint, and a function
//! over a slice of union values.
//!
//! Run: zig test 05_shapes.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#union

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const approxEq = std.math.approxEqAbs;

const Circle = struct { radius: f64 };
const Rectangle = struct { width: f64, height: f64 };
const Triangle = struct { a: f64, b: f64, c: f64 };

const Shape = union(enum) {
    circle: Circle,
    rectangle: Rectangle,
    triangle: Triangle,

    const Self = @This();

    fn area(self: Self) f64 {
        return switch (self) {
            .circle => |c| std.math.pi * c.radius * c.radius,
            .rectangle => |r| r.width * r.height,
            .triangle => |t| blk: {
                const s = (t.a + t.b + t.c) / 2;
                break :blk @sqrt(s * (s - t.a) * (s - t.b) * (s - t.c));
            },
        };
    }

    fn perimeter(self: Self) f64 {
        return switch (self) {
            .circle => |c| 2 * std.math.pi * c.radius,
            .rectangle => |r| 2 * (r.width + r.height),
            .triangle => |t| t.a + t.b + t.c,
        };
    }

    fn scale(self: *Self, factor: f64) void {
        switch (self.*) {
            .circle => |*c| c.radius *= factor,
            .rectangle => |*r| {
                r.width *= factor;
                r.height *= factor;
            },
            .triangle => |*t| {
                t.a *= factor;
                t.b *= factor;
                t.c *= factor;
            },
        }
    }

    fn describe(self: Self, buf: []u8) ![]u8 {
        return std.fmt.bufPrint(buf, "{s}: area={d:.2}, perimeter={d:.2}", .{
            @tagName(self),
            self.area(),
            self.perimeter(),
        });
    }
};

fn totalArea(shapes: []const Shape) f64 {
    var total: f64 = 0;
    for (shapes) |shape| total += shape.area();
    return total;
}

test "area" {
    const c = Shape{ .circle = .{ .radius = 2 } };
    const r = Shape{ .rectangle = .{ .width = 3, .height = 4 } };
    const t = Shape{ .triangle = .{ .a = 3, .b = 4, .c = 5 } };
    try expect(approxEq(f64, 4 * std.math.pi, c.area(), 1e-9));
    try expectEqual(@as(f64, 12), r.area());
    try expect(approxEq(f64, 6, t.area(), 1e-9));
}

test "perimeter" {
    const c = Shape{ .circle = .{ .radius = 2 } };
    const r = Shape{ .rectangle = .{ .width = 3, .height = 4 } };
    const t = Shape{ .triangle = .{ .a = 3, .b = 4, .c = 5 } };
    try expect(approxEq(f64, 4 * std.math.pi, c.perimeter(), 1e-9));
    try expectEqual(@as(f64, 14), r.perimeter());
    try expectEqual(@as(f64, 12), t.perimeter());
}

test "scale mutates in place" {
    var s = Shape{ .circle = .{ .radius = 2 } };
    s.scale(3);
    try expectEqual(@as(f64, 6), s.circle.radius);

    var t = Shape{ .triangle = .{ .a = 3, .b = 4, .c = 5 } };
    t.scale(2);
    try expectEqual(@as(f64, 10), t.triangle.c);
    try expect(approxEq(f64, 24, t.area(), 1e-9)); // 6 * 2^2

    var r = Shape{ .rectangle = .{ .width = 1, .height = 2 } };
    r.scale(0.5);
    try expect(approxEq(f64, 1, r.perimeter() / 3, 1e-9));
}

test "describe via bufPrint" {
    var buf: [64]u8 = undefined;

    const r = Shape{ .rectangle = .{ .width = 3, .height = 4 } };
    try expectEqualStrings(
        "rectangle: area=12.00, perimeter=14.00",
        try r.describe(&buf),
    );

    const c = Shape{ .circle = .{ .radius = 5 } };
    try expectEqualStrings(
        "circle: area=78.54, perimeter=31.42",
        try c.describe(&buf),
    );
}

test "totalArea over a mixed slice" {
    const shapes = [_]Shape{
        .{ .circle = .{ .radius = 1 } },
        .{ .rectangle = .{ .width = 2, .height = 3 } },
        .{ .triangle = .{ .a = 3, .b = 4, .c = 5 } },
    };
    try expect(approxEq(f64, std.math.pi + 12, totalArea(&shapes), 1e-9));

    try expectEqual(@as(f64, 0), totalArea(&.{}));
}
