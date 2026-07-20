//! parse.zig — input-parsing helpers for the AoC toolkit.
//!
//! Everything here operates on one `[]const u8` blob (usually the whole
//! input file). Iterators slice into the blob without allocating; the
//! `[]i64`-returning functions hand you an owned slice you must free.
//!
//! Inputs are assumed to use plain '\n' line endings.
//!
//! Standalone check: zig test src/lib/parse.zig   (from the project root)

const std = @import("std");

// ---------------------------------------------------------------------------
// lines — iterate over the lines of a blob
// ---------------------------------------------------------------------------

/// Yields each line of the text without its trailing '\n'. Empty lines are
/// yielded as empty slices; a final trailing newline does NOT produce an
/// extra empty line at the end. The classic module-11 `next() ?T` shape.
pub const LinesIterator = struct {
    rest: []const u8,

    pub fn next(self: *LinesIterator) ?[]const u8 {
        if (self.rest.len == 0) return null;
        if (std.mem.indexOfScalar(u8, self.rest, '\n')) |nl| {
            const line = self.rest[0..nl];
            self.rest = self.rest[nl + 1 ..];
            return line;
        }
        // last line without a trailing newline
        const line = self.rest;
        self.rest = self.rest[self.rest.len..];
        return line;
    }
};

pub fn lines(text: []const u8) LinesIterator {
    return .{ .rest = text };
}

// ---------------------------------------------------------------------------
// blankLineBlocks — iterate over blank-line-separated groups
// ---------------------------------------------------------------------------

/// Yields each block of consecutive non-blank lines. Blocks are separated by
/// one or more blank lines ("\n\n"); yielded blocks keep their internal
/// newlines but never start or end with one. Blank lines at the very start
/// or end of the text are ignored.
pub const BlockIterator = struct {
    rest: []const u8,

    pub fn next(self: *BlockIterator) ?[]const u8 {
        var r = self.rest;
        while (r.len > 0 and r[0] == '\n') r = r[1..];
        if (r.len == 0) {
            self.rest = r;
            return null;
        }
        if (std.mem.indexOf(u8, r, "\n\n")) |idx| {
            self.rest = r[idx + 2 ..];
            return r[0..idx];
        }
        self.rest = r[r.len..];
        return std.mem.trimEnd(u8, r, "\n");
    }
};

pub fn blankLineBlocks(text: []const u8) BlockIterator {
    return .{ .rest = text };
}

// ---------------------------------------------------------------------------
// parseIntLines — one integer per line
// ---------------------------------------------------------------------------

/// Parses a blob of one-integer-per-line text into an owned `[]i64`
/// (caller frees). Lines are trimmed of spaces/tabs first; blank lines are
/// skipped. A line that is not a valid i64 returns the parseInt error.
pub fn parseIntLines(alloc: std.mem.Allocator, text: []const u8) ![]i64 {
    var out: std.ArrayList(i64) = .empty;
    errdefer out.deinit(alloc);
    var it = lines(text);
    while (it.next()) |line| {
        const t = std.mem.trim(u8, line, " \t");
        if (t.len == 0) continue;
        try out.append(alloc, try std.fmt.parseInt(i64, t, 10));
    }
    return out.toOwnedSlice(alloc);
}

// ---------------------------------------------------------------------------
// extractInts — every signed integer scattered in a line
// ---------------------------------------------------------------------------

/// Pulls every integer out of arbitrary text, in order, ignoring everything
/// else — THE universal AoC parser. A '-' immediately followed by a digit
/// starts a negative number, so "x=-3, y: 44" yields {-3, 44} and "3-4"
/// yields {3, -4}. Returns an owned `[]i64` (caller frees).
pub fn extractInts(alloc: std.mem.Allocator, text: []const u8) ![]i64 {
    var out: std.ArrayList(i64) = .empty;
    errdefer out.deinit(alloc);
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        const negative = c == '-' and i + 1 < text.len and std.ascii.isDigit(text[i + 1]);
        if (negative or std.ascii.isDigit(c)) {
            const start = i;
            i += 1; // the '-' or the first digit
            while (i < text.len and std.ascii.isDigit(text[i])) i += 1;
            try out.append(alloc, try std.fmt.parseInt(i64, text[start..i], 10));
        } else {
            i += 1;
        }
    }
    return out.toOwnedSlice(alloc);
}

// ---------------------------------------------------------------------------
// fields — whitespace-separated columns
// ---------------------------------------------------------------------------

fn isBlank(c: u8) bool {
    return c == ' ' or c == '\t';
}

/// Yields the space/tab-separated fields of a line, skipping runs of
/// whitespace (like tokenize, not like split: never yields empty fields).
pub const FieldsIterator = struct {
    rest: []const u8,

    pub fn next(self: *FieldsIterator) ?[]const u8 {
        var r = self.rest;
        while (r.len > 0 and isBlank(r[0])) r = r[1..];
        if (r.len == 0) {
            self.rest = r;
            return null;
        }
        var end: usize = 0;
        while (end < r.len and !isBlank(r[end])) end += 1;
        self.rest = r[end..];
        return r[0..end];
    }
};

pub fn fields(line: []const u8) FieldsIterator {
    return .{ .rest = line };
}

/// The n-th (0-based) whitespace-separated field of a line, or null if the
/// line has fewer fields than that.
pub fn field(line: []const u8, index: usize) ?[]const u8 {
    var it = fields(line);
    var i: usize = 0;
    while (it.next()) |f| : (i += 1) {
        if (i == index) return f;
    }
    return null;
}

// ---------------------------------------------------------------------------
// tests — `zig build test-parse`, or `zig test src/lib/parse.zig`
// ---------------------------------------------------------------------------

const testing = std.testing;

test "lines: basic, with trailing newline" {
    var it = lines("alpha\nbeta\ngamma\n");
    try testing.expectEqualStrings("alpha", it.next() orelse return error.TestExpectedLine);
    try testing.expectEqualStrings("beta", it.next() orelse return error.TestExpectedLine);
    try testing.expectEqualStrings("gamma", it.next() orelse return error.TestExpectedLine);
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "lines: no trailing newline" {
    var it = lines("one\ntwo");
    try testing.expectEqualStrings("one", it.next() orelse return error.TestExpectedLine);
    try testing.expectEqualStrings("two", it.next() orelse return error.TestExpectedLine);
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "lines: preserves interior empty lines" {
    var it = lines("a\n\nb\n");
    try testing.expectEqualStrings("a", it.next() orelse return error.TestExpectedLine);
    try testing.expectEqualStrings("", it.next() orelse return error.TestExpectedLine);
    try testing.expectEqualStrings("b", it.next() orelse return error.TestExpectedLine);
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "lines: empty input yields nothing" {
    var it = lines("");
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "blankLineBlocks: two blocks" {
    var it = blankLineBlocks("1\n2\n\n3\n4\n");
    try testing.expectEqualStrings("1\n2", it.next() orelse return error.TestExpectedBlock);
    try testing.expectEqualStrings("3\n4", it.next() orelse return error.TestExpectedBlock);
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "blankLineBlocks: extra blank lines and messy edges" {
    var it = blankLineBlocks("\n\nfirst\n\n\n\nsecond block\nstill second\n\n\n");
    try testing.expectEqualStrings("first", it.next() orelse return error.TestExpectedBlock);
    try testing.expectEqualStrings("second block\nstill second", it.next() orelse return error.TestExpectedBlock);
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "blankLineBlocks: single block without separator" {
    var it = blankLineBlocks("only\nblock");
    try testing.expectEqualStrings("only\nblock", it.next() orelse return error.TestExpectedBlock);
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "parseIntLines: numbers, negatives, padding, blank lines" {
    const nums = try parseIntLines(testing.allocator, "12\n-7\n\n  40 \n0\n");
    defer testing.allocator.free(nums);
    try testing.expectEqualSlices(i64, &.{ 12, -7, 40, 0 }, nums);
}

test "parseIntLines: rejects a non-numeric line" {
    try testing.expectError(
        error.InvalidCharacter,
        parseIntLines(testing.allocator, "12\nnope\n34\n"),
    );
}

test "extractInts: scattered signed integers" {
    const nums = try extractInts(testing.allocator, "station 7: cal=-284, drift 19 [gain -1042] ok");
    defer testing.allocator.free(nums);
    try testing.expectEqualSlices(i64, &.{ 7, -284, 19, -1042 }, nums);
}

test "extractInts: minus rules" {
    // '-' with no digit after it is noise; between digits it binds to the
    // right-hand number.
    const nums = try extractInts(testing.allocator, "a-b 3-4 --5 -");
    defer testing.allocator.free(nums);
    try testing.expectEqualSlices(i64, &.{ 3, -4, -5 }, nums);
}

test "extractInts: no integers gives an empty slice" {
    const nums = try extractInts(testing.allocator, "nothing to see here");
    defer testing.allocator.free(nums);
    try testing.expectEqual(@as(usize, 0), nums.len);
}

test "fields: spaces and tabs, runs collapsed" {
    var it = fields("  mv\t-13  7\t\t end ");
    try testing.expectEqualStrings("mv", it.next() orelse return error.TestExpectedField);
    try testing.expectEqualStrings("-13", it.next() orelse return error.TestExpectedField);
    try testing.expectEqualStrings("7", it.next() orelse return error.TestExpectedField);
    try testing.expectEqualStrings("end", it.next() orelse return error.TestExpectedField);
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "field: nth column and out of range" {
    try testing.expectEqualStrings("turn", field("turn off 660,55", 0) orelse return error.TestExpectedField);
    try testing.expectEqualStrings("660,55", field("turn off 660,55", 2) orelse return error.TestExpectedField);
    try testing.expectEqual(@as(?[]const u8, null), field("turn off 660,55", 3));
}
