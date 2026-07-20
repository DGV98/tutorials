//! Unwrapping with if — payload capture, expression form, |*v| mutation (SOLUTION)
//!
//! Run: zig test 02_unwrap_if.zig
//! Ref: https://ziglang.org/documentation/0.16.0/#if

const std = @import("std");

/// Describe an optional i32 in words.
fn describe(opt: ?i32) []const u8 {
    // The expression form: the whole if-else chain produces one value.
    // Inside `|v|`, v is a plain i32 — the null case is already excluded,
    // so the inner comparisons need no further checks.
    return if (opt) |v|
        (if (v < 0) "negative" else if (v == 0) "zero" else "positive")
    else
        "nothing";
}

/// Double the value inside `*opt` if there is one; leave null untouched.
fn doubleIfPresent(opt: *?i32) void {
    // opt.* is the ?i32 itself; |*v| captures a pointer INTO the optional's
    // payload, so writing v.* changes the caller's storage. A plain |v|
    // would hand us a throwaway copy — the classic silent-no-op bug this
    // syntax exists to prevent.
    if (opt.*) |*v| {
        v.* *= 2;
    }
    // null case: nothing to do, so no else branch.
}

// ---------------------------------------------------------------- tests ---

test "describe classifies present values" {
    try std.testing.expectEqualStrings("negative", describe(-5));
    try std.testing.expectEqualStrings("zero", describe(0));
    try std.testing.expectEqualStrings("positive", describe(17));
}

test "describe handles null via the else branch" {
    try std.testing.expectEqualStrings("nothing", describe(null));
}

test "doubleIfPresent mutates in place" {
    var opt: ?i32 = 21;
    doubleIfPresent(&opt);
    try std.testing.expectEqual(@as(?i32, 42), opt);

    doubleIfPresent(&opt);
    try std.testing.expectEqual(@as(?i32, 84), opt);
}

test "doubleIfPresent leaves null alone" {
    var opt: ?i32 = null;
    doubleIfPresent(&opt);
    try std.testing.expectEqual(@as(?i32, null), opt);
}

test "capture is a copy — |*v| is what writes back" {
    var opt: ?i32 = 5;
    if (opt) |v| {
        var copy = v;
        copy += 100;
        try std.testing.expectEqual(@as(i32, 105), copy);
    }
    try std.testing.expectEqual(@as(?i32, 5), opt);

    if (opt) |*v| v.* += 100;
    try std.testing.expectEqual(@as(?i32, 105), opt);
}
