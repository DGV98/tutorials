# Capstone Solutions — How to Self-Grade

**If you haven't finished all three parts, close this folder.** Every number
below is a spoiler.

## What's in here

| file | contents |
|---|---|
| `schema.sql` | reference DDL: staging, final tables + constraints, quarantine, indexes |
| `load.sql` | reference import + cleaning pipeline (runnable end-to-end) |
| `quality_report.sql` | reference data-quality report |
| `build.sh` | rebuilds `citywheels.db` from nothing (see below) |
| `answers_partB.md` | the 12 analysis queries, their real outputs, interpretations |
| `answers_partC.md` | the 20 exam answers |
| `citywheels.db` | the database the reference pipeline produces |

Rebuild everything from raw with one command (deterministic — you get exactly
the numbers below):

```bash
bash capstone/solutions/build.sh
```

## Reference numbers (verified by running the pipeline)

Your Part A quality report should reconcile to these. All values come from
executing `schema.sql` + `load.sql` against the generated raw CSVs and
running `quality_report.sql`:

| # | metric | value |
|---|---|---|
| 01 | raw rows, `trips_2025.csv` | **13,291** |
| 02 | raw rows, `trips_2026.csv` | **7,859** |
| 03 | exact-duplicate rows removed by dedup | **208** (131 + 77) |
| 04 | distinct trips after dedup | **20,942** |
| 05 | quarantined: unknown station (`Pop-up Dock 1`) | **14** |
| 06 | quarantined: ended before started | **104** |
| 07 | quarantined total (no row had both defects) | **118** |
| 08 | station-name fields repaired (trim / case-fold) | **1,090** |
| 09 | `user_type` values case-folded | **3,223** |
| 10 | blank `user_birth_year` → NULL | **628** |
| 11 | absurd `user_birth_year` (1900 / 2020) → NULL | **125** |
| 12 | blank member price imputed to 0.00 | **60** |
| 13 | final rows: `stations` | **60** |
| 14 | final rows: `bikes` | **350** |
| 15 | final rows: `maintenance` | **608** |
| 16 | final rows: `trips` | **20,824** |
| 17 | reconciliation `20,942 − 118 − 20,824` | **0** |

Footnotes worth knowing when comparing against your own counts:

- The generator injects **1,091** dirty station-name fields; metric 08 shows
  1,090 because one of them sits on a quarantined pop-up-dock row and never
  reaches the repair path. If you counted over *all* deduped rows rather than
  station-matched ones, 1,091 is also correct — say which population you
  counted.
- Injected bad birth years total 753 (628 blank + 125 absurd); the final
  `trips` table has **749** NULL birth years because 4 of the bad values were
  on quarantined rows.
- The Part B price audit should find exactly **30** anomalies: 18 casual
  trips charged \$0.00 (−\$103.95 uncollected) and 12 casual trips charged
  10× the rate card (+\$475.20 overcharged). Member trips are anomaly-free —
  which retroactively validates imputing blank member prices as 0.00.

## Grading yourself

Use the rubric in `../README.md` (A/32, B/48, C/20 — mastery ≥ 85).

**Part A (32).** Compare your quality report to the table above.
- Counts match and reconcile to zero → full marks on load mechanics.
- Counts differ: diagnose before scoring. A *policy* difference (e.g. you
  quarantined absurd birth years instead of nulling them — defensible if
  documented) still earns the points; an *arithmetic* difference (rows lost
  without a reason, dedup that also removed non-duplicates, a reconciliation
  that doesn't hit zero) does not.
- Schema points require constraints that would actually fire: PKs, FKs (and
  `PRAGMA foreign_keys = ON` in the load — without it they're decoration),
  CHECKs on `user_type`, price ≥ 0, `ended_at >= started_at`.

**Part B (48, 4 per question).** For each: 2 pts if your numbers match
`answers_partB.md` (exact where fully specified; top-N lists must have the
same members and values), 1 pt for technique (windows where windows belong,
aggregation before joins, dense grids under sliding frames, NULL guards),
1 pt for an interpretation that says what CityWheels should *do*. If your
number differs, run both queries and find the row that explains it — that
diagnosis is the most instructive hour of the whole course.

**Part C (20, 1 each).** Check against `answers_partC.md`. Full point only
for mechanism-level answers (the *why*), as noted at the top of that file.

## If you want a clean rerun

The whole capstone is regenerable: `build.sh` re-runs the (seeded,
deterministic) generator, rebuilds the schema, reloads, and reprints the
quality report. Delete your working directory, rebuild, and take another
pass at any part you scored below 85% on.
