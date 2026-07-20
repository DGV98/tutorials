//! Exercise 02: switch — exhaustive, expression-based dispatch
//!
//! Concepts: switch as an expression, multiple values per prong, ranges,
//!           exhaustiveness (no fallthrough), the else prong, capture |v|.
//! Run:      zig test 02_switch.zig
//! Docs:     https://ziglang.org/documentation/0.16.0/#switch

const std = @import("std");

// A Zig switch is an expression and it must be EXHAUSTIVE: every possible
// value of the operand needs a prong, or the code does not compile. There is
// no fallthrough and no `break` between cases — each prong is independent.
//
//     const days: u8 = switch (month) {
//         1, 3, 5, 7, 8, 10, 12 => 31,   // several values, one prong
//         4, 6, 9, 11 => 30,
//         2 => 28,
//         else => 0,                     // covers everything remaining
//     };
//
// Ranges use `...` (three dots, INCLUSIVE on both ends — different from the
// exclusive `0..n` you'll meet in for loops):
//
//     'a'...'z' => true,
//
// A prong can capture the matched value with |v|. On plain integers that is
// rarely needed (you already have the operand), but the same syntax later
// unlocks tagged-union payloads in module 6, so it's worth seeing once:
//
//     else => |v| v * 2,   // v is the matched value

/// A simple enum — module 6 covers enums properly. For now it is just a set
/// of named labels; you write one as `.lower`, `.digit`, etc.
const CharClass = enum { lower, upper, digit, whitespace, other };

/// Classify an ASCII byte:
///   'a'...'z'                  -> .lower
///   'A'...'Z'                  -> .upper
///   '0'...'9'                  -> .digit
///   ' ', '\t', '\n', '\r'      -> .whitespace
///   anything else              -> .other
fn classify(c: u8) CharClass {
    _ = c; // TODO: remove this discard when you use the parameter.
    // TODO: one switch: three range prongs, one multi-value prong, else.
    return .whitespace; // wrong on purpose — replace it
}

/// Days in a month of the Gregorian calendar. `month` is 1-based
/// (1 = January). February depends on `leap`. Return 0 for an invalid
/// month number (0, 13, 14, ...).
fn daysInMonth(month: u8, leap: bool) u8 {
    _ = month; // TODO: remove these discards when implementing.
    _ = leap;
    // TODO: switch on month. Group the 31-day months into one prong and the
    // 30-day months into another. A prong body can itself be an
    // if-expression — handy for February.
    return 99;
}

/// Letter grade from a 0-100 score:
///   90...100 -> 'A', 80...89 -> 'B', 70...79 -> 'C', 60...69 -> 'D',
///   everything else (0...59, and any out-of-range u8) -> 'F'.
fn letterGrade(score: u8) u8 {
    _ = score; // TODO: remove this discard when you use the parameter.
    // TODO: range prongs + else. Note the switch itself is the expression
    // you return — no temporary variable needed.
    return '?';
}

test "classify letters and digits" {
    try std.testing.expectEqual(CharClass.lower, classify('q'));
    try std.testing.expectEqual(CharClass.lower, classify('a'));
    try std.testing.expectEqual(CharClass.upper, classify('Z'));
    try std.testing.expectEqual(CharClass.digit, classify('0'));
    try std.testing.expectEqual(CharClass.digit, classify('9'));
}

test "classify whitespace and other" {
    try std.testing.expectEqual(CharClass.whitespace, classify(' '));
    try std.testing.expectEqual(CharClass.whitespace, classify('\t'));
    try std.testing.expectEqual(CharClass.whitespace, classify('\n'));
    try std.testing.expectEqual(CharClass.other, classify('!'));
    try std.testing.expectEqual(CharClass.other, classify('_'));
}

test "daysInMonth" {
    try std.testing.expectEqual(31, daysInMonth(1, false));
    try std.testing.expectEqual(31, daysInMonth(12, true));
    try std.testing.expectEqual(30, daysInMonth(4, false));
    try std.testing.expectEqual(30, daysInMonth(11, false));
    try std.testing.expectEqual(28, daysInMonth(2, false));
    try std.testing.expectEqual(29, daysInMonth(2, true));
    try std.testing.expectEqual(0, daysInMonth(0, false));
    try std.testing.expectEqual(0, daysInMonth(13, true));
}

test "letterGrade" {
    try std.testing.expectEqual('A', letterGrade(100));
    try std.testing.expectEqual('A', letterGrade(90));
    try std.testing.expectEqual('B', letterGrade(89));
    try std.testing.expectEqual('C', letterGrade(74));
    try std.testing.expectEqual('D', letterGrade(60));
    try std.testing.expectEqual('F', letterGrade(59));
    try std.testing.expectEqual('F', letterGrade(0));
    try std.testing.expectEqual('F', letterGrade(255));
}
