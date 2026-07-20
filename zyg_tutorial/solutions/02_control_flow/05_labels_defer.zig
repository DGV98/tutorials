//! Solution 05: labels and defer — escaping nested scopes, cleanup order
//! Run: zig test 05_labels_defer.zig

const std = @import("std");

/// Appends one byte to buf and bumps len (provided helper).
fn push(buf: []u8, len: *usize, c: u8) void {
    buf[len.*] = c;
    len.* += 1;
}

/// First occurrence of target as .{ row, col }, or null.
fn findFirst(grid: []const []const u8, target: u8) ?[2]usize {
    // The labeled outer for is an expression: `break :outer` hands it a
    // value from inside the INNER loop, and the else covers "never broke".
    return outer: for (grid, 0..) |row, r| {
        for (row, 0..) |cell, c| {
            if (cell == target) break :outer .{ r, c };
        }
    } else null;
}

/// Count the rows that do NOT contain the byte `bad` anywhere.
fn countCleanRows(grid: []const []const u8, bad: u8) usize {
    var count: usize = 0;
    outer: for (grid) |row| {
        for (row) |cell| {
            // One bad byte disqualifies the row — skip straight to the
            // next one, jumping over the count below.
            if (cell == bad) continue :outer;
        }
        count += 1;
    }
    return count;
}

/// Produce "ADCB" from four pushes, two of them deferred.
fn deferSequence(buf: []u8, len: *usize) void {
    push(buf, len, 'A'); // runs first
    defer push(buf, len, 'B'); // deferred FIRST, so it runs LAST (LIFO)
    defer push(buf, len, 'C'); // deferred second, runs before B
    push(buf, len, 'D'); // runs second
    // Scope ends here: the defers fire in reverse order — C, then B.
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
