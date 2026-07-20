//! Exercise 02: Variables — fix the compile errors
//!
//! Concepts: const vs var, explicit types vs inference, unused variables,
//!           never-mutated vars, illegal shadowing, undefined.
//!
//! Run: zig test 02_variables.zig
//!
//! Reference: https://ziglang.org/documentation/0.16.0/#Variables
//!
//! This file does not compile yet — your job is to fix it.
//! Run the tests, read the FIRST error the compiler prints, fix that one
//! line, and run again. Repeat until the tests pass. Do not change the
//! tests — they already describe the correct behavior.

const std = @import("std");

// Declarations come in two flavors:
//   const x: i32 = 5;  // immutable — cannot be reassigned, ever
//   var y: i32 = 5;    // mutable
// The type annotation is optional when the compiler can infer it:
//   const x = 5;       // x is a comptime_int here — more on that in ex. 03
// Rule of thumb: write `const` by default; the compiler will *tell* you
// when something must be `var`.

// A file-level (container-level) constant. These may be left unused —
// only locals and parameters must be used.
const scale: i32 = 10;

// ── Fix 1: reassigning a const ──────────────────────────────────────────
// The compiler will say "cannot assign to constant". Decide: should
// `answer` be a `var`, or should the code be written another way?
fn incrementedAnswer() i32 {
    const answer: i32 = 41;
    answer += 1;
    return answer;
}

// ── Fix 2: an unused local ──────────────────────────────────────────────
// Zig hard-errors on unused locals ("unused local constant"). Dead code
// doesn't get to linger. The fix is almost always: delete it.
fn perimeter(width: u32, height: u32) u32 {
    const note = "remember to test with zero";
    return 2 * (width + height);
}

// ── Fix 3: a var that never mutates ─────────────────────────────────────
// If a `var` is never written to after initialization, the compiler
// demands `const` ("local variable is never mutated"). This keeps
// mutability an honest signal when reading code.
fn double(x: i32) i32 {
    var result = x * 2;
    return result;
}

// ── Fix 4: shadowing is illegal ─────────────────────────────────────────
// In Python or JS an inner `scale` would quietly hide the outer one. Zig
// refuses: "local constant shadows declaration of 'scale'". Rename the
// local (do NOT touch the file-level `scale` — timesTen needs it).
fn timesThree(x: i32) i32 {
    const scale = 3;
    return x * scale;
}

fn timesTen(x: i32) i32 {
    return x * scale;
}

// ── Nothing to fix here: `undefined` ────────────────────────────────────
// `undefined` means "reserve the memory, I promise to write before I
// read". Reading it before assigning is illegal behavior the compiler
// won't always catch — use it sparingly, and only like this: every path
// assigns before the value is read.
fn larger(a: i32, b: i32) i32 {
    var result: i32 = undefined;
    if (a > b) {
        result = a;
    } else {
        result = b;
    }
    return result;
}

// ── The spec ────────────────────────────────────────────────────────────

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
