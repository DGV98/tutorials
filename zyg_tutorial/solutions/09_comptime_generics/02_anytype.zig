//! anytype: inferred generics and duck typing — SOLUTION
//!
//! Concepts: anytype parameters, @TypeOf, @typeName, duck typing, comptime
//! type checks with @compileError for friendly error messages.
//!
//! Run: zig test 02_anytype.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Function-Parameter-Type-Inference

const std = @import("std");

/// Returns x + x, whatever numeric type x is.
fn double(x: anytype) @TypeOf(x) {
    return x + x;
}

/// Returns the name of the value's type as a string, e.g. "i32".
fn typeNameOf(value: anytype) []const u8 {
    return @typeName(@TypeOf(value));
}

/// Returns true if values of type T support `.len` access.
fn supportsLen(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .array => true,
        .pointer => |info| switch (info.size) {
            .slice => true,
            .one => @typeInfo(info.child) == .array,
            else => false,
        },
        .@"struct" => @hasField(T, "len"),
        else => false,
    };
}

/// Returns x.len — but if @TypeOf(x) has no .len, fails compilation with a
/// clear message that names the offending type.
fn lengthOf(x: anytype) usize {
    const T = @TypeOf(x);
    // The `comptime` keyword is required: a bare supportsLen(T) is a runtime
    // expression, so the compiler would analyze BOTH branches of the if and
    // the @compileError would always fire. Forcing the condition to comptime
    // lets the not-taken branch go unanalyzed.
    if (comptime !supportsLen(T)) {
        @compileError("lengthOf: " ++ @typeName(T) ++
            " has no .len — pass a slice, array, or struct with a len field");
    }
    return x.len;
}

test "double infers the type from the argument" {
    try std.testing.expectEqual(@as(i32, 42), double(@as(i32, 21)));
    try std.testing.expectEqual(@as(f64, 3.0), double(@as(f64, 1.5)));
    try std.testing.expectEqual(@as(u8, 8), double(@as(u8, 4)));
}

test "typeNameOf reports the inferred type" {
    try std.testing.expectEqualStrings("i32", typeNameOf(@as(i32, 1)));
    try std.testing.expectEqualStrings("f64", typeNameOf(@as(f64, 1.0)));
    try std.testing.expectEqualStrings("bool", typeNameOf(true));
}

test "supportsLen classifies types" {
    try std.testing.expect(supportsLen([3]u8)); // array
    try std.testing.expect(supportsLen([]const u8)); // slice
    try std.testing.expect(supportsLen(*const [5]u8)); // pointer to array
    const Fake = struct { len: usize };
    try std.testing.expect(supportsLen(Fake)); // struct with len field
    try std.testing.expect(!supportsLen(i32));
    try std.testing.expect(!supportsLen(struct { count: usize }));
}

test "lengthOf duck-types anything with .len" {
    const arr = [_]i32{ 10, 20, 30 };
    try std.testing.expectEqual(@as(usize, 3), lengthOf(arr));
    try std.testing.expectEqual(@as(usize, 3), lengthOf(&arr)); // *[3]i32
    const slice: []const i32 = &arr;
    try std.testing.expectEqual(@as(usize, 3), lengthOf(slice));
    const Fake = struct { len: usize };
    try std.testing.expectEqual(@as(usize, 99), lengthOf(Fake{ .len = 99 }));

    // Uncommenting the next line fails the build with the friendly message:
    // _ = lengthOf(@as(i32, 5));
}
