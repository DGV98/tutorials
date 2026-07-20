//! Exercise 04: Command-line arguments
//!
//! Concepts: std.process.Args.Iterator, skipping argv[0], parseInt + catch,
//!           friendly CLI errors, std.process.exit.
//!
//! Run the program:  zig run 04_args_cli.zig -- 3 4 5
//! (the `--` separates zig's own arguments from your program's arguments)
//!
//! Expected behavior once you're done:
//!
//!   $ zig run 04_args_cli.zig -- 3 4 5
//!   sum: 12
//!   product: 60
//!
//!   $ zig run 04_args_cli.zig -- 3 four
//!   error: 'four' is not an integer
//!   (and the process exits with status 1)
//!
//!   $ zig run 04_args_cli.zig
//!   usage: 04_args_cli <int> [<int> ...]
//!   (also exit status 1)

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // The raw args live in init.minimal.args; the iterator walks them one
    // by one. No allocation needed for this (there's also
    // `init.minimal.args.toSlice(arena)` if you want them all at once).
    var args: std.process.Args.Iterator = .init(init.minimal.args);

    // argv[0] is the path of the program itself — a CLI almost always skips
    // it. Forget this and your program will try to parse its own name as an
    // integer.
    _ = args.next();

    // TODO: declare your accumulators —
    //   var sum: i64 = 0;
    //   var product: i64 = 1;
    // and a counter so you can tell "no arguments at all" apart from a
    // legitimate result.

    while (args.next()) |arg| {
        // TODO: parse `arg` with std.fmt.parseInt(i64, arg, 10). Don't
        // `try` it — a user typo is not a programmer bug. Handle it:
        //
        //     const n = std.fmt.parseInt(i64, arg, 10) catch {
        //         std.debug.print("error: '{s}' is not an integer\n", .{arg});
        //         std.process.exit(1);
        //     };
        //
        // (error messages go to stderr — std.debug.print is exactly right
        // for them; exit(1) tells the shell the run failed.)
        //
        // Then add to the sum, multiply into the product, bump the counter.
        _ = arg; // remove this line once you use `arg`
    }

    // TODO: if no integers were given, print the usage line (see the header)
    // to stderr and exit(1).

    // TODO: print the results to stdout through a buffered writer — same
    // three lines as exercise 01 — then flush:
    //   sum: {d}\n
    //   product: {d}\n
    _ = io; // remove this line once you use `io`
}
