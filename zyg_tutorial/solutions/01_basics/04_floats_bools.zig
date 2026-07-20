//! Exercise 04: Floats and bools — SOLUTION
//!
//! Run: zig test 04_floats_bools.zig

const std = @import("std");

fn celsiusToFahrenheit(c: f64) f64 {
    // 9.0 / 5.0, not 9 / 5 — the integer version would be 1.
    return c * 9.0 / 5.0 + 32.0;
}

fn average(sum: i64, count: i64) f64 {
    // Both sides converted explicitly; the `: f64` annotations give
    // @floatFromInt its destination type.
    const s: f64 = @floatFromInt(sum);
    const n: f64 = @floatFromInt(count);
    return s / n;
}

fn wholePart(x: f64) i32 {
    // @intFromFloat truncates toward zero: 3.99 -> 3, -3.99 -> -3.
    return @intFromFloat(x);
}

fn nearlyEqual(a: f64, b: f64) bool {
    return std.math.approxEqAbs(f64, a, b, 1e-9);
}

fn canRideAlone(height_cm: u32, age: u8) bool {
    return height_cm >= 120 and age >= 8;
}

fn needsJacket(raining: bool, temp_c: i32) bool {
    return raining or temp_c < 10;
}

test "celsius to fahrenheit" {
    try std.testing.expect(std.math.approxEqAbs(f64, 212.0, celsiusToFahrenheit(100.0), 1e-9));
    try std.testing.expect(std.math.approxEqAbs(f64, -40.0, celsiusToFahrenheit(-40.0), 1e-9));
}

test "average of integers" {
    try std.testing.expect(std.math.approxEqAbs(f64, 3.5, average(7, 2), 1e-9));
    try std.testing.expect(std.math.approxEqAbs(f64, -2.5, average(-5, 2), 1e-9));
}

test "whole part truncates toward zero" {
    try std.testing.expectEqual(3, wholePart(3.99));
    try std.testing.expectEqual(-3, wholePart(-3.99));
}

test "nearlyEqual forgives float error but not real differences" {
    try std.testing.expect(0.1 + 0.2 != 0.3);
    try std.testing.expect(nearlyEqual(0.1 + 0.2, 0.3));
    try std.testing.expect(!nearlyEqual(1.0, 1.1));
}

test "canRideAlone needs both conditions" {
    try std.testing.expect(canRideAlone(140, 10));
    try std.testing.expect(!canRideAlone(140, 6));
    try std.testing.expect(!canRideAlone(90, 10));
}

test "needsJacket needs either condition" {
    try std.testing.expect(needsJacket(true, 20));
    try std.testing.expect(needsJacket(false, 5));
    try std.testing.expect(!needsJacket(false, 20));
}
