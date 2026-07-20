//! while + optionals — the iterator protocol (SOLUTION)
//!
//! Run: zig test 03_while_optionals.zig
//! Ref: https://ziglang.org/documentation/0.16.0/#while-with-Optionals

const std = @import("std");

/// Sum every whitespace-separated integer in `text`.
fn sumNumbers(text: []const u8) !i64 {
    var it = std.mem.tokenizeScalar(u8, text, ' ');
    var total: i64 = 0;
    // Two "might not be there"s, each handled by its own tool:
    // - next() returns ?[]const u8: running out of tokens is EXPECTED,
    //   so the while-unwrap absorbs the null and ends the loop;
    // - parseInt returns !i64: a malformed token is FAILURE, so `try`
    //   forwards the error to our caller.
    while (it.next()) |token| {
        total += try std.fmt.parseInt(i64, token, 10);
    }
    return total;
}

/// An iterator that counts n, n-1, ..., 1 and then finishes.
const Countdown = struct {
    current: u32,

    fn init(n: u32) Countdown {
        return .{ .current = n };
    }

    /// Return the current count and step down — or null when finished.
    fn next(self: *Countdown) ?u32 {
        // Once current hits 0 we return null on every call — iterators
        // must stay exhausted, because `while` will happily call next()
        // again if a consumer restarts the loop.
        if (self.current == 0) return null;
        const value = self.current;
        self.current -= 1;
        return value;
    }
};

// ---------------------------------------------------------------- tests ---

test "tokenizeScalar is an iterator" {
    var it = std.mem.tokenizeScalar(u8, "ab  cd", ' ');
    try std.testing.expectEqualStrings("ab", it.next().?);
    try std.testing.expectEqualStrings("cd", it.next().?);
    try std.testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "sumNumbers adds every token" {
    try std.testing.expectEqual(@as(i64, 32), try sumNumbers("3 14 15"));
    try std.testing.expectEqual(@as(i64, 0), try sumNumbers("10 -10"));
    try std.testing.expectEqual(@as(i64, 5), try sumNumbers("  5  "));
}

test "sumNumbers: no tokens is absence, not failure" {
    try std.testing.expectEqual(@as(i64, 0), try sumNumbers(""));
}

test "sumNumbers: a bad token is failure, not absence" {
    try std.testing.expectError(error.InvalidCharacter, sumNumbers("1 two 3"));
}

test "Countdown yields n..1 then null" {
    var it = Countdown.init(3);
    var collected: [8]u32 = undefined;
    var len: usize = 0;
    while (it.next()) |v| {
        collected[len] = v;
        len += 1;
    }
    try std.testing.expectEqualSlices(u32, &.{ 3, 2, 1 }, collected[0..len]);
}

test "Countdown stays exhausted" {
    var it = Countdown.init(1);
    try std.testing.expectEqual(@as(?u32, 1), it.next());
    try std.testing.expectEqual(@as(?u32, null), it.next());
    try std.testing.expectEqual(@as(?u32, null), it.next());

    var zero = Countdown.init(0);
    try std.testing.expectEqual(@as(?u32, null), zero.next());
}
