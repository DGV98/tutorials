# Problem 1: Supply Packs

The research station on the plateau is resupplied by cargo drones, and every
drone carries a stack of battery packs for the instruments up top. Flight
control has handed you the loading list: one long printout where each drone's
manifest is a run of numbers — the charge, in milliamp-hours, of each pack it
carries — and consecutive manifests are separated by a **blank line**.

The station chief wants to know which drone to flag for the priority landing
slot: the one hauling the most total charge.

Your puzzle input is `input.txt`; each line inside a manifest is one integer,
and a blank line ends the manifest and starts the next drone's.

## Part 1

For each drone, total up the charge of all its packs. **What is the largest
total charge carried by a single drone?**

## Part 2

One drone won't cut it — the chief wants redundancy and asks for the *three*
drones carrying the most, combined.

Find the three highest drone totals. **What is the sum of those three
totals?**

## Worked example

`example.txt`:

```
100
200
300

400

500
600

700
800

900
```

Five drones:

| Drone | Packs           | Total    |
| ----- | --------------- | -------- |
| 1     | 100, 200, 300   | 600      |
| 2     | 400             | 400      |
| 3     | 500, 600        | 1100     |
| 4     | 700, 800        | 1500     |
| 5     | 900             | 900      |

The heaviest hauler is drone 4 with **1500** — that's Part 1.

The top three totals are 1500, 1100, and 900, so Part 2 is
1500 + 1100 + 900 = **3500**.

Those are the numbers the `"part1 example"` and `"part2 example"` tests in
`solve.zig` assert. The `"part1"` / `"part2"` tests assert the answers for
your real `input.txt` — green means solved.
