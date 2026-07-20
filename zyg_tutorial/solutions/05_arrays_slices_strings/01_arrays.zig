//! Exercise 01: Arrays — reference solution
//!
//! Run:  zig test 01_arrays.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Arrays

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn sumArray(arr: [8]u16) u32 {
    var sum: u32 = 0;
    for (arr) |x| sum += x;
    return sum;
}

fn squares() [6]u32 {
    var result: [6]u32 = undefined;
    for (&result, 0..) |*slot, i| {
        const n: u32 = @intCast(i);
        slot.* = n * n;
    }
    return result;
}

fn sameBytes(a: [4]u8, b: [4]u8) bool {
    return std.mem.eql(u8, &a, &b);
}

fn withFirst99(arr: [3]i32) [3]i32 {
    var copy = arr;
    copy[0] = 99;
    return copy;
}

fn diagonalSum(grid: [3][3]i32) i32 {
    var sum: i32 = 0;
    for (grid, 0..) |row, i| sum += row[i];
    return sum;
}

test "initialization shorthands" {
    const primes = [_]i32{ 2, 3, 5, 7, 11 };
    const ruler = [_]u8{ '-', '+' } ** 3; // "-+-+-+"
    const blank: [9]u8 = @splat(' ');

    try expectEqual(@as(usize, 5), primes.len);
    try expectEqual(@as(usize, 6), ruler.len);
    try expectEqual(@as(usize, 9), blank.len);
}

test "sumArray" {
    const data = [8]u16{ 1, 2, 3, 4, 5, 6, 7, 8 };
    try expectEqual(@as(u32, 36), sumArray(data));
    try expectEqual(@as(u32, 800), sumArray(@splat(100)));
}

test "squares" {
    const s = squares();
    try std.testing.expectEqualSlices(u32, &.{ 0, 1, 4, 9, 16, 25 }, &s);
}

test "sameBytes" {
    const a = [4]u8{ 'z', 'i', 'g', '!' };
    const b = [_]u8{ 'z', 'i', 'g', '!' };
    const c = [4]u8{ 'z', 'a', 'g', '!' };
    try expect(sameBytes(a, b));
    try expect(!sameBytes(a, c));
}

test "arrays are values (copied on assignment)" {
    const original = [3]i32{ 1, 2, 3 };
    const changed = withFirst99(original);
    try expectEqual(@as(i32, 1), original[0]);
    try expectEqual(@as(i32, 99), changed[0]);
    try expectEqual(@as(i32, 3), changed[2]);
}

test "diagonalSum" {
    const grid = [3][3]i32{
        .{ 5, 1, 1 },
        .{ 1, 6, 1 },
        .{ 1, 1, 7 },
    };
    try expectEqual(@as(i32, 18), diagonalSum(grid));
}
