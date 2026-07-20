//! Exercise 03: Stream a file line by line — SOLUTION
//!
//! Run the tests (from the module directory!):  zig test 03_read_lines.zig

const std = @import("std");

const Stats = struct {
    sum: i64,
    max: i64,
};

/// Opens `path`, reads it line by line, parses each line as an i64, and
/// returns the sum and the maximum. Streaming: never holds the whole file.
fn analyze(io: std.Io, path: []const u8) !Stats {
    var file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var rbuf: [4096]u8 = undefined;
    var file_reader = file.reader(io, &rbuf);
    const r = &file_reader.interface;

    var sum: i64 = 0;
    var max: i64 = std.math.minInt(i64);

    // takeDelimiter consumes the '\n' and returns null at end of stream —
    // exactly the shape a while-loop wants. (takeDelimiterExclusive leaves
    // the delimiter in the stream: a naive loop over it never advances past
    // the first '\n' and spins forever on empty slices.)
    while (try r.takeDelimiter('\n')) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        const n = try std.fmt.parseInt(i64, trimmed, 10);
        sum += n;
        if (n > max) max = n;
    }

    return .{ .sum = sum, .max = max };
}

test "sum and max of data/numbers.txt" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const stats = try analyze(io, "data/numbers.txt");
    try std.testing.expectEqual(@as(i64, 82), stats.sum);
    try std.testing.expectEqual(@as(i64, 44), stats.max);
}
