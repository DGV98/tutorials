//! main.zig — the puzzle runner.  MILESTONE 4
//!
//!   zig build run -- <puzzle> [input-path]
//!
//! Looks the puzzle up by name, reads its input file at RUNTIME (real-AoC
//! workflow: new day, new input file, same binary — no recompiling inputs
//! in via @embedFile), runs every part, and prints an answer table with
//! per-part wall-clock timings.
//!
//! The scaffold runs as shipped. Your job is the three TODO(runner-*) gaps.

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
    // TODO(runner-1): loop over `puzzles` and compare names with
    // std.mem.eql (module 05); return null when nothing matches. The stub
    // below always picks the first puzzle — it "works" right up until you
    // mistype a name or register a second puzzle.
    _ = name; // delete once used
    return &puzzles[0];
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
    // TODO(runner-2): read the input file at runtime —
    //   std.Io.Dir.cwd().readFileAlloc(io, input_path, gpa, .limited(1 << 24))
    // (module 10, 02_read_file; the docs/zig-0.16-notes.md cheat sheet has
    // the exact shape). On error, print a friendly "cannot read ..." line,
    // flush, and std.process.exit(1). Until then, every puzzle gets an
    // empty input:
    const text: []const u8 = try gpa.dupe(u8, "");
    defer gpa.free(text);

    try out.print("puzzle: {s}   input: {s} ({d} bytes)\n\n", .{ puz.name, input_path, text.len });
    try out.print("{s:<6}{s:<16}{s}\n", .{ "part", "answer", "time" });
    for (puz.parts, 1..) |part, n| {
        // TODO(runner-3): real timings. Take a timestamp before and after
        // the call — std.Io.Clock.awake.now(io) — and t0.durationTo(t1)
        // instead of this fake zero (module 11, 05_perf_habits;
        // std.time.Timer is gone in 0.16).
        const answer = try part(gpa, text);
        const elapsed: std.Io.Duration = .fromNanoseconds(0);
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
