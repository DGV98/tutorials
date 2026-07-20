//! 03 — Enums
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

// An enum is a type with a fixed set of named values. Like structs, enums
// are also namespaces: they can hold methods and constants.
const Direction = enum {
    north,
    east,
    south,
    west,

    const Self = @This();

    // A switch over an enum must be EXHAUSTIVE: every value handled, or an
    // `else` branch. Prefer listing all values — then adding a Direction
    // later makes the compiler point at this switch and demand an update.
    // An `else` would silently swallow the new value.
    // TODO: return the opposite direction (north<->south, east<->west)
    // using an exhaustive switch.
    fn opposite(self: Self) Self {
        return self; // TODO: replace
    }

    // TODO: return true for north and south. Hint: one switch branch can
    // match several values: `.north, .south => true,`
    fn isVertical(self: Self) bool {
        _ = self; // TODO: remove
        return false;
    }
};

test "enum basics and methods" {
    // When the expected type is known, write just the "enum literal":
    // `.north` instead of `Direction.north`.
    const d: Direction = .north;
    try expectEqual(Direction.south, d.opposite());
    try expectEqual(Direction.west, Direction.east.opposite());
    try expect(Direction.north.isVertical());
    try expect(!Direction.east.isVertical());
}

// TODO: parse a string into a Direction.
// std.meta.stringToEnum(Direction, s) returns ?Direction and does exactly
// this (it matches against the value names) — use it instead of a chain of
// std.mem.eql calls.
fn parseDirection(s: []const u8) ?Direction {
    _ = s; // TODO: remove
    return null;
}

test "stringToEnum" {
    try expectEqual(@as(?Direction, .north), parseDirection("north"));
    try expectEqual(@as(?Direction, .west), parseDirection("west"));
    try expectEqual(@as(?Direction, null), parseDirection("upward"));
}

test "@tagName" {
    // @tagName is the inverse of stringToEnum: enum value -> name string.
    // (In format strings, `{t}` prints the same thing.)
    // TODO: fix the expected string.
    try expectEqualStrings("???", @tagName(Direction.east));
}

// By default the compiler picks the integer representation. Declare an
// explicit tag type — enum(u16) — and you can pin each value. This is how
// you model protocols, file formats, and C interop.
const HttpStatus = enum(u16) {
    // TODO: give these their real HTTP codes:
    //   ok = 200, created = 201, not_found = 404, server_error = 500
    ok = 0,
    created = 1,
    not_found = 2,
    server_error = 3,

    const Self = @This();

    // TODO: return true when the numeric code is 400 or above.
    // @intFromEnum(self) converts enum -> integer.
    fn isError(self: Self) bool {
        _ = self; // TODO: remove
        return false;
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

// A trailing `_` makes an enum NON-EXHAUSTIVE: every value of the tag type
// is a valid instance, named or not. Perfect for decoding external data
// (bytes off the wire, forward-compatible protocols) without inventing an
// "unknown" sentinel value.
const Opcode = enum(u8) {
    halt = 0x00,
    push = 0x01,
    add = 0x02,
    _,

    const Self = @This();

    // Switching over a non-exhaustive enum uses a `_ =>` branch to catch
    // all UNNAMED values. Unlike `else`, `_` still forces you to handle
    // every named value explicitly — the compiler keeps checking for you.
    // TODO: return true for the named opcodes, false for unnamed ones:
    //   .halt, .push, .add => true,
    //   _ => false,
    fn isKnown(self: Self) bool {
        _ = self; // TODO: remove
        return false;
    }
};

test "non-exhaustive enums" {
    // @enumFromInt converts int -> enum. For a NON-exhaustive enum, any
    // value that fits the tag type is legal. (For an exhaustive enum, a
    // value with no name is illegal behavior — panic in safe builds.)
    const known: Opcode = @enumFromInt(0x01);
    const mystery: Opcode = @enumFromInt(0x77);
    try expectEqual(Opcode.push, known);
    try expect(known.isKnown());
    try expect(!mystery.isKnown());
    try expectEqual(@as(u8, 0x77), @intFromEnum(mystery));
}
