//! Generic types: functions that return structs
//!
//! Concepts: `fn Stack(comptime T: type) type`, @This(), unmanaged-style
//! containers (pass the allocator to methods), decl literals, instantiation
//! memoization, multi-parameter generics with Pair(A, B).
//!
//! Run: zig test 03_generic_types.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Generic-Data-Structures

const std = @import("std");

// std.ArrayList(u8) is not magic syntax: ArrayList is a plain function that
// takes a type and returns a type. The struct it returns can use T in fields
// and methods because it closes over the comptime parameter.
//
// Conventions you should copy:
//   - Type-returning functions are TitleCase, because they produce a type.
//   - @This() names the anonymous struct being defined; alias it as Self.
//   - 0.16 containers are UNMANAGED: the struct does not store an allocator;
//     every method that allocates or frees takes one. The caller stays in
//     control of memory, and the struct is one pointer smaller.
//   - Instead of an init() function, expose a decl literal:
//     `pub const empty: Self = ...` lets callers write
//     `var s: Stack(i32) = .empty;`

/// A LIFO stack of T, built on std.ArrayList(T).
fn Stack(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),

        const Self = @This();

        /// The empty stack. Usage: `var s: Stack(i32) = .empty;`
        pub const empty: Self = .{ .items = .empty };

        /// Frees the stack's memory. The stack is unusable afterwards.
        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            // TODO: deinit the inner list (it needs the allocator too).
            _ = self; // remove this discard once you use self
            _ = gpa; // remove this discard once you use gpa
        }

        /// Pushes a value on top of the stack.
        pub fn push(self: *Self, gpa: std.mem.Allocator, value: T) !void {
            // TODO: append to the inner list. Remember: unmanaged lists
            // take the allocator on every call that may allocate.
            _ = self; // remove this discard once you use self
            _ = gpa; // remove this discard once you use gpa
            _ = value; // remove this discard once you use value
        }

        /// Removes and returns the top value, or null if empty.
        /// Popping never allocates, so no allocator parameter here.
        pub fn pop(self: *Self) ?T {
            // TODO: ArrayList has exactly this method.
            _ = self; // remove this discard once you use self
            return null;
        }

        /// Returns the top value without removing it, or null if empty.
        pub fn peek(self: Self) ?T {
            // TODO: look at the last element of self.items.items,
            // or use ArrayList's getLastOrNull().
            _ = self; // remove this discard once you use self
            return null;
        }

        /// Number of values currently on the stack.
        pub fn count(self: Self) usize {
            // TODO: the length of the inner list's items slice.
            _ = self; // remove this discard once you use self
            return 0;
        }
    };
}

/// A pair of two possibly different types.
fn Pair(comptime A: type, comptime B: type) type {
    return struct {
        first: A,
        second: B,

        const Self = @This();

        /// Returns the pair with the fields (and type parameters!) swapped:
        /// Pair(A, B).flip() is a Pair(B, A).
        pub fn flip(self: Self) Pair(B, A) {
            // TODO: build the flipped pair from self's fields.
            _ = self; // remove this discard once you use self
            return .{ .first = std.mem.zeroes(B), .second = std.mem.zeroes(A) };
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
    // std.testing.allocator fails this test if deinit leaks — implement
    // push without deinit and watch it complain.
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
    // Calling Stack(i32) twice yields the SAME type — instantiations are
    // cached by argument. This test passes as given; it demonstrates a
    // language guarantee, not your code.
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
    // Flipping twice gets you back where you started.
    const r = q.flip();
    try std.testing.expect(@TypeOf(r) == Pair(i32, bool));
    try std.testing.expectEqual(p, r);
}
