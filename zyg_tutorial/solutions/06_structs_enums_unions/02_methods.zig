//! 02 — Methods (solution)
//!
//! Concepts: methods as namespaced functions, self: Self vs self: *Self
//! (mutation), dot-call syntax, "static" namespace functions (init pattern),
//! method chaining by returning a pointer.
//!
//! Run: zig test 02_methods.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#struct

const std = @import("std");
const expectEqual = std.testing.expectEqual;

const Rectangle = struct {
    width: f64,
    height: f64,

    const Self = @This();

    fn init(width: f64, height: f64) Self {
        return .{ .width = width, .height = height };
    }

    fn square(side: f64) Self {
        return init(side, side);
    }

    fn area(self: Self) f64 {
        return self.width * self.height;
    }

    fn perimeter(self: Self) f64 {
        return 2 * (self.width + self.height);
    }

    fn scale(self: *Self, factor: f64) void {
        self.width *= factor;
        self.height *= factor;
    }
};

test "init and dot-call sugar" {
    const r = Rectangle.init(3, 4);
    try expectEqual(@as(f64, 3), r.width);
    try expectEqual(@as(f64, 4), r.height);

    try expectEqual(@as(f64, 12), r.area());
    try expectEqual(@as(f64, 12), Rectangle.area(r));
}

test "more methods" {
    const r = Rectangle.init(3, 4);
    try expectEqual(@as(f64, 14), r.perimeter());
    try expectEqual(@as(f64, 25), Rectangle.square(5).area());
}

test "mutation needs a pointer" {
    var r = Rectangle.init(2, 3);
    r.scale(2); // sugar for Rectangle.scale(&r, 2)
    try expectEqual(@as(f64, 4), r.width);
    try expectEqual(@as(f64, 6), r.height);
    try expectEqual(@as(f64, 24), r.area());
}

const Calculator = struct {
    value: f64 = 0,

    const Self = @This();

    fn add(self: *Self, x: f64) *Self {
        self.value += x;
        return self;
    }

    fn mul(self: *Self, x: f64) *Self {
        self.value *= x;
        return self;
    }

    fn sub(self: *Self, x: f64) *Self {
        self.value -= x;
        return self;
    }
};

test "method chaining" {
    var c = Calculator{};
    _ = c.add(2).mul(10).sub(5);
    try expectEqual(@as(f64, 15), c.value);
}
