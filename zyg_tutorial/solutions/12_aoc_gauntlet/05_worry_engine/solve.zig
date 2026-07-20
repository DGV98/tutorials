//! Problem 5: Worry Engine — reference solution.
//!
//! Skills: stanza parsing into structs, tagged-union operation, simulation
//! with ArrayList item queues, and the modular-arithmetic insight for part 2
//! (work modulo the product of all the divisors — every `div` test still
//! gives the same answer, but the numbers stay small).
//! Modules 05, 06, 08.
//!
//! Run: zig test solve.zig   (from this directory)

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

const Op = union(enum) {
    add: u64,
    mul: u64,
    square,

    fn apply(op: Op, old: u64) u64 {
        return switch (op) {
            .add => |k| old + k,
            .mul => |k| old * k,
            .square => old * old,
        };
    }
};

const Machine = struct {
    items: std.ArrayList(u64) = .empty,
    op: Op = .square,
    div: u64 = 1,
    on_true: usize = 0,
    on_false: usize = 0,
    inspections: u64 = 0,
};

fn parse(alloc: std.mem.Allocator, text: []const u8) ![]Machine {
    var machines: std.ArrayList(Machine) = .empty;
    errdefer machines.deinit(alloc);

    var stanzas = std.mem.splitSequence(u8, text, "\n\n");
    while (stanzas.next()) |stanza| {
        var m: Machine = .{};
        var lines = std.mem.tokenizeScalar(u8, stanza, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " ");
            if (std.mem.startsWith(u8, line, "items:")) {
                var nums = std.mem.tokenizeAny(u8, line["items:".len..], ", ");
                while (nums.next()) |n| {
                    try m.items.append(alloc, try std.fmt.parseInt(u64, n, 10));
                }
            } else if (std.mem.startsWith(u8, line, "op: old")) {
                var parts = std.mem.tokenizeScalar(u8, line["op: old".len..], ' ');
                const sym = parts.next().?; // "*" or "+"
                const rhs = parts.next().?; // "old" or a number
                if (std.mem.eql(u8, rhs, "old")) {
                    m.op = .square;
                } else if (sym[0] == '*') {
                    m.op = .{ .mul = try std.fmt.parseInt(u64, rhs, 10) };
                } else {
                    m.op = .{ .add = try std.fmt.parseInt(u64, rhs, 10) };
                }
            } else if (std.mem.startsWith(u8, line, "div:")) {
                const n = std.mem.trim(u8, line["div:".len..], " ");
                m.div = try std.fmt.parseInt(u64, n, 10);
            } else if (std.mem.startsWith(u8, line, "true:")) {
                const n = std.mem.trim(u8, line["true:".len..], " ");
                m.on_true = try std.fmt.parseInt(usize, n, 10);
            } else if (std.mem.startsWith(u8, line, "false:")) {
                const n = std.mem.trim(u8, line["false:".len..], " ");
                m.on_false = try std.fmt.parseInt(usize, n, 10);
            }
        }
        try machines.append(alloc, m);
    }
    return machines.toOwnedSlice(alloc);
}

fn run(alloc: std.mem.Allocator, text: []const u8, rounds: usize, relief: bool) !i64 {
    const machines = try parse(alloc, text);
    defer {
        for (machines) |*m| m.items.deinit(alloc);
        alloc.free(machines);
    }

    // Part 2's trick: every routing decision is `worry % div == 0`, so worry
    // values only matter modulo the product of all divisors.
    var modulus: u64 = 1;
    for (machines) |m| modulus *= m.div;

    for (0..rounds) |_| {
        for (machines) |*m| {
            // Machines never send to themselves, so appending to *other*
            // machines while we walk our own items is safe.
            for (m.items.items) |old| {
                m.inspections += 1;
                var worry = m.op.apply(old);
                worry = if (relief) worry / 3 else worry % modulus;
                const target = if (worry % m.div == 0) m.on_true else m.on_false;
                try machines[target].items.append(alloc, worry);
            }
            m.items.clearRetainingCapacity();
        }
    }

    var top = [2]u64{ 0, 0 };
    for (machines) |m| {
        if (m.inspections > top[0]) {
            top[1] = top[0];
            top[0] = m.inspections;
        } else if (m.inspections > top[1]) {
            top[1] = m.inspections;
        }
    }
    return @intCast(top[0] * top[1]);
}

/// Part 1: 20 rounds, worry divided by 3 after each inspection.
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    return run(alloc, text, 20, true);
}

/// Part 2: 10000 rounds, no relief — worry kept modulo the divisor product.
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    return run(alloc, text, 10000, false);
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
