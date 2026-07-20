# Module 11 — Advanced Analytics

Everything you have learned so far — joins, aggregation, CTE pipelines, window
functions — was vocabulary. This module is about fluency: the dozen analytics
*patterns* that professional data engineers reach for daily. Deduplication,
sessionization, cohort retention, funnels, as-of joins — none of these is a SQL
feature; each is a composition of features you already know, and each answers a
class of business question that comes up at every company. Learn the pattern
once and you will recognize it instantly in the wild, whatever the schema.

Every query in this module only *reads* from `shop.db` — no copy needed. Run
them directly:

```bash
sqlite3 -box shop.db
```

## What you'll learn

- Deduplicating messy event-style tables: the latest row per group, three ways, and when each breaks
- Gaps and islands — deriving session IDs from raw timestamps (`LAG` → gap flag → cumulative `SUM`)
- Detecting streaks (consecutive months of activity) with the `value − ROW_NUMBER()` trick
- Building date spines with recursive CTEs and zero-filling sparse time series
- Why moving averages over sparse series are wrong without a spine
- Cohort retention matrices with conditional aggregation — and the fan-out bug that inflates them
- RFM segmentation with `NTILE` and business-readable segment labels
- Funnel analysis from clickstream events with per-step conversion rates
- Pivoting long→wide with `SUM(CASE ...)` and unpivoting wide→long with `UNION ALL`
- Point-in-time (as-of) joins against SCD2 history tables — the range-join pattern and its NULL trap
- Medians and percentiles without `PERCENTILE_CONT`
- Producing and shredding JSON with `json_object`, `json_group_array`, and `json_each`

## 11.1 Deduplication: the latest row per group

**The problem.** Operational tables often carry several rows per business
entity: retries, corrections, status updates. Nordkart's `payments` table is a
textbook case — a failed card attempt followed by a successful retry, or a
capture followed months later by a refund:

```sql
SELECT payment_id, order_id, amount, method, status, paid_at
FROM payments
WHERE order_id IN (38, 92)
ORDER BY order_id, paid_at;
```

```text
╭────────────┬──────────┬────────┬────────┬──────────┬─────────────────────╮
│ payment_id │ order_id │ amount │ method │  status  │       paid_at       │
╞════════════╪══════════╪════════╪════════╪══════════╪═════════════════════╡
│         37 │       38 │ 111.67 │ card   │ failed   │ 2026-07-12 09:18:39 │
│         38 │       38 │ 111.67 │ card   │ captured │ 2026-07-12 10:48:39 │
│         94 │       92 │ 253.13 │ paypal │ failed   │ 2026-06-29 01:54:17 │
│         95 │       92 │ 253.13 │ paypal │ captured │ 2026-06-29 02:23:17 │
╰────────────┴──────────┴────────┴────────┴──────────┴─────────────────────╯
```

Finance asks: *"What is the current payment state of each order?"* That means:
**one row per order — the latest one**. Ask a `GROUP BY` for
`MAX(paid_at)` and you get the timestamp, but you cannot safely drag the
matching `status` along (mixing aggregated and non-aggregated columns is the
Module 3 cardinal sin). You need one of the three canonical patterns.

### Way 1 — `ROW_NUMBER()` (the default choice)

Number the rows within each order, newest first, keep row 1:

```sql
WITH ranked AS (
    SELECT payment_id, order_id, amount, method, status, paid_at,
           ROW_NUMBER() OVER (
               PARTITION BY order_id
               ORDER BY paid_at DESC, payment_id DESC
           ) AS rn
    FROM payments
)
SELECT order_id, payment_id, amount, method, status, paid_at
FROM ranked
WHERE rn = 1
ORDER BY order_id
LIMIT 5;
```

```text
╭──────────┬────────────┬─────────┬───────────────┬──────────┬─────────────────────╮
│ order_id │ payment_id │ amount  │    method     │  status  │       paid_at       │
╞══════════╪════════════╪═════════╪═══════════════╪══════════╪═════════════════════╡
│        1 │          1 │ 3665.27 │ paypal        │ captured │ 2026-03-01 23:36:44 │
│        3 │          2 │  712.22 │ paypal        │ captured │ 2026-07-07 22:02:23 │
│        4 │          3 │  392.29 │ paypal        │ captured │ 2026-01-12 13:49:10 │
│        5 │          4 │  218.72 │ bank_transfer │ captured │ 2024-11-05 14:52:23 │
│        6 │          5 │  278.29 │ paypal        │ captured │ 2024-07-15 03:36:22 │
╰──────────┴────────────┴─────────┴───────────────┴──────────┴─────────────────────╯
```

Note the **tie-breaker**: `ORDER BY paid_at DESC, payment_id DESC`. If two
payments share a timestamp, `ROW_NUMBER` still hands out distinct numbers, and
the extra sort key makes *which* row wins deterministic instead of arbitrary.
This matters in real data — keep reading.

### Way 2 — correlated `MAX` subquery

```sql
SELECT order_id, payment_id, status, paid_at
FROM payments p
WHERE paid_at = (
    SELECT MAX(p2.paid_at)
    FROM payments p2
    WHERE p2.order_id = p.order_id
)
ORDER BY order_id
LIMIT 5;
```

```text
╭──────────┬────────────┬──────────┬─────────────────────╮
│ order_id │ payment_id │  status  │       paid_at       │
╞══════════╪════════════╪══════════╪═════════════════════╡
│        1 │          1 │ captured │ 2026-03-01 23:36:44 │
│        3 │          2 │ captured │ 2026-07-07 22:02:23 │
│        4 │          3 │ captured │ 2026-01-12 13:49:10 │
│        5 │          4 │ captured │ 2024-11-05 14:52:23 │
│        6 │          5 │ captured │ 2024-07-15 03:36:22 │
╰──────────┴────────────┴──────────┴─────────────────────╯
```

### Way 3 — `GROUP BY` + join back

```sql
SELECT p.order_id, p.payment_id, p.status, p.paid_at
FROM payments p
JOIN (
    SELECT order_id, MAX(paid_at) AS last_paid_at
    FROM payments
    GROUP BY order_id
) latest
  ON latest.order_id = p.order_id
 AND latest.last_paid_at = p.paid_at
ORDER BY p.order_id
LIMIT 5;
```

```text
╭──────────┬────────────┬──────────┬─────────────────────╮
│ order_id │ payment_id │  status  │       paid_at       │
╞══════════╪════════════╪══════════╪═════════════════════╡
│        1 │          1 │ captured │ 2026-03-01 23:36:44 │
│        3 │          2 │ captured │ 2026-07-07 22:02:23 │
│        4 │          3 │ captured │ 2026-01-12 13:49:10 │
│        5 │          4 │ captured │ 2024-11-05 14:52:23 │
│        6 │          5 │ captured │ 2024-07-15 03:36:22 │
╰──────────┴────────────┴──────────┴─────────────────────╯
```

### Tradeoffs — and why ties are not hypothetical

Ways 2 and 3 share a flaw: **if two rows tie on `MAX(paid_at)`, both survive**.
And Nordkart has exactly such a tie:

```sql
SELECT order_id, payment_id, method, status, paid_at
FROM payments p
WHERE paid_at = (
    SELECT MAX(p2.paid_at)
    FROM payments p2
    WHERE p2.order_id = p.order_id
)
  AND order_id = 3676;
```

```text
╭──────────┬────────────┬───────────────┬──────────┬─────────────────────╮
│ order_id │ payment_id │    method     │  status  │       paid_at       │
╞══════════╪════════════╪═══════════════╪══════════╪═════════════════════╡
│     3676 │       3775 │ paypal        │ failed   │ 2026-02-10 14:59:53 │
│     3676 │       3776 │ bank_transfer │ captured │ 2026-02-10 14:59:53 │
╰──────────┴────────────┴───────────────┴──────────┴─────────────────────╯
```

A failed PayPal attempt and a successful bank transfer in the same second.
Count the fallout:

```sql
SELECT
    (SELECT COUNT(*) FROM (
        SELECT 1 FROM payments p
        WHERE paid_at = (SELECT MAX(p2.paid_at) FROM payments p2
                         WHERE p2.order_id = p.order_id)
    )) AS correlated_rows,
    (SELECT COUNT(DISTINCT order_id) FROM payments) AS orders_with_payments;
```

```text
╭─────────────────┬──────────────────────╮
│ correlated_rows │ orders_with_payments │
╞═════════════════╪══════════════════════╡
│            5654 │                 5653 │
╰─────────────────┴──────────────────────╯
```

5,654 "latest" rows for 5,653 orders. One extra row is invisible in a report
until it double-counts a payment or breaks a supposedly-unique join key
downstream. Summary of the three ways:

| pattern | guarantees 1 row/group | extra columns | notes |
|---|---|---|---|
| `ROW_NUMBER` + `rn = 1` | **yes** (with tie-breaker) | all, for free | default choice; one pass over the data |
| correlated `MAX` | no — ties leak | all, for free | fine for tiny lookups; O(N×lookup) shape |
| `GROUP BY` + join back | no — ties leak | all, via the join | pre-window-function idiom; two passes |

> **PostgreSQL note:** Postgres has a fourth idiom, `SELECT DISTINCT ON
> (order_id) ... ORDER BY order_id, paid_at DESC`, which is the terse
> equivalent of the `ROW_NUMBER` pattern. It is not portable — SQLite does not
> support `DISTINCT ON`.

### The business payoff

Which orders need payment follow-up — their **latest** attempt failed or is
still pending?

```sql
WITH ranked AS (
    SELECT order_id, status, paid_at,
           ROW_NUMBER() OVER (
               PARTITION BY order_id
               ORDER BY paid_at DESC, payment_id DESC
           ) AS rn
    FROM payments
)
SELECT o.order_id, o.status AS order_status,
       r.status AS last_payment_status, r.paid_at AS last_attempt_at
FROM ranked r
JOIN orders o ON o.order_id = r.order_id
WHERE r.rn = 1
  AND r.status IN ('failed', 'pending')
ORDER BY r.paid_at DESC
LIMIT 10;
```

```text
╭──────────┬──────────────┬─────────────────────┬─────────────────────╮
│ order_id │ order_status │ last_payment_status │   last_attempt_at   │
╞══════════╪══════════════╪═════════════════════╪═════════════════════╡
│     2693 │ pending      │ pending             │ 2026-07-14 21:08:53 │
│      525 │ pending      │ pending             │ 2026-07-14 18:31:57 │
│     4938 │ pending      │ pending             │ 2026-07-14 18:19:17 │
│     3363 │ pending      │ pending             │ 2026-07-14 16:26:48 │
│     5890 │ pending      │ pending             │ 2026-07-14 12:34:12 │
│     5373 │ pending      │ pending             │ 2026-07-14 09:48:36 │
│     4305 │ pending      │ pending             │ 2026-07-14 08:36:06 │
│     2794 │ pending      │ pending             │ 2026-07-14 08:06:08 │
│     2097 │ pending      │ pending             │ 2026-07-14 06:54:18 │
│     2926 │ pending      │ pending             │ 2026-07-14 06:22:28 │
╰──────────┴──────────────┴─────────────────────┴─────────────────────╯
```

(55 rows total without the `LIMIT` — 31 pending, 24 whose last attempt
failed.)

## 11.2 Gaps and islands I: sessionizing the clickstream

This is the flagship pattern of the module. Nordkart's `events` table records
16,364 clickstream events — page views, add-to-carts, checkouts, searches —
but **no session ID**. Marketing wants session-level answers: how long do
visits last, how many events per visit, what share of visits reach checkout?

The standard industry rule: a session ends after **30 minutes of inactivity**.
Events separated by ≤ 30 minutes belong to the same session (an *island*);
a longer silence (a *gap*) starts a new one. You cannot express "compare each
event to the previous one" with `GROUP BY` — this is `LAG` territory, and the
solution is a three-step pipeline worth memorizing.

### Step 1 — fetch each event's predecessor with `LAG`

```sql
SELECT event_id, event_type, occurred_at,
       LAG(occurred_at) OVER (
           PARTITION BY customer_id
           ORDER BY occurred_at, event_id
       ) AS prev_at
FROM events
WHERE customer_id = 1
ORDER BY occurred_at, event_id;
```

```text
╭──────────┬────────────────┬─────────────────────┬─────────────────────╮
│ event_id │   event_type   │     occurred_at     │       prev_at       │
╞══════════╪════════════════╪═════════════════════╪═════════════════════╡
│       14 │ page_view      │ 2025-07-22 04:23:37 │                     │
│       15 │ page_view      │ 2025-08-10 14:18:51 │ 2025-07-22 04:23:37 │
│       16 │ page_view      │ 2025-08-10 14:23:43 │ 2025-08-10 14:18:51 │
│       17 │ add_to_cart    │ 2025-08-10 14:29:00 │ 2025-08-10 14:23:43 │
│        1 │ page_view      │ 2026-01-31 23:47:15 │ 2025-08-10 14:29:00 │
│        2 │ page_view      │ 2026-01-31 23:49:42 │ 2026-01-31 23:47:15 │
│        3 │ add_to_cart    │ 2026-01-31 23:55:53 │ 2026-01-31 23:49:42 │
│        4 │ page_view      │ 2026-01-31 23:57:32 │ 2026-01-31 23:55:53 │
│        5 │ begin_checkout │ 2026-02-01 00:02:00 │ 2026-01-31 23:57:32 │
│        6 │ page_view      │ 2026-02-01 00:07:55 │ 2026-02-01 00:02:00 │
│        7 │ page_view      │ 2026-02-01 00:13:19 │ 2026-02-01 00:07:55 │
│        8 │ page_view      │ 2026-02-01 00:20:01 │ 2026-02-01 00:13:19 │
│        9 │ page_view      │ 2026-04-04 00:23:12 │ 2026-02-01 00:20:01 │
│       10 │ page_view      │ 2026-04-04 00:27:28 │ 2026-04-04 00:23:12 │
│       11 │ add_to_cart    │ 2026-04-04 00:28:31 │ 2026-04-04 00:27:28 │
│       12 │ page_view      │ 2026-04-04 00:32:19 │ 2026-04-04 00:28:31 │
│       13 │ page_view      │ 2026-04-04 00:33:20 │ 2026-04-04 00:32:19 │
╰──────────┴────────────────┴─────────────────────┴─────────────────────╯
```

Two details. `PARTITION BY customer_id` keeps each visitor's timeline
separate — the first event per customer gets `prev_at = NULL`. And `event_id`
in the `ORDER BY` is our tie-breaker again, making the ordering deterministic
even if two events share a timestamp.

### Step 2 — compute the gap and flag session starts

`julianday()` converts a timestamp to a fractional day number, so the
difference `× 24 × 60` is minutes. An event starts a new session when it has
no predecessor (`prev_at IS NULL`) or the gap exceeds 30 minutes:

```sql
WITH with_prev AS (
    SELECT customer_id, event_id, event_type, occurred_at,
           LAG(occurred_at) OVER (
               PARTITION BY customer_id
               ORDER BY occurred_at, event_id
           ) AS prev_at
    FROM events
)
SELECT event_id, event_type, occurred_at,
       ROUND((julianday(occurred_at) - julianday(prev_at)) * 24 * 60, 1) AS gap_min,
       CASE
           WHEN prev_at IS NULL
             OR (julianday(occurred_at) - julianday(prev_at)) * 24 * 60 > 30
           THEN 1 ELSE 0
       END AS is_session_start
FROM with_prev
WHERE customer_id = 1
ORDER BY occurred_at, event_id;
```

```text
╭──────────┬────────────────┬─────────────────────┬──────────┬──────────────────╮
│ event_id │   event_type   │     occurred_at     │ gap_min  │ is_session_start │
╞══════════╪════════════════╪═════════════════════╪══════════╪══════════════════╡
│       14 │ page_view      │ 2025-07-22 04:23:37 │          │                1 │
│       15 │ page_view      │ 2025-08-10 14:18:51 │  27955.2 │                1 │
│       16 │ page_view      │ 2025-08-10 14:23:43 │      4.9 │                0 │
│       17 │ add_to_cart    │ 2025-08-10 14:29:00 │      5.3 │                0 │
│        1 │ page_view      │ 2026-01-31 23:47:15 │ 251118.3 │                1 │
│        2 │ page_view      │ 2026-01-31 23:49:42 │      2.5 │                0 │
│        3 │ add_to_cart    │ 2026-01-31 23:55:53 │      6.2 │                0 │
│        4 │ page_view      │ 2026-01-31 23:57:32 │      1.6 │                0 │
│        5 │ begin_checkout │ 2026-02-01 00:02:00 │      4.5 │                0 │
│        6 │ page_view      │ 2026-02-01 00:07:55 │      5.9 │                0 │
│        7 │ page_view      │ 2026-02-01 00:13:19 │      5.4 │                0 │
│        8 │ page_view      │ 2026-02-01 00:20:01 │      6.7 │                0 │
│        9 │ page_view      │ 2026-04-04 00:23:12 │  89283.2 │                1 │
│       10 │ page_view      │ 2026-04-04 00:27:28 │      4.3 │                0 │
│       11 │ add_to_cart    │ 2026-04-04 00:28:31 │      1.1 │                0 │
│       12 │ page_view      │ 2026-04-04 00:32:19 │      3.8 │                0 │
│       13 │ page_view      │ 2026-04-04 00:33:20 │      1.0 │                0 │
╰──────────┴────────────────┴─────────────────────┴──────────┴──────────────────╯
```

Four `1`s — four sessions for this customer. Notice the third session runs
across midnight (23:47 → 00:20): any approach that buckets by calendar date or
clock time would cut it in half. The gap rule doesn't care what the clock says,
only how long the silence was.

### Step 3 — cumulative `SUM` turns flags into session numbers

A running sum of `is_session_start` increments exactly when a new session
begins — so it *is* the session number:

```sql
WITH with_prev AS (
    SELECT customer_id, event_id, event_type, occurred_at,
           LAG(occurred_at) OVER (
               PARTITION BY customer_id
               ORDER BY occurred_at, event_id
           ) AS prev_at
    FROM events
),
flagged AS (
    SELECT *,
           CASE
               WHEN prev_at IS NULL
                 OR (julianday(occurred_at) - julianday(prev_at)) * 24 * 60 > 30
               THEN 1 ELSE 0
           END AS is_session_start
    FROM with_prev
)
SELECT event_id, event_type, occurred_at,
       SUM(is_session_start) OVER (
           PARTITION BY customer_id
           ORDER BY occurred_at, event_id
       ) AS session_no
FROM flagged
WHERE customer_id = 1
ORDER BY occurred_at, event_id;
```

```text
╭──────────┬────────────────┬─────────────────────┬────────────╮
│ event_id │   event_type   │     occurred_at     │ session_no │
╞══════════╪════════════════╪═════════════════════╪════════════╡
│       14 │ page_view      │ 2025-07-22 04:23:37 │          1 │
│       15 │ page_view      │ 2025-08-10 14:18:51 │          2 │
│       16 │ page_view      │ 2025-08-10 14:23:43 │          2 │
│       17 │ add_to_cart    │ 2025-08-10 14:29:00 │          2 │
│        1 │ page_view      │ 2026-01-31 23:47:15 │          3 │
│        2 │ page_view      │ 2026-01-31 23:49:42 │          3 │
│        3 │ add_to_cart    │ 2026-01-31 23:55:53 │          3 │
│        4 │ page_view      │ 2026-01-31 23:57:32 │          3 │
│        5 │ begin_checkout │ 2026-02-01 00:02:00 │          3 │
│        6 │ page_view      │ 2026-02-01 00:07:55 │          3 │
│        7 │ page_view      │ 2026-02-01 00:13:19 │          3 │
│        8 │ page_view      │ 2026-02-01 00:20:01 │          3 │
│        9 │ page_view      │ 2026-04-04 00:23:12 │          4 │
│       10 │ page_view      │ 2026-04-04 00:27:28 │          4 │
│       11 │ add_to_cart    │ 2026-04-04 00:28:31 │          4 │
│       12 │ page_view      │ 2026-04-04 00:32:19 │          4 │
│       13 │ page_view      │ 2026-04-04 00:33:20 │          4 │
╰──────────┴────────────────┴─────────────────────┴────────────╯
```

`(customer_id, session_no)` is now a proper session key. Note the running-sum
window uses `ORDER BY` with the default frame (everything up to the current
row) — exactly the Module 6 running-total idiom.

### Step 4 — session-level statistics

Group by the derived key and each session collapses to one row:

```sql
WITH with_prev AS (
    SELECT customer_id, event_id, event_type, occurred_at,
           LAG(occurred_at) OVER (
               PARTITION BY customer_id
               ORDER BY occurred_at, event_id
           ) AS prev_at
    FROM events
),
flagged AS (
    SELECT *,
           CASE
               WHEN prev_at IS NULL
                 OR (julianday(occurred_at) - julianday(prev_at)) * 24 * 60 > 30
               THEN 1 ELSE 0
           END AS is_session_start
    FROM with_prev
),
sessionized AS (
    SELECT *,
           SUM(is_session_start) OVER (
               PARTITION BY customer_id
               ORDER BY occurred_at, event_id
           ) AS session_no
    FROM flagged
),
sessions AS (
    SELECT customer_id, session_no,
           MIN(occurred_at) AS started_at,
           MAX(occurred_at) AS ended_at,
           COUNT(*)         AS n_events,
           ROUND((julianday(MAX(occurred_at)) - julianday(MIN(occurred_at))) * 24 * 60, 1)
                            AS duration_min,
           MAX(event_type = 'begin_checkout') AS reached_checkout
    FROM sessionized
    GROUP BY customer_id, session_no
)
SELECT * FROM sessions WHERE customer_id = 1 ORDER BY session_no;
```

```text
╭─────────────┬────────────┬─────────────────────┬─────────────────────┬──────────┬──────────────┬──────────────────╮
│ customer_id │ session_no │     started_at      │      ended_at       │ n_events │ duration_min │ reached_checkout │
╞═════════════╪════════════╪═════════════════════╪═════════════════════╪══════════╪══════════════╪══════════════════╡
│           1 │          1 │ 2025-07-22 04:23:37 │ 2025-07-22 04:23:37 │        1 │          0.0 │                0 │
│           1 │          2 │ 2025-08-10 14:18:51 │ 2025-08-10 14:29:00 │        3 │         10.1 │                0 │
│           1 │          3 │ 2026-01-31 23:47:15 │ 2026-02-01 00:20:01 │        8 │         32.8 │                1 │
│           1 │          4 │ 2026-04-04 00:23:12 │ 2026-04-04 00:33:20 │        5 │         10.1 │                0 │
╰─────────────┴────────────┴─────────────────────┴─────────────────────┴──────────┴──────────────┴──────────────────╯
```

`MAX(event_type = 'begin_checkout')` is a SQLite idiom: the comparison yields
0/1, so its `MAX` is "did any row match?". Session 3 is 32.8 minutes long yet
is a *single* session — every internal gap stayed under 30 minutes.

> **PostgreSQL note:** comparisons yield `boolean` there, and `MAX(boolean)`
> is an error. Write `BOOL_OR(event_type = 'begin_checkout')` or
> `MAX(CASE WHEN event_type = 'begin_checkout' THEN 1 ELSE 0 END)`.

Finally, the site-wide answer marketing asked for:

```sql
WITH with_prev AS (
    SELECT customer_id, event_id, event_type, occurred_at,
           LAG(occurred_at) OVER (
               PARTITION BY customer_id
               ORDER BY occurred_at, event_id
           ) AS prev_at
    FROM events
),
flagged AS (
    SELECT *,
           CASE
               WHEN prev_at IS NULL
                 OR (julianday(occurred_at) - julianday(prev_at)) * 24 * 60 > 30
               THEN 1 ELSE 0
           END AS is_session_start
    FROM with_prev
),
sessionized AS (
    SELECT *,
           SUM(is_session_start) OVER (
               PARTITION BY customer_id
               ORDER BY occurred_at, event_id
           ) AS session_no
    FROM flagged
),
sessions AS (
    SELECT customer_id, session_no,
           COUNT(*) AS n_events,
           ROUND((julianday(MAX(occurred_at)) - julianday(MIN(occurred_at))) * 24 * 60, 1) AS duration_min,
           MAX(event_type = 'begin_checkout') AS reached_checkout
    FROM sessionized
    GROUP BY customer_id, session_no
)
SELECT COUNT(*)                                   AS sessions,
       COUNT(DISTINCT customer_id)                AS visitors,
       ROUND(AVG(n_events), 2)                    AS avg_events,
       ROUND(AVG(duration_min), 1)                AS avg_duration_min,
       SUM(reached_checkout)                      AS checkout_sessions,
       ROUND(100.0 * AVG(reached_checkout), 2)    AS pct_reaching_checkout
FROM sessions;
```

```text
╭──────────┬──────────┬────────────┬──────────────────┬───────────────────┬───────────────────────╮
│ sessions │ visitors │ avg_events │ avg_duration_min │ checkout_sessions │ pct_reaching_checkout │
╞══════════╪══════════╪════════════╪══════════════════╪═══════════════════╪═══════════════════════╡
│     4106 │      738 │       3.99 │             10.8 │               260 │                  6.33 │
╰──────────┴──────────┴────────────┴──────────────────┴───────────────────┴───────────────────────╯
```

From a table with no session concept at all: 4,106 sessions, ~4 events and
~11 minutes each, 6.3% reaching checkout. This four-CTE pipeline
(`with_prev → flagged → sessionized → sessions`) is the canonical
gaps-and-islands shape — memorize it.

## 11.3 Gaps and islands II: consecutive-month streaks

Same pattern, different clothes. The retention team asks: *"Which customers
have ordered in the longest run of consecutive months?"* Here the islands are
runs of consecutive *month numbers* rather than bursts of timestamps, and
there is a slicker trick than the LAG-flag-sum pipeline: for consecutive
integer sequences, **`value − ROW_NUMBER()` is constant within an island**.

Convert each order month to a serial number (`year × 12 + month`), dedupe,
and subtract the row number:

```sql
WITH customer_months AS (
    SELECT DISTINCT
           customer_id,
           strftime('%Y-%m', ordered_at) AS order_month,
           CAST(strftime('%Y', ordered_at) AS INTEGER) * 12
             + CAST(strftime('%m', ordered_at) AS INTEGER) AS month_no
    FROM orders
    WHERE status <> 'cancelled'
),
islands AS (
    SELECT customer_id, order_month, month_no,
           month_no - ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY month_no
           ) AS island_id
    FROM customer_months
)
SELECT customer_id, order_month, month_no, island_id
FROM islands
WHERE customer_id = 7
ORDER BY month_no;
```

```text
╭─────────────┬─────────────┬──────────┬───────────╮
│ customer_id │ order_month │ month_no │ island_id │
╞═════════════╪═════════════╪══════════╪═══════════╡
│           7 │ 2023-09     │    24285 │     24284 │
│           7 │ 2023-12     │    24288 │     24286 │
│           7 │ 2024-02     │    24290 │     24287 │
│           7 │ 2024-03     │    24291 │     24287 │
│           7 │ 2024-04     │    24292 │     24287 │
│           7 │ 2024-05     │    24293 │     24287 │
│           7 │ 2024-08     │    24296 │     24289 │
│           7 │ 2024-09     │    24297 │     24289 │
│           7 │ 2024-10     │    24298 │     24289 │
│           7 │ 2024-11     │    24299 │     24289 │
│           7 │ 2024-12     │    24300 │     24289 │
│           7 │ 2025-02     │    24302 │     24290 │
│           7 │ 2025-05     │    24305 │     24292 │
│           7 │ 2025-07     │    24307 │     24293 │
│           7 │ 2025-08     │    24308 │     24293 │
│           7 │ 2025-09     │    24309 │     24293 │
│           7 │ 2025-12     │    24312 │     24295 │
│           7 │ 2026-01     │    24313 │     24295 │
│           7 │ 2026-02     │    24314 │     24295 │
│           7 │ 2026-07     │    24319 │     24299 │
╰─────────────┴─────────────┴──────────┴───────────╯
```

Watch how it works: within 2024-02 → 2024-05 both `month_no` and the row
number increase by exactly 1 per row, so their difference is frozen at 24287.
The moment a month is skipped, `month_no` jumps but the row number doesn't —
a new `island_id`. Two essentials: the `DISTINCT` (two orders in one month
must count once, or the row number outpaces the months and shatters the
islands) and the `WHERE status <> 'cancelled'` (an "active month" means a
non-cancelled order — the canonical active-customer definition).

Group by the island to get streaks, and rank them:

```sql
WITH customer_months AS (
    SELECT DISTINCT
           customer_id,
           strftime('%Y-%m', ordered_at) AS order_month,
           CAST(strftime('%Y', ordered_at) AS INTEGER) * 12
             + CAST(strftime('%m', ordered_at) AS INTEGER) AS month_no
    FROM orders
    WHERE status <> 'cancelled'
),
islands AS (
    SELECT customer_id, order_month, month_no,
           month_no - ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY month_no
           ) AS island_id
    FROM customer_months
),
streaks AS (
    SELECT customer_id,
           MIN(order_month) AS streak_start,
           MAX(order_month) AS streak_end,
           COUNT(*)         AS streak_months
    FROM islands
    GROUP BY customer_id, island_id
)
SELECT s.customer_id,
       c.first_name || ' ' || c.last_name AS customer,
       s.streak_start, s.streak_end, s.streak_months
FROM streaks s
JOIN customers c ON c.customer_id = s.customer_id
ORDER BY s.streak_months DESC, s.customer_id
LIMIT 10;
```

```text
╭─────────────┬─────────────────┬──────────────┬────────────┬───────────────╮
│ customer_id │    customer     │ streak_start │ streak_end │ streak_months │
╞═════════════╪═════════════════╪══════════════╪════════════╪═══════════════╡
│         682 │ Marco Costa     │ 2025-03      │ 2026-07    │            17 │
│         684 │ Birgitta Berg   │ 2025-06      │ 2026-07    │            14 │
│         363 │ Kirsten Blom    │ 2025-07      │ 2026-07    │            13 │
│         117 │ Hedda Strand    │ 2025-10      │ 2026-07    │            10 │
│         512 │ Ebba Sten       │ 2025-06      │ 2026-03    │            10 │
│           6 │ Mats Sjoberg    │ 2025-11      │ 2026-07    │             9 │
│          12 │ Wilma Magnusson │ 2025-12      │ 2026-07    │             8 │
│          42 │ Hanna Ricci     │ 2025-12      │ 2026-07    │             8 │
│         339 │ Viktor Strom    │ 2025-11      │ 2026-06    │             8 │
│         382 │ Ebba Olsen      │ 2025-02      │ 2025-09    │             8 │
╰─────────────┴─────────────────┴──────────────┴────────────┴───────────────╯
```

Marco Costa has ordered every single month for 17 straight months. The same
trick works for consecutive days (`julianday(date) - ROW_NUMBER()`), login
streaks, sensor uptime — any "consecutive integers" question.

## 11.4 Date spines and zero-filled time series

**The problem.** `GROUP BY month` can only produce rows for months that have
data. Months with *zero* sales silently vanish — which is precisely the signal
a trend report must show. Watch the Paddles category in 2023:

```sql
SELECT strftime('%Y-%m', o.ordered_at) AS month,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2)
           AS gross_revenue
FROM order_items oi
JOIN orders o     ON o.order_id = oi.order_id
JOIN products p   ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE c.name = 'Paddles'
  AND o.status <> 'cancelled'
  AND o.ordered_at >= '2023-01-01' AND o.ordered_at < '2024-01-01'
GROUP BY month
ORDER BY month;
```

```text
╭─────────┬───────────────╮
│  month  │ gross_revenue │
╞═════════╪═══════════════╡
│ 2023-04 │        199.21 │
│ 2023-05 │        234.36 │
│ 2023-10 │         206.8 │
│ 2023-11 │         69.15 │
╰─────────┴───────────────╯
```

Four rows for a twelve-month year. Feed this to a chart or a moving average
and eight zero-revenue months simply don't exist. The fix is a **date spine**:
a generated table with exactly one row per period, which the facts are
LEFT-JOINed onto. A recursive CTE (Module 5) builds one in four lines:

```sql
WITH RECURSIVE month_spine(month_start) AS (
    SELECT '2023-01-01'
    UNION ALL
    SELECT date(month_start, '+1 month')
    FROM month_spine
    WHERE month_start < '2023-12-01'
)
SELECT month_start, strftime('%Y-%m', month_start) AS month
FROM month_spine;
```

```text
╭─────────────┬─────────╮
│ month_start │  month  │
╞═════════════╪═════════╡
│ 2023-01-01  │ 2023-01 │
│ 2023-02-01  │ 2023-02 │
│ 2023-03-01  │ 2023-03 │
│ 2023-04-01  │ 2023-04 │
│ 2023-05-01  │ 2023-05 │
│ 2023-06-01  │ 2023-06 │
│ 2023-07-01  │ 2023-07 │
│ 2023-08-01  │ 2023-08 │
│ 2023-09-01  │ 2023-09 │
│ 2023-10-01  │ 2023-10 │
│ 2023-11-01  │ 2023-11 │
│ 2023-12-01  │ 2023-12 │
╰─────────────┴─────────╯
```

The termination condition compares against the *last desired row*
(`< '2023-12-01'` keeps recursing until December has been emitted). Now LEFT
JOIN the aggregate onto the spine, `COALESCE` the holes to zero, and — the
payoff — compute a moving average that is actually correct:

```sql
WITH RECURSIVE month_spine(month_start) AS (
    SELECT '2023-01-01'
    UNION ALL
    SELECT date(month_start, '+1 month')
    FROM month_spine
    WHERE month_start < '2023-12-01'
),
paddle_sales AS (
    SELECT strftime('%Y-%m', o.ordered_at) AS month,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
               AS gross_revenue
    FROM order_items oi
    JOIN orders o     ON o.order_id = oi.order_id
    JOIN products p   ON p.product_id = oi.product_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE c.name = 'Paddles'
      AND o.status <> 'cancelled'
    GROUP BY month
)
SELECT strftime('%Y-%m', s.month_start)          AS month,
       ROUND(COALESCE(ps.gross_revenue, 0), 2)   AS gross_revenue,
       ROUND(AVG(COALESCE(ps.gross_revenue, 0)) OVER (
           ORDER BY s.month_start
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 2)                                     AS mov_avg_3m
FROM month_spine s
LEFT JOIN paddle_sales ps ON ps.month = strftime('%Y-%m', s.month_start)
ORDER BY month;
```

```text
╭─────────┬───────────────┬────────────╮
│  month  │ gross_revenue │ mov_avg_3m │
╞═════════╪═══════════════╪════════════╡
│ 2023-01 │           0.0 │        0.0 │
│ 2023-02 │           0.0 │        0.0 │
│ 2023-03 │           0.0 │        0.0 │
│ 2023-04 │        199.21 │       66.4 │
│ 2023-05 │        234.36 │     144.52 │
│ 2023-06 │           0.0 │     144.52 │
│ 2023-07 │           0.0 │      78.12 │
│ 2023-08 │           0.0 │        0.0 │
│ 2023-09 │           0.0 │        0.0 │
│ 2023-10 │         206.8 │      68.93 │
│ 2023-11 │         69.15 │      91.98 │
│ 2023-12 │           0.0 │      91.98 │
╰─────────┴───────────────┴────────────╯
```

Why the spine is non-negotiable for the moving average: a window frame like
`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` slides over *rows*, not calendar
months. On the 4-row sparse result, "2 preceding" of 2023-10 would be 2023-04
and 2023-05 — a "3-month average" spanning seven months. On the spine, row
distance equals month distance, so the frame means what it says. Also note
`COALESCE` appears *inside* the `AVG`: `AVG` ignores NULLs (Module 3), so
without it the empty months would be skipped rather than averaged as zero —
144.52 in June would silently stay at 216.79.

> **PostgreSQL note:** no recursion needed —
> `SELECT generate_series('2023-01-01'::date, '2023-12-01', interval '1 month')`
> produces the spine directly.

## 11.5 Cohort retention

The classic growth question: *"Of the customers who made their first purchase
in month X, how many came back and bought again 1, 2, 3… months later?"* The
answer is a matrix — cohorts down the side, "months since first order" across
the top — and it composes three things you know: a `MIN` per customer, a month
difference, and a conditional-aggregation pivot.

The grain discipline that keeps this honest: build a table of **distinct
(customer, active-month) pairs** first, so no customer can be counted twice in
one cell no matter how many orders they placed that month. Cohort = month of
first non-cancelled order; active = at least one non-cancelled order in the
month (the canonical definition).

```sql
WITH first_orders AS (
    SELECT customer_id,
           MIN(ordered_at) AS first_ordered_at
    FROM orders
    WHERE status <> 'cancelled'
    GROUP BY customer_id
),
cohorts AS (
    SELECT customer_id,
           strftime('%Y-%m', first_ordered_at) AS cohort_month,
           CAST(strftime('%Y', first_ordered_at) AS INTEGER) * 12
             + CAST(strftime('%m', first_ordered_at) AS INTEGER) AS cohort_no
    FROM first_orders
),
activity AS (
    SELECT DISTINCT
           customer_id,
           CAST(strftime('%Y', ordered_at) AS INTEGER) * 12
             + CAST(strftime('%m', ordered_at) AS INTEGER) AS active_no
    FROM orders
    WHERE status <> 'cancelled'
)
SELECT c.cohort_month,
       COUNT(DISTINCT c.customer_id) AS cohort_size,
       COUNT(DISTINCT CASE WHEN a.active_no - c.cohort_no = 1 THEN a.customer_id END) AS m1,
       COUNT(DISTINCT CASE WHEN a.active_no - c.cohort_no = 2 THEN a.customer_id END) AS m2,
       COUNT(DISTINCT CASE WHEN a.active_no - c.cohort_no = 3 THEN a.customer_id END) AS m3,
       COUNT(DISTINCT CASE WHEN a.active_no - c.cohort_no = 4 THEN a.customer_id END) AS m4,
       COUNT(DISTINCT CASE WHEN a.active_no - c.cohort_no = 5 THEN a.customer_id END) AS m5
FROM cohorts c
JOIN activity a ON a.customer_id = c.customer_id
WHERE c.cohort_month BETWEEN '2025-07' AND '2026-01'
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
```

```text
╭──────────────┬─────────────┬────┬────┬────┬────┬────╮
│ cohort_month │ cohort_size │ m1 │ m2 │ m3 │ m4 │ m5 │
╞══════════════╪═════════════╪════╪════╪════╪════╪════╡
│ 2025-07      │          15 │  4 │  7 │  2 │  5 │  7 │
│ 2025-08      │          11 │  2 │  4 │  3 │  4 │  1 │
│ 2025-09      │          15 │  5 │  6 │  8 │  3 │  5 │
│ 2025-10      │          21 │  6 │ 11 │  7 │  8 │  6 │
│ 2025-11      │          25 │ 13 │  8 │  8 │  9 │  7 │
│ 2025-12      │          26 │ 12 │ 10 │ 15 │ 10 │ 11 │
│ 2026-01      │           9 │  4 │  7 │  4 │  6 │  5 │
╰──────────────┴─────────────┴────┴────┴────┴────┴────╯
```

Read a row: of the 25 customers acquired in 2025-11, 13 ordered again the
following month (52%), 8 two months out, and so on. Three things to note:

- `COUNT(DISTINCT CASE ... THEN customer_id END)` is the belt-and-suspenders
  form of the conditional pivot: the `CASE` yields NULL for non-matching rows
  (never counted), and the `DISTINCT` makes the query immune to grain mistakes
  in the join. The Pitfalls section shows what happens without it.
- Month arithmetic uses the same `year × 12 + month` serial as §11.3 —
  `strftime('%Y-%m', a) - strftime('%Y-%m', b)` would be string arithmetic
  nonsense.
- We stop at cohort 2026-01 so every cell has had time to happen (2026-01 + 5
  months = 2026-06, fully inside the data). Showing m5 for a 2026-05 cohort
  would display a structural zero as churn — a classic cohort-reporting lie.

## 11.6 RFM segmentation

Marketing wants customers bucketed for campaigns: who are the **champions**,
who is **at risk**? RFM scores each customer on **R**ecency (days since last
order), **F**requency (number of orders), **M**onetary (total spend), then
buckets each dimension into quintiles with `NTILE` (Module 6). Metrics follow
the canon: non-cancelled orders, item revenue for spend, reference date
2026-07-14 (the newest order date in the data).

```sql
WITH customer_orders AS (
    SELECT o.customer_id,
           MAX(o.ordered_at)    AS last_order_at,
           COUNT(DISTINCT o.order_id) AS n_orders,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
                                AS gross_spend
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.customer_id
),
rfm_base AS (
    SELECT customer_id,
           CAST(julianday('2026-07-14') - julianday(last_order_at) AS INTEGER)
               AS recency_days,
           n_orders   AS frequency,
           gross_spend AS monetary
    FROM customer_orders
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(5) OVER (ORDER BY frequency)         AS f_score,
           NTILE(5) OVER (ORDER BY monetary)          AS m_score
    FROM rfm_base
)
SELECT customer_id, recency_days, frequency, ROUND(monetary, 2) AS monetary,
       r_score, f_score, m_score
FROM scored
ORDER BY customer_id
LIMIT 8;
```

```text
╭─────────────┬──────────────┬───────────┬──────────┬─────────┬─────────┬─────────╮
│ customer_id │ recency_days │ frequency │ monetary │ r_score │ f_score │ m_score │
╞═════════════╪══════════════╪═══════════╪══════════╪═════════╪═════════╪═════════╡
│           2 │           33 │         2 │  1162.92 │       3 │       1 │       2 │
│           3 │           34 │         4 │  1631.34 │       3 │       2 │       2 │
│           4 │           19 │        13 │  9531.74 │       4 │       4 │       5 │
│           5 │           37 │        12 │  3387.56 │       3 │       4 │       3 │
│           6 │            7 │        28 │ 10636.87 │       5 │       5 │       5 │
│           7 │            6 │        29 │ 18368.11 │       5 │       5 │       5 │
│           9 │           31 │         3 │   962.45 │       3 │       2 │       1 │
│          10 │           32 │         8 │  3908.98 │       3 │       3 │       3 │
╰─────────────┴──────────────┴───────────┴──────────┴─────────┴─────────┴─────────╯
```

The convention is **5 = best** on every axis, which dictates the sort
directions: `recency_days DESC` puts the *stalest* customers in bucket 1,
while `frequency` and `monetary` ascend so heavy buyers land in bucket 5.
Getting a sort direction backwards silently inverts a score — always eyeball a
few known customers (customer 7, who ordered 6 days ago, 29 times, for €18k,
is 5/5/5 — sanity confirmed).

Now translate score combinations into names the marketing team can act on:

```sql
WITH customer_orders AS (
    SELECT o.customer_id,
           MAX(o.ordered_at)          AS last_order_at,
           COUNT(DISTINCT o.order_id) AS n_orders,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
                                      AS gross_spend
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.customer_id
),
rfm_base AS (
    SELECT customer_id,
           CAST(julianday('2026-07-14') - julianday(last_order_at) AS INTEGER)
               AS recency_days,
           n_orders    AS frequency,
           gross_spend AS monetary
    FROM customer_orders
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(5) OVER (ORDER BY frequency)         AS f_score,
           NTILE(5) OVER (ORDER BY monetary)          AS m_score
    FROM rfm_base
),
labeled AS (
    SELECT *,
           CASE
               WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'champions'
               WHEN r_score >= 4 AND f_score >= 3                  THEN 'loyal'
               WHEN r_score >= 4                                   THEN 'recent'
               WHEN r_score <= 2 AND f_score >= 4                  THEN 'at risk'
               WHEN r_score <= 2 AND f_score <= 2                  THEN 'hibernating'
               ELSE 'needs attention'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                      AS customers,
       ROUND(AVG(recency_days))      AS avg_recency_days,
       ROUND(AVG(frequency), 1)      AS avg_orders,
       ROUND(SUM(monetary))          AS total_gross_spend
FROM labeled
GROUP BY segment
ORDER BY total_gross_spend DESC;
```

```text
╭─────────────────┬───────────┬──────────────────┬────────────┬───────────────────╮
│     segment     │ customers │ avg_recency_days │ avg_orders │ total_gross_spend │
╞═════════════════╪═══════════╪══════════════════╪════════════╪═══════════════════╡
│ champions       │       153 │              9.0 │       18.1 │         1520310.0 │
│ needs attention │       191 │             88.0 │        7.6 │          801367.0 │
│ at risk         │        39 │            130.0 │       12.2 │          257311.0 │
│ loyal           │        68 │             10.0 │        6.8 │          235329.0 │
│ hibernating     │       175 │            322.0 │        2.2 │          209050.0 │
│ recent          │        47 │             13.0 │        2.7 │           63373.0 │
╰─────────────────┴───────────┴──────────────────┴────────────┴───────────────────╯
```

The story writes itself: 153 champions generate €1.52M — nearly half of all
revenue — and 39 "at risk" customers (historically heavy buyers, silent for
~4 months) are worth €257k of win-back campaign. Note the `CASE` ladder is
order-sensitive: the first matching `WHEN` wins, so put the most specific
segments first.

## 11.7 Funnel analysis

*"Where do we lose people between browsing and checkout?"* A funnel counts
entities that reached each stage: `page_view → add_to_cart → begin_checkout`.
The clean way at the customer level is conditional aggregation — collapse each
customer's event history into one row of stage flags:

```sql
SELECT customer_id,
       MAX(CASE WHEN event_type = 'page_view'      THEN 1 ELSE 0 END) AS viewed,
       MAX(CASE WHEN event_type = 'add_to_cart'    THEN 1 ELSE 0 END) AS carted,
       MAX(CASE WHEN event_type = 'begin_checkout' THEN 1 ELSE 0 END) AS checked_out
FROM events
GROUP BY customer_id
ORDER BY customer_id
LIMIT 6;
```

```text
╭─────────────┬────────┬────────┬─────────────╮
│ customer_id │ viewed │ carted │ checked_out │
╞═════════════╪════════╪════════╪═════════════╡
│           1 │      1 │      1 │           1 │
│           3 │      1 │      1 │           0 │
│           4 │      1 │      1 │           1 │
│           5 │      1 │      1 │           0 │
│           6 │      1 │      0 │           0 │
│           7 │      1 │      1 │           1 │
╰─────────────┴────────┴────────┴─────────────╯
```

Then aggregate the flags. Multiplying flags (`viewed * carted`) enforces the
funnel's *and*-logic — a customer counts at step 2 only if they hit steps 1
and 2:

```sql
WITH customer_funnel AS (
    SELECT customer_id,
           MAX(CASE WHEN event_type = 'page_view'      THEN 1 ELSE 0 END) AS viewed,
           MAX(CASE WHEN event_type = 'add_to_cart'    THEN 1 ELSE 0 END) AS carted,
           MAX(CASE WHEN event_type = 'begin_checkout' THEN 1 ELSE 0 END) AS checked_out
    FROM events
    GROUP BY customer_id
)
SELECT SUM(viewed)                                        AS step1_viewed,
       SUM(viewed * carted)                               AS step2_carted,
       SUM(viewed * carted * checked_out)                 AS step3_checkout,
       ROUND(100.0 * SUM(viewed * carted) / SUM(viewed), 1)
           AS pct_view_to_cart,
       ROUND(100.0 * SUM(viewed * carted * checked_out) / SUM(viewed * carted), 1)
           AS pct_cart_to_checkout,
       ROUND(100.0 * SUM(viewed * carted * checked_out) / SUM(viewed), 1)
           AS pct_overall
FROM customer_funnel;
```

```text
╭──────────────┬──────────────┬────────────────┬──────────────────┬──────────────────────┬─────────────╮
│ step1_viewed │ step2_carted │ step3_checkout │ pct_view_to_cart │ pct_cart_to_checkout │ pct_overall │
╞══════════════╪══════════════╪════════════════╪══════════════════╪══════════════════════╪═════════════╡
│          738 │          590 │            203 │             79.9 │                 34.4 │        27.5 │
╰──────────────┴──────────────┴────────────────┴──────────────────┴──────────────────────┴─────────────╯
```

The diagnosis is immediate: view→cart converts at a healthy 79.9%, but
cart→checkout collapses to 34.4% — the cart page is where Nordkart bleeds.
Two design notes. First, this is a *lifetime, unordered* funnel: it doesn't
require the cart event to come chronologically after a view. For a
time-ordered variant you'd compare `MIN(occurred_at)` per stage or run the
funnel within the §11.2 sessions. Second, percentages divide by the *previous*
step, not step 1 — that's what localizes the leak.

> **PostgreSQL note:** conditional aggregation reads better with the `FILTER`
> clause: `COUNT(*) FILTER (WHERE event_type = 'add_to_cart')`. SQLite also
> supports `FILTER` on aggregates; `CASE` shown here is the fully portable
> form.

## 11.8 Pivoting and unpivoting

Analysts think in matrices; SQL thinks in long, skinny tables. **Pivoting**
(long→wide) is conditional aggregation again — one `SUM(CASE)` per desired
column. Operations wants a month × status matrix of 2026 orders to watch the
fulfillment pipeline:

```sql
SELECT strftime('%Y-%m', ordered_at) AS month,
       SUM(CASE WHEN status = 'pending'   THEN 1 ELSE 0 END) AS pending,
       SUM(CASE WHEN status = 'paid'      THEN 1 ELSE 0 END) AS paid,
       SUM(CASE WHEN status = 'shipped'   THEN 1 ELSE 0 END) AS shipped,
       SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
       SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
       SUM(CASE WHEN status = 'returned'  THEN 1 ELSE 0 END) AS returned
FROM orders
WHERE ordered_at >= '2026-01-01'
GROUP BY month
ORDER BY month;
```

```text
╭─────────┬─────────┬──────┬─────────┬───────────┬───────────┬──────────╮
│  month  │ pending │ paid │ shipped │ delivered │ cancelled │ returned │
╞═════════╪═════════╪══════╪═════════╪═══════════╪═══════════╪══════════╡
│ 2026-01 │       0 │    0 │       0 │       190 │        13 │       11 │
│ 2026-02 │       0 │    0 │       0 │       214 │        11 │        3 │
│ 2026-03 │       0 │    0 │       0 │       280 │        18 │        8 │
│ 2026-04 │       0 │    0 │       0 │       338 │        16 │        8 │
│ 2026-05 │       0 │    0 │       0 │       424 │        23 │       12 │
│ 2026-06 │       0 │    0 │      27 │       530 │        26 │       13 │
│ 2026-07 │      63 │   90 │     126 │        84 │        25 │        0 │
╰─────────┴─────────┴──────┴─────────┴───────────┴───────────┴──────────╯
```

The matrix instantly shows operational reality: old months have fully settled
into `delivered`/`cancelled`/`returned`, while July (the current month) still
carries its work-in-progress. The limitation: **columns are hard-coded**. SQL
requires the column list at parse time, so a new status means editing the
query. When the categories are dynamic, deliver the long format and let the
BI tool pivot.

**Unpivoting** (wide→long) is one `SELECT ... UNION ALL` per column — the move
you need when someone hands you a spreadsheet-shaped table:

```sql
WITH status_matrix AS (
    SELECT strftime('%Y-%m', ordered_at) AS month,
           SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
           SUM(CASE WHEN status = 'returned'  THEN 1 ELSE 0 END) AS returned
    FROM orders
    WHERE ordered_at >= '2026-05-01'
    GROUP BY month
)
SELECT month, 'cancelled' AS status, cancelled AS n_orders FROM status_matrix
UNION ALL
SELECT month, 'returned',  returned  FROM status_matrix
ORDER BY month, status;
```

```text
╭─────────┬───────────┬──────────╮
│  month  │  status   │ n_orders │
╞═════════╪═══════════╪══════════╡
│ 2026-05 │ cancelled │       23 │
│ 2026-05 │ returned  │       12 │
│ 2026-06 │ cancelled │       26 │
│ 2026-06 │ returned  │       13 │
│ 2026-07 │ cancelled │       25 │
│ 2026-07 │ returned  │        0 │
╰─────────┴───────────┴──────────╯
```

Column names in the second and later branches of a `UNION ALL` are taken from
the first branch — you may still write them for readability.

> **PostgreSQL note:** the `crosstab()` function (extension `tablefunc`) can
> pivot, and `FILTER` shortens the `CASE`s, but the columns-known-in-advance
> restriction is identical. There is no standard dynamic pivot in SQL.

## 11.9 Point-in-time (as-of) joins

**The problem.** `order_items.unit_price` stores the price *at order time*;
`products.unit_price` stores the price *now*. Joining facts to current
attributes is one of the most common — and most quietly catastrophic —
mistakes in analytics: every historical margin, discount, and audit number
comes out wrong. The cure is a history table like `price_history`, an SCD
type 2 shape where each row carries a validity range and the current row has
`valid_to IS NULL`.

An **as-of join** matches each fact to the dimension row *that was valid at
the fact's timestamp* — a join on a range condition rather than equality:

```sql
SELECT oi.order_id, oi.product_id, o.ordered_at,
       oi.unit_price AS charged, ph.price AS listed_then,
       ph.valid_from, ph.valid_to
FROM order_items oi
JOIN orders o        ON o.order_id = oi.order_id
JOIN price_history ph
  ON ph.product_id = oi.product_id
 AND o.ordered_at BETWEEN ph.valid_from
                      AND COALESCE(ph.valid_to, '9999-12-31')
WHERE oi.product_id = 1
ORDER BY o.ordered_at
LIMIT 6;
```

```text
╭──────────┬────────────┬─────────────────────┬─────────┬─────────────┬─────────────────────┬─────────────────────╮
│ order_id │ product_id │     ordered_at      │ charged │ listed_then │     valid_from      │      valid_to       │
╞══════════╪════════════╪═════════════════════╪═════════╪═════════════╪═════════════════════╪═════════════════════╡
│     4296 │          1 │ 2023-01-01 17:51:33 │  111.52 │      111.52 │ 2022-09-04 09:36:44 │ 2023-07-08 04:25:04 │
│     2500 │          1 │ 2023-02-05 04:20:57 │  111.52 │      111.52 │ 2022-09-04 09:36:44 │ 2023-07-08 04:25:04 │
│     1535 │          1 │ 2023-02-11 07:08:45 │  111.52 │      111.52 │ 2022-09-04 09:36:44 │ 2023-07-08 04:25:04 │
│     3935 │          1 │ 2023-02-13 12:02:22 │  111.52 │      111.52 │ 2022-09-04 09:36:44 │ 2023-07-08 04:25:04 │
│      444 │          1 │ 2023-03-24 23:34:38 │  111.52 │      111.52 │ 2022-09-04 09:36:44 │ 2023-07-08 04:25:04 │
│     4375 │          1 │ 2023-03-29 18:08:14 │  111.52 │      111.52 │ 2022-09-04 09:36:44 │ 2023-07-08 04:25:04 │
╰──────────┴────────────┴─────────────────────┴─────────┴─────────────┴─────────────────────┴─────────────────────╯
```

The `COALESCE(ph.valid_to, '9999-12-31')` is the load-bearing part: the
currently-valid row has `valid_to = NULL`, and `x BETWEEN a AND NULL` is
never true (three-valued logic, Module 2), so without the `COALESCE` every
order priced under the *current* price silently vanishes from an inner join.
The Pitfalls section quantifies the damage.

Because the query is cheap to write, turn it into two **assertion queries** —
queries designed to return a known value (here: full coverage, zero
mismatches) so any future drift screams at you. First: does every order line
find exactly one price row?

```sql
SELECT (SELECT COUNT(*) FROM order_items) AS order_lines,
       COUNT(*) AS matched_lines
FROM order_items oi
JOIN orders o        ON o.order_id = oi.order_id
JOIN price_history ph
  ON ph.product_id = oi.product_id
 AND o.ordered_at BETWEEN ph.valid_from
                      AND COALESCE(ph.valid_to, '9999-12-31')
;
```

```text
╭─────────────┬───────────────╮
│ order_lines │ matched_lines │
╞═════════════╪═══════════════╡
│       13475 │         13475 │
╰─────────────┴───────────────╯
```

Equal counts prove both *coverage* (no line missed a range) and *uniqueness*
(no line matched two overlapping ranges — that would push `matched_lines`
above 13,475). Second: was every customer charged the listed price?

```sql
SELECT COUNT(*) AS mismatched_lines
FROM order_items oi
JOIN orders o        ON o.order_id = oi.order_id
JOIN price_history ph
  ON ph.product_id = oi.product_id
 AND o.ordered_at BETWEEN ph.valid_from
                      AND COALESCE(ph.valid_to, '9999-12-31')
WHERE ABS(oi.unit_price - ph.price) > 0.005;
```

```text
╭──────────────────╮
│ mismatched_lines │
╞══════════════════╡
│                0 │
╰──────────────────╯
```

Zero. Note `ABS(a - b) > 0.005` instead of `a <> b` — prices are REAL, and
Module 2 taught you never to compare floats for exact equality. One
refinement for your own schemas: `BETWEEN` is inclusive on both ends, so an
event stamped *exactly* at a boundary matches both the ending and the starting
row. The strict SCD2 convention is a half-open interval:
`o.ordered_at >= ph.valid_from AND (ph.valid_to IS NULL OR o.ordered_at < ph.valid_to)`.
With sub-second timestamps collisions are rare, which is why the `BETWEEN`
idiom survives in the wild — but write the half-open form when you control
the code.

## 11.10 Percentiles and medians without PERCENTILE_CONT

Averages lie when distributions are skewed — and order values always are.
SQLite has no `PERCENTILE_CONT`, so you need two workarounds that every
data engineer improvises sooner or later.

**The ordered-offset method (exact).** Number the rows in order, count them,
and pick the middle. `AVG` over the one or two middle rows handles odd and
even counts in one query — with integer division, `(n+1)/2` and `(n+2)/2`
are the same row when `n` is odd and the two middle rows when `n` is even:

```sql
WITH order_totals AS (
    SELECT o.order_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
             + o.shipping_cost AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id, o.shipping_cost
),
ranked AS (
    SELECT order_total,
           ROW_NUMBER() OVER (ORDER BY order_total) AS rn,
           COUNT(*)    OVER ()                      AS n
    FROM order_totals
)
SELECT n AS orders,
       ROUND(AVG(order_total), 2) AS median_order_value
FROM ranked
WHERE rn IN ((n + 1) / 2, (n + 2) / 2);
```

```text
╭────────┬────────────────────╮
│ orders │ median_order_value │
╞════════╪════════════════════╡
│   5685 │             382.34 │
╰────────┴────────────────────╯
```

(`order_totals` implements the canonical order-total definition: item revenue
plus shipping, non-cancelled orders only.) Compare with the mean — the AOV:

```sql
WITH order_totals AS (
    SELECT o.order_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
             + o.shipping_cost AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id, o.shipping_cost
)
SELECT ROUND(AVG(order_total), 2) AS aov FROM order_totals;
```

```text
╭────────╮
│  aov   │
╞════════╡
│ 548.65 │
╰────────╯
```

AOV €548.65 vs median €382.34 — the *typical* order is 30% smaller than the
mean suggests, because a tail of huge orders drags the average up. Reporting
both is professional practice. Any percentile works the same way — the 90th
is the row at rank ⌊0.9 × n⌋ (the "nearest-rank" definition):

```sql
WITH order_totals AS (
    SELECT o.order_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
             + o.shipping_cost AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id, o.shipping_cost
),
ranked AS (
    SELECT order_total,
           ROW_NUMBER() OVER (ORDER BY order_total) AS rn,
           COUNT(*)    OVER ()                      AS n
    FROM order_totals
)
SELECT ROUND(order_total, 2) AS p90_order_value
FROM ranked
WHERE rn = CAST(n * 0.90 AS INTEGER);
```

```text
╭─────────────────╮
│ p90_order_value │
╞═════════════════╡
│          1239.1 │
╰─────────────────╯
```

**The NTILE method (bucket boundaries).** When you want the whole
distribution at a glance rather than one exact cut point, `NTILE(10)` and a
`GROUP BY` produce a decile table:

```sql
WITH order_totals AS (
    SELECT o.order_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
             + o.shipping_cost AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id, o.shipping_cost
),
buckets AS (
    SELECT order_total,
           NTILE(10) OVER (ORDER BY order_total) AS decile
    FROM order_totals
)
SELECT decile,
       ROUND(MIN(order_total), 2) AS from_value,
       ROUND(MAX(order_total), 2) AS to_value,
       COUNT(*)                   AS orders
FROM buckets
GROUP BY decile
ORDER BY decile;
```

```text
╭────────┬────────────┬──────────┬────────╮
│ decile │ from_value │ to_value │ orders │
╞════════╪════════════╪══════════╪════════╡
│      1 │       7.77 │    80.36 │    569 │
│      2 │      80.36 │    130.7 │    569 │
│      3 │      130.7 │   208.91 │    569 │
│      4 │     209.04 │    285.8 │    569 │
│      5 │     285.87 │   382.98 │    569 │
│      6 │     383.02 │   505.05 │    568 │
│      7 │     505.43 │   671.22 │    568 │
│      8 │     672.05 │   871.84 │    568 │
│      9 │     872.24 │  1240.56 │    568 │
│     10 │    1240.73 │  4629.29 │    568 │
╰────────┴────────────┴──────────┴────────╯
```

The decile-5/6 boundary (~383) reproduces the median; the decile-9 ceiling
(~1240) reproduces the p90. `NTILE` boundaries are approximate — bucket sizes
are forced equal, so ties can straddle buckets — but for "show me the shape"
questions the table above is exactly what stakeholders want.

> **PostgreSQL note:** use the real thing:
> `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_total)` — an *ordered-set
> aggregate* that also interpolates between rows. `PERCENTILE_DISC` gives the
> nearest-rank behavior of our offset method.

## 11.11 A taste of JSON

Modern pipelines constantly hand nested documents to APIs and event buses —
and receive them. SQLite's built-in JSON functions cover both directions.
**Composing:** `json_object` builds an object per row, `json_group_array` is
an *aggregate* that collects values into an array — combined, they nest a
one-to-many relationship into a single document:

```sql
SELECT json_object(
           'order_id',   o.order_id,
           'status',     o.status,
           'ordered_at', o.ordered_at,
           'items', json_group_array(
               json_object(
                   'sku',        p.sku,
                   'name',       p.name,
                   'qty',        oi.quantity,
                   'unit_price', oi.unit_price
               )
           )
       ) AS order_doc
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.order_id = 74
GROUP BY o.order_id;
```

```text
╭──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│                                                                                                                order_doc                                                                                                                 │
╞══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╡
│ {"order_id":74,"status":"returned","ordered_at":"2025-12-20 07:18:37","items":[{"sku":"NK-04-0083","name":"Trek Water Filter","qty":1,"unit_price":142.38},{"sku":"NK-08-0253","name":"Crag Chest Harness","qty":1,"unit_price":53.69}]} │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
```

**Shredding:** `json_each` is a table-valued function — put it in the `FROM`
clause and each array element becomes a row, addressable with `json_extract`:

```sql
WITH order_doc AS (
    SELECT json_object(
               'order_id', o.order_id,
               'items', json_group_array(
                   json_object('sku', p.sku, 'qty', oi.quantity)
               )
           ) AS doc
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.order_id = 74
    GROUP BY o.order_id
)
SELECT json_extract(item.value, '$.sku') AS sku,
       json_extract(item.value, '$.qty') AS qty
FROM order_doc,
     json_each(order_doc.doc, '$.items') AS item;
```

```text
╭────────────┬─────╮
│    sku     │ qty │
╞════════════╪═════╡
│ NK-04-0083 │   1 │
│ NK-08-0253 │   1 │
╰────────────┴─────╯
```

Round trip complete: relational → nested → relational. This is deliberately a
taste, not a meal — treat JSON columns as a landing zone for semi-structured
data, not a substitute for modeling (Module 7).

> **PostgreSQL note:** Postgres's `jsonb` type is far more powerful — binary
> storage, GIN indexes, containment operators (`@>`), `jsonb_path_query`. The
> composing/shredding equivalents are `jsonb_build_object`, `jsonb_agg`, and
> `jsonb_array_elements`.

## Pitfalls

### Pitfall 1 — sessionizing with fixed time buckets instead of inactivity gaps

The tempting shortcut: "just truncate timestamps to 30-minute buckets and
count distinct buckets as sessions." It compiles, it runs, it's wrong —
a session is defined by *inactivity*, not by where the wall clock happens to
be. Watch it butcher customer 1, whose real sessions we established in §11.2:

```sql
-- BAD: assigns events to fixed 30-minute wall-clock buckets;
-- a continuous browse that crosses a bucket edge is split in two
SELECT event_id, occurred_at,
       strftime('%Y-%m-%d %H', occurred_at)
         || ':' || (CAST(strftime('%M', occurred_at) AS INTEGER) / 30) AS bucket
FROM events
WHERE customer_id = 1
ORDER BY occurred_at, event_id;
```

```text
╭──────────┬─────────────────────┬─────────────────╮
│ event_id │     occurred_at     │     bucket      │
╞══════════╪═════════════════════╪═════════════════╡
│       14 │ 2025-07-22 04:23:37 │ 2025-07-22 04:0 │
│       15 │ 2025-08-10 14:18:51 │ 2025-08-10 14:0 │
│       16 │ 2025-08-10 14:23:43 │ 2025-08-10 14:0 │
│       17 │ 2025-08-10 14:29:00 │ 2025-08-10 14:0 │
│        1 │ 2026-01-31 23:47:15 │ 2026-01-31 23:1 │
│        2 │ 2026-01-31 23:49:42 │ 2026-01-31 23:1 │
│        3 │ 2026-01-31 23:55:53 │ 2026-01-31 23:1 │
│        4 │ 2026-01-31 23:57:32 │ 2026-01-31 23:1 │
│        5 │ 2026-02-01 00:02:00 │ 2026-02-01 00:0 │
│        6 │ 2026-02-01 00:07:55 │ 2026-02-01 00:0 │
│        7 │ 2026-02-01 00:13:19 │ 2026-02-01 00:0 │
│        8 │ 2026-02-01 00:20:01 │ 2026-02-01 00:0 │
│        9 │ 2026-04-04 00:23:12 │ 2026-04-04 00:0 │
│       10 │ 2026-04-04 00:27:28 │ 2026-04-04 00:0 │
│       11 │ 2026-04-04 00:28:31 │ 2026-04-04 00:0 │
│       12 │ 2026-04-04 00:32:19 │ 2026-04-04 00:1 │
│       13 │ 2026-04-04 00:33:20 │ 2026-04-04 00:1 │
╰──────────┴─────────────────────┴─────────────────╯
```

Customer 1 has 4 real sessions; the buckets produce 6. The midnight session
(events 1–8, one continuous 33-minute browse) is chopped at 00:00, and the
April session is chopped at 00:30 even though the "gap" there was 3.8 minutes.
Site-wide, the damage compounds:

```sql
-- BAD: counts distinct (customer, bucket) pairs as "sessions"
SELECT COUNT(DISTINCT customer_id || '|' || strftime('%Y-%m-%d %H', occurred_at)
              || ':' || (CAST(strftime('%M', occurred_at) AS INTEGER) / 30)) AS bucket_sessions
FROM events;
```

```text
╭─────────────────╮
│ bucket_sessions │
╞═════════════════╡
│            5610 │
╰─────────────────╯
```

The fix is the §11.2 pipeline — session starts are events whose gap from the
*previous event* exceeds 30 minutes, so counting the starts gives the true
session count:

```sql
WITH with_prev AS (
    SELECT customer_id, occurred_at, event_id,
           LAG(occurred_at) OVER (
               PARTITION BY customer_id
               ORDER BY occurred_at, event_id
           ) AS prev_at
    FROM events
)
SELECT SUM(CASE
               WHEN prev_at IS NULL
                 OR (julianday(occurred_at) - julianday(prev_at)) * 24 * 60 > 30
               THEN 1 ELSE 0
           END) AS true_sessions
FROM with_prev;
```

```text
╭───────────────╮
│ true_sessions │
╞═══════════════╡
│          4106 │
╰───────────────╯
```

5,610 vs 4,106 — the bucket method invents 37% more sessions, which would
deflate every per-session metric (events, duration, conversion) you report.

### Pitfall 2 — cohort matrices inflated by join fan-out

Join a cohort table (one row per customer) to `orders` (many rows per
customer) and count *rows* with `SUM(CASE)`, and every multi-order month is
counted multiple times — the Module 4 fan-out pitfall wearing analytics
clothing:

```sql
-- BAD: the join is at order grain, so SUM(CASE) counts orders, not customers
WITH first_orders AS (
    SELECT customer_id, MIN(ordered_at) AS first_ordered_at
    FROM orders
    WHERE status <> 'cancelled'
    GROUP BY customer_id
),
cohorts AS (
    SELECT customer_id,
           strftime('%Y-%m', first_ordered_at) AS cohort_month,
           CAST(strftime('%Y', first_ordered_at) AS INTEGER) * 12
             + CAST(strftime('%m', first_ordered_at) AS INTEGER) AS cohort_no
    FROM first_orders
)
SELECT c.cohort_month,
       COUNT(DISTINCT c.customer_id) AS cohort_size,
       SUM(CASE WHEN CAST(strftime('%Y', o.ordered_at) AS INTEGER) * 12
                     + CAST(strftime('%m', o.ordered_at) AS INTEGER)
                     - c.cohort_no = 1 THEN 1 ELSE 0 END) AS m1,
       SUM(CASE WHEN CAST(strftime('%Y', o.ordered_at) AS INTEGER) * 12
                     + CAST(strftime('%m', o.ordered_at) AS INTEGER)
                     - c.cohort_no = 2 THEN 1 ELSE 0 END) AS m2
FROM cohorts c
JOIN orders o ON o.customer_id = c.customer_id AND o.status <> 'cancelled'
WHERE c.cohort_month BETWEEN '2025-10' AND '2025-12'
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
```

```text
╭──────────────┬─────────────┬────┬────╮
│ cohort_month │ cohort_size │ m1 │ m2 │
╞══════════════╪═════════════╪════╪════╡
│ 2025-10      │          21 │ 11 │ 19 │
│ 2025-11      │          25 │ 31 │ 14 │
│ 2025-12      │          26 │ 25 │ 23 │
╰──────────────┴─────────────┴────┴────╯
```

Look at 2025-11: **31 retained out of a cohort of 25** — 124% retention. The
absurdity is visible here, but in a cohort that's merely inflated from 40% to
55% nobody would notice, and the deck ships. The fix is to count *customers*,
not rows — `COUNT(DISTINCT CASE ...)`:

```sql
WITH first_orders AS (
    SELECT customer_id, MIN(ordered_at) AS first_ordered_at
    FROM orders
    WHERE status <> 'cancelled'
    GROUP BY customer_id
),
cohorts AS (
    SELECT customer_id,
           strftime('%Y-%m', first_ordered_at) AS cohort_month,
           CAST(strftime('%Y', first_ordered_at) AS INTEGER) * 12
             + CAST(strftime('%m', first_ordered_at) AS INTEGER) AS cohort_no
    FROM first_orders
)
SELECT c.cohort_month,
       COUNT(DISTINCT c.customer_id) AS cohort_size,
       COUNT(DISTINCT CASE WHEN CAST(strftime('%Y', o.ordered_at) AS INTEGER) * 12
                                + CAST(strftime('%m', o.ordered_at) AS INTEGER)
                                - c.cohort_no = 1 THEN o.customer_id END) AS m1,
       COUNT(DISTINCT CASE WHEN CAST(strftime('%Y', o.ordered_at) AS INTEGER) * 12
                                + CAST(strftime('%m', o.ordered_at) AS INTEGER)
                                - c.cohort_no = 2 THEN o.customer_id END) AS m2
FROM cohorts c
JOIN orders o ON o.customer_id = c.customer_id AND o.status <> 'cancelled'
WHERE c.cohort_month BETWEEN '2025-10' AND '2025-12'
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
```

```text
╭──────────────┬─────────────┬────┬────╮
│ cohort_month │ cohort_size │ m1 │ m2 │
╞══════════════╪═════════════╪════╪════╡
│ 2025-10      │          21 │  6 │ 11 │
│ 2025-11      │          25 │ 13 │  8 │
│ 2025-12      │          26 │ 12 │ 10 │
╰──────────────┴─────────────┴────┴────╯
```

Matching §11.5 exactly. Belt *and* suspenders is better still: pre-aggregate
activity to distinct (customer, month) grain before joining, as §11.5 does —
then the join cannot fan out in the first place.

### Pitfall 3 — as-of join that loses the open-ended current row

Forget the `COALESCE` in the range condition and the currently-valid price
rows (`valid_to IS NULL`) match nothing — `BETWEEN` against a NULL bound is
UNKNOWN, and an inner join drops the row without a sound:

```sql
-- BAD: valid_to IS NULL makes BETWEEN evaluate to UNKNOWN,
-- so every order priced under the current price row disappears
SELECT COUNT(*) AS matched_lines
FROM order_items oi
JOIN orders o        ON o.order_id = oi.order_id
JOIN price_history ph
  ON ph.product_id = oi.product_id
 AND o.ordered_at BETWEEN ph.valid_from AND ph.valid_to;
```

```text
╭───────────────╮
│ matched_lines │
╞═══════════════╡
│          4005 │
╰───────────────╯
```

4,005 of 13,475 order lines — **70% of the audit silently gone**, and
precisely the *recent* 70%, biasing any conclusion toward ancient history.
No error, no warning; only the coverage assertion catches it. The fix from
§11.9 closes the open end:

```sql
SELECT (SELECT COUNT(*) FROM order_items) AS order_lines,
       COUNT(*) AS matched_lines
FROM order_items oi
JOIN orders o        ON o.order_id = oi.order_id
JOIN price_history ph
  ON ph.product_id = oi.product_id
 AND o.ordered_at BETWEEN ph.valid_from
                      AND COALESCE(ph.valid_to, '9999-12-31')
;
```

```text
╭─────────────┬───────────────╮
│ order_lines │ matched_lines │
╞═════════════╪═══════════════╡
│       13475 │         13475 │
╰─────────────┴───────────────╯
```

The general lesson: **whenever you join, assert the row count you expect.**
Fan-out (Pitfall 2) makes it too big; NULL range bounds make it too small;
only the assertion tells you which.

## Exercises

Answer each with a single query (CTE pipelines encouraged). No answers here —
solutions with explanations live in `solutions/11-advanced-analytics.md`.

**Warm-up**

1. Using only `price_history`, find each product's *current* price (the row
   with the latest `valid_from`) via `ROW_NUMBER`, and verify it against the
   catalog: report how many products were checked and how many disagree with
   `products.unit_price` by more than half a cent (expected: 0 — an assertion
   query).
2. Build a country × year matrix: for each customer country, how many
   non-cancelled orders were placed in 2023, 2024, 2025, and 2026 (one column
   per year)? Sort by the 2026 column, descending.
3. The category team asks for Jackets order volume by month for 2024,
   *including months with no jacket orders* (count each order once even if it
   contains several jacket products). Use a recursive date spine.

**Core**

4. Produce the payment follow-up worklist: every order whose **latest**
   payment attempt has status `failed`, with the customer's email, the
   amount, and when the failure happened — newest first. How many such orders
   are there in total?
5. Sessionize `events` with the 30-minute rule and report, per month of 2026:
   number of sessions, average events per session, average session duration
   in minutes, and the percentage of sessions containing a `begin_checkout`.
   (A session belongs to the month it *started* in.)
6. Which 5 customers currently hold the longest *live* ordering streak — a
   run of consecutive months with at least one non-cancelled order that is
   still unbroken as of 2026-07? Show name, streak start, and length in
   months.
7. Retention as percentages: for each first-order cohort from 2025-07 through
   2025-12, show cohort size and the share of the cohort active 1, 2, and 3
   months later (one decimal place).
8. Extend the funnel into a per-step drop-off table: one row per stage
   (`page_view`, `add_to_cart`, `begin_checkout`) with the number of
   customers reaching it, the number *dropped* since the previous stage, and
   the percentage retained from the previous stage. (Hint: compute the three
   counts once in a CTE, then unpivot with `UNION ALL`.)

**Challenge**

9. RFM in action: marketing wants a win-back list — the 10 highest-spending
   **at-risk** customers (recency score ≤ 2 but frequency score ≥ 4 on
   `NTILE(5)` quintiles, reference date 2026-07-14). Show email, recency in
   days, order count, and gross spend, biggest spenders first.
10. Write the full as-of price audit as an assertion: return every order line
    whose `unit_price` differs from the `price_history` price in effect at
    `ordered_at` by more than half a cent — the result should be **empty** —
    and accompany it with a coverage check proving all 13,475 lines matched
    exactly one validity range. Your range condition must handle the
    open-ended current rows.
11. Median order value per country: for non-cancelled orders, compute each
    customer country's median order total (items + shipping), highest first.
    (Per-group medians need `PARTITION BY` in both the `ROW_NUMBER` and the
    `COUNT`.)
12. Produce a single JSON document for Nordkart's highest-grossing customer:
    `customer_id`, full name, gross spend, and a `last_orders` array holding
    their 3 most recent non-cancelled orders (order id, date, order total).

## Key takeaways

- **Latest row per group:** `ROW_NUMBER() OVER (PARTITION BY grp ORDER BY ts DESC, id DESC)` then `rn = 1`. Always add a tie-breaker; correlated-`MAX` and group-by-join leak duplicate rows on ties.
- **Gaps and islands (sessionization):** `LAG` the timestamp → flag rows where the gap exceeds the threshold → running `SUM` of flags = island id → `GROUP BY` the id. Session rule is *inactivity*, never wall-clock buckets.
- **Consecutive sequences (streaks):** `value − ROW_NUMBER()` is constant within a run of consecutive integers. Dedupe first; convert months to `year*12 + month` before subtracting.
- **Date spine:** recursive CTE emitting one row per period; `LEFT JOIN` facts onto it; `COALESCE(x, 0)` — *inside* any windowed `AVG`. Moving averages require the spine because frames count rows, not calendar.
- **Cohort matrix:** cohort = month of first qualifying order; pivot with `COUNT(DISTINCT CASE WHEN diff = k THEN customer_id END)`; join at distinct (customer, month) grain or fan-out inflates retention past 100%.
- **RFM:** `NTILE(5)` per dimension; mind sort directions (5 = best); label segments with an order-sensitive `CASE` ladder.
- **Funnel:** per-entity stage flags via `MAX(CASE ...)`, then `SUM` products of flags; divide each step by the *previous* step to localize the leak.
- **Pivot:** one `SUM(CASE WHEN cat = 'x' THEN ...)` per column; columns are hard-coded by design. **Unpivot:** one `UNION ALL` branch per column.
- **As-of join:** `fact.ts BETWEEN dim.valid_from AND COALESCE(dim.valid_to, '9999-12-31')`; prefer half-open `>= valid_from AND (valid_to IS NULL OR ts < valid_to)`. Assert coverage: matched rows = fact rows.
- **Median without PERCENTILE_CONT:** `ROW_NUMBER` + `COUNT(*) OVER ()`, average rows `(n+1)/2` and `(n+2)/2`; percentile p at rank `CAST(n * p AS INTEGER)`; `NTILE` for whole-distribution bucket tables.
- **JSON:** `json_object` per row, `json_group_array` to aggregate children, `json_each` (table-valued, in `FROM`) + `json_extract` to shred.
- **Meta-rule:** every analytical join gets an assertion query. Expected counts, zero-row mismatch checks — they cost a minute and catch the silent disasters.
