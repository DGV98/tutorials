//! wordcount CLI — reads one file and prints its line/word/byte counts.
//!
//! Usage:  zig build run -- <file>
//! e.g.:   zig build run -- src/main.zig

const std = @import("std");

// This import name is wired up in build.zig (the `.imports` list of the exe
// module). It is NOT a file path — it refers to the "wordcount" module whose
// root is src/root.zig.
const wordcount = @import("wordcount");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var args: std.process.Args.Iterator = .init(init.minimal.args);
    _ = args.next(); // skip argv[0]

    const path = args.next() orelse {
        std.debug.print("usage: wordcount <file>\n", .{});
        std.process.exit(1);
    };

    const text = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(64 << 20)) catch |err| {
        std.debug.print("error: cannot read '{s}': {t}\n", .{ path, err });
        std.process.exit(1);
    };
    defer gpa.free(text);

    const counts = wordcount.count(text);

    var buf: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &stdout_writer.interface;
    try stdout.print("{d} {d} {d} {s}\n", .{ counts.lines, counts.words, counts.bytes, path });
    try stdout.flush();
}
