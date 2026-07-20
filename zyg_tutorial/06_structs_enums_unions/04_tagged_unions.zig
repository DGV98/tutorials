//! 04 — Tagged Unions
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

// A tagged union holds exactly ONE of its variants at a time, plus a tag
// recording which one. It is a sum type ("one of these"), the complement of
// a struct ("all of these").
//
// Where an OOP language defines an interface plus N implementing classes
// scattered across files, Zig flips it: the set of variants is closed and
// listed in one place, and every operation is a switch over them. Adding a
// variant breaks every switch that doesn't handle it — at compile time.
// That's not an annoyance, it's the feature.
const Value = union(enum) {
    int: i64,
    float: f64,
    text: []const u8,
    boolean: bool,
    nil, // no payload: a "void variant" — just the tag

    const Self = @This();

    // Methods work on unions exactly as on structs.
    // TODO: return true iff self is the nil variant. A tagged union
    // compares to an ENUM LITERAL by tag: `self == .nil`.
    fn isNil(self: Self) bool {
        _ = self; // TODO: remove
        return false;
    }

    // Switch on the union to reach the payload. `|v|` captures the active
    // payload by value; its type differs per branch.
    // TODO (JS-style truthiness):
    //   .nil          -> false
    //   .boolean = b  -> b
    //   .int = i      -> i != 0
    //   .float = f    -> f != 0
    //   .text = s     -> s.len != 0
    fn truthy(self: Self) bool {
        _ = self; // TODO: remove
        return false;
    }

    // TODO: a numeric view of the value.
    //   .int = i   -> the int as f64: @as(f64, @floatFromInt(i))
    //   .float = f -> f
    //   everything else -> null (use an `else` branch here — deliberately:
    //                     "not numeric" is one concept, not three cases)
    fn asFloat(self: Self) ?f64 {
        _ = self; // TODO: remove
        return null;
    }
};

test "constructing variants and checking tags" {
    const answer = Value{ .int = 42 };
    const greeting: Value = .{ .text = "hi" };
    const nothing: Value = .nil; // void variant: no payload to write

    // Reading the active payload directly is fine:
    try expectEqual(@as(i64, 42), answer.int);
    // Reading the WRONG field (e.g. `answer.text`) is illegal behavior —
    // safe builds panic. Switch, or check the tag first.

    try expect(nothing.isNil());
    try expect(!greeting.isNil());

    // @tagName works on tagged unions too — it names the ACTIVE variant.
    // TODO: fix the expected string.
    try expectEqualStrings("???", @tagName(greeting));
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

// To mutate the payload IN PLACE, switch on `ptr.*` and capture with |*v|:
// the capture is then a pointer INTO the union, and writing through it
// changes the stored payload.
// TODO: double numeric payloads in place:
//   .int   -> |*i| i.* *= 2
//   .float -> |*f| f.* *= 2
//   everything else -> leave untouched (`else => {}`)
fn double(v: *Value) void {
    _ = v; // TODO: remove
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

    // Reassigning the whole union switches the active variant:
    v = .{ .float = 0.5 };
    double(&v);
    try expectEqual(@as(f64, 1), v.float);
}
