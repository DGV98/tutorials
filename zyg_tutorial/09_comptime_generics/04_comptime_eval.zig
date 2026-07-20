//! Comptime evaluation: tables, strings, inline for, assertions
//!
//! Concepts: comptime blocks and vars, computing lookup tables at compile
//! time, comptime string manipulation with ++, inline for, compile-time
//! assertions with @compileError.
//!
//! Run: zig test 04_comptime_eval.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#comptime

const std = @import("std");

// comptime isn't just for type parameters — you can run arbitrary Zig during
// compilation. Loops, mutation, function calls: same language, different
// time. Classic payoff: compute a table once at build time and ship it as
// constant data in the binary. Zero runtime cost, no codegen script, no
// macro language.

// A top-level comptime block runs while the file compiles. Use it to pin
// down facts your code relies on — the build fails if they drift.
comptime {
    std.debug.assert(@sizeOf(u64) == 8);
}

/// Returns [ 1, 2, 4, 8, ... ] — the first n powers of two.
/// Written as an ordinary function: nothing in the body is comptime-specific,
/// and the SAME code runs at compile time when called in a comptime context
/// (see the test — the result feeds a global-style `const`).
fn powersOfTwo(comptime n: usize) [n]u64 {
    // TODO: fill and return the array. Start a var at 1, double as you go.
    // `var result: [n]u64 = undefined;` then loop `for (&result) |*slot|`.
    return @splat(0); // replace: this fills the array with zeros
}

/// Returns the first n Fibonacci numbers: [ 0, 1, 1, 2, 3, 5, ... ].
fn fibTable(comptime n: usize) [n]u64 {
    // TODO: same shape as powersOfTwo. Watch the first two elements —
    // handle n < 2 (the tests use n >= 2, but don't index out of bounds).
    return @splat(0); // replace
}

/// Repeats s n times at compile time: repeat("ab", 3) == "ababab".
/// Comptime strings concatenate with ++ (and `**` repeats arrays — but
/// build it with a loop here to practice comptime vars).
///
/// GOTCHA: you cannot `return` from inside a `comptime { ... }` statement in
/// a function that's called at runtime. Use a labeled block instead:
///     return comptime blk: {
///         var out: []const u8 = "";
///         ...
///         break :blk out;
///     };
fn repeat(comptime s: []const u8, comptime n: usize) []const u8 {
    // TODO: implement with the labeled-block pattern above.
    _ = s; // remove this discard once you use s
    _ = n; // remove this discard once you use n
    return "";
}

/// Sums @sizeOf every type in the list.
/// A []const type can only be iterated with `inline for`: the loop is
/// unrolled at compile time so each iteration's T is comptime-known. A
/// regular `for` cannot work — its loop variable would have to hold a type
/// at runtime.
fn totalSize(comptime types: []const type) usize {
    // TODO: inline for (types) |T| ... add @sizeOf(T).
    _ = types; // remove this discard once you use types
    return 0;
}

/// Returns log2(n) for a power of two — and REFUSES TO COMPILE otherwise.
/// This is the assertion pattern: validate a comptime argument up front and
/// call @compileError with a message that says what's wrong.
/// Hints:
///   - power of two check: n != 0 and (n & (n - 1)) == 0
///   - format numbers into comptime strings with std.fmt.comptimePrint
///   - std.math.log2 computes the result (cast with @intCast)
fn requirePowerOfTwo(comptime n: u64) u6 {
    // TODO: comptime-check n, @compileError if it fails, else return log2(n).
    _ = n; // remove this discard once you use n
    return 0;
}

test "powers of two, computed at compile time" {
    // `comptime` forces the call to run during compilation; `table` is baked
    // into the binary as constant data. Assigning to a global const outside
    // a function would force comptime evaluation the same way.
    const table = comptime powersOfTwo(10);
    try std.testing.expectEqual(@as(u64, 1), table[0]);
    try std.testing.expectEqual(@as(u64, 8), table[3]);
    try std.testing.expectEqual(@as(u64, 512), table[9]);
}

test "fibonacci table" {
    const fib = comptime fibTable(12);
    try std.testing.expectEqualSlices(
        u64,
        &.{ 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89 },
        &fib,
    );
}

test "comptime string building" {
    try std.testing.expectEqualStrings("ababab", repeat("ab", 3));
    try std.testing.expectEqualStrings("zig", repeat("zig", 1));
    try std.testing.expectEqualStrings("", repeat("anything", 0));
    // Because the result is comptime-known, it can even size an array:
    // const buf: [repeat("ab", 2).len]u8 = undefined;
}

test "inline for over a list of types" {
    try std.testing.expectEqual(@as(usize, 4 + 1 + 8), totalSize(&.{ u32, u8, f64 }));
    try std.testing.expectEqual(@as(usize, 0), totalSize(&.{}));
    try std.testing.expectEqual(@as(usize, 2 * @sizeOf(usize) + 4), totalSize(&.{ []const u8, i32 }));
}

test "requirePowerOfTwo returns the exponent" {
    try std.testing.expectEqual(@as(u6, 0), requirePowerOfTwo(1));
    try std.testing.expectEqual(@as(u6, 6), requirePowerOfTwo(64));
    try std.testing.expectEqual(@as(u6, 12), requirePowerOfTwo(4096));
    // Once implemented, uncomment to watch the build fail with YOUR message:
    // _ = requirePowerOfTwo(1000);
}
