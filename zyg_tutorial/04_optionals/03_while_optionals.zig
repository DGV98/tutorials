//! while + optionals — the iterator protocol
//!
//! Concepts: `while (it.next()) |v|` loop-until-null, std.mem.tokenizeScalar
//! as a real iterator, writing your own iterator, mixing optionals (absence)
//! with error unions (failure) in one function.
//!
//! Run: zig test 03_while_optionals.zig
//! Ref: https://ziglang.org/documentation/0.16.0/#while-with-Optionals

const std = @import("std");

// `while` can unwrap just like `if` — and it re-evaluates the condition
// every iteration. So this:
//
//     while (it.next()) |item| { ... }
//
// calls next(), unwraps the payload into `item`, runs the body, and repeats
// until next() returns null. That is Zig's ENTIRE iterator story. There is
// no Iterator interface or trait — just a convention: any struct with a
// `next()` method returning ?T is an iterator, and null means done. The std
// library uses it everywhere (tokenizers, HashMap iterators, args), and in
// this file you'll consume one and then build one.

/// Sum every whitespace-separated integer in `text`.
///   sumNumbers("3 14 15") == 32
/// Absence and failure meet here, and each keeps its own type:
///   - the tokenizer's next() returns ?[]const u8 — running out of tokens
///     is EXPECTED, so it's an optional, and the while loop absorbs it;
///   - parseInt returns !i64 — a token like "abc" is FAILURE, so it's an
///     error, and `try` passes it to our caller.
fn sumNumbers(text: []const u8) !i64 {
    // TODO:
    //   var it = std.mem.tokenizeScalar(u8, text, ' ');
    //   loop with `while (it.next()) |token|`, adding
    //   `try std.fmt.parseInt(i64, token, 10)` to a running total.
    // tokenizeScalar skips empty tokens, so doubled spaces are harmless.
    _ = text; // TODO: remove this discard once you use the parameter
    return 0;
}

/// An iterator that counts n, n-1, ..., 1 and then finishes.
/// Usage:
///     var it = Countdown.init(3);
///     while (it.next()) |v| ... // yields 3, 2, 1
const Countdown = struct {
    current: u32,

    fn init(n: u32) Countdown {
        return .{ .current = n };
    }

    /// Return the current count and step down — or null when finished.
    /// Once exhausted, every further call must keep returning null; loops
    /// rely on "null means done, forever", not "null means done, once".
    fn next(self: *Countdown) ?u32 {
        // TODO: if self.current is 0, return null. Otherwise remember
        // self.current, decrement it, and return the remembered value.
        // (Why *Countdown and not Countdown? next() must mutate the
        // iterator's state — a copy would forget its progress.)
        _ = self; // TODO: remove this discard once you use the parameter
        return null;
    }
};

// ---------------------------------------------------------------- tests ---

test "tokenizeScalar is an iterator" {
    // Passing test, no TODO: watch the protocol by hand, one call at a time.
    var it = std.mem.tokenizeScalar(u8, "ab  cd", ' ');
    try std.testing.expectEqualStrings("ab", it.next().?);
    try std.testing.expectEqualStrings("cd", it.next().?); // empty token skipped
    try std.testing.expectEqual(@as(?[]const u8, null), it.next()); // done
}

test "sumNumbers adds every token" {
    try std.testing.expectEqual(@as(i64, 32), try sumNumbers("3 14 15"));
    try std.testing.expectEqual(@as(i64, 0), try sumNumbers("10 -10"));
    try std.testing.expectEqual(@as(i64, 5), try sumNumbers("  5  ")); // stray spaces
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
    try std.testing.expectEqual(@as(?u32, null), it.next()); // still null

    var zero = Countdown.init(0);
    try std.testing.expectEqual(@as(?u32, null), zero.next()); // empty from the start
}
