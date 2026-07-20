# Module 4 Solutions — Joins

All queries run against `shop.db` from the course root. Metric definitions are the canonical ones from `DATASET.md`.

## Warm-up

### Exercise 1 — 10 most recent delivered orders

```sql
SELECT
    o.order_id,
    o.ordered_at,
    c.first_name || ' ' || c.last_name AS customer,
    c.country
FROM orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
WHERE o.status = 'delivered'
ORDER BY o.ordered_at DESC
LIMIT 10;
```

```text
╭──────────┬─────────────────────┬────────────────┬─────────╮
│ order_id │     ordered_at      │    customer    │ country │
╞══════════╪═════════════════════╪════════════════╪═════════╡
│     4555 │ 2026-07-12 21:13:35 │ Johan Sjoberg  │ Sweden  │
│     5423 │ 2026-07-12 20:53:28 │ Kirsten Fors   │ Germany │
│     1046 │ 2026-07-12 16:05:52 │ Noah Persson   │ Germany │
│     2303 │ 2026-07-10 05:57:02 │ Astrid Fisker  │ Denmark │
│     3717 │ 2026-07-08 19:33:49 │ Sonja Kowalski │ Germany │
│      437 │ 2026-07-06 20:54:52 │ Hans Yilmaz    │ Norway  │
│      215 │ 2026-07-05 11:18:43 │ Hiro Tanaka    │ Germany │
│     2544 │ 2026-07-05 08:11:34 │ Yusuf Yilmaz   │ France  │
│     2756 │ 2026-07-05 07:30:47 │ Karl Lind      │ Germany │
│     5257 │ 2026-07-05 06:15:52 │ Priya Strand   │ Sweden  │
╰──────────┴─────────────────────┴────────────────┴─────────╯
```

A one-hop INNER JOIN "up" the foreign key: one row per order, so no fan-out risk. The `status` filter lives in `WHERE` — with an INNER JOIN, `WHERE` vs `ON` placement makes no difference; it's LEFT JOINs where it matters.

### Exercise 2 — products from Norwegian suppliers

```sql
SELECT
    p.name AS product,
    p.sku,
    s.name AS supplier
FROM products AS p
JOIN suppliers AS s
    ON s.supplier_id = p.supplier_id
WHERE s.country = 'Norway'
ORDER BY s.name, p.name
LIMIT 10;
```

```text
╭───────────────────────┬────────────┬────────────────────────╮
│        product        │    sku     │        supplier        │
╞═══════════════════════╪════════════╪════════════════════════╡
│ Aero Kids Harness     │ NK-08-0091 │ Bergsport Austria GmbH │
│ Cairn Winter Boots    │ NK-11-0129 │ Bergsport Austria GmbH │
│ Fjell Ski Bindings    │ NK-15-0012 │ Bergsport Austria GmbH │
│ Grip Chest Harness    │ NK-08-0120 │ Bergsport Austria GmbH │
│ Seal Phone Case       │ NK-21-0300 │ Bergsport Austria GmbH │
│ Storm Tunnel Tent     │ NK-02-0350 │ Bergsport Austria GmbH │
│ Drift Spray Skirt     │ NK-19-0038 │ Pyreneen Sport SARL    │
│ Frost Mittens         │ NK-25-0085 │ Pyreneen Sport SARL    │
│ Scout Compass         │ NK-13-0343 │ Pyreneen Sport SARL    │
│ Wave Sit-on-Top Kayak │ NK-19-0330 │ Pyreneen Sport SARL    │
╰───────────────────────┴────────────┴────────────────────────╯
```

... 24 rows total (drop the `LIMIT 10` to see them all). Note that supplier *names* don't necessarily sound Norwegian — the filter is on `suppliers.country`, which is the authoritative fact. Filtering on the joined dimension's attribute (`s.country`) rather than anything on `products` is the whole point of the join.

### Exercise 3 — child categories with parent names

```sql
SELECT
    child.name  AS category,
    parent.name AS parent_category
FROM categories AS child
JOIN categories AS parent
    ON parent.category_id = child.parent_category_id
ORDER BY parent.name, child.name;
```

```text
╭───────────────────────┬─────────────────╮
│       category        │ parent_category │
╞═══════════════════════╪═════════════════╡
│ Base Layers           │ Apparel         │
│ Gloves & Hats         │ Apparel         │
│ Jackets               │ Apparel         │
│ Backpacks             │ Camping         │
│ Camp Kitchen          │ Camping         │
│ Sleeping Bags         │ Camping         │
│ Tents                 │ Camping         │
│ Carabiners & Hardware │ Climbing        │
│ Harnesses             │ Climbing        │
│ Ropes & Slings        │ Climbing        │
│ Hiking Boots          │ Hiking          │
│ Navigation            │ Hiking          │
│ Trekking Poles        │ Hiking          │
│ Dry Bags              │ Water Sports    │
│ Kayaks                │ Water Sports    │
│ Paddles               │ Water Sports    │
│ Avalanche Safety      │ Winter Sports   │
│ Skis                  │ Winter Sports   │
│ Snowshoes             │ Winter Sports   │
╰───────────────────────┴─────────────────╯
```

A self-join: the same table under two aliases, playing two roles. INNER (not LEFT) is correct *here* because the question asks only for child categories — the six top-level rows, whose `parent_category_id` is NULL, can never match and are meant to be excluded. If the question were "all categories and their parent if any", you'd use LEFT.

## Core

### Exercise 4 — products with no reviews

The count:

```sql
SELECT COUNT(*) AS products_without_reviews
FROM products AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM reviews AS r
    WHERE r.product_id = p.product_id
);
```

```text
╭──────────────────────────╮
│ products_without_reviews │
╞══════════════════════════╡
│                       66 │
╰──────────────────────────╯
```

The 5 most expensive, via the equivalent `LEFT JOIN ... IS NULL` spelling:

```sql
SELECT
    p.product_id,
    p.name,
    p.unit_price,
    p.is_active
FROM products AS p
LEFT JOIN reviews AS r
    ON r.product_id = p.product_id
WHERE r.review_id IS NULL
ORDER BY p.unit_price DESC
LIMIT 5;
```

```text
╭────────────┬────────────────────┬────────────┬───────────╮
│ product_id │        name        │ unit_price │ is_active │
╞════════════╪════════════════════╪════════════╪═══════════╡
│        238 │ Probe Airbag Pack  │     893.33 │         1 │
│         50 │ Drift Touring Skis │     745.19 │         1 │
│        339 │ Nordic Tent 2P     │     744.79 │         1 │
│        312 │ Alpine Tunnel Tent │     734.69 │         1 │
│         14 │ Aurora Down Jacket │      501.7 │         1 │
╰────────────┴────────────────────┴────────────┴───────────╯
```

Both anti-join spellings give the same 66 products; the IS NULL test is on `r.review_id` (the right table's NOT NULL primary key), so NULL can only mean "no match". A `NOT IN (SELECT product_id FROM reviews)` would *also* work here because `reviews.product_id` is NOT NULL — but building the habit is the mistake; the day the subquery column is nullable, `NOT IN` silently returns nothing (Pitfall 4).

### Exercise 5 — opted-in customers with no 2026 orders

```sql
SELECT COUNT(*) AS optin_no_orders_2026
FROM customers AS c
WHERE c.marketing_opt_in = 1
  AND NOT EXISTS (
      SELECT 1
      FROM orders AS o
      WHERE o.customer_id = c.customer_id
        AND o.status <> 'cancelled'
        AND o.ordered_at >= '2026-01-01'
  );
```

```text
╭──────────────────────╮
│ optin_no_orders_2026 │
╞══════════════════════╡
│                  109 │
╰──────────────────────╯
```

```sql
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer,
    c.email
FROM customers AS c
WHERE c.marketing_opt_in = 1
  AND NOT EXISTS (
      SELECT 1
      FROM orders AS o
      WHERE o.customer_id = c.customer_id
        AND o.status <> 'cancelled'
        AND o.ordered_at >= '2026-01-01'
  )
ORDER BY c.customer_id
LIMIT 5;
```

```text
╭─────────────┬───────────────┬───────────────────────────╮
│ customer_id │   customer    │           email           │
╞═════════════╪═══════════════╪═══════════════════════════╡
│           8 │ Priya Tanaka  │ priya.tanaka@gmail.com    │
│          33 │ Dag Andersson │ dag.andersson@icloud.com  │
│          40 │ Freja Nilsson │ freja.nilsson@gmail.com   │
│          49 │ Liv Magnusson │ liv.magnusson@outlook.com │
│          64 │ Kwame Berg    │ kwame.berg@gmail.com      │
╰─────────────┴───────────────┴───────────────────────────╯
```

The conditions (non-cancelled, in 2026) live *inside* the `NOT EXISTS`, so "no such order" means "no non-cancelled 2026 order" — exactly the question. **Common wrong approach:** `LEFT JOIN orders` with `o.ordered_at >= '2026-01-01'` in the `WHERE` clause, then `IS NULL` — the WHERE predicate on the right table converts the LEFT JOIN to INNER before the IS NULL test can do its job (module Pitfall 3), returning zero rows. With the LEFT JOIN spelling, those predicates must go in `ON`.

### Exercise 6 — 2025 gross revenue per category, top 10

```sql
SELECT
    cat.name AS category,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
JOIN products AS p
    ON p.product_id = oi.product_id
JOIN categories AS cat
    ON cat.category_id = p.category_id
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2025-01-01' AND o.ordered_at < '2026-01-01'
GROUP BY cat.name
ORDER BY gross_revenue DESC
LIMIT 10;
```

```text
╭──────────────────┬────────┬───────────────╮
│     category     │ orders │ gross_revenue │
╞══════════════════╪════════╪═══════════════╡
│ Tents            │    389 │     213775.07 │
│ Avalanche Safety │    310 │     164086.04 │
│ Kayaks           │    211 │     149161.64 │
│ Skis             │    280 │     129683.33 │
│ Hiking Boots     │    358 │      73513.29 │
│ Navigation       │    248 │      57784.97 │
│ Jackets          │    144 │      46772.19 │
│ Ropes & Slings   │    186 │      41980.34 │
│ Backpacks        │    207 │       39291.3 │
│ Snowshoes        │    163 │      31555.03 │
╰──────────────────┴────────┴───────────────╯
```

Fan-out check: the joined rows are at order-*line* grain. The `SUM` is safe because item revenue is a line-level fact — each line contributes exactly once to exactly one category. The order count needs `COUNT(DISTINCT o.order_id)` because a multi-line order appears once per line (and can legitimately be counted under several categories — the distinct count is per category, which is what "orders that contributed" means). **Common wrong approach:** `COUNT(o.order_id)` — it counts lines, not orders, quietly inflating every category's order count.

### Exercise 7 — per-carrier delivery stats

```sql
SELECT
    s.carrier,
    COUNT(*) AS shipments,
    COUNT(s.delivered_at) AS delivered,
    COUNT(*) - COUNT(s.delivered_at) AS in_transit,
    ROUND(AVG(julianday(s.delivered_at) - julianday(s.shipped_at)), 2) AS avg_delivery_days,
    COUNT(DISTINCT o.customer_id) AS customers_served
FROM shipments AS s
JOIN orders AS o
    ON o.order_id = s.order_id
GROUP BY s.carrier
ORDER BY shipments DESC;
```

```text
╭──────────┬───────────┬───────────┬────────────┬───────────────────┬──────────────────╮
│ carrier  │ shipments │ delivered │ in_transit │ avg_delivery_days │ customers_served │
╞══════════╪═══════════╪═══════════╪════════════╪═══════════════════╪══════════════════╡
│ UPS      │      1126 │      1096 │         30 │              5.47 │              456 │
│ PostNord │      1122 │      1090 │         32 │              5.52 │              448 │
│ Bring    │      1110 │      1075 │         35 │               5.4 │              449 │
│ DHL      │      1101 │      1065 │         36 │               5.4 │              444 │
│ DPD      │      1073 │      1053 │         20 │              5.55 │              464 │
╰──────────┴───────────┴───────────┴────────────┴───────────────────┴──────────────────╯
```

Module 3's NULL-handling does the heavy lifting: `COUNT(delivered_at)` counts only non-NULL values (= delivered), and `AVG` over `julianday(delivered_at) - julianday(shipped_at)` silently skips in-transit rows because NULL arithmetic yields NULL and aggregates ignore NULLs — no explicit "delivered only" filter needed. The join to `orders` is one-to-one from the shipment side (each shipment belongs to one order), so `COUNT(*)` per carrier is not inflated; `DISTINCT` on `customer_id` collapses repeat customers.

### Exercise 8 — active 2026 customers who have reviewed

```sql
SELECT COUNT(*) AS active_2026_reviewers
FROM customers AS c
WHERE EXISTS (
    SELECT 1
    FROM orders AS o
    WHERE o.customer_id = c.customer_id
      AND o.status <> 'cancelled'
      AND o.ordered_at >= '2026-01-01'
)
AND EXISTS (
    SELECT 1
    FROM reviews AS r
    WHERE r.customer_id = c.customer_id
);
```

```text
╭───────────────────────╮
│ active_2026_reviewers │
╞═══════════════════════╡
│                   479 │
╰───────────────────────╯
```

Two independent semi-joins stacked in one `WHERE`. Each customer row is tested twice and appears at most once — no row multiplication, no `DISTINCT` cleanup. **Common wrong approach:** joining `customers → orders → reviews` and counting — that produces (2026 orders × reviews) rows per customer and, even with `COUNT(DISTINCT c.customer_id)` patching the number, does far more work and hides the intent.

## Challenge

### Exercise 9 — 2025 gross revenue per top-level category

```sql
SELECT
    parent.name AS top_level_category,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
JOIN products AS p
    ON p.product_id = oi.product_id
JOIN categories AS child
    ON child.category_id = p.category_id
JOIN categories AS parent
    ON parent.category_id = child.parent_category_id
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2025-01-01' AND o.ordered_at < '2026-01-01'
GROUP BY parent.name
ORDER BY gross_revenue DESC;
```

```text
╭────────────────────┬───────────────╮
│ top_level_category │ gross_revenue │
╞════════════════════╪═══════════════╡
│ Winter Sports      │     325324.39 │
│ Camping            │     296438.33 │
│ Water Sports       │     175314.66 │
│ Hiking             │     150170.23 │
│ Climbing           │      93717.78 │
│ Apparel            │      88379.39 │
╰────────────────────┴───────────────╯
```

A five-table chain ending in a self-join: `categories` appears twice, once as the product's own (child) category and once as that category's parent. INNER JOIN to `parent` is safe because every product sits in a child category, and every child has a parent. In a deeper tree (grandchildren), one self-join hop wouldn't be enough — that generalization is the recursive CTE, Module 5.

### Exercise 10 — order pairs within 7 days, 2026

The count:

```sql
SELECT COUNT(*) AS pairs_within_7_days
FROM orders AS o1
JOIN orders AS o2
    ON o2.customer_id = o1.customer_id
   AND o1.ordered_at < o2.ordered_at
   AND julianday(o2.ordered_at) - julianday(o1.ordered_at) <= 7
WHERE o1.ordered_at >= '2026-01-01';
```

```text
╭─────────────────────╮
│ pairs_within_7_days │
╞═════════════════════╡
│                1855 │
╰─────────────────────╯
```

The 5 closest-spaced pairs:

```sql
SELECT
    o1.customer_id,
    o1.order_id AS first_order,
    o2.order_id AS next_order,
    o1.ordered_at AS first_at,
    o2.ordered_at AS next_at,
    ROUND(julianday(o2.ordered_at) - julianday(o1.ordered_at), 2) AS days_apart
FROM orders AS o1
JOIN orders AS o2
    ON o2.customer_id = o1.customer_id
   AND o1.ordered_at < o2.ordered_at
   AND julianday(o2.ordered_at) - julianday(o1.ordered_at) <= 7
WHERE o1.ordered_at >= '2026-01-01'
ORDER BY days_apart
LIMIT 5;
```

```text
╭─────────────┬─────────────┬────────────┬─────────────────────┬─────────────────────┬────────────╮
│ customer_id │ first_order │ next_order │      first_at       │       next_at       │ days_apart │
╞═════════════╪═════════════╪════════════╪═════════════════════╪═════════════════════╪════════════╡
│         526 │         637 │       5251 │ 2026-06-24 01:58:14 │ 2026-06-24 02:02:24 │        0.0 │
│         244 │        2790 │       4763 │ 2026-06-27 17:34:52 │ 2026-06-27 17:55:05 │       0.01 │
│         104 │        3289 │        113 │ 2026-06-17 13:22:34 │ 2026-06-17 13:41:07 │       0.01 │
│         420 │        5940 │       5147 │ 2026-07-09 01:32:24 │ 2026-07-09 01:42:31 │       0.01 │
│         107 │        1179 │       4720 │ 2026-06-11 15:29:36 │ 2026-06-11 16:14:16 │       0.03 │
╰─────────────┴─────────────┴────────────┴─────────────────────┴─────────────────────┴────────────╯
```

Deduplication and ordering both come from `o1.ordered_at < o2.ordered_at`: each pair is kept exactly once, with `o1` genuinely the earlier order. Look at customer 104's pair: the earlier order has the *higher* id (3289 → 113) — proof that ids aren't chronological here. Because `o1` is the earlier order, `o1.ordered_at >= '2026-01-01'` alone pins the whole pair into 2026. (If two orders could share an identical timestamp, you'd add an `order_id` tie-break to the ordering condition; this dataset has no such ties.)

**Common wrong approach:** deduplicating with `o1.order_id < o2.order_id` plus `julianday(o2.ordered_at) - julianday(o1.ordered_at) BETWEEN 0 AND 7`:

```sql
SELECT COUNT(*) AS pairs_within_7_days
FROM orders AS o1
JOIN orders AS o2
    ON o2.customer_id = o1.customer_id
   AND o1.order_id < o2.order_id
   AND julianday(o2.ordered_at) - julianday(o1.ordered_at) BETWEEN 0 AND 7
WHERE o1.ordered_at >= '2026-01-01';
```

```text
╭─────────────────────╮
│ pairs_within_7_days │
╞═════════════════════╡
│                 895 │
╰─────────────────────╯
```

895 instead of 1,855 — less than half. It assumes a higher `order_id` means a later order. Whenever the higher-id order is actually the *earlier* one, the day difference computes negative and the pair is silently discarded instead of being counted with roles swapped. Sequence questions must be answered with timestamps.

### Exercise 11 — supplier never-sold scorecard

```sql
SELECT
    s.name AS supplier,
    COUNT(DISTINCT p.product_id) AS products,
    COUNT(DISTINCT oi.product_id) AS products_sold,
    COUNT(DISTINCT p.product_id) - COUNT(DISTINCT oi.product_id) AS never_sold
FROM suppliers AS s
JOIN products AS p
    ON p.supplier_id = s.supplier_id
LEFT JOIN order_items AS oi
    ON oi.product_id = p.product_id
GROUP BY s.name
HAVING never_sold > 0
ORDER BY never_sold DESC, supplier
LIMIT 10;
```

```text
╭─────────────────────┬──────────┬───────────────┬────────────╮
│      supplier       │ products │ products_sold │ never_sold │
╞═════════════════════╪══════════╪═══════════════╪════════════╡
│ Glacier Goods AG    │       13 │             9 │          4 │
│ Hardanger Supply AS │        8 │             5 │          3 │
│ Aurora Apparel AB   │       11 │             9 │          2 │
│ Cairn Supply Co     │       13 │            11 │          2 │
│ Dovre Equipment AS  │        8 │             6 │          2 │
│ Elbe Outdoor GmbH   │        6 │             4 │          2 │
│ Gotland Gear AB     │        7 │             5 │          2 │
│ Lapland Works Oy    │       12 │            10 │          2 │
│ Lofoten Gear AS     │       10 │             8 │          2 │
│ Malaren Sport AB    │       12 │            10 │          2 │
╰─────────────────────┴──────────┴───────────────┴────────────╯
```

... 25 suppliers total have at least one never-sold product. This query leans on two NULL/DISTINCT facts working together. The LEFT JOIN to `order_items` fans out heavily (a product sold 100 times contributes 100 rows), so both counts *must* be `DISTINCT` — `COUNT(DISTINCT p.product_id)` collapses the fan-out back to the true product count. And a never-sold product's `oi.product_id` is NULL from the LEFT JOIN, which `COUNT` skips — so `COUNT(DISTINCT oi.product_id)` is precisely "products with at least one sale". The difference is the never-sold count, no subquery needed. **Common wrong approach:** `COUNT(p.product_id)` without `DISTINCT` — the join fan-out makes every supplier appear to carry hundreds of products.
