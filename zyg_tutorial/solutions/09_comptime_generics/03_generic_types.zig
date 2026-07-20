//! Generic types: functions that return structs — SOLUTION
//!
//! Concepts: `fn Stack(comptime T: type) type`, @This(), unmanaged-style
//! containers (pass the allocator to methods), decl literals, instantiation
//! memoization, multi-parameter generics with Pair(A, B).
//!
//! Run: zig test 03_generic_types.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Generic-Data-Structures

const std = @import("std");

/// A LIFO stack of T, built on std.ArrayList(T).
fn Stack(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),

        const Self = @This();

        /// The empty stack. Usage: `var s: Stack(i32) = .empty;`
        pub const empty: Self = .{ .items = .empty };

        /// Frees the stack's memory. The stack is unusable afterwards.
        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            self.items.deinit(gpa);
        }

        /// Pushes a value on top of the stack.
        pub fn push(self: *Self, gpa: std.mem.Allocator, value: T) !void {
            try self.items.append(gpa, value);
        }

        /// Removes and returns the top value, or null if empty.
        pub fn pop(self: *Self) ?T {
            return self.items.pop();
        }

        /// Returns the top value without removing it, or null if empty.
        pub fn peek(self: Self) ?T {
            return self.items.getLastOrNull();
        }

        /// Number of values currently on the stack.
        pub fn count(self: Self) usize {
            return self.items.items.len;
        }
    };
}

/// A pair of two possibly different types.
fn Pair(comptime A: type, comptime B: type) type {
    return struct {
        first: A,
        second: B,

        const Self = @This();

        /// Returns the pair with the fields (and type parameters!) swapped.
        pub fn flip(self: Self) Pair(B, A) {
            return .{ .first = self.second, .second = self.first };
        }
    };
}

test "stack push/pop/peek" {
    const gpa = std.testing.allocator;
    var s: Stack(i32) = .empty;
    defer s.deinit(gpa);

    try std.testing.expectEqual(@as(?i32, null), s.pop());
    try s.push(gpa, 1);
    try s.push(gpa, 2);
    try s.push(gpa, 3);
    try std.testing.expectEqual(@as(usize, 3), s.count());
    try std.testing.expectEqual(@as(?i32, 3), s.peek());
    try std.testing.expectEqual(@as(?i32, 3), s.pop());
    try std.testing.expectEqual(@as(?i32, 2), s.pop());
    try std.testing.expectEqual(@as(usize, 1), s.count());
}

test "stack is generic over element type" {
    const gpa = std.testing.allocator;
    var s: Stack([]const u8) = .empty;
    defer s.deinit(gpa);
    try s.push(gpa, "hello");
    try s.push(gpa, "world");
    const top = s.pop();
    try std.testing.expect(top != null);
    try std.testing.expectEqualStrings("world", top.?);
    const next = s.pop();
    try std.testing.expect(next != null);
    try std.testing.expectEqualStrings("hello", next.?);
}

test "generic instantiations are memoized" {
    try std.testing.expect(Stack(i32) == Stack(i32));
    try std.testing.expect(Stack(i32) != Stack(u8));
    try std.testing.expect(Pair(i32, bool) == Pair(i32, bool));
    try std.testing.expect(Pair(i32, bool) != Pair(bool, i32));
}

test "pair flip swaps values and type parameters" {
    const p = Pair(i32, bool){ .first = 7, .second = true };
    const q = p.flip(); // q: Pair(bool, i32)
    try std.testing.expect(@TypeOf(q) == Pair(bool, i32));
    try std.testing.expectEqual(true, q.first);
    try std.testing.expectEqual(@as(i32, 7), q.second);
    const r = q.flip();
    try std.testing.expect(@TypeOf(r) == Pair(i32, bool));
    try std.testing.expectEqual(p, r);
}
