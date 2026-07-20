# Module 5 Solutions — Subqueries & CTEs

All queries run against `shop.db` and use the canonical metric definitions from DATASET.md.

## Warm-up

### Exercise 1 — Pricing sanity check

```sql
SELECT
    (SELECT ROUND(AVG(unit_price), 2) FROM products) AS catalog_avg_price,
    COUNT(*) AS products_above_avg
FROM products
WHERE unit_price > (SELECT AVG(unit_price) FROM products);
```

```text
╭───────────────────┬────────────────────╮
│ catalog_avg_price │ products_above_avg │
╞═══════════════════╪════════════════════╡
│             206.4 │                128 │
╰───────────────────┴────────────────────╯
```

Two uncorrelated scalar subqueries: one in the SELECT list (display the average), one in WHERE (filter against it). Each is evaluated once. Only 128 of 350 products sit above the mean — the price distribution is right-skewed.

**Common wrong approach:** `WHERE unit_price > AVG(unit_price)` — aggregates are illegal in WHERE, because WHERE runs before aggregation:

```text
Parse error near line 2: misuse of aggregate: AVG()
  SELECT COUNT(*) FROM products WHERE unit_price > AVG(unit_price);
                                     error here ---^
```

### Exercise 2 — Merchandising request — top 5 Water Sports products

```sql
SELECT name, unit_price
FROM products
WHERE category_id IN (
    SELECT category_id
    FROM categories
    WHERE parent_category_id =
          (SELECT category_id FROM categories WHERE name = 'Water Sports')
)
ORDER BY unit_price DESC
LIMIT 5;
```

```text
╭────────────────────────┬────────────╮
│          name          │ unit_price │
╞════════════════════════╪════════════╡
│ Drift Inflatable Kayak │    1004.85 │
│ Fjord Sit-on-Top Kayak │     934.86 │
│ Skerry Spray Skirt     │     773.95 │
│ Wave Inflatable Kayak  │     729.84 │
│ Fjord Inflatable Kayak │     704.38 │
╰────────────────────────┴────────────╯
```

Products attach only to *child* categories, so we resolve 'Water Sports' to its id with a scalar subquery, collect its children's ids with the middle subquery, and filter products with `IN`. No hard-coded ids: if category ids are ever renumbered, the query still works.

### Exercise 3 — Deduplication awareness — city names

```sql
SELECT
    (SELECT COUNT(*) FROM (SELECT city FROM customers
                           UNION ALL
                           SELECT city FROM addresses)) AS with_union_all,
    (SELECT COUNT(*) FROM (SELECT city FROM customers
                           UNION
                           SELECT city FROM addresses)) AS with_union;
```

```text
╭────────────────┬────────────╮
│ with_union_all │ with_union │
╞════════════════╪════════════╡
│           1914 │         38 │
╰────────────────┴────────────╯
```

`UNION ALL` keeps every row (800 customers + 1,114 addresses = 1,914); `UNION` deduplicates down to the 38 distinct city names. Same syntax, wildly different semantics — which is exactly why you should always choose between them consciously (see Pitfall 3 in the module).

## Core

### Exercise 4 — Premium products — ≥ 25% above category average

```sql
SELECT
    p.name,
    c.name AS category,
    p.unit_price,
    (SELECT ROUND(AVG(p2.unit_price), 2)
     FROM products p2
     WHERE p2.category_id = p.category_id) AS category_avg
FROM products p
JOIN categories c ON c.category_id = p.category_id
WHERE p.unit_price >= 1.25 * (SELECT AVG(p2.unit_price)
                              FROM products p2
                              WHERE p2.category_id = p.category_id)
ORDER BY p.unit_price DESC
LIMIT 10;
```

```text
╭─────────────────────────┬──────────────────┬────────────┬──────────────╮
│          name           │     category     │ unit_price │ category_avg │
╞═════════════════════════╪══════════════════╪════════════╪══════════════╡
│ Drift Inflatable Kayak  │ Kayaks           │    1004.85 │        487.3 │
│ Fjord Sit-on-Top Kayak  │ Kayaks           │     934.86 │        487.3 │
│ Probe Airbag Pack       │ Avalanche Safety │     893.33 │       450.53 │
│ Rescue Avalanche Beacon │ Avalanche Safety │     834.53 │       450.53 │
│ Tele Touring Skis       │ Skis             │     775.98 │       443.02 │
│ Skerry Spray Skirt      │ Kayaks           │     773.95 │        487.3 │
│ Drift Touring Skis      │ Skis             │     745.19 │       443.02 │
│ Nordic Tent 2P          │ Tents            │     744.79 │       479.31 │
│ Probe Snow Shovel       │ Avalanche Safety │     744.12 │       450.53 │
│ Alpine Tunnel Tent      │ Tents            │     734.69 │       479.31 │
╰─────────────────────────┴──────────────────┴────────────┴──────────────╯
```

Total count:

```sql
SELECT COUNT(*) AS premium_products
FROM products p
WHERE p.unit_price >= 1.25 * (SELECT AVG(p2.unit_price)
                              FROM products p2
                              WHERE p2.category_id = p.category_id);
```

```text
╭──────────────────╮
│ premium_products │
╞══════════════════╡
│              120 │
╰──────────────────╯
```

The correlation `p2.category_id = p.category_id` gives each product its own category's average. **Common wrong approach:** comparing against the *global* average `(SELECT AVG(unit_price) FROM products)` — that just re-finds expensive categories (kayaks, skis), not products expensive *for what they are*. Note also the cleaner production rewrite from the module's Pitfall 1: compute the 19 category averages once in a CTE (`GROUP BY category_id`) and join, instead of conceptually re-running the average per product.

### Exercise 5 — Lapsed customers — active in 2025, not in 2026

```sql
SELECT COUNT(*) AS lapsed_customers
FROM (
    SELECT customer_id
    FROM orders
    WHERE status <> 'cancelled'
      AND ordered_at >= '2025-01-01' AND ordered_at < '2026-01-01'
    EXCEPT
    SELECT customer_id
    FROM orders
    WHERE status <> 'cancelled'
      AND ordered_at >= '2026-01-01'
);
```

```text
╭──────────────────╮
│ lapsed_customers │
╞══════════════════╡
│              117 │
╰──────────────────╯
```

Both sides implement "active customer" canonically (at least one non-cancelled order in the period); `EXCEPT` subtracts the 2026 actives from the 2025 actives. `EXCEPT` deduplicates, so multi-order customers count once. **Common wrong approach:** a single scan with `WHERE strftime('%Y', ordered_at) = '2025' AND strftime('%Y', ordered_at) <> '2026'` — the second condition is vacuously true row-by-row; "not active in 2026" is a property of the *customer*, not of any single order row, so it needs a set difference (or `NOT IN`/`NOT EXISTS` against a subquery).

### Exercise 6 — AOV by country

```sql
WITH order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
            + o.shipping_cost AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id
)
SELECT
    c.country,
    COUNT(*) AS orders,
    ROUND(AVG(ot.order_total), 2) AS aov
FROM order_totals ot
JOIN customers c ON c.customer_id = ot.customer_id
GROUP BY c.country
ORDER BY aov DESC;
```

```text
╭────────────────┬────────┬────────╮
│    country     │ orders │  aov   │
╞════════════════╪════════╪════════╡
│ Netherlands    │    439 │ 616.73 │
│ Finland        │    357 │ 586.93 │
│ Austria        │    129 │ 556.81 │
│ Sweden         │   1530 │ 553.63 │
│ Germany        │    788 │ 539.01 │
│ Denmark        │    696 │ 537.79 │
│ Switzerland    │    290 │ 536.43 │
│ Norway         │    624 │ 533.04 │
│ France         │    335 │  530.9 │
│ United Kingdom │    497 │  512.8 │
╰────────────────┴────────┴────────╯
```

The CTE establishes the right grain first — one row per non-cancelled order with its canonical order total (item revenue + shipping) — then the outer query joins to customers and averages per country. **Common wrong approach:** joining orders→order_items→customers and averaging line revenue directly. That computes an average *item* value weighted by line count, not an average *order* value: multi-line orders get counted once per line (the Module 4 fan-out pitfall wearing a new hat).

### Exercise 7 — Catalog feed — full category paths per product

```sql
WITH RECURSIVE category_paths AS (
    SELECT category_id, name, name AS path
    FROM categories
    WHERE parent_category_id IS NULL
    UNION ALL
    SELECT c.category_id, c.name, cp.path || ' > ' || c.name
    FROM categories c
    JOIN category_paths cp ON c.parent_category_id = cp.category_id
)
SELECT p.sku, p.name, cp.path AS category_path
FROM products p
JOIN category_paths cp ON cp.category_id = p.category_id
ORDER BY p.sku
LIMIT 5;
```

```text
╭────────────┬────────────────────────┬─────────────────╮
│    sku     │          name          │  category_path  │
╞════════════╪════════════════════════╪═════════════════╡
│ NK-02-0011 │ Nordic Tunnel Tent     │ Camping > Tents │
│ NK-02-0061 │ Storm Tent 2P          │ Camping > Tents │
│ NK-02-0064 │ Trail Tent 3P          │ Camping > Tents │
│ NK-02-0066 │ Nordic Ultralight Tent │ Camping > Tents │
│ NK-02-0150 │ Storm Dome Tent        │ Camping > Tents │
╰────────────┴────────────────────────┴─────────────────╯
```

(350 rows without the LIMIT — one per product.) The recursive CTE materializes every category's full path exactly as in the module; the only new step is the ordinary join from products. Because every product references a child category and every child's path flows down from a root, the inner join loses nothing.

### Exercise 8 — Ops gap check — 2025 days with zero orders

```sql
WITH RECURSIVE calendar AS (
    SELECT DATE('2025-01-01') AS day
    UNION ALL
    SELECT DATE(day, '+1 day') FROM calendar WHERE day < '2025-12-31'
),
daily_orders AS (
    SELECT DATE(ordered_at) AS day
    FROM orders
    GROUP BY day
)
SELECT c.day
FROM calendar c
LEFT JOIN daily_orders d ON d.day = c.day
WHERE d.day IS NULL
ORDER BY c.day;
```

```text
╭────────────╮
│    day     │
╞════════════╡
│ 2025-01-01 │
│ 2025-01-11 │
│ 2025-01-28 │
│ 2025-02-16 │
│ 2025-03-06 │
╰────────────╯
```

Five silent days in all of 2025, all in the slow Q1 (and New Year's Day tops the list — plausible). The spine guarantees all 365 days are candidates; the LEFT JOIN + `IS NULL` anti-join keeps the days no order matched. **Common wrong approach:** `GROUP BY DATE(ordered_at) HAVING COUNT(*) = 0` — it can never return anything, because a day with zero orders has no rows to group. You cannot aggregate your way to rows that don't exist; you must generate them.

## Challenge

### Exercise 9 — Seasonality profile — 2025 monthly revenue and share of year

```sql
WITH order_revenue AS (
    SELECT
        strftime('%Y-%m', o.ordered_at) AS month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS item_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
      AND o.ordered_at >= '2025-01-01' AND o.ordered_at < '2026-01-01'
    GROUP BY o.order_id
),
monthly AS (
    SELECT month, SUM(item_revenue) AS gross_revenue
    FROM order_revenue
    GROUP BY month
),
year_total AS (
    SELECT SUM(gross_revenue) AS total FROM monthly
)
SELECT
    m.month,
    ROUND(m.gross_revenue, 2) AS gross_revenue,
    ROUND(100.0 * m.gross_revenue / yt.total, 1) AS pct_of_year
FROM monthly m
CROSS JOIN year_total yt
ORDER BY m.month;
```

```text
╭─────────┬───────────────┬─────────────╮
│  month  │ gross_revenue │ pct_of_year │
╞═════════╪═══════════════╪═════════════╡
│ 2025-01 │      38104.81 │         3.4 │
│ 2025-02 │      42952.29 │         3.8 │
│ 2025-03 │      53015.78 │         4.7 │
│ 2025-04 │      56496.34 │         5.0 │
│ 2025-05 │       71880.5 │         6.4 │
│ 2025-06 │      93965.19 │         8.3 │
│ 2025-07 │      98034.15 │         8.7 │
│ 2025-08 │      83420.47 │         7.4 │
│ 2025-09 │      97520.64 │         8.6 │
│ 2025-10 │       99072.5 │         8.8 │
│ 2025-11 │     150279.76 │        13.3 │
│ 2025-12 │     244602.36 │        21.7 │
╰─────────┴───────────────┴─────────────╯
```

A three-step pipeline where each CTE builds on the previous one: per-order revenue → per-month revenue → year total. The `CROSS JOIN` against the single-row `year_total` attaches the denominator to every month (a scalar subquery `(SELECT total FROM year_total)` works identically). December alone is 21.7% of the year and Nov+Dec together are 35% — the holiday spike DATASET.md promised. Note the grouping trick in `order_revenue`: `GROUP BY o.order_id` while selecting the month, legal because month is constant within one order.

### Exercise 10 — Worst crashes — biggest MoM revenue drops in history

```sql
WITH order_revenue AS (
    SELECT
        strftime('%Y-%m', o.ordered_at) AS month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS item_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id
),
monthly AS (
    SELECT month, SUM(item_revenue) AS gross_revenue
    FROM order_revenue
    GROUP BY month
)
SELECT
    cur.month,
    ROUND(cur.gross_revenue, 2) AS gross_revenue,
    ROUND(prev.gross_revenue, 2) AS prev_revenue,
    ROUND(100.0 * (cur.gross_revenue - prev.gross_revenue) / prev.gross_revenue, 1) AS mom_pct
FROM monthly cur
JOIN monthly prev
    ON prev.month = strftime('%Y-%m', DATE(cur.month || '-01', '-1 month'))
ORDER BY mom_pct ASC
LIMIT 3;
```

```text
╭─────────┬───────────────┬──────────────┬─────────╮
│  month  │ gross_revenue │ prev_revenue │ mom_pct │
╞═════════╪═══════════════╪══════════════╪═════════╡
│ 2025-01 │      38104.81 │    117650.48 │   -67.6 │
│ 2024-01 │      13397.55 │     30621.11 │   -56.2 │
│ 2026-01 │     128438.46 │    244602.36 │   -47.5 │
╰─────────┴───────────────┴──────────────┴─────────╯
```

The `monthly` CTE is referenced twice — once as `cur`, once as `prev`, shifted one month back with date arithmetic. Every one of the three worst "crashes" is a January following a holiday December: not a crisis, just seasonality — which is exactly why MoM numbers should always be read next to year-over-year ones. An inner `JOIN` (not LEFT) deliberately drops the first month of history (2023-01), which has no predecessor and therefore no defined MoM change. Module 6 replaces the self-join with `LAG(gross_revenue) OVER (ORDER BY month)`.

### Exercise 11 — Board slide — all-time gross revenue by top-level category

```sql
WITH RECURSIVE category_roots AS (
    SELECT category_id, name AS top_level
    FROM categories
    WHERE parent_category_id IS NULL
    UNION ALL
    SELECT c.category_id, cr.top_level
    FROM categories c
    JOIN category_roots cr ON c.parent_category_id = cr.category_id
)
SELECT
    cr.top_level,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN category_roots cr ON cr.category_id = p.category_id
WHERE o.status <> 'cancelled'
GROUP BY cr.top_level
ORDER BY gross_revenue DESC;
```

```text
╭───────────────┬───────────────╮
│   top_level   │ gross_revenue │
╞═══════════════╪═══════════════╡
│ Camping       │     863766.77 │
│ Winter Sports │     854648.85 │
│ Water Sports  │     480212.83 │
│ Hiking        │     385337.49 │
│ Climbing      │     261289.35 │
│ Apparel       │      241485.7 │
╰───────────────┴───────────────╯
```

The recursive CTE flattens the tree into a (category_id → top-level ancestor) mapping — every category, root or child, gets exactly one row — so the subsequent joins can't fan out. Then it's canonical item revenue over non-cancelled orders, grouped by the root. **Common wrong approach:** joining `products → categories → parent categories` with a fixed two-level self-join. It happens to work on Nordkart's 2-level tree but silently breaks the day someone adds a third level; the recursive version is depth-proof.

### Exercise 12 — First-purchase cohorts

```sql
WITH first_orders AS (
    SELECT customer_id, MIN(ordered_at) AS first_ordered_at
    FROM orders
    WHERE status <> 'cancelled'
    GROUP BY customer_id
)
SELECT
    strftime('%Y', first_ordered_at) AS cohort_year,
    COUNT(*) AS new_customers
FROM first_orders
GROUP BY cohort_year
ORDER BY cohort_year;
```

```text
╭─────────────┬───────────────╮
│ cohort_year │ new_customers │
╞═════════════╪═══════════════╡
│ 2023        │           162 │
│ 2024        │           193 │
│ 2025        │           190 │
│ 2026        │           128 │
╰─────────────┴───────────────╯
```

Aggregating an aggregate: the CTE reduces orders to one row per customer (their first non-cancelled order), and the outer query counts customers per first-order year. 162+193+190+128 = 673 — not 800, because 125 customers never ordered (a couple more only ever had cancelled orders). **Common wrong approach:** omitting `WHERE status <> 'cancelled'` — a customer whose 2024 order was cancelled and who first *really* bought in 2025 would be cohorted into 2024, breaking the "active customer" definition. Also note 2026 already has 128 first-time buyers in six and a half months — acquisition is accelerating.
