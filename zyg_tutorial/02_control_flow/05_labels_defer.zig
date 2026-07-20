//! Exercise 05: labels and defer — escaping nested scopes, cleanup order
//!
//! Concepts: labeled blocks `blk: { break :blk v; }`, labeled loops with
//!           break/continue to an outer loop, defer semantics and LIFO order.
//! Run:      zig test 05_labels_defer.zig
//! Docs:     https://ziglang.org/documentation/0.16.0/#Blocks
//!           https://ziglang.org/documentation/0.16.0/#Labeled-for
//!           https://ziglang.org/documentation/0.16.0/#defer

const std = @import("std");

// LABELED BLOCKS. Any block can carry a label, and `break :label value`
// exits the block with that value — this turns a block into an expression.
// It's how Zig writes "compute this in a few statements, then use it":
//
//     const x = blk: {
//         var t: i32 = 1;
//         t *= 10;
//         break :blk t + 5;
//     }; // x == 15
//
// LABELED LOOPS. Plain break/continue only reach the innermost loop. Label
// the outer loop and you can break out of (or continue) it from deep inside:
//
//     outer: for (rows) |row| {
//         for (row) |cell| {
//             if (bad(cell)) continue :outer; // next row, now
//             if (done(cell)) break :outer;   // leave both loops
//         }
//     }
//
// A labeled loop used as an expression combines both ideas:
// `break :outer value` supplies the value, the loop's `else` supplies it
// when nothing broke.
//
// DEFER. `defer stmt;` schedules stmt to run when control leaves the
// CURRENT SCOPE — by falling off the end, by return, by break, even midway
// through an error path. Multiple defers run in REVERSE order (LIFO), which
// is exactly right for cleanup: last acquired, first released.

/// Appends one byte to buf and bumps len. Provided for you — `len: *usize`
/// is a pointer so the function can move the caller's cursor (pointers get
/// full coverage in module 7).
fn push(buf: []u8, len: *usize, c: u8) void {
    buf[len.*] = c;
    len.* += 1;
}

/// Find the first occurrence of target in a 2D grid, scanning rows top to
/// bottom and each row left to right. Return .{ row, col }, or null if the
/// grid doesn't contain target.
/// `grid` is a slice of rows; each row is a slice of bytes (a string).
fn findFirst(grid: []const []const u8, target: u8) ?[2]usize {
    _ = grid; // TODO: remove these discards when implementing.
    _ = target;
    // TODO: two nested `for (..., 0..)` loops. Break out of BOTH with the
    // coordinates using a labeled break: `break :outer .{ r, c }`. Written
    // as a loop-expression with `else null`, the whole body is one return.
    return null;
}

/// Count the rows that do NOT contain the byte `bad` anywhere.
fn countCleanRows(grid: []const []const u8, bad: u8) usize {
    _ = grid; // TODO: remove these discards when implementing.
    _ = bad;
    // TODO: scan each row; on the first bad byte, `continue :outer` to skip
    // straight to the next row. Only rows that survive the inner loop get
    // counted. (An inner loop-else also works — pick whichever reads best.)
    return 999_999;
}

/// Demonstrate defer's LIFO order. Call push(buf, len, ...) exactly four
/// times — with the bytes 'A', 'B', 'C', 'D', each used once. Two calls run
/// immediately; two are scheduled with `defer`. Arrange them so the buffer
/// ends up reading "ADCB".
/// Hint: work backwards — whatever must land LAST must be deferred FIRST.
fn deferSequence(buf: []u8, len: *usize) void {
    _ = buf; // TODO: remove these discards when implementing.
    _ = len;
    // TODO: four push calls, two of them behind `defer`.
}

test "findFirst locates the first occurrence" {
    const grid = [_][]const u8{
        "..#..",
        ".....",
        "#..#.",
    };
    try std.testing.expectEqual(@as(?[2]usize, .{ 0, 2 }), findFirst(&grid, '#'));
    try std.testing.expectEqual(@as(?[2]usize, .{ 0, 0 }), findFirst(&grid, '.'));
}

test "findFirst scans row-major (row 2 before column 4)" {
    const grid = [_][]const u8{
        ".....",
        ".....",
        "@....",
    };
    try std.testing.expectEqual(@as(?[2]usize, .{ 2, 0 }), findFirst(&grid, '@'));
}

test "findFirst returns null when absent" {
    const grid = [_][]const u8{ "abc", "def" };
    try std.testing.expectEqual(@as(?[2]usize, null), findFirst(&grid, 'z'));
}

test "countCleanRows" {
    const grid = [_][]const u8{
        "..x..",
        ".....",
        "x....",
        ".....",
    };
    try std.testing.expectEqual(2, countCleanRows(&grid, 'x'));
    try std.testing.expectEqual(4, countCleanRows(&grid, 'q'));
    try std.testing.expectEqual(0, countCleanRows(&grid, '.'));
}

test "deferSequence produces ADCB" {
    var buf: [8]u8 = undefined;
    var len: usize = 0;
    deferSequence(&buf, &len);
    try std.testing.expectEqualStrings("ADCB", buf[0..len]);
}
