//! Exercise 01: Hello, Zig
//!
//! Concepts: @import("std"), pub fn main, doc comments, std.debug.print,
//!           format specifiers {s} and {d}, your first test.
//!
//! Run the program:  zig run 01_hello.zig
//! Run the tests:    zig test 01_hello.zig
//!
//! Reference: https://ziglang.org/documentation/0.16.0/#Hello-World

// Every Zig file starts like this. @import("std") returns the standard
// library as a value you bind to a constant — there is no global namespace
// magic. `std` is just a name; you could call it anything (don't).
const std = @import("std");

// `pub fn main` is the program's entry point when you `zig run` or build an
// executable. `zig test` ignores it and runs the `test` blocks instead, so
// one file can be both a program and a test suite — handy for exercises.
//
// std.debug.print writes to stderr and needs no setup, which makes it the
// tool for quick output and debugging. (Proper buffered stdout comes in
// module 10.) It takes a format string and a tuple of arguments — the `.{}`
// syntax is an anonymous tuple. `{s}` formats a string, `{d}` a number in
// decimal.
pub fn main() void {
    // TODO: declare two constants inside main —
    //   const name: []const u8 = "..."; // your name ([]const u8 = string)
    //   const age: u8 = ...;            // your age
    // — then print a single line like "Hi, I'm Ada and I'm 36 years old."
    // using ONE std.debug.print call with {s} and {d}.
    //
    // Careful: declare the constants only once you use them — Zig refuses
    // to compile unused locals.
    std.debug.print("TODO: replace me with a real greeting\n", .{});
}

/// This is a doc comment: three slashes, and it documents the declaration
/// directly below it (the `//!` comments at the top document the whole
/// file). Tooling like zls shows these on hover.
///
/// Returns the canonical course greeting.
fn greet() []const u8 {
    // TODO: return exactly the string the test below expects.
    // String literals are `[]const u8` — bytes you can't modify. More on
    // strings in module 05; for now they behave like you'd hope.
    return "TODO";
}

// A `test` block is compiled and run only by `zig test`. The test below IS
// the spec: make it pass. std.testing.expectEqualStrings fails with a nice
// diff when the two strings differ.
test "greet returns the expected greeting" {
    try std.testing.expectEqualStrings("Hello, Zig!", greet());
}
