//! 01 — Structs
//!
//! Concepts: defining structs, field defaults, init literals `.{ .x = 1 }`,
//! anonymous struct literals, nested structs, value (copy) semantics, @This().
//!
//! Run: zig test 01_structs.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#struct

const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

// A struct is a type: a named bag of fields. You address fields by name;
// the compiler is free to reorder them in memory (more on that in the
// README gotchas).
const Point = struct {
    x: f64,
    y: f64,
};

// You instantiate a struct with an "init literal". Two spellings:
//
//   const p = Point{ .x = 1, .y = 2 };    // type spelled out
//   const q: Point = .{ .x = 1, .y = 2 }; // anonymous literal, type inferred
//
// The second form (`.{ ... }`) is an *anonymous struct literal*: it coerces
// to whatever struct type the context expects — a typed constant, a function
// argument, a return value. You will see `.{}` everywhere in Zig.

// TODO: return a Point built from x and y using an init literal.
fn makePoint(x: f64, y: f64) Point {
    _ = x; // TODO: remove
    _ = y; // TODO: remove
    return .{ .x = 0, .y = 0 };
}

test "init literals" {
    const p = makePoint(3, -4);
    try expectEqual(@as(f64, 3), p.x);
    try expectEqual(@as(f64, -4), p.y);

    // An anonymous literal coercing to Point: the annotation provides the
    // type, so `.{ ... }` is enough.
    const q: Point = .{ .x = 1, .y = 1 };
    try expectEqual(@as(f64, 1), q.x);
}

// Fields can carry default values. A field with a default may be omitted
// from the init literal; a field without one MUST be given, or the compiler
// complains about a missing field.
const Config = struct {
    // TODO: give these fields their real defaults:
    //   width 80, height 24, title "untitled"
    // (The placeholders below are deliberately wrong.)
    width: u32 = 0,
    height: u32 = 0,
    title: []const u8 = "?",
};

test "field defaults" {
    const c = Config{}; // every field falls back to its default
    try expectEqual(@as(u32, 80), c.width);
    try expectEqual(@as(u32, 24), c.height);
    try expectEqualStrings("untitled", c.title);

    // Override one field; the others keep their defaults.
    const tall: Config = .{ .height = 50 };
    try expectEqual(@as(u32, 80), tall.width);
    try expectEqual(@as(u32, 50), tall.height);
}

// TODO: return the midpoint of a and b: ((a.x + b.x) / 2, (a.y + b.y) / 2).
// Return it as an anonymous literal: `return .{ .x = ..., .y = ... };`
// (the return type gives the literal its type).
fn midpoint(a: Point, b: Point) Point {
    _ = b; // TODO: remove
    return a; // TODO: replace
}

test "midpoint" {
    const m = midpoint(.{ .x = 0, .y = 0 }, .{ .x = 10, .y = 4 });
    try expectEqual(@as(f64, 5), m.x);
    try expectEqual(@as(f64, 2), m.y);
}

// Structs nest: a field can be another struct type.
const Line = struct {
    from: Point,
    to: Point,
};

// TODO: return the length of the line: sqrt(dx^2 + dy^2).
// std.math.hypot(dx, dy) computes exactly that.
fn lineLength(line: Line) f64 {
    _ = line; // TODO: remove
    return 0;
}

test "nested structs" {
    // Nested anonymous literals: each inner `.{ ... }` coerces to the type
    // the surrounding field expects.
    const l: Line = .{
        .from = .{ .x = 1, .y = 2 },
        .to = .{ .x = 4, .y = 6 },
    };
    try expectEqual(@as(f64, 5), lineLength(l)); // 3-4-5 triangle
}

// Structs are VALUES. Assignment copies every field; passing one to a
// function copies it too. There is no hidden reference like in Python or
// Java — if you want sharing, you take a pointer explicitly.
test "structs are values (copies)" {
    const original = Point{ .x = 1, .y = 2 };
    var copy = original; // a full, independent copy
    copy.x = 99;

    // TODO: fix the two expected values below. Mutating `copy` did NOT
    // touch `original` — they are separate values.
    try expectEqual(@as(f64, 0), original.x); // wrong on purpose
    try expectEqual(@as(f64, 0), copy.x); // wrong on purpose
}

// @This() returns the type it is written inside — the idiomatic way for a
// struct to refer to itself. `const Self = @This();` is the conventional
// first declaration of many structs.
const Temperature = struct {
    celsius: f64,

    const Self = @This(); // Self == Temperature

    // A function in the struct's namespace that returns Self is Zig's
    // "constructor" pattern. The next exercise digs into methods proper.
    // TODO: convert fahrenheit to celsius: (f - 32) * 5 / 9.
    fn fromFahrenheit(f: f64) Self {
        _ = f; // TODO: remove
        return .{ .celsius = -1 };
    }
};

test "@This and namespaced constructor" {
    const boiling = Temperature.fromFahrenheit(212);
    try expectEqual(@as(f64, 100), boiling.celsius);
    const freezing = Temperature.fromFahrenheit(32);
    try expectEqual(@as(f64, 0), freezing.celsius);
}
