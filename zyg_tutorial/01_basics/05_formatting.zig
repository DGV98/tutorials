//! Exercise 05: Formatting with std.fmt
//!
//! Concepts: bufPrint into a stack buffer, allocPrint with an allocator,
//!           specifiers {d} {s} {c} {x} {b} {any}, width/fill like {d:0>4}.
//!
//! Run: zig test 05_formatting.zig
//!
//! Reference: https://ziglang.org/documentation/0.16.0/std/#std.fmt

const std = @import("std");

// Two workhorses for building strings:
//
//   std.fmt.bufPrint(buffer, fmt, args)   // writes into YOUR buffer,
//                                         // returns the slice it used, or
//                                         // error.NoSpaceLeft
//   std.fmt.allocPrint(alloc, fmt, args)  // allocates exactly the right
//                                         // amount; caller must free
//
// bufPrint needs no allocator (the buffer usually lives on the stack);
// allocPrint handles any length but hands you ownership of memory.
//
// Every stub below returns error.NotImplemented so the file compiles.
// Delete that line (and the discards) when you implement.

// TODO: format "<name>: <score>", e.g. "ada: 95". Use {s} and {d}.
// Return what bufPrint returns — its error (NoSpaceLeft, when the buffer
// is too small) becomes YOUR error, which the second test checks.
fn scoreLine(buf: []u8, name: []const u8, score: u32) ![]u8 {
    _ = buf; // remove these discards when you implement
    _ = name;
    _ = score;
    return error.NotImplemented;
}

// A specifier can carry alignment and width: {[spec]:[fill][align][width]}.
//   {d:0>4}  -> pad with '0', right-align, to width 4:  7 becomes "0007"
//   {s:*<6}  -> pad with '*', left-align, to width 6:  "ab" becomes "ab****"
// Values wider than the width are printed in full, never chopped.
//
// TODO: format n as a zero-padded 4-digit ticket number, e.g. "0042".
fn ticketNumber(buf: []u8, n: u32) ![]u8 {
    _ = buf; // remove these discards when you implement
    _ = n;
    return error.NotImplemented;
}

// {x} prints lowercase hex, {b} binary — both combine with padding.
// A color channel is one byte = two hex digits, so {x:0>2}.
//
// TODO: format an RGB color as "#rrggbb", e.g. (255, 128, 0) -> "#ff8000".
fn hexColor(buf: []u8, r: u8, g: u8, b: u8) ![]u8 {
    _ = buf; // remove these discards when you implement
    _ = r;
    _ = g;
    _ = b;
    return error.NotImplemented;
}

// TODO: format a byte as its 8 binary digits, e.g. 5 -> "00000101".
fn bits(buf: []u8, byte: u8) ![]u8 {
    _ = buf; // remove these discards when you implement
    _ = byte;
    return error.NotImplemented;
}

// A u8 can be a number or a character — the specifier decides:
//   {d} on 'A' prints "65", {c} prints "A".
//
// TODO: format "grade: <letter>", e.g. 'A' -> "grade: A".
fn gradeLine(buf: []u8, letter: u8) ![]u8 {
    _ = buf; // remove these discards when you implement
    _ = letter;
    return error.NotImplemented;
}

// {any} debug-prints anything — slices, structs, optionals — in Zig-ish
// syntax. A slice of ints comes out like "{ 1, 2, 3 }". Great for
// debugging; don't build user-facing output with it.
//
// TODO: format "items: " followed by the slice via {any},
// e.g. "items: { 1, 2, 3 }".
fn describeItems(buf: []u8, xs: []const i32) ![]u8 {
    _ = buf; // remove these discards when you implement
    _ = xs;
    return error.NotImplemented;
}

// When you can't predict the length, allocPrint. The caller owns the
// returned memory and must free it with the SAME allocator. In tests use
// std.testing.allocator — it fails the test if you leak.
//
// TODO: return a freshly allocated "<key>=<value>", e.g. "retries=-1".
fn keyValue(alloc: std.mem.Allocator, key: []const u8, value: i64) ![]u8 {
    _ = alloc; // remove these discards when you implement
    _ = key;
    _ = value;
    return error.NotImplemented;
}

// ── The spec ────────────────────────────────────────────────────────────

test "scoreLine formats name and score" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("ada: 95", try scoreLine(&buf, "ada", 95));
}

test "scoreLine propagates NoSpaceLeft" {
    var tiny: [2]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, scoreLine(&tiny, "ada", 95));
}

test "ticketNumber zero-pads to 4 digits" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("0042", try ticketNumber(&buf, 42));
    // width is a minimum, not a truncation:
    try std.testing.expectEqualStrings("12345", try ticketNumber(&buf, 12345));
}

test "hexColor formats each channel as two hex digits" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("#ff8000", try hexColor(&buf, 255, 128, 0));
    try std.testing.expectEqualStrings("#000000", try hexColor(&buf, 0, 0, 0));
}

test "bits shows all eight binary digits" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("00000101", try bits(&buf, 5));
    try std.testing.expectEqualStrings("11111111", try bits(&buf, 255));
}

test "gradeLine prints the byte as a character" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("grade: A", try gradeLine(&buf, 'A'));
}

test "describeItems debug-prints a slice" {
    var buf: [64]u8 = undefined;
    const xs = [_]i32{ 1, 2, 3 };
    try std.testing.expectEqualStrings("items: { 1, 2, 3 }", try describeItems(&buf, &xs));
}

test "keyValue allocates exactly what it needs" {
    const s = try keyValue(std.testing.allocator, "retries", -1);
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("retries=-1", s);
}
