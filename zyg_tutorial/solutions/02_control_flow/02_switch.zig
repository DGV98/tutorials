//! Solution 02: switch — exhaustive, expression-based dispatch
//! Run: zig test 02_switch.zig

const std = @import("std");

const CharClass = enum { lower, upper, digit, whitespace, other };

/// Classify an ASCII byte.
fn classify(c: u8) CharClass {
    // Ranges are inclusive on both ends; several values share one prong via
    // commas. The else prong keeps the switch exhaustive over all 256 bytes.
    return switch (c) {
        'a'...'z' => .lower,
        'A'...'Z' => .upper,
        '0'...'9' => .digit,
        ' ', '\t', '\n', '\r' => .whitespace,
        else => .other,
    };
}

/// Days in a month (1-based). 0 for invalid month numbers.
fn daysInMonth(month: u8, leap: bool) u8 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        // A prong body is just an expression — so an if-expression fits.
        2 => if (leap) 29 else 28,
        else => 0,
    };
}

/// Letter grade from a 0-100 score.
fn letterGrade(score: u8) u8 {
    return switch (score) {
        90...100 => 'A',
        80...89 => 'B',
        70...79 => 'C',
        60...69 => 'D',
        // Covers 0...59 and anything out of range — no gaps allowed.
        else => 'F',
    };
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
