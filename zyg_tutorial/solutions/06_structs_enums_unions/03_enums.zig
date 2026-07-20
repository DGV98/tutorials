//! 03 — Enums (solution)
//!
//! Concepts: enum declaration, methods on enums, @intFromEnum/@enumFromInt,
//! explicit tag values, non-exhaustive enums `_`, std.meta.stringToEnum,
//! exhaustive switch, enum literals.
//!
//! Run: zig test 03_enums.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#enum

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const Direction = enum {
    north,
    east,
    south,
    west,

    const Self = @This();

    fn opposite(self: Self) Self {
        return switch (self) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }

    fn isVertical(self: Self) bool {
        return switch (self) {
            .north, .south => true,
            .east, .west => false,
        };
    }
};

test "enum basics and methods" {
    const d: Direction = .north;
    try expectEqual(Direction.south, d.opposite());
    try expectEqual(Direction.west, Direction.east.opposite());
    try expect(Direction.north.isVertical());
    try expect(!Direction.east.isVertical());
}

fn parseDirection(s: []const u8) ?Direction {
    return std.meta.stringToEnum(Direction, s);
}

test "stringToEnum" {
    try expectEqual(@as(?Direction, .north), parseDirection("north"));
    try expectEqual(@as(?Direction, .west), parseDirection("west"));
    try expectEqual(@as(?Direction, null), parseDirection("upward"));
}

test "@tagName" {
    try expectEqualStrings("east", @tagName(Direction.east));
}

const HttpStatus = enum(u16) {
    ok = 200,
    created = 201,
    not_found = 404,
    server_error = 500,

    const Self = @This();

    fn isError(self: Self) bool {
        return @intFromEnum(self) >= 400;
    }
};

test "explicit tag values" {
    try expectEqual(@as(u16, 200), @intFromEnum(HttpStatus.ok));
    try expectEqual(@as(u16, 201), @intFromEnum(HttpStatus.created));
    try expectEqual(@as(u16, 404), @intFromEnum(HttpStatus.not_found));
    try expect(HttpStatus.server_error.isError());
    try expect(HttpStatus.not_found.isError());
    try expect(!HttpStatus.ok.isError());
}

const Opcode = enum(u8) {
    halt = 0x00,
    push = 0x01,
    add = 0x02,
    _,

    const Self = @This();

    fn isKnown(self: Self) bool {
        return switch (self) {
            .halt, .push, .add => true,
            _ => false,
        };
    }
};

test "non-exhaustive enums" {
    const known: Opcode = @enumFromInt(0x01);
    const mystery: Opcode = @enumFromInt(0x77);
    try expectEqual(Opcode.push, known);
    try expect(known.isKnown());
    try expect(!mystery.isKnown());
    try expectEqual(@as(u8, 0x77), @intFromEnum(mystery));
}
