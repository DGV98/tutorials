//! Problem 5: Worry Engine
//!
//! Skills: multi-line stanza parsing into structs, tagged unions for the
//! operation, ArrayList item queues, simulation, u64 overflow awareness
//! (modules 05, 06, 08).
//!
//! Run: zig test solve.zig   (from this directory)
//! Read README.md first for the full problem statement.

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

// Suggested shape (module 06):
//
//   const Op = union(enum) { add: u64, mul: u64, square };
//   const Machine = struct {
//       items: std.ArrayList(u64),
//       op: Op,
//       div: u64,
//       on_true: usize,
//       on_false: usize,
//       inspections: u64,
//   };
//
// Parsing hints (module 05): stanzas are separated by blank lines
// (splitSequence "\n\n"); inside one, trim each line and dispatch on
// std.mem.startsWith. The op line is always `op: old <sym> <rhs>` where
// <sym> is * or + and <rhs> is a number or the word "old" (old * old).
//
// Round semantics: machines take turns in order 0, 1, 2, ... Each machine
// processes ALL items currently in its queue, in order, then ends its turn
// with an empty queue. Per item: apply op, apply the relief rule, test
// divisibility by `div`, send to on_true/on_false. Items received earlier
// in the SAME round are processed this round. Machines never send to
// themselves. Every processed item counts as one inspection.

/// Part 1: 20 rounds; after each inspection worry is divided by 3 (floor).
/// Answer: product of the two highest inspection counts.
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: parse, simulate 20 rounds with worry /= 3, multiply the two
    // biggest inspection counts. Use u64 for worry values.
    _ = alloc;
    _ = text;
    return -1;
}

/// Part 2: 10000 rounds and NO division by 3. Same answer formula.
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: without the /3 relief, worry values explode past what even u128
    // can hold long before round 10000. The only thing ever done with a
    // worry value is the `divisible by div` test — what property of those
    // tests lets you keep the numbers small without changing any outcome?
    _ = alloc;
    _ = text;
    return -1;
}

test "part1 example" {
    try std.testing.expectEqual(@as(i64, 11232), try part1(std.testing.allocator, example));
}

test "part2 example" {
    try std.testing.expectEqual(@as(i64, 2399320044), try part2(std.testing.allocator, example));
}

test "part1" {
    try std.testing.expectEqual(@as(i64, 59033), try part1(std.testing.allocator, input));
}

test "part2" {
    try std.testing.expectEqual(@as(i64, 13422476826), try part2(std.testing.allocator, input));
}
