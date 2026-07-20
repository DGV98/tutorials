//! Exercise 02: Read a whole file — SOLUTION
//!
//! Run the tests (from the module directory!):  zig test 02_read_file.zig

const std = @import("std");

/// Counts the lines in `text`, where every line ends with '\n'.
fn countLines(text: []const u8) usize {
    var n: usize = 0;
    for (text) |byte| {
        if (byte == '\n') n += 1;
    }
    return n;
}

test "haiku.txt has 67 bytes and 3 lines" {
    const gpa = std.testing.allocator;

    var threaded: std.Io.Threaded = .init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const text = try std.Io.Dir.cwd().readFileAlloc(io, "data/haiku.txt", gpa, .limited(1 << 16));
    defer gpa.free(text);

    try std.testing.expectEqual(@as(usize, 67), text.len);
    try std.testing.expectEqual(@as(usize, 3), countLines(text));
}
