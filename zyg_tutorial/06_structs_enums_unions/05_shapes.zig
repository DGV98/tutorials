//! 05 — Shapes (capstone)
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

// The payload structs. Triangle stores its three SIDE lengths.
const Circle = struct { radius: f64 };
const Rectangle = struct { width: f64, height: f64 };
const Triangle = struct { a: f64, b: f64, c: f64 };

// One closed set of shapes, one place to look. Every operation below is an
// exhaustive switch — add a `.hexagon` variant someday and the compiler
// will list every switch you need to extend.
const Shape = union(enum) {
    circle: Circle,
    rectangle: Rectangle,
    triangle: Triangle,

    const Self = @This();

    // TODO: exhaustive switch with |payload| captures.
    //   circle:    pi * r^2                    (std.math.pi)
    //   rectangle: width * height
    //   triangle:  Heron's formula — with s = (a + b + c) / 2,
    //              area = @sqrt(s * (s - a) * (s - b) * (s - c))
    // Hint: a branch can be a block that computes and `break :blk`s a
    // value, or you can call a helper function.
    fn area(self: Self) f64 {
        _ = self; // TODO: remove
        return 0;
    }

    // TODO:
    //   circle:    2 * pi * r
    //   rectangle: 2 * (width + height)
    //   triangle:  a + b + c
    fn perimeter(self: Self) f64 {
        _ = self; // TODO: remove
        return 0;
    }

    // TODO: scale every linear dimension by factor, IN PLACE. Switch on
    // `self.*` and capture each payload with |*c|, |*r|, |*t|.
    // (Area then grows by factor^2 — the test checks that.)
    fn scale(self: *Self, factor: f64) void {
        _ = self; // TODO: remove
        _ = factor; // TODO: remove
    }

    // TODO: format a one-line description into buf and return the slice
    // std.fmt.bufPrint gives you:
    //   "<tag>: area=<a>, perimeter=<p>"   with both numbers as {d:.2}
    // e.g. "rectangle: area=12.00, perimeter=14.00"
    // @tagName(self) provides the tag string. bufPrint can fail with
    // error.NoSpaceLeft, which is why the return type is an error union —
    // just `return std.fmt.bufPrint(...)`.
    fn describe(self: Self, buf: []u8) ![]u8 {
        _ = self; // TODO: remove
        return buf[0..0]; // TODO: replace
    }
};

// TODO: sum the area of every shape in the slice. Note the parameter type:
// []const Shape accepts a slice of ANY shapes — circles, rectangles and
// triangles mixed. This is the payoff of the sum type: heterogeneous data,
// no inheritance, no vtables.
fn totalArea(shapes: []const Shape) f64 {
    _ = shapes; // TODO: remove
    return 0;
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
