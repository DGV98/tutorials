# Capstone Solutions — Part B (Analysis)

All queries run against `citywheels.db` as built by `build.sh` (schema.sql +
load.sql on the deterministic raw exports). Outputs are pasted verbatim from
`sqlite3 -box`. Trip durations are computed as
`(julianday(ended_at) - julianday(started_at)) * 1440.0` minutes throughout.

## Q1 — Commuter corridors (top station pairs)

```sql
SELECT ss.name          AS start_station,
       es.name          AS end_station,
       COUNT(*)         AS n_trips
FROM trips t
JOIN stations ss ON ss.station_id = t.start_station_id
JOIN stations es ON es.station_id = t.end_station_id
WHERE t.start_station_id <> t.end_station_id
GROUP BY ss.name, es.name
ORDER BY n_trips DESC
LIMIT 10;
```

```text
╭───────────────────────┬─────────────────┬─────────╮
│     start_station     │   end_station   │ n_trips │
╞═══════════════════════╪═════════════════╪═════════╡
│ Student Commons       │ Library Mall    │     140 │
│ Harbor East           │ Old Town Square │     121 │
│ Cedar Park Loop       │ Central Station │     119 │
│ University Gate       │ Central Station │     118 │
│ Northgate Transit Hub │ City Hall       │     113 │
│ Riverside Walk        │ Exchange Street │     103 │
│ Gasometer Park        │ Old Town Square │     101 │
│ Old Town Square       │ Gasometer Park  │      94 │
│ Central Station       │ Old Town Square │      88 │
│ Athletics Center      │ Old Town Square │      75 │
╰───────────────────────┴─────────────────┴─────────╯
```

**Interpretation.** The network has clear commuter corridors: campus-internal
(Student Commons → Library Mall) and residential-to-hub flows into Central
Station, Old Town Square, and City Hall. These are one-directional — only the
Gasometer Park ↔ Old Town Square pair appears in both directions — which is
exactly the pattern that forces manual rebalancing (see Q4). Note the two
joins to `stations` need two different aliases; a single join can't label
both ends.

## Q2 — Median trip duration by district

SQLite has no `MEDIAN()`, so we take the middle row(s) with `ROW_NUMBER`:
for odd counts `(n+1)/2 = (n+2)/2` picks one row, for even counts the
`AVG` spans the two middle rows.

```sql
WITH durations AS (
    SELECT s.district,
           (julianday(t.ended_at) - julianday(t.started_at)) * 1440.0 AS minutes
    FROM trips t
    JOIN stations s ON s.station_id = t.start_station_id
),
ranked AS (
    SELECT district, minutes,
           ROW_NUMBER() OVER (PARTITION BY district ORDER BY minutes) AS rn,
           COUNT(*)     OVER (PARTITION BY district)                  AS n,
           AVG(minutes) OVER (PARTITION BY district)                  AS mean_minutes
    FROM durations
)
SELECT district,
       ROUND(AVG(minutes), 1)      AS median_minutes,
       ROUND(MAX(mean_minutes), 1) AS mean_minutes,
       MAX(n)                      AS n_trips
FROM ranked
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)
GROUP BY district
ORDER BY median_minutes DESC;
```

```text
╭─────────────┬────────────────┬──────────────┬─────────╮
│  district   │ median_minutes │ mean_minutes │ n_trips │
╞═════════════╪════════════════╪══════════════╪═════════╡
│ Westfield   │           14.2 │         18.7 │    2709 │
│ University  │           14.2 │         18.4 │    3227 │
│ Cedar Park  │           14.1 │         18.6 │    1695 │
│ Riverside   │           14.0 │         18.1 │    2202 │
│ Northgate   │           14.0 │         18.6 │    2212 │
│ Midtown     │           14.0 │         18.6 │    2842 │
│ Harborfront │           14.0 │         18.8 │    2669 │
│ Old Town    │           13.9 │         18.2 │    3268 │
╰─────────────┴────────────────┴──────────────┴─────────╯
```

**Interpretation.** Two findings, one boring and one useful. Boring: median
duration is essentially flat across districts (13.9–14.2 min) — geography
doesn't drive trip length here, the member/casual mix does. Useful: the mean
sits ~4.5 minutes above the median everywhere, a classic right-skew signature
(a minority of long casual rides drags the average). Anyone reporting
"average trip ≈ 18–19 minutes" overstates the typical ride by a third —
that's why the question demanded the median.

## Q3 — Member vs casual profile

```sql
SELECT user_type,
       COUNT(*)                                                    AS n_trips,
       ROUND(AVG((julianday(ended_at) - julianday(started_at)) * 1440.0), 1)
                                                                   AS avg_minutes,
       ROUND(100.0 * AVG(strftime('%w', started_at) IN ('0', '6')), 1)
                                                                   AS pct_weekend,
       ROUND(100.0 * AVG(CAST(strftime('%H', started_at) AS INTEGER)
                         IN (7, 8, 9, 16, 17, 18)), 1)             AS pct_commute_hours,
       ROUND(AVG(price), 2)                                        AS avg_price,
       ROUND(SUM(price), 2)                                        AS revenue
FROM trips
GROUP BY user_type;
```

```text
╭───────────┬─────────┬─────────────┬─────────────┬───────────────────┬───────────┬─────────╮
│ user_type │ n_trips │ avg_minutes │ pct_weekend │ pct_commute_hours │ avg_price │ revenue │
╞═══════════╪═════════╪═════════════╪═════════════╪═══════════════════╪═══════════╪═════════╡
│ casual    │    8323 │        27.0 │        34.8 │              43.8 │      5.16 │ 42974.5 │
│ member    │   12501 │        12.8 │        18.3 │              47.2 │      0.01 │    68.3 │
╰───────────┴─────────┴─────────────┴─────────────┴───────────────────┴───────────┴─────────╯
```

(The boolean expressions inside `AVG(...)` evaluate to 0/1, so their average
is directly the share — a tidy trick for percentage columns.)

**Interpretation.** Two different products in one system. Members take 60%
of trips but short, weekday, commute-shaped ones — and being under the 45-min
cap on virtually all of them, they generate almost no per-trip revenue
(essentially all of the \$68 is overage fees; membership fees aren't in this
dataset). Casual riders take twice-as-long, weekend-leaning rides and supply
effectively all per-trip revenue (\$42,975). Pricing or fleet decisions that
optimize for one group will barely touch the other.

## Q4 — Rebalancing hotspots (station × hour imbalance)

```sql
WITH flows AS (
    SELECT start_station_id AS station_id,
           CAST(strftime('%H', started_at) AS INTEGER) AS hour,
           +1 AS delta
    FROM trips
    UNION ALL
    SELECT end_station_id,
           CAST(strftime('%H', ended_at) AS INTEGER),
           -1
    FROM trips
)
SELECT s.name, s.district, f.hour,
       SUM(f.delta = +1)  AS departures,
       SUM(f.delta = -1)  AS arrivals,
       SUM(f.delta)       AS net_outflow
FROM flows f
JOIN stations s ON s.station_id = f.station_id
GROUP BY s.name, s.district, f.hour
ORDER BY ABS(SUM(f.delta)) DESC
LIMIT 10;
```

```text
╭──────────────────┬─────────────┬──────┬────────────┬──────────┬─────────────╮
│       name       │  district   │ hour │ departures │ arrivals │ net_outflow │
╞══════════════════╪═════════════╪══════╪════════════╪══════════╪═════════════╡
│ Old Town Square  │ Old Town    │    9 │        102 │      149 │         -47 │
│ Central Station  │ Midtown     │   16 │         66 │      109 │         -43 │
│ Central Station  │ Midtown     │    9 │         46 │       82 │         -36 │
│ University Gate  │ University  │    8 │         69 │       35 │          34 │
│ Central Station  │ Midtown     │   13 │         49 │       78 │         -29 │
│ Harbor East      │ Harborfront │   16 │         46 │       17 │          29 │
│ Student Commons  │ University  │   11 │         53 │       26 │          27 │
│ Athletics Center │ University  │    8 │         83 │       57 │          26 │
│ Athletics Center │ University  │    7 │         69 │       44 │          25 │
│ Central Station  │ Midtown     │   20 │         45 │       70 │         -25 │
╰──────────────────┴─────────────┴──────┴────────────┴──────────┴─────────────╯
```

**Interpretation.** The morning flow is *into* the hubs: Old Town Square and
Central Station flood with bikes at 09:00 (arrivals far exceeding
departures), while origin stations like University Gate and Athletics Center
drain at 07:00–08:00. The rebalancing van should run hub → periphery
mid-morning. Technique note: turning each trip into a `+1` departure event
and a `-1` arrival event and summing avoids a fragile FULL-OUTER-JOIN
between separate departure and arrival aggregates.

## Q5 — Busiest continuous 3-hour window per station

The frame `ROWS BETWEEN CURRENT ROW AND 2 FOLLOWING` only works if every hour
exists for every station — an hour with zero departures must contribute a 0,
not vanish. So we build a dense station × hour grid first, and only *after*
the window is computed do we discard windows that would wrap past midnight
(start hour > 21). Filtering hours 22–23 before windowing would silently
corrupt the windows starting at 20 and 21.

```sql
WITH RECURSIVE hours (hour) AS (
    SELECT 0
    UNION ALL
    SELECT hour + 1 FROM hours WHERE hour < 23
),
hourly AS (
    SELECT start_station_id AS station_id,
           CAST(strftime('%H', started_at) AS INTEGER) AS hour,
           COUNT(*) AS departures
    FROM trips
    GROUP BY start_station_id, hour
),
grid AS (
    SELECT s.station_id, h.hour, COALESCE(hh.departures, 0) AS departures
    FROM stations s
    CROSS JOIN hours h
    LEFT JOIN hourly hh ON hh.station_id = s.station_id AND hh.hour = h.hour
),
windows AS (
    SELECT station_id, hour AS window_start,
           SUM(departures) OVER (PARTITION BY station_id ORDER BY hour
                                 ROWS BETWEEN CURRENT ROW AND 2 FOLLOWING)
               AS departures_3h
    FROM grid
),
best AS (
    SELECT station_id, window_start, departures_3h,
           ROW_NUMBER() OVER (PARTITION BY station_id
                              ORDER BY departures_3h DESC, window_start) AS rk
    FROM windows
    WHERE window_start <= 21
)
SELECT s.name, s.district,
       printf('%02d:00-%02d:59', b.window_start, b.window_start + 2) AS busiest_window,
       b.departures_3h
FROM best b
JOIN stations s ON s.station_id = b.station_id
WHERE b.rk = 1
ORDER BY b.departures_3h DESC
LIMIT 10;
```

```text
╭───────────────────────┬─────────────┬────────────────┬───────────────╮
│         name          │  district   │ busiest_window │ departures_3h │
╞═══════════════════════╪═════════════╪════════════════╪═══════════════╡
│ Old Town Square       │ Old Town    │ 16:00-18:59    │           482 │
│ Gasometer Park        │ Westfield   │ 16:00-18:59    │           348 │
│ Central Station       │ Midtown     │ 16:00-18:59    │           240 │
│ Athletics Center      │ University  │ 16:00-18:59    │           212 │
│ Pier 12               │ Harborfront │ 16:00-18:59    │           201 │
│ Kayak Launch          │ Riverside   │ 16:00-18:59    │           191 │
│ Student Commons       │ University  │ 16:00-18:59    │           184 │
│ Summit Ridge          │ Northgate   │ 16:00-18:59    │           148 │
│ University Gate       │ University  │ 07:00-09:59    │           141 │
│ Northgate Transit Hub │ Northgate   │ 16:00-18:59    │           134 │
╰───────────────────────┴─────────────┴────────────────┴───────────────╯
```

**Interpretation.** For 9 of the top 10 stations the evening commute
(16:00–18:59) is the busiest departure block — the hubs that *receive* bikes
in the morning (Q4) send them back out in the evening. University Gate is the
lone morning-peaked station, consistent with its role as a residential-side
origin. Staffing and dock-emptying schedules should anchor on the 16:00
block.

## Q6 — Year-over-year growth (Jan–Jun)

This is the question the timestamp fix was for: after normalization,
`strftime()` works identically on both years.

```sql
WITH monthly AS (
    SELECT strftime('%m', started_at)               AS month,
           SUM(strftime('%Y', started_at) = '2025') AS trips_2025,
           SUM(strftime('%Y', started_at) = '2026') AS trips_2026
    FROM trips
    WHERE strftime('%m', started_at) <= '06'
    GROUP BY month
)
SELECT month, trips_2025, trips_2026,
       ROUND(100.0 * (trips_2026 - trips_2025) / trips_2025, 1) AS yoy_pct
FROM monthly
ORDER BY month;
```

```text
╭───────┬────────────┬────────────┬─────────╮
│ month │ trips_2025 │ trips_2026 │ yoy_pct │
╞═══════╪════════════╪════════════╪═════════╡
│ 01    │        620 │        766 │    23.5 │
│ 02    │        643 │        759 │    18.0 │
│ 03    │        807 │       1061 │    31.5 │
│ 04    │       1092 │       1447 │    32.5 │
│ 05    │       1497 │       1776 │    18.6 │
│ 06    │       1463 │       1938 │    32.5 │
╰───────┴────────────┴────────────┴─────────╯
```

**Interpretation.** Ridership is up 18–33% every single month, ~26% for the
half-year overall (6,122 → 7,747 trips) on top of the usual winter→summer
seasonal climb. Growth is broad-based rather than event-driven — a fleet
expansion case, which matches the bike batches acquired in late 2025 and
February 2026.

## Q7 — Idle-bike detection (longest gaps between consecutive trips)

Gaps-and-islands: `LAG(ended_at)` per bike turns the trip log into
(previous end, next start) intervals; the gap is their difference.

```sql
WITH ordered AS (
    SELECT bike_id, started_at,
           LAG(ended_at) OVER (PARTITION BY bike_id ORDER BY started_at)
               AS prev_ended_at
    FROM trips
)
SELECT o.bike_id, b.model,
       o.prev_ended_at,
       o.started_at                                                   AS next_started_at,
       ROUND(julianday(o.started_at) - julianday(o.prev_ended_at), 1) AS idle_days
FROM ordered o
JOIN bikes b ON b.bike_id = o.bike_id
WHERE o.prev_ended_at IS NOT NULL
ORDER BY idle_days DESC
LIMIT 10;
```

```text
╭─────────┬───────────┬─────────────────────┬─────────────────────┬───────────╮
│ bike_id │   model   │    prev_ended_at    │   next_started_at   │ idle_days │
╞═════════╪═══════════╪═════════════════════╪═════════════════════╪═══════════╡
│    1076 │ Volt-E    │ 2025-09-05 08:34:05 │ 2026-04-16 22:02:00 │     223.6 │
│    1180 │ Metro One │ 2025-07-02 11:03:12 │ 2026-01-07 19:11:00 │     189.3 │
│    1301 │ Metro One │ 2025-10-23 16:08:59 │ 2026-04-28 10:19:00 │     186.8 │
│    1182 │ Metro LS  │ 2025-11-12 06:56:50 │ 2026-05-15 22:42:00 │     184.7 │
│    1008 │ Volt-E    │ 2025-08-08 12:18:22 │ 2026-02-04 21:14:00 │     180.4 │
│    1187 │ Metro One │ 2025-01-11 14:17:44 │ 2025-06-28 14:22:20 │     168.0 │
│    1218 │ Metro One │ 2025-09-29 12:57:52 │ 2026-03-14 09:03:00 │     165.8 │
│    1187 │ Metro One │ 2025-07-20 19:28:35 │ 2025-12-26 15:50:30 │     158.8 │
│    1229 │ Metro LS  │ 2025-11-08 06:09:44 │ 2026-04-12 12:23:00 │     155.3 │
│    1183 │ Volt-E    │ 2025-10-27 07:32:03 │ 2026-03-28 16:05:00 │     152.4 │
╰─────────┴───────────┴─────────────────────┴─────────────────────┴───────────╯
```

**Interpretation.** Several bikes sat unridden for 5–7 *months*, mostly
spanning the winter — some of that is low-demand bikes parked at quiet
stations, but gaps this long are indistinguishable from "lost, vandalized, or
forgotten in the warehouse". Operationally: any bike idle > 30 days should
trigger a physical audit; this query is the report that drives it. (Note the
`WHERE prev_ended_at IS NOT NULL` — a bike's first trip has no gap, and
without the guard `julianday(NULL)` rows would sort unpredictably.)

## Q8 — Bike utilization (share of time in use)

```sql
WITH usage AS (
    SELECT bike_id,
           COUNT(*)                                         AS n_trips,
           SUM(julianday(ended_at) - julianday(started_at)) AS days_in_use
    FROM trips
    GROUP BY bike_id
),
service AS (
    SELECT bike_id, model,
           julianday('2026-07-01')
             - MAX(julianday(acquired_date), julianday('2025-01-01'))
               AS days_in_service
    FROM bikes
)
SELECT s.bike_id, s.model,
       COALESCE(u.n_trips, 0)                    AS n_trips,
       ROUND(COALESCE(u.days_in_use, 0) * 24, 1) AS hours_in_use,
       ROUND(s.days_in_service, 0)               AS days_in_service,
       ROUND(100.0 * COALESCE(u.days_in_use, 0) / s.days_in_service, 2)
                                                 AS utilization_pct
FROM service s
LEFT JOIN usage u ON u.bike_id = s.bike_id
ORDER BY utilization_pct DESC
LIMIT 10;
```

```text
╭─────────┬───────────┬─────────┬──────────────┬─────────────────┬─────────────────╮
│ bike_id │   model   │ n_trips │ hours_in_use │ days_in_service │ utilization_pct │
╞═════════╪═══════════╪═════════╪══════════════╪═════════════════╪═════════════════╡
│    1233 │ Metro One │     411 │        122.5 │           500.0 │            1.02 │
│    1201 │ Volt-E    │     289 │         87.1 │           497.0 │            0.73 │
│    1208 │ Volt-E    │     252 │         81.1 │           496.0 │            0.68 │
│    1044 │ Metro LS  │     236 │         79.3 │           546.0 │            0.61 │
│    1327 │ Metro LS  │      54 │         19.5 │           138.0 │            0.59 │
│    1152 │ Metro One │     225 │         69.3 │           546.0 │            0.53 │
│    1011 │ Metro One │     211 │         66.7 │           546.0 │            0.51 │
│    1206 │ Metro LS  │     199 │         60.8 │           497.0 │            0.51 │
│    1077 │ Volt-E    │     203 │         62.1 │           546.0 │            0.47 │
│    1350 │ Metro One │      52 │         16.0 │           141.0 │            0.47 │
╰─────────┴───────────┴─────────┴──────────────┴─────────────────┴─────────────────╯
```

Fleet-wide (same CTEs, aggregated):

```text
╭───────────────────────┬──────────────────╮
│ fleet_utilization_pct │ never_used_bikes │
╞═══════════════════════╪══════════════════╡
│                 0.166 │                0 │
╰───────────────────────┴──────────────────╯
```

**Interpretation.** Even the hardest-working bike is *in use* only ~1% of its
life; the fleet average is 0.17%. That's normal for bike-share (bikes exist
to be *available*, not busy), but the 6× spread between the top bike and the
average is the actionable part: rotation between hot and cold stations would
even out wear. The denominator choice matters — `max(acquired_date,
2025-01-01)` keeps late-2025/2026 bikes (like 1327 and 1350) comparable to
the original fleet instead of penalizing them for months they didn't exist.

## Q9 — Peak load (max bikes simultaneously in use)

Every trip becomes two events: +1 at start, −1 at end. A running sum over
events ordered by time is the number of bikes on the road at every instant;
ordering ties as "ends before starts" (`delta` ascending puts −1 first)
avoids counting a bike as double-present at a shared timestamp.

```sql
WITH events AS (
    SELECT started_at AS ts, +1 AS delta FROM trips
    UNION ALL
    SELECT ended_at, -1 FROM trips
),
running AS (
    SELECT ts, SUM(delta) OVER (ORDER BY ts, delta) AS bikes_in_use
    FROM events
)
SELECT ts AS at_time, bikes_in_use
FROM running
ORDER BY bikes_in_use DESC, ts
LIMIT 5;
```

```text
╭─────────────────────┬──────────────╮
│       at_time       │ bikes_in_use │
╞═════════════════════╪══════════════╡
│ 2025-05-09 17:42:23 │            8 │
│ 2025-05-09 17:50:25 │            8 │
│ 2025-06-19 09:09:08 │            8 │
│ 2025-07-01 08:58:25 │            8 │
│ 2025-07-01 08:59:38 │            8 │
╰─────────────────────┴──────────────╯
```

**Interpretation.** The all-time peak is just **8 of 350 bikes** in use at
once, always in commute peaks (May–July, 08:59 / 17:42). Availability is
nowhere near being the binding constraint — the fleet-size conversation
should be about *station coverage*, not bike count. This +1/−1 running-sum
pattern is the standard interval-concurrency tool; it's O(n log n) instead of
the O(n²) self-join alternative.

## Q10 — Bike cohort retention (acquisition-month cohorts)

The trip exports carry no rider id, so rider cohorts are impossible with this
data — the cohort-worthy entity we *do* have is the bike. Cohort = acquisition
month (2025+ batches, which fall fully inside the observation window);
"retained" = at least one trip in month *n* after acquisition.

```sql
WITH cohorts AS (
    SELECT bike_id,
           strftime('%Y-%m', acquired_date) AS cohort,
           CAST(strftime('%Y', acquired_date) AS INTEGER) * 12
             + CAST(strftime('%m', acquired_date) AS INTEGER) AS cohort_idx
    FROM bikes
    WHERE acquired_date >= '2025-01-01'
),
active AS (
    SELECT DISTINCT c.cohort, c.bike_id,
           CAST(strftime('%Y', t.started_at) AS INTEGER) * 12
             + CAST(strftime('%m', t.started_at) AS INTEGER)
             - c.cohort_idx AS month_n
    FROM cohorts c
    JOIN trips t ON t.bike_id = c.bike_id
),
sizes AS (
    SELECT cohort, COUNT(*) AS n_bikes FROM cohorts GROUP BY cohort
)
SELECT a.cohort, s.n_bikes,
       ROUND(100.0 * SUM(a.month_n = 0) / s.n_bikes) AS m0_pct,
       ROUND(100.0 * SUM(a.month_n = 1) / s.n_bikes) AS m1_pct,
       ROUND(100.0 * SUM(a.month_n = 2) / s.n_bikes) AS m2_pct,
       ROUND(100.0 * SUM(a.month_n = 3) / s.n_bikes) AS m3_pct,
       ROUND(100.0 * SUM(a.month_n = 4) / s.n_bikes) AS m4_pct
FROM active a
JOIN sizes s ON s.cohort = a.cohort
GROUP BY a.cohort, s.n_bikes
ORDER BY a.cohort;
```

```text
╭─────────┬─────────┬────────┬────────┬────────┬────────┬────────╮
│ cohort  │ n_bikes │ m0_pct │ m1_pct │ m2_pct │ m3_pct │ m4_pct │
╞═════════╪═════════╪════════╪════════╪════════╪════════╪════════╡
│ 2025-02 │      50 │   64.0 │   90.0 │   94.0 │   98.0 │   98.0 │
│ 2025-06 │      40 │   88.0 │  100.0 │   95.0 │   98.0 │   95.0 │
│ 2025-10 │      30 │   57.0 │   80.0 │   73.0 │   80.0 │   93.0 │
│ 2026-02 │      30 │   70.0 │   87.0 │   90.0 │   97.0 │  100.0 │
╰─────────┴─────────┴────────┴────────┴────────┴────────┴────────╯
```

**Interpretation.** Unlike customer cohorts (which decay), bike cohorts
*ramp up*: month 0 is partial (a bike acquired on the 14th had half a month)
and adoption climbs as bikes get distributed. The June 2025 cohort activated
fastest (88% in its first partial month — summer demand); the October cohort
slowest (57%, and it wobbles through the winter before hitting 93% by
February). Lesson for deployments: bikes commissioned into winter sit idle —
schedule fleet additions for spring.

## Q11 — Wear and tear: maintenance cost vs usage

Only bikes acquired before 2025 (in service the whole window) are compared,
so the quintiles measure usage intensity, not tenure. `NTILE(5)` buckets by
trip count; then each bucket's maintenance profile is averaged.

```sql
WITH usage AS (
    SELECT b.bike_id, COUNT(t.trip_id) AS n_trips
    FROM bikes b
    LEFT JOIN trips t ON t.bike_id = b.bike_id
    WHERE b.acquired_date <= '2025-01-01'
    GROUP BY b.bike_id
),
maint AS (
    SELECT bike_id, COUNT(*) AS n_visits, SUM(cost) AS total_cost
    FROM maintenance
    GROUP BY bike_id
),
quintiled AS (
    SELECT u.bike_id, u.n_trips,
           COALESCE(m.n_visits, 0)   AS n_visits,
           COALESCE(m.total_cost, 0) AS total_cost,
           NTILE(5) OVER (ORDER BY u.n_trips) AS usage_quintile
    FROM usage u
    LEFT JOIN maint m ON m.bike_id = u.bike_id
)
SELECT usage_quintile,
       COUNT(*)                   AS n_bikes,
       ROUND(AVG(n_trips), 1)     AS avg_trips,
       ROUND(AVG(n_visits), 2)    AS avg_maint_visits,
       ROUND(AVG(total_cost), 2)  AS avg_maint_cost
FROM quintiled
GROUP BY usage_quintile
ORDER BY usage_quintile;
```

```text
╭────────────────┬─────────┬───────────┬──────────────────┬────────────────╮
│ usage_quintile │ n_bikes │ avg_trips │ avg_maint_visits │ avg_maint_cost │
╞════════════════╪═════════╪═══════════╪══════════════════╪════════════════╡
│              1 │      40 │      19.8 │             0.85 │           33.7 │
│              2 │      40 │      35.9 │             1.07 │          49.91 │
│              3 │      40 │      55.7 │             1.55 │           62.7 │
│              4 │      40 │      80.9 │             2.25 │          78.93 │
│              5 │      40 │     133.5 │             3.33 │         120.85 │
╰────────────────┴─────────┴───────────┴──────────────────┴────────────────╯
```

**Interpretation.** Cleanly monotonic: the busiest quintile rides ~6.7× more
than the quietest and costs ~3.6× more in the workshop. Maintenance scales
with usage but *sub-linearly* — cost per trip actually falls (≈\$1.70 →
≈\$0.91), so working bikes harder is efficient, reinforcing the rotation
idea from Q8. Two silent-bug guards mattered here: `COUNT(t.trip_id)` (not
`COUNT(*)`) so a LEFT-JOIN miss counts 0, and `COALESCE` on the maintenance
side for bikes never serviced. And note the two facts (trips, maintenance)
were aggregated in *separate* CTEs before joining — joining both raw tables
to bikes first would fan out trips × visits and inflate every number (that
trap is Part C, Q11).

## Q12 — Price audit

Expected price from the rate card, recomputed per trip; "started minute"
means we bill the ceiling of the duration. Anomaly = deviation > \$0.50
(generous enough to forgive the minute-precision loss in the 2026 export).

```sql
WITH priced AS (
    SELECT trip_id, user_type, price, started_at,
           CAST((julianday(ended_at) - julianday(started_at)) * 1440.0
                + 0.9999 AS INTEGER)                  AS billed_minutes
    FROM trips
),
expected AS (
    SELECT *,
           CASE WHEN user_type = 'casual'
                THEN ROUND(1.00 + 0.15 * billed_minutes, 2)
                WHEN billed_minutes <= 45
                THEN 0.00
                ELSE ROUND(0.10 * (billed_minutes - 45), 2)
           END AS expected_price
    FROM priced
)
SELECT CASE WHEN price = 0              THEN 'charged nothing'
            WHEN price > expected_price THEN 'overcharged'
            ELSE                             'undercharged'
       END                                   AS anomaly,
       COUNT(*)                              AS n_trips,
       ROUND(SUM(price - expected_price), 2) AS revenue_impact
FROM expected
WHERE ABS(price - expected_price) > 0.50
GROUP BY anomaly
ORDER BY n_trips DESC;
```

```text
╭─────────────────┬─────────┬────────────────╮
│     anomaly     │ n_trips │ revenue_impact │
╞═════════════════╪═════════╪════════════════╡
│ charged nothing │      18 │        -103.95 │
│ overcharged     │      12 │          475.2 │
╰─────────────────┴─────────┴────────────────╯
```

Worst offenders (same CTEs, row detail):

```text
╭─────────┬───────────┬────────────────┬───────┬────────────────┬───────────╮
│ trip_id │ user_type │ billed_minutes │ price │ expected_price │ deviation │
╞═════════╪═══════════╪════════════════╪═══════╪════════════════╪═══════════╡
│  107748 │ casual    │             57 │  95.5 │           9.55 │     85.95 │
│  103405 │ casual    │             45 │  77.5 │           7.75 │     69.75 │
│  106592 │ casual    │             26 │  49.0 │            4.9 │      44.1 │
│  108571 │ casual    │             23 │  44.5 │           4.45 │     40.05 │
│  114803 │ casual    │             22 │  43.0 │            4.3 │      38.7 │
│  107285 │ casual    │             21 │  41.5 │           4.15 │     37.35 │
│  102458 │ casual    │             17 │  35.5 │           3.55 │     31.95 │
│  103125 │ casual    │             16 │  34.0 │            3.4 │      30.6 │
│  101864 │ casual    │             15 │  32.5 │           3.25 │     29.25 │
│  100411 │ casual    │             13 │  29.5 │           2.95 │     26.55 │
╰─────────┴───────────┴────────────────┴───────┴────────────────┴───────────╯
```

**Interpretation.** Exactly 30 anomalous trips, all casual, in two clean
clusters: 18 rides **charged \$0.00** (≈\$104 of revenue never collected) and
12 rides charged **exactly 10× the correct fare** (price = 10 × expected on
every one — a decimal-point bug, ≈\$475 overcharged that finance should
refund before riders dispute it). Finance's hunch was right. Member trips
produced no anomalies, which also validates the Part A decision to impute
blank member prices as 0.00 — had we guessed wrong, this audit would have
lit up with false positives.
