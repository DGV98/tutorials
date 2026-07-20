//! grid.zig — a generic 2D grid for the AoC toolkit.  MILESTONE 2
//!
//! `Grid(T)` stores rows*cols cells of any scalar T in one flat slice
//! (row-major: cell (r,c) lives at index r*cols+c — the module-12 trick,
//! now packaged). `Grid(u8)` is the workhorse: `fromText` parses the
//! character grids that half of all AoC puzzles hand you.
//!
//! The tests at the bottom are the specification — make them green:
//!   zig build test-grid        (or: zig test src/lib/grid.zig)

const std = @import("std");

/// A cell coordinate. Row 0 is the top line, col 0 the leftmost column.
pub const Pos = struct {
    row: usize,
    col: usize,
};

const deltas4 = [_][2]i8{ .{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 } };
const deltas8 = [_][2]i8{
    .{ -1, -1 }, .{ -1, 0 }, .{ -1, 1 },
    .{ 0, -1 },  .{ 0, 1 },  .{ 1, -1 },
    .{ 1, 0 },   .{ 1, 1 },
};

pub fn Grid(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []T,
        rows: usize,
        cols: usize,

        pub fn init(alloc: std.mem.Allocator, rows: usize, cols: usize, fill: T) !Self {
            const data = try alloc.alloc(T, rows * cols);
            @memset(data, fill);
            return .{ .data = data, .rows = rows, .cols = cols };
        }

        pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
            alloc.free(self.data);
            self.* = undefined;
        }

        /// Parse a rectangular character grid (lines of equal length).
        /// Blank lines and a trailing newline are ignored. Only exists for
        /// Grid(u8).
        pub fn fromText(alloc: std.mem.Allocator, text: []const u8) !Self {
            comptime if (T != u8) @compileError("fromText only works for Grid(u8)");
            // TODO: two passes with std.mem.tokenizeScalar(u8, text, '\n')
            // (module 05 — tokenize skips the blank pieces for you):
            //   pass 1: count rows, take cols from the first line, and
            //           `return error.NotRectangular` on any length mismatch;
            //           no rows at all is `error.EmptyGrid`.
            //   pass 2: init(alloc, rows, cols, 0), then @memcpy each line
            //           into its slot: self.data[r * cols ..][0..cols].
            _ = alloc; // delete once used
            _ = text; // delete once used
            return error.Todo;
        }

        /// Flat index of (row, col) — the row-major layout in one place.
        pub fn index(self: Self, row: usize, col: usize) usize {
            // TODO: the one-liner that everything else builds on
            // (module 12, problem 2 used it raw). Keep the assert.
            std.debug.assert(row < self.rows and col < self.cols);
            return 0;
        }

        pub fn at(self: Self, row: usize, col: usize) T {
            return self.data[self.index(row, col)];
        }

        pub fn set(self: *Self, row: usize, col: usize, value: T) void {
            self.data[self.index(row, col)] = value;
        }

        /// Signed on purpose: candidate coordinates come from "row - 1"
        /// style arithmetic, which must be allowed to go negative.
        pub fn inBounds(self: Self, row: i64, col: i64) bool {
            // TODO: four comparisons. Zig compares i64 against usize
            // correctly without casts (module 01: peer type resolution).
            _ = self; // delete once used
            _ = row; // delete once used
            _ = col; // delete once used
            return false;
        }

        /// Position of the first cell equal to `needle` (row-major scan
        /// order), or null. How you locate 'S' and 'E'.
        pub fn find(self: Self, needle: T) ?Pos {
            // TODO: scan self.data; on a hit, turn the flat index back into
            // (row, col) with / and % (the inverse of index()).
            _ = self; // delete once used
            _ = needle; // delete once used
            return null;
        }

        /// In-bounds orthogonal neighbors of `center`, in up/down/left/right
        /// order. The module-11 `next() ?Pos` iterator pattern.
        pub fn neighbors4(self: Self, center: Pos) NeighborIterator {
            return .{ .rows = self.rows, .cols = self.cols, .center = center, .deltas = &deltas4 };
        }

        /// Same, but all eight directions (diagonals included), row by row.
        pub fn neighbors8(self: Self, center: Pos) NeighborIterator {
            return .{ .rows = self.rows, .cols = self.cols, .center = center, .deltas = &deltas8 };
        }

        pub const NeighborIterator = struct {
            rows: usize,
            cols: usize,
            center: Pos,
            deltas: []const [2]i8,
            i: usize = 0,

            pub fn next(self: *NeighborIterator) ?Pos {
                // TODO: advance through self.deltas, skipping candidates
                // that fall off the grid; return the first in-bounds Pos, or
                // null when the deltas run out (module 11, exercise 01 — the
                // same skip-and-continue loop as the Evens iterator).
                //
                // Hint: center.row is usize, deltas are signed — widen with
                // @as(i64, @intCast(...)) + d[0] before comparing, and
                // @intCast back when building the Pos (module 03/11 casts).
                _ = self; // delete once used
                return null;
            }
        };

        /// Debug dump: the grid as text, one '\n'-terminated line per row.
        /// Only exists for Grid(u8). Pass any *std.Io.Writer — in a test, a
        /// fixed writer over a stack buffer works well.
        pub fn dump(self: Self, w: *std.Io.Writer) !void {
            comptime if (T != u8) @compileError("dump only works for Grid(u8)");
            // TODO: one writeAll per row (each row is one slice of
            // self.data — you know where it starts) plus a '\n'. You will
            // use this constantly when a BFS goes wrong.
            _ = self; // delete once used
            _ = w; // delete once used
        }
    };
}

// ---------------------------------------------------------------------------
// tests — the specification. `zig build test-grid` runs exactly these.
// ---------------------------------------------------------------------------

const testing = std.testing;

const sample =
    \\ab#d
    \\efgh
    \\i#kl
    \\
;

test "index: row-major flat layout" {
    var g = try Grid(u8).fromText(testing.allocator, sample);
    defer g.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), g.index(0, 0));
    try testing.expectEqual(@as(usize, 3), g.index(0, 3));
    try testing.expectEqual(@as(usize, 4), g.index(1, 0));
    try testing.expectEqual(@as(usize, 11), g.index(2, 3));
}

test "fromText: dimensions and cell values" {
    var g = try Grid(u8).fromText(testing.allocator, sample);
    defer g.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), g.rows);
    try testing.expectEqual(@as(usize, 4), g.cols);
    try testing.expectEqual(@as(u8, 'a'), g.at(0, 0));
    try testing.expectEqual(@as(u8, 'g'), g.at(1, 2));
    try testing.expectEqual(@as(u8, 'l'), g.at(2, 3));
}

test "fromText: no trailing newline is fine too" {
    var g = try Grid(u8).fromText(testing.allocator, "12\n34");
    defer g.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), g.rows);
    try testing.expectEqual(@as(u8, '4'), g.at(1, 1));
}

test "fromText: rejects ragged input" {
    try testing.expectError(error.NotRectangular, Grid(u8).fromText(testing.allocator, "abc\nde\n"));
}

test "fromText: rejects empty input" {
    try testing.expectError(error.EmptyGrid, Grid(u8).fromText(testing.allocator, "\n\n"));
}

test "at/set roundtrip on an init-ed grid" {
    var g = try Grid(u8).init(testing.allocator, 2, 3, '.');
    defer g.deinit(testing.allocator);
    try testing.expectEqual(@as(u8, '.'), g.at(1, 2));
    g.set(1, 2, 'X');
    try testing.expectEqual(@as(u8, 'X'), g.at(1, 2));
    try testing.expectEqual(@as(u8, '.'), g.at(0, 2)); // neighbors untouched
}

test "inBounds: corners, edges, and negatives" {
    var g = try Grid(u8).fromText(testing.allocator, sample);
    defer g.deinit(testing.allocator);
    try testing.expect(g.inBounds(0, 0));
    try testing.expect(g.inBounds(2, 3));
    try testing.expect(!g.inBounds(-1, 0));
    try testing.expect(!g.inBounds(0, -1));
    try testing.expect(!g.inBounds(3, 0));
    try testing.expect(!g.inBounds(0, 4));
}

test "find: hit and miss" {
    var g = try Grid(u8).fromText(testing.allocator, sample);
    defer g.deinit(testing.allocator);
    try testing.expectEqual(@as(?Pos, .{ .row = 1, .col = 2 }), g.find('g'));
    // two '#' cells: find returns the first in row-major order
    try testing.expectEqual(@as(?Pos, .{ .row = 0, .col = 2 }), g.find('#'));
    try testing.expectEqual(@as(?Pos, null), g.find('z'));
}

test "neighbors4: interior cell yields all four, in order" {
    var g = try Grid(u8).fromText(testing.allocator, sample);
    defer g.deinit(testing.allocator);
    var it = g.neighbors4(.{ .row = 1, .col = 2 });
    try testing.expectEqual(@as(?Pos, .{ .row = 0, .col = 2 }), it.next()); // up
    try testing.expectEqual(@as(?Pos, .{ .row = 2, .col = 2 }), it.next()); // down
    try testing.expectEqual(@as(?Pos, .{ .row = 1, .col = 1 }), it.next()); // left
    try testing.expectEqual(@as(?Pos, .{ .row = 1, .col = 3 }), it.next()); // right
    try testing.expectEqual(@as(?Pos, null), it.next());
}

test "neighbors4: corner clips to two" {
    var g = try Grid(u8).fromText(testing.allocator, sample);
    defer g.deinit(testing.allocator);
    var it = g.neighbors4(.{ .row = 0, .col = 0 });
    try testing.expectEqual(@as(?Pos, .{ .row = 1, .col = 0 }), it.next()); // down
    try testing.expectEqual(@as(?Pos, .{ .row = 0, .col = 1 }), it.next()); // right
    try testing.expectEqual(@as(?Pos, null), it.next());
}

test "neighbors8: edge cell clips to five" {
    var g = try Grid(u8).fromText(testing.allocator, sample);
    defer g.deinit(testing.allocator);
    var it = g.neighbors8(.{ .row = 0, .col = 1 });
    var count: usize = 0;
    while (it.next()) |p| : (count += 1) {
        try testing.expect(p.row <= 1); // never out of the 3x4 grid
        try testing.expect(p.col <= 2);
    }
    try testing.expectEqual(@as(usize, 5), count);
}

test "dump: reproduces the parsed text" {
    var g = try Grid(u8).fromText(testing.allocator, sample);
    defer g.deinit(testing.allocator);
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try g.dump(&w);
    try testing.expectEqualStrings("ab#d\nefgh\ni#kl\n", w.buffered());
}

test "Grid(u32): the generic works for non-u8 payloads" {
    var g = try Grid(u32).init(testing.allocator, 4, 4, 0);
    defer g.deinit(testing.allocator);
    g.set(3, 1, 99_999);
    try testing.expectEqual(@as(u32, 99_999), g.at(3, 1));
    try testing.expectEqual(@as(?Pos, .{ .row = 3, .col = 1 }), g.find(99_999));
}
