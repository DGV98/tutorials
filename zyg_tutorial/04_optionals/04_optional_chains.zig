//! Optional chains — ?*Node traversal, optional fields, orelse return error
//!
//! Concepts: optional struct fields (`field: ?T = null`), optional pointers
//! ?*T and the null pointer optimization, walking a `next` chain, converting
//! absence into failure with `orelse return error.X`.
//!
//! Run: zig test 04_optional_chains.zig
//! Ref: https://ziglang.org/documentation/0.16.0/#Optional-Pointers

const std = @import("std");

// ?*T is the honest version of C's nullable pointer. It costs nothing:
// pointers in Zig can never be zero, so the compiler represents the null
// case as address zero — @sizeOf(?*T) == @sizeOf(*T) (a test below proves
// it). Same machine word as C, but the type system forces every user to
// handle null before dereferencing. This is why self-referencing structures
// are spelled with ?*:

const Node = struct {
    value: i32,
    next: ?*Node = null, // the `= null` default makes leaf nodes cheap to write
};

/// Sum the values of a chain of nodes. An empty list (head == null) sums
/// to 0 — absence of nodes is expected, so no optionals leak out of here.
fn listSum(head: ?*const Node) i32 {
    // TODO: the canonical chain walk from the README —
    //   var cur = head;
    //   while (cur) |node| : (cur = node.next) { ...add node.value... }
    // The continue expression `: (cur = node.next)` advances the cursor;
    // forget it and the loop re-checks the same node forever.
    _ = head; // TODO: remove this discard once you use the parameter
    return 0;
}

/// Return the value of the LAST node in the chain, or null if the chain is
/// empty. Here absence does leak out — an empty list has no tail, and ?i32
/// says exactly that.
fn tailValue(head: ?*const Node) ?i32 {
    // TODO: same walk as listSum, but remember the value you just saw:
    // declare `var last: ?i32 = null;` and overwrite it on every node.
    // Whatever it holds after the loop is the answer — including the
    // starts-empty case, where the loop body never runs.
    _ = head; // TODO: remove this discard once you use the parameter
    return null;
}

// Optional FIELDS model data where parts may be missing — think JSON with
// absent keys. Reaching through the layers means unwrapping at every step:

const Profile = struct {
    email: ?[]const u8 = null,
};

const User = struct {
    name: []const u8,
    profile: ?Profile = null,
};

/// Fetch a user's email. Two things can be missing on the way, and for OUR
/// caller each miss is a distinct failure — this is where an optional gets
/// converted into an error (the bridge back to module 3):
///   no profile        -> error.NoProfile
///   profile, no email -> error.NoEmail
fn getEmail(user: User) error{ NoProfile, NoEmail }![]const u8 {
    // TODO: two lines, one unwrap each:
    //   const profile = user.profile orelse return error.NoProfile;
    //   return profile.email orelse return error.NoEmail;
    // `orelse return error.X` reads as: "unwrap, and if there's nothing,
    // my caller gets a failure with a name".
    _ = user; // TODO: remove this discard once you use the parameter
    return error.NoProfile;
}

// ---------------------------------------------------------------- tests ---

test "optional pointers are free" {
    // Passing test, no TODO: the null pointer optimization, measured.
    try std.testing.expectEqual(@sizeOf(*Node), @sizeOf(?*Node));
    // Non-pointer optionals DO pay for the is-null flag:
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
