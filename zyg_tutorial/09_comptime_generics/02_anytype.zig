//! anytype: inferred generics and duck typing
//!
//! Concepts: anytype parameters, @TypeOf, @typeName, duck typing, comptime
//! type checks with @compileError for friendly error messages.
//!
//! Run: zig test 02_anytype.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Function-Parameter-Type-Inference

const std = @import("std");

// `anytype` means: infer the parameter's type from the argument at each call
// site. Like `comptime T: type`, every distinct argument type produces a
// fresh, fully checked copy of the function — but the caller doesn't have to
// spell the type out.
//
// @TypeOf(x) recovers the inferred type. It is usable in the return type
// because parameters are in scope there.

/// Returns x + x, whatever numeric type x is.
fn double(x: anytype) @TypeOf(x) {
    // TODO: return x added to itself.
    return x;
}

/// Returns the name of the value's type as a string, e.g. "i32".
/// @typeName(T) gives a [:0]const u8 at compile time — great for messages.
fn typeNameOf(value: anytype) []const u8 {
    // TODO: get the type of `value`, then its name.
    _ = value; // remove this discard once you use value
    return "unknown";
}

// DUCK TYPING. Because anytype bodies are checked per-instantiation, `x.len`
// compiles for anything that has a length: slices, arrays, pointers to
// arrays, or your own struct with a `len` field. No interface required.
//
// The catch: pass something without .len and the compile error lands inside
// the function body, possibly deep in a call chain. Libraries check the type
// up front and emit their own message with @compileError instead.
//
// @compileError is only triggered if analysis actually reaches it — branches
// not taken for a given type are never analyzed. That laziness is what lets
// you write type-dependent branches at all.

/// Returns true if values of type T support `.len` access:
///   - arrays ([N]T)
///   - slices ([]T)
///   - pointers to arrays (*[N]T)
///   - structs with a field named "len"
/// Hint: switch on @typeInfo(T). The variants you need are .array,
/// .pointer (check info.size: .slice or .one), and .@"struct" (use
/// @hasField). Everything else: false.
fn supportsLen(comptime T: type) bool {
    // TODO: implement the switch described above.
    _ = T; // remove this discard once you use T
    return false;
}

/// Returns x.len — but if @TypeOf(x) has no .len, fails compilation with a
/// clear message that names the offending type.
fn lengthOf(x: anytype) usize {
    // TODO:
    // 1. If `comptime !supportsLen(@TypeOf(x))`, @compileError with a
    //    friendly message. Build it with ++ and @typeName, e.g.:
    //      "lengthOf: " ++ @typeName(T) ++ " has no .len"
    //    The `comptime` keyword on the condition matters: a bare function
    //    call is a runtime expression, so both branches would be analyzed
    //    and the @compileError would fire for every type. A comptime-known
    //    condition leaves the not-taken branch unanalyzed.
    // 2. Otherwise return x.len.
    _ = x; // remove this discard once you use x
    return 0;
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

    // Once lengthOf is implemented, uncomment the next line and recompile to
    // see YOUR error message instead of a confusing one about field access:
    // _ = lengthOf(@as(i32, 5));
}
