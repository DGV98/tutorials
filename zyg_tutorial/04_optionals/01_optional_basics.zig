//! Optional basics — ?T, null, orelse, force-unwrap
//!
//! Concepts: declaring ?T, assigning null, orelse for defaults,
//! `.?` force-unwrap (and why it panics), == null checks.
//!
//! Run: zig test 01_optional_basics.zig
//! Ref: https://ziglang.org/documentation/0.16.0/#Optionals

const std = @import("std");

// `?i32` is "an i32 or null". This is not a pointer trick — for non-pointer
// types Zig stores the payload plus a hidden is-null flag. The win over C's
// NULL: the compiler will not let you use the payload until you have handled
// the null case, so "forgot to check for null" becomes a compile error
// instead of a crash in production.
//
// Getting the value out, from safest to sharpest:
//
//   opt orelse fallback   // unwrap, or use fallback if null
//   if (opt) |v| ...      // next exercise
//   opt.?                 // "I KNOW it's not null" — panics if you're wrong
//
// `.?` panicking is a feature: a loud crash at the exact line of your wrong
// assumption beats a corrupted result far away from the cause. Use it only
// where null is impossible by construction.
//
// Contrast with module 3: an optional means EXPECTED ABSENCE (a search can
// legitimately find nothing), an error union means FAILURE (a job could not
// be done). firstEven below returns ?i32 — a slice with no even numbers is
// not an error, there just isn't one.

/// Return the first even number in `slice`, or null if there is none.
/// (An i32 is even when `@rem(x, 2) == 0` — @rem handles negatives too.)
fn firstEven(slice: []const i32) ?i32 {
    // TODO: loop over `slice` (for (slice) |x| ...) and return the first
    // even element. After the loop, return null — falling off the end of
    // the loop MEANS "nothing found", and the type says exactly that.
    _ = slice; // TODO: remove this discard once you use the parameter
    return null;
}

/// Return the payload of `opt`, or `default` if it is null.
fn valueOrDefault(opt: ?i32, default: i32) i32 {
    // TODO: one line — this is exactly what `orelse` is for.
    _ = opt; // TODO: remove this discard once you use the parameter
    _ = default; // TODO: remove this discard once you use the parameter
    return 0;
}

// ---------------------------------------------------------------- tests ---

test "an optional holds a value or null" {
    // No TODO here — this test already passes. Read it, it's the vocabulary
    // the rest of the module builds on.
    var maybe: ?i32 = null;
    try std.testing.expect(maybe == null);

    maybe = 42; // a plain i32 coerces into ?i32
    try std.testing.expect(maybe != null);
    try std.testing.expectEqual(@as(i32, 42), maybe.?); // safe: we just set it

    // Comparing against a plain value works too: 5 coerces to ?i32, and
    // null compares unequal to any actual value.
    try std.testing.expect(maybe == 42);
    try std.testing.expect(maybe != 7);
}

test "firstEven finds a value" {
    try std.testing.expectEqual(@as(?i32, 4), firstEven(&.{ 1, 3, 4, 6 }));
    try std.testing.expectEqual(@as(?i32, -8), firstEven(&.{ -7, -8, 2 }));
    try std.testing.expectEqual(@as(?i32, 0), firstEven(&.{ 0, 1 })); // 0 is even
}

test "firstEven reports absence with null, not an error" {
    try std.testing.expectEqual(@as(?i32, null), firstEven(&.{ 1, 3, 5 }));
    try std.testing.expectEqual(@as(?i32, null), firstEven(&.{}));
}

test "valueOrDefault unwraps or falls back" {
    try std.testing.expectEqual(@as(i32, 42), valueOrDefault(42, 7));
    try std.testing.expectEqual(@as(i32, 7), valueOrDefault(null, 7));
    // The payload wins even when it equals zero or is negative:
    try std.testing.expectEqual(@as(i32, 0), valueOrDefault(0, 7));
    try std.testing.expectEqual(@as(i32, -3), valueOrDefault(-3, 7));
}

test "orelse chains: first non-null wins" {
    const a: ?i32 = null;
    const b: ?i32 = 10;
    // valueOrDefault(a, ...) as the fallback of another lookup — the same
    // shape as `config orelse env orelse default` in real programs.
    try std.testing.expectEqual(@as(i32, 10), valueOrDefault(a, valueOrDefault(b, 99)));
}
