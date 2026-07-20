//! 02 — Methods
//!
//! Concepts: methods as namespaced functions, self: Self vs self: *Self
//! (mutation), dot-call syntax, "static" namespace functions (init pattern),
//! method chaining by returning a pointer.
//!
//! Run: zig test 02_methods.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#struct

const std = @import("std");
const expectEqual = std.testing.expectEqual;

// Zig has no special "method" construct. A method is just a function
// declared inside a type's namespace whose first parameter is that type (or
// a pointer to it). `r.area()` is pure sugar for `Rectangle.area(r)`.
const Rectangle = struct {
    width: f64,
    height: f64,

    const Self = @This();

    // No `self` parameter, so this is not callable on an instance — you
    // call it on the type: `Rectangle.init(3, 4)`. This is Zig's
    // constructor convention (there are no real constructors).
    // TODO: build and return a Self from the arguments.
    fn init(width: f64, height: f64) Self {
        _ = width; // TODO: remove
        _ = height; // TODO: remove
        return .{ .width = 0, .height = 0 };
    }

    // TODO: a square is a rectangle with equal sides. Reuse init.
    fn square(side: f64) Self {
        _ = side; // TODO: remove
        return .{ .width = 0, .height = 0 };
    }

    // `self: Self` receives a COPY of the struct — fine for reading.
    // Parameters are immutable in Zig, so you couldn't even mutate the
    // copy: to change the caller's value you must take a pointer (below).
    // TODO: return width * height.
    fn area(self: Self) f64 {
        _ = self; // TODO: remove
        return 0;
    }

    // TODO: return 2 * (width + height).
    fn perimeter(self: Self) f64 {
        _ = self; // TODO: remove
        return 0;
    }

    // To MUTATE the instance, take `self: *Self`. Calling `r.scale(2)` on a
    // `var r` automatically takes &r for you. Calling it on a `const`
    // rectangle is a compile error — the compiler protects you.
    // TODO: multiply both width and height by factor, in place.
    fn scale(self: *Self, factor: f64) void {
        _ = self; // TODO: remove
        _ = factor; // TODO: remove
    }
};

test "init and dot-call sugar" {
    const r = Rectangle.init(3, 4);
    try expectEqual(@as(f64, 3), r.width);
    try expectEqual(@as(f64, 4), r.height);

    // Two spellings of the exact same call:
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

// Returning `*Self` from a mutating method lets calls chain: each call
// mutates and hands the same pointer to the next call.
const Calculator = struct {
    value: f64 = 0,

    const Self = @This();

    // TODO: add x to value, then return self so calls can chain.
    fn add(self: *Self, x: f64) *Self {
        _ = x; // TODO: remove
        return self;
    }

    // TODO: multiply value by x, then return self.
    fn mul(self: *Self, x: f64) *Self {
        _ = x; // TODO: remove
        return self;
    }

    // TODO: subtract x from value, then return self.
    fn sub(self: *Self, x: f64) *Self {
        _ = x; // TODO: remove
        return self;
    }
};

test "method chaining" {
    var c = Calculator{};
    // Each call returns *Self, so the next call has a receiver. The last
    // returned pointer goes unused, hence the `_ =` discard.
    _ = c.add(2).mul(10).sub(5);
    try expectEqual(@as(f64, 15), c.value);
}
