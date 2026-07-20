//! main.zig — the puzzle runner.
//!
//!   zig build run -- <puzzle> [input-path]
//!
//! Looks the puzzle up by name, reads its input file at RUNTIME (real-AoC
//! workflow: new day, new input file, same binary — no recompiling inputs
//! in via @embedFile), runs every part, and prints an answer table with
//! per-part wall-clock timings.

const std = @import("std");
const final = @import("puzzles/final.zig");

/// Every part has the same shape: text in, one number out. `anyerror`
/// (rather than an inferred error set) is what lets parts with different
/// error sets share one function-pointer type in the table below.
const PartFn = *const fn (std.mem.Allocator, []const u8) anyerror!i64;

const Puzzle = struct {
    name: []const u8,
    default_input: []const u8,
    parts: []const PartFn,
};

/// The puzzle table. Solving a new puzzle = writing src/puzzles/day01.zig
/// and adding one line here.
const puzzles = [_]Puzzle{
    .{
        .name = "final",
        .default_input = "input/final.txt",
        .parts = &.{ final.part1, final.part2, final.part3 },
    },
};

/// The registered puzzle called `name`, or null.
fn findPuzzle(name: []const u8) ?*const Puzzle {
    for (&puzzles) |*p| {
        if (std.mem.eql(u8, p.name, name)) return p;
    }
    return null;
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const out = &stdout_writer.interface;

    var args: std.process.Args.Iterator = .init(init.minimal.args);
    _ = args.next(); // argv[0]
    const puzzle_name = args.next() orelse return usage(out);
    const input_override = args.next();

    const puz = findPuzzle(puzzle_name) orelse {
        try out.print("unknown puzzle: '{s}'\n\n", .{puzzle_name});
        return usage(out);
    };

    const input_path = input_override orelse puz.default_input;
    const text = std.Io.Dir.cwd().readFileAlloc(io, input_path, gpa, .limited(1 << 24)) catch |err| {
        try out.print("cannot read '{s}': {t}\n", .{ input_path, err });
        try out.flush();
        std.process.exit(1); // message already tells the story; skip the error trace
    };
    defer gpa.free(text);

    try out.print("puzzle: {s}   input: {s} ({d} bytes)\n\n", .{ puz.name, input_path, text.len });
    try out.print("{s:<6}{s:<16}{s}\n", .{ "part", "answer", "time" });
    for (puz.parts, 1..) |part, n| {
        const t0 = std.Io.Clock.awake.now(io);
        const answer = try part(gpa, text);
        const elapsed = t0.durationTo(std.Io.Clock.awake.now(io));
        // Quirk: "{d:<16}" on a SIGNED int prints a leading '+' on positive
        // numbers. Format the answer to a scratch buffer, pad it as a string.
        var num_buf: [24]u8 = undefined;
        const answer_str = try std.fmt.bufPrint(&num_buf, "{d}", .{answer});
        try out.print("{d:<6}{s:<16}{f}\n", .{ n, answer_str, elapsed });
    }
    try out.flush();
}

fn usage(out: *std.Io.Writer) !void {
    try out.writeAll(
        \\usage: zig build run -- <puzzle> [input-path]
        \\
        \\puzzles:
        \\
    );
    for (puzzles) |p| {
        try out.print("  {s:<12}(default input: {s})\n", .{ p.name, p.default_input });
    }
    try out.flush();
}

// ---------------------------------------------------------------------------
// tests
// ---------------------------------------------------------------------------

test "findPuzzle: every registered puzzle is found" {
    for (puzzles) |p| {
        const found = findPuzzle(p.name) orelse return error.TestExpectedPuzzle;
        try std.testing.expectEqualStrings(p.name, found.name);
    }
}

test "findPuzzle: unknown names give null" {
    try std.testing.expectEqual(@as(?*const Puzzle, null), findPuzzle("day99"));
    try std.testing.expectEqual(@as(?*const Puzzle, null), findPuzzle(""));
}

// Pull in every file's tests so `zig build test` covers the whole project.
// Without these explicit references, a file whose code isn't (yet) called
// from main would silently contribute zero tests.
test {
    _ = @import("lib/parse.zig");
    _ = @import("lib/grid.zig");
    _ = @import("lib/algo.zig");
    _ = @import("puzzles/final.zig");
}
