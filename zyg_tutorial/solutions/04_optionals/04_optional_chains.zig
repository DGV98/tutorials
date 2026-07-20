//! Optional chains — ?*Node traversal, optional fields, orelse return error (SOLUTION)
//!
//! Run: zig test 04_optional_chains.zig
//! Ref: https://ziglang.org/documentation/0.16.0/#Optional-Pointers

const std = @import("std");

const Node = struct {
    value: i32,
    next: ?*Node = null,
};

/// Sum the values of a chain of nodes.
fn listSum(head: ?*const Node) i32 {
    var total: i32 = 0;
    // The canonical chain walk. The continue expression `: (cur = node.next)`
    // runs after every iteration, so the advance can never be forgotten —
    // a bare `while (cur) |node|` with no advance re-checks the same node
    // forever.
    var cur = head;
    while (cur) |node| : (cur = node.next) {
        total += node.value;
    }
    return total;
}

/// Return the value of the LAST node in the chain, or null for an empty one.
fn tailValue(head: ?*const Node) ?i32 {
    // Track "the last value seen" as a ?i32. If the loop never runs (empty
    // list), it is still null — the initial value doubles as the answer for
    // the empty case, no special-casing needed.
    var last: ?i32 = null;
    var cur = head;
    while (cur) |node| : (cur = node.next) {
        last = node.value;
    }
    return last;
}

const Profile = struct {
    email: ?[]const u8 = null,
};

const User = struct {
    name: []const u8,
    profile: ?Profile = null,
};

/// Fetch a user's email; each missing layer becomes a named error.
fn getEmail(user: User) error{ NoProfile, NoEmail }![]const u8 {
    // Each `orelse return error.X` converts one layer's EXPECTED absence
    // (the field's ?T) into OUR caller's failure — the deliberate bridge
    // from optionals back to module 3's error unions. After the first
    // line, `profile` is a plain Profile; the null case is gone.
    const profile = user.profile orelse return error.NoProfile;
    return profile.email orelse return error.NoEmail;
}

// ---------------------------------------------------------------- tests ---

test "optional pointers are free" {
    try std.testing.expectEqual(@sizeOf(*Node), @sizeOf(?*Node));
    try std.testing.expect(@sizeOf(?i32) > @sizeOf(i32));
}

test "listSum walks the chain" {
    var c = Node{ .value = 30 };
    var b = Node{ .value = 12, .next = &c };
    const a = Node{ .value = 100, .next = &b };
    try std.testing.expectEqual(@as(i32, 142), listSum(&a));

    const single = Node{ .value = -5 };
    try std.testing.expectEqual(@as(i32, -5), listSum(&single));
}

test "listSum of the empty list is 0" {
    try std.testing.expectEqual(@as(i32, 0), listSum(null));
}

test "tailValue finds the end of the chain" {
    var c = Node{ .value = 3 };
    var b = Node{ .value = 2, .next = &c };
    const a = Node{ .value = 1, .next = &b };
    try std.testing.expectEqual(@as(?i32, 3), tailValue(&a));

    const single = Node{ .value = 9 };
    try std.testing.expectEqual(@as(?i32, 9), tailValue(&single));
}

test "tailValue of the empty list is null — absence, not failure" {
    try std.testing.expectEqual(@as(?i32, null), tailValue(null));
}

test "getEmail unwraps the happy path" {
    const user = User{
        .name = "ada",
        .profile = .{ .email = "ada@example.com" },
    };
    try std.testing.expectEqualStrings("ada@example.com", try getEmail(user));
}

test "getEmail names each missing layer" {
    const no_profile = User{ .name = "ghost" };
    try std.testing.expectError(error.NoProfile, getEmail(no_profile));

    const no_email = User{ .name = "shy", .profile = .{} };
    try std.testing.expectError(error.NoEmail, getEmail(no_email));
}
