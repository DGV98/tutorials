//! wordcount library — the counting logic, kept separate from the CLI so it
//! can be unit-tested. By convention root.zig is the root source file of a
//! package's importable module; only `pub` declarations here are visible to
//! importers.

const std = @import("std");

/// The result of counting a chunk of text.
pub const Counts = struct {
    lines: usize,
    words: usize,
    bytes: usize,
};

/// Counts lines, words, and bytes in `text`, with the same rules as wc(1):
/// a line is a '\n' byte, a word is a maximal run of non-whitespace.
pub fn count(text: []const u8) Counts {
    return .{
        .lines = countLines(text),
        .words = countWords(text),
        .bytes = text.len,
    };
}

fn countLines(text: []const u8) usize {
    var n: usize = 0;
    for (text) |byte| {
        if (byte == '\n') n += 1;
    }
    return n;
}

fn countWords(text: []const u8) usize {
    var it = std.mem.tokenizeAny(u8, text, " \t\r\n");
    var n: usize = 0;
    while (it.next()) |_| n += 1;
    return n;
}

test "empty input counts to zero" {
    const c = count("");
    try std.testing.expectEqual(@as(usize, 0), c.lines);
    try std.testing.expectEqual(@as(usize, 0), c.words);
    try std.testing.expectEqual(@as(usize, 0), c.bytes);
}

test "counts a small sample like wc does" {
    const c = count("one two three\nfour five\n");
    try std.testing.expectEqual(@as(usize, 2), c.lines);
    try std.testing.expectEqual(@as(usize, 5), c.words);
    try std.testing.expectEqual(@as(usize, 24), c.bytes);
}

test "collapses runs of whitespace between words" {
    const c = count("  a\t\tb   c  ");
    try std.testing.expectEqual(@as(usize, 0), c.lines); // no '\n' at all
    try std.testing.expectEqual(@as(usize, 3), c.words);
}
