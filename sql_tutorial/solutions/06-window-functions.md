# Module 6 Solutions — Window Functions

All queries run against `shop.db`. Metric definitions are the canonical ones
from `DATASET.md`.

## Warm-up

### Exercise 1 — Rating vs. product average (product 105)

```sql
SELECT review_id, rating,
       ROUND(AVG(rating) OVER (), 2)          AS product_avg,
       ROUND(rating - AVG(rating) OVER (), 2) AS diff_from_avg
FROM reviews
WHERE product_id = 105
ORDER BY rating DESC, review_id;
```

```text
╭───────────┬────────┬─────────────┬───────────────╮
│ review_id │ rating │ product_avg │ diff_from_avg │
╞═══════════╪════════╪═════════════╪═══════════════╡
│       484 │      5 │         4.1 │           0.9 │
│       814 │      5 │         4.1 │           0.9 │
│      2108 │      5 │         4.1 │           0.9 │
│      2661 │      5 │         4.1 │           0.9 │
│       110 │      4 │         4.1 │          -0.1 │
│      1046 │      4 │         4.1 │          -0.1 │
│      1835 │      4 │         4.1 │          -0.1 │
│      2433 │      4 │         4.1 │          -0.1 │
│      3321 │      3 │         4.1 │          -1.1 │
│      1133 │      2 │         4.1 │          -2.1 │
╰───────────┴────────┴─────────────┴───────────────╯
```

Because the `WHERE` restricts the query to product 105's reviews, an empty
`OVER ()` already means "average of this product's reviews" — no
`PARTITION BY` needed. Every review row survives, annotated with the average.

### Exercise 2 — Order sequence for customer 44

```sql
SELECT customer_id, order_id, date(ordered_at) AS order_date,
       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY ordered_at) AS order_seq
FROM orders
WHERE status <> 'cancelled' AND customer_id = 44
ORDER BY order_seq;
```

```text
╭─────────────┬──────────┬────────────┬───────────╮
│ customer_id │ order_id │ order_date │ order_seq │
╞═════════════╪══════════╪════════════╪═══════════╡
│          44 │     4120 │ 2026-05-13 │         1 │
│          44 │     2927 │ 2026-05-17 │         2 │
│          44 │     1906 │ 2026-05-18 │         3 │
│          44 │     2725 │ 2026-05-23 │         4 │
│          44 │     2044 │ 2026-05-29 │         5 │
│          44 │     3762 │ 2026-07-06 │         6 │
│          44 │     4020 │ 2026-07-10 │         7 │
│          44 │     5358 │ 2026-07-11 │         8 │
╰─────────────┴──────────┴────────────┴───────────╯
```

`PARTITION BY customer_id ORDER BY ordered_at` numbers each customer's orders
independently. Pre-filtering to `customer_id = 44` is safe *only* because the
filter matches the partition key — removing other customers can't change
customer 44's numbering. (Filtering on anything that removes some of customer
44's own rows — like a date range — *would* change the numbers; then you must
window first in a CTE, filter after.)

### Exercise 3 — 2024 monthly revenue and share of year

```sql
WITH monthly_revenue AS (
  SELECT strftime('%Y-%m', o.ordered_at) AS month,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
    AND o.ordered_at >= '2024-01-01' AND o.ordered_at < '2025-01-01'
  GROUP BY 1
)
SELECT month,
       ROUND(gross_revenue, 2)                                       AS gross_revenue,
       ROUND(100.0 * gross_revenue / SUM(gross_revenue) OVER (), 1)  AS pct_of_year
FROM monthly_revenue
ORDER BY month;
```

```text
╭─────────┬───────────────┬─────────────╮
│  month  │ gross_revenue │ pct_of_year │
╞═════════╪═══════════════╪═════════════╡
│ 2024-01 │      13397.55 │         2.9 │
│ 2024-02 │      14889.06 │         3.2 │
│ 2024-03 │      30423.04 │         6.5 │
│ 2024-04 │      16825.65 │         3.6 │
│ 2024-05 │      30355.46 │         6.5 │
│ 2024-06 │      33060.91 │         7.1 │
│ 2024-07 │      42748.66 │         9.1 │
│ 2024-08 │      29256.78 │         6.2 │
│ 2024-09 │      35031.52 │         7.5 │
│ 2024-10 │      42771.06 │         9.1 │
│ 2024-11 │      62271.32 │        13.3 │
│ 2024-12 │     117650.48 │        25.1 │
╰─────────┴───────────────┴─────────────╯
```

December 2024 alone carried 25.1% of the year. `SUM(gross_revenue) OVER ()`
is the year total because the CTE only contains 2024 rows — the window's scope
is whatever the query feeds it.

## Core

### Exercise 4 — MoM growth for 2025 (with a real January number)

```sql
WITH monthly_revenue AS (
  SELECT strftime('%Y-%m', o.ordered_at) AS month,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
    AND o.ordered_at >= '2024-12-01' AND o.ordered_at < '2026-01-01'
  GROUP BY 1
),
with_growth AS (
  SELECT month,
         gross_revenue,
         LAG(gross_revenue) OVER (ORDER BY month) AS prev_revenue
  FROM monthly_revenue
)
SELECT month,
       ROUND(gross_revenue, 2) AS gross_revenue,
       ROUND(100.0 * (gross_revenue - prev_revenue) / prev_revenue, 1) AS growth_pct
FROM with_growth
WHERE month >= '2025-01'
ORDER BY month;
```

```text
╭─────────┬───────────────┬────────────╮
│  month  │ gross_revenue │ growth_pct │
╞═════════╪═══════════════╪════════════╡
│ 2025-01 │      38104.81 │      -67.6 │
│ 2025-02 │      42952.29 │       12.7 │
│ 2025-03 │      53015.78 │       23.4 │
│ 2025-04 │      56496.34 │        6.6 │
│ 2025-05 │       71880.5 │       27.2 │
│ 2025-06 │      93965.19 │       30.7 │
│ 2025-07 │      98034.15 │        4.3 │
│ 2025-08 │      83420.47 │      -14.9 │
│ 2025-09 │      97520.64 │       16.9 │
│ 2025-10 │       99072.5 │        1.6 │
│ 2025-11 │     150279.76 │       51.7 │
│ 2025-12 │     244602.36 │       62.8 │
╰─────────┴───────────────┴────────────╯
```

The trick: the CTE includes **December 2024** so `LAG` has something to see
for January (-67.6% off the holiday peak). The `WHERE month >= '2025-01'`
then trims December from the *display* — after the window ran. **Common wrong
approach:** filtering the CTE to `>= '2025-01-01'` — January's growth comes
back NULL because `LAG` only sees rows inside the query.

### Exercise 5 — 3-month moving average, 12 most recent months

```sql
WITH monthly_revenue AS (
  SELECT strftime('%Y-%m', o.ordered_at) AS month,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
  GROUP BY 1
),
smoothed AS (
  SELECT month,
         gross_revenue,
         AVG(gross_revenue) OVER (
           ORDER BY month
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
         ) AS moving_avg_3m
  FROM monthly_revenue
)
SELECT month,
       ROUND(gross_revenue, 2) AS gross_revenue,
       ROUND(moving_avg_3m, 2) AS moving_avg_3m
FROM smoothed
WHERE month >= '2025-08'
ORDER BY month;
```

```text
╭─────────┬───────────────┬───────────────╮
│  month  │ gross_revenue │ moving_avg_3m │
╞═════════╪═══════════════╪═══════════════╡
│ 2025-08 │      83420.47 │       91806.6 │
│ 2025-09 │      97520.64 │      92991.75 │
│ 2025-10 │       99072.5 │      93337.87 │
│ 2025-11 │     150279.76 │      115624.3 │
│ 2025-12 │     244602.36 │     164651.54 │
│ 2026-01 │     128438.46 │     174440.19 │
│ 2026-02 │     118340.17 │     163793.66 │
│ 2026-03 │     170011.09 │     138929.91 │
│ 2026-04 │     194769.61 │     161040.29 │
│ 2026-05 │     234748.78 │     199843.16 │
│ 2026-06 │     288614.97 │     239377.79 │
│ 2026-07 │     181073.95 │     234812.57 │
╰─────────┴───────────────┴───────────────╯
```

Same window-then-filter discipline as Exercise 4: the moving average is
computed over the *full* history in `smoothed`, and only the display is
trimmed. **Common wrong approach:** putting `>= '2025-08'` in the first CTE —
then August's "3-month average" would be August alone and September's would
average two months, both silently wrong.

### Exercise 6 — Lifetime-spend quartiles

```sql
WITH customer_spend AS (
  SELECT o.customer_id,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_spend
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
  GROUP BY o.customer_id
),
tiled AS (
  SELECT customer_id, gross_spend,
         NTILE(4) OVER (ORDER BY gross_spend DESC) AS spend_quartile
  FROM customer_spend
),
per_quartile AS (
  SELECT spend_quartile,
         COUNT(*)         AS customers,
         MIN(gross_spend) AS min_spend,
         MAX(gross_spend) AS max_spend,
         AVG(gross_spend) AS avg_spend,
         SUM(gross_spend) AS quartile_revenue
  FROM tiled
  GROUP BY spend_quartile
)
SELECT spend_quartile,
       customers,
       ROUND(min_spend, 2) AS min_spend,
       ROUND(max_spend, 2) AS max_spend,
       ROUND(avg_spend, 2) AS avg_spend,
       ROUND(100.0 * quartile_revenue / SUM(quartile_revenue) OVER (), 1) AS pct_of_revenue
FROM per_quartile
ORDER BY spend_quartile;
```

```text
╭────────────────┬───────────┬───────────┬───────────┬───────────┬────────────────╮
│ spend_quartile │ customers │ min_spend │ max_spend │ avg_spend │ pct_of_revenue │
╞════════════════╪═══════════╪═══════════╪═══════════╪═══════════╪════════════════╡
│              1 │       169 │   6464.97 │  29439.99 │  10683.35 │           58.5 │
│              2 │       168 │   3384.24 │   6447.72 │   4707.78 │           25.6 │
│              3 │       168 │   1336.52 │   3382.09 │   2243.24 │           12.2 │
│              4 │       168 │     34.26 │   1330.22 │     675.5 │            3.7 │
╰────────────────┴───────────┴───────────┴───────────┴───────────┴────────────────╯
```

The top 25% of customers account for **58.5%** of all customer spend. Three
layers: aggregate to customer grain → `NTILE` window → `GROUP BY` quartile,
with a final `SUM(...) OVER ()` computing each quartile's share of the total.

### Exercise 7 — Top 3 best-rated products per category

```sql
WITH product_ratings AS (
  SELECT c.name AS category,
         p.name AS product,
         COUNT(*)      AS n_reviews,
         AVG(r.rating) AS avg_rating
  FROM reviews r
  JOIN products p   ON p.product_id = r.product_id
  JOIN categories c ON c.category_id = p.category_id
  GROUP BY c.name, p.name
  HAVING COUNT(*) >= 3
),
ranked AS (
  SELECT category, product, n_reviews,
         ROUND(avg_rating, 2) AS avg_rating,
         ROW_NUMBER() OVER (
           PARTITION BY category
           ORDER BY avg_rating DESC, n_reviews DESC, product
         ) AS rn
  FROM product_ratings
)
SELECT category, rn, product, avg_rating, n_reviews
FROM ranked
WHERE rn <= 3
ORDER BY category, rn;
```

```text
╭───────────────────────┬────┬──────────────────────────┬────────────┬───────────╮
│       category        │ rn │         product          │ avg_rating │ n_reviews │
╞═══════════════════════╪════╪══════════════════════════╪════════════╪═══════════╡
│ Avalanche Safety      │  1 │ Guard Snow Shovel        │       4.67 │         3 │
│ Avalanche Safety      │  2 │ Pulse Avalanche Beacon   │       4.43 │         7 │
│ Avalanche Safety      │  3 │ Guard Probe 240cm        │       4.27 │        15 │
│ Backpacks             │  1 │ Nomad Backpack 70L       │       4.67 │         3 │
│ Backpacks             │  2 │ Nomad Backpack 35L       │       4.56 │         9 │
│ Backpacks             │  3 │ Ridge Backpack 50L       │        4.4 │         5 │
│ Base Layers           │  1 │ Core Base Layer Top      │       4.67 │         3 │
│ Base Layers           │  2 │ Core Merino Socks 3pk    │       4.36 │        11 │
│ Base Layers           │  3 │ Merino Base Layer Bottom │       4.32 │        19 │
│ Camp Kitchen          │  1 │ Titan Spork Set          │       4.54 │        13 │
│ Camp Kitchen          │  2 │ Fire Kettle              │       4.36 │        11 │
│ Camp Kitchen          │  3 │ Compact Stove            │        4.2 │        10 │
... 57 rows total
```

The full top-N-per-group pattern: metric CTE (with `HAVING COUNT(*) >= 3` to
exclude thinly-reviewed products), `ROW_NUMBER` with a fully deterministic
`ORDER BY` (rating, then review count, then name), outer filter `rn <= 3`.
**Common wrong approach:** `RANK()` — average ratings tie frequently, so some
categories would return 4+ "top 3" products (Pitfall 3); and ranking on
`avg_rating` alone makes the result non-reproducible between runs.

### Exercise 8 — Fastest reorderers (≥ 5 orders)

```sql
WITH order_gaps AS (
  SELECT customer_id,
         julianday(ordered_at)
           - julianday(LAG(ordered_at) OVER (
               PARTITION BY customer_id ORDER BY ordered_at
             )) AS gap_days
  FROM orders
  WHERE status <> 'cancelled'
)
SELECT customer_id,
       COUNT(*)                AS n_orders,
       ROUND(AVG(gap_days), 1) AS avg_gap_days
FROM order_gaps
GROUP BY customer_id
HAVING COUNT(*) >= 5
ORDER BY avg_gap_days
LIMIT 10;
```

```text
╭─────────────┬──────────┬──────────────╮
│ customer_id │ n_orders │ avg_gap_days │
╞═════════════╪══════════╪══════════════╡
│         166 │       15 │          0.6 │
│         188 │       15 │          0.8 │
│         420 │       14 │          1.2 │
│         244 │       17 │          1.3 │
│         290 │       16 │          1.6 │
│         598 │       10 │          1.6 │
│         551 │       27 │          2.1 │
│         285 │       24 │          2.2 │
│         526 │        9 │          2.4 │
│         104 │       12 │          2.6 │
╰─────────────┴──────────┴──────────────╯
```

The window computes each order's gap to the customer's previous order; the
outer `GROUP BY` then averages the gaps per customer. Each customer's first
order has `gap_days` NULL, and `AVG` ignores NULLs (Module 3) — exactly what
we want: N orders produce N-1 gaps. `COUNT(*)` still counts all orders, so
`HAVING COUNT(*) >= 5` filters on order count. **Common wrong approach:**
omitting `PARTITION BY customer_id` — then one customer's first order
measures a "gap" against a *different customer's* last order.

## Challenge

### Exercise 9 — Category revenue Pareto

```sql
WITH category_revenue AS (
  SELECT c.name AS category,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM order_items oi
  JOIN orders o     ON o.order_id = oi.order_id
  JOIN products p   ON p.product_id = oi.product_id
  JOIN categories c ON c.category_id = p.category_id
  WHERE o.status <> 'cancelled'
  GROUP BY c.name
),
running AS (
  SELECT category,
         gross_revenue,
         SUM(gross_revenue) OVER (
           ORDER BY gross_revenue DESC, category
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
         ) AS cumulative_revenue,
         SUM(gross_revenue) OVER () AS total_revenue
  FROM category_revenue
)
SELECT category,
       ROUND(gross_revenue, 2)                              AS gross_revenue,
       ROUND(100.0 * cumulative_revenue / total_revenue, 1) AS cumulative_pct
FROM running
ORDER BY gross_revenue DESC;
```

```text
╭───────────────────────┬───────────────┬────────────────╮
│       category        │ gross_revenue │ cumulative_pct │
╞═══════════════════════╪═══════════════╪════════════════╡
│ Tents                 │     580484.54 │           18.8 │
│ Avalanche Safety      │     430632.08 │           32.8 │
│ Kayaks                │      412561.2 │           46.1 │
│ Skis                  │     338681.15 │           57.1 │
│ Hiking Boots          │     197493.39 │           63.5 │
│ Navigation            │     138300.61 │           68.0 │
│ Jackets               │     125975.15 │           72.1 │
│ Backpacks             │     122997.35 │           76.0 │
│ Ropes & Slings        │     102206.09 │           79.4 │
│ Snowshoes             │      85335.63 │           82.1 │
│ Sleeping Bags         │      82398.83 │           84.8 │
│ Carabiners & Hardware │      79941.59 │           87.4 │
│ Harnesses             │      79141.68 │           89.9 │
│ Camp Kitchen          │      77886.05 │           92.5 │
│ Base Layers           │      58588.13 │           94.4 │
│ Gloves & Hats         │      56922.43 │           96.2 │
│ Trekking Poles        │       49543.5 │           97.8 │
│ Paddles               │      44173.84 │           99.2 │
│ Dry Bags              │      23477.78 │          100.0 │
╰───────────────────────┴───────────────┴────────────────╯
```

It takes **10 of the 19 categories** to pass 80% (Snowshoes crosses at 82.1%;
the first 9 reach 79.4%). Two windows over the same CTE: a running sum
(explicit `ROWS` frame plus `category` as a tiebreaker, so two categories with
identical revenue could never share a cumulative value — the Pitfall 4
tie-proofing) and a grand total via `SUM(...) OVER ()`.

### Exercise 10 — First vs. latest order total (≥ 3 orders)

```sql
WITH order_totals AS (
  SELECT o.order_id,
         o.customer_id,
         o.ordered_at,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
           + o.shipping_cost AS order_total
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
  GROUP BY o.order_id, o.customer_id, o.shipping_cost
),
firsts_lasts AS (
  SELECT customer_id,
         COUNT(*) OVER (PARTITION BY customer_id) AS n_orders,
         FIRST_VALUE(order_total) OVER (
           PARTITION BY customer_id ORDER BY ordered_at
         ) AS first_total,
         LAST_VALUE(order_total) OVER (
           PARTITION BY customer_id ORDER BY ordered_at
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
         ) AS latest_total,
         ROW_NUMBER() OVER (
           PARTITION BY customer_id ORDER BY ordered_at
         ) AS rn
  FROM order_totals
)
SELECT customer_id,
       n_orders,
       ROUND(first_total, 2)  AS first_total,
       ROUND(latest_total, 2) AS latest_total,
       ROUND(100.0 * (latest_total - first_total) / first_total, 1) AS pct_change
FROM firsts_lasts
WHERE rn = 1 AND n_orders >= 3
ORDER BY pct_change DESC
LIMIT 10;
```

```text
╭─────────────┬──────────┬─────────────┬──────────────┬────────────╮
│ customer_id │ n_orders │ first_total │ latest_total │ pct_change │
╞═════════════╪══════════╪═════════════╪══════════════╪════════════╡
│         139 │        5 │       29.39 │      3306.25 │    11149.6 │
│         746 │       27 │        12.2 │      1094.07 │     8867.8 │
│         282 │        6 │       11.59 │       727.48 │     6176.8 │
│         292 │        3 │       29.39 │      1275.96 │     4241.5 │
│         253 │        9 │        17.1 │       732.65 │     4184.5 │
│         498 │       11 │        7.77 │       314.89 │     3952.1 │
│         316 │        8 │       41.91 │      1497.08 │     3472.1 │
│         550 │       14 │       78.83 │       2398.6 │     2942.8 │
│         565 │        3 │       25.86 │       734.34 │     2739.7 │
│         726 │        7 │       40.73 │       973.48 │     2289.9 │
╰─────────────┴──────────┴─────────────┴──────────────┴────────────╯
```

Four windows share one partition: `FIRST_VALUE` (default frame is safe),
`LAST_VALUE` with the mandatory full-partition frame (Pitfall 1 — without it,
"latest_total" would equal each row's own total), a `COUNT(*)` for the ≥ 3
filter, and a `ROW_NUMBER` used purely to keep **one row per customer**
(`rn = 1`). **Common wrong approach:** `SELECT DISTINCT customer_id, ...` —
it happens to work here since all rows of a partition carry identical window
values, but it hides the intent and breaks the moment you add any per-row
column; `rn = 1` states "one representative row per customer" explicitly.

### Exercise 11 — Distribution of days between orders

```sql
WITH order_gaps AS (
  SELECT julianday(ordered_at)
           - julianday(LAG(ordered_at) OVER (
               PARTITION BY customer_id ORDER BY ordered_at
             )) AS gap_days
  FROM orders
  WHERE status <> 'cancelled'
),
bucketed AS (
  SELECT gap_days,
         CASE
           WHEN gap_days <= 7  THEN '0-7 days'
           WHEN gap_days <= 30 THEN '8-30 days'
           WHEN gap_days <= 90 THEN '31-90 days'
           ELSE '91+ days'
         END AS gap_bucket
  FROM order_gaps
  WHERE gap_days IS NOT NULL
)
SELECT gap_bucket,
       COUNT(*) AS gaps,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_gaps
FROM bucketed
GROUP BY gap_bucket
ORDER BY MIN(gap_days);
```

```text
╭────────────┬──────┬─────────────╮
│ gap_bucket │ gaps │ pct_of_gaps │
╞════════════╪══════╪═════════════╡
│ 0-7 days   │ 1249 │        24.9 │
│ 8-30 days  │ 1431 │        28.6 │
│ 31-90 days │ 1331 │        26.6 │
│ 91+ days   │ 1001 │        20.0 │
╰────────────┴──────┴─────────────╯
```

Three techniques stacked: a partitioned `LAG` for the gaps (dropping the NULL
first-order rows), a `CASE` bucketing (Module 2), and the
window-over-aggregate `SUM(COUNT(*)) OVER ()` from §6.11 for the share of
total. `ORDER BY MIN(gap_days)` sorts the buckets by their smallest member —
a tidy trick for ordering categorical buckets without a lookup table.

### Exercise 12 — Best revenue month of each year

```sql
WITH monthly_revenue AS (
  SELECT strftime('%Y', o.ordered_at)    AS year,
         strftime('%Y-%m', o.ordered_at) AS month,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
  GROUP BY year, month
),
ranked AS (
  SELECT year, month, gross_revenue,
         RANK() OVER (PARTITION BY year ORDER BY gross_revenue DESC) AS rnk
  FROM monthly_revenue
)
SELECT year, month, ROUND(gross_revenue, 2) AS gross_revenue
FROM ranked
WHERE rnk = 1
ORDER BY year;
```

```text
╭──────┬─────────┬───────────────╮
│ year │  month  │ gross_revenue │
╞══════╪═════════╪═══════════════╡
│ 2023 │ 2023-11 │      34415.52 │
│ 2024 │ 2024-12 │     117650.48 │
│ 2025 │ 2025-12 │     244602.36 │
│ 2026 │ 2026-06 │     288614.97 │
╰──────┴─────────┴───────────────╯
```

Top-1 per group with `PARTITION BY year`. The exercise asked for a ranking
function that *exposes* ties: `RANK()` returns two rows for a year if two
months tie exactly for first (none do here — but with `ROW_NUMBER` you'd never
know). Note 2026's "best month" is June, but 2026 is a partial year ending
mid-July — a caveat worth stating whenever you report on an open period.
