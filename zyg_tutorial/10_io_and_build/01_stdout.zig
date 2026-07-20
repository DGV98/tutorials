//! Exercise 01: Real stdout
//!
//! Concepts: pub fn main(init: std.process.Init), init.io, buffered writers,
//!           the .interface pointer, flush().
//!
//! Run the program:  zig run 01_stdout.zig
//! (No tests in this one — compare your output against the expected block
//! below.)

const std = @import("std");

// So far the course printed with std.debug.print — fine for debugging, but
// it goes to *stderr*, unbuffered. Real program output belongs on *stdout*,
// and in Zig 0.16 all I/O goes through an explicit `std.Io` value, exactly
// like memory goes through an explicit `std.mem.Allocator`.
//
// Where does the Io come from? The new-style main receives it: declare main
// as `pub fn main(init: std.process.Init) !void` and the runtime hands you
//   init.io   — the Io instance
//   init.gpa  — a general-purpose allocator (leak-checked in Debug builds)
// This exercise only needs `init.io`.
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // TODO: build a buffered stdout writer. Three pieces:
    //
    //   var buf: [1024]u8 = undefined;                          // the buffer
    //   var stdout_writer = std.Io.File.stdout().writer(io, &buf);
    //   const stdout = &stdout_writer.interface;                // *std.Io.Writer
    //
    // Why the buffer? Every unbuffered write is a syscall. Writing a table
    // cell-by-cell would be dozens of syscalls; with a buffer it's one. The
    // cost of the deal: nothing reaches the terminal until the buffer fills
    // or you flush.
    //
    // Why `.interface`? stdout_writer is a concrete std.Io.File.Writer; the
    // `interface` field is the generic *std.Io.Writer that all formatting
    // functions (print, writeAll, ...) are defined on. You always print
    // through that pointer.

    // TODO: print the 5x5 multiplication table using two nested while loops
    // (rows 1..5, columns 1..5). Print each product with `{d:>4}` — right-
    // aligned, width 4 — and end each row with "\n". Expected output:
    //
    //    1   2   3   4   5
    //    2   4   6   8  10
    //    3   6   9  12  15
    //    4   8  12  16  20
    //    5  10  15  20  25

    // TODO: flush! `try stdout.flush();` — without it the buffered bytes are
    // silently dropped when main returns. Delete the program's output and
    // you'll see... nothing. That's the bug you'll hunt for an hour someday.

    _ = io; // TODO: remove this line once you use `io` above.
}
