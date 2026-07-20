//! Exercise 05: errdefer and surviving allocation failure
//!
//! Concepts: multi-step allocations where a failure in the MIDDLE must not
//! leak the earlier steps, errdefer as the cleanup tool for exactly that,
//! and std.testing.checkAllAllocationFailures — a test harness that forces
//! every allocation to fail, one at a time, and proves your cleanup is
//! airtight.
//!
//! Run: zig test 05_errdefer_leaks.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#errdefer

const std = @import("std");
const Allocator = std.mem.Allocator;
const expectEqualStrings = std.testing.expectEqualStrings;

// This is the hardest exercise in the module. Take it slowly.
//
// THE PROBLEM. A function makes allocation A, then allocation B. B fails
// with error.OutOfMemory and the error propagates out via `try`. Who frees
// A? Nobody — the caller never got a handle to it. That's a leak that only
// shows up when memory is tight, i.e. in production, i.e. never in your
// happy-path tests.
//
// THE TOOL. `errdefer stmt;` runs stmt only if the function exits WITH AN
// ERROR after that line. It's the mirror image of the caller-owns rule:
// until you hand the finished object to the caller, YOU own the pieces, and
// the error paths are where that ownership bites. The shape to internalize:
//
//     const a = try alloc.create(Thing);
//     errdefer alloc.destroy(a);        // covers every failure BELOW this line
//     a.data = try alloc.alloc(u8, n);
//     errdefer alloc.free(a.data);      // covers every failure below THIS line
//     a.more = try alloc.alloc(u8, m);  // if this fails: free data, destroy a
//     return a;                         // success: no errdefer runs, caller owns all
//
// Each errdefer sits immediately after the allocation it guards, and they
// run in reverse order — later acquisitions are released first, so teardown
// mirrors construction.
//
// THE PROOF. Eyeballing error paths doesn't scale, so std.testing ships
//
//     try std.testing.checkAllAllocationFailures(backing, testFn, extra_args);
//
// It runs `testFn(failing_allocator, extra_args...)` once to count the
// allocations (say N), then N more times, making allocation 0 fail, then
// allocation 1, ... injecting error.OutOfMemory at every possible point.
// Any run that leaks — or swallows the error — fails the test. Your happy
// path runs once; every sad path runs too.

const Person = struct {
    name: []u8,
    email: []u8,
};

/// Heap-allocate a Person with owned copies of `name` and `email`.
/// Caller owns the result; free it with destroyPerson.
///
/// Three allocations: create the struct, dupe the name, dupe the email.
/// Any of the three can fail, and whatever was already allocated must be
/// released before the error leaves this function:
///
///   - create fails      → nothing to clean up, `try` alone is fine
///   - dupe(name) fails  → destroy the struct
///   - dupe(email) fails → free the name, destroy the struct
///
/// One errdefer after each successful acquisition covers all of it. Nothing
/// can fail after the last dupe, so the email needs no errdefer.
///
/// Write the happy path first with plain `try` and get the first test green
/// (the checkAll test may still fail!). Then add the errdefers.
fn createPerson(alloc: Allocator, name: []const u8, email: []const u8) !*Person {
    // TODO: create + errdefer destroy, dupe name + errdefer free, dupe
    // email, return. Then delete the lines below.
    _ = alloc;
    _ = name;
    _ = email;
    return error.NotImplemented;
}

/// Release everything createPerson allocated: both string fields, then the
/// struct itself. (Fields first — after destroy, `person` is gone and
/// touching person.name would be use-after-free.)
fn destroyPerson(alloc: Allocator, person: *Person) void {
    // TODO: two frees and a destroy, in the right order.
    _ = alloc;
    _ = person;
}

test "createPerson: happy path, no leaks" {
    const alloc = std.testing.allocator;

    const person = try createPerson(alloc, "Ada Lovelace", "ada@example.com");
    defer destroyPerson(alloc, person);

    try expectEqualStrings("Ada Lovelace", person.name);
    try expectEqualStrings("ada@example.com", person.email);
}

// checkAllAllocationFailures needs the scenario as a standalone function:
// first parameter is the (failing) allocator it injects, remaining
// parameters arrive via the extra_args tuple, return type must be an error
// union with void. (`anyerror!void` rather than inferred `!void` so the
// harness type-checks no matter what error set your implementation ends up
// inferring — don't change this line.)
fn tryCreateDestroyPerson(alloc: Allocator, name: []const u8, email: []const u8) anyerror!void {
    const person = try createPerson(alloc, name, email);
    destroyPerson(alloc, person);
}

test "createPerson: no leak no matter which allocation fails" {
    // Runs tryCreateDestroyPerson 4 times: once un-sabotaged (3 allocations
    // counted), then once per allocation forced to fail. When it reports a
    // leak, the output names the fail_index and the allocation that leaked —
    // read it, find the `try` it corresponds to, and check the errdefer
    // ABOVE that line. Once green, delete one errdefer and re-run to watch
    // it catch the leak.
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        tryCreateDestroyPerson,
        .{ "Ada Lovelace", "ada@example.com" },
    );
}

/// Return owned copies of every string in `strings` (an owned outer slice of
/// owned inner slices). Caller frees with freeAll.
///
/// Harder than createPerson: the number of allocations isn't fixed, so you
/// can't write one errdefer per allocation. When dupe #k fails you must free
/// dupes 0..k — but only those, since the rest were never made. The pattern:
/// track how many slots are filled in a `var`, and let ONE errdefer block
/// read it when (if) it fires:
///
///     const out = try alloc.alloc([]u8, strings.len);
///     var filled: usize = 0;
///     errdefer {
///         // free out[0..filled] in a loop, then free out itself
///     }
///     for (strings) |s| {
///         out[filled] = try alloc.dupe(u8, s);
///         filled += 1;
///     }
///     return out;
///
/// errdefer captures no snapshot — the block runs at error-exit time and
/// sees the CURRENT value of `filled`. That's exactly what makes this work.
fn dupeAll(alloc: Allocator, strings: []const []const u8) ![][]u8 {
    // TODO: implement the counter + errdefer-block pattern above.
    _ = alloc;
    _ = strings;
    return error.NotImplemented;
}

/// Free everything dupeAll allocated: each inner string, then the outer
/// slice.
fn freeAll(alloc: Allocator, strings: [][]u8) void {
    // TODO: loop of frees, then free the outer slice.
    _ = alloc;
    _ = strings;
}

test "dupeAll: happy path, no leaks" {
    const alloc = std.testing.allocator;

    const copies = try dupeAll(alloc, &.{ "alpha", "beta", "gamma" });
    defer freeAll(alloc, copies);

    try expectEqualStrings("alpha", copies[0]);
    try expectEqualStrings("beta", copies[1]);
    try expectEqualStrings("gamma", copies[2]);
}

fn tryDupeFreeAll(alloc: Allocator, strings: []const []const u8) anyerror!void {
    const copies = try dupeAll(alloc, strings);
    freeAll(alloc, copies);
}

test "dupeAll: no leak no matter which allocation fails" {
    // 4 allocations (outer slice + 3 dupes) → 5 runs. The most interesting
    // injected failure is the LAST dupe: two copies already exist and must
    // be freed by the errdefer block, the third must not be touched.
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        tryDupeFreeAll,
        .{&[_][]const u8{ "alpha", "beta", "gamma" }},
    );
}

// If both checkAllAllocationFailures tests are green, you've proven a strong
// property: these functions cannot leak, no matter where the allocator gives
// up. defer for the paths that always run, errdefer for the paths that only
// run on failure, and a harness that walks every failure — that's the full
// discipline for manual memory management in Zig.
