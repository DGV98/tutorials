//! Exercise 01: Hello, Zig — SOLUTION
//!
//! Run the program:  zig run 01_hello.zig
//! Run the tests:    zig test 01_hello.zig

const std = @import("std");

pub fn main() void {
    const name: []const u8 = "Ada";
    const age: u8 = 36;
    std.debug.print("Hi, I'm {s} and I'm {d} years old.\n", .{ name, age });
}

/// Returns the canonical course greeting.
fn greet() []const u8 {
    return "Hello, Zig!";
}

test "greet returns the expected greeting" {
    try std.testing.expectEqualStrings("Hello, Zig!", greet());
}
