//! 04 — Tagged Unions (solution)
//!
//! Concepts: union(enum), payloads of different types, switch with payload
//! capture |v| and |*v| for in-place mutation, methods on unions, void
//! variants, unions as Zig's sum type.
//!
//! Run: zig test 04_tagged_unions.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Tagged-union

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const Value = union(enum) {
    int: i64,
    float: f64,
    text: []const u8,
    boolean: bool,
    nil,

    const Self = @This();

    fn isNil(self: Self) bool {
        return self == .nil;
    }

    fn truthy(self: Self) bool {
        return switch (self) {
            .nil => false,
            .boolean => |b| b,
            .int => |i| i != 0,
            .float => |f| f != 0,
            .text => |s| s.len != 0,
        };
    }

    fn asFloat(self: Self) ?f64 {
        return switch (self) {
            .int => |i| @as(f64, @floatFromInt(i)),
            .float => |f| f,
            else => null,
        };
    }
};

test "constructing variants and checking tags" {
    const answer = Value{ .int = 42 };
    const greeting: Value = .{ .text = "hi" };
    const nothing: Value = .nil;

    try expectEqual(@as(i64, 42), answer.int);

    try expect(nothing.isNil());
    try expect(!greeting.isNil());

    try expectEqualStrings("text", @tagName(greeting));
}

test "truthy" {
    try expect(Value.truthy(.{ .int = 7 }));
    try expect(!Value.truthy(.{ .int = 0 }));
    try expect(Value.truthy(.{ .text = "x" }));
    try expect(!Value.truthy(.{ .text = "" }));
    try expect(Value.truthy(.{ .boolean = true }));
    try expect(!Value.truthy(.{ .boolean = false }));
    try expect(!Value.truthy(.nil));
}

test "asFloat" {
    try expectEqual(@as(?f64, 42), Value.asFloat(.{ .int = 42 }));
    try expectEqual(@as(?f64, 2.5), Value.asFloat(.{ .float = 2.5 }));
    try expectEqual(@as(?f64, null), Value.asFloat(.{ .text = "3.14" }));
    try expectEqual(@as(?f64, null), Value.asFloat(.{ .boolean = true }));
    try expectEqual(@as(?f64, null), Value.asFloat(.nil));
}

fn double(v: *Value) void {
    switch (v.*) {
        .int => |*i| i.* *= 2,
        .float => |*f| f.* *= 2,
        else => {},
    }
}

test "mutating payloads through |*v|" {
    var v: Value = .{ .int = 21 };
    double(&v);
    try expectEqual(@as(i64, 42), v.int);

    var f: Value = .{ .float = 1.5 };
    double(&f);
    try expectEqual(@as(f64, 3), f.float);

    var t: Value = .{ .text = "hi" };
    double(&t);
    try expectEqualStrings("hi", t.text);

    v = .{ .float = 0.5 };
    double(&v);
    try expectEqual(@as(f64, 1), v.float);
}
