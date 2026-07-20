# Problem 5: Worry Engine

The station's parcel room is run by a chain of sorting machines, and the
machines are... anxious. Each parcel has a **worry level** (a number), and
every time a machine inspects a parcel it fiddles with the level, then
flings the parcel to another machine based on a divisibility test. Your job
is to figure out where all the worry ends up.

`input.txt` describes the machines, one stanza per machine, separated by
blank lines:

```
Machine 0:
  items: 5, 11
  op: old * 3
  div: 2
  true: 1
  false: 2
```

- `items:` — the worry levels of the parcels currently in this machine's
  queue, in the order they'll be processed.
- `op:` — how inspection changes a worry level. It's always `old <sym> <rhs>`
  where `<sym>` is `*` or `+` and `<rhs>` is a number or the word `old`
  (so `old * old` squares it).
- `div:` — after inspecting, the machine tests whether the (adjusted) worry
  level is **divisible by** this number.
- `true:` / `false:` — the machine the parcel is thrown to, depending on the
  test. A machine never throws to itself.

A **round** works like this: the machines take turns in order 0, 1, 2, ....
On its turn a machine processes **every** parcel currently in its queue, in
order, and ends its turn with an empty queue. Processing one parcel is one
**inspection**: apply the `op`, apply the relief rule (see the parts below),
run the `div` test, throw the parcel. Note that a parcel thrown to a
later-numbered machine gets processed again **in the same round**, when that
machine's turn comes.

Count every inspection each machine performs. The answer to both parts is
the **stress rating**: the product of the two highest inspection counts.

## Part 1

You're so relieved a parcel survived inspection that its worry level is
**divided by 3** (rounding down) after every inspection, before the `div`
test.

Run **20 rounds**. **What is the stress rating — the product of the two
highest inspection counts?**

## Part 2

Relief was a luxury. The division by 3 is gone, and now the machines run
**10000 rounds**.

Simulating that naively won't survive contact with the arithmetic: without
relief, the worry levels explode past what even `u128` can hold long before
round 10000. But notice that the *only* thing ever done with a worry level
is the `div` test — what property of those divisibility tests lets you keep
the numbers small without changing a single routing decision?

**What is the stress rating after 10000 rounds?**

## Worked example

`example.txt` has three machines:

```
Machine 0:
  items: 5, 11
  op: old * 3
  div: 2
  true: 1
  false: 2

Machine 1:
  items: 7
  op: old + 4
  div: 3
  true: 2
  false: 0

Machine 2:
  items: 2, 9, 6
  op: old * old
  div: 5
  true: 0
  false: 1
```

Round 1, with Part 1's divide-by-3 relief:

- **Machine 0** inspects `5`: 5 × 3 = 15, relief → 5; 5 is not divisible
  by 2 → thrown to machine 2. Then `11`: 33 → 11, odd → machine 2.
- **Machine 1** inspects `7`: 7 + 4 = 11, relief → 3; divisible by 3 →
  machine 2.
- **Machine 2** started the round with `2, 9, 6` but now also holds
  `5, 11, 3` — all six get processed this round. Squaring plus relief turns
  them into 1, 27, 12, 8, 40, 3; only 40 (from the `11`) is divisible by 5
  and goes to machine 0, the rest go to machine 1.

After round 1 machine 0 holds `40`, machine 1 holds `1, 27, 12, 8, 3`, and
machine 2 is empty; the inspection counts so far are 2, 1, and 6. After 20
rounds the counts are **108, 104, 18**, so Part 1's stress rating is
108 × 104 = **11232**.

For Part 2 — 10000 rounds, no relief — the counts end up at **59989, 20004,
39996**, giving 59989 × 39996 = **2399320044**.

Those are the numbers the `"part1 example"` and `"part2 example"` tests in
`solve.zig` assert. The `"part1"` / `"part2"` tests assert the answers for
your real `input.txt` — green means solved.
