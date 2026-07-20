# Module 6 — Window Functions

Window functions are the single biggest expressiveness jump in SQL. They let you
attach aggregate context — averages, ranks, running totals, "the previous row" —
to every row of a result *without collapsing the rows the way GROUP BY does*.
Almost every serious analytics query a data engineer writes (growth rates,
cohort tables, top-N per group, dedup) leans on them, and they are the most
common topic in SQL interviews. This module is worth slowing down for.

All queries in this module only *read* from `shop.db` — run them directly
against it:

```bash
sqlite3 -box shop.db
```

## What you'll learn

- Why `GROUP BY` can't answer "how does this row compare to its group?" — and how `OVER` can
- The anatomy of a window: `PARTITION BY`, `ORDER BY`, and the frame clause
- `ROW_NUMBER`, `RANK`, `DENSE_RANK` — and exactly how they differ on ties
- `NTILE` for bucketing customers into spend quartiles
- `LAG`/`LEAD` for month-over-month growth and days-between-orders
- Running totals and moving averages with `ROWS BETWEEN` frames
- The default frame (`RANGE ... CURRENT ROW`), how it treats ties, and why that surprises people
- `FIRST_VALUE`/`LAST_VALUE` — including the notorious `LAST_VALUE` frame trap
- Percent-of-total calculations with `SUM(...) OVER ()`
- Reusing window definitions with the `WINDOW` clause
- The top-N-per-group pattern (`ROW_NUMBER` in a CTE) — the most-asked interview pattern
- Where window functions are (and are not) allowed in a query

## 6.1 The problem windows solve

You know from Module 3 that `GROUP BY` *collapses* rows: one output row per
group, detail gone. Suppose the merchandising team asks:

> "For each review of the Fleece Balaclava, how far is its rating from the
> product's average rating?"

The aggregate is easy — but it destroys the reviews:

```sql
SELECT product_id,
       COUNT(*)              AS n_reviews,
       ROUND(AVG(rating), 2) AS avg_rating
FROM reviews
WHERE product_id IN (64, 68)
GROUP BY product_id;
```

```text
╭────────────┬───────────┬────────────╮
│ product_id │ n_reviews │ avg_rating │
╞════════════╪═══════════╪════════════╡
│         64 │        10 │        4.6 │
│         68 │        10 │        3.6 │
╰────────────┴───────────┴────────────╯
```

Two rows. The individual reviews — the thing we were asked about — are gone.
Before window functions you'd reach for a correlated subquery or a self-join
back onto the aggregate (Module 5). A window function does it in one clean
step: **the aggregate is computed across a set of rows, but every input row
survives to the output.**

```sql
SELECT review_id, rating,
       ROUND(AVG(rating) OVER (), 2)          AS avg_rating,
       ROUND(rating - AVG(rating) OVER (), 2) AS diff_from_avg
FROM reviews
WHERE product_id = 68
ORDER BY rating DESC, review_id;
```

```text
╭───────────┬────────┬────────────┬───────────────╮
│ review_id │ rating │ avg_rating │ diff_from_avg │
╞═══════════╪════════╪════════════╪═══════════════╡
│       769 │      5 │        3.6 │           1.4 │
│      1375 │      5 │        3.6 │           1.4 │
│      2583 │      5 │        3.6 │           1.4 │
│       418 │      4 │        3.6 │           0.4 │
│       579 │      4 │        3.6 │           0.4 │
│       735 │      4 │        3.6 │           0.4 │
│      1214 │      4 │        3.6 │           0.4 │
│      2326 │      3 │        3.6 │          -0.6 │
│      1023 │      1 │        3.6 │          -2.6 │
│      1894 │      1 │        3.6 │          -2.6 │
╰───────────┴────────┴────────────┴───────────────╯
```

All 10 reviews are still there, each annotated with the average of the whole
result set. `AVG(rating) OVER ()` means: "compute `AVG(rating)` over a
*window* of rows — here, all rows that survived the `WHERE`." That last part
matters: window functions see the rows *after* filtering, which is why the
average is 3.6 (product 68's reviews only), not the table-wide average.

## 6.2 Anatomy of OVER

Every window function call has this shape:

```
function(arguments) OVER (
    [PARTITION BY expr, ...]     -- split rows into independent groups
    [ORDER BY expr, ...]         -- order rows within each partition
    [frame clause]               -- which ordered rows are visible (§6.9)
)
```

All three parts are optional. `OVER ()` = one partition containing every row,
no ordering, whole partition visible. Two families of functions can appear in
front of `OVER`:

1. **Any aggregate you already know** — `SUM`, `AVG`, `COUNT`, `MIN`, `MAX` —
   which becomes a *windowed aggregate* (no rows collapsed).
2. **Dedicated window functions** — `ROW_NUMBER`, `RANK`, `DENSE_RANK`,
   `NTILE`, `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE` — which
   only make sense with `OVER` and are illegal without it.

## 6.3 PARTITION BY — per-group context on every row

`PARTITION BY` is `GROUP BY`'s non-destructive sibling: it splits the rows
into groups, computes the function separately within each group, but keeps
every row. Here are two products' reviews, each row annotated with *its own
product's* average:

```sql
SELECT product_id, review_id, rating,
       ROUND(AVG(rating) OVER (PARTITION BY product_id), 2) AS product_avg
FROM reviews
WHERE product_id IN (64, 68)
ORDER BY product_id, rating DESC, review_id;
```

```text
╭────────────┬───────────┬────────┬─────────────╮
│ product_id │ review_id │ rating │ product_avg │
╞════════════╪═══════════╪════════╪═════════════╡
│         64 │       816 │      5 │         4.6 │
│         64 │      1306 │      5 │         4.6 │
│         64 │      1316 │      5 │         4.6 │
│         64 │      1776 │      5 │         4.6 │
│         64 │      1948 │      5 │         4.6 │
│         64 │      2293 │      5 │         4.6 │
│         64 │      3179 │      5 │         4.6 │
│         64 │       140 │      4 │         4.6 │
│         64 │      3289 │      4 │         4.6 │
│         64 │      1786 │      3 │         4.6 │
│         68 │       769 │      5 │         3.6 │
│         68 │      1375 │      5 │         3.6 │
│         68 │      2583 │      5 │         3.6 │
│         68 │       418 │      4 │         3.6 │
│         68 │       579 │      4 │         3.6 │
│         68 │       735 │      4 │         3.6 │
│         68 │      1214 │      4 │         3.6 │
│         68 │      2326 │      3 │         3.6 │
│         68 │      1023 │      1 │         3.6 │
│         68 │      1894 │      1 │         3.6 │
╰────────────┴───────────┴────────┴─────────────╯
```

Rows of product 64 see 4.6; rows of product 68 see 3.6. Each partition is a
sealed room — a window function never sees across partition boundaries.

A more production-shaped example. Business question: *"Which of a customer's
orders were unusually large or small for them?"* We compare each order total
(item revenue + shipping, the canonical definition) to that customer's own AOV:

```sql
WITH order_totals AS (
  SELECT o.order_id,
         o.customer_id,
         date(o.ordered_at) AS order_date,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
           + o.shipping_cost AS order_total
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
  GROUP BY o.order_id, o.customer_id, o.shipping_cost
)
SELECT customer_id,
       order_id,
       order_date,
       ROUND(order_total, 2)                                          AS order_total,
       ROUND(AVG(order_total) OVER (PARTITION BY customer_id), 2)     AS customer_aov,
       ROUND(order_total
             - AVG(order_total) OVER (PARTITION BY customer_id), 2)   AS vs_own_aov
FROM order_totals
WHERE customer_id IN (10, 25)
ORDER BY customer_id, order_date;
```

```text
╭─────────────┬──────────┬────────────┬─────────────┬──────────────┬────────────╮
│ customer_id │ order_id │ order_date │ order_total │ customer_aov │ vs_own_aov │
╞═════════════╪══════════╪════════════╪═════════════╪══════════════╪════════════╡
│          10 │     2239 │ 2024-12-26 │      408.42 │        494.8 │     -86.38 │
│          10 │     4279 │ 2025-01-16 │      111.86 │        494.8 │    -382.94 │
│          10 │      783 │ 2025-02-12 │     1541.58 │        494.8 │    1046.78 │
│          10 │     5654 │ 2025-06-09 │       65.94 │        494.8 │    -428.86 │
│          10 │     3944 │ 2025-09-08 │      377.27 │        494.8 │    -117.53 │
│          10 │      780 │ 2025-10-30 │      437.05 │        494.8 │     -57.75 │
│          10 │     5458 │ 2025-12-25 │      930.91 │        494.8 │     436.11 │
│          10 │     2460 │ 2026-06-11 │       85.35 │        494.8 │    -409.45 │
│          25 │     1117 │ 2023-08-09 │       605.3 │       605.54 │      -0.24 │
│          25 │     3325 │ 2023-09-17 │      451.06 │       605.54 │    -154.48 │
│          25 │     5215 │ 2023-09-23 │      102.44 │       605.54 │     -503.1 │
│          25 │     2126 │ 2024-11-18 │      242.47 │       605.54 │    -363.07 │
│          25 │      661 │ 2025-09-27 │      1689.0 │       605.54 │    1083.46 │
│          25 │     3936 │ 2025-12-20 │      666.75 │       605.54 │      61.21 │
│          25 │     5660 │ 2026-02-04 │      481.76 │       605.54 │    -123.78 │
╰─────────────┴──────────┴────────────┴─────────────┴──────────────┴────────────╯
```

Note the shape of this query — a CTE that builds a clean per-order grain, then
windows on top of it. That two-layer structure (aggregate first, window second)
is *the* standard architecture for analytical SQL; you'll use it constantly.

Also note: window functions run *after* the `GROUP BY` inside the CTE has
produced one row per order. Windows always operate on the rows of the query
level they appear in.

## 6.4 ORDER BY inside OVER — from "whole partition" to "so far"

Adding `ORDER BY` inside `OVER` changes the meaning of aggregates from "over
the whole partition" to "over the partition *up to and including this row*".
Compare the two counts:

```sql
SELECT order_id,
       date(ordered_at) AS order_date,
       COUNT(*) OVER (PARTITION BY customer_id)                     AS total_orders,
       COUNT(*) OVER (PARTITION BY customer_id ORDER BY ordered_at) AS orders_so_far
FROM orders
WHERE customer_id = 10 AND status <> 'cancelled'
ORDER BY ordered_at;
```

```text
╭──────────┬────────────┬──────────────┬───────────────╮
│ order_id │ order_date │ total_orders │ orders_so_far │
╞══════════╪════════════╪══════════════╪═══════════════╡
│     2239 │ 2024-12-26 │            8 │             1 │
│     4279 │ 2025-01-16 │            8 │             2 │
│      783 │ 2025-02-12 │            8 │             3 │
│     5654 │ 2025-06-09 │            8 │             4 │
│     3944 │ 2025-09-08 │            8 │             5 │
│      780 │ 2025-10-30 │            8 │             6 │
│     5458 │ 2025-12-25 │            8 │             7 │
│     2460 │ 2026-06-11 │            8 │             8 │
╰──────────┴────────────┴──────────────┴───────────────╯
```

Same function, radically different results. Why? `ORDER BY` inside `OVER`
implicitly activates a *frame* — a moving subset of the partition — whose
default is "from the start of the partition through the current row" (§6.9
makes this precise). This one idea powers running totals, ranks, and
"nth order per customer".

The `ORDER BY` inside `OVER` is completely independent of the query's final
`ORDER BY` — one decides how the window computes, the other how rows print.

## 6.5 Ranking: ROW_NUMBER, RANK, DENSE_RANK

Three functions assign positions within a partition's ordering; they differ
only in how they treat **ties**. The Fleece Balaclava's ratings
(5,5,5,4,4,4,4,3,1,1) make the difference visible:

```sql
SELECT review_id, rating,
       ROW_NUMBER() OVER (ORDER BY rating DESC) AS row_num,
       RANK()       OVER (ORDER BY rating DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY rating DESC) AS dense_rnk
FROM reviews
WHERE product_id = 68
ORDER BY rating DESC, review_id;
```

```text
╭───────────┬────────┬─────────┬─────┬───────────╮
│ review_id │ rating │ row_num │ rnk │ dense_rnk │
╞═══════════╪════════╪═════════╪═════╪═══════════╡
│       769 │      5 │       2 │   1 │         1 │
│      1375 │      5 │       1 │   1 │         1 │
│      2583 │      5 │       3 │   1 │         1 │
│       418 │      4 │       6 │   4 │         2 │
│       579 │      4 │       5 │   4 │         2 │
│       735 │      4 │       4 │   4 │         2 │
│      1214 │      4 │       7 │   4 │         2 │
│      2326 │      3 │       8 │   8 │         3 │
│      1023 │      1 │       9 │   9 │         4 │
│      1894 │      1 │      10 │   9 │         4 │
╰───────────┴────────┴─────────┴─────┴───────────╯
```

- **ROW_NUMBER** — every row gets a distinct number, 1..N. Ties are broken
  **arbitrarily**: look at the three 5-star rows — displayed in `review_id`
  order they carry row numbers 2, 1, 3. The engine assigned numbers in
  whatever order it scanned the ties. If you need reproducible results (you
  do), always add a unique tiebreaker:
  `ROW_NUMBER() OVER (ORDER BY rating DESC, review_id)`.
- **RANK** — ties share a rank, and the next rank *skips*: three rows at
  rank 1, so the 4-star rows are rank 4 ("Olympic ranking").
- **DENSE_RANK** — ties share a rank, no gaps: 1, 2, 3, 4.

Which to use? `ROW_NUMBER` when you need exactly one row per position (dedup,
top-N). `RANK`/`DENSE_RANK` when tied values genuinely deserve the same
standing (leaderboards). Mixing them up causes real bugs — see Pitfall 3.

> **PostgreSQL note:** ranking functions are SQL-standard and behave
> identically in PostgreSQL — including the arbitrary tie order of
> `ROW_NUMBER`. The tiebreaker discipline applies everywhere.

## 6.6 NTILE — quartiles of customer spend

`NTILE(n)` deals rows into `n` buckets of as-equal-as-possible size, in window
order. Classic use: segment customers by lifetime spend. Business question:
*"Split our customers into spend quartiles — how big is each tier and what
does it spend?"*

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
  SELECT customer_id,
         gross_spend,
         NTILE(4) OVER (ORDER BY gross_spend DESC) AS spend_quartile
  FROM customer_spend
)
SELECT spend_quartile,
       COUNT(*)                    AS customers,
       ROUND(MIN(gross_spend), 2)  AS min_spend,
       ROUND(MAX(gross_spend), 2)  AS max_spend,
       ROUND(AVG(gross_spend), 2)  AS avg_spend
FROM tiled
GROUP BY spend_quartile
ORDER BY spend_quartile;
```

```text
╭────────────────┬───────────┬───────────┬───────────┬───────────╮
│ spend_quartile │ customers │ min_spend │ max_spend │ avg_spend │
╞════════════════╪═══════════╪═══════════╪═══════════╪═══════════╡
│              1 │       169 │   6464.97 │  29439.99 │  10683.35 │
│              2 │       168 │   3384.24 │   6447.72 │   4707.78 │
│              3 │       168 │   1336.52 │   3382.09 │   2243.24 │
│              4 │       168 │     34.26 │   1330.22 │     675.5 │
╰────────────────┴───────────┴───────────┴───────────┴───────────╯
```

673 customers who have ever placed a non-cancelled order, dealt into four
tiers (the first bucket takes the remainder row: 169 vs 168). Quartile 1's
average lifetime spend is ~16x quartile 4's — a very normal e-commerce shape.
Note the pattern again: aggregate to customer grain, window over that, then a
plain `GROUP BY` on top of the window's output. Windows compose with
everything you already know.

`NTILE` buckets by *row count*, not by value — customers near a boundary can
have nearly identical spend yet land in different quartiles. That's inherent
to the tool, not a bug.

## 6.7 LAG and LEAD — looking backwards and forwards

`LAG(expr)` fetches `expr` from the *previous* row of the window's ordering;
`LEAD(expr)` from the *next*. They turn "compare this row to the one before
it" — a nightmare with self-joins — into one function call. Both accept
optional offset and default arguments: `LAG(expr, 2, 0)` looks two rows back
and returns 0 instead of NULL when there is no such row.

Business question 1: *"What is our month-over-month revenue growth for the
last 12 months?"* (Gross revenue, canonical definition: item revenue of
non-cancelled orders.)

```sql
WITH monthly_revenue AS (
  SELECT strftime('%Y-%m', o.ordered_at) AS month,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
    AND o.ordered_at >= '2025-07-01'
  GROUP BY 1
)
SELECT month,
       ROUND(gross_revenue, 2)                          AS gross_revenue,
       ROUND(LAG(gross_revenue) OVER (ORDER BY month), 2) AS prev_month,
       ROUND(100.0 * (gross_revenue - LAG(gross_revenue) OVER (ORDER BY month))
                   / LAG(gross_revenue) OVER (ORDER BY month), 1) AS growth_pct
FROM monthly_revenue
ORDER BY month;
```

```text
╭─────────┬───────────────┬────────────┬────────────╮
│  month  │ gross_revenue │ prev_month │ growth_pct │
╞═════════╪═══════════════╪════════════╪════════════╡
│ 2025-07 │      98034.15 │            │            │
│ 2025-08 │      83420.47 │   98034.15 │      -14.9 │
│ 2025-09 │      97520.64 │   83420.47 │       16.9 │
│ 2025-10 │       99072.5 │   97520.64 │        1.6 │
│ 2025-11 │     150279.76 │    99072.5 │       51.7 │
│ 2025-12 │     244602.36 │  150279.76 │       62.8 │
│ 2026-01 │     128438.46 │  244602.36 │      -47.5 │
│ 2026-02 │     118340.17 │  128438.46 │       -7.9 │
│ 2026-03 │     170011.09 │  118340.17 │       43.7 │
│ 2026-04 │     194769.61 │  170011.09 │       14.6 │
│ 2026-05 │     234748.78 │  194769.61 │       20.5 │
│ 2026-06 │     288614.97 │  234748.78 │       22.9 │
│ 2026-07 │     181073.95 │  288614.97 │      -37.3 │
╰─────────┴───────────────┴────────────┴────────────╯
```

You can see the seasonality quirks of the dataset directly: +62.8% into the
December holiday peak, -47.5% in the January hangover. Two things to
internalize:

- The first row's `prev_month` is NULL — there is no previous row *within the
  window*. And since we truncated history in the CTE (`>= '2025-07-01'`),
  `LAG` cannot see June 2025 even though it exists in the table. **`LAG` only
  sees rows that made it into the query.** If January's growth number matters,
  your CTE must include December.
- July 2026's -37.3% is an artifact: the dataset ends 2026-07-14, so it's a
  partial month. Real dashboards exclude the incomplete current period.

Business question 2: *"How many days pass between a customer's consecutive
orders?"* — the raw material for churn models and reorder-reminder emails.
For customer 10:

```sql
SELECT order_id,
       date(ordered_at) AS order_date,
       date(LAG(ordered_at)  OVER (ORDER BY ordered_at)) AS prev_order,
       CAST(julianday(ordered_at)
            - julianday(LAG(ordered_at) OVER (ORDER BY ordered_at)) AS INTEGER) AS days_since_prev,
       date(LEAD(ordered_at) OVER (ORDER BY ordered_at)) AS next_order
FROM orders
WHERE customer_id = 10 AND status <> 'cancelled'
ORDER BY ordered_at;
```

```text
╭──────────┬────────────┬────────────┬─────────────────┬────────────╮
│ order_id │ order_date │ prev_order │ days_since_prev │ next_order │
╞══════════╪════════════╪════════════╪═════════════════╪════════════╡
│     2239 │ 2024-12-26 │            │                 │ 2025-01-16 │
│     4279 │ 2025-01-16 │ 2024-12-26 │              21 │ 2025-02-12 │
│      783 │ 2025-02-12 │ 2025-01-16 │              27 │ 2025-06-09 │
│     5654 │ 2025-06-09 │ 2025-02-12 │             116 │ 2025-09-08 │
│     3944 │ 2025-09-08 │ 2025-06-09 │              91 │ 2025-10-30 │
│      780 │ 2025-10-30 │ 2025-09-08 │              51 │ 2025-12-25 │
│     5458 │ 2025-12-25 │ 2025-10-30 │              55 │ 2026-06-11 │
│     2460 │ 2026-06-11 │ 2025-12-25 │             167 │            │
╰──────────┴────────────┴────────────┴─────────────────┴────────────╯
```

`julianday()` converts the ISO timestamp to a day number so subtraction yields
days (Module 2). `LEAD` is `LAG`'s mirror — first row has no `prev_order`,
last row has no `next_order`. To run this across *all* customers at once,
you'd add `PARTITION BY customer_id` so one customer's orders never bleed into
another's gap calculation.

> **PostgreSQL note:** `LAG`/`LEAD` are identical, but the date arithmetic
> differs: in PostgreSQL you'd write `ordered_at::date - lag(ordered_at::date) OVER (...)`
> (date subtraction yields an integer), and `date_trunc('month', ordered_at)`
> instead of `strftime('%Y-%m', ...)`.

## 6.8 Running totals

An aggregate plus `ORDER BY` inside `OVER` gives a cumulative value — the
running-total pattern. Business question: *"How did 2023 revenue accumulate
toward the year-end total?"*

```sql
WITH monthly_revenue AS (
  SELECT strftime('%Y-%m', o.ordered_at) AS month,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
    AND o.ordered_at >= '2023-01-01' AND o.ordered_at < '2024-01-01'
  GROUP BY 1
)
SELECT month,
       ROUND(gross_revenue, 2)                             AS gross_revenue,
       ROUND(SUM(gross_revenue) OVER (ORDER BY month), 2)  AS cumulative_revenue
FROM monthly_revenue
ORDER BY month;
```

```text
╭─────────┬───────────────┬────────────────────╮
│  month  │ gross_revenue │ cumulative_revenue │
╞═════════╪═══════════════╪════════════════════╡
│ 2023-01 │       5369.87 │            5369.87 │
│ 2023-02 │       9115.78 │           14485.65 │
│ 2023-03 │       8618.27 │           23103.92 │
│ 2023-04 │       7664.94 │           30768.87 │
│ 2023-05 │        9563.2 │           40332.06 │
│ 2023-06 │        6663.4 │           46995.46 │
│ 2023-07 │      18347.94 │            65343.4 │
│ 2023-08 │      15180.89 │           80524.29 │
│ 2023-09 │      12031.31 │            92555.6 │
│ 2023-10 │      15125.47 │          107681.06 │
│ 2023-11 │      34415.52 │          142096.58 │
│ 2023-12 │      30621.11 │          172717.69 │
╰─────────┴───────────────┴────────────────────╯
```

Each row's `cumulative_revenue` is the sum of everything up to and including
that month; the December row equals the 2023 total. Add
`PARTITION BY strftime('%Y', ...)` and you get a year-to-date column that
resets every January — that combination (partition = reset boundary,
order = accumulation direction) is worth memorizing.

## 6.9 Frame clauses — controlling the window's extent

The third slot in `OVER` is the **frame**: which rows around the current row
the function may see. Syntax:

```
{ROWS | RANGE | GROUPS} BETWEEN <start> AND <end>
```

where each bound is `UNBOUNDED PRECEDING`, `<n> PRECEDING`, `CURRENT ROW`,
`<n> FOLLOWING`, or `UNBOUNDED FOLLOWING`. `ROWS` counts physical rows;
`RANGE` extends bounds to all *peer* rows (rows equal on the window's
`ORDER BY`); `GROUPS` counts peer-groups (rarely needed).

The workhorse is `ROWS BETWEEN n PRECEDING AND CURRENT ROW` — a **moving
window**. Business question: *"Monthly revenue is noisy — show a 3-month
moving average so we can see the trend."*

```sql
WITH monthly_revenue AS (
  SELECT strftime('%Y-%m', o.ordered_at) AS month,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
  GROUP BY 1
)
SELECT month,
       ROUND(gross_revenue, 2) AS gross_revenue,
       ROUND(AVG(gross_revenue) OVER (
               ORDER BY month
               ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
             ), 2) AS moving_avg_3m
FROM monthly_revenue
ORDER BY month
LIMIT 12;
```

```text
╭─────────┬───────────────┬───────────────╮
│  month  │ gross_revenue │ moving_avg_3m │
╞═════════╪═══════════════╪═══════════════╡
│ 2023-01 │       5369.87 │       5369.87 │
│ 2023-02 │       9115.78 │       7242.82 │
│ 2023-03 │       8618.27 │       7701.31 │
│ 2023-04 │       7664.94 │       8466.33 │
│ 2023-05 │        9563.2 │       8615.47 │
│ 2023-06 │        6663.4 │       7963.85 │
│ 2023-07 │      18347.94 │      11524.84 │
│ 2023-08 │      15180.89 │      13397.41 │
│ 2023-09 │      12031.31 │      15186.71 │
│ 2023-10 │      15125.47 │      14112.56 │
│ 2023-11 │      34415.52 │       20524.1 │
│ 2023-12 │      30621.11 │       26720.7 │
╰─────────┴───────────────┴───────────────╯
```

(43 rows total without the `LIMIT`.) Each `moving_avg_3m` averages the current
month and the two before it — the first two rows average fewer months because
the frame is truncated at the partition edge (`AVG` divides by the rows
actually present, so the numbers are still correct averages of what's there).
The July spike (18,348) is visibly smoothed to 11,525.

**The default frame.** When you write `ORDER BY` with no frame clause, you get:

```
RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
```

`RANGE` means: the frame ends at the current row *and all its peers* — rows
with the same `ORDER BY` value. In §6.8 that was harmless because months were
unique. But run a cumulative sum ordered by a column with duplicates, and all
tied rows suddenly show the same "running" value — a genuinely confusing bug
demonstrated in Pitfall 4. Rule of thumb: **when you write a running
calculation, order by a unique key or state `ROWS` explicitly.**

Note also which functions frames affect: windowed aggregates and
`FIRST_VALUE`/`LAST_VALUE`/`NTH_VALUE` respect the frame; `ROW_NUMBER`,
`RANK`, `DENSE_RANK`, `NTILE`, `LAG`, `LEAD` always operate on the whole
partition and ignore it.

> **PostgreSQL note:** frames work identically (both engines follow the SQL
> standard, including the `RANGE` default and `GROUPS` mode).

## 6.10 FIRST_VALUE and LAST_VALUE

`FIRST_VALUE(expr)` returns `expr` from the first row of the frame,
`LAST_VALUE(expr)` from the last. Business question: *"How far has each
product's price drifted from its launch price?"* — `price_history` is ordered
by `valid_from`, so the first row per product is the launch price:

```sql
SELECT product_id,
       date(valid_from) AS valid_from,
       price,
       FIRST_VALUE(price) OVER (PARTITION BY product_id ORDER BY valid_from) AS launch_price,
       ROUND(100.0 * (price / FIRST_VALUE(price) OVER (PARTITION BY product_id ORDER BY valid_from) - 1), 1) AS pct_vs_launch
FROM price_history
WHERE product_id IN (321, 338)
ORDER BY product_id, valid_from;
```

```text
╭────────────┬────────────┬────────┬──────────────┬───────────────╮
│ product_id │ valid_from │ price  │ launch_price │ pct_vs_launch │
╞════════════╪════════════╪════════╪══════════════╪═══════════════╡
│        321 │ 2024-06-18 │ 273.45 │       273.45 │           0.0 │
│        321 │ 2025-03-14 │ 251.21 │       273.45 │          -8.1 │
│        321 │ 2025-12-18 │ 234.46 │       273.45 │         -14.3 │
│        321 │ 2026-02-16 │ 249.49 │       273.45 │          -8.8 │
│        338 │ 2023-06-17 │  68.37 │        68.37 │           0.0 │
│        338 │ 2024-03-27 │  73.36 │        68.37 │           7.3 │
│        338 │ 2024-11-25 │  85.45 │        68.37 │          25.0 │
│        338 │ 2025-06-15 │   86.5 │        68.37 │          26.5 │
╰────────────┴────────────┴────────┴──────────────┴───────────────╯
```

Product 321 has been discounted 14.3% below launch and partially recovered;
product 338 has crept up 26.5%. `FIRST_VALUE` with the default frame is safe:
the frame always *starts* at `UNBOUNDED PRECEDING`, so the first row is always
in view.

`LAST_VALUE` is a different story. With the default frame, the frame *ends at
the current row* — so "the last value in the frame" is just... the current
row's value. Everyone hits this once. See Pitfall 1 for the demonstration and
the fix (an explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED
FOLLOWING` frame).

## 6.11 Aggregates as windows and percent of total

Any aggregate with an empty `OVER ()` sees the entire result set — which makes
share-of-total calculations trivial. Business question: *"Which categories
drive our revenue, and what share does each hold?"*

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
)
SELECT category,
       ROUND(gross_revenue, 2)                                     AS gross_revenue,
       ROUND(100.0 * gross_revenue / SUM(gross_revenue) OVER (), 1) AS pct_of_total
FROM category_revenue
ORDER BY gross_revenue DESC
LIMIT 10;
```

```text
╭──────────────────┬───────────────┬──────────────╮
│     category     │ gross_revenue │ pct_of_total │
╞══════════════════╪═══════════════╪══════════════╡
│ Tents            │     580484.54 │         18.8 │
│ Avalanche Safety │     430632.08 │         14.0 │
│ Kayaks           │      412561.2 │         13.4 │
│ Skis             │     338681.15 │         11.0 │
│ Hiking Boots     │     197493.39 │          6.4 │
│ Navigation       │     138300.61 │          4.5 │
│ Jackets          │     125975.15 │          4.1 │
│ Backpacks        │     122997.35 │          4.0 │
│ Ropes & Slings   │     102206.09 │          3.3 │
│ Snowshoes        │      85335.63 │          2.8 │
╰──────────────────┴───────────────┴──────────────╯
```

(19 category rows total.) Four categories generate over half of all revenue.
`SUM(gross_revenue) OVER ()` computes the grand total once per row — the CTE
keeps the item-revenue expression from being written four times.

You can even skip the CTE: **a window function may wrap an aggregate in the
same grouped query**. The window then runs over the grouped rows:

```sql
SELECT c.name AS category,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue,
       ROUND(100.0 * SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
                   / SUM(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))) OVER (), 1) AS pct_of_total
FROM order_items oi
JOIN orders o     ON o.order_id = oi.order_id
JOIN products p   ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.status <> 'cancelled'
GROUP BY c.name
ORDER BY gross_revenue DESC
LIMIT 5;
```

```text
╭──────────────────┬───────────────┬──────────────╮
│     category     │ gross_revenue │ pct_of_total │
╞══════════════════╪═══════════════╪══════════════╡
│ Tents            │     580484.54 │         18.8 │
│ Avalanche Safety │     430632.08 │         14.0 │
│ Kayaks           │      412561.2 │         13.4 │
│ Skis             │     338681.15 │         11.0 │
│ Hiking Boots     │     197493.39 │          6.4 │
╰──────────────────┴───────────────┴──────────────╯
```

Read `SUM(SUM(x)) OVER ()` inside-out: the inner `SUM(x)` is the per-category
aggregate; the outer `SUM(...) OVER ()` adds those per-category sums across all
groups. It works because windows evaluate *after* `GROUP BY`. Most teams
prefer the CTE version for readability — but you will meet this nesting in the
wild, so learn to read it.

## 6.12 Named windows — the WINDOW clause

When several columns share the same window, repeating the definition is noisy
and error-prone. The `WINDOW` clause (placed between `HAVING` and `ORDER BY`)
names it once. Business question: *"One 2026 dashboard query: monthly revenue,
previous month, YTD cumulative, and 3-month moving average."*

```sql
WITH monthly_revenue AS (
  SELECT strftime('%Y-%m', o.ordered_at) AS month,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
    AND o.ordered_at >= '2026-01-01'
  GROUP BY 1
)
SELECT month,
       ROUND(gross_revenue, 2)                    AS gross_revenue,
       ROUND(LAG(gross_revenue) OVER w_month, 2)  AS prev_month,
       ROUND(SUM(gross_revenue) OVER w_month, 2)  AS ytd_revenue,
       ROUND(AVG(gross_revenue) OVER (w_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM monthly_revenue
WINDOW w_month AS (ORDER BY month)
ORDER BY month;
```

```text
╭─────────┬───────────────┬────────────┬─────────────┬───────────────╮
│  month  │ gross_revenue │ prev_month │ ytd_revenue │ moving_avg_3m │
╞═════════╪═══════════════╪════════════╪═════════════╪═══════════════╡
│ 2026-01 │     128438.46 │            │   128438.46 │     128438.46 │
│ 2026-02 │     118340.17 │  128438.46 │   246778.63 │     123389.31 │
│ 2026-03 │     170011.09 │  118340.17 │   416789.72 │     138929.91 │
│ 2026-04 │     194769.61 │  170011.09 │   611559.33 │     161040.29 │
│ 2026-05 │     234748.78 │  194769.61 │   846308.11 │     199843.16 │
│ 2026-06 │     288614.97 │  234748.78 │  1134923.09 │     239377.79 │
│ 2026-07 │     181073.95 │  288614.97 │  1315997.04 │     234812.57 │
╰─────────┴───────────────┴────────────┴─────────────┴───────────────╯
```

Three window calls, one definition. Note
`OVER (w_month ROWS BETWEEN ...)` — a named window can be *extended* with a
frame clause where needed. One definition of "ordered by month", three
different behaviors: `LAG` ignores frames, `SUM` uses the default running
frame, `AVG` gets an explicit moving frame.

> **PostgreSQL note:** the `WINDOW` clause is SQL-standard and works the same
> in PostgreSQL.

## 6.13 Top-N per group — the interview classic

*"Show me the top 3 products in every category by revenue."* `LIMIT` can't do
this — it cuts the whole result, not each group. The canonical solution:
number the rows within each partition, then filter in an outer query.

```sql
WITH product_revenue AS (
  SELECT c.name AS category,
         p.name AS product,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
  FROM order_items oi
  JOIN orders o     ON o.order_id = oi.order_id
  JOIN products p   ON p.product_id = oi.product_id
  JOIN categories c ON c.category_id = p.category_id
  WHERE o.status <> 'cancelled'
  GROUP BY c.name, p.name
),
ranked AS (
  SELECT category, product,
         ROUND(gross_revenue, 2) AS gross_revenue,
         ROW_NUMBER() OVER (
           PARTITION BY category
           ORDER BY gross_revenue DESC, product
         ) AS rn
  FROM product_revenue
)
SELECT category, rn, product, gross_revenue
FROM ranked
WHERE rn <= 3
ORDER BY category, rn
LIMIT 12;
```

```text
╭──────────────────┬────┬──────────────────────────┬───────────────╮
│     category     │ rn │         product          │ gross_revenue │
╞══════════════════╪════╪══════════════════════════╪═══════════════╡
│ Avalanche Safety │  1 │ Rescue Probe 240cm       │      96980.53 │
│ Avalanche Safety │  2 │ Probe Avalanche Beacon   │      58176.66 │
│ Avalanche Safety │  3 │ Rescue Avalanche Beacon  │      55996.96 │
│ Backpacks        │  1 │ Crest Daypack 20L        │      21531.62 │
│ Backpacks        │  2 │ Packrat Daypack 20L      │      19884.64 │
│ Backpacks        │  3 │ Vandra Backpack 35L      │      17901.81 │
│ Base Layers      │  1 │ Thermo Base Layer Bottom │      16257.47 │
│ Base Layers      │  2 │ Merino Base Layer Top    │       9534.65 │
│ Base Layers      │  3 │ Merino Merino Socks 3pk  │       8322.84 │
│ Camp Kitchen     │  1 │ Titan Stove              │       25471.2 │
│ Camp Kitchen     │  2 │ Fire Kettle              │       8584.04 │
│ Camp Kitchen     │  3 │ Titan Water Filter       │       7329.79 │
╰──────────────────┴────┴──────────────────────────┴───────────────╯
```

(57 rows total without the `LIMIT`: 19 categories x 3.) Anatomy of the pattern:

1. **Aggregate CTE** — build the metric at the grain you're ranking (product x category revenue).
2. **Ranking CTE** — `ROW_NUMBER() OVER (PARTITION BY group ORDER BY metric DESC, tiebreaker)`.
3. **Outer filter** — `WHERE rn <= N`.

Why the CTE at step 3? Because you cannot filter on a window function in the
same query level — the next section explains, and Pitfall 2 shows the error.
And why `ROW_NUMBER`, not `RANK`? Because `RANK` can return *more* than N rows
when ties straddle the cutoff — Pitfall 3. If you'd rather *include* deserving
ties, that's a business decision — then `RANK` is the right tool, chosen
deliberately.

## 6.14 Where window functions are allowed

A window function may appear **only in the `SELECT` list or the final
`ORDER BY`** of a query. Not in `WHERE`, `GROUP BY`, or `HAVING`. The reason
is evaluation order: conceptually, a query runs

```
FROM → WHERE → GROUP BY → HAVING → window functions → SELECT → ORDER BY → LIMIT
```

Windows are computed on the rows that *survive* filtering and grouping — so a
`WHERE` clause referencing a window would be circular: the filter would change
the very rows the window needs to compute its value.

The consequence you'll feel daily: to filter on a window result (`rn <= 3`,
`growth_pct < 0`), compute it in a CTE or subquery and filter one level up —
exactly what §6.13 did. Some engines (Snowflake, DuckDB, BigQuery, Databricks)
offer a `QUALIFY` clause that does this in one step
(`QUALIFY ROW_NUMBER() OVER (...) <= 3`); neither SQLite nor PostgreSQL has
it, so the CTE pattern is the portable habit.

## Pitfalls

### Pitfall 1 — LAST_VALUE with the default frame

You want each price row annotated with the product's *latest* price. The
obvious query:

```sql
-- BAD: LAST_VALUE with the default frame — "latest_price" is just each row's own price
SELECT date(valid_from) AS valid_from,
       price,
       LAST_VALUE(price) OVER (PARTITION BY product_id ORDER BY valid_from) AS latest_price
FROM price_history
WHERE product_id = 338
ORDER BY valid_from;
```

```text
╭────────────┬───────┬──────────────╮
│ valid_from │ price │ latest_price │
╞════════════╪═══════╪══════════════╡
│ 2023-06-17 │ 68.37 │        68.37 │
│ 2024-03-27 │ 73.36 │        73.36 │
│ 2024-11-25 │ 85.45 │        85.45 │
│ 2025-06-15 │  86.5 │         86.5 │
╰────────────┴───────┴──────────────╯
```

No error — just silently useless. The default frame ends at `CURRENT ROW`, so
the "last value of the frame" is the current row itself. Widen the frame to
the whole partition:

```sql
SELECT date(valid_from) AS valid_from,
       price,
       LAST_VALUE(price) OVER (
         PARTITION BY product_id
         ORDER BY valid_from
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS latest_price
FROM price_history
WHERE product_id = 338
ORDER BY valid_from;
```

```text
╭────────────┬───────┬──────────────╮
│ valid_from │ price │ latest_price │
╞════════════╪═══════╪══════════════╡
│ 2023-06-17 │ 68.37 │         86.5 │
│ 2024-03-27 │ 73.36 │         86.5 │
│ 2024-11-25 │ 85.45 │         86.5 │
│ 2025-06-15 │  86.5 │         86.5 │
╰────────────┴───────┴──────────────╯
```

Every row now sees 86.5 — the genuinely-latest price. (Equivalent trick:
`FIRST_VALUE(price) OVER (... ORDER BY valid_from DESC)`, since `FIRST_VALUE`
is default-frame-safe.)

### Pitfall 2 — filtering on a window function in WHERE

*"Give me each customer's first order"* — tempting to write:

```sql
-- BAD: window functions are not allowed in WHERE
SELECT customer_id, order_id, date(ordered_at) AS order_date
FROM orders
WHERE ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY ordered_at) = 1;
```

```text
Parse error near line 2: misuse of window function ROW_NUMBER()
   date(ordered_at) AS order_date FROM orders WHERE ROW_NUMBER() OVER (PARTITION
                                      error here ---^
```

At least it fails loudly. Compute the window in a CTE, filter outside:

```sql
WITH numbered AS (
  SELECT customer_id, order_id, date(ordered_at) AS order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY ordered_at) AS rn
  FROM orders
)
SELECT customer_id, order_id, order_date
FROM numbered
WHERE rn = 1
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬──────────┬────────────╮
│ customer_id │ order_id │ order_date │
╞═════════════╪══════════╪════════════╡
│           2 │     1094 │ 2024-03-16 │
│           3 │     3800 │ 2025-09-03 │
│           4 │     4246 │ 2025-10-27 │
│           5 │     4152 │ 2023-05-05 │
│           6 │     1058 │ 2025-11-14 │
╰─────────────┴──────────┴────────────╯
```

(This is exactly the gap `QUALIFY` fills in dialects that have it.)

### Pitfall 3 — RANK where you meant ROW_NUMBER in top-N

*"Feature the top 3 reviews per product, highest rating first."* Using `RANK`:

```sql
-- BAD: RANK() lets ties flood past the top-3 cutoff
WITH ranked AS (
  SELECT product_id, review_id, rating,
         RANK() OVER (PARTITION BY product_id ORDER BY rating DESC) AS rnk
  FROM reviews
  WHERE product_id IN (64, 68)
)
SELECT product_id, review_id, rating, rnk
FROM ranked
WHERE rnk <= 3
ORDER BY product_id, rnk, review_id;
```

```text
╭────────────┬───────────┬────────┬─────╮
│ product_id │ review_id │ rating │ rnk │
╞════════════╪═══════════╪════════╪═════╡
│         64 │       816 │      5 │   1 │
│         64 │      1306 │      5 │   1 │
│         64 │      1316 │      5 │   1 │
│         64 │      1776 │      5 │   1 │
│         64 │      1948 │      5 │   1 │
│         64 │      2293 │      5 │   1 │
│         64 │      3179 │      5 │   1 │
│         68 │       769 │      5 │   1 │
│         68 │      1375 │      5 │   1 │
│         68 │      2583 │      5 │   1 │
╰────────────┴───────────┴────────┴─────╯
```

Product 64 returned **seven** "top 3" reviews — all seven 5-star reviews tie
at rank 1 (and the 4-star rows jump to rank 8, past the cutoff). If the page
layout has room for exactly three, use `ROW_NUMBER` with a deterministic
tiebreaker (here: most recent first):

```sql
WITH ranked AS (
  SELECT product_id, review_id, rating,
         ROW_NUMBER() OVER (
           PARTITION BY product_id
           ORDER BY rating DESC, created_at DESC
         ) AS rn
  FROM reviews
  WHERE product_id IN (64, 68)
)
SELECT product_id, review_id, rating, rn
FROM ranked
WHERE rn <= 3
ORDER BY product_id, rn;
```

```text
╭────────────┬───────────┬────────┬────╮
│ product_id │ review_id │ rating │ rn │
╞════════════╪═══════════╪════════╪════╡
│         64 │      1948 │      5 │  1 │
│         64 │      3179 │      5 │  2 │
│         64 │      1776 │      5 │  3 │
│         68 │      1375 │      5 │  1 │
│         68 │      2583 │      5 │  2 │
│         68 │       769 │      5 │  3 │
╰────────────┴───────────┴────────┴────╯
```

Exactly three per product. The reverse mistake exists too: using `ROW_NUMBER`
for a leaderboard silently demotes tied performers that deserve equal rank.
Choose per the business rule, not by habit.

### Pitfall 4 — running SUM with RANGE vs ROWS on duplicate dates

*"Running revenue, order by order, for the first week of November 2023."*
Ordering the window by `order_date` — which has duplicates — and relying on
the default frame:

```sql
-- BAD: default RANGE frame — every same-day order shows the same "running" value
WITH order_totals AS (
  SELECT o.order_id,
         date(o.ordered_at) AS order_date,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
           + o.shipping_cost AS order_total
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
    AND o.ordered_at >= '2023-11-01' AND o.ordered_at < '2023-11-07'
  GROUP BY o.order_id, o.shipping_cost
)
SELECT order_id, order_date,
       ROUND(order_total, 2) AS order_total,
       ROUND(SUM(order_total) OVER (ORDER BY order_date), 2) AS running_revenue
FROM order_totals
ORDER BY order_date, order_id;
```

```text
╭──────────┬────────────┬─────────────┬─────────────────╮
│ order_id │ order_date │ order_total │ running_revenue │
╞══════════╪════════════╪═════════════╪═════════════════╡
│     3826 │ 2023-11-01 │      245.78 │          245.78 │
│      459 │ 2023-11-03 │      287.27 │          533.05 │
│     2671 │ 2023-11-05 │      1560.6 │         6238.35 │
│     3108 │ 2023-11-05 │       56.18 │         6238.35 │
│     3121 │ 2023-11-05 │      252.05 │         6238.35 │
│     3924 │ 2023-11-05 │      316.32 │         6238.35 │
│     4030 │ 2023-11-05 │     1538.26 │         6238.35 │
│     4040 │ 2023-11-05 │     1981.89 │         6238.35 │
│     1412 │ 2023-11-06 │      402.23 │         7196.17 │
│     4497 │ 2023-11-06 │       277.3 │         7196.17 │
│     5401 │ 2023-11-06 │       74.22 │         7196.17 │
│     5562 │ 2023-11-06 │      204.07 │         7196.17 │
╰──────────┴────────────┴─────────────┴─────────────────╯
```

All six November-5 orders show 6,238.35. Under the default `RANGE` frame, the
current row's frame includes **all its peers** — every row with the same
`order_date` — so each same-day row sums the entire day. The day-end totals
are right, but nothing in between is a per-order running value. Fix: make the
ordering unique and the frame explicit:

```sql
WITH order_totals AS (
  SELECT o.order_id,
         date(o.ordered_at) AS order_date,
         SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
           + o.shipping_cost AS order_total
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status <> 'cancelled'
    AND o.ordered_at >= '2023-11-01' AND o.ordered_at < '2023-11-07'
  GROUP BY o.order_id, o.shipping_cost
)
SELECT order_id, order_date,
       ROUND(order_total, 2) AS order_total,
       ROUND(SUM(order_total) OVER (
               ORDER BY order_date, order_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
             ), 2) AS running_revenue
FROM order_totals
ORDER BY order_date, order_id;
```

```text
╭──────────┬────────────┬─────────────┬─────────────────╮
│ order_id │ order_date │ order_total │ running_revenue │
╞══════════╪════════════╪═════════════╪═════════════════╡
│     3826 │ 2023-11-01 │      245.78 │          245.78 │
│      459 │ 2023-11-03 │      287.27 │          533.05 │
│     2671 │ 2023-11-05 │      1560.6 │         2093.65 │
│     3108 │ 2023-11-05 │       56.18 │         2149.83 │
│     3121 │ 2023-11-05 │      252.05 │         2401.88 │
│     3924 │ 2023-11-05 │      316.32 │          2718.2 │
│     4030 │ 2023-11-05 │     1538.26 │         4256.46 │
│     4040 │ 2023-11-05 │     1981.89 │         6238.35 │
│     1412 │ 2023-11-06 │      402.23 │         6640.58 │
│     4497 │ 2023-11-06 │       277.3 │         6917.88 │
│     5401 │ 2023-11-06 │       74.22 │          6992.1 │
│     5562 │ 2023-11-06 │      204.07 │         7196.17 │
╰──────────┴────────────┴─────────────┴─────────────────╯
```

Now the total climbs order by order and still lands on 7,196.17. Either half
of the fix alone would do it (a unique `ORDER BY` leaves no peers; `ROWS`
ignores peers) — doing both is self-documenting.

## Exercises

Answer each as a business question against `shop.db`. Use the canonical metric
definitions from `DATASET.md`. No answers here — solutions live in
`solutions/06-window-functions.md`.

**Warm-up**

1. For every review of the Flex Folding Poles (product 105), show the
   `review_id`, the rating, the product's average rating, and how far the
   rating deviates from that average — one output row per review.
2. Number each customer's non-cancelled orders chronologically (1 = first
   order). Show the sequence for customer 44: order id, order date, sequence
   number.
3. Report gross revenue per month for 2024, and each month's share (%) of
   2024's total gross revenue. Which month carried a quarter of the year?

**Core**

4. Compute month-over-month gross revenue growth (%) for every month of 2025.
   January 2025's growth must be a real number, not NULL — think about what
   your CTE needs to include for `LAG` to see it.
5. Compute a 3-month moving average of monthly gross revenue over the full
   history, then display only the 12 most recent months. (Careful: if you
   filter to 12 months *before* averaging, the first two averages will be
   wrong. Where must the filter go?)
6. Split all customers who have ordered into lifetime-spend quartiles with
   `NTILE(4)` (1 = biggest spenders). For each quartile report: number of
   customers, min/max/average spend, and the quartile's share (%) of total
   customer spend. What share do the top 25% of customers account for?
7. For each category, find the top 3 best-rated products — average review
   rating, counting only products with at least 3 reviews. Rank
   deterministically: break rating ties by review count (more reviews first),
   then product name. Return category, rank, product, average rating, review
   count.
8. For each customer with at least 5 non-cancelled orders, compute the average
   number of days between their consecutive orders. Show the 10 customers who
   reorder fastest, with their order count.

**Challenge**

9. Build a Pareto view of the 19 categories: order them by gross revenue
   (descending) and show each category's revenue plus the *cumulative* share
   (%) of total revenue. How many categories does it take to pass 80%?
   (Watch out for the default frame — make your running sum tie-proof.)
10. For every customer with at least 3 non-cancelled orders, compare their
    *first* order total to their *most recent* order total (order total =
    item revenue + shipping). Show the 10 customers with the largest
    percentage increase: customer id, order count, first total, latest total,
    % change. One row per customer — no duplicates.
11. How long do customers wait between orders? Take every gap between
    consecutive non-cancelled orders (all customers), bucket the gaps into
    `0-7 days`, `8-30 days`, `31-90 days`, and `91+ days`, and report the
    number of gaps and the share (%) of all gaps in each bucket, ordered from
    shortest to longest bucket.
12. Find the single best revenue month of each calendar year (2023–2026) by
    gross revenue. Use a ranking function that would expose a tie for first
    place rather than hide it. Return year, month, and that month's gross
    revenue.

## Key takeaways

- **Window = aggregate without collapse.** `GROUP BY` merges rows;
  `f(x) OVER (...)` annotates them.
- **`OVER (PARTITION BY p ORDER BY o frame)`** — partition: independent
  groups; order: sequence within group; frame: visible slice.
- Windows see rows **after** `WHERE`/`GROUP BY`/`HAVING`; they may appear only
  in `SELECT` and the final `ORDER BY`. To filter on one → CTE (or `QUALIFY`
  in dialects that have it).
- **Ties:** `ROW_NUMBER` 1,2,3,4 (arbitrary within ties — always add a unique
  tiebreaker); `RANK` 1,1,1,4; `DENSE_RANK` 1,1,1,2.
- **`NTILE(n)`** deals equal-*count* buckets in window order (first buckets
  take remainders).
- **`LAG`/`LEAD`(expr, offset, default)** read neighboring rows; NULL at
  partition edges; they only see rows inside the query — don't truncate the
  history the comparison needs.
- **Running total:** `SUM(x) OVER (ORDER BY unique_key)`.
  **Moving average:** `AVG(x) OVER (ORDER BY k ROWS BETWEEN n PRECEDING AND CURRENT ROW)`.
- **Default frame** with `ORDER BY` is `RANGE BETWEEN UNBOUNDED PRECEDING AND
  CURRENT ROW` — `RANGE` includes *peer* rows (ties). For running
  calculations: unique `ORDER BY` or explicit `ROWS`.
- **`LAST_VALUE` needs** `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED
  FOLLOWING` (default frame stops at the current row). `FIRST_VALUE` is safe.
- **Percent of total:** `100.0 * x / SUM(x) OVER ()`; over grouped rows:
  `SUM(SUM(x)) OVER ()`.
- **Named windows:** `WINDOW w AS (ORDER BY ...)`, then `OVER w` or
  `OVER (w ROWS ...)` to extend with a frame.
- **Top-N per group:** metric CTE → `ROW_NUMBER() OVER (PARTITION BY grp
  ORDER BY metric DESC, tiebreaker)` → outer `WHERE rn <= N`. Memorize it.
