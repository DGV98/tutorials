//! parse.zig — input-parsing helpers for the AoC toolkit.  MILESTONE 1
//!
//! Everything here operates on one `[]const u8` blob (usually the whole
//! input file). Iterators slice into the blob without allocating; the
//! `[]i64`-returning functions hand you an owned slice you must free.
//!
//! Inputs are assumed to use plain '\n' line endings.
//!
//! The tests at the bottom are the specification — make them green:
//!   zig build test-parse        (or: zig test src/lib/parse.zig)

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
        // TODO: slice the next line off the front of `self.rest`.
        //
        // Hints:
        //   - std.mem.indexOfScalar(u8, self.rest, '\n') finds the next
        //     newline (module 05). Everything before it is the line;
        //     everything after it is the new `rest`.
        //   - No newline found and rest non-empty? That's the (unterminated)
        //     last line: return it and leave `rest` empty.
        //   - Iterator state lives in `self` — module 11, exercise 01.
        _ = self; // delete once used
        return null;
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
        // TODO: same idea as LinesIterator, but the separator is "\n\n".
        //
        // Hints:
        //   - First skip any leading '\n' bytes (that swallows runs of extra
        //     blank lines). Nothing left afterwards? Return null.
        //   - std.mem.indexOf(u8, r, "\n\n") finds the separator; no hit
        //     means this is the final block — std.mem.trimEnd(u8, r, "\n")
        //     strips its trailing newline (module 12, problem 1 did all of
        //     this inline; now it becomes a tool).
        _ = self; // delete once used
        return null;
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
    // TODO: lines() + std.mem.trim + std.fmt.parseInt(i64, ...) into an
    // ArrayList, then toOwnedSlice (modules 05, 08).
    //
    // Hint: `var out: std.ArrayList(i64) = .empty;` + `errdefer
    // out.deinit(alloc);` — on the error path the list must not leak
    // (module 07). toOwnedSlice hands ownership to the caller.
    _ = alloc; // delete once used
    _ = text; // delete once used
    return error.Todo;
}

// ---------------------------------------------------------------------------
// extractInts — every signed integer scattered in a line
// ---------------------------------------------------------------------------

/// Pulls every integer out of arbitrary text, in order, ignoring everything
/// else — THE universal AoC parser. A '-' immediately followed by a digit
/// starts a negative number, so "x=-3, y: 44" yields {-3, 44} and "3-4"
/// yields {3, -4}. Returns an owned `[]i64` (caller frees).
pub fn extractInts(alloc: std.mem.Allocator, text: []const u8) ![]i64 {
    // TODO: walk the text byte by byte with an index (a `while` with manual
    // increment, module 02). When you hit a digit — or a '-' whose NEXT byte
    // is a digit — scan to the end of the digit run and parseInt the slice.
    //
    // Hint: std.ascii.isDigit. Get the "minus rules" test green last; the
    // condition for '-' needs both a bounds check and a digit check.
    _ = alloc; // delete once used
    _ = text; // delete once used
    return error.Todo;
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
        // TODO: skip leading blanks, then take bytes up to the next blank
        // (or the end). `isBlank` above is there for you.
        //
        // Hint: this is tokenizeAny(u8, line, " \t") behavior (module 05) —
        // build it yourself here; it's ~10 lines and you'll never wonder
        // what tokenize does again.
        _ = self; // delete once used
        return null;
    }
};

pub fn fields(line: []const u8) FieldsIterator {
    return .{ .rest = line };
}

/// The n-th (0-based) whitespace-separated field of a line, or null if the
/// line has fewer fields than that.
pub fn field(line: []const u8, index: usize) ?[]const u8 {
    // TODO: drive your own fields() iterator and count (module 11:
    // consuming an iterator you wrote).
    _ = line; // delete once used
    _ = index; // delete once used
    return null;
}

// ---------------------------------------------------------------------------
// tests — the specification. `zig build test-parse` runs exactly these.
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
