# Module 11 Solutions — Advanced Analytics

Every solution was run against `shop.db`; outputs are shown verbatim
(truncated with `LIMIT` where noted).

## Warm-up

### Exercise 1 — current price from history, verified

```sql
WITH ranked AS (
    SELECT product_id, price, valid_from,
           ROW_NUMBER() OVER (
               PARTITION BY product_id
               ORDER BY valid_from DESC
           ) AS rn
    FROM price_history
)
SELECT COUNT(*) AS products_checked,
       SUM(CASE WHEN ABS(r.price - p.unit_price) > 0.005 THEN 1 ELSE 0 END)
           AS price_mismatches
FROM ranked r
JOIN products p ON p.product_id = r.product_id
WHERE r.rn = 1;
```

```text
╭──────────────────┬──────────────────╮
│ products_checked │ price_mismatches │
╞══════════════════╪══════════════════╡
│              350 │                0 │
╰──────────────────┴──────────────────╯
```

Latest-row-per-group with `ROW_NUMBER` ordered by `valid_from DESC`; `rn = 1`
is each product's current price row. All 350 products agree with the catalog —
the assertion passes. Note `ABS(diff) > 0.005` rather than `<>`: prices are
REAL, and exact float equality is never trustworthy. A common wrong approach
is `WHERE valid_to IS NULL` — it happens to work here, but the `ROW_NUMBER`
form also survives history tables where the current row's `valid_to` is set
to a far-future date instead of NULL.

### Exercise 2 — country × year order matrix

```sql
SELECT c.country,
       SUM(CASE WHEN o.ordered_at LIKE '2023%' THEN 1 ELSE 0 END) AS y2023,
       SUM(CASE WHEN o.ordered_at LIKE '2024%' THEN 1 ELSE 0 END) AS y2024,
       SUM(CASE WHEN o.ordered_at LIKE '2025%' THEN 1 ELSE 0 END) AS y2025,
       SUM(CASE WHEN o.ordered_at LIKE '2026%' THEN 1 ELSE 0 END) AS y2026
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.status <> 'cancelled'
GROUP BY c.country
ORDER BY y2026 DESC;
```

```text
╭────────────────┬───────┬───────┬───────┬───────╮
│    country     │ y2023 │ y2024 │ y2025 │ y2026 │
╞════════════════╪═══════╪═══════╪═══════╪═══════╡
│ Sweden         │    77 │   244 │   603 │   606 │
│ Germany        │    54 │    97 │   272 │   365 │
│ Norway         │    39 │    88 │   213 │   284 │
│ Denmark        │    55 │   122 │   245 │   274 │
│ United Kingdom │    22 │   106 │   163 │   206 │
│ Netherlands    │    16 │    72 │   165 │   186 │
│ France         │    14 │    53 │    92 │   176 │
│ Switzerland    │    23 │    42 │    94 │   131 │
│ Finland        │    18 │    75 │   139 │   125 │
│ Austria        │     8 │     9 │    44 │    68 │
╰────────────────┴───────┴───────┴───────┴───────╯
```

A pure `SUM(CASE)` pivot; `strftime('%Y', ordered_at) = '2023'` works equally
well as the `LIKE` prefix test. Sorting by the newest column surfaces where
the business is *now* — Sweden leads, France is the fastest 2025→2026 grower.

### Exercise 3 — Jackets by month in 2024, zero-filled

```sql
WITH RECURSIVE month_spine(month_start) AS (
    SELECT '2024-01-01'
    UNION ALL
    SELECT date(month_start, '+1 month')
    FROM month_spine
    WHERE month_start < '2024-12-01'
),
jacket_orders AS (
    SELECT strftime('%Y-%m', o.ordered_at) AS month,
           COUNT(DISTINCT o.order_id)      AS n_orders
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    JOIN categories c   ON c.category_id = p.category_id
    WHERE c.name = 'Jackets'
      AND o.status <> 'cancelled'
    GROUP BY month
)
SELECT strftime('%Y-%m', s.month_start) AS month,
       COALESCE(j.n_orders, 0)          AS jacket_orders
FROM month_spine s
LEFT JOIN jacket_orders j ON j.month = strftime('%Y-%m', s.month_start)
ORDER BY month;
```

```text
╭─────────┬───────────────╮
│  month  │ jacket_orders │
╞═════════╪═══════════════╡
│ 2024-01 │             0 │
│ 2024-02 │             1 │
│ 2024-03 │             1 │
│ 2024-04 │             1 │
│ 2024-05 │             3 │
│ 2024-06 │             2 │
│ 2024-07 │             3 │
│ 2024-08 │             2 │
│ 2024-09 │             3 │
│ 2024-10 │             5 │
│ 2024-11 │             7 │
│ 2024-12 │            14 │
╰─────────┴───────────────╯
```

The spine guarantees twelve rows; the LEFT JOIN + `COALESCE` turns the silent
gap (January — zero jacket orders) into a visible 0. `COUNT(DISTINCT
o.order_id)` matters: an order containing two jacket products would otherwise
count twice — the join to `order_items` is at line grain, not order grain.

## Core

### Exercise 4 — payment follow-up worklist

```sql
WITH ranked AS (
    SELECT order_id, amount, status, paid_at,
           ROW_NUMBER() OVER (
               PARTITION BY order_id
               ORDER BY paid_at DESC, payment_id DESC
           ) AS rn
    FROM payments
)
SELECT o.order_id, c.email, r.amount, r.paid_at AS failed_at
FROM ranked r
JOIN orders o    ON o.order_id = r.order_id
JOIN customers c ON c.customer_id = o.customer_id
WHERE r.rn = 1
  AND r.status = 'failed'
ORDER BY r.paid_at DESC
LIMIT 10;
```

```text
╭──────────┬──────────────────────────────┬─────────┬─────────────────────╮
│ order_id │            email             │ amount  │      failed_at      │
╞══════════╪══════════════════════════════╪═════════╪═════════════════════╡
│     5389 │ tobias.kron@gmail.com        │    54.4 │ 2026-07-12 00:09:54 │
│     4283 │ gustav.wall@icloud.com       │  414.23 │ 2026-07-06 04:29:35 │
│     5201 │ fatima.sten@proton.me        │ 3443.44 │ 2026-06-23 01:06:49 │
│     3358 │ viktor.strom@gmail.com       │    29.3 │ 2026-05-10 18:42:57 │
│     2502 │ rebecka.persson@fastmail.com │  294.89 │ 2026-03-26 19:34:32 │
│      410 │ nora.ahmed@gmail.com         │  172.12 │ 2026-03-23 11:21:59 │
│      880 │ sonja.kowalski@gmail.com     │  775.98 │ 2026-01-30 15:04:43 │
│      983 │ leila.hansen@outlook.com     │  858.71 │ 2026-01-09 08:00:24 │
│      662 │ ragnar.moller@outlook.com    │  163.68 │ 2025-12-25 12:36:34 │
│     5145 │ freja.okafor@outlook.com     │ 1247.65 │ 2025-12-05 15:27:54 │
╰──────────┴──────────────────────────────┴─────────┴─────────────────────╯
```

The total count:

```sql
WITH ranked AS (
    SELECT order_id, status,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY paid_at DESC, payment_id DESC) AS rn
    FROM payments
)
SELECT COUNT(*) FROM ranked WHERE rn = 1 AND status = 'failed';
```

```text
╭──────────╮
│ COUNT(*) │
╞══════════╡
│       24 │
╰──────────╯
```

24 orders whose *latest* attempt failed. The common wrong approach —
`WHERE status = 'failed'` on raw `payments` — returns 342 rows, because it
includes every failure that was later retried successfully. Only the
latest-row filter distinguishes "failed once" from "still failing". The
`payment_id DESC` tie-breaker also matters: order 3676 has a failure and a
capture in the same second, and without the tie-breaker which one represents
the order is arbitrary.

### Exercise 5 — monthly session stats for 2026

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
           COUNT(*)         AS n_events,
           ROUND((julianday(MAX(occurred_at)) - julianday(MIN(occurred_at))) * 24 * 60, 1)
                            AS duration_min,
           MAX(event_type = 'begin_checkout') AS reached_checkout
    FROM sessionized
    GROUP BY customer_id, session_no
)
SELECT strftime('%Y-%m', started_at)            AS month,
       COUNT(*)                                 AS sessions,
       ROUND(AVG(n_events), 2)                  AS avg_events,
       ROUND(AVG(duration_min), 1)              AS avg_minutes,
       ROUND(100.0 * AVG(reached_checkout), 1)  AS pct_checkout
FROM sessions
WHERE started_at >= '2026-01-01'
GROUP BY month
ORDER BY month;
```

```text
╭─────────┬──────────┬────────────┬─────────────┬──────────────╮
│  month  │ sessions │ avg_events │ avg_minutes │ pct_checkout │
╞═════════╪══════════╪════════════╪═════════════╪══════════════╡
│ 2026-01 │      182 │       4.19 │        11.4 │          7.7 │
│ 2026-02 │      156 │       3.88 │        10.2 │          6.4 │
│ 2026-03 │      206 │       3.85 │        10.1 │          5.8 │
│ 2026-04 │      254 │       4.18 │        11.6 │          9.1 │
│ 2026-05 │      258 │       4.09 │        11.0 │          8.1 │
│ 2026-06 │      306 │       3.63 │         9.5 │          5.6 │
│ 2026-07 │      197 │       3.95 │        10.0 │          5.1 │
╰─────────┴──────────┴────────────┴─────────────┴──────────────╯
```

The full §11.2 pipeline with one extra decision: filtering on
`started_at >= '2026-01-01'` *after* sessionizing (so a session is attributed
to the month it started, and sessions are built from the complete event
history). Filtering `events` to 2026 *before* sessionizing would be subtly
wrong — a session straddling New Year's Eve would lose its first events and be
mis-dated.

### Exercise 6 — longest live streaks

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
               PARTITION BY customer_id ORDER BY month_no
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
       s.streak_start, s.streak_months
FROM streaks s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.streak_end = '2026-07'
ORDER BY s.streak_months DESC, s.customer_id
LIMIT 5;
```

```text
╭─────────────┬───────────────┬──────────────┬───────────────╮
│ customer_id │   customer    │ streak_start │ streak_months │
╞═════════════╪═══════════════╪══════════════╪═══════════════╡
│         682 │ Marco Costa   │ 2025-03      │            17 │
│         684 │ Birgitta Berg │ 2025-06      │            14 │
│         363 │ Kirsten Blom  │ 2025-07      │            13 │
│         117 │ Hedda Strand  │ 2025-10      │            10 │
│           6 │ Mats Sjoberg  │ 2025-11      │             9 │
╰─────────────┴───────────────┴──────────────┴───────────────╯
```

Identical to the module's streak query plus one filter: `streak_end =
'2026-07'` keeps only islands that reach the current month — i.e., unbroken
streaks. Marco Costa's 17-month run is both the longest ever and still alive.

### Exercise 7 — retention as percentages

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
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.active_no - c.cohort_no = 1 THEN a.customer_id END)
             / COUNT(DISTINCT c.customer_id), 1) AS pct_m1,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.active_no - c.cohort_no = 2 THEN a.customer_id END)
             / COUNT(DISTINCT c.customer_id), 1) AS pct_m2,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.active_no - c.cohort_no = 3 THEN a.customer_id END)
             / COUNT(DISTINCT c.customer_id), 1) AS pct_m3
FROM cohorts c
JOIN activity a ON a.customer_id = c.customer_id
WHERE c.cohort_month BETWEEN '2025-07' AND '2025-12'
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
```

```text
╭──────────────┬─────────────┬────────┬────────┬────────╮
│ cohort_month │ cohort_size │ pct_m1 │ pct_m2 │ pct_m3 │
╞══════════════╪═════════════╪════════╪════════╪════════╡
│ 2025-07      │          15 │   26.7 │   46.7 │   13.3 │
│ 2025-08      │          11 │   18.2 │   36.4 │   27.3 │
│ 2025-09      │          15 │   33.3 │   40.0 │   53.3 │
│ 2025-10      │          21 │   28.6 │   52.4 │   33.3 │
│ 2025-11      │          25 │   52.0 │   32.0 │   32.0 │
│ 2025-12      │          26 │   46.2 │   38.5 │   57.7 │
╰──────────────┴─────────────┴────────┴────────┴────────╯
```

Same matrix as §11.5 with each cell divided by the cohort size. The `100.0`
(not `100`) forces float division — with integer division every percentage
would silently round down to a whole number of percent, or to zero. Note the
denominator is `COUNT(DISTINCT c.customer_id)`, computed in the same pass —
no second query, no join back.

### Exercise 8 — funnel with per-step drop-off

```sql
WITH customer_funnel AS (
    SELECT customer_id,
           MAX(CASE WHEN event_type = 'page_view'      THEN 1 ELSE 0 END) AS viewed,
           MAX(CASE WHEN event_type = 'add_to_cart'    THEN 1 ELSE 0 END) AS carted,
           MAX(CASE WHEN event_type = 'begin_checkout' THEN 1 ELSE 0 END) AS checked_out
    FROM events
    GROUP BY customer_id
),
counts AS (
    SELECT SUM(viewed)                        AS s1,
           SUM(viewed * carted)               AS s2,
           SUM(viewed * carted * checked_out) AS s3
    FROM customer_funnel
),
steps AS (
    SELECT 1 AS step, 'page_view' AS stage, s1 AS customers, NULL AS prev FROM counts
    UNION ALL
    SELECT 2, 'add_to_cart',    s2, s1 FROM counts
    UNION ALL
    SELECT 3, 'begin_checkout', s3, s2 FROM counts
)
SELECT step, stage, customers,
       prev - customers                          AS dropped,
       ROUND(100.0 * customers / prev, 1)        AS pct_of_previous
FROM steps
ORDER BY step;
```

```text
╭──────┬────────────────┬───────────┬─────────┬─────────────────╮
│ step │     stage      │ customers │ dropped │ pct_of_previous │
╞══════╪════════════════╪═══════════╪═════════╪═════════════════╡
│    1 │ page_view      │       738 │         │                 │
│    2 │ add_to_cart    │       590 │     148 │            79.9 │
│    3 │ begin_checkout │       203 │     387 │            34.4 │
╰──────┴────────────────┴───────────┴─────────┴─────────────────╯
```

The §11.7 conditional-aggregation funnel, unpivoted into a step table with
`UNION ALL` (§11.8) — each branch carries the *previous* step's count along
so drop-off is a simple subtraction. Step 1's `dropped` and `pct_of_previous`
are NULL by construction (`NULL` prev), which renders as blank — honest
reporting for "there is no previous step". The big leak is unmistakable:
387 customers abandon between cart and checkout.

## Challenge

### Exercise 9 — at-risk win-back list

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
scored AS (
    SELECT customer_id,
           CAST(julianday('2026-07-14') - julianday(last_order_at) AS INTEGER)
               AS recency_days,
           n_orders    AS frequency,
           gross_spend AS monetary,
           NTILE(5) OVER (ORDER BY julianday('2026-07-14') - julianday(last_order_at) DESC)
               AS r_score,
           NTILE(5) OVER (ORDER BY n_orders)    AS f_score,
           NTILE(5) OVER (ORDER BY gross_spend) AS m_score
    FROM customer_orders
)
SELECT s.customer_id, c.email,
       s.recency_days, s.frequency, ROUND(s.monetary, 2) AS gross_spend
FROM scored s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.r_score <= 2 AND s.f_score >= 4
ORDER BY s.monetary DESC
LIMIT 10;
```

```text
╭─────────────┬──────────────────────────┬──────────────┬───────────┬─────────────╮
│ customer_id │          email           │ recency_days │ frequency │ gross_spend │
╞═════════════╪══════════════════════════╪══════════════╪═══════════╪═════════════╡
│         631 │ hugo.kim@fastmail.com    │          125 │        23 │    13108.43 │
│         305 │ hans.olsson@hotmail.com  │          132 │        15 │    11264.04 │
│          14 │ anders.vik@gmail.com     │           98 │        15 │    10303.79 │
│         384 │ katja.sjoberg@gmail.com  │          143 │        19 │     9414.41 │
│         324 │ priya.lind@gmail.com     │           99 │        21 │     9216.83 │
│         544 │ felix.yilmaz@hotmail.com │          196 │        12 │      8995.9 │
│         416 │ gustav.sjoberg@gmail.com │          113 │        14 │     8818.52 │
│         270 │ javier.duarte@gmail.com  │           92 │         9 │     7526.04 │
│         311 │ johan.holm@fastmail.com  │          107 │        13 │     7340.49 │
│         165 │ ulf.lundgren@yahoo.com   │          106 │        14 │     7279.14 │
╰─────────────┴──────────────────────────┴──────────────┴───────────┴─────────────╯
```

Exactly the customers a win-back campaign wants: Hugo Kim placed 23 orders
worth €13k, then went silent for 4 months. The critical detail is the
`r_score` sort direction — `recency_days DESC` puts the *most stale* customers
in bucket 1, so `r_score <= 2` means "long silent". Sort it ascending by
mistake and this query returns your most active customers instead — the exact
opposite campaign, and nothing errors.

### Exercise 10 — as-of price audit (assertion)

The mismatch check — this query is expected to return nothing:

```sql
SELECT oi.order_id, oi.product_id, o.ordered_at,
       oi.unit_price AS charged, ph.price AS listed_then
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN price_history ph
  ON ph.product_id = oi.product_id
 AND o.ordered_at >= ph.valid_from
 AND (ph.valid_to IS NULL OR o.ordered_at < ph.valid_to)
WHERE ABS(oi.unit_price - ph.price) > 0.005;
```

```text
```

No rows — the assertion passes: every one of the 13,475 order lines was
charged exactly the price in effect at order time. The coverage companion
proves the empty result means "all correct" rather than "nothing matched":

```sql
SELECT (SELECT COUNT(*) FROM order_items) AS order_lines,
       COUNT(*)                           AS matched_lines
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN price_history ph
  ON ph.product_id = oi.product_id
 AND o.ordered_at >= ph.valid_from
 AND (ph.valid_to IS NULL OR o.ordered_at < ph.valid_to);
```

```text
╭─────────────┬───────────────╮
│ order_lines │ matched_lines │
╞═════════════╪═══════════════╡
│       13475 │         13475 │
╰─────────────┴───────────────╯
```

This solution uses the half-open interval form (`>= valid_from AND (< valid_to
OR IS NULL)`) rather than `BETWEEN ... COALESCE(...)` — both pass here; the
half-open form is the stricter SCD2 convention because it cannot double-match
a fact stamped exactly on a boundary. The classic failure is omitting the NULL
handling entirely: the audit then silently skips the 9,470 lines priced under
each product's *current* price and reports a hollow "0 mismatches" — which is
why the coverage check is not optional.

### Exercise 11 — median order value per country

```sql
WITH order_totals AS (
    SELECT o.order_id, c.country,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
             + o.shipping_cost AS order_total
    FROM orders o
    JOIN customers c    ON c.customer_id = o.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id, c.country, o.shipping_cost
),
ranked AS (
    SELECT country, order_total,
           ROW_NUMBER() OVER (PARTITION BY country ORDER BY order_total) AS rn,
           COUNT(*)    OVER (PARTITION BY country)                       AS n
    FROM order_totals
)
SELECT country,
       MAX(n)                     AS orders,
       ROUND(AVG(CASE WHEN rn IN ((n + 1) / 2, (n + 2) / 2)
                      THEN order_total END), 2) AS median_order_value
FROM ranked
GROUP BY country
ORDER BY median_order_value DESC;
```

```text
╭────────────────┬────────┬────────────────────╮
│    country     │ orders │ median_order_value │
╞════════════════╪════════╪════════════════════╡
│ Netherlands    │    439 │             441.36 │
│ Finland        │    357 │             401.06 │
│ Sweden         │   1530 │              389.0 │
│ Norway         │    624 │             387.58 │
│ Germany        │    788 │              378.8 │
│ France         │    335 │              375.3 │
│ Switzerland    │    290 │             360.19 │
│ United Kingdom │    497 │             356.44 │
│ Denmark        │    696 │             354.58 │
│ Austria        │    129 │             350.42 │
╰────────────────┴────────┴────────────────────╯
```

The module's ordered-offset median, made per-group: both the `ROW_NUMBER` and
the `COUNT(*)` windows get `PARTITION BY country`, and instead of filtering
with `WHERE rn IN (...)` (which would leave nothing to `GROUP BY`), the
middle-row test moves inside a conditional `AVG` — non-middle rows contribute
NULL, which `AVG` ignores. `AVG(CASE ...)` handles even-sized countries (two
middle rows averaged) and odd-sized ones (one row twice named) uniformly.

### Exercise 12 — top customer as a JSON document

```sql
WITH spend AS (
    SELECT o.customer_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_spend
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.customer_id
    ORDER BY gross_spend DESC
    LIMIT 1
),
last_orders AS (
    SELECT o.customer_id, o.order_id, o.ordered_at,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
                 + o.shipping_cost, 2) AS order_total,
           ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.ordered_at DESC) AS rn
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.customer_id = (SELECT customer_id FROM spend)
      AND o.status <> 'cancelled'
    GROUP BY o.customer_id, o.order_id, o.ordered_at, o.shipping_cost
)
SELECT json_object(
           'customer_id', c.customer_id,
           'name',        c.first_name || ' ' || c.last_name,
           'gross_spend', ROUND(s.gross_spend, 2),
           'last_orders', (
               SELECT json_group_array(
                          json_object('order_id',   lo.order_id,
                                      'ordered_at', lo.ordered_at,
                                      'total',      lo.order_total)
                      )
               FROM last_orders lo
               WHERE lo.rn <= 3
           )
       ) AS customer_doc
FROM spend s
JOIN customers c ON c.customer_id = s.customer_id;
```

```text
╭──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│                                                                                                                                         customer_doc                                                                                                                                         │
╞══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╡
│ {"customer_id":684,"name":"Birgitta Berg","gross_spend":29439.99,"last_orders":[{"order_id":3363,"ordered_at":"2026-07-14 16:21:48","total":31.46},{"order_id":1324,"ordered_at":"2026-07-07 01:34:53","total":388.96},{"order_id":5400,"ordered_at":"2026-07-04 03:16:58","total":166.82}]} │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
```

Three patterns stacked: latest-row-per-group (`ROW_NUMBER ... rn <= 3` picks
the three most recent orders — top-N, the general form of `rn = 1`), the
canonical order total at order grain, and `json_object` +
`json_group_array` to nest the array. Birgitta Berg — 14-month streak holder
from Exercise 6 — is also the top spender at €29,439.99. One subtlety:
`json_group_array` has no ORDER BY guarantee in SQLite; if the array's order
is contractual, add an explicit `ORDER BY` subquery or sort downstream.
