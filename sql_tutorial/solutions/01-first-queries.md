# Module 1 Solutions — First Queries

All queries run against `shop.db` from the course root. Outputs are real (`sqlite3 -box`).

## Warm-up

### Exercise 1 — Warehouse tour

```bash
sqlite3 shop.db ".tables"
```

```text
addresses     customers    order_items    payments         products    shipments
categories    events       orders         price_history    reviews     suppliers
```

```bash
sqlite3 shop.db ".schema events"
```

```text
CREATE TABLE events (
    event_id    INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    event_type  TEXT NOT NULL CHECK (event_type IN
                    ('page_view', 'add_to_cart', 'begin_checkout', 'search')),
    product_id  INTEGER REFERENCES products(product_id),
    occurred_at TEXT NOT NULL
);
```

```bash
sqlite3 shop.db ".schema price_history"
```

```text
CREATE TABLE price_history (
    price_id   INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    price      REAL NOT NULL CHECK (price >= 0),
    valid_from TEXT NOT NULL,
    valid_to   TEXT              -- NULL = current price
);
```

```sql
SELECT * FROM events LIMIT 3;
```

```text
╭──────────┬─────────────┬─────────────┬────────────┬─────────────────────╮
│ event_id │ customer_id │ event_type  │ product_id │     occurred_at     │
╞══════════╪═════════════╪═════════════╪════════════╪═════════════════════╡
│        1 │           1 │ page_view   │        238 │ 2026-01-31 23:47:15 │
│        2 │           1 │ page_view   │         26 │ 2026-01-31 23:49:42 │
│        3 │           1 │ add_to_cart │        145 │ 2026-01-31 23:55:53 │
╰──────────┴─────────────┴─────────────┴────────────┴─────────────────────╯
```

```sql
SELECT * FROM price_history LIMIT 3;
```

```text
╭──────────┬────────────┬────────┬─────────────────────┬─────────────────────╮
│ price_id │ product_id │ price  │     valid_from      │      valid_to       │
╞══════════╪════════════╪════════╪═════════════════════╪═════════════════════╡
│        1 │          1 │ 111.52 │ 2022-09-04 09:36:44 │ 2023-07-08 04:25:04 │
│        2 │          1 │  99.65 │ 2023-07-08 04:25:04 │ 2024-12-04 16:32:33 │
│        3 │          1 │  94.69 │ 2024-12-04 16:32:33 │ 2025-04-13 15:49:26 │
╰──────────┴────────────┴────────┴─────────────────────┴─────────────────────╯
```

An `events` row is one clickstream action (a page view, add-to-cart, checkout start, or search) by one customer at one moment; `product_id` can be NULL because searches and checkout starts aren't tied to a product. A `price_history` row says "this product cost this much from `valid_from` until `valid_to`" — a NULL `valid_to` marks the currently valid price. `SELECT * ... LIMIT n` is the right idiom here: this is interactive exploration, exactly where `*` belongs.

### Exercise 2 — Bargain bin

```sql
SELECT sku, name, unit_price
FROM products
ORDER BY unit_price
LIMIT 10;
```

```text
╭────────────┬────────────────────┬────────────╮
│    sku     │        name        │ unit_price │
╞════════════╪════════════════════╪════════════╡
│ NK-21-0086 │ Aqua Dry Bag 20L   │       8.18 │
│ NK-09-0268 │ Micro Ascender     │       8.72 │
│ NK-04-0052 │ Scout Cook Set     │       9.48 │
│ NK-09-0340 │ Micro Belay Device │      10.96 │
│ NK-09-0077 │ Micro Carabiner    │       12.2 │
│ NK-21-0272 │ Splash Dry Bag 40L │      12.48 │
│ NK-25-0278 │ Frost Sun Hat      │      13.25 │
│ NK-25-0024 │ Polar Balaclava    │      14.43 │
│ NK-04-0316 │ Scout Water Filter │      16.56 │
│ NK-04-0095 │ Fire Stove         │      17.46 │
╰────────────┴────────────────────┴────────────╯
```

"Cheapest first" is ascending order, and `ASC` is the default, so no direction keyword is needed. **Common wrong approach:** `LIMIT 10` without the `ORDER BY` — that returns *ten arbitrary* products, not the ten cheapest; `LIMIT` only truncates whatever order the engine happened to produce.

### Exercise 3 — Status inventory

```sql
SELECT DISTINCT status
FROM orders
ORDER BY status;
```

```text
╭───────────╮
│  status   │
╞═══════════╡
│ cancelled │
│ delivered │
│ paid      │
│ pending   │
│ returned  │
│ shipped   │
╰───────────╯
```

```sql
SELECT DISTINCT event_type
FROM events
ORDER BY event_type;
```

```text
╭────────────────╮
│   event_type   │
╞════════════════╡
│ add_to_cart    │
│ begin_checkout │
│ page_view      │
│ search         │
╰────────────────╯
```

`DISTINCT` collapses 6,000 orders to 6 statuses and 16,364 events to 4 types. The `ORDER BY` matters even here: without it, DISTINCT output order is an engine accident.

## Core

### Exercise 4 — Mailing list

```sql
SELECT first_name || ' ' || last_name AS full_name,
       email,
       city || ', ' || country        AS location
FROM customers
ORDER BY last_name, first_name
LIMIT 15;
```

```text
╭─────────────────┬─────────────────────────────┬────────────────────────────╮
│    full_name    │            email            │          location          │
╞═════════════════╪═════════════════════════════╪════════════════════════════╡
│ Alma Ahmed      │ alma.ahmed@outlook.com      │ Zurich, Switzerland        │
│ Bjorn Ahmed     │ bjorn.ahmed@icloud.com      │ Oulu, Finland              │
│ Dag Ahmed       │ dag.ahmed@yahoo.com         │ Manchester, United Kingdom │
│ Elias Ahmed     │ elias.ahmed@gmail.com       │ Uppsala, Sweden            │
│ Katja Ahmed     │ katja.ahmed@gmail.com       │ Amsterdam, Netherlands     │
│ Kirsten Ahmed   │ kirsten.ahmed@fastmail.com  │ Bern, Switzerland          │
│ Linnea Ahmed    │ linnea.ahmed@icloud.com     │ Bergen, Norway             │
│ Mats Ahmed      │ mats.ahmed@gmail.com        │ Malmo, Sweden              │
│ Nora Ahmed      │ nora.ahmed@gmail.com        │ Manchester, United Kingdom │
│ Per Ahmed       │ per.ahmed@proton.me         │ Umea, Sweden               │
│ Ragnar Ahmed    │ ragnar.ahmed@icloud.com     │ Trondheim, Norway          │
│ Ragnar Ahmed    │ ragnar.ahmed@outlook.com    │ Uppsala, Sweden            │
│ Thea Ahmed      │ thea.ahmed@yahoo.com        │ Edinburgh, United Kingdom  │
│ Amara Andersson │ amara.andersson@outlook.com │ Manchester, United Kingdom │
│ Bjorn Andersson │ bjorn.andersson@yahoo.com   │ Utrecht, Netherlands       │
╰─────────────────┴─────────────────────────────┴────────────────────────────╯
```

Note the sort keys are the *raw columns* (`last_name, first_name`), not the concatenated alias — sorting by `full_name` would order by first name ("Alma Ahmed" < "Bjorn Ahmed" works here by luck, but "Bjorn Andersson" would sort before "Dag Ahmed"). Also note the two Ragnar Ahmeds: real datasets have near-duplicate people; only `email` (UNIQUE) distinguishes them.

### Exercise 5 — Margin leaderboard

```sql
SELECT name,
       unit_price,
       unit_cost,
       ROUND(unit_price - unit_cost, 2)                      AS margin,
       ROUND((unit_price - unit_cost) / unit_price * 100, 1) AS margin_pct
FROM products
ORDER BY margin_pct DESC, name
LIMIT 10;
```

```text
╭─────────────────────────┬────────────┬───────────┬────────┬────────────╮
│          name           │ unit_price │ unit_cost │ margin │ margin_pct │
╞═════════════════════════╪════════════╪═══════════╪════════╪════════════╡
│ Core Rope 70m           │     147.33 │     61.89 │  85.44 │       58.0 │
│ Rescue Avalanche Beacon │     834.53 │    351.53 │  483.0 │       57.9 │
│ Flex Ski Poles          │     101.75 │     43.18 │  58.57 │       57.6 │
│ Fjell Quilt             │     205.85 │     87.47 │ 118.38 │       57.5 │
│ Crest Backpack 50L      │     201.38 │     85.88 │  115.5 │       57.4 │
│ Orion Map Case          │     221.04 │     94.18 │ 126.86 │       57.4 │
│ Vandra Backpack 35L     │     273.31 │    116.49 │ 156.82 │       57.4 │
│ Vandra Hydration Pack   │     114.76 │     48.94 │  65.82 │       57.4 │
│ Carbon Folding Poles    │      78.31 │     33.41 │   44.9 │       57.3 │
│ Core Sling 120cm        │      67.39 │     28.76 │  38.63 │       57.3 │
╰─────────────────────────┴────────────┴───────────┴────────┴────────────╯
```

Margin percentage of the sale price is `(price − cost) / price`, and since both columns are REAL there's no integer-division risk here. Ordering by the alias keeps the query readable, and `name` as second key makes the four-way 57.4 tie deterministic.

### Exercise 6 — Whale lines

```sql
SELECT order_id,
       product_id,
       quantity,
       unit_price,
       discount_pct,
       ROUND(quantity * unit_price * (1 - discount_pct / 100.0), 2) AS item_revenue
FROM order_items
ORDER BY item_revenue DESC
LIMIT 10;
```

```text
╭──────────┬────────────┬──────────┬────────────┬──────────────┬──────────────╮
│ order_id │ product_id │ quantity │ unit_price │ discount_pct │ item_revenue │
╞══════════╪════════════╪══════════╪════════════╪══════════════╪══════════════╡
│      629 │        241 │        4 │     834.53 │            0 │      3338.12 │
│     1374 │         46 │        3 │    1004.85 │            0 │      3014.55 │
│     2382 │         46 │        3 │    1004.85 │            0 │      3014.55 │
│     2653 │         46 │        3 │    1004.85 │            0 │      3014.55 │
│     4718 │         46 │        3 │    1004.85 │            0 │      3014.55 │
│     2326 │         46 │        3 │    1004.85 │            5 │      2863.82 │
│      190 │        266 │        4 │     707.39 │            0 │      2829.56 │
│       88 │        289 │        3 │     934.86 │            0 │      2804.58 │
│     2622 │        289 │        3 │     934.86 │            0 │      2804.58 │
│     4494 │         46 │        3 │    1004.85 │           15 │      2562.37 │
╰──────────┴────────────┴──────────┴────────────┴──────────────┴──────────────╯
```

This is the canonical **item revenue** formula from `DATASET.md`, verbatim. **Common wrong approach:** `discount_pct / 100` (integer division) — it evaluates to 0 for every discount up to 99%, so discounted lines like order 2326 would show 3014.55 instead of 2863.82: a query that runs fine, looks plausible, and is wrong. That's the most dangerous kind.

### Exercise 7 — Catalog, page 3

```sql
SELECT sku, name, unit_price
FROM products
ORDER BY name, product_id
LIMIT 20 OFFSET 40;
```

```text
╭────────────┬────────────────────────┬────────────╮
│    sku     │          name          │ unit_price │
╞════════════╪════════════════════════╪════════════╡
│ NK-12-0197 │ Carbon Folding Poles   │      78.31 │
│ NK-20-0125 │ Carbon Kayak Paddle    │       66.8 │
│ NK-20-0127 │ Carbon SUP Paddle      │     226.79 │
│ NK-12-0089 │ Carbon Ski Poles       │     137.47 │
│ NK-04-0147 │ Compact Cook Set       │      96.22 │
│ NK-04-0270 │ Compact Spork Set      │      64.87 │
│ NK-04-0100 │ Compact Stove          │      36.56 │
│ NK-04-0216 │ Compact Water Filter   │     147.12 │
│ NK-24-0140 │ Core Base Layer Bottom │       54.4 │
│ NK-24-0304 │ Core Base Layer Top    │      21.84 │
│ NK-07-0204 │ Core Cordelette        │      241.7 │
│ NK-24-0235 │ Core Merino Socks 3pk  │     114.12 │
│ NK-24-0013 │ Core Merino Tee        │     105.14 │
│ NK-07-0192 │ Core Rope 60m          │     220.15 │
│ NK-07-0087 │ Core Rope 70m          │     147.33 │
│ NK-07-0179 │ Core Sling 120cm       │      67.39 │
│ NK-07-0154 │ Core Static Rope 40m   │      97.51 │
│ NK-08-0137 │ Crag Big Wall Harness  │      97.46 │
│ NK-08-0253 │ Crag Chest Harness     │      62.95 │
│ NK-08-0034 │ Crag Harness           │      60.85 │
╰────────────┴────────────────────────┴────────────╯
```

Page 3 at 20 per page = skip 40, take 20: `LIMIT 20 OFFSET 40`. The `product_id` tie-breaker makes the pagination deterministic even if two products ever shared a name (in this catalog names happen to be unique, but a pagination query shouldn't depend on that being true forever).

### Exercise 8 — Payment matrix

```sql
SELECT DISTINCT method, status
FROM payments
ORDER BY method, status;
```

```text
╭───────────────┬──────────╮
│    method     │  status  │
╞═══════════════╪══════════╡
│ bank_transfer │ captured │
│ bank_transfer │ failed   │
│ bank_transfer │ pending  │
│ card          │ captured │
│ card          │ failed   │
│ card          │ pending  │
│ klarna        │ captured │
│ klarna        │ failed   │
│ klarna        │ pending  │
│ paypal        │ captured │
│ paypal        │ failed   │
│ paypal        │ pending  │
│ refund        │ captured │
╰───────────────┴──────────╯
```

The `refund` method appears only with status `captured` — refunds never fail (or fail-to-pend) in this dataset. Multi-column `DISTINCT` gives distinct *combinations*, which is exactly what a matrix like this needs.

### Exercise 9 — Fresh reviews

```sql
SELECT product_id, rating, review_text, created_at
FROM reviews
ORDER BY created_at DESC
LIMIT 10;
```

```text
╭────────────┬────────┬───────────────────────────────────────────────────────┬─────────────────────╮
│ product_id │ rating │                      review_text                      │     created_at      │
╞════════════╪════════╪═══════════════════════════════════════════════════════╪═════════════════════╡
│        346 │      3 │ Does the job, but the zipper feels flimsy.            │ 2026-07-15 10:23:23 │
│        215 │      5 │                                                       │ 2026-07-15 09:29:24 │
│        299 │      4 │ Solid construction, thoughtful details.               │ 2026-07-15 09:28:38 │
│        164 │      3 │ Does the job, but the zipper feels flimsy.            │ 2026-07-15 08:47:54 │
│        135 │      4 │ My third purchase from this brand. Never disappoints. │ 2026-07-15 08:27:26 │
│        158 │      4 │ Excellent quality, exceeded my expectations.          │ 2026-07-15 05:04:40 │
│        209 │      5 │                                                       │ 2026-07-15 04:53:03 │
│        348 │      5 │ Excellent quality, exceeded my expectations.          │ 2026-07-15 04:01:22 │
│        290 │      5 │                                                       │ 2026-07-15 02:12:00 │
│        175 │      5 │                                                       │ 2026-07-14 21:26:07 │
╰────────────┴────────┴───────────────────────────────────────────────────────┴─────────────────────╯
```

Several `review_text` values render blank: they are `NULL` — the customer left a star rating with no text. Per `DATASET.md` this affects ~35% of reviews and is deliberate, not a bug: rating-only reviews are how real review systems behave. Module 2 covers how NULL behaves in comparisons (and why `review_text = NULL` will never match anything).

*(The seed data is deterministic, so your output should match this exactly; if it doesn't, rebuild `shop.db` from `data/seed.sql` and rerun.)*

## Challenge

### Exercise 10 — Refund radar

```sql
SELECT payment_id, order_id, amount, method, paid_at
FROM payments
ORDER BY amount
LIMIT 5;
```

```text
╭────────────┬──────────┬──────────┬────────┬─────────────────────╮
│ payment_id │ order_id │  amount  │ method │       paid_at       │
╞════════════╪══════════╪══════════╪════════╪═════════════════════╡
│       4120 │     4010 │ -2774.63 │ refund │ 2026-05-16 13:59:59 │
│        112 │      106 │ -2692.49 │ refund │ 2024-11-24 16:29:55 │
│       5154 │     5024 │ -2279.65 │ refund │ 2026-02-18 11:30:33 │
│       1878 │     1836 │ -1983.51 │ refund │ 2025-06-02 10:03:38 │
│       3058 │     2975 │ -1919.91 │ refund │ 2026-06-03 07:06:14 │
╰────────────┴──────────┴──────────┴────────┴─────────────────────╯
```

Refunds are stored as **negative** amounts, so the largest refunds are the *smallest* values in the table — ascending order (the default) puts them on top. **Common wrong approach:** `ORDER BY amount DESC LIMIT 5` — that returns the largest *payments*, the exact opposite of what finance asked for. This inversion (biggest refund = minimum amount) is worth internalizing now; it's why naive `SUM(amount)` will correctly net out refunds in Module 3, and why "largest" always needs a sign convention check.

### Exercise 11 — First deliveries

The naive query:

```sql
-- BAD: NULL delivered_at (in-transit shipments) sorts before every real date
SELECT shipment_id, order_id, carrier, delivered_at
FROM shipments
ORDER BY delivered_at
LIMIT 5;
```

```text
╭─────────────┬──────────┬──────────┬──────────────╮
│ shipment_id │ order_id │ carrier  │ delivered_at │
╞═════════════╪══════════╪══════════╪══════════════╡
│           2 │        3 │ DHL      │              │
│          34 │       38 │ PostNord │              │
│          51 │       58 │ PostNord │              │
│          62 │       70 │ Bring    │              │
│          83 │       92 │ Bring    │              │
╰─────────────┴──────────┴──────────┴──────────────╯
```

SQLite sorts `NULL` before every non-NULL value in ascending order, so the 153 still-in-transit shipments (NULL `delivered_at`) fill the top of the list. The fix:

```sql
SELECT shipment_id, order_id, carrier, delivered_at
FROM shipments
ORDER BY delivered_at NULLS LAST
LIMIT 5;
```

```text
╭─────────────┬──────────┬──────────┬─────────────────────╮
│ shipment_id │ order_id │ carrier  │    delivered_at     │
╞═════════════╪══════════╪══════════╪═════════════════════╡
│        4714 │     5123 │ Bring    │ 2023-01-10 07:01:50 │
│        3948 │     4296 │ PostNord │ 2023-01-12 01:51:33 │
│        1224 │     1338 │ UPS      │ 2023-01-13 03:44:52 │
│        4668 │     5072 │ Bring    │ 2023-01-17 10:44:58 │
│        4214 │     4587 │ Bring    │ 2023-01-25 01:32:45 │
╰─────────────┴──────────┴──────────┴─────────────────────╯
```

(Once you know `WHERE` from Module 2, `WHERE delivered_at IS NOT NULL` is the other idiomatic fix — arguably better, since it states the business rule "delivered shipments only" explicitly.)

### Exercise 12 — Line labels

```sql
SELECT 'Order ' || order_id || ': ' || quantity || ' x ' || unit_price
       || ' (' || discount_pct || '% off)' AS line_label
FROM order_items
ORDER BY order_id, product_id
LIMIT 5;
```

```text
╭───────────────────────────────╮
│          line_label           │
╞═══════════════════════════════╡
│ Order 1: 1 x 340.46 (0% off)  │
│ Order 1: 1 x 399.33 (0% off)  │
│ Order 1: 3 x 834.53 (10% off) │
│ Order 1: 2 x 267.33 (0% off)  │
│ Order 1: 1 x 132.69 (0% off)  │
╰───────────────────────────────╯
```

SQLite implicitly converts each numeric operand to text when it meets `||` — no explicit cast needed (Module 8 covers explicit `CAST` and type affinity). Note the ordering: "lowest order_id, ties by product_id" sorts *within* order 1 by product_id (182, 190, 241, 305, 333), which is why the 834.53 line appears third — all five rows belong to order 1, arranged by product, not by the sequence in which they were added to the cart.
