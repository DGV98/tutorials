# Problem 3: Badge Audit

Security at the supply depot runs on printed badges. Every badge carries a
string of **item codes** — letters, one per authorized item — and the
printer has been misbehaving. You've been handed the day's badge log
(`input.txt`, one badge per line) and asked to audit it.

Every item code has a **clearance value**: `a` through `z` are worth 1
through 26, and `A` through `Z` are worth 27 through 52.

## Part 1

Each badge string has an even length and is really two stamps: the first
half came from the front printer and the second half from the back printer.
The printers are supposed to produce disjoint item lists, but on every badge
in the log **exactly one item code appears in both halves** — that's the
misprint. (How many *times* it appears doesn't matter, only that it shows up
in both halves.)

Find the duplicated code on each badge. **What is the sum of their clearance
values?**

## Part 2

The badges were issued to work crews of three, on three consecutive lines of
the log — the line count is a multiple of three. Each crew shares a single
**crew sticker**: the one item code that appears somewhere on **all three**
badges of the group. No other code is common to all three.

Find each crew's sticker. **What is the sum of the stickers' clearance
values?**

## Worked example

`example.txt`:

```
abcrrxyz
rmnqqstu
defrfghi
jkZllmno
pqrssZtu
ZvwBBcde
```

Part 1 — splitting each badge in half and finding the code in both halves:

| Badge      | Halves            | Common | Clearance |
| ---------- | ----------------- | ------ | --------- |
| `abcrrxyz` | `abcr` / `rxyz`   | `r`    | 18        |
| `rmnqqstu` | `rmnq` / `qstu`   | `q`    | 17        |
| `defrfghi` | `defr` / `fghi`   | `f`    | 6         |
| `jkZllmno` | `jkZl` / `lmno`   | `l`    | 12        |
| `pqrssZtu` | `pqrs` / `sZtu`   | `s`    | 19        |
| `ZvwBBcde` | `ZvwB` / `Bcde`   | `B`    | 28        |

18 + 17 + 6 + 12 + 19 + 28 = **100**.

Part 2 — two crews of three lines each. The only code on all of the first
three badges is `r` (18); the only code on all of the last three is `Z`
(52). 18 + 52 = **70**.

Those are the numbers the `"part1 example"` and `"part2 example"` tests in
`solve.zig` assert. The `"part1"` / `"part2"` tests assert the answers for
your real `input.txt` — green means solved.
