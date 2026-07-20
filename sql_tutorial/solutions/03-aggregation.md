# Module 3 Solutions — Aggregation

All solutions run read-only against `shop.db`. Outputs are real `sqlite3 -box` results.

## Warm-up

### Exercise 1 — Catalog snapshot

```sql
SELECT
  COUNT(*)                    AS products,
  SUM(is_active)              AS active,
  COUNT(*) - SUM(is_active)   AS discontinued,
  COUNT(DISTINCT supplier_id) AS suppliers
FROM products;
```

```text
╭──────────┬────────┬──────────────┬───────────╮
│ products │ active │ discontinued │ suppliers │
╞══════════╪════════╪══════════════╪═══════════╡
│      350 │    324 │           26 │        40 │
╰──────────┴────────┴──────────────┴───────────╯
```

Because `is_active` is a 0/1 flag, `SUM(is_active)` counts the active products directly — the compact cousin of `SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END)`. `COUNT(DISTINCT supplier_id)` deduplicates: 350 products, but only 40 suppliers behind them.

### Exercise 2 — Order pipeline by status

```sql
SELECT status, COUNT(*) AS n_orders
FROM orders
GROUP BY status
ORDER BY n_orders DESC;
```

```text
╭───────────┬──────────╮
│  status   │ n_orders │
╞═══════════╪══════════╡
│ delivered │     5207 │
│ cancelled │      315 │
│ returned  │      172 │
│ shipped   │      153 │
│ paid      │       90 │
│ pending   │       63 │
╰───────────┴──────────╯
```

One bucket per status, ranked by the aggregate via its alias. ~87% of all orders end delivered.

### Exercise 3 — Top 5 countries by customers

```sql
SELECT country, COUNT(*) AS n_customers
FROM customers
GROUP BY country
ORDER BY n_customers DESC
LIMIT 5;
```

```text
╭────────────────┬─────────────╮
│    country     │ n_customers │
╞════════════════╪═════════════╡
│ Sweden         │         175 │
│ Germany        │         115 │
│ Denmark        │         101 │
│ Norway         │          98 │
│ United Kingdom │          69 │
╰────────────────┴─────────────╯
```

The standard top-N shape: group, order by the count descending, `LIMIT`.

## Core

### Exercise 4 — Monthly order volume, 2025

```sql
SELECT strftime('%Y-%m', ordered_at) AS month, COUNT(*) AS n_orders
FROM orders
WHERE ordered_at >= '2025-01-01' AND ordered_at < '2026-01-01'
GROUP BY month
ORDER BY month;
```

```text
╭─────────┬──────────╮
│  month  │ n_orders │
╞═════════╪══════════╡
│ 2025-01 │       88 │
│ 2025-02 │       88 │
│ 2025-03 │      121 │
│ 2025-04 │      118 │
│ 2025-05 │      123 │
│ 2025-06 │      166 │
│ 2025-07 │      188 │
│ 2025-08 │      158 │
│ 2025-09 │      173 │
│ 2025-10 │      171 │
│ 2025-11 │      295 │
│ 2025-12 │      447 │
╰─────────┴──────────╯
```

Staff up for June–July (hiking season) and especially November–December (holidays), which run at 2–5× the January baseline. Common wrong approach: putting the year filter in `HAVING month LIKE '2025%'` — same answer, but it groups all 3.5 years first and does the row filtering after aggregation (Pitfall 4).

### Exercise 5 — Rating distribution and text share

```sql
SELECT
  rating,
  COUNT(*) AS n_reviews,
  ROUND(100.0 * COUNT(review_text) / COUNT(*), 1) AS pct_with_text
FROM reviews
GROUP BY rating
ORDER BY rating;
```

```text
╭────────┬───────────┬───────────────╮
│ rating │ n_reviews │ pct_with_text │
╞════════╪═══════════╪═══════════════╡
│      1 │       160 │          70.0 │
│      2 │       192 │          63.0 │
│      3 │       439 │          63.3 │
│      4 │      1056 │          64.2 │
│      5 │      1484 │          66.8 │
╰────────┴───────────┴───────────────╯
```

This exercise uses the `COUNT(col)` NULL-skipping behavior *deliberately*: `COUNT(review_text)` counts only reviews with text, so `COUNT(review_text) / COUNT(*)` is the text share per rating bucket. Ratings skew heavily positive (4s and 5s are 76% of reviews), and 1-star reviewers are indeed the most motivated writers (70%). Watch the `100.0` — with `100` the integer division would return 0 for every row.

### Exercise 6 — Payment failure rate by year

```sql
SELECT
  strftime('%Y', paid_at) AS year,
  COUNT(*) AS attempts,
  SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed,
  ROUND(100.0 * SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 1) AS failure_pct
FROM payments
WHERE method <> 'refund'
GROUP BY year
ORDER BY year;
```

```text
╭──────┬──────────┬────────┬─────────────╮
│ year │ attempts │ failed │ failure_pct │
╞══════╪══════════╪════════╪═════════════╡
│ 2023 │      347 │     21 │         6.1 │
│ 2024 │      971 │     64 │         6.6 │
│ 2025 │     2144 │    113 │         5.3 │
│ 2026 │     2533 │    144 │         5.7 │
╰──────┴──────────┴────────┴─────────────╯
```

Conditional aggregation (`SUM(CASE ...)`) counts failures inside each year bucket. The rate wobbles between 5.3% and 6.6% — no clear trend. Excluding `method = 'refund'` matters: refunds aren't payment attempts and would dilute the denominator.

### Exercise 7 — Carrier scorecard

```sql
SELECT
  carrier,
  COUNT(*) AS shipments,
  COUNT(*) - COUNT(delivered_at) AS in_transit,
  ROUND(AVG(julianday(delivered_at) - julianday(shipped_at)), 2) AS avg_days
FROM shipments
GROUP BY carrier
ORDER BY avg_days;
```

```text
╭──────────┬───────────┬────────────┬──────────╮
│ carrier  │ shipments │ in_transit │ avg_days │
╞══════════╪═══════════╪════════════╪══════════╡
│ Bring    │      1110 │         35 │      5.4 │
│ DHL      │      1101 │         36 │      5.4 │
│ UPS      │      1126 │         30 │     5.47 │
│ PostNord │      1122 │         32 │     5.52 │
│ DPD      │      1073 │         20 │     5.55 │
╰──────────┴───────────┴────────────┴──────────╯
```

`COUNT(*) - COUNT(delivered_at)` exploits NULL-skipping to count in-transit parcels, and `AVG` correctly averages delivery time over delivered shipments only (NULL `delivered_at` rows are skipped). The carriers are nearly indistinguishable (~5.4–5.6 days). Wrong approach to watch for: `COALESCE(delivered_at, ...)` with today's date *inside* the AVG would mix "still in transit" durations into a delivered-time metric — a different (and muddier) question.

### Exercise 8 — Top 10 products by item revenue

```sql
SELECT
  product_id,
  SUM(quantity) AS units_sold,
  ROUND(SUM(quantity * unit_price * (1 - discount_pct / 100.0)), 2) AS item_revenue
FROM order_items
GROUP BY product_id
ORDER BY item_revenue DESC
LIMIT 10;
```

```text
╭────────────┬────────────┬──────────────╮
│ product_id │ units_sold │ item_revenue │
╞════════════╪════════════╪══════════════╡
│        266 │        212 │    146213.23 │
│        146 │        264 │    106300.06 │
│         46 │        105 │    102745.91 │
│        190 │        235 │     94804.15 │
│         37 │        122 │     91374.12 │
│        289 │         84 │     76331.32 │
│        323 │        133 │     71976.36 │
│        169 │        222 │      67501.4 │
│        143 │        168 │     63633.86 │
│        178 │        118 │     63221.25 │
╰────────────┴────────────┴──────────────╯
```

Canonical item-revenue formula, grouped by product. Two important details: `100.0` avoids integer-division zeroing of every discount, and `order_items.unit_price` (the historical price) is the right column — using `products.unit_price` (current list price) would rewrite history. Caveat for the honest analyst: this includes lines from cancelled orders; excluding them needs the join to `orders` (Module 4).

### Exercise 9 — Marketing opt-in rate by country (≥ 60 customers)

```sql
SELECT
  country,
  COUNT(*) AS n_customers,
  ROUND(100.0 * SUM(marketing_opt_in) / COUNT(*), 1) AS opt_in_pct
FROM customers
GROUP BY country
HAVING COUNT(*) >= 60
ORDER BY opt_in_pct DESC;
```

```text
╭────────────────┬─────────────┬────────────╮
│    country     │ n_customers │ opt_in_pct │
╞════════════════╪═════════════╪════════════╡
│ Norway         │          98 │       43.9 │
│ United Kingdom │          69 │       43.5 │
│ Denmark        │         101 │       42.6 │
│ Germany        │         115 │       40.9 │
│ Netherlands    │          64 │       39.1 │
│ Sweden         │         175 │       36.0 │
│ Finland        │          65 │       35.4 │
╰────────────────┴─────────────┴────────────╯
```

The size threshold is a fact about the group, so it belongs in `HAVING`; the opt-in rate is `SUM` of a 0/1 flag over `COUNT(*)`. Interesting spread: the home market Sweden has the second-lowest consent rate.

## Challenge

### Exercise 10 — Average margin by category (active products)

```sql
SELECT
  category_id,
  COUNT(*) AS active_products,
  ROUND(AVG(100.0 * (unit_price - unit_cost) / unit_price), 1) AS avg_margin_pct
FROM products
WHERE is_active = 1
GROUP BY category_id
ORDER BY avg_margin_pct DESC;
```

```text
╭─────────────┬─────────────────┬────────────────╮
│ category_id │ active_products │ avg_margin_pct │
╞═════════════╪═════════════════╪════════════════╡
│           4 │              20 │           47.4 │
│          21 │              16 │           47.2 │
│          25 │              17 │           46.2 │
│          17 │              14 │           46.2 │
│          12 │              12 │           46.2 │
│           5 │              20 │           46.2 │
│          16 │              12 │           45.8 │
│           2 │              23 │           45.4 │
│          15 │              16 │           45.2 │
│          11 │              18 │           45.0 │
│           7 │              21 │           45.0 │
│          24 │              14 │           44.9 │
│          23 │              19 │           44.8 │
│          13 │              16 │           44.8 │
│          19 │              16 │           44.6 │
│           3 │              22 │           43.9 │
│           9 │              19 │           43.8 │
│           8 │              19 │           43.1 │
│          20 │              10 │           41.7 │
╰─────────────┴─────────────────┴────────────────╯
```

`WHERE is_active = 1` is a row condition, so it goes in `WHERE`, not `HAVING`. Note this is the average of per-product margin *percentages* (each product weighted equally) — a defensible pricing view. A revenue-weighted margin (`100.0 * SUM(unit_price - unit_cost) / SUM(unit_price)`) would answer a different question and give slightly different numbers; know which one you're being asked for. Category names require the join in Module 4.

### Exercise 11 — Yearly order-health report

```sql
SELECT
  strftime('%Y', ordered_at) AS year,
  COUNT(*) AS orders,
  SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
  SUM(CASE WHEN status = 'returned'  THEN 1 ELSE 0 END) AS returned,
  ROUND(100.0 * SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) / COUNT(*), 1) AS cancel_pct,
  ROUND(100.0 * SUM(CASE WHEN status = 'returned'  THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_pct
FROM orders
GROUP BY year
ORDER BY year;
```

```text
╭──────┬────────┬───────────┬──────────┬────────────┬────────────╮
│ year │ orders │ cancelled │ returned │ cancel_pct │ return_pct │
╞══════╪════════╪═══════════╪══════════╪════════════╪════════════╡
│ 2023 │    349 │        23 │       10 │        6.6 │        2.9 │
│ 2024 │    962 │        54 │       37 │        5.6 │        3.8 │
│ 2025 │   2136 │       106 │       70 │        5.0 │        3.3 │
│ 2026 │   2553 │       132 │       55 │        5.2 │        2.2 │
╰──────┴────────┴───────────┴──────────┴────────────┴────────────╯
```

Cancellation rate improved from 6.6% to ~5%. The caveat: 2026's low return rate (2.2%) is *not* good news yet — the year is incomplete, and recent orders haven't had time to be returned (many are still in flight). This is the maturation effect from the module's monthly pivot example: never compare an open period to closed ones without saying so.

### Exercise 12 — 2026 monthly finance summary

```sql
SELECT
  strftime('%Y-%m', paid_at) AS month,
  COUNT(CASE WHEN amount > 0 THEN 1 END) AS sales,
  ROUND(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 2)  AS inflow,
  ROUND(SUM(CASE WHEN amount < 0 THEN -amount ELSE 0 END), 2) AS refunded,
  ROUND(SUM(amount), 2) AS net_cash,
  ROUND(AVG(CASE WHEN amount > 0 THEN amount END), 2) AS avg_sale
FROM payments
WHERE status = 'captured' AND paid_at >= '2026-01-01'
GROUP BY month
ORDER BY month;
```

```text
╭─────────┬───────┬───────────┬──────────┬───────────┬──────────╮
│  month  │ sales │  inflow   │ refunded │ net_cash  │ avg_sale │
╞═════════╪═══════╪═══════════╪══════════╪═══════════╪══════════╡
│ 2026-01 │   200 │ 129501.77 │  7619.62 │ 121882.15 │   647.51 │
│ 2026-02 │   218 │ 119589.71 │   5872.8 │ 113716.91 │   548.58 │
│ 2026-03 │   287 │ 171253.96 │  1915.46 │  169338.5 │    596.7 │
│ 2026-04 │   347 │ 197019.52 │  3531.76 │ 193487.76 │   567.78 │
│ 2026-05 │   435 │ 237175.39 │  7063.07 │ 230112.32 │   545.23 │
│ 2026-06 │   571 │ 292153.73 │  5564.88 │ 286588.85 │   511.65 │
│ 2026-07 │   300 │ 148229.62 │  5835.65 │ 142393.97 │    494.1 │
╰─────────┴───────┴───────────┴──────────┴───────────┴──────────╯
```

Every column is a conditional aggregate over the same rows, computed in one pass: `SUM(CASE ... THEN amount ELSE 0 END)` splits inflow from refunds by sign, `SUM(amount)` nets them (matching the payments-side net-revenue definition), and `AVG(CASE WHEN amount > 0 THEN amount END)` — no `ELSE`, so refunds become NULL and are skipped — is the average sale, our AOV proxy (a captured positive payment equals its order's total: item revenue + shipping). The canonical AOV over *all* non-cancelled orders, computed from order items, arrives in Module 4. Common wrong approach: `AVG(amount)` including the negative refunds, which understates AOV.
