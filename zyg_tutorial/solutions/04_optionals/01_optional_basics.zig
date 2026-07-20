//! Optional basics — ?T, null, orelse, force-unwrap (SOLUTION)
//!
//! Run: zig test 01_optional_basics.zig
//! Ref: https://ziglang.org/documentation/0.16.0/#Optionals

const std = @import("std");

/// Return the first even number in `slice`, or null if there is none.
fn firstEven(slice: []const i32) ?i32 {
    for (slice) |x| {
        if (@rem(x, 2) == 0) return x;
    }
    // Falling off the end of the loop IS the "not found" case. Returning
    // null here — not -1, not 0, not an error — is the point of ?i32: the
    // caller cannot confuse "found 0" with "found nothing", and nothing
    // failed, so an error union would be the wrong tool (module 3).
    return null;
}

/// Return the payload of `opt`, or `default` if it is null.
fn valueOrDefault(opt: ?i32, default: i32) i32 {
    // orelse unwraps or evaluates its right-hand side — exactly this job.
    return opt orelse default;
}

// ---------------------------------------------------------------- tests ---

test "an optional holds a value or null" {
    var maybe: ?i32 = null;
    try std.testing.expect(maybe == null);

    maybe = 42;
    try std.testing.expect(maybe != null);
    try std.testing.expectEqual(@as(i32, 42), maybe.?);

    try std.testing.expect(maybe == 42);
    try std.testing.expect(maybe != 7);
}

test "firstEven finds a value" {
    try std.testing.expectEqual(@as(?i32, 4), firstEven(&.{ 1, 3, 4, 6 }));
    try std.testing.expectEqual(@as(?i32, -8), firstEven(&.{ -7, -8, 2 }));
    try std.testing.expectEqual(@as(?i32, 0), firstEven(&.{ 0, 1 }));
}

test "firstEven reports absence with null, not an error" {
    try std.testing.expectEqual(@as(?i32, null), firstEven(&.{ 1, 3, 5 }));
    try std.testing.expectEqual(@as(?i32, null), firstEven(&.{}));
}

test "valueOrDefault unwraps or falls back" {
    try std.testing.expectEqual(@as(i32, 42), valueOrDefault(42, 7));
    try std.testing.expectEqual(@as(i32, 7), valueOrDefault(null, 7));
    try std.testing.expectEqual(@as(i32, 0), valueOrDefault(0, 7));
    try std.testing.expectEqual(@as(i32, -3), valueOrDefault(-3, 7));
}

test "orelse chains: first non-null wins" {
    const a: ?i32 = null;
    const b: ?i32 = 10;
    try std.testing.expectEqual(@as(i32, 10), valueOrDefault(a, valueOrDefault(b, 99)));
}
