# Capstone Solutions — Part C (Written Exam)

One point per question. Give yourself the point only if your answer names the
*mechanism*, not just the outcome.

**1. Station name + district on every trip row.**
It violates **third normal form (3NF)**: `district` depends on the station,
not on the trip — a transitive dependency `trip → station → district`
(and the name itself is redundant with the station registry). Concrete
anomaly: rename a station or move it to a redrawn district and you must
update thousands of trip rows; miss any and the same station reports trips
in two districts (update anomaly / inconsistent reads). Storing
`start_station_id` and joining fixes it.

**2. Why `trip_id` beats `(bike_id, started_at)` as PK.**
The composite key encodes an assumption the real world doesn't guarantee: one
trip per bike per timestamp. Realistic failure: the 2026 export truncates
times to the minute, so a bike returned and immediately re-rented in the same
minute produces two rows with identical `(bike_id, started_at)` — the second
insert is rejected and data is lost. (Also: clock corrections, and every
child table would have to carry the wide key.) A surrogate key is stable and
meaning-free.

**3. Three-valued logic truth table.**

| expression | result |
|---|---|
| `TRUE AND NULL` | `NULL` |
| `FALSE AND NULL` | `FALSE` |
| `TRUE OR NULL` | `TRUE` |
| `FALSE OR NULL` | `NULL` |
| `NOT NULL` | `NULL` |
| `NULL = NULL` | `NULL` |

The pattern: NULL means "unknown", so the result is NULL exactly when the
unknown value *could* change the outcome (`FALSE AND anything` is already
FALSE; `TRUE OR anything` is already TRUE).

**4. Does `user_birth_year >= 1990 OR user_birth_year < 1990` match all rows?**
No. For NULL birth years both comparisons evaluate to NULL, `NULL OR NULL` is
NULL, and a WHERE clause only keeps rows whose predicate is *TRUE* — NULL is
not TRUE. Every trip with an unknown birth year (blank or absurd values we
nulled in Part A) silently drops out. To include them:
`... OR user_birth_year IS NULL`.

**5. The three COUNTs.**
`COUNT(*)` counts rows (20,824). `COUNT(user_birth_year)` counts rows where
that column is **not NULL** (20,075 — the 749 nulled birth years are
invisible to it). `COUNT(DISTINCT user_birth_year)` counts distinct non-NULL
values (52 different birth years). NULLs are invisible to the last two.

**6. Best index for `WHERE bike_id = 1233 ORDER BY started_at`.**
**(c) `(bike_id, started_at)`.** The equality on the leading column narrows
the search to one bike's slice of the index, and *within that slice the
entries are already sorted by `started_at`*, so the ORDER BY costs nothing.
(b) finds the rows but in no useful order — a sort step remains. (d) is
ordered by time first, so the bike's rows are scattered through the whole
index: the equality can't seek, and the database ends up scanning. Column
order in composite indexes: **equality columns first, then the range/sort
column.**

**7. Why `strftime('%Y', started_at) = '2026'` can't use the index.**
The index stores `started_at` values, not `strftime(...)` results. Wrapping
the column in a function hides it from the index (a non-*sargable*
predicate): the engine must compute the function for every row. Rewrite as a
range over the *bare* column:
`WHERE started_at >= '2026-01-01' AND started_at < '2027-01-01'` — now it's a
straight index range scan.

**8. `SCAN` vs `SEARCH`.**
`SCAN trips` reads every row of the table (full table scan) — cost grows
**linearly** with table size. `SEARCH ... USING INDEX ... (bike_id=?)`
descends the index B-tree to the matching entries and reads only those —
roughly logarithmic seek plus rows actually matched. A SCAN isn't
automatically wrong (reading most of a table via an index is slower), but on
a selective predicate you want SEARCH.

**9. Transaction prediction.**
The UPDATE **survives**, the DELETE **does not**. `ROLLBACK TO s1` undoes
everything after `SAVEPOINT s1` (the DELETE) but leaves the outer
transaction alive with the UPDATE intact; `COMMIT` then makes the UPDATE
permanent. Final state: bike 1001 has model `'X-99'`, `maintenance` is
untouched.

**10. Why capacity check + dock write need one transaction.**
It's a read-then-write race (TOCTOU). Two sessions can both read "2 free
slots", both decide there's room, and both insert — 3 bikes in 2 slots. The
check and the write must be atomic and isolated so the second transaction
sees the first one's write (or is serialized behind it). In SQLite a write
transaction locks the database, making the pair atomic; in PostgreSQL you'd
rely on row locking (`SELECT ... FOR UPDATE`) or a constraint that makes the
overflow impossible.

**11. The fan-out bug.**
Joining `trips` *and* `maintenance` to `bikes` in one query multiplies the
two independent one-to-many relationships: a bike with 200 trips and 3
maintenance visits produces 600 joined rows, so `SUM(t.price)` is counted 3×
and `SUM(m.cost)` 200×. Both totals are inflated, by *different* factors per
bike, and bikes with zero trips or zero maintenance vanish entirely (inner
joins). Fix: aggregate each side **before** joining:

```sql
WITH trip_rev AS (
    SELECT bike_id, SUM(price) AS revenue
    FROM trips GROUP BY bike_id
),
maint AS (
    SELECT bike_id, SUM(cost) AS maintenance_cost
    FROM maintenance GROUP BY bike_id
)
SELECT b.bike_id,
       COALESCE(t.revenue, 0)          AS revenue,
       COALESCE(m.maintenance_cost, 0) AS maintenance_cost
FROM bikes b
LEFT JOIN trip_rev t ON t.bike_id = b.bike_id
LEFT JOIN maint    m ON m.bike_id = b.bike_id;
```

**12. LEFT JOIN killed by WHERE.**
For a zero-trip station the LEFT JOIN produces one row with every trip column
NULL. `WHERE t.user_type = 'member'` evaluates to NULL on that row, and WHERE
discards non-TRUE rows — so the preserved rows are exactly the ones filtered
away. The join silently became an INNER JOIN. Fix: move the condition into
the join — `LEFT JOIN trips t ON t.start_station_id = s.station_id AND
t.user_type = 'member'` — or accept NULL explicitly in the WHERE.

**13. Ranking functions on 12, 12, 10 (`ORDER BY price DESC`).**

| price | ROW_NUMBER | RANK | DENSE_RANK |
|---|---|---|---|
| 12 | 1 | 1 | 1 |
| 12 | 2 | 1 | 1 |
| 10 | 3 | 3 | 2 |

`ROW_NUMBER` breaks the tie arbitrarily (non-deterministic without a
tiebreaker in the ORDER BY); `RANK` gives equal rows equal rank and then
*skips* (1, 1, 3); `DENSE_RANK` doesn't skip (1, 1, 2).

**14. Why `WHERE ROW_NUMBER() OVER (...) = 1` is illegal.**
Window functions are evaluated *after* WHERE (and GROUP BY/HAVING) — the
window operates on the rows that survived filtering, so a WHERE that depends
on the window's result is circular, and the standard forbids it. The pattern:
compute the window in a CTE (or subquery), filter in the next layer:

```sql
WITH ranked AS (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY bike_id
                                   ORDER BY started_at) AS rn
    FROM trips t
)
SELECT * FROM ranked WHERE rn = 1;
```

**15. WHERE vs HAVING.**
`WHERE` filters individual rows *before* grouping and aggregation; `HAVING`
filters *groups after* aggregation. WHERE runs first. `HAVING COUNT(*) > 100`
is legal only in HAVING (aggregates can't appear in WHERE); conversely,
filtering `WHERE started_at >= '2026-01-01'` before grouping is both legal
and cheaper than letting every row into the aggregation. Swapping them
either errors or changes which rows feed the aggregates.

**16. UNIQUE and NULLs.**
SQLite (like PostgreSQL by default) accepts **any number** of NULLs in a
UNIQUE column. Consistent with NULL semantics: UNIQUE rejects two values
that compare *equal*, but `NULL = NULL` is NULL, not TRUE — two unknown
serial numbers can't be proven equal, so neither is a duplicate of the
other. (If that's not the business rule you want, add `NOT NULL`.)

**17. Foreign keys with `PRAGMA foreign_keys` OFF.**
The insert **succeeds** — SQLite parses and stores FK declarations but, for
backward compatibility, does not enforce them unless each connection runs
`PRAGMA foreign_keys = ON;`. Implication: every load script (and every
application connection) must set the pragma explicitly, or your "constrained"
schema will happily accept orphan `bike_id`s. That's why `load.sql` sets it
in its first lines.

**18. Why ISO-8601 text works and `DD/MM/YYYY` doesn't.**
ISO-8601 (`YYYY-MM-DD HH:MM:SS`) orders fields from most to least
significant with fixed widths, so **lexicographic string order equals
chronological order**, and SQLite's date functions parse it natively. The
vendor format sorts by day-of-month first: `'01/06/2026' < '31/01/2026'` as
strings, yet June 1 is *after* January 31 — every range filter, ORDER BY,
MIN/MAX, and `strftime()` on it is quietly wrong. That's why Part A
rearranged it once, at load time.

**19. Critique of the query.**
```sql
select * from trips t, stations s
where t.start_station_id=s.station_id and price>0 order by 2;
```
At least four problems (any four earn the point):
1. **`SELECT *`** — drags every column of both tables through; brittle for
   consumers (column order/count changes when the schema does).
2. **Comma join** — implicit CROSS JOIN with the join condition buried in
   WHERE; one forgotten predicate away from a cartesian product. Use
   explicit `JOIN ... ON`.
3. **`ORDER BY 2`** — positional ordering silently changes meaning whenever
   the select list changes; name the column.
4. **Unqualified `price`** — works until any joined table gains a `price`
   column, then the query breaks (or worse, picks the wrong one); qualify as
   `t.price`.
5. Style: lowercase keywords, no line structure, alias `t`/`s` fine but only
   half-used — inconsistent qualification.
Also worth noting: only *start* station is joined — fine if intended, worth a
comment because the table has two station FKs.

**20. Quality report: VIEW vs table.**
**VIEW**: always current — rerun the load and the report reflects it with
zero refresh logic; no storage; can't drift out of sync with the data.
**Materialized table**: a frozen snapshot you can keep per load run (audit
trail of what the pipeline saw *at the time*), and it's cheap to query
repeatedly. For a load-time audit artifact, a table stamped per run is
defensible; for ad-hoc "how dirty is it now", the view wins.
