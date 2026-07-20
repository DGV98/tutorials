//! Exercise 01: Real stdout — SOLUTION
//!
//! Run the program:  zig run 01_stdout.zig

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &stdout_writer.interface;

    var row: u32 = 1;
    while (row <= 5) : (row += 1) {
        var col: u32 = 1;
        while (col <= 5) : (col += 1) {
            try stdout.print("{d:>4}", .{row * col});
        }
        try stdout.print("\n", .{});
    }

    try stdout.flush();
}
