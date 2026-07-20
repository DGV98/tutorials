//! Exercise 06 (capstone): Group anagrams
//!
//! Concepts: combine sorting + StringHashMap + ArrayList, getOrPut with
//! owned keys, and a clear ownership contract across a data structure.
//!
//! Run: zig test 06_anagram_groups.zig
//!
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.hash_map.StringHashMap
//!       https://ziglang.org/documentation/0.16.0/std/#std.array_list.ArrayList

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

// THE DESIGN
//
// "eat", "tea", and "ate" are anagrams: they contain the same letters.
// Sort each word's bytes and all three collapse to the same string,
// "aet". That sorted string is a perfect hash map key:
//
//     "eat" -> "aet"     "tan" -> "ant"     "bat" -> "abt"
//     "tea" -> "aet"     "nat" -> "ant"
//     "ate" -> "aet"
//
//     map: "aet" -> ["eat", "tea", "ate"]
//          "ant" -> ["tan", "nat"]
//          "abt" -> ["bat"]
//
// So the structure is StringHashMap(std.ArrayList([]const u8)):
// hash map from sorted-key to a growable list of the original words.
//
// THE OWNERSHIP CONTRACT (this is the real lesson)
//
//   - Keys: allocated by sortedKey, OWNED BY THE MAP. deinitGroups
//     frees them.
//   - Values: ArrayLists owned by the map; deinitGroups deinits them.
//   - The []const u8 words INSIDE the lists are borrowed from the
//     caller's `words` slice — never freed here, so the input must
//     outlive the map.
//
// One subtlety: when getOrPut finds an EXISTING group, the fresh sorted
// key you just allocated is redundant — the map already owns an equal
// one. Free it, or you leak one key per duplicate group member.

pub const GroupMap = std.StringHashMap(std.ArrayList([]const u8));

/// Return `word` with its bytes sorted ascending, in newly allocated
/// memory the caller owns. "listen" -> "eilnst".
pub fn sortedKey(alloc: std.mem.Allocator, word: []const u8) ![]u8 {
    const key = try alloc.dupe(u8, word);
    std.mem.sort(u8, key, {}, comptime std.sort.asc(u8));
    return key;
}

/// Group `words` by anagram class. Release the result with deinitGroups.
pub fn groupAnagrams(alloc: std.mem.Allocator, words: []const []const u8) !GroupMap {
    var groups = GroupMap.init(alloc);
    errdefer deinitGroups(&groups);

    for (words) |word| {
        const key = try sortedKey(alloc, word);
        const gop = try groups.getOrPut(key);
        if (gop.found_existing) {
            // The map already owns an identical key; ours is a duplicate.
            alloc.free(key);
        } else {
            // Fresh slot: value_ptr is UNINITIALIZED until we write it.
            gop.value_ptr.* = .empty;
        }
        try gop.value_ptr.append(alloc, word);
    }
    return groups;
}

/// Tear-down that honors the ownership contract above: free every key
/// we allocated, deinit every list, then the map itself. The words
/// inside the lists belong to the caller, so they are left alone.
pub fn deinitGroups(groups: *GroupMap) void {
    const alloc = groups.allocator; // managed maps remember their allocator
    var it = groups.iterator();
    while (it.next()) |entry| {
        alloc.free(entry.key_ptr.*);
        entry.value_ptr.deinit(alloc);
    }
    groups.deinit();
}

test "sortedKey sorts the bytes of a word" {
    const alloc = std.testing.allocator;
    const key = try sortedKey(alloc, "listen");
    defer alloc.free(key);
    try expectEqualStrings("eilnst", key);
}

test "groupAnagrams: the classic example" {
    const alloc = std.testing.allocator;
    const words = [_][]const u8{ "eat", "tea", "tan", "ate", "nat", "bat" };

    var groups = try groupAnagrams(alloc, &words);
    defer deinitGroups(&groups);

    try expectEqual(3, groups.count());

    const eat_group = groups.get("aet") orelse return error.TestExpectedGroup;
    try expectEqual(3, eat_group.items.len);
    try expectEqualStrings("eat", eat_group.items[0]);
    try expectEqualStrings("tea", eat_group.items[1]);
    try expectEqualStrings("ate", eat_group.items[2]);

    const tan_group = groups.get("ant") orelse return error.TestExpectedGroup;
    try expectEqual(2, tan_group.items.len);

    const bat_group = groups.get("abt") orelse return error.TestExpectedGroup;
    try expectEqual(1, bat_group.items.len);

    // Lookups use the SORTED form; the raw word is not a key.
    try expectEqual(null, groups.getPtr("eat"));
}

test "groupAnagrams: duplicate keys don't leak" {
    const alloc = std.testing.allocator;
    // Three words map to the key "ab" — two of the freshly allocated
    // keys are redundant and must be freed inside groupAnagrams, or
    // std.testing.allocator will report the leak.
    const words = [_][]const u8{ "ab", "ba", "ab", "abc" };

    var groups = try groupAnagrams(alloc, &words);
    defer deinitGroups(&groups);

    try expectEqual(2, groups.count());
    const ab_group = groups.get("ab") orelse return error.TestExpectedGroup;
    try expectEqual(3, ab_group.items.len);
}
