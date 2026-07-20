//! Exercise 02: Read a whole file
//!
//! Concepts: std.Io.Threaded (getting an Io inside a test), Io.Dir.cwd(),
//!           readFileAlloc, size limits, freeing what you read.
//!
//! Run the tests:  zig test 02_read_file.zig
//!
//! IMPORTANT — run that from THIS module's directory. The test opens
//! "data/haiku.txt" relative to the *current working directory of the
//! process*, not relative to this source file. From the repo root the path
//! won't resolve and you'll get error.FileNotFound. (./check.sh cd's into
//! the module dir for you.)

const std = @import("std");

/// Counts the lines in `text`, where every line ends with '\n'.
fn countLines(text: []const u8) usize {
    // TODO: count the '\n' bytes in `text` with a for loop.
    _ = text; // remove this line once you use `text`
    return 0;
}

test "haiku.txt has 67 bytes and 3 lines" {
    const gpa = std.testing.allocator;

    // A test doesn't receive std.process.Init, so there's no init.io to
    // grab. Instead you construct an Io implementation yourself. Threaded
    // is the standard general-purpose one:
    var threaded: std.Io.Threaded = .init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    _ = io; // remove this line once you use `io` below

    // TODO: read data/haiku.txt into `text`, replacing the placeholder line
    // below. The tool is
    //
    //     std.Io.Dir.cwd().readFileAlloc(...)
    //
    // and its arguments, in order: the io, the path, the allocator, and a
    // size limit — pass `.limited(1 << 16)`, i.e. "refuse files over 64 KiB"
    // (a guard against accidentally slurping a huge file into memory).
    // It returns an allocated []u8: the existing `defer gpa.free(text)`
    // below must stay, or std.testing.allocator will fail the test with a
    // leak report.
    const text: []const u8 = try gpa.dupe(u8, ""); // placeholder — replace
    defer gpa.free(text);

    try std.testing.expectEqual(@as(usize, 67), text.len);
    try std.testing.expectEqual(@as(usize, 3), countLines(text));
}
