# Problem 4: Hill Route

The last leg of the supply run is on foot: up the hill to the station
itself. Your map (`input.txt`) is a rectangular heightmap where each cell's
elevation is a letter from `a` (lowest) to `z` (highest). Two cells are
special: `S` marks where you're standing (its elevation is `a`) and `E`
marks the station (its elevation is `z`).

Your legs set the rules. From any cell you can step to one of the four
adjacent cells — up, down, left, or right, never diagonally — but you can
only **climb at most one level per step**: a step onto a destination cell is
allowed when its elevation is at most one higher than your current cell's.
Dropping down is unrestricted; you can descend any number of levels in a
single step.

## Part 1

**What is the fewest number of steps needed to get from `S` to `E`?**

## Part 2

Looking at the map again, you notice the start position isn't special — any
lowest-elevation cell would make a fine trailhead, and one of them might
offer a much shorter hike.

Consider every cell with elevation `a` (including `S`) as a possible start.
**What is the fewest number of steps from any such cell to `E`?**

## Worked example

`example.txt`:

```
Sabcdef
mlkjihg
nopqrst
zzyxwvu
zzzzzzE
```

The elevations snake back and forth: `a`–`f` run left-to-right along the top
row, `g`–`m` come back right-to-left along the second, and so on, so the
climb rule funnels you along the switchbacks. One shortest route from `S`
walks the top row to `f`, drops to `g` and doubles back to `m`, crosses to
`t` along the third row, then climbs `u`–`y` on the fourth, cuts down into
the bottom row of `z`s and follows it to `E` — **30** steps, and no route
does better.

For Part 2 there is exactly one other elevation-`a` cell: the `a` directly
right of `S`. Starting there skips one step, so the best hike is **29**
steps.

Those are the numbers the `"part1 example"` and `"part2 example"` tests in
`solve.zig` assert. The `"part1"` / `"part2"` tests assert the answers for
your real `input.txt` — green means solved.
