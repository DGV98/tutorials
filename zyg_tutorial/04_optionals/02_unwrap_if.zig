//! Unwrapping with if — payload capture, expression form, |*v| mutation
//!
//! Concepts: `if (opt) |v| {} else {}`, if as an expression,
//! capturing a pointer with |*v| to mutate through the optional.
//!
//! Run: zig test 02_unwrap_if.zig
//! Ref: https://ziglang.org/documentation/0.16.0/#if

const std = @import("std");

// `if (opt) |v|` unwraps: inside the block, v is the plain payload (i32, not
// ?i32). The else branch runs when opt is null — and v does not exist there,
// so it is impossible to use a value that isn't present. That scoping is the
// whole safety story: the compiler draws the line C programmers had to keep
// in their heads.
//
// Like everything in Zig, `if` is also an expression, so an unwrap can
// produce a value directly:
//
//     const doubled = if (opt) |v| v * 2 else 0;
//
// Mutation is the one wrinkle. `|v|` gives you a COPY of the payload —
// assigning to it wouldn't change the optional (and v is const, so it won't
// even compile). To change the value inside the optional, capture a pointer
// to the payload with `|*v|` and write through it:
//
//     if (opt) |*v| v.* += 1;

/// Describe an optional i32 in words:
///   null         -> "nothing"
///   v < 0        -> "negative"
///   v == 0       -> "zero"
///   v > 0        -> "positive"
fn describe(opt: ?i32) []const u8 {
    // TODO: unwrap with `if (opt) |v|`, then classify v. Both the
    // statement form and the expression form work — try the expression
    // form: `return if (opt) |v| ... else "nothing";`
    _ = opt; // TODO: remove this discard once you use the parameter
    return "";
}

/// Double the value inside `*opt` if there is one; leave null untouched.
/// Note the parameter: a POINTER to an optional. The caller keeps ownership
/// of the ?i32; we reach in and modify it in place.
fn doubleIfPresent(opt: *?i32) void {
    // TODO: unwrap the pointee with `if (opt.*) |*v|` and double through
    // the pointer: `v.* *= 2;`. If it's null there is nothing to do —
    // no else branch needed.
    _ = opt; // TODO: remove this discard once you use the parameter
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

    // Doubling twice keeps working on the same storage:
    doubleIfPresent(&opt);
    try std.testing.expectEqual(@as(?i32, 84), opt);
}

test "doubleIfPresent leaves null alone" {
    var opt: ?i32 = null;
    doubleIfPresent(&opt);
    try std.testing.expectEqual(@as(?i32, null), opt);
}

test "capture is a copy — |*v| is what writes back" {
    // Passing test, no TODO: proof of the copy semantics described above.
    var opt: ?i32 = 5;
    if (opt) |v| {
        // v is an independent i32 copy. We can't assign to it (it's const),
        // and even a mutable copy would not affect `opt`:
        var copy = v;
        copy += 100;
        try std.testing.expectEqual(@as(i32, 105), copy);
    }
    try std.testing.expectEqual(@as(?i32, 5), opt); // unchanged

    if (opt) |*v| v.* += 100; // the pointer capture DOES write back
    try std.testing.expectEqual(@as(?i32, 105), opt);
}
