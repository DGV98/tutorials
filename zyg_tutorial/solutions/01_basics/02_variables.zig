//! Exercise 02: Variables — SOLUTION
//!
//! Run: zig test 02_variables.zig
//!
//! Each fix, in the order the compiler reports them (analysis order may
//! vary, but every one of these was required):
//!   1. incrementedAnswer: `const answer` was reassigned -> make it `var`.
//!   2. perimeter: `note` was never used -> delete the line.
//!   3. double: `var result` never mutated -> make it `const`.
//!   4. timesThree: local `scale` shadowed the file-level `scale`
//!      -> rename the local.

const std = @import("std");

const scale: i32 = 10;

fn incrementedAnswer() i32 {
    // `var` because we mutate it below. Alternative fix with the same
    // observable behavior: `const answer: i32 = 41 + 1;`
    var answer: i32 = 41;
    answer += 1;
    return answer;
}

fn perimeter(width: u32, height: u32) u32 {
    return 2 * (width + height);
}

fn double(x: i32) i32 {
    const result = x * 2;
    return result;
}

fn timesThree(x: i32) i32 {
    // Renamed from `scale` — Zig forbids shadowing the file-level const.
    const factor = 3;
    return x * factor;
}

fn timesTen(x: i32) i32 {
    return x * scale;
}

fn larger(a: i32, b: i32) i32 {
    // This one was already correct: `undefined` is fine because every
    // path assigns before the value is read.
    var result: i32 = undefined;
    if (a > b) {
        result = a;
    } else {
        result = b;
    }
    return result;
}

test "incrementedAnswer returns 42" {
    try std.testing.expectEqual(42, incrementedAnswer());
}

test "perimeter of a 3x4 rectangle" {
    try std.testing.expectEqual(14, perimeter(3, 4));
}

test "double doubles" {
    try std.testing.expectEqual(-10, double(-5));
}

test "timesThree and timesTen use different scales" {
    try std.testing.expectEqual(12, timesThree(4));
    try std.testing.expectEqual(40, timesTen(4));
}

test "larger picks the bigger value" {
    try std.testing.expectEqual(7, larger(7, 3));
    try std.testing.expectEqual(7, larger(3, 7));
}
