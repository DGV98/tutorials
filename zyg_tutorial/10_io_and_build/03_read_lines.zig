//! Exercise 03: Stream a file line by line
//!
//! Concepts: Io.Dir.cwd().openFile, File.Reader, takeDelimiter, parseInt —
//!           the canonical Advent-of-Code input loop.
//!
//! Run the tests (from the module directory!):  zig test 03_read_lines.zig
//!
//! Exercise 02 slurped the whole file into memory. That's fine for small
//! inputs, but the streaming version below uses a fixed 4 KiB buffer no
//! matter how big the file is — and it's the shape you'll reach for on
//! every puzzle input from here to module 12.

const std = @import("std");

const Stats = struct {
    sum: i64,
    max: i64,
};

/// Opens `path`, reads it line by line, parses each line as an i64, and
/// returns the sum and the maximum of all the numbers.
fn analyze(io: std.Io, path: []const u8) !Stats {
    // TODO: open the file relative to the current working directory:
    //
    //     var file = try std.Io.Dir.cwd().openFile(io, path, .{});
    //     defer file.close(io);
    //
    // Note the file, like everything Io, wants the io passed back in when
    // you close it.

    // TODO: make a buffered reader over the file, then grab the generic
    // interface pointer (same two-step dance as the writer in exercise 01):
    //
    //     var rbuf: [4096]u8 = undefined;
    //     var file_reader = file.reader(io, &rbuf);
    //     const r = &file_reader.interface; // *std.Io.Reader

    // TODO: the input loop. `takeDelimiter('\n')` returns the next line
    // (without the '\n', which it consumes) or null at end of stream, so it
    // slots straight into while-with-unwrap from module 04:
    //
    //     while (try r.takeDelimiter('\n')) |line| { ... }
    //
    // Inside the loop:
    //   - trim the line with std.mem.trim(u8, line, " \t\r") — belt and
    //     braces against Windows line endings and stray spaces;
    //   - skip empty lines (`continue`);
    //   - parse with try std.fmt.parseInt(i64, trimmed, 10);
    //   - accumulate the sum and track the max (start max at
    //     std.math.minInt(i64) so negative numbers work).
    //
    // Careful: the slice `line` points into the reader's buffer and is only
    // valid until the next take — copy it if you need to keep it. Here you
    // parse and move on, so no copy needed.
    //
    // A near-miss to know about: takeDelimiterExclusive does NOT consume
    // the delimiter, so a naive loop over it reads the first line and then
    // spins forever on empty slices. takeDelimiter is the loop-friendly one.

    _ = io; // remove this line once you use `io`
    _ = path; // remove this line once you use `path`
    return .{ .sum = 0, .max = 0 };
}

test "sum and max of data/numbers.txt" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    // data/numbers.txt holds: 12, -7, 30, 5, -2, 44 — one per line.
    const stats = try analyze(io, "data/numbers.txt");
    try std.testing.expectEqual(@as(i64, 82), stats.sum);
    try std.testing.expectEqual(@as(i64, 44), stats.max);
}
