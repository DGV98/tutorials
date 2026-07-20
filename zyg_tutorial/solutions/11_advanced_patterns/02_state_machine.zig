//! 02 — State Machines
//!
//! Concepts: tagged unions as states with data, pointer capture in switch,
//!           labeled switch with `continue :sw` for character-by-character
//!           parsing
//!
//! Run: zig test 02_state_machine.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Labeled-switch

const std = @import("std");
const testing = std.testing;

// ---------------------------------------------------------------------------
// Part 1: a tagged union IS a state machine.
//
// Each variant is a state; the payload is the data that only exists in that
// state. Transitioning = assigning a new variant. The compiler guarantees
// you can never read yellow-data while in the red state.
// ---------------------------------------------------------------------------

/// A traffic light. The payload of each state is "ticks remaining".
const TrafficLight = union(enum) {
    green: u8,
    yellow: u8,
    red: u8,

    /// One clock tick: decrement the remaining time; when it hits zero,
    /// transition: green -> yellow(2) -> red(4) -> green(3).
    pub fn tick(self: *TrafficLight) void {
        switch (self.*) {
            .green => |*remaining| {
                remaining.* -= 1;
                if (remaining.* == 0) self.* = .{ .yellow = 2 };
            },
            .yellow => |*remaining| {
                remaining.* -= 1;
                if (remaining.* == 0) self.* = .{ .red = 4 };
            },
            .red => |*remaining| {
                remaining.* -= 1;
                if (remaining.* == 0) self.* = .{ .green = 3 };
            },
        }
    }
};

// ---------------------------------------------------------------------------
// Part 2: labeled switch — a state machine as control flow.
//
// `sw: switch (initial_state)` with `continue :sw next_state` re-dispatches
// the switch on a new value. Each arm is a state; each `continue :sw` is a
// transition. This compiles to efficient jumps and reads exactly like a
// state diagram. It is the modern Zig way to write tokenizers and parsers.
// ---------------------------------------------------------------------------

const ParseError = error{
    ExpectedDigit,
    BadOperator,
    EmptyInput,
};

/// Evaluate "12+34-5" left to right, one character at a time.
/// No precedence, no spaces — digits and + or - only.
fn evalExpr(input: []const u8) ParseError!i64 {
    if (input.len == 0) return error.EmptyInput;

    var i: usize = 0;
    var total: i64 = 0; // accumulated result so far
    var current: i64 = 0; // the number being built
    var op: u8 = '+'; // operator to apply when `current` completes

    const State = enum { number_start, number, operator };

    parse: switch (State.number_start) {
        // We are expecting the first digit of a number.
        .number_start => {
            if (i >= input.len) return error.ExpectedDigit; // "1+" ends here
            const c = input[i];
            if (c < '0' or c > '9') return error.ExpectedDigit;
            current = c - '0';
            i += 1;
            continue :parse .number;
        },
        // Inside a number: keep consuming digits.
        .number => {
            if (i >= input.len) {
                // End of input: fold the last number in and stop.
                total = apply(total, op, current);
                break :parse;
            }
            const c = input[i];
            if (c >= '0' and c <= '9') {
                current = current * 10 + (c - '0');
                i += 1;
                continue :parse .number;
            }
            continue :parse .operator;
        },
        // The number ended; the current character must be an operator.
        .operator => {
            total = apply(total, op, current);
            op = input[i];
            if (op != '+' and op != '-') return error.BadOperator;
            i += 1;
            continue :parse .number_start;
        },
    }

    return total;
}

fn apply(acc: i64, op: u8, operand: i64) i64 {
    return switch (op) {
        '+' => acc + operand,
        '-' => acc - operand,
        else => unreachable, // `evalExpr` validates operators before use
    };
}

test "traffic light cycles through states" {
    var light: TrafficLight = .{ .green = 1 };
    light.tick();
    try testing.expectEqual(TrafficLight{ .yellow = 2 }, light);
    light.tick();
    try testing.expectEqual(TrafficLight{ .yellow = 1 }, light);
    light.tick();
    try testing.expectEqual(TrafficLight{ .red = 4 }, light);
    // Four more ticks: red counts down and wraps back to green.
    for (0..4) |_| light.tick();
    try testing.expectEqual(TrafficLight{ .green = 3 }, light);
}

test "single number" {
    try testing.expectEqual(@as(i64, 7), try evalExpr("7"));
    try testing.expectEqual(@as(i64, 123), try evalExpr("123"));
}

test "left-to-right evaluation" {
    try testing.expectEqual(@as(i64, 41), try evalExpr("12+34-5"));
    try testing.expectEqual(@as(i64, 0), try evalExpr("1+2-3"));
    try testing.expectEqual(@as(i64, -8), try evalExpr("2-10"));
}

test "parse errors" {
    try testing.expectError(error.EmptyInput, evalExpr(""));
    try testing.expectError(error.ExpectedDigit, evalExpr("+3"));
    try testing.expectError(error.ExpectedDigit, evalExpr("1+"));
    try testing.expectError(error.ExpectedDigit, evalExpr("1++2"));
    try testing.expectError(error.BadOperator, evalExpr("1*2"));
}
