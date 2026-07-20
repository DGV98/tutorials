//! Exercise 05 (wordcount): the library half of a real Zig package.
//!
//! Concepts: root.zig as a module root, pub vs file-private, tests living
//!           next to the code, `zig build test`.
//!
//! Run the tests:  zig build test   (from the wordcount/ directory)
//!
//! src/main.zig — the CLI — is already written; it imports this module as
//! @import("wordcount") and calls `count`. Your job is the two counting
//! functions below. Once the tests are green, try the whole program:
//!
//!     zig build run -- src/main.zig
//!
//! By convention root.zig is the root source file of a package's importable
//! module; only `pub` declarations here are visible to importers.

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

// Not pub: helpers stay private to the module. main.zig can only see `count`
// and `Counts`.
fn countLines(text: []const u8) usize {
    // TODO: count the '\n' bytes in `text` — the same for loop you wrote in
    // exercise 02.
    _ = text; // remove this line once you use `text`
    return 0;
}

fn countWords(text: []const u8) usize {
    // TODO: a word is a maximal run of non-whitespace. Module 05's tokenizer
    // does the splitting for you:
    //
    //     var it = std.mem.tokenizeAny(u8, text, " \t\r\n");
    //
    // Count how many tokens `it.next()` yields before returning null.
    _ = text; // remove this line once you use `text`
    return 0;
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
