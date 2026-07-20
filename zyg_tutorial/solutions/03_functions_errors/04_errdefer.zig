//! Solution 04: errdefer

const std = @import("std");

fn dupeUpperNoDigits(gpa: std.mem.Allocator, s: []const u8) ![]u8 {
    const out = try gpa.dupe(u8, s);
    // If any line below returns an error, free the copy; if we reach the
    // final `return out`, ownership moves to the caller and this does NOT
    // run. A plain defer here would free the buffer we just handed out —
    // a use-after-free for the caller. That asymmetry is what errdefer is.
    errdefer gpa.free(out);

    for (out, 0..) |c, i| {
        if (std.ascii.isDigit(c)) return error.HasDigit;
        out[i] = std.ascii.toUpper(c);
    }
    return out;
}

const Pair = struct {
    a: []u8,
    b: []u8,
};

fn dupePair(gpa: std.mem.Allocator, first: []const u8, second: []const u8) !Pair {
    const a = try gpa.dupe(u8, first);
    // The whole exercise in one line: if the second dupe fails, the error
    // return would otherwise strand `a` — the caller never learns it
    // existed. Each acquired resource gets its own errdefer, immediately
    // after acquisition, so every prefix of the function is leak-free.
    errdefer gpa.free(a);

    const b = try gpa.dupe(u8, second);
    return .{ .a = a, .b = b };
}

test "dupeUpperNoDigits success path" {
    const gpa = std.testing.allocator;
    const out = try dupeUpperNoDigits(gpa, "hello, zig");
    defer gpa.free(out); // caller owns the result -> caller frees
    try std.testing.expectEqualStrings("HELLO, ZIG", out);
}

test "dupeUpperNoDigits rejects digits without leaking" {
    try std.testing.expectError(
        error.HasDigit,
        dupeUpperNoDigits(std.testing.allocator, "agent 007"),
    );
}

test "dupePair success path" {
    const gpa = std.testing.allocator;
    const pair = try dupePair(gpa, "left", "right");
    defer gpa.free(pair.a);
    defer gpa.free(pair.b);
    try std.testing.expectEqualStrings("left", pair.a);
    try std.testing.expectEqualStrings("right", pair.b);
}

test "dupePair: second allocation fails, first must be freed" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    try std.testing.expectError(
        error.OutOfMemory,
        dupePair(failing.allocator(), "left", "right"),
    );
}

test "dupePair: first allocation fails, nothing to clean up" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(
        error.OutOfMemory,
        dupePair(failing.allocator(), "left", "right"),
    );
}
