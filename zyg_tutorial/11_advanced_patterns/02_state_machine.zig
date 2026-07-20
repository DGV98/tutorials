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
        // TODO: switch on self.* and capture each payload BY POINTER
        // (`.green => |*remaining|`) so you can decrement it in place.
        // When the payload reaches 0, assign the next state to self.*,
        // e.g. self.* = .{ .yellow = 2 };
        _ = self; // TODO: remove this line when you use `self`
    }
};

// ---------------------------------------------------------------------------
// Part 2: labeled switch — a state machine as control flow.
//
// `sw: switch (initial_state)` with `continue :sw next_state` re-dispatches
// the switch on a new value. Each arm is a state; each `continue :sw` is a
// transition. This compiles to efficient jumps and reads exactly like a
// state diagram. It is the modern Zig way to write tokenizers and parsers.
//
// The skeleton you want:
//
//     const State = enum { number_start, number, operator };
//     parse: switch (State.number_start) {
//         .number_start => { ... continue :parse .number; },
//         .number       => { ... break :parse; /* or continue */ },
//         .operator     => { ... continue :parse .number_start; },
//     }
// ---------------------------------------------------------------------------

const ParseError = error{
    ExpectedDigit,
    BadOperator,
    EmptyInput,
};

/// Evaluate "12+34-5" left to right, one character at a time.
/// No precedence, no spaces — digits and + or - only.
///
/// Keep four mutable locals: an index into input, the running total, the
/// number currently being built, and the pending operator (start it at '+'
/// so the first number is "added to zero").
///
/// States:
///   .number_start — must see a digit (else error.ExpectedDigit; also
///                   hit when input ends right after an operator);
///                   start `current` with it, go to .number
///   .number       — more digits extend `current` (current * 10 + digit);
///                   end of input folds `current` into the total and breaks;
///                   anything else goes to .operator
///   .operator     — fold `current` into the total with the pending op,
///                   record the new operator ('+'/'-' or error.BadOperator),
///                   go back to .number_start
fn evalExpr(input: []const u8) ParseError!i64 {
    // TODO: implement the labeled-switch state machine described above.
    // The provided apply() helper folds one operand into the total.
    _ = input; // TODO: remove this line when you use `input`
    return 0;
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
