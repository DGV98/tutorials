# Problem 2: Signal Grid

The plateau is dotted with a dense square grid of signal masts, one per cell,
and your survey drone has just mapped their heights: a grid of digits where
`0` is a stub and `9` is a full-height tower (`input.txt`).

Ground control has two questions about this forest of steel. First, a
maintenance question: which masts can be inspected *from outside the grid*
with a telescope, without flying in? Second, a placement question: which
existing mast would make the best relay site, based on how much of the grid
it can see?

## Part 1

A mast is **visible from outside the grid** if, in at least one of the four
cardinal directions (up, down, left, right), every mast between it and the
edge of the grid is **strictly shorter** than it. Masts on the edge are
therefore always visible — there's nothing in the way in at least one
direction.

Only look straight along rows and columns; no diagonals.

**How many masts are visible from outside the grid?**

## Part 2

For the relay site you care about the view *from* a mast, looking out. In
each of the four directions, count how many masts it can see: walk away from
it and count every mast until you reach one **as tall as it or taller** (that
blocking mast is still counted — you can see it, just nothing behind it) or
you fall off the edge. If a mast sits on the edge, its count in that
direction is 0.

A mast's **coverage score** is the product of its four viewing distances.

**What is the highest coverage score of any mast?**

## Worked example

`example.txt`:

```
21012
39457
26801
17342
25060
```

Part 1: the 16 masts around the border are all visible by definition. Of the
9 interior masts, every one has a clear line to some edge except the `0` at
row 2, column 3 (counting from 0): it's walled in by `5` above, `4` below,
`8` to the left and `1` to the right — and *anything* is at least as tall as
a `0`. So 16 + 8 = **24** masts are visible.

Part 2: the best relay is the `8` in the very center (row 2, column 2). It
sees 2 masts in every direction — `4`, `0` going up, `3`, `0` going down,
`6`, `2` going left, `0`, `1` going right — reaching the edge each time
without ever being blocked. Its coverage score is 2 × 2 × 2 × 2 = **16**, and
no other mast beats that.

Those are the numbers the `"part1 example"` and `"part2 example"` tests in
`solve.zig` assert. The `"part1"` / `"part2"` tests assert the answers for
your real `input.txt` — green means solved.
