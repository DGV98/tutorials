//! Exercise 04: errdefer
//! Concepts: defer vs errdefer, cleanup on the error path only,
//!           the acquire-two-resources pattern, leak-checked tests
//! Run: zig test 04_errdefer.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#errdefer

const std = @import("std");

// You know `defer` from module 02: run a statement when the scope exits,
// no matter how. `errdefer` is its sibling: run the statement ONLY when the
// scope exits via an error return.
//
//     const res = try acquire();
//     errdefer release(res);     // runs only if a LATER line errors out
//     try somethingThatMayFail();
//     return res;                // success: errdefer does NOT run
//
// Why it exists: on success you usually want to HAND the resource to your
// caller (so no cleanup), but on failure you must not leak it. `defer`
// can't express that — it always runs. `errdefer` is exactly that asymmetry.
//
// Allocators get their own module (07). Today you need three calls:
//   gpa.dupe(u8, s)  -> allocates a copy of slice s; can fail with
//                       error.OutOfMemory
//   gpa.free(buf)    -> releases it
// and in tests: std.testing.allocator, which FAILS THE TEST if anything
// allocated during the test was not freed. A missing errdefer in this file
// shows up as a leak report, not a green run — read those reports.

// TODO: return an UPPERCASED copy of s, but reject any string containing a
// digit with error.HasDigit.
//
// Plan:
//   1. const out = try gpa.dupe(u8, s);
//   2. errdefer ??? — if we bail out below, who frees `out`?
//   3. loop: for (out, 0..) |c, i| — return error.HasDigit on a digit
//      (std.ascii.isDigit), else out[i] = std.ascii.toUpper(c).
//   4. return out; — ownership passes to the caller, nothing is freed.
fn dupeUpperNoDigits(gpa: std.mem.Allocator, s: []const u8) ![]u8 {
    _ = gpa; // delete when implemented
    _ = s;
    return error.NotImplemented;
}

// The classic errdefer pattern: acquire resource A, acquire resource B.
// If B fails, A must be released — otherwise it leaks, because the caller
// only ever sees an error value, never A.
//
// Pair is just a bag with two fields (structs get a full module later).
// Build one with:  return .{ .a = ..., .b = ... };
const Pair = struct {
    a: []u8,
    b: []u8,
};

// TODO: duplicate both input slices and return them as a Pair. If the
// SECOND dupe fails, the first must not leak. That is one errdefer line.
// The tests simulate the failure with std.testing.FailingAllocator: it
// forwards to a real allocator but returns error.OutOfMemory after N
// successes — so `fail_index = 1` makes exactly the second dupe fail.
fn dupePair(gpa: std.mem.Allocator, first: []const u8, second: []const u8) !Pair {
    _ = gpa; // delete when implemented
    _ = first;
    _ = second;
    return error.NotImplemented;
}

test "dupeUpperNoDigits success path" {
    const gpa = std.testing.allocator;
    const out = try dupeUpperNoDigits(gpa, "hello, zig");
    defer gpa.free(out); // caller owns the result -> caller frees
    try std.testing.expectEqualStrings("HELLO, ZIG", out);
}

test "dupeUpperNoDigits rejects digits without leaking" {
    // If you forgot the errdefer, this test fails with a memory-leak
    // report from std.testing.allocator: the copy was allocated, the
    // function returned an error, and nobody could ever free it.
    try std.testing.expectError(
        error.HasDigit,
        dupeUpperNoDigits(std.testing.allocator, "agent 007"),
    );
}

test "dupePair success path" {
    const gpa = std.testing.allocator;
    const pair = try dupePair(gpa, "left", "right");
    defer gpa.free(pair.a);
    defer gpa.free(pair.b);
    try std.testing.expectEqualStrings("left", pair.a);
    try std.testing.expectEqualStrings("right", pair.b);
}

test "dupePair: second allocation fails, first must be freed" {
    // Allocation #0 (first dupe) succeeds, allocation #1 (second dupe)
    // returns error.OutOfMemory. Without errdefer, the first buffer leaks
    // and std.testing.allocator flunks the test at the end.
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    try std.testing.expectError(
        error.OutOfMemory,
        dupePair(failing.allocator(), "left", "right"),
    );
}

test "dupePair: first allocation fails, nothing to clean up" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(
        error.OutOfMemory,
        dupePair(failing.allocator(), "left", "right"),
    );
}
