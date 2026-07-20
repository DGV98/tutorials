//! Exercise 04: Command-line arguments — SOLUTION
//!
//! Run the program:  zig run 04_args_cli.zig -- 3 4 5

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var args: std.process.Args.Iterator = .init(init.minimal.args);
    _ = args.next(); // skip argv[0], the program's own path

    var sum: i64 = 0;
    var product: i64 = 1;
    var count: usize = 0;

    while (args.next()) |arg| {
        const n = std.fmt.parseInt(i64, arg, 10) catch {
            std.debug.print("error: '{s}' is not an integer\n", .{arg});
            std.process.exit(1);
        };
        sum += n;
        product *= n;
        count += 1;
    }

    if (count == 0) {
        std.debug.print("usage: 04_args_cli <int> [<int> ...]\n", .{});
        std.process.exit(1);
    }

    var buf: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &stdout_writer.interface;

    try stdout.print("sum: {d}\n", .{sum});
    try stdout.print("product: {d}\n", .{product});
    try stdout.flush();
}
