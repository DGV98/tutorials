# Module 2 Solutions — Filtering & NULL

Run everything against `shop.db` from the course root. Where an exercise has a
tempting wrong version, it's shown and dissected.

## Warm-up

### Exercise 1 — Impulse rack

```sql
SELECT name, unit_price
FROM products
WHERE is_active = 1
  AND unit_price < 25
ORDER BY unit_price;
```

```text
╭─────────────────────┬────────────╮
│        name         │ unit_price │
╞═════════════════════╪════════════╡
│ Aqua Dry Bag 20L    │       8.18 │
│ Micro Ascender      │       8.72 │
│ Scout Cook Set      │       9.48 │
│ Micro Belay Device  │      10.96 │
│ Micro Carabiner     │       12.2 │
│ Splash Dry Bag 40L  │      12.48 │
│ Scout Water Filter  │      16.56 │
│ Fire Stove          │      17.46 │
│ Scout Map Case      │      21.13 │
│ Tide Dry Bag 10L    │      21.64 │
│ Core Base Layer Top │      21.84 │
│ Seal Dry Bag 10L    │      24.49 │
│ Seal Phone Case     │      24.89 │
╰─────────────────────┴────────────╯
```

Two `AND`-ed conditions, both on the same table. Forgetting `is_active = 1`
would sneak discontinued items onto the rack.

### Exercise 2 — Copenhagen pop-up

```sql
SELECT first_name || ' ' || last_name AS customer, city
FROM customers
WHERE city IN ('Copenhagen', 'Aarhus')
ORDER BY last_name, first_name
LIMIT 10;
```

```text
╭──────────────────┬────────────╮
│     customer     │    city    │
╞══════════════════╪════════════╡
│ Saga Bergstrom   │ Aarhus     │
│ Isak Costa       │ Copenhagen │
│ Rebecka Costa    │ Copenhagen │
│ Casper Dahl      │ Aarhus     │
│ Lars Duarte      │ Copenhagen │
│ Rasmus Ek        │ Copenhagen │
│ Tobias Ek        │ Copenhagen │
│ Marco Eriksson   │ Copenhagen │
│ Stellan Eriksson │ Copenhagen │
│ Erik Fernandez   │ Aarhus     │
╰──────────────────┴────────────╯
```

(56 rows total; `LIMIT 10` shown for display.) `IN` beats
`city = 'Copenhagen' OR city = 'Aarhus'` — same result, no precedence risk if
someone later adds an `AND`. Note `ORDER BY` can sort by `last_name` even
though the `SELECT` list only exposes the concatenated alias.

### Exercise 3 — Tent finder

```sql
-- Works in SQLite because LIKE is case-insensitive for ASCII.
-- On PostgreSQL 'tent' would NOT match 'Tent': use ILIKE or lower(name).
SELECT name, unit_price
FROM products
WHERE name LIKE '%tent%'
ORDER BY unit_price DESC
LIMIT 10;
```

```text
╭──────────────────────────┬────────────╮
│           name           │ unit_price │
╞══════════════════════════╪════════════╡
│ Nordic Tent 2P           │     744.79 │
│ Alpine Tunnel Tent       │     734.69 │
│ Storm Tunnel Tent        │     706.81 │
│ Nordic Tunnel Tent       │      698.9 │
│ Nordic Ultralight Tent   │     696.44 │
│ Basecamp Ultralight Tent │     671.16 │
│ Storm Dome Tent          │     636.15 │
│ Basecamp Tunnel Tent     │     617.94 │
│ Storm Tent 2P            │     604.87 │
│ Trail Dome Tent          │     601.32 │
╰──────────────────────────┴────────────╯
```

(23 rows total.) The catalog stores "Tent" capitalized; the lowercase pattern
matches anyway in SQLite. The portable spelling is
`WHERE lower(name) LIKE '%tent%'`.

## Core

### Exercise 4 — SMS launch list

```sql
SELECT customer_id, first_name || ' ' || last_name AS customer, phone
FROM customers
WHERE country IN ('Sweden', 'Norway', 'Denmark', 'Finland')
  AND marketing_opt_in = 1
  AND phone IS NOT NULL
ORDER BY customer_id
LIMIT 10;
```

```text
╭─────────────┬─────────────────┬──────────────╮
│ customer_id │    customer     │    phone     │
╞═════════════╪═════════════════╪══════════════╡
│           3 │ Ulf Hansen      │ +30 31429110 │
│          10 │ Nora Karlsson   │ +40 38538251 │
│          12 │ Wilma Magnusson │ +32 16323852 │
│          40 │ Freja Nilsson   │ +31 58024342 │
│          44 │ Linnea Kowalski │ +38 19317495 │
│          49 │ Liv Magnusson   │ +42 33357554 │
│          53 │ Dmitri Okafor   │ +42 76354180 │
│          81 │ Leif Andersson  │ +47 49209916 │
│          84 │ Leif Ek         │ +49 40291214 │
│          88 │ Priya Patel     │ +48 98742485 │
╰─────────────┴─────────────────┴──────────────╯
```

(114 rows total.) Three independent conditions, all `AND`-ed, so no
parentheses are needed — but the `phone IS NOT NULL` is essential: an SMS
list with NULL phones fails at send time. Writing `phone != ''` instead would
be wrong twice over — it tests for empty strings (which the data doesn't
use), and it evaluates to NULL for missing phones anyway.

### Exercise 5 — "Give us your number" campaign

```sql
SELECT email, created_at
FROM customers
WHERE marketing_opt_in = 1
  AND phone IS NULL
ORDER BY created_at DESC
LIMIT 10;
```

```text
╭─────────────────────────────┬─────────────────────╮
│            email            │     created_at      │
╞═════════════════════════════╪═════════════════════╡
│ hans.yilmaz@outlook.com     │ 2026-07-04 23:04:34 │
│ dag.nakamura@hotmail.com    │ 2026-06-28 18:58:42 │
│ astrid.pettersson@gmail.com │ 2026-06-09 07:31:01 │
│ priya.strand@icloud.com     │ 2026-05-16 03:40:09 │
│ noah.wall@yahoo.com         │ 2026-04-03 02:11:02 │
│ sofia.nyström@hotmail.com   │ 2026-02-27 01:21:30 │
│ birgitta.gran@gmail.com     │ 2026-02-23 22:52:36 │
│ nora.fors@hotmail.com       │ 2025-12-11 13:07:56 │
│ henrik.lind@proton.me       │ 2025-11-20 12:00:36 │
│ tobias.olsen@outlook.com    │ 2025-11-20 01:55:12 │
╰─────────────────────────────┴─────────────────────╯
```

(98 rows total.) The complement segment of exercise 4 on the phone axis. The
classic wrong turn is `phone = NULL` — which is never TRUE, returns zero
rows, and doesn't even raise an error. Only `IS NULL` tests for NULL.

### Exercise 6 — Holiday trading report rows

```sql
SELECT order_id, ordered_at, status
FROM orders
WHERE ordered_at >= '2025-11-01'
  AND ordered_at <  '2026-01-01'
  AND status <> 'cancelled'
ORDER BY ordered_at DESC
LIMIT 10;
```

```text
╭──────────┬─────────────────────┬───────────╮
│ order_id │     ordered_at      │  status   │
╞══════════╪═════════════════════╪═══════════╡
│     5472 │ 2025-12-31 21:26:33 │ delivered │
│     1071 │ 2025-12-31 19:59:44 │ delivered │
│     3810 │ 2025-12-31 19:32:19 │ delivered │
│     4926 │ 2025-12-31 18:53:44 │ delivered │
│     4002 │ 2025-12-31 18:05:24 │ delivered │
│      511 │ 2025-12-31 16:33:50 │ delivered │
│     4631 │ 2025-12-31 15:19:40 │ delivered │
│       80 │ 2025-12-31 14:46:55 │ delivered │
│     4166 │ 2025-12-31 14:43:06 │ delivered │
│     3542 │ 2025-12-31 13:22:38 │ delivered │
╰──────────┴─────────────────────┴───────────╯
```

(700 rows total.) Yes — Dec 31 orders belong in a Nov–Dec window, which is
exactly why the exclusive upper bound must be `'2026-01-01'`, not
`BETWEEN ... AND '2025-12-31'` (that version loses every order after midnight
on the 31st — 2025 alone has 23 of them). Excluding cancelled orders follows
the dataset's canonical gross-revenue convention (returned orders stay in).
`status <> 'cancelled'` is safe here only because `status` is never NULL —
on a nullable column you'd write `(status IS NULL OR status <> 'cancelled')`
after deciding what NULL should mean.

### Exercise 7 — Price bands

```sql
SELECT name, unit_price,
       CASE
         WHEN unit_price < 50  THEN 'budget'
         WHEN unit_price < 200 THEN 'mid-range'
         WHEN unit_price < 500 THEN 'premium'
         ELSE 'luxury'
       END AS price_band
FROM products
WHERE is_active = 1
ORDER BY unit_price DESC
LIMIT 10;
```

```text
╭─────────────────────────┬────────────┬────────────╮
│          name           │ unit_price │ price_band │
╞═════════════════════════╪════════════╪════════════╡
│ Drift Inflatable Kayak  │    1004.85 │ luxury     │
│ Fjord Sit-on-Top Kayak  │     934.86 │ luxury     │
│ Probe Airbag Pack       │     893.33 │ luxury     │
│ Rescue Avalanche Beacon │     834.53 │ luxury     │
│ Tele Touring Skis       │     775.98 │ luxury     │
│ Skerry Spray Skirt      │     773.95 │ luxury     │
│ Drift Touring Skis      │     745.19 │ luxury     │
│ Nordic Tent 2P          │     744.79 │ luxury     │
│ Probe Snow Shovel       │     744.12 │ luxury     │
│ Alpine Tunnel Tent      │     734.69 │ luxury     │
╰─────────────────────────┴────────────┴────────────╯
```

(324 active products total.) Because a searched `CASE` stops at the first TRUE
branch, each `WHEN` only needs an upper bound — writing
`WHEN unit_price >= 50 AND unit_price < 200` is redundant. Ordering the
branches wrong (e.g. `< 500` first) would swallow the lower bands: every
product under 500 would be labeled `premium`.

### Exercise 8 — Review triage

```sql
SELECT review_id, rating, review_text
FROM reviews
WHERE rating <= 2
  AND review_text IS NOT NULL
ORDER BY created_at DESC, review_id
LIMIT 10;
```

```text
╭───────────┬────────┬───────────────────────────────────────────╮
│ review_id │ rating │                review_text                │
╞═══════════╪════════╪═══════════════════════════════════════════╡
│       137 │      1 │ Arrived with a defect, had to return it.  │
│       224 │      2 │ Broke after two uses. Very disappointed.  │
│       229 │      1 │ Not waterproof at all despite the claims. │
│       356 │      2 │ Arrived with a defect, had to return it.  │
│       426 │      2 │ Sizing chart is completely wrong.         │
│       429 │      1 │ Cheap materials, would not recommend.     │
│       453 │      2 │ Arrived with a defect, had to return it.  │
│       455 │      1 │ Sizing chart is completely wrong.         │
│       535 │      1 │ Broke after two uses. Very disappointed.  │
│       622 │      1 │ Arrived with a defect, had to return it.  │
╰───────────┴────────┴───────────────────────────────────────────╯
```

(233 rows total.) "Most recent" means sorting by `created_at`, not
`review_id` — inserts don't have to arrive in chronological order, and in
this dataset they don't. `review_text IS NOT NULL` is the load-bearing line:
~35% of reviews are rating-only, and support can't reply to an empty
complaint. One real-data wrinkle you'll hit here: 249 reviews share the exact
timestamp `2026-07-14 12:00:00`, so `ORDER BY created_at DESC` alone leaves
the top of the list in arbitrary tie order — the `review_id` tiebreaker makes
the result deterministic. Deterministic ordering matters whenever anyone will
diff, paginate, or re-run your query.

### Exercise 9 — Backlog board

```sql
SELECT order_id, status, ordered_at
FROM orders
WHERE status IN ('pending', 'paid', 'shipped')
ORDER BY
  CASE status
    WHEN 'pending' THEN 1
    WHEN 'paid'    THEN 2
    WHEN 'shipped' THEN 3
  END,
  ordered_at
LIMIT 10;
```

```text
╭──────────┬─────────┬─────────────────────╮
│ order_id │ status  │     ordered_at      │
╞══════════╪═════════╪═════════════════════╡
│     4365 │ pending │ 2026-07-12 13:42:52 │
│     1488 │ pending │ 2026-07-12 14:24:03 │
│      510 │ pending │ 2026-07-12 14:28:26 │
│      447 │ pending │ 2026-07-12 17:03:00 │
│     3787 │ pending │ 2026-07-12 17:57:57 │
│     1989 │ pending │ 2026-07-12 18:43:05 │
│     1596 │ pending │ 2026-07-12 18:51:38 │
│     4709 │ pending │ 2026-07-12 20:00:19 │
│     3907 │ pending │ 2026-07-12 21:04:45 │
│     2873 │ pending │ 2026-07-12 21:14:28 │
╰──────────┴─────────┴─────────────────────╯
```

(306 open orders total.) A plain `ORDER BY status` sorts alphabetically —
`paid, pending, shipped` — which is not the workflow order. The `CASE` maps
each status to an explicit rank. The simple-form `CASE` has no `ELSE`, which
is safe here only because the `WHERE` guarantees the three listed values; on
unfiltered data, unmatched statuses would get a NULL sort key (and sort first
in SQLite).

## Challenge

### Exercise 10 — Power-buyer recency

```sql
SELECT order_id, ordered_at,
       CASE
         WHEN ordered_at >= date('2026-07-15', '-30 days') THEN 'last 30 days'
         WHEN ordered_at >= date('2026-07-15', '-90 days') THEN 'last 90 days'
         ELSE 'older'
       END AS recency_bucket
FROM orders
WHERE customer_id = 684
  AND status <> 'cancelled'
ORDER BY ordered_at DESC
LIMIT 12;
```

```text
╭──────────┬─────────────────────┬────────────────╮
│ order_id │     ordered_at      │ recency_bucket │
╞══════════╪═════════════════════╪════════════════╡
│     3363 │ 2026-07-14 16:21:48 │ last 30 days   │
│     1324 │ 2026-07-07 01:34:53 │ last 30 days   │
│     5400 │ 2026-07-04 03:16:58 │ last 30 days   │
│     1714 │ 2026-06-30 17:06:54 │ last 30 days   │
│     5751 │ 2026-06-26 01:02:24 │ last 30 days   │
│     4358 │ 2026-06-17 20:04:12 │ last 30 days   │
│     1849 │ 2026-06-07 23:04:01 │ last 90 days   │
│     5601 │ 2026-05-23 02:26:36 │ last 90 days   │
│     4176 │ 2026-04-16 09:49:07 │ last 90 days   │
│     4469 │ 2026-04-01 16:01:43 │ older          │
│     1748 │ 2026-03-21 02:40:20 │ older          │
│     4827 │ 2026-03-05 17:15:00 │ older          │
╰──────────┴─────────────────────┴────────────────╯
```

(Customer 684 has 46 non-cancelled orders total.)
`date('2026-07-15', '-30 days')` evaluates to `'2026-06-15'` and
`'-90 days'` to `'2026-04-16'`; a full `YYYY-MM-DD HH:MM:SS` timestamp
compares correctly against the bare-date cutoff because any time on the
cutoff day sorts after it — the boundary behaves half-open, which is what we
want. Branch order matters: testing `-90 days` first would label everything
recent as merely "last 90 days" (both conditions are true for a 10-day-old
order, and `CASE` takes the first match).

### Exercise 11 — Contact channel routing

```sql
SELECT customer_id,
       first_name || ' ' || last_name AS customer,
       CASE
         WHEN marketing_opt_in = 1 AND phone IS NOT NULL THEN 'sms'
         WHEN marketing_opt_in = 1                       THEN 'email'
         ELSE 'do not contact'
       END AS contact_channel
FROM customers
ORDER BY customer_id
LIMIT 10;
```

```text
╭─────────────┬─────────────────┬─────────────────╮
│ customer_id │    customer     │ contact_channel │
╞═════════════╪═════════════════╪═════════════════╡
│           1 │ Hiro Fisker     │ do not contact  │
│           2 │ Tobias Ek       │ do not contact  │
│           3 │ Ulf Hansen      │ sms             │
│           4 │ Frida Holm      │ do not contact  │
│           5 │ Bjorn Ahmed     │ do not contact  │
│           6 │ Mats Sjoberg    │ do not contact  │
│           7 │ Mikael Karlsson │ do not contact  │
│           8 │ Priya Tanaka    │ sms             │
│           9 │ Hiro Wall       │ do not contact  │
│          10 │ Nora Karlsson   │ sms             │
╰─────────────┴─────────────────┴─────────────────╯
```

Sequential `WHEN`s let the second branch stay terse: reaching it already
implies the first was false, so `marketing_opt_in = 1` there *means* "opted
in but no phone". The tempting wrong version is
`WHEN marketing_opt_in = 1 AND phone != '' THEN 'sms'` — for NULL phones the
condition is NULL, the branch is skipped (which happens to work), but the
intent is muddy and it breaks the moment anyone relies on that test being
FALSE. Say `IS NOT NULL` when you mean "has a value". Also note this must be
the searched `CASE` form — the simple form compares with `=` and cannot test
for NULL at all.

### Exercise 12 — New Year's Eve staffing

```sql
SELECT order_id, ordered_at, status
FROM orders
WHERE strftime('%m-%d', ordered_at) = '12-31'
ORDER BY ordered_at DESC
LIMIT 10;
```

```text
╭──────────┬─────────────────────┬───────────╮
│ order_id │     ordered_at      │  status   │
╞══════════╪═════════════════════╪═══════════╡
│     3920 │ 2025-12-31 22:32:52 │ cancelled │
│     5472 │ 2025-12-31 21:26:33 │ delivered │
│     1071 │ 2025-12-31 19:59:44 │ delivered │
│     3810 │ 2025-12-31 19:32:19 │ delivered │
│     4926 │ 2025-12-31 18:53:44 │ delivered │
│     4002 │ 2025-12-31 18:05:24 │ delivered │
│      511 │ 2025-12-31 16:33:50 │ delivered │
│     4631 │ 2025-12-31 15:19:40 │ delivered │
│       80 │ 2025-12-31 14:46:55 │ delivered │
│     4166 │ 2025-12-31 14:43:06 │ delivered │
╰──────────┴─────────────────────┴───────────╯
```

(32 rows total — 9 from 2024 and 23 from 2025; 2023 happens to have no
Dec 31 orders.) A contiguous range can't express "the same
calendar day every year" — this is the legitimate use case for filtering on a
function of the column. `strftime('%m-%d', ...)` extracts the month-day part
as text; comparing to `'12-31'` catches every year at once. Equivalent:
`ordered_at LIKE '_____12-31%'` — clever, but the `strftime` version states
its intent. (And per the module: function-wrapped columns defeat indexes —
fine for an ad-hoc ops question, something to design around in Module 10.)
