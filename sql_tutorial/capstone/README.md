# Capstone — CityWheels

You've been hired as the first data engineer at **CityWheels**, a bike-share
operator. There is no data team, no warehouse, and no documentation — just a
folder of raw operational exports (`data/raw/`) that ops dumped for you, and a
list of questions the leadership team has been arguing about for months.

Your job: build the analytics foundation from scratch, answer the questions,
and pass the written exam. This is the certifying project for the course —
everything from Modules 1–12 shows up here.

> **⚠️ Do not open `solutions/` until you have finished all three parts.**
> The solutions contain the exact issue counts, the reference queries, and the
> exam answers. Peeking turns a certification into a reading exercise. When
> you're done, `solutions/README.md` explains how to grade yourself.

This capstone deliberately does **not** use the course's Nordkart database.
New domain, new schema, and this time nobody has cleaned the data for you.

## The raw exports

Regenerate them any time (deterministic — same bytes every run):

```bash
python3 data/generate_capstone_data.py
```

| file | contents | condition |
|---|---|---|
| `data/raw/stations.csv` | station master data (id, name, district, lat/lon, capacity) | clean |
| `data/raw/trips_2025.csv` | trips started in 2025, ISO timestamps | **dirty** |
| `data/raw/trips_2026.csv` | trips started Jan–Jun 2026 — same columns, but the vendor "upgraded" the export and timestamps now arrive as `DD/MM/YYYY HH:MM` | **dirty** |
| `data/raw/bikes.csv` | bike master data (id, model, acquired_date) | clean |
| `data/raw/maintenance.csv` | workshop log (id, bike, date, type, cost) | clean |

Note what the trip exports do **not** have: a rider id. CityWheels doesn't
track identity per trip — only `user_type` (member vs casual) and the rider's
birth year as entered at signup.

### What ops told you over coffee

Treat these as leads, not a complete list — part of your job is finding
everything:

- "The export job sometimes retries and writes rows twice."
- "Docking-clock bug: a few trips look like they ended before they started."
- "Field staff type station names by hand on the repair tablets… casing and
  stray spaces everywhere."
- "There was a temporary **pop-up dock** at the June 2025 festival. It was
  never added to the station registry."
- "Finance swears some casual trips were mispriced last year."
- "Blank prices on member trips are *probably* fine — members ride free below
  the time cap."

### Pricing rules (from the current rate card)

- **Casual**: \$1.00 unlock fee + \$0.15 per started minute.
- **Member**: rides up to 45 minutes are included (price 0);
  \$0.10 per started minute beyond 45.

---

## Part A — Schema & Load (32 points)

Design the database, load the raw files, clean them defensibly. Work in a new
directory (e.g. `capstone/work/`) and produce a database named
`citywheels.db`.

**Deliverables** (exact files):

1. **`schema.sql`** — everything DDL:
   - *Staging tables* that mirror the CSVs (all-TEXT columns — staging
     receives files as they are; typing happens on the way out).
   - *Final tables* in a normalized design: `stations`, `bikes`,
     `maintenance`, `trips`. Trips must reference stations and bikes **by id,
     not by name**. Declare primary keys, foreign keys, `NOT NULL`, `UNIQUE`,
     and `CHECK` constraints that encode the business rules you can defend
     (valid `user_type` values, non-negative cost/price, sane coordinates,
     `ended_at >= started_at`, …).
   - A *quarantine table* holding raw rows you refuse to load, verbatim, with
     a `reject_reason`. Broken rows get quarantined, never silently deleted.
   - Indexes you expect your Part B queries to need (justify each in a
     comment).
2. **`load.sql`** — runnable end-to-end with
   `sqlite3 citywheels.db ".read load.sql"`:
   - Import all five CSVs into staging with the CLI's `.import --csv --skip 1`.
   - Normalize the 2026 timestamps to ISO-8601 (`YYYY-MM-DD HH:MM:SS`) so both
     years compare, sort, and `strftime()` identically.
   - Remove exact-duplicate export rows.
   - Resolve trip station names against `stations` with trimming and
     case-insensitive matching.
   - Case-fold `user_type` to exactly `member` / `casual`.
   - Decide and **document in comments** a policy for: blank birth years,
     absurd birth years, blank prices, trips at stations that don't exist,
     and trips that end before they start. (Repair what you can defend,
     quarantine what you can't.)
3. **`quality_report.sql`** — one runnable report that counts **every issue
   class you found**, plus a reconciliation line proving
   `raw rows = duplicates removed + quarantined + loaded`. If your pipeline
   ran twice, this report is how you'd notice.

**Self-check before moving on**: your report should account for every single
raw row, and `SELECT COUNT(*) FROM trips` should land within a couple hundred
below 21,000. (Exact reference counts are in the solutions — after you're
done.)

**Scoring** — schema & constraints /10 · staging + load mechanics /10 ·
cleaning decisions & quarantine /8 · quality report & reconciliation /4.

---

## Part B — Analysis (48 points, 4 each)

Answer with a single SQL statement each (CTEs encouraged; one final `SELECT`).
Run against your cleaned `citywheels.db`. For each: the query, the output,
and 1–3 sentences of interpretation a non-analyst could act on.

1. **Commuter corridors.** The 10 most-ridden station *pairs*
   (start → end, direction matters, round trips excluded), with counts.
2. **Median trip duration by district** (of the start station). Medians, not
   averages — but show the mean beside it and explain the gap.
3. **Member vs casual profile.** One row per user type: trip count, average
   duration, % of trips on weekends, % during commute hours (07–09, 16–18),
   average price, total revenue.
4. **Rebalancing hotspots.** For each station × hour of day: departures,
   arrivals, and net outflow. Show the 10 most imbalanced station-hours.
   Which stations drain in the morning, which flood?
5. **Busiest continuous 3-hour window per station.** Using windowed counts
   over an hour-of-day grid (windows must not wrap past midnight), find each
   station's busiest 3-hour departure window; show the top 10 stations.
   Careful: hours with zero departures still count in a window.
6. **Year-over-year growth.** Monthly trip counts Jan–Jun 2025 vs Jan–Jun
   2026 side by side with growth %. (Only works if your Part A timestamp fix
   was right.)
7. **Idle-bike detection.** Using gaps-and-islands thinking: the 10 longest
   idle gaps between consecutive trips of the same bike. What would you do
   with this list?
8. **Bike utilization.** Share of time each bike spent in use since
   `max(acquired_date, 2025-01-01)`. Top 10 bikes plus the fleet-wide
   figure.
9. **Peak load.** The maximum number of bikes simultaneously in use, and when
   it happened. (Hint: +1/−1 events and a running sum.)
10. **Bike cohort retention.** For bikes acquired 2025-01-01 or later, group
    into acquisition-month cohorts and show the % of each cohort active
    (≥1 trip) in months 0–4 after acquisition.
11. **Wear and tear.** Do heavily-ridden bikes cost more in the workshop?
    Bucket full-period bikes (acquired before 2025) into usage quintiles and
    compare average maintenance visits and cost per quintile.
12. **Price audit.** Using the rate card above, compute each trip's expected
    price and flag trips deviating by more than \$0.50. How many anomalies,
    in what direction, and what's the revenue impact?

**Scoring per question**: correct result 2 · sound technique (no fan-out, no
silent NULL loss, windows where windows belong) 1 · interpretation 1.

---

## Part C — Written exam (20 points, 1 each)

Closed-book: no running queries, no looking back at the modules. Write your
answers down *before* opening the solutions.

1. Suppose you had kept `start_station_name` **and** the station's `district`
   directly on every trip row. Which normal form does that violate, and what
   concrete update anomaly does it invite?
2. Why is a surrogate `trip_id` a safer primary key for `trips` than the
   natural composite `(bike_id, started_at)`? Give one realistic failure of
   the composite.
3. Complete the truth table: `TRUE AND NULL`, `FALSE AND NULL`,
   `TRUE OR NULL`, `FALSE OR NULL`, `NOT NULL`, `NULL = NULL`.
4. After your load, some `user_birth_year` values are NULL. Does
   `WHERE user_birth_year >= 1990 OR user_birth_year < 1990` match every trip?
   Explain.
5. For the trips table, what do `COUNT(*)`, `COUNT(user_birth_year)`, and
   `COUNT(DISTINCT user_birth_year)` each count?
6. For `SELECT * FROM trips WHERE bike_id = 1233 ORDER BY started_at;` —
   which single index serves it best: (a) `(started_at)`, (b) `(bike_id)`,
   (c) `(bike_id, started_at)`, (d) `(started_at, bike_id)`? Why does (c)
   beat (b) *and* (d)?
7. Why can an index on `trips(started_at)` not accelerate
   `WHERE strftime('%Y', started_at) = '2026'`? Rewrite the predicate so it
   can.
8. One query's plan says `SCAN trips`; another says
   `SEARCH trips USING INDEX idx_trips_bike_started (bike_id=?)`. What is the
   difference in access pattern, and which one's cost grows linearly with the
   table?
9. Predict the final state:
   ```sql
   BEGIN;
   UPDATE bikes SET model = 'X-99' WHERE bike_id = 1001;
   SAVEPOINT s1;
   DELETE FROM maintenance;
   ROLLBACK TO s1;
   COMMIT;
   ```
10. A dock has 2 free slots and two trips try to end there at once. Why must
    "check free capacity, then record the docking" run inside a single
    transaction?
11. Spot the bug and fix it:
    ```sql
    SELECT b.bike_id,
           SUM(t.price) AS revenue,
           SUM(m.cost)  AS maintenance_cost
    FROM bikes b
    JOIN trips t        ON t.bike_id = b.bike_id
    JOIN maintenance m  ON m.bike_id = b.bike_id
    GROUP BY b.bike_id;
    ```
12. You LEFT JOIN `stations` to `trips` to include stations with zero trips,
    then add `WHERE t.user_type = 'member'`. The zero-trip stations vanish.
    Why, and what's the fix?
13. Three trips have prices 12, 12, 10. In `ORDER BY price DESC`, what do
    `ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()` return for each row?
14. Why is `WHERE ROW_NUMBER() OVER (...) = 1` a syntax error, and what is
    the standard pattern to filter on a window function?
15. What is the difference between `WHERE` and `HAVING`, which is evaluated
    first, and give an example predicate that is legal in only one of them.
16. `bikes.serial_number` is declared `UNIQUE` but nullable. How many NULL
    serials will SQLite accept, and why is that consistent with NULL
    semantics?
17. In SQLite, what happens to an insert that violates a declared foreign key
    when `PRAGMA foreign_keys` is OFF (the default)? What does that mean for
    every load script you write?
18. The 2026 vendor timestamps (`DD/MM/YYYY HH:MM`) were unusable for
    ordering and comparison even as strings. What property of ISO-8601 text
    makes it safe, and show one comparison the vendor format gets wrong.
19. Critique this query — find at least four distinct problems:
    ```sql
    select * from trips t, stations s
    where t.start_station_id=s.station_id and price>0 order by 2;
    ```
20. Your quality report could be a `VIEW` or a materialized table. Name one
    advantage of each choice for this use case.

---

## Grading rubric

| part | points | what mastery looks like |
|---|---|---|
| A — Schema & Load | 32 | every raw row accounted for; constraints that would actually reject bad data; documented cleaning policies |
| B — Analysis | 48 | correct numbers **and** correct technique; interpretations a manager could act on |
| C — Written exam | 20 | crisp, mechanism-level explanations, not memorized slogans |
| **Total** | **100** | **Mastery = ≥ 85** |

Self-assessment guidance:

- Grade Part A against `solutions/quality_report.sql` output — if your counts
  differ, find out *why* before awarding yourself the points (your policy may
  legitimately differ; your arithmetic may not).
- Part B: your numbers should match the solutions exactly where the question
  is fully specified; award technique points honestly (a right answer via an
  accidental fan-out that cancels out is not a right answer).
- Part C: half-credit answers ("it's faster") don't count; the mechanism does.
- Scores 70–84: revisit the modules the misses map to, then redo those parts
  cold a week later. Below 70: redo the capstone from scratch after review —
  it's designed to be rebuilt (`python3 data/generate_capstone_data.py`).

When (and only when) you're done: open [`solutions/`](solutions/README.md).
